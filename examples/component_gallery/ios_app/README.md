# Component Gallery iOS Shell

This directory contains the minimal Xcode project for the Component Gallery iOS
route. The shared mobile iOS template owns the UIKit app shell and native
compilation; this directory supplies app metadata through `Info.plist`, the
Xcode project, and `examples/component_gallery/mobile.json`. Component
Gallery's repository compatibility native symbol and MoonBit C details live in
`moui/mobile/build-contracts.json`.

The current route is an experimental iOS Simulator scaffold. A fallback build
proves packaging only; non-fallback first-frame, tap, resize, scroll, and
lifecycle evidence must be recorded before iOS runtime support is claimed as
passed.

Build with:

```sh
scripts/build-mobile-ios-app.sh --app component_gallery
```
