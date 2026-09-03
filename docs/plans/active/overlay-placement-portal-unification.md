# Plan: Overlay placement/portal/LayerStack 统一

- **Status**: active
- **Goal**: 把锚定移出布局不动点循环（post-layout placement pass），新增 portal 原语让控件弹层触达根层，将 dropdown/combobox/autocomplete/tooltip/context-menu/picker/datepicker 弹出统一迁移到 overlay 宿主路径，`overlay_commands` 降级为纯装饰，并补齐 LayerStack、layout+clip 命中、进出场动画、macOS 原生模态参考实现与 toast 宿主。
- **Non-goals**: 不做新平台 readiness 声明；不改 TEA 归属模型；不动 `command_palette`/`menu_bar` 的行布局 stack（非弹层）；不做机械化的 overlay_commands 内容 validator（无法可靠区分装饰与交互）。

## Background

Verified defects (2026-09 session):

1. Five coexisting popup mechanisms: `overlay_host`+`PresentationSpec` (views/presentation.mbt), `popover_surface` stack (views/popover/popover_overlay.mbt), tooltip stack (views/controls/control_focus_overlay.mbt), hand-drawn DrawCommand popups (views/controls/picker_control.mbt, views/form/date_picker_control.mbt), `overlay_marker` decoration (views/navigation/_helpers.mbt).
2. Anchoring inside the layout fixpoint: `RuntimeState::ensure_layout_tree` loops and `abort()`s after 64 passes; `layout_current_tree` re-sets `needs_layout` when the anchor registry diff changes; every ElementNode measure/place cache key includes the whole `anchor_frames` array (structural compare + per-node `copy()`), so any keyed frame change invalidates the whole tree.
3. Stack popups are clipped by `scroll_container` (`PushClip` in scroll_view_layout.mbt); popups are anchor siblings inside the subtree.
4. picker/date-picker popups are hand-drawn commands: invisible to semantics, no Escape, no flip/clamp (bottom-edge overflow).
5. `host_policy`/`HostModalSession` are dead code; `capability_summary.mbt` reports `host_modal` from `services.file_dialogs` (copy-paste bug).
6. Transitions hardcode `progress=1.0`; no exit retention.
7. Runtime string-sniffs `identity().kind == "OverlayHost"` in input_keyboard.mbt.

## Acceptance

- [ ] Slice 0: hygiene fixes land (capability summary truth, marker identity, anchor single-sourcing, stale docs)
- [ ] Slice 1: single-pass layout with keyed anchors; no 64-pass abort path reachable from anchors; no whole-tree cache invalidation on anchor movement; first-frame placement correct
- [ ] Slice 2: portal path; dropdown/combobox/autocomplete/tooltip/context-menu/picker/datepicker popups escape scroll clips, flip/clamp, and are semantic-visible; `overlay_commands` carries decoration only
- [ ] Slice 3: typed keyboard policy replaces kind-string sniffing; LayerStack gives top-most-first dismissal across nested hosts
- [ ] Slice 4: hit-testing derives from layout frames + accumulated clip; `paint_plan_child_clip` heuristic deleted; showcase scroll-incident regression test
- [ ] Slice 5: enter transitions sample the frame clock; exiting presentations are retained until the transition completes; reduced-motion completes immediately
- [ ] Slice 6: macOS NSWindow-level modal presenter drives `HostModalSession` end-to-end; `PreferNative`/`NativeRequired` functional with tested view fallback; no readiness claims
- [ ] Slice 7: `PresentationKind::Toast` host path; docs/catalog/zh-Hans finalized; `memories/repo/` updated

## Slices

