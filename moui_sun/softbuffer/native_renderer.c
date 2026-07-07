#include "native_renderer.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
// ============================================================================
// Windows Implementation
// ============================================================================
#include <windows.h>

void renderer_present(native_window_t window, const uint8_t* pixels, int32_t width, int32_t height) {
    renderer_present_surface_rect(window, pixels, width, height, 0, 0, width, height);
}

void renderer_present_rect(
    native_window_t window,
    const uint8_t* pixels,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height
) {
    renderer_present_surface_rect(window, pixels, width, height, x, y, width, height);
}

void renderer_present_surface_rect(
    native_window_t window,
    const uint8_t* pixels,
    int32_t surface_width,
    int32_t surface_height,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height
) {
    if (pixels == NULL || surface_width <= 0 || surface_height <= 0 || width <= 0 || height <= 0) {
        return;
    }

    renderer_objc_id view = renderer_content_view(window);
    if (view == NULL) { return; }

    // Find or create passthrough NSImageView subview (created once, reused)
    renderer_objc_id image_view = renderer_find_or_create_image_view(view);
    if (image_view == NULL) { return; }

    // Get content view bounds and window scale factor
    renderer_cgrect_t view_bounds = renderer_view_bounds(view);
    double scale = renderer_backing_scale_factor(view);

    // Update image view frame to match content view bounds (like Skia)
    if (view_bounds.width > 0.0 && view_bounds.height > 0.0) {
        ((void (*)(renderer_objc_id, renderer_objc_sel, renderer_cgrect_t))
            renderer_darwin_api.objc_msg_send)(
                image_view, renderer_sel("setFrame:"), view_bounds);
    }

    // Create CGImage from pixel data
    renderer_backing_t* backing = renderer_backing_for_view(view, surface_width, surface_height);
    if (backing == NULL) { return; }
    renderer_copy_rect_to_backing(backing, pixels, x, y, width, height);

    void* cg_image = renderer_create_cg_image(backing);
    if (cg_image == NULL) { return; }

    // Create NSImage using logical-point size (matching Skia presenter)
    renderer_objc_id ns_image_class = renderer_darwin_api.objc_get_class("NSImage");
    if (ns_image_class != NULL) {
        renderer_objc_id ns_image_alloc = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel))
            renderer_darwin_api.objc_msg_send)(ns_image_class, renderer_sel("alloc"));
        if (ns_image_alloc != NULL) {
            // NSImage size must be in points (logical size), not physical pixels.
            // Skia uses view.bounds; we do the same, falling back to physical
            // pixels divided by the backing scale factor when bounds are empty.
            double point_w, point_h;
            if (view_bounds.width > 0.0 && view_bounds.height > 0.0) {
                point_w = view_bounds.width;
                point_h = view_bounds.height;
            } else {
                point_w = (double)surface_width / scale;
                point_h = (double)surface_height / scale;
            }


            // initWithCGImage:size: takes (CGImageRef, NSSize). NSSize = two doubles on arm64.
            renderer_objc_id ns_image = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel, void*, double, double))
                renderer_darwin_api.objc_msg_send)(
                    ns_image_alloc, renderer_sel("initWithCGImage:size:"),
                    cg_image, point_w, point_h);
            if (ns_image != NULL) {
                ((void (*)(renderer_objc_id, renderer_objc_sel, renderer_objc_id))
                    renderer_darwin_api.objc_msg_send)(
                        image_view, renderer_sel("setImage:"), ns_image);
                ((void (*)(renderer_objc_id, renderer_objc_sel, intptr_t))
                    renderer_darwin_api.objc_msg_send)(
                        image_view, renderer_sel("setNeedsDisplay:"), (intptr_t)1);
                renderer_msg_void(ns_image, "release");
            }
        }
    }

    renderer_darwin_api.cg_image_release(cg_image);
}

int32_t renderer_macos_presenter_passthrough_ready(void) {
    return 0;
}

#elif defined(__APPLE__)
// ============================================================================
// macOS Implementation
//
// Uses an NSImageView subview to display pixel content via setImage:/layer.contents.
// This is the same approach as the Skia macOS presenter and works correctly on
// modern macOS with layer-backed views.
// ============================================================================
#include <dlfcn.h>

// CGRect-equivalent struct
typedef struct {
    double x;
    double y;
    double width;
    double height;
} renderer_cgrect_t;

