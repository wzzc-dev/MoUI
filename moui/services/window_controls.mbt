///|
/// What this host can actually do with a window, so app-drawn chrome can hide
/// or disable a control instead of drawing a dead button.
///
/// Reported by the host at window creation (never probed by the view layer);
/// a host that cannot honor an operation reports `false` and the matching
/// request is dropped at the source instead of failing silently later.
#derive(Eq, Debug)
pub(all) struct WindowControlCapabilities {
  minimize : Bool
  maximize : Bool
  fullscreen : Bool
  decorations : Bool
}

///|
pub extend WindowControlCapabilities with Debug::{to_repr}

///|
pub extend WindowControlCapabilities with Eq::{not_equal, equal}

///|
/// Nothing is supported: the app should draw no window controls at all. This is
/// what an unhosted source reports.
pub fn WindowControlCapabilities::none() -> WindowControlCapabilities {
  { minimize: false, maximize: false, fullscreen: false, decorations: false, }
}

///|
/// Every operation is supported (native desktop backends).
pub fn WindowControlCapabilities::all() -> WindowControlCapabilities {
  { minimize: true, maximize: true, fullscreen: true, decorations: true, }
}

///|
/// A window-control intent the app asked for.
///
/// Intents are recorded here and drained by the host on its own tick, so an
/// app's `update` can raise one without touching a platform backend, and a host
/// that has no window yet can apply it on a later frame.
#derive(Eq, Debug)
pub(all) enum WindowControlRequest {
  Minimize
  Maximize
  Restore
  ToggleFullscreen
  SetFullscreen(Bool)
  SetDecorations(Bool)
}

///|
pub extend WindowControlRequest with Debug::{to_repr}

///|
pub extend WindowControlRequest with Eq::{not_equal, equal}

///|
/// App-facing window-control surface: capabilities, observed state, and a
/// pending-intent queue.
///
/// Ownership follows invariants P5/P10: the app declares intent, the host
/// projects it. Nothing here names a platform API, so app code stays portable;
/// hosts that cannot do an operation advertise `false` and the intent is dropped
/// at the source rather than queued forever.
///
/// ```moonbit nocheck
/// // in an update()
/// services.platform().window_controls().maximize()
///
/// // in a view()
/// let controls = services.platform().window_controls()
/// if controls.can_maximize() { ...draw a green button... }
/// ```
pub struct WindowControlSource {
  priv mut capabilities_value : WindowControlCapabilities
  priv mut maximized_value : Bool
  priv mut fullscreen_value : Bool
  priv mut requests : Array[WindowControlRequest]
  priv mut revision_value : Int32
  /// Occupied space of host-drawn window chrome (e.g. the Linux CSD
  /// titlebar band), mirrored from the host like the observed state.
  priv mut titlebar_value : @core.Insets?
  priv hosted : Bool
}

///|
/// A source the app can call unconditionally: no capabilities, no queued
/// intents, and no observed state. Hosts replace it with a hosted source.
pub fn WindowControlSource::unavailable() -> WindowControlSource {
  {
    capabilities_value: WindowControlCapabilities::none(),
    maximized_value: false,
    fullscreen_value: false,
    requests: [],
    revision_value: 0,
    titlebar_value: None,
    hosted: false,
  }
}

///|
/// A source a host owns and drains. Until the host publishes capabilities the
/// app sees `none()` and its intents are dropped.
pub fn WindowControlSource::new() -> WindowControlSource {
  {
    capabilities_value: WindowControlCapabilities::none(),
    maximized_value: false,
    fullscreen_value: false,
    requests: [],
    revision_value: 0,
    titlebar_value: None,
    hosted: true,
  }
}

///|
pub fn WindowControlSource::capabilities(
  self : WindowControlSource,
) -> WindowControlCapabilities {
  self.capabilities_value
}

///|
pub fn WindowControlSource::can_minimize(self : WindowControlSource) -> Bool {
  self.capabilities_value.minimize
}

///|
pub fn WindowControlSource::can_maximize(self : WindowControlSource) -> Bool {
  self.capabilities_value.maximize
}

///|
pub fn WindowControlSource::can_toggle_fullscreen(
  self : WindowControlSource,
) -> Bool {
  self.capabilities_value.fullscreen
}

///|
pub fn WindowControlSource::can_set_decorations(
  self : WindowControlSource,
) -> Bool {
  self.capabilities_value.decorations
}

