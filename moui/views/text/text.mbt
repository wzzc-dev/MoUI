///|
/// Read-only text: a single-line label by default, an auto-wrapping paragraph
/// with `wrap=true`.
///
/// Single line (default): the string never breaks; the box grows to the
/// measured width and renderers clip glyphs to the run frame.
///
/// `wrap=true`: `width` becomes the line width (the incoming layout constraint
/// may only narrow it), the string flows onto further lines through the shared
/// `TextSystem` paragraph engine — real font metrics, CJK- and grapheme-safe
/// breaking, `\n` hard breaks — and the box grows downward with the line
/// count, so a long paragraph composes with `scroll_view` instead of
/// overflowing its row.
pub fn[Msg] text(
  text : String,
  role~ : @style.TextRole = Body,
  theme? : @core.Theme,
  width~ : Double = 160.0,
  height~ : Double = 32.0,
  align~ : @core.TextAlign = TextCenter,
  wrap~ : Bool = false,
) -> @core.View[Msg] {
  let size = @core.Size::new(width~, height~)
  @core.View::from_node(Text::{ text, role, theme, size, align, wrap, })
}

///|
priv struct Text {
  text : String
  role : @style.TextRole
  theme : @core.Theme?
  size : @core.Size
  align : @core.TextAlign
  wrap : Bool
}

///|
impl @core.ViewNode for Text with fn identity(_self) {
  @core.ViewIdentity::new(kind="Text")
}

///|
impl @core.ViewNode for Text with fn layout(self, context) {
  let resolved_theme = context.effective_theme(pinned=self.theme)
  let font = context.style.font.unwrap_or(self.role.font(resolved_theme))
  if self.wrap {
    // Multi-line mode: the requested width bounds the line box and the
    // incoming constraint can only narrow it; the box grows downward with the
    // wrapped line count. Break points come from the shared paragraph engine
    // (the same one behind text_field/text_area), so measurement here is the
    // text system's real metrics — platform font differences and mixed CJK /
    // ASCII scripts included — never an app-side width estimate.
    let available = if context.constraints.max.width < self.size.width {
      context.constraints.max.width
    } else {
      self.size.width
    }
    let wrap_width = if available < 1.0 { 1.0 } else { available }
    let paragraph = context.text_system.layout_paragraph(
      @core.TextLayoutInput::new(text=self.text, font~, max_width=wrap_width),
    )
    let size = @core.Size::new(
      width=wrap_width,
      height=@common.view_max_double(self.size.height, paragraph.size.height),
    )
    @core.ViewLayoutResult::new(size=context.constraints.constrain(size))
  } else {
    let measured = context.text_system.measure_text(
      @core.TextLayoutInput::new(text=self.text, font~),
    )
    // The requested width/height act as a minimum, mirroring Button's `min_size`:
    // text that fits keeps the requested box, and text that does not fit grows the
    // box instead of being clipped. Renderers clip glyphs to the TextRun frame, so
    // a fixed box silently truncated any string whose measured width exceeded it.
    // That surfaced on Linux, where system fonts are wider than the Windows/macOS
    // defaults, but the truncation was never platform-specific.
    let size = @core.Size::new(
      width=@common.view_max_double(self.size.width, measured.size.width),
      height=@common.view_max_double(self.size.height, measured.size.height),
    )
    @core.ViewLayoutResult::new(size=context.constraints.constrain(size))
  }
}

///|
impl @core.ViewNode for Text with fn paint(self, context) {
  let resolved_theme = context.effective_theme(pinned=self.theme)
  let font = context.style.font.unwrap_or(self.role.font(resolved_theme))
  let color = if context.environment.enabled {
    context.style.foreground.unwrap_or(self.role.color(resolved_theme))
  } else {
    context.style.foreground
    .unwrap_or(self.role.color(resolved_theme))
    .multiply_alpha(0.7)
  }
  if self.wrap {
    // One TextRun per wrapped line. `frame` is the view's rect in canvas-global
    // coordinates, so every line offset is added onto frame.origin (never
    // painted from a local (0,0)), the clip that guards pathological
    // constraint changes opens and closes here, and no surface-wide Clear is
    // ever emitted — either would erase views drawn before this one.
    let commands : Array[@core.DrawCommand] = []
    let paragraph = context.text_system.layout_paragraph(
      @core.TextLayoutInput::new(
        text=self.text,
        font~,
        max_width=context.frame.size.width,
      ),
    )
    commands.push(PushClip(context.frame))
    let chars = self.text.to_array()
    for line in paragraph.lines {
      let range = line.text_range
      if range.start >= range.end {
        continue
      }
      commands.push(
        DrawText(
          @core.TextRun::new(
            text=String::from_array(chars[range.start:range.end]),
            frame=@core.Rect::new(
              x=context.frame.origin.x,
              y=context.frame.origin.y + line.origin.y,
              width=context.frame.size.width,
              height=line.size.height,
            ),
            font~,
            color~,
            align=self.align,
          ),
        ),
      )
    }
    commands.push(PopClip)
    @core.ViewPaintPlan::commands(commands)
  } else {
    @core.ViewPaintPlan::commands([
      DrawText(
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
}

///|
impl @core.ViewNode for Text with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=Boundary,
    role=Text,
    label=self.text,
    value=self.text,
  )
}

///|
pub fn[Msg] text_field(
  value : String,
  on_input~ : (String) -> Msg,
  on_submit~ : Msg? = None,
  placeholder~ : String = "",
  variant~ : @style.TextFieldVariant = Filled,
  theme? : @core.Theme,
  style? : @style.TextFieldStyle,
  width~ : Double = 240.0,
  height~ : Double = 40.0,
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
  placeholder~ : String = "",
  lines~ : Int32 = 4,
  variant~ : @style.TextFieldVariant = Outline,
  theme? : @core.Theme,
  width~ : Double = 320.0,
  line_height~ : Double = 28.0,
  on_submit~ : Msg? = None,
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
