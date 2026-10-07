
///|
test "session row title hugs the row left edge at every width" {
  // 真机反馈:双行会话行前有一段空白——旧实现按内容估宽后 frame 居中,
  // 短标题两侧对称留空,空隙随面板宽度增长。契约:标题后的行首空隙
  // (容器内垫 8 + 图标 11 + 间距 4 ≈ 23)在窄窗/宽窗下都恒定。
  let model = apply_ai(initial_model(), SetPerspective(PsAi))
  let mut row_bg_x = -1.0
  let mut title_x = -1.0
  let mut row_bg_x_wide = -1.0
  let mut title_x_wide = -1.0
  for command in ai_draw(model, 1280.0, 800.0) {
    let rect : @core.Rect? = match command {
      @core.FillRect(rect, _) => Some(rect)
      @core.FillRoundedRect(rounded, _) => Some(rounded.rect)
      @core.FillRoundedRectBrush(rounded, _) => Some(rounded.rect)
      _ => None
    }
    match rect {
      Some(r) =>
        if r.origin.x > 30.0 &&
          r.origin.x < 320.0 &&
          r.origin.y > 110.0 &&
          r.origin.y < 240.0 &&
          r.size.height > 30.0 {
          if row_bg_x < 0.0 || r.origin.x < row_bg_x {
            row_bg_x = r.origin.x
          }
        }
      None => ()
    }
  }
  for run in shell_texts(ai_draw(model, 1280.0, 800.0)) {
    if run.text == "会话 1" && run.frame.origin.y > 110.0 && run.frame.origin.y < 240.0 {
      if title_x < 0.0 || run.frame.origin.x < title_x {
        title_x = run.frame.origin.x
      }
    }
  }
  for command in ai_draw(model, 2000.0, 800.0) {
    let rect : @core.Rect? = match command {
      @core.FillRect(rect, _) => Some(rect)
      @core.FillRoundedRect(rounded, _) => Some(rounded.rect)
      @core.FillRoundedRectBrush(rounded, _) => Some(rounded.rect)
      _ => None
    }
    match rect {
      Some(r) =>
        if r.origin.x > 30.0 &&
          r.origin.x < 400.0 &&
          r.origin.y > 110.0 &&
          r.origin.y < 240.0 &&
          r.size.height > 30.0 {
          if row_bg_x_wide < 0.0 || r.origin.x < row_bg_x_wide {
            row_bg_x_wide = r.origin.x
          }
        }
      None => ()
    }
  }
  for run in shell_texts(ai_draw(model, 2000.0, 800.0)) {
    if run.text == "会话 1" && run.frame.origin.y > 110.0 && run.frame.origin.y < 240.0 {
      if title_x_wide < 0.0 || run.frame.origin.x < title_x_wide {
        title_x_wide = run.frame.origin.x
      }
    }
  }
  assert_true(row_bg_x > 0.0)
  assert_true(title_x > 0.0)
  assert_true(title_x - row_bg_x <= 30.0)
  assert_true(row_bg_x_wide > 0.0)
  assert_true(title_x_wide - row_bg_x_wide <= 30.0)
}
