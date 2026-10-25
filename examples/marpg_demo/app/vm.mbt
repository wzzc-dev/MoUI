// The script VM.  Field names and control flow follow the original engine's
// arrays (`aU` pc, `aV` wait state, `aY`/`aZ`/`ba` wait payload, `bf`/`aX`/`aW`
// binding/class/mark, `bQ` variable pool) so the reproduction is auditable
// against `decompiled/d.java` rather than merely similar to it.
//
// Every case body below was re-read from the decompiled source on 2026-10-24;
// the line references are in the comments.

///|
/// Modal overlay kinds -- the engine's `a((byte)n)` mode switch (1 dialog, 2
/// battle, 5 scene, 6 menu, 14 game over) reduced to what the slice draws.  A
/// thread parked on `ws_dialog` releases when `Ui::active` clears, which is the
/// `ay != 3` test @ d.java:3075.
pub let ov_idle : Int32 = 0

///|
pub let ov_dialog : Int32 = 1

///|
pub let ov_choice : Int32 = 2

///|
pub let ov_message : Int32 = 3

///|
pub let ov_title : Int32 = 4

///|
pub let ov_battle : Int32 = 5

///|
pub let ov_game_over : Int32 = 6

///|
/// `d.db` -- the modal driver the view reads.  The field names are the engine's
/// globals (`dA` body, `dB` portrait, `dC`/`dD` layout, `dE` pose, `dz` prompt,
/// `dx` result var, `dH` options, `dI` count, `dU` title pose).
pub struct Ui {
  mut kind : Int32
  mut active : Bool
  mut body : Int32
  mut name : Int32
  mut portrait : Int32
  mut pose : Int32
  mut layout_a : Int32
  mut layout_b : Int32
  mut text_x : Int32
  mut text_y : Int32
  mut bold : Bool
  mut options : Array[Int32]
  mut option_count : Int32
  mut choice_var : Int32
  mut battle_group : Int32
  mut battle_flag_a : Int32
  mut battle_flag_b : Int32
}

///|
pub fn Ui::new() -> Ui {
  {
    kind: ov_idle,
    active: false,
    body: -1,
    name: -1,
    portrait: -1,
    pose: 0,
    layout_a: 0,
    layout_b: 0,
    text_x: 0,
    text_y: 0,
    bold: false,
    options: [-1, -1, -1, -1, -1],
    option_count: 0,
    choice_var: -1,
    battle_group: -1,
    battle_flag_a: 0,
    battle_flag_b: 0,
  }
}

///|
/// `a(int n, int n2, int n3)` @ d.java:3027 -- the three operand value kinds.
pub fn resolve_operand(
  rng : Rng,
  kind : Int32,
  arg : Int32,
  hi : Int32,
  vars : Array[Int32],
) -> Int32 {
  match kind {
    1 => {
      let index = if arg >= 0 && arg < vars.length() { arg } else { 0 }
      vars[index]
    }
    2 => rng.range(arg, hi)
    _ => arg
  }
}

///|
/// `a(int, int, int)` @ d.java:4724 -- comparator.  Returns 1 when the relation
/// holds, which is what op0 tests against (`if (n2 != 1) jump`).
pub fn compare_values(left : Int32, op : Int32, right : Int32) -> Int32 {
  let ok = match op {
    0 => left == right
    1 => left != right
    2 => left < right
    3 => left > right
    4 => left <= right
    _ => left >= right
  }
  if ok {
    1
  } else {
    0
  }
}

///|
/// `d.c(int, int)` @ d.java:4957: `abs(nextInt()) % (hi - lo) + lo`.  A linear
/// congruential generator replaces J2ME's `Random` so the slice's tests are
/// reproducible; the range arithmetic is the engine's.
pub struct Rng {
  mut state : Int32
} derive(Eq, @debug.Debug)

///|
pub fn Rng::seed(value : Int32) -> Rng {
  { state: value, }
}

