///|
/// Phase 2.2 (ADR 0006 § Context-loss recovery): cross-platform scaffolding
/// for monitoring GPU context-loss signals and deciding when to fall back
/// to `SkiaRasterNative`. Per-platform loss detectors (Metal
/// `MTLDevice deviceLostHandler`, Vulkan `VK_ERROR_DEVICE_LOST`, EGL
/// `EGL_CONTEXT_LOST`, D3D11 `GetDeviceRemovedReason`) feed this module via
/// `report_context_loss`; the renderer thread consults `should_recover` and
/// `should_fallback_to_raster` each frame to drive cache tear-down,
/// context recreation, and the final raster fallback. AppRuntime state is
/// preserved across all transitions: only the renderer-thread-owned GPU
/// resources are recycled.
///
/// The recovery state machine is:
///   Idle -> Lost (context loss reported; 3 VSync deadline starts)
///        -> Recovering (recreation in flight)
///        -> Recovered (recreation succeeded; GPU route resumes)
///        | FallbackToRaster (repeated failure exceeded the budget)
/// The deadline is `3 * vsync_ms` after the loss was reported; on expiry
/// without recovery, the renderer thread falls back to raster.
pub(all) enum RendererRecoveryState {
  /// No context loss has been reported; the GPU route is healthy.
  Idle
  /// A context-loss signal was received. The renderer thread must tear down
  /// GPU caches and recreate the context + surface before
  /// `recovery_deadline_ms`. The payload is the loss reason reported by the
  /// platform detector and the deadline (in milliseconds, host clock).
  Lost(String, Double)
  /// Context + surface recreation is in flight. The renderer thread must
  /// not present GPU frames while in this state; it should drain the
  /// mailbox without beginning new GPU work.
  Recovering
  /// Recreation succeeded; the GPU route is healthy again. The renderer
  /// thread resumes GPU presentation on the next frame.
  Recovered
  /// Repeated recovery failure exceeded the consecutive budget. The
  /// renderer thread must fall back to `SkiaRasterNative` while preserving
  /// `AppRuntime` state. The payload is the final failure reason.
  FallbackToRaster(String)
} derive(Eq, Debug, ToJson)

///|
/// Tunable recovery budget. Per ADR 0006, context-loss recovery must
/// complete within 3 VSyncs. Repeated failure above
/// `max_consecutive_recovery_failures` triggers the raster fallback.
pub(all) struct RendererRecoveryBudget {
  /// VSync interval in milliseconds. Default 16.67 ms (60 Hz).
  vsync_ms : Double
  /// Recovery deadline multiplier. The deadline is
  /// `vsync_ms * recovery_vsync_budget` (default 3).
  recovery_vsync_budget : Int
  /// Maximum consecutive recovery failures before falling back to raster.
  /// Default 2 per ADR 0006 (recovery is retried once; the second failure
  /// falls back).
  max_consecutive_recovery_failures : Int
} derive(Eq, Debug, ToJson)

///|
pub struct RendererRecovery {
  mut state : RendererRecoveryState
  mut loss_count : Int
  mut last_loss_reason : String
  mut last_loss_time_ms : Double
  mut consecutive_failures : Int
  mut recovery_started_for_loss : Bool
  budget : RendererRecoveryBudget
}

///|
pub fn RendererRecoveryBudget::default() -> RendererRecoveryBudget {
  {
    vsync_ms: 16.67,
    recovery_vsync_budget: 3,
    max_consecutive_recovery_failures: 2,
  }
}

///|
/// Builds a custom recovery budget. Useful for testing platform-specific
/// VSync intervals (e.g. 120 Hz) and tighter/looser recovery windows.
pub fn RendererRecoveryBudget::new(
  vsync_ms~ : Double,
  recovery_vsync_budget~ : Int,
  max_consecutive_recovery_failures~ : Int,
) -> RendererRecoveryBudget {
  {
    vsync_ms,
    recovery_vsync_budget,
    max_consecutive_recovery_failures,
  }
}

