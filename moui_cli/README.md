# MoUI CLI

Standalone project generation, environment diagnostics, managed shell shell
ejection, and light project maintenance for MoUI. The CLI does not depend on
`wzzc-dev/moui`, so installing it does not resolve or prebuild Skia.

> **ADR 0015**: `moui build {android,ios,harmonyos}` now uses the
> window-hosted templates at `window/{android,ios,harmonyos}/template/`
> and rejects the retired `--ejected-shell` / `--{android,ios,harmonyos}-project`
> flags. The old `moui_shell/` managed-shell path is no longer produced.

```sh
# Local checkout
moon install ./moui_cli/cmd/moui

# Registry package (when published)
moon install wzzc-dev/moui_cli/cmd/moui
```

## Commands

| Command | Purpose |
|---------|---------|
| `moui new` | Create an independent MoUI project |
| `moui add platform` | Add platforms to an existing project |
| `moui doctor` | Diagnose toolchains and project contracts |
| `moui plugin new` | Scaffold a managed shell plugin |
| `moui package` | Print project package inventory |
| `moui build` | Build a mobile app artifact (APK / .app / .hap) without installing |
| `moui run` | Build, install, and launch a mobile app on a device or emulator |
| `moui devices` | List connected Android / iOS / HarmonyOS devices and emulators |
| `moui verify` | Verify mobile app runtime evidence against the managed shell contract |
| `moui config` | Get/set MoUI CLI configuration values (XDG-backed) |
| `moui shell eject` | Materialize an app-owned shell |

`moui --version` prints the **CLI version** and the **default framework
dependency version** written by `moui new`. Those two numbers are independent.

## Mobile development

`moui build` and `moui run` share the same `build_android` / `build_ios` /
`build_harmonyos` pipeline. `moui build` stops after producing the artifact;
`moui run` continues with install and launch. Both rely on the platform
toolchains (`adb` / `xcrun` / `hdc` / Gradle / Xcode / hvigor) being on PATH
and write outputs under `artifacts/<platform>/<app>/`.

All three platforms stage the window-hosted template from
`window/{android,ios,harmonyos}/template/` into `<build_dir>/<platform>-project/`
and pass `MBW_*` env vars / Gradle project properties so the template's
CMakeLists.txt can locate the workspace, the window module root, the MoonBit
runtime, and the generated MoonBit C. Stage markers
(`.moui-window-hosted-stage`) protect unowned directories from overwrite.

```sh
# List connected devices
moui devices

# Build the showcase APK without installing (run from the app directory)
moui build android showcase

# Build from the repository root by pointing at the app's shell.json
# (always use absolute paths for --app-config when invoking through Gradle /
# Xcode / hvigor — they cd into the staged project before re-invoking moui_cli)
moui build android  showcase --app-config "$PWD/examples/showcase/shell.json"
moui build ios       showcase --app-config "$PWD/examples/showcase/shell.json"
moui build harmonyos showcase --app-config "$PWD/examples/showcase/shell.json"

# iOS device build (defaults are iphonesimulator + arm64)
moui build ios showcase \
  --app-config "$PWD/examples/showcase/shell.json" \
  --sdk iphoneos --arch arm64

# Build only native inputs (MoonBit C / staged template / identity patch),
# skip packaging. Validates the full prepare pipeline (moon build / template
# staging / shell.json identity) without invoking Gradle / clang / hvigor.
moui build harmonyos showcase --app-config "$PWD/examples/showcase/shell.json" --prepare-only

# Build with a specific renderer and Skia fallback
moui build android showcase --renderer skia-gpu --fallback-skia

# Override the workspace / package roots (defaults come from `moui config`)
moui build ios showcase \
  --app-config "$PWD/examples/showcase/shell.json" \
  --workspace-root "$PWD" \
  --moui-root "$PWD/.mooncakes/wzzc-dev/moui" \
  --skia-root "$PWD/.mooncakes/wzzc-dev/moui_skia"

# Emit machine-readable build result JSON
moui build android showcase --app-config "$PWD/examples/showcase/shell.json" --json
```

### Per-platform toolchain requirements

| Platform | Toolchain | Required env / config | Default discovery |
|----------|-----------|-----------------------|-------------------|
| Android  | Gradle + Android SDK + NDK | `ANDROID_HOME` or `ANDROID_SDK_ROOT` | `~/Library/Android/sdk` (macOS), `~/Android/Sdk` (Linux) |
| iOS      | Xcode 15.4+ (clang / clang++) | — | `xcrun --sdk iphonesimulator` |
| HarmonyOS | DevEco-Studio + hvigorw + ohpm | `HARMONYOS_SDK_HOME` (or `OHOS_SDK_HOME`) | DevEco-Studio install path + `~/Library/OpenHarmony/Sdk/<ver>` |

Notes from verified 0.3.0 builds of `examples/showcase` (all three platforms
now use the window-hosted template; `--ejected-shell` / `--{platform}-project`
are rejected with an ADR 0015 error):

