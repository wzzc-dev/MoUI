# Geometry facade flex aligns

- `@geometry` re-exports `MainAxisAlignment` and `CrossAxisAlignment` (plus Point/Size/Rect/…).
- True source remains `moui/core` (`view_style.mbt`). Views flex engine may keep `@core.*` internally.
- Apps/layouts should prefer `@geometry.MainAxisAlignment` / `@geometry.CrossAxisAlignment` when not using views `MainAlign`/`CrossAlign` sugar.
