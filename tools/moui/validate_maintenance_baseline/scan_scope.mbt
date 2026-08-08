///|
fn monitored_roots(scope : String) -> Array[String] {
  if scope == "full" {
    return [
      "moui", "moui_skia_renderer", "moui_web_renderer", "moui_wgpu_renderer", "moui_sun_renderer",
      "moui_tests", "moui_i18n", "moui_richtext", "moui_skia", "moui_sun", "moui_theme",
      "moui_devtools", "moui_webview", "moui_agent", "moui_agent_mcp", "examples",
      "website", "tools",
    ]
  }
  ["moui", "examples", "website"]
}
