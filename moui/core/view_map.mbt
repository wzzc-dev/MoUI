///|
fn[Msg, NextMsg] map_view_node(
  node : ViewNode[Msg],
  map : (Msg) -> NextMsg,
) -> ViewNode[NextMsg] {
  match node {
    WidgetNode(ops) => WidgetNode(ops.map(map))
    EmptyNode => EmptyNode
    TextNode(data) => TextNode(data)
    ButtonNode(data, message) =>
      ButtonNode(data, option_map_message(message, map))
    TextFieldNode(data, message) =>
      TextFieldNode(data, option_map_message(message, map))
    ControlledTextFieldNode(data) =>
      ControlledTextFieldNode({
        key: data.key,
        value: data.value,
        placeholder: data.placeholder,
        size: data.size,
        font: data.font,
        foreground: data.foreground,
        placeholder_color: data.placeholder_color,
        background: data.background,
        border: data.border,
        focused_border: data.focused_border,
        cursor_color: data.cursor_color,
        corner_radius: data.corner_radius,
        on_input: value => map((data.on_input)(value)),
        on_submit: option_map_message(data.on_submit, map),
      })
    RichTextEditorNode(data, selection, prefix) =>
      RichTextEditorNode(
        data,
        option_map_selection_handler(selection, map),
        option_map_prefix_handler(prefix, map),
      )
    ControlledRichTextEditorNode(data) =>
      ControlledRichTextEditorNode({
        key: data.key,
        value: data.value,
        placeholder: data.placeholder,
        size: data.size,
        format: data.format,
        font: data.font,
        foreground: data.foreground,
        placeholder_color: data.placeholder_color,
        background: data.background,
        border: data.border,
        focused_border: data.focused_border,
        cursor_color: data.cursor_color,
        corner_radius: data.corner_radius,
        on_input: value => map((data.on_input)(value)),
        on_selection_change: option_map_selection_handler(
          data.on_selection_change,
          map,
        ),
        on_prefix_click: option_map_prefix_handler(data.on_prefix_click, map),
        input_transform: data.input_transform,
        accepts_tab_input: data.accepts_tab_input,
      })
    ImageNode(data) => ImageNode(data)
    CheckboxNode(data) => CheckboxNode(data)
    ControlledCheckboxNode(data) =>
      ControlledCheckboxNode({
        key: data.key,
        label: data.label,
        checked: data.checked,
        font: data.font,
        foreground: data.foreground,
        check_color: data.check_color,
        size: data.size,
        on_change: value => map((data.on_change)(value)),
      })
    PickerNode(data) => PickerNode(data)
    ControlledPickerNode(data) =>
      ControlledPickerNode({
        key: data.key,
        items: data.items,
        selected: data.selected,
        placeholder: data.placeholder,
        font: data.font,
        foreground: data.foreground,
        background: data.background,
        cornerRadius: data.cornerRadius,
        maxHeight: data.maxHeight,
        on_select: value => map((data.on_select)(value)),
      })
    DatePickerNode(data) => DatePickerNode(data)
    ControlledDatePickerNode(data) =>
      ControlledDatePickerNode({
        key: data.key,
        selected: data.selected,
        mode: data.mode,
        placeholder: data.placeholder,
        font: data.font,
        foreground: data.foreground,
        background: data.background,
        corner_radius: data.corner_radius,
        min_date: data.min_date,
        max_date: data.max_date,
        on_select: value => map((data.on_select)(value)),
      })
    SearchBarNode(data, submit, clear) =>
      SearchBarNode(
        data,
        option_map_message(submit, map),
        option_map_message(clear, map),
      )
    ControlledSearchBarNode(data) =>
      ControlledSearchBarNode({
        key: data.key,
        query: data.query,
        placeholder: data.placeholder,
        font: data.font,
        foreground: data.foreground,
        placeholder_color: data.placeholder_color,
        background: data.background,
        border: data.border,
        focused_border: data.focused_border,
        cursor_color: data.cursor_color,
        corner_radius: data.corner_radius,
        on_input: value => map((data.on_input)(value)),
        on_submit: option_map_message(data.on_submit, map),
        on_clear: option_map_message(data.on_clear, map),
      })
    WebViewNode(data, event_handler) =>
      WebViewNode(data, option_map_web_view_event_handler(event_handler, map))
    SheetNode(data, content, dismiss) =>
      SheetNode(
        data,
        map_view_node(content, map),
        option_map_message(dismiss, map),
      )
    FlexNode(data, children) =>
      FlexNode(data, children.map(child => map_view_node(child, map)))
    PaddingNode(data, child) => PaddingNode(data, map_view_node(child, map))
    ContainerNode(data, child) =>
      ContainerNode(data, option_map_view_node(child, map))
    SpacerNode(data) => SpacerNode(data)
    FrameNode(data, child) => FrameNode(data, map_view_node(child, map))
    StackNode(data, children) =>
      StackNode(data, children.map(child => map_view_node(child, map)))
    ScrollNode(data, child, state, scroll) =>
      ScrollNode(
        data,
        map_view_node(child, map),
        state,
        option_map_scroll_handler(scroll, map),
      )
    GridNode(data, children) =>
      GridNode(data, children.map(child => map_view_node(child, map)))
    ListNode(data, children) =>
      ListNode(data, children.map(child => map_view_node(child, map)))
    ModifiedNode(modifier, child) =>
      ModifiedNode(map_modifier_node(modifier, map), map_view_node(child, map))
    CustomNode(data) => CustomNode(data)
    CustomLayoutNode(data, children) =>
      CustomLayoutNode(data, children.map(child => map_view_node(child, map)))
    ComponentNode(build) => ComponentNode(ctx => build(ctx).map(map))
  }
}

