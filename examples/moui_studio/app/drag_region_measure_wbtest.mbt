///|
/// 精确测量：顶栏运行芯片的**实际绘制矩形** vs 拖拽区右缘
/// （topbar_drag_width）。渲染宽超出预算、芯片左缘落入拖拽区的
/// 任何回归，都会让物理点击变成拖窗口（「点运行没反应」）。
test "run chip stays right of the window drag region" {
  let model = apply_shell(initial_model(), SetWorkSpace(WsVisual))
  let commands = shell_draw(model, 1280.0, 800.0)
  // 运行芯片 = 顶栏带(y<32)内、ide_accent 填充的圆角矩形（主行动作唯一强调色）
  let accent = ide_accent()
  let mut chip : @core.Rect? = None
  for command in commands {
    match command {
      // 芯片背景是容器 Brush（FillRoundedRectBrush），纯色也走 Brush 路径
      @core.FillRoundedRectBrush(rounded, brush) =>
        if rounded.rect.origin.y < 32.0 {
          let c = brush.fallback_color()
          if c.r == accent.r && c.g == accent.g && c.b == accent.b {
            chip = Some(rounded.rect)
          }
        }
      @core.FillRoundedRect(rounded, color) =>
        if rounded.rect.origin.y < 32.0 &&
          color.r == accent.r &&
          color.g == accent.g &&
          color.b == accent.b {
          chip = Some(rounded.rect)
        }
      _ => ()
    }
  }
  guard chip is Some(rect) else { fail("顶栏没有画运行芯片（accent 填充缺失）") }
  let drag_right = topbar_drag_width(model, translator(model), 1280.0)
  let chip_left = rect.origin.x
  let chip_right = rect.origin.x + rect.size.width
  println("chip: x=\{chip_left}..\{chip_right} | drag right=\{drag_right}")
  // 芯片左缘必须严格在拖拽区右侧（留 ≥8px 余量）
  assert_true(chip_left >= drag_right + 8.0)
}
