///|
extern "C" fn win32_is_window(hwnd : UInt64) -> Int32 = "IsWindow"

///|
extern "C" fn win32_get_dc(hwnd : UInt64) -> UInt64 = "GetDC"

///|
extern "C" fn win32_release_dc(hwnd : UInt64, dc : UInt64) -> Int32 = "ReleaseDC"

///|
#borrow(bits, bitmap_info)
extern "C" fn win32_stretch_dibits(
  dc : UInt64,
  x_dest : Int32,
  y_dest : Int32,
  dest_width : Int32,
  dest_height : Int32,
  x_src : Int32,
  y_src : Int32,
  src_width : Int32,
  src_height : Int32,
  bits : Bytes,
  bitmap_info : Bytes,
  usage : UInt32,
  raster_op : UInt32,
) -> Int32 = "StretchDIBits"

///|
let dib_rgb_colors : UInt32 = 0

///|
let srccopy : UInt32 = 0x00cc0020

///|
let gdi_error = -1

///|
let present_trace_logged : Array[Bool] = [false]

///|
fn uint32_le_byte(value : UInt32, index : Int32) -> Byte {
  ((value >> (index * 8)) & 0xff).to_byte()
}

///|
fn int32_le_byte(value : Int32, index : Int32) -> Byte {
  uint32_le_byte(value.reinterpret_as_uint(), index)
}

///|
fn bitmap_info_byte(width : Int32, height : Int32, index : Int32) -> Byte {
  if index < 4 {
    int32_le_byte(40, index)
  } else if index < 8 {
    int32_le_byte(width, index - 4)
  } else if index < 12 {
    int32_le_byte(-height, index - 8)
  } else if index < 14 {
    int32_le_byte(1, index - 12)
  } else if index < 16 {
    int32_le_byte(32, index - 14)
  } else {
    0
  }
}

///|
fn make_bitmap_info(width : Int32, height : Int32) -> Bytes {
  Bytes::makei(44, index => bitmap_info_byte(width, height, index))
}

///|
fn bgra_dib_byte(
  width : Int32,
  row_bytes : Int32,
  pixels : Bytes,
  index : Int32,
) -> Byte {
  let pixel_index = index / 4
  let channel = index % 4
  let x = pixel_index % width
  let y = pixel_index / width
  let src = y * row_bytes + x * 4
  match channel {
    0 => pixels[src + 2]
    1 => pixels[src + 1]
    2 => pixels[src]
    _ => pixels[src + 3]
  }
}

///|
fn make_bgra_dib_pixels(
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
) -> Bytes {
  Bytes::makei(width * height * 4, index => {
    bgra_dib_byte(width, row_bytes, pixels, index)
  })
}

///|
fn trace_present(
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
) -> Unit {
  if present_trace_logged[0] {
    return
  }
  match @env.get_env_var("MOUI_SKIA_TEXT_TRACE") {
    Some(trace) if trace != "" => {
      present_trace_logged[0] = true
      let sample_x = width / 2
      let sample_y = height / 2
      let sample = sample_y * row_bytes + sample_x * 4
      println(
        "skia text present: \{width}x\{height} sample=\{pixels[sample].to_int()},\{pixels[sample + 1].to_int()},\{pixels[sample + 2].to_int()},\{pixels[sample + 3].to_int()}",
      )
    }
    _ => ()
  }
}

///|
fn present_rgba_to_window(
  hwnd : UInt64,
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
) -> Int32 {
  if hwnd == 0 || win32_is_window(hwnd) == 0 {
    return 1
  }
  if width <= 0 || height <= 0 || width > 0x1fffffff {
    return 2
  }
  let min_row_bytes = width * 4
  if row_bytes < min_row_bytes {
    return 2
  }
  if row_bytes <= 0 || height > pixels.length() / row_bytes {
    return 3
  }
  if height > 0x1fffffff / width {
    return 6
  }

  let dib_pixels = make_bgra_dib_pixels(width, height, row_bytes, pixels)
  let bitmap_info = make_bitmap_info(width, height)
  trace_present(width, height, row_bytes, pixels)

  let dc = win32_get_dc(hwnd)
  if dc == 0 {
    return 4
  }
  let result = win32_stretch_dibits(
    dc, 0, 0, width, height, 0, 0, width, height, dib_pixels, bitmap_info, dib_rgb_colors,
    srccopy,
  )
  ignore(win32_release_dc(hwnd, dc))
  if result == gdi_error {
    5
  } else {
    0
  }
}
