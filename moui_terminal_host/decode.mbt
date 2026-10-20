///|
/// 终端输入解码器:原始字节流 → MoUI 可消费的输入事实。
///
/// 键名词表与 `examples/terminal/addon/input_encoding.mbt` 的编码侧一一对应:
/// 终端把 `@core.KeyboardEvent` 编成字节,这里把字节编回同名事件。两侧共用一套
/// 词表,否则同一个键在框架里会出现两种名字。
///
/// 解码器只管字节,不管 fd,也不管 cell 尺寸:
/// - 序列没拼完整就把字节留在缓冲里等下一批,所以「一次按键被分成两次 read
///   送达」可用 `moon test` 复现,不需要真终端;
/// - 鼠标只输出 cell 坐标(终端唯一能给的位置单位)。换算成逻辑像素是
///   `input_channel` 的职责:cell 尺寸随 resize 变化,不属于解码语义。
const ESC_BYTE : Int32 = 0x1b

///|
const CSI_BYTE : Int32 = 0x5b // '['

///|
const SS3_BYTE : Int32 = 0x4f // 'O'

///|
const CR_BYTE : Int32 = 0x0d

///|
const LF_BYTE : Int32 = 0x0a

///|
const TAB_BYTE : Int32 = 0x09

///|
const BACKSPACE_BYTE : Int32 = 0x08

///|
const DEL_BYTE : Int32 = 0x7f

///|
/// CSI 私有标记字节区间的首尾:`<`(SGR 鼠标/键盘协议扩展)到 `?`(设备模式)。
/// read_csi 只在这段区间里认标记,dispatch_mouse 只接受 `<`。
const SGR_MARKER_BYTE : Int32 = 0x3c // '<'

///|
const PRIVATE_MODE_BYTE : Int32 = 0x3f // '?'

///|
/// 缓冲里长期拼不出序列时的上限。超过即清空:一段非法输入不该永久卡住解码,
/// 也不该让缓冲随键盘垃圾无限增长。
const PENDING_LIMIT : Int32 = 4096

///|
/// 终端报告的位置:cell 坐标,0 起算(SGR 的 1 起算在解码时已折算)。
pub(all) struct CellPosition {
  col : Int32
  row : Int32
} derive(Eq, Debug)

///|
pub extend CellPosition with Eq::{not_equal, equal}

///|
pub extend CellPosition with Debug::{to_repr}

///|
pub(all) enum MousePhase {
  Press
  Release
  Drag
} derive(Eq, Debug)

///|
pub extend MousePhase with Eq::{not_equal, equal}

///|
pub extend MousePhase with Debug::{to_repr}

///|
/// SGR(1006) 鼠标报告。`button` 为终端原始按钮号:0 左 1 中 2 右,
/// 3 表示「无键移动」(1003 模式),不是第 4 个按钮。
pub(all) struct MouseReport {
  position : CellPosition
  button : Int32
  phase : MousePhase
  modifiers : @core.KeyModifiers
} derive(Eq, Debug)

///|
pub extend MouseReport with Eq::{not_equal, equal}

///|
pub extend MouseReport with Debug::{to_repr}

///|
/// 滚轮:终端只给「一格」这个事实,不给像素增量。换算成
/// `@core.PointerEvent.wheel_delta` 由 `input_channel` 按平台同款行高策略完成。
pub(all) struct WheelReport {
  position : CellPosition
  up : Bool
  modifiers : @core.KeyModifiers
} derive(Eq, Debug)

///|
pub extend WheelReport with Eq::{not_equal, equal}

///|
pub extend WheelReport with Debug::{to_repr}

///|
/// 一条完整序列解码出的输入事实。键盘/鼠标/滚轮三类都在此暴露,
/// backend 不吞掉任何一类。
pub(all) enum TerminalEvent {
  Key(@core.KeyboardEvent)
  Text(@core.TextInputEvent)
  Mouse(MouseReport)
  Wheel(WheelReport)
} derive(Eq, Debug)

///|
pub extend TerminalEvent with Eq::{not_equal, equal}

///|
pub extend TerminalEvent with Debug::{to_repr}

///|
pub struct TerminalDecoder {
  mut pending : Array[Int32]
}

