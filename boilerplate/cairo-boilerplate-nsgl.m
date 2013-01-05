/* Cairo - a vector graphics library with display and print output
 *
 * Copyright © 2009 Chris Wilson
 * Copyright © 2012 Henry Song
 *
 * This library is free software; you can redistribute it and/or
 * modify it either under the terms of the GNU Lesser General Public
 * License version 2.1 as published by the Free Software Foundation
 * (the "LGPL") or, at your option, under the terms of the Mozilla
 * Public License Version 1.1 (the "MPL"). If you do not alter this
 * notice, a recipient may use your version of this file under either
 * the MPL or the LGPL.
 *
 * You should have received a copy of the LGPL along with this library
 * in the file COPYING-LGPL-2.1; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA 02110-1335, USA
 * You should have received a copy of the MPL along with this library
 * in the file COPYING-MPL-1.1
 *
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY
 * OF ANY KIND, either express or implied. See the LGPL or the MPL for
 * the specific language governing rights and limitations.
 *
 * The Original Code is the cairo graphics library.
 *
 * The Initial Developer of the Original Code is Chris Wilson.
 *
 * Contributors
 *	Henry Song <henry.song@samsung.com>
 */

#import "cairo-boilerplate-private.h"

#import <cairo-gl.h>

#import <AppKit/NSOpenGL.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Cocoa/Cocoa.h>

static const cairo_user_data_key_t gl_closure_key;

typedef struct _nsgl_target_closure {
    NSOpenGLContext *ctx;
    NSAutoreleasePool *pool;
    NSOpenGLView *view;
    NSWindow *window;

    cairo_device_t *device;
    cairo_surface_t *surface;
} nsgl_target_closure_t;

@interface NSGLTestView : NSOpenGLView {
}

@end

@implementation NSGLTestView

+ (NSOpenGLPixelFormat*)defaultPixelFormat
{
    NSOpenGLPixelFormatAttribute attrs[] =
    {
	NSOpenGLPFADoubleBuffer,
	NSOpenGLPFADepthSize, 24,
	NSOpenGLPFAStencilSize, 8,
	NSOpenGLPFAAlphaSize, 8,
	NSOpenGLPFASampleBuffers, 1,
	NSOpenGLPFASamples, 4,
	NSOpenGLPFAMultisample,
	0
    };
	
    NSOpenGLPixelFormat *classPixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs] autorelease];
    if (!classPixelFormat)
	exit (-1);

    return classPixelFormat;
}

@end

static void
_cairo_boilerplate_nsgl_cleanup (void *closure)
{
    nsgl_target_closure_t *gltc = closure;

    cairo_device_finish (gltc->device);
    cairo_device_destroy (gltc->device);

    [NSOpenGLContext clearCurrentContext];
    
    if (gltc->window) {
	[gltc->window orderOut: nil];
	[gltc->window release];
	[gltc->view release];
    }
    else
	[gltc->ctx release];

    [gltc->pool release];

    free (gltc);
}

static cairo_surface_t *
_cairo_boilerplate_nsgl_create_surface (const char		 *name,
				       cairo_content_t		  content,
				       double			  width,
				       double			  height,
				       double			  max_width,
				       double			  max_height,
				       cairo_boilerplate_mode_t   mode,
				       void			**closure)
{
    nsgl_target_closure_t *gltc;
    cairo_surface_t *surface;
    NSOpenGLPixelFormat *pixelFormat;

    NSOpenGLPixelFormatAttribute attrs[] = {
	NSOpenGLPFADepthSize, 24,
	NSOpenGLPFAStencilSize, 8,
	NSOpenGLPFAAlphaSize, 8,
	0
    };

    gltc = xcalloc (1, sizeof (nsgl_target_closure_t));
    gltc->window = nil;
    gltc->view = nil;
    *closure = gltc;
    gltc->pool = [[NSAutoreleasePool alloc] init];

    pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes: attrs];
    if (!pixelFormat)
	return NULL;

    gltc->ctx = [[NSOpenGLContext alloc] initWithFormat: pixelFormat
				  shareContext: nil];

    if (!gltc->ctx)
	return NULL;

    [gltc->ctx makeCurrentContext];
    gltc->device = cairo_nsgl_device_create (gltc->ctx);

    if (width < 1)
	width = 1;
    if (height < 1)
	height = 1;

    gltc->surface = surface = cairo_gl_surface_create (gltc->device,
						       content,
						       ceil (width),
						       ceil (height));
    if (cairo_surface_status (surface))
	_cairo_boilerplate_nsgl_cleanup (gltc);

    return surface;
}

