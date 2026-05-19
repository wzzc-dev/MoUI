# Platform Notes

## Local Window Dependency

MoUI expects the modified `Milky2018/window` checkout under `.local_repos/window`.
The README shows the setup commands. The local branch currently supplies target
support that the upstream package does not yet cover for MoUI.

## Shared Host Contract

Platform backends normalize window, input, surface, focus, text input, redraw,
and close events through `backend/host`. App code receives the same core event
model regardless of whether the host is Web, macOS, or Windows.

The boundary is:

```text
platform window event -> HostEvent -> AppRuntime -> DrawCommand -> renderer
```

Backends should keep platform details at the edge:

- Surface metrics carry logical size, physical size, and scale factor.
- Pointer coordinates are normalized before they reach `core`.
- Keyboard modifiers and IME events are converted into shared core input types.
- Redraw scheduling is owned by `HostRuntimeDriver`; hosts request redraws, but
do not mutate the element tree directly.
- Renderers consume `DrawCommand` values and remain separate from view
constructors and platform event conversion.

## Web Wasm-GC

The Web path is the canonical browser target: `wasm-gc + window/web + browser
WebGPU host imports`. It requires browser WebGPU. Startup fails clearly if
`navigator.gpu`, an adapter, or a device is unavailable. There is no JS-target
fallback branch. Browser font APIs may be used to populate hidden glyph atlas
bitmaps, but visible text composition is performed by WebGPU.

The reusable browser runtime assets live under `backend/web/*.js`. Each
`examples/*/web_wasm/` package is only the app-specific Web entrypoint and
supplies the example-specific wasm URL. The canvas host reports logical event
coordinates after DPR mapping and avoids CSS transforms, borders, and padding so
resize and input coordinates stay stable.

## macOS Native

The macOS host uses `Milky2018/window/macos` for AppKit windows and installs a
`CAMetalLayer` on the window `NSView` for the native `render/wgpu` renderer.
Window events pass through the shared `backend/host` conversion helpers, and the
native host owns only AppKit window lifetime, CAMetalLayer surface creation,
text-input session synchronization, renderer resize, and redraw requests.

Packages that use `backend/macos` must link the macOS frameworks required by
the Objective-C stubs during the final native link step. Missing symbols such
as `_OBJC_CLASS_$_CAMetalLayer`, `_objc_msgSend`, or
`___CFConstantStringClassReference` usually mean that link step is missing
framework/runtime flags such as:

```moonbit
link: {
  "native": {
    "cc-link-flags": "-framework AppKit -framework QuartzCore -framework Foundation -framework CoreFoundation -lobjc"
  },
},
```

Use `moon run <package> --target native --dry-run -v` to inspect the final
`cc` command and confirm the expected flags are present. If `moon build` works
but `moon run` links a temporary native stub dylib without those flags, use the
README build-and-execute flow while debugging the toolchain/link configuration.

## Windows Native

Windows native examples are built with MSYS2 UCRT64 and the static Windows GNU
`wgpu-native` release expected by `scripts/windows/counter_windows_static.ps1`.
The Windows host follows the same `HostEvent` and `HostRuntimeDriver` path as
macOS, with platform-specific ownership limited to Win32 window handles, WGPU
surface creation, resize handling, text-input session synchronization, and redraw
requests.

The expected archive extraction path is:

```text
.local_deps\wgpu-native\v27.0.4.0\wgpu-windows-x86_64-gnu-release
```

Download the archive from:

```text
https://github.com/gfx-rs/wgpu-native/releases/tag/v27.0.4.0
```

## Linux Scaffold

`backend/linux` intentionally preserves the host contract shape while reporting
that no Linux window backend is available yet. Its capability matrix currently
marks window, renderer, pointer, keyboard, text input, IME, clipboard,
accessibility, and scale-factor support as unavailable. Keep the scaffold honest
until a real `window/linux` package and native renderer surface path exist.

## Platform Validation

Use focused platform validation instead of broad all-repository native checks:

```sh
moon test backend/host --target native
moon test backend/web --target wasm-gc
sh scripts/dev-check.sh --platform-examples-test
```

Before release-style validation on a configured host, include platform example
builds:

```sh
sh scripts/dev-check.sh --platform-examples-build
```

When changing event conversion, also run the affected backend package tests. When
changing renderer surface creation or WGPU setup, build at least one native
example for the current platform.
