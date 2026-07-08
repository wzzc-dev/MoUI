///|
pub(all) enum ShaderRegistryStatus {
  ShaderReady
  ShaderFallback
} derive(Eq, Debug, ToJson)

///|
pub struct ShaderRegistryResult {
  priv name : String
  priv status : ShaderRegistryStatus
  priv fallback : @core.Brush
  priv diagnostic : String
} derive(Eq, Debug, ToJson)

///|
pub struct PathVertex {
  priv x : Double
  priv y : Double
  priv brush_kind : Double
  priv start_x : Double
  priv start_y : Double
  priv end_x : Double
  priv end_y : Double
  priv r : Double
  priv g : Double
  priv b : Double
  priv a : Double
  priv r1 : Double
  priv g1 : Double
  priv b1 : Double
  priv a1 : Double
} derive(Eq, Debug, ToJson)

///|
pub struct PathMesh {
  priv vertices : Array[PathVertex]
  priv diagnostics : Array[String]
} derive(Eq, Debug, ToJson)

///|
priv struct PathBrushPayload {
  kind : Double
  start : @core.Point
  end : @core.Point
  color0 : @core.Color
  color1 : @core.Color
}

///|
pub fn builtin_shader_names() -> Array[String] {
  ["solid", "checker", "linear-gradient-debug", "vignette"]
}

///|
pub fn ShaderRegistryResult::name(self : ShaderRegistryResult) -> String {
  self.name
}

///|
pub fn ShaderRegistryResult::status(
  self : ShaderRegistryResult,
) -> ShaderRegistryStatus {
  self.status
}

///|
pub fn ShaderRegistryResult::fallback(
  self : ShaderRegistryResult,
) -> @core.Brush {
  self.fallback
}

///|
pub fn ShaderRegistryResult::diagnostic(self : ShaderRegistryResult) -> String {
  self.diagnostic
}

///|
pub fn PathVertex::components(self : PathVertex) -> Array[Double] {
  [
    self.x,
    self.y,
    self.brush_kind,
    self.start_x,
    self.start_y,
    self.end_x,
    self.end_y,
    self.r,
    self.g,
    self.b,
    self.a,
    self.r1,
    self.g1,
    self.b1,
    self.a1,
  ]
}

///|
pub fn PathMesh::vertices(self : PathMesh) -> Array[PathVertex] {
  self.vertices
}

///|
pub fn PathMesh::diagnostics(self : PathMesh) -> Array[String] {
  self.diagnostics
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
  let path = zeno_path_from_spec(spec, mesh)
  append_zeno_fill_mesh(mesh, path, spec.fill)
  if !append_line_only_stroke_mesh(mesh, spec) {
    append_zeno_stroke_mesh(mesh, path, spec.stroke, spec.stroke_width)
  }
  mesh
}

///|
fn zeno_path_from_spec(
  spec : @core.PathSpec,
  mesh : PathMesh,
) -> Array[@zeno.Command] {
  let path : Array[@zeno.Command] = []
  let mut has_current = false
  for verb in spec.verbs {
    match verb {
      @core.PathVerb::MoveTo(point) => {
        @zeno.PathBuilder::move_to(path, zeno_vector(point))
        has_current = true
      }
      @core.PathVerb::LineTo(point) =>
        if has_current {
          @zeno.PathBuilder::line_to(path, zeno_vector(point))
        } else {
          mesh.diagnostics.push("LineTo ignored before MoveTo")
        }
      @core.PathVerb::QuadTo(control, point) =>
        if has_current {
          @zeno.PathBuilder::quad_to(
            path,
            zeno_vector(control),
            zeno_vector(point),
          )
        } else {
          mesh.diagnostics.push("QuadTo ignored before MoveTo")
        }
      @core.PathVerb::CubicTo(c1, c2, point) =>
        if has_current {
          @zeno.PathBuilder::curve_to(
            path,
            zeno_vector(c1),
            zeno_vector(c2),
            zeno_vector(point),
          )
        } else {
          mesh.diagnostics.push("CubicTo ignored before MoveTo")
        }
      @core.PathVerb::Close =>
        if has_current {
          @zeno.PathBuilder::close(path)
          has_current = false
        } else {
          mesh.diagnostics.push("Close ignored before MoveTo")
        }
    }
  }
  path
}

///|
fn append_zeno_fill_mesh(
  mesh : PathMesh,
  path : Array[@zeno.Command],
  fill : @core.Brush?,
) -> Unit {
  match fill {
    Some(brush) =>
      append_zeno_vertices(
        mesh.vertices,
        path,
        @zeno.Style::Fill(@zeno.Fill::NonZero),
        brush_to_path_payload(brush),
      )
    None => ()
  }
}

///|
fn append_zeno_stroke_mesh(
  mesh : PathMesh,
  path : Array[@zeno.Command],
  stroke : @core.Brush?,
  stroke_width : Double,
) -> Unit {
  match stroke {
    Some(brush) =>
      if stroke_width > 0.0 {
        append_zeno_vertices(
          mesh.vertices,
          path,
          @zeno.Style::Stroke(@zeno.Stroke::Stroke(stroke_width)),
          brush_to_path_payload(brush),
        )
      }
    None => ()
  }
}

