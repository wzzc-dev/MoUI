// Golden byte fixtures: each literal is written out in the container layout the
// reversal recovered, byte for byte, so the decoders are pinned to the format
// rather than to whatever the generator happens to emit today.

///|
fn outcome(f : () -> Unit raise FormatError) -> String {
  try {
    f()
    "ok"
  } catch {
    Truncated => "truncated"
    BadBase64 => "base64"
    BadShape(_) => "shape"
  }
}

///|
/// A cursor over the first `keep` bytes: the shape a truncated blob arrives in.
fn clipped(blob : Bytes, keep : Int32) -> Cursor {
  { data: blob, pos: 0, limit: keep, }
}

///|
/// 1 layer, tileset 0, 4x1 cells.  Tiles `0 | 1 | -1 | 2`, one flag byte
/// 0b01_10_11_00 -- cell 0 is the most significant pair.
let fix_map : Bytes = b"\x01\x00\x00\x04\x00\x01\x00\x00\x00\x01\xff\xff\x00\x02\x6c"

///|
test "map unpacks tiles 0-based and flags MSB-first" {
  let map = map_decode(Cursor::new(fix_map))
  inspect(map.tilesets == [0], content="true")
  inspect(map.width, content="4")
  inspect(map.height, content="1")
  // `tileId - 1`, as the original documentation claimed, would give
  // [-1, 0, -2, 1] and paint one tile index too low everywhere.
  inspect(map.tiles[0] == [0, 1, -1, 2], content="true")
  inspect(map.flags[0] == [1, 2, 3, 0], content="true")
  // the layer doubles as the collision layer here: >= 0 blocks, -1 walks through
  inspect(map.cell_solid(0, 0), content="true")
  inspect(map.cell_solid(2, 0), content="false")
  inspect(map.cell_solid(-1, 0), content="true")
  inspect(map.cell_solid(4, 0), content="true")
}

///|
test "map rejects a zero layer count, trailing bytes and a short body" {
  inspect(
    outcome(() => {
      let _ = map_decode(Cursor::new(b"\x00"))
    }),
    content="shape",
  )
  inspect(
    outcome(() => {
      let _ = map_decode(Cursor::new(fix_map + b"\x00"))
    }),
    content="shape",
  )
  inspect(
    outcome(() => {
      let _ = map_decode(clipped(fix_map, fix_map.length() - 1))
    }),
    content="truncated",
  )
}

///|
/// 2 columns x 3 rows, types [i8, i32], column-major.
let fix_table : Bytes = b"\x00\x02\x00\x03\x00\x02\x01\xfe\x7f\x01\x02\x03\x04\xff\xff\xff\xff\x00\x00\x00\x00"

///|
test "table decodes column-major with per-column width" {
  let table = table_decode(Cursor::new(fix_table))
  inspect(table.kinds == [col_i8, col_i32], content="true")
  inspect(table.rows, content="3")
  inspect(table.columns.length(), content="2")
  inspect(table.columns[0] == [1, -2, 127], content="true")
  inspect(table.columns[1] == [16909060, -1, 0], content="true")
  inspect(table.cell(1, 0), content="-2")
  inspect(table.row(1) == [-2, -1], content="true")
}

///|
test "table rejects an unknown column type and a short body" {
  inspect(
    outcome(() => {
      let _ = table_decode(Cursor::new(b"\x00\x01\x00\x01\x07\x00"))
    }),
    content="shape",
  )
  inspect(
    outcome(() => {
      let _ = table_decode(clipped(fix_table, fix_table.length() - 2))
    }),
    content="truncated",
  )
}

///|
/// 2 strings, byte lengths 3 and 5.
let fix_strings : Bytes = b"\x00\x02\x00\x03\x00\x05abchello"

///|
test "string pool verifies payload bytes against the literal table" {
  strings_verify(Cursor::new(fix_strings), ["abc", "hello"])
  inspect(
    outcome(() => strings_verify(Cursor::new(fix_strings), ["abc", "hell!"])),
    content="shape",
  )
  inspect(
    outcome(() => strings_verify(Cursor::new(fix_strings), ["abc"])),
    content="shape",
  )
  inspect(
    outcome(() => {
      strings_verify(Cursor::new(fix_strings + b"\x00"), ["abc", "hello"])
    }),
    content="shape",
  )
}

