///|
/// Generation-scoped host session transport for window-hosted (and transitional)
/// mobile runtimes. Ported from former moui_shell embedding transport (ADR 0015);
/// no Embedding C ABI, no moui_shell dependency.

///|

///|
pub(all) enum HostSessionState {
  Detached
  Attached
  Destroyed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostSession {
  mut generation : Int
  mut surface_epoch : Int
  mut state : HostSessionState
} derive(Debug, ToJson)

///|
pub fn HostSession::new(generation~ : Int) -> HostSession {
  {
    generation: if generation > 0 {
      generation
    } else {
      1
    },
    surface_epoch: 0,
    state: Detached,
  }
}

///|
pub fn HostSession::generation(self : HostSession) -> Int {
  self.generation
}

///|
pub fn HostSession::surface_epoch(self : HostSession) -> Int {
  self.surface_epoch
}

///|
pub fn HostSession::state(self : HostSession) -> HostSessionState {
  self.state
}

///|
pub fn HostSession::attach(self : HostSession) -> Bool {
  match self.state {
    Destroyed => false
    _ => {
      if self.surface_epoch > 0 {
        self.generation = self.generation + 1
      }
      self.surface_epoch = self.surface_epoch + 1
      self.state = Attached
      true
    }
  }
}

///|
pub fn HostSession::detach(self : HostSession) -> Bool {
  match self.state {
    Attached => {
      self.state = Detached
      true
    }
    _ => false
  }
}

///|
pub fn HostSession::destroy(self : HostSession) -> Bool {
  match self.state {
    Destroyed => false
    _ => {
      self.state = Destroyed
      true
    }
  }
}

///|
pub struct HostFrameScheduler {
  mut requested : Bool
  mut in_frame : Bool
  mut follow_up : Bool
} derive(Debug, ToJson)

///|
pub fn HostFrameScheduler::new() -> HostFrameScheduler {
  { requested: false, in_frame: false, follow_up: false }
}

///|
pub fn HostFrameScheduler::request(self : HostFrameScheduler) -> Unit {
  if self.in_frame {
    self.follow_up = true
  } else {
    self.requested = true
  }
}

///|
pub fn HostFrameScheduler::begin_frame(self : HostFrameScheduler) -> Bool {
  if self.in_frame || !self.requested {
    false
  } else {
    self.requested = false
    self.in_frame = true
    true
  }
}

///|
pub fn HostFrameScheduler::finish_frame(self : HostFrameScheduler) -> Bool {
  if !self.in_frame {
    return false
  }
  self.in_frame = false
  if self.follow_up {
    self.follow_up = false
    self.requested = true
  }
  true
}

///|
/// Whether a native frame source should schedule a callback.
pub fn HostFrameScheduler::requested(self : HostFrameScheduler) -> Bool {
  self.requested
}

///|
/// Drops pending work when a native surface is detached. A new attach will
/// explicitly request its first frame.
pub fn HostFrameScheduler::reset(self : HostFrameScheduler) -> Unit {
  self.requested = false
  self.in_frame = false
  self.follow_up = false
}

///|
pub(all) struct HostRequestId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub struct HostChannel {
  mut next_request_id : Int
  mut pending : Array[HostRequestId]
  mut updates : Array[HostWireUpdate]
} derive(Debug, ToJson)

///|
pub fn HostChannel::new() -> HostChannel {
  { next_request_id: 1, pending: [], updates: [] }
}

///|
pub fn HostChannel::begin_request(self : HostChannel) -> HostRequestId {
  let id = { value: self.next_request_id }
  self.next_request_id = self.next_request_id + 1
  self.pending.push(id)
  id
}

///|
pub fn HostChannel::complete(self : HostChannel, id : HostRequestId) -> Bool {
  match self.pending.search_by(item => item == id) {
    Some(index) => {
      ignore(self.pending.remove(index))
      true
    }
    None => false
  }
}

///|
/// Registers a request id allocated by the embedding runtime. The shell owns
/// correlation and stale-response rejection without importing the runtime's
/// request type.
pub fn HostChannel::track_request(
  self : HostChannel,
  id~ : Int,
) -> HostRequestId? {
  if id <= 0 || self.pending.any(item => item.value == id) {
    None
  } else {
    let request = { value: id }
    self.pending.push(request)
    Some(request)
  }
}

///|
pub fn HostChannel::complete_request(self : HostChannel, id~ : Int) -> Bool {
  match self.pending.search_by(item => item.value == id) {
    Some(index) => {
      ignore(self.pending.remove(index))
      true
    }
    None => false
  }
}

///|
pub fn HostChannel::reset(self : HostChannel) -> Unit {
  self.pending = []
  self.updates = []
}

///|
pub fn HostChannel::pending_count(self : HostChannel) -> Int {
  self.pending.length()
}

///|
/// A neutral outbound shell update. `payload` stays JSON so this SDK owns
/// transport semantics without importing MoUI host or runtime types.
pub(all) struct HostWireUpdate {
  kind : String
  request_id : HostRequestId?
  payload : Json
} derive(Eq, Debug, ToJson)

///|
pub fn HostChannel::enqueue_update(
  self : HostChannel,
  kind~ : String,
  payload~ : Json,
  request_id? : HostRequestId? = None,
) -> Bool {
  if kind == "" {
    return false
  }
  self.updates.push({ kind, request_id, payload })
  true
}

///|
pub fn HostChannel::drain_updates(
  self : HostChannel,
) -> Array[HostWireUpdate] {
  let updates = self.updates
  self.updates = []
  updates
}

///|
pub(all) struct HostWireEnvelope {
  schema_version : Int
  session_generation : Int
  surface_epoch : Int
  updates : Array[HostWireUpdate]
} derive(Eq, Debug, ToJson)

///|
pub fn HostWireEnvelope::new(
  session_generation~ : Int,
  surface_epoch~ : Int,
  updates~ : Array[HostWireUpdate],
) -> HostWireEnvelope {
  {
    schema_version: 1,
    session_generation: session_generation.max(1),
    surface_epoch: surface_epoch.max(0),
    updates,
  }
}

///|
pub fn HostChannel::drain_update_envelope(
  self : HostChannel,
  session : HostSession,
) -> HostWireEnvelope {
  HostWireEnvelope::new(
    session_generation=session.generation(),
    surface_epoch=session.surface_epoch(),
    updates=self.drain_updates(),
  )
}

///|
fn host_wire_update_json(update : HostWireUpdate) -> Json {
  match update.request_id {
    Some(id) =>
      ({ "kind": update.kind, "id": id.value, "payload": update.payload } : Json)
    None => ({ "kind": update.kind, "payload": update.payload } : Json)
  }
}

///|
pub fn HostWireEnvelope::to_json_string(self : HostWireEnvelope) -> String {
  (
    {
      "schemaVersion": self.schema_version,
      "sessionGeneration": self.session_generation,
      "surfaceEpoch": self.surface_epoch,
      "updates": self.updates.map(host_wire_update_json),
    } : Json).stringify()
}

///|
fn host_wire_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn host_wire_string(value : Json?) -> String? {
  match value {
    Some(String(text)) if text != "" => Some(text)
    _ => None
  }
}

///|
fn host_wire_int(value : Json?) -> Int? {
  match value {
    Some(Number(number, repr=_)) => {
      let integer = number.to_int()
      if integer.to_double() == number {
        Some(integer)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn host_wire_update(value : Json) -> HostWireUpdate? {
  guard host_wire_object(Some(value)) is Some(fields) else { return None }
  guard host_wire_string(fields.get("kind")) is Some(kind) else { return None }
  guard fields.get("payload") is Some(payload) else { return None }
  let request_id = match fields.get("id") {
    None => None
    Some(Null) => None
    some =>
      match host_wire_int(some) {
        Some(value) if value > 0 => Some({ value, })
        _ => return None
      }
  }
  Some({ kind, request_id, payload })
}

///|
pub fn parse_host_wire_envelope_json(text : String) -> HostWireEnvelope? {
  let parsed = @json.parse(text) catch { _ => return None }
  guard host_wire_object(Some(parsed)) is Some(root) else { return None }
  guard host_wire_int(root.get("schemaVersion")) is Some(1) else {
    return None
  }
  guard host_wire_int(root.get("sessionGeneration"))
    is Some(session_generation) &&
    session_generation > 0 else {
    return None
  }
  guard host_wire_int(root.get("surfaceEpoch")) is Some(surface_epoch) &&
    surface_epoch >= 0 else {
    return None
  }
  guard root.get("updates") is Some(Array(values)) else { return None }
  let updates : Array[HostWireUpdate] = []
  for value in values {
    guard host_wire_update(value) is Some(update) else { return None }
    updates.push(update)
  }
  Some(HostWireEnvelope::new(session_generation~, surface_epoch~, updates~))
}

///|
/// The one shell-owned transport state for one embedded runtime. It keeps
/// native lifecycle safety independent from MoUI host/runtime semantics.
pub struct HostSessionTransport {
  session : HostSession
  scheduler : HostFrameScheduler
  channel : HostChannel
}

///|
pub fn HostSessionTransport::new(
  initial_generation~ : Int,
) -> HostSessionTransport {
  {
    session: HostSession::new(generation=initial_generation),
    scheduler: HostFrameScheduler::new(),
    channel: HostChannel::new(),
  }
}

///|
pub fn HostSessionTransport::session_generation(
  self : HostSessionTransport,
) -> Int {
  self.session.generation()
}

///|
pub fn HostSessionTransport::surface_epoch(
  self : HostSessionTransport,
) -> Int {
  self.session.surface_epoch()
}

///|
pub fn HostSessionTransport::attached(
  self : HostSessionTransport,
) -> Bool {
  self.session.state() is Attached
}

///|
pub fn HostSessionTransport::attach(self : HostSessionTransport) -> Bool {
  self.channel.reset()
  self.scheduler.reset()
  self.session.attach()
}

///|
pub fn HostSessionTransport::detach(self : HostSessionTransport) -> Bool {
  let detached = self.session.detach()
  if detached {
    self.channel.reset()
    self.scheduler.reset()
  }
  detached
}

///|
pub fn HostSessionTransport::destroy(self : HostSessionTransport) -> Bool {
  let destroyed = self.session.destroy()
  if destroyed {
    self.channel.reset()
    self.scheduler.reset()
  }
  destroyed
}

///|
pub fn HostSessionTransport::request_frame(
  self : HostSessionTransport,
) -> Unit {
  if self.attached() {
    self.scheduler.request()
  }
}

///|
pub fn HostSessionTransport::take_requested_frame(
  self : HostSessionTransport,
) -> Bool {
  self.attached() && self.scheduler.begin_frame()
}

///|
pub fn HostSessionTransport::finish_frame(
  self : HostSessionTransport,
) -> Bool {
  self.attached() && self.scheduler.finish_frame()
}

///|
pub fn HostSessionTransport::frame_requested(
  self : HostSessionTransport,
) -> Bool {
  self.attached() && self.scheduler.requested()
}

///|
pub fn HostSessionTransport::track_request(
  self : HostSessionTransport,
  id~ : Int,
) -> Bool {
  self.attached() && self.channel.track_request(id~) is Some(_)
}

///|
pub fn HostSessionTransport::complete_request(
  self : HostSessionTransport,
  id~ : Int,
) -> Bool {
  self.attached() && self.channel.complete_request(id~)
}

///|
pub fn HostSessionTransport::enqueue_update(
  self : HostSessionTransport,
  kind~ : String,
  payload~ : Json,
  request_id? : Int? = None,
) -> Bool {
  if !self.attached() {
    return false
  }
  let request_id = match request_id {
    Some(value) =>
      if self.channel.track_request(id=value) is Some(request) {
        Some(request)
      } else {
        return false
      }
    None => None
  }
  self.channel.enqueue_update(kind~, payload~, request_id~)
}

///|
pub fn HostSessionTransport::enqueue_tracked_update(
  self : HostSessionTransport,
  kind~ : String,
  payload~ : Json,
  request_id~ : Int,
) -> Bool {
  if !self.attached() ||
    self.channel.pending.any(item => item.value == request_id) == false {
    false
  } else {
    self.channel.enqueue_update(
      kind~,
      payload~,
      request_id=Some({ value: request_id }),
    )
  }
}

///|
pub fn HostSessionTransport::drain_update_envelope_json(
  self : HostSessionTransport,
) -> String {
  if !self.attached() {
    return (
      {
        "schemaVersion": 1,
        "sessionGeneration": 0,
        "surfaceEpoch": 0,
        "updates": ([] : Array[Json]),
      } : Json).stringify()
  }
  self.channel.drain_update_envelope(self.session).to_json_string()
}

///|
pub fn HostSessionTransport::accepts_response_generation(
  self : HostSessionTransport,
  generation~ : Int,
) -> Bool {
  self.attached() && generation == self.session.generation()
}

///|
