///|
test "gpu worker latest wins and completion polling" {
  let worker = GpuRenderWorker::new()
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let input = @render.RenderFrameInput::new(metrics~, commands=[])
  let first = worker.submit(input, submitted_at_ms=1.0)
  let second = worker.submit(
    @render.RenderFrameInput::new(metrics~, commands=[]),
    submitted_at_ms=2.0,
  )
  assert_true(first.queued)
  assert_true(second.queued)
  worker.poll(completed_at_ms=3.0)
  let completions = worker.drain_present_completions()
  assert_eq(completions.length(), 1)
  assert_eq(completions[0].frame_sequence(), 2)
  assert_true(completions[0].status() is @render.RenderPresentStatus::Recorded)
  assert_eq(completions[0].presented_at_ms(), 0.0)
  assert_eq(worker.diagnostics().replaced_pending, 1)
}

///|
test "gpu worker control ordering rejects old generation" {
  let worker = GpuRenderWorker::new()
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let input = @render.RenderFrameInput::new(metrics~, commands=[])
  ignore(worker.submit(input, submitted_at_ms=1.0))
  ignore(
    worker.submit_control(
      @render.RendererControlMessage::Resize(
        @core.Size::new(width=20.0, height=20.0),
      ),
    ),
  )
  worker.poll(completed_at_ms=2.0)
  let diagnostics = worker.diagnostics()
  assert_eq(diagnostics.surface_generation, 2)
  assert_eq(diagnostics.rejected_generation, 1)
  assert_eq(worker.drain_present_completions().length(), 0)
}

///|
test "gpu worker falls back after two recovery failures" {
  let worker = GpuRenderWorker::new()
  worker.fail_next_context_recovery()
  ignore(
    worker.submit_control(@render.RendererControlMessage::ContextLoss("test")),
  )
  worker.poll()
  worker.poll()
  worker.fail_next_context_recovery()
  ignore(
    worker.submit_control(@render.RendererControlMessage::ContextLoss("test-2")),
  )
  worker.poll()
  worker.poll()
  assert_true(worker.state() is GpuRenderWorkerState::FallbackToRaster)
  let completions = worker.drain_present_completions()
  assert_true(
    completions.any(c => {
      c.status() is @render.RenderPresentStatus::FallbackToRaster
    }),
  )
}
