///|
/// Arbitrary SVG icons. The built-in `IconName` set is a fixed 24×24 stroke
/// vocabulary; this entry accepts an SVG document (Lucide, Tabler, Heroicons,
/// brand marks) and draws its `<path>` data as a stroke icon in the current
/// color. Parsing happens once at construction; painting reuses the parsed
/// verbs.
///
/// The converter is intentionally stricter than the generic SVG *image*
/// importer: smooth curves reflect their previous control point and arcs
/// become real cubic segments instead of falling back to lines, because icon
/// sets use both (`spinner`, `loader`, shield-style marks).
///
/// `markup` participates in the paint declaration key, so two different icons
/// never share a cached paint. `verbs`/`view_box` are derived from it.
pub fn[Msg] icon_svg(
  markup : String,
  size~ : Double = 20.0,
  color? : @core.Color,
  stroke_width~ : Double = 1.6,
  label~ : String = "Icon",
) -> @core.View[Msg] {
  let parsed = svg_icon_parse(markup)
  let resolved_color = match color {
    Some(value) => value
    None => @style.default_theme().palette.foreground
  }
  @core.View::from_node(SvgIcon::{
    label,
    markup,
    size,
    color: resolved_color,
    stroke_width,
    verbs: parsed.0,
    view_box: parsed.1,
  })
}

///|
priv struct SvgIcon {
  label : String
  markup : String
  size : Double
  color : @core.Color
  stroke_width : Double
  verbs : Array[@core.PathVerb] // declaration-exempt: derived from `markup`, which is in the paint key
  view_box : @core.Rect? // declaration-exempt: derived from `markup`
}

///|
impl @core.ViewNode for SvgIcon with fn identity(_self) {
  @core.ViewIdentity::new(kind="SvgIcon")
}

///|
impl @core.ViewNode for SvgIcon with fn layout(self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(
      @core.Size::new(width=self.size, height=self.size),
    ),
  )
}

///|
impl @core.ViewNode for SvgIcon with fn paint(self, context) {
  let side = @common.view_min_double(
    context.frame.size.width,
    context.frame.size.height,
  )
  let (min_x, min_y, view_width, view_height) = match self.view_box {
    Some(box) => (box.origin.x, box.origin.y, box.size.width, box.size.height)
    None => (0.0, 0.0, 24.0, 24.0)
  }
  let scale = if view_width <= 0.0 || view_height <= 0.0 {
    1.0
  } else {
    @common.view_min_double(side / view_width, side / view_height)
  }
  let origin_x = context.frame.origin.x +
    (context.frame.size.width - view_width * scale) / 2.0
  let origin_y = context.frame.origin.y +
    (context.frame.size.height - view_height * scale) / 2.0
  let scaled = svg_icon_scale_verbs(
    self.verbs,
    min_x~,
    min_y~,
    scale~,
    origin_x~,
    origin_y~,
  )
  @core.ViewPaintPlan::commands([
    DrawPath(
      @core.PathSpec::new(
        verbs=scaled,
        stroke=Some(@core.Brush::solid(self.color)),
        stroke_width=self.stroke_width,
      ),
    ),
  ])
}

///|
impl @core.ViewNode for SvgIcon with fn semantics(self) {
  @core.ViewSemanticsInfo::leaf(role=Text, label=self.label)
}

///|
/// Icon parsing is pure but not free; named-set icons rebuild with the view
/// tree in TEA. A small FIFO-style cache keeps repeated rebuilds cheap.
let svg_icon_parse_cache : Map[String, (Array[@core.PathVerb], @core.Rect?)] = Map([],
)

///|
let svg_icon_parse_cache_limit = 128

///|
fn svg_icon_parse(markup : String) -> (Array[@core.PathVerb], @core.Rect?) {
  match svg_icon_parse_cache.get(markup) {
    Some(value) => return value
    None => ()
  }
  let parsed = svg_icon_parse_uncached(markup)
  if svg_icon_parse_cache.length() >= svg_icon_parse_cache_limit {
    svg_icon_parse_cache.clear()
  }
  svg_icon_parse_cache.set(markup, parsed)
  parsed
}

