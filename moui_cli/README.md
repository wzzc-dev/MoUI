# MoUI CLI

Standalone project generation, environment diagnostics, managed mobile shell
ejection, and light project maintenance for MoUI. The CLI does not depend on
`wzzc-dev/moui`, so installing it does not resolve or prebuild Skia.

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
| `moui plugin new` | Scaffold a managed mobile plugin |
| `moui package` | Print project package inventory |
| `moui mobile eject` | Materialize an app-owned mobile shell |

`moui --version` prints the **CLI version** and the **default framework
dependency version** written by `moui new`. Those two numbers are independent.

## Create a project

```sh
moui new hello_moui --module local/hello_moui
```

Mobile platforms are additive and require a stable bundle identifier:

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
managed mobile shell API 1/runtime ABI 1; mobile generation against that
release fails with no target directory. Repository development can validate
against the current package source with `MOUI_PACKAGE_ROOT=/path/to/moui`.

Generated projects include `README.md`, `moon.work`, and next-step build
commands for the selected platforms.

## Maintain an existing project

```sh
# Add Android/iOS later
moui add platform android --bundle-id dev.example.hello
moui add platform ios

# Scaffold a managed plugin and register it in mobile.json when present
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
moui doctor --project-root examples/component_gallery \
  --platform android --platform ios --platform harmonyos
```

Doctor JSON uses schema version 1 and `pass|warn|fail|skip` statuses. Exit code
`0` means there are no required failures, `1` means required checks failed,
and `2` means the command or project contract could not be parsed.

## Mobile eject

Materialize a versioned app-owned shell only into an empty path:

```sh
moui mobile eject android --output android_app
```

The command writes `.moui-shell.json` with shell API/runtime ABI versions and
SHA-256 digests for the canonical template, project config, plugins, and
ejected content. MoUI never updates an ejected shell automatically; doctor
reports compatibility, local changes, config/plugin drift, and upstream
template drift.
