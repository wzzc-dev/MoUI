// MoUI runtime hot-path micro-benchmark.
//
// Measures combined impact of: T1.1 early exit, T1.2 dedup scan,
// T1.3 pre-allocated commands, T2.3 dirty-list sync.
//
// Uses set_environment toggle each frame to force a full rebuild path.

extern "c" fn bench_now_ms() -> Double = "moui_reconciliation_benchmark_now_ms"

fn bench_env_int(name : String, fallback : Int) -> Int {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim()
      if trimmed.length() == 0 {
        return fallback
      }
      let mut parsed = 0
      for ch in trimmed.to_array() {
        if ch < '0' || ch > '9' {
          return fallback
        }
        parsed = parsed * 10 + ch.to_int() - '0'.to_int()
      }
      parsed.max(1)
    }
    None => fallback
  }
}

fn bench_deep_view(depth : Int, width_per_level : Int) -> @core.View[Int] {
  if depth <= 0 {
    @views.text("leaf")
  } else {
    let children : Array[@core.View[Int]] = []
    for _ in 0..<width_per_level {
      children.push(bench_deep_view(depth - 1, width_per_level))
    }
    @views.column(children)
  }
}

fn bench_dirty(
  label : String,
  depth : Int,
  width_per_level : Int,
  frames : Int,
) -> Unit {
  // Toggle environment between light and dark each frame to force
  // the full rebuild→layout→paint→draw cycle.
  let view = bench_deep_view(depth, width_per_level)
  let env_light = @core.Environment::neutral()
  let env_dark = @core.Environment::neutral().with_system_scheme(@core.ColorScheme::Dark)
  let runtime = @runtime.AppRuntime::new_view(
    root=view,
    size=@core.Size::new(width=800.0, height=600.0),
    environment=env_light,
  )
  ignore(runtime.draw_frame())

  let start = bench_now_ms()
  for index in 0..<frames {
    let env = if index % 2 == 0 { env_dark } else { env_light }
    runtime.set_environment(env)
    ignore(runtime.draw_frame())
  }
  let elapsed = bench_now_ms() - start

  let snap = runtime.inspector_snapshot().runtime()
  let avg = if frames > 0 { elapsed / frames.to_double() } else { 0.0 }
  println(
    "\{label}: depth=\{depth} width=\{width_per_level} frames=\{frames} total_ms=\{elapsed} avg_ms=\{avg}",
  )
  println(
    "  pipeline: rebuild=\{snap.rebuild_pass_count()} layout=\{snap.layout_pass_count()} paint=\{snap.paint_pass_count()} commands=\{snap.draw_command_build_count()}",
  )
  println(
    "{\"label\":\"\{label}\",\"depth\":\{depth},\"width\":\{width_per_level},\"frames\":\{frames},\"total_ms\":\{elapsed},\"avg_ms\":\{avg}}",
  )
}

fn main {
  let frames = bench_env_int("MOUI_HOTPATH_FRAMES", 20)

  println("MoUI runtime hot-path benchmark (rebuild via set_environment)")
  println("")

  bench_dirty("wide-list", 1, 100, frames)
  bench_dirty("deep-tree", 10, 2, frames)
  bench_dirty("balanced", 4, 6, frames)
  bench_dirty("shallow-wide", 2, 32, frames)
}