///|
fn svg_icon_parse_uncached(
  markup : String,
) -> (Array[@core.PathVerb], @core.Rect?) {
  if !markup.contains("<svg") && !markup.contains("<path") {
    return ([], None)
  }
  match @svg.parse_svg_document(markup) {
    Some(document) => {
      let root = document.root()
      let commands : Array[@svg.PathCommand] = []
      svg_icon_collect_commands(root, commands)
      let view_box = match root.view_box {
        Some(box) =>
          Some(
            @core.Rect::new(
              x=box.min_x,
              y=box.min_y,
              width=box.width,
              height=box.height,
            ),
          )
        None => None
      }
      (svg_icon_commands_to_verbs(commands), view_box)
    }
    None => ([], None)
  }
}

///|
fn svg_icon_collect_commands(
  node : @svg.SVGNode,
  out : Array[@svg.PathCommand],
) -> Unit {
  match node.shape {
    Group =>
      for child in node.children {
        svg_icon_collect_commands(child, out)
      }
    Path(commands~) =>
      for command in commands {
        out.push(command)
      }
    _ => ()
  }
}

///|
fn svg_icon_commands_to_verbs(
  commands : Array[@svg.PathCommand],
) -> Array[@core.PathVerb] {
  let verbs : Array[@core.PathVerb] = []
  let mut x = 0.0
  let mut y = 0.0
  // Last control point of the previous cubic/quadratic, for `S`/`T`
  // reflection. Cleared by every other command, as the SVG spec requires.
  let mut last_cubic_control : @core.Point? = None
  let mut last_quad_control : @core.Point? = None
  for command in commands {
    let mut next_cubic : @core.Point? = None
    let mut next_quad : @core.Point? = None
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
        next_cubic = Some(@core.Point::new(x=x2, y=y2))
      }
      CurveToRel(dx1, dy1, dx2, dy2, dx, dy) => {
        let x0 = x
        let y0 = y
        x = x + dx
        y = y + dy
        let c2 = @core.Point::new(x=x0 + dx2, y=y0 + dy2)
        verbs.push(
          CubicTo(
            @core.Point::new(x=x0 + dx1, y=y0 + dy1),
            c2,
            @core.Point::new(x~, y~),
          ),
        )
        next_cubic = Some(c2)
      }
      SmoothCurveTo(x2, y2, nx, ny) => {
        let c1 = match last_cubic_control {
          Some(point) =>
            @core.Point::new(x=2.0 * x - point.x, y=2.0 * y - point.y)
          None => @core.Point::new(x~, y~)
        }
        x = nx
        y = ny
        let c2 = @core.Point::new(x=x2, y=y2)
        verbs.push(CubicTo(c1, c2, @core.Point::new(x~, y~)))
        next_cubic = Some(c2)
      }
      SmoothCurveToRel(dx2, dy2, dx, dy) => {
        let x0 = x
        let y0 = y
        let c1 = match last_cubic_control {
          Some(point) =>
            @core.Point::new(x=2.0 * x - point.x, y=2.0 * y - point.y)
          None => @core.Point::new(x~, y~)
        }
        x = x + dx
        y = y + dy
        let c2 = @core.Point::new(x=x0 + dx2, y=y0 + dy2)
        verbs.push(CubicTo(c1, c2, @core.Point::new(x~, y~)))
        next_cubic = Some(c2)
      }
      QuadraticCurveTo(x1, y1, nx, ny) => {
        let control = @core.Point::new(x=x1, y=y1)
        x = nx
        y = ny
        verbs.push(QuadTo(control, @core.Point::new(x~, y~)))
        next_quad = Some(control)
      }
      QuadraticCurveToRel(dx1, dy1, dx, dy) => {
        let control = @core.Point::new(x=x + dx1, y=y + dy1)
        x = x + dx
        y = y + dy
        verbs.push(QuadTo(control, @core.Point::new(x~, y~)))
        next_quad = Some(control)
      }
      SmoothQuadraticCurveTo(nx, ny) => {
        let control = match last_quad_control {
          Some(point) =>
            @core.Point::new(x=2.0 * x - point.x, y=2.0 * y - point.y)
          None => @core.Point::new(x~, y~)
        }
        x = nx
        y = ny
        verbs.push(QuadTo(control, @core.Point::new(x~, y~)))
        next_quad = Some(control)
      }
      SmoothQuadraticCurveToRel(dx, dy) => {
        let control = match last_quad_control {
          Some(point) =>
            @core.Point::new(x=2.0 * x - point.x, y=2.0 * y - point.y)
          None => @core.Point::new(x~, y~)
        }
        x = x + dx
        y = y + dy
        verbs.push(QuadTo(control, @core.Point::new(x~, y~)))
        next_quad = Some(control)
      }
      ArcTo(rx, ry, rotation, large_arc, sweep, nx, ny) => {
        let from_x = x
        let from_y = y
        x = nx
        y = ny
        svg_icon_arc_verbs(
          verbs,
          from_x~,
          from_y~,
          rx~,
          ry~,
          rotation~,
          large_arc~,
          sweep~,
          to_x=x,
          to_y=y,
        )
      }
      ArcToRel(rx, ry, rotation, large_arc, sweep, dx, dy) => {
        let from_x = x
        let from_y = y
        x = x + dx
        y = y + dy
        svg_icon_arc_verbs(
          verbs,
          from_x~,
          from_y~,
          rx~,
          ry~,
          rotation~,
          large_arc~,
          sweep~,
          to_x=x,
          to_y=y,
        )
      }
      ClosePath => verbs.push(Close)
    }
    last_cubic_control = next_cubic
    last_quad_control = next_quad
  }
  verbs
}

