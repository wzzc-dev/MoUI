///|
/// Formula evaluator for the Excel example.
///
/// Supports arithmetic, cell references, ranges, and a compact set of
/// spreadsheet functions that are enough for the demo workbook and native UI.

///|
priv enum Token {
  Num(Double)
  Ident(String)
  Plus
  Minus
  Star
  Slash
  Caret
  LParen
  RParen
  Comma
  Colon
  Greater
  Less
  GreaterEq
  LessEq
  Eq
  NotEq
}

///|
priv struct ParseState {
  tokens : Array[Token]
  mut pos : Int
}

///|
pub fn evaluate(
  raw : String,
  lookup : (String) -> @cell.CellValue,
) -> @cell.CellValue {
  let trimmed = raw.trim().to_owned()
  if trimmed.is_empty() {
    return @cell.CellValue::Empty
  }
  if trimmed[0] != '=' {
    return @cell.parse_raw_value(trimmed)
  }
  let expr = trimmed[1:].to_owned()
  if expr.contains("#REF!") {
    return @cell.CellValue::Error("#REF!")
  }
  let result = eval_expr(expr, ref_str => lookup(ref_str).to_display())
  match result {
    Ok(value) =>
      match @cell.parse_number(value) {
        Some(n) => @cell.CellValue::Number(n)
        None => @cell.CellValue::Text(value)
      }
    Err(message) => @cell.CellValue::Error("#" + message)
  }
}

///|
pub fn extract_references(raw : String) -> Array[String] {
  let trimmed = raw.trim().to_owned()
  if trimmed.is_empty() {
    return []
  }
  let expr = if trimmed[0] == '=' { trimmed[1:].to_owned() } else { trimmed }
  let tokens = tokenize(expr)
  let refs : Array[String] = []
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      Ident(start) =>
        if i + 2 < tokens.length() &&
          tokens[i + 1] is Colon &&
          tokens[i + 2] is Ident(_) {
          match tokens[i + 2] {
            Ident(end) => {
              append_range_refs(start, end, refs)
              i = i + 3
            }
            _ => i = i + 1
          }
        } else {
          append_ref(start, refs)
          i = i + 1
        }
      _ => i = i + 1
    }
  }
  refs
}

///|
fn tokenize(s : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == ' ' || c == '\t' || c == '\n' {
      i = i + 1
    } else if is_digit(c) || c == '.' {
      let start = i
      i = i + 1
      while i < chars.length() && (is_digit(chars[i]) || chars[i] == '.') {
        i = i + 1
      }
      let text = chars_to_string(chars[start:i])
      let n = @string.parse_double(text) catch { _ => 0.0 }
      tokens.push(Num(n))
    } else if is_alpha(c) || c == '_' || c == '$' {
      let start = i
      i = i + 1
      while i < chars.length() &&
            (is_alnum(chars[i]) || chars[i] == '_' || chars[i] == '$') {
        i = i + 1
      }
      tokens.push(Ident(chars_to_string(chars[start:i]).to_upper()))
    } else {
      match c {
        '+' => {
          tokens.push(Plus)
          i = i + 1
        }
        '-' => {
          tokens.push(Minus)
          i = i + 1
        }
        '*' => {
          tokens.push(Star)
          i = i + 1
        }
        '/' => {
          tokens.push(Slash)
          i = i + 1
        }
        '^' => {
          tokens.push(Caret)
          i = i + 1
        }
        '(' => {
          tokens.push(LParen)
          i = i + 1
        }
        ')' => {
          tokens.push(RParen)
          i = i + 1
        }
        ',' | ';' => {
          tokens.push(Comma)
          i = i + 1
        }
        ':' => {
          tokens.push(Colon)
          i = i + 1
        }
        '>' =>
          if i + 1 < chars.length() && chars[i + 1] == '=' {
            tokens.push(GreaterEq)
            i = i + 2
          } else {
            tokens.push(Greater)
            i = i + 1
          }
        '<' =>
          if i + 1 < chars.length() && chars[i + 1] == '=' {
            tokens.push(LessEq)
            i = i + 2
          } else if i + 1 < chars.length() && chars[i + 1] == '>' {
            tokens.push(NotEq)
            i = i + 2
          } else {
            tokens.push(Less)
            i = i + 1
          }
        '=' => {
          tokens.push(Eq)
          i = i + 1
        }
        _ => i = i + 1
      }
    }
  }
  tokens
}

