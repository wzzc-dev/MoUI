# 0011: Platform product class and mobile readiness semantics

- **Date**: 2026-07-16
- **Status**: Accepted
- **Deciders**: Agent-assisted (wzzc-dev)
- **Related**: `docs/platform-readiness-declaration.md`, ADR 0006, ADR 0010

## Context

Mobile backends reported `ready: false` with blockers such as “lifecycle glue
is not wired” and Skia preflight `runtime_status=experimental-scaffold`, while
managed shells, `EmbedderHostChannel` services, packaging matrices, and historical
runtime smokes already existed. That binary narrative was both too harsh
(“completely broken”) and too easy to misread against Linux, where `ready: true`
means host usability, not full L3 green.

Docs, Gallery labels, and capability matrices also mixed packaging success,
runtime evidence, and product promotion.

## Decision

1. Publish an explicit **product_class** matrix:
   - macOS / Web: `committed`
   - Windows / Linux: `committed_with_gaps`
   - Android / iOS / HarmonyOS: `runtime_partial`
2. Redefine mobile `ready: true` as **managed-shell host path usable for
   development and demos**, aligned with Linux host usability.
3. Add mobile `readiness.status = "runtime_partial"` for evidence class.
4. Set capability/service flags from **code wiring**, not only from complete
   matching-device promotion evidence.
5. Change Skia mobile preflight `runtime_status` from `experimental-scaffold`
   to `runtime_partial`.
6. Do **not** raise `checks/platforms/*.json` L3/presenter fields without new
   evidence; do **not** claim GPU seven-gate promotion.

## Options Considered

### Option A: Keep `ready: false` and only rewrite strings

- Pros: smaller semantic change
- Cons: still false-negative vs Linux; callers keep treating mobile as unusable

### Option B: Multi-state readiness + `ready=true` for usable host (chosen)

- Pros: matches reality; separates usable vs promoted
- Cons: public struct gains `status`; tests and docs must update

### Option C: Flip mobile to product-complete

- Pros: simplest marketing story
- Cons: contradicts managed re-smoke gaps, signing, presenter verification

## Rationale

Option B stops two failure modes: claiming six-platform product readiness, and
claiming mobile is empty scaffold. Capability truth tracks wiring; promotion
truth stays in checks JSON, smoke manifests, and product_class docs.

## Consequences

- Callers must not treat `ready=true` as “L3 passed / seven-gate claimed.”
- Guidance, README, Gallery, and support docs share one product_class table.
- Follow-up: managed-shell re-smokes and signed HarmonyOS full suite before any
  product_class promotion.
