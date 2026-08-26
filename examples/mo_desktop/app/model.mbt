///|
pub(all) enum SessionPhase {
  Boot
  Locked
  Login
  Unlocked
} derive(Eq, Debug)

///|
pub(all) enum DesktopOverlay {
  OverlayNone
  MenuBarMenu(DesktopMenu)
  Launcher
  Spotlight
  ControlCenter
  NotificationCenter
  AboutThisMac
  SystemSettings
  AppStore
} derive(Eq, Debug)

///|
pub(all) enum DesktopMenu {
  SystemMenu
  AppMenu
  FileMenu
  EditMenu
  ViewMenu
  GoMenu
  WindowMenu
  HelpMenu
} derive(Eq, Debug)

///|
pub(all) enum MenuCommand {
  ToggleAppearance
  ShowAboutThisMac
  ShowSystemSettings
  ShowAppStore
  LockSession
  OpenFinderWindow
  OpenSafariWindow
  BringFinderForward
  BringSafariForward
  OpenDocuments
  OpenDownloads
  OpenLauncher
  OpenNotificationCenter
  ShowFinderIconView
  ShowFinderListView
  CloseFocusedWindow
  MinimizeFocusedWindow
  ZoomFocusedWindow
  ResetDesktopSettingsCommand
  LogOutSession
  ToggleLanguageCommand
} derive(Eq, Debug)

///|
pub(all) enum FinderLocation {
  Documents
  Applications
  Downloads
} derive(Eq, Debug)

///|
pub(all) enum FinderViewMode {
  IconView
  ListView
} derive(Eq, Debug)

///|
pub(all) enum LauncherTab {
  Apps
  Actions
} derive(Eq, Debug)

///|
pub(all) enum DesktopTask {
  ReviewDesktop
  ReplyToMaya
  PlanTahoePhotos
} derive(Eq, Debug)

///|
pub(all) enum AppearanceMode {
  SystemAppearance
  LightAppearance
  DarkAppearance
} derive(Eq, Debug)

///|
pub(all) enum BrowserPage {
  StartPage
  SearchResults(String)
} derive(Eq, Debug)

///|
pub(all) enum DesktopService {
  SystemAppearanceService
  FileImportService
  UrlOpenService
} derive(Eq, Debug)

///|
pub(all) struct DesktopClock {
  year : Int
  month : Int
  day : Int
  weekday : Int
  hour : Int
  minute : Int
  second : Int
} derive(Eq, Debug)

///|
pub fn DesktopClock::new(
  year : Int,
  month : Int,
  day : Int,
  weekday : Int,
  hour : Int,
  minute : Int,
  second? : Int = 0,
) -> DesktopClock {
  { year, month, day, weekday, hour, minute, second }
}

///|
fn default_desktop_clock() -> DesktopClock {
  DesktopClock::new(2026, 7, 19, 0, 9, 41)
}

///|
pub(all) struct DesktopModel {
  wallpaper_source : String
  phase : SessionPhase
  windows : Array[WindowRecord]
  next_window_serial : Int
  next_z_order : Int
  overlay : DesktopOverlay
  appearance : AppearanceMode
  dark_mode : Bool
  clock : DesktopClock
  finder_location : FinderLocation
  finder_history : Array[FinderLocation]
  finder_history_index : Int
  finder_view_mode : FinderViewMode
  finder_query : String
  selected_file : String
  launcher_query : String
  launcher_tab : LauncherTab
  spotlight_query : String
  browser_query : String
  browser_page : BrowserPage
  browser_tab_titles : Array[String]
  browser_active_tab : Int
  wifi_enabled : Bool
  bluetooth_enabled : Bool
  low_power_mode : Bool
  brightness : Double
  volume : Double
  notifications_read : Bool
  first_task_done : Bool
  second_task_done : Bool
  third_task_done : Bool
  imported_files : Array[String]
  icon_placements : Array[DesktopIconPlacement]
  notes : Array[String]
  active_note : Int
  terminal_lines : Array[String]
  terminal_input : String
  boot_ticks : Int
  login_password : String
  language : AppLanguage
  pending_service : DesktopService?
  last_diagnostic : String
  settings_loaded : Bool
}

