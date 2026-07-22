# WeChat Mini Program Support

WeChat Mini Program support is a **runtime_partial** Canvas 2D WebAssembly
route. Unlike Android, iOS, and HarmonyOS, it does not use the native mobile
`window` event loop: the Mini Program template calls the canvas host callbacks
directly. It is usable for development and demos, but is **not**
product-complete until real Mini Program pixel smoke, touch-event verification,
and wx API service integrations close remaining gaps.

The Skyline rendering engine provides enhanced Canvas 2D performance in the
Mini Program environment. MoonBit packages support `wasm` and `wasm-gc`; the
repository build helper currently targets `wasm` for WXWebAssembly and lowers
unsupported features before staging the template. Rendering is dispatched
through the CanvasRenderingContext2D API.

## Ownership

- `moui/backend/wechat` exposes the canvas host callbacks, owns the canvas
  surface host, and provides the `run_app` entry point for Mini Program
  applications.
- `moui/backend/wechat/canvas` wraps `moui/render/canvas2d` and creates
  `HostWindowRenderer` instances backed by the Canvas 2D API.
- `moui/render/canvas2d` implements the Canvas 2D renderer producing
  `HostWindowRenderer` closures with wasm-gc FFI imports to the JS runtime.
- `window/wechat/template` owns the Mini Program project template and its JS
  bridge to the exported MoonBit callbacks.
- `scripts/build-wechat-demo.sh` is the canonical build script for demo
  applications.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  WeChat Mini Program (Skyline Engine)            │
│  ┌───────────┐  ┌─────────────┐  ┌───────────┐ │
│  │ WXML      │  │ WXSS        │  │ JS Logic  │ │
│  │ Canvas 2D │  │ Styles      │  │ Runtime   │ │
│  └─────┬─────┘  └─────────────┘  └─────┬─────┘ │
│        │                                │       │
│        │  CanvasRenderingContext2D       │       │
│        │  (touch events)                │       │
│        │                                │       │
│  ┌─────▼────────────────────────────────▼─────┐ │
│  │         MoonBit WebAssembly Module          │ │
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

## Renderer

The Canvas 2D renderer uses the following approach:

- **Backend**: `canvas2d-wasm` (RendererBackendKind::Canvas2DWasm)
- **Family**: `canvas2d` (RendererFamily::Canvas2D)
- **Target**: `wasm` in the template build; package support also includes
  `wasm-gc`
- **Presentation**: WebCanvas (CanvasRenderingContext2D API)

DrawCommands are mapped to Canvas 2D API calls:
- Rect/FillRect → `fillRect`, `strokeRect`
- RoundedRect → path-based rounded rect + `fill`/`stroke`
- Text → `fillText` with `measureText` for layout
- Image → `drawImage`
- Clip → `save`/`restore` + `clip`
- Transform → `setTransform`, `translate`, `rotate`, `scale`
- Opacity → `globalAlpha`
- Path → `beginPath`/`moveTo`/`lineTo`/`arc`/`bezierCurveTo` + `fill`/`stroke`
- Gradient → `createLinearGradient`/`createRadialGradient`
- Shadow → `shadowBlur`/`shadowColor`/`shadowOffsetX`/`shadowOffsetY`
- BlendMode → `globalCompositeOperation`
- Filter → `filter` property (blur, saturate, brightness, contrast)
- LayerCompositing → offscreen canvases

## Input

The Mini Program provides touch events through the Canvas element:
- **TouchStart** → `PointerDown`
- **TouchMove** → `PointerMove`
- **TouchEnd** → `PointerUp`

Keyboard and IME are not available in the Mini Program canvas environment.

## Lifecycle

The Mini Program template owns the App and Page lifecycle. The backend exports
surface and lifecycle callback slots; they remain partial until device evidence
proves the complete lifecycle contract:
- `App.onLaunch` → runtime initialization
- `App.onShow` → `handle_resumed()`
- `App.onHide` → `handle_suspended()`
- `Page.onUnload` → `destroy_surfaces()`

## Build

```sh
# Build the counter demo
sh scripts/build-wechat-demo.sh counter

# Build the showcase demo
sh scripts/build-wechat-demo.sh showcase
```

Build output is placed in `_build/wechat/<app>/` and is ready to be imported
into WeChat Developer Tools.

## Prerequisites

- WeChat Mini Program base library 3.0+ (Skyline rendering engine)
- WebAssembly support (base library 2.15+)
- WeChat Developer Tools (latest stable)
- MoonBit toolchain with wasm-gc target support

## Service Capabilities

Services are provided through wx API calls bridged from the wasm module:

| Capability  | Status     | Notes                                      |
|-------------|-----------|--------------------------------------------|
| Clipboard   | Gap       | wx.getClipboardData / wx.setClipboardData  |
| File Dialog | Gap       | Not available in Mini Program              |
| System Theme| Gap       | wx.getSystemInfo theme detection           |
| Open URL    | Gap       | wx.navigateToMiniProgram / web-view        |

## Limitations

1. **No DOM access**: All rendering is through Canvas 2D only
2. **No keyboard/IME**: Mini Program Canvas doesn't support text input
3. **No drag-drop**: Not available in Mini Program environment
4. **No multi-window**: Mini Program is single-page by design
5. **No file dialogs**: Mini Program file system is sandboxed
6. **Skyline required**: Base library 3.0+ with Skyline rendering engine
7. **Package size**: wasm-gc module must fit within Mini Program size limits (2MB for code package)

## Evidence

Platform evidence is tracked in `checks/platforms/wechat.json`. Current status:
- **Renderer**: partial (compiles, no real Mini Program pixel smoke)
- **Host**: ready (window-hosted, lifecycle events)
- **Input**: partial (touch events, no keyboard/IME)
- **Services**: gap (wx API integration pending)
