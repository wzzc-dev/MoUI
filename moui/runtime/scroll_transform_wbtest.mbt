///|
fn scroll_transform_probe(
  paint_calls : Ref[Int32],
  platform_calls : Ref[Int32],
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => {
      @core.ViewIdentity::new(
        kind="ScrollTransformProbe",
        key=Some("scroll-transform-probe"),
      )
    },
    declaration=() => @core.ViewDeclaration::constant(),
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=200.0),
        ),
      )
    },
    paint=context => {
      paint_calls.val = paint_calls.val + 1
      @core.ViewPaintPlan::commands([
        FillRect(context.frame, @core.Color::blue()),
      ])
    },
    platform_views=context => {
      platform_calls.val = platform_calls.val + 1
      [
        @core.PlatformViewPlacement::new(
          id="scroll-transform-native",
          kind="test",
          frame=context.frame,
        ),
      ]
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=Boundary,
        role=Text,
        label="scroll-transform-text",
      )
    },
  )
}

///|
fn scroll_transform_find_element(
  element : ElementNode,
  kind : String,
) -> ElementNode? {
  if element.view_node.identity().kind == kind {
    return Some(element)
  }
  for child in element.children {
    match scroll_transform_find_element(child, kind) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn scroll_transform_semantics_frame(
  runtime : AppRuntime,
  label : String,
) -> Rect? {
  match runtime.read_semantics() {
    Ok(Full(snapshot)) =>
      for node in snapshot.nodes() {
        if node.label == label {
          return Some(node.frame)
        }
      }
    Ok(Delta(delta)) =>
      for node in delta.upserted() {
        if node.label == label {
          return Some(node.frame)
        }
      }
    Ok(Unchanged(_)) | Err(_) => ()
  }
  None
}

///|
fn scroll_transform_wheel(
  runtime : AppRuntime,
  x : Double,
  y : Double,
  dy : Double,
) -> Unit {
  ignore(
    runtime.dispatch_event(
      Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x~, y~),
          phase=Move,
          wheel_delta=@core.Point::new(x=0.0, y=dy),
        ),
      ),
    ),
  )
}

///|
test "scroll keeps descendant caches content-local while boundaries move" {
  let paint_calls = Ref(0)
  let platform_calls = Ref(0)
  let runtime = AppRuntime::new_view(
    root=@views.scroll_view(
      scroll_transform_probe(paint_calls, platform_calls),
      width=100.0,
      height=50.0,
    ),
    size=@core.Size::new(width=100.0, height=80.0),
  )
  ignore(runtime.draw_frame())
  let probe = match
    scroll_transform_find_element(
      runtime.state.element_tree.root,
      "ScrollTransformProbe",
    ) {
    Some(found) => found
    None => abort("missing scroll transform probe")
  }
  let local_frame_before = match probe.layout_cache.cached_placed {
    Some(placed) => placed.frame
    None => abort("probe was not placed")
  }
  let place_revision_before = probe.layout_cache.place_revision
  let layout_hits_before = probe.layout_cache.hit_count
  let layout_misses_before = probe.layout_cache.miss_count
  let render_hits_before = probe.render_cache.hit_count
  let paint_calls_before = paint_calls.val
  let platform_calls_before = platform_calls.val
  let platform_frame_before = runtime.draw_frame().platform_views[0].frame

  scroll_transform_wheel(runtime, 50.0, 20.0, -20.0)
  ignore(runtime.draw_frame())

  assert_true(
    probe.layout_cache.hit_count > layout_hits_before,
    msg="the descendant place cache must hit during scroll",
  )
  assert_true(
    probe.layout_cache.miss_count == layout_misses_before,
    msg="scroll must not re-place the content subtree",
  )
  assert_eq(probe.layout_cache.place_revision, place_revision_before)
  assert_eq(probe.layout_cache.cached_placed.unwrap().frame, local_frame_before)
  assert_true(
    probe.render_cache.hit_count > render_hits_before,
    msg="the descendant render cache must hit during scroll",
  )
  assert_eq(paint_calls.val, paint_calls_before)
  assert_eq(platform_calls.val, platform_calls_before)

  assert_eq(runtime.layout().children[0].frame.origin.y, -20.0)
  assert_eq(
    runtime.anchor_frame("scroll-transform-probe").unwrap().origin.y,
    -20.0,
  )
  assert_eq(
    scroll_transform_semantics_frame(runtime, "scroll-transform-text").unwrap().origin.y,
    -20.0,
  )
  let platform_frame_after = runtime.draw_frame().platform_views[0].frame
  assert_eq(platform_frame_after.origin.y, -20.0)
  assert_eq(
    platform_frame_after.origin.y - platform_frame_before.origin.y,
    -20.0,
  )
}

///|
fn scroll_transform_draw_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Rect? {
  let mut current = @core.Transform2D::identity()
  let stack : Array[@core.Transform2D] = []
  for command in commands {
    match command {
      PushTransform(transform) => {
        stack.push(current)
        current = {
          a: current.a * transform.a + current.c * transform.b,
          b: current.b * transform.a + current.d * transform.b,
          c: current.a * transform.c + current.c * transform.d,
          d: current.b * transform.c + current.d * transform.d,
          tx: current.a * transform.tx + current.c * transform.ty + current.tx,
          ty: current.b * transform.tx + current.d * transform.ty + current.ty,
        }
      }
      PopTransform =>
        match stack.pop() {
          Some(transform) => current = transform
          None => current = @core.Transform2D::identity()
        }
      DrawText(run) =>
        if run.text == text {
          return Some(runtime_transform_rect(current, run.frame))
        }
      _ => ()
    }
  }
  None
}

