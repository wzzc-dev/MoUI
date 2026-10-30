///|
pub fn EmbeddedRuntimeHostBridge::new(
  session_generation~ : Int32 = 1,
  service_handler~ : (@host.HostServiceRequest) -> @host.HostServiceResponse? = _ => {
    None
  },
) -> EmbeddedRuntimeHostBridge {
  {
    service_handler,
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
) -> Int32 {
  self.session_generation
}

///|
pub fn EmbeddedHostResponseEnvelope::new(
  session_generation~ : Int32,
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
/// The embedded host service queue, exposed so a platform shell can drain and
/// complete clipboard requests itself when it has no separate service runner.
pub fn EmbeddedRuntimeHostBridge::services(
  self : EmbeddedRuntimeHostBridge,
) -> @host_services_embedded.EmbeddedHostServices {
  self.services
}

///|
pub fn EmbeddedRuntimeHostBridge::service_bridge(
  self : EmbeddedRuntimeHostBridge,
) -> HostServiceBridge {
  // Answer synchronously when the platform provided a handler: the runtime calls
  // this from `dispatch_command_with_services` and expects `ClipboardText`
  // immediately for Ctrl+V. The queued path only works when a shell drains and
  // completes the request, which an embedded template does not have.
  HostServiceBridge::new(capabilities=self.services.capabilities, handle=request => {
    match (self.service_handler)(request) {
      Some(response) => response
      None => self.services.bridge().dispatch(request)
    }
  })
}

///|
pub fn EmbeddedRuntimeHostBridge::sync(
  self : EmbeddedRuntimeHostBridge,
  runtime : @runtime.AppRuntime,
) -> Int32 {
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
