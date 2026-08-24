///|
/// Lifecycle state owned by the neutral host-modal session.
pub(all) enum HostModalSessionState {
  Pending
  Accepted
  Rejected
  Closed
} derive(Eq, Debug, ToJson)

///|
/// A host surface token is opaque to the contract. The concrete platform
/// chooses its native surface id; the session only validates attach/detach.
pub(all) struct HostModalSurface {
  token : String
  generation : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostModalInputTransform {
  offset : @core.Point
  scale : @core.Point
} derive(Eq, Debug, ToJson)

///|
/// Exactly-once lifecycle and generation gate for one presentation request.
pub struct HostModalSession {
  request : @backend_host.HostModalRequest
  mut state : HostModalSessionState
  mut surface : HostModalSurface?
  mut close_emitted : Bool
  mut transform : HostModalInputTransform
}

///|
pub fn HostModalSession::new(
  request : @backend_host.HostModalRequest,
) -> HostModalSession {
  {
    request,
    state: HostModalSessionState::Pending,
    surface: None,
    close_emitted: false,
    transform: HostModalInputTransform::{
      offset: @core.Point::new(x=0.0, y=0.0),
      scale: @core.Point::new(x=1.0, y=1.0),
    },
  }
}

///|
pub fn HostModalSession::request(
  self : HostModalSession,
) -> @backend_host.HostModalRequest {
  self.request
}

///|
pub fn HostModalSession::state(
  self : HostModalSession,
) -> HostModalSessionState {
  self.state
}

///|
pub fn HostModalSession::begin(
  self : HostModalSession,
) -> @backend_host.HostModalEvent {
  @backend_host.HostModalEvent::Pending(
    self.request.request_id,
    self.request.presentation_id,
    self.request.generation,
  )
}

///|
pub fn HostModalSession::apply_result(
  self : HostModalSession,
  request_id : Int,
  generation : Int,
  result : @backend_host.HostModalResult,
) -> @backend_host.HostModalEvent? {
  match result {
    @backend_host.HostModalResult::Accepted =>
      self.accept(request_id, generation)
    @backend_host.HostModalResult::Rejected(reason) =>
      self.reject(request_id, generation, reason)
    @backend_host.HostModalResult::Closed => self.close(request_id, generation)
  }
}

///|
pub fn HostModalSession::is_current(
  self : HostModalSession,
  request_id : Int,
  generation : Int,
) -> Bool {
  self.request.request_id == request_id && self.request.generation == generation
}

///|
pub fn HostModalSession::accept(
  self : HostModalSession,
  request_id : Int,
  generation : Int,
) -> @backend_host.HostModalEvent? {
  if self.is_current(request_id, generation) &&
    self.state is HostModalSessionState::Pending {
    self.state = HostModalSessionState::Accepted
    Some(
      @backend_host.HostModalEvent::Accepted(
        request_id,
        self.request.presentation_id,
        generation,
      ),
    )
  } else {
    None
  }
}

///|
pub fn HostModalSession::reject(
  self : HostModalSession,
  request_id : Int,
  generation : Int,
  reason : String,
) -> @backend_host.HostModalEvent? {
  if self.is_current(request_id, generation) &&
    self.state is HostModalSessionState::Pending {
    self.state = HostModalSessionState::Rejected
    Some(
      @backend_host.HostModalEvent::Rejected(
        request_id,
        self.request.presentation_id,
        generation,
        reason,
      ),
    )
  } else {
    None
  }
}

///|
/// Close is idempotent. Duplicate and stale close notifications are dropped.
pub fn HostModalSession::close(
  self : HostModalSession,
  request_id : Int,
  generation : Int,
) -> @backend_host.HostModalEvent? {
  let can_close = match self.state {
    HostModalSessionState::Pending | HostModalSessionState::Accepted => true
    HostModalSessionState::Rejected | HostModalSessionState::Closed => false
  }
  if self.is_current(request_id, generation) && !self.close_emitted && can_close {
    self.close_emitted = true
    self.state = HostModalSessionState::Closed
    self.surface = None
    Some(
      @backend_host.HostModalEvent::Closed(
        request_id,
        self.request.presentation_id,
        generation,
      ),
    )
  } else {
    None
  }
}

///|
pub fn HostModalSession::attach_surface(
  self : HostModalSession,
  token : String,
  generation : Int,
) -> Bool {
  if generation == self.request.generation &&
    self.state is HostModalSessionState::Accepted {
    self.surface = Some(HostModalSurface::{ token, generation })
    true
  } else {
    false
  }
}

///|
pub fn HostModalSession::attach_surface_event(
  self : HostModalSession,
  token : String,
  generation : Int,
) -> @backend_host.HostModalEvent? {
  if self.attach_surface(token, generation) {
    Some(
      @backend_host.HostModalEvent::SurfaceAttached(
        self.request.request_id,
        self.request.presentation_id,
        generation,
        token,
      ),
    )
  } else {
    None
  }
}

///|
pub fn HostModalSession::detach_surface(
  self : HostModalSession,
  token : String,
  generation : Int,
) -> Bool {
  match self.surface {
    Some(surface) =>
      if surface.token == token && surface.generation == generation {
        self.surface = None
        true
      } else {
        false
      }
    None => false
  }
}

///|
pub fn HostModalSession::detach_surface_event(
  self : HostModalSession,
  token : String,
  generation : Int,
) -> @backend_host.HostModalEvent? {
  if self.detach_surface(token, generation) {
    Some(
      @backend_host.HostModalEvent::SurfaceDetached(
        self.request.request_id,
        self.request.presentation_id,
        generation,
        token,
      ),
    )
  } else {
    None
  }
}

///|
pub fn HostModalSession::surface(self : HostModalSession) -> HostModalSurface? {
  self.surface
}

///|
pub fn HostModalSession::set_input_transform(
  self : HostModalSession,
  offset~ : @core.Point,
  scale~ : @core.Point,
) -> Unit {
  self.transform = HostModalInputTransform::{
    offset,
    scale: @core.Point::new(
      x=if scale.x <= 0.0 { 1.0 } else { scale.x },
      y=if scale.y <= 0.0 { 1.0 } else { scale.y },
    ),
  }
}

///|
pub fn HostModalSession::is_native_only(self : HostModalSession) -> Bool {
  self.state is HostModalSessionState::Accepted
}

///|
pub fn HostModalSession::transform_input(
  self : HostModalSession,
  point : @core.Point,
) -> @core.Point {
  @core.Point::new(
    x=(point.x - self.transform.offset.x) / self.transform.scale.x,
    y=(point.y - self.transform.offset.y) / self.transform.scale.y,
  )
}

///|
/// Convert host-space pointer input into the same logical coordinates consumed
/// by the MoUI surface. Events are ignored while pending, rejected, or stale.
pub fn HostModalSession::route_input(
  self : HostModalSession,
  request_id : Int,
  generation : Int,
  event : @core.PointerEvent,
) -> @backend_host.HostModalEvent? {
  if self.is_current(request_id, generation) &&
    self.state is HostModalSessionState::Accepted &&
    self.surface is Some(_) {
    let transformed = {
      ..event,
      position: self.transform_input(event.position),
    }
    Some(
      @backend_host.HostModalEvent::Input(
        request_id,
        self.request.presentation_id,
        generation,
        transformed,
      ),
    )
  } else {
    None
  }
}
