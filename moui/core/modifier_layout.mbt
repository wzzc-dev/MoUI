///|
/// Layout modifiers: Padding, Frame, Flexible, Offset, Align, AspectRatio,
/// Spacing, LayoutPriority, MainAxisAlignment, CrossAxisAlignment,
/// IntrinsicWidth, IntrinsicHeight, Key.
pub(all) struct PaddingModifier {
  insets : Insets
}

///|
pub fn[Msg] PaddingModifier::to_any_modifier(
  self : PaddingModifier,
) -> AnyModifier[Msg] {
  let insets = self.insets
  {
    ..noop_modifier(),
    identity_kind: "Padding",
    declaration: ViewDeclaration::channels(
      layout=Exact(
        DeclarationKey::record(type_tag="Padding", fields=[
          ("insets", declaration_insets(insets)),
        ]),
      ),
      paint=Constant,
      semantics=Constant,
      platform=Constant,
    ),
    child_constraints: fn(c) { c.deflate(insets) },
    layout: fn(ctx) {
      let child_size = first_modifier_child_size(ctx.child_sizes)
      let size = ctx.constraints.constrain(child_size.inflate(insets))
      let frame = Rect::new(x=0.0, y=0.0, width=size.width, height=size.height)
      ViewLayoutResult::new(size~, child_frames=[frame.inset(insets)])
    },
  }
}

///|
pub(all) struct FrameModifier {
  width : Double?
  height : Double?
  min_width : Double?
  min_height : Double?
  max_width : Double?
  max_height : Double?
}

///|
fn frame_constraints(data : FrameModifier, c : Constraints) -> Constraints {
  match (data.width, data.height) {
    (Some(w), Some(h)) => c.tighten(width=w, height=h).loosen()
    (Some(w), None) => c.tighten(width=w).loosen()
    (None, Some(h)) => c.tighten(height=h).loosen()
    (None, None) => c.loosen()
  }
}

///|
fn frame_resolve(data : FrameModifier, child : Size) -> Size {
  let w = data.width.unwrap_or(child.width)
  let h = data.height.unwrap_or(child.height)
  let mw = data.min_width.unwrap_or(0.0)
  let mh = data.min_height.unwrap_or(0.0)
  let xw = data.max_width.unwrap_or(w)
  let xh = data.max_height.unwrap_or(h)
  Size::new(width=w, height=h).clamp({
    min: Size::new(width=mw, height=mh),
    max: Size::new(width=max_double(mw, xw), height=max_double(mh, xh)),
  })
}

///|
fn frame_child(data : FrameModifier, bounds : Rect) -> Rect {
  let s = frame_resolve(data, bounds.size)
  Rect::new(
    x=bounds.origin.x,
    y=bounds.origin.y,
    width=s.width,
    height=s.height,
  )
}

///|
pub fn[Msg] FrameModifier::to_any_modifier(
  self : FrameModifier,
) -> AnyModifier[Msg] {
  let data = self
  {
    ..noop_modifier(),
    identity_kind: "Frame",
    declaration: ViewDeclaration::channels(
      layout=Exact(
        DeclarationKey::record(type_tag="FrameModifier", fields=[
          ("width", declaration_option_double(data.width)),
          ("height", declaration_option_double(data.height)),
          ("min_width", declaration_option_double(data.min_width)),
          ("min_height", declaration_option_double(data.min_height)),
          ("max_width", declaration_option_double(data.max_width)),
          ("max_height", declaration_option_double(data.max_height)),
        ]),
      ),
      paint=Constant,
      semantics=Constant,
      platform=Constant,
    ),
    child_constraints: fn(c) { frame_constraints(data, c) },
    layout: fn(ctx) {
      let cs = first_modifier_child_size(ctx.child_sizes)
      let s = ctx.constraints.constrain(frame_resolve(data, cs))
      let cf = frame_child(
        data,
        Rect::new(x=0.0, y=0.0, width=s.width, height=s.height),
      )
      ViewLayoutResult::new(size=s, child_frames=[cf])
    },
  }
}

///|
pub(all) struct FlexibleModifier {
  weight : Double
}

///|
pub fn[Msg] FlexibleModifier::to_any_modifier(
  self : FlexibleModifier,
) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "Flexible",
    flex_weight: self.weight,
    layout: fn(ctx) {
      ViewLayoutResult::new(
        size=ctx.constraints.constrain(Size::new(width=0.0, height=0.0)),
        child_frames=[Rect::new(x=0.0, y=0.0, width=0.0, height=0.0)],
      )
    },
  }
}

///|
pub(all) struct OffsetModifier {
  dx : Double
  dy : Double
}

