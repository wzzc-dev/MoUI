///|
/// Validate the neutral metrics every provider receives before it attempts to
/// inspect CPU or native-surface capabilities.
pub fn host_surface_metrics_error(surface : @render.HostSurface) -> String? {
  let metrics = surface.metrics()
  if metrics.logical_size.width < 1.0 ||
    metrics.logical_size.height < 1.0 ||
    metrics.scale_factor <= 0.0 {
    Some(
      "invalid host surface dimensions: " +
      "\{metrics.logical_size.width}x\{metrics.logical_size.height} @ " +
      "\{metrics.scale_factor}x",
    )
  } else {
    None
  }
}
