///|
pub(all) enum SessionPhase {
  Locked
  Unlocked
} derive(Eq, Debug)

///|
pub(all) enum DesktopWindow {
  NoWindow
  Finder
  Safari
} derive(Eq, Debug)

///|
pub(all) enum DesktopOverlay {
  OverlayNone
  MenuBarMenu(DesktopMenu)
  Launcher
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
  OpenDocuments
  OpenDownloads
  OpenLauncher
  OpenNotificationCenter
  ShowFinderIconView
  ShowFinderListView
  CloseFocusedWindow
  MinimizeFocusedWindow
  ZoomFocusedWindow
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
fn default_desktop_clock() -> @host.HostWallClock {
  @host.HostWallClock::new(2026, 7, 19, 0, 9, 41)
}

///|
pub(all) struct DesktopModel {
  wallpaper_source : String
  phase : SessionPhase
  active_window : DesktopWindow
  overlay : DesktopOverlay
  appearance : AppearanceMode
  dark_mode : Bool
  clock : @host.HostWallClock
  window_maximized : Bool
  window_offset_x : Double
  window_offset_y : Double
  finder_location : FinderLocation
  finder_view_mode : FinderViewMode
  finder_query : String
  selected_file : String
  launcher_query : String
  launcher_tab : LauncherTab
  browser_query : String
  browser_page : BrowserPage
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
  pending_service : @host.HostServiceRequestId?
  last_diagnostic : String
}

///|
pub(all) enum Msg {
  UnlockDesktop
  LockDesktop
  OpenFinder
  OpenSafari
  CloseWindow
  MinimizeWindow
  ToggleMaximize
  MoveWindowBy(Double, Double)
  ToggleMenu(DesktopMenu)
  RunMenuCommand(MenuCommand)
  ToggleLauncher
  ToggleControlCenter
  ToggleNotificationCenter
  DismissOverlay
  SelectFinderLocation(FinderLocation)
  SelectFinderView(FinderViewMode)
  FinderQueryChanged(String)
  SelectFinderItem(String)
  LauncherQueryChanged(String)
  LauncherTabSelected(LauncherTab)
  BrowserQueryChanged(String)
  SubmitBrowserQuery
  ShowBrowserStartPage
  OpenFavorite(String)
  ToggleDarkMode
  UseSystemAppearance
  RequestFileImport
  HostCompleted(@host.HostCompletedServiceResponse)
  ClockUpdated(@host.HostWallClock)
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
  clock? : @host.HostWallClock = default_desktop_clock(),
) -> DesktopModel {
  {
    wallpaper_source,
    phase: Locked,
    active_window: Finder,
    overlay: OverlayNone,
    appearance: SystemAppearance,
    dark_mode: false,
    clock,
    window_maximized: false,
    window_offset_x: 0.0,
    window_offset_y: 0.0,
    finder_location: Documents,
    finder_view_mode: IconView,
    finder_query: "",
    selected_file: "",
    launcher_query: "",
    launcher_tab: Apps,
    browser_query: "",
    browser_page: StartPage,
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
    pending_service: None,
    last_diagnostic: "Ready",
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
    HostCompleted(_) | ClockUpdated(_) => updated
    _ => { ..updated, last_diagnostic: message.diagnostic() }
  }
}

///|
fn DesktopModel::apply(self : DesktopModel, message : Msg) -> DesktopModel {
  match message {
    UnlockDesktop =>
      {
        ..self,
        phase: Unlocked,
        active_window: Finder,
        overlay: OverlayNone,
        window_offset_x: 0.0,
        window_offset_y: 0.0,
      }
    LockDesktop =>
      {
        ..self,
        phase: Locked,
        overlay: OverlayNone,
        window_maximized: false,
        window_offset_x: 0.0,
        window_offset_y: 0.0,
      }
    OpenFinder =>
      {
        ..self,
        active_window: Finder,
        overlay: OverlayNone,
        window_maximized: false,
      }
    OpenSafari =>
      {
        ..self,
        active_window: Safari,
        overlay: OverlayNone,
        window_maximized: false,
      }
    CloseWindow | MinimizeWindow =>
      { ..self, active_window: NoWindow, window_maximized: false }
    ToggleMaximize =>
      if self.active_window == NoWindow {
        self
      } else {
        { ..self, window_maximized: !self.window_maximized }
      }
    MoveWindowBy(dx, dy) =>
      if self.active_window == NoWindow {
        self
      } else {
        {
          ..self
          // A title-bar drag from a zoomed macOS window restores it before
          // applying the gesture. Retaining the previous offset makes zoom /
          // restore stable rather than snapping every window back to center.
          ,
          window_maximized: false,
          // Keep the title bar in reach while allowing a deliberate, natural
          // desktop-scale reposition instead of a rigid centered mock window.
          window_offset_x: (self.window_offset_x + dx).max(-360.0).min(360.0),
          window_offset_y: (self.window_offset_y + dy).max(-220.0).min(220.0),
        }
      }
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
        LockSession =>
          {
            ..self,
            phase: Locked,
            overlay: OverlayNone,
            window_maximized: false,
            window_offset_x: 0.0,
            window_offset_y: 0.0,
          }
        OpenFinderWindow =>
          {
            ..self,
            active_window: Finder,
            overlay: OverlayNone,
            window_maximized: false,
          }
        OpenSafariWindow =>
          {
            ..self,
            active_window: Safari,
            overlay: OverlayNone,
            window_maximized: false,
          }
        OpenDocuments =>
          {
            ..self,
            active_window: Finder,
            overlay: OverlayNone,
            finder_location: Documents,
            finder_query: "",
            selected_file: "",
          }
        OpenDownloads =>
          {
            ..self,
            active_window: Finder,
            overlay: OverlayNone,
            finder_location: Downloads,
            finder_query: "",
            selected_file: "",
          }
        OpenLauncher => { ..self, overlay: Launcher }
        OpenNotificationCenter => { ..self, overlay: NotificationCenter }
        ShowFinderIconView =>
          {
            ..self,
            active_window: Finder,
            overlay: OverlayNone,
            finder_view_mode: IconView,
          }
        ShowFinderListView =>
          {
            ..self,
            active_window: Finder,
            overlay: OverlayNone,
            finder_view_mode: ListView,
          }
        CloseFocusedWindow =>
          {
            ..self,
            active_window: NoWindow,
            overlay: OverlayNone,
            window_maximized: false,
          }
        MinimizeFocusedWindow =>
          {
            ..self,
            active_window: NoWindow,
            overlay: OverlayNone,
            window_maximized: false,
          }
        ZoomFocusedWindow =>
          {
            ..self,
            overlay: OverlayNone,
            window_maximized: if self.active_window == NoWindow {
              false
            } else {
              !self.window_maximized
            },
          }
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
    DismissOverlay => { ..self, overlay: OverlayNone }
    SelectFinderLocation(location) =>
      {
        ..self,
        active_window: Finder,
        overlay: OverlayNone,
        finder_location: location,
        finder_query: "",
        selected_file: "",
      }
    SelectFinderView(view_mode) => { ..self, finder_view_mode: view_mode }
    FinderQueryChanged(value) => { ..self, finder_query: value }
    SelectFinderItem(value) => { ..self, selected_file: value }
    LauncherQueryChanged(value) => { ..self, launcher_query: value }
    LauncherTabSelected(tab) => { ..self, launcher_tab: tab }
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
    OpenFavorite(value) =>
      {
        ..self,
        active_window: Safari,
        overlay: OverlayNone,
        browser_query: value,
        browser_page: SearchResults(value),
      }
    ToggleDarkMode =>
      {
        ..self,
        appearance: if self.dark_mode { LightAppearance } else { DarkAppearance },
        dark_mode: !self.dark_mode,
      }
    UseSystemAppearance => { ..self, appearance: SystemAppearance }
    RequestFileImport => { ..self, last_diagnostic: "Opening file dialog…" }
    HostCompleted(completion) => self.apply_host_completion(completion)
    ClockUpdated(clock) => { ..self, clock }
    WifiChanged(value) => { ..self, wifi_enabled: value }
    BluetoothChanged(value) => { ..self, bluetooth_enabled: value }
    LowPowerModeChanged(value) => { ..self, low_power_mode: value }
    BrightnessChanged(value) =>
      { ..self, brightness: value.max(0.0).min(1.0) }
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
fn DesktopModel::apply_host_completion(
  self : DesktopModel,
  completion : @host.HostCompletedServiceResponse,
) -> DesktopModel {
  match completion.response {
    @host.HostServiceResponse::Pending(id) =>
      {
        ..self,
        pending_service: Some(id),
        last_diagnostic: "Waiting for host service…",
      }
    @host.HostServiceResponse::SystemTheme(scheme) =>
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
    @host.HostServiceResponse::FileDialogSelection(paths) => {
      let imported_files = self.imported_files.copy()
      for path in paths {
        if !imported_files.contains(path) {
          imported_files.push(path)
        }
      }
      {
        ..self,
        imported_files,
        pending_service: None,
        active_window: Finder,
        overlay: OverlayNone,
        finder_location: Documents,
        last_diagnostic: if paths.is_empty() {
          "File import cancelled"
        } else {
          "Imported \{paths.length()} file(s)"
        },
      }
    }
    @host.HostServiceResponse::UrlOpened =>
      { ..self, pending_service: None, last_diagnostic: "Opened URL with host" }
    @host.HostServiceResponse::Unavailable(message) =>
      { ..self, pending_service: None, last_diagnostic: message }
    _ => { ..self, pending_service: None, last_diagnostic: "Host service completed" }
  }
}

///|
fn Msg::diagnostic(self : Msg) -> String {
  match self {
    UnlockDesktop => "Unlocked desktop"
    LockDesktop => "Locked desktop"
    OpenFinder => "Opened Finder"
    OpenSafari => "Opened Safari"
    CloseWindow => "Closed focused window"
    MinimizeWindow => "Minimized focused window"
    ToggleMaximize => "Toggled focused window zoom"
    MoveWindowBy(_, _) => "Moved focused window"
    ToggleMenu(_) => "Toggled menu bar menu"
    RunMenuCommand(command) =>
      match command {
        ToggleAppearance => "Toggled appearance"
        ShowAboutThisMac => "Opened About This Mac"
        ShowSystemSettings => "Opened System Settings"
        ShowAppStore => "Opened App Store"
        LockSession => "Locked desktop session"
        OpenFinderWindow => "Opened Finder window"
        OpenSafariWindow => "Opened Safari window"
        OpenDocuments => "Opened Documents"
        OpenDownloads => "Opened Downloads"
        OpenLauncher => "Opened app launcher"
        OpenNotificationCenter => "Opened Notification Center"
        ShowFinderIconView => "Changed Finder to icon view"
        ShowFinderListView => "Changed Finder to list view"
        CloseFocusedWindow => "Closed focused window"
        MinimizeFocusedWindow => "Minimized focused window"
        ZoomFocusedWindow => "Toggled focused window zoom"
      }
    ToggleLauncher => "Toggled app launcher"
    ToggleControlCenter => "Toggled Control Center"
    ToggleNotificationCenter => "Toggled Notification Center"
    DismissOverlay => "Dismissed active overlay"
    SelectFinderLocation(_) => "Changed Finder location"
    SelectFinderView(_) => "Changed Finder view"
    FinderQueryChanged(_) => "Changed Finder search"
    SelectFinderItem(_) => "Selected Finder item"
    LauncherQueryChanged(_) => "Changed launcher search"
    LauncherTabSelected(_) => "Changed launcher tab"
    BrowserQueryChanged(_) => "Changed browser search"
    SubmitBrowserQuery => "Submitted browser search"
    ShowBrowserStartPage => "Opened browser start page"
    OpenFavorite(_) => "Opened browser favorite"
    ToggleDarkMode => "Toggled dark mode"
    UseSystemAppearance => "Requested system appearance"
    RequestFileImport => "Requested file import"
    HostCompleted(_) => "Received host service completion"
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
fn DesktopModel::active_app_label(self : DesktopModel) -> String {
  match self.active_window {
    NoWindow => "Desktop"
    Finder => "Finder"
    Safari => "Safari"
  }
}
