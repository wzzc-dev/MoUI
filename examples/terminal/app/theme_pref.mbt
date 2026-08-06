///|
/// 主题偏好:跟随系统 / 强制浅色 / 强制深色。
/// 与 `@core.ThemeSpec` 的 `color_mode`(System/Light/Dark)一一对应;
/// 宿主(macos_skia)负责把偏好解析成 `ThemeSpec` 并应用到 runtime
/// environment,view 侧据此高亮当前选择。
pub(all) enum ThemePreference {
  System
  Light
  Dark
}

///|
/// 稳定 id(用于 button_group 的 selected 匹配)。
pub fn ThemePreference::id(self : ThemePreference) -> String {
  match self {
    ThemePreference::System => "system"
    ThemePreference::Light => "light"
    ThemePreference::Dark => "dark"
  }
}

///|
/// 显示标签。
pub fn ThemePreference::label(self : ThemePreference) -> String {
  match self {
    ThemePreference::System => "System"
    ThemePreference::Light => "Light"
    ThemePreference::Dark => "Dark"
  }
}

///|
/// 构建期度量用主题:偏好对应主题,便于 cell 尺寸随字号推导。
/// 仅用于布局度量(typography);实际渲染色由 runtime environment 驱动,
/// 终端文本/按钮在 paint 期取 `ctx.environment.theme`。
/// System 无显式主题时退回 neutral(与默认环境一致,字号相同)。
pub fn theme_for_pref(pref : ThemePreference) -> @moui.Theme {
  match pref {
    ThemePreference::System => @views.default_theme()
    ThemePreference::Light => @views.light_theme()
    ThemePreference::Dark => @views.dark_theme()
  }
}