// NSPoint/CGPoint-equivalent struct (two doubles, 16 bytes).
typedef struct {
    double x;
    double y;
} renderer_cgpoint_t;

typedef void* renderer_objc_id;
typedef void* renderer_objc_class;
typedef void* renderer_objc_sel;

typedef renderer_objc_class (*renderer_objc_get_class_fn)(const char*);
typedef renderer_objc_sel (*renderer_sel_register_name_fn)(const char*);
typedef void* (*renderer_cg_color_space_create_device_rgb_fn)(void);
typedef void* (*renderer_cg_data_provider_create_with_data_fn)(
    void*,
    const void*,
    size_t,
    void (*)(void*, const void*, size_t)
);
typedef void* (*renderer_cg_image_create_fn)(
    size_t,
    size_t,
    size_t,
    size_t,
    size_t,
    void*,
    uint32_t,
    void*,
    const double*,
    bool,
    int
);
typedef void (*renderer_cg_release_fn)(void*);

// ObjC runtime class-creation function pointers used to register a passthrough
// NSImageView subclass whose hitTest: returns nil so pointer events fall
// through to the underlying content view (matching the Skia presenter).
typedef renderer_objc_class (*renderer_objc_allocate_class_pair_fn)(
    renderer_objc_class,
    const char*,
    size_t
);
typedef bool (*renderer_class_add_method_fn)(
    renderer_objc_class,
    renderer_objc_sel,
    void*,
    const char*
);
typedef void (*renderer_objc_register_class_pair_fn)(renderer_objc_class);

typedef struct {
    bool attempted;
    bool ready;
    renderer_objc_get_class_fn objc_get_class;
    renderer_sel_register_name_fn sel_register_name;
    void* objc_msg_send;
    renderer_cg_color_space_create_device_rgb_fn cg_color_space_create_device_rgb;
    renderer_cg_data_provider_create_with_data_fn cg_data_provider_create_with_data;
    renderer_cg_image_create_fn cg_image_create;
    renderer_cg_release_fn cg_image_release;
    renderer_cg_release_fn cg_data_provider_release;
    renderer_cg_release_fn cg_color_space_release;
    void* cg_context_draw_image;
    void* cg_context_translate_ctm;
    void* cg_context_scale_ctm;
    renderer_objc_allocate_class_pair_fn objc_allocate_class_pair;
    renderer_class_add_method_fn class_add_method;
    renderer_objc_register_class_pair_fn objc_register_class_pair;
} renderer_darwin_api_t;

typedef struct renderer_backing {
    renderer_objc_id view;
    int32_t width;
    int32_t height;
    uint8_t* pixels;
    struct renderer_backing* next;
} renderer_backing_t;

static renderer_darwin_api_t renderer_darwin_api = {0};
static renderer_backing_t* renderer_backings = NULL;

static void* renderer_dlsym_any(void* handle, const char* symbol) {
    void* value = handle == NULL ? NULL : dlsym(handle, symbol);
    return value == NULL ? dlsym(RTLD_DEFAULT, symbol) : value;
}

