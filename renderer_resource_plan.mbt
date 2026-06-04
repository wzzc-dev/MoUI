///|
fn renderer_resource_descriptor_array_contains_key(
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
fn renderer_resource_plan_unique_descriptors(
  descriptors : Array[RendererResourceDescriptor],
) -> Array[RendererResourceDescriptor] {
  let result : Array[RendererResourceDescriptor] = Array::new(
    capacity=descriptors.length(),
  )
  for descriptor in descriptors {
    if !renderer_resource_descriptor_array_contains_key(result, descriptor.key) {
      result.push(descriptor)
    }
  }
  result
}

///|
/// Auditable resource requirements for a backend render step.
pub(all) struct RendererResourcePlan {
  descriptors : Array[RendererResourceDescriptor]
  byte_size : Int64
  cacheable_count : Int
  uncacheable_count : Int
  gpu_backed_count : Int
} derive(Debug, Eq)

///|
pub fn RendererResourcePlan::new(
  descriptors : Array[RendererResourceDescriptor],
) -> RendererResourcePlan {
  let descriptors = renderer_resource_plan_unique_descriptors(descriptors)
  let mut byte_size = 0L
  let mut cacheable_count = 0
  let mut uncacheable_count = 0
  let mut gpu_backed_count = 0
  for descriptor in descriptors {
    byte_size += descriptor.byte_size
    if descriptor.is_cacheable() {
      cacheable_count += 1
    } else {
      uncacheable_count += 1
    }
    if descriptor.is_gpu_backed() {
      gpu_backed_count += 1
    }
  }
  {
    descriptors,
    byte_size,
    cacheable_count,
    uncacheable_count,
    gpu_backed_count,
  }
}

///|
pub fn RendererResourcePlan::empty() -> RendererResourcePlan {
  RendererResourcePlan::new([])
}

///|
pub fn RendererResourcePlan::length(self : RendererResourcePlan) -> Int {
  self.descriptors.length()
}

///|
pub fn RendererResourcePlan::is_empty(self : RendererResourcePlan) -> Bool {
  self.descriptors.is_empty()
}

///|
pub fn RendererResourcePlan::has_gpu_backed_resources(
  self : RendererResourcePlan,
) -> Bool {
  self.gpu_backed_count > 0
}

///|
pub fn RendererResourcePlan::has_cacheable_resources(
  self : RendererResourcePlan,
) -> Bool {
  self.cacheable_count > 0
}

///|
pub fn RendererResourcePlan::has_uncacheable_resources(
  self : RendererResourcePlan,
) -> Bool {
  self.uncacheable_count > 0
}

///|
pub fn RendererResourcePlan::cacheable_descriptors(
  self : RendererResourcePlan,
) -> Array[RendererResourceDescriptor] {
  let result : Array[RendererResourceDescriptor] = Array::new()
  for descriptor in self.descriptors {
    if descriptor.is_cacheable() {
      result.push(descriptor)
    }
  }
  result
}

///|
pub fn RendererResourcePlan::cacheable_resource_plan(
  self : RendererResourcePlan,
) -> RendererResourcePlan {
  RendererResourcePlan::new(self.cacheable_descriptors())
}

///|
pub fn RendererResourcePlan::uncacheable_descriptors(
  self : RendererResourcePlan,
) -> Array[RendererResourceDescriptor] {
  let result : Array[RendererResourceDescriptor] = Array::new()
  for descriptor in self.descriptors {
    if !descriptor.is_cacheable() {
      result.push(descriptor)
    }
  }
  result
}

///|
pub fn RendererResourcePlan::uncacheable_resource_plan(
  self : RendererResourcePlan,
) -> RendererResourcePlan {
  RendererResourcePlan::new(self.uncacheable_descriptors())
}

///|
pub fn RendererResourcePlan::gpu_backed_descriptors(
  self : RendererResourcePlan,
) -> Array[RendererResourceDescriptor] {
  let result : Array[RendererResourceDescriptor] = Array::new()
  for descriptor in self.descriptors {
    if descriptor.is_gpu_backed() {
      result.push(descriptor)
    }
  }
  result
}

///|
pub fn RendererResourcePlan::gpu_backed_resource_plan(
  self : RendererResourcePlan,
) -> RendererResourcePlan {
  RendererResourcePlan::new(self.gpu_backed_descriptors())
}

///|
pub fn RendererResourcePlan::contains_key(
  self : RendererResourcePlan,
  key : RendererResourceKey,
) -> Bool {
  renderer_resource_descriptor_array_contains_key(self.descriptors, key)
}

///|
pub fn RendererResourcePlan::descriptor_for_key(
  self : RendererResourcePlan,
  key : RendererResourceKey,
) -> RendererResourceDescriptor? {
  let mut result : RendererResourceDescriptor? = None
  for descriptor in self.descriptors {
    if descriptor.key == key {
      result = Some(descriptor)
    }
  }
  result
}

///|
pub fn RendererResourcePlan::descriptors_of_kind(
  self : RendererResourcePlan,
  kind : RendererResourceKind,
) -> Array[RendererResourceDescriptor] {
  let result : Array[RendererResourceDescriptor] = Array::new()
  for descriptor in self.descriptors {
    if descriptor.key.kind == kind {
      result.push(descriptor)
    }
  }
  result
}

///|
pub fn RendererResourcePlan::count_kind(
  self : RendererResourcePlan,
  kind : RendererResourceKind,
) -> Int {
  self.descriptors_of_kind(kind).length()
}

///|
pub fn RendererResourcePlan::byte_size_for_kind(
  self : RendererResourcePlan,
  kind : RendererResourceKind,
) -> Int64 {
  let mut byte_size = 0L
  for descriptor in self.descriptors {
    if descriptor.key.kind == kind {
      byte_size += descriptor.byte_size
    }
  }
  byte_size
}
