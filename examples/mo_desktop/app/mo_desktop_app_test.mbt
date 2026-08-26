///|
test "desktop session opens windows and keeps overlays exclusive" {
  let model = DesktopModel::new()
  debug_inspect(model.phase, content="Boot")
  // Boot advances on the clock tick or an explicit tap.
  let booted = update(model, AdvanceBoot)
  debug_inspect(booted.phase, content="Locked")
  let at_login = update(booted, ShowLogin)
  debug_inspect(at_login.phase, content="Login")
  let unlocked = update(at_login, SubmitLogin("demo"))
  debug_inspect(unlocked.phase, content="Unlocked")
  debug_inspect(
    unlocked.focused_window().map(record => record.id.app),
    content="Some(FinderApp)",
  )
  let launcher = update(unlocked, ToggleLauncher)
  debug_inspect(launcher.overlay, content="Launcher")
  let controls = update(launcher, ToggleControlCenter)
  debug_inspect(controls.overlay, content="ControlCenter")
  let safari = update(controls, OpenSafari)
  debug_inspect(safari.overlay, content="OverlayNone")
  debug_inspect(
    safari.focused_window().map(record => record.id.app),
    content="Some(SafariApp)",
  )
  inspect(update(safari, ToggleDarkMode).dark_mode, content="true")
}

///|
test "finder and browser interactions update controlled state" {
  let finder = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(SelectFinderLocation(Downloads))
    .update(SelectFinderView(ListView))
    .update(FinderQueryChanged("Tahoe"))
    .update(SelectFinderItem("Tahoe Photos"))
  debug_inspect(finder.finder_location, content="Downloads")
  debug_inspect(finder.finder_view_mode, content="ListView")
  inspect(finder.finder_query, content="Tahoe")
  inspect(finder.selected_file, content="Tahoe Photos")
  let browser = finder
    .update(OpenSafari)
    .update(BrowserQueryChanged("MoonBit"))
    .update(SubmitBrowserQuery)
  debug_inspect(browser.browser_page, content="SearchResults(\"MoonBit\")")
  debug_inspect(
    browser.update(ShowBrowserStartPage).browser_page,
    content="StartPage",
  )
}

///|
test "finder history restores locations and drops the forward branch" {
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(SelectFinderLocation(Downloads))
    .update(SelectFinderLocation(Applications))
  debug_inspect(
    model.finder_history,
    content="[Documents, Downloads, Applications]",
  )
  inspect(model.finder_history_index, content="2")
  let back = model.update(GoFinderBack)
  debug_inspect(back.finder_location, content="Downloads")
  inspect(back.finder_history_index, content="1")
  debug_inspect(
    back.update(GoFinderForward).finder_location,
    content="Applications",
  )
  let branch = back.update(SelectFinderLocation(Documents))
  debug_inspect(
    branch.finder_history,
    content="[Documents, Downloads, Documents]",
  )
  inspect(branch.finder_history_index, content="2")
  debug_inspect(
    branch.update(GoFinderBack).finder_location,
    content="Downloads",
  )
}

///|
test "typed service completions retain imported files and system appearance" {
  let waiting = DesktopModel::new().update(RequestFileImport)
  debug_inspect(waiting.pending_service, content="Some(FileImportService)")
  let imported = waiting.update(
    FileImportCompleted(
      @services.ServiceTaskResult::Success([
        "/tmp/notes.md", "/tmp/notes.md", "/tmp/tahoe.jpg",
      ]),
    ),
  )
  inspect(imported.imported_files.length(), content="2")
  inspect(imported.last_diagnostic, content="Imported 3 file(s)")
  let dark = imported
    .update(UseSystemAppearance)
    .update(
      SystemAppearanceCompleted(
        @services.ServiceTaskResult::Success(@state.ColorScheme::Dark),
      ),
    )
  assert_true(dark.dark_mode)
}

///|
test "service failure cancellation and stale completion stay typed" {
  let failed = DesktopModel::new()
    .update(RequestFileImport)
    .update(
      FileImportCompleted(
        @services.ServiceTaskResult::Failure(
          @services.ServiceError::new(
            code="unavailable",
            message="file picker unavailable",
          ),
        ),
      ),
    )
  inspect(failed.last_diagnostic, content="file picker unavailable")
  assert_true(failed.pending_service is None)
  let cancelled = DesktopModel::new()
    .update(OpenFavorite("moonbitlang.com"))
    .update(UrlOpenCompleted(@services.ServiceTaskResult::Cancelled))
  inspect(cancelled.last_diagnostic, content="URL open cancelled")
  let waiting = DesktopModel::new().update(RequestFileImport)
  let stale = waiting.update(
    SystemAppearanceCompleted(
      @services.ServiceTaskResult::Success(@state.ColorScheme::Dark),
    ),
  )
  assert_false(stale.dark_mode)
  debug_inspect(stale.pending_service, content="Some(FileImportService)")
}

