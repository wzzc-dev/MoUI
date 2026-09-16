# MoUI CLI

`moui` creates and operates independent MoUI projects. Desktop and web
targets build and run directly from the project directory; mobile targets use
the matching `wzzc-dev/window` host template and `*_window_hosted` entrypoint,
so the CLI does not create a separate mobile runtime layer.

## Commands

| Command | Purpose |
|---|---|
| `moui new <target>` | Create an independent project. |
| `moui add platform <platform>` | Add a desktop, web, or mobile platform. |
| `moui doctor` | Check selected platform toolchains. |
| `moui package [platform] [app]` | Package a desktop/web app as a distributable (macOS `.app`, Windows portable folder, web bundle); without positional arguments, print the release-planning inventory. |
| `moui dev [package]` | Build, watch, restart, and serve a project during development. |
| `moui build <platform> <app>` | Build an artifact for any platform: desktop/web build the entrypoint package in place; Android / iOS / HarmonyOS produce APK / .app / .hap. |
| `moui run <platform> <app>` | Run an app: desktop builds and launches in place, web serves through the dev runner, mobile builds, installs, and launches on a device or emulator. |
| `moui devices` | List connected mobile devices, emulators, and the desktop host. |
| `moui verify <platform> <app>` | Verify generated embedded-runtime evidence. |
| `moui config <action>` | Read or update CLI configuration. |

Use `moui --help` or `moui <command> --help` for current options.

## Run Desktop And Web

```sh
moui run macos .    # build + launch the native executable
moui run windows .  # MSVC environment is configured automatically
moui run linux .
moui run web .      # serve through the dev runner (refresh + error overlay)
```

Package distributables:

```sh
moui package macos .     # dist/macos/<Name>.app
moui package windows .   # dist/windows-msvc/<Name>/ with exe + run.cmd
moui package web .       # static web bundle (gzip/brotli + bundle-size.json)
```

Linux run/build work directly (`moui run linux .`); Linux bundle packaging is
not implemented yet. Windows builds resolve the MSVC toolchain through
vswhere and vcvarsall in-process, so sourcing `scripts/windows/msvc_env.ps1`
first is no longer required (a preset `CC` environment is respected).

## Develop With A Watch Loop

From a generated project, run a one-shot build with `moui dev --once`. Without
`--once`, native packages are rebuilt and restarted after source changes. Web
packages use `--web` (or infer it from `web_wasm`) and serve the project at
`http://127.0.0.1:3000/`; successful rebuilds refresh the page and failed builds
appear in the injected error overlay while the watcher keeps running. Use
`--interval-ms`, `--port`, and `--state PATH` to tune the loop.

The `--state` path is passed to the app as `MOUI_DEV_STATE_FILE` for optional
file-based model handoff during a restart. V1 restarts processes and does not
preserve in-process runtime state.

## Create A Project

```sh
moon install wzzc-dev/moui_cli/cmd/moui
moui new my_app --platform android --bundle-id dev.example.myapp
cd my_app
moon update
moon check
```

Mobile project generation creates `moui.mobile.json` and an
`android_window_hosted`, `ios_window_hosted`, or `harmonyos_window_hosted`
package. Application code remains in `app/`.

## Build Mobile Targets

`moui.mobile.json` holds the application id, display name, shared app package,
and platform-specific identifiers. Build from the application workspace:

```sh
moui build android my_app --mobile-config "$PWD/moui.mobile.json"
moui build ios my_app --mobile-config "$PWD/moui.mobile.json"
moui build harmonyos my_app --mobile-config "$PWD/moui.mobile.json"
```

Use `--prepare-only` to generate inputs without invoking Gradle, Xcode, or
hvigor. `--fallback-skia` is packaging-only evidence and does not promote a
runtime support claim.

## Validate Hosts

```sh
moui doctor --platform android
moui devices --platform android
moui run android my_app --mobile-config "$PWD/moui.mobile.json"
```

The platform template owns lifecycle, surface creation, and input. MoUI's
backend supplies the app runtime and renderer provider through the window event
loop.
