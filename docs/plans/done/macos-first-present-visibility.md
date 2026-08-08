# Plan: macOS first-present visibility

- **Status**: done
- **Goal**: Prevent the transient uninitialised Metal drawable from being shown
  while `mo_desktop` and `mo_workbench` start on macOS.
- **Non-goals**: Change renderer selection or alter secondary-window behavior.

## Acceptance

- [x] The affected primary windows remain hidden before their first successful
  renderer presentation.
- [x] Both windows become visible after that presentation.
- [x] Deferred primary-window visibility is the safe macOS host default, while
  creation-time visibility remains available as an explicit opt-out.
- [x] Focused backend/app tests, entrypoint checks, and API validation pass.

## Implementation

1. Added an opt-in macOS host option that creates the primary window hidden.
2. The backend reveals that window only after its first successful renderer
   presentation.
3. Made the safe behavior the host default so ordinary composition roots do not
   repeat startup-visibility configuration.

## Validation

- `moon test moui/backend/macos --target native` — 24 passed.
- `moon test examples/mo_desktop/app --target native` — 11 passed.
- `moon test examples/mo_workbench/app --target native` — 68 passed.
- `moon check examples/mo_desktop/macos_skia --target native` — passed.
- `moon check examples/mo_workbench/macos_skia --target native` — passed.
- `node scripts/validate-api-surface.mjs` — passed.
- Launched `examples/mo_desktop/macos_skia`; the deferred window reached the
  on-screen window list at layer 0 with alpha 1 after first presentation.
