///|
pub(all) struct CellAddress {
  row : Int
  col : Int
} derive(Eq, Debug)

///|
pub(all) struct CellRange {
  start : CellAddress
  end : CellAddress
} derive(Eq, Debug)

///|
pub(all) enum CellAlign {
  Auto
  Left
  Center
  Right
} derive(Eq, Debug)

///|
pub(all) enum NumFormat {
  General
  Currency
  Percent
  Fixed
} derive(Eq, Debug)

///|
pub(all) enum CellValue {
  Empty
  Number(Double)
  Text(String)
  Error(String)
} derive(Eq, Debug)

///|
pub(all) struct CellFormat {
  bold : Bool
  italic : Bool
  underline : Bool
  align : CellAlign
  num_format : NumFormat
  bg_color : String
  text_color : String
} derive(Eq, Debug)

///|
pub(all) struct Cell {
  raw : String
  value : CellValue
  format : CellFormat
} derive(Eq, Debug)

///|
pub fn CellAddress::new(row~ : Int, col~ : Int) -> CellAddress {
  { row, col }
}

///|
pub fn CellAddress::key(self : CellAddress) -> String {
  make_key(self.row, self.col)
}

///|
pub fn CellRange::new(start~ : CellAddress, end~ : CellAddress) -> CellRange {
  { start, end }
}

///|
pub fn CellFormat::default() -> CellFormat {
  {
    bold: false,
    italic: false,
    underline: false,
    align: CellAlign::Auto,
    num_format: NumFormat::General,
    bg_color: "",
    text_color: "",
  }
}

///|
pub fn Cell::empty() -> Cell {
  { raw: "", value: CellValue::Empty, format: CellFormat::default() }
}

///|
pub fn Cell::new(
  raw? : String = "",
  value? : CellValue = CellValue::Empty,
  format? : CellFormat = CellFormat::default(),
) -> Cell {
  { raw, value, format }
}

///|
pub fn Cell::display(self : Cell) -> String {
  self.value.format_with(self.format.num_format)
}

///|
pub fn Cell::is_empty(self : Cell) -> Bool {
  self.raw.is_empty() &&
  self.value is CellValue::Empty &&
  self.format == CellFormat::default()
}

///|
pub fn CellValue::to_display(self : CellValue) -> String {
  match self {
    CellValue::Empty => ""
    CellValue::Number(n) => format_general_number(n)
    CellValue::Text(s) => s
    CellValue::Error(e) => e
  }
}

///|
pub fn CellValue::format_with(self : CellValue, fmt : NumFormat) -> String {
  match (self, fmt) {
    (CellValue::Number(n), NumFormat::Currency) => "$" + format_decimal_2(n)
    (CellValue::Number(n), NumFormat::Percent) =>
      format_decimal_2(n * 100.0) + "%"
    (CellValue::Number(n), NumFormat::Fixed) => format_decimal_2(n)
    _ => self.to_display()
  }
}

///|
pub fn parse_raw_value(raw : String) -> CellValue {
  let trimmed = raw.trim().to_owned()
  if trimmed.is_empty() {
    CellValue::Empty
  } else {
    match parse_number(trimmed) {
      Some(n) => CellValue::Number(n)
      None => CellValue::Text(raw)
    }
  }
}

///|
pub fn format_display(value : CellValue, fmt : NumFormat) -> String {
  value.format_with(fmt)
}

///|
pub fn parse_number(value : String) -> Double? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    None
  } else {
    Some(@string.parse_double(trimmed)) catch {
      _ => None
    }
  }
}

///|
pub fn format_general_number(value : Double) -> String {
  let i = value.to_int()
  if i.to_double() == value {
    i.to_string()
  } else {
    value.to_string()
  }
}

///|
pub fn format_decimal_2(value : Double) -> String {
  let negative = value < 0.0
  let abs_value = if negative { -value } else { value }
  let scaled = (abs_value * 100.0 + 0.5).floor().to_int()
  let whole = scaled / 100
  let cents = scaled % 100
  let cents_text = if cents < 10 {
    "0" + cents.to_string()
  } else {
    cents.to_string()
  }
  let prefix = if negative { "-" } else { "" }
  prefix + whole.to_string() + "." + cents_text
}

///|
pub fn make_key(row : Int, col : Int) -> String {
  column_label(col) + (row + 1).to_string()
}

///|
pub fn column_label(col : Int) -> String {
  if col < 0 {
    return "?"
  }
  let chars : Array[Char] = []
  let mut n = col + 1
  while n > 0 {
    let rem = (n - 1) % 26
    chars.insert(0, (rem + 'A'.to_int()).unsafe_to_char())
    n = (n - 1) / 26
  }
  chars_to_string(chars)
}

///|
pub fn parse_ref(ref_str : String) -> CellAddress? {
  let chars = ref_str.to_array()
  if chars.length() < 2 {
    return None
  }
  let col_chars : Array[Char] = []
  let row_chars : Array[Char] = []
  let mut i = 0
  if i < chars.length() && chars[i] == '$' {
    i = i + 1
  }
  while i < chars.length() && is_ascii_letter(chars[i]) {
    col_chars.push(chars[i])
    i = i + 1
  }
  if i < chars.length() && chars[i] == '$' {
    i = i + 1
  }
  while i < chars.length() && is_ascii_digit(chars[i]) {
    row_chars.push(chars[i])
    i = i + 1
  }
  if i != chars.length() || col_chars.length() == 0 || row_chars.length() == 0 {
    return None
  }
  match (col_letters_to_num(col_chars), parse_digits_to_int(row_chars)) {
    (Some(c), Some(r)) => Some(CellAddress::new(row=r - 1, col=c - 1))
    _ => None
  }
}

///|
pub fn parse_range(ref_str : String) -> CellRange? {
  match split_once(ref_str, ':') {
    Some((left, right)) =>
      match (parse_ref(left), parse_ref(right)) {
        (Some(start), Some(end)) => Some(CellRange::new(start~, end~))
        _ => None
      }
    None => None
  }
}

///|
pub fn col_letters_to_num(chars : Array[Char]) -> Int? {
  let mut result = 0
  for c in chars {
    let upper = to_upper_ascii(c)
    if upper >= 'A' && upper <= 'Z' {
      result = result * 26 + (upper.to_int() - 'A'.to_int() + 1)
    } else {
      return None
    }
  }
  Some(result)
}

///|
pub fn parse_digits_to_int(chars : Array[Char]) -> Int? {
  let mut result = 0
  for c in chars {
    if is_ascii_digit(c) {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return None
    }
  }
  if result > 0 {
    Some(result)
  } else {
    None
  }
}

///|
fn split_once(value : String, delimiter : Char) -> (String, String)? {
  let chars = value.to_array()
  for i, ch in chars {
    if ch == delimiter {
      return Some((chars_to_string(chars[:i]), chars_to_string(chars[i + 1:])))
    }
  }
  None
}

///|
fn chars_to_string(chars : ArrayView[Char]) -> String {
  let builder = StringBuilder()
  for ch in chars {
    builder.write_char(ch)
  }
  builder.to_string()
}

///|
fn is_ascii_letter(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn to_upper_ascii(c : Char) -> Char {
  if c >= 'a' && c <= 'z' {
    (c.to_int() - 'a'.to_int() + 'A'.to_int()).unsafe_to_char()
  } else {
    c
  }
}
