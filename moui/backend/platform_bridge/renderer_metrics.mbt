///|
/// Convert host surface metrics to renderer surface metrics.
///
/// Single shared implementation with defensive fallbacks (scale factor
/// clamped to 1.0, physical size derived from logical size when absent);
/// the twelve platform providers used to carry private copies.
pub fn renderer_metrics_from_host(
  metrics : @host.HostSurfaceMetrics,
) -> @render.RendererSurfaceMetrics {
  let scale_factor = if metrics.scale_factor > 0.0 {
    metrics.scale_factor
  } else {
    1.0
  }
  let physical_size = @core.Size::new(
    width=if metrics.physical_size.width > 0.0 {
      metrics.physical_size.width
    } else {
      metrics.logical_size.width * scale_factor
    },
    height=if metrics.physical_size.height > 0.0 {
      metrics.physical_size.height
    } else {
      metrics.logical_size.height * scale_factor
    },
  )
  @render.RendererSurfaceMetrics::new(
    logical_size=metrics.logical_size,
    physical_size~,
    scale_factor~,
  )
}
