///|
pub struct ViewLoweringSink[Msg, Node] {
  priv empty : () -> Node
  priv text : (String?, String, Size, FontSpec, Color) -> Node
  priv button : (
    String?,
    String,
    Size,
    FontSpec,
    Color,
    Brush,
    Brush,
    Brush,
    BorderStyle?,
    ShadowStyle?,
    Double,
    Msg?,
  ) -> Node
  priv text_field : (
    String?,
    Binding[String],
    String,
    Size,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    Msg?,
  ) -> Node
  priv controlled_text_field : (
    String?,
    String,
    (String) -> Msg,
    String,
    Size,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    Msg?,
  ) -> Node
  priv rich_text_editor : (
    String?,
    Binding[String],
    String,
    Size,
    RichTextFormatter,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    ((Int, TextRange?) -> Msg)?,
    ((Int) -> Msg)?,
    ((String, Int, TextRange?, String) -> RichTextInputTransform?)?,
    Bool,
  ) -> Node
  priv controlled_rich_text_editor : (
    String?,
    String,
    (String) -> Msg,
    String,
    Size,
    RichTextFormatter,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    ((Int, TextRange?) -> Msg)?,
    ((Int) -> Msg)?,
    ((String, Int, TextRange?, String) -> RichTextInputTransform?)?,
    Bool,
  ) -> Node
  priv image : (String?, String, Size?, Double, Double, ImageFit) -> Node
  priv checkbox : (String?, String, Binding[Bool], FontSpec, Color, Color, Size) -> Node
  priv controlled_checkbox : (
    String?,
    String,
    Bool,
    (Bool) -> Msg,
    FontSpec,
    Color,
    Color,
    Size,
  ) -> Node
  priv picker : (
    String?,
    Array[PickerItem],
    Binding[String],
    String,
    FontSpec,
    Color,
    Brush,
    Double,
    Double,
  ) -> Node
  priv controlled_picker : (
    String?,
    Array[PickerItem],
    String,
    (String) -> Msg,
    String,
    FontSpec,
    Color,
    Brush,
    Double,
    Double,
  ) -> Node
  priv datepicker : (
    String?,
    Binding[DateValue],
    DatePickerMode,
    String,
    FontSpec,
    Color,
    Brush,
    Double,
    DateValue?,
    DateValue?,
  ) -> Node
  priv controlled_datepicker : (
    String?,
    DateValue,
    (DateValue) -> Msg,
    DatePickerMode,
    String,
    FontSpec,
    Color,
    Brush,
    Double,
    DateValue?,
    DateValue?,
  ) -> Node
  priv search_bar : (
    String?,
    Binding[String],
    String,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    Msg?,
    Msg?,
  ) -> Node
  priv controlled_search_bar : (
    String?,
    String,
    (String) -> Msg,
    String,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    Msg?,
    Msg?,
  ) -> Node
  priv web_view : (String?, WebViewSpec, ((WebViewEvent) -> Msg)?) -> Node
  priv sheet : (
    String?,
    Node,
    SheetPresentationMode,
    Brush,
    Double,
    ShadowStyle?,
    Msg?,
  ) -> Node
  priv flex : (
    String?,
    Axis,
    Double,
    MainAxisAlignment,
    CrossAxisAlignment,
    Array[Node],
  ) -> Node
  priv padding : (String?, Insets, Node) -> Node
  priv container : (
    String?,
    Size?,
    Brush?,
    BorderStyle?,
    Double,
    ShadowStyle?,
    Node?,
  ) -> Node
  priv spacer : (String?, Double, Double) -> Node
  priv frame : (
    String?,
    Double?,
    Double?,
    Double?,
    Double?,
    Double?,
    Double?,
    Node,
  ) -> Node
  priv stack : (String?, Array[Node]) -> Node
  priv scroll : (String?, Point, Size?, ScrollState?, ((Point) -> Msg)?, Node) -> Node
  priv grid : (String?, Int, Double, Double, Array[Node]) -> Node
  priv list : (String?, Double, Array[Node]) -> Node
  priv key : (String, Node) -> Node
  priv padding_modifier : (Insets, Node) -> Node
  priv frame_modifier : (
    Double?,
    Double?,
    Double?,
    Double?,
    Double?,
    Double?,
    Node,
  ) -> Node
  priv background_modifier : (Brush, Node) -> Node
  priv foreground_modifier : (Color, Node) -> Node
  priv font_modifier : (FontSpec, Node) -> Node
  priv corner_radius_modifier : (Double, Node) -> Node
  priv opacity_modifier : (Double, Node) -> Node
  priv shadow_modifier : (ShadowStyle, Node) -> Node
  priv border_modifier : (BorderStyle, Node) -> Node
  priv offset_modifier : (Double, Double, Node) -> Node
  priv clip_modifier : (Node) -> Node
  priv scale_modifier : (Double, Double, Node) -> Node
  priv disabled_modifier : (Bool, Node) -> Node
  priv accessibility_label_modifier : (String, Node) -> Node
  priv semantics_role_modifier : (SemanticsRole, Node) -> Node
  priv semantics_selected_modifier : (Bool, Node) -> Node
  priv semantics_pressed_modifier : (Bool, Node) -> Node
  priv semantics_checked_modifier : (Bool, Node) -> Node
  priv semantics_expanded_modifier : (Bool, Node) -> Node
  priv semantics_invalid_modifier : (Bool, Node) -> Node
  priv semantics_required_modifier : (Bool, Node) -> Node
  priv semantics_description_modifier : (String, Node) -> Node
  priv semantics_action_modifier : (SemanticsAction, Node) -> Node
  priv focusable_modifier : (Bool, Node) -> Node
  priv focus_trap_modifier : (Bool, Node) -> Node
  priv on_tap_modifier : (Msg, Node) -> Node
  priv on_long_press_modifier : (Msg, Node) -> Node
  priv on_double_tap_modifier : (Msg, Node) -> Node
  priv on_drag_modifier : ((DragGestureEvent) -> Msg, Node) -> Node
  priv on_drag_with_frame_modifier : ((DragGestureEvent, Rect) -> Msg, Node) -> Node
  priv on_file_drop_modifier : ((Array[String], Point) -> Msg, Node) -> Node
  priv keyboard_shortcut_modifier : (KeyboardShortcut, Node) -> Node
  priv flexible_modifier : (Double, Node) -> Node
  priv layout_priority_modifier : (Double, Node) -> Node
  priv align_modifier : (Alignment, Node) -> Node
  priv spacing_modifier : (Double, Node) -> Node
  priv main_axis_alignment_modifier : (MainAxisAlignment, Node) -> Node
  priv cross_axis_alignment_modifier : (CrossAxisAlignment, Node) -> Node
  priv theme_modifier : (Theme, Node) -> Node
  priv environment_modifier : (Environment, Node) -> Node
  priv on_tap_handler_modifier : (() -> Unit, Node) -> Node
  priv on_long_press_handler_modifier : (() -> Unit, Node) -> Node
  priv on_double_tap_handler_modifier : (() -> Unit, Node) -> Node
  priv on_drag_handler_modifier : ((DragGestureEvent) -> Unit, Node) -> Node
  priv on_drag_with_frame_handler_modifier : (
    (DragGestureEvent, Rect) -> Unit,
    Node,
  ) -> Node
  priv on_file_drop_handler_modifier : ((Array[String], Point) -> Unit, Node) -> Node
  priv aspect_ratio_modifier : (Double, Node) -> Node
  priv intrinsic_width_modifier : (Node) -> Node
  priv intrinsic_height_modifier : (Node) -> Node
  priv repaint_boundary_modifier : (Node) -> Node
  priv custom : (
    String?,
    (Constraints) -> Size,
    (Rect) -> Array[DrawCommand],
    SemanticsRole,
    String,
  ) -> Node
  priv custom_layout : (
    String?,
    Array[Node],
    CustomLayoutCache,
    (CustomLayoutContext) -> Size,
    (CustomPlacementContext) -> Array[Rect],
    (Rect) -> Array[DrawCommand],
    SemanticsRole,
    String,
  ) -> Node
  priv component : ((BuildContext) -> View[Msg]) -> Node
}

