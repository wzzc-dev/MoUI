// The map/sprite side of the engine: tile-grid movement, camera clamping,
// script timers and the walk-animation reader.  Every shape here mirrors the
// original (`decompiled/f.java` for sprites, `d.java` for the timer array) but
// the numbers, tiles and sheets come from `tools/marpg/gen_content.py`.

///|
/// J2ME canvas the original was written for; the slice keeps it so the camera
/// clamp formulas stay the engine's (`map_w * 16 - 240`).
pub let tile_size : Int32 = 16

///|
pub let view_w : Int32 = 240

///|
pub let view_h : Int32 = 320

///|
/// Pixels a walking sprite advances per tick.  The engine moves a sprite a fixed
/// number of pixels per frame (`f.java`'s step plan), not per second, which is why
/// the main loop runs a fixed tick instead of a free-running frame rate.
pub let step_px : Int32 = 6

///|
/// The engine's direction numbering (0 up, 1 right, 2 down, 3 left -- `f.java`
/// reads a state as `anim * 4 + dir`) and the contact padding `l(int n)` @
/// d.java:2975 adds to an NPC rect before testing overlap with the hero.
pub let engine_dirs : Int32 = 4

///|
pub let contact_pad : Int32 = 6

///|
/// Sprite slot of the player character.  Placements own slots 0..7; the engine
/// keeps the hero outside the placement table (`d.av`) so a script can still bind
/// to it by number.
pub let hero_slot : Int32 = 31

///|
/// `bQ` -- the script variable pool.  Indexes are the content's own
/// (`gen_content.py`'s `V_*`); `v_key_flag` is the slot the engine writes when a
/// key wait releases (`d.bQ[24] = 1` @ d.java:3093).
pub let v_scene : Int32 = 0

///|
pub let v_elder_met : Int32 = 1

///|
pub let v_choice : Int32 = 2

///|
pub let v_key_taken : Int32 = 3

///|
pub let v_chest_open : Int32 = 4

///|
pub let v_battle_result : Int32 = 5

///|
pub let v_money : Int32 = 6

///|
pub let v_hp : Int32 = 8

///|
pub let v_wolf_down : Int32 = 12

///|
pub let v_wisp_down : Int32 = 13

///|
pub let v_chief_down : Int32 = 14

///|
pub let v_key_flag : Int32 = 24

///|
pub let var_pool_size : Int32 = 32

///|
/// `aI`/`aJ`/`aK` -- the countdown arrays.  `r(int n)` @ d.java:3795 only hands
/// out slots 12..15 to scripts, so the slice keeps those four and indexes them
/// locally.
pub let timer_slots : Int32 = 4

///|
/// Placement kinds (`tbl_place` column 2).
pub let kind_npc : Int32 = 0

///|
pub let kind_monster : Int32 = 1

///|
pub let kind_event : Int32 = 2

///|
pub fn sheet_source(sheet : Int32) -> String {
  match sheet {
    0 => SHEET_HERO_URI
    1 => SHEET_NPC_URI
    _ => SHEET_MONSTER_URI
  }
}

///|
/// A sprite on the grid.  `x`/`y` are pixels (the engine's `aw`/`ax`); the tile
/// coordinates are derived on read, so a step never has to keep two positions in
/// sync.
pub struct Sprite {
  slot : Int32
  mut map : Int32
  kind : Int32
  sheet : Int32
  anim : Int32
  mut x : Int32
  mut y : Int32
  mut dir : Int32
  /// `f.aG[0]`: 0 while standing, 1 while a step plan is running.  op9 waits for
  /// it to return to 0, so it has to be observable rather than implied.
  mut mode : Int32
  /// `f.aG[1]`: the auto-talk switch op6 writes and `l(int n)` reads.
  mut auto_talk : Bool
  mut live : Bool
  label : Int32
  reward_thing : Int32
  mut reward_count : Int32
  /// pixels still to travel in the current slide (op13 WALK's `db2`)
  mut remaining : Int32
  /// pixels travelled per tick while `mode != 0`.  A hero step uses `step_px`; a
  /// scripted slide uses `db2 / db3`, the interval op13 derives from its distance
  /// and tick count.
  mut speed : Int32
  /// animation clock in ticks, feeding the `V`/`U`/`W` timeline
  mut tick : Int32
  /// op12 ANIM's `db3`: which half of the record's state table to read (0 stand,
  /// 1 walk).  A pose outlives the opcode that set it, so the sprite stores it.
  /// `raw_state` below takes precedence when op12 was given `db3 < 0`.
  mut anim_group : Int32
  mut raw_state : Int32
} derive(Eq, @debug.Debug)

