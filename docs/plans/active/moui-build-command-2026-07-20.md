# Plan: `moui build` command + Final shell script deletion

- **Status**: active
- **Goal**: Wire the existing `build_android` / `build_ios` / `build_harmonyos`
  MoonBit implementations to a new public `moui build` subcommand, route
  `moui run`'s build step through the same path, then delete the 17 legacy
  shell / Node scripts that the MoonBit implementations have already replaced.
- **Non-goals**:
  - Rewriting `record-shell-runtime-smoke.mjs` end-to-end (only its
    `app-config.mjs` dependency gets inlined).
  - Adding new build features (signing config, custom abi, etc.) — the MoonBit
    `Build*Options` structs already cover what the legacy scripts accept.
  - Desktop platform support — `moui run` / `moui build` remain mobile-only;
    desktop targets continue to use `moon run`.
- **Context**: `moui_cli` 0.2.0 shipped the `run` / `devices` / `verify` /
  `config` command surface and the `build_android` / `build_ios` /
  `build_harmonyos` / `build_ios_core` functions (all 213/213 tests passing),
  but `run_run` step 4 only logs `"skipping build"` instead of invoking
  `build_*`. This plan closes that gap so the equivalent shell / Node scripts
  can be deleted.

## Phases

### Phase 1 — `moui build` subcommand

New file `moui_cli/build_command.mbt`:

- `ParsedBuild` struct (mirrors `ParsedRun` minus the run-only options
  `device` / `no_install` / `no_launch` / `debug` / `filter` / `verify` /
  `custom_args`, plus the build-only options `workspace_root` / `moui_root` /
  `skia_root` / `output` / `android_project` / `xcode_project` / `scheme` /
  `product_name` / `harmonyos_project` / `abi` / `compile_sdk` / `target_sdk`
  / `sdk` / `arch` / `deployment_target` / `sdk_home` / `hvigorw` / `ohpm`
  / `signing_config_file`).
- `parse_build_args(args, cwd, host) -> Result[ParsedBuild, String]` reuses
  the same option-parsing helpers (`option_parts`, `flag_without_value`,
  `option_value`) as `parse_run_args`.
- `build_usage()` text.
- `run_build(parsed, host) -> CliOutcome`:
  1. Read `shell.json` via `read_shell_app(project_root)`.
  2. Resolve `CliConfig` for SDK / NDK / Xcode SDK defaults.
  3. Convert `BuildCommandOptions` to `BuildAndroidOptions` / `BuildIosOptions`
     / `BuildHarmonyosOptions` based on `parsed.platform`.
  4. Call `build_android` / `build_ios` / `build_harmonyos`.
  5. Emit `BuildResult` as JSON or text.

CLI dispatch in `moui_cli/cli.mbt:run_cli`:

```moonbit
"build" =>
  match parse_build_args(args[1:].to_owned(), cwd, detect_host_platform()) {
    Ok(parsed) => run_build(parsed, detect_host_platform())
    Err(message) =>
      failed_outcome(message, json_requested(args), build_usage())
  }
```

Add `"build"` to `root_usage()` listing.

