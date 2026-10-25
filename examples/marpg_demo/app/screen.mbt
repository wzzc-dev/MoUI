// The drawing half of the slice.  Where a pixel goes is decided by the reversed
// formats (16px cells, six-column banks, `id & 0xFFF`, the R/T/S/V arrays, the
// 240x320 J2ME canvas); the panel chrome and its wording are this slice's own.

///|
using @views {
  fill_rect,
  stroke_rect,
  draw_text,
  draw_image,
  push_clip,
  pop_clip,
  push_transform,
  pop_transform,
}

///|
/// Panel geometry inside the canvas.  The engine composited its HUD and strips
/// over the same full-canvas blit, so the map keeps all 240x320 and the panels are
/// drawn on top of it.
let hud_h : Int32 = 30

///|
let notice_h : Int32 = 18

///|
let bank_columns : Int32 = 6

///|
let atlas_mask : Int32 = 0xFFF

///|
let bank_none : Int32 = 255

///|
/// Text is 12px for body copy and 10px for the dense HUD; Skia shapes a run with
/// no wrapping (`renderer_text.mbt` clips it to `run.frame`), so line breaks are
/// produced here and one `TextRun` is submitted per line.
let body_size : Double = 12.0

///|
let small_size : Double = 10.0

///|
let line_units : Int32 = 34

///|
pub fn text_at(index : Int32) -> String {
  if index >= 0 && index < string_pool.length() {
    string_pool[index]
  } else {
    "?"
  }
}

///|
fn shade(r : Int32, g : Int32, b : Int32) -> @graphics.Color {
  @graphics.Color::rgba(
    r=r.to_double() / 255.0,
    g=g.to_double() / 255.0,
    b=b.to_double() / 255.0,
  )
}

///|
let ink_dark : @graphics.Color = shade(10, 12, 16)

///|
let ink_panel : @graphics.Color = shade(20, 24, 32)

///|
let ink_edge : @graphics.Color = shade(92, 108, 128)

///|
let ink_text : @graphics.Color = shade(226, 232, 240)

///|
let ink_muted : @graphics.Color = shade(150, 160, 172)

///|
let ink_hp : @graphics.Color = shade(196, 72, 64)

///|
let ink_mp : @graphics.Color = shade(72, 132, 200)

///|
let ink_cursor : @graphics.Color = shade(232, 196, 96)

///|
fn rect_at(
  ox : Double,
  oy : Double,
  x : Int32,
  y : Int32,
  w : Int32,
  h : Int32,
) -> @geometry.Rect {
  @geometry.Rect::new(
    x=ox + x.to_double(),
    y=oy + y.to_double(),
    width=w.to_double(),
    height=h.to_double(),
  )
}

///|
fn say(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  x : Int32,
  y : Int32,
  w : Int32,
  text : String,
  size : Double,
  color : @graphics.Color,
) -> Unit {
  draw_text(
    ctx,
    @text.TextRun::new(
      text~,
      frame=rect_at(ox, oy, x, y, w, (size + 4.0).to_int()),
      font=@text.FontSpec::new(size~),
      color~,
      align=TextStart,
    ),
  )
}

///|
/// Half-width units: a CJK glyph (or full-width punctuation) counts two, anything
/// below U+2000 counts one.  At `size` px the advance is roughly `size / 2` per
/// unit, which is what the wrapping below assumes.
pub fn text_units(text : String) -> Int32 {
  let mut units = 0
  for ch in text {
    let width = if ch.to_int() >= 0x2000 { 2 } else { 1 }
    units = units + width
  }
  units
}

///|
/// Split a string into lines of at most `max_units` half-widths, keeping any
/// hard breaks the content already carries.
pub fn wrap_lines(text : String, max_units : Int32) -> Array[String] {
  let lines : Array[String] = []
  let mut chunk = ""
  let mut used = 0
  let flush = fn() {
    lines.push(chunk)
    chunk = ""
    used = 0
  }
  for ch in text {
    if ch == '\n' {
      flush()
    } else {
      let width = if ch.to_int() >= 0x2000 { 2 } else { 1 }
      if used + width > max_units && used > 0 {
        flush()
      }
      chunk = chunk + ch.to_string()
      used = used + width
    }
  }
  if used > 0 {
    flush()
  }
  lines
}

