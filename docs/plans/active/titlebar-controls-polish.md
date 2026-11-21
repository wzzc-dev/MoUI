# Titlebar controls polish (close/minimize/maximize + titlebar)

Status: active (Phase 1 + 2 landed; Phase 4 evidence captured)
Parent issue: #24 (completion beyond PR #26)
Branch: `feature/cursor-and-window-chrome` (lands in PR #26)
Companion: wzzc-dev/window PR #3 (merged, 0.5.4-0.2.13 published)

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

### Phase 2 — double-click zoom (delivered at the platform layer)

Delivered in wzzc-dev/window (PR #3, 0.5.4-0.2.13) instead of the originally
planned host-timestamp design: the native Wayland layer already owns the
bare-band move gesture, so the double-click detector lives beside it (second
press within 400 ms and 8 px of the first toggles maximize via the same
native path). This matches Winc/mygo platform-layer ownership and avoids
duplicating the gesture clock on the host side. The host-timestamp plumbing
design above is retired.

- Native: bare-band double-click toggles maximize; button-slot double presses
  stay ordinary clicks (two single activations).
- Host: `Event::MaximizedChanged(Bool)` from `xdg_toplevel` configure lands on
  the window record, so the observed state (restore glyph, `controls.
  maximized()`) is correct for every maximize/restore source — compositor
  shortcut, tiling gesture, CSD request, double-click.
- Evidence (nested weston, Xvfb): double-click maximizes/restores
  (`artifacts/91_dblclick_max.png`, `92_dblclick_restore.png`); CSD-button
  maximize → restore glyph + `MAXIMIZED=TRUE` (`60_clean_after.png`,
  `maximized_glyph_zoom.png`); pressed shrink pixel-verified (strict-green
  48 → 36 while held, `78_p11_pressed.png`); protocol traces
  (`app_wl2.log`, `app_wl3.log`).

### Follow-ups

- Restore geometry under weston: `unset_maximized` on a fully maximized CSD
  window gets a configure that echoes the maximized size (1600×968) instead
  of 0×0, so the client stays large while the compositor animates it to a new
  position. State stays correct (`MAXIMIZED=FALSE`, restore glyph); the size
  choice belongs to the window crate's restore sizing (prefer saved
  restore_width on `pending_unmaximize` when the compositor echoes the
  maximized size). Recorded for the next window slice.
- CSD semantics: host-painted chrome needs an AT-SPI-level design (see
  Phase 1 finding).
- Runtime palette refresh on system theme switch (currently frozen at
  creation).

### Phase 4 — matching-host Wayland evidence (done)

- weston 13.0.0 (x11-backend, pixman renderer) nested in Xvfb; the app
  connects via the `wayland-moui` socket so the CSD path runs for real.
  Phase 1 + Phase 2 evidence listed above; single-instance discipline and
  `WAYLAND_DEBUG=1` protocol traces used to pin event-flow facts.

## Engineering discipline

- Each phase lands as its own commit; budgets registered with rationale
  (source-file-policy 25-line quantum included); interface files minimal
  incremental edits; evidence stays in `artifacts/`; X11 claims never stand
  in for Wayland until Phase 4.
