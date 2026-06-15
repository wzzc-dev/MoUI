///|
fn[Msg] realize_view_node(
  node : ViewNode[Msg],
  emit : (Msg) -> Unit,
) -> ViewSpec {
  match node {
    EmptyNode => EmptySpec
    TextNode(data) => TextSpec(data)
    ButtonNode(data, message) =>
      ButtonSpec({
        ..data,
        on_click: match message {
          Some(message) => Some(() => emit(message))
          None => None
        },
      })
    TextFieldNode(data, message) =>
      TextFieldSpec({
        ..data,
        on_submit: match message {
          Some(message) => Some(() => emit(message))
          None => None
        },
      })
    ControlledTextFieldNode(data) =>
      TextFieldSpec({
        key: data.key,
        value: Binding::new(get=() => data.value, set=value => {
          emit((data.on_input)(value))
        }),
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
        on_submit: match data.on_submit {
          Some(message) => Some(() => emit(message))
          None => None
        },
      })
    RichTextEditorNode(data, selection, prefix) =>
      RichTextEditorSpec({
        ..data,
        on_selection_change: match selection {
          Some(handler) => Some((caret, range) => emit(handler(caret, range)))
          None => None
        },
        on_prefix_click: match prefix {
          Some(handler) => Some(offset => emit(handler(offset)))
          None => None
        },
      })
    ControlledRichTextEditorNode(data) =>
      RichTextEditorSpec({
        key: data.key,
        value: Binding::new(get=() => data.value, set=value => {
          emit((data.on_input)(value))
        }),
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
        on_selection_change: match data.on_selection_change {
          Some(handler) => Some((caret, range) => emit(handler(caret, range)))
          None => None
        },
        on_prefix_click: match data.on_prefix_click {
          Some(handler) => Some(offset => emit(handler(offset)))
          None => None
        },
        input_transform: data.input_transform,
        accepts_tab_input: data.accepts_tab_input,
      })
    ImageNode(data) => ImageSpec(data)
    CheckboxNode(data) => CheckboxSpec(data)
    ControlledCheckboxNode(data) =>
      CheckboxSpec({
        key: data.key,
        label: data.label,
        checked: Binding::new(get=() => data.checked, set=checked => {
          emit((data.on_change)(checked))
        }),
        font: data.font,
        foreground: data.foreground,
        check_color: data.check_color,
        size: data.size,
      })
    PickerNode(data) => PickerSpec(data)
    ControlledPickerNode(data) =>
      PickerSpec({
        key: data.key,
        items: data.items,
        selected: Binding::new(get=() => data.selected, set=selected => {
          emit((data.on_select)(selected))
        }),
        placeholder: data.placeholder,
        font: data.font,
        foreground: data.foreground,
        background: data.background,
        cornerRadius: data.cornerRadius,
        maxHeight: data.maxHeight,
      })
    DatePickerNode(data) => DatePickerSpec(data)
    ControlledDatePickerNode(data) =>
      DatePickerSpec({
        key: data.key,
        selected: Binding::new(get=() => data.selected, set=selected => {
          emit((data.on_select)(selected))
        }),
        mode: data.mode,
        placeholder: data.placeholder,
        font: data.font,
        foreground: data.foreground,
        background: data.background,
        corner_radius: data.corner_radius,
        min_date: data.min_date,
        max_date: data.max_date,
      })
    SearchBarNode(data, submit, clear) =>
      SearchBarSpec({
        ..data,
        on_submit: match submit {
          Some(message) => Some(() => emit(message))
          None => None
        },
        on_clear: match clear {
          Some(message) => Some(() => emit(message))
          None => None
        },
      })
    ControlledSearchBarNode(data) =>
      SearchBarSpec({
        key: data.key,
        query: Binding::new(get=() => data.query, set=query => {
          emit((data.on_input)(query))
        }),
        placeholder: data.placeholder,
        font: data.font,
        foreground: data.foreground,
        placeholder_color: data.placeholder_color,
        background: data.background,
        border: data.border,
        focused_border: data.focused_border,
        cursor_color: data.cursor_color,
        corner_radius: data.corner_radius,
        on_submit: match data.on_submit {
          Some(message) => Some(() => emit(message))
          None => None
        },
        on_clear: match data.on_clear {
          Some(message) => Some(() => emit(message))
          None => None
        },
      })
    WebViewNode(data, event_handler) =>
      WebViewHostSpec({
        ..data,
        on_event: match event_handler {
          Some(handler) => Some(event => emit(handler(event)))
          None => None
        },
      })
    SheetNode(data, content, dismiss) =>
      SheetSpec({
        ..data,
        content: realize_view_node(content, emit),
        on_dismiss: match dismiss {
          Some(message) => Some(() => emit(message))
          None => None
        },
      })
    FlexNode(data, children) =>
      FlexSpec({
        ..data,
        children: children.map(child => realize_view_node(child, emit)),
      })
    PaddingNode(data, child) =>
      PaddingSpec({ ..data, child: realize_view_node(child, emit) })
    ContainerNode(data, child) =>
      ContainerSpec({
        ..data,
        child: match child {
          Some(child) => Some(realize_view_node(child, emit))
          None => None
        },
      })
    SpacerNode(data) => SpacerSpec(data)
    FrameNode(data, child) =>
      FrameSpec({ ..data, child: realize_view_node(child, emit) })
    StackNode(data, children) =>
      StackSpec({
        ..data,
        children: children.map(child => realize_view_node(child, emit)),
      })
    ScrollNode(data, child, state, scroll) =>
      ScrollSpec({
        ..data,
        offset: match state {
          Some(state) => state.offset()
          None => data.offset
        },
        child: realize_view_node(child, emit),
        scroll_state: state,
        scroll_activates: scroll is Some(_),
        on_scroll: match (state, scroll) {
          (Some(state), Some(handler)) =>
            Some(delta => {
              state.scroll_to(
                x=0.0,
                y=max_scroll_offset(0.0, state.offset().y - delta.y),
              )
              emit(handler(delta))
            })
          (Some(state), None) =>
            Some(delta => {
              state.scroll_to(
                x=0.0,
                y=max_scroll_offset(0.0, state.offset().y - delta.y),
              )
            })
          (None, Some(handler)) => Some(delta => emit(handler(delta)))
          (None, None) => None
        },
      })
    GridNode(data, children) =>
      GridSpec({
        ..data,
        children: children.map(child => realize_view_node(child, emit)),
      })
    ListNode(data, children) =>
      ListSpec({
        ..data,
        children: children.map(child => realize_view_node(child, emit)),
      })
    ModifiedNode(modifier, child) => {
      let spec = realize_view_node(child, emit)
      match modifier {
        KeyModifierNode(key) => spec.with_key(key)
        PlainModifier(modifier) => spec.modified(modifier)
        TapModifier(message) => spec.on_tap(() => emit(message))
        LongPressModifier(message) => spec.on_long_press(() => emit(message))
        DoubleTapModifier(message) => spec.on_double_tap(() => emit(message))
        DragModifier(handler) =>
          spec.on_drag(drag_event => emit(handler(drag_event)))
        DragWithFrameModifier(handler) =>
          spec.on_drag_with_frame((drag_event, frame) => {
            emit(handler(drag_event, frame))
          })
        FileDropModifier(handler) =>
          spec.on_file_drop((paths, point) => emit(handler(paths, point)))
      }
    }
    CustomNode(data) => CustomSpec(data)
    CustomLayoutNode(data, children) =>
      CustomLayoutSpec({
        ..data,
        children: children.map(child => realize_view_node(child, emit)),
      })
    ComponentNode(build) =>
      ViewSpec::component(Component::new(ctx => realize_view(build(ctx), emit)))
  }
}

///|
fn[Msg, NextMsg] map_view_node(
  node : ViewNode[Msg],
  map : (Msg) -> NextMsg,
) -> ViewNode[NextMsg] {
  match node {
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
fn max_scroll_offset(min : Double, value : Double) -> Double {
  if value < min {
    min
  } else {
    value
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