///|
/// Convert an SVG elliptical arc into cubic segments (SVG 1.1 F.6.5). A
/// degenerate radius falls back to a line.
fn svg_icon_arc_verbs(
  verbs : Array[@core.PathVerb],
  from_x~ : Double,
  from_y~ : Double,
  rx~ : Double,
  ry~ : Double,
  rotation~ : Double,
  large_arc~ : Bool,
  sweep~ : Bool,
  to_x~ : Double,
  to_y~ : Double,
) -> Unit {
  let mut radius_x = rx.abs()
  let mut radius_y = ry.abs()
  if radius_x < 0.0001 ||
    radius_y < 0.0001 ||
    (from_x == to_x && from_y == to_y) {
    verbs.push(LineTo(@core.Point::new(x=to_x, y=to_y)))
    return
  }
  let phi = rotation * @math.PI / 180.0
  let cos_phi = @math.cos(phi)
  let sin_phi = @math.sin(phi)
  let half_dx = (from_x - to_x) / 2.0
  let half_dy = (from_y - to_y) / 2.0
  let x1p = cos_phi * half_dx + sin_phi * half_dy
  let y1p = -sin_phi * half_dx + cos_phi * half_dy
  // Scale up radii that are too small to span the endpoints.
  let lambda = x1p * x1p / (radius_x * radius_x) +
    y1p * y1p / (radius_y * radius_y)
  if lambda > 1.0 {
    let scale = lambda.sqrt()
    radius_x = radius_x * scale
    radius_y = radius_y * scale
  }
  let rx2 = radius_x * radius_x
  let ry2 = radius_y * radius_y
  let numerator = rx2 * ry2 - rx2 * y1p * y1p - ry2 * x1p * x1p
  let denominator = rx2 * y1p * y1p + ry2 * x1p * x1p
  let coefficient = if denominator <= 0.0 {
    0.0
  } else {
    let sign = if large_arc == sweep { -1.0 } else { 1.0 }
    sign * (numerator / denominator).max(0.0).sqrt()
  }
  let center_xp = coefficient * radius_x * y1p / radius_y
  let center_yp = -coefficient * radius_y * x1p / radius_x
  let center_x = cos_phi * center_xp -
    sin_phi * center_yp +
    (from_x + to_x) / 2.0
  let center_y = sin_phi * center_xp +
    cos_phi * center_yp +
    (from_y + to_y) / 2.0
  let start_angle = @math.atan2(
    (y1p - center_yp) / radius_y,
    (x1p - center_xp) / radius_x,
  )
  let end_angle = @math.atan2(
    (-y1p - center_yp) / radius_y,
    (-x1p - center_xp) / radius_x,
  )
  let mut sweep_angle = end_angle - start_angle
  if !sweep && sweep_angle > 0.0 {
    sweep_angle = sweep_angle - 2.0 * @math.PI
  } else if sweep && sweep_angle < 0.0 {
    sweep_angle = sweep_angle + 2.0 * @math.PI
  }
  let quarters = if sweep_angle.abs() > @math.PI / 2.0 {
    sweep_angle.abs() / (@math.PI / 2.0) + 1.0
  } else {
    1.0
  }
  // Ceil without importing ceil: floor via integer truncation.
  let segments = (quarters - 1.0e-9).to_int().max(1)
  let step = sweep_angle / segments.to_double()
  let mut theta = start_angle
  for _ in 0..<segments {
    let next_theta = theta + step
    let alpha = 4.0 / 3.0 * @math.tan(step / 4.0)
    let p1 = svg_icon_arc_point(
      theta, radius_x, radius_y, cos_phi, sin_phi, center_x, center_y,
    )
    let p2 = svg_icon_arc_point(
      next_theta, radius_x, radius_y, cos_phi, sin_phi, center_x, center_y,
    )
    let d1 = svg_icon_arc_derivative(
      theta, radius_x, radius_y, cos_phi, sin_phi,
    )
    let d2 = svg_icon_arc_derivative(
      next_theta, radius_x, radius_y, cos_phi, sin_phi,
    )
    let control1 = @core.Point::new(
      x=p1.x + alpha * d1.x,
      y=p1.y + alpha * d1.y,
    )
    let control2 = @core.Point::new(
      x=p2.x - alpha * d2.x,
      y=p2.y - alpha * d2.y,
    )
    verbs.push(CubicTo(control1, control2, p2))
    theta = next_theta
  }
}

