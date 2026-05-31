# Script Guide

This directory contains validation and native Skia smoke helpers for `skia_mbt`.
The default project build does not require Skia; real Skia checks are opt-in.
See `../REAL_SKIA_SMOKE.md` for the artifact acceptance checklist that defines
what counts as a real Skia smoke pass. `../skia-platform-status.json` is the
machine-readable platform status; validate it with
`./scripts/verify-platform-status.ps1` from PowerShell or
`bash scripts/verify-platform-status.sh` on Linux/macOS.

`skia-platform-status.json` schema v4 is also the source of truth for CI gate
coverage and native smoke capability markers. Its `ci_gates` list records the
MoonBit, native-smoke, FFI ownership, FFI borrow, platform-status, and artifact
verification commands that must stay wired into CI. `verify-native-smoke-log.*`
reads its `native_smoke_capabilities` list so artifact verification checks the
same Surface, Canvas, Shader, Filter, Path, Image, Text, and FontMgr boundaries
that the platform status file claims.

Native handle ownership is tracked separately in `../native/ownership.json`.
Run `bash scripts/verify-native-ownership.sh` or
`.\scripts\verify-native-ownership.ps1` after changing C++ wrapper structs,
MoonBit handle declarations, or finalizers. The verifier rejects undeclared
external wrapper factories, missing finalizers, and release code that no longer
matches the declared `delete`, Skia `unref`, or borrowed-owner contract.
`verify-native-ffi-borrows.*` complements that C++ check on the MoonBit side by
requiring every non-primitive `extern "C"` parameter in `native/*_native.mbt` to
appear in `#borrow(...)` or `#owned(...)`.

## JetBrains/skia provider

JetBrains/skia is the default binary provider for desktop real-smoke runs. The
locked release lives in `../skia-provider-lock.json` and currently points at
tag `m148-8967a2e80c`, commit
`8967a2e80c71be363146da2395f503cab5f5fb9c`, config `Release`.

Fetch or inspect the selected package with:

```bash
bash scripts/fetch-jetbrains-skia.sh --platform auto --arch auto --print-env
```

```powershell
.\scripts\fetch-jetbrains-skia.ps1 -Platform auto -Arch auto -PrintEnv
```

The fetch helpers cache packages under
`.skia-cache/jetbrains/<tag>/<platform>-<config>-<arch>/`, verify locked
SHA256 values, scan for `include/core/SkSurface.h` and platform Skia libraries,
and use the same-tag JetBrains source archive as a header fallback. They only
print include/lib/flag environment values; `configure-*-native-pkg.*` remains
the only layer that generates `native/moon.pkg` contents.

## Fallback gate

Run this on Windows when you want to verify the no-Skia build stays healthy:

```powershell
.\scripts\check-fallback.ps1
```

It runs formatting/checking, default tests, and builds `scripts/native_smoke`
without linking Skia. It does not execute the smoke binary because the binary is
expected to fail fast when the real backend is unavailable.

## Linux real Skia smoke

Use one entry point for Linux real-backend validation. With no provider option,
it uses the locked JetBrains binary package:

```bash
bash scripts/linux-accept-real-skia-smoke.sh --work-dir .skia-cache/linux
```

For the source-built fallback path, pass `--skia-provider source`:

```bash
bash scripts/install-linux-smoke-deps.sh
bash scripts/linux-accept-real-skia-smoke.sh --skia-provider source --work-dir .skia-cache/linux
```

On Ubuntu, `scripts/install-linux-smoke-deps.sh` installs the apt packages used
by the workflow: `build-essential`, `git`, `python3`, `ninja-build`, `clang`,
`curl`, `ca-certificates`, `libfontconfig1-dev`, `libfreetype-dev`,
`libharfbuzz-dev`, `libwayland-dev`, `libwayland-bin`, and `wayland-protocols`.
The Wayland packages provide the protocol XML, headers, and `wayland-scanner`
used by the `wzzc-dev/window` native prebuild. Use `--check` to verify an
already prepared runner, or `--print-packages` to audit the package list without
touching the system. The Linux source-build GN defaults set `cc="clang"` and
`cxx="clang++"` so source-built smoke runs do not depend on the runner's default
C++ compiler.

