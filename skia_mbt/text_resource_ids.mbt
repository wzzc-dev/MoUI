///|
fn text_run_cache_u64(value : Int) -> Bytes {
  Int::max(0, value).to_uint64().to_be_bytes()
}

///|
fn text_run_cache_bytes(value : Bytes) -> Bytes {
  value.length().to_uint64().to_be_bytes() + value
}

///|
fn text_run_cache_bool(value : Bool) -> Bytes {
  if value {
    b"true"
  } else {
    b"false"
  }
}

///|
fn RendererResourceKind::text_run_cache_name(
  self : RendererResourceKind,
) -> Bytes {
  match self {
    ImageResource => b"image"
    ShaderResource => b"shader"
    ColorFilterResource => b"color-filter"
    ImageFilterResource => b"image-filter"
    MaskFilterResource => b"mask-filter"
    TypefaceResource => b"typeface"
    FontResource => b"font"
    PathResource => b"path"
    TextRunResource => b"text-run"
    SurfaceResource => b"surface"
    GpuContextResource => b"gpu-context"
    GpuSurfaceResource => b"gpu-surface"
  }
}

///|
fn RendererResourceKey::text_run_cache_id(self : RendererResourceKey) -> Bytes {
  text_run_cache_bytes(self.kind.text_run_cache_name()) +
  text_run_cache_bytes(self.id)
}

///|
fn TextDirection::text_run_cache_id(self : TextDirection) -> Bytes {
  match self {
    LeftToRight => b"ltr"
    RightToLeft => b"rtl"
  }
}

///|
fn FontStyleRequest::text_run_cache_id(self : FontStyleRequest) -> Bytes {
  text_run_cache_u64(self.weight) +
  text_run_cache_u64(self.width) +
  text_run_cache_u64(self.slant)
}
