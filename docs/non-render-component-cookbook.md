# Non-Render Component Cookbook

This cookbook collects the app-level patterns that can be built without touching
`moui/render/*`, adding draw commands, or depending on a concrete renderer.
The common rule is: keep state in the app model, use `views` constructors for
composition, use `core` helpers for runtime-neutral contracts, and cross into
`backend/host` only for services that truly belong to the platform.

## Forms

Use `form`, `form_section`, and `form_field` for layout and status surfaces.
Keep field values, async validation state, and validation display controlled by
the app model, then use `@core.FormFieldState`, `required_field`, and
`FormController` when multiple fields need shared validation or
first-invalid-field routing. When a field is checking a server or local rule,
use `FormFieldStatus::Validating`; when submit should move focus, key the
field view and call `AppRuntime::focus_key` from the app or host after the
runtime is available.

```moonbit nocheck
using @views {button, form, form_field, form_section, text_field}

enum Msg { NameChanged(String); Submit }

fn profile_form(name : String, error : String?) -> @moui.View[Msg] {
  form([
    form_section(
      "Profile",
      [
        form_field(
          "Name",
          text_field(name, on_input=NameChanged, placeholder="Display name")
            .key("profile-name"),
          required=true,
          error~,
          helper="Shown in shared workspaces.",
        ),
        form_field(
          "Workspace slug",
          text_field("", on_input=NameChanged, placeholder="workspace-slug")
            .key("workspace-slug"),
          status=@views.FormFieldStatus::Validating,
          helper="Checking availability.",
        ),
        button("Save", on_click=Submit),
      ],
    ),
  ])
}

fn focus_first_invalid(runtime : @runtime.AppRuntime) -> Bool {
  runtime.focus_key("profile-name")
}
```

Recommended checks:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/settings/app --target native
```

## Data Tables

Use `DataSortState`, `PaginationState`, `ColumnVisibilityState`,
`SelectionState`, `data_filter_bar`, `selection_toolbar`,
`column_visibility_panel`, `table`, and `pagination` together for operational
data surfaces. Filtering, sorting predicates, visible columns, pagination, row
selection, and loading/error/empty states should live in the app model so the
table stays renderer-neutral and predictable.

```moonbit nocheck
using @views {
  action_item,
  column,
  column_visibility_panel,
  data_filter,
  data_filter_bar,
  error_state,
  loading_state,
  pagination,
  selection_toolbar,
  table,
  table_column,
}

fn project_table(
  rows : Array[Project],
  query : String,
  selected_count : Int,
  sort : @views.DataSortState,
  pagination_state : @views.PaginationState,
  visible_columns : @views.ColumnVisibilityState,
  selection : @views.SelectionState,
  loading : Bool,
  error : String?,
) -> @moui.View[Msg] {
  let columns = [
    table_column(id="name", label="Name", width=180.0),
    table_column(id="status", label="Status", width=120.0),
  ]
  if loading {
    loading_state("Loading projects")
  } else if error is Some(message) {
    error_state("Unable to load", message=message)
  } else {
    column([
      data_filter_bar(
        query~,
        on_query=QueryChanged,
        filters=[
          data_filter(id="active", label="Active", selected=false, message=ToggleActiveFilter),
        ],
        result_count=rows.length(),
        on_clear=Some(ClearFilters),
      ),
      column_visibility_panel(
        columns,
        visible=visible_columns.visible(),
        locked=visible_columns.locked(),
        on_toggle=(id, shown) => ToggleColumn(id, shown),
      ),
      selection_toolbar(
        selected_count=selection.count(),
        total_count=rows.length(),
        actions=[action_item(id="export", label="Export", message=ExportRows)],
        on_clear=Some(ClearSelection),
      ),
      table(
        columns,
        rows.map(row => [row.name, row.status]),
        selected_row=None,
        on_row_select=Some(index => SelectRow(index)),
        sort_column=sort.column(),
        sort_ascending=sort.ascending(),
        on_sort=Some(id => SortBy(id)),
        sortable_columns=["name", "status"],
        empty=Some(@views.empty_state("No projects", "No projects match the current filter.")),
      ),
      pagination(
        page=pagination_state.page(),
        page_count=pagination_state.page_count(),
        on_previous=PreviousPage,
        on_next=NextPage,
      ),
    ])
  }
}
```

Recommended checks:

```sh
moon test moui/views --target native
moon test examples/data_table/app --target native
```

## Navigation Shells

Use `sidebar`, `breadcrumb`, `split_view`, `master_detail`, `wizard`, and
`router_stack` to describe navigation structure. Keep the active route in the
app model or in `@core.RouterState`; use `RouteLocation` query params when a
route needs stable restoration. For focus restoration, record a route-to-key
mapping in `RouteFocusStore`, key the target focusable view, and call
`runtime.restore_route_focus(store, route)` after the route has rendered.

```moonbit nocheck
using @views {master_detail, sidebar, sidebar_item}