///|
test "control center values and notification tasks are model owned" {
  let model = DesktopModel::new()
    .update(WifiChanged(false))
    .update(BluetoothChanged(false))
    .update(BrightnessChanged(0.55))
    .update(VolumeChanged(0.25))
    .update(LowPowerModeChanged(true))
    .update(CompleteTask(ReviewDesktop))
    .update(CompleteTask(PlanTahoePhotos))
    .update(MarkNotificationsRead)
  inspect(model.wifi_enabled, content="false")
  inspect(model.bluetooth_enabled, content="false")
  inspect(model.brightness, content="0.55")
  inspect(model.volume, content="0.25")
  inspect(model.low_power_mode, content="true")
  inspect(model.remaining_tasks(), content="1")
  inspect(model.notifications_read, content="true")
}

///|
test "menu bar menus are exclusive and commands dismiss after acting" {
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
  let file_menu = model.update(ToggleMenu(FileMenu))
  debug_inspect(file_menu.overlay, content="MenuBarMenu(FileMenu)")
  let window_menu = file_menu.update(ToggleMenu(WindowMenu))
  debug_inspect(window_menu.overlay, content="MenuBarMenu(WindowMenu)")
  let downloads = window_menu
    .update(ToggleMenu(FileMenu))
    .update(RunMenuCommand(OpenDownloads))
  debug_inspect(downloads.finder_location, content="Downloads")
  debug_inspect(downloads.overlay, content="OverlayNone")
  let dark = downloads
    .update(ToggleMenu(SystemMenu))
    .update(RunMenuCommand(ToggleAppearance))
  assert_true(dark.dark_mode)
  debug_inspect(dark.overlay, content="OverlayNone")
  let view_menu = dark.update(ToggleMenu(ViewMenu))
  debug_inspect(view_menu.overlay, content="MenuBarMenu(ViewMenu)")
  let list_view = view_menu.update(RunMenuCommand(ShowFinderListView))
  debug_inspect(list_view.finder_view_mode, content="ListView")
  debug_inspect(list_view.overlay, content="OverlayNone")
  let help_menu = list_view.update(ToggleMenu(HelpMenu))
  debug_inspect(help_menu.overlay, content="MenuBarMenu(HelpMenu)")
  let notifications = help_menu.update(RunMenuCommand(OpenNotificationCenter))
  debug_inspect(notifications.overlay, content="NotificationCenter")
  let minimized = dark
    .update(ToggleMenu(WindowMenu))
    .update(RunMenuCommand(MinimizeFocusedWindow))
  assert_true(minimized.focused_id() is None)
  inspect(minimized.visible_windows().length(), content="0")
  // The record stays in the table so Dock reopen can restore it.
  inspect(minimized.windows.length(), content="1")
  let locked = minimized
    .update(ToggleMenu(SystemMenu))
    .update(RunMenuCommand(LockSession))
  debug_inspect(locked.phase, content="Locked")
}

///|
test "window drag preserves a native-style restore position" {
  let moved = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(MoveWindowBy(116.0, -44.0))
  let focused = moved.focused_window().unwrap()
  inspect(focused.bounds.offset_x, content="116")
  inspect(focused.bounds.offset_y, content="-44")
  let zoomed = moved.update(ToggleMaximize)
  debug_inspect(
    zoomed.focused_window().map(record => record.state),
    content="Some(MaximizedWindow)",
  )
  // Dragging a zoomed window restores it while keeping the normal offsets.
  let restored_by_drag = zoomed.update(MoveWindowBy(80.0, 60.0))
  let dragged = restored_by_drag.focused_window().unwrap()
  debug_inspect(dragged.state, content="NormalWindow")
  inspect(dragged.bounds.offset_x, content="196")
  inspect(dragged.bounds.offset_y, content="16")
  let restored = restored_by_drag.update(ToggleMaximize).update(ToggleMaximize)
  let after_restore = restored.focused_window().unwrap()
  debug_inspect(after_restore.state, content="NormalWindow")
  inspect(after_restore.bounds.offset_x, content="196")
  inspect(after_restore.bounds.offset_y, content="16")
}

///|
test "focus cycles across simultaneous windows by raising z-order" {
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
  let finder_id = model.focused_id().unwrap()
  let with_safari = model.update(OpenSafari)
  let safari_id = with_safari.focused_id().unwrap()
  inspect(with_safari.visible_windows().length(), content="2")
  debug_inspect(safari_id.app, content="SafariApp")
  // Clicking the background Finder window raises it above Safari.
  let refocused = with_safari.update(FocusWindow(finder_id))
  debug_inspect(
    refocused.focused_id(),
    content="Some({ app: FinderApp, serial: 1 })",
  )
  // z-order: Finder raised to the newest value, Safari keeps its old one.
  let finder_z = refocused.window_with_id(finder_id).unwrap().z_order
  let safari_z = refocused.window_with_id(safari_id).unwrap().z_order
  assert_true(finder_z > safari_z)
  // Focusing the already-focused window is a no-op snapshot-wise.
  let again = refocused.update(FocusWindow(finder_id))
  debug_inspect(
    again.focused_id(),
    content="Some({ app: FinderApp, serial: 1 })",
  )
  assert_true(again.window_with_id(safari_id).unwrap().z_order == safari_z)
}