///|
fn ParseState::peek(self : ParseState) -> Token? {
  if self.pos < self.tokens.length() {
    Some(self.tokens[self.pos])
  } else {
    None
  }
}

///|
fn ParseState::advance(self : ParseState) -> Unit {
  self.pos = self.pos + 1
}

///|
fn eval_expr(s : String, lookup : (String) -> String) -> Result[String, String] {
  let state = { tokens: tokenize(s), pos: 0 }
  try {
    let value = parse_comparison(state, lookup)
    Ok(format_value(value))
  } catch {
    _ => Err("ERR")
  }
}

///|
fn parse_comparison(
  state : ParseState,
  lookup : (String) -> String,
) -> Double raise Error {
  let left = parse_expr(state, lookup)
  match state.peek() {
    Some(Greater) => {
      state.advance()
      if left > parse_expr(state, lookup) {
        1.0
      } else {
        0.0
      }
    }
    Some(Less) => {
      state.advance()
      if left < parse_expr(state, lookup) {
        1.0
      } else {
        0.0
      }
    }
    Some(GreaterEq) => {
      state.advance()
      if left >= parse_expr(state, lookup) {
        1.0
      } else {
        0.0
      }
    }
    Some(LessEq) => {
      state.advance()
      if left <= parse_expr(state, lookup) {
        1.0
      } else {
        0.0
      }
    }
    Some(Eq) => {
      state.advance()
      if left == parse_expr(state, lookup) {
        1.0
      } else {
        0.0
      }
    }
    Some(NotEq) => {
      state.advance()
      if left != parse_expr(state, lookup) {
        1.0
      } else {
        0.0
      }
    }
    _ => left
  }
}

///|
fn parse_expr(
  state : ParseState,
  lookup : (String) -> String,
) -> Double raise Error {
  let mut value = parse_term(state, lookup)
  while true {
    match state.peek() {
      Some(Plus) => {
        state.advance()
        value = value + parse_term(state, lookup)
      }
      Some(Minus) => {
        state.advance()
        value = value - parse_term(state, lookup)
      }
      _ => break
    }
  }
  value
}

///|
fn parse_term(
  state : ParseState,
  lookup : (String) -> String,
) -> Double raise Error {
  let mut value = parse_factor(state, lookup)
  while true {
    match state.peek() {
      Some(Star) => {
        state.advance()
        value = value * parse_factor(state, lookup)
      }
      Some(Slash) => {
        state.advance()
        let divisor = parse_factor(state, lookup)
        if divisor == 0.0 {
          fail("division by zero")
        }
        value = value / divisor
      }
      _ => break
    }
  }
  value
}

///|
fn parse_factor(
  state : ParseState,
  lookup : (String) -> String,
) -> Double raise Error {
  let mut value = match state.peek() {
    Some(Num(n)) => {
      state.advance()
      n
    }
    Some(Minus) => {
      state.advance()
      -parse_factor(state, lookup)
    }
    Some(Plus) => {
      state.advance()
      parse_factor(state, lookup)
    }
    Some(LParen) => {
      state.advance()
      let v = parse_comparison(state, lookup)
      match state.peek() {
        Some(RParen) => state.advance()
        _ => fail("missing )")
      }
      v
    }
    Some(Ident(name)) => {
      state.advance()
      match state.peek() {
        Some(LParen) => parse_func_call(state, name, lookup)
        _ =>
          match @cell.parse_ref(name) {
            Some(_) =>
              match to_num(lookup(name)) {
                Some(n) => n
                None => 0.0
              }
            None => 0.0
          }
      }
    }
    _ => fail("unexpected token")
  }
  while true {
    match state.peek() {
      Some(Caret) => {
        state.advance()
        value = pow(value, parse_factor(state, lookup))
      }
      _ => break
    }
  }
  value
}

