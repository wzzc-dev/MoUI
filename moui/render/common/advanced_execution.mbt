///|
pub(all) enum ShaderRegistryStatus {
  ShaderReady
  ShaderFallback
} derive(Eq, Debug, ToJson)

///|
pub extend ShaderRegistryStatus with Debug::{to_repr}

///|
pub extend ShaderRegistryStatus with Eq::{not_equal, equal}

///|
pub extend ShaderRegistryStatus with ToJson::{to_json}

///|
pub struct ShaderRegistryResult {
  priv name : String
  priv status : ShaderRegistryStatus
  priv fallback : @core.Brush
  priv diagnostic : String
} derive(Eq, Debug, ToJson)

///|
pub extend ShaderRegistryResult with Debug::{to_repr}

///|
pub extend ShaderRegistryResult with Eq::{not_equal, equal}

///|
pub extend ShaderRegistryResult with ToJson::{to_json}

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
pub extend PathVertex with Debug::{to_repr}

///|
pub extend PathVertex with Eq::{not_equal, equal}

///|
pub extend PathVertex with ToJson::{to_json}

///|
pub struct PathMesh {
  priv vertices : Array[PathVertex]
  priv diagnostics : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub extend PathMesh with Debug::{to_repr}

///|
pub extend PathMesh with Eq::{not_equal, equal}

///|
pub extend PathMesh with ToJson::{to_json}

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
      status: ShaderReady,
      fallback: spec.fallback,
      diagnostic: "",
    }
  } else {
    {
      name: spec.name,
      status: ShaderFallback,
      fallback: spec.fallback,
      diagnostic: "unknown shader effect: " + spec.name,
    }
  }
}

///|
pub fn tessellate_path(spec : @core.PathSpec) -> PathMesh {
  let mesh = PathMesh::{ vertices: [], diagnostics: [], }
  let path = zeno_path_from_spec(spec, mesh)
  append_zeno_fill_mesh(mesh, path, spec.fill)
  ignore(append_flattened_stroke_mesh(mesh, spec))
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
      MoveTo(point) => {
        @zeno.PathBuilder::move_to(path, zeno_vector(point))
        has_current = true
      }
      LineTo(point) =>
        if has_current {
          @zeno.PathBuilder::line_to(path, zeno_vector(point))
        } else {
          mesh.diagnostics.push("LineTo ignored before MoveTo")
        }
      QuadTo(control, point) =>
        if has_current {
          @zeno.PathBuilder::quad_to(
            path,
            zeno_vector(control),
            zeno_vector(point),
          )
        } else {
          mesh.diagnostics.push("QuadTo ignored before MoveTo")
        }
      CubicTo(c1, c2, point) =>
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
      Close =>
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
        Fill(NonZero),
        brush_to_path_payload(brush),
      )
    None => ()
  }
}

