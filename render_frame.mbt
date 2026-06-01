///|
fn render_frame_descriptor_array_contains_key(
  descriptors : Array[RendererResourceDescriptor],
  key : RendererResourceKey,
) -> Bool {
  let mut found = false
  for descriptor in descriptors {
    if descriptor.key == key {
      found = true
    }
  }
  found
}

///|
fn render_frame_resource_descriptors(
  target : SurfaceTargetDescriptor,
  command_list : RenderCommandList,
) -> Array[RendererResourceDescriptor] {
  let descriptors = target.resource_descriptors()
  let pass_surface_key = command_list.pass.resource_descriptor().key
  for descriptor in command_list.resource_descriptors() {
    if descriptor.key != pass_surface_key &&
      !render_frame_descriptor_array_contains_key(descriptors, descriptor.key) {
      descriptors.push(descriptor)
    }
  }
  descriptors
}

///|
/// Validation outcome for a finalized render frame.
#warnings("-deprecated_syntax")
pub(all) enum RenderFrameValidationStatus {
  FrameReady
  FrameTargetMismatch
  FrameUnbalancedState
  FrameMissingGpuContext
  FrameMissingPresent
} derive(Debug, Eq)

///|
pub fn RenderFrameValidationStatus::is_ready(
  self : RenderFrameValidationStatus,
) -> Bool {
  self is FrameReady
}

///|
/// Frame-level value boundary for a target plus its finalized render commands.
pub(all) struct RenderFrameDescriptor {
  target : SurfaceTargetDescriptor
  command_list : RenderCommandList
  resource_plan : RendererResourcePlan
  stats : RenderCommandStats
  touched_bounds : Rect?
} derive(Debug, Eq)

///|
pub fn RenderFrameDescriptor::new(
  target : SurfaceTargetDescriptor,
  command_list : RenderCommandList,
) -> RenderFrameDescriptor {
  let command_list = command_list.finish()
  let resource_plan = RendererResourcePlan::new(
    render_frame_resource_descriptors(target, command_list),
  )
  {
    target,
    command_list,
    resource_plan,
    stats: command_list.stats(),
    touched_bounds: command_list.touched_bounds(),
  }
}

///|
pub fn RenderFrameDescriptor::empty(
  target : SurfaceTargetDescriptor,
) -> RenderFrameDescriptor {
  RenderFrameDescriptor::new(target, RenderCommandList::for_target(target))
}

///|
pub fn RenderFrameDescriptor::is_target_consistent(
  self : RenderFrameDescriptor,
) -> Bool {
  self.command_list.pass.is_bound_to_target(self.target)
}

///|
pub fn RenderFrameDescriptor::needs_present(
  self : RenderFrameDescriptor,
) -> Bool {
  self.target.needs_present()
}

///|
pub fn RenderFrameDescriptor::has_present(self : RenderFrameDescriptor) -> Bool {
  self.command_list.has_present()
}

///|
pub fn RenderFrameDescriptor::requires_gpu_context(
  self : RenderFrameDescriptor,
) -> Bool {
  self.target.surface.is_gpu()
}

///|
pub fn RenderFrameDescriptor::has_gpu_context(
  self : RenderFrameDescriptor,
) -> Bool {
  self.target.has_gpu_context()
}

///|
pub fn RenderFrameDescriptor::validation_status(
  self : RenderFrameDescriptor,
) -> RenderFrameValidationStatus {
  if !self.is_target_consistent() {
    FrameTargetMismatch
  } else if !self.stats.is_state_balanced() {
    FrameUnbalancedState
  } else if self.requires_gpu_context() && !self.has_gpu_context() {
    FrameMissingGpuContext
  } else if self.needs_present() && !self.has_present() {
    FrameMissingPresent
  } else {
    FrameReady
  }
}

///|
pub fn RenderFrameDescriptor::is_ready(self : RenderFrameDescriptor) -> Bool {
  self.validation_status().is_ready()
}

///|
pub fn RenderFrameDescriptor::cache_resources(
  self : RenderFrameDescriptor,
  cache : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
) -> Int {
  cache.insert_resource_plan(self.resource_plan)
}

///|
pub fn RenderFrameDescriptor::cacheable_resource_plan(
  self : RenderFrameDescriptor,
) -> RendererResourcePlan {
  self.resource_plan.cacheable_resource_plan()
}

///|
pub fn RenderFrameDescriptor::uncacheable_resource_plan(
  self : RenderFrameDescriptor,
) -> RendererResourcePlan {
  self.resource_plan.uncacheable_resource_plan()
}

