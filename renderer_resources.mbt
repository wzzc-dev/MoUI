///|
/// Renderer-owned resource families that commonly need backend caches.
#warnings("-deprecated_syntax")
pub(all) enum RendererResourceKind {
  ImageResource
  ShaderResource
  ColorFilterResource
  ImageFilterResource
  MaskFilterResource
  TypefaceResource
  FontResource
  PathResource
  TextRunResource
  SurfaceResource
  GpuSurfaceResource
} derive(Debug, Eq, Hash)

///|
pub fn RendererResourceKind::is_filter(self : RendererResourceKind) -> Bool {
  self is (ColorFilterResource | ImageFilterResource | MaskFilterResource)
}

///|
pub fn RendererResourceKind::is_text(self : RendererResourceKind) -> Bool {
  self is (TypefaceResource | FontResource | TextRunResource)
}

///|
pub fn RendererResourceKind::is_gpu_backed(self : RendererResourceKind) -> Bool {
  self is GpuSurfaceResource
}

///|
pub fn RendererResourceKind::is_surface(self : RendererResourceKind) -> Bool {
  self is (SurfaceResource | GpuSurfaceResource)
}

///|
/// Stable key for renderer-owned resources. The `id` is intentionally bytes so
/// callers can use hashes, URLs, font family bytes, or serialized descriptors.
pub(all) struct RendererResourceKey {
  kind : RendererResourceKind
  id : Bytes
} derive(Debug, Eq, Hash)

///|
pub fn RendererResourceKey::new(
  kind : RendererResourceKind,
  id : Bytes,
) -> RendererResourceKey {
  { kind, id }
}

///|
pub fn RendererResourceKey::image(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(ImageResource, id)
}

///|
pub fn RendererResourceKey::shader(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(ShaderResource, id)
}

///|
pub fn RendererResourceKey::color_filter(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(ColorFilterResource, id)
}

///|
pub fn RendererResourceKey::image_filter(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(ImageFilterResource, id)
}

///|
pub fn RendererResourceKey::mask_filter(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(MaskFilterResource, id)
}

///|
pub fn RendererResourceKey::typeface(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(TypefaceResource, id)
}

///|
pub fn RendererResourceKey::font(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(FontResource, id)
}

///|
pub fn RendererResourceKey::path(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(PathResource, id)
}

///|
pub fn RendererResourceKey::text_run(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(TextRunResource, id)
}

///|
pub fn RendererResourceKey::surface(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(SurfaceResource, id)
}

///|
pub fn RendererResourceKey::gpu_surface(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(GpuSurfaceResource, id)
}

///|
pub fn RendererResourceKey::is_empty(self : RendererResourceKey) -> Bool {
  self.id.is_empty()
}

///|
pub fn RendererResourceKey::is_gpu_backed(self : RendererResourceKey) -> Bool {
  self.kind.is_gpu_backed()
}

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
pub fn RendererResourceDescriptor::filter(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(ImageFilterResource, id, byte_size~)
}

///|
pub fn RendererResourceDescriptor::typeface(
  id : Bytes,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::of_kind(TypefaceResource, id, byte_size~)
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
