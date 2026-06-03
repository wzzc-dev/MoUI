///|
using @views {
  button,
  column,
  command_menu,
  command_palette,
  context_menu_region,
  row,
  status_bar,
  surface,
  text,
  text_field,
  toolbar,
}

///|
pub struct CommandPaletteApp {
  unit : Unit
}

///|
pub(all) struct CommandPaletteModel {
  query : String
  context_visible : Bool
  dispatched : Array[String]
  last_result : String
}

///|
pub(all) enum CommandPaletteMsg {
  QueryChanged(String)
  CommandSelected(@core.CommandIntent)
  ShowNativeMenu
  HostMenuCompleted(@host.HostServiceResponse)
  ToggleContextMenu
  HideContextMenu
  ClearLog
}

///|
pub fn CommandPaletteApp::new() -> CommandPaletteApp {
  { unit: () }
}

///|
pub fn CommandPaletteModel::new() -> CommandPaletteModel {
  {
    query: "",
    context_visible: true,
    dispatched: [],
    last_result: "No command dispatched",
  }
}

///|
pub fn CommandPaletteModel::update(
  self : CommandPaletteModel,
  message : CommandPaletteMsg,
) -> CommandPaletteModel {
  match message {
    QueryChanged(value) => { ..self, query: value }
    CommandSelected(intent) => self.dispatch_intent(intent)
    ShowNativeMenu =>
      { ..self, last_result: "Native menu requires host services" }
    HostMenuCompleted(response) => self.apply_host_menu_response(response)
    ToggleContextMenu => { ..self, context_visible: !self.context_visible }
    HideContextMenu => { ..self, context_visible: false }
    ClearLog => { ..self, dispatched: [], last_result: "No command dispatched" }
  }
}

///|
pub fn CommandPaletteModel::update_with_services(
  self : CommandPaletteModel,
  message : CommandPaletteMsg,
  services : @host.HostAppServices,
) -> (CommandPaletteModel, @core.Effect[CommandPaletteMsg]) {
  match message {
    ShowNativeMenu =>
      (
        { ..self, last_result: "Opening native menu" },
        @core.Effect::run(
          key="host:command-menu",
          kind="host-service",
          label="Show command menu",
          run=dispatch => {
            dispatch(
              HostMenuCompleted(services.show_context_menu(self.commands())),
            )
          },
        ),
      )
    _ => (self.update(message), @core.Effect::none())
  }
}

///|
pub fn update(
  model : CommandPaletteModel,
  message : CommandPaletteMsg,
) -> CommandPaletteModel {
  model.update(message)
}

///|
pub fn CommandPaletteModel::commands(
  self : CommandPaletteModel,
) -> Array[@core.ActionCommand] {
  ignore(self)
  command_palette_commands()
}

///|
pub fn CommandPaletteModel::filtered_commands(
  self : CommandPaletteModel,
) -> Array[@core.ActionCommand] {
  let needle = self.query.to_lower()
  self
  .commands()
  .filter(command => {
    needle == "" ||
    command.display_label().to_lower().contains(needle) ||
    command.group.to_lower().contains(needle) ||
    command.description.to_lower().contains(needle) ||
    command.shortcut_label().to_lower().contains(needle)
  })
}

///|
pub fn CommandPaletteModel::dispatch_intent(
  self : CommandPaletteModel,
  intent : @core.CommandIntent,
) -> CommandPaletteModel {
  let command = find_command(self.commands(), intent)
  match command {
    Some(command) =>
      if command.enabled {
        let dispatched = self.dispatched.copy()
        dispatched.push(command.display_label())
        {
          ..self,
          dispatched,
          last_result: "Dispatched: " + command.display_label(),
          context_visible: false,
        }
      } else {
        { ..self, last_result: "Disabled: " + command.display_label() }
      }
    None => { ..self, last_result: "Unknown command" }
  }
}

