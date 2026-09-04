///|
extern "c" fn bench_now_ms() -> Double = "moui_reconciliation_benchmark_now_ms"

///|
struct FCResult {
  label : String
  total_nodes : Int
  frames : Int
  total_ms : Double
  rebuild_count : Int
  layout_count : Int
  paint_count : Int
  command_build_count : Int
}

///|
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

///|
fn bench_tree(depth : Int, width : Int, msg_base : Int) -> @core.View[Int] {
  if depth <= 0 {
    @views.button("x", on_click=msg_base)
  } else {
    let children : Array[@core.View[Int]] = []
    for col in 0..<width {
      children.push(bench_tree(depth - 1, width, msg_base + col * 100))
    }
    @views.column(children)
  }
}

///|
fn bench_node_count(depth : Int, width : Int) -> Int {
  if depth <= 0 {
    1
  } else {
    1 + width * bench_node_count(depth - 1, width)
  }
}

///|
fn bench_run(
  label : String,
  depth : Int,
  width : Int,
  frames : Int,
  trigger_rebuild : Bool,
  maps? : Int = 0,
) -> FCResult {
  let total = bench_node_count(depth, width)
  let program = @core.Program::simple(init=0, update=fn(_model, msg) { msg }, view=fn(
    model,
  ) {
    // `maps` layers of View::map rebuild the whole tree per map layer on
    // every view call; G vs F isolates that construction cost.
    let mut view = bench_tree(depth, width, model + 1000)
    for _layer in 0..<maps {
      view = view.map(message => message)
    }
    view
  })
  let runtime = @runtime.AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=800.0, height=600.0),
  )
  let snap_before = runtime.inspector_snapshot().runtime()
  let start = bench_now_ms()
  for idx in 0..<frames {
    if trigger_rebuild {
      // set_environment with a new text_scale forces
      // mark_component_tree_build_dirty → rebuild.
      // Exercises T1.1+T1.2+T2.3+T1.3 on each frame.
      let scale = 1.0 + (idx % 10).to_double() * 0.01
      runtime.set_environment(
        @core.Environment::neutral().with_text_scale(scale),
      )
    }
    ignore(runtime.draw_frame())
  }
  let elapsed = bench_now_ms() - start
  let snap_after = runtime.inspector_snapshot().runtime()

  {
    label,
    total_nodes: total,
    frames,
    total_ms: elapsed,
    rebuild_count: snap_after.rebuild_pass_count() -
    snap_before.rebuild_pass_count(),
    layout_count: snap_after.layout_pass_count() -
    snap_before.layout_pass_count(),
    paint_count: snap_after.paint_pass_count() - snap_before.paint_pass_count(),
    command_build_count: snap_after.draw_command_build_count() -
    snap_before.draw_command_build_count(),
  }
}

///|
fn bench_print(r : FCResult) -> Unit {
  let avg = if r.frames > 0 { r.total_ms / r.frames.to_double() } else { 0.0 }
  println(
    "\{r.label}: nodes=\{r.total_nodes} frames=\{r.frames} total_ms=\{r.total_ms} avg_ms=\{avg}",
  )
  println(
    "  rebuild=\{r.rebuild_count} layout=\{r.layout_count} paint=\{r.paint_count} commands=\{r.command_build_count}",
  )
  println(
    "{\"label\":\"\{r.label}\",\"nodes\":\{r.total_nodes},\"frames\":\{r.frames},\"total_ms\":\{r.total_ms},\"avg_ms\":\{avg},\"rebuild\":\{r.rebuild_count},\"layout\":\{r.layout_count},\"paint\":\{r.paint_count},\"commands\":\{r.command_build_count}}",
  )
}

///|
fn main {
  let frames = bench_env_int("MOUI_FC_FRAMES", 50)

  println(
    "MoUI runtime full-cycle benchmark (Program-based, env-toggle rebuild)",
  )
  println("A/C/E: idle frames, B/D/F: set_environment toggle each frame")
  println("")

  let a = bench_run("A-bal-idle", 3, 3, frames, false)
  bench_print(a)
  println("")

  let b = bench_run("B-bal-click", 3, 3, frames, true)
  bench_print(b)
  println("")

  let c = bench_run("C-wide-idle", 1, 60, frames, false)
  bench_print(c)
  println("")

  let d = bench_run("D-wide-click", 1, 60, frames, true)
  bench_print(d)
  println("")

  let e = bench_run("E-deep-idle", 8, 2, frames, false)
  bench_print(e)
  println("")

  let f = bench_run("F-deep-click", 8, 2, frames, true)
  bench_print(f)
  println("")

  // Same deep tree as F with two nested `View::map` layers: the delta over
  // F is the per-frame map construction amplification (full subtree
  // re-wrap + adapter snapshot per layer).
  let g = bench_run("G-deep-dblmap-click", 8, 2, frames, true, maps=2)
  bench_print(g)
}
