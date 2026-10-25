// Byte-level readers for the container shapes recovered from the original J2ME
// engine.  The payloads are self-authored (tools/marpg/gen_content.py); only the
// framing follows the reversed format, which is what lets the same decoder read
// either side of the round trip.

///|
pub suberror FormatError {
  Truncated
  BadBase64
  BadShape(String)
}

///|
/// A read cursor over one blob, with an explicit end so a `.pak` entry can be
/// read without copying bytes out of the cartridge.
pub struct Cursor {
  data : Bytes
  mut pos : Int32
  limit : Int32
}

///|
pub fn Cursor::new(data : Bytes) -> Cursor {
  { data, pos: 0, limit: data.length(), }
}

///|
pub fn Cursor::remaining(self : Cursor) -> Int32 {
  self.limit - self.pos
}

///|
pub fn Cursor::eof(self : Cursor) -> Bool {
  self.pos >= self.limit
}

///|
pub fn Cursor::u8(self : Cursor) -> Int32 raise FormatError {
  if self.remaining() < 1 {
    raise Truncated
  }
  let v = self.data[self.pos].to_int()
  self.pos = self.pos + 1
  v
}

///|
pub fn Cursor::i8(self : Cursor) -> Int32 raise FormatError {
  let v = self.u8()
  if v >= 0x80 {
    v - 0x100
  } else {
    v
  }
}

///|
/// All multi-byte integers in the reversed formats are big-endian, matching
/// `DataInputStream.readShort`/`readInt` on the original side.
pub fn Cursor::u16(self : Cursor) -> Int32 raise FormatError {
  if self.remaining() < 2 {
    raise Truncated
  }
  let hi = self.data[self.pos].to_int()
  let lo = self.data[self.pos + 1].to_int()
  self.pos = self.pos + 2
  (hi << 8) | lo
}

///|
pub fn Cursor::i16(self : Cursor) -> Int32 raise FormatError {
  let v = self.u16()
  if v >= 0x8000 {
    v - 0x10000
  } else {
    v
  }
}

///|
pub fn Cursor::i32(self : Cursor) -> Int32 raise FormatError {
  if self.remaining() < 4 {
    raise Truncated
  }
  let b0 = self.data[self.pos].to_int()
  let b1 = self.data[self.pos + 1].to_int()
  let b2 = self.data[self.pos + 2].to_int()
  let b3 = self.data[self.pos + 3].to_int()
  self.pos = self.pos + 4
  let v = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
  // MoonBit `Int` is 64-bit on native, so `DataInputStream.readInt`'s sign has
  // to be restored explicitly.  2^32 is beyond the accepted integer literals,
  // hence the doubled half.
  if v >= 0x8000_0000 {
    v - 0x8000_0000 - 0x8000_0000
  } else {
    v
  }
}

///|
pub fn Cursor::u8_all(
  self : Cursor,
  n : Int32,
) -> Array[Int32] raise FormatError {
  let out : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    let v = self.u8()
    out.push(v)
  }
  out
}

///|
pub fn Cursor::i8_all(
  self : Cursor,
  n : Int32,
) -> Array[Int32] raise FormatError {
  let out : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    let v = self.i8()
    out.push(v)
  }
  out
}

///|
pub fn Cursor::u16_all(
  self : Cursor,
  n : Int32,
) -> Array[Int32] raise FormatError {
  let out : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    let v = self.u16()
    out.push(v)
  }
  out
}

///|
pub fn Cursor::i16_all(
  self : Cursor,
  n : Int32,
) -> Array[Int32] raise FormatError {
  let out : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    let v = self.i16()
    out.push(v)
  }
  out
}

///|
pub fn Cursor::i32_all(
  self : Cursor,
  n : Int32,
) -> Array[Int32] raise FormatError {
  let out : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    let v = self.i32()
    out.push(v)
  }
  out
}

///|
/// Unsigned LEB128, the `.pak` entry-length encoding.
pub fn Cursor::leb128(self : Cursor) -> Int32 raise FormatError {
  let mut acc = 0
  let mut shift = 0
  while true {
    let b = self.u8()
    acc = acc | ((b & 0x7f) << shift)
    if (b & 0x80) == 0 {
      break
    }
    shift = shift + 7
  }
  acc
}

///|
/// Split the next `n` bytes off as an independent cursor (a `.pak` payload).
pub fn Cursor::child(self : Cursor, n : Int32) -> Cursor raise FormatError {
  if self.remaining() < n {
    raise Truncated
  }
  let sub = { data: self.data, pos: self.pos, limit: self.pos + n, }
  self.pos = self.pos + n
  sub
}

///|
pub fn decode_base64(text : String) -> Bytes raise FormatError {
  @base64.decode(text) catch {
    _ => raise BadBase64
  }
}

///|
/// `.pak` container: `u8 count | LEB128 x count | payload bytes`.
///
/// The lengths all come first, then the payloads back-to-back -- the original
/// reader could therefore skip an entry it did not need.
pub fn pak_unpack(data : Bytes) -> Array[Cursor] raise FormatError {
  let head = Cursor::new(data)
  let count = head.u8()
  let sizes : Array[Int32] = []
  for i = 0; i < count; i = i + 1 {
    let size = head.leb128()
    sizes.push(size)
  }
  let entries : Array[Cursor] = []
  for size in sizes {
    let entry = head.child(size)
    entries.push(entry)
  }
  entries
}