///|
pub(all) enum Msg {
  AdvanceBoot
  ShowLogin
  SubmitLogin(String)
  LoginPasswordChanged(String)
  SetLanguage(AppLanguage)
  LockDesktop
  OpenFinder
  OpenSafari
  CloseWindow
  MinimizeWindow
  ToggleMaximize
  MoveWindowBy(Double, Double)
  FocusWindow(WindowId)
  CloseWindowAt(WindowId)
  MinimizeWindowAt(WindowId)
  ToggleZoomAt(WindowId)
  ResizeWindowBy(WindowId, Double, Double)
  MoveDesktopIcon(String, Double, Double)
  LoadDesktopSettings
  DesktopSettingsLoaded(@services.ServiceTaskResult[String?])
  DesktopSettingsSaved(@services.ServiceTaskResult[Unit])
  ResetDesktopSettings
  DesktopSettingsResetCompleted(@services.ServiceTaskResult[Unit])
  LaunchApp(AppKind)
  AddNote
  SelectNote(Int)
  DeleteNote(Int)
  NoteBodyChanged(String)
  TerminalInputChanged(String)
  RunTerminalCommand
  ClearTerminal
  ToggleMenu(DesktopMenu)
  RunMenuCommand(MenuCommand)
  ToggleLauncher
  ToggleControlCenter
  ToggleNotificationCenter
  DismissOverlay
  SelectFinderLocation(FinderLocation)
  GoFinderBack
  GoFinderForward
  SelectFinderView(FinderViewMode)
  FinderQueryChanged(String)
  SelectFinderItem(String)
  LauncherQueryChanged(String)
  LauncherTabSelected(LauncherTab)
  SpotlightQueryChanged(String)
  ToggleSpotlight
  BrowserQueryChanged(String)
  SubmitBrowserQuery
  ShowBrowserStartPage
  NewBrowserTab
  SelectBrowserTab(Int)
  CloseBrowserTab(Int)
  OpenFavorite(String)
  ToggleDarkMode
  UseSystemAppearance
  RequestFileImport
  SystemAppearanceCompleted(@services.ServiceTaskResult[@state.ColorScheme])
  FileImportCompleted(@services.ServiceTaskResult[Array[String]])
  UrlOpenCompleted(@services.ServiceTaskResult[Unit])
  ClockUpdated(DesktopClock)
  WifiChanged(Bool)
  BluetoothChanged(Bool)
  LowPowerModeChanged(Bool)
  BrightnessChanged(Double)
  VolumeChanged(Double)
  MarkNotificationsRead
  CompleteTask(DesktopTask)
}

///|
pub fn DesktopModel::new(
  wallpaper_source? : String = "examples/mo_desktop/web_wasm/assets/tahoe-day.jpg",
  clock? : DesktopClock = default_desktop_clock(),
) -> DesktopModel {
  {
    wallpaper_source,
    phase: Boot,
    boot_ticks: 0,
    login_password: "",
    language: EnglishLanguage,
    windows: [
      {
        id: { app: FinderApp, serial: 1 },
        state: NormalWindow,
        bounds: WindowBounds::default(),
        z_order: 1,
      },
    ],
    next_window_serial: 2,
    next_z_order: 2,
    overlay: OverlayNone,
    appearance: SystemAppearance,
    dark_mode: false,
    clock,
    finder_location: Documents,
    finder_history: [Documents],
    finder_history_index: 0,
    finder_view_mode: IconView,
    finder_query: "",
    selected_file: "",
    launcher_query: "",
    launcher_tab: Apps,
    spotlight_query: "",
    browser_query: "",
    browser_page: StartPage,
    browser_tab_titles: ["Start Page"],
    browser_active_tab: 0,
    wifi_enabled: true,
    bluetooth_enabled: true,
    low_power_mode: false,
    brightness: 0.82,
    volume: 0.68,
    notifications_read: false,
    first_task_done: false,
    second_task_done: false,
    third_task_done: false,
    imported_files: [],
    icon_placements: [],
    notes: [default_note_body()],
    active_note: 0,
    terminal_lines: [terminal_banner()],
    terminal_input: "",
    pending_service: None,
    last_diagnostic: "Ready",
    settings_loaded: false,
  }
}

///|
pub fn update(model : DesktopModel, message : Msg) -> DesktopModel {
  model.update(message)
}

///|
pub fn DesktopModel::update(self : DesktopModel, message : Msg) -> DesktopModel {
  let updated = self.apply(message)
  match message {
    SystemAppearanceCompleted(_)
    | FileImportCompleted(_)
    | UrlOpenCompleted(_)
    | DesktopSettingsLoaded(_)
    | DesktopSettingsSaved(_)
    | DesktopSettingsResetCompleted(_)
    | ResetDesktopSettings
    | ClockUpdated(_) => updated
    _ => { ..updated, last_diagnostic: message.diagnostic() }
  }
}