///|
test "closing the focused window falls back to the next window" {
  // Dock-style OpenSafari refocuses; the File-menu "New Safari Window"
  // command spawns a second instance, giving Finder + two Safaris.
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(OpenSafari)
    .update(RunMenuCommand(OpenSafariWindow))
  inspect(model.windows.length(), content="3")
  debug_inspect(
    model.focused_window().map(record => record.id.serial),
    content="Some(3)",
  )
  let closed_top = update(model, CloseWindow)
  debug_inspect(
    closed_top.focused_window().map(record => record.id),
    content="Some({ app: SafariApp, serial: 2 })",
  )
  let closed_all_safari = closed_top.update(CloseWindow)
  debug_inspect(
    closed_all_safari.focused_window().map(record => record.id.app),
    content="Some(FinderApp)",
  )
  let empty = closed_all_safari.update(CloseWindow)
  assert_true(empty.focused_id() is None)
  inspect(empty.windows.length(), content="0")
  // Closing with no windows left stays inert.
  let inert = empty.update(CloseWindow)
  assert_true(inert.focused_id() is None)
  inspect(inert.windows.length(), content="0")
}

///|
test "minimize demotes a window and dock reopen restores it" {
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(OpenSafari)
  let safari_id = model.focused_id().unwrap()
  let minimized = model.update(MinimizeWindowAt(safari_id))
  // Focus falls back to the remaining Finder window.
  debug_inspect(
    minimized.focused_window().map(record => record.id.app),
    content="Some(FinderApp)",
  )
  debug_inspect(
    minimized.window_with_id(safari_id).map(record => record.state),
    content="Some(MinimizedWindow)",
  )
  inspect(minimized.visible_windows().length(), content="1")
  // Dock-style reopen restores the minimized Safari instead of spawning one.
  let restored = minimized.update(OpenSafari)
  inspect(restored.windows.length(), content="2")
  debug_inspect(
    restored.window_with_id(safari_id).map(record => record.state),
    content="Some(NormalWindow)",
  )
  debug_inspect(
    restored.focused_id(),
    content="Some({ app: SafariApp, serial: 2 })",
  )
}

///|
test "zoom is tracked per window and restore keeps bounds" {
  // Drag the initial Finder window before opening Safari, so the bounds are
  // not affected by the new window's cascade offset.
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(MoveWindowBy(-120.0, 40.0))
  let finder_id = model.focused_id().unwrap()
  let with_safari = model.update(OpenSafari)
  let safari_id = with_safari.focused_id().unwrap()
  debug_inspect(safari_id.app, content="SafariApp")
  let zoomed = with_safari.update(ToggleZoomAt(finder_id))
  debug_inspect(
    zoomed.window_with_id(finder_id).map(record => record.state),
    content="Some(MaximizedWindow)",
  )
  // The other window keeps normal state, and the zoomed (background)
  // window does not steal focus from it.
  debug_inspect(
    zoomed.focused_window().map(record => record.id.app),
    content="Some(SafariApp)",
  )
  debug_inspect(
    zoomed
    .visible_windows()
    .iter()
    .filter(record => record.id == safari_id)
    .next()
    .unwrap().state,
    content="NormalWindow",
  )
  // Restoring keeps the dragged normal bounds.
  let restored = zoomed.update(ToggleZoomAt(finder_id))
  let record = restored.window_with_id(finder_id).unwrap()
  debug_inspect(record.state, content="NormalWindow")
  inspect(record.bounds.offset_x, content="-120")
  inspect(record.bounds.offset_y, content="40")
}

///|
test "resize stores clamped sizes and skips zoomed windows" {
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
  let id = model.focused_id().unwrap()
  let resized = model.update(ResizeWindowBy(id, 900.0, 560.0))
  let record = resized.window_with_id(id).unwrap()
  inspect(record.bounds.width, content="900")
  inspect(record.bounds.height, content="560")
  // Values are clamped into the supported range.
  let clamped = resized.update(ResizeWindowBy(id, 99999.0, -5.0))
  let clamped_record = clamped.window_with_id(id).unwrap()
  inspect(clamped_record.bounds.width, content="1600")
  inspect(clamped_record.bounds.height, content="240")
  // Zoomed windows ignore resize gestures.
  let zoomed = clamped.update(ToggleMaximize)
  let untouched = zoomed.update(ResizeWindowBy(id, 400.0, 300.0))
  let zoomed_record = untouched.window_with_id(id).unwrap()
  debug_inspect(zoomed_record.state, content="MaximizedWindow")
  inspect(zoomed_record.bounds.width, content="1600")
  inspect(zoomed_record.bounds.height, content="240")
}

