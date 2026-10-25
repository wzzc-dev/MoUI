// The map/sprite side, checked against the cartridge the generator actually
// produced: stepping, collision, camera, warps, the countdown pool and the walk
// timeline read the same numbers the view will draw.

///|
fn village_world() -> World raise {
  World::new(load_cartridge())
}

///|
fn run(w : World, frames : Int32) -> Unit {
  for i = 0; i < frames; i = i + 1 {
    w.step()
  }
}

///|
test "a hero step crosses one tile in three ticks at six pixels a tick" {
  let w = village_world()
  w.place_hero(0, 5, 7)
  inspect(w.hero_begin_step(1), content="true")
  w.step()
  inspect(w.hero.x, content="86")
  inspect(w.hero.mode, content="1")
  w.step()
  inspect(w.hero.x, content="92")
  inspect(w.hero.remaining, content="4")
  w.step()
  // 6 + 6 + 4: the last tick travels the remainder, not a full stride, and the
  // step plan ends on the tile boundary rather than overshooting it.
  inspect(w.hero.x, content="96")
  inspect(w.hero.col(), content="6")
  inspect(w.hero.row(), content="7")
  inspect(w.hero.mode, content="0")
  inspect(w.hero.remaining, content="0")
}

///|
test "a solid cell refuses the step and leaves the sprite standing" {
  let w = village_world()
  // the cave's second row is rock, so the (2,2) stone floor has one free neighbour
  w.place_hero(2, 2, 2)
  inspect(w.walkable(2, 2), content="true")
  inspect(w.walkable(2, 1), content="false")
  inspect(w.hero_begin_step(0), content="false")
  inspect(w.hero.mode, content="0")
  inspect(w.hero.dir, content="2")
  inspect(w.hero_begin_step(2), content="true")
  run(w, 3)
  inspect(w.hero.y, content="48")
  inspect(w.hero.row(), content="3")
  // the grid has no third axis: outside it is solid, so the hero cannot walk off
  inspect(w.walkable(-1, 5), content="false")
  inspect(w.walkable(26, 5), content="false")
  inspect(w.walkable(1, 18), content="false")
}

///|
test "the camera follows the hero and clamps to the map edges" {
  let w = village_world()
  let m = w.map_of()
  w.place_hero(0, 0, 7)
  let (left_x, left_y) = w.camera()
  inspect(left_x, content="0")
  inspect(left_y, content="0")
  w.place_hero(0, m.width - 1, 7)
  let (right_x, _) = w.camera()
  inspect(right_x, content=(m.width * tile_size - view_w).to_string())
  w.place_hero(0, 12, 7)
  let (mid_x, _) = w.camera()
  inspect(mid_x, content=(12 * tile_size - view_w.div(2)).to_string())
  // the village is shorter than the viewport, so its axis is pinned, not scrolled
  w.place_hero(0, 12, m.height - 1)
  let (_, bottom_y) = w.camera()
  inspect(bottom_y, content="0")
}

///|
test "landing on a warp cell moves the hero to the linked map" {
  let w = village_world()
  w.place_hero(0, 22, 7)
  let (dest_map, dest_col, dest_row) = w.warp_at(23, 7).unwrap()
  inspect(dest_map, content="1")
  inspect(dest_col, content="0")
  inspect(dest_row, content="7")
  let outside : Bool = match w.warp_at(0, 0) {
    None => true
    Some(_) => false
  }
  inspect(outside, content="true")
  inspect(w.map, content="0")
  inspect(w.hero_begin_step(1), content="true")
  run(w, 3)
  // the engine walks `tbl_warp` itself on step completion, so this is data, not a
  // script: no thread had to run for the map to change.
  inspect(w.map, content="1")
  inspect(w.hero.map, content="1")
  inspect(w.hero.col(), content="0")
  inspect(w.hero.row(), content="7")
  inspect(w.hero.mode, content="0")
}

