///|
/// 解码表测试:全部对着终端字节流写,不需要真 TTY。
/// 覆盖计划里记的四类证据:序列被拆成多次 read、修饰键与重复/释放、
/// SGR 鼠标的按下/拖动/释放/滚轮、以及无法识别的序列必须被消费而不是卡住缓冲。
fn ascii(s : String) -> Bytes {
  // 夹具专用:转义序列都在 0x00-0x7f,高位字节用例走 Array[Byte] 字面量。
  let arr : Array[Byte] = []
  for ch in s {
    arr.push(ch.to_int().to_byte())
  }
  Bytes::from_array(arr)
}

///|
fn one(
  dec~ : @moui_terminal_host.TerminalDecoder,
  s : String,
) -> @moui_terminal_host.TerminalEvent {
  let events = dec.feed_bytes(ascii(s))
  if events.length() != 1 {
    abort(
      "期望单条事件,实到 " + events.length().to_string() + " 条: " + s,
    )
  }
  events[0]
}

///|
fn key_of(ev : @moui_terminal_host.TerminalEvent) -> @core.KeyboardEvent {
  match ev {
    @moui_terminal_host.Key(k) => k
    _ => abort("期望 Keyboard 事件")
  }
}

///|
fn mouse_of(
  ev : @moui_terminal_host.TerminalEvent,
) -> @moui_terminal_host.MouseReport {
  match ev {
    @moui_terminal_host.Mouse(m) => m
    _ => abort("期望 Mouse 事件")
  }
}

///|
fn wheel_of(
  ev : @moui_terminal_host.TerminalEvent,
) -> @moui_terminal_host.WheelReport {
  match ev {
    @moui_terminal_host.Wheel(w) => w
    _ => abort("期望 Wheel 事件")
  }
}

///|
fn pressed(
  key : String,
  modifiers? : @core.KeyModifiers = @core.KeyModifiers::none(),
) -> @moui_terminal_host.TerminalEvent {
  @moui_terminal_host.Key(
    @core.KeyboardEvent::new(key~, pressed=true, modifiers~),
  )
}

///|
test "可打印字符同时给出按键与文本插入" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  let events = dec.feed_bytes(ascii("a"))
  assert_eq(events.length(), 2)
  assert_eq(
    events[0],
    @moui_terminal_host.Key(
      @core.KeyboardEvent::new(key="a", pressed=true, text=Some("a")),
    ),
  )
  assert_eq(
    events[1],
    @moui_terminal_host.Text(@core.TextInputEvent::InsertText("a")),
  )
  assert_eq(dec.pending_bytes(), 0)
}

///|
test "控制字节用与编码侧同名的键表" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  assert_eq(one(dec~, "\r"), pressed("Enter"))
  assert_eq(one(dec~, "\n"), pressed("Enter"))
  assert_eq(one(dec~, "\t"), pressed("Tab"))
  assert_eq(one(dec~, "\u{7f}"), pressed("Backspace"))
  // Ctrl+A 与 Ctrl+Space 带 control;Enter/Tab 本身就是控制码,不该再叠一层。
  let ctrl_a = key_of(one(dec~, "\u{1}"))
  assert_eq(ctrl_a.key, "a")
  assert_eq(ctrl_a.modifiers, @core.KeyModifiers::new(control=true))
  assert_eq(
    one(dec~, "\u{0}"),
    @moui_terminal_host.Key(
      @core.KeyboardEvent::new(
        key="Space",
        pressed=true,
        text=Some(" "),
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
}

///|
test "一条序列被拆成两次读取" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  assert_eq(dec.feed_bytes(ascii("\u{1b}[")).length(), 0)
  assert_eq(dec.pending_bytes(), 2)
  let events = dec.feed_bytes(ascii("A"))
  assert_eq(events.length(), 1)
  assert_eq(events[0], pressed("ArrowUp"))
  assert_eq(dec.pending_bytes(), 0)
}

///|
test "裸 ESC 等流停才结算,同批次的前缀立即消歧" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  // 只有 ESC:feed 不派发,否则会打断 ESC x / ESC [ A。
  assert_eq(dec.feed_bytes(ascii("\u{1b}")).length(), 0)
  assert_eq(dec.pending_bytes(), 1)
  // 后续字节下一批到了:按序列解,不当成 Escape。
  let events = dec.feed_bytes(ascii("[A"))
  assert_eq(events.length(), 1)
  assert_eq(events[0], pressed("ArrowUp"))
  // poll 超时(这一轮没有更多字节)才把裸 ESC 结算成 Escape 键。
  assert_eq(dec.feed_bytes(ascii("\u{1b}")).length(), 0)
  assert_eq(dec.flush(), Some(pressed("Escape")))
  assert_eq(dec.pending_bytes(), 0)
  // 前缀和后续字节同批到达:按 Alt+a 解,不留缓冲。
  assert_eq(
    one(dec~, "\u{1b}a"),
    pressed("a", modifiers=@core.KeyModifiers::new(alt=true)),
  )
  assert_eq(dec.pending_bytes(), 0)
  // 只发了 `ESC [` 的残序列:flush 后整条丢弃,不留下会污染下一次按键的前缀。
  assert_eq(dec.feed_bytes(ascii("\u{1b}[")).length(), 0)
  assert_eq(dec.flush(), None)
  assert_eq(dec.pending_bytes(), 0)
  assert_eq(one(dec~, "\u{1b}[A"), pressed("ArrowUp"))
}

