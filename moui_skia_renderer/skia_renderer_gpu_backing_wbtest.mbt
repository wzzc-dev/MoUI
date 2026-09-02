///|
fn skia_test_gpu_surface_for_size(
  context : @skia_native.GpuContext?,
  size : @moui_skia.ISize,
) -> @skia_native.Surface? {
  match context {
    None => None
    Some(context) =>
      @skia_native.Surface::gpu_n32_premul(
        context,
        @moui_skia.SurfaceDescriptor::gpu_n32_premul(size),
      )
  }
}

///|
fn skia_test_gpu_surface(
  context : @skia_native.GpuContext?,
) -> @skia_native.Surface? {
  skia_test_gpu_surface_for_size(context, @moui_skia.ISize::new(8, 8))
}

///|
test "GPU resize acquisition failure remains retryable" {
  guard skia_available() else { return () }
  guard @skia_native.Surface::metal_gpu_context_runtime_available() else {
    return ()
  }
  let attempts = Ref(0)
  let target = SkiaPresentTarget::new(description="resize-retry-test", present=_ => {
    false
  })
  let presentations = Ref(0)
  let gpu_target = HostGpuPresentTarget::new(
    description="resize-retry-test",
    create_window_surface=(context, metrics) => {
      attempts.val = attempts.val + 1
      if attempts.val == 2 {
        None
      } else {
        skia_test_gpu_surface_for_size(
          context,
          @moui_skia.ISize::new(
            metrics.physical_size.width.to_int(),
            metrics.physical_size.height.to_int(),
          ),
        )
      }
    },
    present_gpu=(context, _) => {
      presentations.val = presentations.val + 1
      HostGpuPresentOutcome::new(
        succeeded=presentations.val == 1,
        next_surface=if presentations.val == 1 {
          skia_test_gpu_surface_for_size(context, @moui_skia.ISize::new(8, 8))
        } else {
          None
        },
      )
    },
  )
  let renderer = create_with_present_target_and_route(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
    surface_route=MetalGpuSurfaceRoute,
    gpu_target=Some(gpu_target),
  ) catch {
    _ => return ()
  }
  let first = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[],
      damage=@core.DamageRegion::full("attach before resize"),
      clear_color=@core.Color::white(),
    ),
  )
  assert_true(first.presented)
  assert_eq(attempts.val, 1)
  renderer.resize(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=10.0, height=10.0),
    ),
  ) catch {
    _ => return ()
  }
  let result = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[],
      damage=@core.DamageRegion::full("resize retry"),
      clear_color=@core.Color::white(),
    ),
  )
  assert_false(result.presented)
  assert_eq(attempts.val, 3)
  renderer.dispose()
}

///|
test "Metal host GPU backing rotates drawables without CPU readback" {
  guard skia_available() else { return () }
  guard @skia_native.Surface::metal_gpu_context_runtime_available() else {
    return ()
  }
  let presented = Ref(0)
  let target = SkiaPresentTarget::new(description="gpu-backing-test", present=_ => {
    false
  })
  let gpu_target = HostGpuPresentTarget::new(
    description="offscreen-metal-backing-test",
    create_window_surface=(context, _metrics) => skia_test_gpu_surface(context),
    present_gpu=(context, _surface) => {
      presented.val = presented.val + 1
      HostGpuPresentOutcome::new(
        succeeded=true,
        next_surface=skia_test_gpu_surface(context),
      )
    },
  )
  let renderer = create_with_present_target_and_route(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
    surface_route=MetalGpuSurfaceRoute,
    gpu_target=Some(gpu_target),
  ) catch {
    _ => return ()
  }
  let first = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
          @core.Color::white(),
        ),
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=3.0, height=8.0),
          @core.Color::rgba(r=1.0, g=0.0, b=0.0, a=1.0),
        ),
      ],
      damage=@core.DamageRegion::full("initial Metal backing frame"),
      clear_color=@core.Color::white(),
    ),
  )
  assert_true(first.presented)
  assert_true(renderer.last_frame() is None)
  let second = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=3.0, y=0.0, width=5.0, height=8.0),
          @core.Color::rgba(r=0.0, g=0.0, b=1.0, a=1.0),
        ),
      ],
      damage=@core.DamageRegion::Rects([
        @core.Rect::new(x=3.0, y=0.0, width=5.0, height=8.0),
      ]),
      clear_color=@core.Color::white(),
    ),
  )
  assert_true(second.presented)
  assert_true(renderer.last_frame() is None)
  assert_eq(presented.val, 2)
  renderer.dispose()
}
