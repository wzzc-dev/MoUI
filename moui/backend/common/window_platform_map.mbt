///|
pub(all) struct PlatformWindowBinding {
  platform_id : @window_core.WindowId
  host_id : @backend_host.WindowId
} derive(Eq, Debug)

///|
pub struct PlatformWindowMap {
  mut bindings : Array[PlatformWindowBinding]
}

///|
pub fn PlatformWindowMap::new() -> PlatformWindowMap {
  { bindings: [] }
}

///|
pub fn PlatformWindowMap::count(self : PlatformWindowMap) -> Int {
  self.bindings.length()
}

///|
pub fn PlatformWindowMap::is_empty(self : PlatformWindowMap) -> Bool {
  self.bindings.is_empty()
}

///|
pub fn PlatformWindowMap::bind(
  self : PlatformWindowMap,
  platform_id~ : @window_core.WindowId,
  host_id~ : @backend_host.WindowId,
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
pub fn PlatformWindowMap::lookup_host(
  self : PlatformWindowMap,
  platform_id : @window_core.WindowId,
) -> @backend_host.WindowId? {
  for binding in self.bindings {
    if binding.platform_id == platform_id {
      return Some(binding.host_id)
    }
  }
  None
}

///|
pub fn PlatformWindowMap::lookup_platform(
  self : PlatformWindowMap,
  host_id : @backend_host.WindowId,
) -> @window_core.WindowId? {
  for binding in self.bindings {
    if binding.host_id == host_id {
      return Some(binding.platform_id)
    }
  }
  None
}

///|
pub fn PlatformWindowMap::remove_platform(
  self : PlatformWindowMap,
  platform_id : @window_core.WindowId,
) -> @backend_host.WindowId? {
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
pub fn PlatformWindowMap::remove_host(
  self : PlatformWindowMap,
  host_id : @backend_host.WindowId,
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
