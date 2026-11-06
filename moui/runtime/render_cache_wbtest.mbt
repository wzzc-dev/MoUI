///|
fn runtime_render_cache_probe(paint_calls : Ref[Int32]) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="RenderCacheProbe"),
    declaration=() => @core.ViewDeclaration::constant(),
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=40.0, height=20.0),
        ),
      )
    },
    paint=context => {
      paint_calls.val = paint_calls.val + 1
      @core.ViewPaintPlan::commands([
        FillRect(context.frame, @core.Color::blue()),
      ])
    },
  )
}

///|
fn render_cache_probe_runtime() -> (RuntimeState, Ref[Int32]) {
  let paint_calls = Ref(0)
  let build = () => runtime_render_cache_probe(paint_calls)
  let runtime = RuntimeState::new_view(
    root=build(),
    size=@core.Size::new(width=40.0, height=20.0),
  )
  runtime.set_root_builder(() => adapt_view_for_runtime(build(), _message => ()))
  runtime.ensure_layout_tree()
  (runtime, paint_calls)
}

///|
fn render_cache_direct(
  runtime : RuntimeState,
  environment : RenderEnvironment,
  focused~ : ElementId? = None,
) -> Unit {
  ignore(
    runtime.element_tree.root.render_with_environment(
      runtime.layout_tree.root,
      focused,
      environment,
    ),
  )
}

///|
fn render_cache_expect_paint(
  paint_calls : Ref[Int32],
  before : Int32,
  label : String,
) -> Unit raise {
  if paint_calls.val <= before {
    fail("\{label}: expected a render-cache miss and a fresh paint")
  }
}

///|
fn render_cache_expect_hit(
  paint_calls : Ref[Int32],
  before : Int32,
  label : String,
) -> Unit raise {
  if paint_calls.val != before {
    fail(
      "\{label}: expected a render-cache hit, paint calls before=\{before} after=\{paint_calls.val}",
    )
  }
}

///|
test "render cache survives a paint pass after FrameTick" {
  let paint_calls = Ref(0)
  let build = () => runtime_render_cache_probe(paint_calls)
  let runtime = RuntimeState::new_view(
    root=build(),
    size=@core.Size::new(width=40.0, height=20.0),
  )
  runtime.set_root_builder(() => adapt_view_for_runtime(build(), _message => ()))
  ignore(runtime.build_draw_frame())
  let initial_paint_calls = paint_calls.val
  if initial_paint_calls == 0 {
    fail("expected the initial frame to paint the probe")
  }
  let hits_before = runtime.element_tree.root.inspector_render_cache_hits()

  runtime.advance_time(16.0)
  runtime.dirty.needs_paint = true
  runtime.render_current_tree()

  if paint_calls.val != initial_paint_calls {
    fail(
      "render cache missed after FrameTick: before=\{initial_paint_calls} after=\{paint_calls.val}",
    )
  }
  if runtime.element_tree.root.inspector_render_cache_hits() <= hits_before {
    fail("expected a render-cache hit after FrameTick")
  }
}

///|
test "render cache invalidates across environment dimensions and re-hits" {
  let neutral = @core.Environment::neutral()
  let variants : Array[(String, @core.Environment)] = [
    ("theme", neutral.with_system_scheme(Dark)),
    ("scale", neutral.with_scale_factor(2.0)),
    ("locale", neutral.with_locale("zh-CN")),
    ("direction", neutral.with_layout_direction(RightToLeft)),
    ("contrast", neutral.with_accessibility_contrast(High)),
  ]
  let neutral_environment = RenderEnvironment::from_environment(neutral).with_now_ms(
    16.0,
  )
  for entry in variants {
    let (label, variant) = entry
    let (runtime, paint_calls) = render_cache_probe_runtime()
    render_cache_direct(runtime, neutral_environment)
    let initial = paint_calls.val
    render_cache_direct(runtime, neutral_environment)
    render_cache_expect_hit(paint_calls, initial, "\{label} baseline")

    let changed = RenderEnvironment::from_environment(variant).with_now_ms(16.0)
    render_cache_direct(runtime, changed)
    render_cache_expect_paint(paint_calls, initial, label)
    let after_change = paint_calls.val
    render_cache_direct(runtime, changed)
    render_cache_expect_hit(paint_calls, after_change, "\{label} changed")
  }
}

