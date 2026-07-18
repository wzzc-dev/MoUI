# 入门指南

选择与你要做的事情匹配的路径。

## A. 浏览器 Playground（无需安装）

打开[浏览器 Playground](https://wzzc-dev.github.io/MoUI/playground/)，或访问网站教程 `?section=tutorial`。无需安装原生工具链，即可编辑 `main.mbt` 和受控的 `moon.pkg`。可用 `/playground/?example=03-state-events` 选择一节课程。

可见编辑器由 MoUI 和 `moui_richtext` 实现。浏览器 host 只提供 Worker、Wasm 加载和预览 iframe 桥接。

### 本地网站 + Playground（一次完成）

打包与 GitHub Pages 相同的布局（`dist/pages` + 嵌套 playground）：

```sh
sh scripts/package-website-site.sh
cd dist/pages && python3 -m http.server 8080 --bind 127.0.0.1
```

然后打开 `http://127.0.0.1:8080/`（主页）和 `http://127.0.0.1:8080/playground/`（Playground）。

### 仅本地 Playground 预览

```sh
moon build website/playground/web_wasm --target wasm-gc
node scripts/generate-playground-assets.mjs --out dist/playground
```

提供 `dist/` 的静态服务并打开 `dist/playground/`。

Playground 用户代码会针对 `wasm-gc` 编译，并使用 app-safe allowlist（`moui` facade + `views`）。Runtime、renderer 和任意 registry import 会在编译前被拒绝。

## B. 本地多平台项目（推荐，约 10 分钟）

使用独立 CLI 在本 monorepo **之外**创建真实项目：

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

`moui new` 会写入共享 app 逻辑，以及 Web 和**当前 host 桌面**入口（macOS / Windows / Linux Skia）。Mobile 平台通过 `--platform android|ios|harmonyos` 和 `--bundle-id` 选择加入。

### 运行桌面（取决于 host）

```sh
# macOS
moon run macos_skia --target native

# Windows
moon run windows_skia --target native

# Linux (Wayland)
moon run linux_skia --target native
```

### 运行 Web

```sh
moon build web_wasm --target wasm-gc
# Serve the web_wasm package (static HTTP) and open index.html in a
# WebGPU-capable browser.
```

### 你会得到什么

| 路径 | 角色 |
| --- | --- |
| `app/` | 共享 TEA model / update / view（`Program::simple`） |
| `web_wasm/` | 很薄的浏览器入口 |
| `*_skia/` | 针对 host OS 的很薄原生 Skia 入口 |

除非你正在修改框架，否则**不要**从 clone 完整 MoUI monorepo 开始。对于 monorepo 示例，参见[示例](../examples.md)：`counter` 是最小多平台 app，而 Showcase 的 Platform 工作区包含 Effect/Subscription 和 host-service 配方。

更多细节：[App 模板](../app-templates.md)、[CLI README](../../moui_cli/README.md)、[非渲染 cookbook](../non-render-component-cookbook.md)。

## C. 本仓库（框架贡献者）

```sh
git clone --recurse-submodules https://github.com/wzzc-dev/MoUI.git
cd MoUI
sh scripts/ci-moon-update.sh
sh scripts/check.sh --profile daily
moon run examples/counter/macos_skia --target native
```

关于包边界和验证 gate，请参见[开发指南](../development.md)和 `AGENTS.md`。