///|
/// `wrap_lines` at the dialog width, drawn one run per line.
fn say_wrapped(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  x : Int32,
  y : Int32,
  w : Int32,
  text : String,
  color : @graphics.Color,
) -> Unit {
  let mut row = y
  for line in wrap_lines(text, line_units) {
    say(ctx, ox, oy, x, row, w, line, body_size, color)
    row = row + 16
  }
}

///|
/// Atlas addressing straight out of the reversed map format: the low twelve bits
/// pick the cell, six cells per bank row.
pub fn atlas_src(id : Int32) -> @geometry.Rect {
  let cell = id & atlas_mask
  @geometry.Rect::new(
    x=(cell % bank_columns * tile_size).to_double(),
    y=(cell / bank_columns * tile_size).to_double(),
    width=tile_size.to_double(),
    height=tile_size.to_double(),
  )
}

///|
pub fn bank_source(bank : Int32) -> String {
  if bank == 0 {
    BANK_GROUND_URI
  } else {
    BANK_OBJECT_URI
  }
}

///|
/// The per-cell 2-bit transform, rotated about the centre of the destination cell.
/// `Transform2D` maps `(x, y)` to `(a x + c y + tx, b x + d y + ty)`, so keeping the
/// centre fixed is `t = centre - M(centre)`.
pub fn tile_transform(
  flag : Int32,
  cell_x : Double,
  cell_y : Double,
) -> @graphics.Transform2D {
  let half = (tile_size / 2).to_double()
  let cx = cell_x + half
  let cy = cell_y + half
  let (a, b, c, d) = if flag == trans_rot90_cw {
    (0.0, 1.0, -1.0, 0.0)
  } else if flag == trans_rot180 {
    (-1.0, 0.0, 0.0, -1.0)
  } else if flag == trans_rot90_ccw {
    (0.0, -1.0, 1.0, 0.0)
  } else {
    (1.0, 0.0, 0.0, 1.0)
  }
  @graphics.Transform2D::{
    a,
    b,
    c,
    d,
    tx: cx - (a * cx + c * cy),
    ty: cy - (b * cx + d * cy),
  }
}

///|
fn paint_map(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
) -> Unit {
  let world = model.vm.world
  let map = world.map_of()
  let (cx, cy) = world.camera()
  let drawn = map.tiles.length() - 1
  let first_col = cx / tile_size
  let last_col = if map.width < 1 {
    0
  } else {
    let span = (cx + view_w + tile_size - 1) / tile_size
    if span > map.width {
      map.width
    } else {
      span
    }
  }
  let first_row = cy / tile_size
  let last_row = if map.height < 1 {
    0
  } else {
    let span = (cy + view_h + tile_size - 1) / tile_size
    if span > map.height {
      map.height
    } else {
      span
    }
  }
  push_clip(ctx, rect_at(ox, oy, 0, 0, view_w, view_h))
  fill_rect(ctx, rect_at(ox, oy, 0, 0, view_w, view_h), ink_dark)
  for layer = 0; layer < drawn; layer = layer + 1 {
    let bank = map.tilesets[layer]
    if bank == bank_none {
      // The collision layer is a tile array of solid/open codes, never art.
      continue
    }
    let source = bank_source(bank)
    let ids = map.tiles[layer]
    let codes = map.flags[layer]
    for row = first_row; row < last_row; row = row + 1 {
      for col = first_col; col < last_col; col = col + 1 {
        let index = row * map.width + col
        let id = ids[index]
        if id < 0 {
          continue
        }
        let cell = rect_at(
          ox,
          oy,
          col * tile_size - cx,
          row * tile_size - cy,
          tile_size,
          tile_size,
        )
        let run : @graphics.ImageRun = {
          source,
          frame: cell,
          src_rect: Some(atlas_src(id)),
          opacity: 1.0,
          fit: Contain,
        }
        let flag = codes[index]
        if flag == trans_none {
          draw_image(ctx, run)
        } else {
          push_transform(
            ctx,
            tile_transform(flag, cell.origin.x, cell.origin.y),
          )
          draw_image(ctx, run)
          pop_transform(ctx)
        }
      }
    }
  }
  pop_clip(ctx)
}

