///|
struct GraphemeSample {
  line_number : Int
  codepoints : Array[Int]
  boundaries : Array[Int]
  comment : String
}

///|
fn is_hex_char(ch : Char) -> Bool {
  ch.is_ascii_digit() || (ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f')
}

///|
fn is_hex_token(token : String) -> Bool {
  let len = token.length()
  if len < 4 || len > 6 {
    return false
  }
  for ch in token {
    if !is_hex_char(ch) {
      return false
    }
  }
  true
}

///|
fn parse_hex_int(token : String) -> Result[Int, String] {
  let mut value = 0
  for ch in token {
    let digit = if ch.is_ascii_digit() {
      ch.to_int() - '0'.to_int()
    } else if ch >= 'A' && ch <= 'F' {
      ch.to_int() - 'A'.to_int() + 10
    } else if ch >= 'a' && ch <= 'f' {
      ch.to_int() - 'a'.to_int() + 10
    } else {
      return Err("invalid hex digit")
    }
    value = value * 16 + digit
  }
  if value < 0 || value > 0x10ffff {
    Err("codepoint out of range")
  } else {
    Ok(value)
  }
}

///|
fn split_comment(line : String) -> (String, String) {
  match line.find("#") {
    None => (line, "")
    Some(offset) => (line[:offset].to_owned(), line[offset + 1:].to_owned())
  }
}

///|
fn tokenize_body(body : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut acc = ""
  for ch in body {
    if ch.is_ascii_whitespace() {
      if acc != "" {
        tokens.push(acc)
        acc = ""
      }
    } else {
      acc = acc + String::from_array([ch])
    }
  }
  if acc != "" {
    tokens.push(acc)
  }
  tokens
}

///|
fn normalize_spaces(text : String) -> String {
  tokenize_body(text).join(" ")
}

///|
fn parse_fixture_line(
  line : String,
  line_number : Int,
  input_label : String,
) -> Result[GraphemeSample?, String] {
  let (raw_body, raw_comment) = split_comment(line)
  let body = raw_body.trim().to_owned()
  if body == "" {
    return Ok(None)
  }
  let tokens = tokenize_body(body)
  let codepoints : Array[Int] = []
  let boundaries : Array[Int] = []
  let mut pending_boundary : Bool? = None
  let mut expected_boundary_at = 0
  for token in tokens {
    if token == "÷" || token == "\u00f7" {
      pending_boundary = Some(true)
    } else if token == "×" || token == "\u00d7" {
      pending_boundary = Some(false)
    } else if is_hex_token(token) {
      match pending_boundary {
        None =>
          return Err(
            input_label +
            ":" +
            line_number.to_string() +
            ": codepoint '" +
            token +
            "' has no preceding boundary marker",
          )
        Some(true) => boundaries.push(expected_boundary_at)
        Some(false) => ()
      }
      match parse_hex_int(token) {
        Ok(codepoint) => {
          codepoints.push(codepoint)
          expected_boundary_at += 1
          pending_boundary = None
        }
        Err(_) =>
          return Err(
            input_label +
            ":" +
            line_number.to_string() +
            ": invalid codepoint '" +
            token +
            "'",
          )
      }
    } else {
      return Err(
        input_label +
        ":" +
        line_number.to_string() +
        ": unsupported token '" +
        token +
        "'",
      )
    }
  }
  match pending_boundary {
    Some(true) => boundaries.push(expected_boundary_at)
    Some(false) =>
      return Err(
        input_label +
        ":" +
        line_number.to_string() +
        ": line ended with a no-break marker",
      )
    None => ()
  }
  if codepoints.is_empty() ||
    boundaries.is_empty() ||
    boundaries[0] != 0 ||
    boundaries[boundaries.length() - 1] != codepoints.length() {
    return Err(
      input_label +
      ":" +
      line_number.to_string() +
      ": fixture must start and end with a boundary",
    )
  }
  Ok(
    Some({
      line_number,
      codepoints,
      boundaries,
      comment: normalize_spaces(raw_comment.trim().to_owned()),
    }),
  )
}

///|
fn parse_fixture_text(
  text : String,
  input_label : String,
) -> Result[Array[GraphemeSample], String] {
  let samples : Array[GraphemeSample] = []
  let mut line_number = 0
  for line in text.split("\n") {
    line_number += 1
    let raw = line.to_owned()
    let cleaned = if raw.has_suffix("\r") {
      raw[:raw.length() - 1].to_owned()
    } else {
      raw
    }
    match parse_fixture_line(cleaned, line_number, input_label) {
      Ok(None) => ()
      Ok(Some(sample)) => samples.push(sample)
      Err(message) => return Err(message)
    }
  } nobreak {
    ()
  }
  if samples.is_empty() {
    Err(input_label + ": no grapheme break samples found")
  } else {
    Ok(samples)
  }
}

///|
fn valid_helper_name(name : String) -> Bool {
  if name == "" {
    return false
  }
  let mut first = true
  for ch in name {
    if first {
      if !(ch.is_ascii_alphabetic() || ch == '_') {
        return false
      }
      first = false
    } else if !(ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_') {
      return false
    }
  }
  true
}

///|
fn utf8_len_of_codepoint(codepoint : Int) -> Int {
  if codepoint <= 0x7F {
    1
  } else if codepoint <= 0x7FF {
    2
  } else if codepoint <= 0xFFFF {
    3
  } else {
    4
  }
}

///|
fn utf8_offsets_for_boundaries(
  codepoints : Array[Int],
  boundaries : Array[Int],
) -> Array[Int] {
  let offsets : Array[Int] = []
  for boundary in boundaries {
    let mut total = 0
    for index in 0..<boundary {
      total += utf8_len_of_codepoint(codepoints[index])
    }
    offsets.push(total)
  }
  offsets
}

///|
fn to_hex_upper(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let hex_digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let chars : Array[Char] = []
  let mut n = value
  while n > 0 {
    chars.push(hex_digits[n % 16])
    n = n / 16
  }
  let ordered : Array[Char] = []
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    ordered.push(chars[i])
  }
  String::from_array(ordered)
}

///|
fn escape_moon_string(codepoints : Array[Int]) -> String {
  let builder = StringBuilder()
  for codepoint in codepoints {
    builder.write_string("\\u{")
    builder.write_string(to_hex_upper(codepoint))
    builder.write_string("}")
  }
  builder.to_string()
}

///|
fn sample_label(sample : GraphemeSample) -> String {
  if sample.comment != "" {
    sample.comment
  } else {
    "line " + sample.line_number.to_string()
  }
}

///|
fn join_ints(values : Array[Int]) -> String {
  let parts = values.map(value => value.to_string())
  parts.join(", ")
}
