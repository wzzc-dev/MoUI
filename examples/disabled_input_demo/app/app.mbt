///|
/// Interactive + headless demo for the disabled-control input contract:
/// every control below is wrapped in `.disabled(disabled=!model.enabled)`.
/// Clicking a disabled control must leave every counter at zero; enabling
/// them must make the same clicks increment the counters.
pub struct Model {
  enabled : Bool
  button_clicks : Int32
  checkbox_changes : Int32
  toggle_changes : Int32
  radio_changes : Int32
  slider_changes : Int32
  checked : Bool
  toggled : Bool
  radio_selected : Bool
  slider_value : Double
}

///|
pub(all) enum Msg {
  ToggleEnabled
  Reset
  ButtonClicked
  CheckboxChanged(Bool)
  ToggleChanged(Bool)
  RadioChanged(Bool)
  SliderChanged(Double)
}

///|
pub fn Model::new() -> Model {
  {
    enabled: false,
    button_clicks: 0,
    checkbox_changes: 0,
    toggle_changes: 0,
    radio_changes: 0,
    slider_changes: 0,
    checked: false,
    toggled: false,
    radio_selected: false,
    slider_value: 0.5,
  }
}

///|
pub fn Model::with_enabled(enabled : Bool) -> Model {
  { ..Model::new(), enabled, }
}

///|
pub fn update(model : Model, message : Msg) -> Model {
  match message {
    ToggleEnabled => { ..model, enabled: !model.enabled }
    Reset =>
      {
        ..model,
        button_clicks: 0,
        checkbox_changes: 0,
        toggle_changes: 0,
        radio_changes: 0,
        slider_changes: 0,
      }
    ButtonClicked => { ..model, button_clicks: model.button_clicks + 1 }
    CheckboxChanged(value) =>
      {
        ..model,
        checked: value,
        checkbox_changes: model.checkbox_changes + 1,
      }
    ToggleChanged(value) =>
      {
        ..model,
        toggled: value,
        toggle_changes: model.toggle_changes + 1,
      }
    RadioChanged(value) =>
      {
        ..model,
        radio_selected: value,
        radio_changes: model.radio_changes + 1,
      }
    SliderChanged(value) =>
      {
        ..model,
        slider_value: value,
        slider_changes: model.slider_changes + 1,
      }
  }
}

///|
/// The five controls in a fixed column. The self-test clicks the centers of
/// the fixed 240x40 frames; the interactive view embeds the same column.
pub fn probe_view(model : Model) -> @moui.View[Msg] {
  @views.column(
    [
      @views.button("Click me", on_click=ButtonClicked).disabled(disabled=!model.enabled).frame(
        width=240.0,
        height=40.0,
      ).key("demo-button"),
      @views.checkbox("Checkbox", checked=model.checked, on_change=value => CheckboxChanged(value)).disabled(
        disabled=!model.enabled,
      ).frame(width=240.0, height=40.0).key("demo-checkbox"),
      @views.toggle("Toggle", model.toggled, on_change=value => ToggleChanged(value)).disabled(
        disabled=!model.enabled,
      ).frame(width=240.0, height=40.0).key("demo-toggle"),
      @views.radio("Radio", model.radio_selected, on_change=value => RadioChanged(value)).disabled(
        disabled=!model.enabled,
      ).frame(width=240.0, height=40.0).key("demo-radio"),
      @views.slider(
        model.slider_value,
        min=0.0,
        max=1.0,
        on_change=Some(value => SliderChanged(value)),
        width=240.0,
        height=40.0,
      ).disabled(disabled=!model.enabled).frame(width=240.0, height=40.0).key("demo-slider"),
    ],
    spacing=0.0,
  )
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  @views.center(
    @views.card(
      @views.column(
        [
          @views.text("Disabled input demo").title(),
          @views.text(
            "Controls are \{if model.enabled { "enabled" } else { "disabled" }}. Disabled clicks must not change counters.",
          ),
          @views.row([
            @views.button(
              if model.enabled { "Disable controls" } else { "Enable controls" },
              on_click=ToggleEnabled,
            ),
            @views.button("Reset counters", on_click=Reset),
          ]),
          @views.text(
            "btn=\{model.button_clicks} chk=\{model.checkbox_changes} tog=\{model.toggle_changes} rad=\{model.radio_changes} sld=\{model.slider_changes}",
          ),
          probe_view(model),
        ],
        spacing=12.0,
        align=@views.CrossAlign::Start,
      ),
    ),
  )
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new(), update~, view~)
}
