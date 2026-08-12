# macOS Platform Notes

The macOS host core uses `wzzc-dev/window/macos` for AppKit windows, lifecycle,
events, services, text-input session synchronization, renderer resize calls, and
redraw requests. It creates an opaque `HostSurface` with an `NSImageView` CPU
presenter, opaque native surface/display handles, and a `HostImageSource`. The
application supplies ordered providers from
`moui_skia_renderer`, `moui_sun_renderer`, or `moui_wgpu_renderer`; `backend/macos` never imports or
constructs those renderers.
macOS native WebView support uses `WKWebView` as a host platform view attached
to the window content view. `backend/macos` reports native WebView available
when the WebKit-backed stub is linked, syncs placements from
`DrawFrame.platform_views`, forwards WebView navigation/title/history/script
events through `Event::WebView`, and drains `HostWebViewCommandQueue`
commands after frame rendering.
Window events pass through the shared `backend` conversion helpers, and the
native host never imports `moui_wgpu_renderer`, `moui_skia_renderer`, `wgpu_mbt`, or
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
`Event::ThemeChanged` runtime path when emitted by the local window backend.
Right-click context-menu requests use the same `NSMenu` path and dispatch the
selected `ActionCommand` back through `HostRuntimeDriver`.
File drag/drop events emitted by the local `window/macos` backend are normalized
through `Event::DragDrop` and dispatched to `View::on_file_drop`
targets.
Native WGPU diagnostics can use either the shared Moon Cosmic provider or a platform
provider. `moui_wgpu_renderer` defaults to the CoreText/CoreGraphics provider
for runtime measurement and glyph rasterization, explicitly composed with the
Moon Cosmic provider as fallback; the Objective-C CoreText stub lives in
`moui_wgpu_renderer/coretext`, while the selectable/composed Cosmic provider lives in
`moui_wgpu_renderer/cosmic_text`. The CoreText provider consumes the shared native
`FontSpec` payload, attempts named families from the structured family stack,
maps generic CSS families such as `ui-monospace` and `serif` to suitable macOS
fonts, registers app-provided font bytes under their requested family alias when
CoreText accepts them, and falls back to the system font for unavailable names
before the renderer tries the composed Cosmic fallback.
Choose the text engine with `@wgpu_renderer.native(text_engine=...)`, then
compose it with `@macos_host.entry(options=...)`. Host options can carry a
`WindowSceneResolver`; renderer options stay captured by the provider.
`core` still owns only the neutral `FontSpec`, `TextSystem`
contract, and deterministic fallback text system; it does not name concrete
macOS font files.
The canonical `examples/showcase/macos_wgpu` entrypoint remains a WGPU
diagnostic; it selects CoreText with Moon Cosmic as the internal fallback.
`AppBuilder::run_async_pump` uses the optional async launch closure exposed by
`backend/macos` for native app entrypoints that must run `moonbitlang/async`
side work on the same thread as the AppKit event pump. It lets
`examples/mo_workbench/macos_skia` interleave the Skia window pump with its
owned Pi JSONL transport worker.

Select the native mainline Skia renderer by importing
`wzzc-dev/moui_skia_renderer`, adding
`@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS)` to the app
builder, and capturing `MacosHostAppOptions` in `@macos.entry`. The provider
binds a per-window `RendererSession` backed by `@render_skia.SkiaRasterRenderer`,
draws into a CPU raster surface in physical pixels, scales the canvas by the
host scale factor, reads premultiplied pixels back after each frame, and sends
them to a macOS presenter. The Objective-C presenter builds a `CGImage` from the
pixel bytes and installs it on a dedicated `NSImageView` attached to the content
view. macOS Skia options default to the same system `FontMgr` text path as the
Windows and Linux Skia providers; tester-owned first-frame smoke entrypoints
explicitly select `EmptyTypeface`. This path is intentionally separate from the experimental
`moui_wgpu_renderer` factory; Skia is a renderer package, not a host-core
`NativeRenderer` variant.
For local real Skia configuration, direct `moon run`/`moon build` commands use
the `moui_skia` prebuild hook and `MOUI_SKIA_LINK_MODE=dynamic|static|auto` to
choose the Skia library mode. Helper smoke runs can pass
`--link-mode dynamic|static|auto` to override the environment for that
invocation.
The macOS host loop drains `RendererEvent` image requests, stores only
cancellable byte-I/O tasks in `backend/common/image`, and returns the same
opaque token to the selected session. Renderer sessions own format detection,
decoding, resource caches, and applied-completion diagnostics; the host keeps
no image revision or cache-residency mirror. Applied completions request the
matching window's redraw, while stale or disposed tokens are ignored. The real
Skia smoke records matching-host async second-frame evidence only when the
token completion and repaint markers are present.

## Link Flags

macOS host frameworks are injected by `moui/build.js` for
`wzzc-dev/moui/backend/macos`. Skia/Ganesh libraries and their required
frameworks are generated by `moui_skia/build.js` and used in two distinct
places: `moui_skia/native/moon.pkg` for binding-local tests, and the renderer's
final-application `link_configs` entry.

`moui_skia_renderer/build.js` reuses the binding's build variables and registers
the final-application entry once. The binding package flags do not propagate
through a renderer dependency to an `is-main` application, while registering
the renderer entry twice would append every static archive twice.

Example `macos_skia` entrypoints should not repeat AppKit/Metal/Skia paths.
They only need an empty `cc-link-flags` override so Moon disables `tcc -run`
and uses the system linker for the final binary:

```moonbit
link: {
  "native": {
    "cc-link-flags": "",
  },
},
```

The host and binding packages declare their own link flags for AppKit,
CoreText, WebKit, and Skia symbols. Missing `_objc_msgSend`,
`___CFConstantStringClassReference`, `CAMetalLayer`, or Skia Ganesh symbols
usually means the prebuild `link_configs` did not apply or `tcc -run` was not
disabled.

Use `moon run <package> --target native --dry-run -v` to inspect the final
`cc` command and confirm AppKit/Metal/Skia flags are present. If `moon build`
works but `moon run` fails with `tcc: error: file 'AppKit' not found`, the
entrypoint is missing the empty `cc-link-flags` override.
