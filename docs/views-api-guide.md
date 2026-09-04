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
arrays, and wraps its event closure. The `full_cycle` benchmark measures about
+10% rebuild cost per map layer on a 511-node deep tree (`F-deep-click` vs
`G-deep-dblmap-click` in `benchmarks/full_cycle/native/main.mbt`).

Prefer a flat top-level `Msg` enum for the program, and build child messages
directly in the parent view (or via plain constructor helpers) instead of
nesting `map` per feature module. `map` stays the right tool at real
composition boundaries — mounting a standalone feature view whose messages are
its own `Msg` into the app — but keep the number of live `map` layers on any
root-to-leaf path small (one layer is fine; stacked layers multiply). The
construction snapshots are a documented ownership contract (`from_node` must
survive a producer-owned `children` array being mutated afterwards, pinned in
`moui/core/view_node_test.mbt`), so the copies are not incidental overhead to
strip; full message-adapter fusion is tracked as framework debt instead.

## Boundary

Use `views` for ordinary app authoring: controls, layout, surfaces, scrolling,
and simple composition.

Use `moui/runtime` for platform entrypoint runtime setup and white-box runtime
smoke tests. Use `core` directly only for lower-level state and binding types,
custom paint/layout, rich text models, geometry calculations, and advanced test
assertions that are not covered by root aliases or `views` helpers.

Advanced helpers such as custom layout and navigation destination construction
may stay qualified as `@views.*` when that makes the call site clearer.
