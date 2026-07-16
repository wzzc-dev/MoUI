# Getting Started

Choose the path that matches what you are trying to do.

## A. Browser Playground (no install)

Open the [browser Playground](https://wzzc-dev.github.io/MoUI/playground/) or
the website tutorial at `?section=tutorial`. Edit `main.mbt` and a controlled
`moon.pkg` without installing a native toolchain. Choose a lesson with
`/playground/?example=03-state-events`.

The visible editor is implemented with MoUI and `moui_richtext`. The browser
host only provides the Worker, Wasm load, and preview iframe bridge.

### Local Playground preview

```sh
moon build website/playground/web_wasm --target wasm-gc
node scripts/generate-playground-assets.mjs --out dist/playground
```

Serve `dist/` and open `dist/playground/`.

Playground user code is compiled for `wasm-gc` against an app-safe allowlist
(`moui` facades + `views`). Runtime, renderer, and arbitrary registry imports
are rejected before compilation.

## B. Local multiplatform project (recommended, ~10 minutes)

Create a real project **outside** this monorepo with the standalone CLI:

```sh
moon install wzzc-dev/moui_cli/cmd/moui
# Or from a MoUI checkout: moon install ./moui_cli/cmd/moui

moui new my_app
# Optional smaller skeleton:
# moui new my_app --template hello

cd my_app
moon update
moon check
```

`moui new` writes shared app logic plus Web and the **current host desktop**
entrypoint (macOS / Windows / Linux Skia). Mobile platforms are opt-in with
`--platform android|ios|harmonyos` and `--bundle-id`.

### Run desktop (host-dependent)

```sh
# macOS
moon run macos_skia --target native

# Windows
moon run windows_skia --target native

# Linux (Wayland)
moon run linux_skia --target native
```

### Run Web

```sh
moon build web_wasm --target wasm-gc
# Serve the web_wasm package (static HTTP) and open index.html in a
# WebGPU-capable browser.
```

### What you get

| Path | Role |
| --- | --- |
| `app/` | Shared TEA model / update / view (`Program::simple`) |
| `web_wasm/` | Thin browser entrypoint |
| `*_skia/` | Thin native Skia entrypoint for the host OS |

Do **not** start by cloning the full MoUI monorepo unless you are changing the
framework. For monorepo examples, see [Examples](examples.md): `counter` is the
minimal multiplatform app, while Showcase's Platform workspace contains the
Effect/Subscription and host-service recipes.

More detail: [App templates](app-templates.md), [CLI README](../moui_cli/README.md),
[Non-render cookbook](non-render-component-cookbook.md).

## C. This repository (framework contributors)

```sh
git clone --recurse-submodules https://github.com/wzzc-dev/MoUI.git
cd MoUI
sh scripts/ci-moon-update.sh
sh scripts/check.sh --profile daily
moon run examples/counter/macos_skia --target native
```

See [Development](development.md) and `AGENTS.md` for package boundaries and
validation gates.
