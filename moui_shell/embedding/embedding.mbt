///|
pub(all) enum ShellPlatform {
  Android
  Ios
  Harmonyos
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ShellSessionState {
  Detached
  Attached
  Destroyed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ShellSession {
  mut generation : Int
  mut surface_epoch : Int
  mut state : ShellSessionState
} derive(Debug, ToJson)

///|
pub fn ShellSession::new(generation~ : Int) -> ShellSession {
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
pub fn ShellSession::generation(self : ShellSession) -> Int {
  self.generation
}

///|
pub fn ShellSession::surface_epoch(self : ShellSession) -> Int {
  self.surface_epoch
}

///|
pub fn ShellSession::state(self : ShellSession) -> ShellSessionState {
  self.state
}

///|
pub fn ShellSession::attach(self : ShellSession) -> Bool {
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
pub fn ShellSession::detach(self : ShellSession) -> Bool {
  match self.state {
    Attached => {
      self.state = Detached
      true
    }
    _ => false
  }
}

///|
pub fn ShellSession::destroy(self : ShellSession) -> Bool {
  match self.state {
    Destroyed => false
    _ => {
      self.state = Destroyed
      true
    }
  }
}

///|
pub struct ShellFrameScheduler {
  mut requested : Bool
  mut in_frame : Bool
  mut follow_up : Bool
} derive(Debug, ToJson)

///|
pub fn ShellFrameScheduler::new() -> ShellFrameScheduler {
  { requested: false, in_frame: false, follow_up: false }
}

///|
pub fn ShellFrameScheduler::request(self : ShellFrameScheduler) -> Unit {
  if self.in_frame {
    self.follow_up = true
  } else {
    self.requested = true
  }
}

///|
pub fn ShellFrameScheduler::begin_frame(self : ShellFrameScheduler) -> Bool {
  if self.in_frame || !self.requested {
    false
  } else {
    self.requested = false
    self.in_frame = true
    true
  }
}

///|
pub fn ShellFrameScheduler::finish_frame(self : ShellFrameScheduler) -> Bool {
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
pub fn ShellFrameScheduler::requested(self : ShellFrameScheduler) -> Bool {
  self.requested
}

///|
/// Drops pending work when a native surface is detached. A new attach will
/// explicitly request its first frame.
pub fn ShellFrameScheduler::reset(self : ShellFrameScheduler) -> Unit {
  self.requested = false
  self.in_frame = false
  self.follow_up = false
}

///|
pub(all) struct ShellRequestId {
  value : Int
} derive(Eq, Debug, ToJson)

///|
pub struct ShellChannel {
  mut next_request_id : Int
  mut pending : Array[ShellRequestId]
  mut updates : Array[ShellWireUpdate]
} derive(Debug, ToJson)

///|
pub fn ShellChannel::new() -> ShellChannel {
  { next_request_id: 1, pending: [], updates: [] }
}

///|
pub fn ShellChannel::begin_request(self : ShellChannel) -> ShellRequestId {
  let id = { value: self.next_request_id }
  self.next_request_id = self.next_request_id + 1
  self.pending.push(id)
  id
}

///|
pub fn ShellChannel::complete(self : ShellChannel, id : ShellRequestId) -> Bool {
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
pub fn ShellChannel::track_request(
  self : ShellChannel,
  id~ : Int,
) -> ShellRequestId? {
  if id <= 0 || self.pending.any(item => item.value == id) {
    None
  } else {
    let request = { value: id }
    self.pending.push(request)
    Some(request)
  }
}

///|
pub fn ShellChannel::complete_request(self : ShellChannel, id~ : Int) -> Bool {
  match self.pending.search_by(item => item.value == id) {
    Some(index) => {
      ignore(self.pending.remove(index))
      true
    }
    None => false
  }
}

///|
pub fn ShellChannel::reset(self : ShellChannel) -> Unit {
  self.pending = []
  self.updates = []
}

///|
pub fn ShellChannel::pending_count(self : ShellChannel) -> Int {
  self.pending.length()
}

///|
/// A neutral outbound shell update. `payload` stays JSON so this SDK owns
/// transport semantics without importing MoUI host or runtime types.
pub(all) struct ShellWireUpdate {
  kind : String
  request_id : ShellRequestId?
  payload : Json
} derive(Eq, Debug, ToJson)

///|
pub fn ShellChannel::enqueue_update(
  self : ShellChannel,
  kind~ : String,
  payload~ : Json,
  request_id? : ShellRequestId? = None,
) -> Bool {
  if kind == "" {
    return false
  }
  self.updates.push({ kind, request_id, payload })
  true
}

///|
pub fn ShellChannel::drain_updates(
  self : ShellChannel,
) -> Array[ShellWireUpdate] {
  let updates = self.updates
  self.updates = []
  updates
}

///|
pub(all) struct ShellWireEnvelope {
  schema_version : Int
  session_generation : Int
  surface_epoch : Int
  updates : Array[ShellWireUpdate]
} derive(Eq, Debug, ToJson)

///|
pub fn ShellWireEnvelope::new(
  session_generation~ : Int,
  surface_epoch~ : Int,
  updates~ : Array[ShellWireUpdate],
) -> ShellWireEnvelope {
  {
    schema_version: 1,
    session_generation: session_generation.max(1),
    surface_epoch: surface_epoch.max(0),
    updates,
  }
}

///|
pub fn ShellChannel::drain_update_envelope(
  self : ShellChannel,
  session : ShellSession,
) -> ShellWireEnvelope {
  ShellWireEnvelope::new(
    session_generation=session.generation(),
    surface_epoch=session.surface_epoch(),
    updates=self.drain_updates(),
  )
}

///|
fn shell_wire_update_json(update : ShellWireUpdate) -> Json {
  match update.request_id {
    Some(id) =>
      ({ "kind": update.kind, "id": id.value, "payload": update.payload } : Json)
    None => ({ "kind": update.kind, "payload": update.payload } : Json)
  }
}

///|
pub fn ShellWireEnvelope::to_json_string(self : ShellWireEnvelope) -> String {
  (
    {
      "schemaVersion": self.schema_version,
      "sessionGeneration": self.session_generation,
      "surfaceEpoch": self.surface_epoch,
      "updates": self.updates.map(shell_wire_update_json),
    } : Json).stringify()
}

///|
fn shell_wire_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn shell_wire_string(value : Json?) -> String? {
  match value {
    Some(String(text)) if text != "" => Some(text)
    _ => None
  }
}

///|
fn shell_wire_int(value : Json?) -> Int? {
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
fn shell_wire_update(value : Json) -> ShellWireUpdate? {
  guard shell_wire_object(Some(value)) is Some(fields) else { return None }
  guard shell_wire_string(fields.get("kind")) is Some(kind) else { return None }
  guard fields.get("payload") is Some(payload) else { return None }
  let request_id = match fields.get("id") {
    None => None
    Some(Null) => None
    some =>
      match shell_wire_int(some) {
        Some(value) if value > 0 => Some({ value, })
        _ => return None
      }
  }
  Some({ kind, request_id, payload })
}

///|
pub fn parse_wire_envelope_json(text : String) -> ShellWireEnvelope? {
  let parsed = @json.parse(text) catch { _ => return None }
  guard shell_wire_object(Some(parsed)) is Some(root) else { return None }
  guard shell_wire_int(root.get("schemaVersion")) is Some(1) else {
    return None
  }
  guard shell_wire_int(root.get("sessionGeneration"))
    is Some(session_generation) &&
    session_generation > 0 else {
    return None
  }
  guard shell_wire_int(root.get("surfaceEpoch")) is Some(surface_epoch) &&
    surface_epoch >= 0 else {
    return None
  }
  guard root.get("updates") is Some(Array(values)) else { return None }
  let updates : Array[ShellWireUpdate] = []
  for value in values {
    guard shell_wire_update(value) is Some(update) else { return None }
    updates.push(update)
  }
  Some(ShellWireEnvelope::new(session_generation~, surface_epoch~, updates~))
}

///|
/// The one shell-owned transport state for one embedded runtime. It keeps
/// native lifecycle safety independent from MoUI host/runtime semantics.
pub struct ShellEmbeddingTransport {
  session : ShellSession
  scheduler : ShellFrameScheduler
  channel : ShellChannel
}

///|
pub fn ShellEmbeddingTransport::new(
  initial_generation~ : Int,
) -> ShellEmbeddingTransport {
  {
    session: ShellSession::new(generation=initial_generation),
    scheduler: ShellFrameScheduler::new(),
    channel: ShellChannel::new(),
  }
}

///|
pub fn ShellEmbeddingTransport::session_generation(
  self : ShellEmbeddingTransport,
) -> Int {
  self.session.generation()
}

///|
pub fn ShellEmbeddingTransport::surface_epoch(
  self : ShellEmbeddingTransport,
) -> Int {
  self.session.surface_epoch()
}

///|
pub fn ShellEmbeddingTransport::attached(
  self : ShellEmbeddingTransport,
) -> Bool {
  self.session.state() is Attached
}

///|
pub fn ShellEmbeddingTransport::attach(self : ShellEmbeddingTransport) -> Bool {
  self.channel.reset()
  self.scheduler.reset()
  self.session.attach()
}

///|
pub fn ShellEmbeddingTransport::detach(self : ShellEmbeddingTransport) -> Bool {
  let detached = self.session.detach()
  if detached {
    self.channel.reset()
    self.scheduler.reset()
  }
  detached
}

///|
pub fn ShellEmbeddingTransport::destroy(self : ShellEmbeddingTransport) -> Bool {
  let destroyed = self.session.destroy()
  if destroyed {
    self.channel.reset()
    self.scheduler.reset()
  }
  destroyed
}

///|
pub fn ShellEmbeddingTransport::request_frame(
  self : ShellEmbeddingTransport,
) -> Unit {
  if self.attached() {
    self.scheduler.request()
  }
}

///|
pub fn ShellEmbeddingTransport::take_requested_frame(
  self : ShellEmbeddingTransport,
) -> Bool {
  self.attached() && self.scheduler.begin_frame()
}

///|
pub fn ShellEmbeddingTransport::finish_frame(
  self : ShellEmbeddingTransport,
) -> Bool {
  self.attached() && self.scheduler.finish_frame()
}

///|
pub fn ShellEmbeddingTransport::frame_requested(
  self : ShellEmbeddingTransport,
) -> Bool {
  self.attached() && self.scheduler.requested()
}

///|
pub fn ShellEmbeddingTransport::track_request(
  self : ShellEmbeddingTransport,
  id~ : Int,
) -> Bool {
  self.attached() && self.channel.track_request(id~) is Some(_)
}

///|
pub fn ShellEmbeddingTransport::complete_request(
  self : ShellEmbeddingTransport,
  id~ : Int,
) -> Bool {
  self.attached() && self.channel.complete_request(id~)
}

///|
pub fn ShellEmbeddingTransport::enqueue_update(
  self : ShellEmbeddingTransport,
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
pub fn ShellEmbeddingTransport::enqueue_tracked_update(
  self : ShellEmbeddingTransport,
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
pub fn ShellEmbeddingTransport::drain_update_envelope_json(
  self : ShellEmbeddingTransport,
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
pub fn ShellEmbeddingTransport::accepts_response_generation(
  self : ShellEmbeddingTransport,
  generation~ : Int,
) -> Bool {
  self.attached() && generation == self.session.generation()
}

///|
pub(all) enum ShellCapability {
  Surface
  Pointer
  Scroll
  FrameScheduling
  TextInput
  Clipboard
  Accessibility
  PlatformViews
  HostChannel
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ShellPlatformDescriptor {
  platform : ShellPlatform
  shell_api_version : Int
  embedding_api_version : Int
  capabilities : Array[ShellCapability]
} derive(Eq, Debug, ToJson)

///|
pub fn ShellPlatformDescriptor::compatible_with(
  self : ShellPlatformDescriptor,
  shell_api_version~ : Int,
  embedding_api_version~ : Int,
) -> Bool {
  self.negotiate(shell_api_version~, embedding_api_version~) is Compatible
}

///|
pub(all) enum ShellCompatibility {
  Compatible
  ShellApiMismatch
  EmbeddingApiMismatch
  CapabilityMissing(ShellCapability)
} derive(Eq, Debug, ToJson)

///|
pub fn ShellPlatformDescriptor::negotiate(
  self : ShellPlatformDescriptor,
  shell_api_version~ : Int,
  embedding_api_version~ : Int,
  required_capabilities? : Array[ShellCapability] = [],
) -> ShellCompatibility {
  if self.shell_api_version != shell_api_version {
    return ShellApiMismatch
  }
  if self.embedding_api_version != embedding_api_version {
    return EmbeddingApiMismatch
  }
  for capability in required_capabilities {
    if !self.capabilities.any(item => item == capability) {
      return CapabilityMissing(capability)
    }
  }
  Compatible
}

///|
pub fn shell_api_version() -> Int {
  @contract.runner_api_version().major
}

///|
pub fn embedding_api_version() -> Int {
  @contract.embedding_api_version().major
}
