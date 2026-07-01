# Real Skia Smoke Acceptance

This project keeps the default MoonBit build independent from Skia. Real Skia
validation is opt-in and must prove all of these facts before a platform can be
called accepted:

See `SKIA_PLATFORM_STATUS.md` for the current Linux/macOS/Windows acceptance
matrix and the exact evidence still missing per platform.

- `scripts/native_smoke` was built for the native target with `MOUI_SKIA_HAS_SKIA`.
- The produced executable ran to completion and printed
  `moui_skia native smoke test passed`.
- `native/moon.pkg` and `scripts/native_smoke/moon.pkg` were restored to their
  original contents after the temporary link rewrite.
- The wrapper log records the Skia include path, library path, native flags,
  library file, and resolved `skia_commit` when the Skia checkout is available.
- When SkParagraph is enabled, the wrapper log records the requested
  SkParagraph mode plus header/library availability before the native smoke is
  run.
- The acceptance log records `smoke_status=0`, `native_smoke_marker=passed`,
  and `native_pkg_restore=passed`.
- Artifact verification rejects wrapper, native-smoke, or acceptance logs that
  still contain dry-run markers. The preflight log is intentionally a dry-run
  configuration preview, but it is not acceptance evidence by itself.

## GitHub Release Provider

The default desktop provider is the `wzzc-dev/skia` GitHub release locked in
`skia-provider-lock.json`:

- provider: `release`
- owner/repo: `wzzc-dev/skia`
- tag: `dev-6d73578a36`
- commit: `6d73578a36506d10bc044e920cc71037982e481d`
- config: `Release`
- default link mode: `static`

The fetch helpers select the host package, cache it under
`.skia-cache/release/<tag>/<platform>-<config>-<arch>-<link-mode>/`, verify the
package SHA256, scan for headers and libraries, and fall back to the same-tag
source archive for headers when a binary zip does not include them:

```bash
bash scripts/fetch-release-skia.sh --platform auto --arch auto --print-env
```

```powershell
.\scripts\fetch-release-skia.ps1 -Platform auto -Arch auto -PrintEnv
```

The real-smoke wrappers consume the fetch output and still delegate final
`native/moon.pkg` generation to the existing configure scripts. Release logs
must record `skia_provider=release`, `skia_link_mode`, `release_owner`,
`release_repo`, `release_tag`, `release_url`, full `skia_commit`,
`skia_package`, `skia_package_sha256`, include/lib paths, and final compile/link
flags. `scripts/verify-real-skia-artifact.*` rejects logs whose release
metadata, link mode, package, or SHA256 does not match the lock file. Use
`MOUI_SKIA_LINK_MODE=dynamic` or `--link-mode dynamic` to select the dynamic
asset explicitly.

Use `--skia-provider source` for source-built fallback and diagnostic runs, or
`--skia-provider existing` with explicit include/lib paths for a prepared Skia
build.

Linux and macOS native smoke helpers also accept `--enable-asan` or
`MOUI_SKIA_ENABLE_ASAN=1`. That mode appends AddressSanitizer compile/link flags,
records `asan=enabled` in the wrapper logs, and sets conservative default
`ASAN_OPTIONS` when the runner has not provided its own. ASan is extra evidence
for a real smoke run, not a substitute for the required native-smoke,
acceptance-log, and artifact verifiers. Windows MSVC remains artifact
verification only until its sanitizer mode is proven separately.

Text proof runs build SkParagraph by default. Use
`--require-skparagraph` or `MOUI_SKIA_REQUIRE_SKPARAGRAPH=1` when missing
SkParagraph headers or required SkParagraph, SkShaper, SkUnicode, HarfBuzz, and
ICU libraries should fail the run before any proof marker is emitted.

## Linux Source Acceptance

Linux remains the first source-build path and should be used when establishing
or refreshing the canonical `skia-revision.txt` fallback pin. The default Linux
real smoke now uses the locked release provider; pass `--skia-provider source` for this
source-built path.

