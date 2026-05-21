///|
pub(all) enum ShaderRegistryStatus {
  ShaderReady
  ShaderFallback
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ShaderRegistryResult {
  name : String
  status : ShaderRegistryStatus
  fallback : @core.Brush
  diagnostic : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PathVertex {
  x : Double
  y : Double
  r : Double
  g : Double
  b : Double
  a : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PathMesh {
  vertices : Array[PathVertex]
  diagnostics : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub fn builtin_shader_names() -> Array[String] {
  [ "solid", "checker", "linear-gradient-debug", "vignette" ]
}

///|
pub fn resolve_shader_effect(
  spec : @core.ShaderEffectSpec,
) -> ShaderRegistryResult {
  if builtin_shader_names().any(name => name == spec.name) {
    {
      name: spec.name,
      status: ShaderRegistryStatus::ShaderReady,
      fallback: spec.fallback,
      diagnostic: "",
    }
  } else {
    {
      name: spec.name,
      status: ShaderRegistryStatus::ShaderFallback,
      fallback: spec.fallback,
      diagnostic: "unknown shader effect: " + spec.name,
    }
  }
}

///|
pub fn tessellate_path(spec : @core.PathSpec) -> PathMesh {
  let mesh = PathMesh::{ vertices: [], diagnostics: [] }
  let fill = spec.fill
  let stroke = spec.stroke
  let mut current = @core.Point::new(x=0.0, y=0.0)
  let mut start = @core.Point::new(x=0.0, y=0.0)
  let mut has_current = false
  let mut subpath : Array[@core.Point] = []
  for verb in spec.verbs {
    match verb {
      @core.PathVerb::MoveTo(point) => {
        flush_fill_path(mesh, subpath, fill)
        subpath = [ point ]
        current = point
        start = point
        has_current = true
      }
      @core.PathVerb::LineTo(point) =>
        if has_current {
          append_path_segment(mesh, current, point, stroke, spec.stroke_width)
          subpath.push(point)
          current = point
        } else {
          mesh.diagnostics.push("LineTo ignored before MoveTo")
        }
      @core.PathVerb::QuadTo(control, point) =>
        if has_current {
          let points = flatten_quad(current, control, point)
          for next in points {
            append_path_segment(mesh, current, next, stroke, spec.stroke_width)
            subpath.push(next)
            current = next
          }
        } else {
          mesh.diagnostics.push("QuadTo ignored before MoveTo")
        }
      @core.PathVerb::CubicTo(c1, c2, point) =>
        if has_current {
          let points = flatten_cubic(current, c1, c2, point)
          for next in points {
            append_path_segment(mesh, current, next, stroke, spec.stroke_width)
            subpath.push(next)
            current = next
          }
        } else {
          mesh.diagnostics.push("CubicTo ignored before MoveTo")
        }
      @core.PathVerb::Close =>
        if has_current {
          append_path_segment(mesh, current, start, stroke, spec.stroke_width)
          flush_fill_path(mesh, subpath, fill)
          subpath = []
          current = start
          has_current = false
        } else {
          mesh.diagnostics.push("Close ignored before MoveTo")
        }
    }
  }
  flush_fill_path(mesh, subpath, fill)
  mesh
}

///|
fn flush_fill_path(
  mesh : PathMesh,
  points : Array[@core.Point],
  fill : @core.Brush?,
) -> Unit {
  match fill {
    Some(brush) =>
      if points.length() >= 3 {
        let color = brush_to_path_color(brush)
        for index in 1..<(points.length() - 1) {
          push_path_vertex(mesh.vertices, points[0], color)
          push_path_vertex(mesh.vertices, points[index], color)
          push_path_vertex(mesh.vertices, points[index + 1], color)
        }
      }
    None => ()
  }
}

///|
fn append_path_segment(
  mesh : PathMesh,
  from : @core.Point,
  to : @core.Point,
  stroke : @core.Brush?,
  stroke_width : Double,
) -> Unit {
  match stroke {
    Some(brush) =>
      if stroke_width > 0.0 {
        append_stroke_quad(mesh.vertices, from, to, stroke_width, brush_to_path_color(brush))
      }
    None => ()
  }
}

///|
fn append_stroke_quad(
  vertices : Array[PathVertex],
  from : @core.Point,
  to : @core.Point,
  width : Double,
  color : @core.Color,
) -> Unit {
  let dx = to.x - from.x
  let dy = to.y - from.y
  let len = (dx * dx + dy * dy).sqrt()
  if len <= 0.0 {
    return
  }
  let nx = -dy / len * width / 2.0
  let ny = dx / len * width / 2.0
  let p0 = @core.Point::new(x=from.x + nx, y=from.y + ny)
  let p1 = @core.Point::new(x=from.x - nx, y=from.y - ny)
  let p2 = @core.Point::new(x=to.x - nx, y=to.y - ny)
  let p3 = @core.Point::new(x=to.x + nx, y=to.y + ny)
  push_path_vertex(vertices, p0, color)
  push_path_vertex(vertices, p1, color)
  push_path_vertex(vertices, p2, color)
  push_path_vertex(vertices, p0, color)
  push_path_vertex(vertices, p2, color)
  push_path_vertex(vertices, p3, color)
}

///|
fn flatten_quad(
  from : @core.Point,
  control : @core.Point,
  to : @core.Point,
) -> Array[@core.Point] {
  let points : Array[@core.Point] = []
  for step in 1..=8 {
    let t = step.to_double() / 8.0
    let mt = 1.0 - t
    points.push(
      @core.Point::new(
        x=mt * mt * from.x + 2.0 * mt * t * control.x + t * t * to.x,
        y=mt * mt * from.y + 2.0 * mt * t * control.y + t * t * to.y,
      ),
    )
  }
  points
}

///|
fn flatten_cubic(
  from : @core.Point,
  c1 : @core.Point,
  c2 : @core.Point,
  to : @core.Point,
) -> Array[@core.Point] {
  let points : Array[@core.Point] = []
  for step in 1..=12 {
    let t = step.to_double() / 12.0
    let mt = 1.0 - t
    points.push(
      @core.Point::new(
        x=mt * mt * mt * from.x +
          3.0 * mt * mt * t * c1.x +
          3.0 * mt * t * t * c2.x +
          t * t * t * to.x,
        y=mt * mt * mt * from.y +
          3.0 * mt * mt * t * c1.y +
          3.0 * mt * t * t * c2.y +
          t * t * t * to.y,
      ),
    )
  }
  points
}

///|
fn brush_to_path_color(brush : @core.Brush) -> @core.Color {
  match brush {
    @core.Brush::Solid(color) => color
    @core.Brush::LinearGradient(gradient) => gradient.start_color
  }
}

///|
fn push_path_vertex(
  vertices : Array[PathVertex],
  point : @core.Point,
  color : @core.Color,
) -> Unit {
  vertices.push({
    x: point.x,
    y: point.y,
    r: color.r,
    g: color.g,
    b: color.b,
    a: color.a,
  })
}
