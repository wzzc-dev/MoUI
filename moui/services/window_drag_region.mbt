///|
/// Declarative drag region for a window's own chrome.
///
/// Borderless or immersive apps that draw their own title bar need a
/// rectangular band that moves the window when the user presses and drags
/// inside it. The app declares that band here; the platform backend decodes
/// the raw pointer events and performs the native window drag, so no app
/// touches AppKit, Win32, or Wayland directly (see `docs/invariants.md` P10).
///
/// The value is *state*, not a command: the app may re-publish the same
/// rectangle on every layout pass. `set_region` only records the latest value
/// and advances `revision` when the geometry actually changes, so a host that
/// watches the revision performs at most one native call per real change.
pub struct WindowDragRegionSource {
  priv mut region_value : @core.Rect?
  priv mut revision_value : Int
}

///|
/// A source that accepts declarations but has no host attached. Hosts that do
/// not support window dragging leave this in place, so app code stays
/// unconditional.
pub fn WindowDragRegionSource::new() -> WindowDragRegionSource {
  { region_value: None, revision_value: 0, }
}

///|
/// Explicit spelling of `new()` for hosts and tests that want to signal
/// "this platform has no drag-region support".
pub fn WindowDragRegionSource::unavailable() -> WindowDragRegionSource {
  WindowDragRegionSource::new()
}

///|
/// Declare the drag band in logical window coordinates with a top-left
/// origin, matching MoUI's coordinate policy. Pass `None` to clear it.
///
/// Re-declaring an equal rectangle is a no-op: it neither advances
/// `revision` nor allocates, so per-frame republishing is free.
pub fn WindowDragRegionSource::set_region(
  self : WindowDragRegionSource,
  region : @core.Rect?,
) -> Unit {
  if self.region_value != region {
    self.region_value = region
    self.revision_value = self.revision_value + 1
  }
}

///|
/// The most recently declared band, or `None` when dragging is disabled.
pub fn WindowDragRegionSource::region(
  self : WindowDragRegionSource,
) -> @core.Rect? {
  self.region_value
}

///|
/// Monotonic counter that advances only when the declared band changes. Hosts
/// poll this to skip redundant native work.
pub fn WindowDragRegionSource::revision(self : WindowDragRegionSource) -> Int {
  self.revision_value
}

///|
/// Apply the declared band to a host once, skipping unchanged revisions.
///
/// `source` is the app-facing declaration, `applied` is the revision the host
/// last pushed (`None` when it has pushed nothing), and `set_region` performs
/// the native call and reports whether it landed — return `false` when there
/// is no window yet, so an early declaration is retried on a later tick
/// instead of being recorded as done.
///
/// Returns the revision to store back as `applied`. Hosts must call this on
/// their own loop tick rather than at declaration time, because the window may
/// not exist when the app first publishes.
pub fn apply_window_drag_region(
  source : WindowDragRegionSource,
  applied : Int?,
  set_region : (@core.Rect?) -> Bool,
) -> Int? {
  let current = source.revision()
  if applied == Some(current) {
    return applied
  }
  // Never declared and never applied: keep hosts that do not use a drag
  // region entirely free of native calls.
  if applied is None && source.region() is None {
    return None
  }
  if set_region(source.region()) {
    Some(current)
  } else {
    applied
  }
}