///|
fn DesktopModel::apply(self : DesktopModel, message : Msg) -> DesktopModel {
  match message {
    AdvanceBoot =>
      if self.phase == Boot {
        { ..self, phase: Locked, boot_ticks: self.boot_ticks + 1 }
      } else {
        self
      }
    ShowLogin =>
      if self.phase == Locked {
        { ..self, phase: Login, login_password: "", overlay: OverlayNone }
      } else {
        self
      }
    SubmitLogin(_) =>
      // Demo account: any password (even empty) signs in; the field keeps
      // the flow honest without blocking the demo.
      if self.phase == Login {
        { ..self, phase: Unlocked, overlay: OverlayNone, login_password: "" }
      } else {
        self
      }
    LoginPasswordChanged(value) => { ..self, login_password: value }
    SetLanguage(language) => { ..self, language, }
    LockDesktop => { ..self, phase: Locked, overlay: OverlayNone }
    OpenFinder => { ..self, overlay: OverlayNone }.open_or_focus(FinderApp)
    OpenSafari => { ..self, overlay: OverlayNone }.open_or_focus(SafariApp)
    CloseWindow => self.close_focused()
    MinimizeWindow => self.minimize_focused()
    ToggleMaximize => self.toggle_zoom_focused()
    MoveWindowBy(dx, dy) => self.move_focused_by(dx, dy)
    FocusWindow(id) =>
      match self.window_with_id(id) {
        Some(record) =>
          if record.state == MinimizedWindow {
            self
          } else {
            self.raise_window(id)
          }
        None => self
      }
    CloseWindowAt(id) => self.close_window(id)
    MinimizeWindowAt(id) => self.minimize_window(id)
    ToggleZoomAt(id) => self.toggle_zoom_window(id)
    ResizeWindowBy(id, width, height) => self.resize_window(id, width, height)
    MoveDesktopIcon(name, dx, dy) => self.move_icon_by(name, dx, dy)
    LoadDesktopSettings => self
    DesktopSettingsLoaded(result) => self.apply_settings_load(result)
    DesktopSettingsSaved(result) =>
      match result {
        Failure(error) => { ..self, last_diagnostic: error.message }
        _ => self
      }
    ResetDesktopSettings => self.reset_desktop_settings()
    DesktopSettingsResetCompleted(result) =>
      match result {
        Failure(error) => { ..self, last_diagnostic: error.message }
        _ => self
      }
    LaunchApp(app) => { ..self, overlay: OverlayNone }.open_or_focus(app)
    AddNote => self.add_note()
    SelectNote(index) => self.select_note(index)
    DeleteNote(index) => self.delete_note(index)
    NoteBodyChanged(body) => self.update_active_note_body(body)
    TerminalInputChanged(value) => { ..self, terminal_input: value }
    RunTerminalCommand => self.run_terminal_command()
    ClearTerminal =>
      { ..self, terminal_lines: [terminal_banner()], terminal_input: "" }
    ToggleMenu(menu) =>
      {
        ..self,
        overlay: if self.overlay == MenuBarMenu(menu) {
          OverlayNone
        } else {
          MenuBarMenu(menu)
        },
      }
    RunMenuCommand(command) =>
      match command {
        ToggleAppearance =>
          {
            ..self,
            appearance: if self.dark_mode {
              LightAppearance
            } else {
              DarkAppearance
            },
            dark_mode: !self.dark_mode,
            overlay: OverlayNone,
          }
        ShowAboutThisMac => { ..self, overlay: AboutThisMac }
        ShowSystemSettings => { ..self, overlay: SystemSettings }
        ShowAppStore => { ..self, overlay: AppStore }
        LockSession => { ..self, phase: Locked, overlay: OverlayNone }
        // "New Window" commands always spawn another instance (macOS File >
        // New Window), while "Bring … Forward" refocuses an existing one.
        OpenFinderWindow =>
          { ..self, overlay: OverlayNone }.create_window(FinderApp)
        OpenSafariWindow =>
          { ..self, overlay: OverlayNone }.create_window(SafariApp)
        BringFinderForward =>
          { ..self, overlay: OverlayNone }.open_or_focus(FinderApp)
        BringSafariForward =>
          { ..self, overlay: OverlayNone }.open_or_focus(SafariApp)
        OpenDocuments => self.visit_finder_location(Documents)
        OpenDownloads => self.visit_finder_location(Downloads)
        OpenLauncher => { ..self, overlay: Launcher }
        OpenNotificationCenter => { ..self, overlay: NotificationCenter }
        ShowFinderIconView =>
          { ..self, overlay: OverlayNone, finder_view_mode: IconView }.open_or_focus(
            FinderApp,
          )
        ShowFinderListView =>
          { ..self, overlay: OverlayNone, finder_view_mode: ListView }.open_or_focus(
            FinderApp,
          )
        CloseFocusedWindow => { ..self, overlay: OverlayNone }.close_focused()
        MinimizeFocusedWindow =>
          { ..self, overlay: OverlayNone }.minimize_focused()
        ZoomFocusedWindow =>
          { ..self, overlay: OverlayNone }.toggle_zoom_focused()
        ResetDesktopSettingsCommand =>
          { ..self, overlay: OverlayNone }.reset_desktop_settings()
        LogOutSession =>
          { ..self, phase: Login, login_password: "", overlay: OverlayNone }
        ToggleLanguageCommand =>
          { ..self, overlay: OverlayNone, language: self.language.other() }
      }
    ToggleLauncher =>
      {
        ..self,
        overlay: if self.overlay == Launcher {
          OverlayNone
        } else {
          Launcher
        },
      }
    ToggleControlCenter =>
      {
        ..self,
        overlay: if self.overlay == ControlCenter {
          OverlayNone
        } else {
          ControlCenter
        },
      }
    ToggleNotificationCenter =>
      {
        ..self,
        overlay: if self.overlay == NotificationCenter {
          OverlayNone
        } else {
          NotificationCenter
        },
      }
    ToggleSpotlight =>
      {
        ..self,
        spotlight_query: "",
        overlay: if self.overlay == Spotlight {
          OverlayNone
        } else {
          Spotlight
        },
      }
    DismissOverlay => { ..self, overlay: OverlayNone }
    SelectFinderLocation(location) => self.visit_finder_location(location)
    GoFinderBack =>
      if self.can_go_finder_back() {
        self.restore_finder_history(self.finder_history_index - 1)
      } else {
        self
      }
    GoFinderForward =>
      if self.can_go_finder_forward() {
        self.restore_finder_history(self.finder_history_index + 1)
      } else {
        self
      }
    SelectFinderView(view_mode) => { ..self, finder_view_mode: view_mode }
    FinderQueryChanged(value) => { ..self, finder_query: value }
    SelectFinderItem(value) => { ..self, selected_file: value }
    LauncherQueryChanged(value) => { ..self, launcher_query: value }
    LauncherTabSelected(tab) => { ..self, launcher_tab: tab }
    SpotlightQueryChanged(value) => { ..self, spotlight_query: value }
    BrowserQueryChanged(value) => { ..self, browser_query: value }
    SubmitBrowserQuery =>
      {
        ..self,
        browser_page: if self.browser_query == "" {
          StartPage
        } else {
          SearchResults(self.browser_query)
        },
      }
    ShowBrowserStartPage =>
      { ..self, browser_query: "", browser_page: StartPage }
    NewBrowserTab => {
      let tabs = self.browser_tab_titles
      let updated : Array[String] = []
      for t in tabs {
        updated.push(t)
      }
      updated.push("Start Page")
      { ..self, browser_tab_titles: updated, browser_active_tab: tabs.length() }
    }
    SelectBrowserTab(index) => { ..self, browser_active_tab: index }
    CloseBrowserTab(index) => {
      let tabs = self.browser_tab_titles
      if tabs.length() <= 1 {
        self
      } else {
        let filtered : Array[String] = []
        for i in 0..<tabs.length() {
          if i != index {
            filtered.push(tabs[i])
          }
        }
        let active = if self.browser_active_tab >= filtered.length() {
          filtered.length() - 1
        } else if self.browser_active_tab > index {
          self.browser_active_tab - 1
        } else {
          self.browser_active_tab
        }
        { ..self, browser_tab_titles: filtered, browser_active_tab: active }
      }
    }
    OpenFavorite(value) =>
      {
        ..self,
        overlay: OverlayNone,
        browser_query: value,
        browser_page: SearchResults(value),
        pending_service: Some(UrlOpenService),
      }.open_or_focus(SafariApp)
    ToggleDarkMode =>
      {
        ..self,
        appearance: if self.dark_mode {
          LightAppearance
        } else {
          DarkAppearance
        },
        dark_mode: !self.dark_mode,
      }
    UseSystemAppearance =>
      {
        ..self,
        appearance: SystemAppearance,
        pending_service: Some(SystemAppearanceService),
      }
    RequestFileImport =>
      {
        ..self,
        pending_service: Some(FileImportService),
        last_diagnostic: "Opening file dialog…",
      }
    SystemAppearanceCompleted(result) =>
      self.apply_system_appearance_completion(result)
    FileImportCompleted(result) => self.apply_file_import_completion(result)
    UrlOpenCompleted(result) => self.apply_url_open_completion(result)
    ClockUpdated(clock) => {
      let model = { ..self, clock, }
      if model.phase == Boot && model.boot_ticks >= 1 {
        model.apply(AdvanceBoot)
      } else if model.phase == Boot {
        { ..model, boot_ticks: model.boot_ticks + 1 }
      } else {
        model
      }
    }
    WifiChanged(value) => { ..self, wifi_enabled: value }
    BluetoothChanged(value) => { ..self, bluetooth_enabled: value }
    LowPowerModeChanged(value) => { ..self, low_power_mode: value }
    BrightnessChanged(value) => { ..self, brightness: value.max(0.0).min(1.0) }
    VolumeChanged(value) => { ..self, volume: value.max(0.0).min(1.0) }
    MarkNotificationsRead => { ..self, notifications_read: true }
    CompleteTask(task) =>
      match task {
        ReviewDesktop => { ..self, first_task_done: true }
        ReplyToMaya => { ..self, second_task_done: true }
        PlanTahoePhotos => { ..self, third_task_done: true }
      }
  }
}