///|
pub fn TerminalDecoder::new() -> TerminalDecoder {
  { pending: [], }
}

///|
/// 尚未拼成完整序列的字节数,诊断与测试用。
pub fn TerminalDecoder::pending_bytes(self : TerminalDecoder) -> Int32 {
  self.pending.length()
}

///|
/// 一批原始字节进来:能拼出几条完整序列就出几条事件,拼不出的留在缓冲里。
pub fn TerminalDecoder::feed_bytes(
  self : TerminalDecoder,
  chunk : Bytes,
) -> Array[TerminalEvent] {
  let raw : Array[Int32] = []
  for i in 0..<chunk.length() {
    raw.push(chunk[i].to_int())
  }
  for b in raw {
    self.pending.push(b)
  }
  let out : Array[TerminalEvent] = []
  let mut progressed = true
  while progressed {
    progressed = self.step(out)
  }
  if self.pending.length() > PENDING_LIMIT {
    self.pending = []
  }
  out
}

///|
/// 数据流停了(poll 超时)时调用:把只能靠超时消歧的事实结算掉。
///
/// 单独一个 ESC 既可能是 Escape 键本身,也可能是 `ESC x` / `ESC[A` 的前缀。
/// 读到一半就派发会把 Alt-方向键拆成两次事件;死等又会让 Escape 永不响应。
/// 所以解码时把裸 ESC 留在缓冲,由宿主在「这一轮 poll 没再来字节」时 flush——
/// 瞬时响应与消歧都保住,代价只是 Escape 键晚一个 poll 周期。
///
/// 此时缓冲里若还剩别的前缀(例如终端只发出 `ESC [`),它已经拼不成任何合法
/// 序列:整条丢弃。留着它只会让下一次按键与残留前缀拼出错误事件。
pub fn TerminalDecoder::flush(self : TerminalDecoder) -> TerminalEvent? {
  let buf = self.pending
  self.pending = []
  if buf.length() == 1 && buf[0] == ESC_BYTE {
    Some(Key(@core.KeyboardEvent::new(key="Escape", pressed=true)))
  } else {
    None
  }
}

///|
/// 消费一条完整序列;返回 false 表示字节还不够,等下一次 feed。
fn TerminalDecoder::step(
  self : TerminalDecoder,
  out : Array[TerminalEvent],
) -> Bool {
  let buf = self.pending
  let n = buf.length()
  if n == 0 {
    return false
  }
  let lead = buf[0]
  if lead == ESC_BYTE {
    if n < 2 {
      return false
    }
    if buf[1] == CSI_BYTE {
      return self.step_csi(out)
    }
    if buf[1] == SS3_BYTE {
      return self.step_ss3(out)
    }
    if buf[1] >= 0x80 {
      // ESC + 高位字节:Alt 修饰的多字节码位,必须整码位消费。
      return match decode_utf8(buf, at=1) {
        None => false
        Some(piece) => {
          self.take(piece.size + 1)
          emit_alt_text(piece.cp, out)
          true
        }
      }
    }
    self.take(2)
    emit_alt_byte(buf[1], out)
    return true
  }
  if lead < 0x20 || lead == DEL_BYTE {
    let byte = lead
    self.take(1)
    match legacy_control(byte) {
      Some(event) => out.push(Key(event))
      None => ()
    }
    return true
  }
  match decode_utf8(buf, at=0) {
    None => false
    Some(piece) => {
      self.take(piece.size)
      emit_text_key(piece.cp, out)
      true
    }
  }
}

///|
fn TerminalDecoder::step_csi(
  self : TerminalDecoder,
  out : Array[TerminalEvent],
) -> Bool {
  match self.read_csi() {
    None => false
    Some(csi) => {
      self.take(csi.consumed)
      csi.dispatch(out)
      true
    }
  }
}

///|
fn TerminalDecoder::step_ss3(
  self : TerminalDecoder,
  out : Array[TerminalEvent],
) -> Bool {
  if self.pending.length() < 3 {
    false
  } else {
    let terminator = self.pending[2]
    self.take(3)
    match ss3_key_name(terminator) {
      Some(name) =>
        out.push(Key(@core.KeyboardEvent::new(key=name, pressed=true)))
      None => ()
    }
    true
  }
}