///|
pub fn[Msg, Node] ViewLoweringSink::new(
  empty~ : () -> Node,
  text~ : (String?, String, Size, FontSpec, Color) -> Node,
  button~ : (
    String?,
    String,
    Size,
    FontSpec,
    Color,
    Brush,
    Brush,
    Brush,
    BorderStyle?,
    ShadowStyle?,
    Double,
    Msg?,
  ) -> Node,
  text_field~ : (
    String?,
    Binding[String],
    String,
    Size,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    Msg?,
  ) -> Node,
  controlled_text_field~ : (
    String?,
    String,
    (String) -> Msg,
    String,
    Size,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    Msg?,
  ) -> Node,
  rich_text_editor~ : (
    String?,
    Binding[String],
    String,
    Size,
    RichTextFormatter,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    ((Int, TextRange?) -> Msg)?,
    ((Int) -> Msg)?,
    ((String, Int, TextRange?, String) -> RichTextInputTransform?)?,
    Bool,
  ) -> Node,
  controlled_rich_text_editor~ : (
    String?,
    String,
    (String) -> Msg,
    String,
    Size,
    RichTextFormatter,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    ((Int, TextRange?) -> Msg)?,
    ((Int) -> Msg)?,
    ((String, Int, TextRange?, String) -> RichTextInputTransform?)?,
    Bool,
  ) -> Node,
  image~ : (String?, String, Size?, Double, Double, ImageFit) -> Node,
  checkbox~ : (String?, String, Binding[Bool], FontSpec, Color, Color, Size) -> Node,
  controlled_checkbox~ : (
    String?,
    String,
    Bool,
    (Bool) -> Msg,
    FontSpec,
    Color,
    Color,
    Size,
  ) -> Node,
  picker~ : (
    String?,
    Array[PickerItem],
    Binding[String],
    String,
    FontSpec,
    Color,
    Brush,
    Double,
    Double,
  ) -> Node,
  controlled_picker~ : (
    String?,
    Array[PickerItem],
    String,
    (String) -> Msg,
    String,
    FontSpec,
    Color,
    Brush,
    Double,
    Double,
  ) -> Node,
  datepicker~ : (
    String?,
    Binding[DateValue],
    DatePickerMode,
    String,
    FontSpec,
    Color,
    Brush,
    Double,
    DateValue?,
    DateValue?,
  ) -> Node,
  controlled_datepicker~ : (
    String?,
    DateValue,
    (DateValue) -> Msg,
    DatePickerMode,
    String,
    FontSpec,
    Color,
    Brush,
    Double,
    DateValue?,
    DateValue?,
  ) -> Node,
  search_bar~ : (
    String?,
    Binding[String],
    String,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    Msg?,
    Msg?,
  ) -> Node,
  controlled_search_bar~ : (
    String?,
    String,
    (String) -> Msg,
    String,
    FontSpec,
    Color,
    Color,
    Brush,
    BorderStyle?,
    BorderStyle?,
    Color,
    Double,
    Msg?,
    Msg?,
  ) -> Node,
  web_view~ : (String?, WebViewSpec, ((WebViewEvent) -> Msg)?) -> Node,
  sheet~ : (
    String?,
    Node,
    SheetPresentationMode,
    Brush,
    Double,
    ShadowStyle?,
    Msg?,
  ) -> Node,
  flex~ : (
    String?,
    Axis,
    Double,
    MainAxisAlignment,
    CrossAxisAlignment,
    Array[Node],
  ) -> Node,
  padding~ : (String?, Insets, Node) -> Node,
  container~ : (
    String?,
    Size?,
    Brush?,
    BorderStyle?,
    Double,
    ShadowStyle?,
    Node?,
  ) -> Node,
  spacer~ : (String?, Double, Double) -> Node,
  frame~ : (String?, Double?, Double?, Double?, Double?, Double?, Double?, Node) -> Node,
  stack~ : (String?, Array[Node]) -> Node,
  scroll~ : (String?, Point, Size?, ScrollState?, ((Point) -> Msg)?, Node) -> Node,
  grid~ : (String?, Int, Double, Double, Array[Node]) -> Node,
  list~ : (String?, Double, Array[Node]) -> Node,
  key~ : (String, Node) -> Node,
  padding_modifier~ : (Insets, Node) -> Node,
  frame_modifier~ : (Double?, Double?, Double?, Double?, Double?, Double?, Node) -> Node,
  background_modifier~ : (Brush, Node) -> Node,
  foreground_modifier~ : (Color, Node) -> Node,
  font_modifier~ : (FontSpec, Node) -> Node,
  corner_radius_modifier~ : (Double, Node) -> Node,
  opacity_modifier~ : (Double, Node) -> Node,
  shadow_modifier~ : (ShadowStyle, Node) -> Node,
  border_modifier~ : (BorderStyle, Node) -> Node,
  offset_modifier~ : (Double, Double, Node) -> Node,
  clip_modifier~ : (Node) -> Node,
  scale_modifier~ : (Double, Double, Node) -> Node,
  disabled_modifier~ : (Bool, Node) -> Node,
  accessibility_label_modifier~ : (String, Node) -> Node,
  semantics_role_modifier~ : (SemanticsRole, Node) -> Node,
  semantics_selected_modifier~ : (Bool, Node) -> Node,
  semantics_pressed_modifier~ : (Bool, Node) -> Node,
  semantics_checked_modifier~ : (Bool, Node) -> Node,
  semantics_expanded_modifier~ : (Bool, Node) -> Node,
  semantics_invalid_modifier~ : (Bool, Node) -> Node,
  semantics_required_modifier~ : (Bool, Node) -> Node,
  semantics_description_modifier~ : (String, Node) -> Node,
  semantics_action_modifier~ : (SemanticsAction, Node) -> Node,
  focusable_modifier~ : (Bool, Node) -> Node,
  focus_trap_modifier~ : (Bool, Node) -> Node,
  on_tap_modifier~ : (Msg, Node) -> Node,
  on_long_press_modifier~ : (Msg, Node) -> Node,
  on_double_tap_modifier~ : (Msg, Node) -> Node,
  on_drag_modifier~ : ((DragGestureEvent) -> Msg, Node) -> Node,
  on_drag_with_frame_modifier~ : ((DragGestureEvent, Rect) -> Msg, Node) -> Node,
  on_file_drop_modifier~ : ((Array[String], Point) -> Msg, Node) -> Node,
  keyboard_shortcut_modifier~ : (KeyboardShortcut, Node) -> Node,
  flexible_modifier~ : (Double, Node) -> Node,
  layout_priority_modifier~ : (Double, Node) -> Node,
  align_modifier~ : (Alignment, Node) -> Node,
  spacing_modifier~ : (Double, Node) -> Node,
  main_axis_alignment_modifier~ : (MainAxisAlignment, Node) -> Node,
  cross_axis_alignment_modifier~ : (CrossAxisAlignment, Node) -> Node,
  theme_modifier~ : (Theme, Node) -> Node,
  environment_modifier~ : (Environment, Node) -> Node,
  on_tap_handler_modifier~ : (() -> Unit, Node) -> Node,
  on_long_press_handler_modifier~ : (() -> Unit, Node) -> Node,
  on_double_tap_handler_modifier~ : (() -> Unit, Node) -> Node,
  on_drag_handler_modifier~ : ((DragGestureEvent) -> Unit, Node) -> Node,
  on_drag_with_frame_handler_modifier~ : (
    (DragGestureEvent, Rect) -> Unit,
    Node,
  ) -> Node,
  on_file_drop_handler_modifier~ : ((Array[String], Point) -> Unit, Node) -> Node,
  aspect_ratio_modifier~ : (Double, Node) -> Node,
  intrinsic_width_modifier~ : (Node) -> Node,
  intrinsic_height_modifier~ : (Node) -> Node,
  repaint_boundary_modifier~ : (Node) -> Node,
  custom~ : (
    String?,
    (Constraints) -> Size,
    (Rect) -> Array[DrawCommand],
    SemanticsRole,
    String,
  ) -> Node,
  custom_layout~ : (
    String?,
    Array[Node],
    CustomLayoutCache,
    (CustomLayoutContext) -> Size,
    (CustomPlacementContext) -> Array[Rect],
    (Rect) -> Array[DrawCommand],
    SemanticsRole,
    String,
  ) -> Node,
  component~ : ((BuildContext) -> View[Msg]) -> Node,
) -> ViewLoweringSink[Msg, Node] {
  {
    empty,
    text,
    button,
    text_field,
    controlled_text_field,
    rich_text_editor,
    controlled_rich_text_editor,
    image,
    checkbox,
    controlled_checkbox,
    picker,
    controlled_picker,
    datepicker,
    controlled_datepicker,
    search_bar,
    controlled_search_bar,
    web_view,
    sheet,
    flex,
    padding,
    container,
    spacer,
    frame,
    stack,
    scroll,
    grid,
    list,
    key,
    padding_modifier,
    frame_modifier,
    background_modifier,
    foreground_modifier,
    font_modifier,
    corner_radius_modifier,
    opacity_modifier,
    shadow_modifier,
    border_modifier,
    offset_modifier,
    clip_modifier,
    scale_modifier,
    disabled_modifier,
    accessibility_label_modifier,
    semantics_role_modifier,
    semantics_selected_modifier,
    semantics_pressed_modifier,
    semantics_checked_modifier,
    semantics_expanded_modifier,
    semantics_invalid_modifier,
    semantics_required_modifier,
    semantics_description_modifier,
    semantics_action_modifier,
    focusable_modifier,
    focus_trap_modifier,
    on_tap_modifier,
    on_long_press_modifier,
    on_double_tap_modifier,
    on_drag_modifier,
    on_drag_with_frame_modifier,
    on_file_drop_modifier,
    keyboard_shortcut_modifier,
    flexible_modifier,
    layout_priority_modifier,
    align_modifier,
    spacing_modifier,
    main_axis_alignment_modifier,
    cross_axis_alignment_modifier,
    theme_modifier,
    environment_modifier,
    on_tap_handler_modifier,
    on_long_press_handler_modifier,
    on_double_tap_handler_modifier,
    on_drag_handler_modifier,
    on_drag_with_frame_handler_modifier,
    on_file_drop_handler_modifier,
    aspect_ratio_modifier,
    intrinsic_width_modifier,
    intrinsic_height_modifier,
    repaint_boundary_modifier,
    custom,
    custom_layout,
    component,
  }
}

