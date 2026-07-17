# Plan: Mo Desktop Example

- **Status**: active
- **Goal**: Add a runnable `examples/mo_desktop` MoUI desktop simulation inspired by the macOS 27 reference, with shared TEA app logic and thin Web/macOS Skia entrypoints.
- **Non-goals**: Reimplement every reference app, add framework controls, or claim new renderer/platform capability.

## Acceptance

- [ ] The shared app provides a responsive lock screen and desktop shell.
- [ ] Finder, Safari, the app launcher, notifications, and Control Center have meaningful typed interactions.
- [ ] Light/dark appearance, Finder navigation/search/view mode, sliders, toggles, and window controls update through the model.
- [ ] Web wasm-gc and macOS Skia entrypoints remain thin runtime wiring.
- [ ] Focused native tests, Web build, native entrypoint build, static validators, and browser screenshots pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-07-17 | Use a shared `app` package plus `web_wasm` and `macos_skia` entrypoints. |
| 2026-07-17 | Reproduce the reference's primary workflows rather than create non-functional stubs for every dock app. |
| 2026-07-17 | Use an image asset for the wallpaper and MoUI views/canvas composition for all desktop chrome. |

## Progress

| Date | Note |
|------|------|
| 2026-07-17 | Reference lock screen, desktop, Finder, launcher, Control Center, dark mode, and Safari states captured and analyzed. |