///|
pub fn Sprite::col(self : Sprite) -> Int32 {
  self.x.div(tile_size)
}

///|
pub fn Sprite::row(self : Sprite) -> Int32 {
  self.y.div(tile_size)
}

///|
/// `f.ap` for a character is a 16x24 body rect whose top-left sits on the
/// position; monsters are drawn from a 32x32 cell.
pub fn Sprite::body(self : Sprite) -> (Int32, Int32) {
  if self.sheet == 2 {
    (32, 32)
  } else {
    (tile_size, 24)
  }
}

///|
pub struct Timer {
  mut reserved : Bool
  mut value : Int32
  mut counting : Bool
} derive(Eq, @debug.Debug)

///|
pub fn Timer::seed(self : Timer, frames : Int32) -> Unit {
  self.reserved = true
  self.value = frames
  self.counting = frames > 0
}

///|
pub struct World {
  cart : Cartridge
  mut map : Int32
  hero : Sprite
  sprites : Array[Sprite]
  vars : Array[Int32]
  timers : Array[Timer]
}

///|
pub fn World::map_of(self : World) -> GameMap {
  self.cart.maps[self.map]
}

///|
/// The hero is a sprite too; keeping it in one list means every opcode that
/// addresses a slot (`t(int n)` @ d.java:2957) resolves the same way, including
/// slot 31.
pub fn World::index_of(self : World, slot : Int32) -> Int32? {
  let mut found : Int32? = None
  for i = 0; i < self.sprites.length(); i = i + 1 {
    if self.sprites[i].slot == slot {
      found = Some(i)
      break
    }
  }
  found
}

///|
pub fn World::sprite(self : World, slot : Int32) -> Sprite? {
  match self.index_of(slot) {
    None => None
    Some(i) => Some(self.sprites[i])
  }
}

///|
/// Live sprites standing on the current map, in slot order -- the draw list.
pub fn World::present(self : World) -> Array[Sprite] {
  let out : Array[Sprite] = []
  for s in self.sprites {
    if s.map == self.map && s.live {
      out.push(s)
    }
  }
  out
}

///|
/// Whether a thread may bind to this sprite as its trigger this frame.
/// `bb()` @ d.java:12399 builds one flat sprite table for every map at once
/// (`bS = new f[bR]`, each `f` carrying its own map id), and `l(int n)` @ 2975
/// overlaps the hero with `f2.aw`/`f2.ax` without asking which map those pixels
/// belong to -- the original only avoids cross-map triggers because its content
/// never places two maps' spawns at the same coordinates.  This slice's placements
/// do coincide (the chief at 144,192 covers the village hero at 176,208), so the
/// current map and `live` are required here: the one place the slice is stricter
/// than the engine, and `World::present()` is its drawing-side counterpart.
pub fn World::triggerable(self : World, s : Sprite) -> Bool {
  s.live && s.map == self.map
}

///|
/// `bQ` reads and writes.  `var` is a reserved word, so the getter is named.
pub fn World::get_var(self : World, index : Int32) -> Int32 {
  if index >= 0 && index < self.vars.length() {
    self.vars[index]
  } else {
    0
  }
}

///|
pub fn World::set_var(self : World, index : Int32, value : Int32) -> Unit {
  if index >= 0 && index < self.vars.length() {
    self.vars[index] = value
  }
}

