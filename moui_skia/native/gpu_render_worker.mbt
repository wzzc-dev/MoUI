///|
pub(all) enum GpuRenderWorkerState {
  Idle
  Lost
  Recovering
  Recovered
  FallbackToRaster
  Shutdown
} derive(Eq, Debug)

///|
pub(all) enum GpuRenderWorkerControl {
  Attach(UInt64)
  AttachSurface(UInt64, UInt64)
  Resize(Int, Int)
  Detach
  ContextLoss(String)
  Shutdown
} derive(Eq, Debug)

///|
pub(all) enum GpuRenderCompletionStatus {
  PictureRecorded
  Presented
  Dropped
  FallbackToRaster
} derive(Eq, Debug)

///|
pub(all) struct GpuRenderCompletion {
  sequence : Int
  surface_generation : Int
  image_resource_revision : Int64
  submitted_at_ms : Double
  gpu_completed_at_ms : Double
  presented_at_ms : Double
  status : GpuRenderCompletionStatus
  context_generation : Int
} derive(Eq, Debug)

///|
pub(all) struct GpuRenderWorkerDiagnostics {
  state : GpuRenderWorkerState
  submitted : Int
  started : Int
  completed : Int
  dropped : Int
  replaced_pending : Int
  rejected_generation : Int
  surface_generation : Int
  context_generation : Int
  recovery_count : Int
  recovery_failures : Int
  readback_count : Int
  resource_cache_bytes : Int64
  control_pending : Int
  in_flight : Bool
  pending : Bool
  worker_thread_id : Int64
} derive(Eq, Debug)

///|
struct GpuRenderPictureFrame {
  sequence : Int
  surface_generation : Int
  image_resource_revision : Int64
  submitted_at_ms : Double
  picture : Picture?
}

///|
/// Capacity-two native-picture queue. Platform integrations drive `poll` only
/// from the renderer worker thread; the queue never invokes MoonBit callbacks.
pub struct GpuRenderWorker {
  mut state : GpuRenderWorkerState
  mut next_sequence : Int
  mut surface_generation : Int
  mut context_generation : Int
  mut in_flight : GpuRenderPictureFrame?
  mut pending : GpuRenderPictureFrame?
  controls : Array[GpuRenderWorkerControl]
  completions : Array[GpuRenderCompletion]
  mut submitted : Int
  mut started : Int
  mut completed : Int
  mut dropped : Int
  mut replaced_pending : Int
  mut rejected_generation : Int
  mut recovery_count : Int
  mut recovery_failures : Int
  mut fail_next_recovery : Bool
  resource_cache_bytes : Int64
  worker_thread_id : Int64
}

///|
pub fn GpuRenderWorker::new(
  surface_generation? : Int = 1,
  worker_thread_id? : Int64 = 0L,
) -> GpuRenderWorker {
  {
    state: GpuRenderWorkerState::Idle,
    next_sequence: 1,
    surface_generation: surface_generation.max(1),
    context_generation: 1,
    in_flight: None,
    pending: None,
    controls: [],
    completions: [],
    submitted: 0,
    started: 0,
    completed: 0,
    dropped: 0,
    replaced_pending: 0,
    rejected_generation: 0,
    recovery_count: 0,
    recovery_failures: 0,
    fail_next_recovery: false,
    resource_cache_bytes: 0L,
    worker_thread_id,
  }
}

///|
pub fn GpuRenderWorker::submit(
  self : GpuRenderWorker,
  picture : Picture?,
  image_resource_revision? : Int64 = 0L,
  submitted_at_ms? : Double = 0.0,
) -> Int {
  if self.state is GpuRenderWorkerState::Shutdown ||
    self.state is GpuRenderWorkerState::FallbackToRaster {
    self.dropped = self.dropped + 1
    return 0
  }
  let sequence = self.next_sequence
  self.next_sequence = self.next_sequence + 1
  self.submitted = self.submitted + 1
  if self.pending is Some(_) {
    self.replaced_pending = self.replaced_pending + 1
    self.dropped = self.dropped + 1
  }
  self.pending = Some({
    sequence,
    surface_generation: self.surface_generation,
    image_resource_revision,
    submitted_at_ms,
    picture,
  })
  sequence
}

///|
pub fn GpuRenderWorker::submit_control(
  self : GpuRenderWorker,
  control : GpuRenderWorkerControl,
) -> Int {
  if self.state is GpuRenderWorkerState::Shutdown {
    return self.controls.length()
  }
  self.controls.push(control)
  self.controls.length()
}

///|
pub fn GpuRenderWorker::fail_next_context_recovery(
  self : GpuRenderWorker,
) -> Unit {
  self.fail_next_recovery = true
}

