///|
test "controls can consume neutral core style contracts" {
  let button_bg = @core.Color::rgba(r=0.72, g=0.12, b=0.36)
  let field_bg = @core.Color::rgba(r=0.10, g=0.18, b=0.26)
  let rich_field_bg = @core.Color::rgba(r=0.12, g=0.20, b=0.34)
  let progress_fg = @core.Color::rgba(r=0.18, g=0.64, b=0.38)
  let slider_thumb = @core.Color::rgba(r=0.96, g=0.68, b=0.20)
  let picker_bg = @core.Color::rgba(r=0.18, g=0.12, b=0.30)
  let date_bg = @core.Color::rgba(r=0.14, g=0.24, b=0.20)
  let button_state : @core.ControlStateStyle = {
    foreground: @core.Color::white(),
    background: @core.Brush::solid(button_bg),
    border: None,
    radius: 14.0,
    shadow: None,
  }
  let button_style : @core.ButtonStyle = {
    normal: button_state,
    hovered: button_state,
    pressed: button_state,
    disabled: button_state,
  }
  let field_state : @core.ControlStateStyle = {
    foreground: @core.Color::white(),
    background: @core.Brush::solid(field_bg),
    border: None,
    radius: 10.0,
    shadow: None,
  }
  let field_style : @core.TextFieldStyle = {
    normal: field_state,
    focused: field_state,
    disabled: field_state,
    placeholder_color: @core.Color::gray(),
    cursor_color: progress_fg,
    font: @core.FontSpec::new(size=15.0, weight=500),
  }
  let rich_field_state = {
    ..field_state,
    background: @core.Brush::solid(rich_field_bg),
  }
  let rich_field_style = {
    ..field_style,
    normal: rich_field_state,
    focused: rich_field_state,
    disabled: rich_field_state,
  }
  let progress_style : @core.ProgressStyle = {
    foreground: progress_fg,
    background: @core.Color::rgba(r=0.07, g=0.09, b=0.12),
    radius: 6.0,
  }
  let slider_style : @core.SliderStyle = {
    foreground: progress_fg,
    background: @core.Color::rgba(r=0.12, g=0.14, b=0.18),
    thumb_color: slider_thumb,
    track_height: 7.0,
    thumb_size: 18.0,
    radius: 9.0,
  }
  let picker_style : @core.PickerStyle = {
    font: @core.FontSpec::new(size=14.0, weight=600),
    foreground: @core.Color::white(),
    background: @core.Brush::solid(picker_bg),
    radius: 12.0,
    popup_max_height: 180.0,
  }
  let date_style = { ..picker_style, background: @core.Brush::solid(date_bg) }
  let items = [
    @views.picker_item("material", "Material"),
    @views.picker_item("carbon", "Carbon"),
  ]
  let runtime = test_runtime(
    @views.column([
      @views.button("Styled", on_click=(), style=button_style, width=120.0),
      @views.text_field(
        "tokens",
        on_input=_value => (),
        placeholder="Styled field",
        style=field_style,
      ),
      @views.rich_text_editor(
        "rich tokens",
        value => {
          @core.RichTextDocument::new(blocks=[
            @core.RichTextBlock::new(runs=[@core.RichTextRun::new(text=value)]),
          ])
        },
        on_input=_value => (),
        placeholder="Styled editor",
        style=rich_field_style,
        width=180.0,
        height=60.0,
      ),
      @views.progress(0.5, style=progress_style, width=160.0),
      @views.slider(0.5, style=slider_style, width=160.0),
      @views.picker(
        items,
        selected="material",
        on_select=_value => (),
        style=picker_style,
      ),
      @views.datepicker(
        selected=@core.DateValue::new(year=2026, month=6, day=10),
        on_select=_value => (),
        style=date_style,
      ),
    ]),
  )
  let draw = runtime.draw_commands()
  assert_true(has_solid_fill(draw, button_bg))
  assert_true(has_solid_fill(draw, field_bg))
  assert_true(has_solid_fill(draw, rich_field_bg))
  assert_true(has_solid_fill(draw, progress_fg))
  assert_true(has_solid_fill(draw, slider_thumb))
  assert_true(has_solid_fill(draw, picker_bg))
  assert_true(has_solid_fill(draw, date_bg))
}
