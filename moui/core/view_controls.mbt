///|
priv struct ControlledTextFieldViewData[Msg] {
  key : Key?
  value : String
  placeholder : String
  size : Size
  font : FontSpec
  foreground : Color
  placeholder_color : Color
  background : Brush
  border : BorderStyle?
  focused_border : BorderStyle?
  cursor_color : Color
  corner_radius : Double
  on_input : (String) -> Msg
  on_submit : Msg?
}

///|
priv struct ControlledRichTextEditorViewData[Msg] {
  key : Key?
  value : String
  placeholder : String
  size : Size
  format : RichTextFormatter
  font : FontSpec
  foreground : Color
  placeholder_color : Color
  background : Brush
  border : BorderStyle?
  focused_border : BorderStyle?
  cursor_color : Color
  corner_radius : Double
  on_input : (String) -> Msg
  on_selection_change : ((Int, TextRange?) -> Msg)?
  on_prefix_click : ((Int) -> Msg)?
  input_transform : ((String, Int, TextRange?, String) -> RichTextInputTransform?)?
  accepts_tab_input : Bool
}

///|
priv struct ControlledCheckboxViewData[Msg] {
  key : Key?
  label : String
  checked : Bool
  font : FontSpec
  foreground : Color
  check_color : Color
  size : Size
  on_change : (Bool) -> Msg
}

///|
priv struct ControlledPickerViewData[Msg] {
  key : Key?
  items : Array[PickerItem]
  selected : String
  placeholder : String
  font : FontSpec
  foreground : Color
  background : Brush
  cornerRadius : Double
  maxHeight : Double
  on_select : (String) -> Msg
}

///|
priv struct ControlledDatePickerViewData[Msg] {
  key : Key?
  selected : DateValue
  mode : DatePickerMode
  placeholder : String
  font : FontSpec
  foreground : Color
  background : Brush
  corner_radius : Double
  min_date : DateValue?
  max_date : DateValue?
  on_select : (DateValue) -> Msg
}

///|
priv struct ControlledSearchBarViewData[Msg] {
  key : Key?
  query : String
  placeholder : String
  font : FontSpec
  foreground : Color
  placeholder_color : Color
  background : Brush
  border : BorderStyle?
  focused_border : BorderStyle?
  cursor_color : Color
  corner_radius : Double
  on_input : (String) -> Msg
  on_submit : Msg?
  on_clear : Msg?
}

///|
pub fn[Msg] View::primitive_checkbox_view(
  label~ : String,
  checked~ : Binding[Bool],
  font~ : FontSpec,
  foreground~ : Color,
  check_color~ : Color,
  size~ : Size,
) -> View[Msg] {
  view_from_node(
    CheckboxNode({
      key: None,
      label,
      checked,
      font,
      foreground,
      check_color,
      size,
    }),
  )
}

///|
pub fn[Msg] View::primitive_controlled_checkbox_view(
  label~ : String,
  checked~ : Bool,
  on_change~ : (Bool) -> Msg,
  font~ : FontSpec,
  foreground~ : Color,
  check_color~ : Color,
  size~ : Size,
) -> View[Msg] {
  view_from_node(
    ControlledCheckboxNode({
      key: None,
      label,
      checked,
      font,
      foreground,
      check_color,
      size,
      on_change,
    }),
  )
}

///|
pub fn[Msg] View::primitive_text_field_view(
  value~ : Binding[String],
  placeholder~ : String,
  size~ : Size,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius? : Double = 0.0,
  on_submit? : Msg? = None,
) -> View[Msg] {
  view_from_node(
    TextFieldNode(
      {
        key: None,
        value,
        placeholder,
        size,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        on_submit: None,
      },
      on_submit,
    ),
  )
}

///|
pub fn[Msg] View::primitive_controlled_text_field_view(
  value~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  size~ : Size,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius? : Double = 0.0,
  on_submit? : Msg? = None,
) -> View[Msg] {
  view_from_node(
    ControlledTextFieldNode({
      key: None,
      value,
      placeholder,
      size,
      font,
      foreground,
      placeholder_color,
      background,
      border,
      focused_border,
      cursor_color,
      corner_radius,
      on_input,
      on_submit,
    }),
  )
}

