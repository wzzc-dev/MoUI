///|
/// Records what a surface-level `set_drag_region` received, standing in for the
/// AppKit presenter so the app-to-surface path is observable in a unit test.
fn drag_region_surface_spy() -> (Array[@core.Rect?], (@core.Rect?) -> Unit) {
  let calls : Array[@core.Rect?] = []
  (calls, region => calls.push(region))
}

///|
/// The band an immersive app publishes for its self-drawn title strip.
fn drag_region_test_band() -> @core.Rect {
  @core.Rect::new(x=0.0, y=0.0, width=1280.0, height=26.0)
}

///|
fn drag_region_test_window(value : Int) -> @host.WindowId {
  @host.WindowId::new(value)
}

///|
/// End-to-end reachability for the app-facing drag-region API: an app body only
/// touches `@services`, and the declared band still reaches the per-surface
/// native setter. This is the path Studio's immersive top band uses.
test "app-declared drag region reaches the native surface setter" {
  let source = @services.WindowDragRegionSource::new()
  let services = @services.AppServices::new(
    platform=@services.PlatformServices::new(window_drag=source),
  )
  let (calls, set_region) = drag_region_surface_spy()
  let window = drag_region_test_window(1)
  let mut applied : Int? = None
  let mut applied_window : @host.WindowId? = None
  // First tick: the app has declared nothing, so the host stays quiet.
  let (a0, w0) = push_window_drag_region_to_surface(
    source, window, applied, applied_window, true, set_region,
  )
  applied = a0
  applied_window = w0
  inspect(calls.length(), content="0")
  // The app declares its band exactly as an app body would.
  services.platform().window_drag().set_region(Some(drag_region_test_band()))
  let (a1, w1) = push_window_drag_region_to_surface(
    source, window, applied, applied_window, true, set_region,
  )
  applied = a1
  applied_window = w1
  // Exactly one native call, carrying the declared band.
  inspect(calls.length(), content="1")
  assert_true(calls[0] is Some(_))
  match calls[0] {
    Some(rect) => {
      inspect(rect.size.width, content="1280")
      inspect(rect.size.height, content="26")
    }
    None => fail("expected the declared drag band to reach the surface")
  }
}

///|
/// The app republishes its band on every layout pass. Only real geometry
/// changes may reach the native setter, or the host would be spammed.
test "per-layout republishing reaches the native setter only on change" {
  let source = @services.WindowDragRegionSource::new()
  let (calls, set_region) = drag_region_surface_spy()
  let window = drag_region_test_window(1)
  let mut applied : Int? = None
  let mut applied_window : @host.WindowId? = None
  for _ in 0..<30 {
    source.set_region(Some(drag_region_test_band()))
  }
  for _ in 0..<30 {
    let (a, w) = push_window_drag_region_to_surface(
      source, window, applied, applied_window, true, set_region,
    )
    applied = a
    applied_window = w
  }
  inspect(calls.length(), content="1")
  // A real layout change is pushed once, and only once.
  source.set_region(
    Some(@core.Rect::new(x=0.0, y=0.0, width=800.0, height=32.0)),
  )
  let (a2, w2) = push_window_drag_region_to_surface(
    source, window, applied, applied_window, true, set_region,
  )
  applied = a2
  applied_window = w2
  inspect(calls.length(), content="2")
  let (a3, w3) = push_window_drag_region_to_surface(
    source, window, applied, applied_window, true, set_region,
  )
  applied = a3
  applied_window = w3
  inspect(calls.length(), content="2")
  // Leaving immersive mode clears the band.
  source.set_region(None)
  let (a4, w4) = push_window_drag_region_to_surface(
    source, window, applied, applied_window, true, set_region,
  )
  applied = a4
  applied_window = w4
  inspect(calls.length(), content="3")
  assert_true(calls[2] is None)
  let (_, _) = push_window_drag_region_to_surface(
    source, window, applied, applied_window, true, set_region,
  )
  inspect(calls.length(), content="3")
}

///|
/// A band declared before the window can accept it must be retried rather than
/// recorded as applied, otherwise the first declaration is silently lost.
test "a drag region declared before the surface is ready is retried" {
  let source = @services.WindowDragRegionSource::new()
  let (calls, set_region) = drag_region_surface_spy()
  let window = drag_region_test_window(1)
  source.set_region(Some(drag_region_test_band()))
  let (a0, w0) = push_window_drag_region_to_surface(
    source,
    window,
    None,
    None,
    false,
    set_region,
  )
  inspect(calls.length(), content="0")
  debug_inspect(a0, content="None")
  // Still not ready on the next tick: no call, still pending.
  let (a1, w1) = push_window_drag_region_to_surface(
    source, window, a0, w0, false, set_region,
  )
  inspect(calls.length(), content="0")
  // The surface arrives and the pending band lands without republishing.
  let (a2, _) = push_window_drag_region_to_surface(
    source, window, a1, w1, true, set_region,
  )
  inspect(calls.length(), content="1")
  debug_inspect(a2, content="Some(1)")
}

///|
/// The band is per-surface state, so retargeting the active window pushes to
/// the new surface even when the app-declared revision has not changed.
test "retargeting the active window re-pushes the drag region" {
  let source = @services.WindowDragRegionSource::new()
  let (calls, set_region) = drag_region_surface_spy()
  let first = drag_region_test_window(1)
  let second = drag_region_test_window(2)
  source.set_region(Some(drag_region_test_band()))
  let (applied, applied_window) = push_window_drag_region_to_surface(
    source,
    first,
    None,
    None,
    true,
    set_region,
  )
  inspect(calls.length(), content="1")
  // Same window: no extra call.
  let (a1, w1) = push_window_drag_region_to_surface(
    source, first, applied, applied_window, true, set_region,
  )
  inspect(calls.length(), content="1")
  // Different window: the new surface receives its own band.
  let (_, _) = push_window_drag_region_to_surface(
    source, second, a1, w1, true, set_region,
  )
  inspect(calls.length(), content="2")
}

///|
/// Hosts that never receive a drag region must not touch the native setter.
test "a host without a declared drag region never calls the surface setter" {
  let source = @services.WindowDragRegionSource::new()
  let (calls, set_region) = drag_region_surface_spy()
  let window = drag_region_test_window(1)
  let mut applied : Int? = None
  let mut applied_window : @host.WindowId? = None
  for _ in 0..<10 {
    let (a, w) = push_window_drag_region_to_surface(
      source, window, applied, applied_window, true, set_region,
    )
    applied = a
    applied_window = w
  }
  inspect(calls.length(), content="0")
  debug_inspect(applied, content="None")
}