Tests (`moui_cli/build_command_wbtest.mbt`):
- Parse success for each platform (positional + every option).
- Parse rejects unknown platform with the same error shape as `moui run`.
- `--ejected-shell` validation per platform.
- `run_build` returns `failed_outcome` when `shell.json` is missing.
- `run_build` returns `failed_outcome` on iOS host != macOS (delegates to
  `build_ios`'s guard).
- Build result JSON shape (artifact path / build_dir / platform).

### Phase 2 — `moui run` step 4 wires to `build_*`

`moui_cli/run.mbt:run_run` step 4 (currently `log_info("skipping build")`):

- Extract a private helper `build_options_from_run_options(options, app, platform, cwd, host) -> Result[BuildCommandOptions, String]` that fills `workspace_root` / `moui_root` / `skia_root` from `CliConfig` (or sensible defaults `cwd` / `cwd/moui` / `cwd/moui_skia`).
- Replace the `if not(options.no_build)` block with:

  ```moonbit
  let artifact = if not(options.no_build) {
    match build_options_from_run_options(options, app, parsed.platform, cwd, host) {
      Ok(build_options) =>
        match run_build_internal(build_options, parsed.platform, host) {
          Ok(result) => result.output_artifact
          Err(message) => return failed_outcome(message, parsed.json, run_usage())
        }
      Err(message) => return failed_outcome(message, parsed.json, run_usage())
    }
  } else {
    find_build_artifact(parsed.platform, build_dir, app.id)
  }
  ```

- `run_build_internal` is the platform-dispatch + `build_*` call extracted from
  `run_build` so both `moui build` and `moui run` share it.
- `--build-only` short-circuits after `run_build_internal` returns, emitting
  the same `BuildResult` text/JSON as `moui build`.
- `--prepare-only` short-circuits after `prepare_native_build` (called inside
  `build_*`); the existing `prepare-only` text output stays.

Tests (`moui_cli/run_wbtest.mbt`):
- Mock `build_*` via `process_exec_argv` stubs is out of scope (those are
  covered by `build_*_wbtest.mbt`); `run_wbtest` only verifies that
  `--no-build` skips the `build_*` call and that `--build-only` produces the
  `build-only` status text without trying to install/launch.

### Phase 3 — Fixture script migration

Five shell fixtures stop calling `moui_shell/scripts/build-*.sh` and call
`moui build` instead:

| File | Change |
|---|---|
| `moui_shell/test_probe/tests/build-plugin-fixture.sh` | 3 platform branches → `moui build <platform> showcase ...` |
| `moui_shell/test_probe/tests/build-clean-ejected-fixture.sh` | 3 platform branches → `moui build <platform> showcase --ejected-shell ...` |
| `moui_shell/test_probe/tests/run-shell-matrix.sh` | `run_managed` → `moui build` |
| `moui_shell/harmonyos/runner/tests/build-plugin-fixture.sh` | 1 harmonyos branch → `moui build harmonyos ...` |
| `scripts/build-shell-{android-apk,ios-app,harmonyos-hap}.sh` | Either delete (preferred) or thin wrappers that exec `moui build <platform> ...` |

`MOUI_SHELL_PACKAGE_ROOT` env stays (still used by `moui shell eject`).

### Phase 4 — Validator migration

Two managed-shell validators read deleted `.sh` source for token checks:

| File | Current check | New check |
|---|---|---|
| `moui_shell/ios/embedder/tests/validate-managed-shell.mjs` (lines 32, 46, 130-156) | Reads `build-ios-app.sh` for `shell_mode="managed"`, `--ejected-shell`, `xcode_project=...`, `template_root=...`, etc. | Reads `moui_cli/build_ios.mbt` for the equivalent tokens (`shell_mode = "managed"`, `ejected_shell`, `xcode_project`, `template_root`). Tokens that have no MoonBit equivalent (e.g. shell-script-specific `xcode_project="$workspace_root/ios_app` rejection) are dropped. |
| `moui_shell/harmonyos/runner/tests/validate-managed-shell.mjs` (lines 48-60) | Reads `build-harmonyos-hap.sh` for 4 `MOUI_*` env-var assignments | Reads `moui_cli/build_harmonyos.mbt` for the same env-var names. |

### Phase 5 — `shell-app.gradle` migration

`moui_shell/android/runner/shell-app.gradle:prepareMouiShellNative` (lines 59-69)
currently runs `node ${mouiShellRoot}/scripts/prepare-native-build.mjs`.

Two options:

- **A (preferred)**: Exec `moui build android <app> --prepare-only ...`. The
  `prepare-only` flag already short-circuits inside `build_android` after
  `prepare_native_build` runs, so no new code path is needed.
- **B**: Exec `moui prepare-native-build` as a dedicated subcommand. Adds
  surface area; only worth it if Gradle needs finer control than `BuildAndroidOptions`
  exposes.

Choose A unless Gradle proves to need option B.

### Phase 6 — `record-shell-runtime-smoke.mjs` inlines `app-config.mjs`

`scripts/record-shell-runtime-smoke.mjs:24` imports `readShellApps` from
`moui_shell/scripts/app-config.mjs`. Inline the small subset it actually uses
(estimate: ~80 lines of Node — `readShellApps`, `defaultWorkspaceRoot`,
`defaultMouiRoot`, `defaultSkiaRoot`, `appMetadataPath`). The rest of
`app-config.mjs` (plugin manifest resolution, schema validation) is only used
by the deleted `.test.mjs` files, so it can go away.

After inlining, `app-config.mjs` / `app-config.test.mjs` / `shell-config-schema.mjs`
/ `shell-config-schema.test.mjs` / `plugin-manifest.mjs` / `plugin-manifest.test.mjs`
become deletable.

### Phase 7 — Delete 17 files

> **Scope correction (2026-07-20):** the original plan claimed
> `app-config.mjs` / `shell-config-schema.mjs` / `plugin-manifest.mjs` were
> only used by their own `.test.mjs` files. In fact they are still imported
> by the **active runtime shell resolvers**
> `moui_shell/{android,ios,harmonyos}/runner/resolve-shell.mjs` and
> `moui_shell/android/embedder/prepare-plugins.test.mjs`,
> `moui_shell/test_probe/tests/validate-test-probe.mjs`. They were restored
> via `git checkout HEAD --` after the initial delete. The actual final
> deletion count is **10 files** (3 `.sh` + 7 `.mjs`/`.test.mjs`), not 17.
> A follow-up plan is needed to migrate `resolve-shell.mjs` (3 platforms)
> and `prepare-plugins.mjs` away from these Node modules before they can
> be deleted.

```sh
rm moui_shell/scripts/build-android-apk.sh
rm moui_shell/scripts/build-ios-app.sh
rm moui_shell/scripts/build-harmonyos-hap.sh
rm moui_shell/scripts/validate-ejected-lock.{mjs,test.mjs}
rm moui_shell/scripts/prepare-native-build.mjs
rm moui_shell/scripts/harmonyos-skia-link.{mjs,test.mjs}
rm moui_shell/scripts/android-ndk.{mjs,test.mjs}
```

**Keep**: `app-config.{mjs,test.mjs}`, `shell-config-schema.{mjs,test.mjs}`,
`plugin-manifest.{mjs,test.mjs}` — still used by `resolve-shell.mjs` and
related tests.

**Keep**: `moui_shell/scripts/build-ios-app-core.sh` (M13 thin launcher for
Xcode Run Script Phases).

### Phase 8 — Update validators & CI

- `tools/moui/validate_harness_invariants/main.mbt:check_r3_prepare` (line 939):
  change the path it inspects from `moui_shell/scripts/prepare-native-build.mjs`
  to `moui_cli/prepare_native_build.mbt`, and update the token list to match
  the MoonBit source (`--renderer`, `auto`, `skia-gpu`, `skia-raster`).
- `tools/moui/check_shell_app_config/android_shell.mbt:validate_no_legacy_shell_sources`
  (lines 20-24): remove the deleted `.sh` paths; keep
  `moui_shell/scripts/prepare-native-build.mjs` removed (it's gone) and
  `moui_shell/android/embedder/prepare-plugins.mjs` (kept, if still present).
- `tools/moui/check_shell_app_config/android_shell.mbt:validate_platform_shell_layout`
  (lines 140-156): drop references to `resolve-shell.mjs` if it's deleted.
- `.github/workflows/moui-shell-contracts.yml` (lines 76-77, 126, 151, 184):
  remove `node --test moui_shell/scripts/{plugin-manifest,android-ndk,shell-config-schema,app-config}.test.mjs`
  steps; keep `run-shell-matrix.sh <platform>` (now invokes `moui build`).
- `moui_cli/moon.mod`: bump version `0.2.0` → `0.3.0`, keywords add
  `"build"`.
- `moui_cli/cli.mbt`: bump `version` constant.

### Phase 9 — Final verification

```sh
moon test moui_cli --target native          # new build_command_wbtest passes
moon info moui_cli --target native           # public API ok
moon test tools/moui --target native         # validator changes pass
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-guidance-consistency.mjs
sh scripts/check.sh --profile pr
```

Platform smoke (manual, requires SDK / device):
```sh
moui_shell/test_probe/tests/run-shell-matrix.sh android --fallback-skia
moui_shell/test_probe/tests/run-shell-matrix.sh ios --fallback-skia
moui_shell/test_probe/tests/run-shell-matrix.sh harmonyos --fallback-skia
moui_shell/test_probe/tests/build-plugin-fixture.sh android
moui_shell/test_probe/tests/build-plugin-fixture.sh ios
moui_shell/test_probe/tests/build-plugin-fixture.sh harmonyos
```

## Risk and rollback

- **Risk**: Phase 2 changes `moui run`'s build step behavior. If `build_*`
  fails on a real device CI matrix, `moui run` regression blocks all mobile
  PRs.
- **Mitigation**: Phase 2 lands in the same PR as Phase 1 but behind
  extensive `build_command_wbtest` coverage; if smoke fails, revert the single
  PR (git revert) — no data loss, no broken state because Phase 7 deletion is
  a separate later PR.
- **Phase ordering**: Phases 1 + 2 land first (one PR). Phases 3-6 land
  second (one PR, depends on Phase 1+2). Phase 7 lands third (one PR, depends
  on Phases 3-6). Phase 8 lands with Phase 7. Phase 9 runs at each PR.

## Open questions

- Does `moui shell eject` need a `--build` flag to chain `moui build` after
  eject? Currently `build-clean-ejected-fixture.sh` calls `moui shell eject`
  then `bash build-*.sh`; with Phase 3 it would call `moui build --ejected-shell`.
  No new flag needed.
- Should `moui build` accept `--config KEY VALUE` overrides like `moui run`?
  Defer — `moui config` already persists them; `moui build` reads the same
  `CliConfig` automatically.