///|
fn TerminalDecoder::take(self : TerminalDecoder, k : Int32) -> Unit {
  let n = self.pending.length()
  let rest : Array[Int32] = []
  if k < n {
    for i in k..<n {
      rest.push(self.pending[i])
    }
  }
  self.pending = rest
}

///|
/// 一条已拼完整的 CSI 序列:`ESC [ <私有标记> 参数... 终结字节`。
priv struct Csi {
  marker : Int32
  params : Array[Int32]
  terminator : Int32
  consumed : Int32
}

///|
/// 缺省字段按 0 取(`ESC[A` 无参数,`ESC[;5A` 的第一段是 0)。
/// 参数按 `;` 与 `:` 一并切分:kitty 的子参数(事件类型)落在同一段里,
/// 但对解码而言只是「后一个数」,不需要保留层级。
fn Csi::param(self : Csi, index : Int32) -> Int32 {
  if index < self.params.length() {
    self.params[index]
  } else {
    0
  }
}

///|
/// 消费字节数不含前导 `ESC [`;read_csi 从索引 2 起扫。
fn TerminalDecoder::read_csi(self : TerminalDecoder) -> Csi? {
  let buf = self.pending
  let n = buf.length()
  let mut i = 2
  let mut marker = 0
  if i < n && buf[i] >= SGR_MARKER_BYTE && buf[i] <= PRIVATE_MODE_BYTE {
    marker = buf[i]
    i = i + 1
  }
  let params : Array[Int32] = []
  let mut value = 0
  let mut has_value = false
  let mut final_byte = 0
  let mut closed = false
  while i < n && !closed {
    let b = buf[i]
    if b >= 0x40 && b <= 0x7e {
      final_byte = b
      closed = true
      i = i + 1
    } else if b >= 0x30 && b <= 0x39 {
      value = value * 10 + (b - 0x30)
      has_value = true
      i = i + 1
    } else if b == 0x3b || b == 0x3a {
      params.push(if has_value { value } else { 0 })
      value = 0
      has_value = false
      i = i + 1
    } else {
      // 非法中间字节:跳过,不把它当成序列结束。
      i = i + 1
    }
  }
  if !closed {
    None
  } else {
    if has_value {
      params.push(value)
    }
    Some({ marker, params, terminator: final_byte, consumed: i, })
  }
}

///|
/// 终结字节 → 事件。无法识别的序列(终端自检回复等)静默丢弃:
/// 它们不是用户输入,派发出去只会让应用收到假按键。
fn Csi::dispatch(self : Csi, out : Array[TerminalEvent]) -> Unit {
  match self.terminator {
    0x4d | 0x6d => self.dispatch_mouse(out)
    0x75 => self.dispatch_csi_u(out)
    0x41 => self.dispatch_named("ArrowUp", out)
    0x42 => self.dispatch_named("ArrowDown", out)
    0x43 => self.dispatch_named("ArrowRight", out)
    0x44 => self.dispatch_named("ArrowLeft", out)
    0x48 => self.dispatch_named("Home", out)
    0x46 => self.dispatch_named("End", out)
    0x50 => self.dispatch_function("F1", out)
    0x51 => self.dispatch_function("F2", out)
    0x52 => self.dispatch_function("F3", out)
    0x53 => self.dispatch_function("F4", out)
    0x5a =>
      out.push(
        Key(
          @core.KeyboardEvent::new(
            key="Tab",
            pressed=true,
            modifiers=@core.KeyModifiers::new(shift=true),
          ),
        ),
      )
    0x7e => self.dispatch_tilde(out)
    _ => ()
  }
}

///|
/// `ESC[1;5A` 形式:参数 0 是占位 1,参数 1 是修饰键码。
fn Csi::dispatch_named(
  self : Csi,
  key : String,
  out : Array[TerminalEvent],
) -> Unit {
  out.push(
    Key(
      @core.KeyboardEvent::new(
        key~,
        pressed=true,
        modifiers=legacy_modifiers(self.param(1)),
      ),
    ),
  )
}

