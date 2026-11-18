# Titlebar controls polish (close/minimize/maximize + titlebar)

Status: active
Parent issue: #24 (completion beyond PR #26)
Branch: `feature/cursor-and-window-chrome` (lands in PR #26)

## Goal

Bring MoUI's self-drawn Linux CSD titlebar and window-control plumbing to the
maturity level of production frameworks (Winc, mygo/Electron/GTK), without
re-drawing platform chrome where the OS already does it well.

Confirmed decisions (user, 2026-11-18):

- macOS keeps the system traffic lights forever. 12 pt size is fixed by the
  OS; only titlebar height and control position are adjustable. Self-drawn
  macOS buttons are a non-goal (Winc's re-parenting trick is rejected:
  fighting AppKit resets on theme/title/size changes and fullscreen
  transitions is recurring cost for zero user-visible gain).
- Linux CSD buttons become theme-sized, stateful controls (hover/pressed),
  policy-driven layout, maximize/restore icon follows state, semantics
  exposed, and the titlebar insets are available to app code.
- Right-click window menu: dropped from scope.
- Edge resize: out of scope (window crate C side owns it).
- No bitmap assets: icons stay vector-drawn from theme tokens.

## Phases

### Phase 1 — policy-driven, stateful CSD buttons + insets API

- `LinuxTitlebarPolicy` (pure data): button set and order (close, minimize,
  maximize/restore), edge side, per-state metrics derived from titlebar
  height and theme tokens. Paint and hit-testing both consume the policy —
  `linux_titlebar_button_slot_rect` stays the single geometry source, now
  policy-driven.
- Button state machine: idle / hover / pressed. Visual feedback from theme
  tokens (background highlight + icon color); no hardcoded colors.
- Maximize button renders maximize or restore icon depending on the
  window's observed `maximized` state (Windows behavior).
- Semantics: titlebar container and each button expose role + accessible
  names ("关闭", "最小化", "最大化", "还原") through the existing ViewNode
  semantics pipeline.
  Implementation finding: the CSD band is host-painted `DrawCommand` chrome,
  not a view subtree, so the ViewNode semantics pipeline cannot see it.
  Host-chrome accessibility needs an AT-SPI-level design on the Linux host
  (window titlebar objects under the window's accessibility entry) and is
  recorded as its own follow-up slice rather than faked here.
- Insets API: the titlebar's occupied space (left/right/bottom/height) is
  exposed through platform services so app chrome can lay out against it
  (mygo's `c.TitleBar()` model). Non-CSD platforms report system values
  (height of the server-side titlebar) or zeros where inapplicable.
- Tests: policy layout (incl. maximized-state icon), hit-testing, state
  machine transitions, semantics exposure; X11/Xvfb run evidence in
  `artifacts/`.

### Phase 2 — event timestamps + double-click zoom

- backend/common input pipeline stamps host pointer events with the host
  clock (same timeline as `AppEnvironment.clock`); the normalized `Event`
  gains an optional timestamp, defaulting to absent for existing hosts.
- CSD titlebar double-click toggles maximize (with debounce), matching
  Windows/GNOME behavior; platform-layer ownership mirrors mygo's
  `TitleBarDoubleClicked`.
- Tests: synthetic timestamp sequences for double-click detection; X11
  round-trip evidence.

### Phase 4 — matching-host Wayland evidence

- weston (x11-backend) nested in Xvfb; the app connects via the Wayland
  socket so `uses_client_decorations()` activates and the CSD path runs for
  real. Screenshot/recording evidence for buttons, drag, double-click.
- Requires a one-time `weston` install on the host (user action).

## Engineering discipline

- Each phase lands as its own commit; budgets registered with rationale
  (source-file-policy 25-line quantum included); interface files minimal
  incremental edits; evidence stays in `artifacts/`; X11 claims never stand
  in for Wayland until Phase 4.
