///|
pub fn[Msg] text(
  text : String,
  role? : TextRole = TextRole::Body,
  theme? : @core.Theme,
  width? : Double = 160.0,
  height? : Double = 32.0,
  align? : @core.TextAlign = @core.TextAlign::TextCenter,
) -> @core.View[Msg] {
  let size = @core.Size::new(width~, height~)
  let theme_revision = match theme {
    Some(value) => text_theme_revision(value)
    None => "context"
  }
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Text"),
    revision=() => {
      "text:\{text}:\{size.width}:\{size.height}:\{text_role_revision(role)}:\{text_align_revision(align)}:\{theme_revision}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let font = ctx.style.font.unwrap_or(role.font(resolved_theme))
      let color = if ctx.environment.enabled {
        ctx.style.foreground.unwrap_or(role.color(resolved_theme))
      } else {
        ctx.style.foreground
        .unwrap_or(role.color(resolved_theme))
        .multiply_alpha(0.7)
      }
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::DrawText(
          @core.TextRun::new(text~, frame=ctx.frame, font~, color~, align~),
        ),
      ])
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Text,
        label=text,
        value=text,
      )
    },
  )
}

///|
fn text_align_revision(align : @core.TextAlign) -> String {
  match align {
    @core.TextAlign::TextStart => "start"
    @core.TextAlign::TextCenter => "center"
    @core.TextAlign::TextEnd => "end"
  }
}

///|
fn text_role_revision(role : TextRole) -> String {
  match role {
    Body => "body"
    Title => "title"
    Caption => "caption"
    Control => "control"
    Mono => "mono"
    Display => "display"
    Headline => "headline"
    Subtitle => "subtitle"
    Label => "label"
    Overline => "overline"
  }
}

///|
fn text_theme_revision(theme : @core.Theme) -> String {
  theme.revision_fingerprint()
}

///|
pub fn[Msg] text_field(
  value : String,
  on_input~ : (String) -> Msg,
  on_submit? : Msg? = None,
  placeholder? : String = "",
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  theme? : @core.Theme,
  style? : TextFieldStyle,
  width? : Double = 240.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  // Style is resolved ambient-ly inside the control (an explicit theme?
  // overrides ctx.environment.theme) so the field tracks dark-mode / a11y
  // changes without the caller rebuilding the view tree.
  controlled_text_field_control(
    value~,
    on_input~,
    placeholder~,
    size=@core.Size::new(width~, height~),
    theme?,
    variant~,
    style?,
    on_submit~,
  )
}

///|
pub fn[Msg] text_area(
  value : String,
  on_input~ : (String) -> Msg,
  placeholder? : String = "",
  lines? : Int = 4,
  variant? : TextFieldVariant = TextFieldVariant::Outline,
  theme? : @core.Theme,
  width? : Double = 320.0,
  line_height? : Double = 28.0,
  on_submit? : Msg? = None,
) -> @core.View[Msg] {
  text_area_control(
    value=@core.Binding::new(get=() => value, set=_ => ()),
    on_input=Some(on_input),
    on_submit~,
    placeholder~,
    size=@core.Size::new(
      width~,
      height=views_max_double(line_height, lines.to_double() * line_height),
    ),
    theme?,
    variant~,
    lines~,
    line_height~,
  ).accessibility_label("Multiline text area")
}
