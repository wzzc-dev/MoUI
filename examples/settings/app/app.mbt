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
  type FieldAction,
}

///|
pub struct SettingsApp {
  unit : Unit
}

///|
/// One section of the settings surface: the profile form fields. Sections
/// are plain data owned by `SettingsModel`; they never hold framework state.
pub(all) struct ProfileSection {
  display_name : String
  email : String
}

///|
/// Workspace identity and notification defaults.
pub(all) struct WorkspaceSection {
  workspace : String
  notifications : Bool
}

///|
/// Theme mode and local behavior toggles.
pub(all) struct PreferencesSection {
  theme_mode : String
  telemetry : Bool
}

///|
/// Root-only shell state (sidebar selection, save status). Not a scoped
/// feature: it belongs to the parent update arms directly.
pub(all) struct ShellSection {
  selected_section : String
  saved_label : String
}

///|
pub(all) struct SettingsModel {
  profile : ProfileSection
  workspace : WorkspaceSection
  preferences : PreferencesSection
  shell : ShellSection
}

///|
/// Flat wire format for saveable persistence; deliberately independent of
/// the section split so stored snapshots stay stable across refactors.
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
/// Profile section messages. Field edits are keyed by field name so one
/// variant covers every text field (`views.FieldAction`).
pub(all) enum ProfileMsg {
  Field(String, FieldAction)
}

///|
pub(all) enum WorkspaceMsg {
  WorkspaceChanged(String)
  NotificationsChanged(Bool)
}

///|
pub(all) enum PreferencesMsg {
  ThemeModeSelected(String)
  TelemetryChanged(Bool)
}

///|
/// Root messages: one wrapper variant per scoped section feature, plus the
/// shell-only arms. Section-internal variants stay inside their enums.
pub(all) enum SettingsMsg {
  Profile(ProfileMsg)
  Workspace(WorkspaceMsg)
  Preferences(PreferencesMsg)
  SelectSettingsSection(String)
  SaveSettings
  ResetSettings
}

///|
pub fn SettingsApp::new() -> SettingsApp {
  { unit: (), }
}

// ---------------------------------------------------------------------------
// Section lenses (read/write pairs shared by Feature::scope and snapshot
// rebuild). Pure functions: `write` returns a new parent, never mutates.
// ---------------------------------------------------------------------------

///|
fn profile_read(model : SettingsModel) -> ProfileSection {
  model.profile
}

///|
fn profile_write(
  section : ProfileSection,
  model : SettingsModel,
) -> SettingsModel {
  { ..model, profile: section, }
}

///|
fn workspace_read(model : SettingsModel) -> WorkspaceSection {
  model.workspace
}

///|
fn workspace_write(
  section : WorkspaceSection,
  model : SettingsModel,
) -> SettingsModel {
  { ..model, workspace: section, }
}

///|
fn preferences_read(model : SettingsModel) -> PreferencesSection {
  model.preferences
}

///|
fn preferences_write(
  section : PreferencesSection,
  model : SettingsModel,
) -> SettingsModel {
  { ..model, preferences: section, }
}

///|
fn shell_read(model : SettingsModel) -> ShellSection {
  model.shell
}

///|
fn shell_write(section : ShellSection, model : SettingsModel) -> SettingsModel {
  { ..model, shell: section, }
}

// ---------------------------------------------------------------------------
// Section features: each is a standalone TEA unit (init/update/view) over
// its own section model. Theme enters through the view closure because it
// derives from the preferences section, which is a sibling, not an ancestor.
// ---------------------------------------------------------------------------

///|
fn profile_section_default() -> ProfileSection {
  {
    display_name: "Ada Lovelace",
    email: "ada@https://wzzc-dev.github.io/MoUI",
  }
}

///|
fn workspace_section_default() -> WorkspaceSection {
  { workspace: "Analytical Engine", notifications: true, }
}

///|
fn preferences_section_default() -> PreferencesSection {
  { theme_mode: "system", telemetry: false, }
}

