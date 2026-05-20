///|
struct ImageVertex {
  x : Double
  y : Double
  u : Double
  v : Double
}

///|
struct ImageUVResult {
  u0 : Double
  v0 : Double
  u1 : Double
  v1 : Double
}

///|
fn calculate_image_uv(
  image_size : @core.Size,
  frame_size : @core.Size,
  fit : @core.ImageFit,
) -> ImageUVResult {
  let image_ratio = image_size.width / image_size.height
  let frame_ratio = frame_size.width / frame_size.height

  match fit {
    @core.ImageFit::Contain => {
      if image_ratio > frame_ratio {
        // Image is wider than frame relative to height
        let scale = frame_size.width / image_size.width
        let scaled_height = image_size.height * scale
        let offset_y = (frame_size.height - scaled_height) / 2.0
        {
          u0: 0.0,
          v0: offset_y / frame_size.height,
          u1: 1.0,
          v1: (offset_y + scaled_height) / frame_size.height,
        }
      } else {
        // Image is taller than frame relative to width
        let scale = frame_size.height / image_size.height
        let scaled_width = image_size.width * scale
        let offset_x = (frame_size.width - scaled_width) / 2.0
        {
          u0: offset_x / frame_size.width,
          v0: 0.0,
          u1: (offset_x + scaled_width) / frame_size.width,
          v1: 1.0,
        }
      }
    }
    @core.ImageFit::Cover => {
      if image_ratio > frame_ratio {
        // Image is wider than frame relative to height
        let scale = frame_size.height / image_size.height
        let scaled_width = image_size.width * scale
        let offset_x = (scaled_width - frame_size.width) / 2.0
        {
          u0: offset_x / scaled_width,
          v0: 0.0,
          u1: (offset_x + frame_size.width) / scaled_width,
          v1: 1.0,
        }
      } else {
        // Image is taller than frame relative to width
        let scale = frame_size.width / image_size.width
        let scaled_height = image_size.height * scale
        let offset_y = (scaled_height - frame_size.height) / 2.0
        {
          u0: 0.0,
          v0: offset_y / scaled_height,
          u1: 1.0,
          v1: (offset_y + frame_size.height) / scaled_height,
        }
      }
    }
  }
}

///|
fn generate_image_vertices(
  frame : @core.Rect,
  u0 : Double,
  v0 : Double,
  u1 : Double,
  v1 : Double,
  _screen_size : @core.Size,
) -> Array[ImageVertex] {
  let x0 = frame.origin.x
  let y0 = frame.origin.y
  let x1 = frame.origin.x + frame.size.width
  let y1 = frame.origin.y + frame.size.height

  let vertices : Array[ImageVertex] = []

  // Triangle strip: v0, v1, v2, v0, v2, v3
  // Or two triangles: (v0, v1, v2) and (v0, v2, v3)
  vertices.push({ x: x0, y: y0, u: u0, v: v0 })
  vertices.push({ x: x0, y: y1, u: u0, v: v1 })
  vertices.push({ x: x1, y: y1, u: u1, v: v1 })
  vertices.push({ x: x0, y: y0, u: u0, v: v0 })
  vertices.push({ x: x1, y: y1, u: u1, v: v1 })
  vertices.push({ x: x1, y: y0, u: u1, v: v0 })

  vertices
}
