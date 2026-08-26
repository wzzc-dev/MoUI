# mo_desktop multi-window model (M1) — landed

Date: 2026-07 session. Goal: FluentOS-inspired upgrade of `examples/mo_desktop`.

## State after M1 (multi-window)

- `examples/mo_desktop/app/windows.mbt`: `AppKind { FinderApp | SafariApp }`,
  `WindowId { app, serial }`, `WindowState { NormalWindow | MinimizedWindow |
  MaximizedWindow }`, `WindowBounds { offset_x, offset_y, width, height }`
  (0.0 w/h = responsive default), `WindowRecord { id, state, bounds, z_order }`.
- `DesktopModel.windows : Array[WindowRecord]` replaced `active_window`,
  `window_maximized`, `window_offset_*`. Focus = visible window with max
  z_order; raise assigns `next_z_order`. Copy-on-write array updates only.
- Messages: `FocusWindow / CloseWindowAt / MinimizeWindowAt / ToggleZoomAt /
  ResizeWindowBy(id,w,h)` target explicit windows; `CloseWindow /
  MinimizeWindow / ToggleMaximize / MoveWindowBy` act on focused.
- Semantics: Dock-style `OpenFinder/OpenSafari` = open-or-focus (restores
  minimized); menu `OpenFinderWindow/OpenSafariWindow` = always create new
  cascaded instance; `BringFinderForward/BringSafariForward` = open-or-focus.
  Drag from Maximized restores keeping normal bounds. Resize stores clamped
  size via invisible drag surface over painted grip.
- Views: `app_window(model, record, body, ...)` shared shell (focus-aware
  shadow/rim/titlebar dimming); bodies are `finder_body` / `safari_body`;
  paint order = `visible_windows()` sorted by z ascending.
- Tests: 19 passed on native AND wasm-gc (`moon test examples/mo_desktop/app`).
  Baseline was 11; +7 model tests, +1 runtime two-window test.

## State after M2 (versioned persistence)

- `examples/mo_desktop/app/persistence.mbt`: `DesktopSnapshot`
  (schema_version=2; dark_mode, wallpaper_source, volume, brightness,
  wifi/bt/low_power, windows, recent_files, icon_placements) with
  ToJson/FromJson; `encode_/decode_desktop_snapshot` (tolerant: corrupt JSON
  or unknown version -> None); legacy v1 (`window_offset_x/y` +
  `window_maximized`) migrates to a single-window v2 table.
- Storage goes through `SettingsServices.read/write/remove(SETTINGS_STORAGE_KEY)`
  as typed ServiceTasks — no storage API in the app package. `moon.pkg` adds
  only `moonbitlang/core/json` (precedent: mo_workbench).
- program.mbt: init batches appearance + settings load; update_with_services
  auto-saves when `persisted_snapshot()` changes and `settings_loaded`;
  DesktopSettingsLoaded/ResetCompleted + ResetDesktopSettings are excluded
  from auto-save (load must not re-write; reset must actually clear).
- Model: `settings_loaded`, `icon_placements`, msgs LoadDesktopSettings /
  DesktopSettingsLoaded / Saved / ResetDesktopSettings / ResetCompleted /
  MoveDesktopIcon(name,dx,dy) (clamped ±320/±420); menu command
  ResetDesktopSettingsCommand ("Reset All Settings" in SystemMenu).
- Desktop icons ("Tahoe Trip", "Welcome.txt") are draggable via on_drag ->
  MoveDesktopIcon; offsets render through `.offset`.
- Json gotchas: use `@json.parse(text) catch {..}`, `try { @json.from_json }`,
  `payload { Object(fields) => fields.get(..), Some(Number(raw, ..)) }`;
  `Json::value/as_number` are deprecated; serialize via
  `ToJson::to_json(x).stringify()`.

## State after M3 (app registry + Notes/Terminal)

- `examples/mo_desktop/app/apps.mbt`: `AppDescriptor { id, label, detail,
  icon, color, default_width, default_height, dock_priority }` +
  `app_registry()` (Finder, Safari, Notes 760x520, Terminal 720x480).
  `AppKind` gained NotesApp/TerminalApp; `AppKind::label()` now reads the
  registry. `create_window` fills bounds from descriptor defaults
  (`clamp_window_width_if_set`: 0.0 keeps responsive sizing).
- New apps: `view_notes.mbt` (sidebar + text_area editor; model fields
  notes/active_note), `view_terminal.mbt` (fake shell: help/apps/date/echo/
  open <app>/clear; `open safari|finder|notes|terminal` really launches via
  open_or_focus). Messages LaunchApp(AppKind) drives Dock tiles, launcher
  Apps tab, Spotlight rows - all three iterate app_registry().
- Persistence bumped to schema v3: snapshot gained `notes`; v2 payloads
  migrate (DesktopSnapshotV2 struct -> fill default note); v1 path intact.