///|
/// One atlas cell of an animation record at `x`/`y`, with the record's own step
/// nudge applied.  Sizes come from the record, so a 16x24 character and a 32x32
/// monster both land at 1:1 -- the Skia image path samples linearly, so nothing is
/// scaled up here.
fn blit_frame(
  ctx : @views.PaintContext,
  source : String,
  record : AnimRecord,
  state : Int32,
  tick : Int32,
  x : Double,
  y : Double,
) -> Unit {
  let step = record.entry(state, tick)
  let (sx, sy, sw, sh) = record.rect(step.rect_index)
  draw_image(ctx, {
    source,
    frame: @geometry.Rect::new(
      x=x + step.dx.to_double(),
      y=y + step.dy.to_double(),
      width=sw.to_double(),
      height=sh.to_double(),
    ),
    src_rect: Some(
      @geometry.Rect::new(
        x=sx.to_double(),
        y=sy.to_double(),
        width=sw.to_double(),
        height=sh.to_double(),
      ),
    ),
    opacity: 1.0,
    fit: Contain,
  })
}

///|
/// Painter's order over the present sprites: a sprite further down the map is
/// drawn later, so it stands in front of the ones behind it.
fn present_sorted(world : World) -> Array[Sprite] {
  let out : Array[Sprite] = []
  for sprite in world.present() {
    out.push(sprite)
    let mut j = out.length() - 1
    while j > 0 && out[j - 1].y > out[j].y {
      let above = out[j - 1]
      out[j - 1] = out[j]
      out[j] = above
      j = j - 1
    }
  }
  out
}

///|
fn paint_sprites(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
) -> Unit {
  let world = model.vm.world
  let cart = model.vm.cart()
  let (cx, cy) = world.camera()
  push_clip(ctx, rect_at(ox, oy, 0, 0, view_w, view_h))
  for sprite in present_sorted(world) {
    let record = match cart.anim(sprite.anim) {
      None => continue
      Some(record) => record
    }
    let x = ox + (sprite.x - cx).to_double()
    let y = oy + (sprite.y - cy).to_double()
    if x + 32.0 < ox ||
      y + 32.0 < oy ||
      x > ox + view_w.to_double() ||
      y > oy + view_h.to_double() {
      continue
    }
    blit_frame(
      ctx,
      sheet_source(sprite.sheet),
      record,
      sprite.state(record),
      sprite.tick,
      x,
      y,
    )
  }
  pop_clip(ctx)
}

///|
/// The hero roster card row.  `tbl_combatant` column 1 is a string id, so the name
/// is read through the cartridge rather than stored on the fighter.
fn paint_hud(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
) -> Unit {
  let vm = model.vm
  let cart = vm.cart()
  fill_rect(ctx, rect_at(ox, oy, 0, 0, view_w, hud_h), ink_panel)
  stroke_rect(ctx, rect_at(ox, oy, 0, 0, view_w, hud_h), ink_edge, 1.0)
  for index = 0; index < vm.party.length(); index = index + 1 {
    let fighter = vm.party[index]
    let left = 3 + index * 78
    let name = text_at(cart.combatant.cell(fighter.row, c_name))
    say(ctx, ox, oy, left, 1, 76, name, small_size, ink_text)
    bar(ctx, ox, oy, left, 12, 66, fighter.hp, fighter.hp_max, ink_hp)
    bar(ctx, ox, oy, left, 20, 66, fighter.mp, fighter.mp_max, ink_mp)
  }
}

///|
fn bar(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  x : Int32,
  y : Int32,
  w : Int32,
  value : Int32,
  total : Int32,
  color : @graphics.Color,
) -> Unit {
  fill_rect(ctx, rect_at(ox, oy, x, y, w, 5), ink_dark)
  let span = if total <= 0 {
    0
  } else if value >= total {
    w
  } else if value <= 0 {
    0
  } else {
    w * value / total
  }
  fill_rect(ctx, rect_at(ox, oy, x, y, span, 5), color)
}

///|
fn paint_notice(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
) -> Unit {
  let y = view_h - notice_h
  fill_rect(ctx, rect_at(ox, oy, 0, y, view_w, notice_h), ink_panel)
  let left = if model.notice == "" {
    text_at(model.vm.world.map)
  } else {
    model.notice
  }
  say(ctx, ox, oy, 4, y + 3, 170, left, small_size, ink_muted)
  let gold = "铜钱 " + model.vm.money_at(0).to_string()
  say(ctx, ox, oy, 178, y + 3, 58, gold, small_size, ink_cursor)
}

