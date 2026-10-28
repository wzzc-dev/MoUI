#ifndef MOUI_METAL_PRESENT_SMOKE_H
#define MOUI_METAL_PRESENT_SMOKE_H

#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

// Presenting a frame and drawing something are different claims, and the
// presentation gate could only check the first: the host prints its marker once a
// drawable is handed over, blank surface or not. This file owns the second, and it
// is separate from `metal_renderer.mm` because that file is at the new-source
// length limit and this concern has nothing to do with encoding a frame.
//
// Enabled by MOUI_MACOS_METAL_PRESENT_SMOKE. The layer is also built
// `framebufferOnly = NO` only while it is set, because reading a drawable back
// costs bandwidth on every frame otherwise.

// True when the presentation smoke asked for the readback.
BOOL moui_metal_present_smoke_enabled(void);

// Presents `drawable` on `buffer`, and when the smoke is enabled copies the
// drawable into a staging texture before the present, then prints
// `MOUI-METAL-PRESENT width=.. height=.. ink=..` once, with the number of presented
// pixels that differ from the frame's clear colour.
void moui_metal_present_smoke_draw(id<MTLCommandBuffer> buffer,
                                   id<CAMetalDrawable> drawable,
                                   id<MTLDevice> device,
                                   double red,
                                   double green,
                                   double blue,
                                   double alpha);

#endif  // MOUI_METAL_PRESENT_SMOKE_H
