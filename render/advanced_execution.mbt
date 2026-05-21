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
  ["solid", "checker", "linear-gradient-debug", "vignette"]
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
  append_zeno_stroke_mesh(mesh, path, spec.stroke, spec.stroke_width)
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
        brush_to_path_color(brush),
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
          brush_to_path_color(brush),
        )
      }
    None => ()
  }
}

///|
fn append_zeno_vertices(
  vertices : Array[PathVertex],
  path : Array[@zeno.Command],
  style : @zeno.Style,
  color : @core.Color,
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
    push_path_vertex(vertices, points[base], color)
    push_path_vertex(vertices, points[base + 1], color)
    push_path_vertex(vertices, points[base + 2], color)
  }
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
  point : @zeno.Vector,
  color : @core.Color,
) -> Unit {
  vertices.push({
    x: point.x(),
    y: point.y(),
    r: color.r,
    g: color.g,
    b: color.b,
    a: color.a,
  })
}

///|
fn zeno_vector(point : @core.Point) -> @zeno.Vector {
  @zeno.Vector(point.x, point.y)
}