///|
/// F1-F4 的 CSI 形式只在带修饰键时出现(`ESC[1;2R`),首参恒为占位 1。
/// 首参不是 1 的 `ESC[<row>;<col>R` 是终端的光标位置报告,与 F3 同终结字节:
/// 把它解成按键会让应用收到一次并未发生的输入,所以按序列丢弃。
fn Csi::dispatch_function(
  self : Csi,
  key : String,
  out : Array[TerminalEvent],
) -> Unit {
  if self.params.length() == 0 || self.param(0) == 1 {
    self.dispatch_named(key, out)
  }
}

///|
fn Csi::dispatch_tilde(self : Csi, out : Array[TerminalEvent]) -> Unit {
  match tilde_key_name(self.param(0)) {
    Some(key) => self.dispatch_named(key, out)
    None => ()
  }
}

///|
/// kitty CSI-u:`ESC[<codepoint>;<modifier>[:<event-type>]u`。
/// 事件类型 1=press 2=repeat 3=release;缺省(旧终端只发两段)按 press。
fn Csi::dispatch_csi_u(self : Csi, out : Array[TerminalEvent]) -> Unit {
  let cp = self.param(0)
  let mods = legacy_modifiers(self.param(1))
  let event_type = self.param(2)
  let pressed = event_type != 3
  let repeat = event_type == 2
  let functional = functional_key_name(cp)
  // 功能键码位段没有文本对应物:给 ArrowUp 附上 text 会让文本控件插入一个乱码字符。
  let is_text = match functional {
    Some(_) => false
    None => cp >= 0x20 && cp != DEL_BYTE
  }
  let name = match functional {
    Some(key) => Some(key)
    None =>
      if cp < 0x20 {
        control_key_name(cp)
      } else {
        Some(String::make(1, Int32::unsafe_to_char(cp)))
      }
  }
  let char_text = if is_text {
    Some(String::make(1, Int32::unsafe_to_char(cp)))
  } else {
    None
  }
  let text = if pressed && mods == @core.KeyModifiers::none() {
    char_text
  } else {
    None
  }
  match name {
    Some(key) => {
      out.push(
        Key(
          @core.KeyboardEvent::new(
            key~,
            pressed~,
            text~,
            repeat~,
            modifiers=mods,
          ),
        ),
      )
      // 插入文本只在按下时发生:重复已由终端重发的 press 事件表达过,释放不插入。
      if event_type == 0 || event_type == 1 {
        match text {
          Some(t) => out.push(Text(@core.TextInputEvent::InsertText(t)))
          None => ()
        }
      }
    }
    None => ()
  }
}

///|
/// `ESC[<b;x;yM` / `ESC[<b;x;ym`。非 `<` 标记的旧式鼠标编码不在此支持范围
/// (1006 模式开启后终端只发 SGR)。
fn Csi::dispatch_mouse(self : Csi, out : Array[TerminalEvent]) -> Unit {
  if self.marker != SGR_MARKER_BYTE || self.params.length() < 3 {
    return ()
  }
  let code = self.param(0)
  let col = self.param(1)
  let row = self.param(2)
  if col < 1 || row < 1 {
    return ()
  }
  let position = { col: col - 1, row: row - 1, }
  let modifiers = mouse_modifiers(code)
  if (code & 0x40) != 0 {
    // 滚轮位:低 1 位区分上/下,其余按钮位无意义。
    out.push(Wheel({ position, up: (code & 0x01) == 0, modifiers, }))
  } else if (code & 0x20) != 0 {
    // 拖动位:1003 模式下无键移动也走这里,button=3 表示当前无键。
    out.push(Mouse({ position, button: code & 0x03, phase: Drag, modifiers, }))
  } else if self.terminator == 0x6d {
    out.push(
      Mouse({ position, button: code & 0x03, phase: Release, modifiers, }),
    )
  } else {
    out.push(Mouse({ position, button: code & 0x03, phase: Press, modifiers, }))
  }
}

///|
/// SGR 修饰位:shift=4、alt=8、control=16(xterm 与 crossterm 一致)。
/// 32 是「拖动中」,不是修饰键。
fn mouse_modifiers(code : Int32) -> @core.KeyModifiers {
  @core.KeyModifiers::new(
    shift=(code & 0x04) != 0,
    alt=(code & 0x08) != 0,
    control=(code & 0x10) != 0,
  )
}

