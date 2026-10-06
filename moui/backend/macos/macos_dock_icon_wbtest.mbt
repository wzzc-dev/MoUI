///|
fn dock_icon_action_is(
  action : DockIconAction,
  expected : DockIconAction,
) -> Bool {
  match (action, expected) {
    (ApplyDefaultBranding, ApplyDefaultBranding)
    | (KeepExisting, KeepExisting) => true
    (ApplyPath(left), ApplyPath(right)) => left == right
    _ => false
  }
}

///|
test "dock_icon_action_prefers_explicit_path_over_platform_default" {
  assert_true(
    dock_icon_action_is(
      macos_dock_icon_action(Some("/tmp/app-icon.png"), false),
      ApplyPath("/tmp/app-icon.png"),
    ),
  )
  assert_true(
    dock_icon_action_is(
      macos_dock_icon_action(Some("/tmp/app-icon.png"), true),
      ApplyPath("/tmp/app-icon.png"),
    ),
  )
}

///|
test "dock_icon_action_defaults_by_bundled_state" {
  // Unbundled binaries (moon run output) would show the generic system icon,
  // so they get the embedded Moonbud branding.
  assert_true(
    dock_icon_action_is(
      macos_dock_icon_action(None, false),
      ApplyDefaultBranding,
    ),
  )
  // Bundled .app binaries already carry their own bundle icon; do not
  // override it.
  assert_true(
    dock_icon_action_is(macos_dock_icon_action(None, true), KeepExisting),
  )
}

///|
test "embedded_default_dock_icon_is_a_png" {
  assert_true(macos_default_dock_icon_png.length() > 8)
  // PNG signature: 89 50 4E 47 0D 0A 1A 0A
  assert_eq(macos_default_dock_icon_png[0], 0x89)
  assert_eq(macos_default_dock_icon_png[1], 0x50)
  assert_eq(macos_default_dock_icon_png[2], 0x4E)
  assert_eq(macos_default_dock_icon_png[3], 0x47)
  assert_eq(macos_default_dock_icon_png[4], 0x0D)
  assert_eq(macos_default_dock_icon_png[5], 0x0A)
  assert_eq(macos_default_dock_icon_png[6], 0x1A)
  assert_eq(macos_default_dock_icon_png[7], 0x0A)
}

///|
test "embedded_default_dock_icon_decodes_via_appkit" {
  // Native tests run on the main thread, which is the thread contract the
  // AppKit setter requires. This proves the embedded bytes are decodable by
  // NSImage and accepted by NSApplication, not merely PNG-shaped.
  assert_true(
    @window_macos.set_application_icon_data(macos_default_dock_icon_png),
  )
  assert_false(@window_macos.set_application_icon_data(b"not an image"))
  assert_false(@window_macos.set_application_icon_data(b""))
}

///|
test "macos_host_app_options_dock_icon_path_defaults_to_platform_default" {
  let options = MacosHostAppOptions::new()
  assert_eq(options.dock_icon_path(), None)
  let customized = MacosHostAppOptions::new(
    dock_icon_path=Some("/tmp/custom-icon.png"),
  )
  assert_eq(customized.dock_icon_path(), Some("/tmp/custom-icon.png"))
}