///|
fn GpuRenderWorker::apply_control(
  self : GpuRenderWorker,
  control : GpuRenderWorkerControl,
) -> Bool {
  match control {
    Attach(_) | AttachSurface(_, _) | Resize(_, _) => {
      self.surface_generation = self.surface_generation + 1
      self.in_flight = None
      true
    }
    Detach => {
      self.surface_generation = self.surface_generation + 1
      self.in_flight = None
      self.pending = None
      true
    }
    ContextLoss(_) => {
      if self.state is GpuRenderWorkerState::FallbackToRaster {
        ()
      } else {
        self.state = GpuRenderWorkerState::Lost
        self.in_flight = None
        self.pending = None
      }
      true
    }
    Shutdown => {
      self.state = GpuRenderWorkerState::Shutdown
      self.in_flight = None
      self.pending = None
      false
    }
  }
}

///|
fn GpuRenderWorker::recover_if_needed(self : GpuRenderWorker) -> Unit {
  match self.state {
    Lost => self.state = GpuRenderWorkerState::Recovering
    Recovering =>
      if self.fail_next_recovery {
        self.fail_next_recovery = false
        self.recovery_failures = self.recovery_failures + 1
        if self.recovery_failures >= 2 {
          self.state = GpuRenderWorkerState::FallbackToRaster
          self.completions.push({
            sequence: 0,
            surface_generation: self.surface_generation,
            image_resource_revision: 0L,
            submitted_at_ms: 0.0,
            gpu_completed_at_ms: 0.0,
            presented_at_ms: 0.0,
            status: GpuRenderCompletionStatus::FallbackToRaster,
            context_generation: self.context_generation,
          })
        } else {
          self.state = GpuRenderWorkerState::Lost
        }
      } else {
        self.context_generation = self.context_generation + 1
        self.recovery_count = self.recovery_count + 1
        self.recovery_failures = 0
        self.state = GpuRenderWorkerState::Recovered
      }
    Recovered => self.state = GpuRenderWorkerState::Idle
    _ => ()
  }
}

///|
pub fn GpuRenderWorker::poll(
  self : GpuRenderWorker,
  gpu_completed_at_ms? : Double = 0.0,
  presented_at_ms? : Double = 0.0,
) -> Unit {
  let _ = presented_at_ms
  while !self.controls.is_empty() {
    if !self.apply_control(self.controls.remove(0)) {
      return ()
    }
  }
  self.recover_if_needed()
  if self.state is GpuRenderWorkerState::Lost ||
    self.state is GpuRenderWorkerState::Recovering ||
    self.state is GpuRenderWorkerState::FallbackToRaster ||
    self.state is GpuRenderWorkerState::Shutdown {
    return ()
  }
  if self.in_flight is None {
    match self.pending {
      Some(frame) => {
        self.pending = None
        if frame.surface_generation != self.surface_generation {
          self.rejected_generation = self.rejected_generation + 1
          self.dropped = self.dropped + 1
        } else {
          self.in_flight = Some(frame)
          self.started = self.started + 1
        }
      }
      None => ()
    }
  }
  match self.in_flight {
    Some(frame) => {
      match frame.picture {
        Some(picture) => ignore(picture.is_available())
        None => ()
      }
      self.in_flight = None
      self.completed = self.completed + 1
      self.completions.push({
        sequence: frame.sequence,
        surface_generation: frame.surface_generation,
        image_resource_revision: frame.image_resource_revision,
        submitted_at_ms: frame.submitted_at_ms,
        gpu_completed_at_ms,
        presented_at_ms: 0.0,
        status: GpuRenderCompletionStatus::PictureRecorded,
        context_generation: self.context_generation,
      })
      self.state = GpuRenderWorkerState::Idle
    }
    None => ()
  }
}

///|
pub fn GpuRenderWorker::drain_completions(
  self : GpuRenderWorker,
) -> Array[GpuRenderCompletion] {
  let result = self.completions.copy()
  self.completions.clear()
  result
}

///|
pub fn GpuRenderWorker::diagnostics(
  self : GpuRenderWorker,
) -> GpuRenderWorkerDiagnostics {
  {
    state: self.state,
    submitted: self.submitted,
    started: self.started,
    completed: self.completed,
    dropped: self.dropped,
    replaced_pending: self.replaced_pending,
    rejected_generation: self.rejected_generation,
    surface_generation: self.surface_generation,
    context_generation: self.context_generation,
    recovery_count: self.recovery_count,
    recovery_failures: self.recovery_failures,
    readback_count: 0,
    resource_cache_bytes: self.resource_cache_bytes,
    control_pending: self.controls.length(),
    in_flight: self.in_flight is Some(_),
    pending: self.pending is Some(_),
    worker_thread_id: self.worker_thread_id,
  }
}
