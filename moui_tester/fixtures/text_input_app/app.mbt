///|
using @views {column, text, text_field}

///|
pub(all) struct TextInputSmokeModel {
  value : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum TextInputSmokeMsg {
  ValueChanged(String)
} derive(Eq, Debug, ToJson)

///|
pub fn TextInputSmokeModel::new(value? : String = "") -> TextInputSmokeModel {
  { value, }
}

///|
pub fn update(
  _model : TextInputSmokeModel,
  msg : TextInputSmokeMsg,
) -> TextInputSmokeModel {
  match msg {
    ValueChanged(value) => { value, }
  }
}

///|
pub fn view(model : TextInputSmokeModel) -> @core.View[TextInputSmokeMsg] {
  let theme = @core.Theme::default()
  column(
    [
      text(
        "MoUI Text Input Smoke",
        role=@views.TextRole::Title,
        theme~,
        width=420.0,
        height=34.0,
      ),
      text_field(
        model.value,
        on_input=value => ValueChanged(value),
        placeholder="Type here",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width=420.0,
        height=42.0,
      ),
    ],
    spacing=12.0,
  )
}

///|
pub fn runtime(
  width? : Double = 520.0,
  height? : Double = 180.0,
) -> @runtime.AppRuntime {
  @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init=TextInputSmokeModel::new(),
      update~,
      view~,
    ),
    size=@core.Size::new(width~, height~),
  )
}
