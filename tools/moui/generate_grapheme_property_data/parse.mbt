///|
struct CodeRange {
  start : Int
  end : Int
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
fn parse_codepoint(
  value : String,
  source : String,
  line_number : Int,
) -> Result[Int, String] {
  if !is_hex_token(value) {
    return Err(
      source +
      ":" +
      line_number.to_string() +
      ": invalid codepoint '" +
      value +
      "'",
    )
  }
  match parse_hex_int(value) {
    Ok(codepoint) => Ok(codepoint)
    Err(_) =>
      Err(
        source +
        ":" +
        line_number.to_string() +
        ": invalid codepoint '" +
        value +
        "'",
      )
  }
}

///|
fn parse_range(
  value : String,
  source : String,
  line_number : Int,
) -> Result[CodeRange, String] {
  match value.find("..") {
    None =>
      match parse_codepoint(value.trim().to_owned(), source, line_number) {
        Ok(codepoint) => Ok({ start: codepoint, end: codepoint })
        Err(message) => Err(message)
      }
    Some(offset) => {
      let start_text = value[:offset].trim().to_owned()
      let end_text = value[offset + 2:].trim().to_owned()
      match parse_codepoint(start_text, source, line_number) {
        Err(message) => Err(message)
        Ok(start) =>
          match parse_codepoint(end_text, source, line_number) {
            Err(message) => Err(message)
            Ok(end) =>
              if end < start {
                Err(
                  source +
                  ":" +
                  line_number.to_string() +
                  ": range end precedes start",
                )
              } else {
                Ok({ start, end })
              }
          }
      }
    }
  }
}

///|
fn split_comment(line : String) -> String {
  match line.find("#") {
    None => line
    Some(offset) => line[:offset].to_owned()
  }
}

///|
fn split_fields(body : String) -> Array[String] {
  let fields : Array[String] = []
  let mut acc = ""
  for ch in body {
    if ch == ';' {
      fields.push(acc.trim().to_owned())
      acc = ""
    } else {
      acc = acc + String::from_array([ch])
    }
  }
  fields.push(acc.trim().to_owned())
  fields
}

///|
fn parse_property_ranges(
  text : String,
  source : String,
  wanted_properties : Array[String],
) -> Result[Map[String, Array[CodeRange]], String] {
  let ranges : Map[String, Array[CodeRange]] = Map([])
  for property in wanted_properties {
    ranges[property] = []
  } nobreak {
    ()
  }
  let mut line_number = 0
  for line in text.split("\n") {
    line_number += 1
    let raw = line.to_owned()
    let cleaned = if raw.has_suffix("\r") {
      raw[:raw.length() - 1].to_owned()
    } else {
      raw
    }
    let body = split_comment(cleaned).trim().to_owned()
    if body == "" {
      continue
    }
    let fields = split_fields(body)
    if fields.length() < 2 {
      return Err(
        source +
        ":" +
        line_number.to_string() +
        ": expected '<range>; <property>'",
      )
    }
    let property = fields[1]
    if !wanted_properties.contains(property) {
      continue
    }
    match parse_range(fields[0], source, line_number) {
      Ok(range) => ranges[property].push(range)
      Err(message) => return Err(message)
    }
  } nobreak {
    ()
  }
  Ok(ranges)
}

///|
fn parse_indic_conjunct_ranges(
  text : String,
  source : String,
) -> Result[Map[String, Array[CodeRange]], String] {
  let ranges : Map[String, Array[CodeRange]] = {
    "Linker": [],
    "Consonant": [],
    "Extend": [],
  }
  let mut line_number = 0
  for line in text.split("\n") {
    line_number += 1
    let raw = line.to_owned()
    let cleaned = if raw.has_suffix("\r") {
      raw[:raw.length() - 1].to_owned()
    } else {
      raw
    }
    let body = split_comment(cleaned).trim().to_owned()
    if body == "" {
      continue
    }
    let fields = split_fields(body)
    if fields.length() < 3 || fields[1] != "InCB" {
      continue
    }
    let property = fields[2]
    match ranges.get(property) {
      None => ()
      Some(list) =>
        match parse_range(fields[0], source, line_number) {
          Ok(range) => list.push(range)
          Err(message) => return Err(message)
        }
    }
  } nobreak {
    ()
  }
  Ok(ranges)
}

///|
fn merge_ranges(ranges : Array[CodeRange]) -> Array[CodeRange] {
  let sorted = ranges.copy()
  sorted.sort_by((left, right) => {
    if left.start == right.start {
      left.end - right.end
    } else {
      left.start - right.start
    }
  })
  let merged : Array[CodeRange] = []
  for range in sorted {
    if merged.is_empty() {
      merged.push({ start: range.start, end: range.end })
    } else {
      let previous = merged[merged.length() - 1]
      if range.start <= previous.end + 1 {
        let end = if range.end > previous.end {
          range.end
        } else {
          previous.end
        }
        merged[merged.length() - 1] = { start: previous.start, end }
      } else {
        merged.push({ start: range.start, end: range.end })
      }
    }
  }
  merged
}

///|
fn moon_hex(value : Int) -> String {
  let hex_digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let chars : Array[Char] = []
  let mut n = value
  if n == 0 {
    chars.push('0')
  } else {
    while n > 0 {
      chars.push(hex_digits[n % 16])
      n = n / 16
    }
  }
  while chars.length() < 4 {
    chars.push('0')
  }
  let ordered : Array[Char] = []
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    ordered.push(chars[i])
  }
  "0x" + String::from_array(ordered)
}