static bool renderer_load_darwin_api(void) {
    if (renderer_darwin_api.attempted) {
        return renderer_darwin_api.ready;
    }
    renderer_darwin_api.attempted = true;

    void* objc = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY | RTLD_LOCAL);
    void* appkit = dlopen(
        "/System/Library/Frameworks/AppKit.framework/AppKit",
        RTLD_LAZY | RTLD_LOCAL
    );
    void* core_graphics = dlopen(
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
        RTLD_LAZY | RTLD_LOCAL
    );
    (void)appkit;

    renderer_darwin_api.objc_get_class =
        (renderer_objc_get_class_fn)renderer_dlsym_any(objc, "objc_getClass");
    renderer_darwin_api.sel_register_name =
        (renderer_sel_register_name_fn)renderer_dlsym_any(objc, "sel_registerName");
    renderer_darwin_api.objc_msg_send = renderer_dlsym_any(objc, "objc_msgSend");
    renderer_darwin_api.cg_color_space_create_device_rgb =
        (renderer_cg_color_space_create_device_rgb_fn)renderer_dlsym_any(
            core_graphics,
            "CGColorSpaceCreateDeviceRGB"
        );
    renderer_darwin_api.cg_data_provider_create_with_data =
        (renderer_cg_data_provider_create_with_data_fn)renderer_dlsym_any(
            core_graphics,
            "CGDataProviderCreateWithData"
        );
    renderer_darwin_api.cg_image_create =
        (renderer_cg_image_create_fn)renderer_dlsym_any(core_graphics, "CGImageCreate");
    renderer_darwin_api.cg_image_release =
        (renderer_cg_release_fn)renderer_dlsym_any(core_graphics, "CGImageRelease");
    renderer_darwin_api.cg_data_provider_release =
        (renderer_cg_release_fn)renderer_dlsym_any(core_graphics, "CGDataProviderRelease");
    renderer_darwin_api.cg_color_space_release =
        (renderer_cg_release_fn)renderer_dlsym_any(core_graphics, "CGColorSpaceRelease");
    renderer_darwin_api.cg_context_draw_image =
        renderer_dlsym_any(core_graphics, "CGContextDrawImage");
    renderer_darwin_api.cg_context_translate_ctm =
        renderer_dlsym_any(core_graphics, "CGContextTranslateCTM");
    renderer_darwin_api.cg_context_scale_ctm =
        renderer_dlsym_any(core_graphics, "CGContextScaleCTM");
    renderer_darwin_api.objc_allocate_class_pair =
        (renderer_objc_allocate_class_pair_fn)renderer_dlsym_any(
            objc,
            "objc_allocateClassPair"
        );
    renderer_darwin_api.class_add_method =
        (renderer_class_add_method_fn)renderer_dlsym_any(objc, "class_addMethod");
    renderer_darwin_api.objc_register_class_pair =
        (renderer_objc_register_class_pair_fn)renderer_dlsym_any(
            objc,
            "objc_registerClassPair"
        );

    renderer_darwin_api.ready =
        renderer_darwin_api.objc_get_class != NULL &&
        renderer_darwin_api.sel_register_name != NULL &&
        renderer_darwin_api.objc_msg_send != NULL &&
        renderer_darwin_api.objc_allocate_class_pair != NULL &&
        renderer_darwin_api.class_add_method != NULL &&
        renderer_darwin_api.objc_register_class_pair != NULL &&
        renderer_darwin_api.cg_color_space_create_device_rgb != NULL &&
        renderer_darwin_api.cg_data_provider_create_with_data != NULL &&
        renderer_darwin_api.cg_image_create != NULL &&
        renderer_darwin_api.cg_image_release != NULL &&
        renderer_darwin_api.cg_data_provider_release != NULL &&
        renderer_darwin_api.cg_color_space_release != NULL &&
        renderer_darwin_api.cg_context_draw_image != NULL &&
        renderer_darwin_api.cg_context_translate_ctm != NULL &&
        renderer_darwin_api.cg_context_scale_ctm != NULL;
    return renderer_darwin_api.ready;
}

static renderer_objc_sel renderer_sel(const char* name) {
    return renderer_darwin_api.sel_register_name(name);
}

static renderer_objc_id renderer_msg_id(renderer_objc_id receiver, const char* selector) {
    return ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel))
        renderer_darwin_api.objc_msg_send)(receiver, renderer_sel(selector));
}

static bool renderer_msg_is_kind_of_class(
    renderer_objc_id receiver,
    renderer_objc_class klass
) {
    return ((signed char (*)(renderer_objc_id, renderer_objc_sel, renderer_objc_class))
        renderer_darwin_api.objc_msg_send)(receiver, renderer_sel("isKindOfClass:"), klass) != 0;
}

static void renderer_msg_void(renderer_objc_id receiver, const char* selector) {
    ((void (*)(renderer_objc_id, renderer_objc_sel))
        renderer_darwin_api.objc_msg_send)(receiver, renderer_sel(selector));
}

static double renderer_backing_scale_factor(renderer_objc_id view) {
    renderer_objc_id ns_window = renderer_msg_id(view, "window");
    if (ns_window == NULL) {
        return 1.0;
    }
    double backing_scale = ((double (*)(renderer_objc_id, renderer_objc_sel))
        renderer_darwin_api.objc_msg_send)(ns_window, renderer_sel("backingScaleFactor"));
    return backing_scale > 0.0 ? backing_scale : 1.0;
}

