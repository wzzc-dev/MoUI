// Versioned desktop persistence. The snapshot document is encoded as JSON
// and stored through the injected `SettingsServices` key-value boundary, so
// the shared app package never touches localStorage/IndexedDB/file paths.

///|
/// Where the desktop snapshot lives in the platform settings store.
pub const SETTINGS_STORAGE_KEY : String = "mo_desktop:desktop"

///|
/// Current snapshot schema version. Bump when the shape changes and add a
/// migration branch in `decode_desktop_snapshot`.
pub const SNAPSHOT_SCHEMA_VERSION : Int = 4

///|
/// Persisted position of one desktop icon relative to its default slot.
pub(all) struct DesktopIconPlacement {
  name : String
  offset_x : Double
  offset_y : Double
} derive(Eq, Debug, ToJson, FromJson)

///|
/// Versioned, serializable projection of everything the desktop restores on
/// launch: appearance, media levels, icon layout, window geometry, and the
/// recently imported files.
pub(all) struct DesktopSnapshot {
  schema_version : Int
  dark_mode : Bool
  wallpaper_source : String
  volume : Double
  brightness : Double
  wifi_enabled : Bool
  bluetooth_enabled : Bool
  low_power_mode : Bool
  windows : Array[WindowRecord]
  recent_files : Array[String]
  notes : Array[String]
  language : String
  icon_placements : Array[DesktopIconPlacement]
} derive(Eq, Debug, ToJson, FromJson)

///|
fn DesktopSnapshot::of(
  dark_mode : Bool,
  wallpaper_source : String,
  volume : Double,
  brightness : Double,
  wifi_enabled : Bool,
  bluetooth_enabled : Bool,
  low_power_mode : Bool,
  windows : Array[WindowRecord],
  recent_files : Array[String],
  notes : Array[String],
  language : String,
  icon_placements : Array[DesktopIconPlacement],
) -> DesktopSnapshot {
  {
    schema_version: SNAPSHOT_SCHEMA_VERSION,
    dark_mode,
    wallpaper_source,
    volume,
    brightness,
    wifi_enabled,
    bluetooth_enabled,
    low_power_mode,
    windows: windows.copy(),
    recent_files: recent_files.copy(),
    notes: notes.copy(),
    language,
    icon_placements: icon_placements.copy(),
  }
}

///|
/// Legacy v1 snapshot: a single active window expressed as offsets plus a
/// zoom flag. Kept only so older payloads migrate forward instead of being
/// discarded.
struct DesktopSnapshotV1 {
  dark_mode : Bool
  wallpaper_source : String
  volume : Double
  brightness : Double
  window_offset_x : Double
  window_offset_y : Double
  window_maximized : Bool
} derive(FromJson)

///|
fn DesktopSnapshotV1::migrate(self : DesktopSnapshotV1) -> DesktopSnapshot {
  let bounds : WindowBounds = {
    offset_x: self.window_offset_x,
    offset_y: self.window_offset_y,
    width: 0.0,
    height: 0.0,
  }
  let record : WindowRecord = {
    id: { app: FinderApp, serial: 1 },
    state: if self.window_maximized {
      MaximizedWindow
    } else {
      NormalWindow
    },
    bounds,
    z_order: 1,
  }
  {
    schema_version: SNAPSHOT_SCHEMA_VERSION,
    dark_mode: self.dark_mode,
    wallpaper_source: self.wallpaper_source,
    volume: self.volume,
    brightness: self.brightness,
    wifi_enabled: true,
    bluetooth_enabled: true,
    low_power_mode: false,
    windows: [record],
    recent_files: [],
    notes: [default_note_body()],
    language: EnglishLanguage.tag(),
    icon_placements: [],
  }
}

///|
/// Version 2 snapshot shape: current fields except Notes bodies.
struct DesktopSnapshotV2 {
  dark_mode : Bool
  wallpaper_source : String
  volume : Double
  brightness : Double
  wifi_enabled : Bool
  bluetooth_enabled : Bool
  low_power_mode : Bool
  windows : Array[WindowRecord]
  recent_files : Array[String]
  icon_placements : Array[DesktopIconPlacement]
} derive(FromJson)

///|
fn DesktopSnapshotV2::migrate(self : DesktopSnapshotV2) -> DesktopSnapshot {
  {
    schema_version: SNAPSHOT_SCHEMA_VERSION,
    dark_mode: self.dark_mode,
    wallpaper_source: self.wallpaper_source,
    volume: self.volume,
    brightness: self.brightness,
    wifi_enabled: self.wifi_enabled,
    bluetooth_enabled: self.bluetooth_enabled,
    low_power_mode: self.low_power_mode,
    windows: self.windows.copy(),
    recent_files: self.recent_files.copy(),
    notes: [default_note_body()],
    language: EnglishLanguage.tag(),
    icon_placements: self.icon_placements.copy(),
  }
}

///|
/// Version 3 snapshot shape: current fields except the UI language.
struct DesktopSnapshotV3 {
  dark_mode : Bool
  wallpaper_source : String
  volume : Double
  brightness : Double
  wifi_enabled : Bool
  bluetooth_enabled : Bool
  low_power_mode : Bool
  windows : Array[WindowRecord]
  recent_files : Array[String]
  notes : Array[String]
  icon_placements : Array[DesktopIconPlacement]
} derive(FromJson)

