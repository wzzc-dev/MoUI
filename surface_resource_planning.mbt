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
fn surface_target_gpu_context_resource_id(
  gpu_context_key : RendererResourceKey?,
) -> Bytes {
  match gpu_context_key {
    None => b"none"
    Some(key) => key.id
  }
}

///|
fn SurfacePresentDescriptor::resource_id(
  self : SurfacePresentDescriptor,
) -> Bytes {
  let target_key = self.target.resource_key()
  if !self.is_presentable() || target_key.is_empty() {
    b""
  } else {
    b"skia_mbt:surface-present:v1" +
    surface_resource_bytes(target_key.id) +
    surface_resource_bytes(
      surface_target_present_resource_id(self.present_mode),
    ) +
    surface_resource_u64(self.frame_index) +
    surface_resource_u64(self.buffer_index)
  }
}

///|
fn SurfaceFinalizationDescriptor::resource_id(
  self : SurfaceFinalizationDescriptor,
) -> Bytes {
  let target_key = self.target.resource_key()
  if !self.is_finalizable() || target_key.is_empty() {
    b""
  } else {
    b"skia_mbt:surface-finalization:v1" +
    surface_resource_bytes(target_key.id) +
    surface_resource_u64(self.frame_index)
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
      b"skia_mbt:surface-target:v2" +
      surface_resource_bytes(surface_key.id) +
      surface_resource_bytes(self.target_id) +
      surface_resource_bytes(
        surface_target_present_resource_id(self.present_mode),
      ) +
      surface_resource_u64(self.max_frames_in_flight) +
      surface_resource_bytes(
        surface_target_gpu_context_resource_id(self.gpu_context_key),
      ),
    )
  }
}

///|
pub fn SurfacePresentDescriptor::resource_key(
  self : SurfacePresentDescriptor,
) -> RendererResourceKey {
  let target_key = self.target.resource_key()
  RendererResourceKey::new(target_key.kind, self.resource_id())
}

///|
pub fn SurfaceFinalizationDescriptor::resource_key(
  self : SurfaceFinalizationDescriptor,
) -> RendererResourceKey {
  let target_key = self.target.resource_key()
  RendererResourceKey::new(target_key.kind, self.resource_id())
}

///|
pub fn SurfacePresentDescriptor::resource_descriptor(
  self : SurfacePresentDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id()
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::new(
    self.resource_key(),
    byte_size=measured_byte_size,
    cacheable=false,
  )
}

///|
pub fn SurfaceFinalizationDescriptor::resource_descriptor(
  self : SurfaceFinalizationDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourceDescriptor {
  let id = self.resource_id()
  let measured_byte_size = if byte_size < 0L {
    id.length().to_int64()
  } else {
    byte_size
  }
  RendererResourceDescriptor::new(
    self.resource_key(),
    byte_size=measured_byte_size,
    cacheable=false,
  )
}

///|
pub fn SurfaceTargetDescriptor::gpu_context_resource_descriptor(
  self : SurfaceTargetDescriptor,
) -> RendererResourceDescriptor? {
  match self.gpu_context_key {
    None => None
    Some(key) => Some(RendererResourceDescriptor::new(key))
  }
}

///|
pub fn SurfaceTargetDescriptor::resource_descriptors(
  self : SurfaceTargetDescriptor,
  byte_size? : Int64 = -1L,
) -> Array[RendererResourceDescriptor] {
  let descriptors : Array[RendererResourceDescriptor] = Array::new()
  let surface_descriptor = self.resource_descriptor(byte_size~)
  if !surface_descriptor.key.is_empty() {
    descriptors.push(surface_descriptor)
  }
  match self.gpu_context_resource_descriptor() {
    None => ()
    Some(context_descriptor) =>
      if !context_descriptor.key.is_empty() {
        descriptors.push(context_descriptor)
      }
  }
  descriptors
}

///|
pub fn SurfacePresentDescriptor::resource_descriptors(
  self : SurfacePresentDescriptor,
  byte_size? : Int64 = -1L,
) -> Array[RendererResourceDescriptor] {
  if !self.is_presentable() {
    []
  } else {
    let descriptors = self.target.resource_descriptors()
    let present_descriptor = self.resource_descriptor(byte_size~)
    if !present_descriptor.key.is_empty() {
      descriptors.push(present_descriptor)
    }
    descriptors
  }
}

///|
pub fn SurfaceFinalizationDescriptor::resource_descriptors(
  self : SurfaceFinalizationDescriptor,
  byte_size? : Int64 = -1L,
) -> Array[RendererResourceDescriptor] {
  if !self.is_finalizable() {
    []
  } else {
    let descriptors = self.target.resource_descriptors()
    let finalization_descriptor = self.resource_descriptor(byte_size~)
    if !finalization_descriptor.key.is_empty() {
      descriptors.push(finalization_descriptor)
    }
    descriptors
  }
}

///|
pub fn SurfacePresentDescriptor::resource_plan(
  self : SurfacePresentDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  RendererResourcePlan::new(self.resource_descriptors(byte_size~))
}

///|
pub fn SurfaceFinalizationDescriptor::resource_plan(
  self : SurfaceFinalizationDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  RendererResourcePlan::new(self.resource_descriptors(byte_size~))
}

///|
pub fn SurfaceTargetDescriptor::resource_plan(
  self : SurfaceTargetDescriptor,
  byte_size? : Int64 = -1L,
) -> RendererResourcePlan {
  RendererResourcePlan::new(self.resource_descriptors(byte_size~))
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
