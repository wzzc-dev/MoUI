///|
/// Mutable holder for the host-owned overlay layer attached to the runtime
/// root. One slot is shared by every root adapter the runtime builds, so the
/// layer can mount and unmount without replacing the app root's element
/// identity — the app subtree is never remounted because of it.
priv struct HostOverlaySlot {
  mut nodes : Array[&RuntimeViewNode]
}

///|
fn HostOverlaySlot::new() -> HostOverlaySlot {
  { nodes: [], }
}

///|
/// A host-owned view layered above the app's root view.
///
/// The host mounts it with `AppRuntime::set_host_overlay`; the runtime places
/// it at the surface origin, paints it after the app's own children, and
/// hit-tests it before them. Messages produced by the layer are delivered to
/// `emit`, which the host owns — the app's `Msg` type never sees them. The
/// layer participates in overlay placement, pointer input, keyboard dismissal
/// and semantics exactly like an in-tree overlay host, so
/// `context_menu_region` works unchanged on top of it.
pub struct HostOverlay {
  priv node : &RuntimeViewNode
  /// `true` for a non-activating layer such as a native-style context menu: a
  /// press on it must not move or clear the app's focus.
  priv keeps_focus : Bool
}

///|
/// `keeps_focus` marks the layer non-activating: a primary press on it leaves
/// the app's focus owner alone. A native context menu behaves this way — the
/// command it runs needs the focus the menu was opened over, and taking focus
/// away before the press is dispatched would leave the command without a
/// target. Leave it `false` for layers that are ordinary UI (a palette, a
/// dialog) and should take focus like any other content.
pub fn[Msg] HostOverlay::from_view(
  view : @core.View[Msg],
  emit~ : (Msg) -> Unit,
  keeps_focus~ : Bool = false,
) -> HostOverlay {
  { node: runtime_view_node(view, emit), keeps_focus, }
}