///|
test "修饰键码与 Shift-Tab" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  assert_eq(
    key_of(one(dec~, "\u{1b}[1;5A")),
    @core.KeyboardEvent::new(
      key="ArrowUp",
      pressed=true,
      modifiers=@core.KeyModifiers::new(control=true),
    ),
  )
  assert_eq(
    key_of(one(dec~, "\u{1b}[1;2C")),
    @core.KeyboardEvent::new(
      key="ArrowRight",
      pressed=true,
      modifiers=@core.KeyModifiers::new(shift=true),
    ),
  )
  assert_eq(
    key_of(one(dec~, "\u{1b}[Z")),
    @core.KeyboardEvent::new(
      key="Tab",
      pressed=true,
      modifiers=@core.KeyModifiers::new(shift=true),
    ),
  )
  // Alt+方向键是瞬时按键链路的常见键位,不能退化成 Escape + 方向键。
  let alt_left = key_of(one(dec~, "\u{1b}[1;3D"))
  assert_eq(alt_left.key, "ArrowLeft")
  assert_eq(alt_left.modifiers, @core.KeyModifiers::new(alt=true))
}

///|
test "编号表与 SS3 表" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  assert_eq(one(dec~, "\u{1b}[3~"), pressed("Delete"))
  assert_eq(
    one(dec~, "\u{1b}[5;2~"),
    pressed("PageUp", modifiers=@core.KeyModifiers::new(shift=true)),
  )
  assert_eq(one(dec~, "\u{1b}[H"), pressed("Home"))
  assert_eq(one(dec~, "\u{1b}[F"), pressed("End"))
  assert_eq(one(dec~, "\u{1b}OP"), pressed("F1"))
  assert_eq(one(dec~, "\u{1b}OQ"), pressed("F2"))
  assert_eq(one(dec~, "\u{1b}[15~"), pressed("F5"))
  assert_eq(one(dec~, "\u{1b}[24~"), pressed("F12"))
  // 带修饰键的 F3 用 CSI 形式;占位首参必须是 1。
  assert_eq(
    one(dec~, "\u{1b}[1;5R"),
    pressed("F3", modifiers=@core.KeyModifiers::new(control=true)),
  )
}

///|
test "kitty 的按下/重复/释放可区分" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  assert_eq(one(dec~, "\u{1b}[57352;1:1u"), pressed("ArrowUp"))
  // 重复:同一段文本内容,repeat=true。
  let rep = key_of(one(dec~, "\u{1b}[97;5:2u"))
  assert_eq(rep.key, "a")
  assert_eq(rep.pressed, true)
  assert_eq(rep.repeat, true)
  assert_eq(rep.modifiers, @core.KeyModifiers::new(control=true))
  assert_eq(rep.text, None)
  // 释放:pressed=false,且不产生文本插入。
  let events = dec.feed_bytes(ascii("\u{1b}[97;5:3u"))
  assert_eq(events.length(), 1)
  let rel = key_of(events[0])
  assert_eq(rel.pressed, false)
  assert_eq(rel.repeat, false)
  assert_eq(rel.key, "a")
  // 无修饰的 kitty 字母键给文本插入,和 legacy 路径一致。
  let plain = dec.feed_bytes(ascii("\u{1b}[98;1u"))
  assert_eq(plain.length(), 2)
  assert_eq(
    plain[0],
    @moui_terminal_host.Key(
      @core.KeyboardEvent::new(key="b", pressed=true, text=Some("b")),
    ),
  )
  assert_eq(
    plain[1],
    @moui_terminal_host.Text(@core.TextInputEvent::InsertText("b")),
  )
}

