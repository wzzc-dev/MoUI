# WeChat Mini Program (微信小程序) Platform Notes

## Overview

WeChat Mini Program support targets the Skyline rendering engine with
Canvas 2D rendering. MoonBit compiles to wasm-gc and runs in the Mini
Program's JavaScript logic layer.

## Skyline Engine

The Skyline rendering engine is WeChat's next-generation rendering
pipeline for Mini Programs. It provides:

- Enhanced Canvas 2D performance
- Better touch event handling
- Worklet-based animation support
- Improved rendering pipeline vs. WebView

Skyline requires base library 3.0+ and is enabled in `app.json`:
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

In Skyline mode, the Canvas 2D API is available through the `<canvas type="2d">`
element. The CanvasRenderingContext2D is obtained via `wx.createSelectorQuery()`
with `node: true` and `type: '2d'`.

Key differences from Web Canvas:
- No `document.createElement('canvas')` — use `<canvas>` in WXML
- Canvas node is obtained via SelectorQuery, not `getElementById`
- Canvas size is set via `canvas.width`/`canvas.height` in device pixels
- `requestAnimationFrame` is available on the canvas node

## wasm-gc

MoonBit compiles to wasm-gc (WebAssembly with Garbage Collection). The
.wasm file is loaded in the Mini Program's JavaScript runtime using
`WebAssembly.instantiate()`.

Key considerations:
- The wasm module must be bundled with the Mini Program code
- Package size limit: 2MB for the main code package
- Memory is allocated via `WebAssembly.Memory`
- Imports must be provided for all external functions

## Touch Events

Touch events are the primary input mechanism. The Mini Program provides:
- `bindtouchstart` — finger touches the canvas
- `bindtouchmove` — finger moves on the canvas
- `bindtouchend` — finger lifts from the canvas

These are converted to MoUI `PointerEvent` types:
- `TouchStart` → `PointerDown` (button=Primary)
- `TouchMove` → `PointerMove` (button=None)
- `TouchEnd` → `PointerUp` (button=Primary)

## Lifecycle

Mini Program lifecycle is managed through App and Page lifecycle hooks:

```
App.onLaunch → MoUI runtime initialization
App.onShow   → MoUI handle_resumed()
App.onHide   → MoUI handle_suspended()
Page.onLoad  → Page setup
Page.onReady → Canvas ready
Page.onHide  → Page hidden
Page.onUnload→ MoUI destroy_surfaces()
```

## Performance

Skyline Canvas 2D performance considerations:
- Use `canvas.requestAnimationFrame` for frame scheduling
- Minimize Canvas state changes (save/restore)
- Batch Canvas operations where possible
- Use offscreen canvases for layer compositing
- Avoid unnecessary clear operations

## Development

1. Open WeChat Developer Tools
2. Import the project from `build/wechat/<app>/`
3. Set your AppID in `project.config.json`
4. Enable Skyline in project settings
5. Click "Compile" to build and preview
6. Use "Preview" to test on a real device

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Canvas not rendering | Check that Skyline is enabled in app.json |
| Wasm not loading | Verify the wasm file is in the moui/ directory |
| Touch not working | Ensure canvas has bindtouchstart/bindtouchmove/bindtouchend |
| Build fails | Check MoonBit toolchain has wasm-gc target support |
| Package too large | Optimize wasm module size, use code splitting |