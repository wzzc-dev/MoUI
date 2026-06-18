///|
fn[Msg] sheet_surface(
  content~ : @core.View[Msg],
  presentation_mode? : @core.SheetPresentationMode = @core.SheetPresentationMode::Modal,
  background~ : @core.Brush,
  corner_radius~ : Double,
  shadow? : @core.ShadowStyle? = None,
  on_dismiss? : Msg? = None,
  kind? : String = "Sheet",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "sheet:\{sheet_presentation_revision(presentation_mode)}:\{view_brush_revision(background)}:\{corner_radius}:\{view_shadow_option_revision(shadow)}:\{on_dismiss is Some(_)}"
    },
    children=() => [content],
    child_constraints=constraints => {
      let content_constraints = constraints.deflate(sheet_content_insets())
      match presentation_mode {
        @core.SheetPresentationMode::Modal => content_constraints
        @core.SheetPresentationMode::BottomSheet => content_constraints.loosen()
      }
    },
    layout=ctx => {
      let child_size = first_child_size(ctx.child_sizes)
      let measured = ctx.constraints.constrain(
        child_size.inflate(sheet_content_insets()),
      )
      @core.ViewLayoutResult::new(size=measured, child_frames=[
        sheet_content_frame(
          presentation_mode,
          @core.Rect::new(
            x=0.0,
            y=0.0,
            width=measured.width,
            height=measured.height,
          ),
          child_size,
        ),
      ])
    },
    paint=ctx => {
      let commands : Array[@core.DrawCommand] = []
      let rounded = @core.RoundedRect::new(rect=ctx.frame, radius=corner_radius)
      match shadow {
        Some(style) =>
          commands.push(
            @core.DrawCommand::DrawShadow(
              @core.ShadowSpec::new(
                rect=rounded,
                color=style.color,
                offset=style.offset,
                blur_radius=style.blur_radius,
                spread=style.spread,
              ),
            ),
          )
        None => ()
      }
      commands.push(
        @core.DrawCommand::FillRoundedRectBrush(rounded, background),
      )
      @core.ViewPaintPlan::commands(commands)
    },
    event=ctx => {
      match (ctx.event, on_dismiss) {
        (@core.AppEvent::Pointer(event), Some(message)) =>
          if event.phase == @core.PointerPhase::Up &&
            ctx.frame.contains(event.position) &&
            sheet_point_outside_content(event.position, ctx.child_frames) {
            view_event_result(
              changed=true,
              activated=true,
              captured=true,
              dirty=@core.ViewDirtyHint::ViewPaintDirty,
              messages=[message],
            )
          } else if ctx.frame.contains(event.position) {
            view_event_result(changed=true, captured=true)
          } else {
            @core.ViewEventResult::ignored()
          }
        (@core.AppEvent::Pointer(event), None) =>
          if event.phase == @core.PointerPhase::Up &&
            ctx.frame.contains(event.position) &&
            sheet_point_outside_content(event.position, ctx.child_frames) {
            view_event_result(changed=true, captured=true)
          } else if ctx.frame.contains(event.position) {
            view_event_result(changed=true, captured=true)
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Dialog)
    },
    focusable=() => false,
  )
}

///|
fn sheet_content_insets() -> @core.Insets {
  @core.Insets::symmetric(horizontal=16.0, vertical=16.0)
}

///|
fn sheet_content_frame(
  presentation_mode : @core.SheetPresentationMode,
  frame : @core.Rect,
  child_size : @core.Size,
) -> @core.Rect {
  let content = frame.inset(sheet_content_insets())
  match presentation_mode {
    @core.SheetPresentationMode::Modal => content
    @core.SheetPresentationMode::BottomSheet => {
      let height = sheet_min_double(content.size.height, child_size.height)
      @core.Rect::new(
        x=content.origin.x,
        y=content.origin.y + content.size.height - height,
        width=content.size.width,
        height~,
      )
    }
  }
}

///|
fn sheet_point_outside_content(
  point : @core.Point,
  child_frames : Array[@core.Rect],
) -> Bool {
  match child_frames {
    [content, ..] => !content.contains(point)
    [] => true
  }
}

///|
fn sheet_presentation_revision(mode : @core.SheetPresentationMode) -> String {
  match mode {
    @core.SheetPresentationMode::Modal => "modal"
    @core.SheetPresentationMode::BottomSheet => "bottom"
  }
}

///|
fn sheet_min_double(left : Double, right : Double) -> Double {
  if left <= right {
    left
  } else {
    right
  }
}
