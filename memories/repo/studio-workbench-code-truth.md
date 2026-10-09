# Studio workbench: code as source of truth

## Architecture (M5-M8, 2026-10-05)

- On-disk truth for imported projects = `form.mbt` + `handlers.mbt` in the
  first program package; both derive from one IR snapshot.
  `app/code_project.mbt`:`code_project_files` is the single generator;
  `@export.handler_function_name` is the only function-name source (form.mbt
  `on_click=` and handlers.mbt `fn studio_…` must agree).
- Template apply / proposal accept set `pending_code_project`; the composition
  root (`app.mbt` program() effect assembly) consumes it and writes both files.
  Confirm continuations run inside `update_pure`, so service interception would
  be bypassed — the flag pattern is mandatory for anything the confirm flow
  can trigger.
- `.studio.json` is legacy: opening one runs `migrate_studio_source` (decode →
  write code project → load IR); decode failures are structured errors naming
  the migrator. `DraftLoaded` (settings autosave) keeps direct decode.
- Code view defaults to MoonBit appearance (`CodeAppearance`,
  `CycleCodeAppearance`); edits/commits happen in the DSL appearance. The
  compiled track builds handlers from IR (`traced_from_stmts`), never from the
  display draft.

## Hard gates

- `parse(render_zh(ir)) == ir == parse(render_en(ir))` (check_round_trip).
- `parse∘gen == id` inverse-parser contract (services/blocks_code).
- Two-track diff matrix (services/diff) — audit sequences byte-identical.
- i18n catalog: `node scripts/generate-i18n-catalogs.mjs --input
  moui_studio/app/i18n/catalogs.json --out
  moui_studio/app/i18n_catalog_generated.mbt` (no args targets the
  WEBSITE manifest — wrong file).

## Known flake

`compile_native` progress test shells out to the real moon toolchain 6+ times;
under parallel load it can fail once (bundle unchanged, manual steps pass).
Guarded by a clean-and-retry-once in the test; a second failure is a real
regression.
