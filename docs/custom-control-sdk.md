# Custom Control SDK

Use this guide when a reusable control cannot be expressed as a composition of
`@views` constructors. The supported extension boundary is a concrete
`@core.ViewNode` implementation constructed with `@core.View::from_node`.
There is no dynamic plugin loader, no new renderer ABI, and no public
`ViewNode` re-export from `moui` or `moui/views`.

The runnable reference is [`examples/custom_control`](../examples/custom_control/):
its `widgets` package owns an editable step counter and its `app` package keeps
the value in a TEA model.

## Choose The Smallest Boundary

Try these in order:

1. Compose existing `@views` constructors and modifiers.
2. Add a reusable composition helper in app code.
3. Implement a local `ViewNode` in a dedicated package when the control needs
   its own layout, paint, semantics, focus, or text-input contract.
4. Propose a first-party control in `moui/views` when multiple independent
   apps need the same stable API.

Do not add a control to `moui/core`. `core` owns the `ViewNode` protocol, not
control vocabulary.

## Package Shape

Keep the reusable node and its app separate:

```text
examples/my_app/
  widgets/
    moon.pkg
    my_control.mbt
    my_control_golden_test.mbt
  app/
    moon.pkg
    app.mbt
    my_app_test.mbt
```

The widget package normally needs `wzzc-dev/moui` and
`wzzc-dev/moui/core`. The shared app package keeps its default `moui + views`
boundary, adds `moui/services` only when it injects an app-facing timer, route,
or service source, and imports the local widget package. Runtime imports belong
in tests or platform entrypoints, never in the shared production app.

The reference package layout is:

```text
examples/custom_control/
  widgets/editable_counter.mbt
  widgets/editable_counter_golden_test.mbt
  app/app.mbt
  app/custom_control_app_test.mbt
```

## Minimal Node Template

A node is immutable declaration data. Typed callbacks and `Msg` values live in
the `View::from_node` adapter, not in the node.

```moonbit nocheck
priv struct Badge {
  label : String
  count : Int32
  key : String?
}

impl @core.ViewNode for Badge with fn identity(self) {
  @core.ViewIdentity::new(kind="Badge", key=self.key)
}

impl @core.ViewNode for Badge with fn declaration(self) {
  @core.ViewDeclaration::channels(
    layout=Constant,
    paint=Exact(
      @core.DeclarationKey::record(
        type_tag="Badge.paint",
        fields=[
          ("label", @core.DeclarationKey::string(self.label)),
          ("count", @core.DeclarationKey::int(self.count)),
        ],
      ),
    ),
    semantics=Exact(
      @core.DeclarationKey::record(
        type_tag="Badge.semantics",
        fields=[
          ("label", @core.DeclarationKey::string(self.label)),
          ("count", @core.DeclarationKey::int(self.count)),
        ],
      ),
    ),
    platform=Constant,
  )
}

impl @core.ViewNode for Badge with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(@core.Size::new(width=96.0, height=28.0)),
  )
}

impl @core.ViewNode for Badge with fn paint(self, context) {
  let theme = context.environment.theme
  @core.ViewPaintPlan::commands([
    FillRoundedRect(
      @core.RoundedRect::new(rect=context.frame, radius=6.0),
      theme.palette.surface_variant,
    ),
    DrawText(
      @core.TextRun::new(
        text="\{self.label} \{self.count}",
        frame=context.frame,
        font=theme.typography.control,
        color=theme.palette.on_surface,
      ),
    ),
  ])
}

impl @core.ViewNode for Badge with fn semantics(self) {
  @core.ViewSemanticsInfo::leaf(
    role=@core.SemanticsRole::Status,
    label=self.label,
    value=self.count.to_string(),
  )
}

pub fn[Msg] badge(
  label~ : String,
  count~ : Int32,
  key? : String,
) -> @moui.View[Msg] {
  @core.View::from_node(Badge::{ label, count, key })
}
```

Only `identity` and `layout` are compiler-required. Override the remaining
channels deliberately:

| Channel | Override when |
|---|---|
| `declaration` | Always for a reusable control; otherwise every channel is uncacheable |
| `paint` | The node draws something |
| `semantics` | Assistive technology or automation must observe the node |
| `focusable` | The node participates in Tab/pointer focus |
| `text_input_state` | The node accepts text or IME composition |
| `place_overlays` | The node positions overlay children after base layout |
| `platform_views` | The node owns a native platform child |
| `child_*` | Child constraints/environment/style differ from pass-through |
| `flex_weight` | A parent flex layout must allocate space by weight |

## Identity And Declaration

These are three different identifiers:

- `ViewIdentity.key` controls element reuse. Use a stable key for reorderable
  or multi-instance controls.
- `SemanticId` is the stable automation/accessibility address. It is not a
  layout cache key and does not replace `ViewIdentity.key`.
- `DeclarationKey` states exactly which immutable fields invalidate layout,
  paint, semantics, and platform work.

Keep the node's identity kind stable across releases. Include the caller key in
`identity`, but not in declaration keys. Include every node field read by a
channel:

- layout fields that change measurement or child placement;
- paint fields that change commands, geometry, colors, or text;
- semantics fields that change role, label, value, states, actions, numeric
  metadata, or relations.

Ambient state such as focus, hover, pressed, selection, composition, animation
clock, and environment theme does not belong in the declaration key. The
runtime already invalidates those passes. A pinned theme or font is different:
fingerprint it in the affected channel or return `Uncacheable`.

Run `moon test` across value changes, not only one static sample. At minimum,
assert that an unchanged layout channel stays equal while paint and semantics
change for a value update. The reference test
`editable counter identity and declaration channels stay explicit` does this.

## Semantics, Actions, And Accessibility

`ViewNode::semantics` describes declaration data. `View::from_node` separately
supplies typed action handlers, so advertised capabilities cannot drift from the
handlers that implement them.

- Use `ViewSemanticsInfo::leaf`, `text_field`, or `new` to declare role, label,
  value, state, numeric/text metadata, and composition.
- Add only real actions: `increment`, `decrement`, `set_text`, `select`, and so
  on.
- Return typed messages from handlers. Do not mutate app state inside the
  action callback.
- Test through committed runtime semantics and a real action request, not only
  by checking the node's local `semantics()` value.

The reference counter declares a text-field role with editable-text and numeric
metadata, then advertises `SetText`, `Increment`, and `Decrement`. The app test
drives all three through `AppRuntime::perform_semantics_action`.

## Multi-Instance State And Lifecycle

A reusable control does not need a component store to appear many times. The
reference app owns an `Array[CounterInstance]`; every committed value, edit
count, and auto flag stays in the parent TEA model. An instance's stable string
`id` is both its model key and the source of its scoped lifecycle identity.

- The widget `key` and `SemanticId` include the model key, so reordering does
  not move focus or automation to a different instance.
- `Feature::scope(scope_id="custom-control/<id>", ...)` projects one instance
  through a pure read/write lens. Sibling instances may declare the same local
  subscription key; the scope prefix keeps their lifecycle descriptors
  distinct.
- The app injects an optional `TimerSource` through the program factory. A
  missing source produces no subscription; an enabled instance gets its own
  `counter/auto` timer. Removing an instance removes its subscription and stale
  callbacks are ignored.
- Save/restore uses an app-owned snapshot DTO. Restore validates ids, rebuilds
  values from text, preserves order, and keeps a fresh-id cursor that skips
  existing keys. The runtime stores no persistent component state.

The pilot measurement is deliberately concrete: two or three instances require
an explicit child update/lens, a snapshot DTO, and a stable-id cursor. That work
is linear, typed, and visible in app code. It is accepted friction for the
current product scope; a runtime-owned store would remove some plumbing but add
a second persistence/codec owner and hidden lifecycle state. ADR 0053 therefore
remains in force until independent-product evidence justifies reopening it.

## Focus, Text, And IME