///|
fn DesktopModel::with_diagnostic(
  self : DesktopModel,
  diagnostic : String,
) -> DesktopModel {
  { ..self, last_diagnostic: diagnostic }
}

///|
/// Apply a loaded settings payload. Corrupt or unsupported data degrades to
/// defaults with a diagnostic instead of failing the session.
fn DesktopModel::apply_settings_load(
  self : DesktopModel,
  result : @services.ServiceTaskResult[String?],
) -> DesktopModel {
  let loaded = { ..self, settings_loaded: true }
  match result {
    Success(Some(text)) =>
      match decode_desktop_snapshot(text) {
        Some(snapshot) =>
          loaded
          .restore_snapshot(snapshot)
          .with_diagnostic(
            "Restored desktop layout (v\{snapshot.schema_version})",
          )
        None =>
          loaded.with_diagnostic(
            "Stored desktop data was unusable; using defaults",
          )
      }
    Success(None) =>
      loaded.with_diagnostic("Starting with default desktop settings")
    Failure(error) => loaded.with_diagnostic(error.message)
    Cancelled => loaded.with_diagnostic("Desktop settings load cancelled")
  }
}

///|
/// Restore factory settings for everything the snapshot persists. The
/// wallpaper source and clock stay as launched; the storage entry itself is
/// removed by the effect side so stale payloads never resurrect.
fn DesktopModel::reset_desktop_settings(self : DesktopModel) -> DesktopModel {
  let fresh_window : WindowRecord = {
    id: { app: FinderApp, serial: 1 },
    state: NormalWindow,
    bounds: WindowBounds::default(),
    z_order: 1,
  }
  {
    ..self,
    dark_mode: false,
    appearance: SystemAppearance,
    volume: 0.68,
    brightness: 0.82,
    wifi_enabled: true,
    bluetooth_enabled: true,
    low_power_mode: false,
    windows: [fresh_window],
    next_window_serial: 2,
    next_z_order: 2,
    imported_files: [],
    icon_placements: [],
    notes: [default_note_body()],
    active_note: 0,
    terminal_lines: [terminal_banner()],
    terminal_input: "",
    finder_location: Documents,
    finder_history: [Documents],
    finder_history_index: 0,
    last_diagnostic: "Restored default desktop settings",
  }
}

