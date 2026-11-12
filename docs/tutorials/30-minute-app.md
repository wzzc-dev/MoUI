# Build A 30-Minute MoUI App

This is the shortest path from an empty directory to a runnable, tested,
packaged MoUI app. It assumes the MoonBit toolchain and the `moui` CLI are
installed. The full control surface lives in the Showcase example; this
tutorial links to it instead of copying every API.

## 1. Create and run (5 minutes)

```sh
moon install wzzc-dev/moui_cli/cmd/moui   # or: moon install ./moui_cli/cmd/moui
moui new hello_moui
cd hello_moui
moon update
moon run macos .
```

`moui new` writes shared app logic in `app/` and a thin host entrypoint. The
same app package runs on Web and the other desktop targets:

```sh
moui run web .
moui run windows .
moui run linux .
```

## 2. A counter is just Model / Msg / update / view (5 minutes)

`app/app.mbt` is ordinary MoonBit:

```moonbit
using @views {button, card, center, column, text}

pub struct Model {
  count : Int32
}

pub(all) enum Msg {
  Increment
  Decrement
  Reset
}

pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { count: model.count + 1, }
    Decrement => { count: model.count - 1, }
    Reset => { count: 0, }
  }
}

pub fn view(model : Model) -> @moui.View[Msg] {
  center(
    card(
      column([
        text("MoUI Counter").title(),
        text("Count: \{model.count}").title(),
        row([
          button("-", on_click=Decrement),
          button("Reset", on_click=Reset),
          button("+", on_click=Increment),
        ]),
      ]),
    ),
  )
}
```

Run it again with `moui dev` instead of `moon run` (see step 5). Every click
goes through the typed message loop; there is no hidden component state.

## 3. Add a form and a list (5 minutes)

Use a `text_field` for the draft and `list`/`column` for rows. The model owns
both the draft and the items:

```moonbit
pub struct Model {
  draft : String
  items : Array[String]
}

pub(all) enum Msg {
  Draft(String)
  Add
}

pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Draft(value) => { ..model, draft: value, }
    Add =>
      if model.draft.trim() == "" {
        model
      } else {
        { draft: "", items: model.items + [model.draft], }
      }
  }
}
```

In `view`, compose a `text_field(value=model.draft, on_input=Draft)` with a
`button("Add", on_click=Add)` and render `model.items`. The File Importer and
Settings examples cover async services and persistent settings when you need
them.

## 4. Add navigation (5 minutes)

For a multi-page app, keep route history in the model and use `router_stack`:

- `@views.RouteHistoryState` / `RouterSnapshot` are serializable app state.
- `router_stack` / `navigation_stack_selected` accept a `RouteTransition`
  (slide/fade/scale) for enter transitions.
- The route value stays app-owned; the runtime does not invent a navigation
  stack for you.

The Showcase Navigation Shell is the reference implementation. Start there
before building a custom router.

## 5. Develop and inspect (5 minutes)

```sh
moui dev .
```

Native targets rebuild and restart; Web targets serve at
`http://127.0.0.1:3000/` and show compiler errors in an overlay. Restart
handoff preserves the model and, with the opt-in transient transport, scroll,
focus, and text caret.

To inspect the live tree:

```sh
moui dev . --inspect
moui inspect --method all        # reads .moui/devtools.port / document
moui inspect --method snapshot --json
moui inspect --method diagnostics
```

The DevTools document is read-only: view tree, layout/render/semantics sections,
trace text, and renderer diagnostics. On native hosts the app opens a loopback
socket; Web exposes `/__moui/devtools`.

## 6. Test it (5 minutes)

Add the shared harness as a test-only import in `app/moon.pkg`:

```text
import {
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/runtime/test_support",
} for "test"
```

Then write a real pointer-driven test:

```moonbit
test "counter increments from a button click" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=520.0,
    height=360.0,
  )
  assert_true(@test_support.widget_has_text(runtime.draw_commands(), "Count: 0"))
  @test_support.widget_tap_text(runtime, "+")
  assert_true(@test_support.widget_has_text(runtime.draw_commands(), "Count: 1"))
}
```

Run the project tests through the CLI:

```sh
moui test                 # defaults to the app package, native target
moui test --target wasm-gc
moui test --json
```

The harness exercises layout, hit-testing, and the update loop together. For
golden image coverage, use `moui_tests/golden` inside the MoUI repository; it is
a repo-level gate, not an app package dependency.

## 7. Package it (5 minutes)

```sh
moui package macos .       # dist/macos/<Name>.app (release by default)
moui package windows .     # portable folder
moui package linux .       # binary + run.sh + .desktop
moui package web .         # static bundle + moui-package.json
```

Mobile targets use `moui build <platform>` and `moui verify`; signing and
physical-device evidence are covered by
[the device runbook](../mobile-device-evidence.md).

## Where next

- [Showcase](../../examples/showcase) — visual index of controls, layout,
  themes, and renderer capability.
- [View catalog](../view-catalog.md) — constructor/API/semantics coverage.
- [TEA program model](../tea-program-model.md) — Program, Effect, Subscription,
  and lifecycle keys.
- [Testing](../testing.md) — widget harness, golden suite, and proof profiles.
- [Mobile device evidence](../mobile-device-evidence.md) — signing and real
  device runs.
