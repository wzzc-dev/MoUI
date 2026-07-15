///|
pub fn run_renderer_smoke() -> Unit raise @wgpu_mbt.WgpuError {
  @wgpu_renderer.native_renderer_smoke(
    platform_label="linux",
    text_engine=linux_text_engine(
      @wgpu_renderer.NativeTextEngineSetting::PlatformDefault,
    ),
  )
  assert_linux_wgpu_async_repaint_proof()
  println(
    "MoUI renderer smoke asyncImageSecondFrame passed late-completion repaint-request second-frame-pixels",
  )
}

///|
fn assert_linux_wgpu_async_repaint_proof() -> Unit {
  let loader = wgpu_native_image_loader()
  let window_id = @host.HostWindowId::new(710)
  let lifecycle = @render.ImageResourceLifecycle::new()
  let source = linux_wgpu_proof_png_data_uri()
  ignore(lifecycle.mark_loading(source))
  let renderer = @host.HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=@host.HostRendererImageCapability::new(
      image_resource_snapshot=Some(() => lifecycle.snapshot_with_revision()),
      apply_image_resource_load_completion=Some(completion => {
        lifecycle.apply_load_completion(completion)
      }),
    ),
  )
  let tracker = @host.HostImageResourceRepaintTracker::new()
  ignore(tracker.record_presented(window_id, renderer))
  let redraws : Array[@host.HostWindowId] = []
  let completion_source = @host.HostImageResourceCompletionSource::new(
    tracker~,
    window_open=id => id == window_id,
    request_redraw=id => redraws.push(id),
  )
  let scheduled = loader.schedule_loading_resources(
    window_id, renderer, completion_source,
  )
  if scheduled.loading_count() < 1 || scheduled.scheduled_count() < 1 {
    abort("Linux WGPU smoke async image was not scheduled")
  }
  if completion_source.diagnostics().redraw_requested_count() < 1 ||
    redraws.length() < 1 {
    abort("Linux WGPU smoke async image did not request repaint")
  }
  match lifecycle.lookup(source) {
    Some(record) =>
      if record.status != @render.ImageResourceStatus::ImageReady {
        abort("Linux WGPU smoke async image did not become ready")
      }
    None => abort("Linux WGPU smoke async image record missing")
  }
}

///|
fn linux_wgpu_proof_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}
