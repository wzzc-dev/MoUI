///|
/// 键盘事件 → 终端输入字节序列。
/// 返回 None 表示该按键不应透传给终端(如修饰键单独按下)。

///|
fn ctrl_char(c : Int) -> Int {
  // Ctrl+A..Z / a..z → 1..26
  if c >= 0x61 && c <= 0x7A {
    c - 0x60
  } else if c >= 0x41 && c <= 0x5A {
    c - 0x40
  } else {
    -1
  }
}

///|
fn char_string(cp : Int) -> String {
  String::make(1, Int::unsafe_to_char(cp))
}

///|
pub fn encode_key(event : @core.KeyboardEvent) -> String? {
  if !event.pressed {
    return None
  }
  let mods = event.modifiers
  // Ctrl 组合:优先控制字符
  if mods.control && event.key.length() == 1 {
    let cc = ctrl_char(event.key[0].to_int())
    if cc >= 1 && cc <= 26 {
      return Some(char_string(cc))
    }
  }
  if mods.control && event.key == "Space" {
    return Some(char_string(0))
  }
  // Alt 组合:普通字符前加 ESC 前缀
  let alt_prefix = if mods.alt { char_string(0x1B) } else { "" }
  // 特殊键
  match event.key {
    "Enter" => Some("\r")
    "Backspace" => Some(char_string(0x7F))
    "Tab" => Some("\t")
    "Escape" => Some(char_string(0x1B))
    "ArrowUp" => Some("\u{1b}[A")
    "ArrowDown" => Some("\u{1b}[B")
    "ArrowRight" => Some("\u{1b}[C")
    "ArrowLeft" => Some("\u{1b}[D")
    "Home" => Some("\u{1b}[H")
    "End" => Some("\u{1b}[F")
    "PageUp" => Some("\u{1b}[5~")
    "PageDown" => Some("\u{1b}[6~")
    "Delete" => Some("\u{1b}[3~")
    "Insert" => Some("\u{1b}[2~")
    "F1" => Some("\u{1b}OP")
    "F2" => Some("\u{1b}OQ")
    "F3" => Some("\u{1b}OR")
    "F4" => Some("\u{1b}OS")
    "F5" => Some("\u{1b}[15~")
    "F6" => Some("\u{1b}[17~")
    "F7" => Some("\u{1b}[18~")
    "F8" => Some("\u{1b}[19~")
    "F9" => Some("\u{1b}[20~")
    "F10" => Some("\u{1b}[21~")
    "F11" => Some("\u{1b}[23~")
    "F12" => Some("\u{1b}[24~")
    _ =>
      // 普通字符:优先 text(输入法合成文本),否则用 key 本身
      match event.text {
        Some(text) =>
          if text.is_empty() {
            None
          } else if mods.alt {
            Some(alt_prefix + text)
          } else {
            Some(text)
          }
        None =>
          if event.key.length() == 1 {
            if mods.alt {
              Some(alt_prefix + event.key)
            } else {
              Some(event.key)
            }
          } else {
            None
          }
      }
  }
}