When `--skia-rev` is omitted, the Linux source-build helpers read the first
non-comment line from `skia-revision.txt`. After a real runner proves a Skia
commit works, update that file to the proven commit hash so future source builds
are reproducible instead of floating with Skia `main`. The acceptance summary
log records the resolved `skia_commit`. After the run passes, pin that value:

```bash
bash scripts/pin-skia-revision.sh logs/linux-real-skia-acceptance.log
```

For the default local acceptance log location, `bash scripts/pin-skia-revision.sh`
is enough.

PowerShell equivalent for auditing a downloaded Linux artifact on Windows:

```powershell
.\scripts\linux-accept-artifact-and-pin.ps1 -LogDir logs

.\scripts\linux-accept-artifact-and-pin.ps1 -LogDir logs -AcceptPlatformStatus

.\scripts\pin-skia-revision.ps1 -AcceptanceLog logs\linux-real-skia-acceptance.log
```

Shell equivalent for auditing a downloaded Linux artifact on Linux or macOS:

```bash
bash scripts/linux-accept-artifact-and-pin.sh --log-dir logs

bash scripts/linux-accept-artifact-and-pin.sh --log-dir logs --accept-platform-status
```

The one-step PowerShell helper verifies the Linux source-built artifact bundle
with `-RequireCommit`, pins the accepted commit, and verifies the pin. The shell
helper performs the same artifact verification and pin check. Use the lower-level
`pin-skia-revision.*` helpers only when the artifact bundle has already been
checked. Add `-AcceptPlatformStatus` or run `accept-platform-status.*` separately
when the verified artifact should update `skia-platform-status.json`; the shell
helper accepts the equivalent `--accept-platform-status`.
After the revision is pinned, update `skia-platform-status.json` through the
guarded status helper:

```powershell
.\scripts\accept-platform-status.ps1 -Platform linux -LogDir logs -ArtifactLabel linux-real-skia-smoke-log
```

Shell equivalent:

```bash
bash scripts/accept-platform-status.sh --platform linux --log-dir logs --artifact-label linux-real-skia-smoke-log
```

It reruns artifact verification and the revision-pin check before marking the
platform accepted. The accepted status records both `accepted_artifact` and the
40-character `accepted_commit`, and the status verifier requires the commit to
match `skia-revision.txt`.

For source-built real runs, the Linux workflow uploads
`logs/linux-acceptance-state.patch` with the matching `skia-revision.txt` and
`skia-platform-status.json` changes. Verify a downloaded patch before applying
it:

```powershell
.\scripts\verify-acceptance-state-patch.ps1 -PatchFile logs\linux-acceptance-state.patch
```

For the first Linux source-built acceptance, you can combine the real run,
artifact verification, revision pin, and post-pin check in one guarded command:

```bash
bash scripts/linux-accept-and-pin-skia.sh --work-dir .skia-cache/linux
```

Add `--accept-platform-status` when the verified run should also mark Linux
accepted in `skia-platform-status.json`:

```bash
bash scripts/linux-accept-and-pin-skia.sh --work-dir .skia-cache/linux --accept-platform-status
```

That wrapper rejects existing-build paths and dry runs so only a source-built
Linux acceptance with a full `skia_commit` can update `skia-revision.txt`. It
runs `scripts/install-linux-smoke-deps.sh --check` before the expensive build by
default; pass `--install-deps` to install missing Ubuntu packages first, or
`--skip-deps-check` for a runner whose dependencies are managed elsewhere.

That builds a small CPU-only Skia, temporarily links `native/moon.pkg`, builds
`native_smoke`, runs the produced executable, restores `native/moon.pkg`, checks
the saved native executable log for `skia_mbt native smoke test passed`, and
verifies that `native/moon.pkg` did not change. The smoke executable covers
raster drawing, readback, snapshots, PNG encode/decode, bitmap decode, and
canvas save/restore with clipping behavior. It also exercises shader-backed
draws, native and portable path drawing, image drawing, transforms, default font
text drawing/measurement/metrics, default-typeface text drawing/measurement/metrics when the selected Skia build
provides a default typeface, and font manager family enumeration/matching when
the platform font manager is available. It also exercises native typeface family
metadata and FontMgr character fallback through the value-layer
`FontFallbackRequest`. Pixel assertions are reserved for deterministic
geometry and color operations so minimal CPU-only Skia builds do not fail only
because their font manager differs. Font coverage still verifies positive text
advance, glyph count, glyph ID mapping, glyph advances, glyph positions, glyph
bounds, text bounds, metrics, font-family typeface matching, and typeface family
metadata whenever the native smoke can create the relevant font objects.