///|
test "render cache invalidates when the text system changes" {
  let (runtime, paint_calls) = render_cache_probe_runtime()
  let neutral = @core.Environment::neutral()
  let default_text_system = @core.TextSystem::fallback()
  let alternate_text_system = @core.TextSystem::new(
    id="render-cache-alternate",
    measure=input => default_text_system.measure_text(input),
  )
  let default_environment = RenderEnvironment::from_environment(neutral)
    .with_text_system(default_text_system)
    .with_now_ms(16.0)
  let alternate_environment = RenderEnvironment::from_environment(neutral)
    .with_text_system(alternate_text_system)
    .with_now_ms(16.0)

  render_cache_direct(runtime, default_environment)
  let initial = paint_calls.val
  render_cache_direct(runtime, default_environment)
  render_cache_expect_hit(paint_calls, initial, "default text system")
  render_cache_direct(runtime, alternate_environment)
  render_cache_expect_paint(paint_calls, initial, "alternate text system")
  let after_change = paint_calls.val
  render_cache_direct(runtime, alternate_environment)
  render_cache_expect_hit(paint_calls, after_change, "alternate text system")
}

///|
test "render cache invalidates when focus moves onto the node" {
  let (runtime, paint_calls) = render_cache_probe_runtime()
  let environment = RenderEnvironment::from_environment(
    @core.Environment::neutral(),
  ).with_now_ms(16.0)
  let root_id = runtime.element_tree.root.id

  render_cache_direct(runtime, environment)
  let initial = paint_calls.val
  render_cache_direct(runtime, environment)
  render_cache_expect_hit(paint_calls, initial, "unfocused")
  render_cache_direct(runtime, environment, focused=Some(root_id))
  render_cache_expect_paint(paint_calls, initial, "focused")
  let after_focus = paint_calls.val
  render_cache_direct(runtime, environment, focused=Some(root_id))
  render_cache_expect_hit(paint_calls, after_focus, "focused")
}

///|
test "render cache invalidates when view state changes" {
  let (runtime, paint_calls) = render_cache_probe_runtime()
  let environment = RenderEnvironment::from_environment(
    @core.Environment::neutral(),
  ).with_now_ms(16.0)
  render_cache_direct(runtime, environment)
  let initial = paint_calls.val
  render_cache_direct(runtime, environment)
  render_cache_expect_hit(paint_calls, initial, "rest state")

  let current = runtime.element_tree.root.control.view_context(false)
  runtime.element_tree.root.control.apply_view_context({
    ..current,
    hovered: true,
  })
  render_cache_direct(runtime, environment)
  render_cache_expect_paint(paint_calls, initial, "hovered state")
  let after_change = paint_calls.val
  render_cache_direct(runtime, environment)
  render_cache_expect_hit(paint_calls, after_change, "hovered state")
}

///|
test "animating paint plans bypass the render cache" {
  let paint_calls = Ref(0)
  let view : @core.View[Unit] = runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="AnimatingRenderCacheProbe"),
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=40.0, height=20.0),
        ),
      )
    },
    paint=context => {
      paint_calls.val = paint_calls.val + 1
      @core.ViewPaintPlan::animating_commands([
        FillRect(context.frame, @core.Color::blue()),
      ])
    },
  )
  let runtime = RuntimeState::new_view(
    root=view,
    size=@core.Size::new(width=40.0, height=20.0),
  )
  runtime.ensure_layout_tree()
  let environment = RenderEnvironment::from_environment(
    @core.Environment::neutral(),
  ).with_now_ms(16.0)
  render_cache_direct(runtime, environment)
  let first = paint_calls.val
  render_cache_direct(runtime, environment)
  render_cache_expect_paint(paint_calls, first, "animating")
  if runtime.element_tree.root.render_cache.cached_key is Some(_) {
    fail("an animating plan must not write a render-cache key")
  }
}