///|
/// A 31-bit linear congruential step.  The original used `java.util.Random`'s
/// 48-bit LCG, whose multiply does not fit one MoonBit `Int`, so the slice keeps
/// the engine's *range* arithmetic (`abs(nextInt()) % (hi - lo) + lo`) and swaps
/// in a generator that stays in range and makes the tests reproducible.
fn Rng::next(self : Rng) -> Int32 {
  self.state = (self.state * 1103515245 + 12345) % 1073741824
  self.state
}

///|
pub fn Rng::range(self : Rng, lo : Int32, hi : Int32) -> Int32 {
  if hi <= lo {
    lo
  } else {
    let span = hi - lo
    self.next().mod(span) + lo
  }
}

///|
/// Per-thread machine state, the engine's `aU`/`aV`/`aY`/`aZ`/`ba`.
pub struct ThreadState {
  /// `aU`: instruction index within this thread.
  mut pc : Int32
  /// `aV`: wait state, `ws_*` in `ops.mbt`.
  mut state : Int32
  /// `aY`: sprite slot for `ws_sprite_field`, timer slot for `ws_timer`, key
  /// group for `ws_key`.  The engine reuses one array for three roles.
  mut wait_a : Int32
  /// `aZ`: field index for `ws_sprite_field`, timer slot for `ws_key`.
  mut wait_b : Int32
  /// `ba`: expected field value, or the key-wait timeout flag.
  mut wait_c : Int32
} derive(Eq, @debug.Debug)

///|
pub struct Vm {
  world : World
  threads : Array[ThreadState]
  ui : Ui
  /// `bU`: the unlock flags op65 writes (`flags[97 + db0]` on the original side;
  /// the slice indexes them from 0 because it has no other flag consumer).
  flags : Array[Bool]
  /// Inventory counts per `tbl_item` row, the pool op40 grants into.
  inventory : Array[Int32]
  /// Currency pools per slot: `l(db0, 11, db1)` @ d.java:8668 turns the amount
  /// into the value of pool 13, i.e. "set/add money slot db0".
  money : Array[Int32]
  party : Array[Fighter]
  /// The arena op21 opened, or `None` on the map.  `d.a((byte)2)` @ d.java:5878
  /// is the original's equivalent: the script threads stay frozen until it ends.
  mut battle : Battle?
  rng : Rng
  /// `dc`: the thread whose overlay owns the screen, or -1 while the map driver has
  /// it.  `n()` @ d.java:791-806 pumps the thread list only in screen mode 0, so a
  /// modal overlay freezes every other thread -- which is also why `db` can hold
  /// only one conversation at a time.  The one exception is the title driver @
  /// d.java:12286, which spins `n(bg)` for the boot thread while its card is up.
  mut modal_owner : Int32
  /// `dp`/`dq`: the sprite and hero that triggered an auto-talk or proximity thread.
  mut talk_slot : Int32
  /// `b(int)` @ d.java:1953 -- the just-pressed edge, indexed by key group.
  key_edges : Array[Bool]
  /// Instructions whose opcode the slice does not implement.  The engine prints
  /// "unhandle cmdType" and stops the chain; keeping the count lets a test turn
  /// that print into a failure.
  mut unknown_opcodes : Int32
  /// Frames run so far, for the tick-level assertions in the wbtests.
  mut frame : Int32
}

