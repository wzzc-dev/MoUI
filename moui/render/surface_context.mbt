///|
/// A renderer-neutral pixel frame supplied to a host presenter.
pub(all) struct PixelFrame {
  width : Int
  height : Int
  row_bytes : Int
  scale_factor : Double
  pixels : Bytes
}

///|
pub fn PixelFrame::new(
  width~ : Int,
  height~ : Int,
  row_bytes~ : Int,
  scale_factor~ : Double,
  pixels~ : Bytes,
) -> PixelFrame {
  { width, height, row_bytes, scale_factor, pixels }
}

///|
pub fn PixelFrame::width(self : PixelFrame) -> Int {
  self.width
}

///|
pub fn PixelFrame::height(self : PixelFrame) -> Int {
  self.height
}

///|
pub fn PixelFrame::row_bytes(self : PixelFrame) -> Int {
  self.row_bytes
}

///|
pub fn PixelFrame::scale_factor(self : PixelFrame) -> Double {
  self.scale_factor
}

///|
pub fn PixelFrame::pixels(self : PixelFrame) -> Bytes {
  self.pixels
}

///|
/// A CPU presenter owned by a platform backend. The callback is intentionally
/// expressed in terms of neutral bytes so it cannot depend on a renderer.
pub struct PresentTarget {
  description : String
  present_fn : (PixelFrame) -> Bool
}

///|
pub fn PresentTarget::new(
  description~ : String,
  present~ : (PixelFrame) -> Bool,
) -> PresentTarget {
  { description, present_fn: present }
}

///|
pub fn PresentTarget::description(self : PresentTarget) -> String {
  self.description
}

///|
pub fn PresentTarget::present(self : PresentTarget, frame : PixelFrame) -> Bool {
  (self.present_fn)(frame)
}

///|
/// Opaque GPU lifecycle callbacks supplied by a platform backend. Renderer
/// packages convert their native context/surface values to the opaque handles
/// at this boundary; backend code never names a concrete renderer.
pub struct HostGpuSurfaceBridge {
  descriptor : GpuHostSurfaceDescriptor
  create_surface_fn : (@core.SurfaceMetrics) -> UInt64?
  present_fn : (UInt64) -> Bool
  resize_fn : (@core.SurfaceMetrics) -> Unit
  dispose_fn : () -> Unit
}

///|
pub fn HostGpuSurfaceBridge::new(
  descriptor~ : GpuHostSurfaceDescriptor,
  create_surface~ : (@core.SurfaceMetrics) -> UInt64?,
  present~ : (UInt64) -> Bool,
  resize? : (@core.SurfaceMetrics) -> Unit = _ => (),
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
  metrics : @core.SurfaceMetrics,
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
  metrics : @core.SurfaceMetrics,
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

///|
/// All host capabilities a renderer may consume for one window.
pub struct SurfaceContext {
  surface : SurfaceDescriptor
  surface_id : String
  metrics : @core.SurfaceMetrics
  cpu_present : PresentTarget?
  gpu_surface : HostGpuSurfaceBridge?
  image_source : HostImageSource?
}

///|
pub fn SurfaceContext::new(
  surface~ : SurfaceDescriptor,
  surface_id? : String = "",
  metrics~ : @core.SurfaceMetrics,
  cpu_present? : PresentTarget? = None,
  gpu_surface? : HostGpuSurfaceBridge? = None,
  image_source? : HostImageSource? = None,
) -> SurfaceContext {
  { surface, surface_id, metrics, cpu_present, gpu_surface, image_source }
}

///|
pub fn SurfaceContext::surface(self : SurfaceContext) -> SurfaceDescriptor {
  self.surface
}

///|
pub fn SurfaceContext::surface_id(self : SurfaceContext) -> String {
  self.surface_id
}

///|
pub fn SurfaceContext::metrics(self : SurfaceContext) -> @core.SurfaceMetrics {
  self.metrics
}

///|
pub fn SurfaceContext::cpu_present(self : SurfaceContext) -> PresentTarget? {
  self.cpu_present
}

///|
pub fn SurfaceContext::gpu_surface(
  self : SurfaceContext,
) -> HostGpuSurfaceBridge? {
  self.gpu_surface
}

///|
pub fn SurfaceContext::image_source(self : SurfaceContext) -> HostImageSource? {
  self.image_source
}

///|
/// A renderer binding plus the optional host image loader selected with it.
pub struct RendererBindingPlan {
  binding : RendererProviderBinding
  image_loader : ImageLoader?
  surface : SurfaceDescriptor?
}

///|
pub fn RendererBindingPlan::new(
  binding~ : RendererProviderBinding,
  image_loader? : ImageLoader? = None,
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
) -> ImageLoader? {
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
/// SurfaceContext, so composition roots do not need to know native window
/// types and backend packages do not need to import renderer packages.
pub struct RendererFactory {
  id : String
  bind_fn : (SurfaceContext) -> RendererBindingPlan
}

///|
pub fn RendererFactory::new(
  id~ : String,
  bind~ : (SurfaceContext) -> RendererBindingPlan,
) -> RendererFactory {
  { id, bind_fn: bind }
}

///|
pub fn RendererFactory::id(self : RendererFactory) -> String {
  self.id
}

///|
pub fn RendererFactory::bind(
  self : RendererFactory,
  kit : SurfaceContext,
) -> RendererBindingPlan {
  (self.bind_fn)(kit)
}

///|

///|
pub struct RendererResolution {
  renderer : WindowRenderer
  image_loader : ImageLoader?
}

///|
pub fn RendererResolution::new(
  renderer~ : WindowRenderer,
  image_loader~ : ImageLoader?,
) -> RendererResolution {
  { renderer, image_loader }
}

///|
pub fn RendererResolution::renderer(
  self : RendererResolution,
) -> WindowRenderer {
  self.renderer
}

///|
pub fn RendererResolution::image_loader(
  self : RendererResolution,
) -> ImageLoader? {
  self.image_loader
}
