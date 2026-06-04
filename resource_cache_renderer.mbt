///|
pub fn ResourceCache::insert_resource_descriptor(
  self : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
  descriptor : RendererResourceDescriptor,
) -> Bool {
  if descriptor.is_cacheable() {
    self.insert(descriptor.key, descriptor, byte_size=descriptor.byte_size)
  } else {
    false
  }
}

///|
pub fn ResourceCache::insert_resource_plan(
  self : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
  plan : RendererResourcePlan,
) -> Int {
  let mut inserted = 0
  for descriptor in plan.descriptors {
    if self.insert_resource_descriptor(descriptor) {
      inserted += 1
    }
  }
  inserted
}

///|
pub fn ResourceCache::contains_resource_descriptor(
  self : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
  descriptor : RendererResourceDescriptor,
) -> Bool {
  self.peek(descriptor.key) == Some(descriptor)
}

///|
pub fn ResourceCache::contains_resource_plan(
  self : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
  plan : RendererResourcePlan,
) -> Bool {
  let mut covered = true
  for descriptor in plan.descriptors {
    if descriptor.is_cacheable() &&
      !self.contains_resource_descriptor(descriptor) {
      covered = false
    }
  }
  covered
}

///|
pub fn ResourceCache::cached_cacheable_resource_plan(
  self : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
  plan : RendererResourcePlan,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  for descriptor in plan.descriptors {
    if descriptor.is_cacheable() &&
      self.contains_resource_descriptor(descriptor) {
      descriptors.push(descriptor)
    }
  }
  RendererResourcePlan::new(descriptors)
}

///|
pub fn ResourceCache::missing_cacheable_resource_plan(
  self : ResourceCache[RendererResourceKey, RendererResourceDescriptor],
  plan : RendererResourcePlan,
) -> RendererResourcePlan {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  for descriptor in plan.descriptors {
    if descriptor.is_cacheable() &&
      !self.contains_resource_descriptor(descriptor) {
      descriptors.push(descriptor)
    }
  }
  RendererResourcePlan::new(descriptors)
}