///|
pub fn Vm::new(cart : Cartridge) -> Vm {
  let states : Array[ThreadState] = []
  for thread in cart.scripts.threads {
    // `m(int n)` @ d.java:3021 is applied to every thread at load
    // (d.java:3229-3231); the class-4 boot thread is then moved to `ws_run` by
    // the loader (@ d.java:3204) and the scene it loads positions the hero.
    states.push({ pc: 0, state: ws_trigger, wait_a: -1, wait_b: -1, wait_c: 0, })
    let _ = thread
  }
  let flags : Array[Bool] = []
  for i = 0; i < 16; i = i + 1 {
    flags.push(false)
  }
  let inventory : Array[Int32] = []
  for i = 0; i < cart.item.rows; i = i + 1 {
    inventory.push(0)
  }
  let money : Array[Int32] = []
  for i = 0; i < 8; i = i + 1 {
    money.push(0)
  }
  let key_edges : Array[Bool] = []
  for i = 0; i < 8; i = i + 1 {
    key_edges.push(false)
  }
  let party : Array[Fighter] = []
  for row in [0, 1, 2] {
    party.push(Fighter::from_row(cart, row, side_party))
  }
  let vm = {
    world: World::new(cart),
    threads: states,
    ui: Ui::new(),
    flags,
    inventory,
    money,
    party,
    battle: None,
    rng: Rng::seed(20261024),
    modal_owner: -1,
    talk_slot: -1,
    key_edges,
    unknown_opcodes: 0,
    frame: 0,
  }
  let boot = vm.find_boot_thread()
  match boot {
    None => ()
    Some(index) => vm.threads[index].state = ws_run
  }
  vm
}

///|
pub fn Vm::cart(self : Vm) -> Cartridge {
  self.world.cart
}

///|
/// The class-4 thread the loader starts by hand (@ d.java:12286 on the original
/// side: `d.aV[d.bg] = 0; while (aV[bg] != 6)`).
fn Vm::find_boot_thread(self : Vm) -> Int32? {
  let mut found : Int32? = None
  for i = 0; i < self.cart().scripts.threads.length(); i = i + 1 {
    if self.cart().scripts.threads[i].class == thread_boot {
      found = Some(i)
      break
    }
  }
  found
}

///|
/// The variable pool `bQ`, read by the view and the save.
pub fn Vm::get_var(self : Vm, index : Int32) -> Int32 {
  self.world.get_var(index)
}

///|
pub fn Vm::set_var(self : Vm, index : Int32, value : Int32) -> Unit {
  self.world.set_var(index, value)
}

///|
pub fn Vm::pressed(self : Vm, group : Int32) -> Bool {
  group >= 0 && group < self.key_edges.length() && self.key_edges[group]
}

///|
/// The view forwards a key edge once; `clear_keys` ends the frame, so a held key
/// cannot re-trigger an auto-talk thread every frame.
pub fn Vm::press_key(self : Vm, group : Int32) -> Unit {
  if group >= 0 && group < self.key_edges.length() {
    self.key_edges[group] = true
  }
}

///|
pub fn Vm::clear_keys(self : Vm) -> Unit {
  for i = 0; i < self.key_edges.length(); i = i + 1 {
    self.key_edges[i] = false
  }
}

///|
/// `A(int n)` @ d.java:2935's counterpart for the join branch: the slice has no
/// follower chain, so `db1 == 0` places the joined sprite at the target cell and
/// leaves it there.  Content in this build only uses the `db1 != 0` branch.
fn Vm::face_hero(self : Vm, slot : Int32) -> Unit {
  match self.world.index_of(slot) {
    None => ()
    Some(i) => {
      let sprite = self.world.sprites[i]
      let hero = self.world.hero
      let dx = hero.x - sprite.x
      let dy = hero.y - sprite.y
      sprite.dir = if dy.abs() > dx.abs() {
        if dy < 0 {
          0
        } else {
          2
        }
      } else if dx < 0 {
        3
      } else {
        1
      }
    }
  }
}

///|
/// `k(int n)` @ d.java:2966: a thread that ran out (or hit op2) parks, and a
/// class-2 thread parks in the watch state so it can notice the hero leaving.
fn Vm::park(self : Vm, index : Int32) -> Unit {
  self.talk_slot = -1
  let thread = self.cart().scripts.threads[index]
  self.threads[index].state = if thread.class == thread_proximity {
    ws_watch
  } else {
    ws_parked
  }
}

///|
/// `m(int n)` @ d.java:3021.
fn Vm::rearm(self : Vm, index : Int32) -> Unit {
  self.threads[index].pc = 0
  self.threads[index].state = ws_trigger
  self.threads[index].wait_a = -1
  self.threads[index].wait_b = -1
  self.threads[index].wait_c = 0
}

