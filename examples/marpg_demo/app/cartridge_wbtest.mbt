// Decoding the real generated cartridge: the payloads are self-authored, the
// containers are the reversed ones, so these are the checks that the app-side
// readers agree with the byte-verified format, not merely with themselves.

///|
test "cartridge entry table agrees with the packed indexes" {
  inspect(cartridge_entries.length(), content="12")
  let want : Array[String] = [
    "MAP_VILLAGE", "MAP_WILDPATH", "MAP_CAVE", "TBL_COMBATANT", "TBL_SKILL", "TBL_ITEM",
    "TBL_GROUP", "TBL_PLACE", "TBL_WARP", "STRINGS", "SCRIPTS", "ANIM",
  ]
  for index = 0; index < want.length(); index = index + 1 {
    inspect(cartridge_entries[index], content=want[index])
  }
  inspect(Entry::Anim.index(), content="11")
}

///|
test "malformed base64 is reported as a format error" {
  inspect(
    outcome(() => {
      let _ = decode_base64("not base64 !!")
    }),
    content="base64",
  )
}

///|
test "maps decode as four layers with an undrawn collision layer" {
  let cart = load_cartridge()
  inspect(cart.maps.length(), content="3")
  for map in cart.maps {
    // ground, ground, object, collision -- 0xff means "this layer is never drawn"
    inspect(map.tilesets == [0, 0, 1, 0xff], content="true")
    let cells = map.width * map.height
    inspect(map.tiles.length(), content="4")
    inspect(map.flags.length(), content="4")
    for layer in map.tiles {
      inspect(layer.length(), content=cells.to_string())
    }
    for layer in map.flags {
      inspect(layer.length(), content=cells.to_string())
      for flag in layer {
        // the 2-bit value is a drawRegion transform code, so 0..3 and nothing else
        inspect(flag >= 0 && flag <= 3, content="true")
      }
    }
    let collision = map.tiles[3]
    let shapes : Array[Bool] = [false, false]
    for tile in collision {
      inspect(tile == -1 || tile == 0, content="true")
      if tile == -1 {
        shapes[0] = true
      } else {
        shapes[1] = true
      }
    }
    // a map that is all wall or all floor would hide a packing mistake
    inspect(shapes[0] && shapes[1], content="true")
    inspect(map.cell_solid(-1, -1), content="true")
    inspect(map.cell_solid(map.width, 0), content="true")
  }
}

///|
test "tile ids index the atlas directly and -1 is the only empty marker" {
  let cart = load_cartridge()
  // 0-based indexing came from the extracted maps, whose drawn layers reach
  // exactly `atlas_capacity - 1`; `notes/formats.md` records that.  Here the
  // authored banks are 6x4, so the reader must keep ids inside 0..23 and treat
  // -1, not 0, as "nothing here".
  let mut seen_first = false
  let mut seen_empty = false
  for map in cart.maps {
    for layer_index = 0; layer_index < 3; layer_index = layer_index + 1 {
      for tile in map.tiles[layer_index] {
        if tile == -1 {
          seen_empty = true
        } else {
          inspect(tile >= 0 && tile < 24, content="true")
          if tile == 0 {
            seen_first = true
          }
        }
      }
    }
  }
  inspect(seen_first && seen_empty, content="true")
}

///|
test "tables decode with matching column counts and typed widths" {
  let cart = load_cartridge()
  let tables : Array[NumTable] = [
    cart.combatant,
    cart.skill,
    cart.item,
    cart.group,
    cart.place,
    cart.warp,
  ]
  for table in tables {
    inspect(table.rows > 0, content="true")
    inspect(table.columns.length() == table.kinds.length(), content="true")
    for column in table.columns {
      inspect(column.length(), content=table.rows.to_string())
    }
    for kind in table.kinds {
      inspect(
        kind == col_i8 || kind == col_i16 || kind == col_i32,
        content="true",
      )
    }
  }
  inspect(cart.combatant.rows, content="7")
  // place is authored as 8 sprite-layout columns + label + reward thing + count
  inspect(cart.place.columns.length(), content="11")
  inspect(cart.warp.columns.length(), content="6")
}

///|
fn code_seen(codes : Array[Int32], code : Int32) -> Bool {
  let mut seen = false
  for existing in codes {
    if existing == code {
      seen = true
    }
  }
  seen
}

