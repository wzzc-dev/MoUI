///|
test "scroll offset clamps to scrollback" {
  let m = Model::new(4, 2)
  // 制造回看:写 3 行到 2 行屏幕
  let m = update(m, Msg::Feed(@utf8.encode("a\r\nb\r\nc\r\nd\r\ne\r\nf")))
  inspect(m.screen().total_lines(), content="6")
  // 最大偏移 = total - rows = 4
  let m = update(m, Msg::ScrollBy(10))
  inspect(m.scroll_offset(), content="4")
  let m = update(m, Msg::ScrollBy(-100))
  inspect(m.scroll_offset(), content="0")
  let m = update(m, Msg::ScrollBy(2))
  inspect(m.scroll_offset(), content="2")
}

///|
test "write input resets scroll to bottom" {
  let m = Model::new(4, 2)
  let m = update(m, Msg::Feed(@utf8.encode("a\r\nb\r\nc")))
  let m = update(m, Msg::ScrollBy(1))
  inspect(m.scroll_offset(), content="1")
  let m = update(m, Msg::WriteInput("ls"))
  inspect(m.scroll_offset(), content="0")
}

///|
test "feed keeps scroll position" {
  let m = Model::new(4, 2)
  let m = update(m, Msg::Feed(@utf8.encode("a\r\nb\r\nc")))
  // 第 3 行进回看:total=3,max offset=1
  let m = update(m, Msg::ScrollBy(1))
  inspect(m.scroll_offset(), content="1")
  let m = update(m, Msg::Feed(@utf8.encode("d")))
  inspect(m.scroll_offset(), content="1")
  inspect(m.screen().total_lines(), content="3")
}

///|
test "scroll offset re-clamped when scrollback shrinks" {
  let m = Model::new(4, 2)
  let m = update(m, Msg::Feed(@utf8.encode("a\r\nb\r\nc\r\nd\r\ne")))
  let m = update(m, Msg::ScrollBy(10)) // 最大偏移 3
  inspect(m.scroll_offset(), content="3")
  // ESC c(RIS)清空回看与屏幕:偏移必须收敛,不能留下越界值
  let m = update(m, Msg::Feed(@utf8.encode("\u{1b}c")))
  inspect(m.scroll_offset(), content="0")
  inspect(m.screen().total_lines(), content="2")
}

///|
test "cell metrics follow theme mono size" {
  let theme = @moui.Theme::neutral()
  // 默认字号 body=16px:等宽 advance 0.6em → 9.6px,行高 1.25em → 20px。
  // 旧实现固定 8.4(14px 经验值)导致文本绘制宽度超过节点 frame,
  // 渲染器按 frame 裁剪 → 行尾字符(单词最后一个字母)丢失。
  inspect(cell_width(theme), content="9.6")
  inspect(cell_height(theme), content="20")
  // 自定义字号跟随缩放,度量不是魔法常量
  let t2 = theme.with_typography({
    ..theme.typography,
    body: @core.FontSpec::new(size=14.0, weight=400),
  })
  inspect(cell_width(t2), content="8.4")
  inspect(cell_height(t2), content="17.5")
}

///|
test "terminal colors follow theme" {
  // 面板背景跟随主题 palette(深色主题=黑底,浅色主题=白底)
  let light = theme_for_pref(ThemePreference::Light)
  inspect(
    terminal_background(light) == light.palette.background,
    content="true",
  )
  let dark = theme_for_pref(ThemePreference::Dark)
  inspect(terminal_background(dark) == dark.palette.background, content="true")
  // 默认前景跟随主题前景色(与面板底色保持对比)
  inspect(
    term_color_to_core(TermColor::Default, light) == light.palette.foreground,
    content="true",
  )
  inspect(
    term_color_to_core(TermColor::Default, dark) == dark.palette.foreground,
    content="true",
  )
  // ANSI 16 色/256 色/RGB 色板固定,不随主题变化
  inspect(
    term_color_to_core(TermColor::Indexed(1), dark) ==
    @graphics.Color::rgba(r=0.80, g=0.0, b=0.0),
    content="true",
  )
  inspect(
    term_color_to_core(TermColor::Rgb(0, 128, 255), dark) ==
    @graphics.Color::rgba(r=0.0, g=128.0 / 255.0, b=1.0),
    content="true",
  )
}

///|
test "theme preference ids and labels" {
  inspect(ThemePreference::System.id(), content="system")
  inspect(ThemePreference::Light.id(), content="light")
  inspect(ThemePreference::Dark.id(), content="dark")
  inspect(ThemePreference::System.label(), content="System")
  inspect(ThemePreference::Light.label(), content="Light")
  inspect(ThemePreference::Dark.label(), content="Dark")
}

