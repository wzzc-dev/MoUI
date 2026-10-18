///|
/// Scenario rendering: translate a scenario into `DrawCommand`s on a `canvas`.
///
/// The canvas is renderer-neutral, so the same translation runs on Skia, WGPU,
/// Sun, and the web renderers. Only draw commands are emitted — no renderer
/// API, no platform handle, no image decode.
///
/// The `using @views` block lives in `view.mbt`; this file reaches the paint
/// helpers through the same package-scoped names.

///|
/// Fill the scenario map into `ctx`, clipped to `frame`.
///
/// The canvas view's draw callback paints in **canvas-global** coordinates:
/// `frame` is the map view's rect in the app frame, not a (0,0)-anchored local
/// rect. Everything this function emits is therefore offset by `frame.origin`.
/// `origin` (pan) is the map-space point that maps to the frame's top-left
/// corner, so panning is a pure translation and needs no re-layout.
pub fn draw_scenario(
  ctx : PaintContext,
  frame : @geometry.Rect,
  scenario : Scenario,
  origin : @geometry.Point,
  selected : String?,
) -> Unit {
  // No `clear` here: a Clear command resets the whole canvas surface, which
  // would erase every view drawn before this one. Paint the map's background
  // over its own frame only.
  fill_rounded_rect(
    ctx,
    @graphics.RoundedRect::new(rect=frame, radius=8.0),
    @graphics.Brush::solid(@graphics.Color::rgba(r=0.06, g=0.07, b=0.10)),
  )
  push_clip(ctx, frame)
  // Map space → canvas space: add the frame origin, subtract the pan origin.
  let base = @geometry.Point::new(
    x=frame.origin.x - origin.x,
    y=frame.origin.y - origin.y,
  )
  // The room floor, then each location as a labelled block.
  let floor = @geometry.Rect::new(
    x=base.x,
    y=base.y,
    width=scenario.map_width(),
    height=scenario.map_height(),
  )
  fill_rounded_rect(
    ctx,
    @graphics.RoundedRect::new(rect=floor, radius=8.0),
    @graphics.Brush::solid(@graphics.Color::rgba(r=0.13, g=0.11, b=0.10)),
  )
  for place in scenario.locations() {
    let highlighted = selected_place_for(selected, scenario, place.id())
    draw_location(ctx, place, base, highlighted)
  }
  for card in scenario.characters() {
    draw_character(ctx, card, scenario, base, selected)
  }
  pop_clip(ctx)
}

///|
fn selected_place_for(
  selected : String?,
  scenario : Scenario,
  place_id : String,
) -> Bool {
  match selected {
    Some(character_id) =>
      match scenario.character(character_id) {
        Some(card) => card.location() == place_id
        None => false
      }
    None => false
  }
}

///|
fn draw_location(
  ctx : PaintContext,
  place : ScenarioLocation,
  base : @geometry.Point,
  highlighted : Bool,
) -> Unit {
  let rect = @geometry.Rect::new(
    x=place.rect().origin.x + base.x,
    y=place.rect().origin.y + base.y,
    width=place.rect().size.width,
    height=place.rect().size.height,
  )
  let fill = if highlighted {
    @graphics.Color::rgba(r=0.26, g=0.22, b=0.18)
  } else {
    @graphics.Color::rgba(r=0.19, g=0.17, b=0.15)
  }
  fill_rounded_rect(
    ctx,
    @graphics.RoundedRect::new(rect~, radius=6.0),
    @graphics.Brush::solid(fill),
  )
  stroke_rounded_rect(
    ctx,
    @graphics.RoundedRect::new(rect~, radius=6.0),
    @graphics.Brush::solid(
      if highlighted {
        @graphics.Color::rgba(r=0.85, g=0.72, b=0.45)
      } else {
        @graphics.Color::rgba(r=0.34, g=0.30, b=0.27)
      },
    ),
    1.0,
  )
  // The place name, clipped to its own block so a long name cannot spill onto
  // a neighbour.
  let label = @geometry.Rect::new(
    x=rect.origin.x + 8.0,
    y=rect.origin.y + 8.0,
    width=rect.size.width - 16.0,
    height=20.0,
  )
  draw_text(
    ctx,
    @text.TextRun::new(
      text=place.name(),
      frame=label,
      font=@text.FontSpec::new(size=13.0),
      color=@graphics.Color::rgba(r=0.88, g=0.84, b=0.78),
      align=@text.TextAlign::TextStart,
    ),
  )
}

