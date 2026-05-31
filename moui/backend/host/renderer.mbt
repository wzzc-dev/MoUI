///|
pub struct HostWindowRenderer {
  priv resize_fn : (HostSurfaceMetrics) -> Unit
  priv render_fn : (Array[@core.DrawCommand]) -> Unit
  priv text_system_fn : () -> @core.TextSystem
  priv image_resources_fn : () -> Array[@render.ImageResourceRecord]
  priv present_count_fn : () -> Int
  priv dispose_fn : () -> Unit
}

///|
pub fn HostWindowRenderer::new(
  resize~ : (HostSurfaceMetrics) -> Unit,
  render~ : (Array[@core.DrawCommand]) -> Unit,
  text_system~ : () -> @core.TextSystem,
  image_resources? : () -> Array[@render.ImageResourceRecord] = () => [],
  present_count? : () -> Int = () => 0,
  dispose? : () -> Unit = () => (),
) -> HostWindowRenderer {
  {
    resize_fn: resize,
    render_fn: render,
    text_system_fn: text_system,
    image_resources_fn: image_resources,
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
pub fn HostWindowRenderer::present_count(self : HostWindowRenderer) -> Int {
  (self.present_count_fn)()
}

///|
pub fn HostWindowRenderer::dispose(self : HostWindowRenderer) -> Unit {
  (self.dispose_fn)()
}