///|
test "same-app windows cascade and close falls back inside an app" {
  // File-menu "New Finder Window" spawns a second Finder instance.
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(RunMenuCommand(OpenFinderWindow))
  inspect(model.windows.length(), content="2")
  let first = model.window_with_id({ app: FinderApp, serial: 1 }).unwrap()
  let second = model.focused_window().unwrap()
  debug_inspect(second.id, content="{ app: FinderApp, serial: 2 }")
  // The new instance cascades down-right from the original position.
  assert_true(second.bounds.offset_x > first.bounds.offset_x)
  assert_true(second.bounds.offset_y > first.bounds.offset_y)
  // Closing the new instance returns focus to the original Finder window.
  let closed = model.update(CloseWindowAt(second.id))
  debug_inspect(
    closed.focused_id(),
    content="Some({ app: FinderApp, serial: 1 })",
  )
  inspect(closed.windows.length(), content="1")
}

///|
test "menu bar reflects the focused app and lock preserves windows" {
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(OpenSafari)
  inspect(model.active_app_label(), content="Safari")
  let focused_finder = model.update(FocusWindow({ app: FinderApp, serial: 1 }))
  inspect(focused_finder.active_app_label(), content="Finder")
  // Locking keeps the session's windows so unlocking restores the layout.
  let locked = focused_finder.update(LockDesktop)
  inspect(locked.windows.length(), content="2")
  let unlocked_again = locked
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
  inspect(unlocked_again.windows.length(), content="2")
  debug_inspect(unlocked_again.phase, content="Unlocked")
}

///|
test "desktop runtime unlocks into Finder at desktop size" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=1280.0,
    height=800.0,
  )
  // Boot splash shows the product name over the wallpaper.
  assert_true(has_text(runtime.draw_commands(), "Starting Mo Desktop"))
  assert_true(has_image(runtime.draw_commands(), "tahoe-day.jpg"))
  skip_boot(runtime)
  click_text(runtime, "Sign In")
  click_text(runtime, "Unlock")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Documents"))
  assert_true(has_text(commands, "Project Notes.txt"))
  assert_true(has_text(commands, "Finder"))
  assert_true(has_text(commands, "Sun Jul 19  09:41"))
}

///|
test "desktop runtime reaches login with Enter from the lock screen" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=1280.0,
    height=800.0,
  )
  skip_boot(runtime)
  // Enter on the lock screen opens the sign-in form.
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Unlock"))
  assert_true(has_text(commands, "Demo account — any password works"))
}

///|
test "app registry drives labels sizes and ordering" {
  let registry = app_registry()
  inspect(registry.length(), content="4")
  inspect(registry[0].label, content="Finder")
  inspect(registry[1].label, content="Safari")
  inspect(registry[2].label, content="Notes")
  inspect(registry[3].label, content="Terminal")
  // Notes/Terminal declare preferred window sizes; Finder/Safari stay
  // responsive (0 keeps the default sizing).
  assert_true(registry[2].default_width > 0.0)
  assert_true(registry[3].default_height > 0.0)
  assert_true(registry[0].default_width == 0.0)
}

///|
test "new windows adopt registry default sizes" {
  let opened = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(LaunchApp(NotesApp))
  let record = opened.focused_window().unwrap()
  debug_inspect(record.id.app, content="NotesApp")
  inspect(record.bounds.width, content="760")
  inspect(record.bounds.height, content="520")
  // Responsive-default apps keep 0.0 bounds.
  let finder = opened.window_with_id({ app: FinderApp, serial: 1 }).unwrap()
  inspect(finder.bounds.width, content="0")
}

///|
test "notes app creates selects edits and deletes notes" {
  let model = DesktopModel::new()
  inspect(model.notes.length(), content="1")
  debug_inspect(
    model.active_note_body().has_prefix("Welcome to Mo Notes"),
    content="true",
  )
  // Add prepends a new note and selects it.
  let added = model.update(AddNote)
  inspect(added.notes.length(), content="2")
  inspect(added.active_note, content="0")
  inspect(added.note_title(0), content="New note")
  // Editing writes to the active note only.
  let edited = added.update(NoteBodyChanged("Grocery list\napples"))
  inspect(edited.note_title(0), content="Grocery list")
  inspect(edited.notes.length(), content="2")
  debug_inspect(edited.note_title(1).has_prefix("Welcome"), content="true")
  // Selection switches editors.
  let switched = edited.update(SelectNote(1))
  inspect(switched.active_note, content="1")
  debug_inspect(
    switched.active_note_body().has_prefix("Welcome"),
    content="true",
  )
  // Deleting the first note shifts selection onto the survivor.
  let deleted = switched.update(DeleteNote(0))
  inspect(deleted.notes.length(), content="1")
  inspect(deleted.active_note, content="0")
  debug_inspect(
    deleted.active_note_body().has_prefix("Welcome"),
    content="true",
  )
  // Out-of-range selections are inert; deleting the last note is allowed.
  let inert = deleted.update(SelectNote(9))
  inspect(inert.active_note, content="0")
  let empty = deleted.update(DeleteNote(0))
  inspect(empty.notes.length(), content="0")
  inspect(empty.active_note_body(), content="")
  inspect(empty.note_title(0), content="New note")
}

