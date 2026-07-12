///|
pub(all) struct RenderFramePacket {
  sequence : Int
  surface_generation : Int
  input : RenderFrameInput
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
  }
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
  }
}
