// The view, tested as the command stream it submits: which atlas sub-rect each
// tile reads, which cells the camera window drops, which cells get a transform,
// and which blits are whole-image backgrounds rather than sprite cells.  Every
// expectation here is recomputed from the decoded cartridge -- from map geometry
// and animation records -- so a packing mistake in the content surfaces as a paint
// mismatch instead of a matching pair of mistakes.

///|
/// One tile the map layer says should be on screen.
struct TileRun {
  source : String
  x : Double
  y : Double
  id : Int32
  flag : Int32
} derive(Eq, @debug.Debug)

///|
/// A `PushTransform` and the blit it governs.
struct Applied {
  a : Double
  b : Double
  c : Double
  d : Double
  tx : Double
  ty : Double
  centre_x : Double
  centre_y : Double
  blit : Bool
} derive(Eq, @debug.Debug)

///|
fn canvas_rect() -> @geometry.Rect {
  @geometry.Rect::new(
    x=0.0,
    y=0.0,
    width=view_w.to_double(),
    height=view_h.to_double(),
  )
}

///|
fn paint_frame(model : Model) -> Array[@core.DrawCommand] {
  let ctx = @views.PaintContext::new()
  paint_screen(ctx, canvas_rect(), model)
  ctx.finish()
}

///|
/// Boot chain plus the arrival card, closed: the map driver owns the screen and no
/// overlay paints over the tiles.  Same walk-up as `vm_wbtest`'s `to_the_map`.
fn quiet_model() -> Model raise {
  let vm = vm_new()
  to_the_map(vm)
  vm.close_overlay()
  vm.tick()
  inspect(vm.ui.active, content="false")
  Model::from_vm(vm)
}

///|
fn images(cmds : Array[@core.DrawCommand]) -> Array[@core.ImageRun] {
  let out : Array[@core.ImageRun] = []
  for cmd in cmds {
    match cmd {
      DrawImage(run) => out.push(run)
      _ => ()
    }
  }
  out
}

///|
fn texts(cmds : Array[@core.DrawCommand]) -> Array[String] {
  let out : Array[String] = []
  for cmd in cmds {
    match cmd {
      DrawText(run) => out.push(run.text)
      _ => ()
    }
  }
  out
}

///|
fn dest_x(run : @core.ImageRun) -> Double {
  run.frame.origin.x
}

///|
fn dest_y(run : @core.ImageRun) -> Double {
  run.frame.origin.y
}

///|
fn dest_w(run : @core.ImageRun) -> Double {
  run.frame.size.width
}

///|
fn dest_h(run : @core.ImageRun) -> Double {
  run.frame.size.height
}

///|
/// Source origin as integers: every cell in the content sits on a whole pixel.
fn src_cell(run : @core.ImageRun) -> (Int32, Int32) {
  match run.src_rect {
    None => (-1, -1)
    Some(rect) => (rect.origin.x.to_int(), rect.origin.y.to_int())
  }
}

///|
/// Tiles are the only 16x16 sub-rect blits the view submits: a character frame is
/// 16x24, a monster 32x32, a background whole-canvas with no source rect.
fn tile_blits(cmds : Array[@core.DrawCommand]) -> Array[@core.ImageRun] {
  let out : Array[@core.ImageRun] = []
  for run in images(cmds) {
    if dest_w(run) == 16.0 && dest_h(run) == 16.0 {
      out.push(run)
    }
  }
  out
}

///|
/// The cells the viewport touches over a map whose camera top-left is `(cx, cy)`:
/// a cell is on screen when its 16px rect overlaps the window, so the first column
/// is the one the camera is inside and the last is the one the right edge lands on.
/// Derived from the geometry, not from the paint loop.
fn visible_window(
  map : GameMap,
  cx : Int32,
  cy : Int32,
) -> (Int32, Int32, Int32, Int32) {
  let first_col = cx / tile_size
  let last_col = ceil_div(cx + view_w, tile_size)
  let first_row = cy / tile_size
  let last_row = ceil_div(cy + view_h, tile_size)
  (
    if first_col > map.width {
      map.width
    } else {
      first_col
    },
    if last_col > map.width {
      map.width
    } else {
      last_col
    },
    if first_row > map.height {
      map.height
    } else {
      first_row
    },
    if last_row > map.height {
      map.height
    } else {
      last_row
    },
  )
}