///|
test "terminal commands drive the desktop and report errors" {
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(TerminalInputChanged("echo hello world"))
    .update(RunTerminalCommand)
  inspect(model.terminal_lines.length(), content="3")
  inspect(model.terminal_lines[1], content="mo> echo hello world")
  inspect(model.terminal_lines[2], content="hello world")
  inspect(model.terminal_input, content="")
  // apps lists the registry labels.
  let apps_out = model
    .update(TerminalInputChanged("apps"))
    .update(RunTerminalCommand)
  debug_inspect(
    apps_out.terminal_lines[4].has_prefix("installed: "),
    content="true",
  )
  // open launches the target app and focuses it.
  let launched = apps_out
    .update(TerminalInputChanged("open safari"))
    .update(RunTerminalCommand)
  debug_inspect(
    launched.focused_window().map(record => record.id.app),
    content="Some(SafariApp)",
  )
  inspect(launched.terminal_lines[6], content="Launching Safari")
  // Unknown commands and unknown targets produce error lines.
  let unknown = launched
    .update(TerminalInputChanged("frobnicate"))
    .update(RunTerminalCommand)
  inspect(unknown.terminal_lines[8], content="frobnicate: command not found")
  let bad_open = unknown
    .update(TerminalInputChanged("open calculator"))
    .update(RunTerminalCommand)
  debug_inspect(
    bad_open.terminal_lines[10].has_prefix("open: unknown app"),
    content="true",
  )
  // Clear resets the transcript; empty submits are ignored.
  let cleared = bad_open.update(ClearTerminal)
  inspect(cleared.terminal_lines.length(), content="1")
  let quiet = cleared.update(RunTerminalCommand)
  inspect(quiet.terminal_lines.length(), content="1")
}

///|
test "v2 snapshots migrate forward with default notes" {
  let v2 = "{\"schema_version\":2,\"dark_mode\":false,\"wallpaper_source\":\"w.jpg\",\"volume\":0.4,\"brightness\":0.7,\"wifi_enabled\":true,\"bluetooth_enabled\":false,\"low_power_mode\":false,\"windows\":[],\"recent_files\":[],\"icon_placements\":[]}"
  let migrated = decode_desktop_snapshot(v2)
  assert_true(migrated is Some(_))
  let snapshot = migrated.unwrap()
  inspect(snapshot.schema_version, content="4")
  assert_false(snapshot.bluetooth_enabled)
  inspect(snapshot.notes.length(), content="1")
  debug_inspect(snapshot.windows.is_empty(), content="true")
}

///|
test "desktop runtime shows new apps from the registry" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=1280.0,
    height=800.0,
  )
  skip_boot(runtime)
  click_text(runtime, "Sign In")
  click_text(runtime, "Unlock")
  // Open Notes via Spotlight search.
  click_text(runtime, "Spotlight")
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Notes")),
  )
  click_text(runtime, "Notes")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Welcome to Mo Notes"))
  assert_true(has_text(commands, "New Note"))
  // The Dock now carries registry glyphs for all four apps (dock tiles are
  // icon-only; the terminal glyph draws a ">_" mark).
  assert_true(has_text(runtime.draw_commands(), ">_"))
}

///|
test "session flows boot lock login logout and back" {
  let model = DesktopModel::new()
  debug_inspect(model.phase, content="Boot")
  // The clock subscription auto-advances after the second tick.
  let tick = DesktopClock::new(2026, 7, 19, 0, 9, 41)
  let ticked = model.update(ClockUpdated(tick))
  debug_inspect(ticked.phase, content="Boot")
  let booted = ticked.update(ClockUpdated(tick))
  debug_inspect(booted.phase, content="Locked")
  // Wrong-phase submissions are inert guards, not errors.
  let guarded = booted.update(SubmitLogin("x"))
  assert_true(guarded.phase is Locked)
  // Lock screen to login form.
  let at_login = booted.update(ShowLogin)
  debug_inspect(at_login.phase, content="Login")
  let typed = at_login.update(LoginPasswordChanged("hunter2"))
  inspect(typed.login_password, content="hunter2")
  let signed_in = typed.update(SubmitLogin("hunter2"))
  debug_inspect(signed_in.phase, content="Unlocked")
  inspect(signed_in.login_password, content="")
  // Lock keeps windows; logout returns only to the login form.
  let locked = signed_in.update(LockDesktop)
  debug_inspect(locked.phase, content="Locked")
  assert_true(locked.windows.length() > 0)
  let logged_out = locked.update(RunMenuCommand(LogOutSession))
  debug_inspect(logged_out.phase, content="Login")
  let round_two = logged_out.update(SubmitLogin("")).update(OpenSafari)
  debug_inspect(round_two.phase, content="Unlocked")
}

///|
test "boot tap skips the splash in one step" {
  let model = DesktopModel::new()
  let skipped = model.update(AdvanceBoot)
  debug_inspect(skipped.phase, content="Locked")
  // AdvanceBoot outside of Boot is inert.
  let again = skipped.update(AdvanceBoot)
  debug_inspect(again.phase, content="Locked")
}

