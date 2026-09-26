///|
/// 构造带曲线的闭合外轮廓（凹槽 + 凸头 + 圆角），覆盖 QuadTo/CubicTo/Close。
fn block_outline_verbs() -> Array[@core.PathVerb] {
  let x0 = 60.0
  let y0 = 60.0
  let x1 = 228.0
  let y1 = 132.0
  let c = 8.0
  let cx = 144.0
  let r = 10.0
  let k = 0.5522847498 * r
  let pt = fn(px : Double, py : Double) { @core.Point::new(x=px, y=py) }
  [
    @core.PathVerb::MoveTo(pt(x0 + c, y0)),
    @core.PathVerb::LineTo(pt(cx - r, y0)),
    @core.PathVerb::CubicTo(
      pt(cx - r, y0 + k),
      pt(cx - k, y0 + r),
      pt(cx, y0 + r),
    ),
    @core.PathVerb::CubicTo(
      pt(cx + k, y0 + r),
      pt(cx + r, y0 + k),
      pt(cx + r, y0),
    ),
    @core.PathVerb::LineTo(pt(x1 - c, y0)),
    @core.PathVerb::QuadTo(pt(x1, y0), pt(x1, y0 + c)),
    @core.PathVerb::LineTo(pt(x1, y1 - c)),
    @core.PathVerb::QuadTo(pt(x1, y1), pt(x1 - c, y1)),
    @core.PathVerb::LineTo(pt(cx + r, y1)),
    @core.PathVerb::CubicTo(
      pt(cx + r, y1 + k),
      pt(cx + k, y1 + r),
      pt(cx, y1 + r),
    ),
    @core.PathVerb::CubicTo(
      pt(cx - k, y1 + r),
      pt(cx - r, y1 + k),
      pt(cx - r, y1),
    ),
    @core.PathVerb::LineTo(pt(x0 + c, y1)),
    @core.PathVerb::QuadTo(pt(x0, y1), pt(x0, y1 - c)),
    @core.PathVerb::LineTo(pt(x0, y0 + c)),
    @core.PathVerb::QuadTo(pt(x0, y0), pt(x0 + c, y0)),
    @core.PathVerb::Close,
  ]
}

///|
fn shoelace_area2(contour : Array[@zeno.Vector]) -> Double {
  let n = contour.length()
  let mut sum = 0.0
  for i in 0..<n {
    let a = contour[i]
    let b = contour[(i + 1) % n]
    sum = sum + (a.x * b.y - b.x * a.y)
  }
  sum
}

///|
fn mesh_triangle_area2_sum(mesh : PathMesh) -> Double {
  let mut sum = 0.0
  let components = mesh.vertices().map(fn(v) { v.components() })
  let count = components.length() / 3
  for t in 0..<count {
    let a = components[t * 3]
    let b = components[t * 3 + 1]
    let c = components[t * 3 + 2]
    let area2 = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    if area2 > 0.0 {
      sum += area2
    } else {
      sum -= area2
    }
  }
  sum
}

///|
fn spec_contour_area2_abs(spec : @core.PathSpec) -> Double {
  let sink = PathMesh::{ vertices: [], diagnostics: [], }
  let commands = zeno_path_from_spec(spec, sink)
  let mut sum = 0.0
  for contour in path_fill_contours(commands) {
    let a = shoelace_area2(contour)
    sum += if a > 0.0 { a } else { -a }
  }
  sum
}

///|
test "path fill tessellation conserves polygon area (curves included)" {
  let spec = @core.PathSpec::new(
    verbs=block_outline_verbs(),
    fill=Some(@core.Brush::solid(@core.Color::rgba(r=0.3, g=0.6, b=1.0))),
  )
  let mesh = tessellate_path(spec)
  inspect(mesh.diagnostics.length(), content="0")
  // 三角形面积和应与轮廓鞋带面积一致（耳切三角化不重不漏）
  let contour_area = spec_contour_area2_abs(spec)
  let triangle_area = mesh_triangle_area2_sum(mesh)
  let relative_error = (triangle_area - contour_area) / contour_area
  assert_true(relative_error.abs() < 0.001)
  // 全部顶点必须有限
  let mut nan_count = 0
  for vertex in mesh.vertices() {
    for component in vertex.components() {
      if component.is_nan() {
        nan_count += 1
      }
    }
  }
  inspect(nan_count, content="0")
}

///|
test "path fill tessellation fills a concave polygon" {
  // L 形凹多边形：面积 = 100*100 - 50*50 = 7500，验证凹角剪耳正确
  let pt = fn(px : Double, py : Double) { @core.Point::new(x=px, y=py) }
  let spec = @core.PathSpec::new(
    verbs=[
      @core.PathVerb::MoveTo(pt(0.0, 0.0)),
      @core.PathVerb::LineTo(pt(100.0, 0.0)),
      @core.PathVerb::LineTo(pt(100.0, 100.0)),
      @core.PathVerb::LineTo(pt(50.0, 100.0)),
      @core.PathVerb::LineTo(pt(50.0, 50.0)),
      @core.PathVerb::LineTo(pt(0.0, 50.0)),
      @core.PathVerb::Close,
    ],
    fill=Some(@core.Brush::solid(@core.Color::rgba(r=1.0, g=0.04, b=0.46))),
  )
  let mesh = tessellate_path(spec)
  inspect(mesh.diagnostics.length(), content="0")
  // n-2 = 4 个三角形
  inspect(mesh.vertices().length(), content="12")
  let contour_area = spec_contour_area2_abs(spec)
  let triangle_area = mesh_triangle_area2_sum(mesh)
  let relative_error = (triangle_area - contour_area) / contour_area
  assert_true(relative_error.abs() < 0.001)
  assert_true((triangle_area / 2.0 - 7500.0).abs() < 0.5)
}

///|
test "path fill tessellation ignores degenerate contours" {
  let pt = fn(px : Double, py : Double) { @core.Point::new(x=px, y=py) }
  let mesh = tessellate_path(
    @core.PathSpec::new(
      verbs=[
        @core.PathVerb::MoveTo(pt(1.0, 1.0)),
        @core.PathVerb::LineTo(pt(2.0, 2.0)),
        @core.PathVerb::Close,
      ],
      fill=Some(@core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0))),
    ),
  )
  inspect(mesh.vertices().length(), content="0")
}