///|
/// `r(int n)` @ d.java:3795 -- reserve a free slot, seed value and direction,
/// return the slot or -1 when all four are taken.
pub fn World::reserve_timer(self : World, frames : Int32) -> Int32 {
  let mut slot = -1
  for i = 0; i < timer_slots; i = i + 1 {
    if !self.timers[i].reserved {
      self.timers[i].seed(frames)
      slot = i
      break
    }
  }
  slot
}

///|
/// `s(int n)` @ d.java:3807.
pub fn World::release_timer(self : World, slot : Int32) -> Unit {
  if slot >= 0 && slot < timer_slots {
    self.timers[slot].seed(0)
    self.timers[slot].reserved = false
  }
}

///|
/// `K()` @ d.java:3754: every reserved slot ticks once per frame, down while its
/// direction is positive, up otherwise.
pub fn World::tick_timers(self : World) -> Unit {
  for i = 0; i < timer_slots; i = i + 1 {
    let t = self.timers[i]
    if t.reserved {
      t.value = if t.counting { t.value - 1 } else { t.value + 1 }
    }
  }
}

///|
/// `j(int n, int n2)` @ d.java:3126 reads the countdown for a parked thread.
pub fn World::timer_expired(self : World, slot : Int32) -> Bool {
  slot >= 0 && slot < timer_slots && self.timers[slot].value <= 0
}

///|
pub fn World::new(cart : Cartridge) -> World {
  let sprites : Array[Sprite] = []
  for row = 0; row < cart.place.rows; row = row + 1 {
    let p = cart.place.row(row)
    sprites.push({
      slot: p[1],
      map: p[0],
      kind: p[2],
      sheet: p[3],
      anim: p[4],
      x: p[5] * tile_size,
      y: p[6] * tile_size,
      dir: p[7],
      mode: 0,
      auto_talk: p[2] == kind_npc,
      live: true,
      label: p[8],
      reward_thing: p[9],
      reward_count: p[10],
      remaining: 0,
      speed: step_px,
      tick: 0,
      anim_group: 0,
      raw_state: -1,
    })
  }
  let vars : Array[Int32] = []
  for i = 0; i < var_pool_size; i = i + 1 {
    vars.push(0)
  }
  let timers : Array[Timer] = []
  for i = 0; i < timer_slots; i = i + 1 {
    timers.push({ reserved: false, value: 0, counting: false, })
  }
  sprites.push({
    slot: hero_slot,
    map: 0,
    kind: kind_npc,
    sheet: 0,
    anim: 2,
    x: 0,
    y: 0,
    dir: 2,
    mode: 0,
    auto_talk: false,
    live: true,
    label: -1,
    reward_thing: -1,
    reward_count: 0,
    remaining: 0,
    speed: step_px,
    tick: 0,
    anim_group: 0,
    raw_state: -1,
  })
  let hero = sprites[sprites.length() - 1]
  { cart, map: 0, hero, sprites, vars, timers, }
}

///|
/// Collision is the engine's last-layer rule (`cell_solid`): a tile id >= 0 in the
/// collision layer blocks.  Other sprites never block walking, because the
/// proximity threads are how the original turns a monster into an obstacle.
pub fn World::walkable(self : World, col : Int32, row : Int32) -> Bool {
  !self.map_of().cell_solid(col, row)
}

///|
/// Engine dir order 0..3 -> (dx, dy) in tiles.
pub fn dir_offset(dir : Int32) -> (Int32, Int32) {
  match dir {
    0 => (0, -1)
    1 => (1, 0)
    2 => (0, 1)
    _ => (-1, 0)
  }
}

///|
/// Start a one-tile step for the hero, honouring collision.  Returning whether the
/// step began is what stops a held key from queueing two steps.
pub fn World::hero_begin_step(self : World, dir : Int32) -> Bool {
  let hero = self.hero
  let (dx, dy) = dir_offset(dir)
  let target_col = hero.col() + dx
  let target_row = hero.row() + dy
  let clear = self.walkable(target_col, target_row)
  if clear {
    hero.dir = dir
    hero.mode = 1
    hero.remaining = tile_size
  }
  clear
}

