# Excel Viewer

<div align="center">
  <img src="../../resource/screenshots/excel.png" width="600px" alt="Excel Viewer screenshot"/>
</div>

Excel Viewer renders MoonBit Excel workbooks with MoUI data table components.
It consumes `bobzhang/mbtexcel` workbooks, exposes a shell with a toolbar,
sheet tabs, cell grid, formula bar, status bar, context menu, and heat map
mode; cell selection, editing, and formula entry flow through a single
`Program[ExcelApp, ExcelMsg]`.

> Excel Viewer is on the `wzzc-dev/moui@0.1.10` workspace head.

## Package Shape

- `app/` — shared `ExcelApp` / `ExcelModel` / `ExcelMsg` shell plus
  `view_grid.mbt` (cell grid + editing), `view_formula_bar.mbt`,
  `view_tabs_status.mbt`, `view_toolbar.mbt`, `view_shell.mbt`.
- `cell/`, `sheet/`, `formula/`, `xlsx/` — domain subpackages: cell model,
  workbook model, formula evaluation, and xlsx load surface used by the
  `mbtexcel` adapter.
- `macos_skia/` — retained thin platform entrypoint.

## Dependencies

```toml
import {
  "wzzc-dev/moui@0.1.10",
  "bobzhang/mbtexcel@0.1.6",
}
```

## Running

```sh
# macOS Skia
moon run examples/excel/macos_skia --target native
```

A `windows_skia` entrypoint is not wired today; Web wasm-gc is reserved.

## Tests

```sh
moon test examples/excel/app --target native
```

The app package ships an `app_test.mbt` smoke covering the model, cell model,
sheet model, formula, and view layers.

## Platform Coverage

| Target               | Entrypoint   | Status      |
| -------------------- | ------------ | ----------- |
| macOS Skia           | `macos_skia` | Wired       |
| Linux Skia           | Showcase route | App root retired |
| Windows Skia         | reserved     | Not wired   |
| Web wasm-gc          | reserved     | Not wired   |