///|
fn CommandPaletteModel::apply_host_menu_response(
  self : CommandPaletteModel,
  response : @host.HostServiceResponse,
) -> CommandPaletteModel {
  match response {
    @host.HostServiceResponse::MenuCommand(intent) =>
      self.dispatch_intent(intent)
    @host.HostServiceResponse::Unavailable(reason) =>
      { ..self, last_result: "Native menu unavailable: " + reason }
    _ => { ..self, last_result: "Native menu returned no command" }
  }
}

///|
pub fn view(model : CommandPaletteModel) -> @core.View[CommandPaletteMsg] {
  model.view()
}

///|
pub fn CommandPaletteModel::view(
  self : CommandPaletteModel,
) -> @core.View[CommandPaletteMsg] {
  let theme = @views.light_theme()
  let shell = column(
    [
      row(
        [
          column(
            [
              text(
                "Command Palette",
                role=@views.TextRole::Title,
                theme~,
                width=300.0,
                height=34.0,
              ),
              text(
                "Metadata, shortcuts, disabled rows, and context fallback.",
                role=@views.TextRole::Caption,
                theme~,
                width=460.0,
                height=24.0,
              ),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          button(
            "Clear Log",
            on_click=ClearLog,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=96.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Center,
      ),
      toolbar(
        [
          text_field(
            self.query,
            on_input=value => QueryChanged(value),
            placeholder="Filter commands",
            variant=@views.TextFieldVariant::Outline,
            theme~,
            width=260.0,
            height=38.0,
          ),
          button(
            "Context",
            on_click=ToggleContextMenu,
            variant=@views.ButtonVariant::Tonal,
            theme~,
            width=96.0,
            height=36.0,
          ),
          button(
            "Native Menu",
            on_click=ShowNativeMenu,
            variant=@views.ButtonVariant::Tonal,
            theme~,
            width=118.0,
            height=36.0,
          ),
          button(
            "Submit",
            on_click=CommandSelected(@core.CommandIntent::Submit),
            variant=@views.ButtonVariant::Primary,
            theme~,
            width=88.0,
            height=36.0,
          ),
        ],
        theme~,
        width=700.0,
      ),
      row(
        [
          command_palette(
            self.commands(),
            query=self.query,
            on_select=intent => CommandSelected(intent),
            theme~,
            width=410.0,
            max_height=260.0,
          ),
          self.context_region(theme),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Start,
      ),
      self.command_log(theme),
      status_bar(
        [self.last_result, "Visible: \{self.filtered_commands().length()}"],
        theme~,
        width=700.0,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
  surface(
    shell,
    width=760.0,
    height=620.0,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
pub fn CommandPaletteApp::runtime(
  self : CommandPaletteApp,
  width? : Double = 800.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  ignore(self)
  runtime(width~, height~)
}

///|
pub fn CommandPaletteApp::runtime_with_services(
  self : CommandPaletteApp,
  services : @host.HostAppServices,
  width? : Double = 800.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  ignore(self)
  runtime_with_services(services, width~, height~)
}

///|
pub fn runtime(
  width? : Double = 800.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  CommandPaletteModel::new().runtime(width~, height~)
}

///|
pub fn runtime_with_services(
  services : @host.HostAppServices,
  width? : Double = 800.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  CommandPaletteModel::new().runtime_with_services(services, width~, height~)
}

///|
pub fn CommandPaletteModel::runtime(
  self : CommandPaletteModel,
  width? : Double = 800.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::simple(init=self, update~, view~),
    size=@core.Size::new(width~, height~),
  )
  runtime.set_action_commands(action_command_map())
  runtime
}

///|
pub fn CommandPaletteModel::runtime_with_services(
  self : CommandPaletteModel,
  services : @host.HostAppServices,
  width? : Double = 800.0,
  height? : Double = 680.0,
) -> @core.AppRuntime {
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::new(
      init=() => (self, @core.Effect::none()),
      update=(model, message) => model.update_with_services(message, services),
      view~,
    ),
    size=@core.Size::new(width~, height~),
  )
  runtime.set_action_commands(action_command_map())
  runtime
}

///|
fn CommandPaletteModel::context_region(
  self : CommandPaletteModel,
  theme : @core.Theme,
) -> @core.View[CommandPaletteMsg] {
  context_menu_region(
    child=surface(
      column(
        [
          text(
            "Context menu fallback",
            role=@views.TextRole::Control,
            theme~,
            width=230.0,
            height=28.0,
          ),
          text(
            "Use command menu rows when native menus are unavailable.",
            role=@views.TextRole::Caption,
            theme~,
            width=230.0,
            height=42.0,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Start,
      ),
      width=260.0,
      height=96.0,
      variant=@views.SurfaceVariant::Raised,
      theme~,
      padding=theme.spacing_scale.md,
    ),
    menu=command_menu(
      command_sections(),
      on_select=intent => CommandSelected(intent),
      theme~,
      width=280.0,
      max_height=178.0,
    ),
    visible=self.context_visible,
    theme~,
  )
}

///|
fn CommandPaletteModel::command_log(
  self : CommandPaletteModel,
  theme : @core.Theme,
) -> @core.View[CommandPaletteMsg] {
  let rows : Array[@core.View[CommandPaletteMsg]] = [
    text(
      "Dispatch Log",
      role=@views.TextRole::Control,
      theme~,
      width=680.0,
      height=26.0,
    ),
  ]
  if self.dispatched.is_empty() {
    rows.push(
      text(
        "No commands yet",
        role=@views.TextRole::Caption,
        theme~,
        width=680.0,
        height=24.0,
      ),
    )
  } else {
    for item in self.dispatched {
      rows.push(
        text(
          item,
          role=@views.TextRole::Caption,
          theme~,
          width=680.0,
          height=24.0,
        ),
      )
    }
  }
  surface(
    column(rows, spacing=theme.spacing_scale.xs, align=@views.CrossAlign::Start),
    width=700.0,
    height=110.0,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
pub fn command_palette_commands() -> Array[@core.ActionCommand] {
  [
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Submit,
      label="Save Document",
      shortcut=Some(
        @core.KeyboardShortcut::new(
          key="s",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
      group="File",
      description="Persist the current document.",
    ),
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Copy,
      label="Copy Selection",
      shortcut=Some(
        @core.KeyboardShortcut::new(
          key="c",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
      group="Edit",
      description="Copy the selected block.",
    ),
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Paste,
      label="Paste Selection",
      shortcut=Some(
        @core.KeyboardShortcut::new(
          key="v",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
      group="Edit",
      description="Paste from the clipboard.",
    ),
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Cancel,
      label="Archive Document",
      shortcut=Some(
        @core.KeyboardShortcut::new(
          key="Backspace",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
      enabled=false,
      group="File",
      description="Disabled until a document is selected.",
    ),
    @core.ActionCommand::new(
      intent=@core.CommandIntent::OpenContextMenu,
      label="Open Fallback Menu",
      shortcut=Some(
        @core.KeyboardShortcut::new(
          key="k",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
      group="View",
      description="Show the view-level context menu.",
    ),
  ]
}

///|
pub fn command_sections() -> Array[@views.CommandMenuSection] {
  [
    @views.CommandMenuSection::new(
      title="File",
      commands=command_palette_commands().filter(command => {
        command.group == "File"
      }),
    ),
    @views.CommandMenuSection::new(
      title="Edit",
      commands=command_palette_commands().filter(command => {
        command.group == "Edit"
      }),
    ),
  ]
}

///|
pub fn action_command_map() -> @core.ActionCommandMap {
  let commands = command_palette_commands()
  @core.ActionCommandMap::new(
    bindings=commands.map(command => {
      @core.CommandBinding::new(command~, handle=() => ())
    }),
  )
}

///|
fn find_command(
  commands : Array[@core.ActionCommand],
  intent : @core.CommandIntent,
) -> @core.ActionCommand? {
  for command in commands {
    if command.intent == intent {
      return Some(command)
    }
  }
  None
}
