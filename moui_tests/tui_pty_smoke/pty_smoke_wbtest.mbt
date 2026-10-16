// S5/S7 交互语义验收:在真 PTY 会话里驱动 examples 的 terminal 入口,
// 逐项证明八条桌面级交互。
//
// 断言全部落在反解出来的 cell 栅格上,不落字节数:「渲染了多少字节」证明不了
// 用户看见了什么,而这一门的价值恰恰在于它跑的是真终端通路。
// 每个用例自己起一个会话,交互状态就不会跨用例泄漏。
//
// 白盒(`_wbtest`)而不是黑盒:反解器与会话是这道门自己的零件,不该因为被测试
// 引用就晋升成包外 API。

///|
/// 断言失败时打印整屏:只报一个 false 会让下一次复现变成猜。
fn check(session : Session, label : String, ok : Bool) -> Unit {
  if !ok {
    session.dump(label)
    session.save_log()
    abort("PTY 冒烟失败:" + label)
  }
}

///|
/// 某个标记所在行,拿不到就把整屏打出来再红:后续断言要用 1 基坐标,
/// 行号错了整条鼠标用例都会失去意义。
fn row_or_check(session : Session, needle : String) -> Int {
  match session.screen().find_row(needle) {
    Some(row) => row
    None => {
      session.dump("missing row: " + needle)
      session.save_log()
      abort("PTY 冒烟失败:栅格里没有包含 " + needle + " 的行")
    }
  }
}

///|
async test "S5 startup projects the split grid with borders and clipped rows" {
  match open_demo() {
    None => ()
    Some(session) => {
      session.await_frame(s => s.has("MoUI TUI split") && s.rebuilds >= 1)
      let screen = session.screen()
      check(session, "startup: header", screen.has("MoUI TUI split"))
      check(session, "startup: left pane title", screen.has("Entries 16"))
      check(session, "startup: right pane title", screen.has("Files 7"))
      check(session, "startup: box-drawing border", screen.has("╭"))
      check(session, "startup: focus hint", screen.has("focus: list"))
      check(session, "startup: first visible row", screen.has("Entry 0"))
      // 裁剪是可见属性而不是内部事实:16 行 × 2 格高于视口,最后一行必须看不见。
      check(
        session,
        "startup: viewport clips the tail row",
        !screen.has("Entry 15"),
      )
      check(
        session,
        "startup: some cell carries a non-default attribute",
        screen.styled_count(style => {
          style.bold ||
          style.dim ||
          style.italic ||
          style.underline ||
          style.reverse ||
          style.fg != "" ||
          style.bg != ""
        }) >
        0,
      )
      check(
        session,
        "startup: first frame is one rebuild",
        screen.rebuilds == 1,
      )
      println("tui pty smoke startup: \{screen.locates} locate(s)")
      session.finish()
    }
  }
}

///|
async test "S5 Tab and Shift-Tab move focus across panes with a visible state" {
  match open_demo() {
    None => ()
    Some(session) => {
      session.await_frame(s => s.has("focus: list"))
      session.send("\t")
      session.await_frame(s => s.has("focus: tree"))
      let moved = session.screen()
      check(session, "tab: focus hint follows", moved.has("focus: tree"))
      check(session, "tab: right pane gains brackets", moved.has("[ Files 7 ]"))
      check(
        session,
        "tab: left pane loses brackets",
        !moved.has("[ Entries 16 ]"),
      )
      session.send("\u{1b}[Z")
      session.await_frame(s => s.has("focus: list"))
      let back = session.screen()
      check(session, "shift-tab: focus hint returns", back.has("focus: list"))
      check(
        session,
        "shift-tab: left pane active again",
        back.has("[ Entries 16 ]"),
      )
      check(
        session,
        "shift-tab: right pane loses brackets",
        !back.has("[ Files 7 ]"),
      )
      session.finish()
    }
  }
}

///|
async test "S5 arrow keys move the selection inside the bordered list" {
  match open_demo() {
    None => ()
    Some(session) => {
      session.await_frame(s => s.has("sel=Entry 0"))
      check(
        session,
        "arrows: starts on the first entry",
        session.screen().has("sel=Entry 0"),
      )
      session.send("\u{1b}[B\u{1b}[B")
      session.await_frame(s => s.has("sel=Entry 2"))
      check(
        session,
        "arrows: two downs land on Entry 2",
        session.screen().has("sel=Entry 2"),
      )
      session.send("\u{1b}[A")
      session.await_frame(s => s.has("sel=Entry 1"))
      check(
        session,
        "arrows: one up steps back",
        session.screen().has("sel=Entry 1"),
      )
      // 方向键属于当前面板:换到树面板之后,同样的键必须改的是节点而不是条目。
      session.send("\t")
      session.send("\u{1b}[B")
      session.await_frame(s => s.has("focus: tree"))
      let tree = session.screen()
      check(session, "arrows: focus left the list", !tree.has("focus: list"))
      check(
        session,
        "arrows: selection stayed on Entry 1",
        tree.has("sel=Entry 1"),
      )
      check(session, "arrows: node moved instead", !tree.has("node=src"))
      session.finish()
    }
  }
}