///|
pub fn[Msg] OffsetModifier::to_any_modifier(
  self : OffsetModifier,
) -> AnyModifier[Msg] {
  let dx = self.dx
  let dy = self.dy
  {
    ..noop_modifier(),
    identity_kind: "Offset",
    declaration: ViewDeclaration::channels(
      layout=Exact(
        DeclarationKey::record(type_tag="Offset", fields=[
          ("dx", DeclarationKey::double(dx)),
          ("dy", DeclarationKey::double(dy)),
        ]),
      ),
      paint=Constant,
      semantics=Constant,
      platform=Constant,
    ),
    layout: fn(ctx) {
      let cs = first_modifier_child_size(ctx.child_sizes)
      let s = ctx.constraints.constrain(cs)
      ViewLayoutResult::new(size=s, child_frames=[
        Rect::new(x=0.0, y=0.0, width=s.width, height=s.height).offset(dx~, dy~),
      ])
    },
  }
}

///|
pub(all) struct AlignModifier {
  alignment : Alignment
}

///|
fn mod_aligned_rect(bounds : Rect, cs : Size, a : Alignment) -> Rect {
  let w = min_double(bounds.size.width, cs.width)
  let h = min_double(bounds.size.height, cs.height)
  let dx = max_double(0.0, bounds.size.width - w) * (a.x + 1.0) / 2.0
  let dy = max_double(0.0, bounds.size.height - h) * (a.y + 1.0) / 2.0
  Rect::new(x=bounds.origin.x + dx, y=bounds.origin.y + dy, width=w, height=h)
}

///|
pub fn[Msg] AlignModifier::to_any_modifier(
  self : AlignModifier,
) -> AnyModifier[Msg] {
  let a = self.alignment
  {
    ..noop_modifier(),
    identity_kind: "Align",
    layout: fn(ctx) {
      let cs = first_modifier_child_size(ctx.child_sizes)
      let s = ctx.constraints.constrain(cs)
      ViewLayoutResult::new(size=s, child_frames=[
        mod_aligned_rect(
          Rect::new(x=0.0, y=0.0, width=s.width, height=s.height),
          cs,
          a,
        ),
      ])
    },
  }
}

///|
pub(all) struct AspectRatioModifier {
  ratio : Double
}

///|
fn mod_ar_size(s : Size, r : Double) -> Size {
  if s.width > 0.0 {
    Size::new(width=s.width, height=s.width / r)
  } else if s.height > 0.0 {
    Size::new(width=s.height * r, height=s.height)
  } else {
    s
  }
}

///|
fn mod_ar_rect(f : Rect, r : Double) -> Rect {
  let s = mod_ar_size(f.size, r).clamp(Constraints::tight(f.size))
  Rect::new(x=f.origin.x, y=f.origin.y, width=s.width, height=s.height)
}

///|
pub fn[Msg] AspectRatioModifier::to_any_modifier(
  self : AspectRatioModifier,
) -> AnyModifier[Msg] {
  let r = self.ratio
  {
    ..noop_modifier(),
    identity_kind: "AspectRatio",
    layout: fn(ctx) {
      let cs = first_modifier_child_size(ctx.child_sizes)
      let s = ctx.constraints.constrain(mod_ar_size(cs, r))
      ViewLayoutResult::new(size=s, child_frames=[
        mod_ar_rect(Rect::new(x=0.0, y=0.0, width=s.width, height=s.height), r),
      ])
    },
  }
}

///|
pub(all) struct SpacingModifier {
  spacing : Double
}

///|
pub fn[Msg] SpacingModifier::to_any_modifier(
  _self : SpacingModifier,
) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "Spacing" }
}

///|
pub(all) struct LayoutPriorityModifier {
  priority : Double
}

///|
pub fn[Msg] LayoutPriorityModifier::to_any_modifier(
  _self : LayoutPriorityModifier,
) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "LayoutPriority" }
}

///|
pub(all) struct MainAxisAlignmentModifier {
  alignment : MainAxisAlignment
}

///|
pub fn[Msg] MainAxisAlignmentModifier::to_any_modifier(
  _self : MainAxisAlignmentModifier,
) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "MainAxisAlignment" }
}

///|
pub(all) struct CrossAxisAlignmentModifier {
  alignment : CrossAxisAlignment
}

///|
pub fn[Msg] CrossAxisAlignmentModifier::to_any_modifier(
  _self : CrossAxisAlignmentModifier,
) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "CrossAxisAlignment" }
}

///|
pub(all) struct IntrinsicWidthModifier {}

///|
pub fn[Msg] IntrinsicWidthModifier::to_any_modifier(
  _self : IntrinsicWidthModifier,
) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "IntrinsicWidth" }
}

///|
pub(all) struct IntrinsicHeightModifier {}

///|
pub fn[Msg] IntrinsicHeightModifier::to_any_modifier(
  _self : IntrinsicHeightModifier,
) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "IntrinsicHeight" }
}

///|
pub(all) struct KeyModifier {
  key : Key
}

///|
pub fn[Msg] KeyModifier::to_any_modifier(
  self : KeyModifier,
) -> AnyModifier[Msg] {
  let key = self.key
  { ..noop_modifier(), identity_kind: "Key", identity_key: Some(key) }
}
