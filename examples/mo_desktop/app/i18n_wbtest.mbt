///|
test "system menu carries the language toggle row" {
  let model = DesktopModel::new().update(SetLanguage(ChineseLanguage))
  let items = menu_bar_items(model, SystemMenu, model.language)
  let labels = items.map(item => item.label)
  // The toggle shows the TARGET language name; other rows localize.
  inspect(labels.contains("English"), content="true")
  inspect(labels.contains("退出登录"), content="true")
  inspect(labels.contains("关于本机"), content="true")
  // English mode offers 中文 as the target.
  let en = menu_bar_items(
    model.update(SetLanguage(EnglishLanguage)),
    SystemMenu,
    EnglishLanguage,
  )
  let en_labels = en.map(item => item.label)
  inspect(en_labels.contains("中文"), content="true")
  inspect(en_labels.contains("Log Out"), content="true")
}

///|
test "unlocked desktop renders the localized menu bar" {
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(SetLanguage(ChineseLanguage))
  let size = @geometry.Size::new(width=1280.0, height=800.0)
  let env = @core.ViewEnvironment::new(
    viewport_size=size,
    environment=@core.Environment::neutral(),
  )
  let root = view(model, env)
  let runtime = @runtime.new_view(root~, size~)
  let commands = runtime.draw_commands()
  let mut file_menu = false
  let mut window_menu = false
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, .. }) =>
        if value == "文件" {
          file_menu = true
        } else if value == "窗口" {
          window_menu = true
        }
      _ => ()
    }
  }
  assert_true(file_menu)
  assert_true(window_menu)
}
