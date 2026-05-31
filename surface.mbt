///|
/// Rendering target family for a surface descriptor.
#warnings("-deprecated_syntax")
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
#warnings("-deprecated_syntax")
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
#warnings("-deprecated_syntax")
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

///|
fn surface_resource_u64(value : Int) -> Bytes {
  Int::max(0, value).to_uint64().to_be_bytes()
}

///|
fn surface_resource_bytes(value : Bytes) -> Bytes {
  value.length().to_uint64().to_be_bytes() + value
}

///|
fn SurfaceBackend::surface_resource_name(self : SurfaceBackend) -> Bytes {
  match self {
    Raster => b"raster"
    Window => b"window"
    Gpu => b"gpu"
  }
}

///|
fn SurfaceOrigin::surface_resource_name(self : SurfaceOrigin) -> Bytes {
  match self {
    TopLeft => b"top-left"
    BottomLeft => b"bottom-left"
  }
}

///|
fn SurfaceBudget::surface_resource_name(self : SurfaceBudget) -> Bytes {
  match self {
    Budgeted => b"budgeted"
    Unbudgeted => b"unbudgeted"
  }
}

///|
fn ColorType::surface_resource_name(self : ColorType) -> Bytes {
  match self {
    Unknown => b"unknown"
    Alpha8 => b"alpha8"
    RGB565 => b"rgb565"
    ARGB4444 => b"argb4444"
    RGBA8888 => b"rgba8888"
    RGB888x => b"rgb888x"
    BGRA8888 => b"bgra8888"
    RGBA1010102 => b"rgba1010102"
    RGB101010x => b"rgb101010x"
    Gray8 => b"gray8"
    RGBAF16 => b"rgbaf16"
    RGBAF32 => b"rgbaf32"
  }
}

///|
fn AlphaType::surface_resource_name(self : AlphaType) -> Bytes {
  match self {
    Unknown => b"unknown"
    Opaque => b"opaque"
    Premul => b"premul"
    Unpremul => b"unpremul"
  }
}

///|
fn ImageInfo::surface_resource_id(self : ImageInfo) -> Bytes {
  surface_resource_u64(self.width()) +
  surface_resource_u64(self.height()) +
  surface_resource_bytes(self.color_type().surface_resource_name()) +
  surface_resource_bytes(self.alpha_type().surface_resource_name())
}

///|
fn SurfaceDescriptor::resource_id(self : SurfaceDescriptor) -> Bytes {
  if self.is_empty() {
    b""
  } else {
    b"skia_mbt:surface:v1" +
    surface_resource_bytes(self.backend.surface_resource_name()) +
    self.image_info.surface_resource_id() +
    surface_resource_bytes(self.origin.surface_resource_name()) +
    surface_resource_u64(self.sample_count) +
    surface_resource_u64(self.stencil_bits) +
    surface_resource_bytes(self.budget.surface_resource_name())
  }
}

///|
pub fn SurfaceDescriptor::resource_key(
  self : SurfaceDescriptor,
) -> RendererResourceKey {
  if self.is_gpu() {
    RendererResourceKey::gpu_surface(self.resource_id())
  } else {
    RendererResourceKey::surface(self.resource_id())
  }
}

///|
fn SurfaceDescriptor::resource_byte_size(self : SurfaceDescriptor) -> Int64 {
  self.image_info.compute_min_byte_size64() * self.sample_count.to_int64()
}

///|
pub fn SurfaceDescriptor::resource_descriptor(
  self : SurfaceDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let measured_byte_size = if byte_size < 0L {
    self.resource_byte_size()
  } else {
    byte_size
  }
  RendererResourceDescriptor::new(
    self.resource_key(),
    byte_size=measured_byte_size,
    cacheable=!self.is_empty(),
  )
}

///|
/// Presentation policy for a window or GPU-backed surface target.
#warnings("-deprecated_syntax")
pub(all) enum SurfacePresentMode {
  ImmediatePresent
  MailboxPresent
  FifoPresent
} derive(Debug, Eq)

///|
pub impl Default for SurfacePresentMode with fn default() {
  FifoPresent
}

///|
pub fn SurfacePresentMode::prefers_vsync(self : SurfacePresentMode) -> Bool {
  self is FifoPresent
}

///|
pub fn SurfacePresentMode::allows_tearing(self : SurfacePresentMode) -> Bool {
  self is ImmediatePresent
}

///|
/// Stable value-layer contract for a renderable target and its presentation
/// boundary. Raster targets are valid but never presentable.
pub(all) struct SurfaceTargetDescriptor {
  surface : SurfaceDescriptor
  present_mode : SurfacePresentMode?
  max_frames_in_flight : Int
} derive(Debug, Eq)

///|
fn normalized_surface_present_mode(
  surface : SurfaceDescriptor,
  present_mode : SurfacePresentMode?,
) -> SurfacePresentMode? {
  if surface.is_presentable() {
    present_mode
  } else {
    None
  }
}

