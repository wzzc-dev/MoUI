# moui_studio workbench ownership (editor-first)

## Rule

Since ADR 0042 (2026-10-24), `moui_studio/workbench` owns documents and the
editor area; `moui_studio/app` is only the composition root and policy layer.

- Documents: `@wb.DocumentStore` is the single source of truth for open files
  (draft/saved/caret/dirty, close+rename convergence, one pinned Studio doc).
  Never keep a second writable copy of open-file state in `ProjectState` or
  shell fields — explorer/tab strip read projections only.
- Centre surface: `@wb.editor_area(model.workbench, ctx, editor_providers(),
  preferred, …)`. New centre modes are `EditorProvider` entries (priority +
  accepts), not new switches in `workspace_content`.
- Bottom panels: derive tab headers/badges/bodies from `studio_panels`
  (`@wb.PanelContribution`); a plugin's absence = panel not registered.
  Left/right columns are still hard-coded (registry pulled in M4 for budget).
- Commands: the palette (`studio_commands`) derives from
  `studio_command_registry` (`@wb.CommandContribution`, 43 entries;
  `label_key == ""` = hidden/internal). `run_studio_command` is a table lookup
  (Apply → `update_pure`, Dispatch → `Effect::dispatch`). Add new commands to
  the registry only — never reopen a match arm.
- Dead kernel contribution types (`kernel/contributions.mbt`,
  `PluginDescriptor`) are deleted; the workbench types are the extension
  surface. Kernel keeps event bus / services / PTY / provider contracts.

Budget ratchet (27,374 lines / 39 files / 111 fields / 238 variants, measured at
the pinned subrepo commit `ef2a56f12`) left this repository on 2026-10-25. Its
carrier was `tools/moui/validate_maintenance_baseline/studio_shell_budgets.mbt`,
but `moui_studio` is a separate git repository, so the main-repo gate was
accounting for a directory no git tracks here. Rebuild the gate inside
`moui_studio`; the counting rules and the "no B/C-stage claims before rebuild"
rule are in `docs/plans/active/moui-studio-shell-completion.md` plus ADR 0040.
App source files may not grow (`*wbtest.mbt` files are exempt from the count).