- **Android**: requires JDK 17+ (`export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home`). Default `compileSdk` / `targetSdk` is 34, but newer `androidx.activity` requires 36 — pass `--compile-sdk 36 --target-sdk 36` if the build fails with a `Dependency 'androidx.activity:activity' requires compileSdk 36` error. Verified APK: `artifacts/window-hosted-android/showcase.apk` (14 MB).
- **iOS**: `build_ios` invokes `clang` / `clang++` directly (no Xcode project) to compile MoonBit C, Moon runtime, window-hosted glue, Skia stubs, and `ios_skia_*_glue.mm`, then links with `-framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -framework Metal -framework MetalKit -lc++`. Verified `.app`: `artifacts/window-hosted-ios/showcase.app/` (5 MB executable + `Info.plist`).
- **HarmonyOS**: `hvigorw` and `ohpm` are auto-discovered from `/Applications/DevEco-Studio.app/Contents/tools/`. To override, pass `--hvigorw` / `--ohpm` or set `HVIGORW` / `OHPM` env vars. Builds produce unsigned HAPs unless a `signingConfigFile` is configured (via `--signing-config-file` or `moui config set harmonyos.signingConfigFile <path>`). Verified HAP: `artifacts/window-hosted-harmonyos/showcase.hap` (16 MB).

### Build artifacts

Successful builds write to:

| Platform | Path | Format |
|----------|------|--------|
| Android  | `artifacts/android/<app-id>.apk` | APK |
| iOS      | `artifacts/ios/<app-id>.app/`    | App bundle (directory) |
| HarmonyOS | `artifacts/harmonyos/<app-id>.hap` | HAP (ZIP archive) |

Use `--output PATH` to override the artifact path, or `--build-dir PATH` to
change the parent directory for a single invocation.

`moui run` orchestrates build → install → launch on Android / iOS / HarmonyOS
and reuses the same `Build*Options` as `moui build` (any `--renderer`,
`--fallback-skia`, `--ejected-shell`, `--prepare-only` flag is forwarded).

```sh
# Build, install, and launch the showcase app on the first Android device
moui run android showcase

# Build only (no install / launch) — equivalent to `moui build` but kept
# for compatibility with existing scripts
moui run harmonyos showcase --build-only

# Skip the build step and reuse an existing artifact
moui run android showcase --no-build

# Launch with a specific device and follow logs
moui run ios showcase --device UUID-DEAD --debug

# Run the runtime probe and write verify-manifest.json
moui verify android showcase --require-passed
```

`--build-only` and `moui build` produce the same artifact; prefer `moui build`
when you do not need device install. Use `--prepare-only` to validate MoonBit C
generation, JNI/CMake configuration, and shell staging without invoking Gradle
/ Xcode / hvigor — this is what the Android Gradle `prepareMouiShellNative`
task calls internally.

## Configuration (XDG-backed)

`moui config` stores user preferences at `$XDG_CONFIG_HOME/moui/config.json`
(or `%APPDATA%\moui\config.json` on Windows). Every field is optional — a
missing file degrades gracefully into `default_cli_config()`.

```sh
# Show the config file path
moui config show-path

# Get a single value
moui config get harmonyos.sdkHome

# Set a value (persisted)
moui config set android.sdkHome /opt/android-sdk

# List all set values
moui config list
```

Supported sections: `harmonyos` (`sdkHome`, `hvigorw`, `ohpm`,
`signingConfigFile`), `android` (`sdkHome`, `ndkHome`, `compileSdk`,
`targetSdk`), `ios` (`sdk`, `arch`, `deploymentTarget`), `paths` (`moonHome`,
`mouiRoot`, `skiaRoot`).

## Create a project

```sh
moui new hello_moui --module local/hello_moui
```

Shell platforms are additive and require a stable bundle identifier:

```sh
moui new hello_mobile \
  --module local/hello_mobile \
  --platform android \
  --platform ios \
  --bundle-id dev.example.hello
```

Generation happens in a sibling temporary directory. `moon update`,
`moon check --target all`, and `moon info --target all` must succeed before an
atomic no-replace rename makes the target visible. Registry `0.1.7` predates
managed shell shell API 1/runtime ABI 1; shell generation against that
release fails with no target directory. Repository development can validate
against the current package source with `MOUI_PACKAGE_ROOT=/path/to/moui`.

Generated projects include `README.md`, `moon.work`, and next-step build
commands for the selected platforms.

## Maintain an existing project

```sh
# Add Android/iOS later
moui add platform android --bundle-id dev.example.hello
moui add platform ios

# Scaffold a managed plugin and register it in shell.json when present
moui plugin new sample.camera --platform android

# Package inventory (no publish/upload)
moui package
moui package --json
```

## Doctor

```sh
moui doctor
moui doctor --all --json
moui doctor --fix
```

`--fix` only applies safe local remediations today:

- create missing `moon.work`
- create missing generated-style `README.md` from `moui.project.json`

Doctor does not install or download tools.

From a MoUI repository checkout, point doctor at a repository app package; it
discovers the nearest `moon.work` and reuses the workspace-owned framework,
Skia package, and Gradle wrapper:

```sh
moui doctor --project-root examples/showcase \
  --platform android --platform ios --platform harmonyos
```

Doctor JSON uses schema version 1 and `pass|warn|fail|skip` statuses. Exit code
`0` means there are no required failures, `1` means required checks failed,
and `2` means the command or project contract could not be parsed.

## Shell eject

Materialize a versioned app-owned shell only into an empty path:

```sh
moui shell eject android --output android_app
```

The command writes `.moui-shell.json` with shell API/runtime ABI versions and
SHA-256 digests for the canonical template, project config, plugins, and
ejected content. MoUI never updates an ejected shell automatically; doctor
reports compatibility, local changes, config/plugin drift, and upstream
template drift.