///|
test "SGR 鼠标按下拖动释放" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  assert_eq(mouse_of(one(dec~, "\u{1b}[<0;12;4M")), {
    position: { col: 11, row: 3, },
    button: 0,
    phase: @moui_terminal_host.Press,
    modifiers: @core.KeyModifiers::none(),
  })
  let drag = mouse_of(one(dec~, "\u{1b}[<32;12;4M"))
  assert_eq(drag.phase, @moui_terminal_host.Drag)
  assert_eq(drag.button, 0)
  assert_eq(
    mouse_of(one(dec~, "\u{1b}[<0;12;4m")).phase,
    @moui_terminal_host.Release,
  )
  // 1003 无键移动:button=3 表示当前没有键按下,不是第 4 个按钮。
  let hover = mouse_of(one(dec~, "\u{1b}[<35;20;10M"))
  assert_eq(hover.button, 3)
  assert_eq(hover.phase, @moui_terminal_host.Drag)
  assert_eq(hover.position, { col: 19, row: 9, })
  // shift 位是 4,不是 legacy 修饰码的 1。
  assert_eq(
    mouse_of(one(dec~, "\u{1b}[<4;1;1M")).modifiers,
    @core.KeyModifiers::new(shift=true),
  )
  assert_eq(mouse_of(one(dec~, "\u{1b}[<0;12;4M")).position, {
    col: 11,
    row: 3,
  })
}

///|
test "滚轮给出一格事实与位置" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  assert_eq(wheel_of(one(dec~, "\u{1b}[<64;5;9M")), {
    position: { col: 4, row: 8, },
    up: true,
    modifiers: @core.KeyModifiers::none(),
  })
  assert_eq(wheel_of(one(dec~, "\u{1b}[<65;5;9M")).up, false)
  // 64 | 16 = 控制键 + 滚轮上
  assert_eq(
    wheel_of(one(dec~, "\u{1b}[<80;1;1M")).modifiers,
    @core.KeyModifiers::new(control=true),
  )
}

///|
test "多字节字符跨读取拼接" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  // "中" = E4 B8 AD:前两字节不该产出替换符。
  assert_eq(dec.feed_bytes(Bytes::from_array([b'\xe4', b'\xb8'])).length(), 0)
  assert_eq(dec.pending_bytes(), 2)
  let events = dec.feed_bytes(Bytes::from_array([b'\xad']))
  assert_eq(events.length(), 2)
  assert_eq(
    events[0],
    @moui_terminal_host.Key(
      @core.KeyboardEvent::new(key="中", pressed=true, text=Some("中")),
    ),
  )
  assert_eq(
    events[1],
    @moui_terminal_host.Text(@core.TextInputEvent::InsertText("中")),
  )
}

///|
test "非法字节序列不会锁死解码" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  // 孤立的连续字节(0xA0 不是合法起始字节)按替换符消费掉一格。
  let events = dec.feed_bytes(Bytes::from_array([b'\xa0', b'a']))
  assert_eq(events.length(), 4)
  assert_eq(key_of(events[0]).key, "\u{fffd}")
  assert_eq(key_of(events[2]).key, "a")
  assert_eq(dec.pending_bytes(), 0)
}

///|
test "无法识别的序列被消费掉而不是卡住缓冲" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  // 终端自检回复(DA1)与光标位置报告不是用户输入。
  assert_eq(dec.feed_bytes(ascii("\u{1b}[?1;2c")).length(), 0)
  assert_eq(dec.pending_bytes(), 0)
  // CPR 与 F3 共享终结字节 R:首参不是占位 1 时必须丢弃,否则应用收到假按键。
  assert_eq(dec.feed_bytes(ascii("\u{1b}[12;4R")).length(), 0)
  assert_eq(dec.pending_bytes(), 0)
  // 后续合法按键照常解出。
  assert_eq(one(dec~, "\u{1b}[A"), pressed("ArrowUp"))
}

///|
test "拼不出的垃圾字节超过上限时缓冲清空" {
  let dec = @moui_terminal_host.TerminalDecoder::new()
  let arr : Array[Byte] = [b'\x1b', b'[']
  for _ in 0..<5000 {
    arr.push(b'0')
  }
  assert_eq(dec.feed_bytes(Bytes::from_array(arr)).length(), 0)
  assert_eq(dec.pending_bytes(), 0)
  // 清掉垃圾后解码器仍可用。
  assert_eq(one(dec~, "\u{1b}[A"), pressed("ArrowUp"))
}
