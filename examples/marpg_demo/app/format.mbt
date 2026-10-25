// Decoders for the five container shapes recovered from the original engine.
// Each one is the read side of `tools/marpg/pack.py`, so a fixture encoded by
// the generator and a fixture decoded here describe the same content.

///|
pub struct GameMap {
  tilesets : Array[Int32]
  width : Int32
  height : Int32
  tiles : Array[Array[Int32]]
  flags : Array[Array[Int32]]
}

///|
/// `u8 layer_count | u8 tileset x n | u16 w | u16 h |
///  i16 tiles x n (row-major) | ceil(cells/4) flag bytes x n`.
///
/// Tile ids are 0-based atlas indices and negative means empty: the original
/// documentation claimed `tileId - 1`, which the extracted maps falsify (the
/// drawn layers reach exactly `atlas_capacity - 1`, and the collision layer
/// only ever holds -1 and 0).
pub fn map_decode(cur : Cursor) -> GameMap raise FormatError {
  let layers = cur.u8()
  if layers <= 0 {
    raise BadShape("map layer count " + layers.to_string())
  }
  let tilesets = cur.u8_all(layers)
  let width = cur.u16()
  let height = cur.u16()
  let cells = width * height
  let tiles : Array[Array[Int32]] = []
  for i = 0; i < layers; i = i + 1 {
    let layer = cur.i16_all(cells)
    tiles.push(layer)
  }
  let packed = (cells + 3) / 4
  let flags : Array[Array[Int32]] = []
  for i = 0; i < layers; i = i + 1 {
    let raw = cur.u8_all(packed)
    let layer : Array[Int32] = []
    for j = 0; j < cells; j = j + 1 {
      // MSB-first, exactly `flags[cell / 4] >> (3 - cell % 4) * 2 & 3`.
      let shift = (3 - j % 4) * 2
      layer.push((raw[j / 4] >> shift) & 3)
    }
    flags.push(layer)
  }
  if !cur.eof() {
    raise BadShape("map has trailing bytes")
  }
  { tilesets, width, height, tiles, flags, }
}

///|
pub fn GameMap::cell_solid(self : GameMap, col : Int32, row : Int32) -> Bool {
  // The last layer is the collision layer and is never drawn: `>= 0` blocks.
  let layer = self.tiles[self.tilesets.length() - 1]
  if col < 0 || row < 0 || col >= self.width || row >= self.height {
    true
  } else {
    layer[row * self.width + col] >= 0
  }
}

///|
pub struct NumTable {
  kinds : Array[Int32]
  rows : Int32
  columns : Array[Array[Int32]]
}

///|
pub let col_i8 : Int32 = 0

///|
pub let col_i16 : Int32 = 1

///|
pub let col_i32 : Int32 = 2

///|
/// Column-typed numeric table: `i16 cols | i16 rows | u8 type[] | column-major`.
pub fn table_decode(cur : Cursor) -> NumTable raise FormatError {
  let cols = cur.i16()
  let rows = cur.i16()
  if cols <= 0 || rows < 0 {
    raise BadShape("table shape " + cols.to_string() + "x" + rows.to_string())
  }
  let kinds = cur.u8_all(cols)
  for kind in kinds {
    if kind < col_i8 || kind > col_i32 {
      raise BadShape("unknown column type " + kind.to_string())
    }
  }
  let columns : Array[Array[Int32]] = []
  for kind in kinds {
    let column = if kind == col_i8 {
      cur.i8_all(rows)
    } else if kind == col_i16 {
      cur.i16_all(rows)
    } else {
      cur.i32_all(rows)
    }
    columns.push(column)
  }
  if !cur.eof() {
    raise BadShape("table has trailing bytes")
  }
  { kinds, rows, columns, }
}

///|
pub fn NumTable::cell(self : NumTable, row : Int32, col : Int32) -> Int32 {
  self.columns[col][row]
}

///|
pub fn NumTable::row(self : NumTable, row : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  for col = 0; col < self.columns.length(); col = col + 1 {
    out.push(self.columns[col][row])
  }
  out
}

///|
/// `u16 count | u16 byte_length[] | utf-8 payloads`.
///
/// The engine materialises text straight out of the pool (`fY[idx]`).  MoonBit
/// `String` has no from-UTF-8-bytes constructor in this toolchain, so the
/// payloads are verified byte-for-byte against the generated literal table and
/// the VM reads text from that table by the same index.
pub fn strings_verify(
  cur : Cursor,
  texts : Array[String],
) -> Unit raise FormatError {
  let count = cur.u16()
  if count != texts.length() {
    raise BadShape("string count " + count.to_string())
  }
  let lengths = cur.u16_all(count)
  for i = 0; i < count; i = i + 1 {
    let want = @utf8.encode(texts[i])
    if lengths[i] != want.length() {
      raise BadShape("string " + i.to_string() + " length")
    }
    let sub = cur.child(lengths[i])
    for j = 0; j < want.length(); j = j + 1 {
      let got = sub.u8()
      if got != want[j].to_int() {
        raise BadShape("string " + i.to_string() + " bytes")
      }
    }
  }
  if !cur.eof() {
    raise BadShape("string pool has trailing bytes")
  }
}

///|
pub struct Insn {
  opcode : Int32
  operands : Array[Int32]
}

///|
/// One script thread.  Thread `n` *is* block `n` -- the bundle has no script id,
/// its first column is the engine's `bf` sprite binding (a short, so 0xFFFF is the
/// -1 "unbound" of the boot and scene scripts), the second is the `aX` thread class
/// and the third the `aW` re-arm mark (`d.java:3187-3205`).
pub struct Thread {
  binding : Int32
  class : Int32
  mark : Int32
  insns : Array[Insn]
}