///|
/// The portrait bank does not exist in this content, so the talking head is the
/// speaker's own standing cell, read at 1:1 from the walk sheet.  Which sheet and
/// record a portrait id uses is the slice's mapping.
fn portrait_parts(id : Int32) -> (Int32, Int32) {
  if id <= 0 {
    (0, 2)
  } else if id <= 3 {
    (1, 1)
  } else {
    (2, 3)
  }
}

///|
fn paint_portrait(
  ctx : @views.PaintContext,
  model : Model,
  id : Int32,
  pose : Int32,
  x : Int32,
  y : Int32,
) -> Unit {
  let (sheet, anim) = portrait_parts(id)
  let record = match model.vm.cart().anim(anim) {
    None => return
    Some(record) => record
  }
  let state = if pose < 0 {
    0
  } else if pose >= engine_dirs {
    engine_dirs - 1
  } else {
    pose
  }
  blit_frame(
    ctx,
    sheet_source(sheet),
    record,
    state,
    0,
    x.to_double(),
    y.to_double(),
  )
}

///|
fn panel(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  y : Int32,
  h : Int32,
) -> Unit {
  fill_rect(ctx, rect_at(ox, oy, 0, y, view_w, h), ink_panel)
  stroke_rect(ctx, rect_at(ox, oy, 0, y, view_w, h), ink_edge, 1.0)
}

///|
fn paint_dialog(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
) -> Unit {
  let ui = model.vm.ui
  let top = view_h - 96
  panel(ctx, ox, oy, top, 78)
  paint_portrait(ctx, model, ui.portrait, ui.pose, 6, top + 4)
  say(ctx, ox, oy, 30, top + 3, 120, text_at(ui.name), small_size, ink_cursor)
  // `dC`/`dD` (layout_a/layout_b) are not established in the reverse notes, so the
  // box keeps one fixed geometry instead of guessing at their meaning.
  say_wrapped(ctx, ox, oy, 30, top + 18, 200, text_at(ui.body), ink_text)
  say(ctx, ox, oy, 210, top + 60, 20, "▼", body_size, ink_cursor)
}

///|
fn paint_choice(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
) -> Unit {
  let ui = model.vm.ui
  let rows = if ui.option_count < 0 {
    0
  } else if ui.option_count > 5 {
    5
  } else {
    ui.option_count
  }
  let top = view_h - 78 - rows * 16
  panel(ctx, ox, oy, top, 62 + rows * 16)
  say_wrapped(ctx, ox, oy, 8, top + 4, 220, text_at(ui.body), ink_text)
  for row = 0; row < rows; row = row + 1 {
    let picked = row == model.panel.cursor
    let mark = if picked { "》" } else { "  " }
    say(
      ctx,
      ox,
      oy,
      16,
      top + 24 + row * 16,
      200,
      mark + text_at(ui.options[row]),
      body_size,
      if picked {
        ink_cursor
      } else {
        ink_text
      },
    )
  }
}

///|
fn paint_message(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
) -> Unit {
  let ui = model.vm.ui
  let lines = wrap_lines(text_at(ui.body), line_units)
  let height = 12 + lines.length() * 15
  // `db3`/`db4` are the original's strip position operands, whose exact frame is
  // not established; the slice reads them as an 8px offset from the strip's home.
  let top = view_h - 96 - ui.text_y * 8
  let left = ui.text_x * 8
  panel(ctx, ox, oy, top, height)
  let mut row = 3
  for line in lines {
    say(ctx, ox, oy, left + 8, top + row, 220 - left, line, body_size, ink_text)
    row = row + 15
  }
  if ui.bold {
    stroke_rect(
      ctx,
      rect_at(ox, oy, left + 4, top + 1, 230 - left, height - 3),
      ink_cursor,
      1.0,
    )
  }
}

///|
fn paint_title(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
) -> Unit {
  draw_image(ctx, {
    source: BG_TITLE_URI,
    frame: rect_at(ox, oy, 0, 0, view_w, view_h),
    src_rect: None,
    opacity: 1.0,
    fit: Stretch,
  })
  fill_rect(ctx, rect_at(ox, oy, 0, 120, view_w, 60), ink_panel)
  say(ctx, ox, oy, 12, 128, 216, text_at(model.vm.ui.body), 18.0, ink_cursor)
  say(ctx, ox, oy, 12, 152, 216, "按 确认键 开始", small_size, ink_text)
  let _ = model.vm.ui.pose
}