///|
async test "S5 a bare keypress acts without submission" {
  match open_demo() {
    None => ()
    Some(session) => {
      session.await_frame(s => s.has("Entries 16"))
      check(
        session,
        "instant: starts at 16 entries",
        session.screen().has("Entries 16"),
      )
      // 只发一个 `n`,不带 CR/LF,不带任何提交键。
      session.send("n")
      session.await_frame(s => s.has("Entries 17"))
      let inserted = session.screen()
      check(
        session,
        "instant: insert applied on keydown",
        inserted.has("Entries 17"),
      )
      check(session, "instant: the new row is visible", inserted.has("New 0"))
      // 序号是两条插入命令共用的计数器:`n` 已经用掉 0,所以 `a` 的节点叫
      // `new-1`。断言跟着实际序号写,而不是假设每个键位各自从 0 开始。
      session.send("a")
      session.await_frame(s => s.has("Files 8"))
      let added = session.screen()
      check(
        session,
        "instant: add node applied on keydown",
        added.has("Files 8"),
      )
      check(session, "instant: the new node is visible", added.has("new-1"))
      session.finish()
    }
  }
}

///|
async test "S5 space folds and unfolds the focused tree node" {
  match open_demo() {
    None => ()
    Some(session) => {
      session.await_frame(s => s.has("program.mbt"))
      let opened = session.screen()
      // 折叠前整个子树都在:program.mbt 必须看得见。
      check(session, "fold: subtree visible before", opened.has("program.mbt"))
      check(
        session,
        "fold: count starts at 7",
        opened.int_or_fail("Files") == 7,
      )
      session.send("\t")
      session.send(" ")
      session.await_frame(s => s.has("Files 2"))
      let folded = session.screen()
      check(session, "fold: subtree hidden", !folded.has("program.mbt"))
      check(session, "fold: node count drops", folded.int_or_fail("Files") == 2)
      check(session, "fold: the folder itself stays", folded.has("src"))
      session.send(" ")
      session.await_frame(s => s.has("program.mbt"))
      let again = session.screen()
      check(session, "unfold: subtree back", again.has("program.mbt"))
      check(session, "unfold: node count back", again.int_or_fail("Files") == 7)
      session.finish()
    }
  }
}

///|
async test "S5 mouse click selects and wheel scrolls one pane only" {
  match open_demo() {
    None => ()
    Some(session) => {
      session.await_frame(s => s.has("sel=Entry 0"))
      let before = session.screen()
      check(session, "click: initial selection", before.has("sel=Entry 0"))
      let row = row_or_check(session, "Entry 5")
      // SGR(1006) 坐标是 1 基;第 5 列落在左栏列表框内。
      session.send("\u{1b}[<0;5;\{(row + 1)}M\u{1b}[<0;5;\{(row + 1)}m")
      session.await_frame(s => s.has("sel=Entry 5"))
      let clicked = session.screen()
      check(session, "click: press selects the row", clicked.has("sel=Entry 5"))
      check(
        session,
        "click: pane focus follows the click",
        clicked.has("focus: list"),
      )

      // 针尖必须带 `=`:表头那行的 `focus: list` 在栅格里更靠上,
      // 只写 `list` 会让 int_after 去表头里找一个不存在的数字。
      let list_before = clicked.int_or_fail("list=")
      let tree_before = clicked.int_or_fail("tree=")
      // 滚轮向下:一个格高(scroll_line)对应一格偏移。
      session.send("\u{1b}[<65;5;\{(row + 1)}M")
      // needle 钉成「list= 后跟目标读数」:rebuild 计数和滚动偏移都是回放事实。
      session.await_frame(s => s.has("list=\{(list_before + 1)} "))
      let scrolled = session.screen()
      check(
        session,
        "wheel: the hovered pane scrolled",
        scrolled.int_or_fail("list=") == list_before + 1,
      )
      check(
        session,
        "wheel: the other pane did not",
        scrolled.int_or_fail("tree=") == tree_before,
      )
      // 滚动只换视口,不换选择:选中项必须还跟着它自己那一行。
      check(
        session,
        "wheel: selection survived the scroll",
        scrolled.has("sel=Entry 5"),
      )
      session.finish()
    }
  }
}

///|
/// 标记落在第几格(0 基)。鼠标坐标必须按格给:猜列号会点到空白,
/// 于是「什么都没发生」也能被读成通过。
fn col_or_check(
  session : Session,
  screen : Screen,
  row : Int,
  ch : Char,
) -> Int {
  let mut col = 0
  while col < screen.cols {
    if screen.at(row, col).ch == ch {
      return col
    }
    col = col + 1
  }
  session.dump("missing cell: " + ch.to_string())
  session.save_log()
  abort(
    "PTY 冒烟失败:第 " +
    row.to_string() +
    " 行没有 " +
    ch.to_string() +
    " 那一格",
  )
}

