///|
/// Three sketches built with the p5 MoonBit core. They exercise the same API
/// surface as p5.js: shapes, HSB colors, transforms, text, vectors, Perlin
/// noise, random numbers, and pointer callbacks.

///|
priv struct TrailPoint {
  x : Double
  y : Double
  hue : Double
}

///|
priv struct ShapesState {
  trail : Array[TrailPoint]
  mut badge : @p5.Image?
  mut vector_badge : @p5.Sketch?
}

///|
fn ShapesState::new() -> ShapesState {
  { trail: [], badge: None, vector_badge: None, }
}

///|
fn ShapesState::push(
  self : ShapesState,
  x : Double,
  y : Double,
  hue : Double,
) -> Unit {
  self.trail.push({ x, y, hue, })
  while self.trail.length() > 260 {
    ignore(self.trail.remove(0))
  }
}

///|
priv struct FlowParticle {
  mut x : Double
  mut y : Double
}

///|
priv struct FlowState {
  particles : Array[FlowParticle]
  mut speed : Double
}

///|
fn FlowState::new() -> FlowState {
  { particles: [], speed: 1.0, }
}

///|
fn FlowState::reset(
  self : FlowState,
  p : @p5.Sketch,
  width : Double,
  height : Double,
) -> Unit {
  self.particles.clear()
  for _ in 0..<300 {
    let x = p.random_range(0.0, width)
    let y = p.random_range(0.0, height)
    self.particles.push({ x, y, })
  }
}

///|
priv struct Ball {
  mut x : Double
  mut y : Double
  mut vx : Double
  mut vy : Double
  radius : Double
  hue : Double
}

///|
priv struct BallState {
  balls : Array[Ball]
}

///|
fn BallState::new() -> BallState {
  { balls: [], }
}

///|
fn BallState::reset(
  self : BallState,
  p : @p5.Sketch,
  width : Double,
  height : Double,
) -> Unit {
  self.balls.clear()
  for index in 0..<18 {
    self.balls.push({
      x: p.random_range(60.0, width - 60.0),
      y: p.random_range(60.0, height / 2.0),
      vx: p.random_range(-2.5, 2.5),
      vy: p.random_range(-1.0, 1.0),
      radius: p.random_range(10.0, 28.0),
      hue: index.to_double() * 20.0,
    })
  }
}

///|
fn BallState::add_ball(self : BallState, p : @p5.Sketch) -> Unit {
  self.balls.push({
    x: p.mouse_x,
    y: p.mouse_y,
    vx: p.random_range(-3.0, 3.0),
    vy: p.random_range(-4.0, -1.0),
    radius: p.random_range(8.0, 22.0),
    hue: p.random_range(0.0, 360.0),
  })
  if self.balls.length() > 60 {
    ignore(self.balls.remove(0))
  }
}

///|
/// Owns the sketch views and their app-side state.
pub struct DemoBank {
  priv shapes : @p5m.SketchView
  priv flow : @p5m.SketchView
  priv balls : @p5m.SketchView
  priv intro : @p5m.SketchView
  priv shapes_state : ShapesState
  priv flow_state : FlowState
  priv ball_state : BallState
  priv width : Double
  priv height : Double
}

///|
pub fn DemoBank::new(width : Double, height : Double) -> DemoBank {
  let shapes = @p5m.SketchView::new(width, height)
  let flow = @p5m.SketchView::new(width, height)
  let balls = @p5m.SketchView::new(width, height)
  let intro = @p5m.SketchView::new(width, height)
  let shapes_state = ShapesState::new()
  let flow_state = FlowState::new()
  let ball_state = BallState::new()
  configure_shapes(shapes.sketch(), shapes_state, width, height)
  configure_flow(flow.sketch(), flow_state, width, height)
  configure_balls(balls.sketch(), ball_state, width, height)
  configure_intro(intro.sketch(), IntroState::new(), width, height)
  {
    shapes,
    flow,
    balls,
    intro,
    shapes_state,
    flow_state,
    ball_state,
    width,
    height,
  }
}

