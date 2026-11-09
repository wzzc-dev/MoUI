///|
test "opening another story issues one detail-scroll reset" {
  let model = @app.ShowcaseModel::new(route="components/welcome")
  assert_true(model.detail_scroll_request is None)

  let next = model.update(Navigate("components/button"))
  let first = match next.detail_scroll_request {
    Some(request) => request
    None => abort("expected a detail-scroll reset request")
  }
  inspect(first.id, content="0")
  inspect(first.offset.x, content="0")
  inspect(first.offset.y, content="0")

  // Re-selecting the current story must not reapply the request.
  let repeated = next.update(Navigate("components/button"))
  let repeated_request = match repeated.detail_scroll_request {
    Some(request) => request
    None => abort("expected the previous request to remain")
  }
  inspect(repeated_request.id, content="0")

  let third = repeated.update(Navigate("components/text"))
  let third_request = match third.detail_scroll_request {
    Some(request) => request
    None => abort("expected a new detail-scroll reset request")
  }
  inspect(third_request.id, content="1")
}

///|
test "mobile catalog round-trip resets detail without app-owned offsets" {
  let model = @app.ShowcaseModel::new(route="components/button")
  let different_story = model.update(Navigate("components/text"))
  let reset = match different_story.detail_scroll_request {
    Some(request) => request
    None => abort("expected a detail-scroll reset request")
  }
  inspect(reset.id, content="0")

  let catalog = different_story.update(ShowMobileCatalog)
  assert_false(catalog.mobile_showing_detail)
  let reset_after_catalog = match catalog.detail_scroll_request {
    Some(request) => request
    None => abort("expected the reset request to remain")
  }
  inspect(reset_after_catalog.id, content="0")

  // The detail scroll node is unmounted while the catalog is visible, so its
  // element state is discarded. Reopening the same story therefore resets
  // without a new request or a second app-owned offset.
  let same_story = catalog.update(Navigate("components/text"))
  assert_true(same_story.mobile_showing_detail)
  let same_request = match same_story.detail_scroll_request {
    Some(request) => request
    None => abort("expected the previous request to remain")
  }
  inspect(same_request.id, content="0")

  let another_story = catalog.update(Navigate("components/button"))
  let another_request = match another_story.detail_scroll_request {
    Some(request) => request
    None => abort("expected a new detail-scroll reset request")
  }
  inspect(another_request.id, content="1")
}

///|
test "showcase wheel scroll stays in element state without root rebuild" {
  let program = @app.ShowcaseModel::new(route="diagnostics/advanced-rendering").program()
  let runtime = @runtime.new_program_with_dimensions(
    program~,
    width=1280.0,
    height=720.0,
  )
  ignore(runtime.draw_frame())
  let program_before = runtime.program_runtime_snapshot()
  let inspector_before = runtime.inspector_snapshot().runtime()

  let dispatch = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=470.0, y=260.0),
      phase=Move,
      wheel_delta=@core.Point::new(x=0.0, y=-44.0),
    ),
  )
  assert_true(dispatch.handled)
  assert_false(runtime.needs_rebuild())
  assert_true(runtime.needs_layout())

  let frame = runtime.draw_frame()
  let program_after = runtime.program_runtime_snapshot()
  let inspector_after = runtime.inspector_snapshot().runtime()
  assert_eq(program_after.dispatched_count(), program_before.dispatched_count())
  assert_eq(program_after.update_count(), program_before.update_count())
  assert_eq(
    inspector_after.rebuild_pass_count(),
    inspector_before.rebuild_pass_count(),
  )
  assert_false(
    frame.damage.full_reason() == "activation rebuild",
    msg="an internal scroll must not request an activation rebuild",
  )
  // Placement tracking derives the region from the content the scroll actually
  // moved instead of the blanket "layout changed" class. This pane moves enough
  // that the coalesced rects still cover most of the surface, but the reason is
  // now measured rather than assumed.
  inspect(
    frame.damage.full_reason(),
    content="dirty region covers most of the surface",
  )
}

///|
test "showcase drag scroll stays in element state without root rebuild" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.ShowcaseModel::new(route="diagnostics/advanced-rendering").program(),
    width=1280.0,
    height=720.0,
  )
  ignore(runtime.draw_frame())
  let program_before = runtime.program_runtime_snapshot()
  let inspector_before = runtime.inspector_snapshot().runtime()

  let down = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=470.0, y=260.0),
      phase=Down,
    ),
  )
  assert_true(down.handled)
  let drag = runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=470.0, y=180.0),
      phase=Move,
    ),
  )
  assert_true(drag.handled)
  assert_false(runtime.needs_rebuild())
  assert_true(runtime.needs_layout())

  let frame = runtime.draw_frame()
  let program_after = runtime.program_runtime_snapshot()
  let inspector_after = runtime.inspector_snapshot().runtime()
  assert_eq(program_after.dispatched_count(), program_before.dispatched_count())
  assert_eq(program_after.update_count(), program_before.update_count())
  assert_eq(
    inspector_after.rebuild_pass_count(),
    inspector_before.rebuild_pass_count(),
  )
  assert_false(
    frame.damage.full_reason() == "activation rebuild",
    msg="an internal drag must not request an activation rebuild",
  )
  inspect(
    frame.damage.full_reason(),
    content="damage accumulated across paint passes",
  )
}
