///|
test "basic print and cursor" {
  let s = TermScreen::new(10, 3)
  for ch in ["a", "b", "c"] {
    s.print_char(ch, 1)
  }
  inspect(s.cursor_row(), content="0")
  inspect(s.cursor_col(), content="3")
  inspect(s.line_at(0).text(), content="abc")
}

///|
test "linefeed scrolls into scrollback" {
  let s = TermScreen::new(4, 2)
  for _ in 0..<3 {
    for _ in 0..<4 {
      s.print_char("x", 1)
    }
    s.carriage_return()
    s.linefeed()
  }
  inspect(s.total_lines(), content="4")
  inspect(s.line_at(0).text(), content="xxxx")
  inspect(s.line_at(1).text(), content="xxxx")
  inspect(s.line_at(2).text(), content="xxxx")
  inspect(s.line_at(3).text(), content="")
}

///|
test "wide char occupies two cells" {
  let s = TermScreen::new(5, 1)
  s.print_char("a", 1)
  s.print_char("中", 2)
  s.print_char("b", 1)
  inspect(s.cursor_col(), content="4")
  inspect(s.line_at(0).text(), content="a中b")
  // 相同属性连续字符合并为一个 run
  inspect(s.line_at(0).runs().length(), content="1")
}

///|
test "wide char dropped at right edge" {
  let s = TermScreen::new(4, 1)
  s.print_char("a", 1)
  s.print_char("b", 1)
  s.print_char("c", 1)
  s.print_char("中", 2)
  inspect(s.line_at(0).text(), content="abc")
}

///|
test "auto wrap at last column" {
  let s = TermScreen::new(3, 2)
  s.print_char("a", 1)
  s.print_char("b", 1)
  s.print_char("c", 1)
  s.print_char("d", 1)
  inspect(s.line_at(0).text(), content="abc")
  inspect(s.line_at(1).text(), content="d")
  inspect(s.cursor_col(), content="1")
  inspect(s.cursor_row(), content="1")
}

///|
test "sgr attrs and runs merging" {
  let s = TermScreen::new(10, 1)
  let red = CellAttrs::default()
  s.set_current_attrs(attrs_with_fg(red, TermColor::Indexed(1)))
  s.print_char("h", 1)
  s.print_char("i", 1)
  s.set_current_attrs(CellAttrs::default())
  s.print_char(" ", 1)
  s.set_current_attrs(attrs_with_fg(red, TermColor::Indexed(1)))
  s.print_char("!", 1)
  let runs = s.line_at(0).runs()
  inspect(runs.length(), content="3")
  inspect(runs[0].0, content="hi")
  inspect(runs[1].0, content=" ")
  inspect(runs[2].0, content="!")
}

///|
test "erase in display and line" {
  let s = TermScreen::new(4, 3)
  for r in 0..<3 {
    for c in 0..<4 {
      s.cursor_position(r + 1, c + 1)
      s.print_char("x", 1)
    }
  }
  s.cursor_position(2, 2)
  s.erase_in_display(0)
  inspect(s.line_at(0).text(), content="xxxx")
  inspect(s.line_at(1).text(), content="x")
  inspect(s.line_at(2).text(), content="")
  s.cursor_position(2, 2)
  s.erase_in_line(1)
  // 光标在 col2,清除左侧(含光标列)→ 行内已无字符
  inspect(s.line_at(1).text(), content="")
}

///|
test "scroll region and insert/delete lines" {
  let s = TermScreen::new(3, 4)
  // 填充
  for r in 0..<4 {
    s.cursor_position(r + 1, 1)
    s.print_char("a" + r.to_string(), 1)
  }
  // 区域内的行;insert_lines 把区域底部行推入回看头部
  s.set_scroll_region(2, 3)
  s.cursor_position(2, 1)
  s.insert_lines(1)
  inspect(s.line_at(0).text(), content="a2")
  inspect(s.line_at(1).text(), content="a0")
  inspect(s.line_at(2).text(), content="")
  inspect(s.line_at(3).text(), content="a1")
  inspect(s.line_at(4).text(), content="a3")
}

///|
test "cursor save restore and tab" {
  let s = TermScreen::new(20, 4)
  s.cursor_position(3, 5)
  s.save_cursor()
  s.cursor_position(1, 1)
  s.tab()
  inspect(s.cursor_col(), content="8")
  s.restore_cursor()
  inspect(s.cursor_row(), content="2")
  inspect(s.cursor_col(), content="4")
}

///|
test "resize keeps content" {
  let s = TermScreen::new(4, 2)
  s.print_char("a", 1)
  s.print_char("b", 1)
  s.carriage_return()
  s.linefeed()
  s.print_char("c", 1)
  s.resize(6, 4)
  inspect(s.line_at(0).text(), content="ab")
  inspect(s.line_at(1).text(), content="c")
  inspect(s.rows(), content="4")
  // 缩小行数:顶部行滚出到回看缓冲
  s.resize(6, 1)
  inspect(s.total_lines(), content="4")
  inspect(s.line_at(0).text(), content="ab")
  inspect(s.line_at(1).text(), content="c")
  inspect(s.line_at(3).text(), content="")
}

///|
test "scrollback limit" {
  let s = TermScreen::new(2, 2)
  s.set_scrollback_limit(3)
  for row in 0..<6 {
    for col in 0..<2 {
      s.cursor_position(row + 1, col + 1)
      s.print_char("x", 1)
    }
    s.carriage_return()
    s.linefeed()
  }
  inspect(s.total_lines(), content="5")
}

///|
test "reverse index scrolls down" {
  let s = TermScreen::new(2, 2)
  s.print_char("a", 1)
  s.carriage_return()
  s.linefeed()
  s.print_char("b", 1)
  s.carriage_return()
  s.reverse_index()
  inspect(s.cursor_row(), content="0")
  inspect(s.line_at(0).text(), content="a")
  inspect(s.line_at(1).text(), content="b")
  // 光标已在顶部:再 RI 触发向下滚动,底行进入回看头部
  s.reverse_index()
  inspect(s.line_at(0).text(), content="b")
  inspect(s.line_at(1).text(), content="")
  inspect(s.line_at(2).text(), content="a")
}

///|
test "delete and insert chars" {
  let s = TermScreen::new(5, 1)
  for ch in ["a", "b", "c", "d"] {
    s.print_char(ch, 1)
  }
  s.cursor_column(2)
  s.delete_chars(1)
  inspect(s.line_at(0).text(), content="acd")
  s.cursor_column(2)
  s.insert_chars(1)
  inspect(s.line_at(0).text(), content="a cd")
  // 擦除光标处的字符 c
  s.cursor_column(3)
  s.erase_chars(1)
  inspect(s.line_at(0).text(), content="a  d")
}
