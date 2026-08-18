# RFC 0002: Tiered Platforms And TEA Service Boundary

Status: Accepted (2026-08-04)

## Decision

MoUI uses one machine-readable platform-route matrix with three support tiers:

- Tier 1: macOS Skia and browser Web WebGPU with Canvas2D fallback.
- Tier 2: Windows Skia and Linux Skia.
- Tier 3: native WGPU on macOS, Windows, and Linux; window-hosted Skia on
  Android, iOS, and HarmonyOS; Sun on macOS, Windows, and Linux; and WeChat
  Canvas2D.

Support tier, L0-L3 evidence, and product readiness are independent. Tier 3 is
non-blocking and does not promote experimental or diagnostic routes.

Showcase carries the complete route matrix, while product examples may expose
additional routes that are present in the matrix. A platform/renderer
combination outside the matrix requires a follow-up RFC.

## TEA Boundary

Add `wzzc-dev/moui/services` as an optional app-facing package that depends only
on `moui/core`. It owns typed application service tasks and timer/route sources.
Wire protocols, pending queues, and platform implementations remain in
`moui/backend` and concrete backends.

Application models contain business data, not runtime objects, host bridges, or
service request identifiers. Services are captured by Program factories;
completion, timer, route, and command input re-enter the program as typed
messages.

Core gains typed Program command declarations. Runtime interprets those
declarations by dispatching messages through the existing FIFO program queue.
App code must not mutate a model from `ActionCommandMap` callbacks.

## Facade And Compatibility

`run_app` remains owned by `moui/runtime`. The root `wzzc-dev/moui` facade
returns to an app-loop-only dependency surface and no longer imports runtime.
This supersedes RFC 0001.

The migration lands as one `0.1.x` breaking API update. No long-lived aliases
or dual service/command paths are retained.

## Executable Wasm ABI

Moon `0.1.20260724` exports only public function definitions owned by the
executable package. A `pub using` alias is present in the generated MoonBit
interface but does not materialize a wasm export. Web and WeChat roots therefore
use a second, mechanical `abi.mbt` file containing only the fixed callbacks that
delegate to `backend/web` or `backend/wechat`. This is a linker-boundary shim,
not an application or platform-logic compatibility layer. P1 validates its
closed function set, and Web handoff validation checks the compiled exports.

## Affected Invariants

- P1/P8/P9: app packages and composition roots.
- P5: host contracts versus app-facing services.
- P6/R1/R7: renderer composition and support classification.
- A1/A5: public API discovery and verification.

## Gates

- Platform matrix schema and composition-root validation.
- App dependency and TEA-state validation.
- API surface/interface drift checks.
- PR/daily/platform profiles plus Tier-specific smoke catalog checks.
