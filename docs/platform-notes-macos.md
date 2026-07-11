# macOS Platform Notes

The macOS host core uses `wzzc-dev/window/macos` for AppKit windows, lifecycle,
events, services, text-input session synchronization, renderer resize calls, and
redraw requests. It receives concrete rendering through
`MacosRendererProvider`; `backend/macos/skia` is the recommended native
mainline and presents CPU pixel frames through an `NSImageView`, while
`backend/macos/wgpu` installs a `CAMetalLayer` on the window `NSView` for
native WGPU diagnostics.
macOS native WebView support uses `WKWebView` as a host platform view attached
to the window content view. `backend/macos` reports native WebView available
when the WebKit-backed stub is linked, syncs placements from
`DrawFrame.platform_views`, forwards WebView navigation/title/history/script
events through `HostEvent::WebView`, and drains `HostWebViewCommandQueue`
commands after frame rendering.
Window events pass through the shared `backend/host` conversion helpers, and the
native host never imports `render/wgpu`, `render/skia`, `wgpu_mbt`, or
`moui_skia`.
The macOS service bridge routes text clipboard requests through `NSPasteboard`,
opens URLs through `NSWorkspace`, presents open/save/directory dialogs through
`NSOpenPanel` and `NSSavePanel`, presents command menus at the current pointer
position through `NSMenu`, reads/writes UTF-8 text files through the shared
text-file service contract, and reports the effective light/dark system
appearance through the shared `HostServiceBridge` contract.
The native app entrypoint applies that reported appearance to the runtime
environment before creating the host driver, so components see the system color
scheme on their initial build. AppKit theme-change events use the shared
`HostEvent::ThemeChanged` runtime path when emitted by the local window backend.
Right-click context-menu requests use the same `NSMenu` path and dispatch the
selected `ActionCommand` back through `HostRuntimeDriver`.
File drag/drop events emitted by the local `window/macos` backend are normalized
through `HostEvent::DragDrop` and dispatched to `View::on_file_drop`
targets.
Native WGPU diagnostics can use either the shared Moon Cosmic provider or a platform
provider. `backend/macos/wgpu` defaults to the CoreText/CoreGraphics provider
for runtime measurement and glyph rasterization, explicitly composed with the
Moon Cosmic provider as fallback; the Objective-C CoreText stub lives in
`render/wgpu/coretext`, while the selectable/composed Cosmic provider lives in
`render/wgpu/cosmic_text`. The CoreText provider consumes the shared native
`FontSpec` payload, attempts named families from the structured family stack,
maps generic CSS families such as `ui-monospace` and `serif` to suitable macOS
fonts, registers app-provided font bytes under their requested family alias when
CoreText accepts them, and falls back to the system font for unavailable names
before the renderer tries the composed Cosmic fallback.
Choose the text engine with
`@macos_wgpu.run_app_with_options(..., options=MacosWgpuAppOptions::new(text_engine=...))`.
The same options value can carry a `HostWindowSceneResolver` for
resolver-backed secondary windows and `first_frame_smoke_auto_exit` for first-frame
smoke tests. `core` still owns only the neutral `FontSpec`, `TextSystem`
contract, and deterministic fallback text system; it does not name concrete
macOS font files.
The `examples/showcase/macos_wgpu` and `examples/showcase/macos_wgpu_cosmic` entrypoints
remain WGPU diagnostics; `macos_wgpu_cosmic` selects `MoonCosmic` explicitly for
comparison with the WGPU CoreText path.
`backend/macos` also exposes an async pump variant for native app entrypoints
that must run `moonbitlang/async` side work on the same thread as the AppKit
event pump. `backend/macos/skia.run_app_with_options_async_pump` keeps the
default blocking `run_app_with_options` behavior unchanged, but lets
`examples/mo_workbench/macos_skia` interleave the Skia window pump with its
owned Pi JSONL transport worker.

Select the native mainline Skia provider by importing
`wzzc-dev/moui/backend/macos/skia` and using `MacosSkiaAppOptions`. The
provider creates `render/skia.SkiaRasterRenderer`,
draws into a CPU raster surface in physical pixels, scales the canvas by the
host scale factor, reads premultiplied pixels back after each frame, and sends
them to a macOS presenter. The Objective-C presenter builds a `CGImage` from the
pixel bytes and installs it on a dedicated `NSImageView` attached to the content
view. macOS Skia options default to the same system `FontMgr` text path as the
Windows and Linux Skia providers; tester-owned first-frame smoke entrypoints
explicitly select `EmptyTypeface`. This path is intentionally separate from the experimental
`backend/macos/wgpu`; Skia is a provider package, not a host-core
`NativeRenderer` variant.
For local real Skia configuration, direct `moon run`/`moon build` commands use
the `moui_skia` prebuild hook and `MOUI_SKIA_LINK_MODE=dynamic|static|auto` to
choose the Skia library mode. Helper smoke runs can pass
`--link-mode dynamic|static|auto` to override the environment for that
invocation.
`macos_skia_provider_preflight_summary()` exposes package-level preflight
observation for the selected font resolution, renderer availability,
`moui_skia/native` availability, the `NSImageView` presenter path, inherited
AppKit host service/input/window readiness, explicit
`HostWindowRenderer` bridge forwarding for Skia text-system, image-resource,
image-resource change callbacks, present-count, and disposal diagnostics,
clipboard/menu/file-dialog/open URL/system-theme/async-service readiness,
native context-menu and host-modal file-dialog readiness, native accessibility
status, and the runtime observation boundary. Treat that summary as
provider/package observation
only; MoUI macOS Skia runtime smoke still comes from the real Skia renderer
pixel smoke plus tester-owned first-frame/IME markers. Markdown Editor build
coverage remains optional example coverage and is not a platform runtime
observation gate.
The macOS host loop records the renderer image-resource revision after each
present, routes later observed revision changes through the matching window's
`request_redraw`, exposes tracked-window revision snapshots for diagnostics,
calls the optional provider-owned `HostAsyncImageLoader` after the presented
revision is baselined, and removes tracked image revisions plus in-flight image
loads when a host window is disposed. The macOS Skia provider creates
renderers with post-present async image loading so local/data URI image sources
can be baselined as loading, completed through `skia_image_load_completion`,
and repainted on a second frame; the real Skia smoke records that as a
matching-host artifact only when the async second-frame marker is present.

## Link Flags

Packages that use `backend/macos` directly must link the AppKit service bridge
frameworks during the final native link step. Missing `_objc_msgSend` or
`___CFConstantStringClassReference` usually means that link step is missing the
host-core flags:

```moonbit
link: {
  "native": {
    "cc-link-flags": "-framework AppKit -framework QuartzCore -framework UniformTypeIdentifiers -lz"
  },
},
```

Packages that use `backend/macos/wgpu` also need QuartzCore, CoreText,
CoreGraphics, Foundation, CoreFoundation, and Objective-C flags for the WGPU
surface and native text provider. Missing `CAMetalLayer` or CoreText raster
symbols mean the provider flags are absent from the final link:

```moonbit
link: {
  "native": {
    "cc-link-flags": "-framework AppKit -framework QuartzCore -framework UniformTypeIdentifiers -framework CoreText -framework CoreGraphics -framework Foundation -framework CoreFoundation -lobjc -lz"
  },
},
```

Use `moon run <package> --target native --dry-run -v` to inspect the final
`cc` command and confirm the expected flags are present. If `moon build` works
but `moon run` links a temporary native stub dylib without those flags, use the
README build-and-execute flow while debugging the toolchain/link configuration.
