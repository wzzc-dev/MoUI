#ifndef NATIVE_RENDERER_H
#define NATIVE_RENDERER_H

#include <stdint.h>

// Window handle type
typedef uint64_t native_window_t;

// Draw RGBA pixel buffer to window
void renderer_present(
    native_window_t window,
    const uint8_t* pixels,
    int32_t width,
    int32_t height
);

// Draw a tightly packed RGBA pixel rectangle to a window offset
void renderer_present_rect(
    native_window_t window,
    const uint8_t* pixels,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height
);

// Draw a tightly packed RGBA pixel rectangle with full surface dimensions
void renderer_present_surface_rect(
    native_window_t window,
    const uint8_t* pixels,
    int32_t surface_width,
    int32_t surface_height,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height
);

#endif // NATIVE_RENDERER_H