///|
fn ceil_div(a : Int32, b : Int32) -> Int32 {
  (a + b - 1) / b
}

///|
/// What the map data says belongs on screen, in the order the layers are drawn:
/// every layer the tileset table marks as art, collision layer excluded.
fn expected_tiles(map : GameMap, cx : Int32, cy : Int32) -> Array[TileRun] {
  let out : Array[TileRun] = []
  let drawn = map.tiles.length() - 1
  let (first_col, last_col, first_row, last_row) = visible_window(map, cx, cy)
  for layer = 0; layer < drawn; layer = layer + 1 {
    let bank = map.tilesets[layer]
    if bank == bank_none {
      continue
    }
    let source = bank_source(bank)
    for row = first_row; row < last_row; row = row + 1 {
      for col = first_col; col < last_col; col = col + 1 {
        let index = row * map.width + col
        let id = map.tiles[layer][index]
        if id >= 0 {
          out.push({
            source,
            x: (col * tile_size - cx).to_double(),
            y: (row * tile_size - cy).to_double(),
            id,
            flag: map.flags[layer][index],
          })
        }
      }
    }
  }
  out
}

///|
/// The whole map with the same filter, ignoring the window -- the number culling
/// has to beat for the cull to be real.
fn uncullable_tiles(map : GameMap) -> Int32 {
  let mut count = 0
  for layer = 0; layer < map.tiles.length() - 1; layer = layer + 1 {
    if map.tilesets[layer] == bank_none {
      continue
    }
    for id in map.tiles[layer] {
      if id >= 0 {
        count = count + 1
      }
    }
  }
  count
}

///|
/// The blit identity as one string: which sheet, which destination, which source
/// cell.  Comparing these keeps a single mismatch readable in the failure text.
fn want_key(run : TileRun) -> String {
  let src = atlas_src(run.id)
  describe(run.source, run.x, run.y, src.origin.x, src.origin.y)
}

///|
fn got_key(run : @core.ImageRun) -> String {
  let (sx, sy) = src_cell(run)
  describe(run.source, dest_x(run), dest_y(run), sx.to_double(), sy.to_double())
}

///|
fn describe(
  source : String,
  x : Double,
  y : Double,
  sx : Double,
  sy : Double,
) -> String {
  let sheet = if source == BANK_GROUND_URI {
    "ground"
  } else if source == BANK_OBJECT_URI {
    "object"
  } else if source == SHEET_HERO_URI {
    "hero"
  } else if source == SHEET_NPC_URI {
    "npc"
  } else if source == SHEET_MONSTER_URI {
    "monster"
  } else {
    "other"
  }
  let dest = x.to_string() + "," + y.to_string()
  let cell = sx.to_string() + "," + sy.to_string()
  sheet + "@" + dest + "<-" + cell
}

///|
/// "" when the two streams agree, else the first difference with its index.
fn first_diff(want : Array[TileRun], got : Array[@core.ImageRun]) -> String {
  if want.length() != got.length() {
    return "count " +
      got.length().to_string() +
      " want " +
      want.length().to_string()
  }
  let mut i = 0
  let mut found = ""
  while i < want.length() && found == "" {
    let w = want_key(want[i])
    let g = got_key(got[i])
    if w != g {
      found = "[" + i.to_string() + "] got " + g + " want " + w
    }
    i = i + 1
  }
  found
}

///|
/// (clip opens, clip closes, transform opens, transform closes, lowest depth) over
/// the clip/transform commands the view submits.
fn stack_audit(
  cmds : Array[@core.DrawCommand],
) -> (Int32, Int32, Int32, Int32, Int32) {
  let mut clip_open = 0
  let mut clip_close = 0
  let mut t_open = 0
  let mut t_close = 0
  let mut depth = 0
  let mut lowest = 0
  for cmd in cmds {
    match cmd {
      PushClip(_) => {
        clip_open = clip_open + 1
        depth = depth + 1
      }
      PopClip => {
        clip_close = clip_close + 1
        depth = depth - 1
      }
      PushTransform(_) => {
        t_open = t_open + 1
        depth = depth + 1
      }
      PopTransform => {
        t_close = t_close + 1
        depth = depth - 1
      }
      _ => ()
    }
    if depth < lowest {
      lowest = depth
    }
  }
  (clip_open, clip_close, t_open, t_close, lowest)
}