///|
/// op13 WALK: slide `distance` pixels along `dir` regardless of the grid, spread
/// over `ticks` frames -- the engine's `b(db2, db3)` interval.  Mode 2 is what
/// case 13 writes into `f.aG[0]`, and op9 waits for it to return to 0.
pub fn World::begin_slide(
  self : World,
  slot : Int32,
  dir : Int32,
  distance : Int32,
  ticks : Int32,
) -> Unit {
  match self.index_of(slot) {
    None => ()
    Some(i) => {
      let s = self.sprites[i]
      s.dir = dir
      s.mode = 2
      s.remaining = distance
      s.speed = if ticks <= 0 { step_px } else { distance.div(ticks) }
      s.speed = if s.speed < 1 { 1 } else { s.speed }
    }
  }
}

///|
/// op12 ANIM: force a standing/walking pose without moving.  `group` 0 is the
/// standing half of the record's `V` table, 1 the walking half; `playing` mirrors
/// the engine's `db2` and drives `aG[0]`.
pub fn World::set_pose(
  self : World,
  slot : Int32,
  group : Int32,
  playing : Bool,
) -> Unit {
  match self.index_of(slot) {
    None => ()
    Some(i) => {
      let s = self.sprites[i]
      s.mode = if playing { 1 } else { 0 }
      s.anim_group = group
      s.raw_state = -1
      s.tick = 0
    }
  }
}

///|
/// The other op12 branch (`db3 < 0`): a raw state id straight into the record's
/// `V` table.
pub fn World::set_raw_pose(
  self : World,
  slot : Int32,
  state : Int32,
  playing : Bool,
) -> Unit {
  match self.index_of(slot) {
    None => ()
    Some(i) => {
      let s = self.sprites[i]
      s.mode = if playing { 1 } else { 0 }
      s.raw_state = state
      s.tick = 0
    }
  }
}

///|
/// op72's join branch: put `moved_slot` where `anchor_slot` stands.  The engine's
/// follower chain is not reproduced because no slice content uses it.
pub fn World::place_sprite(
  self : World,
  anchor_slot : Int32,
  moved_slot : Int32,
) -> Unit {
  match self.index_of(anchor_slot) {
    None => ()
    Some(anchor) =>
      match self.index_of(moved_slot) {
        None => ()
        Some(moved) => {
          let from = self.sprites[anchor]
          let to = self.sprites[moved]
          to.map = from.map
          to.x = from.x
          to.y = from.y
        }
      }
  }
}

///|
pub fn World::set_auto_talk(self : World, slot : Int32, enabled : Bool) -> Unit {
  match self.index_of(slot) {
    None => ()
    Some(i) => self.sprites[i].auto_talk = enabled
  }
}

///|
/// op72 JOIN with `db1 != 0`: the sprite leaves the map (`d.A(db2)` @ d.java:2935).
pub fn World::remove_sprite(self : World, slot : Int32) -> Unit {
  match self.index_of(slot) {
    None => ()
    Some(i) => self.sprites[i].live = false
  }
}

///|
/// Advance one frame: every live sprite's animation clock ticks, and a sprite with
/// a running step plan also moves.  The clock is in frames because the walk
/// timeline's holds (`W`) are counted in frames, not pixels.
pub fn World::step(self : World) -> Unit {
  for i = 0; i < self.sprites.length(); i = i + 1 {
    let s = self.sprites[i]
    if s.live {
      s.tick = s.tick + 1
      if s.mode != 0 {
        self.advance(s, s.slot == hero_slot)
      }
    }
  }
}

