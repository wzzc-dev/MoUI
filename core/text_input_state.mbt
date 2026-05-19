///|
pub(all) struct TextInputState {
  focused : Bool
  element_id : ElementId?
  text : String
  caret : Int
  selection : TextRange?
  composition : String?
  composition_cursor : TextRange?
  frame : Rect
  caret_rect : Rect
} derive(Eq, Debug, ToJson)

///|
pub fn TextInputState::none() -> TextInputState {
  {
    focused: false,
    element_id: None,
    text: "",
    caret: 0,
    selection: None,
    composition: None,
    composition_cursor: None,
    frame: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
    caret_rect: Rect::new(x=0.0, y=0.0, width=0.0, height=0.0),
  }
}

///|
fn TextInputState::for_text_field(
  element : ElementNode,
  data : TextFieldViewSpec,
  render : RenderNode,
) -> TextInputState {
  let text = data.value.get()
  let display_text = text_with_composition(text, element, true)
  let text_frame = render.frame.inset(
    Insets::symmetric(horizontal=10.0, vertical=4.0),
  )
  let layout = measure_text_layout(
    TextLayoutInput::new(
      text=display_text,
      font=data.font,
      max_width=text_frame.size.width,
    ),
  )
  let caret = clamp_int(element.caret, 0, text_length(text))
  let visual_caret = clamp_int(
    text_field_visual_caret(text, element, true),
    0,
    layout.caret_positions.length() - 1,
  )
  let cursor_x = text_frame.origin.x + layout.caret_positions[visual_caret]
  let caret_rect = Rect::new(
    x=cursor_x,
    y=text_frame.origin.y + 6.0,
    width=1.5,
    height=max_double(8.0, text_frame.size.height - 12.0),
  )
  {
    focused: true,
    element_id: Some(element.id),
    text,
    caret,
    selection: element.selection,
    composition: element.composition,
    composition_cursor: element.composition_cursor,
    frame: render.frame,
    caret_rect,
  }
}

///|
fn TextInputState::for_rich_text_editor(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  render : RenderNode,
) -> TextInputState {
  let text = data.value.get()
  let display_text = text_with_composition(text, element, true)
  let content = render.frame.inset(
    Insets::symmetric(horizontal=14.0, vertical=12.0),
  )
  let caret = clamp_int(element.caret, 0, text_length(text))
  let visual_caret = clamp_int(
    text_field_visual_caret(text, element, true),
    0,
    text_length(display_text),
  )
  let caret_rect = rich_text_caret_rect(
    display_text,
    visual_caret,
    content,
    data.font,
  )
  {
    focused: true,
    element_id: Some(element.id),
    text,
    caret,
    selection: element.selection,
    composition: element.composition,
    composition_cursor: element.composition_cursor,
    frame: render.frame,
    caret_rect,
  }
}

///|
pub fn ElementNode::focused_text_input(
  self : ElementNode,
  target : ElementId,
  render : RenderNode,
) -> TextInputState? {
  if self.id == target {
    match self.spec {
      TextFieldSpec(data) =>
        Some(TextInputState::for_text_field(self, data, render))
      RichTextEditorSpec(data) =>
        Some(TextInputState::for_rich_text_editor(self, data, render))
      _ => None
    }
  } else {
    for index, child in self.children {
      if index < render.children.length() {
        match child.focused_text_input(target, render.children[index]) {
          Some(state) => return Some(state)
          None => ()
        }
      }
    }
    None
  }
}