- Menu bar gained a "Spotlight" text button (ToggleSpotlight had NO entry
  point before). Note: Finder toolbar also draws text "Search" - runtime
  click_text("Search") hits the wrong frame; use "Spotlight".
- Tests: 31 passed on native AND wasm-gc.

## Gotchas (new)

- No `Array::from_array` / no spread-into-literal for arrays: build with
  push loops.
- `@views.button` has no enabled param - render conditionally instead.
- CrossAlign variants are Start/Center/End/Stretch (no Leading).
- StringView: use `.to_owned()` not `.to_string()`; slices are `s[a:b]`.
- Array method is `.length()`, not `.size()`.
- Record-update syntax requires `..self` first in the literal.

## State after M4 (session flow)

- `SessionPhase { Boot | Locked | Login | Unlocked }`. Init phase is Boot.
  Boot auto-advances on the second `ClockUpdated` tick (reuses the 1s clock
  subscription; no new timer plumbing) and `AdvanceBoot` (tap anywhere)
  skips it - headless runtimes without a timer must tap through.
- Login: `ShowLogin` (Locked->Login, Enter shortcut on Sign In button),
  `LoginPasswordChanged`, `SubmitLogin(_)`: demo account accepts ANY
  password incl. empty; guards make wrong-phase submissions inert.
- `LogOutSession` menu command (System menu, above Lock Screen) returns to
  Login keeping the window table. LockSession/LockDesktop -> Locked.
- Runtime test flow: `skip_boot(runtime)` helper clicks "Starting Mo
  Desktop", then "Sign In" then "Unlock". NOTE: has_text is EXACT match -
  assert "Demo account — any password works" in full.
- Tests: 33 passed native + wasm-gc.

## State after M5 (i18n + final DoD)

- `i18n.mbt`: `AppLanguage { EnglishLanguage | ChineseLanguage }` with
  app-owned en-US / zh-Hans catalogs using `moui_i18n` (Catalog/Translator).
  Session screens, menu titles, and menu items localize via
  `AppLanguage.text/translate`; System menu has a language toggle labelled in
  the target language ("中文" / "English"). Schema bumped to v4 with language
  persisted; v1/v2/v3 migration paths all tested.
- Final DoD all satisfied:
  - 39 tests native + wasm-gc (≥30).
  - `moon check` clean on native/wasm-gc/web_wasm; `moon fmt` clean.
  - `docs/mo-desktop.md` added and indexed in docs/INDEX.md.
  - README now attributes FluentOS-On-Web (MIT).
  - Validators passed: validate-doc-references, validate-maintenance-baseline,
    validate-api-surface.
- Remaining after goal: none (Goal complete).

## Interaction bugs found & fixed (post-goal hardening)

User-reported: close button dead, titlebar drag dead, dock shadow odd.

Root causes:
1. Canvas/gesture nodes intercept pointers across their FULL paint bounds.
   The decorative resize-grip canvas covered the whole window and swallowed
   every event (close/drag/sidebar all deaf). FIX: grip is now a 26x26
   self-contained cell aligned bottom-trailing (paint + drag on one node).
2. DrawShadow commands created pointer-overlay regions in
   moui/runtime/input_pointer.mbt, so a background window glow misrouted
   clicks aimed at the focused window. FIX: pointer_overlay_command_bounds
   returns None for DrawShadow (framework change; runtime 109/109 green).
3. **Modifier ORDER defines gesture hit area**: `node.frame(small)
   .align(bt).on_drag(...)` makes the drag node inherit the PARENT slot as
   its hit area (resize-on-any-drag, dead buttons). Bind gestures to the
   small sized node BEFORE align: `.frame(small).on_drag(...).align(bt)`.
4. Title text nodes swallow pointer taps of the parent behind them; give the
   title label the same drag/zoom/focus handlers so the whole titlebar drags.
5. Traffic-light hover glyphs were removed (dots are plain tap targets).
   If re-added, paint inside the tappable node or attach the same message.

Also tightened window shadows (focused 30/12/.55; unfocused 16/8/.32) to
reduce bleed over the translucent dock.

Follow-up: headless runtime regression tests for click-close/drag are flaky
(stray secondary CREATE dispatches); needs framework event tracing before
re-adding. Model-level coverage remains complete.

## Gotchas

- Blackbox `_test.mbt` files see only pub API; use qualified
  `AppLanguage::EnglishLanguage` and `pub fn` helpers in catalogs.
- `toggle_label()` shows the TARGET language name (Chinese active -> "English"),
  not the current language.
- MoonBit struct copies share Array fields; always copy before mutate.
- Dock tiles are icon-only (accessibility labels, no draw text): runtime
  tests drive menus via `click_text("Window")` then item text instead.
- Menu bar app title follows focused window; old tests asserting literal
  "Finder" text fail once Safari is focused.
