///|
/// Read-only text: a single-line label by default, an auto-wrapping paragraph
/// with `wrap=true`.
///
/// Content-sized by default (RFC 0007): the box is the measured text under the
/// ambient font, so scaled text and longer translations grow it instead of
/// clipping. An explicit `width~`/`height~` is a minimum box, not a clamp —
/// text that does not fit still grows it.
///
/// Single line (default): the string never breaks; renderers clip glyphs to the
/// run frame.
///
/// `wrap=true`: the line width is the incoming layout constraint, or the
/// explicit `width~` when given (the constraint may only narrow it). The string
/// flows onto further lines through the shared `TextSystem` paragraph engine —
/// real font metrics, CJK- and grapheme-safe breaking, `\n` hard breaks — and
/// the box grows downward with the line count, so a long paragraph composes
/// with `scroll_view` instead of overflowing its row.
pub fn[Msg] text(
  text : String,
  role~ : @style.TextRole = Body,
  theme? : @core.Theme,
  width~ : Double = 0.0,
  height~ : Double = 0.0,
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
    // Multi-line mode: an unset width takes the whole incoming constraint; an
    // explicit width bounds the line box and the constraint can only narrow it.
    // The box grows downward with the wrapped line count. Break points come
    // from the shared paragraph engine (the same one behind text_field /
    // text_area), so measurement here is the text system's real metrics —
    // platform font differences and mixed CJK / ASCII scripts included — never
    // an app-side width estimate.
    let available = if self.size.width <= 0.0 {
      context.constraints.max.width
    } else if context.constraints.max.width < self.size.width {
      context.constraints.max.width
    } else {
      self.size.width
    }
    let wrap_width = if available < 1.0 { 1.0 } else { available }
    let paragraph = text_apply_line_height(
      context.text_system.layout_paragraph(
        @core.TextLayoutInput::new(
          text=self.text,
          font~,
          max_width=wrap_width,
          direction=context.environment.layout_direction,
        ),
      ),
      font.line_height,
    )
    let size = @core.Size::new(
      width=wrap_width,
      height=@common.view_max_double(self.size.height, paragraph.size.height),
    )
    @core.ViewLayoutResult::new(size=context.constraints.constrain(size))
  } else {
    let measured = context.text_system.measure_text(
      @core.TextLayoutInput::new(
        text=self.text,
        font~,
        direction=context.environment.layout_direction,
      ),
    )
    // The requested width/height act as a minimum, mirroring Button's `min_size`.
    // The default is 0x0, so an unsized label is exactly its measured content
    // (RFC 0007). Renderers clip glyphs to the TextRun frame, so returning a
    // fixed box verbatim silently truncated any string whose measured width
    // exceeded it. That surfaced on Linux, where system fonts are wider than the
    // Windows/macOS defaults, but the truncation was never platform-specific.
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
    let paragraph = text_apply_line_height(
      context.text_system.layout_paragraph(
        @core.TextLayoutInput::new(
          text=self.text,
          font~,
          max_width=context.frame.size.width,
          direction=context.environment.layout_direction,
        ),
      ),
      font.line_height,
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
/// Re-flow a paragraph's line boxes onto an explicit line height. The provider
/// keeps its natural leading; this only moves each line box and grows the
/// paragraph, centering the glyph box inside the new line box. Caret rects
/// move with their line so selection stays on the glyphs.
fn text_apply_line_height(
  paragraph : @core.TextParagraphLayoutResult,
  line_height : Double?,
) -> @core.TextParagraphLayoutResult {
  let requested = match line_height {
    Some(value) => value
    None => return paragraph
  }
  if requested <= 0.0 || paragraph.lines.is_empty() {
    return paragraph
  }
  let lines : Array[@core.TextParagraphLineMetrics] = []
  // (original_top, original_bottom, shift, new_height) per line, for carets.
  let line_shifts : Array[(Double, Double, Double, Double)] = []
  let mut line_top = 0.0
  for line in paragraph.lines {
    let leading = (requested - line.size.height) / 2.0
    let shift = line_top - line.origin.y + leading
    lines.push({
      ..line,
      origin: @core.Point::new(x=line.origin.x, y=line_top + leading),
      baseline: line.baseline + shift,
    })
    line_shifts.push(
      (line.origin.y, line.origin.y + line.size.height, shift, requested),
    )
    line_top = line_top + requested
  }
  let caret_rects : Array[@core.Rect] = []
  for caret in paragraph.caret_rects {
    let mut shift = 0.0
    let mut height = caret.size.height
    for entry in line_shifts {
      if caret.origin.y >= entry.0 && caret.origin.y < entry.1 {
        shift = entry.2
        height = entry.3
        break
      }
    }
    caret_rects.push(
      @core.Rect::new(
        x=caret.origin.x,
        y=caret.origin.y + shift,
        width=caret.size.width,
        height~,
      ),
    )
  }
  {
    ..paragraph,
    size: @core.Size::new(
      width=paragraph.size.width,
      height=paragraph.lines.length().to_double() * requested,
    ),
    baseline: if lines.is_empty() {
      paragraph.baseline
    } else {
      lines[0].baseline
    },
    lines,
    caret_rects,
  }
}

///|
impl @core.ViewNode for Text with fn semantics(self) {
  @core.ViewSemanticsInfo::leaf(role=Text, label=self.text, value=self.text)
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
  height? : Double,
) -> @core.View[Msg] {
  // Style is resolved ambient-ly inside the control (an explicit theme?
  // overrides ctx.environment.theme) so the field tracks dark-mode / a11y
  // changes without the caller rebuilding the view tree.
  controlled_text_field_control(
    value~,
    on_input~,
    placeholder~,
    size=@core.Size::new(width~, height=height.unwrap_or(0.0)),
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