///|
pub fn SurfaceTargetDescriptor::new(
  surface : SurfaceDescriptor,
  present_mode? : SurfacePresentMode? = None,
  max_frames_in_flight? : Int = 1,
) -> SurfaceTargetDescriptor {
  {
    surface,
    present_mode: normalized_surface_present_mode(surface, present_mode),
    max_frames_in_flight: Int::max(1, max_frames_in_flight),
  }
}

///|
pub fn SurfaceTargetDescriptor::raster_n32_premul(
  size : ISize,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(SurfaceDescriptor::raster_n32_premul(size))
}

///|
pub fn SurfaceTargetDescriptor::window_n32_premul(
  size : ISize,
  origin? : SurfaceOrigin = TopLeft,
  sample_count? : Int = 1,
  stencil_bits? : Int = 0,
  present_mode? : SurfacePresentMode = FifoPresent,
  max_frames_in_flight? : Int = 2,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    SurfaceDescriptor::window_n32_premul(
      size,
      origin~,
      sample_count~,
      stencil_bits~,
    ),
    present_mode=Some(present_mode),
    max_frames_in_flight~,
  )
}

///|
pub fn SurfaceTargetDescriptor::gpu_n32_premul(
  size : ISize,
  origin? : SurfaceOrigin = TopLeft,
  sample_count? : Int = 1,
  stencil_bits? : Int = 0,
  budget? : SurfaceBudget = Budgeted,
  present_mode? : SurfacePresentMode = FifoPresent,
  max_frames_in_flight? : Int = 2,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    SurfaceDescriptor::gpu_n32_premul(
      size,
      origin~,
      sample_count~,
      stencil_bits~,
      budget~,
    ),
    present_mode=Some(present_mode),
    max_frames_in_flight~,
  )
}

///|
pub fn SurfaceTargetDescriptor::dimensions(
  self : SurfaceTargetDescriptor,
) -> ISize {
  self.surface.dimensions()
}

///|
pub fn SurfaceTargetDescriptor::bounds(self : SurfaceTargetDescriptor) -> IRect {
  self.surface.bounds()
}

///|
pub fn SurfaceTargetDescriptor::is_presentable(
  self : SurfaceTargetDescriptor,
) -> Bool {
  self.present_mode is Some(_) && self.surface.is_presentable()
}

///|
pub fn SurfaceTargetDescriptor::needs_present(
  self : SurfaceTargetDescriptor,
) -> Bool {
  self.is_presentable()
}

///|
pub fn SurfaceTargetDescriptor::is_multibuffered(
  self : SurfaceTargetDescriptor,
) -> Bool {
  self.max_frames_in_flight > 1
}

///|
pub fn SurfaceTargetDescriptor::with_dimensions(
  self : SurfaceTargetDescriptor,
  dimensions : ISize,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface.with_dimensions(dimensions),
    present_mode=self.present_mode,
    max_frames_in_flight=self.max_frames_in_flight,
  )
}

///|
pub fn SurfaceTargetDescriptor::with_present_mode(
  self : SurfaceTargetDescriptor,
  present_mode : SurfacePresentMode,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface,
    present_mode=Some(present_mode),
    max_frames_in_flight=self.max_frames_in_flight,
  )
}

///|
pub fn SurfaceTargetDescriptor::without_present(
  self : SurfaceTargetDescriptor,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface,
    max_frames_in_flight=self.max_frames_in_flight,
  )
}

///|
pub fn SurfaceTargetDescriptor::with_max_frames_in_flight(
  self : SurfaceTargetDescriptor,
  max_frames_in_flight : Int,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface,
    present_mode=self.present_mode,
    max_frames_in_flight~,
  )
}

///|
fn SurfacePresentMode::surface_resource_name(
  self : SurfacePresentMode,
) -> Bytes {
  match self {
    ImmediatePresent => b"immediate"
    MailboxPresent => b"mailbox"
    FifoPresent => b"fifo"
  }
}

///|
fn surface_target_present_resource_id(
  present_mode : SurfacePresentMode?,
) -> Bytes {
  match present_mode {
    None => b"none"
    Some(present_mode) => present_mode.surface_resource_name()
  }
}

///|
pub fn SurfaceTargetDescriptor::resource_key(
  self : SurfaceTargetDescriptor,
) -> RendererResourceKey {
  let surface_key = self.surface.resource_key()
  if surface_key.is_empty() {
    surface_key
  } else {
    RendererResourceKey::new(
      surface_key.kind,
      b"skia_mbt:surface-target:v1" +
      surface_resource_bytes(surface_key.id) +
      surface_resource_bytes(
        surface_target_present_resource_id(self.present_mode),
      ) +
      surface_resource_u64(self.max_frames_in_flight),
    )
  }
}

///|
pub fn SurfaceTargetDescriptor::resource_descriptor(
  self : SurfaceTargetDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let measured_byte_size = if byte_size < 0L {
    self.surface.resource_byte_size()
  } else {
    byte_size
  }
  RendererResourceDescriptor::new(
    self.resource_key(),
    byte_size=measured_byte_size,
    cacheable=!self.surface.is_empty(),
  )
}
