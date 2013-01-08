/*
 * Copyright © 2008 Chris Wilson
 * Copyright © 2010 Intel Corporation
 *
 * Permission to use, copy, modify, distribute, and sell this software
 * and its documentation for any purpose is hereby granted without
 * fee, provided that the above copyright notice appear in all copies
 * and that both that copyright notice and this permission notice
 * appear in supporting documentation, and that the name of
 * Chris Wilson not be used in advertising or publicity pertaining to
 * distribution of the software without specific, written prior
 * permission. Chris Wilson makes no representations about the
 * suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * CHRIS WILSON DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
 * SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS, IN NO EVENT SHALL CHRIS WILSON BE LIABLE FOR ANY SPECIAL,
 * INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
 * RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
 * OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
 * IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * Author: Henry Song <henry.song@samsung.com>
 */

#import "cairo-test.h"
#import <cairo-gl.h>

#import <AppKit/NSOpenGL.h>
#import <Foundation/NSAutoreleasePool.h>

#import "surface-source.c"

struct closure {
    NSOpenGLContext *ctx;
    NSAutoreleasePool *pool;
};

static void
cleanup (void *data)
{
    struct closure *arg = data;

    [NSOpenGLContext clearCurrentContext];
    if (arg->ctx)
	[arg->ctx release];
    
    [arg->pool release];

    free (arg);
}

static cairo_surface_t *
create_source_surface (int size)
{
    NSOpenGLPixelFormat *pixelFormat;

    NSOpenGLPixelFormatAttribute attrs[] = {
	NSOpenGLPFADepthSize, 24,
	NSOpenGLPFAStencilSize, 8,
	NSOpenGLPFAAlphaSize, 8,
	0
    };
    struct closure *arg;
    cairo_device_t *device;
    cairo_surface_t *surface;

    arg = xmalloc (sizeof (struct closure));
    arg->ctx = nil;
    arg->pool = [[NSAutoreleasePool alloc] init];
    pixelFormat = [[[NSOpenGLPixelFormat alloc] initWithAttributes: attrs] autorelease];
    if (!pixelFormat) {
	cleanup (arg);
	return NULL;
    }

    arg->ctx = [[NSOpenGLContext alloc] initWithFormat: pixelFormat
					  shareContext: nil];
    if (!arg->ctx) {
	cleanup (arg);
	return NULL;
    }

    device = cairo_nsgl_device_create (arg->ctx);
    if (cairo_device_set_user_data (device,
				    (cairo_user_data_key_t *) cleanup,
				    arg,
				    cleanup))
    {
	cleanup (arg);
	return NULL;
    }

    surface = cairo_gl_surface_create (device,
				       CAIRO_CONTENT_COLOR_ALPHA,
				       size, size);
    cairo_device_destroy (device);

    return surface;
}

CAIRO_TEST (gl_surface_source,
	    "Test using a GL surface as the source",
	    "source", /* keywords */
	    NULL, /* requirements */
	    SIZE, SIZE,
	    preamble, draw)