///|
fn configure_shapes(
  p : @p5.Sketch,
  state : ShapesState,
  width : Double,
  height : Double,
) -> Unit {
  p.setup(p => {
    p.random_seed(7.0)
    p.set_mouse_position(width / 2.0, height / 2.0)
    p.background((9.0, 11.0, 18.0))
    // Offscreen RGBA buffer: createImage -> set -> image() (PNG data URI).
    let badge = p.create_image(24, 24)
    for py in 0..<24 {
      for px in 0..<24 {
        let on = (px / 6 + py / 6) % 2 == 0
        badge.set(
          px,
          py,
          if on {
            @p5.Color::rgb(90.0, 210.0, 255.0)
          } else {
            @p5.Color::rgb(28.0, 48.0, 78.0)
          },
        )
      }
    }
    state.badge = Some(badge)
    let mark = p.create_graphics(24, 24)
    mark.no_stroke()
    mark.fill((255.0, 170.0, 60.0))
    mark.circle(12.0, 12.0, 24.0)
    mark.fill((9.0, 11.0, 18.0))
    mark.circle(12.0, 12.0, 12.0)
    state.vector_badge = Some(mark)
  })
  p.on_key_pressed(p => {
    if p.key == "r" {
      state.trail.clear()
    }
    if p.key == "n" {
      for _ in 0..<18 {
        state.push(
          p.random_range(0.0, width),
          p.random_range(0.0, height),
          p.random_range(0.0, 360.0),
        )
      }
    }
  })
  p.draw(p => {
    p.color_mode(@p5.RGB)
    p.no_stroke()
    p.background((9.0, 11.0, 18.0))
    if p.mouse_is_pressed {
      state.push(p.mouse_x, p.mouse_y, p.frame_count.to_double() * 3.0 % 360.0)
    }
    for index, point in state.trail {
      let fade = (index.to_double() + 1.0) / state.trail.length().to_double()
      p.color_mode(@p5.HSB)
      p.fill((point.hue, 70.0, 100.0, 0.05 + 0.35 * fade))
      p.circle(point.x, point.y, 18.0 + 18.0 * fade)
    }
    p.color_mode(@p5.RGB)
    p.push()
    p.translate(width / 2.0, height / 2.0)
    p.rotate(p.frame_count.to_double() * 0.008)
    p.color_mode(@p5.HSB)
    for index in 0..<14 {
      let angle = @p5.TAU * index.to_double() / 14.0
      let radius = 150.0 +
        32.0 * p.sin(p.frame_count.to_double() * 0.02 + index.to_double())
      let x = p.cos(angle) * radius
      let y = p.sin(angle) * radius
      p.fill((index.to_double() * 25.7, 72.0, 100.0, 0.18))
      p.circle(x, y, 78.0)
      p.fill((index.to_double() * 25.7, 76.0, 100.0, 0.9))
      p.circle(
        x,
        y,
        22.0 + 7.0 * p.sin(p.frame_count.to_double() * 0.05 + index.to_double()),
      )
    }
    p.pop()
    p.color_mode(@p5.HSB)
    if p.mouse_is_pressed {
      p.fill((p.frame_count.to_double() * 3.0 % 360.0, 70.0, 100.0, 0.7))
      p.no_stroke()
      p.circle(p.mouse_x, p.mouse_y, 46.0)
    }
    p.no_fill()
    p.stroke((p.frame_count.to_double() * 3.0 % 360.0, 60.0, 100.0, 0.55))
    p.stroke_weight(1.5)
    p.circle(p.mouse_x, p.mouse_y, 38.0)
    p.no_stroke()
    // A Catmull-Rom ribbon built with spline_vertex; the first and last
    // samples are control points, so the visible span is 0.25w..0.75w.
    p.no_fill()
    p.stroke((205.0, 45.0, 100.0, 0.35))
    p.stroke_weight(2.0)
    p.begin_shape()
    p.spline_vertex(0.0, height - 64.0)
    p.spline_vertex(
      width * 0.25,
      height - 82.0 + 8.0 * p.sin(p.frame_count.to_double() * 0.02),
    )
    p.spline_vertex(
      width * 0.5,
      height - 64.0 + 6.0 * p.cos(p.frame_count.to_double() * 0.03),
    )
    p.spline_vertex(width * 0.75, height - 46.0)
    p.spline_vertex(width, height - 64.0)
    p.end_shape()
    p.no_stroke()
    match state.badge {
      Some(badge) => p.image(badge, width - 60.0, 34.0, width=36.0, height=36.0)
      None => ()
    }
    match state.vector_badge {
      Some(mark) => p.image(mark, width - 104.0, 34.0, width=36.0, height=36.0)
      None => ()
    }
    p.color_mode(@p5.RGB)
    p.fill((235.0, 238.0, 245.0))
    p.text_size(20.0)
    p.text("p5 core on MoUI", 24.0, 38.0)
    p.fill((145.0, 156.0, 178.0))
    p.text_size(13.0)
    p.text("shapes · HSB · transforms · text · pointer", 24.0, 60.0)
    // Stroke-only outlined text: no fill, the orange outline carries it.
    p.no_fill()
    p.stroke((255.0, 170.0, 60.0))
    p.stroke_weight(1.2)
    p.text_size(22.0)
    p.text("outlined", width - 150.0, height - 56.0)
    p.no_stroke()
    p.fill((120.0, 132.0, 154.0))
    p.text("drag to paint · r clear · n burst · s save", 24.0, height - 24.0)
  })
}

