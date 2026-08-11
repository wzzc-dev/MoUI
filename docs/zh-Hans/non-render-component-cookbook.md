# 非渲染组件 Cookbook

本 cookbook 汇总了无需触碰 `moui/render/*`、无需添加绘制命令、也无需依赖具体渲染器即可
构建的应用层模式。通用规则是：把状态保存在应用模型中，用 `views` 构造器组合界面，
用 `core` 辅助函数处理运行时中立契约，并且只在服务确实属于平台时才跨入
`backend`。

## 表单

使用 `form`、`form_section` 和 `form_field` 构造布局与状态表面。将字段值、异步验证状态
和验证展示交给应用模型控制；当多个字段需要共享验证或首个无效字段路由时，使用
`@core.FormFieldState`、`required_field` 和 `FormController`。字段正在检查服务器或本地规则时，
使用 `FormFieldStatus::Validating`；提交需要移动焦点时，为字段视图设置 key，并在运行时可用后
从应用或宿主调用 `AppRuntime::focus_key`。

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

推荐检查：

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/settings/app --target native
```

## 数据表

将 `DataSortState`、`PaginationState`、`ColumnVisibilityState`、`SelectionState`、
`data_filter_bar`、`selection_toolbar`、`column_visibility_panel`、`table` 和
`pagination` 组合使用，构建运营数据表面。过滤、排序谓词、可见列、分页、行选择以及
loading/error/empty 状态都应位于应用模型中，使表格保持渲染器中立且行为可预测。

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

推荐检查：

```sh
moon test moui/views --target native
moon test examples/data_table/app --target native
```

## 导航 Shell

使用 `sidebar`、`breadcrumb`、`split_view`、`master_detail`、`wizard` 和
`router_stack` 描述导航结构。将当前路由保存在应用模型中，或保存在
`@core.RouterState` 中；当路由需要稳定恢复时，使用 `RouteLocation` 查询参数。
对于焦点恢复，在 `RouteFocusStore` 中记录 route-to-key 映射，为目标可聚焦视图设置 key，
并在路由渲染完成后调用 `runtime.restore_route_focus(store, route)`。

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

推荐检查：

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/showcase/app --target native
```

## 菜单与命令

使用 `@core.ActionCommand` 作为命令元数据的事实来源。用 `command_palette`、
`command_menu` 或 `menu_bar` 渲染它；用 `ActionCommandMap` 分发快捷键。
禁用命令应保持可见，但不应更新模型。

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

视图级菜单是叠层组合。原生上下文菜单和聚焦文本剪贴板命令使用
`@services.AppServices`；宿主 bridge 和 completion queue 留在平台适配器之后。

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

