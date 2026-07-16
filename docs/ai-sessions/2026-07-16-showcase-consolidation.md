# 2026-07-16: Showcase consolidation and moui_cli quick start

- **Agent**: ZCode / Grok
- **Goal**: Finish example consolidation — root Showcase composition, retire
  gallery/lab/moui_example, keep moui_cli quick start.
- **Outcome**: Partial / Success for code path; docs/validators still need final
  pass on this branch.

## Summary

Restored a working Showcase root TEA shell over four feature packages,
implemented `program_with_initial_route` for mobile, multi-route Platform with
mobile-service-probe, removed `component_gallery` / `platform_lab` /
`moui_example`, and regenerated repository facts.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `examples/showcase/app/{workspace,model,update,view,app}.mbt` | Root composition + routing | Mid-move root package had no sources |
| `examples/showcase/app/platform/` | Multi-route + probe | Platform was a single lab page |
| `examples/showcase/app/components/platforms.mbt` | Showcase paths/commands | Still advertised deleted gallery scripts |
| `examples/component_gallery`, `platform_lab`, `moui_example` | Deleted | Single comprehensive example |
| `moon.work`, `examples/catalog.json` | Dropped old members | Workspace consistency |
| `docs/decisions/0012-…` | ADR | Record decision |

## Key Decisions

- Root always owns four child models; workspace switch does not reset them.
- Platform timer/pending-service subscriptions stay mapped when Platform is
  hidden.
- Diagnostics types still use historical `ShowcaseModel` names inside the
  package; further rename/trim is follow-up, not a framework API change.
- Old Component Gallery screenshots/artifacts left in place as historical
  evidence; new Showcase device evidence marked pending.

## Validation

```sh
moon check examples/showcase/app --target native
moon test examples/showcase/app --target native
moon test examples/showcase/app/components --target native
moon test examples/showcase/app/platform --target native
moon test examples/showcase/app/patterns --target native
moon check examples/showcase/macos_skia --target native
moon check examples/showcase/android_skia --target native
moon run tools/moui/generate_repo_docs --target native -- --write
```

## Follow-Up / later same day

Unified shell redesign (ADR 0013): root owns chrome; packages export catalog +
`view_body`; Diagnostics trimmed to five runtime items; probe only on Platform;
desktop split + mobile list/detail.

- [ ] Dependency-boundary automation for the four packages
- [ ] Full pre-push validators + daily/platform profiles
- [ ] Fresh mobile Showcase runtime evidence (non-blocking)
- [ ] Further delete unused diagnostics helpers (`header`, `catalog_shell`, …)