To reuse an existing Skia checkout/build instead of the default JetBrains
provider:

```bash
bash scripts/linux-real-skia-smoke.sh \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

Existing-build smoke runs prove that a prepared Skia library can link and run
the native smoke executable. They only prove a pinnable revision when
`--skia-include` points at a Skia Git checkout and the acceptance log records a
full `skia_commit`; otherwise keep them separate from the first source-built
Linux acceptance used to update `skia-revision.txt`.

To generate a persistent `native/moon.pkg` for an existing Linux Skia build,
preview the config first and then write it explicitly:

```bash
bash scripts/configure-linux-native-pkg.sh \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static

bash scripts/configure-linux-native-pkg.sh \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static \
  --write
```

Use `--check` in CI or local scripts to verify that `native/moon.pkg` still
matches the expected Linux Skia link config. The smoke helpers use this same
generator for their temporary package rewrite.

Use `--skia-lib`, `--extra-cc-flags`, and `--extra-link-flags` when a build uses
a non-default library name or needs additional dependent libraries/rpaths. Use
`--extra-gn-args` only for source-built Skia; it is ignored for existing builds.
When the selected library directory contains `libskia.so`, the smoke helper adds
that directory to `LD_LIBRARY_PATH` before executing the smoke binary.
Pass `--smoke-log logs/linux-native-smoke-output.log` to keep the native smoke
executable's stdout/stderr in a dedicated file in addition to the wrapper log.
The acceptance wrapper owns `--smoke-log`; use `--log-dir PATH` there to choose
where both acceptance logs are written.

For local reuse, the Linux helpers also accept environment defaults modeled
after native-link configuration knobs:

```bash
export SKIA_MBT_SKIA_INCLUDE=/path/to/skia
export SKIA_MBT_SKIA_LIB_DIR=/path/to/skia/out/Static
export SKIA_MBT_SKIA_LIB=skia
export SKIA_MBT_EXTRA_LINK_FLAGS="-lfontconfig -lfreetype -lharfbuzz -lpthread -ldl -lm"
bash scripts/linux-accept-real-skia-smoke.sh --log-dir logs
```

Command-line arguments override these variables. For source-built Skia, revision
selection is `--skia-rev`, then `SKIA_MBT_SKIA_REV`, then the first non-comment
line of `skia-revision.txt`, then `main`. Source-build helpers also read
`SKIA_MBT_EXTRA_GN_ARGS` when `--extra-gn-args` is omitted.

To preflight the selected mode and final build/smoke arguments without fetching
or building Skia or rewriting `native/moon.pkg`. In source-build mode it prints
the resolved Skia checkout/build paths and GN args. With existing Skia paths it also checks
that the Skia header and library files exist and prints the exact native flags
that would be injected:

```bash
bash scripts/linux-real-skia-smoke.sh --dry-run-config
```

The `Linux Real Skia Smoke` GitHub Actions workflow exposes the same options as
manual inputs, including `dry_run_config`, and also runs weekly as an expensive
real-backend canary. The default fallback workflow also runs `bash -n` over the
Linux helpers, runs the source-built dry-run, and runs an existing-build dry-run
against fake Skia header/library files on Ubuntu. It additionally dry-runs the
lower-level smoke helper against fake static and shared libraries and checks that
`native/moon.pkg` is unchanged, so wrapper branches, argument construction, and
no-rewrite behavior are checked without building Skia.
The real-smoke workflow uses `linux-accept-real-skia-smoke.sh` for real runs and
saves the wrapper log, source-build Skia build log when present, dedicated
native smoke executable output, and acceptance summary as the
`linux-real-skia-smoke-log` artifact on both success and failure.
It also runs a dry-run preflight before installing build dependencies or
compiling Skia; the artifact includes the preflight log, `logs/linux-skia-build.log`
for source-built runs, wrapper log, native executable log, and acceptance log
when present. On real runs, the workflow also greps
`logs/linux-native-smoke-output.log` for `skia_mbt native smoke test passed` and
records that marker check in the summary. The same check is available as
`scripts/verify-native-smoke-log.sh logs/linux-native-smoke-output.log` for
manual artifact review. For source-built Linux artifacts, the bundle verifier
also checks that the build, wrapper, and acceptance logs agree on the full
`skia_commit`, and that the wrapper and acceptance logs reference the build log.
The workflow summary records the selected mode, dry-run setting, artifact name,
key Skia inputs, expected log paths, the marker check, and whether
`native/moon.pkg` was restored for quick triage.

## Lower-level helpers

`scripts/linux-accept-real-skia-smoke.sh` runs the full Linux real smoke and
performs local acceptance checks around the generated logs and temporary package
rewrite. In GitHub Actions it also exports the marker, restore, and acceptance
log status fields through `GITHUB_ENV` for the workflow summary. Its acceptance
log includes the resolved `skia_commit` when the Skia checkout was available.
`scripts/verify-native-smoke-log.sh` and `scripts/verify-native-smoke-log.ps1`
check a saved native smoke executable log for key stage markers plus the final
success marker and are used by the real-smoke workflows after the one-step
helper runs.
`scripts/verify-acceptance-log.sh` and `scripts/verify-acceptance-log.ps1` check
the acceptance summary fields; the shell version can also require a full
`skia_commit` hash for source-built revision pinning. `scripts/pin-skia-revision.sh`
pins `skia-revision.txt` only after the acceptance fields and full
`skia_commit` hash pass verification.
`scripts/linux-build-skia.sh` only builds Skia from source; pass
`--dry-run-config` to print the resolved checkout/build paths and GN args without
fetching, syncing, or building. If `--skia-rev` is omitted, it uses
`skia-revision.txt`. `scripts/linux-skia-smoke.sh` only links an
existing Skia build and runs `native_smoke`; pass `--dry-run-config` to this
lower-level helper to validate paths and flags without rewriting
`native/moon.pkg`. Prefer the one-step `linux-real-skia-smoke.sh` wrapper unless
you need to debug one stage in isolation.

## macOS real Skia smoke

Use one entry point for macOS real-backend acceptance. With no provider option,
it uses the locked JetBrains binary package:

```bash
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs
```

For the source-built fallback path:

```bash
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs \
  --skia-provider source \
  --work-dir .skia-cache/macos
