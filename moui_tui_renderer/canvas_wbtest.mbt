// 画布层的白盒证据:归属掩码与样式覆盖层是投影器的内部零件,
// 不该为了被断言就晋升成包外 API。

///|
fn cell_at(canvas : Canvas, row : Int, col : Int) -> @tui.Cell {
  canvas.screen.line_at(row).cells[col]
}

///|
/// 高亮带的下划线只能压在「本帧真被认领过」的格子上。
/// 量化盒总比自己写出来的字宽:counter 的焦点按钮是 3 行 × 13 格,而 `[-]`
/// 只占 1 行 3 格。attrs 整段照抄会让下划线落在从没被认领的空格上,在标签
/// 下面画出悬空横线 —— 实测到的「点完按钮出现两根黄线」就是其中两行。
/// 反白与底色在空格上是色带(条目整行高亮靠它),照铺;下划线跟着字形走,
/// 没有字形就没有它。
test "a focus band underlines only claimed cells" {
  let canvas = Canvas::new(12, 4)
  let seq = canvas.new_seq(role_priority(Content))
  ignore(canvas.put(1, 2, "x", @tui.CellAttrs::default(), seq))
  canvas.style_range(
    0,
    0,
    3,
    11,
    @tui.attrs_with(
      @tui.CellAttrs::default(),
      underline=Some(true),
      reverse=Some(true),
    ),
  )
  assert_true(cell_at(canvas, 1, 2).attrs.underline)
  for row in [0, 1, 2, 3] {
    for col in 0..<12 {
      if !(row == 1 && col == 2) {
        assert_false(cell_at(canvas, row, col).attrs.underline)
      }
      // 色带没被削掉:整幅铺开仍然是它的职责。
      assert_true(cell_at(canvas, row, col).attrs.reverse)
    }
  }
}

///|
/// 带移走后的属性回收回归(2026-10-15「点过的区域留着青色块」):
/// 样式带只改 attrs、故意不认领格子,归属清扫永远轮不到它 ——
/// 不留带掩码,带移走后空格子上的反白就永久留在屏上。
/// 有字形的格子照常归画笔与 `sweep_stale` 管,这里只断言无归属的格子。
test "a band that moves away resets the attrs of cells nobody claimed" {
  let canvas = Canvas::new(12, 4)
  // 帧一:一行字形 + 整幅反白带(空格子上是色带)
  let seq = canvas.new_seq(role_priority(Content))
  ignore(canvas.put(1, 2, "x", @tui.CellAttrs::default(), seq))
  canvas.style_range(
    0,
    0,
    3,
    11,
    @tui.attrs_with(@tui.CellAttrs::default(), reverse=Some(true)),
  )
  assert_true(cell_at(canvas, 0, 8).attrs.reverse)
  // 帧二:带移走,画笔照常落字形,帧末清扫回收旧带格子
  canvas.begin_frame()
  let again = canvas.new_seq(role_priority(Content))
  ignore(canvas.put(1, 2, "x", @tui.CellAttrs::default(), again))
  canvas.sweep_stale()
  canvas.sweep_stale_bands()
  for row in 0..<4 {
    for col in 0..<12 {
      assert_false(cell_at(canvas, row, col).attrs.reverse)
    }
  }
  // 字形不受清扫误伤
  assert_true(cell_at(canvas, 1, 2).ch == "x")
}

///|
/// R-P5:词间空位只在能被本画笔归属时才填空白。直接抢格会把兄弟节点的
/// 首字母擦成空格 —— 实测过的 `Entry 0` 变 ` ntry 0`。这里让两个同优先级
/// 画笔竞争一格:先占的 `X` 必须原样存活,后面的词只能绕开它。
test "a word gap never paints over a sibling glyph" {
  let canvas = Canvas::new(8, 2)
  let sibling = canvas.new_seq(role_priority(Content))
  ignore(canvas.put(0, 3, "X", @tui.CellAttrs::default(), sibling))
  let mine = canvas.new_seq(role_priority(Content))
  canvas.write_boxed(0, 0, 0, 7, "ab cd", @tui.CellAttrs::default(), mine)
  assert_true(cell_at(canvas, 0, 0).ch == "a")
  // 词尾空格落在无主的 2 格:这是允许的。
  assert_true(cell_at(canvas, 0, 2).ch == " ")
  // 3 格是兄弟的首字母,gap 与 'c' 都不能把它擦掉。
  assert_true(cell_at(canvas, 0, 3).ch == "X")
  assert_true(cell_at(canvas, 0, 4).ch == "d")
}

///|
/// R-P6:盒子小到画不出笔画时退化为一个 `~` 标记格,区域不能整个消失;
/// 而 3x3 起步的盒必须画出真正的四角,`~` 不许出现在能画框的盒上。
test "a too-small box degrades to a marker cell, a real box gets corners" {
  let canvas = Canvas::new(8, 4)
  let tiny = canvas.new_seq(role_priority(Region))
  canvas.draw_box(0, 0, 0, 3, @tui.CellAttrs::default(), tiny)
  assert_true(cell_at(canvas, 0, 0).ch == "~")
  let real = canvas.new_seq(role_priority(Region))
  canvas.draw_box(1, 0, 3, 2, @tui.CellAttrs::default(), real)
  assert_true(cell_at(canvas, 1, 0).ch == "╭")
  assert_true(cell_at(canvas, 3, 2).ch == "╯")
  assert_true(cell_at(canvas, 2, 0).ch == "│")
}
