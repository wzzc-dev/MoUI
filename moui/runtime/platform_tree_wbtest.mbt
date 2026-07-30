///|
fn runtime_platform_leaf(
  id : String,
  source : String,
  platform_calls : @core.State[Int],
  paint_calls : @core.State[Int],
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="PlatformLeaf", key=Some(id)),
    declaration=() => {
      @core.ViewDeclaration::channels(
        layout=@core.DeclarationChannel::Constant,
        paint=@core.DeclarationChannel::Constant,
        semantics=@core.DeclarationChannel::Constant,
        platform=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::string(source),
        ),
      )
    },
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=50.0, height=40.0),
        ),
      )
    },
    paint=_context => {
      paint_calls.set(paint_calls.get() + 1)
      @core.ViewPaintPlan::empty()
    },
    platform_views=context => {
      platform_calls.set(platform_calls.get() + 1)
      [
        @core.PlatformViewPlacement::new(
          id~,
          kind="test",
          frame=context.frame,
          properties=[
            @core.PlatformViewProperty::new(key="source", value=source),
          ],
        ),
      ]
    },
  )
}

///|
fn runtime_platform_row(
  left : @core.View[Unit],
  right : @core.View[Unit],
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="PlatformRow"),
    declaration=() => @core.ViewDeclaration::constant(),
    children=() => [left, right],
    layout=context => {
      let size = context.constraints.constrain(
        @core.Size::new(width=100.0, height=40.0),
      )
      @core.ViewLayoutResult::new(size~, child_frames=[
        @core.Rect::new(x=0.0, y=0.0, width=50.0, height=size.height),
        @core.Rect::new(x=50.0, y=0.0, width=50.0, height=size.height),
      ])
    },
  )
}

///|
test "platform-only declaration rebuild updates PlatformTree without paint or redraw" {
  let source = @core.State::new("before")
  let left_platform_calls = @core.State::new(0)
  let right_platform_calls = @core.State::new(0)
  let left_paint_calls = @core.State::new(0)
  let right_paint_calls = @core.State::new(0)
  let runtime = RuntimeState::new_view(
    root=runtime_component_view(context => {
      runtime_platform_row(
        runtime_platform_leaf(
          "left",
          context.watch(source),
          left_platform_calls,
          left_paint_calls,
        ),
        runtime_platform_leaf(
          "right", "stable", right_platform_calls, right_paint_calls,
        ),
      )
    }),
    size=@core.Size::new(width=100.0, height=40.0),
  )
  ignore(runtime.cached_semantics())
  inspect(left_platform_calls.get(), content="1")
  inspect(right_platform_calls.get(), content="1")
  inspect(left_paint_calls.get(), content="1")
  inspect(right_paint_calls.get(), content="1")
  runtime.dirty.needs_redraw = false
  runtime.dirty.rebuild_wakeup_redraw = false
  let paint_passes = runtime.stats.paint_pass_count

  source.set("after")
  let frame = runtime.build_draw_frame()

  inspect(frame.platform_views.length(), content="2")
  inspect(frame.platform_views[0].property_or("source", ""), content="after")
  inspect(frame.platform_views[1].property_or("source", ""), content="stable")
  inspect(runtime.stats.paint_pass_count == paint_passes, content="true")
  inspect(left_paint_calls.get(), content="1")
  inspect(right_paint_calls.get(), content="1")
  inspect(left_platform_calls.get(), content="2")
  inspect(right_platform_calls.get(), content="1")
  inspect(runtime.dirty.needs_redraw, content="false")
  inspect(runtime.dirty.dirty_platform_elements.length(), content="0")
  inspect(runtime.dirty_count(), content="0")

  ignore(runtime.build_draw_frame())
  inspect(left_platform_calls.get(), content="2")
  inspect(right_platform_calls.get(), content="1")
}