///|
/// 点一格:按下 + 抬起。调用方给栅格的 0 基列行,SGR(1006) 要的是 1 基。
async fn tap_cell(session : Session, col~ : Int, row~ : Int) -> Unit {
  session.send(
    "\u{1b}[<0;\{(col + 1)};\{(row + 1)}M\u{1b}[<0;\{(col + 1)};\{(row + 1)}m",
  )
}

///|
/// 点一格(按 SGR 1006 的按下+抬起),等内容里出现 `expect` 那行读数,
/// 再读回 counter 的 Count。`expect` 必须锚新帧才出现的读数;
/// 「不该变」的点击传当前读数即可 —— needle 已成立,等待只剩确认窗。
async fn click_cell(
  session : Session,
  col~ : Int,
  row~ : Int,
  expect~ : String,
) -> Int {
  tap_cell(session, col~, row~)
  session.await_frame(s => s.has(expect))
  session.screen().int_or_fail("Count:")
}

///|
/// 某行里被下划线覆盖的最左/最右格(没找到就是 -1/-1)。
fn underlined_span(screen : Screen, row : Int) -> (Int, Int) {
  let mut lo = -1
  let mut hi = -1
  let mut col = 0
  while col < screen.cols {
    if screen.at(row, col).style.underline {
      if lo < 0 {
        lo = col
      }
      hi = col
    }
    col = col + 1
  }
  (lo, hi)
}

///|
/// 整行没有字形却带下划线的行数。下划线是跟着字形走的装饰,压在从没被
/// 认领的空格上就成了一条悬空横线 —— 用户报的「点完按钮出现两根黄线」,
/// 实测是焦点量化盒下面两整空格行各被画了一条。
fn floating_rules(screen : Screen) -> Int {
  let mut count = 0
  for row in 0..<screen.rows {
    let mut glyph = false
    for col in 0..<screen.cols {
      if screen.at(row, col).ch != ' ' {
        glyph = true
      }
    }
    let (_, hi) = underlined_span(screen, row)
    if !glyph && hi >= 0 {
      count = count + 1
    }
  }
  count
}

///|
/// 「视觉盒 = 命中盒」的真机回归:宿主把点击换成格中心那一个点,所以按钮标签
/// 画在哪一行,哪一行的中心就必须落在按钮帧里。
/// 54x11 是实测到的错位档 —— 帧顶边 y=110 落在第 6 格的下半格,
/// 外扩量化(顶边 floor)把 `[-]` 画在第 6 行,而第 6 行的中心在 104,点它没反应;
/// 改按中心量化后标签落在第 7 行,和命中区同一行。
async test "S5 the row a button label is drawn on is the row that fires" {
  match counter_binary() {
    None => ()
    Some(path) => {
      let session = Session::open(path, cols=54, rows=11)
      session.await_frame(s => s.has("Count:"))
      let before = session.screen()
      let label_row = row_or_check(session, "[-]")
      let label_col = col_or_check(session, before, label_row, '-')
      let count = before.int_or_fail("Count:")
      // 看得见就得点得着:点标签那一格,Count 必须减一。
      let after = click_cell(
        session,
        col=label_col,
        row=label_row,
        expect="Count: \{count - 1}",
      )
      check(session, "click: the drawn label row fires", after == count - 1)
      // 焦点带必须贴着标签:`[-]` 占 3 格,再加词尾那一格空白,总共不超过
      // 4 格。量化盒有 13 格宽,整幅刷下划线就会在按钮右边拖出一条黄线。
      // 读屏要放在下一次点击之前:点命中盒外面那一格会把焦点清掉,
      // 届时整屏已经没有下划线,断言就变成在比谁跑得快。
      let band = session.screen()
      let (lo, hi) = underlined_span(band, label_row)
      check(
        session,
        "focus: the underline hugs the label",
        lo <= label_col && hi >= label_col && hi - lo <= 3,
      )
      check(
        session,
        "focus: no underline floats over a glyph-free row",
        floating_rules(band) == 0,
      )
      // 命中盒不能往外扩:标签上面那一格不属于按钮,点了不该动。
      // expect 传当前读数:needle 已成立,await 只剩确认窗,负断言读的是稳定帧。
      let above = click_cell(
        session,
        col=label_col,
        row=label_row - 1,
        expect="Count: \{count - 1}",
      )
      check(
        session,
        "click: the row above the label stays outside the hit box",
        above == count - 1,
      )
      session.finish()
    }
  }
}

