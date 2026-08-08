///|
/// Build a Sun CPU raster provider from the renderer-neutral host contract.
pub fn raster() -> @render.RendererProvider {
  let image_decoder = sun_image_decoder()
  let caps = sun_feature_capabilities()
  @render.RendererProvider::new(
    id="sun-raster",
    descriptor=sun_raster_native_descriptor(),
    capabilities=() => caps,
    bind=surface => {
      match @render_common.host_surface_metrics_error(surface) {
        Some(message) => return @render.RendererBindResult::Rejected(message)
        None => ()
      }
      guard surface.cpu_present() is Some(host) else {
        return @render.RendererBindResult::Rejected(
          "sun-raster requires a CPU presenter",
        )
      }
      let target = SunPresentTarget::new(description=host.description(), present=frame => {
        host.present(
          @render.PixelFrame::new(
            width=frame.width(),
            height=frame.height(),
            row_bytes=frame.row_bytes(),
            scale_factor=frame.scale_factor(),
            pixels=frame.bytes(),
          ),
        )
      })
      let renderer = create_with_present_target(
        surface.metrics(),
        target,
        async_image_loading=true,
      ) catch {
        err =>
          return @render.RendererBindResult::Rejected(
            "sun-raster unavailable: " + err.message(),
          )
      }
      @render.RendererBindResult::Bound(
        renderer.to_renderer_session(
          image_source=surface.image_source().unwrap_or(
            @render.HostImageSource::unavailable(),
          ),
          image_decoder=Some(image_decoder),
        ),
      )
    },
  )
}

///|
fn sun_image_decoder() -> @render.RendererImageDecoder {
  @render.RendererImageDecoder::new(decode=(source, bytes) => {
    match bytes {
      Some(data) =>
        sun_image_load_completion_from_bytes(source, data, background_io=true)
      None => sun_image_load_completion(source)
    }
  })
}

///|
pub fn SunRasterRenderer::to_renderer_session(
  self : SunRasterRenderer,
  image_source? : @render.HostImageSource = @render.HostImageSource::unavailable(),
  image_decoder? : @render.RendererImageDecoder? = None,
) -> @render.RendererSession {
  @render.RendererSession::new(
    resize=metrics => {
      self.resize(metrics) catch {
        err => println("error resizing Sun renderer: \{err.message()}")
      }
    },
    render_frame=submission => self.render_frame(submission.frame()),
    text_system=() => self.text_system(),
    present_count=() => self.present_count(),
    recover=_reason => @render.RecoveryResult::FallbackToCpu,
    dispose=() => self.dispose(),
    image_records=() => self.image_resources(),
    apply_image_load_completion=completion =>
      self.apply_image_resource_load_completion(completion),
    image_source~,
    image_decoder~,
    platform_view=@render.RendererPlatformViewCapability::new(
      draw_platform_view_pixels=fn(
        pixels,
        src_width,
        src_height,
        src_stride,
        dst_x,
        dst_y,
        dst_width,
        dst_height,
      ) {
        self.draw_platform_view_pixels(
          pixels, src_width, src_height, src_stride, dst_x, dst_y, dst_width, dst_height,
        )
      },
      set_platform_view_draw_fn=draw_fn => {
        self.set_platform_view_draw_fn(draw_fn)
      },
    ),
  )
}
