///|
pub fn[Msg] text(
  text : String,
  role? : @style.TextRole = @style.TextRole::Body,
  theme? : @core.Theme,
  width? : Double = 160.0,
  height? : Double = 32.0,
  align? : @core.TextAlign = @core.TextAlign::TextCenter,
) -> @core.View[Msg] {
  let size = @core.Size::new(width~, height~)
  @core.View::from_node(Text::{ text, role, theme, size, align })
}

///|
priv struct Text {
  text : String
  role : @style.TextRole
  theme : @core.Theme?
  size : @core.Size
  align : @core.TextAlign
}

///|
impl @core.ViewNode for Text with fn identity(_self) {
  @core.ViewIdentity::new(kind="Text")
}

///|
impl @core.ViewNode for Text with fn declaration(self) {
  let role = @core.DeclarationKey::int(
    match self.role {
      Body => 0
      Title => 1
      Caption => 2
      Control => 3
      Mono => 4
      Display => 5
      Headline => 6
      Subtitle => 7
      Label => 8
      Overline => 9
    },
  )
  let align = @core.DeclarationKey::int(
    match self.align {
      @core.TextAlign::TextStart => 0
      @core.TextAlign::TextCenter => 1
      @core.TextAlign::TextEnd => 2
    },
  )
  @common.view_declaration(
    layout=@common.view_exact_channel(@common.view_size_key(self.size)),
    paint=if self.theme is Some(_) {
      @core.DeclarationChannel::Uncacheable
    } else {
      @common.view_exact_channel(
        @common.view_record_key("Text.paint", [
          ("text", @core.DeclarationKey::string(self.text)),
          ("role", role),
          ("align", align),
        ]),
      )
    },
    semantics=@common.view_exact_channel(
      @core.DeclarationKey::string(self.text),
    ),
  )
}

///|
impl @core.ViewNode for Text with fn layout(self, context) {
  @core.ViewLayoutResult::new(size=context.constraints.constrain(self.size))
}

///|
impl @core.ViewNode for Text with fn paint(self, context) {
  let resolved_theme = self.theme.unwrap_or(context.environment.theme)
  let font = context.style.font.unwrap_or(self.role.font(resolved_theme))
  let color = if context.environment.enabled {
    context.style.foreground.unwrap_or(self.role.color(resolved_theme))
  } else {
    context.style.foreground
    .unwrap_or(self.role.color(resolved_theme))
    .multiply_alpha(0.7)
  }
  @core.ViewPaintPlan::commands([
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=self.text,
        frame=context.frame,
        font~,
        color~,
        align=self.align,
      ),
    ),
  ])
}

///|
impl @core.ViewNode for Text with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Text,
    label=self.text,
    value=self.text,
  )
}

///|
pub fn[Msg] text_field(
  value : String,
  on_input~ : (String) -> Msg,
  on_submit? : Msg? = None,
  placeholder? : String = "",
  variant? : @style.TextFieldVariant = @style.TextFieldVariant::Filled,
  theme? : @core.Theme,
  style? : @style.TextFieldStyle,
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
  variant? : @style.TextFieldVariant = @style.TextFieldVariant::Outline,
  theme? : @core.Theme,
  width? : Double = 320.0,
  line_height? : Double = 28.0,
  on_submit? : Msg? = None,
) -> @core.View[Msg] {
  text_area_control(
    value~,
    on_input=Some(on_input),
    on_submit~,
    placeholder~,
    size=@core.Size::new(
      width~,
      height=@common.view_max_double(
        line_height,
        lines.to_double() * line_height,
      ),
    ),
    theme?,
    variant~,
    lines~,
    line_height~,
  ).accessibility_label("Multiline text area")
}
