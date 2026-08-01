///|
/// Paint modifiers: Background, Foreground, Font, CornerRadius, Opacity,
/// Shadow, Border, Clip, Scale, RepaintBoundary.

///|
pub(all) struct BackgroundModifier {
  brush : Brush
}

///|
pub fn[Msg] BackgroundModifier::to_any_modifier(
  self : BackgroundModifier,
) -> AnyModifier[Msg] {
  let brush = self.brush
  {
    ..noop_modifier(),
    identity_kind: "Background",
    declaration: ViewDeclaration::channels(
      layout=Constant,
      paint=Exact(declaration_brush(brush)),
      semantics=Constant,
      platform=Constant,
    ),
    paint: fn(ctx) {
      let radius = ctx.style.corner_radius.unwrap_or(0.0)
      ViewPaintPlan::commands([
        DrawCommand::FillRoundedRectBrush(
          RoundedRect::new(rect=ctx.frame, radius~),
          brush,
        ),
      ])
    },
  }
}

///|
pub(all) struct ForegroundModifier {
  color : Color
}

///|
pub fn[Msg] ForegroundModifier::to_any_modifier(
  self : ForegroundModifier,
) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "Foreground",
    declaration: ViewDeclaration::channels(
      layout=Constant,
      paint=Exact(declaration_color(self.color)),
      semantics=Constant,
      platform=Constant,
    ),
    child_style: fn(s) { { ..s, foreground: Some(self.color) } },
  }
}

///|
pub(all) struct FontModifier {
  font : FontSpec
}

///|
pub fn[Msg] FontModifier::to_any_modifier(
  self : FontModifier,
) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "Font",
    declaration: ViewDeclaration::channels(
      layout=Exact(declaration_font(self.font)),
      paint=Constant,
      semantics=Constant,
      platform=Constant,
    ),
    child_style: fn(s) { { ..s, font: Some(self.font) } },
  }
}

///|
pub(all) struct CornerRadiusModifier {
  radius : Double
}

///|
pub fn[Msg] CornerRadiusModifier::to_any_modifier(
  self : CornerRadiusModifier,
) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "CornerRadius",
    declaration: ViewDeclaration::channels(
      layout=Constant,
      paint=Exact(DeclarationKey::double(self.radius)),
      semantics=Constant,
      platform=Constant,
    ),
    child_style: fn(s) { { ..s, corner_radius: Some(self.radius) } },
  }
}

///|
pub(all) struct OpacityModifier {
  opacity : Double
}

///|
pub fn[Msg] OpacityModifier::to_any_modifier(
  self : OpacityModifier,
) -> AnyModifier[Msg] {
  let opacity = self.opacity
  {
    ..noop_modifier(),
    identity_kind: "Opacity",
    declaration: ViewDeclaration::channels(
      layout=Constant,
      paint=Exact(DeclarationKey::double(opacity)),
      semantics=Constant,
      platform=Constant,
    ),
    paint: fn(_ctx) {
      {
        commands: [DrawCommand::PushOpacity(opacity)],
        child_layers: [],
        post_commands: [DrawCommand::PopOpacity],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    },
  }
}

///|
pub(all) struct ShadowModifier {
  style : ShadowStyle
}

///|
pub fn[Msg] ShadowModifier::to_any_modifier(
  self : ShadowModifier,
) -> AnyModifier[Msg] {
  let style = self.style
  {
    ..noop_modifier(),
    identity_kind: "Shadow",
    declaration: ViewDeclaration::channels(
      layout=Constant,
      paint=Exact(declaration_shadow(style)),
      semantics=Constant,
      platform=Constant,
    ),
    paint: fn(ctx) {
      ViewPaintPlan::commands([
        DrawCommand::DrawShadow(
          ShadowSpec::new(
            rect=RoundedRect::new(rect=ctx.frame, radius=0.0),
            color=style.color,
            offset=style.offset,
            blur_radius=style.blur_radius,
            spread=style.spread,
          ),
        ),
      ])
    },
  }
}

///|
pub(all) struct BorderModifier {
  style : BorderStyle
}

///|
pub fn[Msg] BorderModifier::to_any_modifier(
  self : BorderModifier,
) -> AnyModifier[Msg] {
  let style = self.style
  {
    ..noop_modifier(),
    identity_kind: "Border",
    declaration: ViewDeclaration::channels(
      layout=Constant,
      paint=Exact(declaration_border(style)),
      semantics=Constant,
      platform=Constant,
    ),
    paint: fn(ctx) {
      if style.width > 0.0 {
        let radius = ctx.style.corner_radius.unwrap_or(0.0)
        ViewPaintPlan::commands([
          DrawCommand::StrokeRoundedRectBrush(
            RoundedRect::new(rect=ctx.frame, radius~),
            style.brush,
            style.width,
          ),
        ])
      } else {
        ViewPaintPlan::empty()
      }
    },
  }
}

///|
pub(all) struct ClipModifier {}

///|
pub fn[Msg] ClipModifier::to_any_modifier(
  _self : ClipModifier,
) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "Clip",
    paint: fn(ctx) {
      {
        commands: [DrawCommand::PushClip(ctx.frame)],
        child_layers: [],
        post_commands: [DrawCommand::PopClip],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    },
  }
}

///|
pub(all) struct ScaleModifier {
  sx : Double
  sy : Double
}

///|
pub fn[Msg] ScaleModifier::to_any_modifier(
  self : ScaleModifier,
) -> AnyModifier[Msg] {
  let sx = self.sx
  let sy = self.sy
  {
    ..noop_modifier(),
    identity_kind: "Scale",
    declaration: ViewDeclaration::channels(
      layout=Constant,
      paint=Exact(
        DeclarationKey::record(type_tag="Scale", fields=[
          ("sx", DeclarationKey::double(sx)),
          ("sy", DeclarationKey::double(sy)),
        ]),
      ),
      semantics=Constant,
      platform=Constant,
    ),
    paint: fn(_ctx) {
      {
        commands: [DrawCommand::PushTransform(Transform2D::scale(sx~, sy~))],
        child_layers: [],
        post_commands: [DrawCommand::PopTransform],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    },
  }
}

///|
pub(all) struct RepaintBoundaryModifier {}

///|
pub fn[Msg] RepaintBoundaryModifier::to_any_modifier(
  _self : RepaintBoundaryModifier,
) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "RepaintBoundary",
    paint: fn(_ctx) { { ..ViewPaintPlan::empty(), repaint_boundary: true } },
  }
}
