///|
/// 词法分析：语言无关（中英文关键字都是标识符 token，由解析器按表分派）。
/// 全角标点/数字/字母在词法层归一化为 ASCII，中文 IME 直接输入也能解析；
/// 字符串字面量内保留原文。

///|
fn normalize_char(c : Char) -> Char {
  let code = c.to_int()
  if code >= 0xFF10 && code <= 0xFF19 {
    (code - 0xFF10 + 0x30).unsafe_to_char()
  } else if code >= 0xFF21 && code <= 0xFF3A {
    (code - 0xFF21 + 0x41).unsafe_to_char()
  } else if code >= 0xFF41 && code <= 0xFF5A {
    (code - 0xFF41 + 0x61).unsafe_to_char()
  } else {
    match code {
      0xFF08 => '(' // （
      0xFF09 => ')' // ）
      0xFF3B => '[' // ［
      0xFF3D => ']' // ］
      0xFF0C => ',' // ，
      0xFF0B => '+' // ＋
      0xFF0D => '-' // －
      0xFF0A => '*' // ＊
      0xFF0F => '/' // ／
      0xFF1D => '=' // ＝
      0xFF1C => '<' // ＜
      0xFF1E => '>' // ＞
      0x3002 => '.' // 。
      0x2260 => '#' // ≠ → 占位，双字符判定在下方还原为 <>
      0x2264 => '$' // ≤ → 占位
      0x2265 => '%' // ≥ → 占位
      _ => c
    }
  }
}

///|
priv enum TokenKind {
  Ident(String)
  Num(Double)
  Int(Int)
  LBracket
  RBracket
  Str(String)
  Newline
  LParen
  RParen
  Comma
  Plus
  Minus
  Star
  Slash
  Eq
  Ne
  Lt
  Gt
  Le
  Ge
  Eof
}

///|
priv struct Token {
  kind : TokenKind
  line : Int
}

///|
fn is_digit_char(c : Char) -> Bool {
  let code = c.to_int()
  code >= 0x30 && code <= 0x39
}

///|
fn is_space_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r'
}

///|
fn is_operator_char(c : Char) -> Bool {
  c == '(' ||
  c == ')' ||
  c == '[' ||
  c == ']' ||
  c == ',' ||
  c == '+' ||
  c == '-' ||
  c == '*' ||
  c == '/' ||
  c == '=' ||
  c == '<' ||
  c == '>' ||
  c == '"' ||
  c == '#' ||
  c == '$' ||
  c == '%'
}

