///|
/// Recording spy standing in for a platform host's native `set_drag_region`.
/// Returns `true` (the call "landed") so tests can count real native calls.
fn drag_region_spy() -> (Array[@core.Rect?], (@core.Rect?) -> Bool) {
  let calls : Array[@core.Rect?] = []
  (
    calls,
    region => {
      calls.push(region)
      true
    },
  )
}

///|
test "window drag region publishes declaratively and defaults to cleared" {
  let source = @services.WindowDragRegionSource::new()
  inspect(source.region() is None, content="true")
  inspect(source.revision(), content="0")
  source.set_region(
    Some(@core.Rect::new(x=0.0, y=0.0, width=320.0, height=26.0)),
  )
  debug_inspect(
    source.region(),
    content="Some({ origin: { x: 0, y: 0 }, size: { width: 320, height: 26 } })",
  )
  inspect(source.revision(), content="1")
}

///|
test "re-declaring the same drag region every frame is idempotent" {
  let source = @services.WindowDragRegionSource::new()
  let band = Some(@core.Rect::new(x=0.0, y=0.0, width=1280.0, height=26.0))
  let (calls, set_region) = drag_region_spy()
  let mut applied : Int? = None
  // Layout republishes the band on every pass; the host polls each tick.
  for _ in 0..<60 {
    source.set_region(band)
    applied = @services.apply_window_drag_region(source, applied, set_region)
  }
  inspect(source.revision(), content="1")
  // Exactly one native call for sixty identical declarations.
  inspect(calls.length(), content="1")
  debug_inspect(applied, content="Some(1)")
  // A real change costs exactly one more call.
  source.set_region(
    Some(@core.Rect::new(x=0.0, y=0.0, width=800.0, height=32.0)),
  )
  applied = @services.apply_window_drag_region(source, applied, set_region)
  inspect(calls.length(), content="2")
  // Clearing is idempotent too: the first clear pushes once, the second is
  // skipped because the host already knows about the cleared revision.
  source.set_region(None)
  applied = @services.apply_window_drag_region(source, applied, set_region)
  source.set_region(None)
  ignore(@services.apply_window_drag_region(source, applied, set_region))
  inspect(calls.length(), content="3")
  assert_true(calls[2] is None)
}

///|
test "an idle host with no declared drag region makes no native calls" {
  let source = @services.WindowDragRegionSource::new()
  let (calls, set_region) = drag_region_spy()
  let mut applied : Int? = None
  for _ in 0..<10 {
    applied = @services.apply_window_drag_region(source, applied, set_region)
  }
  inspect(calls.length(), content="0")
  debug_inspect(applied, content="None")
}

///|
test "a drag region declared before the window exists is retried, not lost" {
  let source = @services.WindowDragRegionSource::new()
  let band = Some(@core.Rect::new(x=0.0, y=0.0, width=320.0, height=26.0))
  let calls : Array[@core.Rect?] = []
  // Host rejects the first two attempts because no native window exists yet.
  let mut ready = false
  let set_region : (@core.Rect?) -> Bool = region => {
    calls.push(region)
    ready
  }
  source.set_region(band)
  let mut applied = @services.apply_window_drag_region(source, None, set_region)
  debug_inspect(applied, content="None")
  applied = @services.apply_window_drag_region(source, applied, set_region)
  debug_inspect(applied, content="None")
  inspect(calls.length(), content="2")
  // Window arrives: the pending declaration is applied without republishing.
  ready = true
  applied = @services.apply_window_drag_region(source, applied, set_region)
  debug_inspect(applied, content="Some(1)")
  inspect(calls.length(), content="3")
  // And it is not pushed again afterwards.
  ignore(@services.apply_window_drag_region(source, applied, set_region))
  inspect(calls.length(), content="3")
}

///|
test "app reaches the drag region through the standard platform services" {
  let source = @services.WindowDragRegionSource::new()
  let services = @services.AppServices::new(
    platform=@services.PlatformServices::new(window_drag=source),
  )
  // The exact path an app body uses, with no backend import.
  services
  .platform()
  .window_drag()
  .set_region(Some(@core.Rect::new(x=0.0, y=0.0, width=1280.0, height=26.0)))
  inspect(source.region() is Some(_), content="true")
  inspect(source.revision(), content="1")
}

///|
test "hosts without drag support keep the unwired default" {
  let services = @services.AppServices::unavailable()
  let drag = services.platform().window_drag()
  // Declaring is safe and silent; nothing is ever applied.
  drag.set_region(Some(@core.Rect::new(x=0.0, y=0.0, width=100.0, height=20.0)))
  inspect(drag.region() is Some(_), content="true")
  let (calls, set_region) = drag_region_spy()
  let applied = @services.apply_window_drag_region(drag, None, set_region)
  debug_inspect(applied, content="Some(1)")
  inspect(calls.length(), content="1")
}