///|
fn draw_character(
  ctx : PaintContext,
  card : CharacterCard,
  scenario : Scenario,
  base : @geometry.Point,
  selected : String?,
) -> Unit {
  let point = match scenario.character_point(card.id()) {
    Some(value) => value
    None => return
  }
  let center = @geometry.Point::new(x=point.x + base.x, y=point.y + base.y)
  let radius = 11.0
  if selected is Some(id) && id == card.id() {
    // A selection ring, drawn under the disc so it reads as a halo.
    let ring = @geometry.Rect::new(
      x=center.x - radius - 4.0,
      y=center.y - radius - 4.0,
      width=(radius + 4.0) * 2.0,
      height=(radius + 4.0) * 2.0,
    )
    fill_rounded_rect(
      ctx,
      @graphics.RoundedRect::new(rect=ring, radius=radius + 4.0),
      @graphics.Brush::solid(
        @graphics.Color::rgba(r=0.95, g=0.85, b=0.35, a=0.85),
      ),
    )
  }
  let disc = @geometry.Rect::new(
    x=center.x - radius,
    y=center.y - radius,
    width=radius * 2.0,
    height=radius * 2.0,
  )
  fill_rounded_rect(
    ctx,
    @graphics.RoundedRect::new(rect=disc, radius~),
    @graphics.Brush::solid(card.color()),
  )
  // Name plate under the marker, so the map reads without hovering.
  let plate = @geometry.Rect::new(
    x=center.x - 60.0,
    y=center.y + radius + 2.0,
    width=120.0,
    height=18.0,
  )
  draw_text(
    ctx,
    @text.TextRun::new(
      text=card.name(),
      frame=plate,
      font=@text.FontSpec::new(size=12.0),
      color=@graphics.Color::rgba(r=0.92, g=0.90, b=0.86),
      align=@text.TextAlign::TextCenter,
    ),
  )
}

///|
/// Hit-test a pointer position against the map, returning the character whose
/// marker was clicked. Called with view-local coordinates.
pub fn character_at(
  scenario : Scenario,
  origin : @geometry.Point,
  position : @geometry.Point,
) -> String? {
  let world = @geometry.Point::new(
    x=position.x + origin.x,
    y=position.y + origin.y,
  )
  for card in scenario.characters() {
    let point = match scenario.character_point(card.id()) {
      Some(value) => value
      None => continue
    }
    let dx = world.x - point.x
    let dy = world.y - point.y
    if dx * dx + dy * dy <= 15.0 * 15.0 {
      return Some(card.id())
    }
  }
  None
}

///|
/// Hit-test a pointer position against the map's places, returning the location
/// whose rect contains it. Called with view-local coordinates.
///
/// Places are tested after characters (see `view.mbt`): tapping a person must
/// win over tapping the room they stand in, or selecting anyone inside a
/// building would open the scene instead.
pub fn location_at(
  scenario : Scenario,
  origin : @geometry.Point,
  position : @geometry.Point,
) -> String? {
  let world = @geometry.Point::new(
    x=position.x + origin.x,
    y=position.y + origin.y,
  )
  for place in scenario.locations() {
    let rect = place.rect()
    if world.x >= rect.origin.x &&
      world.x <= rect.origin.x + rect.size.width &&
      world.y >= rect.origin.y &&
      world.y <= rect.origin.y + rect.size.height {
      return Some(place.id())
    }
  }
  None
}
