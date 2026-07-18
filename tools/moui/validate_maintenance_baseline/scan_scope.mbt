///|
fn monitored_roots(scope : String) -> Array[String] {
  if scope == "full" {
    return [
      "moui", "moui_i18n", "moui_richtext", "moui_skia", "moui_sun", "moui_theme",
      "moui_tester", "moui_devtools", "moui_webview", "moui_agent", "moui_agent_mcp",
      "examples", "website", "tools",
    ]
  }
  ["moui", "examples", "website"]
}
