# 非渲染组件 Cookbook

本 cookbook 汇总了无需触碰 `moui/render/*`、无需添加绘制命令、也无需依赖具体渲染器即可
构建的应用层模式。通用规则是：把状态保存在应用模型中，用 `views` 构造器组合界面，
用 `core` 辅助函数处理运行时中立契约，并且只在服务确实属于平台时才跨入
`backend/host`。

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

视图级菜单是叠层组合。原生上下文菜单和聚焦文本剪贴板命令应通过
`HostServiceBridge` 和 `HostAppServices`，而不是通过 `views`。

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

推荐检查：

```sh
moon test moui/core --target native
moon test moui/views --target native
moon test examples/command_palette/app --target native
```

## 宿主服务

使用 `@host.HostAppServices` 处理剪贴板、文件对话框、URL 打开、系统主题和原生上下文菜单。
支持 effect 的应用应在宿主服务 runner 需要携带稳定诊断 key 时，从 `Program::new`
的 update 返回 `Effect::host_service`；从 effect runner 调用服务，并为 `Unavailable`、
同步响应和待完成异步响应分发带类型的完成消息。自定义结构化 effect 种类使用
`Effect::run`；当类似服务的一次性异步任务需要运行时拥有取消、完成和过期分发诊断时，
使用 `Effect::service_task`；自定义任务描述符种类使用 `Effect::task`。对于应用拥有的
pending 服务，把 pending request id 保存在模型中，并从 `subscriptions=model => ...`
声明 `HostAppServices::completion_subscription`，使后续宿主回调重新进入同一个带类型消息循环，
并在模型不再声明它时取消。`views` 只应发出 `BrowseRequested` 或
`RecordFileDrop(paths)` 之类的消息。当宿主服务工作流实现为子功能时，在父级中用
`View::map` 提升子视图，用 `Effect::map` 提升子 effect，并用 `Subscription::map`
提升子完成订阅，使父级仍然拥有顶层消息循环。

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

Web 宿主可能暴露文件名或浏览器 handle，而原生宿主可以暴露文件系统路径。除非活动平台契约另有说明，
否则应把返回的字符串视为宿主提供的导入 handle。

推荐检查：

```sh
moon test moui/backend/host --target native
moon test moui/backend/web --target wasm-gc
moon test examples/file_importer/app --target native
moon test examples/showcase/app/platform --target native
```

## 定时器

从平台入口使用 `@host.HostTimerSource`，并将其作为可选依赖传给共享应用。仅在模型需要
tick 时声明 `source.subscription(interval_ms, key, map)`（例如 toast 队列非空或秒表运行时）。
当 `subscriptions` 不再返回某个 key 时，缺失 key 会自动取消。

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

平台入口拥有具体 source，例如
`@macos_host.macos_timer_source()` / `windows_timer_source` /
`linux_timer_source`。Web 目前还没有暴露宿主定时器适配器。

推荐检查：

```sh
moon test moui/backend/host --target native
moon test examples/showcase/app/platform --target native
moon test examples/markdown_editor/app --target native
```

## 剪贴板

剪贴板是宿主服务，不是视图。通过 `HostAppServices` 写入或读取文本，返回
`Effect::host_service`，并像文件打开一样用 `completion_subscription` 订阅 pending 完成。

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

推荐检查：

```sh
moon test moui/backend/host --target native
moon test examples/showcase/app/platform --target native
moon test examples/markdown_editor/app --target native
```

## 键盘命令

优先使用安装在运行时（`AppRuntime::set_action_commands`）上的
`@core.ActionCommand` / `@views.ActionCommandMap` 来提供可发现的快捷键。保持禁用命令可见。
只有需要命令映射之外的组合键时，才过滤 `HostEvent::Keyboard`。

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
`HostEvent::Resized` 映射为一条消息。

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

桌面 Skia 入口会通过 `MacosHostAppOptions` / `WindowsHostAppOptions` /
`LinuxHostAppOptions` 传入 `event_sources`。Web 使用 `WebAppOptions::event_sources`。

推荐检查：

```sh
moon test moui/backend/host --target native
moon test examples/showcase/app/platform --target native
```

## Effect 速查表

| 辅助函数 | 使用场景 |
| --- | --- |
| `Effect::none` | 纯模型更新 |
| `Effect::send` | 立即重新进入消息循环 |
| `Effect::host_service` | 带诊断的一次性宿主桥 |
| `Effect::run` | 自定义结构化一次性 runner |
| `Effect::task` / `service_task` | 带运行时生命周期的可取消一次性异步 |

关于 key/kind 复用规则和过期分发行为，见 [TEA 程序模型](tea-program-model.md)。

## 应用菜单栏（L2 preview）

菜单层级：

| 层级 | API | 状态 |
| --- | --- | --- |
| L0 内容菜单 | `menu_bar` / `command_menu` / `context_menu_region` | 就绪（视图叠层） |
| L1 上下文菜单 | `HostAppServices::show_context_menu` | 支持菜单的宿主上就绪 |
| L2 应用菜单栏 | `HostAppServices::set_application_menu` | macOS 安装原生菜单；Windows/Linux/Web 返回 `Unavailable` |

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

在 macOS 上，应在主窗口就绪后（`on_ready`）安装，使默认 AppKit 菜单不会覆盖自定义菜单栏。
见 Showcase 的 Platform workspace 和 `examples/markdown_editor/macos_skia`。

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
可见窗口和 overscan，但仍返回普通 `View[Msg]`；渲染器行为不会改变。使用
`scroll_to_index` 计算受控偏移，然后把该偏移保存在应用模型中。

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

推荐检查：

```sh
moon test moui/views --target native
moon test moui/core --target native
```

## 保持分层诚实

- 将可复用状态契约放在 `core`。
- 将渲染器中立的视图构造器放在 `views`。
- 将平台请求放在 `backend/host` 和活动平台后端中。
- 在 Showcase 或共享 `examples/*/app` 包中演示面向用户的工作流。
- 公共构造器或其语义变化时，更新 `docs/view-catalog.md`。
- 公共 API 变化后运行 `moon info`，并将生成的接口 diff 与实现提交一起保留。
