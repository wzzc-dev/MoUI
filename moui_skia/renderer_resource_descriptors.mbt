///|
fn renderer_resource_non_negative_i64(value : Int64) -> Int64 {
  if value < 0L {
    0L
  } else {
    value
  }
}

///|
/// Cache metadata for one backend resource. Empty keys are automatically marked
/// non-cacheable so anonymous one-shot resources do not collide in an LRU map.
pub(all) struct RendererResourceDescriptor {
  key : RendererResourceKey
  byte_size : Int64
  cacheable : Bool
} derive(Debug, Eq)

///|
pub fn RendererResourceDescriptor::new(
  key : RendererResourceKey,
  byte_size? : Int64 = 0L,
  cacheable? : Bool = true,
) -> RendererResourceDescriptor {
  {
    key,
    byte_size: renderer_resource_non_negative_i64(byte_size),
    cacheable: cacheable && !key.is_empty(),
  }
}

///|
pub fn RendererResourceDescriptor::of_kind(
  kind : RendererResourceKind,
  id : Bytes,
  byte_size? : Int64 = 0L,
  cacheable? : Bool = true,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::new(
    RendererResourceKey::new(kind, id),
    byte_size~,
    cacheable~,
  )
}

///|
pub fn RendererResourceDescriptor::image(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(ImageResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::shader(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(ShaderResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::color_filter(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(ColorFilterResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::image_filter(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(ImageFilterResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::mask_filter(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(MaskFilterResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::filter(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::image_filter(id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::typeface(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(TypefaceResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::font(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(FontResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::path(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(PathResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::text_run(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(TextRunResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::surface(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(SurfaceResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::gpu_context(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(GpuContextResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::gpu_surface(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(GpuSurfaceResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::is_cacheable(
  self : RendererResourceDescriptor,
) -> Bool {
  self.cacheable
}

///|
pub fn RendererResourceDescriptor::is_gpu_backed(
  self : RendererResourceDescriptor,
) -> Bool {
  self.key.is_gpu_backed()
}

///|
pub fn RendererResourceDescriptor::with_byte_size(
  self : RendererResourceDescriptor,
  byte_size : Int64,
) -> RendererResourceDescriptor {
  { ..self, byte_size: renderer_resource_non_negative_i64(byte_size) }
}

///|
pub fn RendererResourceDescriptor::uncacheable(
  self : RendererResourceDescriptor,
) -> RendererResourceDescriptor {
  { ..self, cacheable: false }
}