///|
/// Each `PushTransform` with the run it applies to, which is the blit right after it.
fn applied_transforms(cmds : Array[@core.DrawCommand]) -> Array[Applied] {
  let out : Array[Applied] = []
  let mut i = 0
  while i < cmds.length() {
    match cmds[i] {
      PushTransform(t) => {
        let next = if i + 1 < cmds.length() { Some(cmds[i + 1]) } else { None }
        match next {
          Some(DrawImage(run)) =>
            out.push({
              a: t.a,
              b: t.b,
              c: t.c,
              d: t.d,
              tx: t.tx,
              ty: t.ty,
              centre_x: dest_x(run) + dest_w(run) / 2.0,
              centre_y: dest_y(run) + dest_h(run) / 2.0,
              blit: true,
            })
          _ =>
            out.push({
              a: t.a,
              b: t.b,
              c: t.c,
              d: t.d,
              tx: t.tx,
              ty: t.ty,
              centre_x: 0.0,
              centre_y: 0.0,
              blit: false,
            })
        }
      }
      _ => ()
    }
    i = i + 1
  }
  out
}

///|
fn close(x : Double, y : Double) -> Bool {
  let d = if x > y { x - y } else { y - x }
  d < 0.000001
}

///|
/// A quarter turn: orthonormal, determinant 1, and it holds the cell centre still.
fn is_rotation_about_centre(t : Applied) -> Bool {
  let unit_rows = close(t.a * t.a + t.b * t.b, 1.0) &&
    close(t.c * t.c + t.d * t.d, 1.0)
  let orthogonal = close(t.a * t.c + t.b * t.d, 0.0)
  let turns = close(t.a * t.d - t.b * t.c, 1.0)
  let fixed_x = close(t.a * t.centre_x + t.c * t.centre_y + t.tx, t.centre_x)
  let fixed_y = close(t.b * t.centre_x + t.d * t.centre_y + t.ty, t.centre_y)
  unit_rows && orthogonal && turns && fixed_x && fixed_y
}

///|
fn seen_in(items : Array[String], item : String) -> Bool {
  let mut seen = false
  for existing in items {
    if existing == item {
      seen = true
    }
  }
  seen
}

///|
fn has_text(lines : Array[String], text : String) -> Bool {
  seen_in(lines, text)
}

///|
/// Two integers as one comparable string, so a mismatch shows both halves.
fn pair(a : Int32, b : Int32) -> String {
  a.to_string() + "," + b.to_string()
}

///|
/// Source y of a facing's row on a character sheet: the generator lays the rows out
/// as down=0, left=1, right=2, up=3 while the engine numbers its facings up=0,
/// right=1, down=2, left=3, so the four facings read rows 72, 48, 0 and 24.
fn facing_row(facing : Int32) -> Int32 {
  match facing {
    0 => 72
    1 => 48
    2 => 0
    _ => 24
  }
}

///|
test "the tile blits are the visible window of the art layers, in draw order" {
  let model = quiet_model()
  for map_index = 0; map_index < 3; map_index = map_index + 1 {
    let map = model.vm.cart().maps[map_index]
    model.vm.world.place_hero(map_index, 1, 1)
    let (cx, cy) = model.vm.world.camera()
    let want = expected_tiles(map, cx, cy)
    let got = tile_blits(paint_frame(model))
    inspect(first_diff(want, got), content="")
    // the collision layer is a tile array of solid/open codes, never art
    let mut ground = false
    let mut object = false
    for run in got {
      if run.source == BANK_GROUND_URI {
        ground = true
      } else if run.source == BANK_OBJECT_URI {
        object = true
      }
      // a 16px cell out of a six-column bank, on the grid and inside the sheet
      match run.src_rect {
        None => inspect("tile without a source rect", content="")
        Some(src) => {
          inspect(
            src.size.width == 16.0 && src.size.height == 16.0,
            content="true",
          )
          inspect(
            src.origin.x % 16.0 == 0.0 && src.origin.y % 16.0 == 0.0,
            content="true",
          )
          inspect(src.origin.x < 96.0 && src.origin.y < 64.0, content="true")
        }
      }
    }
    inspect(ground && object, content="true")
  }
}

