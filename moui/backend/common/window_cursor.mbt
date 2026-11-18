///|
/// Project the neutral `@core.CursorIcon` onto the platform window crate's icon
/// set.
///
/// This is the single upward mapping table for all desktop/web backends: the
/// neutral set lives in `moui/core` so apps and view declarations never import a
/// platform package, and this is the only place that names the platform
/// variants. Adding a shape is one neutral variant plus one arm here, and an
/// upstream variant the framework does not project cannot leak into the public
/// API.
///
/// Hosts that cannot show a shape keep their own default: the platform call is
/// the last step, and no capability query is involved.
pub fn cursor_icon_to_window(
  icon : @core.CursorIcon,
) -> @window_core.CursorIcon {
  match icon {
    CursorDefault => @window_core.CursorIcon::Default
    CursorContextMenu => @window_core.CursorIcon::ContextMenu
    CursorHelp => @window_core.CursorIcon::Help
    CursorProgress => @window_core.CursorIcon::Progress
    CursorWait => @window_core.CursorIcon::Wait
    CursorCell => @window_core.CursorIcon::Cell
    CursorVerticalText => @window_core.CursorIcon::VerticalText
    CursorAlias => @window_core.CursorIcon::Alias
    CursorCopy => @window_core.CursorIcon::Copy
    CursorNoDrop => @window_core.CursorIcon::NoDrop
    CursorGrab => @window_core.CursorIcon::Grab
    CursorGrabbing => @window_core.CursorIcon::Grabbing
    CursorEResize => @window_core.CursorIcon::EResize
    CursorNResize => @window_core.CursorIcon::NResize
    CursorNeResize => @window_core.CursorIcon::NeResize
    CursorNwResize => @window_core.CursorIcon::NwResize
    CursorSResize => @window_core.CursorIcon::SResize
    CursorSeResize => @window_core.CursorIcon::SeResize
    CursorSwResize => @window_core.CursorIcon::SwResize
    CursorWResize => @window_core.CursorIcon::WResize
    CursorEwResize => @window_core.CursorIcon::EwResize
    CursorNsResize => @window_core.CursorIcon::NsResize
    CursorNeswResize => @window_core.CursorIcon::NeswResize
    CursorNwseResize => @window_core.CursorIcon::NwseResize
    CursorColResize => @window_core.CursorIcon::ColResize
    CursorRowResize => @window_core.CursorIcon::RowResize
    CursorAllScroll => @window_core.CursorIcon::AllScroll
    CursorZoomIn => @window_core.CursorIcon::ZoomIn
    CursorZoomOut => @window_core.CursorIcon::ZoomOut
    CursorPointer => @window_core.CursorIcon::Pointer
    CursorText => @window_core.CursorIcon::Text
    CursorCrosshair => @window_core.CursorIcon::Crosshair
    CursorMove => @window_core.CursorIcon::Move
    CursorNotAllowed => @window_core.CursorIcon::NotAllowed
  }
}