///|
fn paint_game_over(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  _model : Model,
) -> Unit {
  fill_rect(ctx, rect_at(ox, oy, 0, 0, view_w, view_h), shade(6, 4, 6))
  say(ctx, ox, oy, 12, 132, 216, text_at(50), 18.0, ink_hp)
  say(
    ctx, ox, oy, 12, 160, 216, "按 确认键 重新开始", small_size, ink_muted,
  )
}

///|
/// Action rows, in the order the arrow keys walk them.  There is no flee: the
/// content reads `bQ[V_BATTLE_RESULT]` as win-or-game-over, so a fled battle would
/// have no result the scripts could carry.
pub let atk_attack : Int32 = 0

///|
pub let atk_skill : Int32 = 1

///|
pub let atk_item : Int32 = 2

///|
pub let action_count : Int32 = 3

///|
fn action_name(row : Int32) -> String {
  if row == atk_attack {
    "攻击"
  } else if row == atk_skill {
    "法术"
  } else {
    "物品"
  }
}

///|
fn paint_battle(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
) -> Unit {
  draw_image(ctx, {
    source: BG_BATTLE_URI,
    frame: rect_at(ox, oy, 0, 0, view_w, view_h),
    src_rect: None,
    opacity: 1.0,
    fit: Stretch,
  })
  match model.vm.battle {
    None => ()
    Some(arena) => {
      let cart = model.vm.cart()
      paint_units(ctx, ox, oy, model, arena, cart, side_enemy, 26, 78)
      paint_units(ctx, ox, oy, model, arena, cart, side_party, 150, 214)
      paint_battle_panel(ctx, ox, oy, model, arena, cart)
    }
  }
}

///|
/// One side of the arena.  A combatant's own `sheet`/`anim` columns drive the blit,
/// so a monster animates from the monster sheet through the same timeline reader
/// the map uses; the facing is fixed (down for the party's opponents, right for the
/// party) because the slice has no per-unit battle direction table.
fn paint_units(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
  arena : Battle,
  cart : Cartridge,
  side : Int32,
  y : Int32,
  name_y : Int32,
) -> Unit {
  let mut slot = 0
  for index = 0; index < arena.unit_count(); index = index + 1 {
    if arena.side(index) != side {
      continue
    }
    let fighter = arena.unit(index)
    if !fighter.is_alive() {
      slot = slot + 1
      continue
    }
    let sheet = cart.combatant.cell(fighter.row, c_sheet)
    let anim_id = cart.combatant.cell(fighter.row, c_anim)
    let record = match cart.anim(anim_id) {
      None => continue
      Some(record) => record
    }
    let state = if side == side_enemy { 2 } else { 1 }
    let x = if side == side_enemy { 24 + slot * 56 } else { 16 + slot * 46 }
    blit_frame(
      ctx,
      sheet_source(sheet),
      record,
      state,
      model.vm.frame,
      x.to_double(),
      y.to_double(),
    )
    say(
      ctx,
      ox,
      oy,
      x,
      name_y,
      52,
      text_at(cart.combatant.cell(fighter.row, c_name)),
      small_size,
      ink_text,
    )
    bar(ctx, ox, oy, x, name_y + 12, 46, fighter.hp, fighter.hp_max, ink_hp)
    if side == side_party {
      bar(ctx, ox, oy, x, name_y + 18, 46, fighter.mp, fighter.mp_max, ink_mp)
    }
    if index == current_target(model) {
      stroke_rect(ctx, rect_at(ox, oy, x - 2, y - 2, 36, 36), ink_cursor, 1.0)
    }
    slot = slot + 1
  }
}

///|
fn current_target(model : Model) -> Int32 {
  let list = target_candidates(model)
  let at = model.panel.target
  if at >= 0 && at < list.length() {
    list[at]
  } else {
    -1
  }
}

