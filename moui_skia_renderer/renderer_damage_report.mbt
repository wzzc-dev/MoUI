///|
/// Where the frame's effective damage was applied.
///
/// - `RetainedSurface`: the CPU raster surface retains its pixels between
///   frames, so the command stream is clipped to the damage union.
/// - `GpuBacking`: a persistent offscreen GPU backing retains its pixels; the
///   complete backing is copied into the fresh host drawable afterwards.
/// - `GpuDrawable`: a direct full redraw into a fresh drawable with no
///   preserved backbuffer. Damage can only be honoured as a full surface.
#derive(Eq, Debug, ToJson)
pub(all) enum SkiaDamageTarget {
  RetainedSurface
  GpuBacking
  GpuDrawable
}

///|
pub fn SkiaDamageTarget::label(self : SkiaDamageTarget) -> String {
  match self {
    RetainedSurface => "retained-raster-surface"
    GpuBacking => "gpu-persistent-backing"
    GpuDrawable => "gpu-fresh-drawable"
  }
}

///|
/// Per-frame damage observation. `requested` is the frame's runtime damage,
/// `effective` is what the renderer actually honoured, and
/// `fallback_reason` is present only when a non-full request degraded to a
/// full-surface redraw. Phase timings are measured with the core monotonic
/// clock in microseconds; `copy` covers the full backing-to-drawable copy (or
/// the CPU readback) and `present` covers the host present call.
pub struct SkiaDamageReport {
  priv requested : @core.DamageRegion
  priv effective : @core.DamageRegion
  priv fallback_reason : String?
  priv target : SkiaDamageTarget
  priv presented : Bool
  priv draw_us : Double
  priv copy_us : Double
  priv present_us : Double
}

///|
fn SkiaDamageReport::new(
  requested~ : @core.DamageRegion,
  effective~ : @core.DamageRegion,
  target~ : SkiaDamageTarget,
  presented~ : Bool,
  draw_us~ : Double,
  copy_us~ : Double,
  present_us~ : Double,
) -> SkiaDamageReport {
  let fallback_reason = match requested {
    FullSurface(_) => None
    _ =>
      match effective {
        FullSurface(reason) => Some(reason)
        _ => None
      }
  }
  {
    requested,
    effective,
    fallback_reason,
    target,
    presented,
    draw_us,
    copy_us,
    present_us,
  }
}

///|
pub fn SkiaDamageReport::requested(
  self : SkiaDamageReport,
) -> @core.DamageRegion {
  self.requested
}

///|
pub fn SkiaDamageReport::effective(
  self : SkiaDamageReport,
) -> @core.DamageRegion {
  self.effective
}

///|
pub fn SkiaDamageReport::fallback_reason(self : SkiaDamageReport) -> String? {
  self.fallback_reason
}

///|
pub fn SkiaDamageReport::target(self : SkiaDamageReport) -> SkiaDamageTarget {
  self.target
}

///|
pub fn SkiaDamageReport::presented(self : SkiaDamageReport) -> Bool {
  self.presented
}

///|
pub fn SkiaDamageReport::draw_us(self : SkiaDamageReport) -> Double {
  self.draw_us
}

///|
pub fn SkiaDamageReport::copy_us(self : SkiaDamageReport) -> Double {
  self.copy_us
}

///|
pub fn SkiaDamageReport::present_us(self : SkiaDamageReport) -> Double {
  self.present_us
}

///|
/// Surface-retention capability of the bound renderer. A persistent offscreen
/// backing and a preserved drawable are different claims: the backing can be
/// updated partially while every fresh drawable still receives a full pixel
/// copy and no partial present is attempted.
pub struct SkiaPartialRepaintReport {
  priv surface_damage : @render.SurfaceDamageCapability
  priv drawable_retained : Bool
  priv persistent_backing : Bool
  priv partial_redraw : Bool
  priv partial_present : Bool
}

