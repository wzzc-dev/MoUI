///|
/// W2.1 damage classes: invalidation reasons and dirty bounds are distinct.
/// These fixtures keep geometry fixed so a declaration change can isolate the
/// paint-only path from structural/layout movement.
fn damage_classification_paint_cell(
  key : String,
  selected : Bool,
  focusable~ : Bool = false,
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => {
      @core.ViewIdentity::new(kind="DamagePaintCell", key=Some(key))
    },
    declaration=() => {
      @core.ViewDeclaration::channels(
        layout=Constant,
        paint=Exact(
          @core.DeclarationKey::record(type_tag="DamagePaintCell", fields=[
            ("selected", @core.DeclarationKey::bool(selected)),
          ]),
        ),
        semantics=Constant,
        platform=Constant,
      )
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=100.0, height=40.0),
        ),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        FillRect(
          ctx.frame,
          if ctx.focused {
            @core.Color::blue()
          } else if selected {
            @core.Color::gray()
          } else {
            @core.Color::white()
          },
        ),
      ])
    },
    focusable=() => focusable,
  )
}

///|
fn damage_classification_layout_cell(
  key : String,
  variant : Int32,
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => {
      @core.ViewIdentity::new(kind="DamageLayoutCell", key=Some(key))
    },
    declaration=() => {
      @core.ViewDeclaration::channels(
        layout=Exact(@core.DeclarationKey::int(variant)),
        paint=Constant,
        semantics=Constant,
        platform=Constant,
      )
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=100.0, height=40.0),
        ),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([FillRect(ctx.frame, @core.Color::white())])
    },
  )
}

///|
fn damage_classification_stage(
  children : Array[@core.View[Unit]],
) -> @core.View[Unit] {
  let frames : Array[@core.Rect] = []
  for index, _child in children {
    frames.push(
      @core.Rect::new(
        x=100.0 * index.to_double(),
        y=0.0,
        width=100.0,
        height=40.0,
      ),
    )
  }
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="DamageClassificationStage"),
    declaration=() => @core.ViewDeclaration::constant(),
    children=() => children.copy(),
    child_constraints=_constraints => {
      @core.Constraints::tight(@core.Size::new(width=100.0, height=40.0))
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=400.0, height=40.0),
        ),
        child_frames=frames,
      )
    },
  )
}

///|
fn damage_classification_selection_row(selected : Int32) -> @core.View[Unit] {
  let children : Array[@core.View[Unit]] = []
  for index in 0..<4 {
    children.push(
      damage_classification_paint_cell("cell-\{index}", selected == index),
    )
  }
  damage_classification_stage(children)
}

///|
fn damage_classification_runtime(
  build : () -> @core.View[Unit],
) -> RuntimeState {
  let runtime = RuntimeState::new_view(
    root=build(),
    size=@core.Size::new(width=400.0, height=40.0),
  )
  runtime.set_root_builder(() => adapt_view_for_runtime(build(), _message => ()))
  runtime
}

///|
test "damage classification: no-op projection rebuild is empty" {
  let runtime = damage_classification_runtime(() => {
    damage_classification_selection_row(0)
  })
  let first = runtime.build_draw_frame()
  assert_true(first.damage is FullSurface(_))
  let paint_passes = runtime.stats.paint_pass_count
  runtime.request_root_rebuild(reason="no-op message")
  let frame = runtime.build_draw_frame()
  assert_true(frame.damage is Empty)
  assert_eq(runtime.stats.paint_pass_count, paint_passes)
}

///|
test "damage classification: paint-only selection uses precise dirty bounds" {
  let selected = Ref(0)
  let runtime = damage_classification_runtime(() => {
    damage_classification_selection_row(selected.val)
  })
  ignore(runtime.build_draw_frame())
  selected.val = 1
  runtime.request_root_rebuild(reason="paint-only selection")
  let frame = runtime.build_draw_frame()
  match frame.damage {
    Rects(rects) => {
      let previous_cell = @core.Point::new(x=50.0, y=20.0)
      let current_cell = @core.Point::new(x=150.0, y=20.0)
      let static_cell = @core.Point::new(x=350.0, y=20.0)
      assert_true(rects.any(rect => rect.inflate(1.0).contains(previous_cell)))
      assert_true(rects.any(rect => rect.inflate(1.0).contains(current_cell)))
      assert_false(rects.any(rect => rect.inflate(1.0).contains(static_cell)))
    }
    FullSurface(reason) => fail("expected precise paint damage, got \{reason}")
    Empty => fail("expected precise paint damage, got empty")
  }
}