///|
/// xterm 传统修饰键码:`值 = 1 + shift + 2*alt + 4*ctrl + 8*meta`。
/// 0 与 1 都表示无修饰(缺省字段按 0 读)。
fn legacy_modifiers(code : Int32) -> @core.KeyModifiers {
  if code <= 1 {
    @core.KeyModifiers::none()
  } else {
    let bits = code - 1
    @core.KeyModifiers::new(
      shift=(bits & 1) != 0,
      alt=(bits & 2) != 0,
      control=(bits & 4) != 0,
      meta=(bits & 8) != 0,
    )
  }
}

///|
/// 可打印码位:同时给 Keyboard 与 TextInput——前者驱动瞬时按键,后者驱动
/// 文本控件的插入,和 `examples/terminal/addon/keyboard_input.mbt` 的两侧消费一致。
fn emit_text_key(cp : Int32, out : Array[TerminalEvent]) -> Unit {
  let name = String::make(1, Int32::unsafe_to_char(cp))
  out.push(
    Key(@core.KeyboardEvent::new(key=name, pressed=true, text=Some(name))),
  )
  out.push(Text(@core.TextInputEvent::InsertText(name)))
}

///|
fn emit_alt_text(cp : Int32, out : Array[TerminalEvent]) -> Unit {
  out.push(
    Key(
      @core.KeyboardEvent::new(
        key=String::make(1, Int32::unsafe_to_char(cp)),
        pressed=true,
        modifiers=@core.KeyModifiers::new(alt=true),
      ),
    ),
  )
}

///|
/// `ESC <byte>`:控制字节按控制键名 + alt,可打印字节按字符 + alt。
fn emit_alt_byte(byte : Int32, out : Array[TerminalEvent]) -> Unit {
  if byte == ESC_BYTE {
    out.push(
      Key(
        @core.KeyboardEvent::new(
          key="Escape",
          pressed=true,
          modifiers=@core.KeyModifiers::new(alt=true),
        ),
      ),
    )
  } else if byte < 0x20 || byte == DEL_BYTE {
    match control_key_name(byte) {
      Some(key) =>
        out.push(
          Key(
            @core.KeyboardEvent::new(
              key~,
              pressed=true,
              modifiers=merge_alt(control_modifiers(byte)),
            ),
          ),
        )
      None => ()
    }
  } else {
    out.push(
      Key(
        @core.KeyboardEvent::new(
          key=String::make(1, Int32::unsafe_to_char(byte)),
          pressed=true,
          modifiers=@core.KeyModifiers::new(alt=true),
        ),
      ),
    )
  }
}

///|
/// 终端没有独立修饰键事件,alt 只能从前缀字节推出,所以合并就地做。
fn merge_alt(m : @core.KeyModifiers) -> @core.KeyModifiers {
  @core.KeyModifiers::new(
    shift=m.shift,
    control=m.control,
    alt=true,
    meta=m.meta,
  )
}

///|
/// 裸控制字节 → 按键事件(legacy 编码下按键总是 press)。
fn legacy_control(byte : Int32) -> @core.KeyboardEvent? {
  match control_key_name(byte) {
    None => None
    Some(key) =>
      Some(
        @core.KeyboardEvent::new(
          key~,
          pressed=true,
          text=if key == "Space" { Some(" ") } else { None },
          modifiers=control_modifiers(byte),
        ),
      )
  }
}

///|
/// 控制码 → 键名,词表与编码侧一致。
fn control_key_name(byte : Int32) -> String? {
  if byte == CR_BYTE || byte == LF_BYTE {
    Some("Enter")
  } else if byte == TAB_BYTE {
    Some("Tab")
  } else if byte == DEL_BYTE || byte == BACKSPACE_BYTE {
    Some("Backspace")
  } else if byte == 0x00 {
    Some("Space")
  } else if byte >= 0x01 && byte <= 0x1a {
    Some(String::make(1, Int32::unsafe_to_char(byte + 0x60)))
  } else {
    None
  }
}

