# Plan: All-target diagnostics cleanup

- **Status**: active
- **Goal**: Restore `moon check --target all` and remove compiler warnings outside `window/` packages.
- **Non-goals**: Changing warnings emitted from `window/` packages or altering renderer/product behavior beyond the reported diagnostics.

## Acceptance

- [ ] `moon check --target all` has no errors.
- [ ] All compiler warnings outside `window/` packages are resolved.
- [ ] Focused affected-package checks and formatting pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-07-29 | Exclude `window/` package warnings exactly as requested. |

## Progress

| Date | Note |
|------|------|
| 2026-07-29 | Plan created; collecting the current diagnostic baseline. |