///|
fn parse_func_call(
  state : ParseState,
  name : String,
  lookup : (String) -> String,
) -> Double raise Error {
  state.advance()
  let result = match name {
    "IF" => parse_if(state, lookup)
    "AND" | "OR" => parse_logic_func(state, name, lookup)
    "NOT" => parse_not_func(state, lookup)
    "SUM"
    | "AVG"
    | "AVERAGE"
    | "MIN"
    | "MAX"
    | "COUNT"
    | "PRODUCT"
    | "MEDIAN" => parse_aggregate_func(state, name, lookup)
    "ROUND" | "ABS" | "SQRT" | "POW" => parse_math_func(state, name, lookup)
    "LEN" => parse_string_func(state, name, lookup)
    _ => fail("unknown function")
  }
  match state.peek() {
    Some(RParen) => state.advance()
    _ => fail("missing )")
  }
  result
}

///|
fn parse_if(
  state : ParseState,
  lookup : (String) -> String,
) -> Double raise Error {
  let cond = parse_comparison(state, lookup)
  match state.peek() {
    Some(Comma) => state.advance()
    _ => fail("missing comma")
  }
  let then_value = parse_comparison(state, lookup)
  match state.peek() {
    Some(Comma) => state.advance()
    _ => fail("missing comma")
  }
  let else_value = parse_comparison(state, lookup)
  if cond != 0.0 {
    then_value
  } else {
    else_value
  }
}

///|
fn parse_logic_func(
  state : ParseState,
  name : String,
  lookup : (String) -> String,
) -> Double raise Error {
  let values : Array[Double] = []
  values.push(parse_comparison(state, lookup))
  while state.peek() is Some(Comma) {
    state.advance()
    values.push(parse_comparison(state, lookup))
  }
  match name {
    "AND" => if values.all(value => value != 0.0) { 1.0 } else { 0.0 }
    "OR" => if values.any(value => value != 0.0) { 1.0 } else { 0.0 }
    _ => fail("unknown logic")
  }
}

///|
fn parse_not_func(
  state : ParseState,
  lookup : (String) -> String,
) -> Double raise Error {
  if parse_comparison(state, lookup) == 0.0 {
    1.0
  } else {
    0.0
  }
}

///|
fn parse_math_func(
  state : ParseState,
  name : String,
  lookup : (String) -> String,
) -> Double raise Error {
  let args : Array[Double] = []
  args.push(parse_comparison(state, lookup))
  while state.peek() is Some(Comma) {
    state.advance()
    args.push(parse_comparison(state, lookup))
  }
  apply_math_func(name, args)
}

///|
fn parse_string_func(
  state : ParseState,
  _name : String,
  lookup : (String) -> String,
) -> Double raise Error {
  match state.peek() {
    Some(Ident(name)) => {
      state.advance()
      lookup(name).length().to_double()
    }
    _ => parse_comparison(state, lookup).to_string().length().to_double()
  }
}

///|
fn parse_aggregate_func(
  state : ParseState,
  name : String,
  lookup : (String) -> String,
) -> Double raise Error {
  let values : Array[Double] = []
  parse_aggregate_arg(state, lookup, values)
  while state.peek() is Some(Comma) {
    state.advance()
    parse_aggregate_arg(state, lookup, values)
  }
  apply_aggregate_func(name, values)
}

///|
fn parse_aggregate_arg(
  state : ParseState,
  lookup : (String) -> String,
  values : Array[Double],
) -> Unit raise Error {
  match state.peek() {
    Some(Ident(start)) => {
      state.advance()
      match state.peek() {
        Some(Colon) => {
          state.advance()
          match state.peek() {
            Some(Ident(end)) => {
              state.advance()
              expand_range(start, end, lookup, values)
            }
            _ => fail("bad range")
          }
        }
        _ =>
          match to_num(lookup(start)) {
            Some(n) => values.push(n)
            None => ()
          }
      }
    }
    _ => values.push(parse_comparison(state, lookup))
  }
}

///|
fn expand_range(
  r1 : String,
  r2 : String,
  lookup : (String) -> String,
  values : Array[Double],
) -> Unit {
  match (@cell.parse_ref(r1), @cell.parse_ref(r2)) {
    (Some(a), Some(b)) => {
      let row_start = if a.row < b.row { a.row } else { b.row }
      let row_end = if a.row > b.row { a.row } else { b.row }
      let col_start = if a.col < b.col { a.col } else { b.col }
      let col_end = if a.col > b.col { a.col } else { b.col }
      for row in row_start..<=row_end {
        for col in col_start..<=col_end {
          match to_num(lookup(@cell.make_key(row, col))) {
            Some(n) => values.push(n)
            None => ()
          }
        }
      }
    }
    _ => ()
  }
}