///|
fn profile_update(
  model : ProfileSection,
  message : ProfileMsg,
) -> (ProfileSection, @moui.Effect[ProfileMsg]) {
  match message {
    Field(name, action) =>
      (
        match action {
          Text(value) =>
            if name == "display_name" {
              { ..model, display_name: value, }
            } else if name == "email" {
              { ..model, email: value, }
            } else {
              model // unknown field keys are inert
            }
          Toggle(_enabled) => model // profile is text-only
          Select(_value) => model
        },
        @moui.Effect::none(),
      )
  }
}

///|
fn workspace_update(
  model : WorkspaceSection,
  message : WorkspaceMsg,
) -> (WorkspaceSection, @moui.Effect[WorkspaceMsg]) {
  match message {
    WorkspaceChanged(value) =>
      ({ ..model, workspace: value, }, @moui.Effect::none())
    NotificationsChanged(value) =>
      ({ ..model, notifications: value, }, @moui.Effect::none())
  }
}

///|
fn preferences_update(
  model : PreferencesSection,
  message : PreferencesMsg,
) -> (PreferencesSection, @moui.Effect[PreferencesMsg]) {
  match message {
    ThemeModeSelected(value) =>
      ({ ..model, theme_mode: value, }, @moui.Effect::none())
    TelemetryChanged(value) =>
      ({ ..model, telemetry: value, }, @moui.Effect::none())
  }
}

///|
fn profile_feature(
  theme : @moui.Theme,
) -> @moui.Feature[ProfileSection, ProfileMsg] {
  @moui.Feature::new(
    init=() => (profile_section_default(), @moui.Effect::none()),
    update=profile_update,
    view=model => profile_form(model, theme),
  )
}

///|
fn workspace_feature(
  theme : @moui.Theme,
) -> @moui.Feature[WorkspaceSection, WorkspaceMsg] {
  @moui.Feature::new(
    init=() => (workspace_section_default(), @moui.Effect::none()),
    update=workspace_update,
    view=model => workspace_form(model, theme),
  )
}

///|
fn preferences_feature(
  theme : @moui.Theme,
) -> @moui.Feature[PreferencesSection, PreferencesMsg] {
  @moui.Feature::new(
    init=() => (preferences_section_default(), @moui.Effect::none()),
    update=preferences_update,
    view=model => preferences_form(model, theme),
  )
}

///|
/// Mounted profile handle. The `update` path never evaluates the view, so
/// the default theme argument is irrelevant there; the `view` path passes
/// the model-resolved theme (`theme~`).
fn profile_scope(
  theme? : @moui.Theme = @views.light_theme(),
) -> @moui.ScopedFeature[SettingsModel, ProfileSection, ProfileMsg, SettingsMsg] {
  profile_feature(theme).scope(read=profile_read, write=profile_write, wrap=message => {
    Profile(message)
  })
}

///|
fn workspace_scope(
  theme? : @moui.Theme = @views.light_theme(),
) -> @moui.ScopedFeature[
  SettingsModel,
  WorkspaceSection,
  WorkspaceMsg,
  SettingsMsg,
] {
  workspace_feature(theme).scope(read=workspace_read, write=workspace_write, wrap=message => {
    Workspace(message)
  })
}

///|
fn preferences_scope(
  theme? : @moui.Theme = @views.light_theme(),
) -> @moui.ScopedFeature[
  SettingsModel,
  PreferencesSection,
  PreferencesMsg,
  SettingsMsg,
] {
  preferences_feature(theme).scope(
    read=preferences_read,
    write=preferences_write,
    wrap=message => Preferences(message),
  )
}

// ---------------------------------------------------------------------------
// Root model
// ---------------------------------------------------------------------------

///|
pub fn SettingsModel::new() -> SettingsModel {
  {
    profile: profile_section_default(),
    workspace: workspace_section_default(),
    preferences: preferences_section_default(),
    shell: { selected_section: "profile", saved_label: "Saved: Not saved", },
  }
}

