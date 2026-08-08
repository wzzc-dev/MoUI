# ADR 0027: Backend ownership and renderer lifecycle convergence

- **Date**: 2026-08-07
- **Status**: Accepted
- **Supersedes**: ADR 0019 clauses that require separate
  `RendererProviderBinding` and `RendererInstance` lifecycles; ADR 0024 clauses
  that place lifecycle/frame/image state in aggregate coordinator types; ADR
  0025 clauses that require `RendererFactory`, `RendererResolution`, or root
  platform surface descriptors/routes.

## Decision

Root render uses one static provider and one live session contract.
`RendererProvider::bind` receives an opaque `HostSurface` and returns either a
fully constructed `RendererSession` or a rejection reason. Ordered selection
is the only creation path. `RendererSession` exposes the host-required frame,
resize, text, image, completion, platform-view, recovery, diagnostics, and
dispose behavior. Disposal is idempotent and releases every renderer-owned or
accepted native-surface resource exactly once.

Host surface capabilities are open and object-safe. Neutral root types expose
metrics, CPU presentation, image bytes, opaque surface/display handles, and
lifecycle callbacks. They do not name a platform or graphics API. Renderer
modules own platform enums and route types and interpret opaque handles using
the policy selected by the composition root.

Backend-common state uses narrow package owners for lifecycle, frame, image,
input, services, and embedded session assembly. Platform backends store those
owners directly. Shared multi-owner operations are stateless workflows; no
single stateful coordinator owns all dependencies or teardown behavior.

## Consequences

The old factory/plan/binding/instance/resolution/window-renderer chain and
closed surface matrix are removed atomically. Root renderer API breadth
shrinks, provider rejection becomes side-effect constrained, and concrete
renderers can add a platform route without editing the base surface contract.

Window close and embedded detach follow one explicit order: block lifecycle
re-entry, detach image callbacks and cancel work, close service/session
channels, dispose the renderer session, dispose platform views/native host
resources, remove maps/runtime records, then finish the close transition.

MoonBit-backed boundary validation enforces package ownership, forbidden old
types, root surface neutrality, and the absence of a replacement aggregate
coordinator. Product classification and release-module topology do not change.