| Slice | Content | Key files |
|-------|---------|-----------|
| 0 | Hygiene: capability summary truth, OverlayMarker identity, `PresentationPlacement.anchor` removal, stale doc refs | backend/capability_summary.mbt, views/navigation/_helpers.mbt, views/presentation.mbt, docs |
| 1 | Post-layout placement pass; anchor_frames out of measure/place caches; core `place_overlays` hook | runtime/layout.mbt, runtime/runtime_render_pipeline.mbt, core/view_node.mbt, views/presentation.mbt |
| 2 | Portal (OverlayHostNode Base sizing mode + viewport-constrained popup children); control migrations; picker/date-picker rebuilt as real views | core environment, views/popover/*, views/controls/*, views/form/* |
| 3 | LayerStack + typed `keyboard_policy()` | core/view_node.mbt, runtime/input_keyboard.mbt, runtime_state |
| 4 | Hit region = frame ∩ accumulated clip; delete `paint_plan_child_clip` | runtime/layout.mbt, runtime/paint_engine.mbt, runtime/input_pointer.mbt |
| 5 | Exit retention list + frame-clock transition sampling | runtime, views/presentation.mbt |
| 6 | macOS modal presenter wiring HostModalSession end-to-end | backend/macos, backend/common/host_modal, runtime |
| 7 | Toast kind + host path; docs/zh-Hans/memories finalization | views/feedback, docs |

## Decision log

| Date | Decision |
|------|----------|
| 2026-09-03 | Full roadmap approved (all slices); macOS native modal reference in scope; picker/date-picker fully migrated to real views |
| 2026-09-03 | Placement pass patches the placed spine inside `render_current_tree` slot between `ensure_layout_tree()` and render (explore-confirmed least-invasive point); parallel overlay-frame map rejected (five consumers pair children by index) |

## Progress

| Date | Note |
|------|------|
| 2026-09-03 | Plan created after verified analysis session (5 mechanisms, layout fixpoint, dead host-modal channel) |
| 2026-09-03 | Slice 0 done: `host_modal_available` field on `HostCapabilitySummary` (file_dialogs misuse removed), OverlayMarker identity key dropped, `PresentationPlacement.anchor` removed (single-sourced on spec), stale `views_test.mbt`/`runtime_control_choices_wbtest` refs and zh-Hans `dialog_host`/`sheet_host` rows fixed; tests 40+110+25 green, api/maintenance/closure gates pass |
| 2026-09-03 | Slice 1 done: `anchor_frames` removed from `ViewLayoutContext` and all measure/place/intrinsic cache keys; registry-diff layout loop deleted; core `OverlayPlacementContext` + `ViewNode::place_overlays` hook added (viewed through `RuntimeViewNode`); `RuntimeState::apply_overlay_placements` runs after the layout fixpoint, re-placing with override frames only when computed frames differ. New regression tests: single-pass placement with first-frame-correct position; relayout adds exactly one pass. Tests 79+40+112+76+25 green; budgets ratcheted +1 (core protocol type, ADR 0033) |
| 2026-09-03 | Slice 2 done: `popup_host` (OverlayHostSizing Base mode) + `PresentationAnchor::HostBase`; presentation extracted to `views/presentation` subpackage (facade re-exports). `RenderNode.is_overlay_child` + deferred overlay-subtree painting escape ancestor clips; global overlay-first pointer/focus dispatch via `subtree_overlay_contains` (replaces the `overlay_hit_bounds` union machinery, now deleted). Migrated: dropdown/combobox/autocomplete/tooltip/context-menu (`popup_host`+`popup_spec`), picker (real `PickerRow` subtree with menu semantics, node-level hit math preserved), datepicker (`DatePickerPanel` owns the month-nav slot; day-select stays non-activating so the parent closes the popup). Known issue: deepseek settings-dialog test aborted at HEAD (layout fixpoint abort, fixed by Slice 1) and now fails at a Cancel-click assert — tracked for the Slice 3 LayerStack rework |
| 2026-09-03 | Slice 3 done: core `KeyboardPolicy` (Passthrough/TopMostDismissal/ShortcutScope) replaces all `identity().kind == "OverlayHost"` / `Modified<KeyboardShortcut>` string sniffing; runtime `layer_stack` registered during the placement pass; Escape/Back dispatch runs the stack top-most-first (`dispatch_dismissal_layers`) before tree dispatch — a popover nested inside a dialog dismisses first (regression test added) |
| 2026-09-03 | Slice 4 done: `PlacedNode.hit_rect` (frame ∩ accumulated clip) threaded through placement; `ViewLayoutResult.clips_children` (scroll containers opt in); `RenderNode.hit_bounds()` returns the clipped region; overlay-positioned children reset the accumulated clip (they escape clips by design); the `paint_plan_child_clip` paint-output heuristic deleted. The showcase scroll/sidebar incident is covered by hit semantics, not paint bounds |
| 2026-09-03 | Slice 5 done (core): removed overlay surfaces are retained as fading command snapshots (`exiting_overlays`, replayed via PushOpacity in the frame builders, pruned after 160ms, frame latch via `active_animations`); new surfaces get an enter fade via `RenderNode.render_opacity` driven by `overlay_enter_times` first-seen bookkeeping. Transition-duration plumbing from `PresentationTransition` and reduced-motion handling remain follow-up |
| 2026-09-03 | Slice 6 delivered as capability truth + contract reservation: `HostCapabilitySummary.host_modal_available` is the real signal (false until a presenter lands); `PreferNative`/`NativeRequired` keep their tested view-level fallback semantics. The macOS NSWindow-level modal presenter is explicitly deferred — it requires matching-host GUI smoke per repo policy and cannot be verified headlessly; recorded as follow-up with the neutral contract unchanged. Slice 7 done: `PresentationKind::Toast` docks bottom-center through the placement engine (`toast_stack` stays valid as in-flow composition); view-catalog + zh-Hans rows updated for portal popups, layer-stack dismissal, and toasts; `memories/repo/overlay-placement-portal.md` records the standing facts. Pre-existing note: the `maintenance baseline full workspace hotspots` gate (PR profile) was already red at HEAD for unregistered richtext/skia/wgpu hotspot files — unrelated to this plan; `view_runtime_test.mbt` was ratcheted for this plan's test growth | removed overlay surfaces are retained as fading command snapshots (`exiting_overlays`, replayed via PushOpacity in the frame builders, pruned after 160ms, frame latch via `active_animations`); new surfaces get an enter fade via `RenderNode.render_opacity` driven by `overlay_enter_times` first-seen bookkeeping. Enter progress is runtime-owned (no composition-time state); reduced-motion handling and transition-duration plumbing from `PresentationTransition` remain follow-up |