///|
test "the camera window drops the cells the viewport does not touch" {
  let model = quiet_model()
  let map = model.vm.world.map_of()
  // the boot spawn is not at the left edge, so the camera is already scrolled
  model.vm.world.place_hero(0, 11, 13)
  let (near_x, near_y) = model.vm.world.camera()
  inspect(near_x, content="56")
  inspect(near_y, content="0")
  let near = tile_blits(paint_frame(model))
  // walking to the far side moves the camera to its clamp and re-windows the map
  model.vm.world.place_hero(0, map.width - 2, 13)
  let (far_x, far_y) = model.vm.world.camera()
  // the village is 26 columns, so the clamp is 416 - 240
  inspect(far_x, content="176")
  inspect(far_y, content="0")
  let far = tile_blits(paint_frame(model))
  let (near_first, near_last, near_top, near_bottom) = visible_window(
    map, near_x, near_y,
  )
  let (far_first, far_last, far_top, far_bottom) = visible_window(
    map, far_x, far_y,
  )
  inspect(pair(near_first, near_last), content="3,19")
  inspect(pair(far_first, far_last), content="11,26")
  inspect(pair(near_top, near_bottom), content="0,18")
  inspect(pair(far_top, far_bottom), content="0,18")
  // scroll actually changes what is submitted, and both windows agree with the data
  inspect(dest_x(near[0]) != dest_x(far[0]), content="true")
  inspect(first_diff(expected_tiles(map, near_x, near_y), near), content="")
  inspect(first_diff(expected_tiles(map, far_x, far_y), far), content="")
  // culling is real, though not dramatic: a 240px viewport over a 416px map submits
  // 16 of 26 columns near the edge and 15 at the clamp, and no blit lands off the window
  let total = uncullable_tiles(map)
  inspect(near.length() < total && far.length() < total, content="true")
  inspect(near_first < far_first, content="true")
  let mut outside = 0
  for run in far {
    let x = dest_x(run)
    let y = dest_y(run)
    if !(x + 16.0 > 0.0 &&
      x < view_w.to_double() &&
      y + 16.0 > 0.0 &&
      y < view_h.to_double()) {
      outside = outside + 1
    }
  }
  inspect(outside, content="0")
}

///|
test "the authored maps fit the viewport vertically, so only the x axis scrolls" {
  let model = quiet_model()
  // An honesty item, stated as an assertion: 16-18 rows of 16px is 256-288px against
  // a 320px canvas, so `clamp_window` pins `cy` at 0 for every cell of every authored
  // map and the vertical half of the window math is never exercised by content. The
  // horizontal scroll and the row clamp are covered above; nothing here claims more.
  for index = 0; index < 3; index = index + 1 {
    let map = model.vm.cart().maps[index]
    model.vm.world.place_hero(index, 1, 1)
    let (cx, cy) = model.vm.world.camera()
    inspect(map.height * tile_size <= view_h, content="true")
    inspect(cy, content="0")
    let (first_col, last_col, first_row, last_row) = visible_window(map, cx, cy)
    inspect(pair(first_row, last_row), content="0," + map.height.to_string())
    inspect(
      last_col < map.width || map.width * tile_size <= view_w,
      content="true",
    )
    inspect(first_col, content="0")
  }
}

///|
test "a rotated cell is drawn inside a push/pop pair that turns about its centre" {
  let model = quiet_model()
  let map = model.vm.world.map_of()
  model.vm.world.place_hero(0, 11, 5)
  let (cx, cy) = model.vm.world.camera()
  let cmds = paint_frame(model)
  let want = expected_tiles(map, cx, cy)
  let mut want_rotated = 0
  for run in want {
    if run.flag != trans_none {
      want_rotated = want_rotated + 1
    }
  }
  // the fence, roof and window rows of the authored village carry transform codes,
  // so this branch is reached by content rather than only by a unit fixture
  inspect(want_rotated > 0, content="true")
  let (clip_open, clip_close, t_open, t_close, lowest) = stack_audit(cmds)
  inspect(t_open, content=want_rotated.to_string())
  inspect(t_close, content=want_rotated.to_string())
  inspect(clip_open == clip_close && clip_open == 2, content="true")
  inspect(lowest, content="0")
  let applied = applied_transforms(cmds)
  let mut unapplied = 0
  let mut not_rotation = 0
  for t in applied {
    if !t.blit {
      unapplied = unapplied + 1
    } else if !is_rotation_about_centre(t) {
      not_rotation = not_rotation + 1
    }
  }
  inspect(unapplied, content="0")
  inspect(not_rotation, content="0")
}

