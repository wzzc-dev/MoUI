# Skia Platform Status

This file tracks whether a platform is actually accepted for the real Skia
backend. A platform is not accepted just because the fallback build passes, a
dry-run prints a valid configuration, or a workflow exists. Accepted means there
is a real runner artifact whose logs prove that MoonBit linked Skia, executed
`scripts/native_smoke`, restored `native/moon.pkg`, and passed the artifact
verifier for that platform.

The machine-readable status lives in `skia-platform-status.json`. Check that it
stays consistent with `skia-revision.txt` by running:

```powershell
.\scripts\verify-platform-status.ps1
```

On Linux or macOS runners, use the shell equivalent:

```bash
bash scripts/verify-platform-status.sh
```

Schema v4 also records `ci_gates`: the canonical list of repository and artifact
verification commands that must stay wired into CI. The status verifier checks
that MoonBit checks/tests, all-target MoonBit compilation, native smoke build,
FFI ownership, FFI borrow annotations, native fallback parity, platform status,
native smoke log verification, and real-Skia artifact verification are all
represented.

The same status file records `native_smoke_capabilities`: the canonical list of
smoke markers that must appear in every accepted native smoke executable log.
The platform-status verifier checks this list covers Surface, Canvas, Pipeline,
GPU, Shader, Filter, Path, Image, Codec, Bitmap, Text, and FontMgr boundaries, and
`verify-native-smoke-log.*` reads the same list when validating artifact logs.
Conditional markers such as SkShaper-shaped glyph counts live in
`native_smoke_conditional_capabilities`; those markers are required only when
their availability marker reports the enabled value, and the status verifier
checks that the conditional contract remains declared.
`native_smoke_expected_values` records exact values for markers where a presence
check is too weak, such as text-run dependency plan counts.
It also records `ci_gate_evidence_files`, the workflow and fallback-helper files
that must contain every `ci_gates` verifier script or MoonBit command fragment.
For each platform, the verifier also requires the exact preflight, wrapper,
native smoke, and acceptance summary log names that artifact verification needs.

When a real artifact has passed verification and the Skia revision has been
pinned, mark a platform accepted through the guarded helper instead of editing
the JSON by hand:

```powershell
.\scripts\accept-platform-status.ps1 -Platform linux -LogDir logs -ArtifactLabel linux-real-skia-smoke-log
```

On Linux or macOS runners, use:

```bash
bash scripts/accept-platform-status.sh --platform linux --log-dir logs --artifact-label linux-real-skia-smoke-log
```

The helper reruns artifact verification before it updates
`skia-platform-status.json`. For `source` artifacts it also checks the
revision pin. Accepted entries record `accepted_artifact`, `accepted_provider`,
`accepted_version`, and `accepted_commit`; the status verifier requires source
commits to match `skia-revision.txt` and JetBrains commits/versions to match
`skia-provider-lock.json`.

## Current Matrix

| Platform | Current state | What exists | Missing before accepted |
| --- | --- | --- | --- |
| Linux | Ready for JetBrains binary acceptance, not accepted yet | JetBrains fetch/cache provider, source-build helper, existing-build smoke helper, acceptance wrapper, dependency checker, artifact verifier, guarded revision pin wrapper, workflow | A real Linux artifact using the default JetBrains provider, or a source-built artifact when refreshing `skia-revision.txt` |
| macOS | Accepted with JetBrains `m148-8967a2e80c` artifact | JetBrains fetch/cache provider, source-build helper, existing-build smoke helper, acceptance wrapper, artifact verifier, workflow | Keep verifying refreshed macOS runs against the locked JetBrains provider |
| Windows | Ready for JetBrains MSVC binary acceptance, not accepted yet | JetBrains fetch/cache provider, existing MinGW-compatible helper, MSVC smoke/acceptance helper, artifact verifier, workflow, persistent link-config generators | A real Windows MSVC artifact using the default JetBrains provider |

## Acceptance Evidence

Every accepted platform needs a downloaded or retained artifact directory with
these facts recorded in logs:

- `scripts/native_smoke` was built for the native target with
  `SKIA_MBT_HAS_SKIA` and real Skia include/link flags.
- The native smoke executable printed `skia_mbt native smoke test passed`.
- The native smoke log passed `scripts/verify-native-smoke-log.*`, including
  all required stage markers for readback dimensions, readback row bytes,
  bounded snapshots, PNG encode/decode dimensions, codec dimensions, decoded
  bitmap readback dimensions, surface descriptor reporting, canvas state
  restore, canvas clipping, canvas command replay, render resource planning,
  GPU context
  resource planning, GPU context identity variation, GPU frame context validation,
  GPU frame submission resource planning, GPU frame submission GPU-resource
  filtering, cacheable/uncacheable render-frame resource subplans,
  cacheable/uncacheable frame submission resource subplans,
  render target identity
  validation, render-frame unbalanced-state validation, missing-present
  validation, missing-finalization validation, shaped glyph-run command replay,
  bound target resource planning, window physical-size derivation, frame pacing, frame-pacing key variation,
  present-mode key variation, window-frame present finalization,
  render-frame present descriptor validation, render-frame submission resource
  planning, render-frame submission cache population, render-frame finalization
  resource planning, cacheable/uncacheable frame finalization resource subplans,
  render-frame finalization cache population, surface
  finalization resource planning, surface finalization cache-key variation, GPU
  finalization resource planning, GPU frame finalization resource filtering,
  surface present buffer-slot derivation, surface present resource planning, GPU
  present resource planning, GPU-backed submission subplans, render-frame
  touched bounds, resource-cache insertion, preflight missing/resident splits,
  cache-plan coverage,
  hit/miss accounting, byte-budget behavior, and LRU eviction, surface flush-and-submit, shader
  draws, native/portable path geometry, text-run dependency planning,
  byte-range text-run resource keys, text measurement resource planning,
  measured-text result resource planning, measured-text result cache-key
  variation, text measurement cache-key variation, text shaping resource
  planning, shaped-text result resource planning, shaped glyph-run resource
  planning, shaped glyph-run cache-key variation, UTF-8 text measurement, glyph count,
  glyph ID mapping, glyph advances, glyph positions, glyph bounds, text bounds
  measurement, SkShaper availability reporting, optional native shaped-text
  metadata planning, default typeface availability,
  font resource planning, font metrics, font family enumeration, native typeface
  family metadata, FontMgr character fallback, font fallback cache-key
  variation, font fallback family metadata, resolved fallback match cache-key
  variation, fallback match resource planning, fallback resolution cache-key
  variation, fallback resolution resource planning, font fallback resource planning,
  and shader/filter resource planning.
