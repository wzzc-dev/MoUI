///|
fn[Msg] rich_text_editor(
  value~ : String,
  placeholder~ : String,
  size~ : @core.Size,
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border? : @core.BorderStyle? = None,
  focused_border? : @core.BorderStyle? = None,
  cursor_color~ : @core.Color,
  corner_radius? : Double = 0.0,
  on_input? : ((String) -> Msg)? = None,
  on_input_edit? : ((String, Int, @core.TextRange?) -> Msg)? = None,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  on_command_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
  visible_scroll_y? : Double = 0.0,
  on_scroll? : ((Double) -> Msg)? = None,
  visible_viewport_height? : Double = 0.0,
  visible_overscan? : Double = 320.0,
  selection_caret? : Int = -1,
  selection_range? : @core.TextRange? = None,
  kind? : String = "RichTextEditor",
  key? : String? = None,
) -> @core.View[Msg] {
  rich_text_editor_snapshot(
    value~,
    placeholder~,
    size~,
    format~,
    font~,
    foreground~,
    placeholder_color~,
    background~,
    border~,
    focused_border~,
    cursor_color~,
    corner_radius~,
    on_input~,
    on_input_edit~,
    on_selection_change~,
    on_prefix_click~,
    on_command_click~,
    input_transform~,
    accepts_tab_input~,
    visible_scroll_y~,
    on_scroll~,
    visible_viewport_height~,
    visible_overscan~,
    selection_caret~,
    selection_range~,
    kind~,
    key~,
  )
}

///|
fn[Msg] rich_text_editor_snapshot(
  value~ : String,
  placeholder~ : String,
  size~ : @core.Size,
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border~ : @core.BorderStyle?,
  focused_border~ : @core.BorderStyle?,
  cursor_color~ : @core.Color,
  corner_radius~ : Double,
  on_input~ : ((String) -> Msg)?,
  on_input_edit~ : ((String, Int, @core.TextRange?) -> Msg)?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int) -> Msg)?,
  on_command_click~ : ((Int) -> Msg)?,
  input_transform~ : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)?,
  accepts_tab_input~ : Bool,
  visible_scroll_y~ : Double,
  on_scroll~ : ((Double) -> Msg)?,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
  selection_caret~ : Int,
  selection_range~ : @core.TextRange?,
  kind~ : String,
  key~ : String?,
) -> @core.View[Msg] {
  // Internal event paths publish the committed edit record alongside the
  // text; the public channel keeps its three-argument shape and ignores it.
  let on_input_edit = match on_input_edit {
    Some(handler) =>
      Some(
        fn(
          text : String,
          caret : Int,
          selection : @core.TextRange?,
          _edit : RichTextInputEdit?,
        ) { handler(text, caret, selection) },
      )
    None => None
  }
  let value_snapshot = value
  @core.View::from_node(
    RichTextEditorViewNode::{
      value: value_snapshot,
      placeholder,
      size,
      format,
      font,
      foreground,
      placeholder_color,
      background,
      border,
      focused_border,
      cursor_color,
      corner_radius,
      accepts_tab_input,
      visible_scroll_y,
      visible_viewport_height,
      visible_overscan,
      selection_caret,
      selection_range,
      kind,
      key,
    },
    event=(node, ctx) => {
      rich_text_editor_event(
        ctx,
        value~,
        format=node.format,
        font=node.font,
        on_input~,
        on_input_edit~,
        on_selection_change~,
        on_prefix_click~,
        on_command_click~,
        input_transform~,
        accepts_tab_input=node.accepts_tab_input,
        visible_scroll_y~,
        on_scroll~,
        visible_viewport_height=node.visible_viewport_height,
        visible_overscan=node.visible_overscan,
      )
    },
    text_command=(node, ctx, intent, paste_text) => {
      rich_text_editor_command(
        ctx,
        value~,
        format=node.format,
        on_input~,
        on_input_edit~,
        on_selection_change~,
        input_transform~,
        intent,
        paste_text~,
      )
    },
    semantics_actions=_node => {
      [
        @core.ViewSemanticsActionHandler::set_text((ctx, next_text) => {
          let caret = text_length(next_text)
          let next_control = {
            ..ctx.text_control,
            caret,
            selection: None,
            text_selection_anchor: None,
            composition: None,
            composition_cursor: None,
          }
          let messages : Array[Msg] = []
          match on_input {
            Some(handler) => messages.push(handler(next_text))
            None => ()
          }
          match on_input_edit {
            Some(handler) => messages.push(handler(next_text, caret, None, None))
            None => ()
          }
          @core.ViewSemanticsActionResult::accepted(
            text_control=Some(next_control),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
            messages~,
          )
        }),
      ]
    },
  )
}