Run locally on Ubuntu or trigger the `Linux Real Skia Smoke` workflow without
`dry_run_config`:

```bash
bash scripts/install-linux-smoke-deps.sh
bash scripts/linux-accept-real-skia-smoke.sh --skia-provider source --work-dir .skia-cache/linux
```

On a pre-provisioned Ubuntu runner, use
`bash scripts/install-linux-smoke-deps.sh --check` to verify the required apt
packages before spending time on native smoke work. This includes
`libwayland-dev`, `libwayland-bin`, and `wayland-protocols`, which the
`wzzc-dev/window` native prebuild requires for the xdg-shell protocol XML,
Wayland headers, and `wayland-scanner`. The source-build path installs `clang`
plus fontconfig/FreeType/HarfBuzz development headers and sets Skia GN
`cc="clang"` / `cxx="clang++"` by default for reproducible Linux smoke builds.

Default release expected artifact/log files:

- `logs/linux-real-skia-smoke-preflight.log`
- `logs/linux-real-skia-smoke.log`
- `logs/linux-native-smoke-output.log`
- `logs/linux-real-skia-acceptance.log`

Source-built expected artifact/log files:

- `logs/linux-real-skia-smoke-preflight.log`
- `logs/linux-real-skia-smoke.log`
- `logs/linux-skia-build.log` for source-built runs
- `logs/linux-native-smoke-output.log`
- `logs/linux-real-skia-acceptance.log`

Required checks:

```bash
bash scripts/verify-native-smoke-log.sh logs/linux-native-smoke-output.log
bash scripts/verify-acceptance-log.sh logs/linux-real-skia-acceptance.log
bash scripts/verify-real-skia-artifact.sh --platform linux --log-dir logs
```

Add `--require-commit` to the acceptance and artifact checks only for
source-built runs that will be used to pin `skia-revision.txt`.

The native smoke log verifier checks both the final pass marker and intermediate
stage markers for readback, bounded readback, snapshot/image drawing, PNG
encode/decode, codec creation, decoded bitmap readback, render resource
planning, target-based raster surface construction, predictable unsupported
window/GPU target handling, target identity/resource binding, present descriptor
validation, opt-in Metal GPU context support diagnostics, opt-in Metal GPU
surface allocation/finalization markers,
shaped glyph-run command replay, cacheable/uncacheable render-frame resource
subplans, render-frame submission resource planning,
cacheable/uncacheable submission resource subplans, render-frame submission
preflight/cache population, render-frame finalization resource planning,
cacheable/uncacheable finalization resource subplans, render-frame
finalization preflight/cache population, surface finalization resource planning, surface
finalization cache-key variation, GPU finalization resource planning, GPU frame
finalization resource filtering, surface present resource planning, GPU present
resource planning, GPU frame submission resource planning, GPU-backed submission
subplans, resource-cache preflight missing/resident splits,
byte-range text-run resource keys, text measurement resource planning,
measured-text result resource planning, measured-text result cache-key
variation, text measurement cache-key variation,
text shaping resource planning, shaped-text result resource planning, shaped
glyph-run resource planning, shaped glyph-run cache-key variation, optional
native shaped glyph descriptor bridging, UTF-8 text
measurement, glyph count, glyph ID mapping, glyph advances, glyph positions,
glyph bounds, text bounds measurement, font metrics, and font manager family
enumeration, character fallback, fallback family metadata, resolved fallback
match resource planning, fallback resolution metadata planning, native fallback
resolution bridging, and optional SkParagraph availability, paragraph line
metrics, selection boxes, and hit testing.

The `--require-commit` checks are mandatory for the first source-built Linux
acceptance because that run establishes the revision to pin. Existing-build
Linux smoke runs are still useful, but if their Skia include path is not a Git
checkout the acceptance log may record `skia_commit=unknown`; such runs must not
be used for `skia-revision.txt` pinning.
For source-built Linux artifacts, `verify-real-skia-artifact.sh --require-commit`
also requires `logs/linux-skia-build.log` and checks that it records the Skia
build environment, checkout path, resolved commit, and GN arguments. It also
requires the `skia_commit` in the build log, wrapper log, and acceptance log to
match before the artifact can be used for revision pinning. The wrapper log and
acceptance log must also reference the build log so the downloaded artifact
bundle can be audited as one connected run.

