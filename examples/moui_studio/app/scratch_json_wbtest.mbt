///|
/// 临时实证:DrawCommand JSON 形态(用完即删)。
test "scratch: draw command json" {
  let model = initial_model()
  let program : @core.Program[Model, Msg] = @moui.Program::new_with_environment(
    init=() => (model, @moui.Effect::none()),
    update=(current, msg) => update_pure(current, msg),
    view=(current, env) => view_with_viewport(current, env.viewport_size()),
  )
  let runtime = @runtime.new_program_with_dimensions(
    program~,
    width=400.0,
    height=300.0,
  )
  let commands = runtime.draw_commands()
  let mut shown = 0
  for command in commands {
    let text = command.to_json().stringify()
    if text.contains("DrawText") ||
      text.contains("PushClip") ||
      text.contains("PushTransform") ||
      text.contains("PushOpacity") ||
      text.contains("RetainedLayer") ||
      text.contains("PushLayer") {
      println(text)
      shown = shown + 1
      if shown >= 3 {
        break
      }
    }
  }
  assert_true(shown > 0, msg="应找到文本或状态类命令")
}
