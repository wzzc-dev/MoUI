///|
using @views {
  button,
  column,
  command_menu,
  command_menu_section,
  command_palette,
  context_menu_region,
  row,
  status_bar,
  container,
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
  CommandSelected(@views.CommandIntent)
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
) -> (CommandPaletteModel, @moui.Effect[CommandPaletteMsg]) {
  match message {
    ShowNativeMenu =>
      (
        { ..self, last_result: "Opening native menu" },
        @moui.Effect::host_service(
          key="host:command-menu",
          label="Show command menu",
          run=dispatch => {
            dispatch(
              HostMenuCompleted(services.show_context_menu(self.commands())),
            )
          },
        ),
      )
    _ => (self.update(message), @moui.Effect::none())
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
) -> Array[@views.ActionCommand] {
  ignore(self)
  command_palette_commands()
}

///|
pub fn CommandPaletteModel::filtered_commands(
  self : CommandPaletteModel,
) -> Array[@views.ActionCommand] {
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
  intent : @views.CommandIntent,
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
    @host.HostServiceResponse::MenuAction(command) =>
      self.dispatch_intent(command.intent)
    @host.HostServiceResponse::MenuCommand(intent) =>
      self.dispatch_intent(intent)
    @host.HostServiceResponse::Unavailable(reason) =>
      { ..self, last_result: "Native menu unavailable: " + reason }
    _ => { ..self, last_result: "Native menu returned no command" }
  }
}

///|
pub fn view(model : CommandPaletteModel) -> @moui.View[CommandPaletteMsg] {
  model.view()
}

///|
pub fn CommandPaletteModel::view(
  self : CommandPaletteModel,
) -> @moui.View[CommandPaletteMsg] {
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
            on_click=CommandSelected(@views.CommandIntent::Submit),
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
  container(
    shell,
    width=760.0,
    height=620.0,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
pub fn CommandPaletteApp::program(
  self : CommandPaletteApp,
) -> @moui.Program[CommandPaletteModel, CommandPaletteMsg] {
  ignore(self)
  program()
}

///|
pub fn CommandPaletteApp::program_with_services(
  self : CommandPaletteApp,
  services : @host.HostAppServices,
) -> @moui.Program[CommandPaletteModel, CommandPaletteMsg] {
  ignore(self)
  program_with_services(services)
}

///|
pub fn program() -> @moui.Program[CommandPaletteModel, CommandPaletteMsg] {
  CommandPaletteModel::new().program()
}

///|
pub fn program_with_services(
  services : @host.HostAppServices,
) -> @moui.Program[CommandPaletteModel, CommandPaletteMsg] {
  CommandPaletteModel::new().program_with_services(services)
}

///|
pub fn CommandPaletteModel::program(
  self : CommandPaletteModel,
) -> @moui.Program[CommandPaletteModel, CommandPaletteMsg] {
  @moui.Program::simple(init=self, update~, view~)
}

///|
pub fn CommandPaletteModel::program_with_services(
  self : CommandPaletteModel,
  services : @host.HostAppServices,
) -> @moui.Program[CommandPaletteModel, CommandPaletteMsg] {
  @moui.Program::new(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => model.update_with_services(message, services),
    view~,
  )
}

///|
fn CommandPaletteModel::context_region(
  self : CommandPaletteModel,
  theme : @moui.Theme,
) -> @moui.View[CommandPaletteMsg] {
  context_menu_region(
    child=container(
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
      variant=@views.ContainerVariant::Raised,
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
  theme : @moui.Theme,
) -> @moui.View[CommandPaletteMsg] {
  let rows : Array[@moui.View[CommandPaletteMsg]] = [
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
  container(
    column(rows, spacing=theme.spacing_scale.xs, align=@views.CrossAlign::Start),
    width=700.0,
    height=110.0,
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
pub fn command_palette_commands() -> Array[@views.ActionCommand] {
  [
    @views.ActionCommand::new(
      intent=@views.CommandIntent::Submit,
      label="Save Document",
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key="s",
          modifiers=@views.KeyModifiers::new(meta=true),
        ),
      ),
      group="File",
      description="Persist the current document.",
    ),
    @views.ActionCommand::new(
      intent=@views.CommandIntent::Copy,
      label="Copy Selection",
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key="c",
          modifiers=@views.KeyModifiers::new(meta=true),
        ),
      ),
      group="Edit",
      description="Copy the selected block.",
    ),
    @views.ActionCommand::new(
      intent=@views.CommandIntent::Paste,
      label="Paste Selection",
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key="v",
          modifiers=@views.KeyModifiers::new(meta=true),
        ),
      ),
      group="Edit",
      description="Paste from the clipboard.",
    ),
    @views.ActionCommand::new(
      intent=@views.CommandIntent::Cancel,
      label="Archive Document",
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key="Backspace",
          modifiers=@views.KeyModifiers::new(meta=true),
        ),
      ),
      enabled=false,
      group="File",
      description="Disabled until a document is selected.",
    ),
    @views.ActionCommand::new(
      intent=@views.CommandIntent::OpenContextMenu,
      label="Open Fallback Menu",
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key="k",
          modifiers=@views.KeyModifiers::new(meta=true),
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
    command_menu_section(
      title="File",
      commands=command_palette_commands().filter(command => {
        command.group == "File"
      }),
    ),
    command_menu_section(
      title="Edit",
      commands=command_palette_commands().filter(command => {
        command.group == "Edit"
      }),
    ),
  ]
}

///|
pub fn action_command_map() -> @views.ActionCommandMap {
  let commands = command_palette_commands()
  @views.ActionCommandMap::new(
    bindings=commands.map(command => {
      @views.CommandBinding::new(command~, handle=() => ())
    }),
  )
}

///|
fn find_command(
  commands : Array[@views.ActionCommand],
  intent : @views.CommandIntent,
) -> @views.ActionCommand? {
  for command in commands {
    if command.intent == intent {
      return Some(command)
    }
  }
  None
}
