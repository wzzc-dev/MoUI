///|
test "damage starts clean and drains once" {
  let s = @moui_tui.TermScreen::new(4, 2)
  assert_true(s.take_damage().is_empty())
  inspect(s.revision(), content="0")
  s.print_char("a", 1)
  s.print_char("b", 1)
  let d = s.take_damage()
  inspect(d.full, content="false")
  inspect(d.rows.length(), content="1")
  inspect(d.rows[0], content="0")
  assert_true(s.take_damage().is_empty())
  inspect(s.revision(), content="1")
}

///|
test "cursor and attribute changes are not damage" {
  let s = @moui_tui.TermScreen::new(8, 3)
  s.print_char("x", 1)
  ignore(s.take_damage())
  s.cursor_position(3, 5)
  s.cursor_up(1)
  s.cursor_down(1)
  s.cursor_left(2)
  s.cursor_right(1)
  s.cursor_line(2)
  s.cursor_column(3)
  s.save_cursor()
  s.restore_cursor()
  s.tab()
  s.backspace()
  s.carriage_return()
  let rgb = @moui_tui.attrs_with(
    @moui_tui.CellAttrs::default(),
    fg=Some(@moui_tui.Rgb(1, 2, 3)),
  )
  s.set_current_attrs(rgb)
  s.set_scroll_region(1, 3)
  s.set_title("tui")
  s.set_scrollback_limit(10)
  assert_true(s.take_damage().is_empty())
}

///|
test "damage merges writes per row and bumps once per new dirty row" {
  let s = @moui_tui.TermScreen::new(4, 3)
  s.print_char("a", 1)
  s.print_char("b", 1)
  s.cursor_position(3, 1)
  s.print_char("c", 1)
  s.cursor_position(1, 1)
  s.print_char("d", 1)
  inspect(s.revision(), content="2")
  let d = s.take_damage()
  inspect(d.rows.length(), content="2")
  inspect(d.rows[0], content="0")
  inspect(d.rows[1], content="2")
}

///|
test "scroll and clear report whole-region or full damage" {
  let s = @moui_tui.TermScreen::new(3, 3)
  for r in 0..<3 {
    s.cursor_position(r + 1, 1)
    s.print_char("x", 1)
  }
  ignore(s.take_damage())
  // 光标在底部行 → linefeed 触发 scroll_up,整区内容位移
  s.cursor_position(3, 1)
  s.linefeed()
  let d = s.take_damage()
  inspect(d.full, content="false")
  inspect(d.rows.length(), content="3")
  s.erase_in_display(3)
  let full = s.take_damage()
  inspect(full.full, content="true")
  inspect(full.rows.length(), content="0")
  inspect(s.total_lines(), content="3")
}

///|
test "resize always rebuilds the whole screen" {
  let s = @moui_tui.TermScreen::new(4, 2)
  s.print_char("a", 1)
  ignore(s.take_damage())
  s.resize(6, 2)
  inspect(s.take_damage().full, content="true")
  s.print_char("b", 1)
  ignore(s.take_damage())
  // 同尺寸 resize 不产生增量
  s.resize(6, 2)
  assert_true(s.take_damage().is_empty())
}

///|
test "put writes at a cell address without moving the cursor" {
  let s = @moui_tui.TermScreen::new(5, 2)
  let plain = @moui_tui.CellAttrs::default()
  assert_true(s.put(1, 0, "h", 1, plain))
  assert_true(s.put(1, 1, "中", 2, plain))
  inspect(s.line_at(1).text(), content="h中")
  inspect(s.cursor_row(), content="0")
  inspect(s.cursor_col(), content="0")
  // 越界与最后一列放不下宽字符都要报告失败(投影器据此降级)
  assert_true(!s.put(1, 4, "中", 2, plain))
  assert_true(!s.put(2, 0, "x", 1, plain))
  assert_true(!s.put(1, -1, "x", 1, plain))
  let d = s.take_damage()
  inspect(d.rows.length(), content="1")
  inspect(d.rows[0], content="1")
}

///|
test "erase cells clips to the requested span" {
  let s = @moui_tui.TermScreen::new(6, 1)
  for ch in ["a", "b", "c", "d"] {
    s.print_char(ch, 1)
  }
  ignore(s.take_damage())
  // 只擦 [1, 3):量化盒内的裁剪绘制
  s.erase_cells(0, 1, 3, @moui_tui.CellAttrs::default())
  inspect(s.line_at(0).text(), content="a  d")
  s.erase_cells(0, 100, 200, @moui_tui.CellAttrs::default())
  s.erase_cells(9, 0, 6, @moui_tui.CellAttrs::default())
  let d = s.take_damage()
  inspect(d.rows.length(), content="1")
  inspect(d.rows[0], content="0")
}

///|
test "rewriting identical content is not damage" {
  let s = @moui_tui.TermScreen::new(4, 2)
  let plain = @moui_tui.CellAttrs::default()
  assert_true(s.put(0, 0, "a", 1, plain))
  assert_true(s.put(0, 1, "中", 2, plain))
  ignore(s.take_damage())
  // 投影器每帧重画整棵语义树:同字符+同属性的写入不得再次标脏,
  // 否则增量通路永远非空,省下的重绘就不存在
  assert_true(s.put(0, 0, "a", 1, plain))
  assert_true(s.put(0, 1, "中", 2, plain))
  // 擦除已经全空的一行不该产生增量;擦到有内容的行才算
  s.cursor_position(2, 1)
  s.erase_in_line(0)
  assert_true(s.take_damage().is_empty())
  s.cursor_position(1, 2)
  s.erase_in_line(0)
  let d = s.take_damage()
  inspect(d.rows.length(), content="1")
  inspect(d.rows[0], content="0")
  assert_true(
    s.put(0, 0, "a", 1, @moui_tui.attrs_with_fg(plain, @moui_tui.Indexed(1))),
  )
  inspect(s.take_damage().rows.length(), content="1")
}

///|
test "unicode width table covers cjk, emoji and fullwidth forms" {
  inspect(@moui_tui.unicode_width("a"), content="1")
  inspect(@moui_tui.unicode_width("中"), content="2")
  inspect(@moui_tui.unicode_width("한"), content="2")
  inspect(@moui_tui.unicode_width("Ａ"), content="2")
  inspect(@moui_tui.unicode_width("　"), content="2")
  inspect(@moui_tui.unicode_width("🤣"), content="2")
  inspect(@moui_tui.unicode_width("│"), content="1")
}
