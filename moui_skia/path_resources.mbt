///|
fn path_resource_u64(value : Int) -> Bytes {
  Int::max(0, value).to_uint64().to_be_bytes()
}

///|
fn path_resource_bytes(value : Bytes) -> Bytes {
  value.length().to_uint64().to_be_bytes() + value
}

///|
fn PathFillType::resource_name(self : PathFillType) -> Bytes {
  match self {
    Winding => b"winding"
    EvenOdd => b"even-odd"
    InverseWinding => b"inverse-winding"
    InverseEvenOdd => b"inverse-even-odd"
  }
}

///|
fn Point::path_resource_id(self : Point) -> Bytes {
  self.x.to_be_bytes() + self.y.to_be_bytes()
}

///|
fn PathVerb::resource_id(self : PathVerb) -> Bytes {
  match self {
    MoveTo(point) => b"M" + point.path_resource_id()
    LineTo(point) => b"L" + point.path_resource_id()
    QuadTo(control, end) =>
      b"Q" + control.path_resource_id() + end.path_resource_id()
    ConicTo(control, end, weight) =>
      b"C" +
      control.path_resource_id() +
      end.path_resource_id() +
      weight.to_be_bytes()
    CubicTo(control0, control1, end) =>
      b"U" +
      control0.path_resource_id() +
      control1.path_resource_id() +
      end.path_resource_id()
    Close => b"Z"
  }
}

///|
fn Path::resource_id(self : Path) -> Bytes {
  if self.is_empty() || !self.is_finite() {
    b""
  } else {
    let mut id = b"moui_skia:path:v1" +
      path_resource_bytes(self.fill_type.resource_name()) +
      path_resource_u64(self.verbs.length())
    for verb in self.verbs {
      id = id + path_resource_bytes(verb.resource_id())
    }
    id
  }
}

///|
pub fn Path::resource_key(self : Path) -> RendererResourceKey {
  RendererResourceKey::path(self.resource_id())
}

///|
pub fn Path::resource_descriptor(
  self : Path,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id()
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::path(id, byte_size=measured_byte_size)
}
