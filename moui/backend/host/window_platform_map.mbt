///|
pub(all) struct HostPlatformWindowBinding {
  platform_id : @window_core.WindowId
  host_id : HostWindowId
} derive(Eq, Debug)

///|
pub struct HostPlatformWindowMap {
  mut bindings : Array[HostPlatformWindowBinding]
}

///|
pub fn HostPlatformWindowMap::new() -> HostPlatformWindowMap {
  { bindings: [] }
}

///|
pub fn HostPlatformWindowMap::count(self : HostPlatformWindowMap) -> Int {
  self.bindings.length()
}

///|
pub fn HostPlatformWindowMap::is_empty(self : HostPlatformWindowMap) -> Bool {
  self.bindings.is_empty()
}

///|
pub fn HostPlatformWindowMap::bind(
  self : HostPlatformWindowMap,
  platform_id~ : @window_core.WindowId,
  host_id~ : HostWindowId,
) -> Bool {
  match (self.lookup_host(platform_id), self.lookup_platform(host_id)) {
    (None, None) => {
      self.bindings.push({ platform_id, host_id })
      true
    }
    _ => false
  }
}

///|
pub fn HostPlatformWindowMap::lookup_host(
  self : HostPlatformWindowMap,
  platform_id : @window_core.WindowId,
) -> HostWindowId? {
  for binding in self.bindings {
    if binding.platform_id == platform_id {
      return Some(binding.host_id)
    }
  }
  None
}

///|
pub fn HostPlatformWindowMap::lookup_platform(
  self : HostPlatformWindowMap,
  host_id : HostWindowId,
) -> @window_core.WindowId? {
  for binding in self.bindings {
    if binding.host_id == host_id {
      return Some(binding.platform_id)
    }
  }
  None
}

///|
pub fn HostPlatformWindowMap::remove_platform(
  self : HostPlatformWindowMap,
  platform_id : @window_core.WindowId,
) -> HostWindowId? {
  let mut removed = None
  let kept = []
  for binding in self.bindings {
    if binding.platform_id == platform_id {
      removed = Some(binding.host_id)
    } else {
      kept.push(binding)
    }
  }
  self.bindings = kept
  removed
}

///|
pub fn HostPlatformWindowMap::remove_host(
  self : HostPlatformWindowMap,
  host_id : HostWindowId,
) -> @window_core.WindowId? {
  let mut removed = None
  let kept = []
  for binding in self.bindings {
    if binding.host_id == host_id {
      removed = Some(binding.platform_id)
    } else {
      kept.push(binding)
    }
  }
  self.bindings = kept
  removed
}
