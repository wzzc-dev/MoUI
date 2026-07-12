///|
pub(all) struct RenderFramePacket {
  sequence : Int
  surface_generation : Int
  input : RenderFrameInput
} derive(Eq, Debug, ToJson)

///|
/// Control message for the renderer mailbox. Per ADR 0006 § Renderer-thread
/// ownership, control messages are ordered and never dropped: resize,
/// detach, context-loss, and shutdown must reach the renderer thread even
/// when the runtime/UI thread is flooding frame submissions. Frame
/// submissions are capacity-two latest-wins (one in-flight + one pending);
/// control messages are appended to an unbounded FIFO queue.
pub(all) enum RendererControlMessage {
  /// Surface size changed; the renderer thread must recreate the window
  /// surface before rendering the next frame.
  Resize(@core.Size)
  /// The host view was detached (e.g. embedded session torn down). The
  /// renderer thread must release the window surface but keep the GPU
  /// context alive for re-attachment.
  Detach
  /// The GPU context was reported lost by the platform. The renderer thread
  /// must tear down GPU caches and recreate the context + surface within
  /// 3 VSyncs, per ADR 0006. The payload is a backend-specific loss reason
  /// (e.g. `MTLDevice deviceLostHandler`, `VK_ERROR_DEVICE_LOST`,
  /// `EGL_CONTEXT_LOST`, `D3D11 GetDeviceRemovedReason`).
  ContextLoss(String)
  /// The renderer thread must exit. Pending frames are dropped. The
  /// renderer thread must release all GPU resources before exiting.
  Shutdown
} derive(Eq, Debug, ToJson)

///|
pub(all) struct RenderFrameMailboxDiagnostics {
  submitted : Int
  started : Int
  completed : Int
  replaced_pending : Int
  rejected_generation : Int
  surface_generation : Int
  in_flight : Bool
  pending : Bool
  control_pending : Int
  control_submitted : Int
  control_drained : Int
} derive(Eq, Debug, ToJson)

///|
pub struct RenderFrameMailbox {
  mut surface_generation : Int
  mut next_sequence : Int
  mut in_flight : RenderFramePacket?
  mut pending : RenderFramePacket?
  mut submitted : Int
  mut started : Int
  mut completed : Int
  mut replaced_pending : Int
  mut rejected_generation : Int
  control_queue : Array[RendererControlMessage]
  mut control_submitted : Int
  mut control_drained : Int
}

///|
pub fn RenderFramePacket::new(
  sequence~ : Int,
  surface_generation~ : Int,
  input : RenderFrameInput,
) -> RenderFramePacket {
  {
    sequence,
    surface_generation,
    input: { ..input, commands: input.commands.copy() },
  }
}

///|
pub fn RenderFrameMailbox::new(
  surface_generation? : Int = 1,
) -> RenderFrameMailbox {
  {
    surface_generation,
    next_sequence: 1,
    in_flight: None,
    pending: None,
    submitted: 0,
    started: 0,
    completed: 0,
    replaced_pending: 0,
    rejected_generation: 0,
    control_queue: [],
    control_submitted: 0,
    control_drained: 0,
  }
}

///|
/// Appends a control message to the ordered queue. Control messages are
/// never dropped and are drained FIFO by the renderer thread before
/// consuming the next frame. Returns the queue depth after submission so
/// callers can detect backpressure (e.g. a host that keeps submitting
/// resize without draining).
pub fn RenderFrameMailbox::submit_control(
  self : RenderFrameMailbox,
  message : RendererControlMessage,
) -> Int {
  self.control_queue.push(message)
  self.control_submitted = self.control_submitted + 1
  self.control_queue.length()
}

///|
/// Returns true when at least one control message is pending. The
/// renderer thread should drain control messages before beginning the next
/// frame: a `Resize` may invalidate the current surface, and `Shutdown`
/// terminates the loop.
pub fn RenderFrameMailbox::has_control(
  self : RenderFrameMailbox,
) -> Bool {
  !self.control_queue.is_empty()
}

///|
/// Drains all pending control messages in submission order. The renderer
/// thread must process every returned message; none are dropped. A
/// `Shutdown` in the returned array signals loop termination.
pub fn RenderFrameMailbox::drain_control(
  self : RenderFrameMailbox,
) -> Array[RendererControlMessage] {
  let drained = self.control_queue.copy()
  self.control_drained = self.control_drained + drained.length()
  self.control_queue.clear()
  drained
}

///|
/// Returns the number of pending control messages without draining.
pub fn RenderFrameMailbox::control_pending(
  self : RenderFrameMailbox,
) -> Int {
  self.control_queue.length()
}

///|
pub fn RenderFrameMailbox::submit(
  self : RenderFrameMailbox,
  input : RenderFrameInput,
) -> Int {
  let sequence = self.next_sequence
  self.next_sequence = self.next_sequence + 1
  let packet = RenderFramePacket::new(
    sequence~,
    surface_generation=self.surface_generation,
    input,
  )
  self.submitted = self.submitted + 1
  if self.pending is Some(_) {
    self.replaced_pending = self.replaced_pending + 1
  }
  self.pending = Some(packet)
  sequence
}

///|
pub fn RenderFrameMailbox::begin_next(
  self : RenderFrameMailbox,
) -> RenderFramePacket? {
  if self.in_flight is Some(_) {
    return None
  }
  match self.pending {
    Some(packet) => {
      self.pending = None
      if packet.surface_generation != self.surface_generation {
        self.rejected_generation = self.rejected_generation + 1
        None
      } else {
        self.in_flight = Some(packet)
        self.started = self.started + 1
        Some(packet)
      }
    }
    None => None
  }
}

///|
pub fn RenderFrameMailbox::complete(
  self : RenderFrameMailbox,
  sequence : Int,
) -> Bool {
  match self.in_flight {
    Some(packet) =>
      if packet.sequence == sequence {
        self.in_flight = None
        self.completed = self.completed + 1
        true
      } else {
        false
      }
    None => false
  }
}

///|
pub fn RenderFrameMailbox::replace_surface_generation(
  self : RenderFrameMailbox,
  generation : Int,
) -> Unit {
  if generation != self.surface_generation {
    self.surface_generation = generation
    self.pending = None
  }
}

///|
pub fn RenderFrameMailbox::diagnostics(
  self : RenderFrameMailbox,
) -> RenderFrameMailboxDiagnostics {
  {
    submitted: self.submitted,
    started: self.started,
    completed: self.completed,
    replaced_pending: self.replaced_pending,
    rejected_generation: self.rejected_generation,
    surface_generation: self.surface_generation,
    in_flight: self.in_flight is Some(_),
    pending: self.pending is Some(_),
    control_pending: self.control_queue.length(),
    control_submitted: self.control_submitted,
    control_drained: self.control_drained,
  }
}
