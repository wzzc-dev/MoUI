# RFC 0004: Release Module Dependency Closures

Status: Accepted (2026-08-07)

## Decision

Concrete renderer implementations become independent MoonBit publication
modules:

- `wzzc-dev/moui_skia_renderer`
- `wzzc-dev/moui_web_renderer`
- `wzzc-dev/moui_wgpu_renderer`
- `wzzc-dev/moui_sun_renderer`

The root `wzzc-dev/moui` module retains the app API, domain facades, controls,
services, runtime, backend contracts and implementations, renderer contracts,
and renderer-common algorithms. It does not depend on any concrete renderer,
renderer binding, diagnostic renderer stack, or integration-test library.

WebGPU is the root package of `moui_web_renderer`; Canvas2D is its
`canvas2d` child package. WGPU text providers remain child packages of
`moui_wgpu_renderer`. Existing `wzzc-dev/moui/render/*` concrete-renderer
paths are removed without compatibility wrappers.

Test harnesses and fixtures move under `moui_tests/tester`; dedicated
integration tests, benchmarks, text conformance packages, and Skia smoke
entrypoints stay in the same unpublished `wzzc-dev/moui_tests` module. There is
no separately published tester module because its only consumers are
repository-internal smokes. Unit tests remain with their production package.

## Release policy

The affected public modules launch at 0.2.0. Equal versions are a migration
convenience, not a standing invariant. Each module subsequently versions and
publishes only when its own API, implementation, or dependency requirements
change.

A checked release-module catalog declares publication class and directory.
Release tooling derives package order from declared module dependencies and
rejects accidental publication of internal modules.

## Consequences

Composition roots must declare both `wzzc-dev/moui` and the selected renderer
module. Ordinary app packages continue to depend only on the root app API,
domain facades, views, and services.

The base module keeps platform backends in this wave, so `window`, AccessKit,
Zeno, SVG, async, and x remain in its production closure. Splitting host
backends is a separate RFC.

Module-level closure validation becomes a required PR and daily gate. It
rejects renderer dependencies in the base module, cross-renderer dependencies,
accidental publication of `moui_tests`, and stale workspace dependency pins.
