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
/// A CPU presenter owned by a platform backend. The callback is expressed in
/// neutral bytes and does not depend on a renderer module.
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
/// Renderer-neutral image source supplied by a platform backend. Format
/// detection and decoding stay in the selected renderer module.
pub struct HostImageSource {
  read_fn : (String) -> Bytes?
}

///|
pub fn HostImageSource::new(read~ : (String) -> Bytes?) -> HostImageSource {
  { read_fn: read }
}

///|
pub fn HostImageSource::unavailable() -> HostImageSource {
  HostImageSource::new(read=_ => None)
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
/// Object-safe native-surface operations. Handles have no platform or graphics
/// API tag in the root contract; the selected renderer interprets them using
/// its composition-root platform policy.
pub(open) trait NativeSurfaceCapability {
  fn surface_handle(Self) -> UInt64
  fn display_handle(Self) -> UInt64?
  fn acquire(Self, @core.SurfaceMetrics) -> UInt64?
  fn present(Self, UInt64) -> Bool
  fn resize(Self, @core.SurfaceMetrics) -> Unit
  fn dispose(Self) -> Unit
}

///|
priv struct ClosureNativeSurfaceCapability {
  surface_handle : UInt64
  display_handle : UInt64?
  acquire_fn : (@core.SurfaceMetrics) -> UInt64?
  present_fn : (UInt64) -> Bool
  resize_fn : (@core.SurfaceMetrics) -> Unit
  dispose_fn : () -> Unit
  mut disposed : Bool
}

///|
impl NativeSurfaceCapability for ClosureNativeSurfaceCapability with fn surface_handle(
  self,
) {
  self.surface_handle
}

///|
impl NativeSurfaceCapability for ClosureNativeSurfaceCapability with fn display_handle(
  self,
) {
  self.display_handle
}

///|
impl NativeSurfaceCapability for ClosureNativeSurfaceCapability with fn acquire(
  self,
  metrics,
) {
  (self.acquire_fn)(metrics)
}

///|
impl NativeSurfaceCapability for ClosureNativeSurfaceCapability with fn present(
  self,
  surface,
) {
  (self.present_fn)(surface)
}

///|
impl NativeSurfaceCapability for ClosureNativeSurfaceCapability with fn resize(
  self,
  metrics,
) {
  (self.resize_fn)(metrics)
}

///|
impl NativeSurfaceCapability for ClosureNativeSurfaceCapability with fn dispose(
  self,
) {
  if !self.disposed {
    self.disposed = true
    (self.dispose_fn)()
  }
}

///|
/// Opaque wrapper around native surface operations. Construction rejects zero
/// surface handles and zero display handles.
pub struct NativeSurface {
  capability : &NativeSurfaceCapability
}

///|
pub fn NativeSurface::new(
  surface_handle~ : UInt64,
  display_handle? : UInt64? = None,
  acquire? : (@core.SurfaceMetrics) -> UInt64? = _ => None,
  present? : (UInt64) -> Bool = _ => false,
  resize? : (@core.SurfaceMetrics) -> Unit = _ => (),
  dispose? : () -> Unit = () => (),
) -> NativeSurface? {
  if surface_handle == 0UL || display_handle == Some(0UL) {
    return None
  }
  let capability = ClosureNativeSurfaceCapability::{
    surface_handle,
    display_handle,
    acquire_fn: acquire,
    present_fn: present,
    resize_fn: resize,
    dispose_fn: dispose,
    disposed: false,
  }
  Some({ capability: capability as &NativeSurfaceCapability })
}

///|
pub fn NativeSurface::surface_handle(self : NativeSurface) -> UInt64 {
  self.capability.surface_handle()
}

///|
pub fn NativeSurface::display_handle(self : NativeSurface) -> UInt64? {
  self.capability.display_handle()
}

///|
pub fn NativeSurface::acquire(
  self : NativeSurface,
  metrics : @core.SurfaceMetrics,
) -> UInt64? {
  self.capability.acquire(metrics)
}

///|
pub fn NativeSurface::present(self : NativeSurface, surface : UInt64) -> Bool {
  self.capability.present(surface)
}

///|
pub fn NativeSurface::resize(
  self : NativeSurface,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  self.capability.resize(metrics)
}

///|
pub fn NativeSurface::dispose(self : NativeSurface) -> Unit {
  self.capability.dispose()
}

///|
/// Object-safe capabilities supplied by one platform window.
pub(open) trait HostSurfaceCapability {
  fn surface_id(Self) -> String
  fn metrics(Self) -> @core.SurfaceMetrics
  fn cpu_present(Self) -> PresentTarget?
  fn native_surface(Self) -> NativeSurface?
  fn image_source(Self) -> HostImageSource?
}

///|
priv struct ClosureHostSurfaceCapability {
  surface_id : String
  metrics : @core.SurfaceMetrics
  cpu_present : PresentTarget?
  native_surface : NativeSurface?
  image_source : HostImageSource?
}

///|
impl HostSurfaceCapability for ClosureHostSurfaceCapability with fn surface_id(
  self,
) {
  self.surface_id
}

///|
impl HostSurfaceCapability for ClosureHostSurfaceCapability with fn metrics(
  self,
) {
  self.metrics
}

///|
impl HostSurfaceCapability for ClosureHostSurfaceCapability with fn cpu_present(
  self,
) {
  self.cpu_present
}

///|
impl HostSurfaceCapability for ClosureHostSurfaceCapability with fn native_surface(
  self,
) {
  self.native_surface
}

///|
impl HostSurfaceCapability for ClosureHostSurfaceCapability with fn image_source(
  self,
) {
  self.image_source
}

///|
/// Opaque surface wrapper passed from a platform backend to renderer providers.
pub struct HostSurface {
  capability : &HostSurfaceCapability
}

///|
pub fn HostSurface::new(
  surface_id? : String = "",
  metrics~ : @core.SurfaceMetrics,
  cpu_present? : PresentTarget? = None,
  native_surface? : NativeSurface? = None,
  image_source? : HostImageSource? = None,
) -> HostSurface {
  let capability = ClosureHostSurfaceCapability::{
    surface_id,
    metrics,
    cpu_present,
    native_surface,
    image_source,
  }
  { capability: capability as &HostSurfaceCapability }
}

///|
pub fn HostSurface::from_capability(
  capability : &HostSurfaceCapability,
) -> HostSurface {
  { capability, }
}

///|
pub fn HostSurface::surface_id(self : HostSurface) -> String {
  self.capability.surface_id()
}

///|
pub fn HostSurface::metrics(self : HostSurface) -> @core.SurfaceMetrics {
  self.capability.metrics()
}

///|
pub fn HostSurface::cpu_present(self : HostSurface) -> PresentTarget? {
  self.capability.cpu_present()
}

///|
pub fn HostSurface::native_surface(self : HostSurface) -> NativeSurface? {
  self.capability.native_surface()
}

///|
pub fn HostSurface::image_source(self : HostSurface) -> HostImageSource? {
  self.capability.image_source()
}