///|
fn append_range_refs(r1 : String, r2 : String, refs : Array[String]) -> Unit {
  match (@cell.parse_ref(r1), @cell.parse_ref(r2)) {
    (Some(a), Some(b)) => {
      let row_start = if a.row < b.row { a.row } else { b.row }
      let row_end = if a.row > b.row { a.row } else { b.row }
      let col_start = if a.col < b.col { a.col } else { b.col }
      let col_end = if a.col > b.col { a.col } else { b.col }
      for row in row_start..<=row_end {
        for col in col_start..<=col_end {
          append_ref(@cell.make_key(row, col), refs)
        }
      }
    }
    _ => {
      append_ref(r1, refs)
      append_ref(r2, refs)
    }
  }
}

///|
fn append_ref(ref_str : String, refs : Array[String]) -> Unit {
  match @cell.parse_ref(ref_str) {
    Some(addr) => {
      let key = addr.key()
      if !refs.any(item => item == key) {
        refs.push(key)
      }
    }
    None => ()
  }
}

///|
fn apply_aggregate_func(
  name : String,
  values : Array[Double],
) -> Double raise Error {
  if values.is_empty() {
    return 0.0
  }
  match name {
    "SUM" => values.fold(init=0.0, fn(acc, v) { acc + v })
    "AVG" | "AVERAGE" =>
      values.fold(init=0.0, fn(acc, v) { acc + v }) /
      values.length().to_double()
    "MIN" => {
      let mut m = values[0]
      for v in values {
        if v < m {
          m = v
        }
      }
      m
    }
    "MAX" => {
      let mut m = values[0]
      for v in values {
        if v > m {
          m = v
        }
      }
      m
    }
    "COUNT" => values.length().to_double()
    "PRODUCT" => values.fold(init=1.0, fn(acc, v) { acc * v })
    "MEDIAN" => median_value(values)
    _ => fail("unknown aggregate")
  }
}

///|
fn median_value(values : Array[Double]) -> Double {
  let sorted = values.copy()
  for i in 0..<sorted.length() {
    let start = i + 1
    for j in start..<sorted.length() {
      if sorted[j] < sorted[i] {
        let value = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = value
      }
    }
  }
  let mid = sorted.length() / 2
  if sorted.length() % 2 == 1 {
    sorted[mid]
  } else {
    (sorted[mid - 1] + sorted[mid]) / 2.0
  }
}

///|
fn apply_math_func(name : String, args : Array[Double]) -> Double raise Error {
  match name {
    "ROUND" =>
      if args.length() == 1 {
        (args[0] + 0.5).floor()
      } else {
        let scale = pow10(args[1].to_int())
        (args[0] * scale + 0.5).floor() / scale
      }
    "ABS" => if args[0] < 0.0 { -args[0] } else { args[0] }
    "SQRT" => pow(args[0], 0.5)
    "POW" => if args.length() >= 2 { pow(args[0], args[1]) } else { args[0] }
    _ => fail("unknown math")
  }
}

///|
fn to_num(s : String) -> Double? {
  @cell.parse_number(s)
}

///|
fn format_value(n : Double) -> String {
  @cell.format_general_number(n)
}

///|
fn pow(base : Double, exp : Double) -> Double {
  @math.pow(base, exp)
}

///|
fn pow10(n : Int) -> Double {
  let mut value = 1.0
  if n >= 0 {
    for _ in 0..<n {
      value = value * 10.0
    }
    value
  } else {
    for _ in 0..<-n {
      value = value / 10.0
    }
    value
  }
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_alpha(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
fn is_alnum(c : Char) -> Bool {
  is_alpha(c) || is_digit(c)
}

///|
fn chars_to_string(chars : ArrayView[Char]) -> String {
  let builder = StringBuilder()
  for ch in chars {
    builder.write_char(ch)
  }
  builder.to_string()
}