// hitTest: implementation that always returns nil so the image view never
// intercepts pointer events. This mirrors MOUIMacosSkiaPassthroughImageView.
// Signature: - (NSView *)hitTest:(NSPoint)point;
// NSPoint is a struct of two doubles; on arm64 it is passed in v0/v1.
static renderer_objc_id renderer_passthrough_hit_test(
    renderer_objc_id self,
    renderer_objc_sel _cmd,
    renderer_cgpoint_t point
) {
    (void)self;
    (void)_cmd;
    (void)point;
    return NULL;
}

static renderer_objc_class renderer_passthrough_image_view_class(void) {
    static renderer_objc_class cached = NULL;
    if (cached != NULL) {
        return cached;
    }
    if (!renderer_darwin_api.ready) {
        return NULL;
    }
    renderer_objc_class ns_image_view_class = renderer_darwin_api.objc_get_class("NSImageView");
    if (ns_image_view_class == NULL) {
        return NULL;
    }
    renderer_objc_class new_class = renderer_darwin_api.objc_allocate_class_pair(
        ns_image_view_class,
        "MouiSunPassthroughImageView",
        0
    );
    if (new_class == NULL) {
        // Another module may have already registered the class; look it up.
        cached = renderer_darwin_api.objc_get_class("MouiSunPassthroughImageView");
        return cached;
    }
    // hitTest: returns a pointer; type encoding "16@0:8{CGPoint=dd}16" on arm64,
    // but the portable encoding for an object return with a struct arg is
    // "@16@0:8{CGPoint=dd}16". Use the standard NSView hitTest signature.
    bool added = renderer_darwin_api.class_add_method(
        new_class,
        renderer_sel("hitTest:"),
        (void*)renderer_passthrough_hit_test,
        "@16@0:8{CGPoint=dd}16"
    );
    if (!added) {
        return NULL;
    }
    renderer_darwin_api.objc_register_class_pair(new_class);
    cached = new_class;
    return cached;
}

static bool renderer_passthrough_hit_test_returns_nil(void) {
    renderer_objc_class image_view_class = renderer_passthrough_image_view_class();
    if (image_view_class == NULL) {
        return false;
    }
    renderer_objc_id alloc_view = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel))
        renderer_darwin_api.objc_msg_send)(image_view_class, renderer_sel("alloc"));
    if (alloc_view == NULL) {
        return false;
    }
    renderer_cgrect_t frame = {0.0, 0.0, 1.0, 1.0};
    renderer_objc_id image_view = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel, renderer_cgrect_t))
        renderer_darwin_api.objc_msg_send)(alloc_view, renderer_sel("initWithFrame:"), frame);
    if (image_view == NULL) {
        return false;
    }
    renderer_cgpoint_t point = {0.5, 0.5};
    renderer_objc_id hit = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel, renderer_cgpoint_t))
        renderer_darwin_api.objc_msg_send)(image_view, renderer_sel("hitTest:"), point);
    renderer_msg_void(image_view, "release");
    return hit == NULL;
}

int32_t renderer_macos_presenter_passthrough_ready(void) {
    if (!renderer_load_darwin_api()) {
        return 0;
    }
    return renderer_passthrough_hit_test_returns_nil() ? 1 : 0;
}

// Get view bounds (NSRect/CGRect) via ObjC runtime.
// On ARM64, the compiler handles the HFA (4 doubles) return in v0-v3.
static renderer_cgrect_t renderer_view_bounds(renderer_objc_id view) {
    renderer_cgrect_t rect = {0.0, 0.0, 0.0, 0.0};
    if (view == NULL) { return rect; }
    typedef renderer_cgrect_t (*bounds_fn)(renderer_objc_id, renderer_objc_sel);
    bounds_fn fn = (bounds_fn)renderer_darwin_api.objc_msg_send;
    return fn(view, renderer_sel("bounds"));
}

static renderer_objc_id renderer_content_view(native_window_t window) {
    if (!renderer_load_darwin_api() || window == 0) {
        return NULL;
    }
    if (window < 4096u) {
        return NULL;
    }

    renderer_objc_id object = (renderer_objc_id)(uintptr_t)window;
    renderer_objc_class ns_window = renderer_darwin_api.objc_get_class("NSWindow");
    renderer_objc_class ns_view = renderer_darwin_api.objc_get_class("NSView");
    renderer_objc_id view = object;

    if (ns_window != NULL && renderer_msg_is_kind_of_class(object, ns_window)) {
        view = renderer_msg_id(object, "contentView");
    }
    if (view == NULL) {
        return NULL;
    }
    if (ns_view != NULL && !renderer_msg_is_kind_of_class(view, ns_view)) {
        return NULL;
    }
    return view;
}