///|
/// `l(int n)` @ d.java:2975 -- whether a parked/trigger thread may start.  The
/// sprite has to pass `World::triggerable` first, which is the slice's one addition
/// to the engine's test.
fn Vm::ready(self : Vm, index : Int32) -> Bool {
  let thread = self.cart().scripts.threads[index]
  let binding = thread.binding
  let class_ = thread.class
  if class_ == thread_plain {
    true
  } else if class_ == thread_auto_talk || class_ == thread_proximity {
    // `l(int n)` @ d.java:2975: proximity (class 2) only needs the contact rect,
    // auto-talk (class 1) additionally needs the sprite's `aG[1]` switch and the
    // confirm edge.  Either way the triggering sprite becomes `dp`/`dq`.
    let needs_key = class_ == thread_auto_talk
    match self.world.sprite(binding) {
      None => false
      Some(sprite) => {
        let geometry = if needs_key {
          sprite.auto_talk &&
          self.world.in_contact(sprite, true) &&
          self.pressed(key_confirm)
        } else {
          self.world.in_contact(sprite, false)
        }
        let result = self.world.triggerable(sprite) && geometry
        if result {
          self.talk_slot = binding
        }
        result
      }
    }
  } else {
    false
  }
}

///|
/// The field `f.aG[]` a sprite-field wait reads: 0 is the movement mode, 1 the
/// auto-talk switch.
fn Sprite::field(self : Sprite, index : Int32) -> Int32 {
  match index {
    1 => if self.auto_talk { 1 } else { 0 }
    _ => self.mode
  }
}

///|
/// `n(int n)` @ d.java:3045 -- one thread's wait-state dispatch.  The outer loop
/// is the engine's `while (bl)`: releasing a wait runs an opcode in the same
/// frame.
fn Vm::dispatch(self : Vm, index : Int32) -> Bool {
  let state = self.threads[index]
  let thread = self.cart().scripts.threads[index]
  if state.state == ws_trigger {
    if self.ready(index) {
      state.state = ws_run
      true
    } else {
      false
    }
  } else if state.state == ws_run {
    self.step_insn(index)
  } else if state.state == ws_timer {
    // A slot the pool refused (`r()` returning -1, d.java:3795) never expires,
    // which stalls that thread the same way the original's array bounds would.
    if self.world.timer_expired(state.wait_a) {
      state.state = ws_run
      self.world.release_timer(state.wait_a)
      true
    } else {
      false
    }
  } else if state.state == ws_dialog {
    if !self.ui.active {
      state.state = ws_run
      true
    } else {
      false
    }
  } else if state.state == ws_sprite_field {
    match self.world.sprite(state.wait_a) {
      None => {
        state.state = ws_run
        true
      }
      Some(sprite) =>
        if sprite.field(state.wait_b) == state.wait_c {
          state.state = ws_run
          true
        } else {
          false
        }
    }
  } else if state.state == ws_key {
    if self.pressed(state.wait_a) {
      state.state = ws_run
      self.world.set_var(v_key_flag, 1)
      self.world.release_timer(state.wait_b)
      true
    } else if state.wait_c == 1 && self.world.timer_expired(state.wait_b) {
      state.state = ws_run
      self.world.release_timer(state.wait_b)
      true
    } else {
      false
    }
  } else if state.state == ws_parked {
    // case 5|6 @ d.java:3093: a thread whose bundle mark is 1 is re-armed so the
    // NPC can be talked to again; one-shot encounters keep their mark at 0.
    if thread.mark == 1 {
      self.rearm(index)
    }
    false
  } else if state.state == ws_watch {
    // case 7: a touch-encounter thread stays armed until the hero leaves the
    // sprite's rect, at which point it drops back to the parked state.
    match self.world.sprite(thread.binding) {
      None => {
        state.state = ws_parked
        false
      }
      Some(sprite) => {
        // Losing contact parks it; so does the sprite dying or belonging to another
        // map, which is the same `triggerable` filter that arms it.
        if !self.world.triggerable(sprite) ||
          !self.world.in_contact(sprite, false) {
          state.state = ws_parked
        }
        false
      }
    }
  } else {
    false
  }
}

