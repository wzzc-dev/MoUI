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
