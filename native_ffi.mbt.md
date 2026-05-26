# Native FFI Sketch

This file documents the MoonBit side of the first native package. The checked
implementation lives in `native/skia_native.mbt`; this sketch keeps the intended
FFI boundary visible without requiring Skia headers in documentation tests.

```mbt nocheck
///|
#external
type NativeSurface

///|
#external
type NativeCanvas

///|
#external
type NativeData

///|
#external
type NativeImage

///|
#external
type NativePath

///|
priv extern "C" fn native_path_new() -> NativePath = "moonbit_skia_path_new"

///|
#borrow(path)
priv extern "C" fn native_path_move_to(
  path : NativePath,
  x : Float,
  y : Float,
) -> Unit = "moonbit_skia_path_move_to"

///|
#borrow(data)
priv extern "C" fn native_data_to_bytes(data : NativeData) -> Bytes = "moonbit_skia_data_to_bytes"

///|
#borrow(bytes)
priv extern "C" fn native_data_from_bytes(bytes : Bytes) -> NativeData = "moonbit_skia_data_from_bytes"

///|
#borrow(image)
priv extern "C" fn native_image_encode_to_data(
  image : NativeImage,
  format : Int,
  quality : Int,
) -> NativeData = "moonbit_skia_image_encode_to_data"

///|
#borrow(data)
priv extern "C" fn native_image_from_encoded_data(
  data : NativeData,
) -> NativeImage = "moonbit_skia_image_from_encoded_data"

///|
priv extern "C" fn native_surface_raster_n32_premul(
  width : Int,
  height : Int,
) -> NativeSurface = "moonbit_skia_surface_raster_n32_premul"

///|
#borrow(surface)
priv extern "C" fn native_surface_width(surface : NativeSurface) -> Int = "moonbit_skia_surface_width"

///|
#borrow(surface)
priv extern "C" fn native_surface_height(surface : NativeSurface) -> Int = "moonbit_skia_surface_height"

///|
#borrow(surface)
priv extern "C" fn native_surface_canvas(
  surface : NativeSurface,
) -> NativeCanvas = "moonbit_skia_surface_canvas"

///|
#borrow(surface)
priv extern "C" fn native_surface_image_snapshot(
  surface : NativeSurface,
) -> NativeImage = "moonbit_skia_surface_image_snapshot"

///|
#borrow(surface)
priv extern "C" fn native_surface_image_snapshot_with_bounds(
  surface : NativeSurface,
  left : Int,
  top : Int,
  right : Int,
  bottom : Int,
) -> NativeImage = "moonbit_skia_surface_image_snapshot_with_bounds"

///|
#borrow(canvas)
priv extern "C" fn native_canvas_save(canvas : NativeCanvas) -> Int = "moonbit_skia_canvas_save"

///|
#borrow(canvas)
priv extern "C" fn native_canvas_translate(
  canvas : NativeCanvas,
  dx : Float,
  dy : Float,
) -> Unit = "moonbit_skia_canvas_translate"

///|
#borrow(canvas)
priv extern "C" fn native_canvas_concat(
  canvas : NativeCanvas,
  scale_x : Float,
  skew_x : Float,
  trans_x : Float,
  skew_y : Float,
  scale_y : Float,
  trans_y : Float,
  persp_0 : Float,
  persp_1 : Float,
  persp_2 : Float,
) -> Unit = "moonbit_skia_canvas_concat"

///|
#borrow(canvas)
priv extern "C" fn native_canvas_clip_rect(
  canvas : NativeCanvas,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  op : Int,
  anti_alias : Bool,
) -> Unit = "moonbit_skia_canvas_clip_rect"

///|
#borrow(canvas)
priv extern "C" fn native_canvas_draw_rect(
  canvas : NativeCanvas,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_rect"

///|
#borrow(canvas)
priv extern "C" fn native_canvas_draw_round_rect(
  canvas : NativeCanvas,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  rx : Float,
  ry : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_round_rect"

///|
#borrow(canvas, path)
priv extern "C" fn native_canvas_draw_path(
  canvas : NativeCanvas,
  path : NativePath,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_path"

///|
#borrow(canvas, image)
priv extern "C" fn native_canvas_draw_image(
  canvas : NativeCanvas,
  image : NativeImage,
  x : Float,
  y : Float,
) -> Unit = "moonbit_skia_canvas_draw_image"

///|
#borrow(canvas, image)
priv extern "C" fn native_canvas_draw_image_rect(
  canvas : NativeCanvas,
  image : NativeImage,
  src_left : Float,
  src_top : Float,
  src_right : Float,
  src_bottom : Float,
  dst_left : Float,
  dst_top : Float,
  dst_right : Float,
  dst_bottom : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_image_rect"
```

The matching C++ stub should include `moonbit.h`, allocate MoonBit external
objects for owning Skia ref-counted handles, and release the underlying Skia
object in the finalizer.
