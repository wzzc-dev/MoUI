///|
/// Renderer-worker protocol lifecycle. This value-level model exercises queue,
/// generation, and recovery behavior; it does not prove a platform present.
pub(all) enum GpuRenderWorkerState {
  Idle
  Lost
  Recovering
  Recovered
  FallbackToRaster
  Shutdown
} derive(Eq, Debug, ToJson)

///|
pub(all) struct GpuRenderWorkerFrame {
  token : @render.FrameToken
  submitted_at_ms : Double
  input : @render.RenderFrameInput
} derive(Debug)

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
  gpu_context_generation : Int
  recovery_count : Int
  recovery_failures : Int
  readback_count : Int
  resource_cache_bytes : Int64
  in_flight : Bool
  pending : Bool
  control_pending : Int
  worker_thread_id : Int
} derive(Eq, Debug, ToJson)

///|
pub struct GpuRenderWorker {
  mut state : GpuRenderWorkerState
  mut surface_generation : Int
  mut gpu_context_generation : Int
  mut next_sequence : Int
  mut in_flight : GpuRenderWorkerFrame?
  mut pending : GpuRenderWorkerFrame?
  controls : Array[@render.RendererControlMessage]
  completions : Array[@render.RenderPresentCompletion]
  mut submitted : Int
  mut started : Int
  mut completed : Int
  mut dropped : Int
  mut replaced_pending : Int
  mut rejected_generation : Int
  mut recovery_count : Int
  mut recovery_failures : Int
  readback_count : Int
  resource_cache_bytes : Int64
  worker_thread_id : Int
  mut fail_next_recovery : Bool
}

///|
pub fn GpuRenderWorker::new(
  surface_generation? : Int = 1,
  worker_thread_id? : Int = 0,
) -> GpuRenderWorker {
  {
    state: GpuRenderWorkerState::Idle,
    surface_generation: surface_generation.max(1),
    gpu_context_generation: 1,
    next_sequence: 1,
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
    readback_count: 0,
    resource_cache_bytes: 0L,
    worker_thread_id,
    fail_next_recovery: false,
  }
}

///|
pub fn GpuRenderWorker::state(self : GpuRenderWorker) -> GpuRenderWorkerState {
  self.state
}

///|
pub fn GpuRenderWorker::surface_generation(self : GpuRenderWorker) -> Int {
  self.surface_generation
}

///|
pub fn GpuRenderWorker::gpu_context_generation(self : GpuRenderWorker) -> Int {
  self.gpu_context_generation
}

///|
pub fn GpuRenderWorker::submit_control(
  self : GpuRenderWorker,
  control : @render.RendererControlMessage,
) -> Int {
  if self.state is GpuRenderWorkerState::Shutdown {
    return self.controls.length()
  }
  self.controls.push(control)
  self.controls.length()
}

///|
/// Make the next context recreation fail. This is intentionally test-only in
/// spirit but public so platform providers can model a failed native probe.
pub fn GpuRenderWorker::fail_next_context_recovery(
  self : GpuRenderWorker,
) -> Unit {
  self.fail_next_recovery = true
}

///|
pub fn GpuRenderWorker::submit(
  self : GpuRenderWorker,
  input : @render.RenderFrameInput,
  token? : @render.FrameToken,
  submitted_at_ms? : Double = 0.0,
) -> @render.RenderFrameResult {
  if self.state is GpuRenderWorkerState::Shutdown ||
    self.state is GpuRenderWorkerState::FallbackToRaster {
    self.dropped = self.dropped + 1
    return @render.RenderFrameResult::new(presented=false, queued=false)
  }
  let resolved_token = token.unwrap_or(
    @render.FrameToken::new(
      surface_generation=self.surface_generation,
      sequence=self.next_sequence,
    ),
  )
  let frame = {
    token: resolved_token,
    submitted_at_ms,
    input: { ..input, commands: input.commands.copy() },
  }
  self.next_sequence = self.next_sequence + 1
  self.submitted = self.submitted + 1
  match self.pending {
    Some(_) => {
      self.replaced_pending = self.replaced_pending + 1
      self.dropped = self.dropped + 1
    }
    None => ()
  }
  self.pending = Some(frame)
  @render.RenderFrameResult::new(presented=false, queued=true)
}