///|
test "the countdown pool hands out four slots and refuses the fifth" {
  let w = village_world()
  inspect(w.reserve_timer(5), content="0")
  inspect(w.reserve_timer(20), content="1")
  inspect(w.reserve_timer(20), content="2")
  inspect(w.reserve_timer(20), content="3")
  // `r(int n)` @ d.java:3795 has no fifth slot, and a refused wait stays refused
  inspect(w.reserve_timer(1), content="-1")
  for i = 0; i < 5; i = i + 1 {
    w.tick_timers()
  }
  inspect(w.timer_expired(0), content="true")
  inspect(w.timer_expired(1), content="false")
  for i = 0; i < 15; i = i + 1 {
    w.tick_timers()
  }
  inspect(w.timer_expired(1), content="true")
  w.release_timer(0)
  inspect(w.reserve_timer(2), content="0")
  // slot -1 (the refusal) never expires, exactly like the original's array bounds
  inspect(w.timer_expired(-1), content="false")
}

///|
test "the walk timeline cycles three frames and wraps on its summed holds" {
  let cart = load_cartridge()
  let figure = cart.anim(2).unwrap()
  inspect(figure.frames, content="12")
  inspect(figure.state_count(), content="8")
  // state 4 is the walking-up half of the figure record: three entries of six
  // ticks, reading source rects 9, 10, 11 of the 3x4 sheet
  inspect(figure.entry(4, 0).rect_index, content="9")
  inspect(figure.entry(4, 5).rect_index, content="9")
  inspect(figure.entry(4, 6).rect_index, content="10")
  inspect(figure.entry(4, 12).rect_index, content="11")
  inspect(figure.entry(4, 17).rect_index, content="11")
  inspect(figure.entry(4, 18).rect_index, content="9")
  inspect(figure.entry(4, 6).hold, content="6")
  inspect(figure.entry(4, 6).dy, content="-1")
  inspect(figure.entry(4, 0).dy, content="0")
  let (sx, sy, sw, sh) = figure.rect(9)
  inspect(sx, content="0")
  inspect(sy, content="72")
  inspect(sw, content="16")
  inspect(sh, content="24")
  // an out-of-range state clamps to the last one instead of running off the table
  inspect(figure.entry(99, 0).rect_index, content="3")
  let monster = cart.anim(3).unwrap()
  inspect(monster.state_count(), content="4")
  inspect(monster.entry(0, 0).rect_index, content="0")
  inspect(monster.entry(0, 9).rect_index, content="0")
  inspect(monster.entry(0, 10).rect_index, content="1")
  inspect(monster.entry(0, 20).rect_index, content="0")
}

///|
test "op12's state group selects the walking half and outlives the opcode" {
  let w = village_world()
  let figure = w.cart.anim(1).unwrap()
  w.set_pose(0, 1, true)
  let elder = w.sprite(0).unwrap()
  inspect(elder.anim_group, content="1")
  inspect(elder.mode, content="1")
  inspect(elder.raw_state, content="-1")
  // the placement faces left, so group 1 selects walking state 7
  inspect(elder.dir, content="3")
  inspect(elder.state(figure), content="7")
  w.set_pose(0, 0, false)
  let standing = w.sprite(0).unwrap()
  inspect(standing.mode, content="0")
  inspect(standing.state(figure), content="3")
  w.set_pose(3, 1, false)
  let wolf = w.sprite(3).unwrap()
  let monster = w.cart.anim(3).unwrap()
  // a four-state monster record has no walking half, so the facing index is used
  inspect(wolf.state(monster), content="2")
  w.set_raw_pose(3, 1, true)
  inspect(w.sprite(3).unwrap().raw_state, content="1")
  // the raw operand names a state outright, so it wins over both halves
  inspect(w.sprite(3).unwrap().state(w.cart.anim(3).unwrap()), content="1")
  w.set_pose(3, 0, false)
  inspect(w.sprite(3).unwrap().state(w.cart.anim(3).unwrap()), content="2")
}

///|
test "a hero mid-step reads the walking half without any opcode" {
  let w = village_world()
  w.place_hero(0, 5, 7)
  let figure = w.cart.anim(w.hero.anim).unwrap()
  // 4 standing states then 4 walking ones -- `figure_anim` authors both halves
  // for every character record, and the view picks with this state id.
  inspect(figure.state_count(), content="8")
  inspect(w.hero.state(figure), content="2")
  inspect(w.hero_begin_step(1), content="true")
  // no op12 ran: the step plan in progress is the only thing that can select the
  // walking half for the hero, or the player would slide around on a standing frame
  inspect(w.hero.state(figure), content="5")
  run(w, 3)
  inspect(w.hero.state(figure), content="1")
  // a refused step leaves no plan running, so the pose stays on the standing half
  // and keeps the facing the hero already had
  w.place_hero(2, 2, 2)
  inspect(w.hero_begin_step(0), content="false")
  inspect(w.hero.state(figure), content="1")
}

