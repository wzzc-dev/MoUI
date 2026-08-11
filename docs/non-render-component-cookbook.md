# Non-Render Component Cookbook

This cookbook collects the app-level patterns that can be built without touching
`moui/render/*`, adding draw commands, or depending on a concrete renderer.
The common rule is: keep state in the app model, use `views` constructors for
composition, use `core` helpers for runtime-neutral contracts, and cross into
`backend` only for services that truly belong to the platform.

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
  let focus_store = @views.RouteFocusStore::new()
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
  store : @views.RouteFocusStore,
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
clipboard commands use `@services.AppServices`; host bridges and completion
queues stay behind the platform adapter.

```moonbit nocheck
fn request_native_menu(
  services : @services.AppServices,
  commands : Array[@core.ActionCommand],
) -> @moui.Effect[Msg] {
  services
  .menus()
  .show_context(commands)
  .effect(map=result => HostMenuCompleted(result))
}
```

Recommended checks:

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/command_palette/app --target native
```

## Host Services

Capture `@services.AppEnvironment` in the Program closure and keep it out of
business `Model` data. Files, clipboard, URLs, settings, appearance, and menus
return `ServiceTask[T]`; convert the typed `Success`, `Failure`, and
`Cancelled` results to `Msg` with `ServiceTask::effect`. The task runtime
owns cancellation and stale completion rejection, so app code never stores a
host request id or subscribes to a completion queue.

```moonbit nocheck
fn request_browse(
  services : @services.AppServices,
) -> @moui.Effect[ImportMsg] {
  services
  .files()
  .open_file(
    options=@services.FileDialogOptions::new(
      title="Import files",
      filters=["csv", "json"],
    ),
  )
  .effect(map=result => FileDialogCompleted(result))
}
```

Handle all terminal results in `update`:

```moonbit nocheck
match msg {
  FileDialogCompleted(Success(path)) => add_file(model, path)
  FileDialogCompleted(Failure(error)) => { ..model, error: Some(error.message) }
  FileDialogCompleted(Cancelled) => { ..model, status: "Cancelled" }
  _ => model
}
```

When a service workflow is a child feature, lift its view with `View::map` and
its effect with `Effect::map`. Web hosts may return browser handles while
native hosts may return filesystem paths; treat the value according to the
active service contract.

Recommended checks:

```sh
moon test moui/services --target native
moon test moui/backend --target native
moon test examples/file_importer/app --target native
moon test examples/showcase/app/platform --target native
```

## Timers

Platform composition supplies an optional `@services.TimerSource` in
`AppEnvironment`. Capture the environment in the Program closure and declare a
subscription only while the model needs ticks. Missing keys cancel
automatically.

```moonbit nocheck
fn subscriptions(
  model : LabModel,
  environment : @services.AppEnvironment,
) -> @moui.Subscription[LabMsg] {
  match environment.timer() {
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

Platform backends expose `app_environment()`; timer scheduler details stay
outside the app package.

Recommended checks:

```sh
moon test moui/services --target native
moon test examples/showcase/app/platform --target native
moon test examples/markdown_editor/app --target native
```

## Clipboard

Clipboard is a service, not a view. Return the typed task effect and handle its
result in `update`.

```moonbit nocheck
fn write_clipboard(
  services : @services.AppServices,
  value : String,
) -> @moui.Effect[LabMsg] {
  services
  .clipboard()
  .write_text(value)
  .effect(map=result => ClipboardWritten(result))
}
```

Recommended checks:

```sh
moon test moui/services --target native
moon test examples/showcase/app/platform --target native
moon test examples/markdown_editor/app --target native
```

## Keyboard Commands

Declare discoverable shortcuts as typed `ProgramCommand[Msg]` values with
`Program::with_commands`. Runtime maps keyboard, system-menu, and context-menu
selection to the same FIFO Program queue; command callbacks do not mutate the
model directly.

```moonbit nocheck
fn program() -> @moui.Program[LabModel, LabMsg] {
  @moui.Program::simple(init=LabModel::new(), update~, view~)
  .with_commands(commands=model => [
    @moui.ProgramCommand::new(
      command=@views.ActionCommand::new(
        intent=@views.CommandIntent::Activate,
        label="Lab tick",
        shortcut=Some(
          @views.KeyboardShortcut::new(
            key="t",
            modifiers=@views.KeyModifiers::new(meta=true),
          ),
        ),
        group="Lab",
        enabled=model.timer_running,
      ),
      message=TimerTick,
    ),
  ])
}
```

Recommended checks:

```sh
moon test moui/core --target native
moon test moui/runtime --target native
moon test examples/command_palette/app --target native
```

## Window Resize

Hosts already apply resize to the surface. Apps that need the logical size in
the model should obtain `HostWindowEventSource` (usually via
`HostPlatformEventSources`) from host options and map
`Event::Resized` into a message.

```moonbit nocheck
fn window_subscriptions(
  source : @runtime.HostWindowEventSource,
) -> @moui.Subscription[LabMsg] {
  source.subscription(
    key="lab:window",
    label="Lab window events",
    map=window_event =>
      match window_event.event {
        @backend.Event::Resized(metrics) =>
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
moon test moui/backend --target native
moon test examples/showcase/app/platform --target native
```

## Effect Cheat Sheet

| Helper | Use when |
| --- | --- |
| `Effect::none` | Pure model update |
| `Effect::send` | Re-enter the message loop immediately |
| `ServiceTask::effect` | Typed app service with cancellation/stale lifecycle |
| `Effect::run` | Custom structured one-shot runner |
| `Effect::task` / `service_task` | Cancellable one-shot async with runtime lifecycle |

See [TEA program model](tea-program-model.md) for key/kind reuse rules and
stale-dispatch behavior.

## Application Menu Bar (L2 preview)

Menu levels:

| Level | API | Status |
| --- | --- | --- |
| L0 content menus | `menu_bar` / `command_menu` / `context_menu_region` | Ready (view overlays) |
| L1 context menu | `MenuServices::show_context` | Ready on menu-capable hosts |
| L2 application menu bar | `MenuServices::install_application` | macOS installs native menus; other hosts may return `Unavailable` |

Build menu items from the same `ActionCommand` values used by
`Program::with_commands`:

```moonbit nocheck
fn application_menus(
  open : @views.ActionCommand,
) -> Array[@services.ApplicationMenu] {
  [
    @services.ApplicationMenu::new(title="File", items=[
      @services.ApplicationMenuItem::MenuCommand(open),
      @services.ApplicationMenuItem::MenuSeparator,
    ]),
  ]
}
```

The module-root integration package installs menus through
`environment.services().menus().install_application(...)`. On macOS, install
after the primary window is ready so AppKit does not replace the menu. Selection
resolves the command metadata and enqueues the matching typed Program message.

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
normal `View[Msg]`; renderer behavior does not change. The list keeps a fixed
stride `item_height + spacing`, so the app owns the scroll position: keep the
`offset` in the app model and feed new positions back through `on_scroll`, and
use `scroll_to_index` to build a `ScrollRequest` for programmatic jumps.

```moonbit nocheck
using @views {virtual_list, scroll_to_index}

fn activity_list(
  rows : Array[Activity],
  scroll_offset : @core.Point,
) -> @moui.View[Msg] {
  virtual_list(
    rows,
    key=row => row.id,
    row=row => @views.text(row.title, height=28.0),
    item_height=32.0,
    viewport_height=360.0,
    offset=scroll_offset,
    on_scroll=ActivityScrolled,
  )
}

/// Jump to row 10: apply the request with a fresh id.
fn jump_to_ten() -> @core.ScrollRequest {
  scroll_to_index(request_id=1, index=10, item_height=32.0)
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
- Put platform requests in `backend` and active platform backends.
- Demonstrate user-facing workflows in Showcase or a shared `examples/*/app`
  package.
- Update `docs/view-catalog.md` when a public constructor or its semantics
  changes.
- Run `moon info` after public API changes and keep generated interface diffs
  with the implementing commit.
