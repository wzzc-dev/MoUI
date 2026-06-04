///|
/// Presentation policy for a window or GPU-backed surface target.
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
  target_id : Bytes
  present_mode : SurfacePresentMode?
  max_frames_in_flight : Int
  gpu_context_key : RendererResourceKey?
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
fn normalized_surface_target_id(
  surface : SurfaceDescriptor,
  target_id : Bytes,
) -> Bytes {
  if surface.is_presentable() && !surface.is_empty() {
    target_id
  } else {
    b""
  }
}

///|
fn normalized_surface_gpu_context_key(
  surface : SurfaceDescriptor,
  gpu_context_key : RendererResourceKey?,
) -> RendererResourceKey? {
  match gpu_context_key {
    Some(key) =>
      if surface.is_gpu() && key.kind == GpuContextResource && !key.is_empty() {
        Some(key)
      } else {
        None
      }
    None => None
  }
}

///|
pub fn SurfaceTargetDescriptor::new(
  surface : SurfaceDescriptor,
  present_mode? : SurfacePresentMode? = None,
  max_frames_in_flight? : Int = 1,
  gpu_context_key? : RendererResourceKey? = None,
  target_id? : Bytes = b"",
) -> SurfaceTargetDescriptor {
  {
    surface,
    target_id: normalized_surface_target_id(surface, target_id),
    present_mode: normalized_surface_present_mode(surface, present_mode),
    max_frames_in_flight: Int::max(1, max_frames_in_flight),
    gpu_context_key: normalized_surface_gpu_context_key(
      surface, gpu_context_key,
    ),
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
  target_id? : Bytes = b"",
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
    target_id~,
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
  gpu_context_key? : RendererResourceKey? = None,
  target_id? : Bytes = b"",
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
    gpu_context_key~,
    target_id~,
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
pub fn SurfaceTargetDescriptor::has_target_id(
  self : SurfaceTargetDescriptor,
) -> Bool {
  !self.target_id.is_empty()
}

///|
pub fn SurfaceTargetDescriptor::has_gpu_context(
  self : SurfaceTargetDescriptor,
) -> Bool {
  self.gpu_context_key is Some(_)
}

///|
pub fn SurfaceTargetDescriptor::with_dimensions(
  self : SurfaceTargetDescriptor,
  dimensions : ISize,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface.with_dimensions(dimensions),
    target_id=self.target_id,
    present_mode=self.present_mode,
    max_frames_in_flight=self.max_frames_in_flight,
    gpu_context_key=self.gpu_context_key,
  )
}

///|
pub fn SurfaceTargetDescriptor::with_target_id(
  self : SurfaceTargetDescriptor,
  target_id : Bytes,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface,
    present_mode=self.present_mode,
    max_frames_in_flight=self.max_frames_in_flight,
    gpu_context_key=self.gpu_context_key,
    target_id~,
  )
}

///|
pub fn SurfaceTargetDescriptor::without_target_id(
  self : SurfaceTargetDescriptor,
) -> SurfaceTargetDescriptor {
  self.with_target_id(b"")
}

///|
pub fn SurfaceTargetDescriptor::with_present_mode(
  self : SurfaceTargetDescriptor,
  present_mode : SurfacePresentMode,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface,
    target_id=self.target_id,
    present_mode=Some(present_mode),
    max_frames_in_flight=self.max_frames_in_flight,
    gpu_context_key=self.gpu_context_key,
  )
}

///|
pub fn SurfaceTargetDescriptor::without_present(
  self : SurfaceTargetDescriptor,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface,
    target_id=self.target_id,
    max_frames_in_flight=self.max_frames_in_flight,
    gpu_context_key=self.gpu_context_key,
  )
}

///|
pub fn SurfaceTargetDescriptor::with_max_frames_in_flight(
  self : SurfaceTargetDescriptor,
  max_frames_in_flight : Int,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface,
    target_id=self.target_id,
    present_mode=self.present_mode,
    max_frames_in_flight~,
    gpu_context_key=self.gpu_context_key,
  )
}

///|
pub fn SurfaceTargetDescriptor::with_gpu_context(
  self : SurfaceTargetDescriptor,
  gpu_context : GpuContextDescriptor,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface,
    target_id=self.target_id,
    present_mode=self.present_mode,
    max_frames_in_flight=self.max_frames_in_flight,
    gpu_context_key=Some(gpu_context.resource_key()),
  )
}

///|
pub fn SurfaceTargetDescriptor::without_gpu_context(
  self : SurfaceTargetDescriptor,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::new(
    self.surface,
    target_id=self.target_id,
    present_mode=self.present_mode,
    max_frames_in_flight=self.max_frames_in_flight,
  )
}