///|
/// `i(int n, int n2)` @ d.java:2100 -- forward scan for the matching marker,
/// counting `op0` up and `op1` down so a nested branch cannot be mistaken for
/// this thread's own `ELSE`/`ENDIF`.  Returns the instruction index, or the
/// thread length when the marker is missing.
fn Vm::scan_marker(self : Vm, index : Int32, marker : Opcode) -> Int32 {
  let thread = self.cart().scripts.threads[index]
  let insns = thread.insns
  let start = self.threads[index].pc + 1
  let mut depth = 0
  let mut found = insns.length()
  let mut i = start
  while i < insns.length() {
    let code = insns[i].opcode
    if code == marker.code() && depth == 0 {
      found = i
      break
    }
    if code == If.code() {
      depth = depth + 1
    }
    if code == Endif.code() {
      depth = depth - 1
    }
    i = i + 1
  }
  found
}

///|
/// `j(int n)` @ d.java:2122 -- run one instruction.  The return value is the
/// engine's `bl`: true keeps the frame chain going, false ends it.  The `pc`
/// increment in the tail is unconditional, which is what makes the
/// IF/ELSE/ENDIF "jump to marker" primitive work.
fn Vm::step_insn(self : Vm, index : Int32) -> Bool {
  let state = self.threads[index]
  let thread = self.cart().scripts.threads[index]
  if state.pc >= thread.insns.length() {
    self.park(index)
    return false
  }
  let insn = thread.insns[state.pc]
  let ops = insn.operands
  let mut keep = false
  match opcode_of_code(insn.opcode) {
    None => {
      self.unknown_opcodes = self.unknown_opcodes + 1
      keep = false
    }
    Some(op) => keep = self.run_opcode(index, op, ops)
  }
  state.pc = state.pc + 1
  if state.pc >= thread.insns.length() {
    self.park(index)
    keep = false
  }
  keep
}

///|
/// `H()` @ d.java:3041: every thread is dispatched once per frame, and the frame
/// also moves the world and ticks the script timers.
pub fn Vm::tick(self : Vm) -> Unit {
  self.world.step()
  self.world.tick_timers()
  let mut index = 0
  while index < self.threads.length() {
    // The flag is re-read per thread, so the frame a thread hands the screen to a
    // modal driver is where the pump stops: the overlay it just opened cannot be
    // overwritten by a later thread in the same frame.  The owner keeps being
    // driven -- the title driver's `n(bg)` spin -- so it can finish its chain the
    // frame the card is dismissed.
    if self.modal_owner < 0 || index == self.modal_owner {
      let mut again = true
      while again {
        again = self.dispatch(index)
      }
    }
    index = index + 1
  }
  self.clear_keys()
  self.frame = self.frame + 1
}

///|
/// An opcode is handing the screen to the modal driver.
fn Vm::show(self : Vm, index : Int32) -> Unit {
  self.ui.active = true
  self.modal_owner = index
}

///|
/// The view has dismissed the modal overlay (`ay` leaving 3), so the next pump is
/// the engine's mode-0 frame: every thread runs again and the owner's
/// `ws_dialog` wait releases.
pub fn Vm::close_overlay(self : Vm) -> Unit {
  self.ui.active = false
  self.ui.kind = ov_idle
  self.modal_owner = -1
}

///|
pub fn Vm::overlay(self : Vm) -> Ui {
  self.ui
}

///|
/// The pool op16 writes once the player has picked: `dx` is the target var and
/// the picked index becomes its value.
pub fn Vm::pick_option(self : Vm, option : Int32) -> Unit {
  if self.ui.choice_var >= 0 {
    self.world.set_var(self.ui.choice_var, option)
  }
  self.close_overlay()
}