///|
fn default_note_body() -> String {
  "Welcome to Mo Notes\nCapture quick thoughts; they persist with the desktop snapshot."
}

///|
fn terminal_banner() -> String {
  "Mo Terminal - type help for available commands"
}

///|
fn DesktopModel::add_note(self : DesktopModel) -> DesktopModel {
  let notes : Array[String] = ["New note"]
  for body in self.notes {
    notes.push(body)
  }
  { ..self, notes, active_note: 0 }
}

///|
fn DesktopModel::select_note(self : DesktopModel, index : Int) -> DesktopModel {
  if index >= 0 && index < self.notes.length() {
    { ..self, active_note: index }
  } else {
    self
  }
}

///|
fn DesktopModel::delete_note(self : DesktopModel, index : Int) -> DesktopModel {
  if index < 0 || index >= self.notes.length() {
    return self
  }
  let notes : Array[String] = []
  for i, body in self.notes {
    if i != index {
      notes.push(body)
    }
  }
  // Keep the selection clamped to the surviving notes.
  let active = if notes.is_empty() {
    0
  } else if index < self.active_note {
    self.active_note - 1
  } else if self.active_note >= notes.length() {
    notes.length() - 1
  } else {
    self.active_note
  }
  { ..self, notes, active_note: active }
}

