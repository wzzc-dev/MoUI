# Mo Workbench

<div align="center">
  <img src="../../resource/screenshots/mo_workbench.png" width="600px" alt="Mo Workbench screenshot"/>
</div>

Mo Workbench is the native-Skia-first desktop agent dogfood app in the MoUI
workspace. It is a TRAE-style task workbench shell with three top tabs
(`Work` / `Code` / `Design`) and a side settings panel, wired over an
`AgentBackendRuntime` so the same shell renders an empty state, a code chat
surface, and a settings form from one shared
`Program[WorkbenchModel, WorkbenchMsg]`.

This example is the only one that requires an external submodule. The
`openseek` agent transport is vendored locally under `./openseek` (see the
workspace top-level `moon.work` listing and `scripts/openseek-dev-mode.sh`) so
`mo_workbench/app` imports `bobzhang/openseek@0.2.0` through the workspace path.

## Package Shape

- `app/` — shared `WorkbenchModel` / `WorkbenchMsg` shell plus the embedded
  `CodeWorkspace` (coding-agent chat surface) and `SettingsWorkspace`
  (agent runtime + chrome settings form state). The `Model`/`Msg`/`update`/
  `view` split lives here; platform entrypoints only inject a backend.
- `macos_skia/` — the only wired entrypoint today. It constructs the
  `AgentBackendRuntime` and runs `program_with_backend` against the macOS
  native Skia host.
- `openseek_native_transport/` — native transport bridge glue used by the
  macOS entrypoint.

## Dependencies

```toml
import {
  "moonbitlang/async@0.19.4",
  "wzzc-dev/moui@0.1.4",
  "bobzhang/openseek@0.2.0",
}
```

`openseek` is not yet published to mooncakes.io; the workspace top-level
`moon.work` must list `./openseek` (the registry path is reserved). CI and
`scripts/dev-check.sh` enforce this via `scripts/validate-openseek-workbench.mjs`.

## Running

First enable the local `openseek` override and initialize the submodule:

```sh
git submodule update --init openseek
sh scripts/openseek-dev-mode.sh on
```

On first launch the app creates `.mo_workbench/settings.json` under the process
working directory (gitignored). Edit `openai_api_key` / `openai_base_url` there,
or copy from `settings.json.example` as a reference.

Then run the macOS Skia entrypoint:

```sh
moon run examples/mo_workbench/macos_skia --target native
```

Linux/Windows/Web entrypoints are reserved and not wired today.

## Tests

```sh
moon test examples/mo_workbench/app --target native
```

## Platform Coverage

| Target      | Entrypoint    | Status      |
| ----------- | ------------- | ----------- |
| macOS Skia  | `macos_skia`  | Wired       |
| Linux       | reserved      | Not wired   |
| Windows     | reserved      | Not wired   |
| Web wasm-gc | reserved      | Not wired   |

See [docs/mo-workbench.md](../../docs/mo-workbench.md) for the architecture
narrative and [docs/showcases.md](../../docs/showcases.md) for the showcase
listing.
