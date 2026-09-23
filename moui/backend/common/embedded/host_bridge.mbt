///|
pub fn EmbeddedRuntimeHostBridge::new(
  session_generation? : Int = 1,
) -> EmbeddedRuntimeHostBridge {
  {
    services: @host_services_embedded.EmbeddedHostServices::new(),
    session_generation: session_generation.max(1),
    updates: [],
    ime_revision: 0,
    last_text_input: None,
    semantics_cursor: None,
    platform_view_revision: 0,
    last_platform_views: [],
    disposed: false,
  }
}

///|
pub fn EmbeddedRuntimeHostBridge::session_generation(
  self : EmbeddedRuntimeHostBridge,
) -> Int {
  self.session_generation
}

///|
pub fn EmbeddedHostResponseEnvelope::new(
  session_generation~ : Int,
  response~ : EmbeddedHostResponse,
) -> EmbeddedHostResponseEnvelope {
  { schema_version: 1, session_generation, response, }
}

///|
pub fn EmbeddedRuntimeHostBridge::disposed(
  self : EmbeddedRuntimeHostBridge,
) -> Bool {
  self.disposed
}

///|
pub fn EmbeddedRuntimeHostBridge::service_bridge(
  self : EmbeddedRuntimeHostBridge,
) -> HostServiceBridge {
  self.services.bridge()
}

///|
pub fn EmbeddedRuntimeHostBridge::sync(
  self : EmbeddedRuntimeHostBridge,
  runtime : @runtime.AppRuntime,
) -> Int {
  if self.disposed {
    return 0
  }
  let previous_count = self.updates.length()
  self.sync_text_input(runtime.focused_text_input())
  self.sync_semantics(runtime)
  for pending in self.services.drain_pending() {
    match pending.request {
      Clipboard(_) => self.updates.push(Clipboard(pending))
      PlatformChannel(_) => self.updates.push(PlatformChannel(pending))
      _ => ()
    }
  }
  self.updates.length() - previous_count
}

///|
pub fn EmbeddedRuntimeHostBridge::push_diagnostic(
  self : EmbeddedRuntimeHostBridge,
  message : String,
) -> Bool {
  if self.disposed {
    false
  } else {
    self.updates.push(Diagnostic(message))
    true
  }
}