///|
pub fn[Msg, Node] View::lower_for_runtime(
  self : View[Msg],
  sink : ViewLoweringSink[Msg, Node],
) -> Node {
  lower_view_node_for_runtime(self.node, sink)
}

///|
fn key_string(key : Key?) -> String? {
  match key {
    Some(key) => Some(key.value)
    None => None
  }
}

///|
fn[Msg, Node] lower_view_node_for_runtime(
  node : ViewNode[Msg],
  sink : ViewLoweringSink[Msg, Node],
) -> Node {
  match node {
    EmptyNode => (sink.empty)()
    TextNode(data) =>
      (sink.text)(
        key_string(data.key),
        data.text,
        data.size,
        data.font,
        data.color,
      )
    ButtonNode(data, message) =>
      (sink.button)(
        key_string(data.key),
        data.text,
        data.size,
        data.font,
        data.foreground,
        data.background,
        data.hovered_background,
        data.pressed_background,
        data.border,
        data.shadow,
        data.corner_radius,
        message,
      )
    TextFieldNode(data, message) =>
      (sink.text_field)(
        key_string(data.key),
        data.value,
        data.placeholder,
        data.size,
        data.font,
        data.foreground,
        data.placeholder_color,
        data.background,
        data.border,
        data.focused_border,
        data.cursor_color,
        data.corner_radius,
        message,
      )
    ControlledTextFieldNode(data) =>
      (sink.controlled_text_field)(
        key_string(data.key),
        data.value,
        data.on_input,
        data.placeholder,
        data.size,
        data.font,
        data.foreground,
        data.placeholder_color,
        data.background,
        data.border,
        data.focused_border,
        data.cursor_color,
        data.corner_radius,
        data.on_submit,
      )
    RichTextEditorNode(data, selection, prefix) =>
      (sink.rich_text_editor)(
        key_string(data.key),
        data.value,
        data.placeholder,
        data.size,
        data.format,
        data.font,
        data.foreground,
        data.placeholder_color,
        data.background,
        data.border,
        data.focused_border,
        data.cursor_color,
        data.corner_radius,
        selection,
        prefix,
        data.input_transform,
        data.accepts_tab_input,
      )
    ControlledRichTextEditorNode(data) =>
      (sink.controlled_rich_text_editor)(
        key_string(data.key),
        data.value,
        data.on_input,
        data.placeholder,
        data.size,
        data.format,
        data.font,
        data.foreground,
        data.placeholder_color,
        data.background,
        data.border,
        data.focused_border,
        data.cursor_color,
        data.corner_radius,
        data.on_selection_change,
        data.on_prefix_click,
        data.input_transform,
        data.accepts_tab_input,
      )
    ImageNode(data) =>
      (sink.image)(
        key_string(data.key),
        data.source,
        data.size,
        data.opacity,
        data.corner_radius,
        data.fit,
      )
    CheckboxNode(data) =>
      (sink.checkbox)(
        key_string(data.key),
        data.label,
        data.checked,
        data.font,
        data.foreground,
        data.check_color,
        data.size,
      )
    ControlledCheckboxNode(data) =>
      (sink.controlled_checkbox)(
        key_string(data.key),
        data.label,
        data.checked,
        data.on_change,
        data.font,
        data.foreground,
        data.check_color,
        data.size,
      )
    PickerNode(data) =>
      (sink.picker)(
        key_string(data.key),
        data.items,
        data.selected,
        data.placeholder,
        data.font,
        data.foreground,
        data.background,
        data.cornerRadius,
        data.maxHeight,
      )
    ControlledPickerNode(data) =>
      (sink.controlled_picker)(
        key_string(data.key),
        data.items,
        data.selected,
        data.on_select,
        data.placeholder,
        data.font,
        data.foreground,
        data.background,
        data.cornerRadius,
        data.maxHeight,
      )
    DatePickerNode(data) =>
      (sink.datepicker)(
        key_string(data.key),
        data.selected,
        data.mode,
        data.placeholder,
        data.font,
        data.foreground,
        data.background,
        data.corner_radius,
        data.min_date,
        data.max_date,
      )
    ControlledDatePickerNode(data) =>
      (sink.controlled_datepicker)(
        key_string(data.key),
        data.selected,
        data.on_select,
        data.mode,
        data.placeholder,
        data.font,
        data.foreground,
        data.background,
        data.corner_radius,
        data.min_date,
        data.max_date,
      )
    SearchBarNode(data, submit, clear) =>
      (sink.search_bar)(
        key_string(data.key),
        data.query,
        data.placeholder,
        data.font,
        data.foreground,
        data.placeholder_color,
        data.background,
        data.border,
        data.focused_border,
        data.cursor_color,
        data.corner_radius,
        submit,
        clear,
      )
    ControlledSearchBarNode(data) =>
      (sink.controlled_search_bar)(
        key_string(data.key),
        data.query,
        data.on_input,
        data.placeholder,
        data.font,
        data.foreground,
        data.placeholder_color,
        data.background,
        data.border,
        data.focused_border,
        data.cursor_color,
        data.corner_radius,
        data.on_submit,
        data.on_clear,
      )
    WebViewNode(data, event_handler) =>
      (sink.web_view)(key_string(data.key), data, event_handler)
    SheetNode(data, content, dismiss) =>
      (sink.sheet)(
        key_string(data.key),
        lower_view_node_for_runtime(content, sink),
        data.presentation_mode,
        data.background,
        data.corner_radius,
        data.shadow,
        dismiss,
      )
    FlexNode(data, children) =>
      (sink.flex)(
        key_string(data.key),
        data.axis,
        data.spacing,
        data.main_axis_alignment,
        data.cross_axis_alignment,
        children.map(child => lower_view_node_for_runtime(child, sink)),
      )
    PaddingNode(data, child) =>
      (sink.padding)(
        key_string(data.key),
        data.insets,
        lower_view_node_for_runtime(child, sink),
      )
    ContainerNode(data, child) =>
      (sink.container)(
        key_string(data.key),
        data.size,
        data.background,
        data.border,
        data.corner_radius,
        data.shadow,
        match child {
          Some(child) => Some(lower_view_node_for_runtime(child, sink))
          None => None
        },
      )
    SpacerNode(data) =>
      (sink.spacer)(key_string(data.key), data.min_length, data.weight)
    FrameNode(data, child) =>
      (sink.frame)(
        key_string(data.key),
        data.width,
        data.height,
        data.min_width,
        data.min_height,
        data.max_width,
        data.max_height,
        lower_view_node_for_runtime(child, sink),
      )
    StackNode(data, children) =>
      (sink.stack)(
        key_string(data.key),
        children.map(child => lower_view_node_for_runtime(child, sink)),
      )
    ScrollNode(data, child, state, scroll) =>
      (sink.scroll)(
        key_string(data.key),
        data.offset,
        data.viewport,
        state,
        scroll,
        lower_view_node_for_runtime(child, sink),
      )
    GridNode(data, children) =>
      (sink.grid)(
        key_string(data.key),
        data.columns,
        data.row_spacing,
        data.column_spacing,
        children.map(child => lower_view_node_for_runtime(child, sink)),
      )
    ListNode(data, children) =>
      (sink.list)(
        key_string(data.key),
        data.spacing,
        children.map(child => lower_view_node_for_runtime(child, sink)),
      )
    ModifiedNode(modifier, child) =>
      lower_modifier_for_runtime(
        modifier,
        lower_view_node_for_runtime(child, sink),
        sink,
      )
    CustomNode(data) =>
      (sink.custom)(
        key_string(data.key),
        data.measure,
        data.paint,
        data.semantics_role,
        data.semantics_label,
      )
    CustomLayoutNode(data, children) =>
      (sink.custom_layout)(
        key_string(data.key),
        children.map(child => lower_view_node_for_runtime(child, sink)),
        data.cache,
        data.measure,
        data.place,
        data.paint,
        data.semantics_role,
        data.semantics_label,
      )
    ComponentNode(build) => (sink.component)(build)
  }
}