///|
fn range_chunk_size() -> Int {
  48
}

///|
fn expression_for_ranges(ranges : Array[CodeRange]) -> Array[String] {
  if ranges.is_empty() {
    return ["  false"]
  }
  let lines : Array[String] = []
  for index, range in ranges {
    let suffix = if index == ranges.length() - 1 { "" } else { " ||" }
    if range.start == range.end {
      lines.push("  codepoint == " + moon_hex(range.start) + suffix)
    } else {
      lines.push(
        "  (codepoint >= " +
        moon_hex(range.start) +
        " && codepoint <= " +
        moon_hex(range.end) +
        ")" +
        suffix,
      )
    }
  }
  lines
}

///|
fn function_body_for_ranges(ranges : Array[CodeRange]) -> String {
  expression_for_ranges(ranges).join("\n")
}

///|
fn function_for_ranges(name : String, ranges : Array[CodeRange]) -> String {
  let merged = merge_ranges(ranges)
  if merged.length() <= range_chunk_size() {
    return "///|\nfn " +
      name +
      "(codepoint : Int) -> Bool {\n" +
      function_body_for_ranges(merged) +
      "\n}\n"
  }
  let chunks : Array[Array[CodeRange]] = []
  let mut start = 0
  while start < merged.length() {
    let end = if start + range_chunk_size() < merged.length() {
      start + range_chunk_size()
    } else {
      merged.length()
    }
    let chunk : Array[CodeRange] = []
    for index in start..<end {
      chunk.push(merged[index])
    }
    chunks.push(chunk)
    start = end
  }
  let dispatch_lines : Array[String] = []
  for index, _ in chunks {
    let suffix = if index == chunks.length() - 1 { "" } else { " ||" }
    dispatch_lines.push(
      "  " + name + "_chunk_" + index.to_string() + "(codepoint)" + suffix,
    )
  }
  let helpers : Array[String] = []
  for index, chunk in chunks {
    helpers.push(
      "///|\nfn " +
      name +
      "_chunk_" +
      index.to_string() +
      "(codepoint : Int) -> Bool {\n" +
      function_body_for_ranges(chunk) +
      "\n}\n",
    )
  }
  "///|\nfn " +
  name +
  "(codepoint : Int) -> Bool {\n" +
  dispatch_lines.join("\n") +
  "\n}\n\n" +
  helpers.join("\n")
}

///|
fn ranges_or_empty(
  map : Map[String, Array[CodeRange]],
  key : String,
) -> Array[CodeRange] {
  match map.get(key) {
    Some(values) => values
    None => []
  }
}