推荐检查：

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/command_palette/app --target native
```

## 宿主服务

在 Program 闭包中捕获 `@services.AppEnvironment`，不要把它放进业务 `Model`。
文件、剪贴板、URL、设置、外观和菜单操作返回 `ServiceTask[T]`；使用
`ServiceTask::effect` 把类型化的 `Success`、`Failure` 和 `Cancelled` 结果转换为
`Msg`。任务生命周期由 runtime 负责取消和拒绝 stale completion，因此应用代码既不保存
宿主 request id，也不订阅 completion queue。`views` 只应发出 `BrowseRequested` 或
`RecordFileDrop(paths)` 之类的消息。当宿主服务工作流是子功能时，在父级中用
`View::map` 提升子视图，并用 `Effect::map` 提升子 effect，使父级继续拥有顶层消息循环。

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

```moonbit nocheck
match msg {
  FileDialogCompleted(Success(path)) => add_file(model, path)
  FileDialogCompleted(Failure(error)) => { ..model, error: Some(error.message) }
  FileDialogCompleted(Cancelled) => { ..model, status: "Cancelled" }
  _ => model
}
```

Web 宿主可能暴露文件名或浏览器 handle，而原生宿主可以暴露文件系统路径。除非活动平台契约另有说明，
否则应把返回的字符串视为宿主提供的导入 handle。

推荐检查：

```sh
moon test moui/backend --target native
moon test moui/backend/web --target wasm-gc
moon test examples/file_importer/app --target native
moon test examples/showcase/app/platform --target native
```

## 定时器

平台 composition 在 `AppEnvironment` 中提供可选的 `@services.TimerSource`。Program 闭包
捕获 environment，仅在模型需要 tick 时声明 subscription；缺失的 key 会自动取消。

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

平台后端通过 `app_environment()` 暴露适配后的 source；scheduler 细节留在应用包之外。

推荐检查：

```sh
moon test moui/backend --target native
moon test examples/showcase/app/platform --target native
moon test examples/markdown_editor/app --target native
```

## 剪贴板

剪贴板是服务，不是视图。返回类型化 task effect，并在 `update` 中处理结果。

```moonbit nocheck
fn write_clipboard(
  services : @services.AppServices,
  text : String,
) -> @moui.Effect[LabMsg] {
  services
  .clipboard()
  .write_text(text)
  .effect(map=result => ClipboardWritten(result))
}
```

推荐检查：

```sh
moon test moui/backend --target native
moon test examples/showcase/app/platform --target native
moon test examples/markdown_editor/app --target native
```

## 键盘命令

优先使用安装在运行时（`Program::with_commands`）上的
`@core.ActionCommand` / `@views.ActionCommandMap` 来提供可发现的快捷键。保持禁用命令可见。
只有需要命令映射之外的组合键时，才过滤 `Event::Keyboard`。

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

推荐检查：

```sh
moon test examples/command_palette/app --target native
moon test examples/showcase/app/platform --target native
```

## 窗口调整大小

宿主已经将 resize 应用到 surface。需要在模型中使用逻辑尺寸的应用，应从宿主选项获取
`HostWindowEventSource`（通常通过 `HostPlatformEventSources`），并将
`Event::Resized` 映射为一条消息。

```moonbit nocheck
fn window_subscriptions(
  source : @host.HostWindowEventSource,
) -> @moui.Subscription[LabMsg] {
  source.subscription(
    key="lab:window",
    label="Lab window events",
    map=window_event =>
      match window_event.event {
        @host.Event::Resized(metrics) =>
          Some(WindowResized(metrics.logical_size.width, metrics.logical_size.height))
        _ => None
      },
  )
}
```

桌面 Skia 入口会通过 `MacosHostAppOptions` / `WindowsHostAppOptions` /
`LinuxHostAppOptions` 传入 `event_sources`。Web 使用 `WebAppOptions::event_sources`。

推荐检查：

```sh
moon test moui/backend --target native
moon test examples/showcase/app/platform --target native
```

## Effect 速查表

| 辅助函数 | 使用场景 |
| --- | --- |
| `Effect::none` | 纯模型更新 |
| `Effect::send` | 立即重新进入消息循环 |
| `ServiceTask::effect` | 带诊断的一次性宿主桥 |
| `Effect::run` | 自定义结构化一次性 runner |
| `Effect::task` / `service_task` | 带运行时生命周期的可取消一次性异步 |

关于 key/kind 复用规则和过期分发行为，见 [TEA 程序模型](tea-program-model.md)。

## 应用菜单栏（L2 preview）

菜单层级：

| 层级 | API | 状态 |
| --- | --- | --- |
| L0 内容菜单 | `menu_bar` / `command_menu` / `context_menu_region` | 就绪（视图叠层） |
| L1 上下文菜单 | `@services.MenuServices::show_context` | 支持菜单的宿主上就绪 |
| L2 应用菜单栏 | `@services.MenuServices::install_application` | macOS 安装原生菜单；Windows/Linux/Web 返回 `Unavailable` |

菜单项应复用传给 `Program::with_commands` 的同一组 `ActionCommand`：

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

模块根集成包通过
`environment.services().menus().install_application(...)` 安装菜单。在 macOS
上应等待主窗口就绪，避免 AppKit 默认菜单覆盖应用菜单。选择菜单项时，runtime
解析命令元数据，并将对应的 typed Program message 入队。

## Toast 队列

当应用需要可预测的临时通知状态，同时仍想拥有定时器、宿主通知和重试 effect 时，使用
`ToastQueue` 和 `ToastQueueItem`。队列可以直接转换为 `toast_stack` 条目。

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

推荐检查：

```sh
moon test moui/views --target native
moon test examples/showcase/app --target native
```

## 虚拟列表

当应用数据大于当前 viewport 时，使用 `virtual_list` 和 `sectioned_list`。这些辅助函数计算
可见窗口和 overscan，但仍返回普通 `View[Msg]`；渲染器行为不会改变。列表保持固定步长
`item_height + spacing`，因此滚动位置由应用拥有：把 `offset` 保存在应用模型中，
并通过 `on_scroll` 回喂新位置；程序化跳转用 `scroll_to_index` 构造 `ScrollRequest`。

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

/// 跳到第 10 行：用新的 id 应用请求。
fn jump_to_ten() -> @core.ScrollRequest {
  scroll_to_index(request_id=1, index=10, item_height=32.0)
}
```

推荐检查：

```sh
moon test moui/views --target native
moon test moui/core --target native
```

## 保持分层诚实

- 将可复用状态契约放在 `core`。
- 将渲染器中立的视图构造器放在 `views`。
- 将平台请求放在 `backend` 和活动平台后端中。
- 在 Showcase 或共享 `examples/*/app` 包中演示面向用户的工作流。
- 公共构造器或其语义变化时，更新 `docs/view-catalog.md`。
- 公共 API 变化后运行 `moon info`，并将生成的接口 diff 与实现提交一起保留。