///|
/// op21 leaves the arena through `k(3int)` @ d.java:5873; the result comes back
/// through the pool, which is what the content's
/// `IF bQ[V_BATTLE_RESULT] == 0` branch reads.
pub fn Vm::finish_battle(self : Vm, result : Int32) -> Unit {
  match self.battle {
    None => ()
    Some(arena) => {
      // The arena owns the end-of-battle pass; `report` is what lets a hand-back
      // that did not come from the last round's `check_end` count its loot once.
      arena.report(result)
      arena.settle()
      if result == battle_win {
        self.money[0] = self.money[0] + arena.gold
      }
      self.battle = None
    }
  }
  self.world.set_var(v_battle_result, result)
  self.close_overlay()
}

///|
fn Vm::grant_reward(self : Vm, slot : Int32, all : Bool) -> Unit {
  match self.world.sprite(slot) {
    None => ()
    Some(sprite) => {
      let thing = sprite.reward_thing
      let count = sprite.reward_count
      if thing >= 0 && count > 0 {
        if all {
          // `h(f)` @ d.java:5198 appends every pair in the sprite's list.
          self.add_thing(thing, count)
        } else {
          // `i(f)` @ d.java:5227 sums the counts, draws a weighted pair and
          // consumes it.  With one pair the sum equals that pair's count.
          self.add_thing(thing, count)
          sprite.reward_count = 0
        }
      }
    }
  }
}

///|
/// A `tbl_item` row grant.  Kind 0 is an inventory item, so the row index is the
/// inventory column; the slice's rewards are all items.
fn Vm::add_thing(self : Vm, thing : Int32, count : Int32) -> Unit {
  if thing >= 0 && thing < self.inventory.length() {
    self.inventory[thing] = self.inventory[thing] + count
  }
}

///|
pub fn Vm::item_count(self : Vm, row : Int32) -> Int32 {
  if row >= 0 && row < self.inventory.length() {
    self.inventory[row]
  } else {
    0
  }
}

///|
pub fn Vm::spend_item(self : Vm, row : Int32) -> Bool {
  if self.item_count(row) > 0 {
    self.inventory[row] = self.inventory[row] - 1
    true
  } else {
    false
  }
}

///|
pub fn Vm::money_at(self : Vm, slot : Int32) -> Int32 {
  if slot >= 0 && slot < self.money.length() {
    self.money[slot]
  } else {
    0
  }
}

///|
pub fn Vm::is_unlocked(self : Vm, flag : Int32) -> Bool {
  flag >= 0 && flag < self.flags.length() && self.flags[flag]
}

///|
pub fn Vm::party_stat(self : Vm, index : Int32, column : Int32) -> Int32 {
  if index >= 0 && index < self.party.length() {
    self.party[index].stat(column)
  } else {
    0
  }
}

///|
/// `d.t(int n)` @ d.java:2957 for the stat read: the hero slot addresses the
/// party leader's stat array, which is the only mapping slice content needs.
fn Vm::stat_of(self : Vm, slot : Int32, column : Int32) -> Int32 {
  if slot == hero_slot {
    self.party_stat(0, column)
  } else {
    0
  }
}

///|
/// `a(false)` @ d.java:4265: every member that is still standing comes back to
/// full hp/mp and loses its status flags.
fn Vm::restore_party(self : Vm) -> Unit {
  for fighter in self.party {
    fighter.restore()
  }
}

