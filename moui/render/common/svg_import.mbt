///|
pub struct SvgImportResult {
  priv commands : Array[@core.DrawCommand]
  priv diagnostics : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub fn SvgImportResult::commands(
  self : SvgImportResult,
) -> Array[@core.DrawCommand] {
  self.commands
}

///|
pub fn SvgImportResult::diagnostics(self : SvgImportResult) -> Array[String] {
  self.diagnostics
}

///|
pub fn import_svg(svg : String) -> SvgImportResult {
  let result = SvgImportResult::{ commands: [], diagnostics: [], }
  if !svg.contains("<svg") {
    result.diagnostics.push("missing <svg> root")
    return result
  }
  match @svg.parse_svg_document(svg) {
    Some(doc) => {
      lower_svg_node(doc.root(), result)
      collect_svg_feature_diagnostics(svg, result)
    }
    None => result.diagnostics.push("parse failed")
  }
  result
}

///|
fn collect_svg_feature_diagnostics(
  svg : String,
  result : SvgImportResult,
) -> Unit {
  if svg.contains("<foreignObject") {
    result.diagnostics.push("foreignObject is unsupported")
  }
  if svg.contains("<animate") {
    result.diagnostics.push("SMIL animation is unsupported")
  }
}

///|
fn lower_svg_node(node : @svg.SVGNode, result : SvgImportResult) -> Unit {
  let pushed_transform = push_svg_transform(node.transform, result)
  let pushed_opacity = push_svg_opacity(node.opacity, result)
  match node.shape {
    Group =>
      for child in node.children {
        lower_svg_node(child, result)
      }
    Rect(x~, y~, width~, height~, rx~, ry~) =>
      lower_svg_rect(node, result, x, y, width, height, rx, ry)
    Circle(cx~, cy~, r~) =>
      lower_svg_path(node, result, svg_circle_verbs(cx, cy, r))
    Ellipse(cx~, cy~, rx~, ry~) =>
      lower_svg_path(node, result, svg_ellipse_verbs(cx, cy, rx, ry))
    Line(x1~, y1~, x2~, y2~) =>
      lower_svg_path(node, result, [
        MoveTo(@core.Point::new(x=x1, y=y1)),
        LineTo(@core.Point::new(x=x2, y=y2)),
      ])
    Polyline(points~) =>
      lower_svg_path(node, result, svg_points_to_verbs(points, close=false))
    Polygon(points~) =>
      lower_svg_path(node, result, svg_points_to_verbs(points, close=true))
    Path(commands~) =>
      lower_svg_path(node, result, svg_path_commands_to_verbs(commands, result))
    Text(x~, y~, text~, font_size~) =>
      lower_svg_text(node, result, x, y, text, font_size)
    Image(..) => result.diagnostics.push("image elements are unsupported")
  }
  if pushed_opacity {
    result.commands.push(PopOpacity)
  }
  if pushed_transform {
    result.commands.push(PopTransform)
  }
}

///|
fn push_svg_transform(
  transform : @svg.Transform,
  result : SvgImportResult,
) -> Bool {
  if transform.a == 1.0 &&
    transform.b == 0.0 &&
    transform.c == 0.0 &&
    transform.d == 1.0 &&
    transform.e == 0.0 &&
    transform.f == 0.0 {
    false
  } else {
    result.commands.push(
      PushTransform({
        a: transform.a,
        b: transform.b,
        c: transform.c,
        d: transform.d,
        tx: transform.e,
        ty: transform.f,
      }),
    )
    true
  }
}

///|
fn push_svg_opacity(node_opacity : Double, result : SvgImportResult) -> Bool {
  if node_opacity >= 0.999999 {
    false
  } else {
    result.commands.push(PushOpacity(node_opacity))
    true
  }
}

///|
fn lower_svg_rect(
  node : @svg.SVGNode,
  result : SvgImportResult,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rx : Double,
  ry : Double,
) -> Unit {
  let rect = @core.Rect::new(x~, y~, width~, height~)
  let radius = if rx > ry { rx } else { ry }
  match svg_node_fill(node, result) {
    Some(color) =>
      if radius > 0.0 {
        result.commands.push(
          FillRoundedRect(@core.RoundedRect::new(rect~, radius~), color),
        )
      } else {
        result.commands.push(FillRect(rect, color))
      }
    None => ()
  }
  match svg_node_stroke(node, result) {
    Some((color, stroke_width)) =>
      if radius > 0.0 {
        result.commands.push(
          StrokeRoundedRect(
            @core.RoundedRect::new(rect~, radius~),
            color,
            stroke_width,
          ),
        )
      } else {
        result.commands.push(StrokeRect(rect, color, stroke_width))
      }
    None => ()
  }
}

///|
fn lower_svg_path(
  node : @svg.SVGNode,
  result : SvgImportResult,
  verbs : Array[@core.PathVerb],
) -> Unit {
  if verbs.length() == 0 {
    return
  }
  result.commands.push(
    DrawPath(
      @core.PathSpec::new(
        verbs~,
        fill=svg_node_fill(node, result).map(@core.Brush::solid),
        stroke=svg_node_stroke(node, result).map(fn(stroke) {
          @core.Brush::solid(stroke.0)
        }),
        stroke_width=svg_node_stroke_width(node),
      ),
    ),
  )
}

///|
fn lower_svg_text(
  node : @svg.SVGNode,
  result : SvgImportResult,
  x : Double,
  y : Double,
  text : String,
  font_size : Double,
) -> Unit {
  match svg_node_fill(node, result) {
    Some(color) =>
      result.commands.push(
        DrawText(
          @core.TextRun::new(
            text~,
            frame=@core.Rect::new(x~, y~, width=0.0, height=font_size),
            font={ ..@core.FontSpec::new(), size: font_size, },
            color~,
            align=TextStart,
          ),
        ),
      )
    None => ()
  }
}

///|
fn svg_node_fill(node : @svg.SVGNode, result : SvgImportResult) -> @core.Color? {
  svg_paint_to_color(node.fill, node.color, node.fill_opacity, result)
}

///|
fn svg_node_stroke(
  node : @svg.SVGNode,
  result : SvgImportResult,
) -> (@core.Color, Double)? {
  match
    svg_paint_to_color(
      node.stroke.paint,
      node.color,
      node.stroke_opacity,
      result,
    ) {
    Some(color) => Some((color, svg_node_stroke_width(node)))
    None => None
  }
}

///|
fn svg_node_stroke_width(node : @svg.SVGNode) -> Double {
  if node.stroke.width <= 0.0 {
    1.0
  } else {
    node.stroke.width
  }
}

///|
fn svg_paint_to_color(
  paint : @svg.Paint,
  current_color : @svg.Color?,
  opacity : Double,
  result : SvgImportResult,
) -> @core.Color? {
  match paint {
    None => None
    SolidColor(color) => Some(svg_color_to_core(color, opacity))
    CurrentColor =>
      current_color.map(fn(color) { svg_color_to_core(color, opacity) })
    LinearGrad(_) | RadialGrad(_) => {
      result.diagnostics.push("gradient paint is unsupported")
      None
    }
    PaintServerRef(_, fallback) =>
      match fallback {
        NoPaint => None
        SolidColor(color) => Some(svg_color_to_core(color, opacity))
        CurrentColor =>
          current_color.map(fn(color) { svg_color_to_core(color, opacity) })
      }
  }
}

///|
fn svg_color_to_core(color : @svg.Color, opacity : Double) -> @core.Color {
  @core.Color::rgba(
    r=color.r.to_double() / 255.0,
    g=color.g.to_double() / 255.0,
    b=color.b.to_double() / 255.0,
    a=color.a.to_double() / 255.0 * opacity,
  )
}

///|
fn svg_circle_verbs(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@core.PathVerb] {
  svg_ellipse_verbs(cx, cy, radius, radius)
}

///|
fn svg_ellipse_verbs(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
) -> Array[@core.PathVerb] {
  let verbs : Array[@core.PathVerb] = []
  if rx <= 0.0 || ry <= 0.0 {
    return verbs
  }
  let unit_points = [
    @core.Point::new(x=1.0, y=0.0),
    @core.Point::new(x=0.70710678, y=0.70710678),
    @core.Point::new(x=0.0, y=1.0),
    @core.Point::new(x=-0.70710678, y=0.70710678),
    @core.Point::new(x=-1.0, y=0.0),
    @core.Point::new(x=-0.70710678, y=-0.70710678),
    @core.Point::new(x=0.0, y=-1.0),
    @core.Point::new(x=0.70710678, y=-0.70710678),
  ]
  for index, unit in unit_points {
    let point = @core.Point::new(x=cx + unit.x * rx, y=cy + unit.y * ry)
    if index == 0 {
      verbs.push(MoveTo(point))
    } else {
      verbs.push(LineTo(point))
    }
  }
  verbs.push(Close)
  verbs
}

///|
fn svg_points_to_verbs(
  points : Array[(Double, Double)],
  close~ : Bool,
) -> Array[@core.PathVerb] {
  let verbs : Array[@core.PathVerb] = []
  if points.length() == 0 {
    return verbs
  }
  verbs.push(MoveTo(@core.Point::new(x=points[0].0, y=points[0].1)))
  for index in 1..<points.length() {
    verbs.push(LineTo(@core.Point::new(x=points[index].0, y=points[index].1)))
  }
  if close {
    verbs.push(Close)
  }
  verbs
}

///|
fn svg_path_commands_to_verbs(
  commands : Array[@svg.PathCommand],
  result : SvgImportResult,
) -> Array[@core.PathVerb] {
  let verbs : Array[@core.PathVerb] = []
  let mut x = 0.0
  let mut y = 0.0
  for command in commands {
    match command {
      MoveTo(nx, ny) => {
        x = nx
        y = ny
        verbs.push(MoveTo(@core.Point::new(x~, y~)))
      }
      MoveToRel(dx, dy) => {
        x = x + dx
        y = y + dy
        verbs.push(MoveTo(@core.Point::new(x~, y~)))
      }
      LineTo(nx, ny) => {
        x = nx
        y = ny
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      LineToRel(dx, dy) => {
        x = x + dx
        y = y + dy
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      HorizontalLineTo(nx) => {
        x = nx
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      HorizontalLineToRel(dx) => {
        x = x + dx
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      VerticalLineTo(ny) => {
        y = ny
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      VerticalLineToRel(dy) => {
        y = y + dy
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      CurveTo(x1, y1, x2, y2, nx, ny) => {
        x = nx
        y = ny
        verbs.push(
          CubicTo(
            @core.Point::new(x=x1, y=y1),
            @core.Point::new(x=x2, y=y2),
            @core.Point::new(x~, y~),
          ),
        )
      }
      CurveToRel(dx1, dy1, dx2, dy2, dx, dy) => {
        let x0 = x
        let y0 = y
        x = x + dx
        y = y + dy
        verbs.push(
          CubicTo(
            @core.Point::new(x=x0 + dx1, y=y0 + dy1),
            @core.Point::new(x=x0 + dx2, y=y0 + dy2),
            @core.Point::new(x~, y~),
          ),
        )
      }
      QuadraticCurveTo(x1, y1, nx, ny) => {
        x = nx
        y = ny
        verbs.push(
          QuadTo(@core.Point::new(x=x1, y=y1), @core.Point::new(x~, y~)),
        )
      }
      QuadraticCurveToRel(dx1, dy1, dx, dy) => {
        let x0 = x
        let y0 = y
        x = x + dx
        y = y + dy
        verbs.push(
          QuadTo(
            @core.Point::new(x=x0 + dx1, y=y0 + dy1),
            @core.Point::new(x~, y~),
          ),
        )
      }
      ClosePath => verbs.push(Close)
      SmoothCurveTo(_, _, nx, ny) => {
        x = nx
        y = ny
        result.diagnostics.push("smooth cubic path commands are approximated")
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      SmoothCurveToRel(_, _, dx, dy) => {
        x = x + dx
        y = y + dy
        result.diagnostics.push("smooth cubic path commands are approximated")
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      SmoothQuadraticCurveTo(nx, ny) => {
        x = nx
        y = ny
        result.diagnostics.push(
          "smooth quadratic path commands are approximated",
        )
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      SmoothQuadraticCurveToRel(dx, dy) => {
        x = x + dx
        y = y + dy
        result.diagnostics.push(
          "smooth quadratic path commands are approximated",
        )
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      ArcTo(_, _, _, _, _, nx, ny) => {
        x = nx
        y = ny
        result.diagnostics.push("arc path commands are approximated")
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
      ArcToRel(_, _, _, _, _, dx, dy) => {
        x = x + dx
        y = y + dy
        result.diagnostics.push("arc path commands are approximated")
        verbs.push(LineTo(@core.Point::new(x~, y~)))
      }
    }
  }
  verbs
}
