///|
/// App-facing window controls: capability gating, pending-intent queue, and the
/// observed-state mirror. These tests pin the honest-degradation rule — a host
/// that cannot do an operation must not accumulate intents for it.

///|
fn window_controls_all() -> @services.WindowControlCapabilities {
  @services.WindowControlCapabilities::all()
}

///|
test "window controls queue intents only for supported operations" {
  let source = @services.WindowControlSource::new()
  // Nothing published yet: an unsupported host must drop intents, not queue
  // them forever.
  source.maximize()
  source.toggle_fullscreen()
  assert_true(source.drain().is_empty())

  source.set_capabilities(window_controls_all())
  assert_true(source.can_maximize())
  assert_true(source.can_toggle_fullscreen())
  source.maximize()
  source.toggle_fullscreen()
  source.set_decorations(false)
  assert_eq(source.drain(), [
    @services.WindowControlRequest::Maximize,
    @services.WindowControlRequest::ToggleFullscreen,
    @services.WindowControlRequest::SetDecorations(false),
  ])
  // Drain is destructive: the host applies each intent once.
  assert_true(source.drain().is_empty())
}

///|
test "window controls report capabilities honestly for a browser-like host" {
  let source = @services.WindowControlSource::new()
  source.set_capabilities(@services.WindowControlCapabilities::{
    minimize: false,
    maximize: false,
    fullscreen: true,
    decorations: false,
  })
  assert_false(source.can_minimize())
  assert_false(source.can_maximize())
  assert_true(source.can_toggle_fullscreen())
  assert_false(source.can_set_decorations())
  source.maximize()
  source.minimize()
  source.set_decorations(true)
  // Only fullscreen survives the capability gate.
  source.toggle_fullscreen()
  assert_eq(source.drain(), [@services.WindowControlRequest::ToggleFullscreen])
}

///|
test "window controls revision advances only on real capability/state change" {
  let source = @services.WindowControlSource::new()
  assert_eq(source.revision(), 0)
  source.set_capabilities(window_controls_all())
  assert_eq(source.revision(), 1)
  // Re-publishing an equal value is free.
  source.set_capabilities(window_controls_all())
  assert_eq(source.revision(), 1)
  source.set_observed(maximized=true, fullscreen=false)
  assert_eq(source.revision(), 2)
  source.set_observed(maximized=true, fullscreen=false)
  assert_eq(source.revision(), 2)
  assert_true(source.maximized())
  assert_false(source.fullscreen())
}

///|
test "unavailable source keeps app chrome callable and inert" {
  let source = @services.WindowControlSource::unavailable()
  // Even with capabilities forced through the host setter, an unhosted source
  // must never hand a queue to a host that does not exist.
  source.set_capabilities(window_controls_all())
  source.maximize()
  assert_true(source.drain().is_empty())
  assert_eq(source.capabilities(), window_controls_all())
}
