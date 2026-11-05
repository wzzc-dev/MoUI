# 0055: The 0.3.x release line is synchronized

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W4.1-W4.2),
  ADR 0026, ADR 0047

## Context

MoUI publishes 25 public modules across four dependency-safe release stages:
base/bindings, renderers, addons, and entrypoints. `checks/release-modules.json`
owns that closure, and `validate-release-module-closures` already checks stage
direction, package manifests, and renderer dependency boundaries.

At this decision, every public module declares `0.3.0` except `moui_cli`
`0.3.1`. Consumers pin exact workspace versions. There is no external consumer
compatibility matrix, no independently versioned renderer contract, and no
release automation that can safely publish one base patch while leaving a
renderer/addon line on an older base.

The architecture review asked whether a base-only patch path or per-module
compatibility matrix is justified. Offering one now would create release
metadata that no consumer has exercised while still requiring every module to
be tested against the same base API.

## Decision

The accepted release policy is a synchronized `0.3.x` line:

- Public modules advance within the same `major.minor` line at a coordinated
  release window. Patch versions may differ when a module needs a focused fix;
  `moui_cli 0.3.1` is the current example.
- A base-only patch path is not offered. A base change is validated against all
  affected renderer, addon, and entrypoint closures before publication.
- A per-module compatibility matrix is deferred. It requires external consumer
  evidence, independently supported renderer contracts, and release automation
  that can test and publish combinations against older bases.
- A renderer or addon is not forced to take a semantic version bump merely
  because an unrelated base module changed. It keeps its version unless its own
  public contract or behavior changes, or the coordinated release requires a
  new artifact for the shared line.
- Exact workspace pins and `node scripts/validate-release-module-closures.mjs`
  verify the current repository closure. The portfolio validator rejects a
  public module outside the declared release line.

This is release coordination, not an API-compatibility promise between
arbitrary historical module versions.

## Options Considered

### Option A: synchronized line with coordinated release windows

- Pros: matches the current closure, exact pins, and test matrix; keeps one
  known-good base/renderer/addon combination; no unvalidated compatibility
  metadata.
- Cons: one release window can delay a focused module fix; GitHub/Mooncakes
  publication remains a batch operation.

### Option B: base-only patch path

- Pros: faster base bug fixes.
- Cons: every public renderer/addon would need to prove compatibility with a
  moving base patch, while the current suite only proves the workspace
  combination. The saved coordination cost would be paid by consumers.

### Option C: independent module cadence and compatibility matrix

- Pros: teams could publish modules independently once their own contract
  changes.
- Cons: needs external consumer demand plus maintained test/publish lanes and
  compatibility metadata for every supported base pairing. No such evidence or
  automation exists.

## Consequences

- Release documentation must describe the synchronized line and must not imply
  that arbitrary base-only upgrades are supported.
- `checks/portfolio-governance.json` records the policy; the portfolio
  validator checks public manifest versions against `0.3.x`.
- Renderers and addons remain independently owned packages whose own semantic
  version changes when their contract changes, but publication coordination and
  validation remain shared.
- Revisit this decision only with external consumer evidence and a concrete
  compatibility/publish automation design. A new ADR should supersede this one
  before introducing independent cadence.

## References

- `checks/release-modules.json`
- `checks/portfolio-governance.json`
- `scripts/validate-release-module-closures.mjs`
- `scripts/validate-portfolio-governance.mjs`
- `docs/plans/done/architecture-priority-execution.md`
