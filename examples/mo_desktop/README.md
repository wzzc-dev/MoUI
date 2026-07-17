# Mo Desktop

Mo Desktop is a platform-neutral desktop simulation built with MoUI. The shared
app owns the lock screen, menu bar, dock, Finder, Safari, launcher, Control
Center, notifications, light/dark appearance, and responsive layout.

```sh
moon test examples/mo_desktop/app --target native
moon build examples/mo_desktop/web_wasm --target wasm-gc
moon run examples/mo_desktop/macos_skia --target native
```

The local demo wallpaper is sourced from
[Unsplash](https://images.unsplash.com/photo-1470770841072-f978cf4d019e)
and is used under the Unsplash License.