///|
test "desktop catalogs translate interpolate and fall back" {
  // English and Simplified Chinese resolve from the app-owned catalog.
  inspect(AppLanguage::EnglishLanguage.text("lock.sign_in"), content="Sign In")
  inspect(AppLanguage::ChineseLanguage.text("lock.sign_in"), content="登录")
  inspect(AppLanguage::ChineseLanguage.text("menu.file"), content="文件")
  // Named interpolation flows through the translator.
  inspect(
    AppLanguage::ChineseLanguage.translate("item.close", values=[
      ("app", "Finder"),
    ]),
    content="关闭Finder",
  )
  inspect(
    AppLanguage::EnglishLanguage.translate("item.close", values=[
      ("app", "Safari"),
    ]),
    content="Close Safari",
  )
  // Unknown keys surface the visible missing-key marker.
  inspect(
    AppLanguage::EnglishLanguage.text("no.such.key"),
    content="[[no.such.key]]",
  )
}

///|
test "language toggles at runtime and persists in snapshots" {
  let model = DesktopModel::new()
  debug_inspect(model.language, content="EnglishLanguage")
  let switched = model.update(SetLanguage(ChineseLanguage))
  debug_inspect(switched.language, content="ChineseLanguage")
  // The menu command toggles to the other language.
  let back = switched.update(RunMenuCommand(ToggleLanguageCommand))
  debug_inspect(back.language, content="EnglishLanguage")
  // Language rides the snapshot across restarts.
  let decoded = decode_desktop_snapshot(
    encode_desktop_snapshot(switched.persisted_snapshot()),
  ).unwrap()
  assert_true(decoded.language == "zh-Hans")
  let restored = DesktopModel::new().restore_snapshot(decoded)
  debug_inspect(restored.language, content="ChineseLanguage")
}

///|
test "v3 snapshots migrate forward with the default language" {
  let v3 = "{\"schema_version\":3,\"dark_mode\":true,\"wallpaper_source\":\"w.jpg\",\"volume\":0.4,\"brightness\":0.7,\"wifi_enabled\":true,\"bluetooth_enabled\":false,\"low_power_mode\":false,\"windows\":[],\"recent_files\":[],\"notes\":[],\"icon_placements\":[]}"
  let migrated = decode_desktop_snapshot(v3)
  assert_true(migrated is Some(_))
  let snapshot = migrated.unwrap()
  inspect(snapshot.schema_version, content="4")
  assert_true(snapshot.language == "en-US")
  inspect(snapshot.notes.length(), content="0")
  assert_true(snapshot.dark_mode)
}

///|
test "desktop runtime switches language from the system menu" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=1280.0,
    height=800.0,
  )
  skip_boot(runtime)
  click_text(runtime, "Sign In")
  click_text(runtime, "Unlock")
  // Open the system menu and switch to Chinese.
  click_text(runtime, "Mo")
  click_text(runtime, "中文")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "文件"))
  assert_true(has_text(commands, "编辑"))
  // Switching back restores English labels.
  click_text(runtime, "Mo")
  click_text(runtime, "English")
  assert_true(has_text(runtime.draw_commands(), "File"))
}

///|
test "desktop snapshot roundtrips through encode and decode" {
  let model = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(ToggleDarkMode)
    .update(VolumeChanged(0.2))
    .update(BrightnessChanged(0.9))
    .update(MoveWindowBy(48.0, -24.0))
    .update(OpenSafari)
    .update(RequestFileImport)
    .update(
      FileImportCompleted(
        @services.ServiceTaskResult::Success(["/tmp/a.md", "/tmp/b.md"]),
      ),
    )
    .update(MoveDesktopIcon("Tahoe Trip", 40.0, -12.0))
  let snapshot = model.persisted_snapshot()
  let decoded = decode_desktop_snapshot(encode_desktop_snapshot(snapshot))
  assert_true(decoded == Some(snapshot))
  let restored = DesktopModel::new().restore_snapshot(snapshot)
  assert_true(restored.dark_mode)
  debug_inspect(restored.appearance, content="DarkAppearance")
  inspect(restored.volume, content="0.2")
  inspect(restored.brightness, content="0.9")
  inspect(restored.windows.length(), content="2")
  inspect(restored.imported_files.length(), content="2")
  inspect(restored.imported_files[1], content="/tmp/b.md")
  inspect(restored.icon_placements.length(), content="1")
  inspect(restored.icon_placements[0].name, content="Tahoe Trip")
  // Serial/z counters continue above the restored records.
  let raised = restored.update(FocusWindow({ app: FinderApp, serial: 1 }))
  let finder = raised.window_with_id({ app: FinderApp, serial: 1 }).unwrap()
  assert_true(finder.z_order >= 3)
}

