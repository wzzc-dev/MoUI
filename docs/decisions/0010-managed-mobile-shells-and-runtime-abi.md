# 0010: Managed Mobile Shells and Stable Runtime ABI

- **Date**: 2026-07-15
- **Status**: Accepted
- **Deciders**: Agent-assisted (Codex, GPT-5)
- **Related**: ADR 0005, ADR 0006, `docs/embedding-api-v1.md`,
  `moui_shell/template.shell.json`

## Context

MoUI's first mobile path coupled each application to copied Java, UIKit, or
ArkTS projects and app-specific C symbols. That made examples useful but made
external onboarding, framework upgrades, plugin composition, ABI ownership,
and cross-platform validation depend on duplicated native projects.

The three platforms also evolved different lifecycle and service translations.
Surface recreation could be confused with application destruction, stale
asynchronous responses could cross session generations, and build metadata
could describe a requested renderer without proving the presenter that ran.

## Decision

1. Managed Android, iOS, and HarmonyOS builds stage a canonical shell from the
   resolved `wzzc-dev/moui` package. Application repositories own shared app
   code, thin MoonBit mobile entrypoints, schema v2 `shell.json`, resource
   overlays, and optional local plugins, but no native project copy.
2. All managed shells negotiate `moui_embedding_get_api_v1()` and call a
   versioned function table. Fixed-width input values and explicit-length UTF-8
   buffers cross the C boundary; MoonBit objects and strings do not.
3. Host Wire v1 envelopes carry `schemaVersion`, `sessionGeneration`, and
   revision or request identifiers. Late responses from detached or destroyed
   generations are rejected.
4. `EmbeddedSessionCore` owns the shared runtime, renderer, redraw, host
   channel, image, generation, and disposal state. It lives under
   `backend/internal/mobile_runtime` so MoonBit internal visibility permits all
   backend siblings while keeping it out of the public catalog. Surface detach
   preserves `AppRuntime`; application destroy is terminal.
5. Schema v2 is strict and records identity, renderer, system UI, orientation,
   resources, permissions, plugins, deployment floors, and per-platform
   `managed|ejected` mode. It cannot contain app-specific native exports,
   generated C names, or native project paths.
6. Managed plugins use `moui.plugin.json` shell API v1. They may contribute only
   workspace-local Kotlin/Java, Swift/Objective-C++, or ArkTS source and
   resources, declared PlatformView kinds, Host Service channels, and
   permissions. Build scripts, remote dependencies, native libraries, path
   escapes, and the reserved `moui.*` namespace require eject.
7. Android uses Kotlin `ComponentActivity`, registered JNI, and a SurfaceView
   below a PlatformView overlay. iOS uses SwiftUI around a
   `CAMetalLayer`-backed `UIView`; Objective-C++ is only the ABI bridge.
   HarmonyOS uses framework-owned ArkTS `MoUIRoot`, with native XComponent
   callbacks as the only surface/input/resize/detach source.
8. `moui mobile eject` materializes a versioned snapshot with template,
   configuration, and plugin digests. Framework builds never rewrite it.
9. Release N defaults to schema v2 managed modern shells. Schema v1 and the
   Java/UIKit legacy shells require explicit flags and emit structured
   deprecation output. Release N+1 removes those legacy parsers and wrappers;
   compatible versioned ejected projects remain supported.

## Options Considered

### Keep copied native projects as the default

- Pros: Every application can edit native files immediately.
- Cons: Framework fixes drift across copies, upgrades are manual, and examples
  become accidental templates.

### Modernize shell languages before stabilizing the protocol

- Pros: Kotlin and SwiftUI appear sooner in isolation.
- Cons: Repeats the old platform-specific coupling behind newer syntax.

### Stable shared protocol plus managed modern shells (chosen)

- Pros: One lifecycle and service contract, reproducible framework upgrades,
  narrow plugin permissions, explicit eject ownership, and auditable evidence.
- Cons: The managed plugin contract is intentionally bounded, and custom
  build systems or native dependencies require eject.

## Consequences

- `moui new` can generate a mobile-ready application without copying Activity,
  Xcode, Stage Ability, JNI/NAPI, or CMake files.
- Platform shells can evolve independently while runtime ABI v1 and shell API
  v1 remain compatible.
- PlatformView overlay composition and renderer platform-view capabilities are
  separate contracts and must not be conflated.
- Build success proves source/toolchain integration only. Android, iOS, and
  HarmonyOS runtime and renderer status remain `partial` until fresh
  managed-shell matching-device pixels, lifecycle, services, GPU/recovery, and
  stress evidence passes.
- Canonical templates remain framework implementation inputs. Direct native
  customization starts from a versioned eject, never an undocumented copy.

## Agent Notes

- **Session context**: Unify onboarding, runtime ownership, renderer selection,
  mobile ABI, native shells, plugins, eject, generated repository facts, and CI.
- **Agent model**: Codex (GPT-5)
- **Key instruction**: Implement the complete plan and commit each complete
  feature separately.
- **Validation**: Focused MoonBit tests, ABI ownership and ASan tests, three
  managed/ejected/plugin build matrices, legacy compatibility fixtures, and
  repository profiles. Matching-device managed-shell evidence remains pending.

## References

- `docs/embedding-api-v1.md`
- `docs/shell-mainline-roadmap.md`
- `docs/android-support.md`
- `docs/ios-support.md`
- `docs/harmonyos-support.md`
- `docs/testing.md`
