///|
/// Portable image recipes that can be planned before native Skia images are
/// decoded or uploaded.
#warnings("-deprecated_syntax")
pub(all) enum ImageDescriptor {
  EncodedImage(Bytes, EncodedImageFormat?, ISize?)
} derive(Debug, Eq)

///|
fn image_descriptor_resource_u64(value : Int) -> Bytes {
  Int::max(0, value).to_uint64().to_be_bytes()
}

///|
fn image_descriptor_resource_bytes(value : Bytes) -> Bytes {
  value.length().to_uint64().to_be_bytes() + value
}

///|
fn image_descriptor_optional_format_id(format : EncodedImageFormat?) -> Bytes {
  match format {
    None => b"\x00"
    Some(format) =>
      b"\x01" + image_descriptor_resource_u64(format.to_skia_ordinal())
  }
}

///|
fn image_descriptor_optional_size_id(dimensions : ISize?) -> Bytes {
  match dimensions {
    None => b"\x00"
    Some(dimensions) =>
      b"\x01" +
      image_descriptor_resource_u64(dimensions.width) +
      image_descriptor_resource_u64(dimensions.height)
  }
}

///|
pub fn ImageDescriptor::encoded(
  bytes : Bytes,
  format? : EncodedImageFormat? = None,
  dimensions? : ISize? = None,
) -> ImageDescriptor? {
  if bytes.is_empty() {
    None
  } else {
    let normalized_dimensions : ISize? = match dimensions {
      None => None
      Some(dimensions) =>
        if dimensions.is_empty() {
          None
        } else {
          Some(dimensions)
        }
    }
    Some(
      EncodedImage(
        Bytes::from_array(bytes.to_array()),
        format,
        normalized_dimensions,
      ),
    )
  }
}

///|
pub fn ImageDescriptor::encoded_bytes(self : ImageDescriptor) -> Bytes {
  match self {
    EncodedImage(bytes, _, _) => Bytes::from_array(bytes.to_array())
  }
}

///|
pub fn ImageDescriptor::dimensions(self : ImageDescriptor) -> ISize? {
  match self {
    EncodedImage(_, _, dimensions) => dimensions
  }
}

///|
pub fn ImageDescriptor::byte_size(self : ImageDescriptor) -> Int64 {
  match self {
    EncodedImage(bytes, _, _) => bytes.length().to_int64()
  }
}

///|
fn ImageDescriptor::resource_id(self : ImageDescriptor) -> Bytes {
  match self {
    EncodedImage(bytes, format, dimensions) =>
      b"skia_mbt:image:v1" +
      image_descriptor_resource_bytes(b"encoded") +
      image_descriptor_optional_format_id(format) +
      image_descriptor_optional_size_id(dimensions) +
      image_descriptor_resource_bytes(bytes)
  }
}

///|
pub fn ImageDescriptor::resource_key(
  self : ImageDescriptor,
) -> RendererResourceKey {
  RendererResourceKey::image(self.resource_id())
}

///|
pub fn ImageDescriptor::resource_descriptor(
  self : ImageDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id()
  let measured_byte_size = if byte_size < 0L {
    self.byte_size()
  } else {
    byte_size
  }
  RendererResourceDescriptor::image(id, byte_size=measured_byte_size)
}
