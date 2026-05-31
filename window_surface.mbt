///|
fn normalized_window_surface_device_pixel_ratio(value : Float) -> Float {
  if geometry_scalar_is_finite(value) && value > 0.0 {
    value
  } else {
    1.0
  }
}

///|
fn normalized_window_surface_logical_size(size : Size) -> Size {
  if size.is_finite() && !size.is_empty() {
    size
  } else {
    Size::empty()
  }
}

///|
fn normalized_window_surface_physical_size(size : ISize) -> ISize {
  if size.is_empty() {
    ISize::empty()
  } else {
    size
  }
}

///|
fn window_surface_physical_size_from_logical_size(
  logical_size : Size,
  device_pixel_ratio : Float,
) -> ISize {
  normalized_window_surface_physical_size(
    logical_size.scale(device_pixel_ratio).to_isize_round(),
  )
}

///|
fn window_surface_logical_size_from_physical_size(
  physical_size : ISize,
  device_pixel_ratio : Float,
) -> Size {
  if physical_size.is_empty() {
    Size::empty()
  } else {
    physical_size.to_size().scale(1.0 / device_pixel_ratio)
  }
}

///|
/// Stable value-layer contract for a native window-backed render target.
///
/// `window_id` is an owned, stable identity token chosen by the host GUI layer;
/// it should identify the window/swapchain without borrowing a platform handle.
pub(all) struct WindowSurfaceDescriptor {
  window_id : Bytes
  logical_size : Size
  physical_size : ISize
  device_pixel_ratio : Float
  origin : SurfaceOrigin
  sample_count : Int
  stencil_bits : Int
  present_mode : SurfacePresentMode
  max_frames_in_flight : Int
} derive(Debug, Eq)

///|
pub fn WindowSurfaceDescriptor::new(
  window_id? : Bytes = b"",
  logical_size? : Size = Size::empty(),
  physical_size? : ISize = ISize::empty(),
  device_pixel_ratio? : Float = 1.0,
  origin? : SurfaceOrigin = TopLeft,
  sample_count? : Int = 1,
  stencil_bits? : Int = 0,
  present_mode? : SurfacePresentMode = FifoPresent,
  max_frames_in_flight? : Int = 2,
) -> WindowSurfaceDescriptor {
  let device_pixel_ratio = normalized_window_surface_device_pixel_ratio(
    device_pixel_ratio,
  )
  let logical_size = normalized_window_surface_logical_size(logical_size)
  let physical_size = normalized_window_surface_physical_size(physical_size)
  let physical_size = if physical_size.is_empty() {
    window_surface_physical_size_from_logical_size(
      logical_size, device_pixel_ratio,
    )
  } else {
    physical_size
  }
  let logical_size = if logical_size.is_empty() {
    window_surface_logical_size_from_physical_size(
      physical_size, device_pixel_ratio,
    )
  } else {
    logical_size
  }
  {
    window_id,
    logical_size,
    physical_size,
    device_pixel_ratio,
    origin,
    sample_count: Int::max(1, sample_count),
    stencil_bits: Int::max(0, stencil_bits),
    present_mode,
    max_frames_in_flight: Int::max(1, max_frames_in_flight),
  }
}

///|
pub fn WindowSurfaceDescriptor::from_physical_size(
  window_id : Bytes,
  physical_size : ISize,
  device_pixel_ratio? : Float = 1.0,
  origin? : SurfaceOrigin = TopLeft,
  sample_count? : Int = 1,
  stencil_bits? : Int = 0,
  present_mode? : SurfacePresentMode = FifoPresent,
  max_frames_in_flight? : Int = 2,
) -> WindowSurfaceDescriptor {
  WindowSurfaceDescriptor::new(
    window_id~,
    physical_size~,
    device_pixel_ratio~,
    origin~,
    sample_count~,
    stencil_bits~,
    present_mode~,
    max_frames_in_flight~,
  )
}

///|
pub fn WindowSurfaceDescriptor::has_window_id(
  self : WindowSurfaceDescriptor,
) -> Bool {
  !self.window_id.is_empty()
}

///|
pub fn WindowSurfaceDescriptor::is_empty(
  self : WindowSurfaceDescriptor,
) -> Bool {
  self.physical_size.is_empty()
}

///|
pub fn WindowSurfaceDescriptor::dimensions(
  self : WindowSurfaceDescriptor,
) -> ISize {
  self.physical_size
}

///|
pub fn WindowSurfaceDescriptor::logical_dimensions(
  self : WindowSurfaceDescriptor,
) -> Size {
  self.logical_size
}

///|
pub fn WindowSurfaceDescriptor::surface_descriptor(
  self : WindowSurfaceDescriptor,
) -> SurfaceDescriptor {
  SurfaceDescriptor::window_n32_premul(
    self.physical_size,
    origin=self.origin,
    sample_count=self.sample_count,
    stencil_bits=self.stencil_bits,
  )
}

///|
pub fn WindowSurfaceDescriptor::target_descriptor(
  self : WindowSurfaceDescriptor,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::window_n32_premul(
    self.physical_size,
    origin=self.origin,
    sample_count=self.sample_count,
    stencil_bits=self.stencil_bits,
    present_mode=self.present_mode,
    max_frames_in_flight=self.max_frames_in_flight,
    target_id=self.window_id,
  )
}