///|
pub fn RenderFrameDescriptor::cached_cacheable_resource_plan(
  self : RenderFrameDescriptor,
  cache : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
) -> RendererResourcePlan {
  cache.cached_cacheable_resource_plan(self.resource_plan)
}

///|
pub fn RenderFrameDescriptor::missing_cacheable_resource_plan(
  self : RenderFrameDescriptor,
  cache : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
) -> RendererResourcePlan {
  cache.missing_cacheable_resource_plan(self.resource_plan)
}

///|
pub fn RenderFrameDescriptor::present_descriptor(
  self : RenderFrameDescriptor,
  frame_index? : Int = 0,
  buffer_index? : Int = -1,
) -> SurfacePresentDescriptor? {
  if self.is_ready() && self.needs_present() && self.has_present() {
    Some(self.target.present_descriptor(frame_index~, buffer_index~))
  } else {
    None
  }
}

///|
pub fn RenderFrameDescriptor::present_resource_plan(
  self : RenderFrameDescriptor,
  frame_index? : Int = 0,
  buffer_index? : Int = -1,
) -> RendererResourcePlan {
  match self.present_descriptor(frame_index~, buffer_index~) {
    Some(descriptor) => descriptor.resource_plan()
    None => RendererResourcePlan::empty()
  }
}

///|
fn render_frame_finalization_resource_plan(
  frame : RenderFrameDescriptor,
  finalization : SurfaceFinalizationDescriptor?,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  for descriptor in frame.resource_plan.descriptors {
    descriptors.push(descriptor)
  }
  match finalization {
    None => ()
    Some(finalization) =>
      for descriptor in finalization.resource_plan().descriptors {
        descriptors.push(descriptor)
      }
  }
  RendererResourcePlan::new(descriptors)
}

///|
/// Auditable backend finalization boundary for a finalized frame before
/// flush/submit is performed on its target surface.
pub(all) struct RenderFrameFinalizationDescriptor {
  frame : RenderFrameDescriptor
  frame_index : Int
  validation_status : RenderFrameValidationStatus
  finalization : SurfaceFinalizationDescriptor?
  resource_plan : RendererResourcePlan
} derive(Debug, Eq)

///|
pub fn RenderFrameFinalizationDescriptor::new(
  frame : RenderFrameDescriptor,
  frame_index? : Int = 0,
) -> RenderFrameFinalizationDescriptor {
  let frame_index = Int::max(0, frame_index)
  let surface_finalization = frame.target.finalization_descriptor(frame_index~)
  let finalization = if frame.is_ready() &&
    surface_finalization.is_finalizable() {
    Some(surface_finalization)
  } else {
    None
  }
  {
    frame,
    frame_index,
    validation_status: frame.validation_status(),
    finalization,
    resource_plan: render_frame_finalization_resource_plan(frame, finalization),
  }
}

///|
pub fn RenderFrameDescriptor::finalization_descriptor(
  self : RenderFrameDescriptor,
  frame_index? : Int = 0,
) -> RenderFrameFinalizationDescriptor {
  RenderFrameFinalizationDescriptor::new(self, frame_index~)
}

///|
pub fn RenderFrameDescriptor::finalization_resource_plan(
  self : RenderFrameDescriptor,
  frame_index? : Int = 0,
) -> RendererResourcePlan {
  self.finalization_descriptor(frame_index~).resource_plan
}

///|
pub fn RenderFrameFinalizationDescriptor::is_ready(
  self : RenderFrameFinalizationDescriptor,
) -> Bool {
  self.validation_status.is_ready() && self.finalization is Some(_)
}

///|
pub fn RenderFrameFinalizationDescriptor::has_finalization(
  self : RenderFrameFinalizationDescriptor,
) -> Bool {
  self.finalization is Some(_)
}

///|
pub fn RenderFrameFinalizationDescriptor::requires_gpu_context(
  self : RenderFrameFinalizationDescriptor,
) -> Bool {
  self.frame.requires_gpu_context()
}

///|
pub fn RenderFrameFinalizationDescriptor::gpu_backed_resource_plan(
  self : RenderFrameFinalizationDescriptor,
) -> RendererResourcePlan {
  self.resource_plan.gpu_backed_resource_plan()
}

///|
pub fn RenderFrameFinalizationDescriptor::cacheable_resource_plan(
  self : RenderFrameFinalizationDescriptor,
) -> RendererResourcePlan {
  self.resource_plan.cacheable_resource_plan()
}

///|
pub fn RenderFrameFinalizationDescriptor::uncacheable_resource_plan(
  self : RenderFrameFinalizationDescriptor,
) -> RendererResourcePlan {
  self.resource_plan.uncacheable_resource_plan()
}