///|
test "op13 slides a sprite its pixel distance spread over its tick count" {
  let w = village_world()
  w.begin_slide(2, 3, 48, 16)
  let before = w.sprite(2).unwrap()
  inspect(before.mode, content="2")
  inspect(before.speed, content="3")
  inspect(before.x, content="80")
  run(w, 8)
  inspect(w.sprite(2).unwrap().x, content="56")
  run(w, 8)
  let after = w.sprite(2).unwrap()
  inspect(after.x, content="32")
  inspect(after.mode, content="0")
  inspect(after.remaining, content="0")
  // an NPC slide ignores the collision layer: op13 is a cutscene nudge, and the
  // engine's `b(db2, db3)` moves pixels rather than cells
  inspect(after.col(), content="2")
}

///|
test "a scripted slide for the hero still honours collision" {
  let w = village_world()
  w.place_hero(0, 0, 13)
  w.begin_slide(hero_slot, 1, 48, 16)
  run(w, 16)
  // the fence at (3,13) stops the 48-pixel slide 3 pixels short of its goal
  inspect(w.hero.col(), content="2")
  inspect(w.hero.x, content="45")
  inspect(w.hero.mode, content="0")
  inspect(w.hero.remaining, content="0")
}

///|
test "the contact rect is the sprite body padded by six pixels" {
  let w = village_world()
  let elder = w.sprite(0).unwrap()
  inspect(elder.x, content="144")
  let (ew, eh) = elder.body()
  inspect(ew, content="16")
  inspect(eh, content="24")
  let wolf = w.sprite(3).unwrap()
  let (mw, mh) = wolf.body()
  inspect(mw, content="32")
  inspect(mh, content="32")
  w.place_hero(0, 10, 9)
  inspect(w.in_contact(elder, false), content="true")
  w.place_hero(0, 11, 9)
  inspect(w.in_contact(elder, false), content="false")
  // `l(int n)`'s auto-talk branch shifts the padded rect by -1 and grows it by +1,
  // which only shows on a sub-pixel edge: at 22 the two branches disagree.
  inspect(
    rects_overlap(
      0,
      0,
      16,
      24,
      22 - contact_pad,
      0,
      16 + 2 * contact_pad,
      24 + 2 * contact_pad,
    ),
    content="false",
  )
  inspect(
    rects_overlap(
      0,
      0,
      16,
      24,
      22 - 1 - contact_pad,
      0,
      16 + 2 * contact_pad + 1,
      24 + 2 * contact_pad + 1,
    ),
    content="true",
  )
}

///|
test "op72 moves a sprite and a removed sprite leaves the draw list" {
  let w = village_world()
  // placements own the other maps too, so the draw list is the current map's subset
  inspect(w.present().length(), content="5")
  w.place_sprite(0, 7)
  let mirror = w.sprite(7).unwrap()
  inspect(mirror.x, content="144")
  inspect(mirror.y, content="144")
  inspect(mirror.map, content="0")
  w.remove_sprite(7)
  inspect(w.present().length(), content="4")
  inspect(w.sprite(7).unwrap().live, content="false")
  // a slot nothing binds to is a gap, not a crash
  let gap : Bool = match w.sprite(20) {
    None => true
    Some(_) => false
  }
  inspect(gap, content="true")
}

///|
test "the variable pool and the auto-talk switch are the only shared state" {
  let w = village_world()
  inspect(w.get_var(v_elder_met), content="0")
  w.set_var(v_elder_met, 1)
  inspect(w.get_var(v_elder_met), content="1")
  // writing past the pool is ignored rather than growing it, like `bQ`
  w.set_var(var_pool_size, 7)
  inspect(w.get_var(var_pool_size), content="0")
  inspect(w.get_var(-1), content="0")
  w.set_auto_talk(0, false)
  inspect(w.sprite(0).unwrap().auto_talk, content="false")
  w.set_auto_talk(0, true)
  inspect(w.sprite(0).unwrap().auto_talk, content="true")
  // the placements start their auto-talk switch from their kind, not a script
  inspect(w.sprite(3).unwrap().auto_talk, content="false")
  inspect(w.hero.auto_talk, content="false")
}
