# App Templates

## Product path: `moui new`

For a new independent multiplatform app, use the CLI (not hand-copied monorepo
trees):

```sh
moon install wzzc-dev/moui_cli/cmd/moui
moui new my_app
# Optional minimal skeleton:
# moui new my_app --template hello
cd my_app
moon update
moon check
moon run macos_skia --target native   # or windows_skia / linux_skia
```

`moui new` generates:

```text
app/                 # shared TEA app
web_wasm/            # browser entrypoint
macos_skia|windows_skia|linux_skia/   # host desktop
# optional mobile with --platform + --bundle-id
```

See [Getting started](getting-started.md) section B and `moui_cli/README.md`.

## Docs-backed skeletons

The skeletons below remain useful when extending the monorepo
`examples/<name>/app` packages or explaining TEA shape. Prefer the CLI for
standalone projects. Each template keeps platform entrypoints separate: start
with a shared app package, add package-local tests, then add Web/native
entrypoints only when the shared model is already covered.

## Shared App Package

```text
examples/<name>/app/
  moon.pkg
  app.mbt
  <name>_app_test.mbt
  pkg.generated.mbti
```

Minimal `moon.pkg`:

```moonbit
import {
  "wzzc-dev/moui",
  "wzzc-dev/moui/views",
}

options(
  targets: { },
)
```

Default shared app imports should stay at `moui + views`. Add
`"wzzc-dev/moui/backend/host"` only when the app calls host services, keep
`runtime` in platform entrypoints or test-only imports when a runtime smoke
needs it, add `core` only for low-level diagnostics or advanced framework
contracts, and add the package to `moon.work` when it is part of this
repository.

## Counter

Use this for the smallest TEA-first app: one model, one message enum, pure
`update`, declarative `view`, and a `Program` factory for platform entrypoints.

`app.mbt`:

```moonbit
///|
using @views {button, card, center, column, row, text}

///|
pub struct Model {
  count : Int
}

///|
pub(all) enum Msg {
  Increment
  Decrement
  Reset
}

///|
pub fn Model::new() -> Model {
  { count: 0 }
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { count: model.count + 1 }
    Decrement => { count: model.count - 1 }
    Reset => { count: 0 }
  }
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  center(
    card(
      column([
        text("Counter").title(),
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

///|
pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new(), update~, view~)
}
```

`counter_app_test.mbt`:

```moonbit
///|
test "counter update changes model" {
  let model = update(Model::new(), Increment)
  inspect(model.count, content="1")
  inspect(update(model, Reset).count, content="0")
}
```

Platform entrypoints construct the runtime outside the shared app package:

```moonbit
///|
fn main {
  @web.run_app(
    "MoUI Counter",
    @runtime.new_program_with_dimensions(
      program=@counter_app.program(),
      width=520.0,
      height=360.0,
    ),
  )
}
```

## Dashboard

Use this for operational tools that need navigation, filters, data display, and
workflow states without custom rendering.

Recommended imports:

```moonbit
///|
using @views {
  action_item,
  banner,
  button,
  column,
  column_visibility_panel,
  data_filter,
  data_filter_bar,
  empty_state,
  error_state,
  pagination,
  row,
  selection_toolbar,
  sidebar,
  sidebar_item,
  split_view,
  stat_card,
  table,
  table_column,
  text,
  tree_item,
  tree_view,
}
```

Model shape:

```moonbit
///|
pub(all) enum LoadState {
  Loading
  Ready
  Empty
  Failed(String)
}

///|
pub(all) struct DashboardModel {
  route : String
  query : String
  visible_columns : Array[String]
  selected_row : Int?
  selected_count : Int
  page : Int
  page_count : Int
  load_state : LoadState
  rows : Array[Array[String]]
}

///|
pub(all) enum DashboardMsg {
  SelectRoute(String)
  QueryChanged(String)
  ClearFilters
  ToggleStatusFilter
  ToggleColumn(String, Bool)
  SelectRow(Int)
  SortBy(String)
  ClearSelection
  ExportRows
  PreviousPage
  NextPage
  RetryLoad
}
```

View shell:

```moonbit
///|
pub fn DashboardModel::view(self : DashboardModel) -> @moui.View[DashboardMsg] {
  let columns = [
    table_column(id="name", label="Name", width=220.0),
    table_column(id="status", label="Status", width=140.0),
  ]
  split_view(
    primary=sidebar(
      "Dashboard",
      [
        sidebar_item(id="overview", label="Overview", message=SelectRoute("overview")),
        sidebar_item(id="reports", label="Reports", message=SelectRoute("reports")),
      ],
      selected=self.route,
    ),
    detail=column([
      row([
        stat_card("Open", "24"),
        stat_card("Blocked", "3", tone=@views.FeedbackTone::Warning),
      ]),
      data_filter_bar(
        query=self.query,
        on_query=QueryChanged,
        filters=[
          data_filter(id="blocked", label="Blocked", selected=false, message=ToggleStatusFilter),
        ],
        result_count=self.rows.length(),
        on_clear=Some(ClearFilters),
      ),
      row([
        column_visibility_panel(
          columns,
          visible=self.visible_columns,
          locked=["name"],
          on_toggle=(id, visible) => ToggleColumn(id, visible),
          width=280.0,
        ),
        selection_toolbar(
          selected_count=self.selected_count,
          total_count=self.rows.length(),
          actions=[action_item(id="export", label="Export", message=ExportRows)],
          on_clear=Some(ClearSelection),
        ),
      ], spacing=12.0),
      self.table_body(columns),
      pagination(
        page=self.page,
        page_count=self.page_count,
        on_previous=PreviousPage,
        on_next=NextPage,
      ),
    ], spacing=12.0),
    primary_width=240.0,
    detail_width=640.0,
    height=520.0,
  )
}
```