///|
fn DesktopSnapshotV3::migrate(self : DesktopSnapshotV3) -> DesktopSnapshot {
  {
    schema_version: SNAPSHOT_SCHEMA_VERSION,
    dark_mode: self.dark_mode,
    wallpaper_source: self.wallpaper_source,
    volume: self.volume,
    brightness: self.brightness,
    wifi_enabled: self.wifi_enabled,
    bluetooth_enabled: self.bluetooth_enabled,
    low_power_mode: self.low_power_mode,
    windows: self.windows.copy(),
    recent_files: self.recent_files.copy(),
    notes: self.notes.copy(),
    language: EnglishLanguage.tag(),
    icon_placements: self.icon_placements.copy(),
  }
}

///|
pub fn encode_desktop_snapshot(snapshot : DesktopSnapshot) -> String {
  ToJson::to_json(snapshot).stringify()
}

///|
/// Tolerant decode: returns `None` for corrupt payloads or unsupported
/// schema versions so callers can fall back to defaults safely. Version 1
/// payloads are migrated forward instead of being discarded.
pub fn decode_desktop_snapshot(text : String) -> DesktopSnapshot? {
  let payload = @json.parse(text) catch { _ => return None }
  let version : Int = match payload {
    Object(fields) =>
      match fields.get("schema_version") {
        Some(Number(raw, ..)) => raw.to_int()
        _ => return None
      }
    _ => return None
  }
  if version == SNAPSHOT_SCHEMA_VERSION {
    try {
      let snapshot : DesktopSnapshot = @json.from_json(payload)
      Some(snapshot)
    } catch {
      _ => None
    }
  } else if version == 3 {
    try {
      let legacy : DesktopSnapshotV3 = @json.from_json(payload)
      Some(legacy.migrate())
    } catch {
      _ => None
    }
  } else if version == 2 {
    try {
      let legacy : DesktopSnapshotV2 = @json.from_json(payload)
      Some(legacy.migrate())
    } catch {
      _ => None
    }
  } else if version == 1 {
    try {
      let legacy : DesktopSnapshotV1 = @json.from_json(payload)
      Some(legacy.migrate())
    } catch {
      _ => None
    }
  } else {
    None
  }
}

///|
/// The persistable projection of the current model. Compared before/after
/// each update to decide whether a settings write is worth issuing.
pub fn DesktopModel::persisted_snapshot(self : DesktopModel) -> DesktopSnapshot {
  DesktopSnapshot::of(
    self.dark_mode,
    self.wallpaper_source,
    self.volume,
    self.brightness,
    self.wifi_enabled,
    self.bluetooth_enabled,
    self.low_power_mode,
    self.windows,
    self.imported_files,
    self.notes,
    self.language.tag(),
    self.icon_placements,
  )
}

///|
/// Apply a decoded snapshot. Only meaningful values are overwritten; the
/// model keeps its own defaults for anything the snapshot leaves out.
pub fn DesktopModel::restore_snapshot(
  self : DesktopModel,
  snapshot : DesktopSnapshot,
) -> DesktopModel {
  {
    ..self,
    dark_mode: snapshot.dark_mode,
    appearance: if snapshot.dark_mode {
      DarkAppearance
    } else {
      LightAppearance
    },
    wallpaper_source: snapshot.wallpaper_source,
    volume: snapshot.volume.max(0.0).min(1.0),
    brightness: snapshot.brightness.max(0.0).min(1.0),
    wifi_enabled: snapshot.wifi_enabled,
    bluetooth_enabled: snapshot.bluetooth_enabled,
    low_power_mode: snapshot.low_power_mode,
    windows: snapshot.windows.copy(),
    imported_files: snapshot.recent_files.copy(),
    notes: if snapshot.notes.is_empty() {
      [default_note_body()]
    } else {
      snapshot.notes.copy()
    },
    active_note: 0,
    language: AppLanguage::parse(snapshot.language),
    icon_placements: snapshot.icon_placements.copy(),
    next_window_serial: next_serial_after(snapshot.windows),
    next_z_order: next_z_after(snapshot.windows),
  }
}

///|
fn next_serial_after(windows : Array[WindowRecord]) -> Int {
  let mut highest = 0
  for record in windows {
    if record.id.serial > highest {
      highest = record.id.serial
    }
  }
  highest + 1
}

///|
fn next_z_after(windows : Array[WindowRecord]) -> Int {
  let mut highest = 0
  for record in windows {
    if record.z_order > highest {
      highest = record.z_order
    }
  }
  highest + 1
}

///|
fn DesktopModel::icon_placement(
  self : DesktopModel,
  name : String,
) -> (Double, Double) {
  for placement in self.icon_placements {
    if placement.name == name {
      return (placement.offset_x, placement.offset_y)
    }
  }
  (0.0, 0.0)
}

///|
/// Move a desktop icon by a drag delta, creating its placement entry on
/// first move. Deltas are clamped so icons stay near the desktop surface.
pub fn DesktopModel::move_icon_by(
  self : DesktopModel,
  name : String,
  dx : Double,
  dy : Double,
) -> DesktopModel {
  let limit_x = 320.0
  let limit_y = 420.0
  let clamp = fn(value : Double, limit : Double) {
    value.max(-limit).min(limit)
  }
  let updated : Array[DesktopIconPlacement] = []
  let mut found = false
  for placement in self.icon_placements {
    if placement.name == name {
      found = true
      updated.push({
        ..placement,
        offset_x: clamp(placement.offset_x + dx, limit_x),
        offset_y: clamp(placement.offset_y + dy, limit_y),
      })
    } else {
      updated.push(placement)
    }
  }
  if !found {
    updated.push({
      name,
      offset_x: clamp(dx, limit_x),
      offset_y: clamp(dy, limit_y),
    })
  }
  { ..self, icon_placements: updated }
}
