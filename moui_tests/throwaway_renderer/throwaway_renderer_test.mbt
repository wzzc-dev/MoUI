///|
/// E7 acceptance (ADR 0007): a new renderer hangs onto the composition root
/// with one registration line and zero changes to core/host/runtime/other
/// renderers. This test IS the new renderer's registration surface — it
/// imports only its own package plus the public core/render/runtime APIs.
test "throwaway renderer registers through AppBuilder and binds in registry order" {
  // The one registration line a composition root adds for a new renderer.
  let builder = @runtime.run_app(
    "throwaway",
    @runtime.AppRuntime::new_view(
      root=@views.text("throwaway"),
      size=@core.Size::new(width=120.0, height=80.0),
    ),
  ).render(throwaway_provider())
  assert_eq(builder.renderer_providers.length(), 1)
  assert_eq(builder.renderer_providers[0].id(), "throwaway")

  // The registry binds in registration order and yields a live session.
  let surface = @render.HostSurface::new(
    surface_id="throwaway-surface",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=120.0, height=80.0),
      scale_factor=2.0,
    ),
    cpu_present=Some(
      @render.PresentTarget::new(description="throwaway presenter", present=_ => {
        true
      }),
    ),
  )
  let session = @render_common.resolve_renderer(
    builder.renderer_providers,
    surface,
  )
  assert_true(session is Some(_))
  // The provider's bind side effect ran exactly once (registration-order
  // first match).
  assert_eq(throwaway_bind_count(), 1)
}
