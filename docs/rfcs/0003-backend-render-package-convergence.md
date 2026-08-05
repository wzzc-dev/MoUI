# RFC 0003: Backend And Render Package Convergence

Status: Accepted (2026-08-05)

## Decision

Backend and render use the same package shape:

```text
backend                     render
├── common                  ├── common
│   ├── desktop             └── {skia,wgpu,sun,canvas2d,webgpu_adapter}
│   ├── embedded
│   └── native
└── {macos,windows,linux,android,ios,harmonyos,web,wechat}
```

Root packages contain neutral protocols and DTOs. Common packages contain
registries, queues, lifecycle/frame/input state, provider selection, workers,
image lifecycle, fallback, and shared algorithms. Concrete subpackages contain
native decode, presentation, renderer code, and platform integration.

The old backend host and bridge packages are removed atomically. No facade,
deprecated alias, or dual import path remains. `SurfaceMetrics` is shared from
`moui/core`.

## Composition

Application entrypoints continue to supply ordered runtime `RendererFactory`
values and one platform `PlatformEntry`. A backend creates a neutral
`SurfaceContext`; `render/common` negotiates a factory and returns a root
`RendererResolution` containing a `WindowRenderer` and optional stateless
`ImageLoader` port. Backends never import a concrete renderer.

MoUI does not adopt Iced's Rust generic `Compositor` model. MoonBit package
composition and runtime factory selection preserve open renderer extension and
keep platform entrypoints explicit without coupling backend types to a renderer.

## Ownership

`backend/common` uniquely owns window mappings, lifecycle transitions, frame
completion ordering, image repaint routing, and teardown effects. Desktop and
embedded adapters remain separate projections of physical callbacks.
`render/common` uniquely owns provider selection, fallback, mailbox/GPU worker,
image lifecycle, and shared drawing algorithms.

## Gates

- API surface rules reject implementation types in root backend/render.
- Backend common and window lifecycle validators reject duplicate ownership.
- Backend-renderer validation rejects concrete renderer imports from backends.
- Focused package tests, host simulation, and PR/platform profiles remain
  required; readiness classifications do not change without matching-device
  evidence.