///|
test "damage classification: layout-only projection uses the changed cell" {
  let variant = Ref(0)
  let runtime = damage_classification_runtime(() => {
    damage_classification_stage([
      damage_classification_layout_cell("layout-cell", variant.val),
      damage_classification_paint_cell("stable-cell", false),
      damage_classification_paint_cell("stable-cell-2", false),
      damage_classification_paint_cell("stable-cell-3", false),
    ])
  })
  ignore(runtime.build_draw_frame())
  variant.val = 1
  runtime.request_root_rebuild(reason="layout-only projection")
  let frame = runtime.build_draw_frame()
  // The layout declaration changed but the placed geometry did not, so
  // placement tracking finds no moved id and only the re-painted cell is
  // damaged. The three stable cells keep their pixels.
  match frame.damage {
    Rects(rects) => {
      let changed_cell = @core.Point::new(x=50.0, y=20.0)
      let stable_cell = @core.Point::new(x=150.0, y=20.0)
      assert_true(rects.any(rect => rect.inflate(1.0).contains(changed_cell)))
      assert_false(rects.any(rect => rect.inflate(1.0).contains(stable_cell)))
    }
    FullSurface(reason) => fail("expected placed damage, got \{reason}")
    Empty => fail("expected the changed cell to be damaged")
  }
}

///|
test "damage classification: deletion stays full" {
  let removed = Ref(false)
  let runtime = damage_classification_runtime(() => {
    let keys = if removed.val { ["a", "c", "d"] } else { ["a", "b", "c", "d"] }
    let children : Array[@core.View[Unit]] = []
    for key in keys {
      children.push(damage_classification_paint_cell(key, false))
    }
    damage_classification_stage(children)
  })
  ignore(runtime.build_draw_frame())
  removed.val = true
  runtime.request_root_rebuild(reason="deletion")
  let frame = runtime.build_draw_frame()
  assert_true(frame.damage is FullSurface(_))
  assert_eq(frame.damage.full_reason(), "structure changed")
}

///|
test "damage classification: reorder stays full" {
  let reordered = Ref(false)
  let runtime = damage_classification_runtime(() => {
    let keys = if reordered.val {
      ["c", "a", "b", "d"]
    } else {
      ["a", "b", "c", "d"]
    }
    let children : Array[@core.View[Unit]] = []
    for key in keys {
      children.push(damage_classification_paint_cell(key, false))
    }
    damage_classification_stage(children)
  })
  ignore(runtime.build_draw_frame())
  reordered.val = true
  runtime.request_root_rebuild(reason="reorder")
  let frame = runtime.build_draw_frame()
  assert_true(frame.damage is FullSurface(_))
  assert_eq(frame.damage.full_reason(), "structure changed")
}

///|
test "damage classification: focus change uses paint dirty bounds" {
  let runtime = damage_classification_runtime(() => {
    damage_classification_stage([
      damage_classification_paint_cell("focus-a", false, focusable=true),
      damage_classification_paint_cell("focus-b", false, focusable=true),
      damage_classification_paint_cell("focus-c", false, focusable=true),
      damage_classification_paint_cell("focus-d", false, focusable=true),
    ])
  })
  ignore(runtime.build_draw_frame())
  let target = runtime.element_tree.root.children[0].id
  assert_true(runtime.commit_focus(Some(target)))
  let frame = runtime.build_draw_frame()
  match frame.damage {
    Rects(rects) => {
      let target_point = @core.Point::new(x=50.0, y=20.0)
      let sibling_point = @core.Point::new(x=250.0, y=20.0)
      assert_true(rects.any(rect => rect.inflate(1.0).contains(target_point)))
      assert_false(rects.any(rect => rect.inflate(1.0).contains(sibling_point)))
    }
    FullSurface(reason) => fail("expected focus paint damage, got \{reason}")
    Empty => fail("expected focus paint damage, got empty")
  }
}

///|
fn damage_classification_overlay_root(presented : Bool) -> @core.View[Unit] {
  @views.overlay_host(
    @views.frame(@views.text("Base"), width=200.0, height=100.0),
    [
      @views.PresentationSpec::new(
        id="menu",
        kind=Popover,
        content=@views.frame(@views.text("Menu"), width=80.0, height=40.0),
        presented~,
      ),
    ],
  )
}

///|
test "damage classification: overlay projection close stays full" {
  let presented = Ref(true)
  let build = () => damage_classification_overlay_root(presented.val)
  let runtime = RuntimeState::new_view(
    root=build(),
    size=@core.Size::new(width=200.0, height=100.0),
  )
  runtime.set_root_builder(() => adapt_view_for_runtime(build(), _message => ()))
  ignore(runtime.build_draw_frame())
  presented.val = false
  runtime.request_root_rebuild(reason="overlay close")
  let frame = runtime.build_draw_frame()
  assert_true(frame.damage is FullSurface(_))
}
