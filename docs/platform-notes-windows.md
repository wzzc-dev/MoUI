# Windows Platform Notes

Windows native examples use the MSVC toolchain with Visual Studio C++ build
tools and vcpkg `zlib:x64-windows`. The Skia entrypoints are the recommended
native mainline. WGPU diagnostic entrypoints still use `wgpu_mbt` dynamic mode
with the official `wgpu-windows-x86_64-msvc-release.zip` release.
Windows native WebView support is auto-detected by the `moui_webview`
prebuild from the `.tools/webview2/` cache directory (set up by
`scripts/windows/setup_msvc_deps.ps1 -InstallWebView2`), matching how Linux
auto-detects WebKitGTK via `pkg-config`. Fallback builds compile without the
WebView2 SDK and report `HostWebViewCapabilities.available=false`; builds with
the SDK use WebView2 controllers parented to the app HWND, sync
`DrawFrame.platform_views`, forward controlled navigation and
title/history/script events, and drain `HostWebViewCommandQueue` commands after
renderer presentation. Override auto-detection by setting environment variables
such as `MOUI_WINDOWS_ENABLE_WEBVIEW2=1`,
`MOUI_WINDOWS_WEBVIEW2_INCLUDE=<webview2-sdk-include>`, and
`MOUI_WINDOWS_WEBVIEW2_LINK_FLAGS=\"<WebView2Loader link flags>\"`, or by setting
the explicit `MOUI_WINDOWS_WEBVIEW2_STUB_CC_FLAGS` /
`MOUI_WINDOWS_WEBVIEW2_CC_LINK_FLAGS` pair. The prebuild adds
`-DMOUI_WINDOWS_ENABLE_WEBVIEW2` when WebView2 flags are resolved.

## MSVC Setup

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -AppName MoUIShowcase
```

The MSVC helper imports `vcvarsall.bat` through `vswhere`, sets `CC` and `CXX`
to `cl.exe` on `PATH`, and applies shared `CL`/`LINK` flags for MoonBit native
stubs. It detects whether the selected package imports the WGPU
provider. Skia packages do not download or package `wgpu_native.dll`; WGPU
diagnostic packages set `MBT_WGPU_LINK_MODE=dynamic` and point
`MBT_WGPU_NATIVE_ROOT` at the extracted MSVC WGPU release. `moui_skia` emits
`/std:c++20` stub flags for its Windows Skia C++ bindings via the package
prebuild. Packaged MSVC apps use the vcpkg
`zlib:x64-windows` runtime for native image decoding. When the
Visual Studio-bundled vcpkg rejects direct classic installs, run
`setup_msvc_deps.ps1 -InstallZlib` so the dependency is installed with an
ignored repository-local manifest workspace under `.tools\\vcpkg-msvc`. Packaged
apps should be launched through the generated `run.cmd`; WGPU diagnostic
packages use that wrapper so the bundled WGPU release metadata is visible to
the dynamic loader.

To run an entrypoint directly after setup:

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }"
```

The ordinary Windows Skia entrypoints are interactive app entrypoints. Keep
matching-host first-frame smoke in tester/backend smoke runners rather than
adding auto-exit flags to Showcase or Markdown Editor packages.

## Host Architecture