///|
fn[Msg, Node] lower_modifier_for_runtime(
  modifier : ViewModifierNode[Msg],
  child : Node,
  sink : ViewLoweringSink[Msg, Node],
) -> Node {
  match modifier {
    KeyModifierNode(key) => (sink.key)(key.value, child)
    PlainModifier(modifier) =>
      lower_plain_modifier_for_runtime(modifier, child, sink)
    TapModifier(message) => (sink.on_tap_modifier)(message, child)
    LongPressModifier(message) => (sink.on_long_press_modifier)(message, child)
    DoubleTapModifier(message) => (sink.on_double_tap_modifier)(message, child)
    DragModifier(handler) => (sink.on_drag_modifier)(handler, child)
    DragWithFrameModifier(handler) =>
      (sink.on_drag_with_frame_modifier)(handler, child)
    FileDropModifier(handler) => (sink.on_file_drop_modifier)(handler, child)
  }
}

///|
fn[Msg, Node] lower_plain_modifier_for_runtime(
  modifier : ViewModifier,
  child : Node,
  sink : ViewLoweringSink[Msg, Node],
) -> Node {
  match modifier {
    PaddingModifier(insets) => (sink.padding_modifier)(insets, child)
    FrameModifier(data) =>
      (sink.frame_modifier)(
        data.width,
        data.height,
        data.min_width,
        data.min_height,
        data.max_width,
        data.max_height,
        child,
      )
    BackgroundModifier(brush) => (sink.background_modifier)(brush, child)
    ForegroundModifier(color) => (sink.foreground_modifier)(color, child)
    FontModifier(font) => (sink.font_modifier)(font, child)
    CornerRadiusModifier(radius) => (sink.corner_radius_modifier)(radius, child)
    OpacityModifier(opacity) => (sink.opacity_modifier)(opacity, child)
    ShadowModifier(style) => (sink.shadow_modifier)(style, child)
    BorderModifier(style) => (sink.border_modifier)(style, child)
    OffsetModifier(dx, dy) => (sink.offset_modifier)(dx, dy, child)
    ClipModifier => (sink.clip_modifier)(child)
    ScaleModifier(sx, sy) => (sink.scale_modifier)(sx, sy, child)
    DisabledModifier(disabled) => (sink.disabled_modifier)(disabled, child)
    AccessibilityLabelModifier(label) =>
      (sink.accessibility_label_modifier)(label, child)
    SemanticsRoleModifier(role) => (sink.semantics_role_modifier)(role, child)
    SemanticsSelectedModifier(selected) =>
      (sink.semantics_selected_modifier)(selected, child)
    SemanticsPressedModifier(pressed) =>
      (sink.semantics_pressed_modifier)(pressed, child)
    SemanticsCheckedModifier(checked) =>
      (sink.semantics_checked_modifier)(checked, child)
    SemanticsExpandedModifier(expanded) =>
      (sink.semantics_expanded_modifier)(expanded, child)
    SemanticsInvalidModifier(invalid) =>
      (sink.semantics_invalid_modifier)(invalid, child)
    SemanticsRequiredModifier(required) =>
      (sink.semantics_required_modifier)(required, child)
    SemanticsDescriptionModifier(description) =>
      (sink.semantics_description_modifier)(description, child)
    SemanticsActionModifier(action) =>
      (sink.semantics_action_modifier)(action, child)
    FocusableModifier(focusable) => (sink.focusable_modifier)(focusable, child)
    FocusTrapModifier(enabled) => (sink.focus_trap_modifier)(enabled, child)
    OnTapModifier(handler) => (sink.on_tap_handler_modifier)(handler, child)
    OnLongPressModifier(handler) =>
      (sink.on_long_press_handler_modifier)(handler, child)
    OnDoubleTapModifier(handler) =>
      (sink.on_double_tap_handler_modifier)(handler, child)
    OnDragModifier(handler) => (sink.on_drag_handler_modifier)(handler, child)
    OnDragWithFrameModifier(handler) =>
      (sink.on_drag_with_frame_handler_modifier)(handler, child)
    OnFileDropModifier(handler) =>
      (sink.on_file_drop_handler_modifier)(handler, child)
    KeyboardShortcutModifier(shortcut) =>
      (sink.keyboard_shortcut_modifier)(shortcut, child)
    FlexibleModifier(weight) => (sink.flexible_modifier)(weight, child)
    LayoutPriorityModifier(priority) =>
      (sink.layout_priority_modifier)(priority, child)
    AlignModifier(alignment) => (sink.align_modifier)(alignment, child)
    SpacingModifier(spacing) => (sink.spacing_modifier)(spacing, child)
    MainAxisAlignmentModifier(alignment) =>
      (sink.main_axis_alignment_modifier)(alignment, child)
    CrossAxisAlignmentModifier(alignment) =>
      (sink.cross_axis_alignment_modifier)(alignment, child)
    ThemeModifier(theme) => (sink.theme_modifier)(theme, child)
    EnvironmentModifier(environment) =>
      (sink.environment_modifier)(environment, child)
    AspectRatioModifier(ratio) => (sink.aspect_ratio_modifier)(ratio, child)
    IntrinsicWidthModifier => (sink.intrinsic_width_modifier)(child)
    IntrinsicHeightModifier => (sink.intrinsic_height_modifier)(child)
    RepaintBoundaryModifier => (sink.repaint_boundary_modifier)(child)
  }
}