To reuse an existing Linux Skia build without long command lines, the Linux
helpers accept `MOUI_SKIA_SKIA_INCLUDE`, `MOUI_SKIA_SKIA_LIB_DIR`,
`MOUI_SKIA_SKIA_LIB`, `MOUI_SKIA_EXTRA_CC_FLAGS`, and
`MOUI_SKIA_EXTRA_LINK_FLAGS` as environment defaults. Command-line options still
win when both are supplied.
For source-built Linux runs, revision selection is `--skia-rev`, then
`MOUI_SKIA_SKIA_REV`, then `skia-revision.txt`, then `main`.
When you want a persistent Linux link configuration instead of a temporary smoke
rewrite, use `scripts/configure-linux-native-pkg.sh` to preview, write, or check
the generated `native/moon.pkg` contents for an existing Skia build.

If you downloaded the workflow artifact as a log directory on Windows, audit the
same bundle from PowerShell:

```powershell
.\scripts\verify-real-skia-artifact.ps1 -Platform linux -LogDir logs -RequireCommit
```

On Linux or macOS, the equivalent artifact-level audit is:

```bash
bash scripts/verify-real-skia-artifact.sh --platform linux --log-dir logs --require-commit
```

After the first successful source-built run, pin the resolved commit:

```bash
bash scripts/pin-skia-revision.sh logs/linux-real-skia-acceptance.log
```

The guarded one-step variant runs the source-built acceptance, verifies the log
bundle with `--require-commit`, pins `skia-revision.txt`, and checks the pin:

```bash
bash scripts/linux-accept-and-pin-skia.sh --work-dir .skia-cache/linux
```

To also mark Linux accepted in `skia-platform-status.json` after the pin
verifies, add `--accept-platform-status`:

```bash
bash scripts/linux-accept-and-pin-skia.sh --work-dir .skia-cache/linux --accept-platform-status
```

It intentionally rejects existing-build Skia paths and dry-run mode, because the
first repository pin must come from a real source-built Linux acceptance. The
wrapper checks Ubuntu smoke dependencies before starting the expensive build;
add `--install-deps` to install them first, or `--skip-deps-check` on a managed
runner.

The pin helper first verifies the acceptance fields and the full commit hash.
Do not replace `skia-revision.txt` with a guessed commit. It should move away
from `main` only after a real acceptance run proves that exact Skia commit.
After pinning, keep follow-up platform runs honest by checking that their
acceptance log matches the pinned revision:

```bash
bash scripts/verify-skia-revision-pin.sh logs/linux-real-skia-acceptance.log
```

Source-provider real-smoke workflows run the same check with
`--skip-if-unpinned`: the first source-built Linux run is allowed while
`skia-revision.txt` is still `main`, and later source runs fail if their
accepted `skia_commit` diverges from the pinned commit. Release-provider runs
are checked against `skia-provider-lock.json` instead.

PowerShell equivalent:

```powershell
.\scripts\linux-accept-artifact-and-pin.ps1 -LogDir logs

.\scripts\linux-accept-artifact-and-pin.ps1 -LogDir logs -AcceptPlatformStatus

.\scripts\pin-skia-revision.ps1 -AcceptanceLog logs\linux-real-skia-acceptance.log
.\scripts\verify-skia-revision-pin.ps1 -AcceptanceLog logs\linux-real-skia-acceptance.log
```

Prefer `linux-accept-artifact-and-pin.ps1` for downloaded Linux artifacts: it
verifies the full source-built artifact bundle with `-RequireCommit`, pins the
accepted commit, and verifies the pin in one step. Add `-AcceptPlatformStatus`
when the downloaded artifact should also mark Linux accepted in
`skia-platform-status.json` after the pin verifies.
On Linux or macOS, use the shell equivalent for downloaded artifacts:

