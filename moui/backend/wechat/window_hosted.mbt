///|
/// WeChat Mini Program window-hosted helpers.
/// Provides surface metrics and input handling for the canvas host.

///|
pub fn canvas_metrics(
  logical_width~ : Double,
  logical_height~ : Double,
  scale_factor? : Double = 1.0,
) -> @host.HostSurfaceMetrics {
  @host.HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=logical_width, height=logical_height),
    scale_factor~,
  )
}

///|
pub fn host_metrics_to_dpi_size(
  metrics : @host.HostSurfaceMetrics,
) -> @dpi.Size {
  @dpi.LogicalSize::LogicalSize(
    metrics.logical_size.width,
    metrics.logical_size.height,
  ).into_size()
}