```

When `--skia-rev` is omitted in source mode, `scripts/macos-real-skia-smoke.sh`
and `scripts/macos-build-skia.sh` read
`SKIA_MBT_SKIA_REV`, then `skia-revision.txt`, matching Linux's revision
priority. The real wrapper and lower-level smoke scripts support
`--dry-run-config` for CI preflight. The acceptance wrapper captures the
dry-run preflight log, optional source-build log, wrapper log, native executable
log, and `macos-real-skia-acceptance.log`;
checks the final `skia_mbt native smoke test passed` marker; and verifies that
`native/moon.pkg` was restored. The lower-level smoke helper temporarily
rewrites `native/moon.pkg`, runs `scripts/native_smoke`, restores the package
file, and adds the Skia library directory to `DYLD_LIBRARY_PATH` before
executing the smoke binary.

The macOS helpers accept the same `SKIA_MBT_*` environment defaults as Linux:
`SKIA_MBT_SKIA_INCLUDE`, `SKIA_MBT_SKIA_LIB_DIR`, `SKIA_MBT_SKIA_LIB`,
`SKIA_MBT_SKIA_REV`, `SKIA_MBT_EXTRA_GN_ARGS`, `SKIA_MBT_EXTRA_CC_FLAGS`, and
`SKIA_MBT_EXTRA_LINK_FLAGS`. Command-line arguments and workflow inputs override
environment variables.

To generate a persistent `native/moon.pkg` for an existing macOS Skia build,
preview the config first and then write it explicitly:

```bash
bash scripts/configure-macos-native-pkg.sh \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static

bash scripts/configure-macos-native-pkg.sh \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static \
  --write
```

Use `--check` in CI or local scripts to verify that `native/moon.pkg` still
matches the expected macOS Skia link config. The macOS smoke helper uses this
same generator for its temporary package rewrite, including the required macOS
framework link flags.

The `macOS Real Skia Smoke` workflow exposes source-build inputs (`skia_rev`,
`extra_gn_args`) and existing-build inputs (`skia_include`, `skia_lib_dir`,
`skia_lib`) plus `extra_*` and `dry_run_config`. Supplying both existing-build
paths skips the source build and cache. The workflow saves
preflight/build/smoke/native logs as the `macos-real-skia-smoke-log` artifact,
records the acceptance log, and verifies the same native smoke marker and
temporary package restoration after real runs.

## Windows real Skia smoke

The Windows helpers currently cover existing-build smoke paths only. Use the
MinGW-compatible path when MoonBit is building native stubs through GCC/MinGW:

```powershell
.\scripts\windows-accept-real-skia-smoke.ps1 -LogDir logs `
  -SkiaInclude C:\path\to\skia `
  -SkiaLibDir C:\path\to\skia\out\moonbit-smoke