///|
async test "S5 resize reflows with a full rebuild and leaves no ghosts" {
  match open_demo() {
    None => ()
    Some(session) => {
      session.await_frame(s => s.has("focus: list"))
      let before = session.screen()
      check(session, "resize: baseline focus hint", before.has("focus: list"))
      session.resize_to(60, 20)
      // rebuild 计数在回放里单调递增,是 resize 全量重建的确定性锚点。
      session.await_frame(s => s.rebuilds >= before.rebuilds + 1)
      let small = session.screen()
      check(
        session,
        "resize: shrink rebuilt the screen",
        small.rebuilds == before.rebuilds + 1,
      )
      check(
        session,
        "resize: still laid out at the new size",
        small.has("MoUI TUI split"),
      )
      check(session, "resize: panes still side by side", small.has("Files 7"))
      let mut clean = true
      for r in 20..<ROWS {
        if !small.row_untouched(r) {
          clean = false
        }
      }
      // 缩小之后写超出新网格的行,就是残影的直接来源。
      check(session, "resize: nothing painted outside the new grid", clean)
      session.resize_to(COLS, ROWS)
      session.await_frame(s => s.rebuilds >= small.rebuilds + 1)
      let full = session.screen()
      check(
        session,
        "resize: grow rebuilt again",
        full.rebuilds == small.rebuilds + 1,
      )
      // 整屏脏必须逐行重画:每一行都被定位写过,才没有从没被覆盖的旧格。
      check(
        session,
        "resize: every row repainted",
        full.painted_count() == ROWS,
      )
      check(
        session,
        "resize: selection survived the reflow",
        full.has("sel=Entry 0"),
      )
      session.finish()
    }
  }
}

