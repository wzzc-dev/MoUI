# Mo Desktop

Mo Desktop is a platform-neutral desktop simulation built with MoUI. The shared
app owns the lock screen, menu bar, dock, Finder, Safari, launcher, Control
Center, notifications, light/dark appearance, and responsive layout.

- Architecture deep dive: [ARCHITECTURE.md](ARCHITECTURE.md) — package boundary, window model, app registry, persistence, session flow, i18n, and theme mapping.

```sh
moon test examples/mo_desktop/app --target native
moon build examples/mo_desktop/web_wasm --target wasm-gc
moon run examples/mo_desktop/macos_skia --target native
```

The local demo wallpaper is sourced from
[Unsplash](https://images.unsplash.com/photo-1470770841072-f978cf4d019e)
and is used under the Unsplash License.

## Acknowledgements

Product behavior and interaction design — multi-window management, boot/lock/
login session flow, Dock and launcher conventions, Control Center, and the
glass chrome visual direction — are inspired by
[FluentOS-On-Web](https://github.com/YoYoPAN1115/FluentOS-On-Web) (MIT).
Mo Desktop is an independent MoonBit/MoUI implementation; no FluentOS source
code or binary assets are included.
