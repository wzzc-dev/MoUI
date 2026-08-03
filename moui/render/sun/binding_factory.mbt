///|
/// Build a Sun CPU raster factory from the renderer-neutral host contract.
pub fn raster() -> @render.RendererBindingFactory {
  let image_decoder = sun_image_decoder()
  @render.RendererBindingFactory::new(id="sun-raster", bind=kit => {
    let target = match kit.cpu_present() {
      Some(host) =>
        SunPresentTarget::new(description=host.description(), present=frame => {
          host.present(
            @render.HostPixelFrame::new(
              width=frame.width(),
              height=frame.height(),
              row_bytes=frame.row_bytes(),
              scale_factor=frame.scale_factor(),
              pixels=frame.bytes(),
            ),
          )
        })
      None =>
        SunPresentTarget::new(description="missing host CPU presenter", present=_ => {
          false
        })
    }
    let provider = create_sun_provider(create_sun=metrics => {
      create_with_present_target(metrics, target, async_image_loading=true) catch {
        err => abort(err.message())
      }
    })
    @render.RendererBindingPlan::new(
      binding=@render.RendererProviderBinding::new(provider~, create_host_renderer=(
        metrics,
        _bound,
      ) => {
        create_with_present_target(metrics, target, async_image_loading=true).to_host_window_renderer() catch {
          err => abort(err.message())
        }
      }),
      image_loader=Some(image_decoder.loader(kit.image_source())),
    )
  })
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
pub fn SunRasterRenderer::to_host_window_renderer(
  self : SunRasterRenderer,
) -> @render.HostWindowRenderer {
  @render.HostWindowRenderer::new(
    resize=metrics => {
      self.resize(metrics) catch {
        err => println("error resizing Sun renderer: \{err.message()}")
      }
    },
    render=commands => {
      self.render(commands) catch {
        err => println("error rendering Sun frame: \{err.message()}")
      }
    },
    render_frame=Some(frame => self.render_frame(frame)),
    text_system=() => self.text_system(),
    present_count=() => self.present_count(),
    dispose=() => self.dispose(),
    image=@render.HostRendererImageCapability::new(
      image_resources=() => self.image_resources(),
      image_resource_snapshot=Some(() => self.image_resource_snapshot()),
      apply_image_resource_load_completion=Some(completion => {
        self.apply_image_resource_load_completion(completion)
      }),
      set_image_resource_change_callback=callback => {
        self.set_image_resource_change_callback(callback)
      },
    ),
    platform_view=@render.HostRendererPlatformViewCapability::new(
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
