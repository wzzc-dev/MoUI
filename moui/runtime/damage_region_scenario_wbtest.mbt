///|
/// F3 damage-coverage investigation (plan
/// `hot-path-invalidation-boilerplate-convergence`): pins the runtime damage
/// behavior of the `benchmarks/performance_budget` scenario shapes and the
/// mechanism behind each `FullSurface`.
///
/// Measured mechanism (2026-10-31, this file + probe run): every
/// message-driven and environment-driven frame returns `FullSurface` from
/// `compute_damage_region` because `request_root_rebuild` sets
/// `dirty.full_damage_reason` for the whole rebuild class ("program model
/// changed", "activation rebuild", "environment changed", "viewport
/// resized"). No scenario falls back through the coverage threshold or the
/// dirty-bounds path. The policy is deliberate and pinned by
/// `runtime_pointer_input_test.mbt` ("component rebuild requests full damage
/// after replacing content"): reconcile marks only declaration-changed
/// elements paint-dirty, so a clean sibling moved by a dirty neighbor's
/// resize re-renders (frame-keyed render cache) without ever entering the
/// paint-dirty id set — dirty-id-derived damage would ghost its exposed
/// strip. Narrowing rebuild damage therefore needs placement-level move
/// detection plus an active-animation/fade gate. Placement tracking has since
/// landed (`DamageIndex::placement_changes`, pinned by
/// `placement_damage_wbtest.mbt`) and the `Placement` damage class uses it;
/// the classes below stay `Absolute` because their paint effects are not
/// placement-visible (activation, environment, viewport) or have no render
/// node to compare (exit ghosts).

///|
fn damage_scenario_wheel(direction : Double) -> @core.AppEvent {
  Pointer(
    @core.PointerEvent::new(
      position=@core.Point::new(x=400.0, y=300.0),
      phase=Move,
      wheel_delta=@core.Point::new(x=0.0, y=direction),
    ),
  )
}

///|
test "damage: virtual-list wheel scroll (full-window viewport)" {
  // virtual-list-100k shape: the scroll viewport is the whole window, so a
  // scroll translation legitimately invalidates the full surface.
  let items : Array[Int32] = []
  for index in 0..<200 {
    items.push(index)
  }
  let program : @core.Program[@core.Point, @core.Point] = @core.Program::simple(
    init=@core.Point::new(x=0.0, y=0.0),
    update=fn(_model, offset) { offset },
    view=fn(offset) {
      @views.virtual_list(
        items,
        value => value.to_string(),
        value => @views.text("Row \{value}", width=760.0, height=24.0),
        item_height=24.0,
        viewport_height=600.0,
        spacing=1.0,
        overscan=4,
        offset~,
        on_scroll=offset => offset,
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=800.0, height=600.0),
  )
  let first = runtime.draw_frame()
  assert_eq(first.damage.full_reason(), "initial frame")
  runtime.dispatch_event(damage_scenario_wheel(-120.0))
  let scrolled = runtime.draw_frame()
  // The pointer message activates the scroll control. Activation is a
  // conservative full-surface class, and the scrolled layout movement would
  // independently require full damage until content-coordinate scroll lands.
  assert_eq(scrolled.damage.full_reason(), "activation rebuild")
}

///|
test "damage: message-driven scroll pane (partial-window viewport)" {
  // showcase-runtime-scroll shape: the scroll pane covers a quarter of the
  // window. The rebuild full-damage request still dominates; the pane-size
  // coverage threshold is never reached.
  let program : @core.Program[@core.Point, @core.Point] = @core.Program::simple(
    init=@core.Point::new(x=0.0, y=0.0),
    update=fn(_model, offset) { offset },
    view=fn(offset) {
      let entries : Array[@core.View[@core.Point]] = []
      for index in 0..<60 {
        entries.push(@views.text("Entry \{index}", height=28.0))
      }
      @views.row([
        @views.scroll_view(
          @views.column(entries),
          offset~,
          width=380.0,
          height=600.0,
          on_scroll=Some(offset => offset),
        ),
        @views.text("static header panel", width=400.0, height=600.0),
      ])
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=1280.0, height=720.0),
  )
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=200.0, y=300.0),
        phase=Move,
        wheel_delta=@core.Point::new(x=0.0, y=-44.0),
      ),
    ),
  )
  let frame = runtime.draw_frame()
  assert_eq(frame.damage.full_reason(), "activation rebuild")
}

