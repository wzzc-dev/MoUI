///|
/// Build a direct-Metal provider for a host GPU surface. The platform backend
/// owns the window and its `CAMetalLayer`; this provider only configures that
/// layer and draws into it, so nothing here creates a device-backed surface of
/// its own (ADR 0044 boundary: Apple frameworks yes, graphics libraries no).
///
/// The composition root injects the native text engine, which is why this
/// module depends on no text provider: the same Metal route can be driven by
/// CoreText, DirectWrite or Fontconfig coverage.
pub fn metal(text_engine~ : NativeTextEngine) -> @render.RendererProvider {
  let caps = metal_feature_capabilities()
  let cache = @native_text.NativeTextCache::new_with_engine(text_engine)
  @render.RendererProvider::new(
    id="metal-direct",
    descriptor=metal_renderer_descriptor(caps),
    capabilities=() => caps,
    bind=surface => {
      match @render_common.host_surface_metrics_error(surface) {
        Some(message) => return Rejected(message)
        None => ()
      }
      guard surface.native_surface() is Some(native_surface) else {
        return Rejected("metal requires a native surface capability")
      }
      let context = metal_context_create()
      guard context != 0UL else { return Rejected("metal device unavailable") }
      guard metal_context_prepare(context, native_surface.surface_handle()) == 1 else {
        metal_context_release(context)
        return Rejected(
          "metal could not prepare the host surface layer or its render pipelines",
        )
      }
      Bound(
        MetalRenderer::new(
          metrics=surface.metrics(),
          context~,
          layer=native_surface.surface_handle(),
          cache~,
          image_source=surface
            .image_source()
            .unwrap_or(@render.HostImageSource::unavailable()),
        ).to_renderer_session(native_surface=Some(native_surface)),
      )
    },
  )
}

///|
fn MetalRenderer::to_renderer_session(
  self : MetalRenderer,
  native_surface~ : @render.NativeSurface? = None,
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=metrics => {
      match native_surface {
        Some(surface) => surface.resize(metrics)
        None => ()
      }
      self.resize(metrics)
    },
    render_frame=submission => self.render_frame(submission.frame()),
    text_system=() => @native_text.native_text_system_with_cache(self.cache),
    present_count=() => self.present_count(),
    recover=_reason => {
      RecoveryFailed(
        "metal direct has no gpu recovery path before plan stage L4",
      )
    },
    dispose=() => self.dispose(),
    image_source=self.image_source,
    image_decoder=Some(metal_image_decoder()),
    image_records=() => self.images.lifecycle.snapshot(),
    apply_image_load_completion=completion => {
      apply_metal_image_completion(
        self.images,
        context=self.context,
        completion,
      )
    },
    native_surface~,
  )
}
