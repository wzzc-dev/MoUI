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
  text_system : TextSystem,
) -> TextInputState {
  let text = data.value.get()
  let boundaries = TextGraphemeBoundaries::new(text~)
  let display_text = text_with_composition(text, element, true)
  let text_frame = render.frame.inset(
    Insets::symmetric(horizontal=10.0, vertical=4.0),
  )
  let layout = text_system.measure_text(
    TextLayoutInput::new(
      text=display_text,
      font=data.font,
      max_width=text_frame.size.width,
    ),
  )
  let caret = boundaries.nearest_boundary(element.control.caret)
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
    selection: text_input_grapheme_selection(
      boundaries,
      element.control.selection,
    ),
    composition: element.control.composition,
    composition_cursor: element.control.composition_cursor,
    frame: render.frame,
    caret_rect,
  }
}

///|
fn TextInputState::for_searchbar(
  element : ElementNode,
  data : SearchBarViewSpec,
  render : RenderNode,
  text_system : TextSystem,
) -> TextInputState {
  let text = data.query.get()
  let boundaries = TextGraphemeBoundaries::new(text~)
  let display_text = text_with_composition(text, element, true)
  let text_frame = searchbar_text_frame(render.frame, has_text=text != "")
  let layout = text_system.measure_text(
    TextLayoutInput::new(
      text=display_text,
      font=data.font,
      max_width=text_frame.size.width,
    ),
  )
  let caret = boundaries.nearest_boundary(element.control.caret)
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
    selection: text_input_grapheme_selection(
      boundaries,
      element.control.selection,
    ),
    composition: element.control.composition,
    composition_cursor: element.control.composition_cursor,
    frame: render.frame,
    caret_rect,
  }
}

///|
fn TextInputState::for_rich_text_editor(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  render : RenderNode,
  text_system : TextSystem,
) -> TextInputState {
  let text = data.value.get()
  let boundaries = TextGraphemeBoundaries::new(text~)
  let display_text = text_with_composition(text, element, true)
  let content = render.frame.inset(
    Insets::symmetric(horizontal=14.0, vertical=12.0),
  )
  let caret = boundaries.nearest_boundary(element.control.caret)
  let visual_caret = clamp_int(
    text_field_visual_caret(text, element, true),
    0,
    text_length(display_text),
  )
  let document = (data.format)(display_text)
  let caret_rect = rich_text_document_caret_rect(
    document,
    visual_caret,
    content,
    data.font,
    text_system,
  ).unwrap_or(
    rich_text_caret_rect(
      display_text,
      visual_caret,
      content,
      data.font,
      text_system,
    ),
  )
  {
    focused: true,
    element_id: Some(element.id),
    text,
    caret,
    selection: text_input_grapheme_selection(
      boundaries,
      element.control.selection,
    ),
    composition: element.control.composition,
    composition_cursor: element.control.composition_cursor,
    frame: render.frame,
    caret_rect,
  }
}

///|
fn text_input_grapheme_selection(
  boundaries : TextGraphemeBoundaries,
  selection : TextRange?,
) -> TextRange? {
  match selection {
    Some(selection) => {
      let start = boundaries.nearest_boundary(selection.start)
      let end = boundaries.nearest_boundary(selection.end)
      if start == end {
        None
      } else {
        Some(TextRange::new(start~, end~))
      }
    }
    None => None
  }
}

///|
fn ElementNode::focused_text_input(
  self : ElementNode,
  target : ElementId,
  render : RenderNode,
  text_system? : TextSystem = TextSystem::fallback(),
) -> TextInputState? {
  if self.id == target {
    match self.spec {
      TextFieldSpec(data) =>
        Some(TextInputState::for_text_field(self, data, render, text_system))
      SearchBarSpec(data) =>
        Some(TextInputState::for_searchbar(self, data, render, text_system))
      RichTextEditorSpec(data) =>
        Some(
          TextInputState::for_rich_text_editor(self, data, render, text_system),
        )
      _ => None
    }
  } else {
    for index, child in self.children {
      if index < render.children.length() {
        match
          child.focused_text_input(target, render.children[index], text_system~) {
          Some(state) => return Some(state)
          None => ()
        }
      }
    }
    None
  }
}