///|
/// S7 八项合一 demo 的门,管第 6–8 项:瞬时按键、鼠标点击/滚轮、resize 重排。
/// 前五项由上面那批 `tui_split` 用例覆盖;这里补的三件事只有这个 app 有载体 ——
/// 列表能被文本框逐键过滤、两栏各自滚动、缩到极窄时两栏都得活着。
/// 全程没发过一个 CR/LF:`rows=` 每按一下都在动,就是「不等提交」的证据。
async test "S7 mouse, per-keystroke filter, wheel and resize drive the layers demo" {
  match open_layers() {
    None => ()
    Some(session) => {
      session.await_frame(s => s.has("sel=Background"))
      let start = session.screen()
      check(
        session,
        "layers: startup status",
        start.has("sel=Background") && start.has("rows=8 hide=2 only=0"),
      )
      // 看得见的那一格就是命中格:`[x]` 画在列表行里,投影按中心量化,
      // 所以点标记那一格必然落在这条行的命中框内,不用按像素猜。
      let labels_row = row_or_check(session, "] Labels")
      let labels_col = col_or_check(session, start, labels_row, '[')
      tap_cell(session, col=labels_col, row=labels_row)
      session.await_frame(s => s.has("sel=Labels"))
      check(
        session,
        "click: the marked row is selected",
        session.screen().has("sel=Labels"),
      )
      // 选中跟着那一层,而不是跟着第几格:切掉可见性后,读回来的是这条行的标记。
      session.send(" ")
      session.await_frame(s => s.has("hide=3"))
      let toggled = session.screen()
      check(session, "space: that layer is now hidden", toggled.has("hide=3"))
      check(
        session,
        "space: the marker reads back as off",
        toggled.has("[ ] Labels") && !toggled.has("[x] Labels"),
      )
      // 文本框要点它自己画出来的占位符才拿到焦点:demo 没有应用侧的请求焦点接口。
      let field_row = row_or_check(session, "narrow")
      let field_col = col_or_check(session, toggled, field_row, 'n')
      tap_cell(session, col=field_col, row=field_row)
      session.send("s")
      session.await_frame(s => s.has("filter=s rows=6"))
      check(
        session,
        "type: one keystroke reshapes the list",
        session.screen().has("filter=s rows=6"),
      )
      session.send("t")
      session.await_frame(s => s.has("filter=st rows=2"))
      check(
        session,
        "type: the second keystroke narrows again",
        session.screen().has("filter=st rows=2"),
      )
      session.send("r")
      session.send("o")
      session.await_frame(s => s.has("filter=stro rows=1"))
      let typed = session.screen()
      check(
        session,
        "type: four keystrokes leave one row",
        typed.has("filter=stro rows=1"),
      )
      check(
        session,
        "type: the header shows the field holds focus",
        typed.has("focus: filter"),
      )
      // 终端解码器对一个可打印字节会同时发 Keyboard 和 TextInput
      // (`moui_terminal_host/decode.mbt::emit_text_key`),所以这条门同时证明
      // 「没松开时是命令」和「松开时是字符」:Space 在过滤态被释放,
      // 于是 hide= 不动,而那一个空格进了框,把最后一行也滤掉。
      session.send(" ")
      session.await_frame(s => s.has("rows=0"))
      let spaced = session.screen()
      check(
        session,
        "space while typing does not toggle a layer",
        spaced.has("hide=3"),
      )
      check(
        session,
        "space while typing reached the field",
        spaced.has("rows=0"),
      )
      // 退格是框里还能用的编辑键(方向键被面板占着):五下把 `stro ` 清空。
      session.send("\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}")
      session.await_frame(s => s.has("filter=- rows=8"))
      check(
        session,
        "backspace edits the field",
        session.screen().has("filter=- rows=8"),
      )
      // 焦点进框之后方向键仍归列表:实测选中从 Labels 走到 Shadows,插入点不动。
      // 这是 `program_commands` 那条「按面板而不是按角色路由」的取舍,不是漏掉的键。
      session.send("\u{1b}[B")
      session.await_frame(s => s.has("sel=Shadows"))
      check(
        session,
        "arrows still command the list while typing",
        session.screen().has("sel=Shadows"),
      )
      // 滚轮按悬停的那一栏走,和键盘焦点无关:焦点还在文本框,
      // 滚列表栏只动 `row=`,`file=` 一格都不该碰。
      let stream_row = row_or_check(session, "] Streamlines")
      let stream_col = col_or_check(session, session.screen(), stream_row, '[')
      let before_scroll = session.screen()
      let row_before = before_scroll.int_or_fail("row=")
      let file_before = before_scroll.int_or_fail("file=")
      session.send("\u{1b}[<65;\{(stream_col + 1)};\{(stream_row + 1)}M")
      session.await_frame(s => s.has("row=\{(row_before + 1)} "))
      let scrolled = session.screen()
      check(
        session,
        "wheel: the hovered pane scrolled",
        scrolled.int_or_fail("row=") == row_before + 1,
      )
      check(
        session,
        "wheel: the other pane did not",
        scrolled.int_or_fail("file=") == file_before,
      )
      // 滚回来:上限是内容超出视口的那一格,所以这里只有一格可滚。
      session.send("\u{1b}[<64;\{(stream_col + 1)};\{(stream_row + 1)}M")
      session.await_frame(s => s.has("row=\{(row_before)} "))
      check(
        session,
        "wheel: scrolling back lands where it started",
        session.screen().int_or_fail("row=") == row_before,
      )
      // resize:三档走一圈,每一档都必须两栏俱在。
      let full = session.screen()
      session.resize_to(72, 14)
      session.await_frame(s => s.rebuilds >= full.rebuilds + 1)
      let wide = session.screen()
      check(
        session,
        "resize 72x14: shrinking rebuilt the screen",
        wide.rebuilds == full.rebuilds + 1,
      )
      check(
        session,
        "resize 72x14: both pane titles survive",
        wide.has("Layers 8/8") && wide.has("Files 10"),
      )
      check(
        session,
        "resize 72x14: both panes still have rows",
        wide.has("[x] Background") && wide.has("[src]"),
      )
      check(session, "resize 72x14: status survived", wide.has("sel=Shadows"))
      let mut clean = true
      for r in 14..<ROWS {
        if !wide.row_untouched(r) {
          clean = false
        }
      }
      check(
        session, "resize 72x14: nothing painted outside the new grid", clean,
      )
      session.resize_to(43, 11)
      session.await_frame(s => s.rebuilds >= wide.rebuilds + 1)
      let tiny = session.screen()
      check(
        session,
        "resize 43x11: both pane titles survive",
        tiny.has("Layers 8/8") && tiny.has("Files 10"),
      )
      check(
        session,
        "resize 43x11: both panes still have rows",
        tiny.has("[x] Background") && tiny.has("[src]"),
      )
      // 43 格放不下整条状态行,尾部 `only=` 被截是这条路的已知上限;
      // 要断言的是开头的读数还在,用户才知道选中在哪。
      check(
        session,
        "resize 43x11: the status head survives",
        tiny.has("sel=Shadows"),
      )
      let mut tiny_clean = true
      for r in 11..<ROWS {
        if !tiny.row_untouched(r) {
          tiny_clean = false
        }
      }
      check(
        session, "resize 43x11: nothing painted outside the new grid", tiny_clean,
      )
      session.resize_to(COLS, ROWS)
      session.await_frame(s => s.rebuilds >= tiny.rebuilds + 1)
      let back = session.screen()
      check(
        session,
        "resize back: grew with another rebuild",
        back.rebuilds == tiny.rebuilds + 1,
      )
      check(
        session,
        "resize back: every row repainted",
        back.painted_count() == ROWS,
      )
      check(
        session,
        "resize back: the whole status line is readable again",
        back.has("sel=Shadows") && back.has("hide=3 only=0"),
      )
      session.finish()
    }
  }
}

///|
/// 一栏框的左右角列:顶行每一对 `╭`…`╮` 算一栏。极矮窗口里两栏并排,
/// 只取第一个角就会把另一栏的格子当成框外,断言于是空过。
fn ring_spans(screen : Screen, row : Int) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let mut left = -1
  for col in 0..<screen.cols {
    let ch = screen.at(row, col).ch
    if ch == '╭' {
      left = col
    } else if ch == '╮' && left >= 0 {
      out.push((left, col))
      left = -1
    }
  }
  out
}

///|
/// 框线行上混进来的字形数。那一行只该有笔画和空格:列表行压上顶边框或
/// 底边框,就是用户报的「列表有时候会滚到列表框外面」。
fn ring_glyph_count(screen : Screen, row : Int, left : Int, right : Int) -> Int {
  let mut count = 0
  for col in left..<=right {
    let ch = screen.at(row, col).ch.to_int()
    // U+2500–U+257F 是制框符号区,笔画本身不算被抢走的字形。
    if ch != 0x20 && !(ch >= 0x2500 && ch <= 0x257f) {
      count = count + 1
    }
  }
  count
}