///|
pub fn RendererRecoveryBudget::recovery_deadline_ms(
  self : RendererRecoveryBudget,
  loss_time_ms : Double,
) -> Double {
  loss_time_ms + self.vsync_ms * Double::from_int(self.recovery_vsync_budget)
}

///|
pub fn RendererRecovery::new(
  budget? : RendererRecoveryBudget = RendererRecoveryBudget::default(),
) -> RendererRecovery {
  {
    state: RendererRecoveryState::Idle,
    loss_count: 0,
    last_loss_reason: "",
    last_loss_time_ms: 0.0,
    consecutive_failures: 0,
    recovery_started_for_loss: false,
    budget,
  }
}

///|
/// Returns the current recovery state. The renderer thread consults this
/// each frame to decide whether to render GPU work, drain only, or fall
/// back to raster.
pub fn RendererRecovery::state(
  self : RendererRecovery,
) -> RendererRecoveryState {
  self.state
}

///|
/// Returns the total number of context-loss events observed since
/// construction. Used by promotion manifests (Phase 2.3) as evidence that
/// recovery has been exercised on matching hardware.
pub fn RendererRecovery::loss_count(self : RendererRecovery) -> Int {
  self.loss_count
}

///|
/// Returns the most recent loss reason reported by a platform detector,
/// or the empty string if no loss has been observed.
pub fn RendererRecovery::last_loss_reason(
  self : RendererRecovery,
) -> String {
  self.last_loss_reason
}

///|
/// Returns the number of consecutive recovery failures since the last
/// successful recovery. Resets to 0 on `report_recovery_succeeded`.
pub fn RendererRecovery::consecutive_failures(
  self : RendererRecovery,
) -> Int {
  self.consecutive_failures
}

///|
/// Returns true when the renderer thread should fall back to
/// `SkiaRasterNative`. Once true, the state is terminal: the renderer
/// thread must not attempt GPU recreation again without an external reset
/// (e.g. a host-driven surface recreation that re-initializes the
/// renderer thread).
pub fn RendererRecovery::should_fallback_to_raster(
  self : RendererRecovery,
) -> Bool {
  match self.state {
    FallbackToRaster(_) => true
    _ => false
  }
}

///|
/// Returns true when the renderer thread should attempt GPU context +
/// surface recreation this frame. The caller must call
/// `report_recovery_started` before beginning recreation and
/// `report_recovery_succeeded` / `report_recovery_failed` once the attempt
/// completes.
pub fn RendererRecovery::should_recover(
  self : RendererRecovery,
  now_ms~ : Double,
) -> Bool {
  match self.state {
    Lost(_, deadline) => now_ms <= deadline
    _ => false
  }
}

///|
/// Returns true when the recovery deadline has expired without a
/// successful recovery. The renderer thread should call
/// `report_recovery_failed` to advance to the next attempt (or the raster
/// fallback).
pub fn RendererRecovery::recovery_deadline_expired(
  self : RendererRecovery,
  now_ms~ : Double,
) -> Bool {
  match self.state {
    Lost(_, deadline) => now_ms > deadline
    _ => false
  }
}

///|
/// Reports a context-loss signal received from the platform detector.
/// Transitions from `Idle` or `Recovered` to `Lost`, stamping the recovery
/// deadline. Calling from `Lost`/`Recovering` records a new loss (the
/// in-flight recovery is treated as failed). Calling from
/// `FallbackToRaster` is a no-op: the renderer thread is no longer on the
/// GPU route.
pub fn RendererRecovery::report_context_loss(
  self : RendererRecovery,
  reason : String,
  now_ms~ : Double,
) -> Unit {
  match self.state {
    FallbackToRaster(_) => return
    _ => ()
  }
  // If a recovery was in flight, count it as a failure.
  if self.recovery_started_for_loss {
    self.consecutive_failures = self.consecutive_failures + 1
    self.recovery_started_for_loss = false
  }
  self.loss_count = self.loss_count + 1
  self.last_loss_reason = reason
  self.last_loss_time_ms = now_ms
  let deadline = self.budget.recovery_deadline_ms(now_ms)
  self.state = Lost(reason, deadline)
}