///|
fn GpuRenderWorker::apply_control(
  self : GpuRenderWorker,
  control : @render.RendererControlMessage,
) -> Bool {
  match control {
    @render.RendererControlMessage::Resize(_) => {
      self.surface_generation = self.surface_generation + 1
      self.in_flight = None
      true
    }
    @render.RendererControlMessage::Detach => {
      self.in_flight = None
      self.pending = None
      true
    }
    @render.RendererControlMessage::ContextLoss(_) => {
      if self.state is GpuRenderWorkerState::FallbackToRaster {
        ()
      } else {
        self.state = GpuRenderWorkerState::Lost
        self.in_flight = None
        self.pending = None
      }
      true
    }
    @render.RendererControlMessage::Shutdown => {
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
    GpuRenderWorkerState::Lost => self.state = GpuRenderWorkerState::Recovering
    GpuRenderWorkerState::Recovering =>
      if self.fail_next_recovery {
        self.fail_next_recovery = false
        self.recovery_failures = self.recovery_failures + 1
        if self.recovery_failures >= 2 {
          self.state = GpuRenderWorkerState::FallbackToRaster
          self.completions.push(
            @render.RenderPresentCompletion::new(
              token=@render.FrameToken::new(
                surface_generation=self.surface_generation,
                sequence=0,
              ),
              submitted_at_ms=0.0,
              completed_at_ms=0.0,
              presented_at_ms=0.0,
              status=@render.RenderPresentStatus::FallbackToRaster,
              gpu_context_generation=self.gpu_context_generation,
            ),
          )
        } else {
          self.state = GpuRenderWorkerState::Lost
        }
      } else {
        self.gpu_context_generation = self.gpu_context_generation + 1
        self.recovery_count = self.recovery_count + 1
        self.state = GpuRenderWorkerState::Recovered
        self.recovery_failures = 0
      }
    GpuRenderWorkerState::Recovered => self.state = GpuRenderWorkerState::Idle
    _ => ()
  }
}

///|
/// Process controls first, then at most one frame. Native workers call this
/// from their event loop; fallback-safe providers call it from the host tick.
pub fn GpuRenderWorker::poll(
  self : GpuRenderWorker,
  completed_at_ms? : Double = 0.0,
) -> Unit {
  while !self.controls.is_empty() {
    let control = self.controls.remove(0)
    if !self.apply_control(control) {
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
        if frame.token.surface_generation() != self.surface_generation {
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
      self.in_flight = None
      self.completed = self.completed + 1
      self.completions.push(
        @render.RenderPresentCompletion::new(
          token=frame.token,
          submitted_at_ms=frame.submitted_at_ms,
          completed_at_ms~,
          presented_at_ms=0.0,
          status=@render.RenderPresentStatus::Recorded,
          gpu_context_generation=self.gpu_context_generation,
        ),
      )
      self.state = GpuRenderWorkerState::Idle
    }
    None => ()
  }
}

///|
pub fn GpuRenderWorker::drain_present_completions(
  self : GpuRenderWorker,
) -> Array[@render.RenderPresentCompletion] {
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
    gpu_context_generation: self.gpu_context_generation,
    recovery_count: self.recovery_count,
    recovery_failures: self.recovery_failures,
    readback_count: self.readback_count,
    resource_cache_bytes: self.resource_cache_bytes,
    in_flight: self.in_flight is Some(_),
    pending: self.pending is Some(_),
    control_pending: self.controls.length(),
    worker_thread_id: self.worker_thread_id,
  }
}