```bash
bash scripts/linux-accept-artifact-and-pin.sh --log-dir logs

bash scripts/linux-accept-artifact-and-pin.sh --log-dir logs --accept-platform-status
```

It performs the same artifact verification, writes the accepted commit to
`skia-revision.txt`, and verifies the pin. Add `--accept-platform-status` when
the downloaded artifact should also mark Linux accepted in
`skia-platform-status.json` after the pin verifies.
After the pin is in place, update the machine-readable platform matrix through
the guarded status helper rather than editing `skia-platform-status.json` by
hand:

```powershell
.\scripts\accept-platform-status.ps1 -Platform linux -LogDir logs -ArtifactLabel linux-real-skia-smoke-log
```

Shell equivalent:

```bash
bash scripts/accept-platform-status.sh --platform linux --log-dir logs --artifact-label linux-real-skia-smoke-log
```

The helper reruns artifact verification, checks that `skia-revision.txt` matches
the accepted commit, writes the accepted platform state, and then reruns the
platform-status verifier. The accepted platform state records both the artifact
label and the accepted commit, and the verifier requires that commit to match
`skia-revision.txt`.

The `Linux Real Skia Smoke` workflow also writes
`logs/linux-acceptance-state.patch` for source-built real runs. Review and apply
that patch after the artifact bundle passes; it contains the corresponding
`skia-revision.txt` and `skia-platform-status.json` updates without requiring a
second local edit. Before applying a downloaded patch, verify it locally:

```powershell
.\scripts\verify-acceptance-state-patch.ps1 -PatchFile logs\linux-acceptance-state.patch
```

The verifier checks that the patch only touches `skia-revision.txt` and
`skia-platform-status.json`, applies it in a temporary directory, and reruns the
platform-status checks.

## macOS Acceptance

macOS defaults to the locked release provider and also has source-build and
existing-build modes. Run locally on macOS or trigger the `macOS Real Skia Smoke`
workflow without `dry_run_config`:

```bash
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs
```

For the source-built fallback path:

```bash
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs \
  --skia-provider source \
  --work-dir .skia-cache/macos
```

To reuse an existing macOS Skia build, pass `skia_include` and `skia_lib_dir` to
the workflow, or run:

```bash
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

Expected artifact/log files:

- `logs/macos-real-skia-smoke-preflight.log`
- `logs/macos-skia-build.log`
- `logs/macos-real-skia-smoke.log`
- `logs/macos-native-smoke-output.log`
- `logs/macos-real-skia-acceptance.log`

Required checks:

```bash
bash scripts/verify-native-smoke-log.sh logs/macos-native-smoke-output.log
bash scripts/verify-acceptance-log.sh logs/macos-real-skia-acceptance.log
bash scripts/verify-real-skia-artifact.sh --platform macos --log-dir logs
```

PowerShell artifact-level check:

```powershell
.\scripts\verify-real-skia-artifact.ps1 -Platform macos -LogDir logs
```

If the macOS build uses the pinned Linux Skia revision, its `skia_commit` should
match `skia-revision.txt`. If it is intentionally testing another revision,
record that in the workflow input or local command line.
macOS helpers also accept `MOUI_SKIA_SKIA_INCLUDE`, `MOUI_SKIA_SKIA_LIB_DIR`,
`MOUI_SKIA_SKIA_LIB`, `MOUI_SKIA_SKIA_REV`, `MOUI_SKIA_EXTRA_GN_ARGS`,
`MOUI_SKIA_EXTRA_CC_FLAGS`, and `MOUI_SKIA_EXTRA_LINK_FLAGS` as environment
defaults. `MOUI_SKIA_LINK_MODE=static|dynamic|auto` controls whether the
generated macOS native package links `libskia.a` or `libskia.dylib`.
Workflow inputs and command-line options override those environment values.
When you want a persistent macOS link configuration instead of a temporary
smoke rewrite, use `scripts/configure-macos-native-pkg.sh` to preview, write, or
check the generated `native/moon.pkg` contents for an existing Skia build.
For pinned-revision macOS acceptance, verify the match explicitly:

```bash
bash scripts/verify-skia-revision-pin.sh logs/macos-real-skia-acceptance.log
```

## Windows Acceptance

Windows defaults to the locked `wzzc-dev/skia` release package through the MSVC helper.
It does not build Skia from source in CI. The MinGW-compatible path is still
available for GCC native-stub builds, and the MSVC path covers release or
prepared release zips/checkouts that provide `skia.lib` for static mode or
`skia.dll.lib` plus `skia.dll` for dynamic mode.

Run locally on Windows or trigger the `Windows Real Skia Smoke` workflow with
the default `skia_provider=release`:

```powershell
.\scripts\windows-msvc-accept-real-skia-smoke.ps1 -LogDir logs
```

For a prepared MinGW-compatible Skia build:

```powershell
.\scripts\windows-accept-real-skia-smoke.ps1 -LogDir logs `
  -SkiaInclude C:\path\to\skia `
  -SkiaLibDir C:\path\to\skia\out\moonbit-smoke
