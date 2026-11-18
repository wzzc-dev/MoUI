# tools/moui test ratchet

## Rule

Every package under `tools/moui` ships a `*_wbtest.mbt` suite. The ratchet is
`checks/tool-test-coverage.json` (`root: "tools/moui"`,
`maxUntestedPackages: 0`) checked by `tools/moui/validate_tool_test_coverage`
(entry point `node scripts/validate-tool-test-coverage.mjs`). It walks the
directory tree, counts packages with a `moon.pkg` and no `*_wbtest.mbt`, and
fails above the ceiling. `0` means one test file per package is the floor, not a
quality bar — the suite still has to assert decision logic (thresholds, path
matching, ordering, failure text), not `assert_true(true)`.

`pr-static` runs the whole tree in one step:
`moon -C tools test --target native`. `-C tools` is load-bearing: `tools/` has
its own `tools/moon.work` with `members = ["."]`, so the command scopes to the
`wzzc-dev/moui_tools` module. Running `moon test` from the repository root with
no paths instead walks the workspace and its nested modules (thousands of
tests), and a bare module path (`moon test moui_p5`) only runs the module's root
package — subpackages need explicit paths.

## Why

Before the ratchet, 30 of 44 tool packages (68% of the tool tree) had no test at
all; the governance layer that gates every other package was itself unverified.
A per-package step list had already drifted: removing one package silently
removed its coverage. One blanket command plus a count ceiling cannot drift.

## How to apply

- Adding a tool package: add the test file, and if it needs imports, add
  `import { ... } for "wbtest"` in `moon.pkg` (test helpers are builtins, so
  `moonbitlang/core/test` is not needed).
- New test files stay out of `checks/source-file-policy.json`; the 1200-line
  hard limit applies to them like any logic file.
- A shim in `scripts/validate-*.mjs` needs a `WrapperBudget` row in
  `tools/moui/validate_maintenance_baseline/moonbit_tool_wrapper_budget.mbt`.
- Related: `checks/profiles.json` (`pr-static`), `docs/testing.md`,
  `AGENTS.md` pre-push list.