An editable custom control has two state owners:

- the parent TEA model owns the committed text/value;
- the runtime owns transient caret, selection, composition, and reveal state.

`text_input_state` must report the input frame, current caret, selection, and
active composition. Keep the caret within grapheme boundaries.

The event adapter must handle:

- pointer down by placing the caret from the local text geometry and taking
  focus;
- `InsertText`, `DeleteRange`, `DeleteSurrounding`, and `ReplaceText`;
- `CompositionStart`, `CompositionUpdate`, and `CompositionEnd`;
- `SetSelection`;
- paste/copy/cut when the control claims those commands.

Emit one committed value message when text is inserted or composition ends.
Transient composition frames update `TextControlStateContext` without rewriting
the model until commit. Do not assume the runtime's initial caret is the end;
seed it from the pointer or another explicit selection action.

Test at least one pointer-focus followed by composition begin/update/end, then
read back both `AppRuntime::focused_text_input()` and committed semantics.

## RTL And Direction

Place logical leading/trailing controls from one geometry source:

```moonbit
let leading_x = frame.mirrored_x(
  x=frame.origin.x,
  width=step_width,
  direction=context.environment.layout_direction,
)
```

Use that same geometry for paint, hit testing, caret placement, and golden
tests. Decrement remains the leading action and increment the trailing action;
their physical x coordinates swap under `RightToLeft`. Do not keep separate LTR
and RTL layout branches that can drift.

## Golden Layout And Paint Fixtures

Every reusable control should have a small deterministic fixture:

- exact constrained size;
- child frames or the absence of children;
- exact paint-command sequence for one representative state;
- a second assertion for mirrored RTL zones.

Use the neutral environment and fallback text system unless the control
specifically owns a text provider. Avoid raster screenshots for structural
contracts; a pixel smoke complements a command/layout fixture but does not
replace it.

The reference tests live in
`examples/custom_control/widgets/editable_counter_golden_test.mbt`.
Update them only when a layout or paint change is intentional.

## Migration Example

A typical hand-wired control accumulates state and cache invalidation in the
widget:

```moonbit nocheck
// Before: node owns transient and committed state, and every field forces a
// whole-node rebuild.
struct LegacyCounter {
  mut value : String
  mut hovered : Bool
  mut pressed : Bool
}
```

Migrate it as follows:

1. Move `value` into the parent TEA model; pass it down as immutable node data.
2. Replace hover/pressed fields with `ViewEventContext.state`.
3. Move caret/selection/composition to the runtime text-control state.
4. Expose constructors as `@moui.View[Msg]` with typed callbacks.
5. Split the declaration into layout, paint, semantics, and platform channels.
6. Declare semantic actions beside the typed handlers.
7. Replace heuristic hit tests with the same geometry helper used by paint.
8. Add golden, semantics/action, focus/IME, and RTL tests before deleting the
   old wrapper.

The reference app follows this shape with no component store and no hidden `ComponentContext`.

## Conformance Checklist

- [ ] Control lives outside `core`; app logic remains in the parent model.
- [ ] `identity` distinguishes kinds and uses stable keys for instances.
- [ ] Every field read by a declaration channel is in that channel's key.
- [ ] Paint and text-input geometry share one direction-aware source.
- [ ] Semantics expose role, label/value, state, and only real actions.
- [ ] Pointer focus seeds caret position; IME commit produces one model update.
- [ ] Golden layout, LTR paint, and RTL mirrored-zone fixtures exist.
- [ ] Runtime semantics/action, focus, and IME tests use the public boundary.
- [ ] `moon info` / API-surface review is run if the widget package is published.

Focused validation for the reference:

```sh
moon test examples/custom_control/widgets --target native
moon test examples/custom_control/app --target native
moon check examples/custom_control/app --target wasm-gc
node scripts/validate-viewnode-declaration-coverage.mjs
```

For framework-wide changes, continue with the applicable command from
`docs/testing.md`; do not treat the SDK example as a renderer or platform
smoke.
