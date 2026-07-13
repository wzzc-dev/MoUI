///|
test "native gpu picture worker queue is latest wins" {
  let worker = GpuRenderWorker::new(worker_thread_id=7L)
  assert_eq(worker.submit(None, submitted_at_ms=1.0), 1)
  assert_eq(worker.submit(None, submitted_at_ms=2.0), 2)
  worker.poll(gpu_completed_at_ms=3.0, presented_at_ms=4.0)
  let completions = worker.drain_completions()
  assert_eq(completions.length(), 1)
  assert_eq(completions[0].sequence, 2)
  assert_true(
    completions[0].status is GpuRenderCompletionStatus::PictureRecorded,
  )
  assert_eq(completions[0].presented_at_ms, 0.0)
  assert_eq(worker.diagnostics().replaced_pending, 1)
  assert_eq(worker.diagnostics().readback_count, 0)
}

///|
test "native gpu picture worker preserves control fifo" {
  let worker = GpuRenderWorker::new()
  ignore(worker.submit(None))
  ignore(worker.submit_control(GpuRenderWorkerControl::Resize(20, 20)))
  ignore(worker.submit_control(GpuRenderWorkerControl::Detach))
  ignore(worker.submit_control(GpuRenderWorkerControl::Attach(42UL)))
  worker.poll()
  let diagnostics = worker.diagnostics()
  assert_eq(diagnostics.surface_generation, 4)
  assert_eq(diagnostics.control_pending, 0)
  assert_eq(worker.drain_completions().length(), 0)
}

///|
test "native gpu worker runs on an independent thread and acknowledges detach" {
  match NativeGpuRenderWorker::new() {
    Some(worker) => {
      let sequence = match PictureRecorder::new() {
        Some(recorder) => {
          match recorder.begin(8, 8) {
            Some(canvas) => canvas.clear(@skia.Color::blue())
            None => recorder.record_empty(8, 8)
          }
          match recorder.finish() {
            Some(picture) =>
              worker.submit_picture(
                picture,
                image_resource_revision=9L,
                submitted_at_ms=1.0,
              )
            None =>
              worker.submit_empty_picture(
                image_resource_revision=9L,
                submitted_at_ms=1.0,
              )
          }
        }
        None => worker.submit_empty_picture(submitted_at_ms=1.0)
      }
      assert_true(sequence > 0L)
      assert_true(worker.wait_completion(timeout_ms=1000))
      let frames = worker.drain_completions()
      assert_true(
        frames.any(completion => {
          completion.sequence == sequence &&
          completion.image_resource_revision == 9L &&
          completion.submitted_at_ms == 1.0 &&
          completion.processed_at_ms > 0.0 &&
          completion.status is NativeGpuWorkerCompletionStatus::PictureRecorded
        }),
      )

      let detach = worker.submit_control(GpuRenderWorkerControl::Detach)
      assert_true(detach > 0L)
      assert_true(worker.wait_completion(timeout_ms=1000))
      let controls = worker.drain_completions()
      assert_true(
        controls.any(completion => completion.control_token == detach),
      )
      let diagnostics = worker.diagnostics()
      assert_true(diagnostics.worker_thread_id != 0L)
      assert_eq(diagnostics.readback_count, 0L)
      assert_true(diagnostics.surface_generation >= 2)
      assert_eq(diagnostics.resource_cache_bytes, 0L)
      assert_eq(diagnostics.completion_pending, 0)
      worker.shutdown()
    }
    None => fail("native GPU worker should be available on the native target")
  }
}
