///|
fn visual_vertices_to_bytes(vertices : Array[VisualVertex]) -> Bytes {
  let out : Array[Byte] = []
  for vertex in vertices {
    push_visual_f32le(out, vertex.x)
    push_visual_f32le(out, vertex.y)
    push_visual_f32le(out, vertex.local_x)
    push_visual_f32le(out, vertex.local_y)
    push_visual_f32le(out, vertex.width)
    push_visual_f32le(out, vertex.height)
    push_visual_f32le(out, vertex.radius)
    push_visual_f32le(out, vertex.mode)
    push_visual_f32le(out, vertex.stroke_width)
    push_visual_f32le(out, vertex.blur_radius)
    push_visual_f32le(out, vertex.start_x)
    push_visual_f32le(out, vertex.start_y)
    push_visual_f32le(out, vertex.end_x)
    push_visual_f32le(out, vertex.end_y)
    push_visual_f32le(out, vertex.r0)
    push_visual_f32le(out, vertex.g0)
    push_visual_f32le(out, vertex.b0)
    push_visual_f32le(out, vertex.a0)
    push_visual_f32le(out, vertex.r1)
    push_visual_f32le(out, vertex.g1)
    push_visual_f32le(out, vertex.b1)
    push_visual_f32le(out, vertex.a1)
  }
  Bytes::from_array(out)
}

///|
fn advanced_vertices_to_bytes(vertices : Array[AdvancedVertex]) -> Bytes {
  let out : Array[Byte] = []
  for vertex in vertices {
    push_visual_f32le(out, vertex.x)
    push_visual_f32le(out, vertex.y)
    push_visual_f32le(out, vertex.u)
    push_visual_f32le(out, vertex.v)
    push_visual_f32le(out, vertex.opacity)
    push_visual_f32le(out, vertex.blend_mode)
    push_visual_f32le(out, vertex.shader_kind)
    push_visual_f32le(out, vertex.effect_amount)
    push_visual_f32le(out, vertex.local_x)
    push_visual_f32le(out, vertex.local_y)
    push_visual_f32le(out, vertex.filter_kind)
    push_visual_f32le(out, vertex.filter_amount)
    push_visual_f32le(out, vertex.r0)
    push_visual_f32le(out, vertex.g0)
    push_visual_f32le(out, vertex.b0)
    push_visual_f32le(out, vertex.a0)
    push_visual_f32le(out, vertex.r1)
    push_visual_f32le(out, vertex.g1)
    push_visual_f32le(out, vertex.b1)
    push_visual_f32le(out, vertex.a1)
    push_advanced_matrix_f32le(out, vertex.matrix)
    push_visual_f32le(out, vertex.rect_width)
    push_visual_f32le(out, vertex.rect_height)
    push_visual_f32le(out, vertex.mask_radius)
    push_visual_f32le(out, vertex.mask_kind)
  }
  Bytes::from_array(out)
}

///|
fn push_advanced_matrix_f32le(
  out : Array[Byte],
  values : Array[Double],
) -> Unit {
  let identity = native_identity_color_matrix()
  for index in 0..<20 {
    match values.get(index) {
      Some(value) => push_visual_f32le(out, value)
      None => push_visual_f32le(out, identity[index])
    }
  }
}

///|
fn push_visual_f32le(out : Array[Byte], value : Double) -> Unit {
  let bits : UInt = Float::from_double(value)
    .reinterpret_as_int()
    .reinterpret_as_uint()
  out.push((bits & 0xFF).to_byte())
  out.push(((bits >> 8) & 0xFF).to_byte())
  out.push(((bits >> 16) & 0xFF).to_byte())
  out.push(((bits >> 24) & 0xFF).to_byte())
}

///|
fn visual_pixel_x_to_ndc(x : Double, width : Double) -> Double {
  if width <= 0.0 {
    -1.0
  } else {
    x / width * 2.0 - 1.0
  }
}

///|
fn visual_pixel_y_to_ndc(y : Double, height : Double) -> Double {
  if height <= 0.0 {
    1.0
  } else {
    1.0 - y / height * 2.0
  }
}