///|
pub fn WindowSurfaceDescriptor::gpu_target_descriptor(
  self : WindowSurfaceDescriptor,
  budget? : SurfaceBudget = Budgeted,
  gpu_context_key? : RendererResourceKey? = None,
) -> SurfaceTargetDescriptor {
  SurfaceTargetDescriptor::gpu_n32_premul(
    self.physical_size,
    origin=self.origin,
    sample_count=self.sample_count,
    stencil_bits=self.stencil_bits,
    budget~,
    present_mode=self.present_mode,
    max_frames_in_flight=self.max_frames_in_flight,
    gpu_context_key~,
    target_id=self.window_id,
  )
}

///|
pub fn WindowSurfaceDescriptor::resource_key(
  self : WindowSurfaceDescriptor,
) -> RendererResourceKey {
  self.target_descriptor().resource_key()
}

///|
pub fn WindowSurfaceDescriptor::resource_descriptor(
  self : WindowSurfaceDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  self.target_descriptor().resource_descriptor(byte_size~)
}

///|
pub fn WindowSurfaceDescriptor::resource_plan(
  self : WindowSurfaceDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  self.target_descriptor().resource_plan(byte_size~)
}

///|
pub fn WindowSurfaceDescriptor::with_window_id(
  self : WindowSurfaceDescriptor,
  window_id : Bytes,
) -> WindowSurfaceDescriptor {
  WindowSurfaceDescriptor::new(
    window_id~,
    logical_size=self.logical_size,
    physical_size=self.physical_size,
    device_pixel_ratio=self.device_pixel_ratio,
    origin=self.origin,
    sample_count=self.sample_count,
    stencil_bits=self.stencil_bits,
    present_mode=self.present_mode,
    max_frames_in_flight=self.max_frames_in_flight,
  )
}

///|
pub fn WindowSurfaceDescriptor::with_logical_size(
  self : WindowSurfaceDescriptor,
  logical_size : Size,
) -> WindowSurfaceDescriptor {
  WindowSurfaceDescriptor::new(
    window_id=self.window_id,
    logical_size~,
    device_pixel_ratio=self.device_pixel_ratio,
    origin=self.origin,
    sample_count=self.sample_count,
    stencil_bits=self.stencil_bits,
    present_mode=self.present_mode,
    max_frames_in_flight=self.max_frames_in_flight,
  )
}

///|
pub fn WindowSurfaceDescriptor::with_physical_size(
  self : WindowSurfaceDescriptor,
  physical_size : ISize,
) -> WindowSurfaceDescriptor {
  WindowSurfaceDescriptor::new(
    window_id=self.window_id,
    physical_size~,
    device_pixel_ratio=self.device_pixel_ratio,
    origin=self.origin,
    sample_count=self.sample_count,
    stencil_bits=self.stencil_bits,
    present_mode=self.present_mode,
    max_frames_in_flight=self.max_frames_in_flight,
  )
}

///|
pub fn WindowSurfaceDescriptor::with_device_pixel_ratio(
  self : WindowSurfaceDescriptor,
  device_pixel_ratio : Float,
) -> WindowSurfaceDescriptor {
  if self.logical_size.is_empty() {
    WindowSurfaceDescriptor::new(
      window_id=self.window_id,
      physical_size=self.physical_size,
      device_pixel_ratio~,
      origin=self.origin,
      sample_count=self.sample_count,
      stencil_bits=self.stencil_bits,
      present_mode=self.present_mode,
      max_frames_in_flight=self.max_frames_in_flight,
    )
  } else {
    WindowSurfaceDescriptor::new(
      window_id=self.window_id,
      logical_size=self.logical_size,
      device_pixel_ratio~,
      origin=self.origin,
      sample_count=self.sample_count,
      stencil_bits=self.stencil_bits,
      present_mode=self.present_mode,
      max_frames_in_flight=self.max_frames_in_flight,
    )
  }
}

///|
pub fn WindowSurfaceDescriptor::with_present_mode(
  self : WindowSurfaceDescriptor,
  present_mode : SurfacePresentMode,
) -> WindowSurfaceDescriptor {
  WindowSurfaceDescriptor::new(
    window_id=self.window_id,
    logical_size=self.logical_size,
    physical_size=self.physical_size,
    device_pixel_ratio=self.device_pixel_ratio,
    origin=self.origin,
    sample_count=self.sample_count,
    stencil_bits=self.stencil_bits,
    present_mode~,
    max_frames_in_flight=self.max_frames_in_flight,
  )
}

///|
pub fn WindowSurfaceDescriptor::with_max_frames_in_flight(
  self : WindowSurfaceDescriptor,
  max_frames_in_flight : Int,
) -> WindowSurfaceDescriptor {
  WindowSurfaceDescriptor::new(
    window_id=self.window_id,
    logical_size=self.logical_size,
    physical_size=self.physical_size,
    device_pixel_ratio=self.device_pixel_ratio,
    origin=self.origin,
    sample_count=self.sample_count,
    stencil_bits=self.stencil_bits,
    present_mode=self.present_mode,
    max_frames_in_flight~,
  )
}
