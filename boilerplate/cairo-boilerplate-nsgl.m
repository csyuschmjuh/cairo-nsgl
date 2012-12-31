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

static const cairo_user_data_key_t gl_closure_key;

typedef struct _nsgl_target_closure {
    NSOpenGLContext *ctx;
    NSAutoreleasePool *pool;

    cairo_device_t *device;
    cairo_surface_t *surface;
} nsgl_target_closure_t;

static void
_cairo_boilerplate_nsgl_cleanup (void *closure)
{
    nsgl_target_closure_t *gltc = closure;

    cairo_device_finish (gltc->device);
    cairo_device_destroy (gltc->device);

    [NSOpenGLContext clearCurrentContext];
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

static void
_cairo_boilerplate_nsgl_synchronize (void *closure)
{
    nsgl_target_closure_t *gltc = closure;

    if (cairo_device_acquire (gltc->device))
	return;

    glFinish ();

    cairo_device_release (gltc->device);
}

static const cairo_boilerplate_target_t targets[] = {
    {
	"nsgl", "gl", NULL, NULL,
	CAIRO_SURFACE_TYPE_GL, CAIRO_CONTENT_COLOR_ALPHA, 1,
	"cairo_nsgl_device_create",
	_cairo_boilerplate_nsgl_create_surface,
	cairo_surface_create_similar,
	NULL, NULL,
	_cairo_boilerplate_get_image_surface,
	cairo_surface_write_to_png,
	_cairo_boilerplate_nsgl_cleanup,
	_cairo_boilerplate_nsgl_synchronize,
        NULL,
	TRUE, FALSE, FALSE
    }
};
CAIRO_BOILERPLATE (nsgl, targets)
