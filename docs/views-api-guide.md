# Views API Guide

MoUI application code should prefer the root `moui` facade plus the `views`
package for ordinary UI. `core` remains the lower-level contract, layout,
paint, rich text, geometry, and advanced testing surface; runtime construction
belongs in `moui/runtime`.

## Local DSL Imports

In application and example UI packages, import only the `views` functions the
package uses:

```moonbit
using @views { column, text, container, scroll_view }
```

MoonBit packages share top-level identifiers across files, so multi-file
packages should keep these imports in one small package-level DSL file instead
of repeating the same `using` block in every file.

Then call those functions without the `@views.` prefix:

```moonbit
container(
  column([...], align=@views.CrossAlign::Start),
  variant=@views.ContainerVariant::Raised,
  theme~,
)
```

Keep enum and type names qualified by default:

```moonbit
align=@views.CrossAlign::Start
variant=@views.ButtonVariant::Primary
variant=@views.ContainerVariant::Raised
```

This keeps the DSL compact while making `Start`, `Raised`, and similar variant
names unambiguous in larger files.

## Descriptor Helpers

Many reusable views take small descriptor values for actions, menus, sidebars,
breadcrumbs, navigation cards, and selectable-list rows. Prefer the free helper
constructors in app DSL code so ordinary view trees read like compositions:

```moonbit
using @views {
  action_item,
  menu_item,
  section_nav_item,
  selectable_list_item,
  command_bar,
  menu_bar,
  section_nav,
  selectable_list,
}
```

Then build descriptors next to the view that consumes them:

```moonbit
command_bar([
  action_item(id="open", label="Open", message=OpenDocument),
  action_item(id="save", label="Save", message=SaveDocument, enabled=can_save),
])

section_nav(
  "Workspace",
  [
    section_nav_item(id="overview", label="Overview", message=Select("overview")),
    section_nav_item(
      id="reports",
      label="Reports",
      summary="Charts",
      message=Select("reports"),
    ),
  ],
  selected=route,
)
```

Use the `Type::new` form only when it makes a type annotation or cross-package
API boundary clearer. This keeps ordinary app packages on `moui + views` while
leaving lower-level runtime, host, and renderer packages out of view code.

## Message Types and `View::map` Cost

`View::map` rebuilds the entire wrapped subtree on every view call: each layer
re-creates one adapter per node, snapshots its children and semantics-handler
arrays, and wraps its event closure. The native leaf benchmark records the
structural copy count: with one map layer, 1k/10k trees make 30,060/300,060
adapter copies over 30 frames; with two layers those counts double. Frame timing
is report-only because shared-host variance is larger than the copy delta
(`benchmarks/performance_budget/native/main.mbt`). The `full_cycle` benchmark
provides the wall-clock companion (`F-deep-click` vs `G-deep-dblmap-click` in
`benchmarks/full_cycle/native/main.mbt`).

Prefer a flat top-level `Msg` enum for the program, and build child messages
directly in the parent view (or via plain constructor helpers) instead of
nesting `map` per feature module. `map` stays the right tool at real
composition boundaries — mounting a standalone feature view whose messages are
its own `Msg` into the app — but keep the number of live `map` layers on any
root-to-leaf path small (one layer is fine; stacked layers multiply). The
construction snapshots are a documented ownership contract (`from_node` must
survive a producer-owned `children` array being mutated afterwards, pinned in
`moui/core/view_node_test.mbt`), so the copies are not incidental overhead to
strip. ADR 0058 records why the typed non-copying transform chain is not
implementable with the current language representation; the debt and reopen
triggers live in `docs/plans/debt/message-transform-chain.md`.

## Declarative Drag And Drop

`View::draggable` and `View::drop_target` declare an in-app drag source and
target on ordinary views. The runtime owns the pointer session and sends TEA
messages, so update code never handles raw pointer state:

```moonbit
let done_column =
  container(
    column([text("Done")]),
    variant=@views.ContainerVariant::Raised,
    theme~,
  ).drop_target(
    key="done",
    accepts=Some(fn(payload) { payload.key.has_prefix("pr/") }),
    on_drop=Some(fn(payload, _position) { CompleteCard(payload.key) }),
    on_enter=Some(fn(_payload, _position) { HighlightColumn("done") }),
    on_leave=Some(fn() { ClearHighlight("done") }),
  )

column([
  text("Review pull request").draggable(
    payload=@core.DragPayload::new(key="pr/42", text="Review PR"),
    on_end=Some(fn(end) {
      match end.target_key {
        Some(target) => MoveCard("pr/42", target)
        None => DropCancelled("pr/42")
      }
    }),
  ),
  done_column,
])
```

The source fires `Started` only after the pointer travels `min_distance`
(4.0 default), then observes every `Moved`; the single terminal `Ended` names
the accepting target under the release point, or `None` for release outside a
target, Escape, and host cancellation. The deepest accepting target is the only
hovered one, with `Entered`/`Moved`/`Left`/`Dropped`; a target whose `accepts`
returns false never hovers. Every phase goes only to the declaring view, with
that view's own screen `frame` and the pointer `position`. Both modifiers
report their own declaration, so `.draggable().drop_target()` stacks as an
outer target over an inner source, and stacking a `.draggable` above a nested
target lets the source start and the deepest target receive the drop.

Drag handlers are observers: return a message (or `None`) to update the model;
the runtime keeps the session stable across rebuilds. `.disabled()` around the
source or target suppresses the role like other pointer modifiers. `.on_drag`
is a separate low-level recognizer and may coexist with `.draggable`; OS file
drop stays on `View::on_file_drop` (`DragDropEvent`).

## Boundary

Use `views` for ordinary app authoring: controls, layout, surfaces, scrolling,
and simple composition.

Use `moui/runtime` for platform entrypoint runtime setup and white-box runtime
smoke tests. Use `core` directly only for lower-level state and binding types,
custom paint/layout, rich text models, geometry calculations, and advanced test
assertions that are not covered by root aliases or `views` helpers.

Advanced helpers such as custom layout and navigation destination construction
may stay qualified as `@views.*` when that makes the call site clearer.
