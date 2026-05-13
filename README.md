# MoUI

MoUI 是一个面向 macOS native 的 MoonBit GUI 框架原型，底层复用 `Milky2018/window` 的窗口事件循环与 `Milky2018/wgpu_mbt` 的 WebGPU/Metal 能力。

## 首版范围

- 声明式 `ViewNode` 视图树。
- 几何、约束、布局、命中测试与绘制命令。
- 基础视图：`label`、`button`、`row`、`column`、`padding`。
- 后端与渲染 facade，为真实 surface 桥接预留集中接入点。
- `examples/counter` 作为窗口、事件、布局与重绘链路示例。

## 包结构

```text
core/              平台无关核心模型
views/             基础视图构造器
render/            渲染器 facade 与绘制批处理
backend/           macOS window 事件适配 facade
examples/counter/  Counter 示例应用
```

## 验证

```bash
export MBT_WGPU_NATIVE_ROOT=/Users/zc/Downloads/wgpu-macos-aarch64-release
moon check --target native
moon test --target native
moon fmt
moon info
moon run examples/counter --target native
```

`Milky2018/wgpu_mbt` 按上游 README 使用默认 static 模式；下游包只需要用
`"Milky2018/wgpu_mbt" @wgpu` 导入，不需要手写额外 link flags。如果本机无法访问
GitHub release 下载器，可将 `MBT_WGPU_NATIVE_ROOT` 指向已解压的官方
`wgpu-macos-aarch64-release` 目录。

## 已知限制

- 文本渲染首版使用占位几何，不包含字体栅格化。
- `wgpu_mbt` 当前公开 API 创建自有 `CAMetalLayer`，与 `window` 的真实 onscreen surface 桥接集中保留在 `backend/native_surface.mbt`。
- 跨平台后端、主题系统、无障碍树、动画与增量 diff 不在首版范围内。
