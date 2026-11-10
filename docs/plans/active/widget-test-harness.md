# Plan: Shared widget-test harness for app package tests

- **Status**: active
- **Goal**: Give application package tests one shared, importable widget
  testing API instead of seven near-identical hand copies of
  `text_frame` / `has_text` / `click_text` (counter, file_importer, settings,
  mo_desktop, harmonyos_demo apps). The API lives in `moui_tests/tester` —
  the designated unpublished test-support module — so no production package
  surface grows and app packages keep importing it only `for "test"`.
- **Non-goals**: replacing `moui_tests/tester` smoke recording, semantics-tree
  assertion helpers (follow-up), golden image comparison, in-process hot
  reload, published-package API (publishing `moui_tests/tester` is a separate
  release decision).

## API shape

1. Drop-in free functions over `AppRuntime` / draw commands, replacing the
   duplicated copies verbatim:
   - `widget_text_frame(commands, text) -> Rect?`
   - `widget_has_text(commands, text) -> Bool`
   - `widget_tap_text(runtime, text) -> Unit raise` (tap the center of the
     first matching `DrawText` frame; raises `fail` when absent)
2. `WidgetHarness` struct for new-style tests: `from_program(program~,
   width~, height~)` plus `commands`, `text_frame`, `has_text`, `tap_text`,
   `tap_at`, and `dispatch` delegating to the runtime.

## Placement revision

The first draft put the harness in `moui_tests/tester`, but the
release-closure validator forbids versions on internal test modules and
`moui_tests` depends on example modules, so app packages can neither pin nor
reverse-import it (module cycle). The harness moved to
`wzzc-dev/moui/runtime/test_support` — the runtime naturally owns a test
driver over `AppRuntime`, the `moui` module already carries the version all
example modules pin, and the published base module gains a small, clearly
test-scoped package. `moui_tests/tester` stays the smoke recorder.

## Acceptance

- [x] `moui/runtime/test_support` exposes the harness with black-box tests
      over a local counter-style program.
- [x] All five app test suites (counter / file_importer / settings /
      mo_desktop / harmonyos_demo) delete their local copies and import
      `wzzc-dev/moui/runtime/test_support` `for "test"`; every suite passes.
- [x] `docs/testing.md` points app authors at the harness.
- [ ] `moon info` + committed tester `pkg.generated.mbti` diff;
      `validate-api-surface`, `validate-maintenance-baseline`,
      `validate-guidance-consistency`, `validate-doc-references` pass.