- The acceptance log passed `scripts/verify-acceptance-log.*` and contains
  `smoke_status=0`, `native_smoke_marker=passed`, and
  `native_pkg_restore=passed`.
- The platform artifact passed `scripts/verify-real-skia-artifact.*`.
- The wrapper, native-smoke, and acceptance logs do not contain dry-run markers
  such as `dry_run_config=true`, `Dry run complete`, or
  `real <platform> smoke was not run`. The preflight log is allowed to come
  from `--dry-run-config`; the accepted artifact itself is not.
- `native/moon.pkg` and `scripts/native_smoke/moon.pkg` were restored after the
  temporary link rewrite.

The `Real Skia Acceptance` GitHub Actions workflow is designed to produce that
evidence with the locked JetBrains/skia provider. A successful job for one
platform can be used as that platform's acceptance evidence when all of these
conditions are true:

- the job is not a dry run and did not use the fallback workflow;
- the job used `skia_provider=jetbrains` from `skia-provider-lock.json`;
- the native smoke executable log contains the full required marker set and
  `skia_mbt native smoke test passed`;
- `scripts/verify-real-skia-artifact.*` passed for the uploaded log bundle;
- the job produced a non-empty `*-platform-acceptance.patch`, proving
  `accept-platform-status.*` would mark the platform accepted from those logs;
- the uploaded artifact is retained or downloaded before updating
  `skia-platform-status.json`.

Passing the older `Fallback` workflow, a dry run, or a syntax-only workflow is
not acceptance evidence.

Linux source-built acceptance also needs stronger revision evidence:

- `logs/linux-skia-build.log` exists and records the Skia build environment,
  checkout path, resolved `skia_commit`, and GN args.
- The build log, wrapper log, and acceptance log all agree on the same full
  40-character `skia_commit`.
- `scripts/verify-real-skia-artifact.sh --platform linux --log-dir logs --require-commit`
  passes before any revision pinning.
- `skia-revision.txt` is updated only through a guarded pin helper after that
  source-built artifact is verified.
- `skia-platform-status.json` records the same commit in Linux
  `accepted_commit`, `accepted_provider=source`, and matching
  `accepted_version` before that source path is considered accepted.

JetBrains acceptance needs provider evidence:

- The wrapper and acceptance logs record `skia_provider=jetbrains`,
  `jetbrains_tag`, full `skia_commit`, `skia_package`, and
  `skia_package_sha256`.
- The artifact verifier checks those fields against `skia-provider-lock.json`.
- `skia-platform-status.json` records `accepted_provider=jetbrains`,
  `accepted_version` equal to the locked tag, and `accepted_commit` equal to the
  locked JetBrains commit.

## Next Acceptance Step

The next concrete milestone is a desktop JetBrains-provider acceptance run on
Linux and Windows through the real-smoke workflows. macOS is accepted with the
locked JetBrains `m148-8967a2e80c` package and should continue to run as a
regression check. The source-built Linux path remains the canonical fallback pin
path:

```bash
bash scripts/linux-accept-and-pin-skia.sh --install-deps --work-dir .skia-cache/linux --accept-platform-status
```

On managed Ubuntu runners where dependencies are already installed, replace
`--install-deps` with `--skip-deps-check` only when dependency provisioning is
handled elsewhere. Keep `skia-revision.txt` as `main` until this run produces a
verified full Skia commit. The `--accept-platform-status` flag marks Linux
accepted only after artifact verification and revision-pin verification pass.

After Linux pins the first known-good Skia revision, run Windows real-smoke
against the same revision or explicitly document why a different revision is
being evaluated; keep macOS JetBrains smoke green against the locked provider.
For source-built Linux workflow runs, the uploaded
`logs/linux-acceptance-state.patch` contains the `skia-revision.txt` and
`skia-platform-status.json` changes produced by the guarded artifact-and-status
helpers. Check a downloaded patch before applying it:

```powershell
.\scripts\verify-acceptance-state-patch.ps1 -PatchFile logs\linux-acceptance-state.patch
```

## Non-Acceptance Evidence

These checks are useful, but they do not make a platform accepted:

- `moon test` or the fallback CI gate passing without real Skia.
- `scripts/native_smoke` compiling without real Skia link flags.
- Any `--dry-run-config` run.
- A generated `native/moon.pkg` preview without a real smoke executable run.
- A workflow summary without the downloadable logs required above.