///|
test "render cache invalidates when text control state changes" {
  let paint_calls = Ref(0)
  let build = () => runtime_render_cache_probe(paint_calls)
  let runtime = RuntimeState::new_view(
    root=build(),
    size=@core.Size::new(width=40.0, height=20.0),
  )
  runtime.set_root_builder(() => adapt_view_for_runtime(build(), _message => ()))
  ignore(runtime.build_draw_frame())
  runtime.advance_time(16.0)
  runtime.dirty.needs_paint = true
  runtime.render_current_tree()
  let paint_calls_before = paint_calls.val

  let current = runtime.element_tree.root.control.text_context()
  runtime.element_tree.root.control.apply_text_context({
    ..current,
    caret: current.caret + 1,
  })
  runtime.dirty.needs_paint = true
  runtime.render_current_tree()

  if paint_calls.val <= paint_calls_before {
    fail("render cache reused a plan across a text-control state change")
  }
}

///|
test "message rebuild reuses a static child render cache after FrameTick" {
  let parent_paint_calls = Ref(0)
  let child_paint_calls = Ref(0)
  let program : @core.Program[Int32, Int32] = @core.Program::simple(
    init=0,
    update=fn(_model, message) { message },
    view=fn(model) {
      let child : @core.View[Int32] = runtime_wb_fixture_view(
        identity=() => @core.ViewIdentity::new(kind="RenderCacheStaticChild"),
        declaration=() => @core.ViewDeclaration::constant(),
        layout=context => {
          @core.ViewLayoutResult::new(
            size=context.constraints.constrain(
              @core.Size::new(width=10.0, height=10.0),
            ),
          )
        },
        paint=context => {
          child_paint_calls.val = child_paint_calls.val + 1
          @core.ViewPaintPlan::commands([
            FillRect(context.frame, @core.Color::blue()),
          ])
        },
      )
      runtime_wb_fixture_view(
        identity=() => @core.ViewIdentity::new(kind="RenderCacheParent"),
        declaration=() => {
          @core.ViewDeclaration::channels(
            layout=Constant,
            paint=Exact(@core.DeclarationKey::int(model)),
            semantics=Constant,
            platform=Constant,
          )
        },
        children=() => [child],
        layout=_context => {
          @core.ViewLayoutResult::new(
            size=@core.Size::new(width=100.0, height=100.0),
            child_frames=[
              @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
            ],
          )
        },
        paint=context => {
          parent_paint_calls.val = parent_paint_calls.val + 1
          @core.ViewPaintPlan::commands([
            FillRect(context.frame, @core.Color::black()),
          ])
        },
        event=context => {
          match context.event {
            Pointer(event) if event.phase == Down =>
              @core.ViewEventResult::message(1)
            _ => @core.ViewEventResult::ignored()
          }
        },
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  ignore(runtime.draw_frame())
  let initial_parent_paints = parent_paint_calls.val
  let initial_child_paints = child_paint_calls.val
  let child_hits_before = runtime.state.element_tree.root.children[0].render_cache.hit_count
  if initial_parent_paints == 0 || initial_child_paints == 0 {
    fail("expected the initial frame to paint both message-fixture nodes")
  }
  runtime.advance_time(16.0)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=Down,
      ),
    ),
  )
  ignore(runtime.draw_frame())
  if parent_paint_calls.val <= initial_parent_paints {
    fail("expected the message-driven parent declaration change to repaint")
  }
  if child_paint_calls.val != initial_child_paints {
    fail(
      "expected the unchanged child paint to be reused, before=\{initial_child_paints} after=\{child_paint_calls.val}",
    )
  }
  if runtime.state.element_tree.root.children[0].render_cache.hit_count <=
    child_hits_before {
    fail("expected the static child render cache to hit after the message")
  }
}

