// Application registry. The desktop's Dock, launcher, Spotlight, and window
// factory all read from this table instead of hardcoding app identities, so
// adding an app means appending a descriptor plus its typed view/update.

///|
/// One entry in the desktop application registry. Data only: behavior stays
/// in the app's typed message/update/view; the shell consults the
/// descriptor for labels, artwork hints, and default window geometry.
pub(all) struct AppDescriptor {
  id : AppKind
  label : String
  detail : String
  icon : @views.IconName
  color : @graphics.Color
  /// Preferred normal-state window size. A value of 0.0 keeps the
  /// responsive default sizing for that axis.
  default_width : Double
  default_height : Double
  /// Ordering hint: lower values appear earlier in the Dock and launcher.
  dock_priority : Int
} derive(Eq, Debug)

///|
fn app_descriptor(
  id : AppKind,
  label : String,
  detail : String,
  icon : @views.IconName,
  color : @graphics.Color,
  default_width? : Double = 0.0,
  default_height? : Double = 0.0,
  dock_priority? : Int = 0,
) -> AppDescriptor {
  {
    id,
    label,
    detail,
    icon,
    color,
    default_width,
    default_height,
    dock_priority,
  }
}

///|
/// The full application registry, ordered by Dock priority.
pub fn app_registry() -> Array[AppDescriptor] {
  let entries = [
    app_descriptor(
      FinderApp,
      "Finder",
      "Browse local files",
      FolderOpen,
      rgba8(33, 150, 243),
      dock_priority=0,
    ),
    app_descriptor(
      SafariApp,
      "Safari",
      "Browse the web",
      Link,
      rgba8(36, 177, 216),
      dock_priority=1,
    ),
    app_descriptor(
      NotesApp,
      "Notes",
      "Capture quick thoughts",
      FileNew,
      rgba8(244, 170, 53),
      default_width=760.0,
      default_height=520.0,
      dock_priority=2,
    ),
    app_descriptor(
      TerminalApp,
      "Terminal",
      "Run desktop commands",
      CodeInline,
      rgba8(45, 52, 64),
      default_width=720.0,
      default_height=480.0,
      dock_priority=3,
    ),
  ]
  entries.sort_by((a, b) => a.dock_priority.compare(b.dock_priority))
  entries
}

///|
pub fn AppKind::descriptor(self : AppKind) -> AppDescriptor {
  for entry in app_registry() {
    if entry.id == self {
      return entry
    }
  }
  // Unreachable while every AppKind has a descriptor; fall back to Finder
  // so the compiler never sees a partial match at call sites.
  app_descriptor(
    FinderApp,
    "Finder",
    "Browse local files",
    FolderOpen,
    rgba8(33, 150, 243),
  )
}

///|
pub fn AppKind::label(self : AppKind) -> String {
  self.descriptor().label
}
