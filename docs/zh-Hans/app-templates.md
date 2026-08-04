# 应用模板

## 产品路径：`moui new`

对于新的独立多平台应用，使用 CLI（不要手工复制 monorepo 树）：

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

`moui new` 会生成：

```text
app/                 # shared TEA app
web_wasm/            # browser entrypoint
macos_skia|windows_skia|linux_skia/   # host desktop
# optional mobile with --platform + --bundle-id
```

见 [入门](getting-started.md) 的 B 节和 `moui_cli/README.md`。

## 文档支撑的骨架

下面的骨架在扩展 monorepo 的 `examples/<name>/app` 包或解释 TEA 形状时仍然有用。
独立项目优先使用 CLI。每个模板都保持平台入口分离：先从共享应用包开始，添加包内测试，
然后只有在共享模型已经被覆盖后，才添加 Web/原生入口。

## 共享应用包

```text
examples/<name>/app/
  moon.pkg
  app.mbt
  <name>_app_test.mbt
  pkg.generated.mbti
```

最小 `moon.pkg`：

```moonbit
import {
  "wzzc-dev/moui",
  "wzzc-dev/moui/views",
}

options(
  targets: { },
)
```

默认共享应用 imports 应保持为 `moui + views`。只有当应用调用宿主服务时才添加
`"wzzc-dev/moui/backend/host"`；当运行时 smoke 需要时，把 `runtime` 放在平台入口
或仅测试 imports 中；只有低层诊断或高级框架契约需要时才添加 `core`；如果该包属于本仓库，
将其添加到 `moon.work`。

## Counter

将此模板用于最小的 TEA-first 应用：一个模型、一个消息枚举、纯 `update`、声明式 `view`，
以及供平台入口使用的 `Program` 工厂。

`app.mbt`：

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

`counter_app_test.mbt`：

```moonbit
///|
test "counter update changes model" {
  let model = update(Model::new(), Increment)
  inspect(model.count, content="1")
  inspect(update(model, Reset).count, content="0")
}
```

平台入口在共享应用包外构造运行时：

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

将此模板用于需要导航、过滤器、数据显示和工作流状态，但不需要自定义渲染的运营工具。

推荐 imports：

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

模型形状：

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

视图 shell：

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

表格主体：

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

推荐检查：

```sh
moon test moui/views --target native
moon test examples/data_table/app --target native
moon test examples/showcase/app --target native
```

## Document Editor

将此模板用于需要可编辑文档状态、命令、菜单和宿主服务的应用。将文档解析和保存状态保留在应用包中；
仅将宿主服务用于 open/save 对话框、剪贴板、URL 打开和原生上下文菜单等平台操作。

推荐 imports：

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

模型和命令：

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

视图 shell：

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

应用服务 effect 模式：

```moonbit
///|
pub fn EditorModel::update_with_services(
  self : EditorModel,
  msg : EditorMsg,
  services : @services.AppServices,
) -> (EditorModel, @moui.Effect[EditorMsg]) {
  match msg {
    BrowseForDocument =>
      (
        self,
        services
        .files()
        .open_file(
          options=@services.FileDialogOptions::new(
            title="Open document",
            filters=["md", "txt"],
          ),
        )
        .effect(map=result => OpenDocumentCompleted(result)),
      )
    OpenDocumentCompleted(Success(path)) => (self.open(path), @moui.Effect::none())
    OpenDocumentCompleted(Failure(error)) =>
      ({ ..self, error: Some(error.message) }, @moui.Effect::none())
    OpenDocumentCompleted(Cancelled) =>
      ({ ..self, status: "Open cancelled" }, @moui.Effect::none())
    SourceChanged(source) => ({ ..self, source, dirty: true }, @moui.Effect::none())
    _ => (self, @moui.Effect::none())
  }
}

///|
pub fn EditorModel::program(
  self : EditorModel,
  environment : @services.AppEnvironment,
) -> @moui.Program[EditorModel, EditorMsg] {
  let services = environment.services()
  @moui.Program::new(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => model.update_with_services(message, services),
    view=model => model.view(),
  )
  .with_commands(commands=model => model.program_commands())
}
```

推荐检查：

```sh
moon test moui/views --target native
moon test moui/backend/host --target native
moon test examples/markdown_editor/app --target native
moon test examples/command_palette/app --target native
```

## 模板检查清单

- 先把 `Model`、`Msg`、`update`、`view` 和 `program` 放在共享应用包中。
- 为纯 update 行为添加包内测试；只有在验证运行时接线或诊断时，才添加运行时 smoke。
- 保持平台入口轻薄且不包含业务逻辑。
- 保持普通恢复由应用拥有；只有低层恢复 store 或其他高级框架契约才显式添加
  `wzzc-dev/moui/core`。平台服务使用 `@services.AppServices`。
- 添加包后运行 `moon info`，并将生成的 `pkg.generated.mbti` 与模板派生应用一起提交。