///|
fn SkiaPartialRepaintReport::new(
  surface_damage~ : @render.SurfaceDamageCapability,
  drawable_retained~ : Bool,
  persistent_backing~ : Bool,
  partial_redraw~ : Bool,
  partial_present~ : Bool,
) -> SkiaPartialRepaintReport {
  {
    surface_damage,
    drawable_retained,
    persistent_backing,
    partial_redraw,
    partial_present,
  }
}

///|
pub fn SkiaPartialRepaintReport::surface_damage(
  self : SkiaPartialRepaintReport,
) -> @render.SurfaceDamageCapability {
  self.surface_damage
}

///|
pub fn SkiaPartialRepaintReport::drawable_retained(
  self : SkiaPartialRepaintReport,
) -> Bool {
  self.drawable_retained
}

///|
pub fn SkiaPartialRepaintReport::persistent_backing(
  self : SkiaPartialRepaintReport,
) -> Bool {
  self.persistent_backing
}

///|
pub fn SkiaPartialRepaintReport::partial_redraw(
  self : SkiaPartialRepaintReport,
) -> Bool {
  self.partial_redraw
}

///|
pub fn SkiaPartialRepaintReport::partial_present(
  self : SkiaPartialRepaintReport,
) -> Bool {
  self.partial_present
}

///|
/// Resolve the frame damage without capability or initialization gates. Scope
/// commands force a full redraw because clip-scoped composition can affect
/// pixels outside the dirty region.
fn SkiaRasterRenderer::resolve_frame_damage(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @core.DamageRegion {
  let _ = self
  match frame.damage {
    Empty => Empty
    FullSurface(reason) => FullSurface(reason)
    Rects(rects) =>
      if skia_frame_has_scope_commands(frame) {
        @core.DamageRegion::full("scope commands present with damage rects")
      } else {
        match skia_damage_rect_union(rects) {
          Some(rect) => Rects([rect])
          None => Empty
        }
      }
  }
}

///|
fn skia_frame_has_scope_commands(frame : @core.DrawFrame) -> Bool {
  for command in frame.commands {
    match command {
      PushOpacity(_) | PushLayer(_) | PushFilter(_) | PushTransform(_) =>
        return true
      _ => ()
    }
  }
  false
}

///|
/// Damage for the retained CPU raster surface. A freshly created or resized
/// surface has no valid pixels, so the first frame must fully initialize it
/// even when the runtime reports an empty or sub-rect damage region.
fn SkiaRasterRenderer::resolve_retained_surface_damage(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @core.DamageRegion {
  if self.surface_damage is FullSurfaceOnly {
    return @core.DamageRegion::full("surface capability: full-surface-only")
  }
  if !self.surface_initialized {
    return @core.DamageRegion::full(
      "retained raster surface is not initialized",
    )
  }
  self.resolve_frame_damage(frame)
}

///|
/// Damage for the persistent offscreen GPU backing. The backing retains its
/// pixels, so a sub-rect update is valid after its initializing full frame.
/// The host drawable is still treated as uninitialized: the complete backing
/// is copied into every fresh drawable.
fn SkiaRasterRenderer::resolve_gpu_backing_damage(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @core.DamageRegion {
  if self.surface_damage is FullSurfaceOnly {
    return @core.DamageRegion::full("surface capability: full-surface-only")
  }
  if !self.gpu_backing_initialized {
    return @core.DamageRegion::full("GPU backing surface is not initialized")
  }
  self.resolve_frame_damage(frame)
}

///|
/// Damage for the direct host-drawable path. Without the persistent backing a
/// fresh drawable has no preserved backbuffer, so the only honest region is a
/// full-surface overwrite. The reason is carried into the frame observation.
fn SkiaRasterRenderer::resolve_gpu_drawable_damage(
  self : SkiaRasterRenderer,
  frame : @core.DrawFrame,
) -> @core.DamageRegion {
  let _ = frame
  if self.surface_damage is FullSurfaceOnly {
    @core.DamageRegion::full("surface capability: full-surface-only")
  } else {
    @core.DamageRegion::full("host-gpu drawable has no preserved backbuffer")
  }
}
