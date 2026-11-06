# 0064: First-class AppShell is deferred beyond 0.4.0

- **Date**: 2026-11-06
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-hardening-program` (W8.1), ADR 0059

## Context

MoUI already has host-level multi-window primitives: `WindowRequests`, the
`backend/common/lifecycle` registry, `WindowScene`, and `WindowActions`. The
`examples/multi_window` app composes one `Program` per scene and routes open,
close, focus, and completion through typed messages.

A first-class `AppShell`/`WindowProgram` API would sit above those primitives
and own per-window model slices, lifecycle messages, and persistence. That is a
product API decision, not a mechanical convergence: it must define identity,
model partitioning, persistence, restoration, close policy, and interaction
with embedded detach/recreate. Shipping it without that design gate would give
apps a second window registry alongside the backend lifecycle owner, which the
architecture forbids.

## Decision

`0.4.0` does not add a public `AppShell`/`WindowProgram` API. The existing
`WindowActions`/`WindowScene` composition pattern remains the supported
multi-window contract, and `examples/multi_window` keeps documenting it.

The design gate moves to `0.5.0`:

- Write an RFC/ADR that defines window identity, per-window model ownership,
  persistence/restoration, and exactly-once close.
- Reuse `WindowRequests` and `backend/common/lifecycle`; do not add a second
  coordinator.
- Migrate `examples/mo_desktop` and `examples/multi_window` only after the ADR
  is accepted.

## Consequences

- `0.4.0` ships a coherent synchronized line without a half-designed product
  API.
- Multi-window apps keep working through the existing host primitives.
- The deferred work is visible in the release notes and active plan rather
  than being silently dropped.
