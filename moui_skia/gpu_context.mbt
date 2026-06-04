///|
/// Future GPU context families that can back a GPU surface target.
pub(all) enum GpuContextBackend {
  MockGpuContext
  MetalGpuContext
  VulkanGpuContext
  Direct3D12GpuContext
  OpenGLGpuContext
} derive(Debug, Eq)

///|
pub impl Default for GpuContextBackend with fn default() {
  MockGpuContext
}

///|
pub fn GpuContextBackend::is_mock(self : GpuContextBackend) -> Bool {
  self is MockGpuContext
}

///|
pub fn GpuContextBackend::is_native_window_backend(
  self : GpuContextBackend,
) -> Bool {
  self
  is (MetalGpuContext
  | VulkanGpuContext
  | Direct3D12GpuContext
  | OpenGLGpuContext)
}

///|
/// Stable identity for a GPU context or device queue a future native backend can
/// use when creating GPU-backed surfaces.
pub(all) struct GpuContextDescriptor {
  backend : GpuContextBackend
  id : Bytes
  adapter_id : Bytes
  device_id : Bytes
  queue_family_index : Int
  protected_context : Bool
} derive(Debug, Eq)

///|
pub fn GpuContextDescriptor::new(
  backend? : GpuContextBackend = MockGpuContext,
  id? : Bytes = b"",
  adapter_id? : Bytes = b"",
  device_id? : Bytes = b"",
  queue_family_index? : Int = 0,
  protected_context? : Bool = false,
) -> GpuContextDescriptor {
  {
    backend,
    id,
    adapter_id,
    device_id,
    queue_family_index: Int::max(0, queue_family_index),
    protected_context,
  }
}

///|
pub fn GpuContextDescriptor::mock(
  id? : Bytes = b"mock",
) -> GpuContextDescriptor {
  GpuContextDescriptor::new(backend=MockGpuContext, id~)
}

///|
pub fn GpuContextDescriptor::metal(
  id : Bytes,
  adapter_id? : Bytes = b"",
  device_id? : Bytes = b"",
) -> GpuContextDescriptor {
  GpuContextDescriptor::new(
    backend=MetalGpuContext,
    id~,
    adapter_id~,
    device_id~,
  )
}

///|
pub fn GpuContextDescriptor::vulkan(
  id : Bytes,
  adapter_id? : Bytes = b"",
  device_id? : Bytes = b"",
  queue_family_index? : Int = 0,
) -> GpuContextDescriptor {
  GpuContextDescriptor::new(
    backend=VulkanGpuContext,
    id~,
    adapter_id~,
    device_id~,
    queue_family_index~,
  )
}

///|
pub fn GpuContextDescriptor::direct3d12(
  id : Bytes,
  adapter_id? : Bytes = b"",
  device_id? : Bytes = b"",
) -> GpuContextDescriptor {
  GpuContextDescriptor::new(
    backend=Direct3D12GpuContext,
    id~,
    adapter_id~,
    device_id~,
  )
}

///|
pub fn GpuContextDescriptor::opengl(
  id : Bytes,
  adapter_id? : Bytes = b"",
  device_id? : Bytes = b"",
) -> GpuContextDescriptor {
  GpuContextDescriptor::new(
    backend=OpenGLGpuContext,
    id~,
    adapter_id~,
    device_id~,
  )
}

///|
pub fn GpuContextDescriptor::is_anonymous(self : GpuContextDescriptor) -> Bool {
  self.id.is_empty()
}

///|
pub fn GpuContextDescriptor::with_protected_context(
  self : GpuContextDescriptor,
  protected_context : Bool,
) -> GpuContextDescriptor {
  { ..self, protected_context, }
}

///|
fn GpuContextBackend::gpu_context_resource_name(
  self : GpuContextBackend,
) -> Bytes {
  match self {
    MockGpuContext => b"mock"
    MetalGpuContext => b"metal"
    VulkanGpuContext => b"vulkan"
    Direct3D12GpuContext => b"direct3d12"
    OpenGLGpuContext => b"opengl"
  }
}

///|
fn gpu_context_resource_u64(value : Int) -> Bytes {
  Int::max(0, value).to_uint64().to_be_bytes()
}

///|
fn gpu_context_resource_bool(value : Bool) -> Bytes {
  if value {
    b"true"
  } else {
    b"false"
  }
}

///|
fn gpu_context_resource_bytes(value : Bytes) -> Bytes {
  value.length().to_uint64().to_be_bytes() + value
}

///|
fn GpuContextDescriptor::resource_id(self : GpuContextDescriptor) -> Bytes {
  if self.is_anonymous() {
    b""
  } else {
    b"moui_skia:gpu-context:v1" +
    gpu_context_resource_bytes(self.backend.gpu_context_resource_name()) +
    gpu_context_resource_bytes(self.id) +
    gpu_context_resource_bytes(self.adapter_id) +
    gpu_context_resource_bytes(self.device_id) +
    gpu_context_resource_u64(self.queue_family_index) +
    gpu_context_resource_bytes(
      gpu_context_resource_bool(self.protected_context),
    )
  }
}

///|
pub fn GpuContextDescriptor::resource_key(
  self : GpuContextDescriptor,
) -> RendererResourceKey {
  RendererResourceKey::gpu_context(self.resource_id())
}

///|
pub fn GpuContextDescriptor::resource_descriptor(
  self : GpuContextDescriptor,
  byte_size? : Int64 = 0L,
) -> RendererResourceDescriptor {
  RendererResourceDescriptor::gpu_context(self.resource_id(), byte_size~)
}
