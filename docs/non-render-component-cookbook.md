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

fn profile_form(name : String, error : String?) -> @core.View[Msg] {
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

fn focus_first_invalid(runtime : @core.AppRuntime) -> Bool {
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
) -> @core.View[Msg] {
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
        visible=visible_columns.visible,
        locked=visible_columns.locked,
        on_toggle=(id, shown) => ToggleColumn(id, shown),
      ),
      selection_toolbar(
        selected_count=selection.count(),
        total_count=rows.length(),
        actions=[@views.MenuItem::new(id="export", label="Export", message=ExportRows)],
        on_clear=Some(ClearSelection),
      ),
      table(
        columns,
        rows.map(row => [row.name, row.status]),
        selected_row=None,
        on_row_select=Some(index => SelectRow(index)),
        sort_column=sort.column,
        sort_ascending=sort.ascending,
        on_sort=Some(id => SortBy(id)),
        sortable_columns=["name", "status"],
        empty=Some(@views.empty_state("No projects", "No projects match the current filter.")),
      ),
      pagination(
        page=pagination_state.page,
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
`store.restore(runtime, route)` after the route has rendered.

```moonbit nocheck
using @views {master_detail, sidebar}

enum Msg { SelectSection(String) }

fn settings_shell(current : String, detail : @core.View[Msg]) -> @core.View[Msg] {
  let focus_store = @core.RouteFocusStore::new()
  focus_store.remember(route="account", focus_key="sidebar-item-account")
  focus_store.remember(route="appearance", focus_key="sidebar-item-appearance")
  master_detail(
    master=sidebar(
      "Settings",
      [
        @views.SidebarItem::new(id="account", label="Account", message=SelectSection("account")),
        @views.SidebarItem::new(id="appearance", label="Appearance", message=SelectSection("appearance")),
      ],
      selected=current,
    ),
    detail~,
  )
}

fn restore_settings_focus(
  store : @core.RouteFocusStore,
  runtime : @core.AppRuntime,
  route : String,
) -> Bool {
  store.restore(runtime, route)
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

fn palette(commands : Array[@core.ActionCommand]) -> @core.View[Msg] {
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
) -> @core.Effect[Msg] {
  @core.Effect::run(
    key="host:context-menu",
    kind="host-service",
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
`Effect::run` from `Program::new` updates when the runner should carry a stable
diagnostic key, call the service from the effect runner, and dispatch a typed
completion message for `Unavailable`, synchronous responses, and pending async
completions. Use `Effect::task` instead when a one-shot async task needs
runtime-owned cancellation, completion, and stale-dispatch diagnostics. For
pending app-owned services, store the pending request id in the model and
declare `HostAppServices::completion_subscription` from
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
) -> @core.Effect[ImportMsg] {
  @core.Effect::run(
    key="host:file-import",
    kind="host-service",
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
) -> @core.Subscription[ImportMsg] {
  match model.pending_request {
    Some(id) =>
      services.completion_subscription(
        id,
        map=completion => HostCompleted(completion),
        label="Import files completion",
      )
    None => @core.Subscription::none()
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
```

## Toast Queues

Use `ToastQueue` and `ToastQueueItem` when an app needs predictable transient
notification state but still wants to own timers, host notifications, and retry
effects. The queue can convert directly to `toast_stack` items.

```moonbit nocheck
using @views {toast_stack}

enum Msg { RetrySync; DismissToast(String) }

fn notifications(now_ms : Double) -> @core.View[Msg] {
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
) -> @core.View[Msg] {
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
sh scripts/conformance-check.sh --layout
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
