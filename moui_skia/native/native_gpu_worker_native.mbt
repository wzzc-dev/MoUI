///|
priv type NativeGpuWorkerHandle

///|
extern "C" fn native_gpu_worker_new() -> NativeGpuWorkerHandle = "moonbit_skia_native_gpu_worker_new"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_is_null(worker : NativeGpuWorkerHandle) -> Bool = "moonbit_skia_native_gpu_worker_is_null"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_submit_empty(
  worker : NativeGpuWorkerHandle,
  image_resource_revision : Int64,
  submitted_at_ms : Double,
) -> Int64 = "moonbit_skia_native_gpu_worker_submit_empty"

///|
#borrow(worker, picture)
extern "C" fn native_gpu_worker_submit_picture(
  worker : NativeGpuWorkerHandle,
  picture : PictureHandle,
  image_resource_revision : Int64,
  submitted_at_ms : Double,
) -> Int64 = "moonbit_skia_native_gpu_worker_submit"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_submit_control(
  worker : NativeGpuWorkerHandle,
  kind : Int,
  handle : UInt64,
  auxiliary_handle : UInt64,
  width : Int,
  height : Int,
) -> Int64 = "moonbit_skia_native_gpu_worker_submit_control"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_count(
  worker : NativeGpuWorkerHandle,
) -> Int = "moonbit_skia_native_gpu_worker_completion_count"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_wait_completion(
  worker : NativeGpuWorkerHandle,
  timeout_ms : Int,
) -> Bool = "moonbit_skia_native_gpu_worker_wait_completion"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_sequence(
  worker : NativeGpuWorkerHandle,
) -> Int64 = "moonbit_skia_native_gpu_worker_completion_sequence"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_control_token(
  worker : NativeGpuWorkerHandle,
) -> Int64 = "moonbit_skia_native_gpu_worker_completion_control_token"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_status(
  worker : NativeGpuWorkerHandle,
) -> Int = "moonbit_skia_native_gpu_worker_completion_status"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_surface_generation(
  worker : NativeGpuWorkerHandle,
) -> Int = "moonbit_skia_native_gpu_worker_completion_surface_generation"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_context_generation(
  worker : NativeGpuWorkerHandle,
) -> Int = "moonbit_skia_native_gpu_worker_completion_context_generation"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_image_resource_revision(
  worker : NativeGpuWorkerHandle,
) -> Int64 = "moonbit_skia_native_gpu_worker_completion_image_resource_revision"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_submitted_at_ms(
  worker : NativeGpuWorkerHandle,
) -> Double = "moonbit_skia_native_gpu_worker_completion_submitted_at_ms"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_processed_at_ms(
  worker : NativeGpuWorkerHandle,
) -> Double = "moonbit_skia_native_gpu_worker_completion_processed_at_ms"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_presented_at_ms(
  worker : NativeGpuWorkerHandle,
) -> Double = "moonbit_skia_native_gpu_worker_completion_presented_at_ms"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_pop_completion(
  worker : NativeGpuWorkerHandle,
) -> Unit = "moonbit_skia_native_gpu_worker_pop_completion"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_thread_id(
  worker : NativeGpuWorkerHandle,
) -> Int64 = "moonbit_skia_native_gpu_worker_thread_id"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_submitted(
  worker : NativeGpuWorkerHandle,
) -> Int64 = "moonbit_skia_native_gpu_worker_submitted"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completed(
  worker : NativeGpuWorkerHandle,
) -> Int64 = "moonbit_skia_native_gpu_worker_completed"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_dropped(
  worker : NativeGpuWorkerHandle,
) -> Int64 = "moonbit_skia_native_gpu_worker_dropped"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_replaced_pending(
  worker : NativeGpuWorkerHandle,
) -> Int64 = "moonbit_skia_native_gpu_worker_replaced_pending"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_surface_generation(
  worker : NativeGpuWorkerHandle,
) -> Int = "moonbit_skia_native_gpu_worker_surface_generation"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_context_generation(
  worker : NativeGpuWorkerHandle,
) -> Int = "moonbit_skia_native_gpu_worker_context_generation"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_recovery_count(
  worker : NativeGpuWorkerHandle,
) -> Int64 = "moonbit_skia_native_gpu_worker_recovery_count"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_resource_cache_bytes(
  worker : NativeGpuWorkerHandle,
) -> Int64 = "moonbit_skia_native_gpu_worker_resource_cache_bytes"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_control_pending(
  worker : NativeGpuWorkerHandle,
) -> Int = "moonbit_skia_native_gpu_worker_control_pending"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_completion_pending(
  worker : NativeGpuWorkerHandle,
) -> Int = "moonbit_skia_native_gpu_worker_completion_pending"

///|
#borrow(worker)
extern "C" fn native_gpu_worker_shutdown(
  worker : NativeGpuWorkerHandle,
) -> Unit = "moonbit_skia_native_gpu_worker_shutdown"

