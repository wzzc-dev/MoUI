///|
using @views {
  button,
  choice_item,
  column,
  form,
  form_field,
  form_section,
  row,
  scroll_view,
  segmented_control,
  sidebar,
  sidebar_item,
  split_view,
  status_bar,
  container,
  text,
  text_field,
  toggle,
}

///|
pub struct SettingsApp {
  unit : Unit
}

///|
pub(all) struct SettingsModel {
  selected_section : String
  display_name : String
  email : String
  workspace : String
  theme_mode : String
  notifications : Bool
  telemetry : Bool
  saved_label : String
}

///|
pub struct SettingsSnapshot {
  selected_section : String
  display_name : String
  email : String
  workspace : String
  theme_mode : String
  notifications : Bool
  telemetry : Bool
  saved_label : String
} derive(Eq, Debug)

///|
pub(all) enum SettingsMsg {
  SelectSettingsSection(String)
  DisplayNameChanged(String)
  EmailChanged(String)
  WorkspaceChanged(String)
  ThemeModeSelected(String)
  NotificationsChanged(Bool)
  TelemetryChanged(Bool)
  SaveSettings
  ResetSettings
}

///|
pub fn SettingsApp::new() -> SettingsApp {
  { unit: () }
}

///|
pub fn SettingsModel::new() -> SettingsModel {
  {
    selected_section: "profile",
    display_name: "Ada Lovelace",
    email: "ada@https://wzzc-dev.github.io/MoUI",
    workspace: "Analytical Engine",
    theme_mode: "system",
    notifications: true,
    telemetry: false,
    saved_label: "Saved: Not saved",
  }
}

///|
pub fn SettingsModel::update(
  self : SettingsModel,
  message : SettingsMsg,
) -> SettingsModel {
  match message {
    SelectSettingsSection(section) => { ..self, selected_section: section }
    DisplayNameChanged(value) => { ..self, display_name: value }
    EmailChanged(value) => { ..self, email: value }
    WorkspaceChanged(value) => { ..self, workspace: value }
    ThemeModeSelected(value) => { ..self, theme_mode: value }
    NotificationsChanged(value) => { ..self, notifications: value }
    TelemetryChanged(value) => { ..self, telemetry: value }
    SaveSettings => { ..self, saved_label: "Saved: " + self.section_label() }
    ResetSettings => SettingsModel::new()
  }
}

///|
pub fn update(model : SettingsModel, message : SettingsMsg) -> SettingsModel {
  model.update(message)
}

///|
pub fn SettingsModel::save_snapshot(self : SettingsModel) -> SettingsSnapshot {
  {
    selected_section: self.selected_section,
    display_name: self.display_name,
    email: self.email,
    workspace: self.workspace,
    theme_mode: self.theme_mode,
    notifications: self.notifications,
    telemetry: self.telemetry,
    saved_label: self.saved_label,
  }
}

///|
pub fn SettingsModel::restore_from_snapshot(
  snapshot : SettingsSnapshot,
) -> SettingsModel {
  {
    selected_section: snapshot.selected_section,
    display_name: snapshot.display_name,
    email: snapshot.email,
    workspace: snapshot.workspace,
    theme_mode: snapshot.theme_mode,
    notifications: snapshot.notifications,
    telemetry: snapshot.telemetry,
    saved_label: snapshot.saved_label,
  }
}

///|
pub fn view(model : SettingsModel) -> @moui.View[SettingsMsg] {
  model.view()
}