///|
test "v1 snapshots migrate into the current window table" {
  let legacy = "{\"schema_version\":1,\"dark_mode\":true,\"wallpaper_source\":\"w.jpg\",\"volume\":0.5,\"brightness\":0.9,\"window_offset_x\":40,\"window_offset_y\":-20,\"window_maximized\":true}"
  let migrated = decode_desktop_snapshot(legacy)
  assert_true(migrated is Some(_))
  let snapshot = migrated.unwrap()
  inspect(snapshot.schema_version, content="4")
  assert_true(snapshot.dark_mode)
  inspect(snapshot.volume, content="0.5")
  inspect(snapshot.windows.length(), content="1")
  let record = snapshot.windows[0]
  debug_inspect(record.id.app, content="FinderApp")
  debug_inspect(record.state, content="MaximizedWindow")
  inspect(record.bounds.offset_x, content="40")
  inspect(record.bounds.offset_y, content="-20")
  // Defaults fill fields the legacy format did not track.
  assert_true(snapshot.wifi_enabled)
  inspect(snapshot.recent_files.length(), content="0")
}

///|
test "corrupt or unknown snapshots degrade to defaults" {
  assert_true(decode_desktop_snapshot("not json at all") is None)
  assert_true(decode_desktop_snapshot("{}") is None)
  assert_true(
    decode_desktop_snapshot("{\"schema_version\":99,\"dark_mode\":true}")
    is None,
  )
  // A failed decode never reaches restore_snapshot, so a fresh model keeps
  // its defaults; loading reports the degradation instead of crashing.
  let loaded = DesktopModel::new().update(
    DesktopSettingsLoaded(@services.ServiceTaskResult::Success(None)),
  )
  inspect(loaded.settings_loaded, content="true")
  inspect(
    loaded.last_diagnostic,
    content="Starting with default desktop settings",
  )
  let broken = DesktopModel::new().update(
    DesktopSettingsLoaded(@services.ServiceTaskResult::Success(Some("garbage"))),
  )
  inspect(broken.settings_loaded, content="true")
  inspect(
    broken.last_diagnostic,
    content="Stored desktop data was unusable; using defaults",
  )
  let failed = DesktopModel::new().update(
    DesktopSettingsLoaded(
      @services.ServiceTaskResult::Failure(
        @services.ServiceError::new(code="unavailable", message="no storage"),
      ),
    ),
  )
  inspect(failed.last_diagnostic, content="no storage")
}

///|
test "desktop icon drags move and clamp persisted placements" {
  let moved = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(MoveDesktopIcon("Welcome.txt", 30.0, -10.0))
  inspect(moved.icon_placements.length(), content="1")
  inspect(moved.icon_placements[0].offset_x, content="30")
  inspect(moved.icon_placements[0].offset_y, content="-10")
  // Repeated drags accumulate onto the same entry.
  let again = moved.update(MoveDesktopIcon("Welcome.txt", -5.0, 5.0))
  inspect(again.icon_placements.length(), content="1")
  inspect(again.icon_placements[0].offset_x, content="25")
  // Values are clamped so icons cannot be thrown off screen.
  let wild = again.update(MoveDesktopIcon("Welcome.txt", 99999.0, -99999.0))
  inspect(wild.icon_placements[0].offset_x, content="320")
  inspect(wild.icon_placements[0].offset_y, content="-420")
  // Placements ride along in the snapshot.
  let decoded = decode_desktop_snapshot(
    encode_desktop_snapshot(wild.persisted_snapshot()),
  )
  assert_true(decoded.unwrap().icon_placements[0].offset_x == 320.0)
}

///|
test "reset desktop settings restores factory values" {
  let dirty = DesktopModel::new()
    .update(AdvanceBoot)
    .update(ShowLogin)
    .update(SubmitLogin(""))
    .update(ToggleDarkMode)
    .update(VolumeChanged(0.1))
    .update(RunMenuCommand(OpenFinderWindow))
    .update(MoveDesktopIcon("Tahoe Trip", 12.0, 12.0))
  let reset = dirty.update(ResetDesktopSettings)
  assert_false(reset.dark_mode)
  inspect(reset.volume, content="0.68")
  inspect(reset.windows.length(), content="1")
  inspect(reset.windows[0].id.serial, content="1")
  inspect(reset.icon_placements.length(), content="0")
  inspect(reset.imported_files.length(), content="0")
  inspect(reset.last_diagnostic, content="Restored default desktop settings")
}

///|
fn map_settings_store(store : Map[String, String]) -> @services.AppEnvironment {
  @services.AppEnvironment::new(
    services=@services.AppServices::new(
      settings=@services.SettingsServices::new(
        read=key => {
          @services.ServiceTask::succeed(
            key="test:settings:read",
            value=store.get(key),
          )
        },
        write=(key, value) => {
          store[key] = value
          @services.ServiceTask::succeed(key="test:settings:write", value=())
        },
        remove=key => {
          ignore(store.remove(key))
          @services.ServiceTask::succeed(key="test:settings:remove", value=())
        },
      ),
    ),
  )
}

