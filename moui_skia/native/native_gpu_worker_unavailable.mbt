///|
#warnings("-struct_never_constructed")
pub struct NativeGpuRenderWorker {}

///|
pub(all) enum NativeGpuWorkerCompletionStatus {
  PictureRecorded
  Dropped
  ControlAcknowledged
  FallbackToRaster
  Presented
  Unknown(Int)
} derive(Eq, Debug)

///|
pub(all) struct NativeGpuWorkerCompletion {
  sequence : Int64
  control_token : Int64
  surface_generation : Int
  context_generation : Int
  image_resource_revision : Int64
  submitted_at_ms : Double
  processed_at_ms : Double
  presented_at_ms : Double
  status : NativeGpuWorkerCompletionStatus
} derive(Eq, Debug)

///|
pub(all) struct NativeGpuWorkerDiagnostics {
  worker_thread_id : Int64
  submitted : Int64
  completed : Int64
  dropped : Int64
  replaced_pending : Int64
  readback_count : Int64
  surface_generation : Int
  context_generation : Int
  recovery_count : Int64
  resource_cache_bytes : Int64
  control_pending : Int
  completion_pending : Int
} derive(Eq, Debug)

///|
pub fn NativeGpuRenderWorker::new() -> NativeGpuRenderWorker? {
  None
}

///|
pub fn NativeGpuRenderWorker::submit_empty_picture(
  self : NativeGpuRenderWorker,
  image_resource_revision? : Int64 = 0L,
  submitted_at_ms? : Double = 0.0,
) -> Int64 {
  let _ = (self, image_resource_revision, submitted_at_ms)
  0L
}

///|
pub fn NativeGpuRenderWorker::submit_picture(
  self : NativeGpuRenderWorker,
  picture : Picture,
  image_resource_revision? : Int64 = 0L,
  submitted_at_ms? : Double = 0.0,
) -> Int64 {
  let _ = (self, picture, image_resource_revision, submitted_at_ms)
  0L
}

///|
pub fn NativeGpuRenderWorker::submit_control(
  self : NativeGpuRenderWorker,
  control : GpuRenderWorkerControl,
) -> Int64 {
  let _ = (self, control)
  0L
}

///|
pub fn NativeGpuRenderWorker::wait_completion(
  self : NativeGpuRenderWorker,
  timeout_ms? : Int = 1000,
) -> Bool {
  let _ = (self, timeout_ms)
  false
}

///|
pub fn NativeGpuRenderWorker::drain_completions(
  self : NativeGpuRenderWorker,
) -> Array[NativeGpuWorkerCompletion] {
  let _ = self
  []
}

///|
pub fn NativeGpuRenderWorker::diagnostics(
  self : NativeGpuRenderWorker,
) -> NativeGpuWorkerDiagnostics {
  let _ = self
  {
    worker_thread_id: 0L,
    submitted: 0L,
    completed: 0L,
    dropped: 0L,
    replaced_pending: 0L,
    readback_count: 0L,
    surface_generation: 0,
    context_generation: 0,
    recovery_count: 0L,
    resource_cache_bytes: 0L,
    control_pending: 0,
    completion_pending: 0,
  }
}

///|
pub fn NativeGpuRenderWorker::shutdown(self : NativeGpuRenderWorker) -> Unit {
  let _ = self
}