static renderer_backing_t* renderer_backing_for_view(
    renderer_objc_id view,
    int32_t width,
    int32_t height
) {
    renderer_backing_t* backing = renderer_backings;
    while (backing != NULL) {
        if (backing->view == view) {
            break;
        }
        backing = backing->next;
    }
    if (backing == NULL) {
        backing = (renderer_backing_t*)calloc(1, sizeof(renderer_backing_t));
        if (backing == NULL) {
            return NULL;
        }
        backing->view = view;
        backing->next = renderer_backings;
        renderer_backings = backing;
    }

    if (backing->width != width || backing->height != height || backing->pixels == NULL) {
        size_t bytes = (size_t)width * (size_t)height * 4u;
        uint8_t* pixels = (uint8_t*)calloc(bytes, 1);
        if (pixels == NULL) {
            return NULL;
        }
        free(backing->pixels);
        backing->pixels = pixels;
        backing->width = width;
        backing->height = height;
    }
    return backing;
}

static void renderer_copy_rect_to_backing(
    renderer_backing_t* backing,
    const uint8_t* pixels,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height
) {
    if (backing == NULL || backing->pixels == NULL || pixels == NULL) {
        return;
    }
    if (x < 0 || y < 0 || width <= 0 || height <= 0) {
        return;
    }
    if (x >= backing->width || y >= backing->height) {
        return;
    }
    int32_t copy_width = width;
    int32_t copy_height = height;
    if (x + copy_width > backing->width) {
        copy_width = backing->width - x;
    }
    if (y + copy_height > backing->height) {
        copy_height = backing->height - y;
    }
    if (copy_width <= 0 || copy_height <= 0) {
        return;
    }

    size_t src_row_bytes = (size_t)width * 4u;
    size_t dst_row_bytes = (size_t)backing->width * 4u;
    size_t copy_row_bytes = (size_t)copy_width * 4u;
    for (int32_t row = 0; row < copy_height; row++) {
        const uint8_t* src = pixels + (size_t)row * src_row_bytes;
        uint8_t* dst =
            backing->pixels + (size_t)(y + row) * dst_row_bytes + (size_t)x * 4u;
        memcpy(dst, src, copy_row_bytes);
    }
}

static void renderer_release_image_data(void* info, const void* data, size_t size) {
    (void)info;
    (void)size;
    free((void*)data);
}

static void* renderer_create_cg_image(renderer_backing_t* backing) {
    if (backing == NULL || backing->pixels == NULL) {
        return NULL;
    }

    size_t row_bytes = (size_t)backing->width * 4u;
    size_t byte_count = row_bytes * (size_t)backing->height;
    uint8_t* snapshot = (uint8_t*)malloc(byte_count);
    if (snapshot == NULL) {
        return NULL;
    }
    memcpy(snapshot, backing->pixels, byte_count);

    void* provider = renderer_darwin_api.cg_data_provider_create_with_data(
        NULL,
        snapshot,
        byte_count,
        renderer_release_image_data
    );
    if (provider == NULL) {
        free(snapshot);
        return NULL;
    }

    void* color_space = renderer_darwin_api.cg_color_space_create_device_rgb();
    if (color_space == NULL) {
        renderer_darwin_api.cg_data_provider_release(provider);
        return NULL;
    }

    // Match Skia: kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast
    const uint32_t bitmap_info = 0x4000u | 1u;
    void* image = renderer_darwin_api.cg_image_create(
        (size_t)backing->width,
        (size_t)backing->height,
        8u,
        32u,
        row_bytes,
        color_space,
        bitmap_info,
        provider,
        NULL,
        false,
        0
    );
    renderer_darwin_api.cg_color_space_release(color_space);
    renderer_darwin_api.cg_data_provider_release(provider);
    return image;
}

void renderer_present(native_window_t window, const uint8_t* pixels, int32_t width, int32_t height) {
    renderer_present_surface_rect(window, pixels, width, height, 0, 0, width, height);
}

