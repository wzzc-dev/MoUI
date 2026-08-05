# ADR 0025: Backend and render package convergence

- **Date**: 2026-08-05
- **Status**: Accepted
- **Supersedes**: ADR 0018/0020 package-path clauses that require
  `moui/backend/host` or `moui/backend/platform_bridge`; ADR 0024 ownership is
  retained with its implementation moved under `moui/backend/common`.

## Decision

Backend and renderer packages use the same three-level shape:

- `moui/backend` and `moui/render` are neutral protocol/value packages;
- `moui/backend/common` and `moui/render/common` own shared implementations;
- platform and renderer subpackages own concrete integration.

`moui/backend/host` and `moui/backend/platform_bridge` are removed in one
breaking migration without compatibility facades. Platform-neutral surface
metrics move to `moui/core`. Application entrypoints continue to select
ordered renderer factories; concrete backends may consume `moui/render`
protocols but may not import concrete renderer packages.

Renderer factories return the root `@render.RendererResolution` contract.
Provider registration and ordered negotiation are implemented by
`@render_common.resolve_renderer`; the root package does not own a registry or
selection loop. Root `@render.ImageLoader` is a stateless closure port used by
backend lifecycle code, while in-flight scheduling, cancellation, repaint
tracking, and native pending-source state live in `render/common`.

The shared backend implementation owns the single platform-window mapping,
logical lifecycle transitions, frame completion ordering, and exactly-once
teardown decisions. Desktop and embedded adapters remain separate projections
of physical callbacks. Raw pointer, keyboard, IME, and drag decoding remains in
the concrete platform backend.

Names use package context instead of a generic `Host` prefix (`@backend.Event`,
`@backend.WindowId`, `@render.WindowRenderer`, `@render.SurfaceContext`). Names
that describe the external embedder ABI, including `HostCmd`, remain unchanged.

## Consequences

The package graph has no bridge package and no backend-to-concrete-renderer
edge. Shared event conversion lives in `backend/common`; desktop native wire
encoding lives in `backend/common/desktop`; renderer-independent algorithms
live in `render/common`. Root protocol packages cannot accumulate registries,
queues, coordinators, workers, caches, or platform-specific decoding.

All workspace consumers, generated interfaces, validators, guidance, and
tests migrate atomically. Renderer/platform readiness classifications do not
change without separate matching-device evidence.

The enforced production dependency directions are:

- root `backend` imports no common, runtime, or render package;
- root `render` imports no backend, common, or concrete renderer package;
- `render/common` imports root `render` and `core`, but no backend or concrete
  renderer;
- `backend/common` imports root `backend`; concrete backends enter through the
  matching common layer and never import a concrete renderer.

`validate-backend-common-boundary.mjs` enforces this graph and shared event
ownership. `validate-window-lifecycle-boundary.mjs` enforces lifecycle/frame
ownership and the physical-only window dispatcher.
