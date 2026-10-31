///|
test "gpu worker latest wins and completion polling" {
  let worker = @common.GpuRenderWorker::new()
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
  assert_eq(completions[0].token().sequence(), 2)
  assert_true(completions[0].status() is Recorded)
  assert_eq(completions[0].presented_at_ms(), 0.0)
  assert_eq(worker.diagnostics().replaced_pending, 1)
}

///|
test "gpu worker control ordering rejects old generation" {
  let worker = @common.GpuRenderWorker::new()
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let input = @render.RenderFrameInput::new(metrics~, commands=[])
  ignore(worker.submit(input, submitted_at_ms=1.0))
  ignore(
    worker.submit_control(Resize(@core.Size::new(width=20.0, height=20.0))),
  )
  worker.poll(completed_at_ms=2.0)
  let diagnostics = worker.diagnostics()
  assert_eq(diagnostics.surface_generation, 2)
  assert_eq(diagnostics.rejected_generation, 1)
  assert_eq(worker.drain_present_completions().length(), 0)
}

///|
test "gpu worker falls back after two recovery failures" {
  let worker = @common.GpuRenderWorker::new()
  worker.fail_next_context_recovery()
  ignore(worker.submit_control(ContextLoss("test")))
  worker.poll()
  worker.poll()
  worker.fail_next_context_recovery()
  ignore(worker.submit_control(ContextLoss("test-2")))
  worker.poll()
  worker.poll()
  assert_true(worker.state() is FallbackToRaster)
  let completions = worker.drain_present_completions()
  assert_true(completions.any(c => c.status() is FallbackToRaster))
}

///|
/// Control messages drain FIFO and are never dropped, even when frame
/// submissions flood (ADR 0006 § Renderer-thread ownership). Poll consumes
/// every queued control in order: Resize bumps the surface generation before
/// Detach/ContextLoss reset queue state, and Shutdown terminates last.
test "gpu worker control queue drains fifo under frame flood" {
  let worker = @common.GpuRenderWorker::new()
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=100.0, height=80.0),
  )
  let input = @render.RenderFrameInput::new(metrics~, commands=[])
  // Flood frames around the controls; frames do not reorder or drop them.
  ignore(worker.submit(input, submitted_at_ms=1.0))
  ignore(
    worker.submit_control(Resize(@core.Size::new(width=200.0, height=120.0))),
  )
  ignore(worker.submit(input, submitted_at_ms=2.0))
  ignore(worker.submit_control(Detach))
  ignore(worker.submit_control(ContextLoss("metal-device-lost")))
  ignore(worker.submit_control(Shutdown))
  assert_eq(worker.diagnostics().control_pending, 4)
  worker.poll(completed_at_ms=3.0)
  let diagnostics = worker.diagnostics()
  // FIFO observable through state transitions: the Resize generation bump
  // landed, ContextLoss/Detach cleared queue state, Shutdown consumed last.
  assert_eq(diagnostics.control_pending, 0)
  assert_eq(diagnostics.surface_generation, 2)
  assert_true(diagnostics.state is Shutdown)
  assert_eq(diagnostics.completed, 0)
}

///|
/// A `Shutdown` does not implicitly drop pending control messages: the
/// renderer thread observes every earlier control message in order.
test "gpu worker shutdown observes earlier control messages" {
  let worker = @common.GpuRenderWorker::new()
  ignore(worker.submit_control(ContextLoss("vulkan-device-lost")))
  ignore(worker.submit_control(Detach))
  ignore(worker.submit_control(Shutdown))
  worker.poll()
  let diagnostics = worker.diagnostics()
  assert_true(diagnostics.state is Shutdown)
  assert_eq(diagnostics.control_pending, 0)
}
