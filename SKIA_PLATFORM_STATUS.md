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

The helper reruns artifact verification and the revision-pin check before it
updates `skia-platform-status.json`. Accepted entries record both
`accepted_artifact` and `accepted_commit`; the status verifier requires the
accepted commit to match `skia-revision.txt`.

## Current Matrix

| Platform | Current state | What exists | Missing before accepted |
| --- | --- | --- | --- |
| Linux | Ready for first source-built acceptance, not accepted yet | Source-build helper, existing-build smoke helper, acceptance wrapper, dependency checker, artifact verifier, guarded revision pin wrapper, workflow | A real source-built Ubuntu/Linux artifact with `--require-commit`, then `skia-revision.txt` pinned to the accepted 40-character Skia commit |
| macOS | Smoke path ready, not accepted yet | Source-build helper, existing-build smoke helper, acceptance wrapper, artifact verifier, workflow | A real macOS artifact using the pinned Skia revision once Linux establishes it, or a documented temporary revision while evaluating |
| Windows | Existing-build smoke paths ready, not accepted yet | Existing MinGW-compatible Skia smoke/acceptance helper, MSVC release-zip smoke/acceptance helper, artifact verifier, workflow, persistent link-config generators | A real Windows artifact proving link and smoke execution, plus a documented repeatable Skia acquisition path for the accepted Windows toolchain |

## Acceptance Evidence

Every accepted platform needs a downloaded or retained artifact directory with
these facts recorded in logs:

- `scripts/native_smoke` was built for the native target with
  `SKIA_MBT_HAS_SKIA` and real Skia include/link flags.
- The native smoke executable printed `skia_mbt native smoke test passed`.
- The native smoke log passed `scripts/verify-native-smoke-log.*`, including
  all required stage markers for readback, snapshots, PNG encode/decode, codec,
  decoded bitmap readback, UTF-8 text measurement, glyph count, glyph ID
  mapping, glyph advances, glyph positions, glyph bounds, text bounds
  measurement, and font metrics.
- The acceptance log passed `scripts/verify-acceptance-log.*` and contains
  `smoke_status=0`, `native_smoke_marker=passed`, and
  `native_pkg_restore=passed`.
- The platform artifact passed `scripts/verify-real-skia-artifact.*`.
- `native/moon.pkg` was restored after the temporary link rewrite.

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
  `accepted_commit` before Linux is considered accepted.

## Next Acceptance Step

The next concrete milestone is the first Linux source-built acceptance:

```bash
bash scripts/linux-accept-and-pin-skia.sh --install-deps --work-dir .skia-cache/linux --accept-platform-status
```

On managed Ubuntu runners where dependencies are already installed, replace
`--install-deps` with `--skip-deps-check` only when dependency provisioning is
handled elsewhere. Keep `skia-revision.txt` as `main` until this run produces a
verified full Skia commit. The `--accept-platform-status` flag marks Linux
accepted only after artifact verification and revision-pin verification pass.

After Linux pins the first known-good Skia revision, run the macOS and Windows
real-smoke workflows against the same revision or explicitly document why a
different revision is being evaluated.
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