///|
test "model defaults to system theme and SetTheme updates it" {
  let model = Model::new(20, 5)
  inspect(model.theme_pref.id(), content="system")
  let dark = update(model, Msg::SetTheme(ThemePreference::Dark))
  inspect(dark.theme_pref.id(), content="dark")
  let light = update(dark, Msg::SetTheme(ThemePreference::Light))
  inspect(light.theme_pref.id(), content="light")
}

///|
test "theme_for_pref resolves the matching scheme" {
  inspect(
    theme_for_pref(ThemePreference::Light).scheme == @core.ColorScheme::Light,
    content="true",
  )
  inspect(
    theme_for_pref(ThemePreference::Dark).scheme == @core.ColorScheme::Dark,
    content="true",
  )
}

///|

///|
test "selection normalized and column ranges" {
  let sel = Selection::new(5, 10, 3, 2)
  let (top, left, bottom, right) = sel.normalized()
  inspect(top, content="3")
  inspect(left, content="2")
  inspect(bottom, content="5")
  inspect(right, content="10")
  inspect(sel.contains_row(3), content="true")
  inspect(sel.contains_row(5), content="true")
  inspect(sel.contains_row(4), content="true")
  inspect(sel.contains_row(2), content="false")
  // 首行从 left 开始,末行到 right(含)
  let (s1, e1) = match sel.col_range_at(3) {
    Some(range) => range
    None => fail("expected range")
  }
  inspect(s1, content="2")
  // top 行是首行:end 为无穷(延伸到行尾)
  inspect(e1, content="2147483647")
  let (s2, e2) = match sel.col_range_at(5) {
    Some(range) => range
    None => fail("expected range")
  }
  // bottom 行从列 0 开始,到 right(含)
  inspect(s2, content="0")
  inspect(e2, content="11")
  match sel.col_range_at(6) {
    Some(_) => fail("out of range row")
    None => ()
  }
}

///|
test "selection text extraction" {
  let model = Model::new(20, 3)
  model.parser.feed_bytes(@utf8.encode("hello world\r\nsecond\r\nthird"))
  // 选择第一行第 6..10 列(world)
  let sel = Selection::new(0, 6, 0, 10)
  inspect(selection_text(model.screen, Some(sel)), content="world")
  // 跨行:第 0 行从 anchor 到行尾 + 第 1 行 0..6(second 含第 5 列)
  let sel2 = Selection::new(0, 0, 1, 5)
  inspect(
    selection_text(model.screen, Some(sel2)),
    content="hello world\nsecond",
  )
  // 全选第二行
  let sel3 = Selection::new(1, 0, 1, 9)
  inspect(selection_text(model.screen, Some(sel3)), content="second")
  // 无选择
  inspect(selection_text(model.screen, None), content="")
}

///|
test "selection messages update model" {
  let model = Model::new(10, 3)
  let m1 = update(model, Msg::SelectionBegin(2, 4))
  match m1.selection {
    Some(sel) => {
      inspect(sel.anchor_row, content="2")
      inspect(sel.anchor_col, content="4")
    }
    None => fail("selection should exist")
  }
  let m2 = update(m1, Msg::SelectionMove(5, 8))
  match m2.selection {
    Some(sel) => {
      inspect(sel.active_row, content="5")
      inspect(sel.active_col, content="8")
      // anchor 保持
      inspect(sel.anchor_row, content="2")
    }
    None => fail("selection should exist")
  }
  // Copy 不改模型
  let m3 = update(m2, Msg::Copy)
  match m3.selection {
    Some(sel) => inspect(sel.active_col, content="8")
    None => fail("copy keeps selection")
  }
}

///|
test "selection text preserves leading spaces" {
  let model = Model::new(20, 2)
  model.parser.feed_bytes(@utf8.encode("  indented\r\n"))
  let sel = Selection::new(0, 0, 0, 11)
  inspect(selection_text(model.screen, Some(sel)), content="  indented")
  // 行尾空格裁剪
  let model2 = Model::new(20, 2)
  model2.parser.feed_bytes(@utf8.encode("trail   \r\n"))
  let sel2 = Selection::new(0, 0, 0, 9)
  inspect(selection_text(model2.screen, Some(sel2)), content="trail")
}

///|
test "wide characters in selection text" {
  let model = Model::new(12, 2)
  // "中" 占 2 列
  model.parser.feed_bytes(@utf8.encode("ab中c\r\n"))
  let sel = Selection::new(0, 0, 0, 11)
  inspect(selection_text(model.screen, Some(sel)), content="ab中c")
  // 选中第 2..4 列(中)
  let sel2 = Selection::new(0, 2, 0, 3)
  inspect(selection_text(model.screen, Some(sel2)), content="中")
}
