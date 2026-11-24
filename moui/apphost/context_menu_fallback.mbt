///|
/// What the view-level context menu reports back to the host.
///
/// The layer is host-owned, so its messages never enter the app's `Msg`: the
/// driver keeps them in the menu's own mailbox and drains that mailbox right
/// after the event that produced them.
priv enum HostContextMenuMessage {
  Select(@core.ActionCommand)
  Dismiss
}

///|
/// One open view-level context menu.
///
/// This is the fallback a host runs when the platform menu service answers
/// "unavailable": the menu is `@views.context_menu_region` over the same
/// command table the native path hands to `ShowMenu`, so a headless run shows
/// the menu a desktop run shows.
///
/// The service bridge is captured when the menu opens because the chosen
/// command runs after the layer is gone, and the text-editing commands need
/// the clipboard bridge that was live at that moment.
priv struct HostContextMenu {
  commands : Array[@core.ActionCommand]
  anchor : @core.Point
  theme : @core.Theme
  mut active : Int32
  messages : Array[HostContextMenuMessage]
  services : @backend_host.HostServiceBridge
}

///|
fn HostContextMenu::new(
  commands : Array[@core.ActionCommand],
  anchor~ : @core.Point,
  theme~ : @core.Theme,
  services~ : @backend_host.HostServiceBridge,
) -> HostContextMenu {
  {
    commands,
    anchor,
    theme,
    // Native context menus open with no row highlighted, and so does this
    // one: Enter stays inert until the keyboard walk visits a row.
    active: -1,
    messages: [],
    services,
  }
}

///|
/// Whether row `index` exists and can run. Disabled rows are not navigable:
/// the walk only highlights rows that will dispatch something.
fn HostContextMenu::is_enabled(self : HostContextMenu, index : Int32) -> Bool {
  if index < 0 || index.to_int() >= self.commands.length() {
    return false
  }
  self.commands[index.to_int()].enabled
}

///|
fn HostContextMenu::first_enabled(self : HostContextMenu) -> Int32 {
  let count = self.commands.length()
  let mut index : Int32 = 0
  while index.to_int() < count {
    if self.commands[index.to_int()].enabled {
      return index
    }
    index = index + 1
  }
  -1
}

///|
fn HostContextMenu::last_enabled(self : HostContextMenu) -> Int32 {
  let count = self.commands.length()
  let mut index : Int32 = 0
  let mut last : Int32 = -1
  while index.to_int() < count {
    if self.commands[index.to_int()].enabled {
      last = index
    }
    index = index + 1
  }
  last
}

///|
/// Next runnable row strictly beyond the highlight in `step`'s direction, or
/// the highlight itself at the end of the list: a context menu does not wrap.
fn HostContextMenu::step_enabled(self : HostContextMenu, step : Int32) -> Int32 {
  let count = self.commands.length()
  let mut index = self.active + step
  while index >= 0 && index.to_int() < count {
    if self.commands[index.to_int()].enabled {
      return index
    }
    index = index + step
  }
  self.active
}

///|
fn HostContextMenu::move_highlight(
  self : HostContextMenu,
  step : Int32,
) -> Unit {
  let target = if self.active < 0 {
    if step > 0 {
      self.first_enabled()
    } else {
      self.last_enabled()
    }
  } else {
    self.step_enabled(step)
  }
  // A menu whose rows are all disabled keeps the highlight cleared.
  if target >= 0 {
    self.active = target
  }
}

///|
/// The row Enter runs, or `None` while nothing usable is highlighted.
fn HostContextMenu::active_command(
  self : HostContextMenu,
) -> @core.ActionCommand? {
  if self.is_enabled(self.active) {
    Some(self.commands[self.active.to_int()])
  } else {
    None
  }
}

///|
/// The layer's view: the command table in a context-menu region anchored at
/// the right-click point. Clicking a row reports the whole command through
/// `on_select_command`, so two rows sharing an intent still dispatch their own
/// command; the intent channel only exists because the view type requires a
/// fallback message.
fn HostContextMenu::view(
  self : HostContextMenu,
) -> @core.View[HostContextMenuMessage] {
  let menu = @views.command_menu(
    [@views.command_menu_section(title="", commands=self.commands)],
    on_select=_intent => Dismiss,
    theme=self.theme,
    active=self.active,
    on_select_command=Some(command => Select(command)),
  )
  @views.context_menu_region(
    child=@views.empty(),
    menu~,
    visible=true,
    anchor=Some(self.anchor),
    dismiss=Some(Dismiss),
    theme=self.theme,
  )
}

///|
/// Whether the view-level context menu is on screen.
fn HostRuntimeDriver::context_menu_is_open(self : HostRuntimeDriver) -> Bool {
  self.context_menu is Some(_)
}

///|
/// Rebuild the host layer from the current menu state.
///
/// Installing a new layer replaces only the layer: the runtime keeps the app
/// root's element identity, so the app subtree is never remounted and its
/// focus and caret survive a highlight move.
fn HostRuntimeDriver::install_context_menu(self : HostRuntimeDriver) -> Unit {
  match self.context_menu {
    Some(menu) => {
      let layer = @runtime.HostOverlay::from_view(
        menu.view(),
        emit=message => menu.messages.push(message),
        keeps_focus=true,
        // A context menu never takes focus: a press on a row must keep the
        // app's focus owner, so the command the row carries still has its
        // target when `Select` is settled.
      )
      self.runtime.set_host_overlay(Some(layer))
      self.request_redraw()
    }
    None => ()
  }
}