///|
fn[Msg, NextMsg] map_modifier_node(
  modifier : ViewModifierNode[Msg],
  map : (Msg) -> NextMsg,
) -> ViewModifierNode[NextMsg] {
  match modifier {
    KeyModifierNode(key) => KeyModifierNode(key)
    PlainModifier(modifier) => PlainModifier(modifier)
    TapModifier(message) => TapModifier(map(message))
    LongPressModifier(message) => LongPressModifier(map(message))
    DoubleTapModifier(message) => DoubleTapModifier(map(message))
    DragModifier(handler) =>
      DragModifier(drag_event => map(handler(drag_event)))
    DragWithFrameModifier(handler) =>
      DragWithFrameModifier((drag_event, frame) => {
        map(handler(drag_event, frame))
      })
    FileDropModifier(handler) =>
      FileDropModifier((paths, point) => map(handler(paths, point)))
  }
}

///|
fn[Msg, NextMsg] option_map_message(
  message : Msg?,
  map : (Msg) -> NextMsg,
) -> NextMsg? {
  match message {
    Some(message) => Some(map(message))
    None => None
  }
}

///|
fn[Msg, NextMsg] option_map_scroll_handler(
  handler : ((Point) -> Msg)?,
  map : (Msg) -> NextMsg,
) -> ((Point) -> NextMsg)? {
  match handler {
    Some(handler) => Some(delta => map(handler(delta)))
    None => None
  }
}

///|
fn[Msg, NextMsg] option_map_selection_handler(
  handler : ((Int, TextRange?) -> Msg)?,
  map : (Msg) -> NextMsg,
) -> ((Int, TextRange?) -> NextMsg)? {
  match handler {
    Some(handler) => Some((caret, range) => map(handler(caret, range)))
    None => None
  }
}

///|
fn[Msg, NextMsg] option_map_prefix_handler(
  handler : ((Int) -> Msg)?,
  map : (Msg) -> NextMsg,
) -> ((Int) -> NextMsg)? {
  match handler {
    Some(handler) => Some(offset => map(handler(offset)))
    None => None
  }
}

///|
fn[Msg, NextMsg] option_map_web_view_event_handler(
  handler : ((WebViewEvent) -> Msg)?,
  map : (Msg) -> NextMsg,
) -> ((WebViewEvent) -> NextMsg)? {
  match handler {
    Some(handler) => Some(event => map(handler(event)))
    None => None
  }
}

///|
fn[Msg, NextMsg] option_map_view_node(
  node : ViewNode[Msg]?,
  map : (Msg) -> NextMsg,
) -> ViewNode[NextMsg]? {
  match node {
    Some(node) => Some(map_view_node(node, map))
    None => None
  }
}