///|
fn DesktopModel::update_active_note_body(
  self : DesktopModel,
  body : String,
) -> DesktopModel {
  let updated : Array[String] = []
  for i, existing in self.notes {
    if i == self.active_note {
      updated.push(body)
    } else {
      updated.push(existing)
    }
  }
  { ..self, notes: updated }
}

///|
pub fn DesktopModel::note_title(self : DesktopModel, index : Int) -> String {
  match self.notes.get(index) {
    Some(body) => note_first_line(body)
    None => "New note"
  }
}

///|
pub fn DesktopModel::active_note_body(self : DesktopModel) -> String {
  match self.notes.get(self.active_note) {
    Some(body) => body
    None => ""
  }
}

///|
fn note_first_line(body : String) -> String {
  match body.find("\n") {
    Some(index) => {
      let line = body[:index].to_owned()
      if line.is_empty() {
        "New note"
      } else {
        line
      }
    }
    None => if body.is_empty() { "New note" } else { body }
  }
}

///|
fn DesktopModel::run_terminal_command(self : DesktopModel) -> DesktopModel {
  let input = self.terminal_input.trim(chars=" ").to_owned()
  if input.is_empty() {
    return self
  }
  let prompt = "mo> " + input
  let output : Array[String] = match input {
    "help" =>
      [
        "commands: help, apps, open <finder|safari|notes|terminal>, echo <text>, date, clear",
      ]
    "apps" => {
      let names : Array[String] = []
      for entry in app_registry() {
        names.push(entry.label)
      }
      ["installed: " + names.join(", ")]
    }
    "date" =>
      [
        desktop_clock_lock_date(self.clock) +
        " - " +
        desktop_clock_time(self.clock),
      ]
    "clear" => return { ..self, terminal_lines: [], terminal_input: "" }
    _ =>
      if input.has_prefix("echo ") {
        [input[5:].to_owned()]
      } else if input.has_prefix("open ") {
        let target = input[5:].trim(chars=" ").to_owned()
        match target {
          "finder" | "safari" | "notes" | "terminal" =>
            return self.launch_from_terminal(target)
          _ => ["open: unknown app '" + target + "'"]
        }
      } else {
        [input + ": command not found"]
      }
  }
  let lines : Array[String] = []
  for line in self.terminal_lines {
    lines.push(line)
  }
  lines.push(prompt)
  for line in output {
    lines.push(line)
  }
  { ..self, terminal_lines: lines, terminal_input: "" }
}

///|
fn DesktopModel::launch_from_terminal(
  self : DesktopModel,
  target : String,
) -> DesktopModel {
  let app = match target {
    "finder" => FinderApp
    "safari" => SafariApp
    "notes" => NotesApp
    _ => TerminalApp
  }
  let lines : Array[String] = []
  for line in self.terminal_lines {
    lines.push(line)
  }
  lines.push("mo> open " + target)
  lines.push("Launching " + app.label())
  { ..self, terminal_lines: lines, terminal_input: "" }.open_or_focus(app)
}

///|
pub fn DesktopModel::remaining_tasks(self : DesktopModel) -> Int {
  let first = if self.first_task_done { 0 } else { 1 }
  let second = if self.second_task_done { 0 } else { 1 }
  let third = if self.third_task_done { 0 } else { 1 }
  first + second + third
}

///|
pub fn DesktopModel::task_done(self : DesktopModel, task : DesktopTask) -> Bool {
  match task {
    ReviewDesktop => self.first_task_done
    ReplyToMaya => self.second_task_done
    PlanTahoePhotos => self.third_task_done
  }
}

///|
fn DesktopModel::apply_system_appearance_completion(
  self : DesktopModel,
  result : @services.ServiceTaskResult[@state.ColorScheme],
) -> DesktopModel {
  if self.pending_service != Some(SystemAppearanceService) {
    return self
  }
  match result {
    Success(scheme) =>
      {
        ..self,
        pending_service: None,
        dark_mode: if self.appearance == SystemAppearance {
          scheme == @state.ColorScheme::Dark
        } else {
          self.dark_mode
        },
        last_diagnostic: "Updated system appearance",
      }
    Failure(error) =>
      { ..self, pending_service: None, last_diagnostic: error.message }
    Cancelled =>
      {
        ..self,
        pending_service: None,
        last_diagnostic: "System appearance request cancelled",
      }
  }
}

