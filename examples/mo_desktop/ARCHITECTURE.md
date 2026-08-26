# Mo Desktop example architecture

`examples/mo_desktop` is MoUI's desktop-shell example: a multi-window desktop
simulation with a session flow, an application registry, persisted settings,
and bilingual UI copy. It is a product showcase, not a framework component —
everything lives in the shared `app` package plus thin platform entrypoints
(`web_wasm`, `macos_skia`).

## Package boundary

```
examples/mo_desktop/
├── app/            # all model/view/persistence logic (this doc)
├── web_wasm/       # composition root: program + WebGPU renderer + web backend
└── macos_skia/     # composition root: Skia renderer entrypoint
```

The `app` package depends only on `wzzc-dev/moui`, `views`, `services`,
small core helpers (`geometry`, `graphics`, `state`, `text`),
`moonbitlang/core/json`, and the optional `wzzc-dev/moui_i18n` addon. It never
imports runtimes, renderers, or platform backends; both entrypoints stay thin
wiring.

## Window model (`windows.mbt`, `apps.mbt`)

- Identity: `WindowId { app : AppKind, serial : Int }`; serials come from a
  monotonic counter and are never reused within a session.
- Records: `WindowRecord { id, state, bounds, z_order }` with
  `WindowState { NormalWindow | MinimizedWindow | MaximizedWindow }`.
  `bounds` stores center-relative offsets plus an explicit size where `0.0`
  means "responsive default".
- Focus: the visible window with the highest `z_order`. Raising assigns
  `next_z_order`; closing or minimizing falls focus back to the next window.
- The table is an `Array[WindowRecord]` updated copy-on-write so TEA snapshots
  stay independent (struct copies share array storage).
- Messages split by target: focused-window commands (`CloseWindow`,
  `MoveWindowBy`, …) for keyboard/menu use, and explicit-target messages
  (`FocusWindow(id)`, `CloseWindowAt(id)`, `ResizeWindowBy(id, w, h)`) for
  per-window chrome like traffic lights and the resize grip.

## Application registry (`apps.mbt`)

`AppDescriptor { id, label, detail, icon, color, default_width,
default_height, dock_priority }` drives everything app-shaped:

- Dock tiles, launcher entries, and Spotlight rows iterate `app_registry()`.
- `create_window` seeds new windows with the descriptor's default size
  (0 keeps responsive sizing).
- Adding an app means appending a descriptor plus its typed view/update —
  no shell code changes. `LaunchApp(AppKind)` is open-or-focus; menu commands
  `OpenFinderWindow` / `OpenSafariWindow` always spawn a cascaded instance.

Built-in apps: Finder, Safari (demo browser), Notes (persisted), Terminal
(fake shell whose `open <app>` command really launches apps).

## Persistence (`persistence.mbt`)

- Boundary: `SettingsServices.read/write/remove` typed `ServiceTask`s. The
  shared package contains no storage APIs.
- Document: `DesktopSnapshot` with `schema_version = 4` covering appearance,
  wallpaper, volume/brightness, connectivity switches, the window table,
  recent files, Notes bodies, UI language, and icon placements.
- Migrations: v1 (single-window offsets) and v2/v3 shapes migrate forward;
  corrupt payloads or unknown versions decode to `None` and fall back to
  defaults with a diagnostic.
- Save policy: after each update, if the projected snapshot changed and the
  initial load completed, a write effect is batched in. Load/reset messages are
  excluded so restore never re-writes and reset actually clears storage.
- "Reset All Settings" restores factory values and removes the stored key.

## Session flow

`SessionPhase { Boot | Locked | Login | Unlocked }`.

- Boot auto-advances on the second clock tick and accepts a tap to skip.
- Login accepts any password (demo account); wrong-phase messages are inert.
- Lock Screen keeps windows; Log Out returns to Login preserving them.
- PIN/account logic is deliberately a product model here — it never sinks
  into MoUI core.

## Internationalization (`i18n.mbt`)

Catalogs are product data owned by the app package, built on `moui_i18n`'s
`Catalog`/`Translator`. `AppLanguage { EnglishLanguage | ChineseLanguage }`
selects `en-US` / `zh-Hans` fallback chains; the System menu carries a toggle
labelled in the target language ("中文" / "English"). All system chrome —
session screens, menu titles, and menu items — resolves through the catalog;
interpolation uses named values such as `Close {app}`. Diagnostics inside the
update layer are developer telemetry and are not translated.

## Theme mapping

Visual styling maps FluentOS-inspired design intent onto MoUI primitives:
`DesktopPalette` (theme.mbt) owns accent/glass/shadow tokens resolved per dark
mode, `@moui.Theme` flows ambiently through every control, and materials use
translucent fills + shadows rather than CSS effects. No CSS, DOM overlays, or
platform styles are involved.
