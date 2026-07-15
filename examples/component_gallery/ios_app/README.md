# Component Gallery iOS Shell

This directory contains the repository-only Xcode fixture for the Component
Gallery iOS route. The package-published `moui/mobile/ios` SwiftUI managed shell owns
scene/view lifecycle, the `CAMetalLayer` surface, UIKit host adapters, ABI
bridge, and native compilation. Managed builds stage the package-owned template
and read identity from `examples/component_gallery/mobile.json`; this project
exists for native target and explicit Release N compatibility validation.
App-specific symbols in `moui/mobile/build-contracts.json` apply only to that
legacy path.

The current route is an experimental iOS Simulator scaffold. A fallback build
proves packaging only; non-fallback first-frame, tap, resize, scroll, and
lifecycle evidence must be recorded before iOS runtime support is claimed as
passed.

Build with:

```sh
scripts/build-mobile-ios-app.sh --app component_gallery
```

Use `--fallback-skia` for packaging-only validation. The frozen Release N
UIKit fixture is available only through `--legacy-uikit-shell`.
