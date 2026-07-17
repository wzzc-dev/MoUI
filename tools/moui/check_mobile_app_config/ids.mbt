///|
fn is_ascii_letter(ch : Char) -> Bool {
  ch.is_ascii_alphabetic()
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch.is_ascii_digit()
}

///|
fn is_android_id_part_char(ch : Char) -> Bool {
  is_ascii_letter(ch) || is_ascii_digit(ch) || ch == '_'
}

///|
fn is_bundle_id_part_char(ch : Char) -> Bool {
  is_ascii_letter(ch) || is_ascii_digit(ch) || ch == '-'
}

///|
fn valid_segmented_id(value : String, part_ok : (Char) -> Bool) -> Bool {
  if value == "" {
    return false
  }
  let mut segments = 0
  let mut segment_len = 0
  let mut first_in_segment = true
  for ch in value {
    if ch == '.' {
      if segment_len == 0 {
        return false
      }
      segments += 1
      segment_len = 0
      first_in_segment = true
      continue
    }
    if first_in_segment {
      if !is_ascii_letter(ch) {
        return false
      }
      first_in_segment = false
      segment_len = 1
    } else if part_ok(ch) {
      segment_len += 1
    } else {
      return false
    }
  }
  segments >= 1 && segment_len > 0
}

///|
fn valid_android_application_id(value : String) -> Bool {
  valid_segmented_id(value, is_android_id_part_char)
}

///|
fn valid_bundle_id(value : String) -> Bool {
  valid_segmented_id(value, is_bundle_id_part_char)
}

///|
fn valid_native_library(value : String) -> Bool {
  if value == "" {
    return false
  }
  for ch in value {
    if !(is_ascii_letter(ch) || is_ascii_digit(ch) || ch == '_') {
      return false
    }
  }
  true
}

///|
fn safe_app_id(app_id : String) -> String {
  let builder = StringBuilder::new()
  for ch in app_id {
    if is_ascii_letter(ch) || is_ascii_digit(ch) || ch == '_' {
      builder.write_char(ch)
    } else {
      builder.write_char('_')
    }
  }
  builder.to_string()
}

///|
fn parse_float_prefix(value : String) -> Double {
  let mut acc = 0.0
  let mut seen_digit = false
  let mut frac = false
  let mut place = 0.1
  for ch in value {
    if ch.is_ascii_digit() {
      let digit = (ch.to_int() - '0'.to_int()).to_double()
      if frac {
        acc = acc + digit * place
        place = place * 0.1
      } else {
        acc = acc * 10.0 + digit
      }
      seen_digit = true
    } else if ch == '.' && !frac {
      frac = true
    } else {
      break
    }
  }
  if seen_digit {
    acc
  } else {
    0.0
  }
}
