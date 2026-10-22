///|
/// Paint modifiers: Background, Foreground, Font, CornerRadius, Opacity,
/// Shadow, Border, Clip, Scale, RepaintBoundary.

///|
priv struct BackgroundModifier {
  brush : Brush
}

///|
fn[Msg] BackgroundModifier::to_any_modifier(
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
        FillRoundedRectBrush(RoundedRect::new(rect=ctx.frame, radius~), brush),
      ])
    },
  }
}

///|
priv struct ForegroundModifier {
  color : Color
}

///|
fn[Msg] ForegroundModifier::to_any_modifier(
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
    child_style: fn(s) { { ..s, foreground: Some(self.color), } },
  }
}

///|
priv struct FontModifier {
  font : FontSpec
}

///|
fn[Msg] FontModifier::to_any_modifier(self : FontModifier) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "Font",
    declaration: ViewDeclaration::channels(
      layout=Exact(declaration_font(self.font)),
      paint=Constant,
      semantics=Constant,
      platform=Constant,
    ),
    child_style: fn(s) { { ..s, font: Some(self.font), } },
  }
}

///|
priv struct CornerRadiusModifier {
  radius : Double
}

///|
fn[Msg] CornerRadiusModifier::to_any_modifier(
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
    child_style: fn(s) { { ..s, corner_radius: Some(self.radius), } },
  }
}

///|
priv struct OpacityModifier {
  opacity : Double
}

///|
fn[Msg] OpacityModifier::to_any_modifier(
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
        commands: [PushOpacity(opacity)],
        child_layers: [],
        post_commands: [PopOpacity],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    },
  }
}

///|
priv struct ShadowModifier {
  style : ShadowStyle
}

///|
fn[Msg] ShadowModifier::to_any_modifier(
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
        DrawShadow(
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
priv struct BorderModifier {
  style : BorderStyle
}

///|
fn[Msg] BorderModifier::to_any_modifier(
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
          StrokeRoundedRectBrush(
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
priv struct ClipModifier {}

///|
fn[Msg] ClipModifier::to_any_modifier(_self : ClipModifier) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "Clip",
    paint: fn(ctx) {
      {
        commands: [PushClip(ctx.frame)],
        child_layers: [],
        post_commands: [PopClip],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    },
  }
}

///|
priv struct ScaleModifier {
  sx : Double
  sy : Double
}

///|
fn[Msg] ScaleModifier::to_any_modifier(
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
        commands: [PushTransform(Transform2D::scale(sx~, sy~))],
        child_layers: [],
        post_commands: [PopTransform],
        overlay_commands: [],
        repaint_boundary: false,
        animating: false,
      }
    },
  }
}

///|
priv struct RepaintBoundaryModifier {}

///|
fn[Msg] RepaintBoundaryModifier::to_any_modifier(
  _self : RepaintBoundaryModifier,
) -> AnyModifier[Msg] {
  {
    ..noop_modifier(),
    identity_kind: "RepaintBoundary",
    paint: fn(_ctx) { { ..ViewPaintPlan::empty(), repaint_boundary: true, } },
  }
}