///|
test "desktop layout persists across program restarts" {
  let store : Map[String, String] = Map([])
  let clock = () => DesktopClock::new(2026, 7, 19, 0, 9, 41)
  // Session one: unlock, open Safari, and let the auto-save run.
  let first = @runtime.new_program_with_dimensions(
    program=program(environment=map_settings_store(store), wall_clock=clock),
    width=1280.0,
    height=800.0,
  )
  skip_boot(first)
  click_text(first, "Sign In")
  click_text(first, "Unlock")
  assert_false(store.contains(SETTINGS_STORAGE_KEY))
  click_text(first, "Window")
  click_text(first, "Bring Safari Forward")
  assert_true(store.contains(SETTINGS_STORAGE_KEY))
  let stored = store.get(SETTINGS_STORAGE_KEY).unwrap()
  let saved = decode_desktop_snapshot(stored).unwrap()
  inspect(saved.schema_version, content="4")
  inspect(saved.windows.length(), content="2")
  // Session two over the same store boots straight into both windows.
  let second = @runtime.new_program_with_dimensions(
    program=program(environment=map_settings_store(store), wall_clock=clock),
    width=1280.0,
    height=800.0,
  )
  skip_boot(second)
  click_text(second, "Sign In")
  click_text(second, "Unlock")
  let commands = second.draw_commands()
  assert_true(has_text(commands, "Documents"))
  assert_true(has_text(commands, "Start Page"))
}

///|
test "desktop runtime renders simultaneous windows after menu open" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=1280.0,
    height=800.0,
  )
  skip_boot(runtime)
  click_text(runtime, "Sign In")
  click_text(runtime, "Unlock")
  // Open Safari via the Window menu ("Bring Safari Forward"), so both
  // windows coexist on screen.
  click_text(runtime, "Window")
  click_text(runtime, "Bring Safari Forward")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Documents"))
  assert_true(has_text(commands, "Project Notes.txt"))
  // The menu bar reflects the newly focused app while the Finder window
  // (title "Documents") stays alive underneath.
  assert_true(has_text(commands, "Safari"))
  assert_true(has_text(commands, "Start Page"))
}

///|
test "desktop runtime keeps primary controls visible in compact viewport" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=390.0,
    height=720.0,
  )
  skip_boot(runtime)
  click_text(runtime, "Sign In")
  click_text(runtime, "Unlock")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Docs"))
  assert_true(has_text(commands, "Apps"))
  assert_true(has_text(commands, "Downloads"))
  assert_true(has_text(commands, "Finder"))
  assert_true(has_text(commands, "09:41"))
}

///|
/// Pass the boot splash (timer is absent in headless runtimes, so tests
/// tap through it exactly like impatient users would).
fn skip_boot(runtime : @runtime.AppRuntime) -> Unit raise {
  click_text(runtime, "Starting Mo Desktop")
}

///|
test "traffic light close button removes its window at runtime" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=1280.0,
    height=800.0,
  )
  skip_boot(runtime)
  click_text(runtime, "Sign In")
  click_text(runtime, "Unlock")
  // Close-dot center for the initial Finder window at 1280x800 (measured):
  // window left ~166.4; dots start 20pt in, 12pt wide.
  let cx = 192.4
  let cy = 121.0
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=cx, y=cy),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=cx, y=cy),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  let after = runtime.draw_commands()
  for command in after {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == "Documents" || value == "Project Notes.txt" {
          println("AFTER \{value} @ (\{frame.origin.x},\{frame.origin.y})")
        }
      _ => ()
    }
  }
  // The Finder window's content disappears; the shell stays and the menu
  // bar app title falls back to "Desktop" (no focused window).
  assert_false(has_text(after, "Project Notes.txt"))
  assert_true(has_text(after, "Desktop"))
  assert_false(has_text(after, "Sign In"))
}

///|
test "titlebar drag moves the window on screen" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=1280.0,
    height=800.0,
  )
  skip_boot(runtime)
  click_text(runtime, "Sign In")
  click_text(runtime, "Unlock")
  // The titlebar copy of the location label is the topmost "Documents".
  guard text_frame(runtime.draw_commands(), "Documents") is Some(before) else {
    fail("expected window title")
  }
  assert_true(before.origin.y < 160.0)
  let gx = before.origin.x + before.size.width / 2.0
  let gy = before.origin.y + 11.0
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=gx, y=gy),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  for step in 1..<=5 {
    runtime.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=@geometry.Point::new(
            x=gx + step.to_double() * 12.0,
            y=gy + step.to_double() * 8.0,
          ),
          phase=@core.PointerPhase::Move,
        ),
      ),
    )
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=gx + 60.0, y=gy + 40.0),
        phase=@core.PointerPhase::Up,
      ),
    ),
  )
  guard text_frame(runtime.draw_commands(), "Documents") is Some(after) else {
    fail("window title vanished after drag")
  }
  let dx = after.origin.x - before.origin.x
  let dy = after.origin.y - before.origin.y
  assert_true(dx > 50.0)
  assert_true(dy > 30.0)
}

///|
fn click_text(runtime : @runtime.AppRuntime, text : String) -> Unit raise {
  guard text_frame(runtime.draw_commands(), text) is Some(frame) else {
    fail("expected text frame for " + text)
  }
  let point = @geometry.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
}

///|
fn has_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn has_image(commands : Array[@core.DrawCommand], suffix : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawImage({ source, .. }) &&
    source.has_suffix(suffix)
  })
}

///|
fn text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}
