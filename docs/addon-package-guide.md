# Addon Package Guide

How to build, validate, and publish a third-party MoUI addon — a versioned
MoonBit module of custom controls, domain helpers, and service contracts that
MoUI applications consume. Status: `canonical`.

Scaffold one locally:

```sh
moui new --template addon my_addon
cd my_addon && moon test --target native
```

## Module layout

```text
my_addon/
├── moon.mod              # name = <owner>/my_addon; imports wzzc-dev/moui only
├── moon.work             # members = ["."]
├── moui.project.json     # generated identity manifest
└── my_addon/
    ├── moon.pkg          # build imports: wzzc-dev/moui, wzzc-dev/moui/views
    │                     # test imports: core, runtime
    ├── my_addon_control.mbt      # ViewNode implementation + typed constructor
    └── my_addon_control_test.mbt # runtime-level smoke over drawn commands
```

## Dependency rules (same as app packages)

An addon depends on `wzzc-dev/moui` plus the app-facing domain facades
(`views`, `animation`, `services`, `geometry`, `graphics`, `text`, `state`) and
may re-export curated `@core` types. It must not import `moui/runtime`
internals from production code, platform backends, renderer modules, or
`moui_theme`. Tests may import `wzzc-dev/moui/runtime` and the shared
`wzzc-dev/moui/runtime/test_support` widget harness (`for "test"` only).

## Stable extension surface

The API an addon may rely on across minor releases (see
[api-surface.md](api-surface.md) tiers and
[compatibility-policy.md](compatibility-policy.md) for SemVer, deprecation,
and quality levels):

| Surface | Contract |
|---|---|
| `@core.ViewNode` + `View::from_node` | Custom controls; declaration channels and semantics per [custom-control-sdk.md](custom-control-sdk.md) |
| `View[Msg]`, `Program`, `Effect`, `Subscription` | The TEA loop; see [tea-program-model.md](tea-program-model.md) |
| `@services.AppServices` / `ServiceTask[T]` | Typed host services (files, clipboard, timers, routes) |
| `@core` value types re-exported through facades | Geometry, paint, easing/spring motion, text, state |
| `wzzc-dev/moui/runtime/test_support` (`for "test"` only) | Shared widget-test harness |

Anything else reachable through `moui/*` packages is not addon-stable: treat
it like private API. Breaking a constructor signature, a `ViewNode`
declaration shape, or a semantics contract is a major version.

## Versioning and publication

- Pin the framework: `"wzzc-dev/moui@<version>"` in `moon.mod`. Bump the pin in
  lockstep with upstream minor releases that carry API you use; publish a
  matching addon release.
- Publish to mooncakes.io. Keep the module name `<owner>/<addon>`.
- Growth checks: `moon test <pkg> --target native` stays the minimal loop;
  run the whole addon suite before publishing.
- Addon-generated projects validate against the resolved registry package; a
  scaffold feature that needs a newer framework dependency (for example the
  `runtime/test_support` harness) works once the addon bumps its `wzzc-dev/moui`
  pin to the release that carries it.

## Testing expectations

1. Value-change tests per the control SDK: unchanged channels stay equal
   while changed fields invalidate the right channel.
2. Runtime smoke through committed semantics and drawn commands — the
   generated `*_control_test.mbt` shows the minimal shape; grow it with the
   `test_support` harness (`WidgetHarness::from_program`, `tap_text`,
   `has_text`) for tap and semantics assertions.
3. No addon test may depend on a concrete renderer or backend package.