```

The release workflow fetches the locked Windows package into
`.skia-cache/release`. The MSVC helper calls `vcvarsall.bat`, prepends the
Skia library directory to `PATH`, and uses `cl` with the generated MSVC
`native/moon.pkg` link config. Pass `-SkiaRoot`, `-SkiaInclude`, `-SkiaZip`,
`-SkiaLibDir`, `-VcVarsAll`, or `-VcArch` when a runner uses a different layout.

Expected artifact/log files:

- `logs/windows-real-skia-smoke-preflight.log`
- `logs/windows-real-skia-smoke.log`
- `logs/windows-native-smoke-output.log`
- `logs/windows-real-skia-acceptance.log`

Required checks:

```powershell
.\scripts\verify-native-smoke-log.ps1 -LogPath logs\windows-native-smoke-output.log
.\scripts\verify-acceptance-log.ps1 -LogPath logs\windows-real-skia-acceptance.log
.\scripts\verify-real-skia-artifact.ps1 -Platform windows -LogDir logs
```

Windows MinGW acceptance requires `lib<name>.a` or `<name>.lib` that is
compatible with the GCC/MinGW toolchain used by that native-stub path.
Windows MSVC acceptance requires `skia.lib` for static mode, or `skia.dll.lib`
and adjacent `skia.dll` for dynamic mode, plus a Visual Studio developer
environment selected through `vcvarsall.bat`.
For self-hosted or manually prepared runners, the Windows helpers also accept
`MOUI_SKIA_SKIA_INCLUDE`, `MOUI_SKIA_SKIA_LIB_DIR`, `MOUI_SKIA_SKIA_LIB`,
`MOUI_SKIA_SKIA_ROOT`, `MOUI_SKIA_SKIA_ZIP`, `MOUI_SKIA_EXTRA_CC_FLAGS`, and
`MOUI_SKIA_EXTRA_LINK_FLAGS` as environment defaults. Workflow inputs and
explicit PowerShell parameters override those environment values.
When you want a persistent Windows link configuration instead of a temporary
smoke rewrite, use `scripts/configure-windows-native-pkg.ps1` for an existing
MinGW-compatible Skia build, or `scripts/configure-windows-msvc-native-pkg.ps1`
for an existing MSVC `skia.lib` build.

## What Still Does Not Count

These checks are useful but do not prove real Skia acceptance by themselves:

- `moon test` passing under the fallback build.
- `moon -C scripts/native_smoke build --target native` without Skia link flags.
- Any `--dry-run-config` command.
- `bash -n` or PowerShell parameter parsing.
- A workflow summary without downloadable logs showing the acceptance fields.

The final project goal remains broader than smoke acceptance: full platform
support also needs repeatable Skia acquisition/builds, stable linker discovery,
expanded API coverage, and real runner evidence for every supported platform.