enum Msg { SelectSection(String) }

fn settings_shell(current : String, detail : @moui.View[Msg]) -> @moui.View[Msg] {
  let focus_store = @core.RouteFocusStore::new()
  focus_store.remember(route="account", focus_key="sidebar-item-account")
  focus_store.remember(route="appearance", focus_key="sidebar-item-appearance")
  master_detail(
    master=sidebar(
      "Settings",
      [
        sidebar_item(id="account", label="Account", message=SelectSection("account")),
        sidebar_item(id="appearance", label="Appearance", message=SelectSection("appearance")),
      ],
      selected=current,
    ),
    detail~,
  )
}

fn restore_settings_focus(
  store : @core.RouteFocusStore,
  runtime : @runtime.AppRuntime,
  route : String,
) -> Bool {
  runtime.restore_route_focus(store, route)
}
```

Recommended checks:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/showcase/app --target native
```

## Menus And Commands

Use `@core.ActionCommand` as the source of truth for command metadata. Render it
with `command_palette`, `command_menu`, or `menu_bar`; dispatch shortcuts with
`ActionCommandMap`. Disabled commands should stay visible but should not update
the model.

```moonbit nocheck
using @views {command_palette}

enum Msg { Dispatch(@core.CommandIntent) }

fn palette(commands : Array[@core.ActionCommand]) -> @moui.View[Msg] {
  command_palette(
    commands,
    query="",
    on_select=Dispatch,
  )
}
```

View-level menus are overlay compositions. Native context menus and focused text
clipboard commands should go through `HostServiceBridge` and `HostAppServices`
instead of `views`.

```moonbit nocheck
fn request_native_menu(
  services : @host.HostAppServices,
  commands : Array[@core.ActionCommand],
) -> @moui.Effect[Msg] {
  @moui.Effect::host_service(
    key="host:context-menu",
    label="Show context menu",
    run=dispatch => {
      let response = services.show_context_menu(commands)
      dispatch(HostMenuCompleted(response))
    },
  )
}
```

