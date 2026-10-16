///|
/// Build a terminal ANSI provider from the renderer-neutral host contract.
///
/// Unlike the Sun raster factory this provider presents to a composition-root
/// `TuiSink` instead of `surface.cpu_present()`: the `PresentTarget` contract
/// carries `PixelFrame` geometry, and ANSI bytes have no width/row_bytes.
/// `host_surface_metrics_error` stays the shared bind gate, so a zero-sized
/// surface is still rejected the same way for every renderer.
pub fn ansi(
  sink~ : TuiSink,
  cell? : CellBox = CellBox::default(),
  diagnostics? : DegradeLog = DegradeLog::new(),
  palette? : TuiPalette = TuiPalette::default(),
) -> @render.RendererProvider {
  let caps = tui_feature_capabilities()
  @render.RendererProvider::new(
    id="tui-ansi",
    descriptor=tui_terminal_ansi_native_descriptor(),
    capabilities=() => caps,
    bind=surface => {
      match @render_common.host_surface_metrics_error(surface) {
        Some(message) => return Rejected(message)
        None => ()
      }
      let renderer = TuiRenderer::new(
        metrics=surface.metrics(),
        sink~,
        cell~,
        diagnostics~,
        palette~,
      )
      Bound(renderer.to_renderer_session())
    },
  )
}

///|
pub fn TuiRenderer::to_renderer_session(
  self : TuiRenderer,
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=metrics => self.resize(metrics),
    render_frame=submission => self.render_frame(submission.frame()),
    text_system=() => self.text_system(),
    present_count=() => self.present_count(),
    // 没有 GPU 资源会丢,也不存在 CPU 回退路径:投影器本身就是最终输出。
    recover=_reason => RecoverySucceeded,
  )
}