///|
/// op0/op3/op4/... bodies, one match arm per verified case.
fn Vm::run_opcode(
  self : Vm,
  index : Int32,
  op : Opcode,
  ops : Array[Int32],
) -> Bool {
  let state = self.threads[index]
  match op {
    If => {
      // a(7int) @ d.java:2136: compare, and when it fails jump to whichever
      // ELSE or ENDIF comes first (the tail `pc++` then steps over it).
      let left = resolve_operand(
        self.rng,
        ops[0],
        ops[1],
        ops[2],
        self.world.vars,
      )
      let right = resolve_operand(
        self.rng,
        ops[4],
        ops[5],
        ops[6],
        self.world.vars,
      )
      if compare_values(left, ops[3], right) != 1 {
        let to_else = self.scan_marker(index, Else)
        let to_endif = self.scan_marker(index, Endif)
        state.pc = if to_else < to_endif { to_else } else { to_endif }
      }
      true
    }
    Else => {
      // case 15 @ d.java:2305: jump to the matching ENDIF.
      state.pc = self.scan_marker(index, Endif)
      false
    }
    Endif => true
    Kill => {
      self.park(index)
      false
    }
    Var => {
      // b(5int) @ d.java:3258: vars[db0] = db1(resolve(db2, db3, db4)).
      let value = resolve_operand(
        self.rng,
        ops[2],
        ops[3],
        ops[4],
        self.world.vars,
      )
      self.apply_var(ops[0], ops[1], value)
      true
    }
    Scene => {
      // case 4 @ d.java:2160: `aH = {db0, db3, db1, db2}` then `k(n)` parks the
      // requesting thread; the scene load positions the hero and the curtain is
      // the view's business.
      self.world.place_hero(ops[0], ops[1], ops[2])
      match self.world.index_of(hero_slot) {
        None => ()
        Some(i) => self.world.sprites[i].dir = ops[3]
      }
      self.park(index)
      false
    }
    Show => {
      // case 6 @ d.java:2193: `f.aG[1] = db1` -- the auto-talk switch.
      self.world.set_auto_talk(ops[0], ops[1] != 0)
      true
    }
    Dialog => {
      // b(6int) @ d.java:2200: body db3, name db5, portrait db0, layout db1/db2,
      // pose db4.  `dp.a(dq.aw, dq.ax, 0)` turns the talking sprite to face the
      // hero before the box opens.
      if self.talk_slot >= 0 {
        self.face_hero(self.talk_slot)
      }
      self.ui.kind = ov_dialog
      self.ui.portrait = ops[0]
      self.ui.layout_a = ops[1]
      self.ui.layout_b = ops[2]
      self.ui.body = ops[3]
      self.ui.pose = ops[4]
      self.ui.name = ops[5]
      self.show(index)
      state.state = ws_dialog
      false
    }
    WaitSprite => {
      // case 9 @ d.java:2221: `f(n, db0, 0, 0)` -- wait for that sprite's
      // movement mode to return to 0.
      state.wait_a = ops[0]
      state.wait_b = 0
      state.wait_c = 0
      state.state = ws_sprite_field
      false
    }
    Anim => {
      // case 12 @ d.java:2250: db3 >= 0 selects the state group (group * 4 +
      // current facing), otherwise db1 is the raw state; db2 == 1 means playing.
      if ops[3] >= 0 {
        self.world.set_pose(ops[0], ops[3], ops[2] == 1)
      } else {
        self.world.set_raw_pose(ops[0], ops[1], ops[2] == 1)
      }
      true
    }
    Walk => {
      // case 13 @ d.java:2262: `f.aG[0] = 2`, a slide of db2 pixels along db1
      // spread over db3 ticks.
      self.world.begin_slide(ops[0], ops[1], ops[2], ops[3])
      false
    }
    TimerWait => {
      // case 14 @ d.java:2299: reserve a countdown slot and park on it.
      state.wait_a = self.world.reserve_timer(ops[0])
      state.state = ws_timer
      false
    }
    Choice => {
      // case 16 @ d.java:2312: `dx = db0` result var, prompt db1, `dI = db2`
      // options drawn from `dH[0..4]` = db3..db7.
      self.ui.kind = ov_choice
      self.ui.choice_var = ops[0]
      self.ui.body = ops[1]
      self.ui.option_count = ops[2]
      self.ui.options = [ops[3], ops[4], ops[5], ops[6], ops[7]]
      self.show(index)
      state.state = ws_dialog
      false
    }
    Battle => {
      // case 21 @ d.java:2379: `k(3int)` @ 5873 writes eD = {db1, db2, group, 1}
      // and switches to mode 2.
      self.ui.kind = ov_battle
      self.ui.battle_group = ops[0]
      self.ui.battle_flag_a = ops[1]
      self.ui.battle_flag_b = ops[2]
      self.show(index)
      self.battle = Some(
        Battle::begin(self.cart(), self.rng, ops[0], self.party),
      )
      state.state = ws_dialog
      false
    }
    GameOver => {
      // case 23 @ d.java:2389: mode 14.
      self.ui.kind = ov_game_over
      self.show(index)
      state.state = ws_dialog
      false
    }
    Title => {
      // case 24 @ d.java:2395: `dA = fW + db0`, `dU = db1`, mode 1 -- the title
      // card, which parks until a confirm edge closes it.
      self.ui.kind = ov_title
      self.ui.body = ops[0]
      self.ui.pose = ops[1]
      self.show(index)
      state.state = ws_dialog
      false
    }
    StatToVar => {
      // case 38 @ d.java:2609: `bQ[db2] = t(db0).aH[db1]`.
      self.world.set_var(ops[2], self.stat_of(ops[0], ops[1]))
      true
    }
    Give => {
      // case 40 @ d.java:2623: db1 == 0 grants the whole reward list, else draw
      // one weighted pair.
      self.grant_reward(ops[0], ops[1] == 0)
      false
    }
    Restore => {
      self.restore_party()
      true
    }
    Unlock => {
      // case 65 @ d.java:2858: `bU[97 + db0] = (db1 == 1)`.
      if ops[0] >= 0 && ops[0] < self.flags.length() {
        self.flags[ops[0]] = ops[1] == 1
      }
      true
    }
    Message => {
      // case 66 @ d.java:2865: text db0, bold db1, sound db2, position db3/db4.
      self.ui.kind = ov_message
      self.ui.body = ops[0]
      self.ui.bold = ops[1] == 1
      self.ui.text_x = ops[3]
      self.ui.text_y = ops[4]
      self.show(index)
      state.state = ws_dialog
      false
    }
    Money => {
      // case 68 @ d.java:2892: `l(db0 & 0xFFFF, 11, db1)`; kind 11 @ 8668 routes
      // the amount into the currency pool, so the slot keeps its running total.
      let slot = ops[0] % self.money.length()
      self.money[slot] = self.money[slot] + ops[1]
      true
    }
    KeyWait => {
      // case 71 @ d.java:2895: park on the just-pressed edge of key group db0;
      // db1 != 0 also reserves a countdown slot so the wait can time out, and
      // `bQ[24]` is cleared on entry and set on release.
      state.wait_a = ops[0]
      if ops[1] != 0 {
        state.wait_b = self.world.reserve_timer(ops[1])
        state.wait_c = 1
      } else {
        state.wait_b = -1
        state.wait_c = 0
      }
      self.world.set_var(v_key_flag, 0)
      state.state = ws_key
      false
    }
    Join => {
      // case 72 @ d.java:2935: db1 == 0 joins sprite db2 to sprite db0, else
      // `A(db2)` removes it.
      if ops[1] == 0 {
        self.world.place_sprite(ops[0], ops[2])
      } else {
        self.world.remove_sprite(ops[2])
      }
      true
    }
  }
}

///|
/// `b(5int)` @ d.java:3260's operator switch (6 set, 7 add, 8 sub, 9 mul,
/// 10 div, 11 mod).  Division by zero leaves the target alone rather than
/// throwing, which is the only place the slice has to deviate from Java.
fn Vm::apply_var(self : Vm, dst : Int32, op : Int32, value : Int32) -> Unit {
  let old = self.world.get_var(dst)
  let next = match op {
    6 => value
    7 => old + value
    8 => old - value
    9 => old * value
    10 => if value == 0 { old } else { old.div(value) }
    11 => if value == 0 { old } else { old.mod(value) }
    _ => old
  }
  self.world.set_var(dst, next)
}
