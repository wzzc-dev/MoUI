///|
/// Logical lifecycle phase owned by MoUI for an embedded host.
pub enum EmbeddedHostLifecyclePhase {
  Idle
  Resumed
  SurfaceAttached
  Exited
} derive(Eq, Debug)

///|
/// Surface identity crossing the physical window adapter boundary. The
/// generation is created here; embedded transport has its own session
/// generation and must never mint a surface epoch.
pub struct EmbeddedHostSurface {
  handle : UInt64
  metrics : @core.SurfaceMetrics
  generation : Int
} derive(Eq, Debug)

///|
pub enum EmbeddedWindowHostAction {
  Resumed
  CanCreateSurfaces
  SurfaceAttached(EmbeddedHostSurface)
  SurfaceDetached(Int)
  DestroySurfaces
  Suspended
  Exit(Int)
} derive(Eq, Debug)

///|
/// The embedded lifecycle adapter shared by Android, iOS, and HarmonyOS.
/// It has no native queue and no event-loop handle; those remain in
/// `wzzc-dev/window`. It owns only MoUI logical phase, surface generation,
/// primary-window identity, detach semantics, and application exit intent.
pub struct EmbeddedLifecycle {
  mut phase : EmbeddedHostLifecyclePhase
  mut generation : Int
  mut surface : EmbeddedHostSurface?
  mut primary_window : @backend_host.WindowId?
  mut exit_intent : Int?
}

///|
pub fn EmbeddedLifecycle::new() -> EmbeddedLifecycle {
  {
    phase: Idle,
    generation: 0,
    surface: None,
    primary_window: None,
    exit_intent: None,
  }
}

///|
pub fn EmbeddedLifecycle::phase(
  self : EmbeddedLifecycle,
) -> EmbeddedHostLifecyclePhase {
  self.phase
}

///|
pub fn EmbeddedLifecycle::surface_generation(self : EmbeddedLifecycle) -> Int {
  self.generation
}

///|
pub fn EmbeddedLifecycle::surface(
  self : EmbeddedLifecycle,
) -> EmbeddedHostSurface? {
  self.surface
}

///|
pub fn EmbeddedLifecycle::primary_window(
  self : EmbeddedLifecycle,
) -> @backend_host.WindowId? {
  self.primary_window
}

///|
pub fn EmbeddedLifecycle::register_window(
  self : EmbeddedLifecycle,
  id : @backend_host.WindowId,
) -> Unit {
  if self.primary_window is None {
    self.primary_window = Some(id)
  }
}

///|
pub fn EmbeddedLifecycle::unregister_window(
  self : EmbeddedLifecycle,
  id : @backend_host.WindowId,
) -> Unit {
  if self.primary_window == Some(id) {
    self.primary_window = None
  }
}

///|
pub fn EmbeddedLifecycle::resumed(
  self : EmbeddedLifecycle,
) -> Array[EmbeddedWindowHostAction] {
  match self.phase {
    Exited | Resumed | SurfaceAttached => []
    Idle => {
      self.phase = Resumed
      [Resumed]
    }
  }
}

///|
pub fn EmbeddedLifecycle::attach_surface(
  self : EmbeddedLifecycle,
  handle : UInt64,
  metrics : @core.SurfaceMetrics,
) -> Array[EmbeddedWindowHostAction] {
  if self.phase is Exited {
    return []
  }
  let actions : Array[EmbeddedWindowHostAction] = []
  if self.surface is Some(_) {
    actions.append(self.detach_surface())
  }
  self.generation = self.generation + 1
  let surface = EmbeddedHostSurface::{
    handle,
    metrics,
    generation: self.generation,
  }
  self.surface = Some(surface)
  self.phase = SurfaceAttached
  actions.push(CanCreateSurfaces)
  actions.push(SurfaceAttached(surface))
  actions
}

///|
pub fn EmbeddedLifecycle::resize_surface(
  self : EmbeddedLifecycle,
  metrics : @core.SurfaceMetrics,
) -> EmbeddedWindowHostAction? {
  match self.surface {
    Some(surface) => {
      let updated = EmbeddedHostSurface::{ ..surface, metrics, }
      self.surface = Some(updated)
      Some(SurfaceAttached(updated))
    }
    None => None
  }
}

///|
pub fn EmbeddedLifecycle::detach_surface(
  self : EmbeddedLifecycle,
) -> Array[EmbeddedWindowHostAction] {
  match self.surface {
    Some(_) => {
      self.surface = None
      self.generation = self.generation + 1
      if self.phase == SurfaceAttached {
        self.phase = Resumed
      }
      [SurfaceDetached(self.generation), DestroySurfaces]
    }
    None => []
  }
}

///|
pub fn EmbeddedLifecycle::suspended(
  self : EmbeddedLifecycle,
) -> Array[EmbeddedWindowHostAction] {
  let actions = self.detach_surface()
  match self.phase {
    Idle | Exited => actions
    Resumed | SurfaceAttached => {
      self.phase = Idle
      actions.push(Suspended)
      actions
    }
  }
}

///|
pub fn EmbeddedLifecycle::request_exit(
  self : EmbeddedLifecycle,
  code : Int,
) -> EmbeddedWindowHostAction {
  self.exit_intent = Some(code)
  self.phase = Exited
  Exit(code)
}

///|
pub fn EmbeddedLifecycle::exit_intent(self : EmbeddedLifecycle) -> Int? {
  self.exit_intent
}