///|
/// Pure root reducer. Section arms delegate through `Feature::scope`; each
/// section is effect-free, so the dropped effect is explicit. If a section
/// grows an effect, switch `program()` to `Program::new` and forward it —
/// do not silently widen this drop.
pub fn SettingsModel::update(
  self : SettingsModel,
  message : SettingsMsg,
) -> SettingsModel {
  match message {
    Profile(inner) => {
      let (next, _effect) = profile_scope().update(self, inner)
      next
    }
    Workspace(inner) => {
      let (next, _effect) = workspace_scope().update(self, inner)
      next
    }
    Preferences(inner) => {
      let (next, _effect) = preferences_scope().update(self, inner)
      next
    }
    SelectSettingsSection(section) =>
      shell_write({ ..self.shell, selected_section: section, }, self)
    SaveSettings =>
      shell_write(
        { ..self.shell, saved_label: "Saved: " + self.section_label(), },
        self,
      )
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
    selected_section: shell_read(self).selected_section,
    display_name: profile_read(self).display_name,
    email: profile_read(self).email,
    workspace: workspace_read(self).workspace,
    theme_mode: preferences_read(self).theme_mode,
    notifications: workspace_read(self).notifications,
    telemetry: preferences_read(self).telemetry,
    saved_label: shell_read(self).saved_label,
  }
}

///|
pub fn SettingsModel::restore_from_snapshot(
  snapshot : SettingsSnapshot,
) -> SettingsModel {
  let base = SettingsModel::new()
  let base = profile_write(
    { display_name: snapshot.display_name, email: snapshot.email, },
    base,
  )
  let base = workspace_write(
    { workspace: snapshot.workspace, notifications: snapshot.notifications, },
    base,
  )
  let base = preferences_write(
    { theme_mode: snapshot.theme_mode, telemetry: snapshot.telemetry, },
    base,
  )
  shell_write(
    {
      selected_section: snapshot.selected_section,
      saved_label: snapshot.saved_label,
    },
    base,
  )
}

// ---------------------------------------------------------------------------
// Root view
// ---------------------------------------------------------------------------

///|
pub fn view(model : SettingsModel) -> @moui.View[SettingsMsg] {
  model.view()
}

///|
pub fn SettingsModel::view(self : SettingsModel) -> @moui.View[SettingsMsg] {
  self.view_with_environment(standalone_view_environment())
}