///|
fn configure_flow(
  p : @p5.Sketch,
  state : FlowState,
  width : Double,
  height : Double,
) -> Unit {
  p.setup(p => {
    p.random_seed(19.0)
    p.noise_seed(19.0)
    p.set_mouse_position(width / 2.0, height / 2.0)
    p.background((7.0, 9.0, 16.0))
    state.reset(p, width, height)
    p.color_mode(@p5.HSB)
  })
  p.draw(p => {
    p.color_mode(@p5.RGB)
    p.no_stroke()
    p.background((7.0, 9.0, 16.0))
    p.color_mode(@p5.HSB)
    let z = p.millis() * 0.00012 * state.speed +
      p.frame_count.to_double() * 0.001
    p.stroke_weight(1.15)
    for particle in state.particles {
      let angle = p.noise(particle.x * 0.0028, y=particle.y * 0.0028, z~) *
        @p5.TAU *
        2.0
      particle.x = particle.x + p.cos(angle) * 1.35 * state.speed
      particle.y = particle.y + p.sin(angle) * 1.35 * state.speed
      if particle.x < 0.0 ||
        particle.x > width ||
        particle.y < 0.0 ||
        particle.y > height {
        particle.x = p.random_range(0.0, width)
        particle.y = p.random_range(0.0, height)
      }
      let dx = p.cos(angle)
      let dy = p.sin(angle)
      p.stroke((angle * 57.2958 % 360.0, 62.0, 100.0, 0.58))
      p.line(
        particle.x - dx * 9.0,
        particle.y - dy * 9.0,
        particle.x + dx * 3.0,
        particle.y + dy * 3.0,
      )
    }
    p.color_mode(@p5.RGB)
    p.fill((235.0, 238.0, 245.0))
    p.text_size(20.0)
    p.text("flow field", 24.0, 38.0)
    p.fill((145.0, 156.0, 178.0))
    p.text_size(13.0)
    p.text("Perlin noise · vectors · 300 particles", 24.0, 60.0)
    p.fill((120.0, 132.0, 154.0))
    p.text("press reseeds · wheel changes speed", width - 245.0, height - 24.0)
  })
  p.on_mouse_pressed(p => state.reset(p, width, height))
  p.on_mouse_wheel((_, delta) => {
    state.speed = (state.speed + delta * 0.002).max(0.2).min(4.0)
  })
  p.on_key_pressed(p => if p.key == "r" { state.reset(p, width, height) })
}

///|
fn configure_balls(
  p : @p5.Sketch,
  state : BallState,
  width : Double,
  height : Double,
) -> Unit {
  p.setup(p => {
    p.random_seed(31.0)
    p.set_mouse_position(width / 2.0, height / 2.0)
    p.background((10.0, 12.0, 18.0))
    state.reset(p, width, height)
  })
  p.draw(p => {
    p.color_mode(@p5.RGB)
    p.no_stroke()
    p.background((10.0, 12.0, 18.0))
    p.color_mode(@p5.HSB)
    for ball in state.balls {
      ball.vy = ball.vy + 0.28
      ball.x = ball.x + ball.vx
      ball.y = ball.y + ball.vy
      if ball.x < ball.radius {
        ball.x = ball.radius
        ball.vx = ball.vx.abs() * 0.92
      }
      if ball.x > width - ball.radius {
        ball.x = width - ball.radius
        ball.vx = -ball.vx.abs() * 0.92
      }
      if ball.y > height - ball.radius {
        ball.y = height - ball.radius
        ball.vy = -ball.vy.abs() * 0.9
      }
      if p.mouse_is_pressed {
        let dx = ball.x - p.mouse_x
        let dy = ball.y - p.mouse_y
        let distance = (dx * dx + dy * dy).sqrt().max(20.0)
        if distance < 190.0 {
          ball.vx = ball.vx + dx / distance * 0.55
          ball.vy = ball.vy + dy / distance * 0.55
        }
      }
      p.fill((ball.hue, 62.0, 100.0, 0.9))
      p.circle(ball.x, ball.y, ball.radius * 2.0)
    }
    p.color_mode(@p5.RGB)
    p.fill((235.0, 238.0, 245.0))
    p.text_size(20.0)
    p.text("bouncing balls", 24.0, 38.0)
    p.fill((145.0, 156.0, 178.0))
    p.text_size(13.0)
    p.text("gravity · collision · pointer repulsion", 24.0, 60.0)
    p.fill((120.0, 132.0, 154.0))
    p.text("click / space adds a ball", width - 175.0, height - 24.0)
  })
  p.on_mouse_pressed(p => state.add_ball(p))
  p.on_key_pressed(p => if p.key == " " { state.add_ball(p) })
}