///|
test "the hero is blitted from the walking half of its record while a step runs" {
  let model = quiet_model()
  let vm = model.vm
  let record = vm.cart().anim(vm.world.hero.anim).unwrap()
  fn hero_blit(model : Model) -> @core.ImageRun {
    let mut found : @core.ImageRun? = None
    for run in images(paint_frame(model)) {
      if run.source == SHEET_HERO_URI && dest_h(run) == 24.0 {
        found = Some(run)
      }
    }
    found.unwrap()
  }
  // standing, facing down (the engine's 2, the sheet's first row), clock reset so the
  // state's single step is the one on show
  vm.world.place_hero(0, 5, 7)
  vm.world.hero.tick = 0
  inspect(vm.world.hero.state(record), content="2")
  let (fx, fy, fw, fh) = record.rect(record.entry(2, 0).rect_index)
  inspect(pair(fx, fy), content="0,0")
  inspect(pair(fw, fh), content="16,24")
  let standing = hero_blit(model)
  let (sx, sy) = src_cell(standing)
  inspect(pair(sx, sy), content="0,0")
  // the tile at (5, 7) lands at 80, 112: the village is 24 columns wide, so the
  // camera is pinned to its left edge here
  let on_tile = dest_x(standing) == 80.0 && dest_y(standing) == 112.0
  let one_to_one = dest_w(standing) == 16.0 && dest_h(standing) == 24.0
  inspect(on_tile && one_to_one, content="true")
  // mid-step with no opcode involved: the walking half of the record, on the facing's
  // own row, and the destination tracks the interpolated position
  inspect(vm.world.hero_begin_step(1), content="true")
  vm.world.step()
  inspect(vm.world.hero.state(record), content="5")
  let stepping = hero_blit(model)
  let (wx, wy) = src_cell(stepping)
  inspect(pair(wx, wy), content="0," + facing_row(1).to_string())
  inspect(dest_x(stepping) == 86.0, content="true")
  // the walking state's own cycle: three columns, six ticks apiece, and the middle
  // frame is the one carrying the record's vertical nudge into the destination
  let cols : Array[Int32] = []
  let mut off_row = 0
  let mut nudged = 0
  for t = 0; t < 18; t = t + 1 {
    vm.world.set_pose(hero_slot, 1, true)
    vm.world.hero.dir = 1
    vm.world.hero.tick = t
    let run = hero_blit(model)
    let (cx, cy) = src_cell(run)
    if cy != facing_row(1) {
      off_row = off_row + 1
    }
    if !code_seen(cols, cx) {
      cols.push(cx)
    }
    if dest_y(run) != 112.0 {
      nudged = nudged + 1
    }
  }
  inspect(off_row, content="0")
  inspect(cols.length(), content="3")
  inspect(cols[0] == 0 && cols[1] == 16 && cols[2] == 32, content="true")
  inspect(nudged, content="6")
  // and a scripted walking pose names one row per facing, so all four are reachable
  let rows : Array[Int32] = []
  for dir = 0; dir < engine_dirs; dir = dir + 1 {
    vm.world.set_pose(hero_slot, 1, false)
    vm.world.hero.dir = dir
    let (px, py) = src_cell(hero_blit(model))
    inspect(px, content="0")
    inspect(py, content=facing_row(dir).to_string())
    if !code_seen(rows, py) {
      rows.push(py)
    }
  }
  inspect(rows.length(), content="4")
}

