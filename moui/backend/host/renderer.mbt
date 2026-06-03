///|
pub struct HostWindowRenderer {
  priv resize_fn : (HostSurfaceMetrics) -> Unit
  priv render_fn : (Array[@core.DrawCommand]) -> Unit
  priv text_system_fn : () -> @core.TextSystem
  priv image_resources_fn : () -> Array[@render.ImageResourceRecord]
  priv image_resource_snapshot_fn : () -> @render.ImageResourceSnapshot
  priv present_count_fn : () -> Int
  priv dispose_fn : () -> Unit
}

///|
pub fn HostWindowRenderer::new(
  resize~ : (HostSurfaceMetrics) -> Unit,
  render~ : (Array[@core.DrawCommand]) -> Unit,
  text_system~ : () -> @core.TextSystem,
  image_resources? : () -> Array[@render.ImageResourceRecord] = () => [],
  image_resource_snapshot? : (() -> @render.ImageResourceSnapshot)? = None,
  present_count? : () -> Int = () => 0,
  dispose? : () -> Unit = () => (),
) -> HostWindowRenderer {
  let image_resource_snapshot = match image_resource_snapshot {
    Some(snapshot) => snapshot
    None => () => @render.ImageResourceSnapshot::from_records(image_resources())
  }
  {
    resize_fn: resize,
    render_fn: render,
    text_system_fn: text_system,
    image_resources_fn: image_resources,
    image_resource_snapshot_fn: image_resource_snapshot,
    present_count_fn: present_count,
    dispose_fn: dispose,
  }
}

///|
pub fn HostWindowRenderer::resize(
  self : HostWindowRenderer,
  metrics : HostSurfaceMetrics,
) -> Unit {
  (self.resize_fn)(metrics)
}

///|
pub fn HostWindowRenderer::render(
  self : HostWindowRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit {
  (self.render_fn)(commands)
}

///|
pub fn HostWindowRenderer::text_system(
  self : HostWindowRenderer,
) -> @core.TextSystem {
  (self.text_system_fn)()
}

///|
pub fn HostWindowRenderer::image_resources(
  self : HostWindowRenderer,
) -> Array[@render.ImageResourceRecord] {
  (self.image_resources_fn)()
}

///|
pub fn HostWindowRenderer::image_resource_snapshot(
  self : HostWindowRenderer,
) -> @render.ImageResourceSnapshot {
  (self.image_resource_snapshot_fn)()
}

///|
pub fn HostWindowRenderer::present_count(self : HostWindowRenderer) -> Int {
  (self.present_count_fn)()
}

///|
pub fn HostWindowRenderer::dispose(self : HostWindowRenderer) -> Unit {
  (self.dispose_fn)()
}
