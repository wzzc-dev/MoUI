///|
pub fn WebGpuWasmRenderer::apply_image_resource_load_completion(
  self : WebGpuWasmRenderer,
  completion : @render.ImageResourceLoadCompletion,
) -> @render.ImageResourceSnapshot {
  self.image_lifecycle.apply_load_completion(completion)
}

///|
fn WebGpuWasmRenderer::record_web_image_commands(
  self : WebGpuWasmRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit {
  for command in commands {
    match command {
      @core.DrawCommand::DrawImage(run) =>
        ignore(self.image_lifecycle.mark_loading(run.source))
      _ => ()
    }
  }
}

///|
fn WebGpuWasmRenderer::refresh_web_image_commands(
  self : WebGpuWasmRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit {
  for command in commands {
    match command {
      @core.DrawCommand::DrawImage(run) =>
        self.sync_web_image_resource(run.source)
      _ => ()
    }
  }
}

///|
fn WebGpuWasmRenderer::sync_web_image_resource(
  self : WebGpuWasmRenderer,
  source : String,
) -> Unit {
  match (self.port.image_resource)(source) {
    Some({ status: @render.ImageResourceStatus::ImageReady, width, height, .. }) =>
      ignore(self.image_lifecycle.mark_ready(source, width~, height~))
    Some({ status: @render.ImageResourceStatus::ImageFailed, diagnostic, .. }) =>
      ignore(self.image_lifecycle.mark_failed(source, diagnostic~))
    Some({ status: @render.ImageResourceStatus::ImageDisposed, .. }) =>
      ignore(self.image_lifecycle.dispose(source))
    Some({ status: @render.ImageResourceStatus::ImageLoading, .. }) =>
      ignore(self.image_lifecycle.mark_loading(source))
    None => ()
  }
}

///|
