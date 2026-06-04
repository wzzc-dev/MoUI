///|
/// Renderer-owned resource families that commonly need backend caches.
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
  GpuContextResource
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
  self is (GpuContextResource | GpuSurfaceResource)
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
pub fn RendererResourceKey::gpu_context(id : Bytes) -> RendererResourceKey {
  RendererResourceKey::new(GpuContextResource, id)
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