///|
/// A hero step stops at the tile it was aimed at (collision can end it early); a
/// scripted slide stops where its pixel distance ran out.
fn World::advance(self : World, s : Sprite, is_hero : Bool) -> Unit {
  if s.remaining <= 0 {
    s.mode = 0
    s.anim_group = 0
  } else {
    let (dx, dy) = dir_offset(s.dir)
    let travel = if s.remaining < s.speed { s.remaining } else { s.speed }
    let nx = s.x + dx * travel
    let ny = s.y + dy * travel
    let blocked = is_hero &&
      !self.walkable(nx.div(tile_size), ny.div(tile_size))
    if blocked {
      s.mode = 0
      s.remaining = 0
    } else {
      s.x = nx
      s.y = ny
      s.remaining = s.remaining - travel
      if s.remaining == 0 {
        s.mode = 0
        s.anim_group = 0
        if is_hero {
          self.warp_on_land(s)
        }
      }
    }
  }
}

///|
/// Warp lookup the engine performs on step completion (`d.java` walks `tbl_warp`
/// and issues the scene change itself): a warp is data, not a thread.
pub fn World::warp_at(
  self : World,
  col : Int32,
  row : Int32,
) -> (Int32, Int32, Int32)? {
  let table = self.cart.warp
  let mut found : (Int32, Int32, Int32)? = None
  for r = 0; r < table.rows; r = r + 1 {
    let w = table.row(r)
    if w[0] == self.map && w[1] == col && w[2] == row {
      found = Some((w[3], w[4], w[5]))
      break
    }
  }
  found
}

///|
fn World::warp_on_land(self : World, hero : Sprite) -> Unit {
  match self.warp_at(hero.col(), hero.row()) {
    None => ()
    Some((dest_map, dest_col, dest_row)) =>
      self.place_hero(dest_map, dest_col, dest_row)
  }
}

///|
/// op4 SCENE minus the curtain fade, which is a view concern: change map and park
/// the hero on the new cell.
pub fn World::place_hero(
  self : World,
  map : Int32,
  col : Int32,
  row : Int32,
) -> Unit {
  self.map = map
  let hero = self.hero
  hero.map = map
  hero.x = col * tile_size
  hero.y = row * tile_size
  hero.remaining = 0
  hero.mode = 0
}

///|
/// Camera top-left in pixels, clamped so the viewport never leaves the map; a map
/// smaller than the viewport is pinned at 0.
pub fn World::camera(self : World) -> (Int32, Int32) {
  let m = self.map_of()
  let hero = self.hero
  let follow_x = hero.x - view_w.div(2)
  let follow_y = hero.y - view_h.div(2)
  let (cx, cy) = (
    clamp_window(follow_x, m.width * tile_size, view_w),
    clamp_window(follow_y, m.height * tile_size, view_h),
  )
  (cx, cy)
}

///|
fn clamp_window(follow : Int32, map_px : Int32, view_px : Int32) -> Int32 {
  if map_px <= view_px {
    0
  } else if follow < 0 {
    0
  } else {
    let max = map_px - view_px
    if follow > max {
      max
    } else {
      follow
    }
  }
}

///|
/// `l(int n)`'s overlap test @ d.java:2975, reduced to the two rects it builds: the
/// hero's body rect against the NPC rect expanded by `contact_pad`.  The auto-talk
/// branch shifts that rect by -1 and grows it by +1 (the engine's `ap[2] + 12 + 1`),
/// so the asymmetry is a parameter rather than an assumption.
pub fn rects_overlap(
  ax : Int32,
  ay : Int32,
  aw : Int32,
  ah : Int32,
  bx : Int32,
  by : Int32,
  bw : Int32,
  bh : Int32,
) -> Bool {
  ax < bx + bw && bx < ax + aw && ay < by + bh && by < ay + ah
}

///|
pub fn World::in_contact(self : World, s : Sprite, shrink : Bool) -> Bool {
  let hero = self.hero
  let (hw, hh) = hero.body()
  let (sw, sh) = s.body()
  let ox = if shrink { s.x - 1 - contact_pad } else { s.x - contact_pad }
  let oy = if shrink { s.y - 1 - contact_pad } else { s.y - contact_pad }
  let ew = if shrink { sw + 2 * contact_pad + 1 } else { sw + 2 * contact_pad }
  let eh = if shrink { sh + 2 * contact_pad + 1 } else { sh + 2 * contact_pad }
  rects_overlap(hero.x, hero.y, hw, hh, ox, oy, ew, eh)
}

