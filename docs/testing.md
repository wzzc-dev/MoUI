# Testing

MoUI uses layered validation instead of broad all-repository checks for every
change. Prefer the smallest command that covers the package, platform, or public
API surface you touched.

## Daily Check

Run the bounded development check for routine work:

```sh
sh scripts/dev-check.sh
```

This keeps feedback fast by running stable package-level tests, native renderer
contract tests, and Web wasm-gc example builds without invoking every native or
wasm-gc target.

## Focused Package Tests

Use package-level commands while editing implementation code:

```sh
moon test core --target native
moon test views --target native
moon test render --target native
moon test render/wgpu --target native
moon test render/webgpu_adapter --target wasm-gc
moon test backend/host --target native
moon test backend/web --target wasm-gc
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
```

Run `moon fmt` before handoff so MoonBit source stays normalized.

Use `moon check --warn-list +unnecessary_annotation` as a cleanup audit before
or during public API reviews. Treat new unnecessary annotations as cleanup work,
but do not require this stricter audit to be warning-free for every inner-loop
change until existing warnings are resolved.

## Platform Validation

When platform behavior matters, include backend tests without forcing native
example builds:

```sh
sh scripts/dev-check.sh --platform-examples-test
```

Before release-style validation on a configured host, build current-platform
examples:

```sh
sh scripts/dev-check.sh --platform-examples-build
```

Native builds link platform stubs and `wgpu-native`, so they are intentionally
not part of every inner-loop check.

## Public API Review

After changing exported types, constructors, functions, package imports, or
public behavior, run:

```sh
moon info
```

Review generated `pkg.generated.mbti` diffs. If no public API changed, generated
interfaces should stay unchanged.

## Renderer Capability Rule

When draw command support changes, keep the capability loop synchronized:

1. Update `render/capabilities.mbt`.
2. Update `render/capabilities_test.mbt`.
3. Update `docs/renderer-capability-report.md`.
4. If the behavior is visible, update Showcase coverage.

Suggested validation:

```sh
moon test render --target native
moon test render/wgpu --target native
moon test render/webgpu_adapter --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
```

## Conformance-Oriented Coverage

The SwiftUI/Flutter/Compose parity work should grow focused conformance tests
before it grows broad platform claims:

- Runtime: dirty component rebuilds, keyed effect reuse/cancellation, unmount
  cleanup, and saveable state restore.
- Layout/render: custom child layout delegates, baseline/alignment follow-ups,
  lazy viewport behavior, clip/transform/opacity/image/text command stability,
  and renderer capability report synchronization.
- Input/accessibility: gesture arbitration, action-command matching, focus
  traversal, shortcut dispatch, IME/text selection, clipboard service routing,
  and semantics action roundtrips.
- Platform/tooling: host-service capability checks, Linux readiness, Web
  wasm-gc backend tests, devtool snapshots, frame-profile counters, and example
  builds.

## Release-Oriented Checklist

Before a broad handoff or release candidate:

```sh
sh scripts/dev-check.sh
sh scripts/dev-check.sh --platform-examples-test
sh scripts/dev-check.sh --platform-examples-build
moon info
```

Also confirm README and docs mention current commands, platform constraints,
example paths, and renderer capability status. If the release includes warning
cleanup, include `moon check --warn-list +unnecessary_annotation` and review the
remaining diagnostics explicitly.