///|
/// 被反白盖住的框线格数。反白带是选中的唯一表示,但它盖住边框那一圈格子时
/// 用户看到的就不是「哪一行选中」而是一个吞掉整框的色块。
fn ring_reversed_count(
  screen : Screen,
  top : Int,
  bottom : Int,
  left : Int,
  right : Int,
) -> Int {
  let mut count = 0
  for col in left..<=right {
    if screen.at(top, col).style.reverse {
      count = count + 1
    }
    if screen.at(bottom, col).style.reverse {
      count = count + 1
    }
  }
  for row in top..<=bottom {
    if screen.at(row, left).style.reverse {
      count = count + 1
    }
    if screen.at(row, right).style.reverse {
      count = count + 1
    }
  }
  count
}

///|
/// 极矮窗口(用户截图那种 190x12,一栏只剩一圈框加一行内边)的两条框线不变量:
/// 框线格只属于框,高亮带也不许盖住框线。像素边框只有几 px 而终端一格 8x16,
/// 两者抢同一圈格子时谁先量化谁赢,所以投影必须分成「边框用整栏、
/// 字与带用内侧」两条范围 —— 这条门就是那个划分在真终端上的证据。
async test "S7 a short pane keeps its ring free of rows and bands" {
  match layers_binary() {
    None => println("skip: no tui_layers binary, set MOUI_TUI_LAYERS_BIN")
    Some(path) => {
      let session = Session::open(path, cols=190, rows=12)
      session.await_frame(s => s.has("[x] Background") && s.has("[src]"))
      let start = session.screen()
      let top = row_or_check(session, "╭")
      let bottom = row_or_check(session, "╰")
      let spans = ring_spans(start, top)
      check(
        session,
        "short window: both panes drew a ring",
        spans.length() == 2,
      )
      // 一栏只剩一行内边:这是 12 行窗口的实测几何,框再吃一格就没有内容行可画了。
      check(
        session,
        "short window: the ring leaves one interior row",
        bottom == top + 2,
      )
      check(
        session,
        "short window: both panes still show a row",
        start.has("[x] Background") && start.has("[src]"),
      )
      for span in spans {
        let (left, right) = span
        check(
          session,
          "short window: ring rows carry only strokes",
          ring_glyph_count(start, top, left, right) == 0 &&
          ring_glyph_count(start, bottom, left, right) == 0,
        )
      }
      // 滚一格:第二层被推进可视区,但它必须落在内边行之外就没有的位置上,
      // 而不是写在底边框那一格(修之前的实测症状)。
      let item_row = row_or_check(session, "] Background")
      let list_col = col_or_check(
        session,
        start,
        row_or_check(session, "[ Layers"),
        '[',
      )
      session.send("\u{1b}[<65;\{(list_col + 1)};\{(item_row + 1)}M")
      // 这条断言组没有「新文本」可锚(滚一格可能仍是 Background 可见),
      // 但滚动必然重绘:`await_reply` 等首字节再确认,把「没反应」和「没等到」区分开。
      session.await_reply()
      let scrolled = session.screen()
      for span in ring_spans(scrolled, top) {
        let (left, right) = span
        check(
          session,
          "wheel: the ring rows are still only strokes",
          ring_glyph_count(scrolled, top, left, right) == 0 &&
          ring_glyph_count(scrolled, bottom, left, right) == 0,
        )
      }
      check(
        session,
        "wheel: the list did not go blank",
        scrolled.has("] Background") || scrolled.has("] Streamlines"),
      )
      // 点树根:那一格被反白,但反白必须整条落在框的内侧。
      let src_row = row_or_check(session, "[src]")
      let src_col = col_or_check(session, scrolled, src_row, '[')
      tap_cell(session, col=src_col + 1, row=src_row)
      // 反白带是 attrs 变化,没有文本 needle 可锚;点击必然触发重绘,等响应。
      session.await_reply()
      let tapped = session.screen()
      check(
        session,
        "tap: a selection band reached the terminal",
        tapped.styled_count(style => style.reverse) > 0,
      )
      for span in ring_spans(tapped, top) {
        let (left, right) = span
        check(
          session,
          "tap: the band never covers the ring",
          ring_reversed_count(tapped, top, bottom, left, right) == 0,
        )
        check(
          session,
          "tap: the ring rows are still only strokes",
          ring_glyph_count(tapped, top, left, right) == 0 &&
          ring_glyph_count(tapped, bottom, left, right) == 0,
        )
      }
      session.finish()
    }
  }
}

///|
/// 某一行上带反白的格子数。反白带是选中的唯一表示,也是残留最显眼的形态:
/// 带一移走,它留在空格子上的反白必须跟着走。
fn reversed_in_row(screen : Screen, row : Int) -> Int {
  reversed_in_cols(screen, row, col_from=0, col_to=screen.cols - 1)
}