///|
fn DesktopModel::apply_file_import_completion(
  self : DesktopModel,
  result : @services.ServiceTaskResult[Array[String]],
) -> DesktopModel {
  if self.pending_service != Some(FileImportService) {
    return self
  }
  match result {
    Success(paths) => {
      let imported_files = self.imported_files.copy()
      for path in paths {
        if !imported_files.contains(path) {
          imported_files.push(path)
        }
      }
      let navigated = self.visit_finder_location(Documents)
      {
        ..navigated,
        imported_files,
        pending_service: None,
        last_diagnostic: if paths.is_empty() {
          "File import cancelled"
        } else {
          "Imported \{paths.length()} file(s)"
        },
      }
    }
    Failure(error) =>
      { ..self, pending_service: None, last_diagnostic: error.message }
    Cancelled =>
      {
        ..self,
        pending_service: None,
        last_diagnostic: "File import cancelled",
      }
  }
}

///|
fn DesktopModel::apply_url_open_completion(
  self : DesktopModel,
  result : @services.ServiceTaskResult[Unit],
) -> DesktopModel {
  if self.pending_service != Some(UrlOpenService) {
    return self
  }
  match result {
    Success(_) =>
      { ..self, pending_service: None, last_diagnostic: "Opened URL with host" }
    Failure(error) =>
      { ..self, pending_service: None, last_diagnostic: error.message }
    Cancelled =>
      { ..self, pending_service: None, last_diagnostic: "URL open cancelled" }
  }
}

///|
fn DesktopModel::visit_finder_location(
  self : DesktopModel,
  location : FinderLocation,
) -> DesktopModel {
  if self.finder_location == location {
    return { ..self, overlay: OverlayNone, finder_query: "", selected_file: "" }.open_or_focus(
      FinderApp,
    )
  }
  let history : Array[FinderLocation] = []
  let keep_count = self.finder_history_index + 1
  for index, visited in self.finder_history {
    if index < keep_count {
      history.push(visited)
    }
  }
  history.push(location)
  {
    ..self,
    overlay: OverlayNone,
    finder_location: location,
    finder_history: history,
    finder_history_index: history.length() - 1,
    finder_query: "",
    selected_file: "",
  }.open_or_focus(FinderApp)
}

///|
fn DesktopModel::restore_finder_history(
  self : DesktopModel,
  index : Int,
) -> DesktopModel {
  match self.finder_history.get(index) {
    Some(location) =>
      {
        ..self,
        overlay: OverlayNone,
        finder_location: location,
        finder_history_index: index,
        finder_query: "",
        selected_file: "",
      }.open_or_focus(FinderApp)
    None => self
  }
}

///|
fn DesktopModel::can_go_finder_back(self : DesktopModel) -> Bool {
  self.finder_history_index > 0
}

///|
fn DesktopModel::can_go_finder_forward(self : DesktopModel) -> Bool {
  self.finder_history_index + 1 < self.finder_history.length()
}