///|
/// Two threads over a 3-opcode arity table `[2, 0, 1]`: thread 0 is bound to
/// sprite 1 and runs `op0 op1` (2 + 0 operands), thread 1 is the unbound sentinel
/// 0xFFFF and runs `op2` (1 operand).  The operand pool is flat, so the second
/// thread's operand is the third pool value.
let fix_scripts : Bytes = b"\x00\x02\x00\x01\xff\xff\x01\x04\x00\x01\x00\x02\x00\x01\x00\x00\x00\x01\x00\x02\x00\x03\x00\x0a\x00\x14\x00\x1e"

///|
test "script bundle slices operands as a prefix sum over arity" {
  let arity : Array[Int32] = [2, 0, 1]
  let set = script_decode(Cursor::new(fix_scripts), arity)
  inspect(set.threads.length(), content="2")
  let first = set.threads[0]
  inspect(first.binding, content="1")
  inspect(first.class, content="1")
  inspect(first.mark, content="0")
  inspect(first.insns.length(), content="2")
  inspect(first.insns[0].operands == [10, 20], content="true")
  inspect(first.insns[1].operands == [], content="true")
  // the binding column and the operand pool are both read as shorts
  inspect(set.threads[1].binding, content="-1")
  inspect(set.threads[1].class, content="4")
  inspect(set.threads[1].mark, content="1")
  inspect(set.threads[1].insns[0].operands == [30], content="true")
}

///|
test "script bundle rejects a short operand pool and a stray opcode" {
  let arity : Array[Int32] = [2, 0, 1]
  // one instruction of opcode 2 (arity 1) but an empty operand pool
  inspect(
    outcome(() => {
      let _ = script_decode(
        Cursor::new(b"\x00\x01\x00\x01\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00"),
        arity,
      )
    }),
    content="shape",
  )
  // opcode 9 is outside a 3-entry arity table
  inspect(
    outcome(() => {
      let _ = script_decode(Cursor::new(fix_scripts), [2, 0, 0])
    }),
    content="shape",
  )
  inspect(
    outcome(() => {
      let _ = script_decode(
        clipped(fix_scripts, fix_scripts.length() - 2),
        arity,
      )
    }),
    content="truncated",
  )
}

///|
/// One animation record: id 1, a single frame stored (y=0, x=0, 16x24), one
/// state holding one step, then the `0xff` terminator.
let fix_anim : Bytes = b"\x01\x00\x01\x00\x00\x00\x00\x00\x10\x00\x18\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x00\x08\x00\x00\xff"

///|
/// A record whose `T` and `V` tables disagree on purpose: one step in `S`, two
/// walk-timeline entries.  The extracted `anim.bin` is full of these (record 0
/// totals 1090 against 94), so reading it is the point of this fixture.
let fix_anim_independent : Bytes = b"\x01\x00\x01\x00\x00\x00\x00\x00\x10\x00\x18\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x02\x01\x01\x00\x00\x08\x08\x00\x00\x00\x00\xff"

///|
test "anim reads R as y-x-w-h and rebuilds the T/V prefixes" {
  let records = anim_decode(Cursor::new(fix_anim))
  inspect(records.length(), content="1")
  let record = records[0]
  inspect(record.id, content="1")
  inspect(record.frames, content="1")
  inspect(record.rects == [0, 0, 16, 24], content="true")
  // one step is four shorts, so T is scaled by 4 while V counts timeline entries
  inspect(record.t == [0, 4], content="true")
  inspect(record.v == [0, 1], content="true")
  inspect(record.steps == [0, 0, 0, 0], content="true")
  inspect(record.rect_of_step == [0], content="true")
  inspect(record.hold_of_step == [8], content="true")
  inspect(record.deltas == [0, 0], content="true")
}

///|
test "anim reads a record whose t and v totals differ" {
  let records = anim_decode(Cursor::new(fix_anim_independent))
  inspect(records.length(), content="1")
  let record = records[0]
  inspect(record.t == [0, 4], content="true")
  inspect(record.v == [0, 1, 2], content="true")
  inspect(record.steps.length(), content="4")
  // U/W are one byte per timeline entry and X two signed bytes
  inspect(record.rect_of_step == [0, 0], content="true")
  inspect(record.hold_of_step == [8, 8], content="true")
  inspect(record.deltas.length(), content="4")
}

///|
test "anim rejects a missing terminator and leftover bytes" {
  inspect(
    outcome(() => {
      let _ = anim_decode(clipped(fix_anim, fix_anim.length() - 1))
    }),
    content="shape",
  )
  inspect(
    outcome(() => {
      let _ = anim_decode(Cursor::new(fix_anim + b"\x00"))
    }),
    content="shape",
  )
}