static cairo_surface_t *
_cairo_boilerplate_nsgl_create_view (const char			*name,
				     cairo_content_t		content,
				     double			width,
				     double			height,
				     double			max_width,
				     double			max_height,
				     cairo_boilerplate_mode_t   mode,
				     void			**closure)
{
    nsgl_target_closure_t *gltc;
    cairo_surface_t *surface;
    int style = NSTexturedBackgroundWindowMask;

    NSWindow *win;
    NSOpenGLView *view;

    NSScreen *screen = [NSScreen mainScreen];
    NSRect frame = [screen visibleFrame];
    int screen_height = frame.size.height;

    gltc = xcalloc (1, sizeof (nsgl_target_closure_t));
    gltc->window = nil;
    gltc->view = nil;
    *closure = gltc;

    gltc->pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    
    if (width < 1)
	width = 1;
    if (height < 1)
	height = 1;

    win = [[NSWindow alloc] initWithContentRect: NSMakeRect (0, screen_height - ceil (height), ceil (width), ceil (height))
			    styleMask: style
			    backing: NSBackingStoreBuffered
			    defer: NO];

    view = [[NSGLTestView alloc] initWithFrame: NSMakeRect (0, 0, ceil (width), ceil (height))];
    [win setContentView: view];
    
    gltc->view = view;
    gltc->window = win;

    gltc->ctx = [gltc->view openGLContext];

    if (!gltc->ctx)
	return NULL;

    [gltc->ctx makeCurrentContext];
    gltc->device = cairo_nsgl_device_create (gltc->ctx);

    gltc->surface = surface = cairo_gl_surface_create_for_view (gltc->device,
								gltc->view,
								ceil (width),
								ceil (height));
    if (cairo_surface_status (surface))
	_cairo_boilerplate_nsgl_cleanup (gltc);

    [win orderFront: win];

    return surface;
}

static cairo_surface_t *
_cairo_boilerplate_nsgl_create_view_db (const char		  *name,
					cairo_content_t		   content,
				 	double			   width,
				 	double			   height,
				 	double			   max_width,
					double			   max_height,
					cairo_boilerplate_mode_t   mode,
					void			 **closure)
{
    cairo_status_t status;
    nsgl_target_closure_t *gltc;
    cairo_surface_t *surface;
    int style = NSTexturedBackgroundWindowMask;

    NSWindow *win;
    NSOpenGLView *view;

    NSScreen *screen = [NSScreen mainScreen];
    NSRect frame = [screen visibleFrame];
    int screen_height = frame.size.height;

    gltc = xcalloc (1, sizeof (nsgl_target_closure_t));
    gltc->window = nil;
    gltc->view = nil;
    *closure = gltc;

    gltc->pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    
    if (width < 1)
	width = 1;
    if (height < 1)
	height = 1;

    win = [[NSWindow alloc] initWithContentRect: NSMakeRect (0, screen_height - ceil (height), ceil (width), ceil (height))
			    styleMask: style
			    backing: NSBackingStoreBuffered
			    defer: NO];

    view = [[NSGLTestView alloc] initWithFrame: NSMakeRect (0, 0, ceil (width), ceil (height))];
    [win setContentView: view];
    
    gltc->view = view;
    gltc->window = win;

    gltc->ctx = [gltc->view openGLContext];

    if (!gltc->ctx)
	return NULL;

    [gltc->ctx makeCurrentContext];
    gltc->device = cairo_nsgl_device_create (gltc->ctx);

    gltc->surface = cairo_gl_surface_create_for_view (gltc->device,
						      gltc->view,
						      ceil (width),
						      ceil (height));
    surface = cairo_surface_create_similar (gltc->surface, content, width, height);

    status = cairo_surface_set_user_data (surface, &gl_closure_key, gltc, NULL);
   
    if (status == CAIRO_STATUS_SUCCESS) {
	[win orderFront: win];
	return surface;
    }

    cairo_surface_destroy (surface);
    _cairo_boilerplate_nsgl_cleanup (gltc);

    return cairo_boilerplate_surface_create_in_error (status);
}