///|
fn append_line_only_stroke_mesh(mesh : PathMesh, spec : @core.PathSpec) -> Bool {
  match spec.stroke {
    Some(brush) =>
      if spec.stroke_width > 0.0 {
        let payload = brush_to_path_payload(brush)
        let vertices : Array[PathVertex] = []
        let mut current : @core.Point? = None
        let mut emitted = false
        for verb in spec.verbs {
          match verb {
            @core.PathVerb::MoveTo(point) => current = Some(point)
            @core.PathVerb::LineTo(point) => {
              match current {
                Some(start) =>
                  if append_line_stroke_vertices(
                      vertices,
                      start,
                      point,
                      spec.stroke_width,
                      payload,
                    ) {
                    emitted = true
                  }
                None => return false
              }
              current = Some(point)
            }
            @core.PathVerb::QuadTo(_, _)
            | @core.PathVerb::CubicTo(_, _, _)
            | @core.PathVerb::Close => return false
          }
        }
        if emitted {
          for vertex in vertices {
            mesh.vertices.push(vertex)
          }
        }
        emitted
      } else {
        false
      }
    None => false
  }
}

///|
fn append_line_stroke_vertices(
  vertices : Array[PathVertex],
  start : @core.Point,
  end : @core.Point,
  stroke_width : Double,
  payload : PathBrushPayload,
) -> Bool {
  let dx = end.x - start.x
  let dy = end.y - start.y
  let length = (dx * dx + dy * dy).sqrt()
  if length <= 0.000001 {
    return false
  }
  let half_width = stroke_width / 2.0
  let nx = -dy / length * half_width
  let ny = dx / length * half_width
  push_path_vertex(vertices, @zeno.Vector(start.x + nx, start.y + ny), payload)
  push_path_vertex(vertices, @zeno.Vector(start.x - nx, start.y - ny), payload)
  push_path_vertex(vertices, @zeno.Vector(end.x - nx, end.y - ny), payload)
  push_path_vertex(vertices, @zeno.Vector(start.x + nx, start.y + ny), payload)
  push_path_vertex(vertices, @zeno.Vector(end.x - nx, end.y - ny), payload)
  push_path_vertex(vertices, @zeno.Vector(end.x + nx, end.y + ny), payload)
  true
}

///|
fn append_zeno_vertices(
  vertices : Array[PathVertex],
  path : Array[@zeno.Command],
  style : @zeno.Style,
  payload : PathBrushPayload,
) -> Unit {
  let applied : Array[@zeno.Command] = []
  ignore(@zeno.apply(path, style, None, applied))
  let walker = @zeno.Vertices::Vertices(applied)
  let points : Array[@zeno.Vector] = []
  while walker.next() is Some(vertex) {
    match vertex {
      @zeno.Vertex::Start(point, _) => points.push(point)
      @zeno.Vertex::Middle(point, _, _) => points.push(point)
      @zeno.Vertex::End(point, _, _) => points.push(point)
    }
  }
  for index in 0..<(points.length() / 3) {
    let base = index * 3
    push_path_vertex(vertices, points[base], payload)
    push_path_vertex(vertices, points[base + 1], payload)
    push_path_vertex(vertices, points[base + 2], payload)
  }
}

///|
fn brush_to_path_payload(brush : @core.Brush) -> PathBrushPayload {
  match brush {
    @core.Brush::Solid(color) =>
      {
        kind: 0.0,
        start: @core.Point::new(x=0.0, y=0.0),
        end: @core.Point::new(x=1.0, y=0.0),
        color0: color,
        color1: color,
      }
    @core.Brush::LinearGradient(gradient) =>
      {
        kind: 0.0,
        start: gradient.start,
        end: gradient.end,
        color0: gradient.start_color,
        color1: gradient.end_color,
      }
    @core.Brush::RadialGradient(gradient) =>
      {
        kind: 1.0,
        start: gradient.center,
        end: @core.Point::new(x=gradient.radius.max(1.0), y=0.0),
        color0: gradient.center_color,
        color1: gradient.edge_color,
      }
  }
}

///|
fn push_path_vertex(
  vertices : Array[PathVertex],
  point : @zeno.Vector,
  payload : PathBrushPayload,
) -> Unit {
  vertices.push({
    x: point.x(),
    y: point.y(),
    brush_kind: payload.kind,
    start_x: payload.start.x,
    start_y: payload.start.y,
    end_x: payload.end.x,
    end_y: payload.end.y,
    r: payload.color0.r,
    g: payload.color0.g,
    b: payload.color0.b,
    a: payload.color0.a,
    r1: payload.color1.r,
    g1: payload.color1.g,
    b1: payload.color1.b,
    a1: payload.color1.a,
  })
}

///|
fn zeno_vector(point : @core.Point) -> @zeno.Vector {
  @zeno.Vector(point.x, point.y)
}