///|
pub struct NativeGpuRenderWorker {
  priv handle : NativeGpuWorkerHandle
}

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
fn native_gpu_worker_completion_status_from_int(
  value : Int,
) -> NativeGpuWorkerCompletionStatus {
  match value {
    1 => NativeGpuWorkerCompletionStatus::PictureRecorded
    2 => NativeGpuWorkerCompletionStatus::Dropped
    3 => NativeGpuWorkerCompletionStatus::ControlAcknowledged
    4 => NativeGpuWorkerCompletionStatus::FallbackToRaster
    5 => NativeGpuWorkerCompletionStatus::Presented
    value => NativeGpuWorkerCompletionStatus::Unknown(value)
  }
}

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
  let handle = native_gpu_worker_new()
  if native_gpu_worker_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn NativeGpuRenderWorker::submit_empty_picture(
  self : NativeGpuRenderWorker,
  image_resource_revision? : Int64 = 0L,
  submitted_at_ms? : Double = 0.0,
) -> Int64 {
  native_gpu_worker_submit_empty(
    self.handle,
    image_resource_revision,
    submitted_at_ms,
  )
}

///|
/// Retains the native `SkPicture` before enqueueing it. The worker thread sees
/// only the retained Skia reference and POD metadata, never the MoonBit object.
pub fn NativeGpuRenderWorker::submit_picture(
  self : NativeGpuRenderWorker,
  picture : Picture,
  image_resource_revision? : Int64 = 0L,
  submitted_at_ms? : Double = 0.0,
) -> Int64 {
  native_gpu_worker_submit_picture(
    self.handle,
    picture.handle,
    image_resource_revision,
    submitted_at_ms,
  )
}

///|
pub fn NativeGpuRenderWorker::submit_control(
  self : NativeGpuRenderWorker,
  control : GpuRenderWorkerControl,
) -> Int64 {
  match control {
    Attach(handle) =>
      native_gpu_worker_submit_control(self.handle, 1, handle, 0UL, 0, 0)
    AttachSurface(handle, auxiliary_handle) =>
      native_gpu_worker_submit_control(
        self.handle,
        1,
        handle,
        auxiliary_handle,
        0,
        0,
      )
    Resize(width, height) =>
      native_gpu_worker_submit_control(self.handle, 2, 0UL, 0UL, width, height)
    Detach => native_gpu_worker_submit_control(self.handle, 3, 0UL, 0UL, 0, 0)
    ContextLoss(_) =>
      native_gpu_worker_submit_control(self.handle, 4, 0UL, 0UL, 0, 0)
    Shutdown => native_gpu_worker_submit_control(self.handle, 5, 0UL, 0UL, 0, 0)
  }
}

///|
pub fn NativeGpuRenderWorker::wait_completion(
  self : NativeGpuRenderWorker,
  timeout_ms? : Int = 1000,
) -> Bool {
  native_gpu_worker_wait_completion(self.handle, timeout_ms.max(0))
}

///|
pub fn NativeGpuRenderWorker::drain_completions(
  self : NativeGpuRenderWorker,
) -> Array[NativeGpuWorkerCompletion] {
  let result : Array[NativeGpuWorkerCompletion] = []
  while native_gpu_worker_completion_count(self.handle) > 0 {
    result.push({
      sequence: native_gpu_worker_completion_sequence(self.handle),
      control_token: native_gpu_worker_completion_control_token(self.handle),
      surface_generation: native_gpu_worker_completion_surface_generation(
        self.handle,
      ),
      context_generation: native_gpu_worker_completion_context_generation(
        self.handle,
      ),
      image_resource_revision: native_gpu_worker_completion_image_resource_revision(
        self.handle,
      ),
      submitted_at_ms: native_gpu_worker_completion_submitted_at_ms(self.handle),
      processed_at_ms: native_gpu_worker_completion_processed_at_ms(self.handle),
      presented_at_ms: native_gpu_worker_completion_presented_at_ms(self.handle),
      status: native_gpu_worker_completion_status_from_int(
        native_gpu_worker_completion_status(self.handle),
      ),
    })
    native_gpu_worker_pop_completion(self.handle)
  }
  result
}

///|
pub fn NativeGpuRenderWorker::diagnostics(
  self : NativeGpuRenderWorker,
) -> NativeGpuWorkerDiagnostics {
  {
    worker_thread_id: native_gpu_worker_thread_id(self.handle),
    submitted: native_gpu_worker_submitted(self.handle),
    completed: native_gpu_worker_completed(self.handle),
    dropped: native_gpu_worker_dropped(self.handle),
    replaced_pending: native_gpu_worker_replaced_pending(self.handle),
    readback_count: 0L,
    surface_generation: native_gpu_worker_surface_generation(self.handle),
    context_generation: native_gpu_worker_context_generation(self.handle),
    recovery_count: native_gpu_worker_recovery_count(self.handle),
    resource_cache_bytes: native_gpu_worker_resource_cache_bytes(self.handle),
    control_pending: native_gpu_worker_control_pending(self.handle),
    completion_pending: native_gpu_worker_completion_pending(self.handle),
  }
}

///|
pub fn NativeGpuRenderWorker::shutdown(self : NativeGpuRenderWorker) -> Unit {
  native_gpu_worker_shutdown(self.handle)
}