///|
/// Ctrl 前缀字母与 Ctrl+Space 带 control;Enter/Tab/Backspace 本身就是控制码,
/// 再叠 control 会让应用收到「Ctrl+Enter」这种终端并未表达的键位。
fn control_modifiers(byte : Int32) -> @core.KeyModifiers {
  let ordinary_control_code = byte == CR_BYTE ||
    byte == LF_BYTE ||
    byte == TAB_BYTE ||
    byte == BACKSPACE_BYTE
  if byte <= 0x1a && !ordinary_control_code {
    @core.KeyModifiers::new(control=true)
  } else {
    @core.KeyModifiers::none()
  }
}

///|
fn ss3_key_name(terminator : Int32) -> String? {
  match terminator {
    0x50 => Some("F1")
    0x51 => Some("F2")
    0x52 => Some("F3")
    0x53 => Some("F4")
    0x41 => Some("ArrowUp")
    0x42 => Some("ArrowDown")
    0x43 => Some("ArrowRight")
    0x44 => Some("ArrowLeft")
    0x48 => Some("Home")
    0x46 => Some("End")
    _ => None
  }
}

///|
/// `ESC[<num>~` 编号表,与编码侧一一对应。
fn tilde_key_name(code : Int32) -> String? {
  match code {
    1 => Some("Home")
    2 => Some("Insert")
    3 => Some("Delete")
    4 => Some("End")
    5 => Some("PageUp")
    6 => Some("PageDown")
    7 => Some("Home")
    8 => Some("End")
    11 => Some("F1")
    12 => Some("F2")
    13 => Some("F3")
    14 => Some("F4")
    15 => Some("F5")
    17 => Some("F6")
    18 => Some("F7")
    19 => Some("F8")
    20 => Some("F9")
    21 => Some("F10")
    23 => Some("F11")
    24 => Some("F12")
    _ => None
  }
}

///|
/// kitty CSI-u 功能键码位段(`ESC[>1u` 之后终端用这段码位表达无文本对应的键)。
fn functional_key_name(cp : Int32) -> String? {
  match cp {
    57344 => Some("Escape")
    57345 => Some("Enter")
    57346 => Some("Tab")
    57347 => Some("Backspace")
    57348 => Some("Insert")
    57349 => Some("Delete")
    57350 => Some("ArrowLeft")
    57351 => Some("ArrowRight")
    57352 => Some("ArrowUp")
    57353 => Some("ArrowDown")
    57354 => Some("PageUp")
    57355 => Some("PageDown")
    57356 => Some("Home")
    57357 => Some("End")
    57364 => Some("F1")
    57365 => Some("F2")
    57366 => Some("F3")
    57367 => Some("F4")
    57368 => Some("F5")
    57369 => Some("F6")
    57370 => Some("F7")
    57371 => Some("F8")
    57372 => Some("F9")
    57373 => Some("F10")
    57374 => Some("F11")
    57375 => Some("F12")
    _ => None
  }
}

///|
/// 一个 UTF-8 起始字节需要的总长度;非法起始字节返回 0。
fn utf8_sequence_length(lead : Int32) -> Int32 {
  if lead < 0x80 {
    1
  } else if lead >= 0xc2 && lead <= 0xdf {
    2
  } else if lead >= 0xe0 && lead <= 0xef {
    3
  } else if lead >= 0xf0 && lead <= 0xf4 {
    4
  } else {
    0
  }
}

///|
priv struct Utf8Piece {
  cp : Int32
  size : Int32
}

///|
/// 缓冲不足一个完整码位时返回 None:半个汉字不能变成替换符,
/// 否则会污染 renderer 的文本投影(它按字节块 feed,自行拼接)。
fn decode_utf8(buf : Array[Int32], at~ : Int32) -> Utf8Piece? {
  if at >= buf.length() {
    return None
  }
  let lead = buf[at]
  let size = utf8_sequence_length(lead)
  if size == 0 {
    return Some({ cp: 0xfffd, size: 1, })
  }
  if buf.length() - at < size {
    return None
  }
  let mut cp = if size == 1 { lead } else { lead & (0x7f >> size) }
  for i in 1..<size {
    let cont = buf[at + i]
    if cont < 0x80 || cont > 0xbf {
      return Some({ cp: 0xfffd, size: 1, })
    }
    cp = (cp << 6) | (cont & 0x3f)
  }
  Some({ cp, size, })
}
