///|
/// MoUI Studio 品牌主题：印泥朱砂主色 + 浅色基底。
/// 「卯」取木工榫卯的朱印意象——from_seed 从主色派生完整角色盘
/// （on/container/outline 全套），scheme 钉浅色（课堂/路演的确定性
/// 外观，不随系统深色漂移）。
pub fn studio_theme() -> @core.Theme {
  @views.theme(
    palette=@core.ColorPalette::from_seed(
      primary=@core.Color::rgba(r=0.78, g=0.26, b=0.20),
      Light,
    ),
  )
}
