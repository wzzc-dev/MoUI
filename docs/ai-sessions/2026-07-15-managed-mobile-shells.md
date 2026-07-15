# 2026-07-15: Managed Mobile Shells and Runtime Contracts

- **Agent**: Codex (GPT-5)
- **Goal**: Implement the onboarding, renderer/runtime consolidation, stable
  mobile ABI, modern managed shells, CLI/doctor/eject, generated facts, and
  source-size governance plan.
- **Outcome**: Success for source, tooling, build, and compatibility contracts;
  matching-device modern-shell runtime promotion remains pending.

## Summary

MoUI now uses one native renderer resolver, a shared internal mobile session
core, Runtime ABI v1, and Host Wire v1 across Android, iOS, and HarmonyOS. The
default mobile experience stages package-owned Kotlin, SwiftUI, or ArkTS shells;
strict schema v2 configuration, bounded local plugins, and versioned ejects
replace copied native projects and app-specific symbol maps.

The repository also gained three-path onboarding, an independent `moui_cli`
with generator/doctor/eject commands, external-consumer CI, generated repository
facts, source-file governance, managed-shell build matrices, and a repo-only
test-probe plugin. Runtime declarations deliberately remain `partial` until the
new shells pass fresh matching-device evidence.

## Changes Made

| Area | What Changed | Why |
|---|---|---|
| Renderer/host | Unified native/mobile resolver and split `HostWindowRenderer` optional capabilities | Keep the stable renderer core small and capability growth explicit |
| Mobile runtime | Added package-private session core, ABI v1 function table, generation-scoped Host Wire, and detach/destroy separation | Share lifecycle and reject stale asynchronous responses |
| Shells | Added canonical Kotlin, SwiftUI, and ArkTS shells with PlatformView and Host Service plugin adapters | Make modern managed shells the default without changing the ABI per platform |
| Configuration | Added strict schema v2, local plugin manifest v1, managed/ejected modes, and Release N legacy gates | Remove app-specific native symbols and project paths from application metadata |
| CLI/onboarding | Added `moui new`, `moui doctor`, `moui mobile eject`, Quick Start paths, and external-consumer CI | Make first use and toolchain diagnosis reproducible outside the monorepo |
| Governance | Added generated repository facts, platform manifests, file-size policy, shell matrices, and runtime evidence validators | Reduce documentation drift and prevent unsupported proof claims |

## Key Decisions

- Stabilize Runtime ABI v1 and Host Wire v1 before switching platform shell
  languages. See ADR 0010.
- Keep `MobileRuntimeSessionCore` under `backend/internal/mobile_runtime`:
  moving it below `backend/host/internal` would block sibling backend imports
  under MoonBit internal visibility.
- Keep `actualPresenterRoute=unverified` and mobile runtime/renderer status
  `partial` until matching-device managed-shell evidence exists.
- Treat versioned ejected shells as a supported ownership mode, distinct from
  Release N legacy fixtures.

## Validation

```sh
sh moui/mobile/tests/run-mobile-runtime-v1-tests.sh
sh moui/mobile/ios/tests/run-ios-managed-shell-tests.sh
sh moui/mobile/harmonyos/tests/run-harmonyos-managed-shell-tests.sh
node --test moui/mobile/test-probe/tests/validate-test-probe.mjs
node scripts/check-mobile-app-config.mjs
node scripts/generate-repo-docs.mjs --check
node scripts/validate-source-file-policy.mjs
```

The Runtime ABI suite includes ownership, symbol, once-init, lifecycle, mismatch,
and AddressSanitizer coverage. Managed, clean-ejected, local-plugin, and explicit
legacy fallback builds were exercised for all three platforms. Full daily,
platform, and theme profiles are recorded in the final task handoff.

## Follow-Up

- [ ] Collect fresh Android/iOS/HarmonyOS managed-shell matching-device pixels,
  lifecycle, IME, clipboard, accessibility, async image, PlatformView, Host
  Service, GPU recovery, and stress evidence.
- [ ] Remove schema v1 parsers, old Java/UIKit wrappers, and legacy fixtures in
  Release N+1 after the announced compatibility window.
