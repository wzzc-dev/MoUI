# 0011: Platform product class and mobile readiness semantics

- **Date**: 2026-07-16
- **Status**: Accepted (product-class decision superseded in part by ADR 0021 on 2026-08-02)
- **Deciders**: Agent-assisted (wzzc-dev)
- **Related**: `docs/platform-readiness-declaration.md`, ADR 0006, ADR 0010, ADR 0021

## Context

Embedded runtime backends reported `ready: false` with blockers such as “lifecycle glue
is not wired” and Skia preflight `runtime_status=experimental-scaffold`, while
embedded runtime backends, `EmbedderHostChannel` services, and host-sim coverage
already existed. That binary narrative was both too harsh
(“completely broken”) and too easy to misread against Linux, where `ready: true`
means host usability, not full L3 green.

Docs, Gallery labels, and capability matrices also mixed packaging success,
runtime evidence, and product promotion.

## Decision

1. Publish an explicit **product_class** matrix:
   - macOS / Web: `committed`
   - Windows / Linux: `committed_with_gaps`
   - Android / iOS / HarmonyOS: `runtime_partial`
2. Redefine mobile `ready: true` as **window-hosted path usable for
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
- Cons: contradicts matching-device evidence gaps, signing, presenter verification

## Rationale

Option B stops two failure modes: claiming six-platform product readiness, and
claiming mobile is empty scaffold. Capability truth tracks wiring; promotion
truth stays in checks JSON, smoke manifests, and product_class docs.

## Consequences

- Callers must not treat `ready=true` as “L3 passed / seven-gate claimed.”
- Guidance, README, Gallery, and support docs share one product_class table.
- Follow-up: matching-device re-smokes and signed HarmonyOS full suite before any
  product_class promotion.

## Amendment (2026-08-02, ADR 0021)

ADR 0021 downgrades Android / iOS / HarmonyOS / WeChat Mini Program from
`runtime_partial` to **`experimental`** (`ready=false`): the code paths compile
and host-sim tests pass, but no development/demonstration usability or product
commitment is made without matching-device evidence. Decision points 1, 2, 3,
and 5 above are superseded in part by ADR 0021. The capability/service wiring
and host-sim coverage this ADR describes remain intact.
