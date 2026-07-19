///|
test "desktop session opens windows and keeps overlays exclusive" {
  let model = DesktopModel::new()
  debug_inspect(model.phase, content="Locked")
  let unlocked = update(model, UnlockDesktop)
  debug_inspect(unlocked.phase, content="Unlocked")
  debug_inspect(unlocked.active_window, content="Finder")
  let launcher = update(unlocked, ToggleLauncher)
  debug_inspect(launcher.overlay, content="Launcher")
  let controls = update(launcher, ToggleControlCenter)
  debug_inspect(controls.overlay, content="ControlCenter")
  let safari = update(controls, OpenSafari)
  debug_inspect(safari.active_window, content="Safari")
  debug_inspect(safari.overlay, content="OverlayNone")
  inspect(update(safari, ToggleDarkMode).dark_mode, content="true")
}

///|
test "finder and browser interactions update controlled state" {
  let finder = DesktopModel::new()
    .update(UnlockDesktop)
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
  let model = DesktopModel::new().update(UnlockDesktop)
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
  debug_inspect(minimized.active_window, content="NoWindow")
  let locked = minimized
    .update(ToggleMenu(SystemMenu))
    .update(RunMenuCommand(LockSession))
  debug_inspect(locked.phase, content="Locked")
}

///|
test "window drag preserves a native-style restore position" {
  let moved = DesktopModel::new()
    .update(UnlockDesktop)
    .update(MoveWindowBy(116.0, -44.0))
  inspect(moved.window_offset_x, content="116")
  inspect(moved.window_offset_y, content="-44")
  let zoomed = moved.update(ToggleMaximize)
  assert_true(zoomed.window_maximized)
  let restored_by_drag = zoomed.update(MoveWindowBy(80.0, 60.0))
  assert_false(restored_by_drag.window_maximized)
  inspect(restored_by_drag.window_offset_x, content="196")
  inspect(restored_by_drag.window_offset_y, content="16")
  let restored = restored_by_drag.update(ToggleMaximize).update(ToggleMaximize)
  assert_false(restored.window_maximized)
  inspect(restored.window_offset_x, content="196")
  inspect(restored.window_offset_y, content="16")
  let relocked = restored.update(LockDesktop)
  inspect(relocked.window_offset_x, content="0")
  inspect(relocked.window_offset_y, content="0")
}

///|
test "desktop runtime unlocks into Finder at desktop size" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=1280.0,
    height=800.0,
  )
  assert_true(has_text(runtime.draw_commands(), "Enter Mo Desktop"))
  assert_true(has_image(runtime.draw_commands(), "tahoe-day.jpg"))
  click_text(runtime, "Enter Mo Desktop")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Documents"))
  assert_true(has_text(commands, "Project Notes.txt"))
  assert_true(has_text(commands, "Finder"))
  assert_true(has_text(commands, "Sun Jul 19  09:41"))
}

///|
test "desktop runtime unlocks with Enter from the lock screen" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=1280.0,
    height=800.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Documents"))
  assert_true(has_text(commands, "Finder"))
}

///|
test "desktop runtime keeps primary controls visible in compact viewport" {
  let runtime = @runtime.new_program_with_dimensions(
    program=program(),
    width=390.0,
    height=720.0,
  )
  click_text(runtime, "Enter Mo Desktop")
  let commands = runtime.draw_commands()
  assert_true(has_text(commands, "Docs"))
  assert_true(has_text(commands, "Apps"))
  assert_true(has_text(commands, "Downloads"))
  assert_true(has_text(commands, "Finder"))
  assert_true(has_text(commands, "09:41"))
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