///|
fn Msg::diagnostic(self : Msg) -> String {
  match self {
    AdvanceBoot => "Finished booting"
    ShowLogin => "Showing sign-in"
    SubmitLogin(_) => "Signed in"
    LoginPasswordChanged(_) => "Typed password"
    SetLanguage(_) => "Changed language"
    LockDesktop => "Locked desktop"
    OpenFinder => "Opened Finder"
    OpenSafari => "Opened Safari"
    CloseWindow => "Closed focused window"
    MinimizeWindow => "Minimized focused window"
    ToggleMaximize => "Toggled focused window zoom"
    MoveWindowBy(_, _) => "Moved focused window"
    FocusWindow(_) => "Focused window"
    CloseWindowAt(_) => "Closed window"
    MinimizeWindowAt(_) => "Minimized window"
    ToggleZoomAt(_) => "Toggled window zoom"
    ResizeWindowBy(_, _, _) => "Resized window"
    MoveDesktopIcon(_, _, _) => "Moved desktop icon"
    LoadDesktopSettings => "Requested desktop settings"
    DesktopSettingsLoaded(_) => "Received desktop settings"
    DesktopSettingsSaved(_) => "Saved desktop settings"
    ResetDesktopSettings => "Reset desktop settings"
    DesktopSettingsResetCompleted(_) => "Received settings reset completion"
    LaunchApp(_) => "Launched app"
    AddNote => "Created note"
    SelectNote(_) => "Selected note"
    DeleteNote(_) => "Deleted note"
    NoteBodyChanged(_) => "Edited note"
    TerminalInputChanged(_) => "Typed terminal command"
    RunTerminalCommand => "Ran terminal command"
    ClearTerminal => "Cleared terminal"
    ToggleMenu(_) => "Toggled menu bar menu"
    RunMenuCommand(command) =>
      match command {
        ToggleAppearance => "Toggled appearance"
        ShowAboutThisMac => "Opened About This Mac"
        ShowSystemSettings => "Opened System Settings"
        ShowAppStore => "Opened App Store"
        LockSession => "Locked desktop session"
        OpenFinderWindow => "Opened a new Finder window"
        OpenSafariWindow => "Opened a new Safari window"
        BringFinderForward => "Brought Finder forward"
        BringSafariForward => "Brought Safari forward"
        OpenDocuments => "Opened Documents"
        OpenDownloads => "Opened Downloads"
        OpenLauncher => "Opened app launcher"
        OpenNotificationCenter => "Opened Notification Center"
        ShowFinderIconView => "Changed Finder to icon view"
        ShowFinderListView => "Changed Finder to list view"
        CloseFocusedWindow => "Closed focused window"
        MinimizeFocusedWindow => "Minimized focused window"
        ZoomFocusedWindow => "Toggled focused window zoom"
        ResetDesktopSettingsCommand => "Restored default desktop settings"
        LogOutSession => "Logged out"
        ToggleLanguageCommand => "Changed language"
      }
    ToggleLauncher => "Toggled app launcher"
    ToggleControlCenter => "Toggled Control Center"
    ToggleNotificationCenter => "Toggled Notification Center"
    DismissOverlay => "Dismissed active overlay"
    SelectFinderLocation(_) => "Changed Finder location"
    GoFinderBack => "Navigated Finder back"
    GoFinderForward => "Navigated Finder forward"
    SelectFinderView(_) => "Changed Finder view"
    FinderQueryChanged(_) => "Changed Finder search"
    SelectFinderItem(_) => "Selected Finder item"
    LauncherQueryChanged(_) => "Changed launcher search"
    LauncherTabSelected(_) => "Changed launcher tab"
    SpotlightQueryChanged(_) => "Changed Spotlight search"
    ToggleSpotlight => "Toggled Spotlight"
    BrowserQueryChanged(_) => "Changed browser search"
    SubmitBrowserQuery => "Submitted browser search"
    ShowBrowserStartPage => "Opened browser start page"
    NewBrowserTab => "Created new browser tab"
    SelectBrowserTab(_) => "Selected browser tab"
    CloseBrowserTab(_) => "Closed browser tab"
    OpenFavorite(_) => "Opened browser favorite"
    ToggleDarkMode => "Toggled dark mode"
    UseSystemAppearance => "Requested system appearance"
    RequestFileImport => "Requested file import"
    SystemAppearanceCompleted(_) => "Received system appearance completion"
    FileImportCompleted(_) => "Received file import completion"
    UrlOpenCompleted(_) => "Received URL open completion"
    ClockUpdated(_) => "Updated live clock"
    WifiChanged(_) => "Changed Wi-Fi setting"
    BluetoothChanged(_) => "Changed Bluetooth setting"
    LowPowerModeChanged(_) => "Changed low power mode"
    BrightnessChanged(_) => "Changed brightness"
    VolumeChanged(_) => "Changed volume"
    MarkNotificationsRead => "Marked notifications read"
    CompleteTask(_) => "Completed task"
  }
}

///|
fn FinderLocation::id(self : FinderLocation) -> String {
  match self {
    Documents => "documents"
    Applications => "applications"
    Downloads => "downloads"
  }
}

///|
fn FinderLocation::label(self : FinderLocation) -> String {
  match self {
    Documents => "Documents"
    Applications => "Applications"
    Downloads => "Downloads"
  }
}

///|
fn LauncherTab::id(self : LauncherTab) -> String {
  match self {
    Apps => "apps"
    Actions => "actions"
  }
}

///|
/// Name shown in the menu bar: the focused app, or "Desktop" when no
/// window holds focus.
pub fn DesktopModel::active_app_label(self : DesktopModel) -> String {
  match self.focused_window() {
    Some(record) => record.id.app.label()
    None => "Desktop"
  }
}
