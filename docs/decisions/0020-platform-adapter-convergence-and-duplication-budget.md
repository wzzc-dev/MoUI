# 0020: Platform adapter convergence and duplication budget

- **Date**: 2026-07-28
- **Status**: Accepted
- **Deciders**: Agent-assisted (AtomCode GLM-5.2)
- **Related**: ADR 0011 (platform product class and mobile readiness),
  ADR 0018 (host contract split), invariants P5/M6, architecture-map
  ownership cheat sheet

## Context

`moui/backend/{macos,windows,linux,web,android,ios,harmonyos,wechat}` each
re-implement the same cross-platform seams with only native-type decode
differing:

- `*_timer_host.mbt` (+ `.c`/`.m` glue) — wall clock / frame timer
- `*_service_host` (`macos_service_host.m`, `win32_service_host.c`,
  `linux_service_host.c`) — host service bridge
- `*_window_requests.mbt` — window lifecycle/size/scale requests
- `*_app_handler.mbt` + `*_app_runtime.mbt` — lifecycle handler
- `*_backend.mbt` — typed adapter into `HostCmd`/`HostEvent`
- `menu_helpers.mbt`, `file_dialog_helpers.mbt` — shared service helpers
- pointer/keyboard/IME input translation, resize/scale, surface
  attach/detach, clipboard, text-input session, error mapping

Real platform differences exist (HarmonyOS XComponent-only surface/pointer,
Android Choreographer pacing, iOS UIKit event-loop pacing, Windows message
queue, Web DOM/CDP). But the **structural** repetition (same function shapes,
same `HostCmd` mapping tables, same resize normalization) has no platform
reason — it is copy-paste divergence drift, not capability expression.

Forces:

- Mobile sessions share `EmbedderHostChannel` (ADR 0005); desktop share a
  host-service facade. The seam must not be widened to absorb platform logic
  (invariant P5/M6).
- Adding a new platform should not require copying an existing adapter and
  editing decode tables — that hides divergence and grows the duplication
  budget silently.
- Platform differences must be expressed as explicit **capability** /
  **strategy interface** / platform-local implementation, not flattened into
  a shared module that imports backends (no reverse dependency).

## Decision

Converge platform adapters into a shared-neutral layer + thin platform wiring.

1. **Shared cross-platform transformers** in a new
   `moui/backend/shared_adapter` (platform-neutral) own the **single**
   implementation of: window event → `HostEvent` mapping tables, pointer/
   keyboard decode normalization, resize/scale normalization, lifecycle state
   machine, clipboard command mapping, text-input session state machine,
   surface attach/detach lifecycle, error mapping tables. These are
   table-driven where the only platform input is a native type tag or enum.
2. **Platform packages keep only**: native type decode (native enum →
   neutral event), capability declaration (what this platform supports),
   platform-specific strategy implementation (Choreographer pacing,
  XComponent surface, UIKit event loop, Win32 message queue, DOM/CDP), and
   thin wiring that calls into the shared transformer with decoded neutral
   values. No reverse dependency: `shared_adapter` imports `core` +
   `backend/host` contracts only; platform packages import `shared_adapter`.
3. **Capability / strategy interface for real differences.** Where platforms
   diverge semantically (surface source, input pacing, IME composition shape,
   clipboard capability), express it as a `PlatformCapability` enum +
   strategy interface implemented platform-locally. The shared transformer
   branches only on declared capability, never on platform identity.
4. **Duplication budget + structural validator.** A new validator
   `scripts/validate-platform-adapter-duplication.mjs` measures cross-
   platform structural duplication (function-name + signature + body
   similarity across `backend/<platform>/*_*.mbt`) against a frozen budget
   baseline (`checks/platform-adapter-duplication-baseline.json`). Adding a
   new platform must not grow the budget unless an `allowlist` entry gives a
   platform-difference reason. The budget only shrinks or stays; growth
   requires an RFC entry in the allowlist.
5. **Table-driven tests for shared transformers.** The shared adapter has a
   table-driven test suite (`backend/shared_adapter/*_table_test.mbt`) that
   feeds (native_type_tag, native_payload) → expected `HostEvent`/`HostCmd`
   across all platforms, so a transformer change is validated against every
   platform's decode in one place.

## Options Considered

### Option A: shared-neutral transformer + thin platform wiring (chosen)

- Pros: single owner for cross-platform logic; platform packages shrink to
   decode + capability + strategy; new platform adds decode + capability
   declaration, not a copy; duplication budget is mechanizable.
- Cons: one-time migration of ~8 platforms; need a `shared_adapter` package
   and capability/strategy interfaces; must resist widening host to absorb
   platform logic (ADR 0018 already forbids reverse deps).

### Option B: accept duplication, document per-platform

- Pros: zero migration.
- Cons: divergence drift continues; new platform copies an adapter;
   invariant "platform adapters translate into HostCmd/HostEvent only"
   stays uneconomical; no mechanizable budget.

### Option C: absorb platform logic into `backend/host`

- Pros: one place to edit.
- Cons: violates ADR 0018 and invariant P5/M6; reverse dependency; host must
   know every platform; blocks renderer provider model. Explicitly rejected.

## Rationale

Option A is the only choice that removes structural duplication without
flattening real platform differences or widening host. The capability/
strategy interface makes genuine divergence explicit and testable, while the
shared transformer makes the cross-platform seam single-owner. The
duplication budget validator makes "new platform must not copy" mechanizable,
so the convergence cannot silently regress.

## Consequences

- New `moui/backend/shared_adapter` package owns cross-platform transformers;
   imports `core` + `backend/host` contracts only.
- `backend/{macos,windows,linux,web,android,ios,harmonyos,wechat}` shrink to
   native decode + capability + strategy + wiring; their `moon.pkg` adds
   `shared_adapter` import.
- `menu_helpers.mbt`/`file_dialog_helpers.mbt`/`*_timer_host` glue: shared
   half moves to `shared_adapter`; native glue stays platform-local.
- New `scripts/validate-platform-adapter-duplication.mjs` +
   `checks/platform-adapter-duplication-baseline.json` enforce the budget.
- Table-driven `shared_adapter` tests replace per-platform mirror tests for
   the cross-platform seams; platform packages keep platform-specific tests
   (Choreographer, XComponent, UIKit, Win32, DOM/CDP).
- Invariants P5/M6 updated to reference `shared_adapter` and the budget.

## Agent Notes

- **Session context**: MoUI core/views/host/renderer/platform architecture
   convergence task; sub-task 5 (platform adapter 收敛).
- **Agent model**: AtomCode (GLM-5.2).
- **Key prompt or instruction**: "收敛平台 adapter 中的明显复制…把真正跨
   平台且语义一致的逻辑提取到职责匹配的共享 adapter、规范化转换器或可
   复用服务组件中，平台包只保留原生类型解码、能力差异和薄 wiring…
   建立可机械执行的 adapter 重复度或结构预算。"
- **Validation**: `validate-platform-adapter-duplication.mjs` green vs
   baseline; `moon test moui/backend/shared_adapter --target native`;
   `sh scripts/check.sh --profile platform`; per-platform smoke unaffected.

## References

- `docs/invariants.md` P5/M6
- `docs/architecture-map.md` ownership cheat sheet
- `moui/backend/{macos,windows,linux,web,android,ios,harmonyos,wechat}`
- ADR 0011, ADR 0018
