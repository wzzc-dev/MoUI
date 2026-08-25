///|
/// Decode a `data:` URL to its payload text.
/// Supports `data:text/html,<payload>` and `data:text/html;base64,<payload>`
/// (base64 payload is interpreted as UTF-8, per the data URL spec).
/// Returns `None` for non-data URLs or undecodable payloads.
pub fn decode_data_url(url : String) -> String? {
  if !url.has_prefix("data:") {
    return None
  }
  let rest = url.unsafe_substring(start=5, end=url.length())
  let comma = rest.find(",")
  match comma {
    None => None
    Some(comma) => {
      let meta = rest.unsafe_substring(start=0, end=comma)
      let payload = rest.unsafe_substring(start=comma + 1, end=rest.length())
      if meta.contains(";base64") {
        let bytes = Some(@base64.decode(payload)) catch { _ => None }
        match bytes {
          None => None
          Some(b) => {
            let text = Some(@utf8.decode(b[:], ignore_bom=true)) catch {
              _ => None
            }
            text
          }
        }
      } else {
        Some(percent_decode(payload))
      }
    }
  }
}

///|
/// Decode percent-encoded payload (`%XX`). Consecutive `%XX` bytes are
/// accumulated and decoded as UTF-8 so multi-byte characters survive.
fn percent_decode(s : String) -> String {
  let buf = StringBuilder()
  let len = s.length()
  let mut i = 0
  let pending : Array[Byte] = []
  while i < len {
    if s[i] == '%' && i + 2 < len {
      match parse_hex_byte(s, i + 1) {
        Some(byte) => {
          pending.push(byte.to_byte())
          i = i + 3
          continue
        }
        None => ()
      }
    }
    if pending.length() > 0 {
      let text = Some(
        @utf8.decode(Bytes::from_array(pending)[:], ignore_bom=true),
      ) catch {
        _ => None
      }
      match text {
        Some(t) => buf.write_string(t)
        None => ()
      }
      pending.clear()
    }
    buf.write_char(s[i].to_int().unsafe_to_char())
    i = i + 1
  }
  if pending.length() > 0 {
    let text = Some(
      @utf8.decode(Bytes::from_array(pending)[:], ignore_bom=true),
    ) catch {
      _ => None
    }
    match text {
      Some(t) => buf.write_string(t)
      None => ()
    }
  }
  buf.to_string()
}

///|
/// Parse two hex digits at `start` as a byte value.
fn parse_hex_byte(s : String, start : Int) -> Int? {
  fn digit(c : UInt16) -> Int? {
    let v = c.to_int()
    if v >= '0'.to_int() && v <= '9'.to_int() {
      return Some(v - '0'.to_int())
    }
    if v >= 'a'.to_int() && v <= 'f'.to_int() {
      return Some(v - 'a'.to_int() + 10)
    }
    if v >= 'A'.to_int() && v <= 'F'.to_int() {
      return Some(v - 'A'.to_int() + 10)
    }
    None
  }
  let hi = digit(s[start])
  let lo = digit(s[start + 1])
  match (hi, lo) {
    (Some(h), Some(l)) => Some(h * 16 + l)
    _ => None
  }
}
