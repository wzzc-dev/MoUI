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
  self.command_list.pass.surface == self.target.surface
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
pub fn RenderFrameDescriptor::is_ready(self : RenderFrameDescriptor) -> Bool {
  self.is_target_consistent() &&
  self.stats.is_state_balanced() &&
  (!self.needs_present() || self.has_present())
}

///|
pub fn RenderCommandList::frame_descriptor(
  self : RenderCommandList,
  target : SurfaceTargetDescriptor,
) -> RenderFrameDescriptor {
  RenderFrameDescriptor::new(target, self)
}
