# 0065: The 0.4.x release line is synchronized

- **Date**: 2026-11-06
- **Status**: Accepted (supersedes ADR 0055). The synchronized-line policy
  continues on the `0.5.x` line: 0.5.0 advanced every public module together
  with the platform-bridge features recorded in `docs/releases/0.5.0.md`.
  It continues again on `0.6.x`: 0.6.0 advances every public module together
  with the mature-framework parity program recorded in
  `docs/releases/0.6.0.md`. The cadence is unchanged, so no superseding ADR
  is required.
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: ADR 0055, ADR 0059, `checks/release-modules.json`,
  `docs/releases/0.4.0.md`

## Context

ADR 0055 pinned the synchronized `0.3.x` line. The 0.4.0 architecture program
moves host orchestration to `moui/apphost`, removes the core text cache, opens
the service extension point, adds capability/diagnostic contracts, and changes
several public interfaces. `moui/runtime` is now core-only; every composition
root imports `moui/apphost`.

A synchronized line remains the only release policy the repository can verify:
renderers and addons pin exact base versions and are tested against one
known-good closure. A per-module compatibility matrix would require external
consumer evidence for historical combinations that do not exist yet.

## Decision

The release policy becomes a synchronized `0.4.x` line:

- Every public module advances to `0.4.0` at the release window. Patch
  versions may differ later only for focused fixes within `0.4.x`.
- A base-only patch path is not offered. A base change is validated against all
  affected renderer/addon/entrypoint closures before publication.
- `docs/compatibility-matrix.md` records the product/lab classification and
  the exact base pin for each public module, but it is a documentation aid, not
  a claim that arbitrary historical combinations are supported.
- Exact workspace pins and `node scripts/validate-release-module-closures.mjs`
  remain the machine gate. The portfolio validator rejects a public module
  outside the declared line.
- `moui/apphost` is part of the base module (`wzzc-dev/moui`); it is not a new
  release module.

## Consequences

- `0.4.0` is the single migration point for the synchronized line; no
  compatibility aliases are kept.
- `moui_studio`, `moui_cli`, the website, examples, and the external consumer
  fixture move their pins to `0.4.0` in the same release window.
- The next structural change that needs a different cadence must supersede
  this ADR.