///|
/// Last known maximize state (the host mirrors the window record back here).
pub fn WindowControlSource::maximized(self : WindowControlSource) -> Bool {
  self.maximized_value
}

///|
/// Last known fullscreen state.
pub fn WindowControlSource::fullscreen(self : WindowControlSource) -> Bool {
  self.fullscreen_value
}

///|
/// Monotonic counter advanced when capabilities or observed state change. Apps
/// can compare it across frames to know whether their chrome needs a repaint.
pub fn WindowControlSource::revision(self : WindowControlSource) -> Int32 {
  self.revision_value
}

///|
/// Ask the host to minimize the window. A no-op without the capability.
pub fn WindowControlSource::minimize(self : WindowControlSource) -> Unit {
  if self.capabilities_value.minimize {
    self.requests.push(Minimize)
  }
}

///|
/// Ask the host to maximize the window. A no-op without the capability.
pub fn WindowControlSource::maximize(self : WindowControlSource) -> Unit {
  if self.capabilities_value.maximize {
    self.requests.push(Maximize)
  }
}

///|
/// Ask the host to restore the window to its normal frame.
pub fn WindowControlSource::restore(self : WindowControlSource) -> Unit {
  if self.capabilities_value.maximize || self.capabilities_value.fullscreen {
    self.requests.push(Restore)
  }
}

///|
/// Ask the host to leave fullscreen if it is in it, and enter it otherwise.
pub fn WindowControlSource::toggle_fullscreen(
  self : WindowControlSource,
) -> Unit {
  if self.capabilities_value.fullscreen {
    self.requests.push(ToggleFullscreen)
  }
}

///|
/// Ask the host for a specific fullscreen state.
pub fn WindowControlSource::set_fullscreen(
  self : WindowControlSource,
  fullscreen : Bool,
) -> Unit {
  if self.capabilities_value.fullscreen {
    self.requests.push(SetFullscreen(fullscreen))
  }
}

///|
/// Ask the host to show or hide native decorations.
pub fn WindowControlSource::set_decorations(
  self : WindowControlSource,
  decorations : Bool,
) -> Unit {
  if self.capabilities_value.decorations {
    self.requests.push(SetDecorations(decorations))
  }
}

///|
/// Host side: publish what this window can do. Re-publishing an equal value is
/// free and does not advance the revision.
pub fn WindowControlSource::set_capabilities(
  self : WindowControlSource,
  capabilities : WindowControlCapabilities,
) -> Unit {
  if self.capabilities_value != capabilities {
    self.capabilities_value = capabilities
    self.revision_value = self.revision_value + 1
  }
}

///|
/// Host side: publish the observed maximize/fullscreen state. Equal values do
/// not advance the revision.
pub fn WindowControlSource::set_observed(
  self : WindowControlSource,
  maximized~ : Bool,
  fullscreen~ : Bool,
) -> Unit {
  if self.maximized_value != maximized || self.fullscreen_value != fullscreen {
    self.maximized_value = maximized
    self.fullscreen_value = fullscreen
    self.revision_value = self.revision_value + 1
  }
}

///|
/// Occupied space of host-drawn window chrome (e.g. the Linux CSD titlebar
/// band), or `None` when the window carries no client-side chrome. Mirrored
/// from the host like the observed maximize/fullscreen state, so chrome can
/// lay out against the band without touching the platform.
pub fn WindowControlSource::titlebar_insets(
  self : WindowControlSource,
) -> @core.Insets? {
  self.titlebar_value
}

///|
/// Host side: mirror the chrome occupancy and bump the revision on change.
pub fn WindowControlSource::set_titlebar_insets(
  self : WindowControlSource,
  insets~ : @core.Insets?,
) -> Unit {
  let changed = match (self.titlebar_value, insets) {
    (Some(previous), Some(next)) => @core.Insets::equal(previous, next) == false
    (None, None) => false
    _ => true
  }
  if changed {
    self.titlebar_value = insets
    self.revision_value = self.revision_value + 1
  }
}

///|
/// Host side: take every pending intent, in order.
///
/// An unhosted source always returns an empty array: an app that asks for
/// window control on a host without one must not accumulate a queue nobody
/// drains.
pub fn WindowControlSource::drain(
  self : WindowControlSource,
) -> Array[WindowControlRequest] {
  if !self.hosted {
    return []
  }
  let pending = self.requests
  self.requests = []
  pending
}
