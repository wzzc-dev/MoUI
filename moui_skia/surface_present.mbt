///|
fn normalized_surface_present_frame_index(frame_index : Int) -> Int {
  Int::max(0, frame_index)
}

///|
fn surface_present_mod(value : Int, divisor : Int) -> Int {
  let divisor = Int::max(1, divisor)
  value - value / divisor * divisor
}

///|
fn normalized_surface_present_buffer_index(
  target : SurfaceTargetDescriptor,
  frame_index : Int,
  buffer_index : Int,
) -> Int {
  if !target.is_presentable() {
    0
  } else {
    surface_present_mod(
      if buffer_index < 0 {
        frame_index
      } else {
        buffer_index
      },
      target.max_frames_in_flight,
    )
  }
}

///|
/// Per-frame presentation scheduling metadata for a presentable target.
pub(all) struct SurfacePresentDescriptor {
  target : SurfaceTargetDescriptor
  frame_index : Int
  buffer_index : Int
  present_mode : SurfacePresentMode?
} derive(Debug, Eq)

///|
pub fn SurfacePresentDescriptor::new(
  target : SurfaceTargetDescriptor,
  frame_index? : Int = 0,
  buffer_index? : Int = -1,
) -> SurfacePresentDescriptor {
  let frame_index = normalized_surface_present_frame_index(frame_index)
  {
    target,
    frame_index,
    buffer_index: normalized_surface_present_buffer_index(
      target, frame_index, buffer_index,
    ),
    present_mode: if target.is_presentable() {
      target.present_mode
    } else {
      None
    },
  }
}

///|
pub fn SurfaceTargetDescriptor::present_descriptor(
  self : SurfaceTargetDescriptor,
  frame_index? : Int = 0,
  buffer_index? : Int = -1,
) -> SurfacePresentDescriptor {
  SurfacePresentDescriptor::new(self, frame_index~, buffer_index~)
}

///|
/// Per-frame surface finalization metadata before a backend flushes/submits work.
pub(all) struct SurfaceFinalizationDescriptor {
  target : SurfaceTargetDescriptor
  frame_index : Int
} derive(Debug, Eq)

///|
pub fn SurfaceFinalizationDescriptor::new(
  target : SurfaceTargetDescriptor,
  frame_index? : Int = 0,
) -> SurfaceFinalizationDescriptor {
  { target, frame_index: normalized_surface_present_frame_index(frame_index) }
}

///|
pub fn SurfaceTargetDescriptor::finalization_descriptor(
  self : SurfaceTargetDescriptor,
  frame_index? : Int = 0,
) -> SurfaceFinalizationDescriptor {
  SurfaceFinalizationDescriptor::new(self, frame_index~)
}

///|
pub fn SurfaceFinalizationDescriptor::is_finalizable(
  self : SurfaceFinalizationDescriptor,
) -> Bool {
  !self.target.resource_key().is_empty()
}

///|
pub fn SurfaceFinalizationDescriptor::requires_gpu_context(
  self : SurfaceFinalizationDescriptor,
) -> Bool {
  self.target.surface.is_gpu()
}

///|
pub fn SurfacePresentDescriptor::is_presentable(
  self : SurfacePresentDescriptor,
) -> Bool {
  self.present_mode is Some(_) && self.target.is_presentable()
}

///|
pub fn SurfacePresentDescriptor::prefers_vsync(
  self : SurfacePresentDescriptor,
) -> Bool {
  match self.present_mode {
    Some(mode) => mode.prefers_vsync()
    None => false
  }
}

///|
pub fn SurfacePresentDescriptor::allows_tearing(
  self : SurfacePresentDescriptor,
) -> Bool {
  match self.present_mode {
    Some(mode) => mode.allows_tearing()
    None => false
  }
}