///|
fn scroll_transform_local_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Rect? {
  for command in commands {
    match command {
      DrawText(run) => if run.text == text { return Some(run.frame) }
      _ => ()
    }
  }
  None
}

///|
test "scroll paint commands are translated by the viewport transform" {
  let root : @core.View[Unit] = @views.scroll_view(
    @views.column(
      [
        @views.frame(@views.text("Above"), width=100.0, height=100.0),
        @views.text("Scrolled"),
      ],
      spacing=0.0,
    ),
    width=100.0,
    height=80.0,
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  ignore(runtime.draw_frame())
  let before = match
    scroll_transform_draw_text_frame(runtime.draw_commands(), "Scrolled") {
    Some(frame) => frame
    None => abort("scrolled text was not painted")
  }
  let before_local = match
    scroll_transform_local_text_frame(runtime.draw_frame().commands, "Scrolled") {
    Some(frame) => frame
    None => abort("scrolled text was not in the draw frame")
  }
  scroll_transform_wheel(runtime, 50.0, 20.0, -30.0)
  let draw_frame = runtime.draw_frame()
  let after = match
    scroll_transform_draw_text_frame(runtime.draw_commands(), "Scrolled") {
    Some(frame) => frame
    None => abort("scrolled text disappeared")
  }
  let after_local = match
    scroll_transform_local_text_frame(draw_frame.commands, "Scrolled") {
    Some(frame) => frame
    None => abort("scrolled text disappeared from the draw frame")
  }
  assert_eq(before.origin.y - after.origin.y, 30.0)
  assert_eq(before_local, after_local)
  assert_true(
    draw_frame.commands.any(command => command is PushTransform(_)),
    msg="the renderer frame keeps the viewport transform explicit",
  )
  assert_false(
    runtime.draw_commands().any(command => command is PushTransform(_)),
    msg="legacy commands fold layout translations into geometry",
  )
}

///|
fn scroll_transform_click(runtime : AppRuntime, x : Double, y : Double) -> Unit {
  let position = @core.Point::new(x~, y~)
  ignore(
    runtime.dispatch_event(
      Pointer(@core.PointerEvent::new(position~, phase=Down)),
    ),
  )
  ignore(
    runtime.dispatch_event(
      Pointer(@core.PointerEvent::new(position~, phase=Up)),
    ),
  )
}

///|
fn scroll_transform_event_probe(log : Ref[Array[String]]) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="ScrollTransformEventProbe"),
    declaration=() => @core.ViewDeclaration::constant(),
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=100.0),
        ),
      )
    },
    event=context => {
      match context.event {
        Pointer(event) =>
          if event.phase == Down {
            log.val.push("down")
          } else if event.phase == Up {
            log.val.push("up")
          }
        _ => ()
      }
      @core.ViewEventResult::ignored()
    },
  )
}

///|
fn scroll_transform_pair(
  left : @core.View[Unit],
  right : @core.View[Unit],
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="ScrollTransformPair"),
    declaration=() => @core.ViewDeclaration::constant(),
    children=() => [left, right],
    layout=_context => {
      @core.ViewLayoutResult::new(
        size=@core.Size::new(width=200.0, height=100.0),
        child_frames=[
          @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
          @core.Rect::new(x=100.0, y=0.0, width=100.0, height=100.0),
        ],
      )
    },
  )
}

///|
test "scroll hit testing follows the translated content and viewport clip" {
  let received : Ref[Array[String]] = Ref([])
  let runtime = AppRuntime::new_view(
    root=@views.column(
      [
        @views.scroll_view(
          @views.column(
            [
              @views.frame(@views.text("Above"), width=100.0, height=100.0),
              scroll_transform_event_probe(received),
            ],
            spacing=0.0,
          ),
          width=100.0,
          height=100.0,
        ),
        @views.frame(@views.text("Below"), width=100.0, height=40.0),
      ],
      spacing=0.0,
    ),
    size=@core.Size::new(width=100.0, height=140.0),
  )
  ignore(runtime.draw_frame())
  scroll_transform_wheel(runtime, 50.0, 20.0, -50.0)
  ignore(runtime.draw_frame())

  scroll_transform_click(runtime, 50.0, 60.0)
  assert_eq(received.val, ["down", "up"])

  received.val = []
  scroll_transform_click(runtime, 50.0, 120.0)
  assert_eq(received.val, [])
}

///|
test "RTL scroll presents and hit-tests the trailing content edge" {
  let left : Ref[Array[String]] = Ref([])
  let right : Ref[Array[String]] = Ref([])
  let runtime = AppRuntime::new_view(
    root=@views.column(
      [
        @views.scroll_view(
          scroll_transform_pair(
            scroll_transform_event_probe(left),
            scroll_transform_event_probe(right),
          ),
          width=100.0,
          height=100.0,
        ),
        @views.frame(@views.text("Below"), width=100.0, height=40.0),
      ],
      spacing=0.0,
    ),
    size=@core.Size::new(width=100.0, height=140.0),
    environment=@core.Environment::neutral().with_layout_direction(RightToLeft),
  )
  ignore(runtime.draw_frame())
  assert_eq(runtime.layout().children[0].children[0].frame.origin.x, -100.0)
  scroll_transform_click(runtime, 20.0, 20.0)
  assert_eq(left.val, [])
  assert_eq(right.val, ["down", "up"])
}