Recommended checks:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/command_palette/app --target native
```

## Host Services

Use `@host.HostAppServices` for clipboard, file dialogs, URL opening, system
theme, and native context menus. Effect-capable apps should return
`Effect::host_service` from `Program::new` updates when the host-service runner
should carry a stable diagnostic key, call the service from the effect runner,
and dispatch a typed completion message for `Unavailable`, synchronous
responses, and pending async completions. Use `Effect::run` for custom
structured effect kinds, `Effect::service_task` when a service-like one-shot
async task needs runtime-owned cancellation, completion, and stale-dispatch
diagnostics, and `Effect::task` for custom task descriptor kinds. For pending
app-owned services, store the pending request id in the model and declare
`HostAppServices::completion_subscription` from
`subscriptions=model => ...` so the later host callback re-enters the same
typed message loop and is canceled when the model no longer declares it.
`views` should only emit messages such as `BrowseRequested` or
`RecordFileDrop(paths)`. When a host-service workflow is implemented as a child
feature, lift the child view with `View::map`, lift the child effect with
`Effect::map`, and lift the child completion subscription with
`Subscription::map` in the parent so the parent still owns the top-level
message loop.

```moonbit nocheck
fn request_browse(
  services : @host.HostAppServices,
) -> @moui.Effect[ImportMsg] {
  @moui.Effect::host_service(
    key="host:file-import",
    label="Import files",
    run=dispatch => {
      let response = services.open_file(title="Import files", filters=["csv", "json"])
      dispatch(HostCompleted(file_dialog_completion(response)))
    },
  )
}
```

```moonbit nocheck
fn subscriptions(
  model : ImportModel,
  services : @host.HostAppServices,
) -> @moui.Subscription[ImportMsg] {
  match model.pending_request {
    Some(id) =>
      services.completion_subscription(
        id,
        map=completion => HostCompleted(completion),
        label="Import files completion",
      )
    None => @moui.Subscription::none()
  }
}
```

Web hosts may expose file names or browser handles while native hosts can expose
filesystem paths. Treat returned strings as host-provided import handles unless
the active platform contract says otherwise.

Recommended checks:

```sh
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test examples/file_importer/app --target native
moon test examples/showcase/app/platform --target native
```

## Timers

Use `@host.HostTimerSource` from the platform entrypoint and pass it into the
shared app as an optional dependency. Declare
`source.subscription(interval_ms, key, map)` only while the model needs the
tick (for example while a toast queue is non-empty or a stopwatch is running).
Missing keys cancel automatically when `subscriptions` no longer returns them.

```moonbit nocheck
fn subscriptions(
  model : LabModel,
  timer_source : @host.HostTimerSource?,
) -> @moui.Subscription[LabMsg] {
  match timer_source {
    Some(source) =>
      if model.timer_running {
        source.subscription(
          interval_ms=500.0,
          key="lab:timer",
          label="Lab timer",
          map=_ => TimerTick,
        )
      } else {
        @moui.Subscription::none()
      }
    None => @moui.Subscription::none()
  }
}
```

Platform entrypoints own the concrete source, for example
`@macos_host.macos_timer_source()` / `windows_timer_source` /
`linux_timer_source`. Web does not yet expose a host timer adapter.

Recommended checks:

```sh
moon test moui/backend/host --target native
moon test examples/showcase/app/platform --target native
moon test examples/markdown_editor/app --target native
```

## Clipboard

Clipboard is a host service, not a view. Write or read text through
`HostAppServices`, return `Effect::host_service`, and subscribe to pending
completions with `completion_subscription` the same way as file open.

```moonbit nocheck
fn write_clipboard(
  services : @host.HostAppServices,
  text : String,
) -> @moui.Effect[LabMsg] {
  @moui.Effect::host_service(
    key="host:clipboard-write",
    label="Write clipboard",
    run=dispatch => {
      dispatch(HostCompleted(services.write_clipboard_text(text)))
    },
  )
}
```

Recommended checks:

```sh
moon test moui/backend/host --target native
moon test examples/showcase/app/platform --target native
moon test examples/markdown_editor/app --target native
```

## Keyboard Commands

Prefer `@core.ActionCommand` / `@views.ActionCommandMap` installed on the
runtime (`AppRuntime::set_action_commands`) for discoverable shortcuts. Keep
disabled commands visible. Filter `HostEvent::Keyboard` only when you need
chords that are not part of the command map.

```moonbit nocheck
fn action_command_map() -> @views.ActionCommandMap {
  let command = @views.ActionCommand::new(
    intent=@views.CommandIntent::Activate,
    label="Lab tick",
    shortcut=Some(
      @views.KeyboardShortcut::new(
        key="t",
        modifiers=@views.KeyModifiers::new(meta=true),
      ),
    ),
    group="Showcase Platform",
  )
  @views.ActionCommandMap::new(
    bindings=[@views.CommandBinding::new(command~, handle=() => ())],
  )
}
```

Recommended checks:

```sh
moon test examples/command_palette/app --target native
moon test examples/showcase/app/platform --target native
```

## Window Resize

Hosts already apply resize to the surface. Apps that need the logical size in
the model should obtain `HostWindowEventSource` (usually via
`HostPlatformEventSources`) from host options and map
`HostEvent::Resized` into a message.

```moonbit nocheck
fn window_subscriptions(
  source : @host.HostWindowEventSource,
) -> @moui.Subscription[LabMsg] {
  source.subscription(
    key="lab:window",
    label="Lab window events",
    map=window_event =>
      match window_event.event {
        @host.HostEvent::Resized(metrics) =>
          Some(WindowResized(metrics.logical_size.width, metrics.logical_size.height))
        _ => None
      },
  )
}
```

Desktop Skia entrypoints pass `event_sources` through
`MacosHostAppOptions` / `WindowsHostAppOptions` / `LinuxHostAppOptions`.
Web uses `WebAppOptions::event_sources`.

Recommended checks:

```sh
moon test moui/backend/host --target native
moon test examples/showcase/app/platform --target native
```

## Effect Cheat Sheet

| Helper | Use when |
| --- | --- |
| `Effect::none` | Pure model update |
| `Effect::send` | Re-enter the message loop immediately |
| `Effect::host_service` | One-shot host bridge with diagnostics |
| `Effect::run` | Custom structured one-shot runner |
| `Effect::task` / `service_task` | Cancellable one-shot async with runtime lifecycle |

See [TEA program model](tea-program-model.md) for key/kind reuse rules and
stale-dispatch behavior.

## Application Menu Bar (L2 preview)

Menu levels:

| Level | API | Status |
| --- | --- | --- |
| L0 content menus | `menu_bar` / `command_menu` / `context_menu_region` | Ready (view overlays) |
| L1 context menu | `HostAppServices::show_context_menu` | Ready on menu-capable hosts |
| L2 application menu bar | `HostAppServices::set_application_menu` | macOS installs native menus; Windows/Linux/Web return `Unavailable` |

```moonbit nocheck
fn install_app_menu(services : @host.HostAppServices) -> Unit {
  let menu = @host.HostApplicationMenu::new(
    title="File",
    items=[
      @host.HostApplicationMenuItem::new(title="Open…", action_id=1),
      @host.HostApplicationMenuItem::separator(),
    ],
  )
  ignore(services.set_application_menu([menu]))
}
```

On macOS, install after the primary window is ready (`on_ready`) so the default
AppKit menu does not overwrite the custom bar. See Showcase's Platform workspace and
`examples/markdown_editor/macos_skia`.

## Toast Queues

Use `ToastQueue` and `ToastQueueItem` when an app needs predictable transient
notification state but still wants to own timers, host notifications, and retry
effects. The queue can convert directly to `toast_stack` items.

```moonbit nocheck
using @views {toast_stack}