///|
/// `u16 count | u16 bindings | u8 classes | u8 marks | u16 lengths |
///  i16 opcodes | u16 operand_total | u16 operands`.
///
/// Operands live in one flat pool and are consumed in bundle order, so an
/// instruction's operand base is the running sum of `arity[opcode]` -- the same
/// prefix table the engine keeps as `bd[]`.
pub fn script_decode(
  cur : Cursor,
  arity : Array[Int32],
) -> ScriptSet raise FormatError {
  let count = cur.u16()
  let stored_bindings = cur.u16_all(count)
  let classes = cur.u8_all(count)
  let marks = cur.u8_all(count)
  let lengths = cur.u16_all(count)
  let mut total = 0
  for n in lengths {
    total = total + n
  }
  let opcodes = cur.i16_all(total)
  let operand_total = cur.u16()
  let stored = cur.u16_all(operand_total)
  let operands : Array[Int32] = []
  for v in stored {
    operands.push(if v >= 0x8000 { v - 0x10000 } else { v })
  }
  if !cur.eof() {
    raise BadShape("script bundle has trailing bytes")
  }
  let threads : Array[Thread] = []
  let mut insn_at = 0
  let mut operand_at = 0
  for index = 0; index < count; index = index + 1 {
    let length = lengths[index]
    let insns : Array[Insn] = []
    for pc = 0; pc < length; pc = pc + 1 {
      let opcode = opcodes[insn_at + pc]
      if opcode < 0 || opcode >= arity.length() {
        raise BadShape("opcode out of table " + opcode.to_string())
      }
      let width = arity[opcode]
      if operand_at + width > operands.length() {
        raise BadShape("operand pool too small")
      }
      let values : Array[Int32] = []
      for k = 0; k < width; k = k + 1 {
        values.push(operands[operand_at + k])
      }
      operand_at = operand_at + width
      insns.push({ opcode, operands: values, })
    }
    let binding = stored_bindings[index]
    threads.push({
      binding: if binding >= 0x8000 {
        binding - 0x10000
      } else {
        binding
      },
      class: classes[index],
      mark: marks[index],
      insns,
    })
    insn_at = insn_at + length
  }
  if insn_at != opcodes.length() {
    raise BadShape("opcode table has leftovers")
  }
  if operand_at != operands.length() {
    raise BadShape("operand pool has leftovers")
  }
  { threads, }
}

///|
/// The VM keeps one state record per thread, so it addresses them by index; a
/// repeatable NPC is two threads with the same binding, not one thread looked up
/// by name.
pub struct ScriptSet {
  threads : Array[Thread]
}

///|
/// One animation record.  The field names mirror the engine's arrays:
/// - `rects` is `R`, four i16 per source rect stored `(y, x, w, h)`
///   (f.java:649-655 reads slot 1 as source x and slot 0 as source y);
/// - `steps` is `S`, four i16 per step stored `(rect_id, offset_a, offset_b,
///   transform)` (f.java:674-685);
/// - `t` is the `T` prefix table, scaled by 4 because a step is four shorts; it
///   bounds the steps of one group, `f.java:630-632`'s `(T[n+1] - T[n]) >> 2`;
/// - `v` is the `V` prefix table, counted in timeline entries;
/// - `rect_of_step`/`hold_of_step`/`deltas` are `U`/`W`/`X`, the per-entry walk
///   timeline: rect id, ticks to hold, and the signed destination nudge
///   (f.java:196-213).
///
/// `T` and `V` index different spaces and agree on nothing: in the extracted
/// `anim.bin` record 0 they hold 64 and 20 increments and total 1090 and 94, so
/// a reader that requires them to match rejects valid data.
pub struct AnimRecord {
  id : Int32
  frames : Int32
  rects : Array[Int32]
  t : Array[Int32]
  steps : Array[Int32]
  v : Array[Int32]
  rect_of_step : Array[Int32]
  hold_of_step : Array[Int32]
  deltas : Array[Int32]
}

///|
/// `u8 id | u16 frames | i16 rects[frames*4] | u8 n | u8 t_inc[n] |
///  i16 steps[t*4] | u8 m | u8 v_inc[m] | u8 rect[nv] | u8 hold[nv] |
///  i8 delta[nv*2]`, records back-to-back and terminated by `id == 0xFF`.
pub fn anim_decode(cur : Cursor) -> Array[AnimRecord] raise FormatError {
  let records : Array[AnimRecord] = []
  let mut terminated = false
  while !cur.eof() {
    let id = cur.u8()
    if id == 0xFF {
      terminated = true
      break
    }
    let frames = cur.u16()
    let rects = cur.i16_all(frames * 4)
    let t_groups = cur.u8()
    let t_inc = cur.u8_all(t_groups)
    let t : Array[Int32] = [0]
    for i = 0; i < t_groups; i = i + 1 {
      t.push(t[i] + t_inc[i] * 4)
    }
    let steps = cur.i16_all(t[t_groups])
    let v_groups = cur.u8()
    let v_inc = cur.u8_all(v_groups)
    let v : Array[Int32] = [0]
    for i = 0; i < v_groups; i = i + 1 {
      v.push(v[i] + v_inc[i])
    }
    let timeline = v[v_groups]
    let rect_of_step = cur.u8_all(timeline)
    let hold_of_step = cur.u8_all(timeline)
    let deltas = cur.i8_all(timeline * 2)
    let record = {
      id,
      frames,
      rects,
      t,
      steps,
      v,
      rect_of_step,
      hold_of_step,
      deltas,
    }
    records.push(record)
  }
  if !terminated {
    raise BadShape("anim records lack terminator")
  }
  if !cur.eof() {
    raise BadShape("anim has trailing bytes")
  }
  records
}