Table body:

```moonbit
///|
fn DashboardModel::table_body(
  self : DashboardModel,
  columns : Array[@views.TableColumn],
) -> @moui.View[DashboardMsg] {
  match self.load_state {
    Loading => @views.loading_state("Loading rows")
    Empty => empty_state("No rows", "Try another filter.")
    Failed(message) => error_state("Load failed", message~)
    Ready => table(
      columns,
      self.rows,
      selected_row=self.selected_row,
      on_row_select=Some(index => SelectRow(index)),
      sort_column="name",
      on_sort=Some(id => SortBy(id)),
      sortable_columns=["name", "status"],
    )
  }
}
```

Recommended checks:

```sh
moon test moui/views --target native
moon test examples/data_table/app --target native
moon test examples/showcase/app --target native
```

## Document Editor

Use this for apps that need editable document state, commands, menus, and host
services. Keep document parsing and save state in the app package; use host
services only for platform operations such as open/save dialogs, clipboard, URL
opening, and native context menus.

Recommended imports:

```moonbit
///|
using @views {
  action_item,
  button,
  column,
  command_menu_section,
  command_bar,
  command_menu,
  command_palette,
  context_menu_region,
  markdown_editor,
  menu_item,
  menu_bar,
  status_bar,
  text,
}
```

Model and commands:

```moonbit
///|
pub(all) struct EditorModel {
  title : String
  source : String
  dirty : Bool
  command_query : String
  palette_open : Bool
}

///|
pub(all) enum EditorMsg {
  SourceChanged(String)
  TogglePalette
  CommandQueryChanged(String)
  DispatchCommand(@views.CommandIntent)
  BrowseForDocument
  HostCompleted(@host.HostCompletedServiceResponse)
}

///|
pub fn EditorModel::commands(self : EditorModel) -> Array[@views.ActionCommand] {
  [
    @views.ActionCommand::new(
      intent=@views.CommandIntent::Submit,
      label="Save Document",
      group="File",
      description="Persist the current document.",
    ),
    @views.ActionCommand::new(
      intent=@views.CommandIntent::OpenContextMenu,
      label="Open Document",
      group="File",
    ),
  ]
}
```

View shell:

```moonbit
///|
pub fn EditorModel::view(self : EditorModel) -> @moui.View[EditorMsg] {
  let editor = markdown_editor(
    self.source,
    format_markdown,
    on_input=SourceChanged,
    placeholder="Write Markdown...",
  )
  let menu = command_menu(
    [command_menu_section(title="File", commands=self.commands())],
    on_select=DispatchCommand,
  )
  context_menu_region(
    child=column([
      menu_bar([
        menu_item(id="open", label="Open", message=BrowseForDocument),
        menu_item(id="save", label="Save", message=DispatchCommand(@views.CommandIntent::Submit)),
      ]),
      command_bar([
        action_item(id="open", label="Open", message=BrowseForDocument),
        action_item(id="commands", label="Commands", message=TogglePalette),
      ]),
      editor,
      status_bar([if self.dirty { "Unsaved" } else { "Saved" }]),
      if self.palette_open {
        command_palette(
          self.commands(),
          query=self.command_query,
          on_select=DispatchCommand,
        )
      } else {
        text("")
      },
    ], spacing=8.0),
    menu~,
    visible=self.palette_open,
  )
}
```

Host service effect pattern:

```moonbit
///|
pub fn EditorModel::update_with_services(
  self : EditorModel,
  msg : EditorMsg,
  services : @host.HostAppServices,
) -> (EditorModel, @moui.Effect[EditorMsg]) {
  match msg {
    BrowseForDocument =>
      (
        self,
        @moui.Effect::host_service(
          key="host:open-document",
          label="Open document",
          run=dispatch => {
            let response = services.open_file(title="Open document", filters=["md", "txt"])
            dispatch(HostCompleted(file_dialog_completion(response)))
          },
        ),
      )
    DispatchCommand(intent) => (self.dispatch_command(intent, services), @moui.Effect::none())
    SourceChanged(source) => ({ ..self, source, dirty: true }, @moui.Effect::none())
    HostCompleted(completion) => (self.apply_host_completion(completion), @moui.Effect::none())
    _ => (self, @moui.Effect::none())
  }
}

///|
pub fn EditorModel::program_with_services(
  self : EditorModel,
  services : @host.HostAppServices,
) -> @moui.Program[EditorModel, EditorMsg] {
  @moui.Program::new(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => model.update_with_services(message, services),
    view=model => model.view(),
    subscriptions=model => model.subscriptions(services),
  )
}

///|
pub fn EditorModel::subscriptions(
  self : EditorModel,
  services : @host.HostAppServices,
) -> @moui.Subscription[EditorMsg] {
  match self.pending_host_request {
    Some(id) =>
      services.completion_subscription(
        id,
        map=completion => HostCompleted(completion),
        label="Open document completion",
      )
    None => @moui.Subscription::none()
  }
}
```

Recommended checks:

```sh
moon test moui/views --target native
moon test moui/backend/host --target native
moon test examples/markdown_editor/app --target native
moon test examples/command_palette/app --target native
```

## Template Checklist

- Keep `Model`, `Msg`, `update`, `view`, and `program` in the shared app
  package first.
- Add package-local tests for pure update behavior; add a runtime smoke only
  when validating runtime wiring or diagnostics.
- Keep platform entrypoints thin and free of business logic.
- Keep ordinary restoration app-owned; add `wzzc-dev/moui/core` explicitly
  only for low-level restore stores or other advanced framework contracts.
  Use `@host.HostAppServices` for platform services.
- Run `moon info` after adding a package and commit the generated
  `pkg.generated.mbti` with the template-derived app.
