# MoUI CLI

`moui` creates and operates independent MoUI projects. Mobile targets use the
matching `wzzc-dev/window` host template and `*_window_hosted` entrypoint; the
CLI does not create a separate mobile runtime layer.

## Commands

| Command | Purpose |
|---|---|
| `moui new <target>` | Create an independent project. |
| `moui add platform <platform>` | Add a desktop, web, or mobile platform. |
| `moui doctor` | Check selected platform toolchains. |
| `moui package` | Print the project package inventory. |
| `moui build <platform> <app>` | Build Android, iOS, or HarmonyOS artifacts. |
| `moui run <platform> <app>` | Build, install, and launch a mobile artifact. |
| `moui devices` | List connected mobile devices and emulators. |
| `moui verify <platform> <app>` | Verify generated window-hosted mobile evidence. |
| `moui config <action>` | Read or update CLI configuration. |

Use `moui --help` or `moui <command> --help` for current options.

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