///|
pub fn[Msg] View::primitive_rich_text_editor_view(
  value~ : Binding[String],
  placeholder~ : String,
  size~ : Size,
  format~ : RichTextFormatter,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius? : Double = 0.0,
  on_selection_change? : ((Int, TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
) -> View[Msg] {
  view_from_node(
    RichTextEditorNode(
      {
        key: None,
        value,
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
        on_selection_change: None,
        on_prefix_click: None,
        input_transform,
        accepts_tab_input,
      },
      on_selection_change,
      on_prefix_click,
    ),
  )
}

///|
pub fn[Msg] View::primitive_controlled_rich_text_editor_view(
  value~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  size~ : Size,
  format~ : RichTextFormatter,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius? : Double = 0.0,
  on_selection_change? : ((Int, TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
) -> View[Msg] {
  view_from_node(
    ControlledRichTextEditorNode({
      key: None,
      value,
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
      on_input,
      on_selection_change,
      on_prefix_click,
      input_transform,
      accepts_tab_input,
    }),
  )
}

///|
pub fn[Msg] View::primitive_picker_view(
  items~ : Array[PickerItem],
  selected~ : Binding[String],
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  background~ : Brush,
  corner_radius~ : Double,
  max_height~ : Double,
) -> View[Msg] {
  view_from_node(
    PickerNode({
      key: None,
      items,
      selected,
      placeholder,
      font,
      foreground,
      background,
      cornerRadius: corner_radius,
      maxHeight: max_height,
    }),
  )
}

///|
pub fn[Msg] View::primitive_controlled_picker_view(
  items~ : Array[PickerItem],
  selected~ : String,
  on_select~ : (String) -> Msg,
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  background~ : Brush,
  corner_radius~ : Double,
  max_height~ : Double,
) -> View[Msg] {
  view_from_node(
    ControlledPickerNode({
      key: None,
      items,
      selected,
      placeholder,
      font,
      foreground,
      background,
      cornerRadius: corner_radius,
      maxHeight: max_height,
      on_select,
    }),
  )
}

///|
pub fn[Msg] View::primitive_datepicker_view(
  selected~ : Binding[DateValue],
  mode~ : DatePickerMode,
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  background~ : Brush,
  corner_radius~ : Double,
  min_date? : DateValue? = None,
  max_date? : DateValue? = None,
) -> View[Msg] {
  view_from_node(
    DatePickerNode({
      key: None,
      selected,
      mode,
      placeholder,
      font,
      foreground,
      background,
      corner_radius,
      min_date,
      max_date,
    }),
  )
}

///|
pub fn[Msg] View::primitive_controlled_datepicker_view(
  selected~ : DateValue,
  on_select~ : (DateValue) -> Msg,
  mode~ : DatePickerMode,
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  background~ : Brush,
  corner_radius~ : Double,
  min_date? : DateValue? = None,
  max_date? : DateValue? = None,
) -> View[Msg] {
  view_from_node(
    ControlledDatePickerNode({
      key: None,
      selected,
      mode,
      placeholder,
      font,
      foreground,
      background,
      corner_radius,
      min_date,
      max_date,
      on_select,
    }),
  )
}

///|
pub fn[Msg] View::primitive_search_bar_view(
  query~ : Binding[String],
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius~ : Double,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
) -> View[Msg] {
  view_from_node(
    SearchBarNode(
      {
        key: None,
        query,
        placeholder,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        on_submit: None,
        on_clear: None,
      },
      on_submit,
      on_clear,
    ),
  )
}

///|
pub fn[Msg] View::primitive_controlled_search_bar_view(
  query~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  font~ : FontSpec,
  foreground~ : Color,
  placeholder_color~ : Color,
  background~ : Brush,
  border? : BorderStyle? = None,
  focused_border? : BorderStyle? = None,
  cursor_color~ : Color,
  corner_radius~ : Double,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
) -> View[Msg] {
  view_from_node(
    ControlledSearchBarNode({
      key: None,
      query,
      placeholder,
      font,
      foreground,
      placeholder_color,
      background,
      border,
      focused_border,
      cursor_color,
      corner_radius,
      on_input,
      on_submit,
      on_clear,
    }),
  )
}
