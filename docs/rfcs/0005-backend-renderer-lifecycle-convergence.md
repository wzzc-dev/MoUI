# RFC 0005: Backend Ownership and Renderer Lifecycle Convergence

Status: Accepted (2026-08-07)

## Decision

MoUI replaces the renderer factory/binding/instance/window-renderer chain with
two root contracts:

- `RendererProvider` owns identity, descriptor, capability reporting, and a
  delayed `HostSurface` bind operation;
- `RendererSession` owns the complete per-window renderer lifecycle, image
  loader port, presentation completion, recovery, platform-view hooks, and
  idempotent disposal.

Provider selection remains ordered and renderer-neutral in `moui/render/common`.
A rejection is inspection-only and may not leave persistent renderer or native
surface resources behind.

Root `moui/render` exposes object-safe host/native surface capabilities with
opaque handles and neutral presenter/image ports. It does not define platform
surface variants or a Metal/Vulkan/EGL/D3D route enum. Concrete renderer
modules own handle interpretation and surface-route policy; composition roots
pass the matching renderer-local platform policy explicitly.

Backend-common state is split by ownership:

- logical windows, requests, mappings, and close state;
- frame submission and presentation completion;
- async image scheduling and repaint tracking;
- input and text-input sessions;
- service bridge and async completion lifetime;
- embedded transport/session assembly.

Platform backends store these owners directly. Cross-owner workflows are
stateless functions with explicit inputs. There is no replacement aggregate
coordinator.

## Compatibility

This is an atomic 0.2 breaking migration. The old renderer lifecycle types,
surface descriptors, surface routes, and coordinator types are removed without
aliases or wrapper packages. All repository consumers and generated interfaces
migrate in the same change.

## Consequences

Adding a renderer no longer expands a central surface matrix. Backend lifecycle
and image/service teardown can be tested independently, while renderers keep
their platform-specific construction inside their publication module.

The release-module graph from RFC 0004 is unchanged. Renderer classifications,
platform readiness, and the Native Skia mainline remain unchanged. This work
validates 0.2 head and package archives but does not publish them.