The Windows host follows the same `HostEvent` and `HostRuntimeDriver` path as
macOS, with platform-specific ownership limited to Win32 window handles,
services, lifecycle, resize handling, text-input session synchronization, and
redraw requests. Concrete rendering is injected through
`WindowsRendererProvider`; `backend/windows/wgpu` owns HWND/HINSTANCE WGPU
surface creation for diagnostics and `backend/windows/skia` owns the GDI pixel
presenter for the native mainline. Text
clipboard requests are implemented through the Win32
`CF_UNICODETEXT` clipboard API and normalized to UTF-8 at the host-service
boundary. The Windows service bridge also opens URLs through `ShellExecuteW`,
presents basic open/save/directory dialogs through the Win32 common dialog and
shell APIs, presents command menus at the current cursor position through
`TrackPopupMenu`, reads/writes UTF-8 text files through the shared text-file
service contract, and reports light/dark system theme from the current user's
`AppsUseLightTheme` registry value.
The native app entrypoint applies that reported theme to the runtime environment
before creating the host driver, matching the macOS startup path. Windows
theme-change events use the shared `HostEvent::ThemeChanged` runtime path when
emitted by the local window backend.
Right-click context-menu requests use the same `TrackPopupMenu` path and dispatch
the selected `ActionCommand` back through `HostRuntimeDriver`.
File drag/drop events emitted by the local `window/windows` backend are
normalized through `HostEvent::DragDrop` and dispatched to
`View::on_file_drop` targets, matching the macOS host path.
`backend/windows/wgpu` remains the WGPU diagnostic path and installs the sibling
`render/wgpu/directwrite` provider
through the same renderer/runtime boundary used by macOS CoreText and composes
it with `render/wgpu/cosmic_text` as fallback. That provider is currently an
explicit scaffold using `render/wgpu/text_protocol` for UTF-32 input encoding,
private versioned measurement payload parsing, a versioned registration
payload, and a generic shaped-run envelope for glyph placements plus
DirectWrite-private raster payloads. It also routes raster glyph bytes through
the shared single-channel raster parser. Its native stub advertises the
DirectWrite integration point while returning no platform layout/raster data,
so the composed Cosmic fallback handles native text until the real DirectWrite
engine lands. Choose `MoonCosmic` with
`WindowsWgpuAppOptions::new(text_engine=...)`.
The `examples/showcase/windows_wgpu` and `examples/showcase/windows_wgpu_cosmic`
entrypoints remain WGPU diagnostics; `windows_wgpu_cosmic` selects `MoonCosmic`
explicitly for comparison with the WGPU DirectWrite scaffold plus Cosmic
fallback path. The `examples/showcase/windows_skia` entrypoint selects the
Windows Skia provider for the mainline Showcase, and
`examples/markdown_editor/windows_skia` selects it for the mainline editing
workflow.
The Markdown Editor also has `examples/markdown_editor/windows_wgpu_cosmic` for the
same explicit text-provider comparison on the editing workflow.

## Skia Provider

Select Skia by importing `wzzc-dev/moui/backend/windows/skia` and using
`WindowsSkiaAppOptions`. The provider creates `render/skia.SkiaRasterRenderer`
and presents the CPU pixel frame through the Win32 presenter. The C presenter
copies the RGBA premultiplied readback into a top-down 32-bit BGRA DIB buffer
and blits it to the client DC with `StretchDIBits`. If `moui_skia/native` is only
in fallback mode, renderer creation is rejected with a diagnostic instead of
opening an empty HWND.
`windows_skia_provider_preflight_summary()` exposes package-level preflight
observation for the selected font resolution, renderer availability,
`moui_skia/native` availability, the GDI presenter path, inherited Win32 host
service/input/window readiness, explicit clipboard/menu/file-dialog/open
URL/system-theme/async-service readiness, the `HostWindowRenderer` bridge that
forwards Skia text-system, image-resource, present-count, and disposal
diagnostics, native context-menu and host-modal
file-dialog readiness, native accessibility status, and the matching-host
runtime boundary, including whether the first-frame smoke option is enabled.
Treat that summary and its package test as provider/preflight diagnostic only;
The Windows host loop records the renderer image-resource revision after each
present, routes later observed revision changes through the matching HWND's
`request_redraw`, exposes tracked-window revision snapshots for diagnostics,
calls the optional provider-owned `HostAsyncImageLoader` after the presented
revision is baselined, and removes tracked image revisions plus in-flight image
loads when a host window is disposed. The Windows Skia provider creates
renderers with post-present async image loading, but the required async
second-frame artifact remains matching-host pending until a Windows/MSVC run
records it from the Skia entrypoints or provider smoke.
Passed Windows runtime observation still needs a Windows/MSVC host running the
Showcase or Markdown Editor Skia entrypoints with recorded artifacts. On
non-Windows hosts, the Win32 presenter and service stubs may fail C compilation
because they require `windows.h`, so a Darwin failure of
`moui/backend/windows/skia` is a host/toolchain limit rather than Windows
runtime observation.

To use a preseeded local `wgpu-native` release for WGPU diagnostics instead of
the helper-managed copy, set `MBT_WGPU_NATIVE_ROOT` to the extracted MSVC
release root or pass that path as `-WgpuNativeRoot` to the Windows helper
script. MSVC dynamic roots should contain `lib\\wgpu_native.dll` and
`wgpu-native-meta\\wgpu-native-git-tag`.
