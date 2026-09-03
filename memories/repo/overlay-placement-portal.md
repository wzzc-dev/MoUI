# Overlay Placement / Portal / LayerStack

- **ADR**: `docs/decisions/0033-overlay-placement-and-portal.md` (amends 0030).
- **Plan**: `docs/plans/active/overlay-placement-portal-unification.md`.

## Standing Facts

- Anchoring never re-enters layout: the anchor registry is collected after
  base placement; `RuntimeState::apply_overlay_placements` runs once per
  frame after the layout fixpoint and re-places with `overlay_overrides`
  (host element id -> (child index, absolute rect)) only when computed frames
  differ. Layout caches must never key on anchor data.
- `ViewNode.place_overlays(context)` (core, default None) is the hook overlay
  hosts implement; the geometry engine stays in `moui/views/presentation`.
- `View::popup_host(base, specs)` = base-sized portal for control popups;
  `PresentationAnchor::HostBase` anchors to the base child frame.
- Hoisted overlay children (`PlacedNode.overlay_child_indices`) are painted
  after the whole tree via a deferred worklist and win pointer/focus dispatch
  through `RenderNode::subtree_overlay_contains`; the old
  `overlay_hit_bounds` union machinery is deleted.
- Dismissal layers: `ViewNode.keyboard_policy()` (Passthrough /
  TopMostDismissal / ShortcutScope); `RuntimeState.layer_stack` is
  registered during the placement pass and Escape/Back dispatch runs it
  top-most-first.
- Exit retention: removed overlay surfaces are replayed as fading command
  snapshots (`exiting_overlays`, 160ms default) in the frame builders; enter
  fades come from `overlay_enter_times` via `RenderNode.render_opacity`.
- `overlay_commands` is decoration-only now (shadows, `overlay_marker`,
  native-composition markers). Interactive popups must go through
  `popup_host`/`overlay_host`.
- `PresentationPlacement` has no `anchor` field (single-sourced on
  `PresentationSpec`); `PresentationKind::Toast` docks bottom-center.

## Known Follow-ups

- macOS NSWindow-level modal presenter (HostModalSession wiring) is deferred:
  requires matching-host smoke per repo policy; capability truth is on
  `HostCapabilitySummary.host_modal_available`.
- Datepicker per-day cell semantics need composition-visible month state.
- deepseek `settings dialog accepts pointer editing cancel and save` was
  already broken at HEAD (layout fixpoint abort); re-verify after the
  LayerStack rework.
