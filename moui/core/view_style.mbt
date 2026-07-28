///|
pub(all) enum MainAxisAlignment {
  MainStart
  MainCenter
  MainEnd
  SpaceBetween
  SpaceAround
  SpaceEvenly
} derive(Eq, Debug, ToJson)

///|
pub(all) enum CrossAxisAlignment {
  CrossStart
  CrossCenter
  CrossEnd
  CrossStretch
} derive(Eq, Debug, ToJson)

///|
pub(all) struct Alignment {
  x : Double
  y : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct KeyboardShortcut {
  key : String
  modifiers : KeyModifiers
} derive(Eq, Debug, ToJson)

///|
pub(all) enum PressableState {
  Normal
  Hovered
  Pressed
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ViewStyle {
  font : FontSpec?
  foreground : Color?
  background : Brush?
  corner_radius : Double?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum ImageFit {
  Contain
  Cover
  Stretch
  ScaleDown
  FitWidth
  FitHeight
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ShadowStyle {
  color : Color
  offset : Point
  blur_radius : Double
  spread : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct BorderStyle {
  brush : Brush
  width : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct VisualStyle {
  background : Brush?
  foreground : Color?
  border : BorderStyle?
  shadow : ShadowStyle?
  radius : Double?
  opacity : Double?
} derive(Eq, Debug, ToJson)

///|
pub fn ViewStyle::empty() -> ViewStyle {
  { font: None, foreground: None, background: None, corner_radius: None }
}

///|
pub fn ShadowStyle::new(
  color~ : Color,
  offset? : Point = Point::new(x=0.0, y=2.0),
  blur_radius? : Double = 8.0,
  spread? : Double = 0.0,
) -> ShadowStyle {
  { color, offset, blur_radius, spread }
}

///|
pub fn BorderStyle::new(brush~ : Brush, width? : Double = 1.0) -> BorderStyle {
  { brush, width }
}

///|
pub fn VisualStyle::empty() -> VisualStyle {
  {
    background: None,
    foreground: None,
    border: None,
    shadow: None,
    radius: None,
    opacity: None,
  }
}

///|
pub fn Alignment::new(x~ : Double, y~ : Double) -> Alignment {
  { x: clamp_double(x, -1.0, 1.0), y: clamp_double(y, -1.0, 1.0) }
}

///|
pub fn Alignment::center() -> Alignment {
  Alignment::new(x=0.0, y=0.0)
}

///|
pub fn Alignment::top_leading() -> Alignment {
  Alignment::new(x=-1.0, y=-1.0)
}

///|
pub fn Alignment::top_trailing() -> Alignment {
  Alignment::new(x=1.0, y=-1.0)
}

///|
pub fn Alignment::bottom_leading() -> Alignment {
  Alignment::new(x=-1.0, y=1.0)
}

///|
pub fn Alignment::bottom_trailing() -> Alignment {
  Alignment::new(x=1.0, y=1.0)
}

///|
pub fn KeyboardShortcut::new(
  key~ : String,
  modifiers? : KeyModifiers = KeyModifiers::none(),
) -> KeyboardShortcut {
  { key, modifiers }
}

///|
pub fn KeyboardShortcut::matches(
  self : KeyboardShortcut,
  event : KeyboardEvent,
) -> Bool {
  event.pressed && event.key == self.key && event.modifiers == self.modifiers
}

///|
pub fn ViewStyle::merge(self : ViewStyle, next : ViewStyle) -> ViewStyle {
  {
    font: option_prefer(next.font, self.font),
    foreground: option_prefer(next.foreground, self.foreground),
    background: option_prefer(next.background, self.background),
    corner_radius: option_prefer(next.corner_radius, self.corner_radius),
  }
}

///|
fn[T] option_prefer(value : T?, fallback : T?) -> T? {
  match value {
    Some(_) => value
    None => fallback
  }
}
