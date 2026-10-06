///|
/// How `create_macos_app` should configure the Dock icon for this run.
priv enum DockIconAction {
  /// Apply the embedded MoUI Moonbud icon. This is the default for unbundled
  /// binaries, whose system icon would otherwise be the generic gear.
  ApplyDefaultBranding
  /// Apply the icon stored at this file path (app-declared override).
  ApplyPath(String)
  /// Leave the Dock icon untouched. Bundled `.app` binaries without an
  /// override keep the icon declared by their bundle.
  KeepExisting
}

///|
fn macos_dock_icon_action(
  dock_icon_path : String?,
  bundled : Bool,
) -> DockIconAction {
  match dock_icon_path {
    Some(path) => ApplyPath(path)
    None => if bundled { KeepExisting } else { ApplyDefaultBranding }
  }
}

///|
/// Apply the configured Dock icon before the event loop starts. Must run on
/// the main thread; the application icon is app-global AppKit state, so any
/// override wins regardless of how many windows follow.
fn macos_apply_dock_icon(dock_icon_path : String?) -> Unit {
  match
    macos_dock_icon_action(
      dock_icon_path,
      @window_macos.application_is_bundled(),
    ) {
    ApplyDefaultBranding =>
      if !@window_macos.set_application_icon_data(macos_default_dock_icon_png) {
        println(
          "macOS default dock icon could not be decoded; keeping the system icon",
        )
      }
    ApplyPath(path) =>
      if !@window_macos.set_application_icon_path(path) {
        println("macOS dock icon file could not be loaded: \{path}")
      }
    KeepExisting => ()
  }
}