///|
pub fn DemoBank::view(
  self : DemoBank,
  demo : Int32,
) -> @moui.View[@p5m.CanvasInput] {
  match demo {
    1 => self.flow.view()
    2 => self.balls.view()
    3 => self.intro.view()
    _ => self.shapes.view()
  }
}

///|
pub fn DemoBank::handle_input(
  self : DemoBank,
  demo : Int32,
  input : @p5m.CanvasInput,
) -> Unit {
  // "s" snapshots the active canvas through the installed rasterizer. On
  // hosts without one (the Web build today) save_canvas returns false.
  match input {
    @p5m.Key("s", _, true, _) =>
      ignore(self.canvas(demo).save_canvas("p5-canvas.png"))
    _ => ()
  }
  match demo {
    1 => self.flow.handle_input(input)
    2 => self.balls.handle_input(input)
    3 => self.intro.handle_input(input)
    _ => self.shapes.handle_input(input)
  }
}

///|
/// The live sketch view for a demo slot; `render_intro_frames` walks this to
/// rasterize the introduction offline.
pub fn DemoBank::sketch_view(self : DemoBank, demo : Int32) -> @p5m.SketchView {
  self.canvas(demo)
}

///|
/// A fresh demo bank for offline capture.
pub fn intro_bank() -> DemoBank {
  DemoBank::new(900.0, 540.0)
}

///|
fn DemoBank::canvas(self : DemoBank, demo : Int32) -> @p5m.SketchView {
  match demo {
    1 => self.flow
    2 => self.balls
    3 => self.intro
    _ => self.shapes
  }
}

///|
fn DemoBank::sketch(self : DemoBank, demo : Int32) -> @p5.Sketch {
  match demo {
    1 => self.flow.sketch()
    2 => self.balls.sketch()
    3 => self.intro.sketch()
    _ => self.shapes.sketch()
  }
}

///|
pub fn DemoBank::set_paused(
  self : DemoBank,
  demo : Int32,
  paused : Bool,
) -> Unit {
  let sketch = self.sketch(demo)
  if paused {
    sketch.no_loop()
  } else {
    sketch.loop_()
  }
}

///|
pub fn DemoBank::reset(self : DemoBank, demo : Int32) -> Unit {
  let sketch = self.sketch(demo)
  match demo {
    1 => self.flow_state.reset(sketch, self.width, self.height)
    2 => self.ball_state.reset(sketch, self.width, self.height)
    _ => self.shapes_state.trail.clear()
  }
  sketch.reset_sketch()
}

///|
/// Timeline state for the self-playing MoUI introduction sketch.
priv struct IntroState {
  mut start_ms : Double
}

///|
fn IntroState::new() -> IntroState {
  { start_ms: 0.0, }
}

