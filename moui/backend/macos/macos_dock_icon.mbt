///|
extern "C" fn macos_application_bundle_has_icon() -> Int32 = "moui_macos_application_bundle_has_icon"

///|
/// How `create_macos_app` should configure the Dock icon for this run.
priv enum DockIconAction {
  /// Apply the embedded MoUI Moonbud icon. Used for unbundled binaries and
  /// development bundles that declare no icon of their own.
  ApplyDefaultBranding
  /// Apply the icon stored at this file path (app-declared override).
  ApplyPath(String)
  /// Leave the Dock icon untouched. Bundled `.app` binaries with their own
  /// icon keep the icon declared by their bundle.
  KeepExisting
}

///|
fn macos_dock_icon_action(
  dock_icon_path : String?,
  bundled : Bool,
  bundle_has_icon~ : Bool = macos_application_bundle_has_icon() != 0,
) -> DockIconAction {
  match dock_icon_path {
    Some(path) => ApplyPath(path)
    None =>
      if bundled && bundle_has_icon {
        KeepExisting
      } else {
        ApplyDefaultBranding
      }
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
