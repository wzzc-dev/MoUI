///|
fn runtime_pending_scroll_target() -> @core.View[@core.Point] {
  runtime_wb_fixture_view(
    identity=() => {
      @core.ViewIdentity::new(
        kind="PendingScrollTarget",
        key=Some("pending-target"),
      )
    },
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=20.0),
        ),
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=@core.SemanticsComposition::Boundary,
        role=@core.SemanticsRole::Text,
        label="pending target",
      )
    },
  )
}

///|
fn runtime_pending_scroll_content(visible : Bool) -> @core.View[@core.Point] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="PendingScrollContent"),
    children=() => if visible { [runtime_pending_scroll_target()] } else { [] },
    layout=context => {
      @core.ViewLayoutResult::new(
        size=context.constraints.constrain(
          @core.Size::new(width=100.0, height=120.0),
        ),
        child_frames=if visible {
          [@core.Rect::new(x=0.0, y=100.0, width=100.0, height=20.0)]
        } else {
          []
        },
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=@core.SemanticsComposition::Transparent,
      )
    },
  )
}

///|
fn runtime_pending_scroll_view(
  visible : Bool,
  offset : @core.Point,
) -> @core.View[@core.Point] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="PendingScrollView"),
    declaration=() => {
      @core.ViewDeclaration::channels(
        layout=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::record(type_tag="PendingScrollView.layout", fields=[
            ("x", @core.DeclarationKey::double(offset.x)),
            ("y", @core.DeclarationKey::double(offset.y)),
          ]),
        ),
        paint=@core.DeclarationChannel::Constant,
        semantics=@core.DeclarationChannel::Constant,
        platform=@core.DeclarationChannel::Constant,
      )
    },
    children=() => [runtime_pending_scroll_content(visible)],
    child_constraints=_constraints => @core.Constraints::unbounded(),
    layout=_context => {
      @core.ViewLayoutResult::new(
        size=@core.Size::new(width=100.0, height=40.0),
        child_frames=[
          @core.Rect::new(x=-offset.x, y=-offset.y, width=100.0, height=120.0),
        ],
      )
    },
    event=context => {
      match context.event {
        @core.AppEvent::Pointer(event) =>
          if event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0 {
            @core.ViewEventResult::message(
              @core.Point::new(
                x=offset.x - event.wheel_delta.x,
                y=offset.y - event.wheel_delta.y,
              ),
            )
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        composition=@core.SemanticsComposition::Boundary,
        role=@core.SemanticsRole::ScrollView,
      )
    },
  )
}

///|
test "semantics commit stabilizes pending scroll before publishing bounds" {
  let visible = Ref(false)
  let offset = Ref(@core.Point::new(x=0.0, y=0.0))
  let runtime_ref : Ref[RuntimeState?] = Ref(None)
  let build = () => runtime_pending_scroll_view(visible.val, offset.val)
  let runtime = RuntimeState::new_view(
    root=build(),
    size=@core.Size::new(width=100.0, height=40.0),
    on_message=Some(next => {
      offset.val = next
      match runtime_ref.val {
        Some(state) =>
          state.request_root_rebuild(reason="test scroll model changed")
        None => ()
      }
    }),
  )
  runtime_ref.val = Some(runtime)
  runtime.set_root_builder(() => {
    adapt_view_for_runtime(build(), next => {
      offset.val = next
      runtime.request_root_rebuild(reason="test scroll model changed")
    })
  })
  inspect(
    runtime.scroll_to_key("pending-target", @core.ScrollAlignment::Nearest),
    content="false",
  )
  visible.val = true
  runtime.request_root_rebuild(reason="test model changed")
  let snapshot = runtime.cached_semantics()
  let mut target_y = -1.0
  for node in snapshot.nodes() {
    if node.label == "pending target" {
      target_y = node.frame.origin.y
    }
  }
  inspect(offset.val.y, content="80")
  inspect(target_y, content="20")
}
