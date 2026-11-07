///|
/// The default swatch ramp: a fixed, theme-independent spectrum so the
/// picker's evidence is stable across themes.
pub fn color_picker_default_swatches() -> Array[@core.Color] {
  [
    @core.Color::rgba(r=0.86, g=0.27, b=0.24),
    @core.Color::rgba(r=0.91, g=0.45, b=0.20),
    @core.Color::rgba(r=0.98, g=0.74, b=0.18),
    @core.Color::rgba(r=0.65, g=0.75, b=0.24),
    @core.Color::rgba(r=0.30, g=0.69, b=0.31),
    @core.Color::rgba(r=0.20, g=0.65, b=0.45),
    @core.Color::rgba(r=0.20, g=0.60, b=0.73),
    @core.Color::rgba(r=0.12, g=0.36, b=0.95),
    @core.Color::rgba(r=0.42, g=0.36, b=0.85),
    @core.Color::rgba(r=0.61, g=0.15, b=0.67),
    @core.Color::rgba(r=0.85, g=0.25, b=0.55),
    @core.Color::rgba(r=0.45, g=0.28, b=0.20),
    @core.Color::rgba(r=0.42, g=0.45, b=0.50),
    @core.Color::rgba(r=0.62, g=0.66, b=0.70),
    @core.Color::rgba(r=0.30, g=0.32, b=0.36),
    @core.Color::rgba(r=0.10, g=0.12, b=0.16),
  ]
}

///|
/// Lowercase hex text for a color's opaque channels, the swatch's accessible
/// description: `#rrggbb`.
fn color_picker_hex(color : @core.Color) -> String {
  fn digit(d : Int32) -> String {
    // The digit is constructed 0..15, always a valid code point.
    let code : Int32 = if d < 10 { 48 + d } else { 87 + d }
    String::from_array([code.unsafe_to_char()])
  }

  fn channel(v : Double) -> String {
    let scaled = (v * 255.0).round().clamp(min=0.0, max=255.0).to_int()
    digit(scaled / 16) + digit(scaled % 16)
  }

  "#" + channel(color.r) + channel(color.g) + channel(color.b)
}

///|
/// Concrete view node for the `color_picker` control: a grid of swatch
/// children, laid out `columns` per row with a fixed gap, each swatch a
/// rounded square of the derived size.
priv struct ColorPicker {
  selected : @core.Color
  swatches : Array[@core.Color]
  columns : Int32
  swatch_size : Double
  gap : Double
  width : Double
}

///|
impl @core.ViewNode for ColorPicker with fn identity(_self) {
  @core.ViewIdentity::new(kind="ColorPicker")
}

///|
impl @core.ViewNode for ColorPicker with fn child_constraints(
  _self,
  constraints,
) {
  constraints
}

///|
fn color_picker_swatch_size(
  width~ : Double,
  columns~ : Int32,
  gap~ : Double,
) -> Double {
  let count = if columns < 1 { 1 } else { columns }
  ((width - gap * (count - 1).to_double()) / count.to_double()).max(1.0)
}

///|
fn color_picker_rows(count~ : Int32, columns~ : Int32) -> Int32 {
  let resolved = if columns < 1 { 1 } else { columns }
  (count + resolved - 1) / resolved
}

///|
impl @core.ViewNode for ColorPicker with fn layout(self, ctx) {
  let columns = if self.columns < 1 { 1 } else { self.columns }
  let count = self.swatches.length()
  let rows = color_picker_rows(count~, columns~)
  let size = ctx.constraints.constrain(
    @core.Size::new(
      width=self.width,
      height=rows.to_double() * self.swatch_size +
        (rows - 1).to_double().max(0.0) * self.gap,
    ),
  )
  let frames : Array[@core.Rect] = []
  for index in 0..<count {
    let column = index % columns
    let row = index / columns
    frames.push(
      @core.Rect::new(
        x=column.to_double() * (self.swatch_size + self.gap),
        y=row.to_double() * (self.swatch_size + self.gap),
        width=self.swatch_size,
        height=self.swatch_size,
      ),
    )
  }
  @core.ViewLayoutResult::new(size~, child_frames=frames)
}

///|
impl @core.ViewNode for ColorPicker with fn semantics(_self) {
  @core.ViewSemanticsInfo::container(
    composition=Boundary,
    role=Group,
    value="color picker",
  )
}

///|
/// A swatch's ring must contrast the swatch color itself (not the surface):
/// light colors ring dark, dark colors ring white. The selection widens the
/// ring; the semantics `selected` state carries the rest.
fn color_picker_ring_color(color : @core.Color) -> @core.Color {
  let luminance = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
  if luminance > 0.6 {
    @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.55)
  } else {
    @core.Color::rgba(r=1.0, g=1.0, b=1.0, a=0.9)
  }
}

///|
/// One swatch: a rounded square filled with its color, a contrast ring that
/// widens when it is the selection, a tap message, and button semantics
/// carrying the selection state and the hex description.
fn[Msg] color_picker_swatch(
  color : @core.Color,
  selected~ : Bool,
  size~ : Double,
  on_change~ : (@core.Color) -> Msg,
) -> @core.View[Msg] {
  @container.container(
    @container.empty(),
    width=size,
    height=size,
    background=color,
    corner_radius=size / 4.0,
    border=Some(@core.BorderStyle::{
      brush: @core.Brush::Solid(color_picker_ring_color(color)),
      width: if selected {
        3.0
      } else {
        1.0
      },
    }),
  )
  .on_tap_with_frame((_point, _frame) => on_change(color))
  .semantics_role(Button)
  .semantics_selected(selected~)
  .semantics_description(color_picker_hex(color))
}

///|
/// A color swatch grid: the app owns the selected color and the swatch ramp,
/// each swatch reports itself through `on_change` when tapped, and the
/// selection renders a ring with per-swatch button semantics carrying the
/// hex description. A full hue/saturation field is follow-up work; this slice
/// is the token-grid picker design systems use for named colors.
pub fn[Msg] color_picker(
  selected~ : @core.Color,
  on_change~ : (@core.Color) -> Msg,
  swatches~ : Array[@core.Color] = color_picker_default_swatches(),
  columns~ : Int32 = 8,
  width~ : Double = 272.0,
) -> @core.View[Msg] {
  let resolved_columns = if columns < 1 { 1 } else { columns }
  let gap = 8.0
  let swatch_size = color_picker_swatch_size(
    width~,
    columns=resolved_columns,
    gap~,
  )
  @core.View::from_node(
    ColorPicker::{
      selected,
      swatches,
      columns: resolved_columns,
      swatch_size,
      gap,
      width,
    },
    children=node => {
      let views : Array[@core.View[Msg]] = []
      for color in node.swatches {
        views.push(
          color_picker_swatch(
            color,
            selected=color == node.selected,
            size=node.swatch_size,
            on_change~,
          ),
        )
      }
      views
    },
  )
}