///|
fn lex(source : String) -> Result[Array[Token], LangError] {
  let chars : Array[Char] = []
  for c in source {
    chars.push(c)
  }
  let tokens : Array[Token] = []
  let n = chars.length()
  let mut i = 0
  let mut line = 1
  while i < n {
    let c = normalize_char(chars[i])
    if c == '\n' {
      tokens.push({ kind: Newline, line, })
      line = line + 1
      i = i + 1
    } else if is_space_char(c) {
      i = i + 1
    } else if c == '/' && i + 1 < n && normalize_char(chars[i + 1]) == '/' {
      // 行注释：跳到行尾（不含换行符本身）
      while i < n && chars[i] != '\n' {
        i = i + 1
      }
    } else if chars[i] == '"' || c == '"' {
      let buf = StringBuilder()
      let mut j = i + 1
      let mut closed = false
      while j < n {
        let cj = chars[j]
        if cj == '"' {
          closed = true
          break
        }
        if cj == '\n' {
          break
        }
        buf.write_char(cj)
        j = j + 1
      }
      if !closed {
        return Err(LangError(UnterminatedString, line, "", ""))
      }
      tokens.push({ kind: Str(buf.to_string()), line, })
      i = j + 1
    } else if is_digit_char(c) {
      let buf = StringBuilder()
      while i < n {
        let cn = normalize_char(chars[i])
        if is_digit_char(cn) || cn == '.' {
          buf.write_char(cn)
          i = i + 1
        } else {
          break
        }
      }
      let text = buf.to_string()
      // 整数字面量（无小数点）用独立 token：IR 层 IntLit 才能区分
      // 「7」与「7.0」——整数除法/整数身份的语义源头在这里。
      match digits_to_double(text) {
        Some(v) =>
          if text.contains(".") {
            tokens.push({ kind: Num(v), line, })
          } else {
            tokens.push({ kind: Int(v.to_int()), line, })
          }
        None => return Err(LangError(BadNumber, line, text, ""))
      }
    } else if is_operator_char(c) {
      // ≠ ≤ ≥ 由单字符归一化而来，只前进一格
      if c == '#' {
        tokens.push({ kind: Ne, line, })
        i = i + 1
      } else if c == '$' {
        tokens.push({ kind: Le, line, })
        i = i + 1
      } else if c == '%' {
        tokens.push({ kind: Ge, line, })
        i = i + 1
      } else {
        let next = if i + 1 < n { normalize_char(chars[i + 1]) } else { ' ' }
        let two_char = if c == '<' && next == '=' {
          Some(Le)
        } else if c == '<' && next == '>' {
          Some(Ne)
        } else if c == '>' && next == '=' {
          Some(Ge)
        } else {
          None
        }
        match two_char {
          Some(kind) => {
            tokens.push({ kind, line, })
            i = i + 2
          }
          None => {
            let kind = match c {
              '(' => LParen
              ')' => RParen
              '[' => LBracket
              ']' => RBracket
              ',' => Comma
              '+' => Plus
              '-' => Minus
              '*' => Star
              '/' => Slash
              '=' => Eq
              '<' => Lt
              _ => Gt
            }
            tokens.push({ kind, line, })
            i = i + 1
          }
        }
      }
    } else {
      let buf = StringBuilder()
      while i < n {
        let c2 = normalize_char(chars[i])
        if c2 == '\n' || is_space_char(c2) || is_operator_char(c2) {
          break
        }
        buf.write_char(c2)
        i = i + 1
      }
      tokens.push({ kind: Ident(buf.to_string()), line, })
    }
  }
  tokens.push({ kind: Eof, line, })
  Ok(tokens)
}

///|
/// 手写 [0-9.]+ 解析（不依赖 strconv；空串/多 dot 返回 None）。
fn digits_to_double(text : String) -> Double? {
  let mut value = 0.0
  let mut frac = false
  let mut scale = 0.1
  let mut seen_digit = false
  let mut seen_dot = false
  for c in text {
    if c == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
      frac = true
    } else {
      let d = c.to_int() - 0x30
      seen_digit = true
      if frac {
        value = value + d.to_double() * scale
        scale = scale / 10.0
      } else {
        value = value * 10.0 + d.to_double()
      }
    }
  }
  if seen_digit {
    Some(value)
  } else {
    None
  }
}

///|
/// IDE 属性面板与 `取数值` 共用的宽松文本转数字：容许正负号与全角数字。
pub fn text_to_number(text : String) -> Double? {
  let chars : Array[Char] = []
  for c in text {
    chars.push(normalize_char(c))
  }
  let n = chars.length()
  let mut i = 0
  let mut negative = false
  while i < n && is_space_char(chars[i]) {
    i = i + 1
  }
  if i < n && (chars[i] == '-' || chars[i] == '+') {
    negative = chars[i] == '-'
    i = i + 1
  }
  let buf = StringBuilder()
  while i < n {
    let c = chars[i]
    if is_digit_char(c) || c == '.' {
      buf.write_char(c)
      i = i + 1
    } else if is_space_char(c) {
      i = i + 1
    } else {
      return None
    }
  }
  match digits_to_double(buf.to_string()) {
    Some(value) => Some(if negative { -value } else { value })
    None => None
  }
}

///|
/// 数值的文本形式：整数值不带小数点（DSL 与属性面板共用）。
pub fn number_to_text(n : Double) -> String {
  if n == n.floor() && n.abs() < 1.0e15 {
    n.to_int().to_string()
  } else {
    n.to_string()
  }
}
