# MoUI Studio

MoUI Studio is **MoUI's IDE**: a bilingual (zh-Hans / English) visual programming
environment for people who want real software and for teachers who want to explain
what a block actually does. It targets both geeks and beginners, with a
technical-looking shell: dark engineering panels, hairline dividers, mono-first
toolchain output, a grid canvas, and a terminal-style console.

- Source: `examples/moui_studio` (module + `moon.work` member)
- Entrypoints: Web (`web_wasm`) and macOS (`macos_skia`)
- Project format: `moui.studio.project` v1 (`.studio.json`), the only format —
  files from earlier product generations are rejected with a structured error,
  never read or migrated
- Language: `domain/studio_lang` keywords render in zh-Hans or en-US over one
  canonical IR

## One program, three same-source views

A single statement-level IR (`domain/ir`) backs every editing surface. There is
no second source of truth:

| View | What you edit | Backed by |
|---|---|---|
| Design | Controls on a form canvas (drag, resize, snap to grid/guides) | IR `controls` |
| Blocks | Puzzle-shaped typed blocks with same-level drag reorder | IR statement projection (`domain/blocks`) |
| Code | Bilingual text with `如果…则…结束` ↔ `if…then…end` | IR rendering (`domain/studio_lang`) |

Editing anywhere writes back to the IR and refreshes the other views. Round-trip
consistency is a hard gate:
`parse(render_zh(ir)) == ir == parse(render_en(ir))`.

## Two execution tracks

| | Interpret track | Compile track |
|---|---|---|
| Semantics | `domain/studio_lang` instruction machine runs the IR directly | IR → readable MoonBit source → real `moon check` / `moon build` |
| Execution | Sandboxed: 100_000 step budget, submit-data confirmation gate, audit log | `app/generated_handlers.mbt` executed by the `compiled_runtime` surface |
| Platforms | native + Web (wasm-gc) | native only |
| Run state | `RunModel` (single-step, spotlight, variables table) | `CompiledRun` (independent of the interpret track) |
| Availability | always | `compile_track_available=false` on Web, shown explicitly as `app.track.unavailable_web` |

**The two tracks are independent.** Switching tracks does not carry run state
across, does not silently fall back, and does not implicitly compile.

### Compile track: real build, no silent fallback

The compile track runs the toolchain for real:

1. Export the project IR into a bundle (`services/export`), where the readable
   MoonBit handler source lands in `app/generated_handlers.mbt`.
2. Load the gitignored bundle project and run `moon update`.
3. Run `moon check --target native`.
4. Build `--target wasm-gc` and `--target native`.
5. Launch the native smoke artifact and require it to stay alive.

The MoonBit preview shown in the Code view is byte-for-byte the same text that
participates in compilation — not a parallel display path (locked by tests).

Failures are never silent. `moon check`/`moon build` diagnostics are parsed into
structured errors (file, line, column, error code), localized through
`moui_i18n`, rendered back into the code and run views, and clickable: a
diagnostic jumps back to the IR statement (block or control) that produced it.
The compile track offers no single-step (the artifact is native execution) and
never falls back to the interpret track without telling you.

Exporting a standalone app follows the same "never pretend" rule: it needs a
native directory picker plus real disk writes, so `export_available` is true
only on the macOS entry. On the web entry, choosing "Export app" states the
limitation explicitly (`app.export.unavailable_web`) instead of opening a
directory dialog that cannot write. Every user-facing failure path — save,
open, export, budget limits, parse errors — reports through one
`with_notice` funnel that also raises a visible toast.

### Interpret track: sandbox and gate

The instruction machine enforces a 100_000 step budget, keeps a teaching-grade
audit log (one human-readable line per step), supports single-step execution and
statement spotlighting, and pauses on the `提交数据` (`submit_data`) gate: the v1
gate is a simulated action that only writes to the audit log and shows a
confirmation card. No real network request is made, on either platform.

## Dual-track differential gate

