///|
pub fn settings_action_command() -> @views.ActionCommand {
  @views.ActionCommand::new(
    intent=@views.CommandIntent::Activate,
    label="Settings\u{2026}",
    shortcut=Some(
      @views.KeyboardShortcut::new(
        key=",",
        modifiers=@views.KeyModifiers::new(meta=true),
      ),
    ),
  )
}

///|
pub fn switch_site_action_command() -> @views.ActionCommand {
  @views.ActionCommand::new(
    intent=@views.CommandIntent::SwitchSite,
    label="Switch Chat/DSH Site",
    group="View",
    description="Switch between the Harness and Chat roots.",
  )
}

///|
pub fn toggle_floating_action_command() -> @views.ActionCommand {
  @views.ActionCommand::new(
    intent=@views.CommandIntent::ToggleFloating,
    label="Toggle Floating Button",
    group="View",
    description="Show or hide the floating site-switch button.",
  )
}

///|
fn edit_action_command(
  intent : @views.CommandIntent,
  label : String,
  key : String,
  shift? : Bool = false,
) -> @views.ActionCommand {
  @views.ActionCommand::new(
    intent~,
    label~,
    shortcut=Some(
      @views.KeyboardShortcut::new(
        key~,
        modifiers=@views.KeyModifiers::new(shift~, meta=true),
      ),
    ),
  )
}

///|
pub fn application_menus() -> Array[@services.ApplicationMenu] {
  [
    @services.ApplicationMenu::application(items=[
      @services.ApplicationMenuItem::MenuCommand(settings_action_command()),
    ]),
    @services.ApplicationMenu::new(title="Edit", items=[
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::Undo, "Undo", "z"),
      ),
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::Redo, "Redo", "z", shift=true),
      ),
      @services.ApplicationMenuItem::MenuSeparator,
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::Cut, "Cut", "x"),
      ),
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::Copy, "Copy", "c"),
      ),
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::Paste, "Paste", "v"),
      ),
      @services.ApplicationMenuItem::MenuSeparator,
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::SelectAll, "Select All", "a"),
      ),
    ]),
    @services.ApplicationMenu::new(title="View", items=[
      @services.ApplicationMenuItem::MenuCommand(switch_site_action_command()),
      @services.ApplicationMenuItem::MenuSeparator,
      @services.ApplicationMenuItem::MenuCommand(
        toggle_floating_action_command(),
      ),
    ]),
  ]
}

///|
fn program_commands() -> Array[@moui.ProgramCommand[Msg]] {
  [
    @moui.ProgramCommand::new(
      command=settings_action_command(),
      message=OpenSettings,
    ),
    @moui.ProgramCommand::new(
      command=switch_site_action_command(),
      message=SwitchSite,
    ),
    @moui.ProgramCommand::new(
      command=toggle_floating_action_command(),
      message=ToggleFloating,
    ),
  ]
}

///|
fn request_settings_load(services : @services.AppServices) -> @moui.Effect[Msg] {
  @moui.Effect::batch([
    services
    .settings()
    .read(request_url_settings_key)
    .effect(map=result => SettingsLoaded(result)),
    services
    .settings()
    .read(chat_url_settings_key)
    .effect(map=result => ChatSettingsLoaded(result)),
    services
    .settings()
    .read(theme_mode_settings_key)
    .effect(map=result => ThemeModeLoaded(result)),
    services
    .appearance()
    .system_color_scheme()
    .effect(map=result => SystemColorSchemeLoaded(result)),
  ])
}

///|
fn update_with_services(
  model : Model,
  msg : Msg,
  services : @services.AppServices,
) -> (Model, @moui.Effect[Msg]) {
  if msg is SaveSettings && model.settings_saving {
    return (model, @moui.Effect::none())
  }
  let next = update(model, msg)
  match msg {
    SaveSettings if next.settings_saving => {
      let harness = next.request_url_input
      let chat = next.chat_url_input
      let theme_mode = next.theme_mode_input.id()
      (
        next,
        @moui.Effect::batch([
          services
          .settings()
          .write(request_url_settings_key, harness)
          .effect(map=result => HarnessSettingsSaved(harness, result)),
          services
          .settings()
          .write(chat_url_settings_key, chat)
          .effect(map=result => ChatSettingsSaved(chat, result)),
          services
          .settings()
          .write(theme_mode_settings_key, theme_mode)
          .effect(map=result => ThemeModeSaved(next.theme_mode_input, result)),
        ]),
      )
    }
    _ => (next, @moui.Effect::none())
  }
}