void renderer_present_rect(
    native_window_t window,
    const uint8_t* pixels,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height
) {
    renderer_present_surface_rect(window, pixels, width, height, x, y, width, height);
}

static const char* renderer_sun_image_view_id = "moui_sun_pixel_image_view";

static renderer_objc_id renderer_find_or_create_image_view(renderer_objc_id view) {
    renderer_objc_id ns_view_class = renderer_darwin_api.objc_get_class("NSView");
    renderer_objc_id ns_image_view_class = renderer_darwin_api.objc_get_class("NSImageView");
    if (ns_view_class == NULL || ns_image_view_class == NULL) {
        return NULL;
    }

    // Check subviews for existing image view
    renderer_objc_id subviews = renderer_msg_id(view, "subviews");
    if (subviews != NULL) {
        renderer_objc_id ns_array_class = renderer_darwin_api.objc_get_class("NSArray");
        if (ns_array_class != NULL) {
            uintptr_t count = ((uintptr_t (*)(renderer_objc_id, renderer_objc_sel))
                renderer_darwin_api.objc_msg_send)(subviews, renderer_sel("count"));
            for (uintptr_t i = 0; i < count; i++) {
                renderer_objc_id subview = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel, uintptr_t))
                    renderer_darwin_api.objc_msg_send)(subviews, renderer_sel("objectAtIndex:"), i);
                if (subview == NULL) continue;

                renderer_objc_id identifier = renderer_msg_id(subview, "identifier");
                if (identifier != NULL) {
                    const char* ident_str = ((const char* (*)(renderer_objc_id, renderer_objc_sel))
                        renderer_darwin_api.objc_msg_send)(identifier, renderer_sel("UTF8String"));
                    if (ident_str != NULL && strcmp(ident_str, renderer_sun_image_view_id) == 0) {
                        return subview;
                    }
                }
            }
        }
    }

    // Use a passthrough NSImageView subclass whose hitTest: returns nil so
    // pointer events fall through to the content view (matching Skia).
    renderer_objc_class image_view_class = renderer_passthrough_image_view_class();
    if (image_view_class == NULL) {
        return NULL;
    }

    // Create new passthrough image view
    renderer_objc_id alloc_view = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel))
        renderer_darwin_api.objc_msg_send)(image_view_class, renderer_sel("alloc"));
    if (alloc_view == NULL) { return NULL; }

    // Get content view's bounds for initial size
    renderer_cgrect_t parent_frame = renderer_view_bounds(view);
    if (parent_frame.width <= 0.0) { parent_frame.width = 768.0; }
    if (parent_frame.height <= 0.0) { parent_frame.height = 512.0; }

    renderer_objc_id image_view = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel, renderer_cgrect_t))
        renderer_darwin_api.objc_msg_send)(
            alloc_view, renderer_sel("initWithFrame:"), parent_frame);
    if (image_view == NULL) { return NULL; }

    // Set identifier to find it later
    renderer_objc_id ns_string_class = renderer_darwin_api.objc_get_class("NSString");
    if (ns_string_class != NULL) {
        renderer_objc_id ident = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel, const char*))
            renderer_darwin_api.objc_msg_send)(
                ns_string_class, renderer_sel("stringWithUTF8String:"),
                renderer_sun_image_view_id);
        if (ident != NULL) {
            ((void (*)(renderer_objc_id, renderer_objc_sel, renderer_objc_id))
                renderer_darwin_api.objc_msg_send)(
                    image_view, renderer_sel("setIdentifier:"), ident);
        }
    }

    // Set imageScaling to NSImageScaleAxesIndependently (value = 1)
    ((void (*)(renderer_objc_id, renderer_objc_sel, uintptr_t))
        renderer_darwin_api.objc_msg_send)(
            image_view, renderer_sel("setImageScaling:"), (uintptr_t)1);

    // Set autoresizingMask so it fills parent on resize
    ((void (*)(renderer_objc_id, renderer_objc_sel, uintptr_t))
        renderer_darwin_api.objc_msg_send)(
            image_view, renderer_sel("setAutoresizingMask:"),
            (uintptr_t)(18u)); // NSViewWidthSizable | NSViewHeightSizable

    // Add as subview
    ((void (*)(renderer_objc_id, renderer_objc_sel, renderer_objc_id))
        renderer_darwin_api.objc_msg_send)(
            view, renderer_sel("addSubview:"), image_view);

    // Release the alloc reference (view now owns it)
    renderer_msg_void(image_view, "release");

    return image_view;
}

