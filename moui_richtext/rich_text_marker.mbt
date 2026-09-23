///|
/// Vector markers for block prefix lanes.
///
/// A task list item's marker is geometry, not text: the box, its border, and
/// the checkmark are drawn from `DrawCommand`s so the shape, weight, and color
/// are identical on every host and font. The lane still holds one placeholder
/// character, so caret, selection, and hit-test arithmetic stay
/// character-indexed; only the painted and measured lane width changes.

///|
/// Side of the marker square, in ems of the block font.
fn rich_text_marker_box_em() -> Double {
  1.0
}

///|
/// Painted width of a block's prefix lane. Marker blocks reserve the square
/// plus the label gap instead of the placeholder glyph's advance, so the label
/// column is the same on every font.
fn rich_text_block_marker_lane(
  block : RichTextBlock,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Double {
  match block.marker {
    Some(_) => font.size * 1.55
    None => rich_text_width(block.prefix, font, text_system)
  }
}

///|
/// Draw the marker inside `lane`, a rect whose origin is the prefix lane start
/// and whose height is the first visual line box. Text paints its first line
/// centered in that box (`skia_text_baseline_y`), so the marker centers on the
/// same line to sit optically with the label.
fn append_rich_text_marker_commands(
  commands : Array[@core.DrawCommand],
  marker : RichTextMarker,
  lane : @core.Rect,
  font : @core.FontSpec,
) -> Unit {
  match marker {
    TaskCheckbox(checked_) => {
      let side = font.size * rich_text_marker_box_em()
      let box = @core.Rect::new(
        x=lane.origin.x,
        y=lane.origin.y + (lane.size.height - side) / 2.0,
        width=side,
        height=side,
      )
      match checked_ {
        true => {
          let rounded = @core.RoundedRect::new(
            rect=box,
            radius=rich_text_marker_corner_radius(side),
          )
          commands.push(
            FillRoundedRect(rounded, rich_text_marker_accent_color()),
          )
          commands.push(DrawPath(rich_text_marker_checkmark_path(box, side)))
        }
        false => {
          // Inset by half the stroke so the outline stays inside the square.
          let stroke = rich_text_marker_border_width(side)
          let rounded = @core.RoundedRect::new(
            rect=@core.Rect::new(
              x=box.origin.x + stroke / 2.0,
              y=box.origin.y + stroke / 2.0,
              width=box.size.width - stroke,
              height=box.size.height - stroke,
            ),
            radius=rich_text_marker_corner_radius(side),
          )
          commands.push(
            StrokeRoundedRect(rounded, rich_text_marker_outline_color(), stroke),
          )
        }
      }
    }
  }
}

///|
/// Marker fill for the checked state. GitHub's accent blue, so the box reads
/// as the same control the app's own checkbox uses.
fn rich_text_marker_accent_color() -> @core.Color {
  @core.Color::rgba(r=0.122, g=0.435, b=0.922)
}

///|
/// Marker border for the unchecked state: a neutral gray that reads as a solid
/// empty slot rather than as faint body text.
fn rich_text_marker_outline_color() -> @core.Color {
  @core.Color::rgba(r=0.573, g=0.600, b=0.631)
}

///|
/// Box corner radius. Proportional to the square so every editor font size and
/// appearance (16.5pt to 18pt) keeps the same pill-ish silhouette.
fn rich_text_marker_corner_radius(side : Double) -> Double {
  side * 0.22
}

///|
/// Unchecked outline weight.
fn rich_text_marker_border_width(side : Double) -> Double {
  side * 0.11
}

///|
/// Filled checkmark polygon.
///
/// The mark is a filled six-point outline rather than a stroked polyline: the
/// path contract has no cap/join fields, so a stroke would render with butt
/// caps and a miter spike on some backends and a round join on others. Filling
/// the outline of the two strokes (plus the outer miter vertex at the elbow)
/// draws the same chunky, slightly rounded mark everywhere.
fn rich_text_marker_checkmark_path(
  box : @core.Rect,
  side : Double,
) -> @core.PathSpec {
  // Mark geometry in box-relative units: down-stroke to the elbow, then a
  // longer up-stroke to the tip.
  let start = @core.Point::new(
    x=box.origin.x + side * 0.25,
    y=box.origin.y + side * 0.53,
  )
  let elbow = @core.Point::new(
    x=box.origin.x + side * 0.43,
    y=box.origin.y + side * 0.70,
  )
  let tip = @core.Point::new(
    x=box.origin.x + side * 0.76,
    y=box.origin.y + side * 0.32,
  )
  let half = side * 0.085
  let (down_x, down_y) = rich_text_marker_unit_normal(start, elbow)
  let (up_x, up_y) = rich_text_marker_unit_normal(elbow, tip)
  let outer_start = @core.Point::new(
    x=start.x + down_x * half,
    y=start.y + down_y * half,
  )
  let outer_elbow = @core.Point::new(
    x=elbow.x + down_x * half,
    y=elbow.y + down_y * half,
  )
  let inner_elbow = @core.Point::new(
    x=elbow.x - down_x * half,
    y=elbow.y - down_y * half,
  )
  let inner_start = @core.Point::new(
    x=start.x - down_x * half,
    y=start.y - down_y * half,
  )
  let inner_tip = @core.Point::new(x=tip.x - up_x * half, y=tip.y - up_y * half)
  let outer_tip = @core.Point::new(x=tip.x + up_x * half, y=tip.y + up_y * half)
  let outer_join = @core.Point::new(
    x=elbow.x + up_x * half,
    y=elbow.y + up_y * half,
  )
  // Outer corner of the elbow: the two offset edges meet here, so the outline
  // needs this vertex or the elbow loses its point.
  let miter = @core.Point::new(
    x=(outer_elbow.x + outer_join.x) / 2.0 + up_x * half * 0.6,
    y=(outer_elbow.y + outer_join.y) / 2.0 + up_y * half * 0.6,
  )
  @core.PathSpec::new(
    verbs=[
      MoveTo(outer_start),
      LineTo(miter),
      LineTo(outer_tip),
      LineTo(inner_tip),
      LineTo(inner_elbow),
      LineTo(inner_start),
      Close,
    ],
    fill=Some(@core.Brush::solid(@core.Color::white())),
  )
}

///|
/// Unit normal of the segment `from` -> `to`, pointing away from the segment's
/// travel direction (used on both sides of the stroke by offsetting +/-).
fn rich_text_marker_unit_normal(
  from : @core.Point,
  to : @core.Point,
) -> (Double, Double) {
  let dx = to.x - from.x
  let dy = to.y - from.y
  let length = (dx * dx + dy * dy).sqrt()
  if length <= 0.0 {
    (0.0, 0.0)
  } else {
    (-dy / length, dx / length)
  }
}
