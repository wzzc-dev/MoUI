///|
fn[Msg] sheet_shell(
  content~ : @core.View[Msg],
  presentation_mode? : SheetPresentationMode = SheetPresentationMode::Modal,
  theme? : @core.Theme,
  background? : @core.Brush,
  corner_radius? : Double,
  shadow? : @core.ShadowStyle? = None,
  on_dismiss? : Msg? = None,
  kind? : String = "Sheet",
  key? : String? = None,
) -> @core.View[Msg] {
  let theme_revision = match theme {
    Some(t) => t.revision_fingerprint()
    None => "context"
  }
  @core.View::from_node(
    SheetShell::{
      presentation_mode,
      theme,
      background,
      corner_radius,
      shadow,
      theme_revision,
      has_on_dismiss: on_dismiss is Some(_),
      kind,
      key,
    },
    children=_node => [content],
    event=(_node, ctx) => sheet_shell_event(ctx, on_dismiss),
  )
}

///|
priv struct SheetShell {
  presentation_mode : SheetPresentationMode
  theme : @core.Theme?
  background : @core.Brush?
  corner_radius : Double?
  shadow : @core.ShadowStyle?
  theme_revision : String
  has_on_dismiss : Bool
  kind : String
  key : String?
}

///|
impl @core.ViewNode for SheetShell with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for SheetShell with fn revision(self) {
  "sheet:\{sheet_presentation_revision(self.presentation_mode)}:\{self.theme_revision}:\{self.shadow is Some(_)}:\{self.has_on_dismiss}"
}

///|
impl @core.ViewNode for SheetShell with fn child_constraints(
  self,
  constraints,
) {
  let content_constraints = constraints.deflate(sheet_content_insets())
  match self.presentation_mode {
    SheetPresentationMode::Modal => content_constraints
    SheetPresentationMode::BottomSheet => content_constraints.loosen()
  }
}

///|
impl @core.ViewNode for SheetShell with fn layout(self, ctx) {
  let child_size = first_child_size(ctx.child_sizes)
  let measured = ctx.constraints.constrain(
    child_size.inflate(sheet_content_insets()),
  )
  @core.ViewLayoutResult::new(size=measured, child_frames=[
    sheet_content_frame(
      self.presentation_mode,
      @core.Rect::new(
        x=0.0,
        y=0.0,
        width=measured.width,
        height=measured.height,
      ),
      child_size,
    ),
  ])
}

///|
impl @core.ViewNode for SheetShell with fn paint(self, ctx) {
  // Resolve the sheet surface ambient-ly so it tracks palette changes without
  // requiring the caller to rebuild the view tree.
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_background = self.background.unwrap_or(
    @core.Brush::solid(resolved_theme.palette.surface),
  )
  let resolved_radius = self.corner_radius.unwrap_or(
    resolved_theme.radius_scale.lg,
  )
  let commands : Array[@core.DrawCommand] = []
  let rounded = @core.RoundedRect::new(rect=ctx.frame, radius=resolved_radius)
  emit_elevation_shadow(
    commands,
    rounded,
    self.shadow,
    ctx.environment.color_scheme(),
  )
  commands.push(
    @core.DrawCommand::FillRoundedRectBrush(rounded, resolved_background),
  )
  @core.ViewPaintPlan::commands(commands)
}

///|
impl @core.ViewNode for SheetShell with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Dialog)
}

///|
fn[Msg] sheet_shell_event(
  ctx : @core.ViewEventContext,
  on_dismiss : Msg?,
) -> @core.ViewEventResult[Msg] {
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
}

///|
fn sheet_content_insets() -> @core.Insets {
  @core.Insets::symmetric(horizontal=16.0, vertical=16.0)
}

///|
fn sheet_content_frame(
  presentation_mode : SheetPresentationMode,
  frame : @core.Rect,
  child_size : @core.Size,
) -> @core.Rect {
  let content = frame.inset(sheet_content_insets())
  match presentation_mode {
    SheetPresentationMode::Modal => content
    SheetPresentationMode::BottomSheet => {
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
fn sheet_presentation_revision(mode : SheetPresentationMode) -> String {
  match mode {
    SheetPresentationMode::Modal => "modal"
    SheetPresentationMode::BottomSheet => "bottom"
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