///|
/// `[col_from, col_to]` 闭区间内的反白格数。终端同一行被左右两栏共用,
/// 断言一栏的带时必须把另一栏的合法带排除在外,否则整行清零的断言
/// 会永远误红(列表行和树行永远共线)。
fn reversed_in_cols(
  screen : Screen,
  row : Int,
  col_from~ : Int,
  col_to~ : Int,
) -> Int {
  let mut count = 0
  let mut col = col_from
  while col <= col_to {
    if screen.at(row, col).style.reverse {
      count = count + 1
    }
    col = col + 1
  }
  count
}

///|
/// 选中带移动后的残留回归(2026-10-15 用户截图):
/// 图层行高 40px,在 100x30 的格子上是 2.5 行 —— 选中带除了文字行,
/// 还在下面占一整行空格子。高亮带只改属性、不认领格子,老实现的
/// 归属清扫永远轮不到它们:选中一挪走,旧带位置空行上的反白就
/// 永久留在屏上,看起来就是「点过的区域留着一块没有字的青色」。
async test "S7 a moved selection sweeps the band off the vacated row" {
  match open_layers() {
    None => println("skip: no tui_layers binary, set MOUI_TUI_LAYERS_BIN")
    Some(session) => {
      session.await_frame(s => s.has("sel=Background"))
      let start = session.screen()
      check(
        session,
        "band flow: list starts on Background",
        start.has("sel=Background"),
      )
      let bg = row_or_check(session, "] Background")
      let below = bg + 1
      // 初始选中就有带:文字行下面那一整行空格子都是反白。
      check(
        session,
        "band flow: the selected row's tail line carries the band",
        reversed_in_row(start, below) >= 10,
      )
      // 方向键把选中挪到 Grid(不动焦点):旧带所在的空行必须一格格不留,
      // 新带必须真的落在 Grid 行上。
      session.send("\u{1b}[B")
      session.await_frame(s => s.has("sel=Grid"))
      let moved = session.screen()
      check(
        session,
        "band flow: selection moved to Grid",
        moved.has("sel=Grid"),
      )
      check(
        session,
        "band flow: the vacated tail line keeps no reversed cell",
        reversed_in_row(moved, below) == 0,
      )
      let grid_row = row_or_check(session, "] Grid")
      check(
        session,
        "band flow: the new band lands on the Grid row",
        reversed_in_row(moved, grid_row) >= 10,
      )
      session.finish()
    }
  }
}

///|
/// 点击选中的行必须把带带在**自己**身上(2026-10-15 用户报:左栏点击后
/// 青色闪现在上一次点击处、右栏被点选项前面亮一块)。焦点带先刷、选中带后刷
/// 之前,点击先移焦点选中后落地:旧选中行(焦点已走、选中未变)的反白带
/// 闪现一帧;树的行里标签按钮的盒子从缩进+折叠钮之后才开始,按钮的焦点带
/// 只盖中段,行带只在按钮没盖住的前几格留下反白。
/// 注意:终端同一行被左右两栏共用,列表断言只用 `[10,40]` 列,树断言只用
/// `[50,95]` 列——对面一栏的合法选中带不许计进断言,也不许被它误红。
async test "S7 a clicked row keeps the selection band on itself" {
  match open_layers() {
    None => println("skip: no tui_layers binary, set MOUI_TUI_LAYERS_BIN")
    Some(session) => {
      // 列区间:列表带只在 [10,40],树带只在 [50,95];对面一栏的合法带
      // 不计进断言。
      let list = (10, 40)
      let tree = (50, 95)
      session.await_frame(s => s.has("sel=Background"))
      let start = session.screen()
      let bg = row_or_check(session, "] Background")
      // 点 Background 的行名(owned 格):点击选中的行自己必须亮整行带。
      tap_cell(session, col=nth_glyph_col_mid(start, bg), row=bg)
      // sel=Background 一直成立,没有新文本可锚;点击改变焦点带,等重绘响应。
      session.await_reply()
      let picked = session.screen()
      check(
        session,
        "clicked flow: selection followed the click",
        picked.has("sel=Background"),
      )
      check(
        session,
        "clicked flow: the clicked row carries the band on its own line",
        reversed_in_cols(picked, bg, col_from=list.0, col_to=list.1) >= 10,
      )
      let grid_start = row_or_check(session, "] Grid")
      // 点 Grid:带必须**当拍**跟到 Grid,Background 连尾行一起收干净。
      tap_cell(
        session,
        col=nth_glyph_col_mid(picked, grid_start),
        row=grid_start,
      )
      session.await_frame(s => s.has("sel=Grid"))
      let moved = session.screen()
      check(
        session,
        "clicked flow: selection moved to Grid",
        moved.has("sel=Grid"),
      )
      check(
        session,
        "clicked flow: the band lands on the clicked row",
        reversed_in_cols(moved, grid_start, col_from=list.0, col_to=list.1) >=
        10,
      )
      let bg_after = row_or_check(session, "] Background")
      check(
        session,
        "clicked flow: the vacated row and its tail keep no reversed cell",
        reversed_in_cols(moved, bg_after, col_from=list.0, col_to=list.1) == 0 &&
        reversed_in_cols(moved, bg_after + 1, col_from=list.0, col_to=list.1) ==
        0,
      )
      // 点空白处(两个面板之间,布景没有按钮):焦点散了,带不许闪没。
      tap_cell(session, col=45, row=grid_start)
      // blur 只撤焦点带(attrs),sel=Grid 不变,没有新文本可锚;等重绘。
      session.await_reply()
      let blurred = session.screen()
      check(
        session,
        "clicked flow: a dead-zone click does not blink the band",
        reversed_in_cols(blurred, grid_start, col_from=list.0, col_to=list.1) >=
        10,
      )
      // 右栏:点 [runtime] 的标签(最后一个 '[',折叠钮后面那一枚)。
      // 被点行的带必须从**行首**一直盖过标签字形:修复前标签按钮的焦点带
      // 把标签四格的反白刷掉,行带只剩折叠钮前面那一小块。
      let runtime_row = row_or_check(session, "[runtime]")
      tap_cell(
        session,
        col=last_open_bracket(moved, runtime_row),
        row=runtime_row,
      )
      session.await_frame(s => s.has("node=runtime"))
      let tree_frame = session.screen()
      check(
        session,
        "clicked flow: tree selection moved",
        tree_frame.has("node=runtime"),
      )
      let runtime_now = row_or_check(session, "[runtime]")
      let src_now = row_or_check(session, "[src]")
      let label_col = last_open_bracket(tree_frame, runtime_now)
      check(
        session,
        "clicked flow: the tree band reaches the row's front marker columns",
        first_reversed_col(tree_frame, runtime_now) <= label_col,
      )
      check(
        session,
        "clicked flow: the tree band covers the label glyphs too",
        reversed_in_cols(
          tree_frame,
          runtime_now,
          col_from=label_col,
          col_to=label_col + 8,
        ) >=
        8,
      )
      check(
        session,
        "clicked flow: the previous tree selection keeps no reversed cell",
        reversed_in_cols(tree_frame, src_now, col_from=tree.0, col_to=tree.1) ==
        0 &&
        reversed_in_cols(
          tree_frame,
          src_now + 1,
          col_from=tree.0,
          col_to=tree.1,
        ) ==
        0,
      )
      session.finish()
    }
  }
}

