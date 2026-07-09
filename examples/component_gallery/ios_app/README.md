# Component Gallery iOS Shell

This directory contains the minimal UIKit host used by
`scripts/build-component-gallery-ios-app.sh`. The shell owns `UIApplicationDelegate`,
`UIViewController`, layout, lifecycle, and touch forwarding. MoUI receives only
the raw `UIView` handle, resize events, pointer events, render requests, and
detach.

The current route is an experimental iOS Simulator scaffold. A fallback build
proves packaging only; non-fallback first-frame, tap, resize, and lifecycle
evidence must be recorded before iOS runtime support is claimed as passed.
