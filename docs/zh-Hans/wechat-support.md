# 微信小程序支持

微信小程序支持是一个 **experimental** 的 Canvas 2D WebAssembly
路径（product_class `experimental`，`ready=false`）。
与 Android、iOS 和 HarmonyOS 不同，它不使用原生移动端的 `window` 事件循环；
小程序模板直接调用 canvas host callbacks。该路径可编译，但在真实小程序
像素 smoke、触摸事件验证和 wx API 服务集成完成前，**不**做任何
开发/演示可用性或产品承诺。

Skyline 渲染引擎为小程序提供增强的 Canvas 2D 性能。MoonBit 包支持 `wasm` 和
`wasm-gc`；仓库构建辅助脚本当前以 `wasm` 为 WXWebAssembly 生成目标，再在
staging template 前降低不受支持的特性。渲染经 CanvasRenderingContext2D API 完成。

## 所有权

- `moui/backend/wechat` 提供 canvas host callbacks、拥有 canvas surface host，并为
  小程序应用提供 `run_app` 入口。
- `moui/render/canvas2d` 包装 `moui/render/canvas2d`，创建由 Canvas 2D API
  驱动的 `WindowRenderer`。
- `moui/render/canvas2d` 实现 Canvas 2D renderer，并通过 wasm-gc FFI imports
  生成 `WindowRenderer` closures。
- `window/wechat/template` 拥有小程序项目模板，以及到 MoonBit 导出 callbacks 的
  JS bridge。
- `scripts/build-wechat-demo.sh` 是演示应用的规范构建脚本。

## 架构

```text
┌─────────────────────────────────────────────────┐
│  微信小程序（Skyline Engine）                     │
│  ┌───────────┐  ┌─────────────┐  ┌───────────┐ │
│  │ WXML      │  │ WXSS        │  │ JS Logic  │ │
│  │ Canvas 2D │  │ Styles      │  │ Runtime   │ │
│  └─────┬─────┘  └─────────────┘  └─────┬─────┘ │
│        │                                │       │
│        │  CanvasRenderingContext2D       │       │
│        │  （触摸事件）                   │       │
│        │                                │       │
│  ┌─────▼────────────────────────────────▼─────┐ │
│  │          MoonBit WebAssembly Module         │ │
│  │  ┌──────────────────────────────────────┐  │ │
│  │  │  moui/render/canvas2d                │  │ │
│  │  │  DrawCommand → Canvas2D API          │  │ │
│  │  └──────────────────────────────────────┘  │ │
│  │  ┌──────────────────────────────────────┐  │ │
│  │  │  moui/backend/wechat                 │  │ │
│  │  │  run_app + HostRuntimeDriver         │  │ │
│  │  └──────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

## 渲染器

Canvas 2D renderer 的配置：

- **Backend**：`canvas2d-wasm`（RendererBackendKind::Canvas2DWasm）
- **Family**：`canvas2d`（RendererFamily::Canvas2D）
- **Target**：模板构建使用 `wasm`；包同时支持 `wasm-gc`
- **Presentation**：WebCanvas（CanvasRenderingContext2D API）

DrawCommands 对应到 Canvas 2D API：

- Rect/FillRect → `fillRect`、`strokeRect`
- RoundedRect → 基于 path 的圆角矩形 + `fill` / `stroke`
- Text → `fillText`，使用 `measureText` 做布局
- Image → `drawImage`
- Clip → `save` / `restore` + `clip`
- Transform → `setTransform`、`translate`、`rotate`、`scale`
- Opacity → `globalAlpha`
- Path → `beginPath` / `moveTo` / `lineTo` / `arc` / `bezierCurveTo` + `fill` / `stroke`
- Gradient → `createLinearGradient` / `createRadialGradient`
- Shadow → `shadowBlur` / `shadowColor` / `shadowOffsetX` / `shadowOffsetY`
- BlendMode → `globalCompositeOperation`
- Filter → `filter` 属性（blur、saturate、brightness、contrast）
- LayerCompositing → 离屏 canvases

## 输入

小程序通过 Canvas 元素提供触摸事件：

- **TouchStart** → `PointerDown`
- **TouchMove** → `PointerMove`
- **TouchEnd** → `PointerUp`

小程序 Canvas 环境不提供键盘和 IME。

## 生命周期

小程序模板拥有 App 和 Page 生命周期。后端导出 Surface 和生命周期 callback slots；
在设备证据证明完整生命周期契约前，它们仍是 partial：

- `App.onLaunch` → runtime 初始化
- `App.onShow` → 恢复 callback slot
- `App.onHide` → 暂停 callback slot
- `Page.onUnload` → Surface 销毁 callback slot

## 构建

```sh
# 构建 counter 演示
sh scripts/build-wechat-demo.sh counter

# 构建 showcase 演示
sh scripts/build-wechat-demo.sh showcase
```

构建输出位于 `_build/wechat/<app>/`，可直接导入微信开发者工具。

## 前置条件

- 微信小程序基础库 3.0+（Skyline rendering engine）
- WebAssembly 支持（基础库 2.15+）
- 微信开发者工具（最新稳定版）
- 支持 wasm / wasm-gc target 的 MoonBit toolchain

## 服务能力

服务应通过从 wasm 模块桥接的 wx API 提供：

| 能力 | 状态 | 说明 |
|------|------|------|
| 剪贴板 | Gap | wx.getClipboardData / wx.setClipboardData |
| 文件对话框 | Gap | 小程序中不可用 |
| 系统主题 | Gap | wx.getSystemInfo theme detection |
| 打开 URL | Gap | wx.navigateToMiniProgram / web-view |

## 限制

1. **无 DOM access**：所有渲染仅通过 Canvas 2D
2. **无 keyboard/IME**：小程序 Canvas 不支持文本输入
3. **无 drag-drop**：小程序环境不可用
4. **无 multi-window**：小程序设计上是单页
5. **无文件对话框**：小程序文件系统处于 sandbox
6. **需要 Skyline**：基础库 3.0+ 并启用 Skyline
7. **包大小**：wasm-gc 模块必须符合小程序包大小限制（代码包 2MB）

## 证据

平台证据记录在 `checks/platforms/wechat.json`。当前状态：

- **Renderer**：partial（能编译，尚无真实小程序 pixel smoke）
- **Host**：partial（canvas callbacks 已有，完整生命周期仍待设备验证）
- **Input**：partial（触摸事件，无 keyboard/IME）
- **Services**：gap（待集成 wx API）
