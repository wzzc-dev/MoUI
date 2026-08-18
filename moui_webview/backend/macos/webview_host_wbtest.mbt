///|
extern "C" fn macos_webview_overlay_composition_test() -> Int = "moui_macos_webview_overlay_composition_test"

///|
test "macOS WebView overlay keeps Web pixels and returns input to MoUI" {
  assert_eq(macos_webview_overlay_composition_test(), 1)
}
