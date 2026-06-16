///|
test "alert composes dialog content and actions" {
  let primary = @views.StateViewAction::new(label="Confirm", message=())
  let secondary = @views.StateViewAction::new(label="Cancel", message=())
  let runtime = test_runtime(
    @views.alert(
      "Delete project",
      "This action cannot be undone.",
      primary_action=primary,
      secondary_action=Some(secondary),
      tone=@views.FeedbackTone::Danger,
    ),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Delete project"))
  assert_true(has_text(draw, "This action cannot be undone."))
  assert_true(has_text(draw, "Confirm"))
  assert_true(has_text(draw, "Cancel"))
  guard find_semantics_label(runtime.semantics(), "Delete project")
    is Some(alert) else {
    fail("expected alert dialog semantics")
  }
  assert_true(alert.role == @core.SemanticsRole::Dialog)
}

///|
test "dialog composes custom content dismiss and action messages" {
  let selected = Ref("")
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.dialog(
      "Edit project",
      content=@views.description_list([
        @views.description_item("Owner", "Mira"),
        @views.description_item("Status", "Active"),
      ]),
      subtitle="Custom dialog content",
      primary_action=Some(
        @views.StateViewAction::new(label="Save", message="save"),
      ),
      secondary_action=Some(
        @views.StateViewAction::new(label="Cancel", message="cancel"),
      ),
      dismiss_action=Some(
        @views.StateViewAction::new(label="Dismiss", message="dismiss"),
      ),
      width=420.0,
      height=260.0,
    ),
    size=@core.Size::new(width=480.0, height=320.0),
    on_message=Some(message => selected.val = message),
  )
  let draw = runtime.draw_commands()
  assert_true(has_text(draw, "Edit project"))
  assert_true(has_text(draw, "Custom dialog content"))
  assert_true(has_text(draw, "Owner"))
  assert_true(has_text(draw, "Mira"))
  assert_true(has_text(draw, "Save"))
  assert_true(has_text(draw, "Cancel"))
  guard text_frame(draw, "Edit project") is Some(title_frame) else {
    fail("expected dialog title")
  }
  guard text_frame(draw, "Custom dialog content") is Some(subtitle_frame) else {
    fail("expected dialog subtitle")
  }
  guard text_frame(draw, "Owner") is Some(owner_frame) else {
    fail("expected dialog body term")
  }
  guard text_frame(draw, "Active") is Some(active_frame) else {
    fail("expected dialog body detail")
  }
  guard text_frame(draw, "Cancel") is Some(cancel_frame) else {
    fail("expected secondary action")
  }
  guard text_frame(draw, "Save") is Some(save_frame) else {
    fail("expected primary action")
  }
  guard text_frame(draw, "Dismiss") is Some(dismiss_frame) else {
    fail("expected dismiss action")
  }
  guard smallest_rounded_brush_containing(draw, title_frame)
    is Some(dialog_frame) else {
    fail("expected dialog surface frame")
  }
  for
    frame in [
      title_frame, subtitle_frame, owner_frame, active_frame, cancel_frame, save_frame,
      dismiss_frame,
    ] {
    assert_true(rect_contains_rect(dialog_frame, frame))
  }
  assert_true(owner_frame.origin.y > subtitle_frame.origin.y)
  assert_true(cancel_frame.origin.y > active_frame.origin.y)
  assert_true(save_frame.origin.x > cancel_frame.origin.x)
  assert_true(dismiss_frame.origin.x > title_frame.origin.x)
  guard find_semantics_label(runtime.semantics(), "Edit project")
    is Some(dialog) else {
    fail("expected custom dialog semantics")
  }
  assert_true(dialog.role == @core.SemanticsRole::Dialog)
  guard find_semantics_label(runtime.semantics(), "Dismiss") is Some(close) else {
    fail("expected dismiss action semantics")
  }
  assert_true(
    close.actions.any(action => action == @core.SemanticsAction::Dismiss),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=save_frame.origin.x + 4.0,
          y=save_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=save_frame.origin.x + 4.0,
          y=save_frame.origin.y + 4.0,
        ),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  inspect(selected.val, content="save")
}

///|
test "dialog host uses transparent scrim and keeps modal boundary visible" {
  let runtime = @runtime.AppRuntime::new_view(
    root=@views.dialog_host(
      @views.text("Background", width=180.0, height=32.0),
      dialog=Some(
        @views.dialog(
          "Visible dialog",
          content=@views.text("Bounded modal content", width=300.0, height=40.0),
          subtitle="Clear boundary",
          primary_action=Some(
            @views.StateViewAction::new(label="Close", message=()),
          ),
          width=360.0,
          height=260.0,
        ),
      ),
      presented=true,
    ),
    size=@core.Size::new(width=640.0, height=480.0),
  )
  let draw = runtime.draw_commands()
  inspect(full_frame_solid_fill_count(draw), content="1")
  assert_true(has_full_frame_solid_fill(draw, alpha=0.22))
  assert_true(has_text(draw, "Visible dialog"))
  assert_true(has_text(draw, "Bounded modal content"))
  assert_true(has_text(draw, "Close"))
  assert_true(draw.any(command => command is @core.DrawCommand::DrawShadow(_)))
  assert_true(
    draw.any(command => {
      command is @core.DrawCommand::StrokeRoundedRectBrush(_, _, 1.0)
    }),
  )
}
