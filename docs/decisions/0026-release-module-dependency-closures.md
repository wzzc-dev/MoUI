# ADR 0026: Release module dependency closures

- **Date**: 2026-08-07
- **Status**: Accepted

## Decision

MoonBit modules, rather than package-directory proximity, define MoUI release
and dependency closures. `wzzc-dev/moui` owns neutral framework and platform
layers. Concrete renderer implementations are published as
`wzzc-dev/moui_{skia,web,wgpu,sun}_renderer` and depend inward on the base
module.

Renderer release modules use the `moui_<implementation>_renderer` naming
shape. This keeps engine/binding modules such as `moui_skia` and `moui_sun`
adjacent to their renderer modules while retaining an explicit role suffix.

No compatibility package remains at the old concrete-renderer paths because a
wrapper would require the base module to depend on the extracted renderer and
would recreate the closure being removed.

WebGPU and Canvas2D share one Web renderer module. WGPU provider packages share
one WGPU module. Test harnesses and fixtures live under `moui_tests/tester`;
dedicated integration tests and renderer smoke entrypoints share that
unpublished module. A separate public tester module is not retained without an
external consumer or a substantial stable API.

Module prebuild hooks follow the same ownership: platform host link setup stays
in `moui`, Skia setup moves to `moui_skia_renderer`, and native WGPU text/link
setup moves to `moui_wgpu_renderer`.

## Consequences

The base module's direct dependency list is reduced to the production
dependencies required by neutral runtime, backend, and render-common code.
Adding or releasing a renderer no longer changes the base dependency closure.

All affected public modules use 0.2.0 for the migration release, then version
independently. A release-module catalog and closure validator enforce the graph
without enforcing equal versions.

Package imports in composition roots change to the new renderer namespaces.
Renderer provider protocols, runtime behavior, and readiness classifications
do not change.
