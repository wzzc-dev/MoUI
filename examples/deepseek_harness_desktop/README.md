# DSH Desktop

`deepseek_harness_desktop` is a thin native MoUI window for DeepSeek Harness. DSH owns the
product UI and state; this example only embeds the local Harness surface in a
controlled `moui_webview` platform view and reports a clear fallback when the
native WebView is unavailable.

The retained app lives in `app/`; the macOS, Windows, and Linux entrypoints
only assemble their native WebView plugin, Skia renderer, and native host.

Run the native prototype on its matching desktop platform with:

```sh
moon run examples/deepseek_harness_desktop/macos_skia --target native
moon run examples/deepseek_harness_desktop/windows_skia --target native
moon run examples/deepseek_harness_desktop/linux_skia --target native
```

The default surface is `http://127.0.0.1:3080`, matching a local DSH host.
Start the Host before launching this composition root. The app does not
duplicate DSH navigation, sessions, profiles, settings, or terminal UI.

All three composition roots use the Skia provider route. `MOUI_SKIA_RENDERER`
selects `auto` (the default), `skia-gpu`, or `skia-raster`; auto prefers the
native GPU surface and falls back to Skia raster. Windows requires the WebView2
runtime and Linux requires the WebKitGTK native dependencies. When either
native WebView is unavailable, the app shows its capability fallback instead of
embedding a substitute surface.

Use `Settings…` in the standard macOS application menu, or press `Cmd+,`, to
change the DSH root URL. The native setting accepts trimmed `http://` and
`https://` URLs, persists the value through `NSUserDefaults`, and applies it
only after persistence succeeds. Saving the current URL only closes the dialog;
it does not reload the WebView. This setting chooses which DSH Web UI to load;
it is not a duplicate of DSH's own profile or API-endpoint settings.

On macOS, the settings dialog is a MoUI modal above the full-window WKWebView.
While it is open, the active Skia presenter moves above the WebView, uses a
transparent frame clear, and the WebView excludes the full overlay bounds from
hit testing. Skia auto mode tries the GPU surface first and falls back to the
CPU raster presenter when GPU setup is unavailable. Closing the dialog restores
the WebView as the front sibling and restores its input. This is a targeted
full-window WebView/modal composition path, not general interleaving of
arbitrary MoUI and native-view content.

The first 32 points of the WebView are also a drag/no-drag strip: blank space
moves the native window, while links, buttons, inputs, editable controls, and
elements marked `data-moui-no-drag` remain clickable. DSH can add that
attribute to any custom interactive control in its top bar.

After each DSH navigation completes, every native composition root reads and
executes [`patch.js`](patch.js). The patch increases the expanded sidebar's top
inset from 6px to 27px, uses 37px for the collapsed rail, widens the collapsed
rail from 55px to 80px, and centers its compact controls. The DSH grid column,
sidebar surface, and rail root are widened together, then restored on expand.
The macOS traffic lights themselves are not resized.