///|
/// Open the view-level menu for a command table, anchored at the pointer.
/// An already open menu (a second right-click elsewhere) is replaced.
fn HostRuntimeDriver::open_context_menu(
  self : HostRuntimeDriver,
  commands : Array[@core.ActionCommand],
  services : @backend_host.HostServiceBridge,
) -> Unit {
  let anchor = match self.runtime.pointer_position() {
    Some(point) => point
    // Synthetic and headless hosts may never report a pointer position; a
    // menu without one still opens inside the viewport insets.
    None => @core.Point::new(x=8.0, y=8.0)
  }
  let menu = HostContextMenu::new(
    commands,
    anchor~,
    theme=self.runtime.environment().theme,
    services~,
  )
  self.context_menu = Some(menu)
  self.install_context_menu()
}

///|
/// Close the view-level menu and give the surface back to the app. Idempotent.
fn HostRuntimeDriver::close_context_menu(self : HostRuntimeDriver) -> Unit {
  match self.context_menu {
    Some(_) => {
      self.context_menu = None
      self.runtime.set_host_overlay(None)
      self.request_redraw()
    }
    None => ()
  }
}

///|
/// Move the highlight and repaint the layer.
fn HostRuntimeDriver::move_context_menu_highlight(
  self : HostRuntimeDriver,
  step : Int32,
) -> Unit {
  match self.context_menu {
    Some(menu) => {
      let before = menu.active
      menu.move_highlight(step)
      if menu.active != before {
        self.install_context_menu()
      }
    }
    None => ()
  }
}

///|
fn HostRuntimeDriver::highlight_context_menu_first(
  self : HostRuntimeDriver,
) -> Unit {
  match self.context_menu {
    Some(menu) => {
      let target = menu.first_enabled()
      if target >= 0 && target != menu.active {
        menu.active = target
        self.install_context_menu()
      }
    }
    None => ()
  }
}

///|
fn HostRuntimeDriver::highlight_context_menu_last(
  self : HostRuntimeDriver,
) -> Unit {
  match self.context_menu {
    Some(menu) => {
      let target = menu.last_enabled()
      if target >= 0 && target != menu.active {
        menu.active = target
        self.install_context_menu()
      }
    }
    None => ()
  }
}

///|
/// Run the highlighted row. The menu closes first: the command may open a
/// dialog or a file picker, and those must not run underneath a layer that
/// intercepts the next click.
fn HostRuntimeDriver::activate_context_menu(self : HostRuntimeDriver) -> Unit {
  match self.context_menu {
    Some(menu) =>
      match menu.active_command() {
        Some(command) => {
          let services = menu.services
          self.close_context_menu()
          ignore(self.dispatch_action_command_with_services(command, services))
        }
        None => ()
      }
    None => ()
  }
}

///|
/// Route a keyboard event to the view-level menu.
///
/// Returns whether the menu consumed the event. Arrows, Home/End, Enter and
/// Escape belong to the menu; any other key closes it and is handed back to
/// the app, so an open context menu never swallows a shortcut the program
/// owns.
fn HostRuntimeDriver::context_menu_keyboard(
  self : HostRuntimeDriver,
  event : @core.KeyboardEvent,
) -> Bool {
  if !self.context_menu_is_open() {
    return false
  }
  if !event.pressed {
    // A release inside an open menu has no target of its own; consuming it
    // keeps the app from acting on a key it never saw go down.
    return true
  }
  let key = if event.key != "" { event.key } else { event.code }
  match key {
    "Escape" | "Esc" | "Tab" => {
      self.close_context_menu()
      true
    }
    "ArrowDown" | "Down" => {
      self.move_context_menu_highlight(1)
      true
    }
    "ArrowUp" | "Up" => {
      self.move_context_menu_highlight(-1)
      true
    }
    "Home" => {
      self.highlight_context_menu_first()
      true
    }
    "End" => {
      self.highlight_context_menu_last()
      true
    }
    "Enter" | "Space" | " " => {
      self.activate_context_menu()
      true
    }
    _ => {
      self.close_context_menu()
      false
    }
  }
}

///|
/// Drain what the layer reported and act on it.
///
/// Messages are collected before acting: a row click and the barrier's dismiss
/// message can arrive in the same event, and closing the menu drops the
/// mailbox with it.
fn HostRuntimeDriver::settle_context_menu(self : HostRuntimeDriver) -> Unit {
  match self.context_menu {
    Some(menu) => {
      let pending = menu.messages.copy()
      menu.messages.clear()
      for message in pending {
        match message {
          Select(command) => {
            let services = menu.services
            self.close_context_menu()
            ignore(
              self.dispatch_action_command_with_services(command, services),
            )
          }
          Dismiss => self.close_context_menu()
        }
      }
    }
    None => ()
  }
}

///|
/// Whether a `ShowMenu` answer means "this host has no native menu service".
///
/// The fallback keys off the canonical answer rather than
/// `capabilities().menus`, because a platform that advertises a menu service
/// can still fail to show one (the Linux zenity/kdialog path answers `-2` when
/// neither dialog tool is installed) and it must fall back too. A different
/// message means the user did see a native menu — "cancelled" for a dismissal,
/// "disabled" for a greyed command — and must not open a second menu.
fn host_menu_service_unavailable(message : String) -> Bool {
  message ==
  @backend_host.HostServiceRequest::ShowMenu([]).unavailable_message()
}