static cairo_status_t
_cairo_boilerplate_nsgl_finish_window (cairo_surface_t *surface)
{
    nsgl_target_closure_t *gltc = cairo_surface_get_user_data (surface,
							       &gl_closure_key);

    if (gltc != NULL && gltc->surface != NULL) {
	cairo_t *cr;

	cr = cairo_create (gltc->surface);
	cairo_surface_set_device_offset (surface, 0, 0);
	cairo_set_source_surface (cr, surface, 0, 0);
	cairo_set_operator (cr, CAIRO_OPERATOR_SOURCE);
	cairo_paint (cr);
	cairo_destroy (cr);

	surface = gltc->surface;
    }

    cairo_gl_surface_swapbuffers (surface);
    return CAIRO_STATUS_SUCCESS;
}

static void
_cairo_boilerplate_nsgl_synchronize (void *closure)
{
    nsgl_target_closure_t *gltc = closure;

    if (cairo_device_acquire (gltc->device))
	return;

    glFinish ();

    cairo_device_release (gltc->device);
}

static char *
_cairo_boilerplate_nsgl_describe (void *closure)
{
    nsgl_target_closure_t *gltc = closure;
    char *s;
    const GLubyte *vendor, *renderer, *version;

    if (cairo_device_acquire (gltc->device))
	return NULL;

    vendor   = glGetString (GL_VENDOR);
    renderer = glGetString (GL_RENDERER);
    version  = glGetString (GL_VERSION);

    xasprintf (&s, "%s %s %s", vendor, renderer, version);

    cairo_device_release (gltc->device);

    return s;
}

static const cairo_boilerplate_target_t targets[] = {
    {
	"nsgl", "gl", NULL, NULL,
	CAIRO_SURFACE_TYPE_GL, CAIRO_CONTENT_COLOR_ALPHA, 1,
	"cairo_nsgl_surface_create",
	_cairo_boilerplate_nsgl_create_surface,
	cairo_surface_create_similar,
	NULL, NULL,
	_cairo_boilerplate_get_image_surface,
	cairo_surface_write_to_png,
	_cairo_boilerplate_nsgl_cleanup,
	_cairo_boilerplate_nsgl_synchronize,
        _cairo_boilerplate_nsgl_describe,
	TRUE, FALSE, FALSE
    },
    {
	"nsgl", "gl", NULL, NULL,
	CAIRO_SURFACE_TYPE_GL, CAIRO_CONTENT_COLOR, 1,
	"cairo_nsgl_surface_create",
	_cairo_boilerplate_nsgl_create_surface,
	cairo_surface_create_similar,
	NULL, NULL,
	_cairo_boilerplate_get_image_surface,
	cairo_surface_write_to_png,
	_cairo_boilerplate_nsgl_cleanup,
	_cairo_boilerplate_nsgl_synchronize,
        _cairo_boilerplate_nsgl_describe,
	TRUE, FALSE, FALSE
    },
    {
	"nsgl-window", "gl", NULL, NULL,
	CAIRO_SURFACE_TYPE_GL, CAIRO_CONTENT_COLOR_ALPHA, 1,
	"cairo_nsgl_surface_create_for_window",
	_cairo_boilerplate_nsgl_create_view,
	cairo_surface_create_similar,
	NULL,
 	_cairo_boilerplate_nsgl_finish_window,
	_cairo_boilerplate_get_image_surface,
	cairo_surface_write_to_png,
	_cairo_boilerplate_nsgl_cleanup,
	_cairo_boilerplate_nsgl_synchronize,
        _cairo_boilerplate_nsgl_describe,
	FALSE, FALSE, FALSE
    },
    {
	"nsgl-windowi&", "gl", NULL, NULL,
	CAIRO_SURFACE_TYPE_GL, CAIRO_CONTENT_COLOR_ALPHA, 1,
	"cairo_nsgl_surface_create_for_window",
	_cairo_boilerplate_nsgl_create_view_db,
	cairo_surface_create_similar,
	NULL,
 	_cairo_boilerplate_nsgl_finish_window,
	_cairo_boilerplate_get_image_surface,
	cairo_surface_write_to_png,
	_cairo_boilerplate_nsgl_cleanup,
	_cairo_boilerplate_nsgl_synchronize,
        _cairo_boilerplate_nsgl_describe,
	FALSE, FALSE, FALSE
    }
};
CAIRO_BOILERPLATE (nsgl, targets)