///|
/// p5's RGB color mode reads a 4-tuple alpha on the 0..255 channel range
/// (`fill(r,g,b,128)` is half-transparent), while HSB/HSL use 0..1. The intro
/// designs in 0..1 alpha, so every translucent paint goes through these two
/// helpers instead of a raw tuple.
fn intro_fill(
  p : @p5.Sketch,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Unit {
  p.fill((r, g, b, a.max(0.0).min(1.0) * 255.0))
}

///|
fn intro_stroke(
  p : @p5.Sketch,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) -> Unit {
  p.stroke((r, g, b, a.max(0.0).min(1.0) * 255.0))
}

///|
fn intro_ease(t : Double) -> Double {
  let t = t.max(0.0).min(1.0)
  let u = 1.0 - t
  1.0 - u * u * u
}

///|
/// 0 -> 1 -> 0 envelope over a scene window, in seconds.
fn intro_envelope(
  t : Double,
  start : Double,
  hold : Double,
  fade : Double,
) -> Double {
  if t < start || t >= start + hold + fade {
    0.0
  } else if t < start + fade {
    intro_ease((t - start) / fade)
  } else if t < start + hold {
    1.0
  } else {
    intro_ease((start + hold + fade - t) / fade)
  }
}

///|
/// Drifting dust: (x, y, speed, phase).
fn intro_dust(
  p : @p5.Sketch,
  width : Double,
  height : Double,
) -> Array[(Double, Double, Double, Double)] {
  p.random_seed(41.0)
  let dust : Array[(Double, Double, Double, Double)] = []
  for _ in 0..<24 {
    dust.push(
      (
        p.random_range(0.0, width),
        p.random_range(0.0, height),
        p.random_range(0.05, 0.32),
        p.random_range(0.0, 6.28),
      ),
    )
  }
  dust
}

///|
fn intro_background(
  p : @p5.Sketch,
  dust : Array[(Double, Double, Double, Double)],
  width : Double,
  height : Double,
  t : Double,
) -> Unit {
  // Vertical gradient, built from bands so it works with solid fills only.
  let bands = 10
  let step = height / bands.to_double()
  for i in 0..<bands {
    let k = i.to_double() / (bands - 1).to_double()
    let k = k * k * (3.0 - 2.0 * k)
    p.fill((10.0 - 6.0 * k, 15.0 - 9.0 * k, 30.0 - 19.0 * k))
    p.rect(0.0, i.to_double() * step, width, step + 1.0)
  }
  // Soft accent glow behind the hero.
  let cx = width * 0.5
  let cy = height * 0.40 + 26.0 * p.sin(t * 0.0004)
  for i in 0..<4 {
    let k = i.to_double() / 3.0
    let radius = 380.0 - 240.0 * k
    intro_fill(p, 52.0, 92.0, 176.0, 0.018 + 0.030 * k)
    p.circle(cx, cy, radius)
  }
  // Dust.
  p.no_stroke()
  for particle in dust {
    let (px, py, speed, phase) = particle
    let x = (px + t * speed * 0.06) % (width + 40.0) - 20.0
    let y = py + 6.0 * p.sin(t * 0.0004 + phase)
    intro_fill(p, 128.0, 158.0, 208.0, 0.05 + 0.04 * p.sin(t * 0.001 + phase))
    p.circle(x, y, 1.6)
  }
}

///|
fn intro_scene_hero(
  p : @p5.Sketch,
  width : Double,
  height : Double,
  t : Double,
  sa : Double,
) -> Unit {
  let cx = width / 2.0
  let cy = height / 2.0 - 26.0
  let word = intro_ease((t - 0.35) / 0.85)
  if word > 0.0 {
    p.text_font("Helvetica Neue")
    p.text_style(@p5.Bold)
    p.text_size(112.0)
    p.text_align(@p5.HCenter, vertical=@p5.VCenter)
    p.no_stroke()
    intro_fill(p, 236.0, 241.0, 250.0, sa * word)
    p.text("MoUI", cx, cy + (1.0 - word) * 26.0)
  }
  let line = intro_ease((t - 1.0) / 0.7)
  if line > 0.0 {
    let w = 132.0 * line
    p.no_stroke()
    intro_fill(p, 91.0, 140.0, 255.0, sa * 0.95)
    p.rect(cx - w / 2.0, cy + 68.0, w, 2.0)
  }
  let sub = intro_ease((t - 1.3) / 0.8)
  if sub > 0.0 {
    p.text_style(@p5.Normal)
    p.text_size(21.0)
    p.text_align(@p5.HCenter, vertical=@p5.VCenter)
    p.no_stroke()
    intro_fill(p, 150.0, 163.0, 188.0, sa * sub)
    p.text(
      "MoonBit-native interface framework",
      cx,
      cy + 110.0 + (1.0 - sub) * 12.0,
    )
  }
  let micro = intro_ease((t - 2.2) / 0.8)
  if micro > 0.0 {
    p.text_size(13.5)
    p.no_stroke()
    intro_fill(p, 96.0, 108.0, 134.0, sa * micro)
    p.text("pure TEA  ·  renderer-neutral  ·  agent-native", cx, cy + 198.0)
  }
}

///|
fn intro_pillar_icon(
  p : @p5.Sketch,
  kind : Int32,
  icx : Double,
  icy : Double,
  accent : (Double, Double, Double),
  sa : Double,
  t : Double,
) -> Unit {
  match kind {
    0 => {
      // AI-native: an orbit with two satellites.
      p.no_fill()
      intro_stroke(p, accent.0, accent.1, accent.2, sa * 0.85)
      p.stroke_weight(1.4)
      p.circle(icx, icy, 30.0)
      p.no_stroke()
      intro_fill(p, accent.0, accent.1, accent.2, sa)
      p.circle(icx, icy, 9.0)
      let a1 = t * 0.0028
      let a2 = a1 + 2.4
      intro_fill(p, accent.0, accent.1, accent.2, sa * 0.85)
      p.circle(icx + p.cos(a1) * 30.0, icy + p.sin(a1) * 30.0, 5.0)
      intro_fill(p, accent.0, accent.1, accent.2, sa * 0.55)
      p.circle(icx + p.cos(a2) * 30.0, icy + p.sin(a2) * 30.0, 3.5)
    }
    1 => {
      // Pure TEA: the model -> view -> update loop.
      let top = (0.0, -26.0)
      let left = (-25.0, 16.0)
      let right = (25.0, 16.0)
      p.no_fill()
      intro_stroke(p, accent.0, accent.1, accent.2, sa * 0.8)
      p.stroke_weight(1.4)
      p.begin_shape()
      p.vertex(icx + top.0, icy + top.1)
      p.vertex(icx + left.0, icy + left.1)
      p.vertex(icx + right.0, icy + right.1)
      p.end_shape(close=true)
      p.no_stroke()
      intro_fill(p, 210.0, 220.0, 238.0, sa)
      p.text_size(10.0)
      p.text_align(@p5.HCenter, vertical=@p5.VCenter)
      p.text("M", icx + top.0, icy + top.1 - 12.0)
      p.text("V", icx + left.0 - 12.0, icy + left.1 + 10.0)
      p.text("U", icx + right.0 + 12.0, icy + right.1 + 10.0)
      let phase = t * 0.0006 % 1.0 * 3.0
      let edge = phase.to_int().min(2)
      let frac = phase - edge.to_double()
      let a = match edge {
        0 => top
        1 => left
        _ => right
      }
      let b = match edge {
        0 => left
        1 => right
        _ => top
      }
      intro_fill(p, accent.0, accent.1, accent.2, sa)
      p.circle(
        icx + a.0 + (b.0 - a.0) * frac,
        icy + a.1 + (b.1 - a.1) * frac,
        5.0,
      )
    }
    _ => {
      // Renderer-neutral: three stacked command targets.
      let offsets = [(-20.0, 2.0), (0.0, -3.0), (20.0, 2.0)]
      for offset in offsets {
        p.no_stroke()
        intro_fill(p, accent.0, accent.1, accent.2, sa * 0.10)
        p.rect(
          icx + offset.0 - 19.0,
          icy + offset.1 - 13.0,
          38.0,
          26.0,
          tl=6.0,
          tr=6.0,
          br=6.0,
          bl=6.0,
        )
        p.no_fill()
        intro_stroke(p, accent.0, accent.1, accent.2, sa * 0.75)
        p.stroke_weight(1.3)
        p.rect(
          icx + offset.0 - 19.0,
          icy + offset.1 - 13.0,
          38.0,
          26.0,
          tl=6.0,
          tr=6.0,
          br=6.0,
          bl=6.0,
        )
      }
    }
  }
}

///|
fn intro_pillar_card(
  p : @p5.Sketch,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  accent : (Double, Double, Double),
  number : String,
  title : String,
  desc : String,
  icon : Int32,
  sa : Double,
  t : Double,
) -> Unit {
  p.no_stroke()
  intro_fill(p, 14.0, 22.0, 40.0, sa * 0.94)
  p.rect(x, y, w, h, tl=18.0, tr=18.0, br=18.0, bl=18.0)
  p.no_fill()
  intro_stroke(p, accent.0, accent.1, accent.2, sa * 0.40)
  p.stroke_weight(1.2)
  p.rect(x, y, w, h, tl=18.0, tr=18.0, br=18.0, bl=18.0)
  // Accent dash and index.
  p.no_stroke()
  p.fill((accent.0, accent.1, accent.2))
  p.rect(x + 20.0, y + 20.0, 26.0, 3.0)
  intro_fill(p, 104.0, 116.0, 142.0, sa)
  p.text_size(12.0)
  p.text_align(@p5.Right, vertical=@p5.Top)
  p.text(number, x + w - 20.0, y + 18.0)
  intro_pillar_icon(p, icon, x + w / 2.0, y + 92.0, accent, sa, t)
  p.no_stroke()
  p.text_align(@p5.Left, vertical=@p5.Baseline)
  p.text_style(@p5.Bold)
  p.text_size(19.0)
  intro_fill(p, 226.0, 233.0, 245.0, sa)
  p.text(title, x + 20.0, y + h - 52.0)
  p.text_style(@p5.Normal)
  p.text_size(12.5)
  intro_fill(p, 118.0, 130.0, 156.0, sa)
  p.text(desc, x + 20.0, y + h - 26.0)
}

///|
fn intro_scene_pillars(
  p : @p5.Sketch,
  width : Double,
  t : Double,
  sa : Double,
) -> Unit {
  let cx = width / 2.0
  let head = intro_ease((t - 5.25) / 0.6)
  if head > 0.0 {
    p.no_stroke()
    p.text_align(@p5.HCenter, vertical=@p5.Baseline)
    p.text_style(@p5.Bold)
    p.text_size(26.0)
    intro_fill(p, 230.0, 236.0, 247.0, sa * head)
    p.text("Three ideas, one framework", cx, 118.0)
  }
  let cards = [
    (
      "01",
      "AI-native",
      "agents observe and drive the same UI",
      0,
      (56.0, 189.0, 248.0),
    ),
    (
      "02",
      "Pure TEA",
      "model, update, view — no hidden state",
      1,
      (167.0, 139.0, 250.0),
    ),
    (
      "03",
      "Renderer-neutral",
      "one command stream, every backend",
      2,
      (251.0, 191.0, 36.0),
    ),
  ]
  let w = 248.0
  let gap = 26.0
  let total = w * 3.0 + gap * 2.0
  let left = cx - total / 2.0
  for index, card in cards {
    let shown = intro_ease((t - 5.4 - index.to_double() * 0.16) / 0.6)
    if shown > 0.0 {
      let rise = (1.0 - shown) * 34.0
      intro_pillar_card(
        p,
        left + index.to_double() * (w + gap),
        230.0 + rise,
        w,
        190.0,
        card.4,
        card.0,
        card.1,
        card.2,
        card.3,
        sa * shown,
        t,
      )
    }
  }
}

///|
fn intro_scene_platforms(
  p : @p5.Sketch,
  width : Double,
  t : Double,
  sa : Double,
) -> Unit {
  let cx = width / 2.0
  let head = intro_ease((t - 10.15) / 0.6)
  if head > 0.0 {
    p.no_stroke()
    p.text_align(@p5.HCenter, vertical=@p5.Baseline)
    p.text_style(@p5.Bold)
    p.text_size(28.0)
    intro_fill(p, 230.0, 236.0, 247.0, sa * head)
    p.text("One sketch. Every platform.", cx, 112.0)
  }
  let sub = intro_ease((t - 10.4) / 0.6)
  if sub > 0.0 {
    p.no_stroke()
    p.text_style(@p5.Normal)
    p.text_size(15.0)
    p.text_align(@p5.HCenter, vertical=@p5.Baseline)
    intro_fill(p, 120.0, 133.0, 160.0, sa * sub)
    p.text("Same draw commands, seven native hosts", cx, 146.0)
  }
  let rows = [
    [
      ("macOS", (200.0, 214.0, 230.0)),
      ("Web", (91.0, 140.0, 255.0)),
      ("Windows", (106.0, 184.0, 255.0)),
      ("Linux", (250.0, 190.0, 80.0)),
    ],
    [
      ("iOS", (196.0, 166.0, 255.0)),
      ("Android", (126.0, 220.0, 152.0)),
      ("HarmonyOS", (108.0, 206.0, 236.0)),
    ],
  ]
  let chip_w = 168.0
  let chip_h = 50.0
  let chip_gap = 14.0
  p.text_size(15.0)
  p.text_align(@p5.HCenter, vertical=@p5.VCenter)
  for row_index, row in rows {
    let row_width = row.length().to_double() * chip_w +
      (row.length().to_double() - 1.0) * chip_gap
    let left = cx - row_width / 2.0
    let y = 305.0 + row_index.to_double() * 66.0
    for chip_index, chip in row {
      let order = row_index * 4 + chip_index
      let shown = intro_ease((t - 10.4 - order.to_double() * 0.09) / 0.45)
      if shown > 0.0 {
        let x = left + chip_index.to_double() * (chip_w + chip_gap)
        let accent = chip.1
        p.push()
        p.translate(x + chip_w / 2.0, y)
        p.scale(0.92 + 0.08 * shown)
        p.no_stroke()
        intro_fill(p, 13.0, 20.0, 35.0, sa * shown * 0.92)
        p.rect(
          -chip_w / 2.0,
          -chip_h / 2.0,
          chip_w,
          chip_h,
          tl=25.0,
          tr=25.0,
          br=25.0,
          bl=25.0,
        )
        p.no_fill()
        intro_stroke(p, accent.0, accent.1, accent.2, 0.38 * sa * shown)
        p.stroke_weight(1.2)
        p.rect(
          -chip_w / 2.0,
          -chip_h / 2.0,
          chip_w,
          chip_h,
          tl=25.0,
          tr=25.0,
          br=25.0,
          bl=25.0,
        )
        p.no_stroke()
        intro_fill(p, 226.0, 233.0, 245.0, sa * shown)
        p.text(chip.0, 0.0, 0.0)
        p.pop()
      }
    }
  }
}

///|
fn intro_scene_closing(
  p : @p5.Sketch,
  width : Double,
  height : Double,
  t : Double,
  sa : Double,
) -> Unit {
  let cx = width / 2.0
  let cy = height / 2.0 - 12.0
  let word = intro_ease((t - 15.15) / 0.8)
  if word > 0.0 {
    // True stroke-only wordmark: transparent fill + glyph outline.
    p.text_font("Helvetica Neue")
    p.text_style(@p5.Bold)
    p.text_size(92.0)
    p.text_align(@p5.HCenter, vertical=@p5.VCenter)
    p.no_fill()
    intro_stroke(p, 126.0, 166.0, 255.0, sa * word)
    p.stroke_weight(1.3)
    p.text("MoUI", cx, cy - 30.0 + (1.0 - word) * 18.0)
  }
  let tagline = intro_ease((t - 15.7) / 0.8)
  if tagline > 0.0 {
    p.no_stroke()
    p.text_style(@p5.Normal)
    p.text_size(24.0)
    p.text_align(@p5.HCenter, vertical=@p5.VCenter)
    intro_fill(p, 220.0, 228.0, 242.0, sa * tagline)
    p.text("Write once. Render everywhere.", cx, cy + 58.0)
  }
  let url = intro_ease((t - 16.3) / 0.8)
  if url > 0.0 {
    p.text_size(15.0)
    intro_fill(p, 110.0, 122.0, 148.0, sa * url)
    p.text("github.com/wzzc-dev/MoUI", cx, cy + 104.0)
  }
}

///|
fn configure_intro(
  p : @p5.Sketch,
  state : IntroState,
  width : Double,
  height : Double,
) -> Unit {
  let dust = intro_dust(p, width, height)
  p.setup(p => {
    state.start_ms = p.millis()
    p.background((6.0, 9.0, 16.0))
  })
  p.draw(p => {
    // Seconds, looping every 20s.
    let t = (p.millis() - state.start_ms) % 20000.0 / 1000.0
    p.color_mode(@p5.RGB)
    p.no_stroke()
    intro_background(p, dust, width, height, t * 1000.0)
    let s1 = intro_envelope(t, 0.25, 4.55, 0.6)
    if s1 > 0.0 {
      intro_scene_hero(p, width, height, t, s1)
    }
    let s2 = intro_envelope(t, 5.15, 4.35, 0.6)
    if s2 > 0.0 {
      intro_scene_pillars(p, width, t, s2)
    }
    let s3 = intro_envelope(t, 10.0, 4.3, 0.6)
    if s3 > 0.0 {
      intro_scene_platforms(p, width, t, s3)
    }
    let s4 = intro_envelope(t, 15.0, 3.6, 0.6)
    if s4 > 0.0 {
      intro_scene_closing(p, width, height, t, s4)
    }
    // Loop seam: fade up from black at the start, down to black at the end.
    if t < 0.4 {
      p.no_stroke()
      intro_fill(p, 3.0, 5.0, 10.0, 1.0 - t / 0.4)
      p.rect(0.0, 0.0, width, height)
    }
    if t > 19.2 {
      let k = ((t - 19.2) / 0.8).min(1.0)
      p.no_stroke()
      intro_fill(p, 3.0, 5.0, 10.0, k)
      p.rect(0.0, 0.0, width, height)
    }
  })
}
