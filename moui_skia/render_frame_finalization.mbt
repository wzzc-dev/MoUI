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
