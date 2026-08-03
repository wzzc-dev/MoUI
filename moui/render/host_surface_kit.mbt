///|
/// A renderer-neutral pixel frame supplied to a host presenter.
pub(all) struct HostPixelFrame {
  width : Int
  height : Int
  row_bytes : Int
  scale_factor : Double
  pixels : Bytes
}

///|
pub fn HostPixelFrame::new(
  width~ : Int,
  height~ : Int,
  row_bytes~ : Int,
  scale_factor~ : Double,
  pixels~ : Bytes,
) -> HostPixelFrame {
  { width, height, row_bytes, scale_factor, pixels }
}

///|
pub fn HostPixelFrame::width(self : HostPixelFrame) -> Int {
  self.width
}

///|
pub fn HostPixelFrame::height(self : HostPixelFrame) -> Int {
  self.height
}

///|
pub fn HostPixelFrame::row_bytes(self : HostPixelFrame) -> Int {
  self.row_bytes
}

///|
pub fn HostPixelFrame::scale_factor(self : HostPixelFrame) -> Double {
  self.scale_factor
}

///|
pub fn HostPixelFrame::pixels(self : HostPixelFrame) -> Bytes {
  self.pixels
}

///|
/// A CPU presenter owned by a platform backend. The callback is intentionally
/// expressed in terms of neutral bytes so it cannot depend on a renderer.
pub struct HostPresentTarget {
  description : String
  present_fn : (HostPixelFrame) -> Bool
}

///|
pub fn HostPresentTarget::new(
  description~ : String,
  present~ : (HostPixelFrame) -> Bool,
) -> HostPresentTarget {
  { description, present_fn: present }
}

///|
pub fn HostPresentTarget::description(self : HostPresentTarget) -> String {
  self.description
}

///|
pub fn HostPresentTarget::present(
  self : HostPresentTarget,
  frame : HostPixelFrame,
) -> Bool {
  (self.present_fn)(frame)
}

///|
/// Opaque GPU lifecycle callbacks supplied by a platform backend. Renderer
/// packages convert their native context/surface values to the opaque handles
/// at this boundary; backend code never names a concrete renderer.
pub struct HostGpuSurfaceBridge {
  descriptor : GpuHostSurfaceDescriptor
  create_surface_fn : (RendererSurfaceMetrics) -> UInt64?
  present_fn : (UInt64) -> Bool
  resize_fn : (RendererSurfaceMetrics) -> Unit
  dispose_fn : () -> Unit
}

///|
pub fn HostGpuSurfaceBridge::new(
  descriptor~ : GpuHostSurfaceDescriptor,
  create_surface~ : (RendererSurfaceMetrics) -> UInt64?,
  present~ : (UInt64) -> Bool,
  resize? : (RendererSurfaceMetrics) -> Unit = _ => (),
  dispose? : () -> Unit = () => (),
) -> HostGpuSurfaceBridge {
  {
    descriptor,
    create_surface_fn: create_surface,
    present_fn: present,
    resize_fn: resize,
    dispose_fn: dispose,
  }
}

///|
pub fn HostGpuSurfaceBridge::descriptor(
  self : HostGpuSurfaceBridge,
) -> GpuHostSurfaceDescriptor {
  self.descriptor
}

///|
pub fn HostGpuSurfaceBridge::create_surface(
  self : HostGpuSurfaceBridge,
  metrics : RendererSurfaceMetrics,
) -> UInt64? {
  (self.create_surface_fn)(metrics)
}

///|
pub fn HostGpuSurfaceBridge::present(
  self : HostGpuSurfaceBridge,
  surface : UInt64,
) -> Bool {
  (self.present_fn)(surface)
}

///|
pub fn HostGpuSurfaceBridge::resize(
  self : HostGpuSurfaceBridge,
  metrics : RendererSurfaceMetrics,
) -> Unit {
  (self.resize_fn)(metrics)
}

///|
pub fn HostGpuSurfaceBridge::dispose(self : HostGpuSurfaceBridge) -> Unit {
  (self.dispose_fn)()
}

///|
/// Renderer-neutral image source supplied by a platform backend. It only
/// reads opaque bytes; format detection and decoding stay in renderer packages.
pub struct HostImageSource {
  read_fn : (String) -> Bytes?
}

///|
pub fn HostImageSource::new(read~ : (String) -> Bytes?) -> HostImageSource {
  { read_fn: read }
}

///|
pub fn HostImageSource::read(self : HostImageSource, source : String) -> Bytes? {
  (self.read_fn)(source)
}

///|
/// Renderer-owned byte decoder used to build a host async image loader.
pub struct RendererImageDecoder {
  decode_fn : (String, Bytes?) -> ImageResourceLoadCompletion
}

///|
pub fn RendererImageDecoder::new(
  decode~ : (String, Bytes?) -> ImageResourceLoadCompletion,
) -> RendererImageDecoder {
  { decode_fn: decode }
}

///|
pub fn RendererImageDecoder::decode(
  self : RendererImageDecoder,
  source : String,
  bytes : Bytes?,
) -> ImageResourceLoadCompletion {
  (self.decode_fn)(source, bytes)
}