///|
fn append_flattened_stroke_mesh(mesh : PathMesh, spec : @core.PathSpec) -> Bool {
  match spec.stroke {
    Some(brush) =>
      if spec.stroke_width > 0.0 {
        let payload = brush_to_path_payload(brush)
        let vertices : Array[PathVertex] = []
        let mut current : @core.Point? = None
        let mut subpath_start : @core.Point? = None
        let mut emitted = false
        for verb in spec.verbs {
          match verb {
            MoveTo(point) => {
              current = Some(point)
              subpath_start = Some(point)
            }
            LineTo(point) => {
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
                None => ()
              }
              current = Some(point)
            }
            QuadTo(control, point) => {
              match current {
                Some(start) =>
                  if append_quadratic_stroke_vertices(
                      vertices,
                      start,
                      control,
                      point,
                      spec.stroke_width,
                      payload,
                    ) {
                    emitted = true
                  }
                None => ()
              }
              current = Some(point)
            }
            CubicTo(c1, c2, point) => {
              match current {
                Some(start) =>
                  if append_cubic_stroke_vertices(
                      vertices,
                      start,
                      c1,
                      c2,
                      point,
                      spec.stroke_width,
                      payload,
                    ) {
                    emitted = true
                  }
                None => ()
              }
              current = Some(point)
            }
            Close => {
              match (current, subpath_start) {
                (Some(start), Some(point)) =>
                  if append_line_stroke_vertices(
                      vertices,
                      start,
                      point,
                      spec.stroke_width,
                      payload,
                    ) {
                    emitted = true
                  }
                _ => ()
              }
              current = None
              subpath_start = None
            }
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
fn append_quadratic_stroke_vertices(
  vertices : Array[PathVertex],
  start : @core.Point,
  control : @core.Point,
  end : @core.Point,
  stroke_width : Double,
  payload : PathBrushPayload,
) -> Bool {
  let segments = 12
  let mut previous = start
  let mut emitted = false
  for step in 1..<=segments {
    let t = step.to_double() / segments.to_double()
    let point = quadratic_point(start, control, end, t)
    if append_line_stroke_vertices(
        vertices, previous, point, stroke_width, payload,
      ) {
      emitted = true
    }
    previous = point
  }
  emitted
}

///|
fn append_cubic_stroke_vertices(
  vertices : Array[PathVertex],
  start : @core.Point,
  c1 : @core.Point,
  c2 : @core.Point,
  end : @core.Point,
  stroke_width : Double,
  payload : PathBrushPayload,
) -> Bool {
  let segments = 16
  let mut previous = start
  let mut emitted = false
  for step in 1..<=segments {
    let t = step.to_double() / segments.to_double()
    let point = cubic_point(start, c1, c2, end, t)
    if append_line_stroke_vertices(
        vertices, previous, point, stroke_width, payload,
      ) {
      emitted = true
    }
    previous = point
  }
  emitted
}

///|
fn quadratic_point(
  start : @core.Point,
  control : @core.Point,
  end : @core.Point,
  t : Double,
) -> @core.Point {
  let mt = 1.0 - t
  @core.Point::new(
    x=mt * mt * start.x + 2.0 * mt * t * control.x + t * t * end.x,
    y=mt * mt * start.y + 2.0 * mt * t * control.y + t * t * end.y,
  )
}

///|
fn cubic_point(
  start : @core.Point,
  c1 : @core.Point,
  c2 : @core.Point,
  end : @core.Point,
  t : Double,
) -> @core.Point {
  let mt = 1.0 - t
  let mt2 = mt * mt
  let t2 = t * t
  @core.Point::new(
    x=mt2 * mt * start.x +
      3.0 * mt2 * t * c1.x +
      3.0 * mt * t2 * c2.x +
      t2 * t * end.x,
    y=mt2 * mt * start.y +
      3.0 * mt2 * t * c1.y +
      3.0 * mt * t2 * c2.y +
      t2 * t * end.y,
  )
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
  push_path_vertex(vertices, Vector(start.x + nx, start.y + ny), payload)
  push_path_vertex(vertices, Vector(start.x - nx, start.y - ny), payload)
  push_path_vertex(vertices, Vector(end.x - nx, end.y - ny), payload)
  push_path_vertex(vertices, Vector(start.x + nx, start.y + ny), payload)
  push_path_vertex(vertices, Vector(end.x - nx, end.y - ny), payload)
  push_path_vertex(vertices, Vector(end.x + nx, end.y + ny), payload)
  true
}

///|
/// 把填充路径命令流展平为轮廓点集。QuadTo/CubicTo 的分段数与描边展平
/// 保持同一精度约定；Close 后轮廓隐式闭合（填充语义不要求显式回加起点）。
fn path_fill_contours(
  path : Array[@zeno.Command],
) -> Array[Array[@zeno.Vector]] {
  let contours : Array[Array[@zeno.Vector]] = []
  let mut current : Array[@zeno.Vector]? = None
  for command in path {
    match command {
      MoveTo(point) => {
        let contour : Array[@zeno.Vector] = []
        contour.push(Vector(point.x, point.y))
        contours.push(contour)
        current = Some(contour)
      }
      LineTo(point) =>
        match current {
          Some(contour) => contour.push(Vector(point.x, point.y))
          None => ()
        }
      QuadTo(control, point) =>
        match current {
          Some(contour) => {
            let start = contour[contour.length() - 1]
            let segments = 12
            for step in 1..<(segments + 1) {
              let t = step.to_double() / segments.to_double()
              let mt = 1.0 - t
              contour.push(
                Vector(
                  mt * mt * start.x + 2.0 * mt * t * control.x + t * t * point.x,
                  mt * mt * start.y + 2.0 * mt * t * control.y + t * t * point.y,
                ),
              )
            }
          }
          None => ()
        }
      CurveTo(c1, c2, point) =>
        match current {
          Some(contour) => {
            let start = contour[contour.length() - 1]
            let segments = 16
            for step in 1..<(segments + 1) {
              let t = step.to_double() / segments.to_double()
              let mt = 1.0 - t
              let mt2 = mt * mt
              let t2 = t * t
              contour.push(
                Vector(
                  mt2 * mt * start.x +
                  3.0 * mt2 * t * c1.x +
                  3.0 * mt * t2 * c2.x +
                  t2 * t * point.x,
                  mt2 * mt * start.y +
                  3.0 * mt2 * t * c1.y +
                  3.0 * mt * t2 * c2.y +
                  t2 * t * point.y,
                ),
              )
            }
          }
          None => ()
        }
      Close => current = None
    }
  }
  contours
}

///|
fn emit_normalized_triangle(
  emit : (Int, Int, Int) -> Unit,
  i0 : Int,
  i1 : Int,
  i2 : Int,
) -> Unit {
  // 以最小原始索引为旋转基准，保持绕序不变并让三角形发射顺序稳定。
  if i0 <= i1 && i0 <= i2 {
    emit(i0, i1, i2)
  } else if i1 <= i0 && i1 <= i2 {
    emit(i1, i2, i0)
  } else {
    emit(i2, i0, i1)
  }
}

///|
/// 耳切三角化：简单多边形（单轮廓、无洞）的填充三角化。
/// NonZero 洞语义暂不支持——当前填充用例（图形路径、图标）均为单轮廓，
/// 多轮廓按独立多边形分别处理。
fn triangulate_contour(
  contour : Array[@zeno.Vector],
  emit : (Int, Int, Int) -> Unit,
) -> Unit {
  let n = contour.length()
  if n < 3 {
    return
  }
  let indices : Array[Int] = []
  for i in 0..<n {
    indices.push(i)
  }
  let mut area2 = 0.0
  for i in 0..<n {
    let a = contour[i]
    let b = contour[(i + 1) % n]
    area2 = area2 + (a.x * b.y - b.x * a.y)
  }
  let positive = area2 > 0.0
  let eps = 1.0e-9
  let clip_budget = n * n + 16
  let mut clips = 0
  while indices.length() > 2 && clips < clip_budget {
    clips += 1
    let mut clipped = false
    let m = indices.length()
    let mut i = 0
    while i < m {
      let i0 = indices[(i + m - 1) % m]
      let i1 = indices[i]
      let i2 = indices[(i + 1) % m]
      let a = contour[i0]
      let b = contour[i1]
      let c = contour[i2]
      let turn = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
      let is_convex = if positive { turn > -eps } else { turn < eps }
      if is_convex {
        let mut contains_other = false
        for j in indices {
          if j != i0 && j != i1 && j != i2 {
            let p = contour[j]
            let d1 = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
            let d2 = (c.x - b.x) * (p.y - b.y) - (c.y - b.y) * (p.x - b.x)
            let d3 = (a.x - c.x) * (p.y - c.y) - (a.y - c.y) * (p.x - c.x)
            let inside = if positive {
              d1 > eps && d2 > eps && d3 > eps
            } else {
              d1 < -eps && d2 < -eps && d3 < -eps
            }
            if inside {
              contains_other = true
              break
            }
          }
        }
        if !contains_other {
          emit_normalized_triangle(emit, i0, i1, i2)
          ignore(indices.remove(i))
          clipped = true
          break
        }
      }
      i += 1
    }
    if !clipped {
      // 数值兜底：剪不出耳朵时退化为扇形三角化，保证不丢轮廓不挂死
      let last = indices.length()
      for k in 1..<(last - 1) {
        emit_normalized_triangle(emit, indices[0], indices[k], indices[k + 1])
      }
      break
    }
  }
}

///|
fn append_zeno_vertices(
  vertices : Array[PathVertex],
  path : Array[@zeno.Command],
  style : @zeno.Style,
  payload : PathBrushPayload,
) -> Unit {
  // 仅 Fill 走此处；Stroke 由 append_flattened_stroke_mesh 处理。
  match style {
    Fill(_) =>
      for contour in path_fill_contours(path) {
        triangulate_contour(contour, fn(i0, i1, i2) {
          push_path_vertex(vertices, contour[i0], payload)
          push_path_vertex(vertices, contour[i1], payload)
          push_path_vertex(vertices, contour[i2], payload)
        })
      }
    _ => ()
  }
}

///|
fn brush_to_path_payload(brush : @core.Brush) -> PathBrushPayload {
  match brush {
    Solid(color) =>
      {
        kind: 0.0,
        start: @core.Point::new(x=0.0, y=0.0),
        end: @core.Point::new(x=1.0, y=0.0),
        color0: color,
        color1: color,
      }
    LinearGradient(gradient) =>
      {
        kind: 0.0,
        start: gradient.start,
        end: gradient.end,
        color0: gradient.start_color,
        color1: gradient.end_color,
      }
    RadialGradient(gradient) =>
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
  Vector(point.x, point.y)
}