///|
fn svg_icon_arc_point(
  theta : Double,
  radius_x : Double,
  radius_y : Double,
  cos_phi : Double,
  sin_phi : Double,
  center_x : Double,
  center_y : Double,
) -> @core.Point {
  let cos_theta = @math.cos(theta)
  let sin_theta = @math.sin(theta)
  @core.Point::new(
    x=cos_phi * radius_x * cos_theta - sin_phi * radius_y * sin_theta + center_x,
    y=sin_phi * radius_x * cos_theta + cos_phi * radius_y * sin_theta + center_y,
  )
}

///|
fn svg_icon_arc_derivative(
  theta : Double,
  radius_x : Double,
  radius_y : Double,
  cos_phi : Double,
  sin_phi : Double,
) -> @core.Point {
  let cos_theta = @math.cos(theta)
  let sin_theta = @math.sin(theta)
  @core.Point::new(
    x=-cos_phi * radius_x * sin_theta - sin_phi * radius_y * cos_theta,
    y=-sin_phi * radius_x * sin_theta + cos_phi * radius_y * cos_theta,
  )
}

///|
fn svg_icon_scale_verbs(
  verbs : Array[@core.PathVerb],
  min_x~ : Double,
  min_y~ : Double,
  scale~ : Double,
  origin_x~ : Double,
  origin_y~ : Double,
) -> Array[@core.PathVerb] {
  let scaled : Array[@core.PathVerb] = []
  for verb in verbs {
    match verb {
      MoveTo(point) =>
        scaled.push(
          MoveTo(
            svg_icon_map_point(
              point,
              min_x~,
              min_y~,
              scale~,
              origin_x~,
              origin_y~,
            ),
          ),
        )
      LineTo(point) =>
        scaled.push(
          LineTo(
            svg_icon_map_point(
              point,
              min_x~,
              min_y~,
              scale~,
              origin_x~,
              origin_y~,
            ),
          ),
        )
      QuadTo(control, point) =>
        scaled.push(
          QuadTo(
            svg_icon_map_point(
              control,
              min_x~,
              min_y~,
              scale~,
              origin_x~,
              origin_y~,
            ),
            svg_icon_map_point(
              point,
              min_x~,
              min_y~,
              scale~,
              origin_x~,
              origin_y~,
            ),
          ),
        )
      CubicTo(control1, control2, point) =>
        scaled.push(
          CubicTo(
            svg_icon_map_point(
              control1,
              min_x~,
              min_y~,
              scale~,
              origin_x~,
              origin_y~,
            ),
            svg_icon_map_point(
              control2,
              min_x~,
              min_y~,
              scale~,
              origin_x~,
              origin_y~,
            ),
            svg_icon_map_point(
              point,
              min_x~,
              min_y~,
              scale~,
              origin_x~,
              origin_y~,
            ),
          ),
        )
      Close => scaled.push(Close)
    }
  }
  scaled
}

///|
fn svg_icon_map_point(
  point : @core.Point,
  min_x~ : Double,
  min_y~ : Double,
  scale~ : Double,
  origin_x~ : Double,
  origin_y~ : Double,
) -> @core.Point {
  @core.Point::new(
    x=origin_x + (point.x - min_x) * scale,
    y=origin_y + (point.y - min_y) * scale,
  )
}
