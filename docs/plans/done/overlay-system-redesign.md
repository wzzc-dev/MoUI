# Plan: Overlay 系统重设计

- **Status**: done
- **Goal**: 将 presentation 统一收敛到 `OverlayHost + PresentationSpec`，由 runtime 负责层级、定位、输入、焦点和语义，由 backend 提供 neutral host-modal transport。
- **Non-goals**: 本阶段不宣称七个平台 native modal 的产品 readiness；不把 MoUI 内容转换成平台原生控件；不引入第二份 app model。

## Delivered

- `moui/views` now owns `PresentationSpec`, presentation kinds, stable/viewport anchors, ordered placement candidates, modality, dismissal, host policy, transitions, and the sole `overlay_host` composition entrypoint. `stack` remains a pure layout primitive and the presentation-oriented legacy APIs were removed.
- Runtime placement consumes a stable-key anchor snapshot after base layout, keeps presentation frames independent from anchor hit bounds, and dispatches pointer/keyboard/focus in top-most order. Modal barriers block input independently from dismissal messages.
- Modal semantics isolate the deepest modal subtree, preserve existing action handlers, and focus traps use the runtime's stable-key restore mechanism.
- `moui/backend` exposes the neutral host-modal DTO contract. `backend/common/host_modal` validates request/generation identity, negotiates pending/accepted/rejected/closed, owns surface attach/detach, transforms input coordinates, and emits close exactly once.
- Examples, website, showcase, generated interfaces, catalog, architecture guidance, and focused tests were migrated.

## Deferred Evidence

Platform-specific native presenters for macOS/Windows/Linux, Web DOM/canvas host layers, and Android/iOS/HarmonyOS window-hosted surfaces remain adapter work gated by matching-host evidence. The neutral contract and transparent view-level fallback are implemented; no platform readiness claim is made here. Runtime exit visual-state retention is also deferred to the next animation-state slice.

## Validation

Focused views/runtime/backend tests, API/release closure validators, generated-interface checks, and `sh scripts/check.sh --profile pr` pass.
