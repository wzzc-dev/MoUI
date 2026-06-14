///|
fn test_label(text : String, key? : String) -> ViewSpec {
  let spec = ViewSpec::TextSpec({
    key: None,
    text,
    size: Size::new(width=80.0, height=20.0),
    font: FontSpec::new(size=16.0, weight=500),
    color: Color::black(),
  })
  match key {
    Some(key) => spec.key(key)
    None => spec
  }
}

///|
fn test_text_field(
  value : Binding[String],
  on_submit? : (() -> Unit)? = None,
) -> ViewSpec {
  ViewSpec::TextFieldSpec({
    key: None,
    value,
    placeholder: "Type",
    size: Size::new(width=120.0, height=40.0),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: Some(BorderStyle::new(brush=Brush::solid(Color::gray()), width=1.0)),
    focused_border: Some(
      BorderStyle::new(brush=Brush::solid(Color::blue()), width=2.0),
    ),
    cursor_color: Color::blue(),
    corner_radius: 0.0,
    on_submit,
  })
}

///|
fn test_tab_accepting_rich_text_editor(value : Binding[String]) -> ViewSpec {
  ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder: "Write",
    size: Size::new(width=160.0, height=80.0),
    format: value => RichTextDocument::plain(value),
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: None,
    focused_border: None,
    cursor_color: Color::blue(),
    corner_radius: 0.0,
    on_selection_change: None,
    on_prefix_click: None,
    input_transform: None,
    accepts_tab_input: true,
  })
}

///|
fn[Msg] runtime_test_label(text : String) -> View[Msg] {
  View::text(
    text~,
    size=Size::new(width=320.0, height=24.0),
    font=FontSpec::new(size=14.0),
    color=Color::black(),
  )
}