///|
priv struct RichTextEditorViewNode {
  value : String
  placeholder : String
  size : @core.Size
  format : RichTextFormatter
  font : @core.FontSpec
  foreground : @core.Color
  placeholder_color : @core.Color
  background : @core.Brush
  border : @core.BorderStyle?
  focused_border : @core.BorderStyle?
  cursor_color : @core.Color
  corner_radius : Double
  accepts_tab_input : Bool
  visible_scroll_y : Double
  visible_viewport_height : Double
  visible_overscan : Double
  selection_caret : Int
  selection_range : @core.TextRange?
  kind : String
  key : String?
}

///|
impl @core.ViewNode for RichTextEditorViewNode with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for RichTextEditorViewNode with fn declaration(self) {
  rich_text_declaration(
    layout=rich_text_exact_channel(declaration_size_key(self.size)),
    paint=@core.DeclarationChannel::Uncacheable,
    semantics=rich_text_exact_channel(
      rich_text_record_key("RichTextEditor.semantics", [
        ("label", @core.DeclarationKey::string(self.placeholder)),
        ("value", @core.DeclarationKey::string(self.value)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for RichTextEditorViewNode with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(self.size))
}

///|
impl @core.ViewNode for RichTextEditorViewNode with fn paint(self, ctx) {
  rich_text_editor_paint(
    ctx,
    value=self.value,
    placeholder=self.placeholder,
    format=self.format,
    font=self.font,
    foreground=self.foreground,
    placeholder_color=self.placeholder_color,
    background=self.background,
    border=self.border,
    focused_border=self.focused_border,
    cursor_color=self.cursor_color,
    corner_radius=self.corner_radius,
    visible_scroll_y=self.visible_scroll_y,
    visible_viewport_height=self.visible_viewport_height,
    visible_overscan=self.visible_overscan,
  )
}

///|
impl @core.ViewNode for RichTextEditorViewNode with fn text_input_state(
  self,
  ctx,
) {
  Some(
    rich_text_input_state(
      text=self.value,
      frame=ctx.frame,
      format=self.format,
      font=self.font,
      control=ctx.text_control,
      selection_caret=self.selection_caret,
      selection_range=self.selection_range,
      visible_scroll_y=self.visible_scroll_y,
      visible_viewport_height=self.visible_viewport_height,
      visible_overscan=self.visible_overscan,
      text_system=ctx.text_system,
    ),
  )
}

///|
impl @core.ViewNode for RichTextEditorViewNode with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::TextField,
    label=self.placeholder,
    value=self.value,
  )
}

///|
impl @core.ViewNode for RichTextEditorViewNode with fn focusable(_self) {
  true
}

///|
pub fn[Msg] controlled_rich_text_editor(
  value~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  size~ : @core.Size,
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border? : @core.BorderStyle? = None,
  focused_border? : @core.BorderStyle? = None,
  cursor_color~ : @core.Color,
  corner_radius? : Double = 0.0,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  on_command_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
  visible_scroll_y? : Double = 0.0,
  on_scroll? : ((Double) -> Msg)? = None,
  visible_viewport_height? : Double = 0.0,
  visible_overscan? : Double = 320.0,
  selection_caret? : Int = -1,
  selection_range? : @core.TextRange? = None,
  kind? : String = "RichTextEditor",
  key? : String? = None,
) -> @core.View[Msg] {
  rich_text_editor(
    value~,
    placeholder~,
    size~,
    format~,
    font~,
    foreground~,
    placeholder_color~,
    background~,
    border~,
    focused_border~,
    cursor_color~,
    corner_radius~,
    on_input=Some(on_input),
    on_input_edit=None,
    on_selection_change~,
    on_prefix_click~,
    on_command_click~,
    input_transform~,
    accepts_tab_input~,
    visible_scroll_y~,
    on_scroll~,
    visible_viewport_height~,
    visible_overscan~,
    selection_caret~,
    selection_range~,
    kind~,
    key~,
  )
}
