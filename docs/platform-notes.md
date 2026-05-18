# Platform Notes

## Local Window Dependency

MoUI expects the modified `Milky2018/window` checkout under `.local_repos/window`.
The README shows the setup commands. The local branch currently supplies target
support that the upstream package does not yet cover for MoUI.

## Web Wasm-GC

The Web path requires browser WebGPU. Startup fails clearly if `navigator.gpu`,
an adapter, or a device is unavailable. There is no JS-target fallback branch.
Browser font APIs may be used to populate hidden glyph atlas bitmaps, but
visible text composition is performed by WebGPU.

The reusable browser runtime assets live under `backend/web/*.js`. Each
`examples/*/web_wasm/` package is only the app-specific Web entrypoint and
supplies the example-specific wasm URL.

## macOS Native

The macOS host uses `Milky2018/window/macos` for AppKit windows and installs a
`CAMetalLayer` on the window `NSView` for the native `render/wgpu` renderer.

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
The expected archive extraction path is:

```text
.local_deps\wgpu-native\v27.0.4.0\wgpu-windows-x86_64-gnu-release
```

Download the archive from:

```text
https://github.com/gfx-rs/wgpu-native/releases/tag/v27.0.4.0
```
