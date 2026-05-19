# Development

This page collects local setup, example run commands, and validation guidance
for MoUI development.

## Local Dependencies

The upstream `Milky2018/window` package does not currently cover the targets
MoUI needs, so use the modified local checkout instead.

From the repository root:

```sh
sh scripts/setup-local-deps.sh
sh scripts/check-local-deps.sh
```

This keeps `Milky2018/window` resolved through the local path override in
`moon.mod.json`:

```json
"Milky2018/window": {
  "path": ".local_repos/window"
}
```

The checkout is intentionally a normal editable Git repository, not a submodule.
MoUI uses the `wzzc-dev/window` fork on the `moui-support` branch because the
current upstream package is macOS-only.

- Upstream: `https://github.com/moonbit-community/window.git`
- MoUI fork: `git@github.com:wzzc-dev/window.git`
- Fork branch: `moui-support`

`scripts/setup-local-deps.sh` configures the fork as `origin` and upstream as
`upstream`. When merging new upstream commits into the fork, fetch `upstream`
inside `.local_repos/window` and merge into `moui-support`. Keep fork changes
focused on the Web, Windows, and Linux platform packages when possible. Avoid
touching macOS or shared window logic unless a task explicitly requires that
broader change.

## Validation

For routine local development, prefer the bounded daily check:

```sh
sh scripts/dev-check.sh
```

It runs stable package-level tests and Web wasm-gc example builds without
invoking all-repository native or wasm-gc test targets.

Current-platform backend tests can be included without native example builds:

```sh
sh scripts/dev-check.sh --platform-examples-test
```

Native platform example builds such as
`moon build examples/todo/macos --target native` link platform stubs and
`wgpu-native`, so cold builds can be slow. Include them only when validating
the current host platform's executable examples:

```sh
sh scripts/dev-check.sh --platform-examples-build
```

Useful focused commands:

```sh
moon test render/webgpu_adapter --target wasm-gc
moon test backend/web --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/todo/web_wasm --target wasm-gc
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon test --target native
moon build examples/todo/macos --target native
moon build examples/counter/macos --target native
moon build examples/showcase/macos --target native
moon build examples/markdown_editor/macos --target native
moon build examples/todo/windows --target native
moon build examples/counter/windows --target native
moon build examples/markdown_editor/windows --target native
```