enum Msg { RetrySync; DismissToast(String) }

fn notifications(now_ms : Double) -> @moui.View[Msg] {
  let queue = @views.ToastQueue::new(
    items=[
      @views.ToastQueueItem::new(
        id="sync",
        message="Sync queued for retry",
        tone=@views.FeedbackTone::Warning,
        action=Some(@views.StateViewAction::new(label="Retry", message=RetrySync)),
        dismiss=Some(DismissToast("sync")),
        created_at_ms=now_ms,
        ttl_ms=5000.0,
      ),
    ],
  )
  toast_stack(queue.expire(now_ms).to_stack_items())
}
```

Recommended checks:

```sh
moon test moui/views --target native
moon test examples/showcase/app --target native
```

## Virtual Lists

Use `virtual_list` and `sectioned_list` when app data is larger than the current
viewport. The helpers compute a visible window plus overscan and still return a
normal `View[Msg]`; renderer behavior does not change. Use `scroll_to_index` to
calculate a controlled offset, then store that offset in the app model.

```moonbit nocheck
using @views {scroll_view, virtual_list}

fn activity_list(
  rows : Array[Activity],
  scroll : @core.ScrollState,
) -> @moui.View[Msg] {
  scroll_view(
    virtual_list(
      rows,
      key=row => row.id,
      row=row => @views.text(row.title, height=28.0),
      state=scroll,
      item_height=32.0,
      viewport_height=360.0,
    ),
    state=Some(scroll),
    on_scroll=ActivityScrolled,
  )
}
```

Recommended checks:

```sh
moon test moui/views --target native
moon test moui/core --target native
```

## Keeping The Layers Honest

- Put reusable state contracts in `core`.
- Put renderer-neutral view constructors in `views`.
- Put platform requests in `backend/host` and active platform backends.
- Demonstrate user-facing workflows in Showcase or a shared `examples/*/app`
  package.
- Update `docs/view-catalog.md` when a public constructor or its semantics
  changes.
- Run `moon info` after public API changes and keep generated interface diffs
  with the implementing commit.