///|
/// H4 主题接线的终端级证据:`--theme dark` 启动的会话必须把主题色量化
/// 进可见格子,而默认调色板的按钮蓝(`idx:4`)一格不剩。期望值与被测链路
/// 共用同一条量化函数,钉的是「Theme 走完了 host→palette→cells」,
/// 不是具体 RGB 表。
async test "H4 a themed launch repaints cells with theme colors" {
  match layers_binary() {
    None => ()
    Some(path) => {
      let session = Session::open(path, cols=100, rows=30, args=[
        "--theme", "dark",
      ])
      session.await_frame(s => s.has("sel=Background"))
      let theme = @core.Theme::neutral().with_palette(
        @core.ColorPalette::dark(),
      )
      let palette = @tui_renderer.TuiPalette::from_theme(theme)
      let expected = match palette.primary {
        @tui.Indexed(n) => "idx:" + n.to_string()
        _ => fail("dark primary must quantize to a 256-palette index")
      }
      let screen = session.screen()
      check(
        session,
        "themed: primary cells carry the quantized theme color",
        screen.styled_count(style => style.fg == expected) > 0,
      )
      check(
        session,
        "themed: the default button blue is gone",
        screen.styled_count(style => style.fg == "idx:4") == 0,
      )
      session.finish()
    }
  }
}

///|
/// 第 want 个非空白格的列(跳过边框与空白):点行名用,别点在边框上。
fn nth_glyph_col_mid(screen : Screen, row : Int) -> Int {
  let mut seen = 0
  let mut col = 0
  while col < screen.cols {
    if screen.at(row, col).ch != ' ' {
      if seen == 4 {
        return col
      }
      seen = seen + 1
    }
    col = col + 1
  }
  screen.cols - 1
}

///|
/// 某行最后一个 '[' 的列:树行的标签按钮在折叠钮之后,最后一个 '['
/// 就是标签首格;点它落在标签按钮的盒子里,而不是折叠钮上。
fn last_open_bracket(screen : Screen, row : Int) -> Int {
  let mut col = screen.cols - 1
  while col >= 0 {
    if screen.at(row, col).ch == '[' {
      return col
    }
    col = col - 1
  }
  0
}

///|
/// 该行最左的反白格(没有就是 -1):树的高亮带必须从行首算起。
fn first_reversed_col(screen : Screen, row : Int) -> Int {
  let mut col = 0
  while col < screen.cols {
    if screen.at(row, col).style.reverse {
      return col
    }
    col = col + 1
  }
  -1
}