///|
test "the dialog opens over the map with a portrait cell and the script's own text" {
  let model = quiet_model()
  let vm = model.vm
  stand_right_of(vm, 0)
  vm.press_key(key_confirm)
  vm.tick()
  inspect(vm.ui.kind, content="1")
  let cmds = paint_frame(model)
  let lines = texts(cmds)
  inspect(has_text(lines, text_at(vm.ui.name)), content="true")
  inspect(
    has_text(lines, wrap_lines(text_at(vm.ui.body), line_units)[0]),
    content="true",
  )
  // the talking head is the speaker's standing cell off its own walk sheet: the
  // facing row is the one the script asked for (`db4`, kept as `ui.pose`), the column
  // is 0 because a pose is not a step, and the destination is the panel's own slot
  let (_, anim) = portrait_parts(vm.ui.portrait)
  let record = vm.cart().anim(anim).unwrap()
  let pose = vm.ui.pose
  let state = if pose < 0 {
    0
  } else if pose >= engine_dirs {
    engine_dirs - 1
  } else {
    pose
  }
  let step = record.entry(state, 0)
  let (rx, ry, rw, rh) = record.rect(step.rect_index)
  inspect(rx, content="0")
  inspect(ry, content=facing_row(state).to_string())
  let mut portrait : @core.ImageRun? = None
  for run in images(cmds) {
    if run.source == SHEET_NPC_URI {
      portrait = Some(run)
    }
  }
  match portrait {
    None => inspect("no portrait blit", content="none")
    Some(run) => {
      let one_to_one = dest_w(run) == rw.to_double() &&
        dest_h(run) == rh.to_double()
      inspect(one_to_one, content="true")
      match run.src_rect {
        None => inspect("portrait without a source rect", content="")
        Some(src) => {
          let cell = src.origin.x == rx.to_double() &&
            src.origin.y == ry.to_double()
          inspect(cell, content="true")
          inspect(src.size.width == rw.to_double(), content="true")
          inspect(src.size.height == rh.to_double(), content="true")
        }
      }
      let slot_x = dest_x(run) == 6.0 + step.dx.to_double()
      let slot_y = dest_y(run) ==
        (view_h - 96 + 4).to_double() + step.dy.to_double()
      inspect(slot_x && slot_y, content="true")
    }
  }
}

///|
test "the title and battle cards stretch a whole background and add no sub-rect" {
  // the card is a script event, not the loader's first frame: the boot thread's
  // `Title` opcode takes the screen one tick after the model exists
  let title = Model::boot()
  title.vm.tick()
  inspect(title.vm.ui.kind, content="4")
  inspect(title.vm.ui.active, content="true")
  let cmds = paint_frame(title)
  let mut whole = 0
  for run in images(cmds) {
    match run.src_rect {
      None => {
        whole = whole + 1
        inspect(run.source, content=BG_TITLE_URI)
        let at_origin = dest_x(run) == 0.0 && dest_y(run) == 0.0
        let full_canvas = dest_w(run) == view_w.to_double() &&
          dest_h(run) == view_h.to_double()
        inspect(at_origin && full_canvas, content="true")
      }
      Some(_) => ()
    }
  }
  inspect(whole, content="1")
  inspect(has_text(texts(cmds), text_at(title.vm.ui.body)), content="true")
  // the arena: one stretched backdrop, then one sub-rect per living combatant
  let model = quiet_model()
  stand_right_of(model.vm, 3)
  model.vm.tick()
  inspect(model.vm.ui.kind, content="5")
  let arena = model.vm.battle.unwrap()
  let battle = paint_frame(model)
  let mut backdrop = 0
  let mut units = 0
  // the arena is drawn over a live map, so its own blits are the ones that follow the
  // backdrop: count from there rather than calling every sub-rect a combatant
  let mut past_backdrop = false
  for run in images(battle) {
    match run.src_rect {
      None => {
        inspect(run.source, content=BG_BATTLE_URI)
        past_backdrop = true
        backdrop = backdrop + 1
      }
      Some(_) => if past_backdrop { units = units + 1 }
    }
  }
  inspect(backdrop, content="1")
  let combatants = arena.alive_count(side_party) + arena.alive_count(side_enemy)
  inspect(units, content=combatants.to_string())
  // a monster anim reads its own 32x32 cells, so no unit is stretched
  let mut monsters = 0
  let mut wrong_size = 0
  for run in images(battle) {
    if run.source == SHEET_MONSTER_URI {
      monsters = monsters + 1
      if dest_w(run) != 32.0 || dest_h(run) != 32.0 {
        wrong_size = wrong_size + 1
      }
    }
  }
  inspect(monsters > 0, content="true")
  inspect(wrong_size, content="0")
}
