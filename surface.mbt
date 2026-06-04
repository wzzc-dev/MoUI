///|
/// Rendering target family for a surface descriptor.
pub(all) enum SurfaceBackend {
  Raster
  Window
  Gpu
} derive(Debug, Eq)

///|
pub impl Default for SurfaceBackend with fn default() {
  Raster
}

///|
pub fn SurfaceBackend::is_raster(self : SurfaceBackend) -> Bool {
  self is Raster
}

///|
pub fn SurfaceBackend::is_window(self : SurfaceBackend) -> Bool {
  self is Window
}

///|
pub fn SurfaceBackend::is_gpu(self : SurfaceBackend) -> Bool {
  self is Gpu
}

///|
pub fn SurfaceBackend::is_presentable(self : SurfaceBackend) -> Bool {
  self is Window || self is Gpu
}

///|
/// Pixel origin used by a render target.
pub(all) enum SurfaceOrigin {
  TopLeft
  BottomLeft
} derive(Debug, Eq)

///|
pub impl Default for SurfaceOrigin with fn default() {
  TopLeft
}

///|
/// Whether a surface should count against an implementation resource budget.
pub(all) enum SurfaceBudget {
  Budgeted
  Unbudgeted
} derive(Debug, Eq)

///|
pub impl Default for SurfaceBudget with fn default() {
  Unbudgeted
}

///|
pub fn SurfaceBudget::is_budgeted(self : SurfaceBudget) -> Bool {
  self is Budgeted
}

///|
/// Stable value-layer contract for raster, window, and future GPU surfaces.
pub(all) struct SurfaceDescriptor {
  backend : SurfaceBackend
  image_info : ImageInfo
  origin : SurfaceOrigin
  sample_count : Int
  stencil_bits : Int
  budget : SurfaceBudget
} derive(Debug, Eq)

///|
pub fn SurfaceDescriptor::new(
  backend : SurfaceBackend,
  image_info : ImageInfo,
  origin? : SurfaceOrigin = TopLeft,
  sample_count? : Int = 1,
  stencil_bits? : Int = 0,
  budget? : SurfaceBudget = Unbudgeted,
) -> SurfaceDescriptor {
  {
    backend,
    image_info,
    origin,
    sample_count: Int::max(1, sample_count),
    stencil_bits: Int::max(0, stencil_bits),
    budget,
  }
}

///|
pub fn SurfaceDescriptor::raster_n32_premul(size : ISize) -> SurfaceDescriptor {
  SurfaceDescriptor::new(Raster, ImageInfo::n32_premul(size))
}

///|
pub fn SurfaceDescriptor::window_n32_premul(
  size : ISize,
  origin? : SurfaceOrigin = TopLeft,
  sample_count? : Int = 1,
  stencil_bits? : Int = 0,
) -> SurfaceDescriptor {
  SurfaceDescriptor::new(
    Window,
    ImageInfo::n32_premul(size),
    origin~,
    sample_count~,
    stencil_bits~,
  )
}

///|
pub fn SurfaceDescriptor::gpu_n32_premul(
  size : ISize,
  origin? : SurfaceOrigin = TopLeft,
  sample_count? : Int = 1,
  stencil_bits? : Int = 0,
  budget? : SurfaceBudget = Budgeted,
) -> SurfaceDescriptor {
  SurfaceDescriptor::new(
    Gpu,
    ImageInfo::n32_premul(size),
    origin~,
    sample_count~,
    stencil_bits~,
    budget~,
  )
}

///|
pub fn SurfaceDescriptor::dimensions(self : SurfaceDescriptor) -> ISize {
  self.image_info.dimensions
}

///|
pub fn SurfaceDescriptor::width(self : SurfaceDescriptor) -> Int {
  self.image_info.width()
}

///|
pub fn SurfaceDescriptor::height(self : SurfaceDescriptor) -> Int {
  self.image_info.height()
}

///|
pub fn SurfaceDescriptor::bounds(self : SurfaceDescriptor) -> IRect {
  self.image_info.bounds()
}

///|
pub fn SurfaceDescriptor::is_empty(self : SurfaceDescriptor) -> Bool {
  self.image_info.is_empty()
}

///|
pub fn SurfaceDescriptor::is_raster(self : SurfaceDescriptor) -> Bool {
  self.backend.is_raster()
}

///|
pub fn SurfaceDescriptor::is_window(self : SurfaceDescriptor) -> Bool {
  self.backend.is_window()
}

///|
pub fn SurfaceDescriptor::is_gpu(self : SurfaceDescriptor) -> Bool {
  self.backend.is_gpu()
}

///|
pub fn SurfaceDescriptor::is_presentable(self : SurfaceDescriptor) -> Bool {
  self.backend.is_presentable() && !self.is_empty()
}

///|
pub fn SurfaceDescriptor::is_msaa(self : SurfaceDescriptor) -> Bool {
  self.sample_count > 1
}

///|
pub fn SurfaceDescriptor::is_budgeted(self : SurfaceDescriptor) -> Bool {
  self.budget.is_budgeted()
}

///|
pub fn SurfaceDescriptor::with_backend(
  self : SurfaceDescriptor,
  backend : SurfaceBackend,
) -> SurfaceDescriptor {
  { ..self, backend, }
}

///|
pub fn SurfaceDescriptor::with_image_info(
  self : SurfaceDescriptor,
  image_info : ImageInfo,
) -> SurfaceDescriptor {
  { ..self, image_info, }
}

///|
pub fn SurfaceDescriptor::with_dimensions(
  self : SurfaceDescriptor,
  dimensions : ISize,
) -> SurfaceDescriptor {
  self.with_image_info(self.image_info.with_dimensions(dimensions))
}

///|
pub fn SurfaceDescriptor::with_origin(
  self : SurfaceDescriptor,
  origin : SurfaceOrigin,
) -> SurfaceDescriptor {
  { ..self, origin, }
}

///|
pub fn SurfaceDescriptor::with_sample_count(
  self : SurfaceDescriptor,
  sample_count : Int,
) -> SurfaceDescriptor {
  { ..self, sample_count: Int::max(1, sample_count) }
}

///|
pub fn SurfaceDescriptor::with_stencil_bits(
  self : SurfaceDescriptor,
  stencil_bits : Int,
) -> SurfaceDescriptor {
  { ..self, stencil_bits: Int::max(0, stencil_bits) }
}

///|
pub fn SurfaceDescriptor::with_budget(
  self : SurfaceDescriptor,
  budget : SurfaceBudget,
) -> SurfaceDescriptor {
  { ..self, budget, }
}