///|
/// Canonical view entry: threads the runtime `ViewEnvironment` into scoped
/// section views. Standalone callers get a neutral environment.
pub fn SettingsModel::view_with_environment(
  self : SettingsModel,
  environment : @moui.ViewEnvironment,
) -> @moui.View[SettingsMsg] {
  let theme = self.resolved_theme()
  let content = column(
    [
      row(
        [
          column(
            [
              text("Settings", role=Title, theme~, width=240.0, height=34.0),
              text(
                "Form, sidebar, saveable state, and theme preferences.",
                role=Caption,
                theme~,
                width=420.0,
                height=24.0,
              ),
            ],
            spacing=0.0,
            align=Start,
          ),
          button(
            "Save Settings",
            on_click=SaveSettings,
            variant=Primary,
            theme~,
            width=132.0,
            height=38.0,
          ),
          button(
            "Reset",
            on_click=ResetSettings,
            variant=Outline,
            theme~,
            width=86.0,
            height=38.0,
          ),
        ],
        spacing=theme.spacing_scale.md,
        align=Center,
      ),
      split_view(
        primary=self.settings_sidebar(theme),
        detail=self.settings_detail(theme, environment),
        primary_width=210.0,
        detail_width=590.0,
        height=420.0,
        spacing=theme.spacing_scale.md,
      ),
      status_bar(
        [
          self.shell.saved_label,
          "Section: " + self.section_label(),
          "Theme: " + self.theme_label(),
        ],
        theme~,
        width=824.0,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=Stretch,
  )
  container(
    content,
    width=880.0,
    height=560.0,
    variant=Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
fn standalone_view_environment() -> @moui.ViewEnvironment {
  @moui.ViewEnvironment::new(
    viewport_size=@geometry.Size::new(width=880.0, height=560.0),
    environment=@moui.Environment::neutral(),
  )
}

// ---------------------------------------------------------------------------
// Program bridge: Feature at the root, Program at the runtime boundary.
// ---------------------------------------------------------------------------

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
  @moui.Program::simple_with_environment(init=self, update~, view=(
    model,
    environment,
  ) => model.view_with_environment(environment))
}

// ---------------------------------------------------------------------------
// Section composition (sidebar/shell stay parent-owned)
// ---------------------------------------------------------------------------

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
    selected=self.shell.selected_section,
    theme~,
    width=210.0,
    height=420.0,
  )
}

///|
fn SettingsModel::settings_detail(
  self : SettingsModel,
  theme : @moui.Theme,
  environment : @moui.ViewEnvironment,
) -> @moui.View[SettingsMsg] {
  // The active section's scoped feature builds its view; messages lift
  // through the wrapper variant automatically.
  let detail = match self.shell.selected_section {
    "workspace" => workspace_scope(theme~).view(self, environment)
    "preferences" => preferences_scope(theme~).view(self, environment)
    _ => profile_scope(theme~).view(self, environment)
  }
  container(
    scroll_view(detail, width=558.0, height=388.0),
    width=590.0,
    height=420.0,
    variant=Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

// ---------------------------------------------------------------------------
// Section forms (feature views: Section model in, section Msg out)
// ---------------------------------------------------------------------------

///|
fn profile_form(
  model : ProfileSection,
  theme : @moui.Theme,
) -> @moui.View[ProfileMsg] {
  form(
    [
      form_section(
        [
          form_field(
            label="Display name",
            child=text_field(
              model.display_name,
              on_input=value => Field("display_name", Text(value)),
              placeholder="Name shown in the app",
              variant=Outline,
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
              model.email,
              on_input=value => Field("email", Text(value)),
              placeholder="name@example.com",
              variant=Outline,
              theme~,
              width=440.0,
            ),
            helper="Receives account notifications.",
            error=email_error(model.email),
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
fn workspace_form(
  model : WorkspaceSection,
  theme : @moui.Theme,
) -> @moui.View[WorkspaceMsg] {
  form(
    [
      form_section(
        [
          form_field(
            label="Workspace",
            child=text_field(
              model.workspace,
              on_input=value => WorkspaceChanged(value),
              placeholder="Workspace name",
              variant=Outline,
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
              if model.notifications {
                "Enabled"
              } else {
                "Disabled"
              },
              model.notifications,
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
fn preferences_form(
  model : PreferencesSection,
  theme : @moui.Theme,
) -> @moui.View[PreferencesMsg] {
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
              selected=model.theme_mode,
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
              if model.telemetry {
                "Enabled"
              } else {
                "Disabled"
              },
              model.telemetry,
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

// ---------------------------------------------------------------------------
// Derived labels
// ---------------------------------------------------------------------------

///|
fn SettingsModel::resolved_theme(self : SettingsModel) -> @moui.Theme {
  if self.preferences.theme_mode == "dark" {
    @views.dark_theme()
  } else {
    @views.light_theme()
  }
}

///|
fn email_error(email : String) -> String {
  if email == "" {
    "Email is required"
  } else if !email.contains("@") {
    "Email must include @"
  } else {
    ""
  }
}

///|
fn SettingsModel::section_label(self : SettingsModel) -> String {
  match self.shell.selected_section {
    "workspace" => "Workspace"
    "preferences" => "Preferences"
    _ => "Profile"
  }
}

///|
fn SettingsModel::theme_label(self : SettingsModel) -> String {
  match self.preferences.theme_mode {
    "light" => "Light"
    "dark" => "Dark"
    _ => "System"
  }
}
