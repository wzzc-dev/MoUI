///|
/// The kind of application a desktop window belongs to. Kept separate from
/// window identity so several windows can share one app (like multiple
/// Finder windows on macOS).
pub(all) enum AppKind {
  FinderApp
  SafariApp
  NotesApp
  TerminalApp
} derive(Eq, Debug, ToJson, FromJson)

///|
/// Stable identity for one window instance. `serial` comes from a
/// monotonically increasing counter on the model, so ids are never reused
/// within a session.
pub(all) struct WindowId {
  app : AppKind
  serial : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
/// Lifecycle of a single window, mirroring macOS zoom/minimize semantics.
pub(all) enum WindowState {
  NormalWindow
  MinimizedWindow
  MaximizedWindow
} derive(Eq, Debug, ToJson, FromJson)

///|
/// Persisted geometry of one window. Offsets are relative to the centered
/// default position so the layout survives viewport changes; width/height of
/// `0.0` mean "responsive default" until the user explicitly resizes.
pub(all) struct WindowBounds {
  offset_x : Double
  offset_y : Double
  width : Double
  height : Double
} derive(Eq, Debug, ToJson, FromJson)

///|
fn WindowBounds::default() -> WindowBounds {
  { offset_x: 0.0, offset_y: 0.0, width: 0.0, height: 0.0 }
}

///|
/// One entry in the desktop window table. Painting order is derived from
/// `z_order`: higher values paint later (on top). The focused window is the
/// visible window with the highest z-order.
pub(all) struct WindowRecord {
  id : WindowId
  state : WindowState
  bounds : WindowBounds
  z_order : Int
} derive(Eq, Debug, ToJson, FromJson)

///|
let window_offset_limit_x : Double = 360.0

///|
let window_offset_limit_y : Double = 220.0

///|
let window_min_width : Double = 320.0

///|
let window_max_width : Double = 1600.0

///|
let window_min_height : Double = 240.0

///|
let window_max_height : Double = 1000.0

///|
fn clamp_window_offset_x(value : Double) -> Double {
  value.max(-window_offset_limit_x).min(window_offset_limit_x)
}

///|
fn clamp_window_offset_y(value : Double) -> Double {
  value.max(-window_offset_limit_y).min(window_offset_limit_y)
}

///|
/// Registry default sizes of 0 mean "responsive default": only clamp real
/// values into the supported range.
fn clamp_window_width_if_set(value : Double) -> Double {
  if value > 0.0 {
    clamp_window_width(value)
  } else {
    0.0
  }
}

///|
fn clamp_window_height_if_set(value : Double) -> Double {
  if value > 0.0 {
    clamp_window_height(value)
  } else {
    0.0
  }
}

///|
fn clamp_window_width(value : Double) -> Double {
  value.max(window_min_width).min(window_max_width)
}

///|
fn clamp_window_height(value : Double) -> Double {
  value.max(window_min_height).min(window_max_height)
}

///|

///|
/// All windows that participate in focus and painting, oldest (bottom of the
/// stack) first. Minimized windows are excluded, matching macOS Dock
/// behavior where only minimized-to-Dock windows leave the canvas.
pub fn DesktopModel::visible_windows(
  self : DesktopModel,
) -> Array[WindowRecord] {
  let visible : Array[WindowRecord] = []
  for record in self.windows {
    if record.state != MinimizedWindow {
      visible.push(record)
    }
  }
  visible.sort_by((a, b) => a.z_order.compare(b.z_order))
  visible
}

///|
pub fn DesktopModel::window_with_id(
  self : DesktopModel,
  id : WindowId,
) -> WindowRecord? {
  for record in self.windows {
    if record.id == id {
      return Some(record)
    }
  }
  None
}

///|
/// The focused window: the visible window with the highest z-order.
pub fn DesktopModel::focused_window(self : DesktopModel) -> WindowRecord? {
  let visible = self.visible_windows()
  let top = visible.length() - 1
  if top < 0 {
    None
  } else {
    match visible.get(top) {
      Some(record) => Some(record)
      None => None
    }
  }
}

///|
pub fn DesktopModel::focused_id(self : DesktopModel) -> WindowId? {
  self.focused_window().map(record => record.id)
}

///|
pub fn DesktopModel::has_visible_window(
  self : DesktopModel,
  app : AppKind,
) -> Bool {
  for record in self.windows {
    if record.id.app == app && record.state != MinimizedWindow {
      return true
    }
  }
  false
}

///|
/// Copy-on-write replacement for the window table so TEA snapshots stay
/// independent (arrays are shared by structural copies).
fn DesktopModel::with_windows(
  self : DesktopModel,
  records : Array[WindowRecord],
) -> DesktopModel {
  { ..self, windows: records.copy() }
}

///|
/// Bring a window to the front by assigning it the next z-order value.
fn DesktopModel::raise_window(
  self : DesktopModel,
  id : WindowId,
) -> DesktopModel {
  let updated : Array[WindowRecord] = []
  let top_z = self.next_z_order
  for record in self.windows {
    if record.id == id && record.z_order < top_z {
      updated.push({ ..record, z_order: top_z })
    } else {
      updated.push(record)
    }
  }
  self.with_windows(updated).bump_z_order()
}

///|
fn DesktopModel::bump_z_order(self : DesktopModel) -> DesktopModel {
  { ..self, next_z_order: self.next_z_order + 1 }
}

///|
/// Open a window for `app`, or refocus an existing one. A minimized window
/// is restored (macOS un-minimizes instead of spawning duplicates); a hidden
/// behind-others window is raised; otherwise a new cascaded window opens.
pub fn DesktopModel::open_or_focus(
  self : DesktopModel,
  app : AppKind,
) -> DesktopModel {
  let mut best : WindowRecord? = None
  let mut minimized : WindowRecord? = None
  for record in self.windows {
    if record.id.app == app {
      match record.state {
        MinimizedWindow => if minimized is None { minimized = Some(record) }
        _ =>
          match best {
            Some(current) =>
              if record.z_order > current.z_order {
                best = Some(record)
              }
            None => best = Some(record)
          }
      }
    }
  }
  match best {
    Some(record) => self.raise_window(record.id)
    None =>
      match minimized {
        Some(record) => self.restore_record(record).raise_window(record.id)
        None => self.create_window(app)
      }
  }
}

///|
fn DesktopModel::restore_record(
  self : DesktopModel,
  record : WindowRecord,
) -> DesktopModel {
  let updated : Array[WindowRecord] = []
  for candidate in self.windows {
    if candidate.id == record.id {
      updated.push({ ..candidate, state: NormalWindow })
    } else {
      updated.push(candidate)
    }
  }
  self.with_windows(updated)
}

///|
/// Create a new window for `app` with a cascade offset derived from how many
/// windows already exist, then focus it.
fn DesktopModel::create_window(
  self : DesktopModel,
  app : AppKind,
) -> DesktopModel {
  let serial = self.next_window_serial
  let cascade = self.windows.length()
  let step_x = cascade.to_double() * 34.0
  let step_y = cascade.to_double() * 30.0
  // The registry supplies each app's preferred normal window size; 0 keeps
  // the responsive default for that axis.
  let descriptor = app.descriptor()
  let record : WindowRecord = {
    id: { app, serial },
    state: NormalWindow,
    bounds: {
      offset_x: clamp_window_offset_x(step_x),
      offset_y: clamp_window_offset_y(step_y),
      width: clamp_window_width_if_set(descriptor.default_width),
      height: clamp_window_height_if_set(descriptor.default_height),
    },
    z_order: self.next_z_order,
  }
  let table = self.windows.copy()
  table.push(record)
  {
    ..self,
    windows: table,
    next_window_serial: serial + 1,
    next_z_order: self.next_z_order + 1,
  }
}

///|
fn DesktopModel::close_focused(self : DesktopModel) -> DesktopModel {
  match self.focused_id() {
    Some(id) => self.close_window(id)
    None => self
  }
}

///|
pub fn DesktopModel::close_window(
  self : DesktopModel,
  id : WindowId,
) -> DesktopModel {
  let kept : Array[WindowRecord] = []
  for record in self.windows {
    if record.id != id {
      kept.push(record)
    }
  }
  self.with_windows(kept)
}

///|
fn DesktopModel::minimize_focused(self : DesktopModel) -> DesktopModel {
  match self.focused_id() {
    Some(id) => self.minimize_window(id)
    None => self
  }
}

///|
pub fn DesktopModel::minimize_window(
  self : DesktopModel,
  id : WindowId,
) -> DesktopModel {
  let updated : Array[WindowRecord] = []
  for record in self.windows {
    if record.id == id && record.state != MinimizedWindow {
      updated.push({ ..record, state: MinimizedWindow })
    } else {
      updated.push(record)
    }
  }
  self.with_windows(updated)
}

///|
/// Zoom (maximize/restore) a specific window without touching its normal
/// bounds, so restore keeps the pre-zoom geometry.
pub fn DesktopModel::toggle_zoom_window(
  self : DesktopModel,
  id : WindowId,
) -> DesktopModel {
  let updated : Array[WindowRecord] = []
  for record in self.windows {
    if record.id == id {
      let state = if record.state == MaximizedWindow {
        NormalWindow
      } else {
        MaximizedWindow
      }
      updated.push({ ..record, state, })
    } else {
      updated.push(record)
    }
  }
  self.with_windows(updated)
}

///|
fn DesktopModel::toggle_zoom_focused(self : DesktopModel) -> DesktopModel {
  match self.focused_id() {
    Some(id) => self.toggle_zoom_window(id)
    None => self
  }
}

///|
/// Move the focused window by a drag delta. Dragging a zoomed window first
/// restores it (macOS behavior) while keeping the previous normal offsets so
/// zoom / restore stays stable.
fn DesktopModel::move_focused_by(
  self : DesktopModel,
  dx : Double,
  dy : Double,
) -> DesktopModel {
  match self.focused_window() {
    Some(focused) => {
      let base = if focused.state == MaximizedWindow {
        NormalWindow
      } else {
        focused.state
      }
      let updated : Array[WindowRecord] = []
      for record in self.windows {
        if record.id == focused.id {
          updated.push({
            ..record,
            state: base,
            bounds: {
              ..record.bounds,
              offset_x: clamp_window_offset_x(record.bounds.offset_x + dx),
              offset_y: clamp_window_offset_y(record.bounds.offset_y + dy),
            },
          })
        } else {
          updated.push(record)
        }
      }
      self.with_windows(updated)
    }
    None => self
  }
}

///|
/// Store an absolute size for a window (the view resolves responsive
/// defaults before dispatching, so the model only clamps). Zoomed and
/// minimized windows ignore resize gestures.
pub fn DesktopModel::resize_window(
  self : DesktopModel,
  id : WindowId,
  width : Double,
  height : Double,
) -> DesktopModel {
  let updated : Array[WindowRecord] = []
  for record in self.windows {
    if record.id == id {
      match record.state {
        NormalWindow =>
          updated.push({
            ..record,
            bounds: {
              ..record.bounds,
              width: clamp_window_width(width),
              height: clamp_window_height(height),
            },
          })
        _ => updated.push(record)
      }
    } else {
      updated.push(record)
    }
  }
  self.with_windows(updated)
}