`services/diff` is a hard gate, not a report. It runs the four built-in samples
(plus one synthetic handler per statement class) through both tracks, rendering
to zh-Hans and en-US first, and asserts item by item:

- final control text
- final variable values (excluding the interpret track's internal `@iN` counter
  slots)
- the complete audit sequence `(line, op, detail)`
- gate state and gate `(kind, prompt, payload)`
- terminal status and, on failure, error type and line

Any mismatch is a P0 defect. There is no "known differences" allow-list. The
gate is registered in the `pr` profile as `studio diff matrix tests`.

## Look and feel

- `studio_theme()` pins Dark with IDE blue (`#3574F0`) as the only accent color;
  graphite surfaces, hairline outlines, and a tight radius scale
  (`sm 2 / md 4 / lg 6`). Semantic status colors (gate/error dots) stay
  independent of the accent.
- Canvas: stage plate, dot grid, alignment guides and selection handles read from
  the same palette.
- Console and generated-code previews use the Mono role; compile reports are
  terminal-style.
- Keyboard: `Cmd+K` / `Ctrl+K` opens the filterable command palette
  (30 Studio commands), `Cmd+Z` / `Ctrl+Z` undo and `Cmd+Shift+Z` /
  `Ctrl+Shift+Z` redo — every shortcut registers both the macOS (`meta`) and
  Windows/Linux (`control`) modifier, because `KeyboardShortcut::matches`
  compares modifiers for exact equality. The top bar carries undo/redo buttons
  with the same shortcuts. Icon-bar buttons are textless, so hovering one writes
  its name into the status bar (the framework's `Tooltip` semantic role has no
  visual overlay yet; a portal-based tooltip would be a framework addition).
- Composition uses existing `moui/views` controls only — no new built-in controls
  and no new core view enum variants.

## Readable AI proposals

AI never writes arbitrary code. It produces a versioned, structured IR proposal
with a bilingual `note` per handler, self-explanatory names (rejecting `a1`/`tmp`
style names), a field-level diff preview, and an "explain this program" narration
per statement. The proposal is validated (schema → IR invariants → bilingual
parser → budgets → readability) and must be accepted before it touches the IR.

This makes the proposal teachable: the classroom can show the diff, run it,
inspect the audit, and then graduate to the compiled MoonBit source.

## Market positioning

| Competitor | What it is good at | What MoUI Studio takes / rejects |
|---|---|---|
| Lovable | Natural language to a deployable app | Takes "describe it and get a product"; rejects "generate arbitrary code and run it" — AI only produces structured IR proposals with diffs |
| Figma | Canvas, snapping, component editing craft | Takes canvas/snap/guide/inspector discipline; rejects stopping at a design file — every control is also a program declaration |
| FlutterFlow | Visual building plus real code export | Takes the "visual → real code → real artifact" graduation channel; rejects preview-only text — the build is the acceptance test here |
| Power Apps | Form-style business apps and data flows | Takes domain modeling and event-driven handlers; rejects hosted lock-in — artifacts are standalone, offline-buildable MoUI projects |

The fixed three-sentence differentiator:

1. Three views over one IR — design, blocks, and code consume the same
   statement-level program; editing any of them cannot fork it.
2. Readable, explainable AI proposals — the model writes structured IR with
   bilingual intent notes and field-level diffs, and narrates it line by line.
3. A graduation channel that really compiles — the IR lowers to readable MoonBit
   and runs the real `moon check` / `moon build` toolchain for native and
   wasm-gc artifacts.

## Build and run

```sh
# Web (wasm-gc)
moon build examples/moui_studio/web_wasm --target wasm-gc

# macOS native
moon run examples/moui_studio/macos_skia --target native

# Tests
moon test examples/moui_studio/app --target native
moon test examples/moui_studio/app --target wasm-gc
```

See `examples/moui_studio/README.md` for the full verification loop and
`docs/plans/active/moui-studio.md` for the acceptance matrix.