///|
test "child environment scope reclassifies when its declaration changes" {
  let paint_calls = Ref(0)
  let observed_scales : Array[Double] = []
  let parent_environment = @core.Environment::neutral().with_system_scheme(Dark)
  let scoped_environment = parent_environment.with_scale_factor(1.5)
  let program : @core.Program[Bool, Int32] = @core.Program::simple(
    init=false,
    update=fn(_model, _message) { true },
    view=fn(use_scoped_environment) {
      let child : @core.View[Int32] = runtime_wb_fixture_view(
        identity=() => @core.ViewIdentity::new(kind="RenderCacheScopeChild"),
        declaration=() => @core.ViewDeclaration::constant(),
        layout=context => {
          @core.ViewLayoutResult::new(
            size=context.constraints.constrain(
              @core.Size::new(width=100.0, height=100.0),
            ),
          )
        },
        paint=context => {
          paint_calls.val = paint_calls.val + 1
          observed_scales.push(context.environment.scale_factor)
          @core.ViewPaintPlan::commands([
            FillRect(context.frame, @core.Color::blue()),
          ])
        },
      )
      runtime_wb_fixture_view(
        identity=() => @core.ViewIdentity::new(kind="RenderCacheScopeRoot"),
        declaration=() => {
          runtime_wb_fixture_exact_declaration("render-cache-scope", [
            (
              "useScopedEnvironment",
              @core.DeclarationKey::bool(use_scoped_environment),
            ),
          ])
        },
        children=() => [child],
        // The first scope is a structural no-op relative to the parent. A
        // classifier must not cache that fact as a property of the node.
        child_environment=_environment => {
          if use_scoped_environment {
            scoped_environment
          } else {
            parent_environment
          }
        },
        layout=_context => {
          @core.ViewLayoutResult::new(
            size=@core.Size::new(width=100.0, height=100.0),
            child_frames=[
              @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
            ],
          )
        },
        event=context => {
          match context.event {
            Pointer(event) if event.phase == Down =>
              @core.ViewEventResult::message(1)
            _ => @core.ViewEventResult::ignored()
          }
        },
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  runtime.set_environment(parent_environment)
  ignore(runtime.draw_frame())
  let initial_paints = paint_calls.val
  if initial_paints == 0 {
    fail("expected the initial scope frame to paint the child")
  }
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=Down,
      ),
    ),
  )
  ignore(runtime.draw_frame())
  if paint_calls.val <= initial_paints {
    fail("expected a changed child environment scope to repaint the child")
  }
  assert_eq(observed_scales[observed_scales.length() - 1], 1.5)
}

///|
test "render cache observes child frame changes without a parent paint flag" {
  let parent_paint_calls = Ref(0)
  let observed_child_widths : Array[Double] = []
  let program : @core.Program[Bool, Int32] = @core.Program::simple(
    init=false,
    update=fn(_model, _message) { true },
    view=fn(wide_child) {
      let child : @core.View[Int32] = runtime_wb_fixture_view(
        identity=() => @core.ViewIdentity::new(kind="RenderCacheFrameChild"),
        declaration=() => {
          runtime_wb_fixture_exact_declaration("render-cache-frame-child", [
            (
              "width",
              @core.DeclarationKey::double(if wide_child { 20.0 } else { 10.0 }),
            ),
          ])
        },
        layout=context => {
          @core.ViewLayoutResult::new(
            size=context.constraints.constrain(
              @core.Size::new(
                width=if wide_child { 20.0 } else { 10.0 },
                height=10.0,
              ),
            ),
          )
        },
      )
      runtime_wb_fixture_view(
        identity=() => @core.ViewIdentity::new(kind="RenderCacheFrameParent"),
        children=() => [child],
        layout=context => {
          @core.ViewLayoutResult::new(
            size=@core.Size::new(width=100.0, height=100.0),
            child_frames=[
              @core.Rect::new(
                x=0.0,
                y=0.0,
                width=match context.child_sizes {
                  [size, ..] => size.width
                  [] => 0.0
                },
                height=10.0,
              ),
            ],
          )
        },
        paint=context => {
          parent_paint_calls.val = parent_paint_calls.val + 1
          match context.child_frames {
            [frame, ..] => observed_child_widths.push(frame.size.width)
            [] => observed_child_widths.push(0.0)
          }
          @core.ViewPaintPlan::commands([
            FillRect(context.frame, @core.Color::black()),
          ])
        },
        event=context => {
          match context.event {
            Pointer(event) if event.phase == Down =>
              @core.ViewEventResult::message(1)
            _ => @core.ViewEventResult::ignored()
          }
        },
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  ignore(runtime.draw_frame())
  let initial_paints = parent_paint_calls.val
  if initial_paints == 0 {
    fail("expected the initial parent frame to paint")
  }
  assert_eq(observed_child_widths[observed_child_widths.length() - 1], 10.0)
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=50.0, y=50.0),
        phase=Down,
      ),
    ),
  )
  ignore(runtime.draw_frame())
  if parent_paint_calls.val <= initial_paints {
    fail("expected a parent paint plan to observe its changed child frame")
  }
  assert_eq(observed_child_widths[observed_child_widths.length() - 1], 20.0)
}