///|
test "damage: environment toggle forces full, no-op write does not repaint" {
  // deep-tree-env-toggle / multi-window-4 shape. Environment invalidation is
  // global by design (set_environment marks the whole subtree build+layout
  // dirty), and a non-1.0 text_scale resolves to a different interned
  // environment id, so every render cache key changes and all nodes re-render
  // — FullSurface matches the actual repaint extent.
  let program : @core.Program[Int32, Int32] = @core.Program::simple(
    init=0,
    update=fn(_model, msg) { msg },
    view=fn(model) { @views.text("cell \{model}", width=100.0, height=28.0) },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=400.0, height=300.0),
  )
  ignore(runtime.draw_frame())
  runtime.set_environment(@core.Environment::neutral().with_text_scale(1.02))
  let toggled = runtime.draw_frame()
  assert_eq(toggled.damage.full_reason(), "environment changed")
  // Writing the identical environment must not schedule any work: the next
  // frame is a passive re-present with no rebuild, layout, or paint pass.
  runtime.set_environment(@core.Environment::neutral().with_text_scale(1.02))
  assert_false(runtime.needs_rebuild())
  assert_false(runtime.needs_layout())
  assert_false(runtime.needs_paint())
}

///|
test "damage: keyed-cell click keeps activation damage conservative" {
  // excel-grid-navigation shape: the click activates the cell and emits a
  // model message. Activation remains a conservative full-surface class even
  // though a direct paint-only projection can now use precise dirty bounds.
  let program : @core.Program[(Int32, Int32), (Int32, Int32)] = @core.Program::simple(
    init=(-1, -1),
    update=fn(_model, cell) { cell },
    view=fn(model) {
      let rows : Array[@core.View[(Int32, Int32)]] = []
      for row in 0..<12 {
        let cells : Array[@core.View[(Int32, Int32)]] = []
        for col in 0..<8 {
          let selected = model.0 == row && model.1 == col
          let cell_index = row * 8 + col
          cells.push(
            runtime_wb_fixture_view(
              identity=() => {
                @core.ViewIdentity::new(
                  kind="Cell",
                  key=Some("cell-\{cell_index}"),
                )
              },
              declaration=() => {
                runtime_wb_fixture_exact_declaration("cell", [
                  ("selected", @core.DeclarationKey::bool(selected)),
                ])
              },
              layout=ctx => {
                @core.ViewLayoutResult::new(
                  size=ctx.constraints.constrain(
                    @core.Size::new(width=110.0, height=28.0),
                  ),
                )
              },
              paint=ctx => {
                @core.ViewPaintPlan::commands([
                  FillRect(
                    ctx.frame,
                    if selected {
                      @core.Color::rgba(r=0.23, g=0.51, b=0.96)
                    } else {
                      @core.Color::rgba(r=0.94, g=0.94, b=0.94)
                    },
                  ),
                ])
              },
              event=ctx => {
                match ctx.event {
                  Pointer(event) =>
                    if event.phase == Down && ctx.frame.contains(event.position) {
                      {
                        ..@core.ViewEventResult::ignored(),
                        changed: true,
                        activated: true,
                        messages: [(row, col)],
                      }
                    } else {
                      @core.ViewEventResult::ignored()
                    }
                  _ => @core.ViewEventResult::ignored()
                }
              },
            ),
          )
        }
        rows.push(@views.row(cells))
      }
      @views.column(rows)
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=1280.0, height=800.0),
  )
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=92.0, y=172.0),
        phase=Down,
      ),
    ),
  )
  let frame = runtime.draw_frame()
  assert_eq(frame.damage.full_reason(), "activation rebuild")
}