void renderer_present_surface_rect(
    native_window_t window,
    const uint8_t* pixels,
    int32_t surface_width,
    int32_t surface_height,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height
) {
    if (pixels == NULL || surface_width <= 0 || surface_height <= 0 || width <= 0 || height <= 0) {
        return;
    }

    renderer_objc_id view = renderer_content_view(window);
    if (view == NULL) { return; }

    // Find or create passthrough NSImageView subview (created once, reused)
    renderer_objc_id image_view = renderer_find_or_create_image_view(view);
    if (image_view == NULL) { return; }

    // Get content view bounds and window scale factor
    renderer_cgrect_t view_bounds = renderer_view_bounds(view);
    double scale = renderer_backing_scale_factor(view);

    if (view_bounds.width > 0.0 && view_bounds.height > 0.0) {
        ((void (*)(renderer_objc_id, renderer_objc_sel, renderer_cgrect_t))
            renderer_darwin_api.objc_msg_send)(
                image_view, renderer_sel("setFrame:"), view_bounds);
    }

    // Create CGImage from pixel data
    renderer_backing_t* backing = renderer_backing_for_view(view, surface_width, surface_height);
    if (backing == NULL) { return; }
    renderer_copy_rect_to_backing(backing, pixels, x, y, width, height);

    void* cg_image = renderer_create_cg_image(backing);
    if (cg_image == NULL) { return; }

    // Create NSImage using logical-point size (matching Skia presenter)
    renderer_objc_id ns_image_class = renderer_darwin_api.objc_get_class("NSImage");
    if (ns_image_class != NULL) {
        renderer_objc_id ns_image_alloc = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel))
            renderer_darwin_api.objc_msg_send)(ns_image_class, renderer_sel("alloc"));
        if (ns_image_alloc != NULL) {
            // NSImage size must be in points (logical size), not physical pixels.
            // Skia uses view.bounds; we do the same, falling back to physical
            // pixels divided by the backing scale factor when bounds are empty.
            double point_w, point_h;
            if (view_bounds.width > 0.0 && view_bounds.height > 0.0) {
                point_w = view_bounds.width;
                point_h = view_bounds.height;
            } else {
                point_w = (double)surface_width / scale;
                point_h = (double)surface_height / scale;
            }


            // initWithCGImage:size: takes (CGImageRef, NSSize). NSSize = two doubles on arm64.
            renderer_objc_id ns_image = ((renderer_objc_id (*)(renderer_objc_id, renderer_objc_sel, void*, double, double))
                renderer_darwin_api.objc_msg_send)(
                    ns_image_alloc, renderer_sel("initWithCGImage:size:"),
                    cg_image, point_w, point_h);
            if (ns_image != NULL) {
                ((void (*)(renderer_objc_id, renderer_objc_sel, renderer_objc_id))
                    renderer_darwin_api.objc_msg_send)(
                        image_view, renderer_sel("setImage:"), ns_image);
                ((void (*)(renderer_objc_id, renderer_objc_sel, intptr_t))
                    renderer_darwin_api.objc_msg_send)(
                        image_view, renderer_sel("setNeedsDisplay:"), (intptr_t)1);
                renderer_msg_void(ns_image, "release");
            }
        }
    }

    renderer_darwin_api.cg_image_release(cg_image);
}

#else
// ============================================================================
// Stub Implementation for platforms without a native softbuffer backend
// ============================================================================

void renderer_present(native_window_t window, const uint8_t* pixels, int32_t width, int32_t height) {
    (void)window;
    (void)pixels;
    (void)width;
    (void)height;
}

void renderer_present_rect(
    native_window_t window,
    const uint8_t* pixels,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height
) {
    (void)window;
    (void)pixels;
    (void)x;
    (void)y;
    (void)width;
    (void)height;
}

void renderer_present_surface_rect(
    native_window_t window,
    const uint8_t* pixels,
    int32_t surface_width,
    int32_t surface_height,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height
) {
    (void)window;
    (void)pixels;
    (void)surface_width;
    (void)surface_height;
    (void)x;
    (void)y;
    (void)width;
    (void)height;
}

int32_t renderer_macos_presenter_passthrough_ready(void) {
    return 0;
}

#endif
