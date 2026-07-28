///|
/// Concrete view node for the `slider` control.
///
/// Carries only immutable declaration data: value, range, geometry, theme,
/// optional style, and optional foreground/background overrides. The node is
/// message-independent; `View::from_node` wires the typed `on_change` event
/// adapter. Its declaration keys capture every paint-affecting field (value,
/// range, geometry, style, and colors) so reconciliation cannot reuse stale
/// paint output when only a visual input changes.
///
/// The slider owns its pointer interaction directly: the event adapter
/// handles `Pointer` phases (`Down`/`Move`/`Up`) inside the rendered frame,
/// requests focus + capture on `Down`, and maps the pointer x to a clamped
/// `value` via `on_change`. This replaces the previous `on_drag_with_frame`
/// modifier wiring, which had two problems: (1) the slider had no focus/event
/// ownership of its own, and (2) the drag modifier also produced Button
/// semantics. The slider node reports `Slider` semantics directly and is the
/// sole owner of the pointer interaction.
priv struct Slider {
  value : Double
  min : Double
  max : Double
  width : Double
  height : Double
  theme : @core.Theme?
  style : SliderStyle?
  foreground : @core.Color?
  background : @core.Color?
  has_on_change : Bool
}

///|
impl @core.ViewNode for Slider with fn identity(_self) {
  @core.ViewIdentity::new(kind="Slider")
}

///|
impl @core.ViewNode for Slider with fn declaration(self) {
  let paint_key = view_record_key("Slider.paint", [
    ("value", @core.DeclarationKey::double(self.value)),
    ("min", @core.DeclarationKey::double(self.min)),
    ("max", @core.DeclarationKey::double(self.max)),
    (
      "style",
      @core.DeclarationKey::option(
        self.style.map(style => {
          view_record_key("SliderStyle", [
            ("foreground", view_color_key(style.foreground)),
            ("background", view_color_key(style.background)),
            ("thumb_color", view_color_key(style.thumb_color)),
            ("track_height", @core.DeclarationKey::double(style.track_height)),
            ("thumb_size", @core.DeclarationKey::double(style.thumb_size)),
            ("radius", @core.DeclarationKey::double(style.radius)),
          ])
        }),
      ),
    ),
    (
      "foreground",
      @core.DeclarationKey::option(self.foreground.map(view_color_key)),
    ),
    (
      "background",
      @core.DeclarationKey::option(self.background.map(view_color_key)),
    ),
  ])
  view_declaration(
    layout=view_exact_channel(
      view_record_key("Slider.layout", [
        ("width", @core.DeclarationKey::double(self.width)),
        ("height", @core.DeclarationKey::double(self.height)),
      ]),
    ),
    paint=if self.theme is Some(_) {
      @core.DeclarationChannel::Uncacheable
    } else {
      view_exact_channel(paint_key)
    },
    semantics=view_exact_channel(
      view_record_key("Slider.semantics", [
        ("value", @core.DeclarationKey::double(self.value)),
        ("scroll", @core.DeclarationKey::bool(self.has_on_change)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for Slider with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=self.height),
    ),
  )
}

///|
impl @core.ViewNode for Slider with fn paint(self, ctx) {
  // Resolve the slider style ambient-ly so the track/thumb track
  // dark-mode / palette / thumb-shape changes without a rebuild.
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => SliderStyle::default(theme=resolved_theme)
  }
  let range = if self.max <= self.min { 1.0 } else { self.max - self.min }
  let normalized = clamp_view_double((self.value - self.min) / range, 0.0, 1.0)
  let knob = min_view_double(self.height, resolved_style.thumb_size)
  let track_height = min_view_double(self.height, resolved_style.track_height)
  let track_radius = min_view_double(track_height / 2.0, resolved_style.radius)
  // Circle thumbs force a full circle (radius = knob/2) regardless of the
  // theme radius; Rounded thumbs respect the resolved radius.
  let thumb_shape = views_ambient_control_theme(resolved_theme).slider.thumb_shape
  let thumb_radius = match thumb_shape {
    ThumbShape::Circle => knob / 2.0
    ThumbShape::Rounded =>
      min_view_double(knob / 2.0, resolved_style.radius)
  }
  let foreground_color = resolve_control_color(
    self.foreground,
    resolved_style.foreground,
  )
  let track_background = resolve_control_color(
    self.background,
    resolved_style.background,
  )
  let thumb_color = resolve_control_color(
    self.foreground,
    resolved_style.thumb_color,
  )
  let frame = ctx.frame
  // Focus grows the thumb slightly so keyboard users get a visible
  // affordance, and the thumb gains a crisp ring that separates it from
  // the filled track. Ring color is a near-white highlight in light mode
  // and a faint surface-tinted edge in dark mode.
  let focused = ctx.focused
  let thumb_size = knob + (if focused { 3.0 } else { 0.0 })
  let ring_color = match resolved_theme.scheme {
    @core.ColorScheme::Light => @core.Color::white().with_alpha(0.92)
    @core.ColorScheme::Dark =>
      resolved_theme.palette.foreground.with_alpha(0.18)
  }
  let ring_width = 2.0
  let track = @core.Rect::new(
    x=frame.origin.x,
    y=frame.origin.y + (frame.size.height - track_height) / 2.0,
    width=frame.size.width,
    height=track_height,
  )
  let knob_x = frame.origin.x +
    normalized * max_view_double(0.0, frame.size.width - thumb_size)
  let thumb_rect = @core.RoundedRect::new(
    rect=@core.Rect::new(
      x=knob_x,
      y=frame.origin.y + (frame.size.height - thumb_size) / 2.0,
      width=thumb_size,
      height=thumb_size,
    ),
    radius=thumb_radius,
  )
  @core.ViewPaintPlan::commands([
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(rect=track, radius=track_radius),
      @core.Brush::solid(track_background),
    ),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(
          x=track.origin.x,
          y=track.origin.y,
          width=track.size.width * normalized,
          height=track.size.height,
        ),
        radius=track_radius,
      ),
      @core.Brush::solid(foreground_color),
    ),
    @core.DrawCommand::FillRoundedRectBrush(
      thumb_rect,
      @core.Brush::solid(thumb_color),
    ),
    @core.DrawCommand::StrokeRoundedRectBrush(
      thumb_rect,
      @core.Brush::solid(ring_color),
      ring_width,
    ),
  ])
}

///|
impl @core.ViewNode for Slider with fn focusable(_self) {
  true
}

///|
impl @core.ViewNode for Slider with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Slider,
    label="Slider",
    value="\{self.value}",
  )
}

///|
/// Map a pointer x position inside `frame` to the slider's value range,
/// clamped to `[min, max]`. Used by both the drag handler and (in the future)
/// accessibility action handlers.
fn slider_value_at(
  frame : @core.Rect,
  local_x : Double,
  min : Double,
  max : Double,
) -> Double {
  let range = if max <= min { 1.0 } else { max - min }
  let track_width = max_view_double(1.0, frame.size.width)
  let clamped = clamp_view_double(local_x, 0.0, track_width)
  clamp_view_double(min + clamped / track_width * range, min, max)
}
