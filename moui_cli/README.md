# MoUI CLI

Standalone project generation, environment diagnostics, and managed mobile
shell ejection for MoUI. The CLI does not depend on `wzzc-dev/moui`, so
installing it does not resolve or prebuild Skia.

```sh
moon install wzzc-dev/moui_cli/cmd/moui
```

Create an independent project with Web and the current desktop platform:

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

Inspect the selected project and host toolchains:

```sh
moui doctor
moui doctor --all --json
```

Doctor JSON uses schema version 1 and `pass|warn|fail|skip` statuses. Exit code
`0` means there are no required failures, `1` means required checks failed,
and `2` means the command or project contract could not be parsed. Doctor does
not install or download tools.

Materialize a versioned app-owned shell only into an empty path:

```sh
moui mobile eject android --output android_app
```

The command writes `.moui-shell.json` with shell API/runtime ABI versions and
SHA-256 digests for the canonical template, project config, plugins, and
ejected content. MoUI never updates an ejected shell automatically; doctor
reports compatibility, local changes, config/plugin drift, and upstream
template drift.
