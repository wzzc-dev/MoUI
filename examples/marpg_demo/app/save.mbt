// Persistence.  The original stored its progress in a J2ME `RecordStore` of packed
// bytes; the slice goes through `AppServices` settings instead, which is the
// platform-independent key/value face an app is allowed to touch.  What is stored
// is the world's own state -- the variable pool, the unlock flags, the inventory,
// the currency pools, the party rows and the placement table -- because those are
// exactly the arrays the engine's `bQ`/`bU`/`cE` state lives in.

///|
/// The settings key.  A version prefix inside the value, not in the key, so an old
/// snapshot is recognised and refused rather than silently half-applied.
pub let save_key : String = "marpg_demo.snapshot"

///|
pub let save_version : Int32 = 1

///|
/// Fields per party member: the mutable half of `Fighter`.  `row` and `side` come
/// from the cartridge, so a snapshot never carries them.
let fighter_fields : Int32 = 11

///|
/// Fields per sprite: `map, x, y, dir, live, reward_count, auto_talk`.  The step
/// plan (`mode`/`remaining`/`speed`) and the animation clock are deliberately not
/// stored -- a restore always lands on a standing sprite.
let sprite_fields : Int32 = 7

///|
fn put_fighter(out : Array[Int32], fighter : Fighter) -> Unit {
  for
    value in [
      fighter.hp,
      fighter.hp_max,
      fighter.mp,
      fighter.mp_max,
      fighter.level,
      fighter.exp,
      fighter.exp_next,
      fighter.atk,
      fighter.def,
      fighter.spd,
      fighter.agl,
    ] {
    out.push(value)
  }
}

///|
fn take_fighter(values : Array[Int32], base : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  for i = 0; i < fighter_fields; i = i + 1 {
    out.push(values[base + i])
  }
  out
}

///|
fn put_sprite(out : Array[Int32], sprite : Sprite) -> Unit {
  for
    value in [
      sprite.map,
      sprite.x,
      sprite.y,
      sprite.dir,
      if sprite.live {
        1
      } else {
        0
      },
      sprite.reward_count,
      if sprite.auto_talk {
        1
      } else {
        0
      },
    ] {
    out.push(value)
  }
}

///|
/// The flat integer layout: `version, map, vars, flags, inventory, money, party,
/// sprites`.  Counts come from the arrays themselves, so the shape follows the
/// cartridge; `snapshot_length` is what a restore compares against.
fn collect(vm : Vm) -> Array[Int32] {
  let out : Array[Int32] = [save_version, vm.world.map]
  for value in vm.world.vars {
    out.push(value)
  }
  for flag in vm.flags {
    out.push(if flag { 1 } else { 0 })
  }
  for count in vm.inventory {
    out.push(count)
  }
  for pool in vm.money {
    out.push(pool)
  }
  for fighter in vm.party {
    put_fighter(out, fighter)
  }
  for sprite in vm.world.sprites {
    put_sprite(out, sprite)
  }
  out
}

///|
fn join_ints(values : Array[Int32]) -> String {
  let mut out = ""
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      out = out + ","
    }
    out = out + values[i].to_string()
  }
  out
}

///|
/// There is no decimal parser on `String` in the toolchain this app builds
/// against, so the field reader is written out: digits, one leading minus, comma
/// separators, and `None` for anything else.  A refused parse means no field is
/// touched.
fn split_ints(text : String) -> Array[Int32]? {
  let out : Array[Int32] = []
  let mut value = 0
  let mut sign = 1
  let mut seen = false
  for ch in text {
    if ch == ',' {
      if !seen {
        return None
      }
      out.push(value * sign)
      value = 0
      sign = 1
      seen = false
    } else if ch == '-' {
      if seen {
        return None
      }
      sign = -1
    } else if ch >= '0' && ch <= '9' {
      value = value * 10 + (ch.to_int() - 48)
      seen = true
    } else {
      return None
    }
  }
  if seen {
    out.push(value * sign)
  }
  if out.length() == 0 {
    None
  } else {
    Some(out)
  }
}

///|
/// The snapshot text for the running game.  Called from the update path, so the
/// whole state is one flat string on the way out to the settings service.
pub fn snapshot_text(vm : Vm) -> String {
  join_ints(collect(vm))
}

///|
/// Apply a snapshot to a virtual machine built from the same cartridge.  `false`
/// means nothing was changed: the text is not a number list, its length does not
/// match this cartridge's arrays, or it carries another version.
pub fn restore_snapshot(vm : Vm, text : String) -> Bool {
  match split_ints(text) {
    None => false
    Some(values) => {
      let shape = collect(vm)
      if values.length() != shape.length() || values[0] != save_version {
        false
      } else {
        apply_snapshot(vm, values)
        true
      }
    }
  }
}

///|
/// The one place a snapshot is allowed to write.  Reading order must match
/// `collect` exactly; `snapshot_round_trip` in the wbtests is what holds them
/// together, because a swapped pair here is otherwise invisible.
fn apply_snapshot(vm : Vm, values : Array[Int32]) -> Unit {
  let mut at = 1
  vm.world.map = values[at]
  at = at + 1
  for i = 0; i < vm.world.vars.length(); i = i + 1 {
    vm.world.vars[i] = values[at + i]
  }
  at = at + vm.world.vars.length()
  for i = 0; i < vm.flags.length(); i = i + 1 {
    vm.flags[i] = values[at + i] == 1
  }
  at = at + vm.flags.length()
  for i = 0; i < vm.inventory.length(); i = i + 1 {
    vm.inventory[i] = values[at + i]
  }
  at = at + vm.inventory.length()
  for i = 0; i < vm.money.length(); i = i + 1 {
    vm.money[i] = values[at + i]
  }
  at = at + vm.money.length()
  for fighter in vm.party {
    let fields = take_fighter(values, at)
    fighter.hp = fields[0]
    fighter.hp_max = fields[1]
    fighter.mp = fields[2]
    fighter.mp_max = fields[3]
    fighter.level = fields[4]
    fighter.exp = fields[5]
    fighter.exp_next = fields[6]
    fighter.atk = fields[7]
    fighter.def = fields[8]
    fighter.spd = fields[9]
    fighter.agl = fields[10]
    at = at + fighter_fields
  }
  for sprite in vm.world.sprites {
    let base = at
    sprite.map = values[base]
    sprite.x = values[base + 1]
    sprite.y = values[base + 2]
    sprite.dir = values[base + 3]
    sprite.live = values[base + 4] == 1
    sprite.reward_count = values[base + 5]
    sprite.auto_talk = values[base + 6] == 1
    sprite.mode = 0
    sprite.remaining = 0
    sprite.speed = step_px
    sprite.tick = 0
    sprite.anim_group = 0
    sprite.raw_state = -1
    at = at + sprite_fields
  }
}

///|
/// Every script thread goes back to the engine's load-time state after a restore:
/// `m(int n)` @ d.java:3021 parks every thread, and the parked branch @
/// d.java:3093 re-arms only the bundles whose mark is 1.  That is what makes a
/// re-armable NPC talkable again while a one-shot encounter stays spent -- the
/// script's own `IF bQ[...]` branch then decides which line it says, which is why
/// the elder greets a loaded game differently from a first meeting.
pub fn park_threads(vm : Vm) -> Unit {
  for thread in vm.threads {
    thread.pc = 0
    thread.state = ws_parked
    thread.wait_a = -1
    thread.wait_b = -1
    thread.wait_c = 0
  }
  vm.modal_owner = -1
  vm.talk_slot = -1
  vm.battle = None
  vm.ui.kind = ov_idle
  vm.ui.active = false
  vm.clear_keys()
}