///|
test "script bundle covers the verified opcodes and stays inside the pool" {
  let cart = load_cartridge()
  inspect(cart.scripts.threads.length(), content="10")
  let used : Array[Int32] = []
  let mut unknown = 0
  let mut branches = 0
  for thread in cart.scripts.threads {
    for insn in thread.insns {
      // the arity table is the only thing that may slice the operand pool
      inspect(
        insn.operands.length(),
        content=opcode_arity[insn.opcode].to_string(),
      )
      if !code_seen(used, insn.opcode) {
        used.push(insn.opcode)
      }
      match opcode_of_code(insn.opcode) {
        None => unknown = unknown + 1
        Some(op) => {
          // IF/ELSE/ENDIF is what makes a script more than a straight line
          if op == If || op == Else || op == Endif {
            branches = branches + 1
          }
          // CHOICE fills all five option operands but only draws `db[2]` of
          // them (d.java:2312-2318 into the loop bound at d.java:4360), so the
          // padding slots are unconstrained
          let options = if op == Choice { insn.operands[2] } else { 0 }
          for slot in opcode_string_slots(op) {
            let addressed = if op != Choice {
              true
            } else if slot < 3 {
              true
            } else {
              slot - 3 < options
            }
            if addressed {
              // scripts address the pool by index; no inline text anywhere
              let index = insn.operands[slot]
              inspect(
                index >= 0 && index < string_pool.length(),
                content="true",
              )
            }
          }
        }
      }
    }
  }
  inspect(unknown, content="0")
  // the goal's floor is 12 reviewed opcodes including the branch triple
  inspect(used.length() >= 12, content="true")
  inspect(branches >= 3, content="true")
  inspect(string_pool.length(), content="62")
}

///|
test "every app-side opcode constant agrees with the generated arity table" {
  let ops : Array[Opcode] = [
    If,
    Endif,
    Kill,
    Var,
    Scene,
    Show,
    Dialog,
    WaitSprite,
    Anim,
    Walk,
    TimerWait,
    Else,
    Choice,
    Battle,
    GameOver,
    Title,
    StatToVar,
    Give,
    Restore,
    Unlock,
    Message,
    Money,
    KeyWait,
    Join,
  ]
  for op in ops {
    let code = op.code()
    inspect(opcode_arity.length() > code, content="true")
    // a code the engine gives a different operand count to is a decode-time
    // desync, so re-derive it from the table the content ships with
    match opcode_of_code(code) {
      Some(back) => inspect(back == op, content="true")
      None => inspect("missing mapping", content="none")
    }
  }
  inspect(Opcode::Else.code(), content="15")
  inspect(Opcode::KeyWait.code(), content="71")
  inspect(Opcode::Join.code(), content="72")
  inspect(opcode_of_code(5) is None, content="true")
}

///|
test "anim records lay their frames out on the authored sheet" {
  let cart = load_cartridge()
  inspect(cart.anims.length(), content="3")
  let hero = cart.anim(1)
  match hero {
    Some(record) => {
      inspect(record.frames, content="12")
      // 4 directions x 3 frames, each 16x24 on a 48x96 sheet, stored y-x-w-h
      inspect(record.rects.length(), content="48")
      for index = 0; index < 12; index = index + 1 {
        let y = record.rects[index * 4]
        let x = record.rects[index * 4 + 1]
        let w = record.rects[index * 4 + 2]
        let h = record.rects[index * 4 + 3]
        inspect(w, content="16")
        inspect(h, content="24")
        inspect(y % 24, content="0")
        inspect(x % 16, content="0")
        inspect(y < 96 && x < 48, content="true")
      }
      // `T` is grouped per frame (12 + 1 prefixes), `V` per walk state (8 + 1),
      // so the two tables legitimately hold different counts here
      inspect(record.t.length(), content="13")
      inspect(record.v.length(), content="9")
      inspect(record.steps.length(), content="64")
      inspect(record.t[12], content="64")
      inspect(record.v[8], content="16")
      inspect(record.rect_of_step.length(), content="16")
      inspect(record.deltas.length(), content="32")
      for step in record.rect_of_step {
        inspect(step < record.frames, content="true")
      }
    }
    None => inspect("no hero anim", content="none")
  }
  let monster = cart.anim(3)
  match monster {
    Some(record) => {
      inspect(record.frames, content="2")
      // the two monster frames sit side by side, so x advances and y does not
      inspect(record.rects[4], content="0")
      inspect(record.rects[5], content="32")
      inspect(record.v.length(), content="5")
    }
    None => inspect("no monster anim", content="none")
  }
  inspect(cart.anim(99) is None, content="true")
}
