///|
/// Placement-level move tracking. Layout work moves clean subtrees that never
/// enter the paint-dirty id set, so dirty-id bounds alone leave the strip a
/// moved sibling vacated painted with last frame's pixels. These fixtures grow
/// and shrink one cell while its sibling stays declaration-clean, and pin that
/// the vacated strip is damaged while untouched surface is not.

///|
fn placement_damage_grow_cell(width : Double) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => {
      @core.ViewIdentity::new(kind="PlacementGrow", key=Some("grow"))
    },
    declaration=() => {
      @core.ViewDeclaration::channels(
        layout=Exact(@core.DeclarationKey::double(width)),
        paint=Constant,
        semantics=Constant,
        platform=Constant,
      )
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height=40.0)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([FillRect(ctx.frame, @core.Color::white())])
    },
  )
}

///|
/// The stage's own declaration is constant: it is a plain container whose
/// placement derives from its children, so it never becomes paint-dirty and
/// cannot mask the sibling's move with its own bounds.
fn placement_damage_stage(
  width : Double,
  children : Array[@core.View[Unit]],
) -> @core.View[Unit] {
  let frames = [
    @core.Rect::new(x=0.0, y=0.0, width~, height=40.0),
    @core.Rect::new(x=width, y=0.0, width=100.0, height=40.0),
  ]
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="PlacementStage"),
    children=() => children.copy(),
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
fn placement_damage_runtime(width : Ref[Double]) -> RuntimeState {
  let build = () => {
    placement_damage_stage(width.val, [
      placement_damage_grow_cell(width.val),
      damage_classification_paint_cell("clean-sibling", false),
    ])
  }
  let runtime = RuntimeState::new_view(
    root=build(),
    size=@core.Size::new(width=800.0, height=400.0),
  )
  runtime.set_root_builder(() => adapt_view_for_runtime(build(), _m => ()))
  runtime
}

///|
test "placement damage: shrinking a cell clears the sibling's vacated strip" {
  let width = Ref(300.0)
  let runtime = placement_damage_runtime(width)
  ignore(runtime.build_draw_frame())
  width.val = 100.0
  runtime.request_root_rebuild(reason="sibling shrink")
  let frame = runtime.build_draw_frame()
  match frame.damage {
    Rects(rects) => {
      // The sibling moved from x=300..400 to x=100..200. x=350 is outside
      // every current bound and outside the dirty cell's previous 0..300
      // bound, so only placement tracking can reach it.
      let vacated = @core.Point::new(x=350.0, y=20.0)
      let arrived = @core.Point::new(x=150.0, y=20.0)
      let untouched = @core.Point::new(x=700.0, y=200.0)
      assert_true(rects.any(rect => rect.inflate(1.0).contains(vacated)))
      assert_true(rects.any(rect => rect.inflate(1.0).contains(arrived)))
      assert_false(rects.any(rect => rect.inflate(1.0).contains(untouched)))
    }
    FullSurface(reason) => fail("expected placed damage, got \{reason}")
    Empty => fail("a moved sibling must damage its vacated strip")
  }
}

///|
test "placement damage: growing a cell covers the sibling's new position" {
  let width = Ref(100.0)
  let runtime = placement_damage_runtime(width)
  ignore(runtime.build_draw_frame())
  width.val = 300.0
  runtime.request_root_rebuild(reason="sibling grow")
  let frame = runtime.build_draw_frame()
  match frame.damage {
    Rects(rects) => {
      // The sibling moved from x=100..200 to x=300..400; its new position is
      // outside the dirty cell's previous 0..100 bound.
      let arrived = @core.Point::new(x=350.0, y=20.0)
      let vacated = @core.Point::new(x=150.0, y=20.0)
      let untouched = @core.Point::new(x=700.0, y=200.0)
      assert_true(rects.any(rect => rect.inflate(1.0).contains(arrived)))
      assert_true(rects.any(rect => rect.inflate(1.0).contains(vacated)))
      assert_false(rects.any(rect => rect.inflate(1.0).contains(untouched)))
    }
    FullSurface(reason) => fail("expected placed damage, got \{reason}")
    Empty => fail("a moved sibling must damage its new position")
  }
}

///|
test "placement damage: a second identical layout pass stops moving" {
  let width = Ref(300.0)
  let runtime = placement_damage_runtime(width)
  ignore(runtime.build_draw_frame())
  width.val = 100.0
  runtime.request_root_rebuild(reason="sibling shrink")
  ignore(runtime.build_draw_frame())
  // Same geometry, same declarations: the placement scan must find no moved
  // id, so the frame carries no damage rather than re-clearing the strip.
  runtime.request_root_rebuild(reason="repeat projection")
  let frame = runtime.build_draw_frame()
  assert_true(frame.damage is Empty)
}