///|
/// Marks the start of a GPU context + surface recreation attempt. The
/// renderer thread must call this before recreating the context so that
/// subsequent `report_context_loss` calls (e.g. a loss detected during
/// recreation) count as a recovery failure.
pub fn RendererRecovery::report_recovery_started(
  self : RendererRecovery,
) -> Unit {
  match self.state {
    Lost(_, _) => {
      self.state = Recovering
      self.recovery_started_for_loss = true
    }
    _ => ()
  }
}

///|
/// Reports that GPU context + surface recreation succeeded. Resets the
/// consecutive failure count and transitions to `Recovered`. The renderer
/// thread resumes GPU presentation on the next frame.
pub fn RendererRecovery::report_recovery_succeeded(
  self : RendererRecovery,
) -> Unit {
  match self.state {
    Recovering => {
      self.consecutive_failures = 0
      self.recovery_started_for_loss = false
      self.state = Recovered
    }
    _ => ()
  }
}

///|
/// Reports that GPU context + surface recreation failed. If the
/// consecutive failure count exceeds the budget, transitions to
/// `FallbackToRaster`; otherwise transitions back to `Lost` with the
/// original loss reason and a fresh deadline, allowing one retry per
/// ADR 0006.
pub fn RendererRecovery::report_recovery_failed(
  self : RendererRecovery,
  failure_reason : String,
  now_ms~ : Double,
) -> Unit {
  match self.state {
    Recovering => {
      self.recovery_started_for_loss = false
      self.consecutive_failures = self.consecutive_failures + 1
      if self.consecutive_failures >=
        self.budget.max_consecutive_recovery_failures {
        self.state = FallbackToRaster(failure_reason)
      } else {
        // Retry: a fresh deadline so the renderer thread gets another
        // 3-VSync budget for the next attempt.
        let deadline = self.budget.recovery_deadline_ms(now_ms)
        self.state = Lost(self.last_loss_reason, deadline)
      }
    }
    _ => ()
  }
}

///|
/// Transitions the state machine back to `Idle` from `Recovered`. Called by
/// the renderer thread once it has resumed GPU presentation. Calling from
/// any other state is a no-op.
pub fn RendererRecovery::acknowledge_recovered(
  self : RendererRecovery,
) -> Unit {
  match self.state {
    Recovered => self.state = Idle
    _ => ()
  }
}

///|
/// Returns a diagnostic snapshot suitable for inclusion in the mobile
/// runtime manifest (Phase 2.3). The snapshot is read-only; callers
/// should not mutate the recovery state based on this snapshot.
pub fn RendererRecovery::snapshot(
  self : RendererRecovery,
) -> RendererRecoverySnapshot {
  let state_label = match self.state {
    Idle => "idle"
    Lost(_, _) => "lost"
    Recovering => "recovering"
    Recovered => "recovered"
    FallbackToRaster(_) => "fallback-to-raster"
  }
  let deadline = match self.state {
    Lost(_, deadline) => deadline
    _ => 0.0
  }
  let fallback_reason = match self.state {
    FallbackToRaster(reason) => reason
    _ => ""
  }
  {
    state: state_label,
    loss_count: self.loss_count,
    last_loss_reason: self.last_loss_reason,
    last_loss_time_ms: self.last_loss_time_ms,
    recovery_deadline_ms: deadline,
    consecutive_failures: self.consecutive_failures,
    fallback_reason,
  }
}

///|
pub(all) struct RendererRecoverySnapshot {
  state : String
  loss_count : Int
  last_loss_reason : String
  last_loss_time_ms : Double
  recovery_deadline_ms : Double
  consecutive_failures : Int
  fallback_reason : String
} derive(Eq, Debug, ToJson)
