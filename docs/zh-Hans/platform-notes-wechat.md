# 微信小程序平台说明

## 概览

微信小程序支持面向 Skyline 渲染引擎，使用 Canvas 2D 渲染。MoonBit 编译为
WebAssembly，并运行在小程序的 JavaScript 逻辑层。

## Skyline 引擎

Skyline 是微信小程序的新一代渲染管线，提供：

- 更高的 Canvas 2D 性能
- 更好的触摸事件处理
- 基于 Worklet 的动画支持
- 相较 WebView 更好的渲染管线

Skyline 需要基础库 3.0+，可在 `app.json` 中启用：

```json
{
  "renderer": "skyline",
  "rendererOptions": {
    "skyline": { "defaultDisplayBlock": true }
  },
  "componentFramework": "glass-easel"
}
```

## Canvas 2D API

在 Skyline 模式下，可通过 `<canvas type="2d">` 元素使用 Canvas 2D API。
`CanvasRenderingContext2D` 通过 `wx.createSelectorQuery()` 获得，并指定
`node: true` 和 `type: '2d'`。

与 Web Canvas 的主要差异：

- 不能使用 `document.createElement('canvas')`，应在 WXML 中使用 `<canvas>`
- 通过 SelectorQuery 而非 `getElementById` 获得 Canvas node
- Canvas 的 `canvas.width` / `canvas.height` 使用设备像素设置
- Canvas node 支持 `requestAnimationFrame`

## WebAssembly

MoonBit 可编译为带 GC 的 WebAssembly（wasm-gc）。仓库的微信构建辅助脚本当前
输出兼容 WXWebAssembly 的 `wasm`，并使用 `WebAssembly.instantiate()` 在小程序
JavaScript runtime 中加载。

注意事项：

- wasm 模块必须和小程序代码一起打包
- 主包大小限制为 2MB
- 内存由 `WebAssembly.Memory` 分配
- 必须为所有外部函数提供 imports

## 触摸事件

触摸事件是主要输入方式，小程序提供：

- `bindtouchstart`：手指触摸 Canvas
- `bindtouchmove`：手指在 Canvas 上移动
- `bindtouchend`：手指离开 Canvas

它们会转换为 MoUI `PointerEvent`：

- `TouchStart` → `PointerDown`（button=Primary）
- `TouchMove` → `PointerMove`（button=None）
- `TouchEnd` → `PointerUp`（button=Primary）

## 生命周期

小程序生命周期由 App 和 Page hooks 管理：

```text
App.onLaunch → MoUI runtime 初始化
App.onShow   → 恢复回调槽
App.onHide   → 暂停回调槽
Page.onLoad  → Page 设置
Page.onReady → Canvas 就绪
Page.onHide  → Page 隐藏
Page.onUnload→ Surface 销毁回调槽
```

在真实设备运行时证据验证完整契约之前，生命周期和 Surface 回调仍属于
`runtime_partial` 范围。

## 性能

Skyline Canvas 2D 的性能建议：

- 使用 `canvas.requestAnimationFrame` 调度帧
- 减少 Canvas 状态变更（save/restore）
- 尽可能批量执行 Canvas 操作
- 使用离屏 Canvas 做图层合成
- 避免不必要的 clear 操作

## 开发

1. 打开微信开发者工具
2. 导入 `_build/wechat/<app>/` 中的项目
3. 在 `project.config.json` 设置 AppID
4. 在项目设置中启用 Skyline
5. 点击“编译”预览
6. 使用“预览”在真实设备上测试

## 故障排查

| 问题 | 解决方法 |
|------|----------|
| Canvas 未渲染 | 检查 `app.json` 是否启用了 Skyline |
| Wasm 未加载 | 确认 wasm 文件位于 `moui/` 目录 |
| 触摸无效 | 确认 Canvas 有 bindtouchstart/bindtouchmove/bindtouchend |
| 构建失败 | 检查 MoonBit toolchain 是否具备 wasm / wasm-gc target 支持 |
| 包过大 | 优化 wasm 模块大小，使用代码分割 |