///|
pub fn SettingsModel::view(self : SettingsModel) -> @moui.View[SettingsMsg] {
  let theme = self.resolved_theme()
  let content = column(
    [
      row(
        [
          column(
            [
              text(
                "Settings",
                role=@views.TextRole::Title,
                theme~,
                width=240.0,
                height=34.0,
              ),
              text(
                "Form, sidebar, saveable state, and theme preferences.",
                role=@views.TextRole::Caption,
                theme~,
                width=420.0,
                height=24.0,
              ),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          button(
            "Save Settings",
            on_click=SaveSettings,
            variant=@views.ButtonVariant::Primary,
            theme~,
            width=132.0,
            height=38.0,
          ),
          button(
            "Reset",
            on_click=ResetSettings,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=86.0,
            height=38.0,
          ),
        ],
        spacing=theme.spacing_scale.md,
        align=@views.CrossAlign::Center,
      ),
      split_view(
        primary=self.settings_sidebar(theme),
        detail=self.settings_detail(theme),
        primary_width=210.0,
        detail_width=590.0,
        height=420.0,
        spacing=theme.spacing_scale.md,
      ),
      status_bar(
        [
          self.saved_label,
          "Section: " + self.section_label(),
          "Theme: " + self.theme_label(),
        ],
        theme~,
        width=824.0,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
  container(
    content,
    width=880.0,
    height=560.0,
    variant=@views.ContainerVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
pub fn SettingsApp::program(
  self : SettingsApp,
) -> @moui.Program[SettingsModel, SettingsMsg] {
  ignore(self)
  SettingsModel::new().program()
}

///|
pub fn program() -> @moui.Program[SettingsModel, SettingsMsg] {
  SettingsModel::new().program()
}

///|
pub fn SettingsModel::program(
  self : SettingsModel,
) -> @moui.Program[SettingsModel, SettingsMsg] {
  @moui.Program::simple(init=self, update~, view~)
}

///|
fn SettingsModel::settings_sidebar(
  self : SettingsModel,
  theme : @moui.Theme,
) -> @moui.View[SettingsMsg] {
  sidebar(
    "Settings",
    [
      sidebar_item(
        id="profile",
        label="Profile",
        message=SelectSettingsSection("profile"),
      ),
      sidebar_item(
        id="workspace",
        label="Workspace",
        message=SelectSettingsSection("workspace"),
      ),
      sidebar_item(
        id="preferences",
        label="Preferences",
        message=SelectSettingsSection("preferences"),
      ),
    ],
    selected=self.selected_section,
    theme~,
    width=210.0,
    height=420.0,
  )
}

///|
fn SettingsModel::settings_detail(
  self : SettingsModel,
  theme : @moui.Theme,
) -> @moui.View[SettingsMsg] {
  let detail = match self.selected_section {
    "workspace" => self.workspace_form(theme)
    "preferences" => self.preferences_form(theme)
    _ => self.profile_form(theme)
  }
  container(
    scroll_view(detail, width=558.0, height=388.0),
    width=590.0,
    height=420.0,
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn SettingsModel::profile_form(
  self : SettingsModel,
  theme : @moui.Theme,
) -> @moui.View[SettingsMsg] {
  form(
    [
      form_section(
        [
          form_field(
            label="Display name",
            child=text_field(
              self.display_name,
              on_input=value => DisplayNameChanged(value),
              placeholder="Name shown in the app",
              variant=@views.TextFieldVariant::Outline,
              theme~,
              width=440.0,
            ),
            helper="Used in menus, comments, and audit trails.",
            required=true,
            theme~,
            width=500.0,
          ),
          form_field(
            label="Email",
            child=text_field(
              self.email,
              on_input=value => EmailChanged(value),
              placeholder="name@example.com",
              variant=@views.TextFieldVariant::Outline,
              theme~,
              width=440.0,
            ),
            helper="Receives account notifications.",
            error=self.email_error(),
            required=true,
            theme~,
            width=500.0,
          ),
        ],
        title="Profile",
        summary="Required account fields with app-owned validation.",
        theme~,
        width=520.0,
      ),
    ],
    theme~,
    width=540.0,
  )
}

///|
fn SettingsModel::workspace_form(
  self : SettingsModel,
  theme : @moui.Theme,
) -> @moui.View[SettingsMsg] {
  form(
    [
      form_section(
        [
          form_field(
            label="Workspace",
            child=text_field(
              self.workspace,
              on_input=value => WorkspaceChanged(value),
              placeholder="Workspace name",
              variant=@views.TextFieldVariant::Outline,
              theme~,
              width=440.0,
            ),
            helper="Shown in the sidebar and window title.",
            required=true,
            theme~,
            width=500.0,
          ),
          form_field(
            label="Notifications",
            child=toggle(
              if self.notifications {
                "Enabled"
              } else {
                "Disabled"
              },
              self.notifications,
              on_change=value => NotificationsChanged(value),
              foreground=theme.palette.foreground,
              check_color=theme.palette.primary,
            ),
            helper="Controls product update and billing email.",
            theme~,
            width=500.0,
          ),
        ],
        title="Workspace",
        summary="Team identity and notification defaults.",
        theme~,
        width=520.0,
      ),
    ],
    theme~,
    width=540.0,
  )
}

///|
fn SettingsModel::preferences_form(
  self : SettingsModel,
  theme : @moui.Theme,
) -> @moui.View[SettingsMsg] {
  form(
    [
      form_section(
        [
          form_field(
            label="Theme",
            child=segmented_control(
              [
                choice_item("light", "Light"),
                choice_item("dark", "Dark"),
                choice_item("system", "System"),
              ],
              selected=self.theme_mode,
              on_select=value => ThemeModeSelected(value),
              theme~,
              width=420.0,
            ),
            helper="System keeps the app ready for host theme integration.",
            theme~,
            width=500.0,
          ),
          form_field(
            label="Telemetry",
            child=toggle(
              if self.telemetry {
                "Enabled"
              } else {
                "Disabled"
              },
              self.telemetry,
              on_change=value => TelemetryChanged(value),
              foreground=theme.palette.foreground,
              check_color=theme.palette.primary,
            ),
            helper="Demo-only preference persisted through saveable state.",
            theme~,
            width=500.0,
          ),
        ],
        title="Preferences",
        summary="Theme mode and local behavior toggles.",
        theme~,
        width=520.0,
      ),
    ],
    theme~,
    width=540.0,
  )
}

///|
fn SettingsModel::resolved_theme(self : SettingsModel) -> @moui.Theme {
  if self.theme_mode == "dark" {
    @views.dark_theme()
  } else {
    @views.light_theme()
  }
}

///|
fn SettingsModel::email_error(self : SettingsModel) -> String {
  if self.email == "" {
    "Email is required"
  } else if !self.email.contains("@") {
    "Email must include @"
  } else {
    ""
  }
}

///|
fn SettingsModel::section_label(self : SettingsModel) -> String {
  match self.selected_section {
    "workspace" => "Workspace"
    "preferences" => "Preferences"
    _ => "Profile"
  }
}

///|
fn SettingsModel::theme_label(self : SettingsModel) -> String {
  match self.theme_mode {
    "light" => "Light"
    "dark" => "Dark"
    _ => "System"
  }
}