///|
/// One entry of the per-state walk timeline: which source rect to show, how long to
/// hold it, and the destination nudge (`U`/`W`/`X` @ f.java:196-213).
pub struct WalkEntry {
  rect_index : Int32
  hold : Int32
  dx : Int32
  dy : Int32
} derive(Eq, @debug.Debug)

///|
/// `f.aR` stores each rect as `(y, x, w, h)`; f.java:649-655 reads slot 1 as the
/// source x and slot 0 as the source y, so the pairing is kept here.
pub fn AnimRecord::rect(
  self : AnimRecord,
  frame : Int32,
) -> (Int32, Int32, Int32, Int32) {
  let base = frame * 4
  let y = self.rects[base]
  let x = self.rects[base + 1]
  (x, y, self.rects[base + 2], self.rects[base + 3])
}

///|
pub fn AnimRecord::state_count(self : AnimRecord) -> Int32 {
  if self.v.length() == 0 {
    0
  } else {
    self.v.length() - 1
  }
}

///|
pub fn AnimRecord::entry(
  self : AnimRecord,
  state : Int32,
  tick : Int32,
) -> WalkEntry {
  let count = self.state_count()
  if count == 0 {
    { rect_index: 0, hold: 1, dx: 0, dy: 0, }
  } else {
    let clamped = if state < 0 {
      0
    } else if state >= count {
      count - 1
    } else {
      state
    }
    let start = self.v[clamped]
    let stop = self.v[clamped + 1]
    if start >= stop {
      { rect_index: self.rect_of_step[0], hold: 1, dx: 0, dy: 0, }
    } else {
      self.entry_in(start, stop, tick)
    }
  }
}

///|
/// The `V` window `[start, stop)` is a cycle: the clock wraps on the summed holds
/// and the entry whose slice contains the wrapped tick is the one to show.
fn AnimRecord::entry_in(
  self : AnimRecord,
  start : Int32,
  stop : Int32,
  tick : Int32,
) -> WalkEntry {
  let mut total = 0
  for i = start; i < stop; i = i + 1 {
    total = total + hold_at(self.hold_of_step, i)
  }
  let mut left = if total <= 0 { 0 } else { tick.mod(total) }
  let mut picked : WalkEntry = {
    rect_index: self.rect_of_step[start],
    hold: 1,
    dx: 0,
    dy: 0,
  }
  let mut i = start
  while i < stop {
    let h = hold_at(self.hold_of_step, i)
    if left < h {
      picked = {
        rect_index: self.rect_of_step[i],
        hold: h,
        dx: self.deltas[i * 2],
        dy: self.deltas[i * 2 + 1],
      }
      break
    }
    left = left - h
    i = i + 1
  }
  picked
}

///|
fn hold_at(holds : Array[Int32], i : Int32) -> Int32 {
  let h = holds[i]
  if h <= 0 {
    1
  } else {
    h
  }
}

///|
/// State id for a sprite: the record's `V` table is authored as four standing
/// states then four walking ones, so the animation group selects the half.  A
/// record without the walking half (the monster sheet) keeps the facing index.
/// Two things select the walking half: op12's group operand, which outlives the
/// opcode, and a step plan still in progress -- the hero's own walk is movement,
/// not a scripted pose, so it has no opcode to set the group and reads walking
/// frames from `remaining`.  op12's raw state (`db3 < 0`) bypasses the halves
/// entirely and names a state directly.
pub fn Sprite::state(self : Sprite, record : AnimRecord) -> Int32 {
  if self.raw_state >= 0 {
    self.raw_state
  } else {
    let group = if self.anim_group != 0 || self.remaining > 0 { 1 } else { 0 }
    let wanted = group * engine_dirs + self.dir
    if wanted < record.state_count() {
      wanted
    } else {
      self.dir
    }
  }
}