```

Use the MSVC path for the default JetBrains provider or a prepared release zip
or checkout that provides `skia.lib`. The workflow fetches JetBrains packages
into `.skia-cache/jetbrains`; the helper calls `vcvarsall.bat`, builds with
`cl`, prepends the Skia library directory to `PATH`, captures the same artifact
log names, and restores both temporary package rewrites:

```powershell
.\scripts\windows-msvc-accept-real-skia-smoke.ps1 -LogDir logs
```

Pass `-SkiaRoot`, `-SkiaInclude`, `-SkiaZip`, `-SkiaLibDir`, `-VcVarsAll`, or
`-VcArch` when a self-hosted runner uses a different Visual Studio install or
Skia layout. The MSVC helper also accepts `SKIA_MBT_SKIA_ROOT`,
`SKIA_MBT_SKIA_INCLUDE`, `SKIA_MBT_SKIA_ZIP`, `SKIA_MBT_SKIA_LIB_DIR`,
`VCVARSALL`, `SKIA_MBT_EXTRA_CC_FLAGS`, and `SKIA_MBT_EXTRA_LINK_FLAGS` as
environment defaults.

Use `-SkiaLib`, `-ExtraCcFlags`, and `-ExtraLinkFlags` when the build uses a
non-default library name or needs additional dependent libraries. The acceptance
wrapper captures the dry-run preflight log, wrapper log, native executable log, and
`windows-real-skia-acceptance.log`; checks the final
`skia_mbt native smoke test passed` marker; and verifies that `native/moon.pkg`
was restored. The lower-level smoke helper checks for `include/core/SkSurface.h`,
either `lib<name>.a` or `<name>.lib`, temporarily rewrites `native/moon.pkg`,
runs `scripts/native_smoke`, restores the package file, and prepends the Skia
library directory to `PATH` before running the smoke binary so adjacent DLLs can
be found.

The Windows helpers also accept the same existing-build environment defaults as
Linux: `SKIA_MBT_SKIA_INCLUDE`, `SKIA_MBT_SKIA_LIB_DIR`, `SKIA_MBT_SKIA_LIB`,
`SKIA_MBT_EXTRA_CC_FLAGS`, and `SKIA_MBT_EXTRA_LINK_FLAGS`. Explicit PowerShell
parameters override environment variables, which lets a self-hosted runner keep
Skia paths in its environment while workflow inputs can still override them.

To generate a persistent Windows `native/moon.pkg` for an existing
MinGW-compatible Skia build, preview the config first and then write it
explicitly:

```powershell
.\scripts\configure-windows-native-pkg.ps1 `
  -SkiaInclude C:\path\to\skia `
  -SkiaLibDir C:\path\to\skia\out\moonbit-smoke

.\scripts\configure-windows-native-pkg.ps1 `
  -SkiaInclude C:\path\to\skia `
  -SkiaLibDir C:\path\to\skia\out\moonbit-smoke `
  -Write
```

Use `-Check` to verify that the file still matches the expected Windows Skia
link config. The Windows smoke helper uses this same generator for its temporary
package rewrite.

For preflight without rewriting `native/moon.pkg` or building the smoke binary:

```powershell
.\scripts\windows-skia-smoke.ps1 `
  -SkiaInclude C:\path\to\skia `
  -SkiaLibDir C:\path\to\skia\out\moonbit-smoke `
  -DryRunConfig

.\scripts\windows-msvc-skia-smoke.ps1 -DryRunConfig
```

The `Windows Real Skia Smoke` workflow exposes the same existing-build inputs,
saves preflight/wrapper/native/acceptance logs as the
`windows-real-skia-smoke-log` artifact, verifies the native smoke marker after
real runs, and checks that `native/moon.pkg` was restored. Its `dry_run_config`
input can be used without `skia_include` / `skia_lib_dir`; real runs require
both existing-build paths.
