///|
/// Portrait assets: the small amount of binary handling a world needs.
///
/// A portrait is a file in the world folder (`characters/<名>.png`), and the
/// host contract carries text, so bytes travel as base64 and the UI feeds a
/// `data:` URI to `@views.image`. Keeping the codec here means both hosts
/// produce identical bytes and the tests can round-trip without a filesystem.

///|
/// The base64 alphabet, standard (not URL-safe) with padding.
let base64_alphabet : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
/// Encode bytes as standard base64 with padding.
pub fn base64_encode(bytes : Bytes) -> String {
  let out : Array[Char] = []
  let table : Array[Char] = []
  for ch in base64_alphabet {
    table.push(ch)
  }
  let length = bytes.length()
  let mut index = 0
  while index + 2 < length {
    let a = bytes[index].to_int()
    let b = bytes[index + 1].to_int()
    let c = bytes[index + 2].to_int()
    out.push(table[a >> 2])
    out.push(table[((a & 0x03) << 4) | (b >> 4)])
    out.push(table[((b & 0x0F) << 2) | (c >> 6)])
    out.push(table[c & 0x3F])
    index += 3
  }
  let remaining = length - index
  if remaining == 1 {
    let a = bytes[index].to_int()
    out.push(table[a >> 2])
    out.push(table[(a & 0x03) << 4])
    out.push('=')
    out.push('=')
  } else if remaining == 2 {
    let a = bytes[index].to_int()
    let b = bytes[index + 1].to_int()
    out.push(table[a >> 2])
    out.push(table[((a & 0x03) << 4) | (b >> 4)])
    out.push(table[(b & 0x0F) << 2])
    out.push('=')
  }
  String::from_array(out)
}

///|
/// Does this text look like base64 (and therefore like a portrait a host
/// wrote as text rather than as bytes)?
///
/// A world folder holds portraits two ways: a real image dropped in by hand,
/// and the base64 text a host without a byte writer leaves behind. The reader
/// has to tell them apart, and the only reliable signal is the alphabet: a
/// base64 payload is made of `A-Z a-z 0-9 + / =` and whitespace, while real
/// image bytes almost never are.
pub fn is_base64_text(text : String) -> Bool {
  let trimmed = text.trim()
  if trimmed.is_empty() {
    return false
  }
  for ch in trimmed {
    let ok = (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '+' ||
      ch == '/' ||
      ch == '=' ||
      ch == ' ' ||
      ch == '\n' ||
      ch == '\r' ||
      ch == '\t'
    if !ok {
      return false
    }
  }
  true
}

///|
/// Decode standard base64 back to bytes. `None` means the text is not base64
/// (damaged or hand-edited), which callers treat as "no portrait" rather than
/// rendering noise.
pub fn base64_decode(text : String) -> Bytes? {
  let chars : Array[Char] = []
  for ch in text {
    if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
      continue
    }
    chars.push(ch)
  }
  if chars.length() % 4 != 0 {
    return None
  }
  let out : Array[Byte] = []
  let mut index = 0
  while index < chars.length() {
    let a = base64_value(chars[index])
    let b = base64_value(chars[index + 1])
    let third = chars[index + 2]
    let fourth = chars[index + 3]
    let c : Int32? = if third == '=' { Some(0) } else { base64_value(third) }
    let d : Int32? = if fourth == '=' { Some(0) } else { base64_value(fourth) }
    let (va, vb, vc, vd) = match (a, b, c, d) {
      (Some(va), Some(vb), Some(vc), Some(vd)) => (va, vb, vc, vd)
      _ => return None
    }
    out.push(((va << 2) | (vb >> 4)).to_byte())
    if third != '=' {
      out.push((((vb & 0x0F) << 4) | (vc >> 2)).to_byte())
    }
    if fourth != '=' {
      out.push((((vc & 0x03) << 6) | vd).to_byte())
    }
    index += 4
  }
  Some(Bytes::from_array(out))
}

///|
fn base64_value(ch : Char) -> Int32? {
  if ch >= 'A' && ch <= 'Z' {
    Some(ch.to_int() - 'A'.to_int())
  } else if ch >= 'a' && ch <= 'z' {
    Some(ch.to_int() - 'a'.to_int() + 26)
  } else if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int() + 52)
  } else if ch == '+' {
    Some(62)
  } else if ch == '/' {
    Some(63)
  } else {
    None
  }
}