///|
pub fn RenderFrameFinalizationDescriptor::cached_cacheable_resource_plan(
  self : RenderFrameFinalizationDescriptor,
  cache : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
) -> RendererResourcePlan {
  cache.cached_cacheable_resource_plan(self.resource_plan)
}

///|
pub fn RenderFrameFinalizationDescriptor::missing_cacheable_resource_plan(
  self : RenderFrameFinalizationDescriptor,
  cache : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
) -> RendererResourcePlan {
  cache.missing_cacheable_resource_plan(self.resource_plan)
}

///|
pub fn RenderFrameFinalizationDescriptor::cache_resources(
  self : RenderFrameFinalizationDescriptor,
  cache : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
) -> Int {
  if self.is_ready() {
    cache.insert_resource_plan(self.resource_plan)
  } else {
    0
  }
}

///|
fn render_frame_submission_resource_plan(
  frame : RenderFrameDescriptor,
  present : SurfacePresentDescriptor?,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  for descriptor in frame.resource_plan.descriptors {
    descriptors.push(descriptor)
  }
  match present {
    None => ()
    Some(present) =>
      for descriptor in present.resource_plan().descriptors {
        descriptors.push(descriptor)
      }
  }
  RendererResourcePlan::new(descriptors)
}

///|
/// Auditable backend submission boundary for a finalized frame plus any
/// per-frame present resources.
pub(all) struct RenderFrameSubmissionDescriptor {
  frame : RenderFrameDescriptor
  frame_index : Int
  validation_status : RenderFrameValidationStatus
  present : SurfacePresentDescriptor?
  resource_plan : RendererResourcePlan
} derive(Debug, Eq)

///|
pub fn RenderFrameSubmissionDescriptor::new(
  frame : RenderFrameDescriptor,
  frame_index? : Int = 0,
  buffer_index? : Int = -1,
) -> RenderFrameSubmissionDescriptor {
  let frame_index = Int::max(0, frame_index)
  let present = frame.present_descriptor(frame_index~, buffer_index~)
  {
    frame,
    frame_index,
    validation_status: frame.validation_status(),
    present,
    resource_plan: render_frame_submission_resource_plan(frame, present),
  }
}

///|
pub fn RenderFrameDescriptor::submission_descriptor(
  self : RenderFrameDescriptor,
  frame_index? : Int = 0,
  buffer_index? : Int = -1,
) -> RenderFrameSubmissionDescriptor {
  RenderFrameSubmissionDescriptor::new(self, frame_index~, buffer_index~)
}

///|
pub fn RenderFrameSubmissionDescriptor::is_ready(
  self : RenderFrameSubmissionDescriptor,
) -> Bool {
  self.validation_status.is_ready()
}

///|
pub fn RenderFrameSubmissionDescriptor::has_present(
  self : RenderFrameSubmissionDescriptor,
) -> Bool {
  self.present is Some(_)
}

///|
pub fn RenderFrameSubmissionDescriptor::gpu_backed_resource_plan(
  self : RenderFrameSubmissionDescriptor,
) -> RendererResourcePlan {
  self.resource_plan.gpu_backed_resource_plan()
}

///|
pub fn RenderFrameSubmissionDescriptor::cacheable_resource_plan(
  self : RenderFrameSubmissionDescriptor,
) -> RendererResourcePlan {
  self.resource_plan.cacheable_resource_plan()
}

///|
pub fn RenderFrameSubmissionDescriptor::uncacheable_resource_plan(
  self : RenderFrameSubmissionDescriptor,
) -> RendererResourcePlan {
  self.resource_plan.uncacheable_resource_plan()
}

///|
pub fn RenderFrameSubmissionDescriptor::cached_cacheable_resource_plan(
  self : RenderFrameSubmissionDescriptor,
  cache : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
) -> RendererResourcePlan {
  cache.cached_cacheable_resource_plan(self.resource_plan)
}

///|
pub fn RenderFrameSubmissionDescriptor::missing_cacheable_resource_plan(
  self : RenderFrameSubmissionDescriptor,
  cache : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
) -> RendererResourcePlan {
  cache.missing_cacheable_resource_plan(self.resource_plan)
}

///|
pub fn RenderFrameSubmissionDescriptor::cache_resources(
  self : RenderFrameSubmissionDescriptor,
  cache : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
) -> Int {
  if self.is_ready() {
    cache.insert_resource_plan(self.resource_plan)
  } else {
    0
  }
}

///|
pub fn RenderCommandList::frame_descriptor(
  self : RenderCommandList,
  target : SurfaceTargetDescriptor,
) -> RenderFrameDescriptor {
  RenderFrameDescriptor::new(target, self)
}