///|
fn paint_battle_panel(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  model : Model,
  arena : Battle,
  cart : Cartridge,
) -> Unit {
  let panel_top = 250
  panel(ctx, ox, oy, panel_top, 52)
  let stage = model.panel.stage
  if stage == bs_menu {
    for row = 0; row < action_count; row = row + 1 {
      let picked = row == model.panel.cursor
      say(
        ctx,
        ox,
        oy,
        12 + row * 60,
        panel_top + 6,
        56,
        action_name(row),
        body_size,
        if picked {
          ink_cursor
        } else {
          ink_text
        },
      )
    }
    say(
      ctx,
      ox,
      oy,
      12,
      panel_top + 26,
      220,
      "方向键选择 确认键确定",
      small_size,
      ink_muted,
    )
  } else if stage == bs_slot {
    paint_slot_list(ctx, ox, oy, panel_top, model, cart)
  } else if stage == bs_target {
    say(
      ctx,
      ox,
      oy,
      12,
      panel_top + 6,
      220,
      "选择目标",
      body_size,
      ink_cursor,
    )
    say(
      ctx,
      ox,
      oy,
      12,
      panel_top + 26,
      220,
      "左右键移动 确认键出手",
      small_size,
      ink_muted,
    )
  } else {
    let lines = wrap_lines(model.panel.log, line_units)
    let mut row = 4
    for line in lines {
      say(ctx, ox, oy, 12, panel_top + row, 220, line, body_size, ink_text)
      row = row + 15
    }
    if stage == bs_line {
      say(ctx, ox, oy, 200, panel_top + 34, 30, "确认", small_size, ink_muted)
    }
    let _ = arena
  }
}

///|
fn slot_rows(model : Model, cart : Cartridge) -> Array[Int32] {
  if model.panel.action == atk_skill {
    let rows : Array[Int32] = []
    for row = 0; row < cart.skill.rows; row = row + 1 {
      rows.push(row)
    }
    rows
  } else {
    let rows : Array[Int32] = []
    for row = 0; row < cart.item.rows; row = row + 1 {
      if model.vm.item_count(row) > 0 {
        rows.push(row)
      }
    }
    rows
  }
}

///|
fn paint_slot_list(
  ctx : @views.PaintContext,
  ox : Double,
  oy : Double,
  panel_top : Int32,
  model : Model,
  cart : Cartridge,
) -> Unit {
  let rows = slot_rows(model, cart)
  if rows.length() == 0 {
    say(
      ctx,
      ox,
      oy,
      12,
      panel_top + 6,
      220,
      "没有可用的。",
      body_size,
      ink_muted,
    )
    return
  }
  for at = 0; at < 4 && at < rows.length(); at = at + 1 {
    let row = rows[at]
    let picked = at == model.panel.cursor
    let mark = if picked { "》" } else { "  " }
    let tail = if model.panel.action == atk_skill {
      " 灵" + cart.skill.cell(row, s_mp).to_string()
    } else {
      " x" + model.vm.item_count(row).to_string()
    }
    let name = if model.panel.action == atk_skill {
      text_at(cart.skill.cell(row, 1))
    } else {
      text_at(cart.item.cell(row, 1))
    }
    say(
      ctx,
      ox,
      oy,
      12,
      panel_top + 4 + at * 13,
      210,
      mark + name + tail,
      small_size,
      ink_text,
    )
  }
}

///|
pub fn paint_screen(
  ctx : @views.PaintContext,
  frame : @geometry.Rect,
  model : Model,
) -> Unit {
  let ox = frame.origin.x
  let oy = frame.origin.y
  fill_rect(ctx, frame, ink_dark)
  paint_map(ctx, ox, oy, model)
  paint_sprites(ctx, ox, oy, model)
  paint_hud(ctx, ox, oy, model)
  paint_notice(ctx, ox, oy, model)
  let ui = model.vm.ui
  if !ui.active || ui.kind == ov_idle {
    ()
  } else if ui.kind == ov_title {
    paint_title(ctx, ox, oy, model)
  } else if ui.kind == ov_dialog {
    paint_dialog(ctx, ox, oy, model)
  } else if ui.kind == ov_choice {
    paint_choice(ctx, ox, oy, model)
  } else if ui.kind == ov_message {
    paint_message(ctx, ox, oy, model)
  } else if ui.kind == ov_battle {
    paint_battle(ctx, ox, oy, model)
  } else {
    paint_game_over(ctx, ox, oy, model)
  }
}