///|
pub fn RendererImageDecoder::loader(
  self : RendererImageDecoder,
  image_source : HostImageSource?,
) -> HostAsyncImageLoader {
  HostAsyncImageLoader::new(start_load=(_window_id, source, complete) => {
    let bytes = match image_source {
      Some(reader) => reader.read(source)
      None => None
    }
    complete(self.decode(source, bytes))
    None
  })
}

///|
/// All host capabilities a renderer may consume for one window.
pub struct HostSurfaceKit {
  surface : SurfaceDescriptor
  surface_id : String
  metrics : RendererSurfaceMetrics
  cpu_present : HostPresentTarget?
  gpu_surface : HostGpuSurfaceBridge?
  image_source : HostImageSource?
}

///|
pub fn HostSurfaceKit::new(
  surface~ : SurfaceDescriptor,
  surface_id? : String = "",
  metrics~ : RendererSurfaceMetrics,
  cpu_present? : HostPresentTarget? = None,
  gpu_surface? : HostGpuSurfaceBridge? = None,
  image_source? : HostImageSource? = None,
) -> HostSurfaceKit {
  { surface, surface_id, metrics, cpu_present, gpu_surface, image_source }
}

///|
pub fn HostSurfaceKit::surface(self : HostSurfaceKit) -> SurfaceDescriptor {
  self.surface
}

///|
pub fn HostSurfaceKit::surface_id(self : HostSurfaceKit) -> String {
  self.surface_id
}

///|
pub fn HostSurfaceKit::metrics(self : HostSurfaceKit) -> RendererSurfaceMetrics {
  self.metrics
}

///|
pub fn HostSurfaceKit::cpu_present(self : HostSurfaceKit) -> HostPresentTarget? {
  self.cpu_present
}

///|
pub fn HostSurfaceKit::gpu_surface(
  self : HostSurfaceKit,
) -> HostGpuSurfaceBridge? {
  self.gpu_surface
}

///|
pub fn HostSurfaceKit::image_source(self : HostSurfaceKit) -> HostImageSource? {
  self.image_source
}

///|
/// A renderer binding plus the optional host image loader selected with it.
pub struct RendererBindingPlan {
  binding : RendererProviderBinding
  image_loader : HostAsyncImageLoader?
  surface : SurfaceDescriptor?
}

///|
pub fn RendererBindingPlan::new(
  binding~ : RendererProviderBinding,
  image_loader? : HostAsyncImageLoader? = None,
  surface? : SurfaceDescriptor? = None,
) -> RendererBindingPlan {
  { binding, image_loader, surface }
}

///|
pub fn RendererBindingPlan::binding(
  self : RendererBindingPlan,
) -> RendererProviderBinding {
  self.binding
}

///|
pub fn RendererBindingPlan::image_loader(
  self : RendererBindingPlan,
) -> HostAsyncImageLoader? {
  self.image_loader
}

///|
pub fn RendererBindingPlan::surface(
  self : RendererBindingPlan,
) -> SurfaceDescriptor? {
  self.surface
}

///|
/// A delayed factory. It is evaluated after a platform window has supplied a
/// HostSurfaceKit, so composition roots do not need to know native window
/// types and backend packages do not need to import renderer packages.
pub struct RendererBindingFactory {
  id : String
  bind_fn : (HostSurfaceKit) -> RendererBindingPlan
}

///|
pub fn RendererBindingFactory::new(
  id~ : String,
  bind~ : (HostSurfaceKit) -> RendererBindingPlan,
) -> RendererBindingFactory {
  { id, bind_fn: bind }
}

///|
pub fn RendererBindingFactory::id(self : RendererBindingFactory) -> String {
  self.id
}

///|
pub fn RendererBindingFactory::bind(
  self : RendererBindingFactory,
  kit : HostSurfaceKit,
) -> RendererBindingPlan {
  (self.bind_fn)(kit)
}

///|

///|
pub struct HostRendererResolution {
  renderer : HostWindowRenderer
  image_loader : HostAsyncImageLoader?
}

///|
pub fn HostRendererResolution::new(
  renderer~ : HostWindowRenderer,
  image_loader~ : HostAsyncImageLoader?,
) -> HostRendererResolution {
  { renderer, image_loader }
}

///|
pub fn HostRendererResolution::renderer(
  self : HostRendererResolution,
) -> HostWindowRenderer {
  self.renderer
}

///|
pub fn HostRendererResolution::image_loader(
  self : HostRendererResolution,
) -> HostAsyncImageLoader? {
  self.image_loader
}

///|
/// Bind and negotiate factories in registration order. The first provider
/// accepting the host surface wins.
pub fn resolve_host_renderer(
  factories : Array[RendererBindingFactory],
  kit : HostSurfaceKit,
) -> HostRendererResolution? {
  for factory in factories {
    let plan = factory.bind(kit)
    let binding = plan.binding()
    let surface = match plan.surface() {
      Some(surface) => surface
      None => kit.surface()
    }
    match (binding.provider().negotiate)(surface) {
      SurfaceNegotiationResult::SurfaceAccepted(bound) =>
        return Some(
          HostRendererResolution::new(
            renderer=(binding.create_host_renderer)(kit.metrics(), bound),
            image_loader=plan.image_loader(),
          ),
        )
      SurfaceNegotiationResult::SurfaceRejected(_) => ()
    }
  }
  None
}
