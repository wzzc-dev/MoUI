///|
/// Gated hot-path benchmark (MOUI_EDITOR_HOT_BENCH=1). GUI-free: it drives
/// the same package-private entry points the editor uses per keystroke, per
/// wheel event, and per viewport rebuild, and prints one `key=value` line
/// per metric. Numbers are transcribed into the active ai-sessions log for
/// before/after comparison. The suite stays fast by default because every
/// case returns immediately when the gate is off.

///|
fn hot_path_bench_enabled() -> Bool {
  @env.get_env_var("MOUI_EDITOR_HOT_BENCH") == Some("1")
}

///|
fn hot_path_bench_print(key : String, value : Double) -> Unit {
  let line = "hot-bench " + key + "=" + value.round().to_string() + "us"
  println(line)
}

///|
fn hot_path_bench_print_int(key : String, value : Int) -> Unit {
  let line = "hot-bench " + key + "=" + value.to_string()
  println(line)
}

///|
/// Keystroke input at the document end. The baseline column reproduces the
/// pre-incremental shape (full-document parse per keystroke); the current
/// column uses `MarkdownDocumentSession::apply` with the incremental path.
fn hot_path_bench_input(fixture : String, keystrokes : Int) -> Unit {
  let mut baseline_session = MarkdownDocumentSession::new(fixture)
  let mut baseline_keep = 0
  let baseline_start = @bench.monotonic_clock_start()
  for _ in 0..<keystrokes {
    baseline_session = MarkdownDocumentSession::new(
      baseline_session.source + "x",
    )
    baseline_keep = baseline_keep + baseline_session.blocks.length()
  }
  let baseline_us = @bench.monotonic_clock_end(baseline_start)
  hot_path_metrics_reset()
  let mut current = MarkdownDocumentSession::new(fixture)
  let mut current_keep = 0
  let current_start = @bench.monotonic_clock_start()
  for _ in 0..<keystrokes {
    current = current.apply(
      MarkdownEditTransaction::from_sources(
        current.source,
        current.source + "x",
        reason=TextInput,
      ),
    )
    current_keep = current_keep + current.blocks.length()
  }
  let current_us = @bench.monotonic_clock_end(current_start)
  hot_path_bench_print_int("input_fixture_blocks", current.blocks.length())
  hot_path_bench_print_int("input_fixture_chars", current.source_length)
  hot_path_bench_print_int("input_keystrokes", keystrokes)
  hot_path_bench_print(
    "input_baseline_per_keystroke",
    baseline_us / keystrokes.to_double(),
  )
  hot_path_bench_print(
    "input_current_per_keystroke",
    current_us / keystrokes.to_double(),
  )
  hot_path_bench_print_int(
    "input_current_full_parses",
    hot_path_full_parse_count.val,
  )
  hot_path_bench_print_int(
    "input_current_region_reparses",
    hot_path_region_reparse_count.val,
  )
  hot_path_bench_print_int(
    "input_current_fallbacks",
    hot_path_incremental_fallback_count.val,
  )
  hot_path_bench_print_int(
    "input_keep",
    if baseline_keep == current_keep {
      1
    } else {
      0 - current_keep
    },
  )
}

///|
/// Scroll geometry: per wheel step, rebuild the measured block-height
/// array and locate the visible window — the exact pair of calls the wheel
/// handler performs today.
fn hot_path_bench_scroll(fixture : String, steps : Int) -> Unit {
  let session = MarkdownDocumentSession::new(fixture)
  let base = @core.FontSpec::new()
  let viewport = 900.0
  let width = 720.0
  hot_path_metrics_reset()
  let mut keep = 0.0
  let start = @bench.monotonic_clock_start()
  for step in 0..<steps {
    let scroll_y = step.to_double() * 40.0
    match markdown_document_block_geometry(session, base, content_width=width) {
      Some(geometry) => {
        let range = markdown_document_window_range_for_geometry(
          geometry,
          scroll_y~,
          viewport_height=viewport,
          overscan=320.0,
        )
        keep = keep + range.content_height + range.top_padding
      }
      None => ()
    }
  }
  let total_us = @bench.monotonic_clock_end(start)
  hot_path_bench_print("scroll_per_step", total_us / steps.to_double())
  hot_path_bench_print_int(
    "scroll_walk_blocks_per_step",
    hot_path_block_height_walk_blocks.val / steps,
  )
  hot_path_bench_print_int(
    "scroll_cache_hits",
    hot_path_scroll_geometry_cache_hits.val,
  )
  hot_path_bench_print_int("scroll_keep", keep.round().to_int())
}

///|
/// Viewport rebuild: `rich_text_window` at successive scroll offsets, which
/// is what a wheel-triggered repaint performs (geometry window + visible
/// block conversions).
fn hot_path_bench_rebuild(fixture : String, steps : Int) -> Unit {
  let session = MarkdownDocumentSession::new(fixture)
  let selection = { caret: 0, selection: None }
  hot_path_metrics_reset()
  let mut keep = 0
  let mut window_us = 0.0
  let mut conversions_us = 0.0
  let start = @bench.monotonic_clock_start()
  for step in 0..<steps {
    let scroll_y = step.to_double() * 40.0
    let t0 = @bench.monotonic_clock_start()
    let range = markdown_document_block_geometry(
      session,
      @core.FontSpec::new(),
      content_width=720.0,
    )
    match range {
      Some(geometry) => {
        let _ = markdown_document_window_range_for_geometry(
          geometry,
          scroll_y~,
          viewport_height=900.0,
          overscan=320.0,
        )
      }
      None => ()
    }
    window_us = window_us + @bench.monotonic_clock_end(t0)
    let t1 = @bench.monotonic_clock_start()
    let window = session.rich_text_window(
      selection,
      scroll_y~,
      viewport_height=900.0,
      overscan=320.0,
      content_width=720.0,
    )
    // Mirror the session editor: paint, caret, and hit-test consume one
    // shared memoized soft-wrap pass over the window document.
    let document = rich_text_document_soft_wrap(
      window.document,
      720.0,
      @core.FontSpec::new(),
      @core.TextSystem::fallback(),
    )
    conversions_us = conversions_us + @bench.monotonic_clock_end(t1)
    keep = keep + document.blocks.length()
  }
  let total_us = @bench.monotonic_clock_end(start)
  hot_path_bench_print(
    "rebuild_geometry_per_rebuild",
    window_us / steps.to_double(),
  )
  hot_path_bench_print(
    "rebuild_document_per_rebuild",
    conversions_us / steps.to_double(),
  )
  hot_path_bench_print("rebuild_per_rebuild", total_us / steps.to_double())
  hot_path_bench_print_int(
    "rebuild_walk_blocks_per_rebuild",
    hot_path_block_height_walk_blocks.val / steps,
  )
  hot_path_bench_print_int(
    "rebuild_conversion_builds_per_rebuild",
    hot_path_block_conversion_builds.val / steps,
  )
  hot_path_bench_print_int(
    "rebuild_wrap_builds_per_rebuild",
    hot_path_block_wrap_builds.val / steps,
  )
  hot_path_bench_print_int(
    "rebuild_wrap_cache_hits_per_rebuild",
    hot_path_block_wrap_cache_hits.val / steps,
  )
  hot_path_bench_print_int("rebuild_keep", keep)
}

///|
test "hot path: gated end-to-end benchmark" {
  if !hot_path_bench_enabled() {
    return
  }
  let fixture = hot_path_bench_document(300)
  hot_path_bench_input(fixture, 80)
  hot_path_bench_scroll(fixture, 120)
  hot_path_bench_rebuild(fixture, 60)
}
