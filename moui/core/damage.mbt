///|
pub(all) enum DamageRegion {
  Empty
  FullSurface(String)
  Rects(Array[Rect])
} derive(Eq, Debug, ToJson)

///|
/// Renderer-facing frame payload. `clear_color` owns frame initialization;
/// `commands` contains view content and does not need a leading `Clear`.
/// Adapters for legacy command-only renderers must materialize that clear when
/// lowering a frame back to an `Array[DrawCommand]`.
pub(all) struct DrawFrame {
  commands : Array[DrawCommand]
  platform_views : Array[PlatformViewPlacement]
  /// Bounds of the runtime's view-level overlay paint, when present. Native
  /// platform views may use this to expose the already-rendered overlay pixels
  /// above their own surface without introducing a second renderer.
  overlay_bounds : Rect?
  damage : DamageRegion
  clear_color : Color
} derive(Eq, Debug, ToJson)

///|
fn damage_region_max_rects() -> Int {
  8
}

///|
fn damage_region_full_threshold() -> Double {
  0.6
}

///|
pub fn DamageRegion::empty() -> DamageRegion {
  DamageRegion::Empty
}

///|
pub fn DamageRegion::full(reason : String) -> DamageRegion {
  DamageRegion::FullSurface(reason)
}

///|
pub fn DamageRegion::from_rects(
  rects : Array[Rect],
  surface : Rect,
) -> DamageRegion {
  let clipped : Array[Rect] = []
  for rect in rects {
    match rect.clamp_to(surface) {
      Some(clamped) => if !clamped.is_empty() { clipped.push(clamped) }
      None => ()
    }
  }
  if clipped.is_empty() {
    DamageRegion::Empty
  } else {
    let coalesced = coalesce_damage_rects(clipped)
    if coalesced.length() > damage_region_max_rects() {
      DamageRegion::FullSurface("too many dirty rects")
    } else {
      let mut union_rect = coalesced[0]
      for index in 1..<coalesced.length() {
        union_rect = union_rect.union(coalesced[index])
      }
      let surface_area = surface.area()
      if surface_area > 0.0 &&
        union_rect.area() / surface_area > damage_region_full_threshold() {
        DamageRegion::FullSurface("dirty region covers most of the surface")
      } else {
        DamageRegion::Rects(coalesced)
      }
    }
  }
}

///|
fn coalesce_damage_rects(rects : Array[Rect]) -> Array[Rect] {
  let mut merged = rects.copy()
  let mut changed = true
  while changed {
    changed = false
    let used : Array[Bool] = []
    for _ in merged {
      used.push(false)
    }
    let next : Array[Rect] = []
    for index, rect in merged {
      if !used[index] {
        let mut current = rect
        used[index] = true
        let mut expanded = true
        while expanded {
          expanded = false
          for other_index, other in merged {
            if !used[other_index] && current.touches_or_overlaps(other) {
              current = current.union(other)
              used[other_index] = true
              expanded = true
              changed = true
            }
          }
        }
        next.push(current)
      }
    }
    merged = next
  }
  merged
}

///|
fn Rect::touches_or_overlaps(self : Rect, other : Rect) -> Bool {
  !self.is_empty() &&
  !other.is_empty() &&
  self.origin.x <= other.max_x() &&
  other.origin.x <= self.max_x() &&
  self.origin.y <= other.max_y() &&
  other.origin.y <= self.max_y()
}

///|
pub fn DamageRegion::rect_count(self : DamageRegion) -> Int {
  match self {
    Empty => 0
    FullSurface(_) => 0
    Rects(rects) => rects.length()
  }
}

///|
pub fn DamageRegion::kind(self : DamageRegion) -> String {
  match self {
    Empty => "empty"
    FullSurface(_) => "full"
    Rects(_) => "rects"
  }
}

///|
pub fn DamageRegion::full_reason(self : DamageRegion) -> String {
  match self {
    FullSurface(reason) => reason
    _ => ""
  }
}

///|
pub fn DrawFrame::new(
  commands~ : Array[DrawCommand],
  platform_views? : Array[PlatformViewPlacement] = [],
  overlay_bounds? : Rect? = None,
  damage~ : DamageRegion,
  clear_color? : Color = Color::white(),
) -> DrawFrame {
  { commands, platform_views, overlay_bounds, damage, clear_color }
}

///|
pub fn optional_rect_union(left : Rect?, right : Rect?) -> Rect? {
  match (left, right) {
    (Some(a), Some(b)) => Some(a.union(b))
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
}

///|
pub fn DrawCommand::bounds(self : DrawCommand) -> Rect? {
  match self {
    Clear(_) => None
    FillRect(rect, _) => Some(rect.inflate(1.0))
    StrokeRect(rect, _, width) => Some(rect.inflate(width.max(1.0)))
    FillRoundedRect(rounded, _) => Some(rounded.rect.inflate(1.0))
    StrokeRoundedRect(rounded, _, width) =>
      Some(rounded.rect.inflate(width.max(1.0)))
    FillRoundedRectBrush(rounded, _) => Some(rounded.rect.inflate(1.0))
    StrokeRoundedRectBrush(rounded, _, width) =>
      Some(rounded.rect.inflate(width.max(1.0)))
    DrawShadow(shadow) =>
      Some(
        shadow.rect.rect
        .inflate(shadow.blur_radius + shadow.spread.abs() + 2.0)
        .offset(dx=shadow.offset.x, dy=shadow.offset.y),
      )
    DrawText(run) => Some(run.frame.inflate(1.0))
    DrawImage(run) => Some(run.frame.inflate(1.0))
    PushClip(rect) => Some(rect)
    PopClip => None
    PushRoundedClip(rounded) => Some(rounded.rect)
    PopRoundedClip => None
    PushTransform(_) => None
    PopTransform => None
    PushOpacity(_) => None
    PopOpacity => None
    PushLayer(layer) =>
      match layer.mask {
        NoMask => None
        RectMask(rect) => Some(rect)
        RoundedMask(rounded) => Some(rounded.rect)
      }
    PopLayer => None
    BeginRetainedLayer(spec) => Some(spec.frame)
    EndRetainedLayer(_) => None
    PushFilter(filter) =>
      match filter {
        Blur(radius) =>
          Some(Rect::new(x=0.0, y=0.0, width=0.0, height=0.0).inflate(radius))
        _ => None
      }
    PopFilter => None
    DrawPath(path) => path.bounds()
    DrawShaderEffect(spec) => Some(spec.frame.inflate(1.0))
  }
}

///|
pub fn PathSpec::bounds(self : PathSpec) -> Rect? {
  let mut has_point = false
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let add_point = (point : Point) => {
    if !has_point {
      min_x = point.x
      min_y = point.y
      max_x = point.x
      max_y = point.y
      has_point = true
    } else {
      min_x = min_x.min(point.x)
      min_y = min_y.min(point.y)
      max_x = max_x.max(point.x)
      max_y = max_y.max(point.y)
    }
  }
  for verb in self.verbs {
    match verb {
      MoveTo(point) | LineTo(point) => add_point(point)
      QuadTo(a, b) => {
        add_point(a)
        add_point(b)
      }
      CubicTo(a, b, c) => {
        add_point(a)
        add_point(b)
        add_point(c)
      }
      Close => ()
    }
  }
  if has_point {
    Some(
      Rect::new(x=min_x, y=min_y, width=max_x - min_x, height=max_y - min_y).inflate(
        self.stroke_width.max(1.0),
      ),
    )
  } else {
    None
  }
}
