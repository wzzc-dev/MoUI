# View Catalog

`views` 包暴露面向用户的 constructor，用于构建 MoUI app。公开 constructor 返回不透明的 `@moui.View[Msg]`，因此 app 代码可以保持声明式，而 runtime 拥有 tree reconciliation、dirty state、layout、paint、input 和 semantics dispatch。新的内置具体控件在 `moui/views` 中实现 `@core.ViewNode`，并用 `@core.View::from_node` 构造类型化 view；`ViewSpec` 是历史名称，`ViewNode` 则是高级 core 扩展协议，不由面向 app 的 facade 重导出。

请把本 catalog 当作当前 view API 的支持矩阵。源码级细节仍在 `views/*.mbt` 中，生成的公开 API 摘要位于 `views/pkg.generated.mbti`。

面向任务的组合模式参见[非渲染组件 cookbook](../non-render-component-cookbook.md)。它展示如何在不改变 renderer surface 的情况下组装 form、data table、navigation shell、menu、host-service flow 和 virtual list。

Showcase 按以下顺序暴露当前面向用户的 catalog：`Overview -> Text & Media -> Controls -> Forms -> Data -> Layout -> Navigation Shell -> Feedback -> Runtime/Renderer -> Diagnostics`。更深层的 advanced rendering、text diagnostics、interaction diagnostics 和 reusable examples 路由，会作为聚焦诊断 destination 保留，而不是顶层 catalog row。

## API 风格

- Constructor 对常见选项使用 MoonBit labeled 和 optional parameter。
- TEA 优先控件接收普通值以及 `on_input`、`on_change` 或 `on_select` 回调。基于 binding 的 companion 保留 `*_binding` 后缀，用于 component-local 或高级状态。
- Descriptor-heavy helper 暴露自由 constructor，例如 `action_item`、`menu_item`、`sidebar_item`、`breadcrumb_item`、`section_nav_item`、`selectable_list_item`、`table_column` 和 `description_item`，这样普通 app DSL 代码不必把 view constructor 和 `Type::new` 仪式混在一起。
- Core 暴露 `FocusScope` helper，用于 app-owned focus 顺序、first-invalid form target，以及 Enter/Escape 默认动作 intent。Runtime element focus traversal 是单独的；app 可以对 keyed focusable view 调用 `AppRuntime::focus_key`，而 `RouteFocusStore` 会记录 route-to-focus-key restore target。`View::focus_trap` 把 Tab traversal 和 pointer focus 约束到 dialog/popover 组合的 view-level subtree 中。
- 视觉定制通常流经 `@moui.Theme` 上的 token group、style 类型，或 `.padding`、`.background`、`.title`、`.clip`、`.opacity` 等有序 modifier。Theme 定制应替换 `palette`、`typography`、`spacing_scale`、`radius_scale` 等 canonical group，而不是添加 theme-level alias field。
- File drop target 使用 `View::on_file_drop` modifier，让 app 可以把规范化的平台文件路径作为类型化消息接收，而不依赖 backend-specific event。
- 不应在 `views` 中添加平台特定行为；view 应把 UI intent 保持为 `@moui.View[Msg]` 和最终的 `@core.DrawCommand` 数据。
- View-level menu（`menu_bar`、`command_menu`、`context_menu_region`）是 overlay 和 button 组合。Native context-menu preview 通过 `@services.MenuServices::show_context` / `HostServiceBridge::ShowMenu` 流动。Application menu bar 是 L2 host preview，通过 `@services.MenuServices::install_application` 暴露（macOS 安装 native menu；Windows/Linux/Web 返回 `Unavailable`）。参见[非渲染 cookbook](../non-render-component-cookbook.md) 和 Showcase 的 Platform 工作区。

## Preview Control Baseline

该 baseline 按 app 作者通常最先需要的 workflow 对公开控件和可复用 app pattern 分组。它刻意是一个 preview 矩阵：`ready` 表示公开 `views` API 可用、下方已记录、有聚焦测试覆盖，并在 Showcase 中可见。`partial` 表示面向用户的 surface 已存在，但重要行为仍由 app、host 拥有，或比 SwiftUI/Flutter 风格预期更窄。`example-only pattern` 表示 workflow 在示例包中演示，但尚不是可复用的公开 constructor。`missing` 表示 catalog 不应暗示该能力存在。Catalog 本身保持 renderer-neutral：view helper 发出普通 core layout、event、semantics 和 draw-command surface。在当前 preview push 中，Showcase 和 Markdown Editor 原生 Skia 入口是首选 runtime consumer，用于证明这些 surface 在 Skia-first 原生 baseline 上仍然可用。

| Workflow | 当前状态 | 公开 surface | Showcase / 示例覆盖 | Preview 缺口 |
| --- | --- | --- | --- | --- |
| Forms | ready，validation 由 app 拥有 | `form`、`form_section`、`form_field`、`form_field_state`、`FormFieldStatus::Validating`、`form_validation_summary`、`form_actions`、`form_workflow_bar`、`form_error`、`form_helper_text`、`input_group`、`clearable_text_field`、`password_field`、`number_field`、`stepper`、`text_area`，以及 `text_field`、`checkbox`、`toggle`、`segmented_control`、`picker`、`datepicker` | Showcase Forms 和 Controls；Settings 示例 | Validation rule 和 async check 留在 app model 中；可复用 view/runtime helper 现在覆盖 validating/help/error state、keyed first-invalid focus target、submit guard 和 Enter/Escape action status。 |
| Navigation | ready，支持 controlled shell、app-owned route history、app-sampled route transition 和 route focus restoration | `navigation_stack`、`router_stack`、`route_header`、`section_nav`、`sidebar`、`breadcrumb`、`split_view`、`master_detail`、`resizable_split_view`、`wizard`、`tab_view`、`@views.RouteHistoryState`、`@views.RouteFocusStore`、`@services.RouteSource`、`View::transition`、`AppRuntime::focus_key` | Showcase Navigation Shell；views navigation/router 测试；Showcase route/state 测试；host route fanout 测试 | App-owned deep-link shadow history 已 preview-ready，通过可序列化 route stack、back/forward cursor 和 `RouterSnapshot` restoration 实现。`@services.RouteSource` 通过 `Subscription::route_event` 覆盖类型化 route/deep-link event fanout，但它不会自行修改 app history。Showcase 现在演示由 app state 采样的受控 fade/slide route transition；automatic transition scheduling、browser history、native URL bar 和 OS deep-link dispatch 仍是 app/host 后续工作。固定和受控拖拽可调整 split pane 已 preview-ready；app 仍拥有持久化 pane width。Route focus restoration 已 preview-ready，形式是在 route switch 后由 app/host 调用 runtime。 |
| Dialogs and menus | ready，支持 view-level + host context menu；L2 app menu preview | `dialog`、`alert`、`sheet`、`popover`、`dropdown`、`combobox`、`autocomplete`、`menu_button`、`menu_bar`、`command_menu`、`context_menu_region`、`command_palette`、`@views.ActionCommand`、`@views.CommandIntent`、`View::focus_trap`、`@services.MenuServices::show_context`、`@services.MenuServices::install_application`、`@services.ApplicationMenuPlacement` | Showcase Patterns 和 Platform 工作区；Command Palette；DSH Desktop | TEA-controlled view-level surface 和 host context-menu service preview 可用。macOS 支持顶层 menu-bar group 和标准应用菜单内的命令；Windows/Linux/Web 仍不可用。Host-modal deep binding 和 native accessibility adapter 仍是平台后续工作。 |
| Custom paint | ready，支持 canvas / custom_layout | `canvas`、`animated_canvas`、`custom_layout`、`custom_children_layout`、`PaintContext` helper | Showcase Diagnostics 和 Platform 工作区；PDF Workbench；教程 `06-animation` | 参见 [Canvas and custom paint](../canvas-and-custom-paint.md)。循环 canvas motion 可使用 `animated_canvas` + paint clock（`now_ms`）；model tick 仍使用 `@services.TimerSource` / `View::transition`。 |
| Data views | ready，data logic 由 app 拥有 | `DataSortState`、`PaginationState`、`ColumnVisibilityState`、`ColumnWidthState`、`ColumnOrderState`、`SelectionState`、`data_filter_bar`、`data_filter`、`selection_toolbar`、`action_item`、`table`、`table_column`、`column_visibility_panel`、`selectable_list`、`selectable_list_item`、`pagination`、`detail_panel`、`description_item`、`tree_view`、`description_list`、`avatar`、`avatar_group`、`virtual_list`、`sectioned_list`、`scroll_to_index`、`lazy_list`、`lazy_grid` | Showcase Data 和 Layout；升级后的 Data Table 示例 | Filtering rule、sorting rule、request lifecycle、row virtualization policy 和 pointer-specific table header interaction 目前留在 app 包中；可复用 helper 覆盖可预期的 sort、page、visibility、column width、column order 和 selection state。 |
| Feedback and workflow states | ready，状态由 app 拥有 | `ToastQueue`、`ToastQueueItem`、`toast`、`toast_stack`、`snackbar`、`banner`、`callout`、`progress_status`、`inline_error`、`empty_state`、`loading_state`、`error_state`、`status_badge`、`badge`、`stat_card`、`accordion`、`disclosure`、`collapsible_panel`、`drop_zone`、`file_import_panel` | Showcase Feedback 和 Interaction Lab；File Importer 示例 | Toast queue storage 有可复用 helper，而 timer、host notification、progress task lifecycle 和 native file-picker UX 仍由 app/host 拥有。 |
| Input, gestures, and accessibility | ready，preview semantics/focus 可用，native adapter 已跟踪 | `AppRuntime::focus_key`、`shortcut_button`、`focus_ring`、`FocusScope` helper、`View::focus_trap`、`@views.ActionCommand`、`@views.KeyboardShortcut`、keyboard shortcut dispatch、`View::on_long_press`、`View::on_double_tap`、`View::on_drag`、`View::on_drag_with_frame`，以及包括 disabled、pressed、selected、checked、expanded、invalid、required 和 action label 的 semantics role 与 state modifier | Showcase Interaction Lab 展示 focus order、first-invalid targeting、Enter/Escape command target、runtime focus trapping、shortcut、可见 app-owned focus ring、semantic state、gesture 和 file drop；Navigation Shell 展示 command metadata；Web ARIA 测试覆盖 disabled/action；host/native 测试保持 AccessKit tree/action roundtrip | Runtime focus traversal、key focus 和 view-level trapping 已 preview-ready。macOS menu、IME 和 drag/drop readiness 可通过 host capability diagnostics 观察；完整 native accessibility adapter 和 parity announcement 仍是后续工作。 |
| Native platform views | partial native host primitive | `web_view`、`@host.WebViewHost`、`@host.WebViewController`、`@host.WebViewEvent`、`@host.WebViewSecurityPolicy`、`@host.HostWebViewCapabilities` | `views/tests/smoke`；WebView Demo 示例 | `web_view` 参与 MoUI layout 和 semantics，但真实内容是 host-owned native WebView placement，并从 `DrawFrame.platform_views` 同步。它不是 `DrawCommand`，Web wasm 会报告 unavailable，而不是使用 iframe overlay。导航和 bridge 通信通过 controller task 发起，并由 host 校验。macOS 上，sibling WKWebView 保持可见，overlay 激活时透明 presenter 移到其上方；WebView 只在 view-level MoUI overlay bounds 内退出命中测试，因此 dialog、sheet 和 popover 可以接收 pointer input。其顶部 32 点是 drag/no-drag 区域，空白处拖动窗口，交互 DOM 控件和 `[data-moui-no-drag]` 元素仍可点击。Web、Windows 和 Linux 尚未提供这些 macOS 路径。除此之外 v1 只支持矩形 placement 和 clipping；transform、opacity、filter 和 rounded clipping 不适用于 native WebView。低层 WebView spec 和 platform-view placement 仍是 host integration 的 `core` contract。 |

```mbt nocheck
enum Msg { DraftChanged(String); SubmitDraft }

fn view(draft : String) -> @moui.View[Msg] {
  @views.column([
    @views.text("Todo"),
    @views.text_field(draft, on_input=DraftChanged, placeholder="New item"),
    @views.button("Add", on_click=SubmitDraft),
  ], spacing=8.0)
}
```

## Text And Media

| Constructor | Source | Theme | Semantics | Tests | 示例覆盖 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `text` | `views/views.mbt` | Font/foreground modifier | core 中的 Text role | `views/tests/smoke` | Showcase、Markdown Editor | 基础 label primitive。 |
| `image` | `views/views.mbt` | 基于 modifier | Image draw intent | `views/tests/smoke` | Showcase | Renderer image 支持在 capability report 中跟踪；Showcase Interaction Lab 覆盖 ready/loading/failed lifecycle state。 |
| `icon` | `views/views.mbt` | 基于 modifier | core 中的 Image role | `views/tests/smoke` | Showcase | 按 `IconName` 定尺寸的 icon glyph primitive，可选 color/weight override。 |
| `web_view` | `views/web_view.mbt` | Host native WebView | core 中的 WebView role | `views/tests/smoke`、WebView Demo app 测试 | WebView Demo | 受控 native WebView primitive。composition root 创建 `WebViewHost` 和 `WebViewController`；导航使用 `controller.navigate(url)`，controller task 覆盖 reload、stop、back、forward、JSON bridge message、request/response 和 dispose。经过校验的 `WebViewEvent` 通过 program effect/subscription path 返回。 |
| `canvas` | `views/canvas.mbt` | 基于 modifier | Group | `views/tests/smoke` | Showcase Platform 和 Diagnostics 工作区 | 纯绘制 view（带 `PaintContext` 的 `measure` + `draw`）。无 children。参见 [Canvas and custom paint](../canvas-and-custom-paint.md)。 |
| `custom_layout` / `custom_children_layout` | `views/views.mbt` | N/A | Group / child semantics | `views/tests/smoke` | PDF Workbench；Markdown Editor surface；Showcase | 用于高级控件的 custom measure/paint 和 multi-child layout delegate。 |

## Controls

| Constructor | Source | Theme | Semantics | Tests | 示例覆盖 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `button` | `views/button.mbt` | ButtonStyle | Button | `views/tests/smoke` | 所有示例 | 主要 activation primitive。 |
| `shortcut_button` | `views/button.mbt` | ButtonStyle/surface/text | 带 shortcut 描述的 Button | `views/tests/smoke` | Showcase Interaction Lab | 组合常规 button、可见 shortcut label、`View::keyboard_shortcut` 和 shortcut semantics，使 app-owned keyboard shortcut 保持可发现，并通过类型化消息循环 dispatch。 |
| `menu_button` | `views/control_focus_overlay.mbt` | ButtonStyle | Menu | `views/tests/smoke` | Showcase | 带 menu semantics 的 button wrapper。 |
| `checkbox` | `views/views.mbt` | ChoiceControlStyle，支持直接 font/color/size override | Checkbox | `views/tests/smoke` | Showcase Todo pattern | TEA 优先 boolean control。Component-local state 应在跨越公开 `views` API 边界前投影为显式值和类型化 `on_change` 消息。 |
| `toggle` | `views/control_choice.mbt` | ChoiceControlStyle，支持直接 color override | Switch | `views/tests/smoke` | Showcase | TEA 优先 switch control。 |
| `radio` | `views/control_choice.mbt` | ChoiceControlStyle，支持直接 color override | Radio | `views/tests/smoke` | Showcase | TEA 优先 single-option primitive。 |
| `text_field` | `views/views.mbt`、`views/text_input_controls.mbt` | TextFieldStyle | Text field | `views/tests/smoke`、core input 测试 | Showcase、Markdown Editor | TEA 优先 text input。App、host、smoke 和跨包测试应使用这个 `views` 入口，而不是直接使用 core control constructor。 |
| `searchbar` | `views/views.mbt`、`views/text_input_controls.mbt` | TextFieldStyle | Search field | `views/tests/smoke` | Showcase | 专用于过滤和 clear action 的 TEA 优先 text input。 |
| `picker` | `views/views.mbt` | PickerStyle | Picker | `views/tests/smoke` | Showcase | TEA 优先 option picker，其弹出层是真实的 overlay 子树：由 runtime placement pass 摆放（翻转并夹取到视口）、提升到祖先裁剪之上，并通过 layer stack 暴露语义与 Escape。 |
| `datepicker` | `views/datepicker.mbt` | PickerStyle | Date picker | `views/tests/smoke` | Showcase | TEA 优先 date picker，其日历面板是真实的 overlay 子树，由 runtime placement pass 摆放（翻转并夹取到视口）并支持 min/max range enforcement；逐日单元格语义仍是后续工作。 |
| `dropdown` / `combobox` / `autocomplete` | `views/popover_selectors.mbt` | ButtonStyle/TextFieldStyle/SurfaceStyle | 带 selected/disabled option state 的 expanded menu anchor | `views/tests/smoke` | Showcase Interaction Lab | 用 overlay、scroll view、button 和 text field 构建的受控 floating menu。Expansion、selected option、disabled option 和 toggle action 通过 semantics 暴露，而 state 和 filtering 留给 app 拥有。 |
| `menu_bar` / `command_menu` / `context_menu_region` | `views/views.mbt` | ButtonStyle/text/surface | 带 selected、disabled 和 expanded fallback state 的 Menu/group | `views/descriptor_helpers_test.mbt`、`views/tests/smoke` | Showcase Navigation Shell | 基于 `menu_item` descriptor 和 `@views.ActionCommand` metadata 的 TEA 优先 menu surface。Disabled command 会渲染但不 dispatch，fallback view menu 暴露 expanded/collapse semantics，而 native context menu 留在 host service 中。 |
| `radio_group` / `checkbox_group` | `views/choice_groups.mbt` | ChoiceControlStyle | 带 radio/checkbox children 的 Group | `views/tests/smoke` | Showcase Controls | 基于 `ChoiceItem` descriptor 构建的 TEA 优先 grouped selection。 |
| `segmented_control` | `views/choice_segmented.mbt` | ButtonStyle/SurfaceStyle | 类似 tab 的 group | `views/tests/smoke` | Showcase Controls | 受控 single-selection segmented button。 |
| `chip` / `tag` / `filter_chip` / `choice_chip` | `views/choice_chips.mbt` | SurfaceStyle/ButtonStyle | Button 或 text role | `views/tests/smoke` | Showcase Controls | 紧凑 selection 和 labeling control。 |
| `slider` | `views/control_slider.mbt` | SliderStyle，支持直接 color override，可选 `on_change` | Slider | `views/tests/smoke` | Showcase | Custom painted scalar control，通过 `on_change` 进行 TEA-controlled drag update；drag mapping 使用声明的 control width，因此拖拽期间 model rebuild 不会叠加 translation。 |
| `progress` | `views/control_progress.mbt` | ProgressStyle，支持直接 color override | Progress | `views/tests/smoke` | Showcase | Custom painted progress indicator。 |
| `focus_ring` | `views/control_focus_overlay.mbt` | Border/theme | 带 selected state 的 focusable group | `views/tests/smoke` | Showcase Interaction Lab | app-owned focus id 的视觉 wrapper。它暴露 focus action 以及 selected/unselected semantics；当 runtime Tab traversal 必须留在 dialog 或 popover subtree 内时，使用 `View::focus_trap`。 |
| `tooltip` | `views/control_focus_overlay.mbt` | SurfaceStyle | 可见时的 Tooltip | `views/tests/smoke` | Showcase Interaction Lab | 用可选 overlay 包装 child。 |
| `View::on_long_press` / `View::on_double_tap` / `View::on_drag` / `View::on_drag_with_frame` | `core/view.mbt` | N/A | Button-like activation metadata | `core/gesture_action_wbtest.mbt`、`core/state_holder_wbtest.mbt`、`views/tests/smoke` | Showcase Interaction Lab | 指针事件之上的高级 gesture wrapper；recognizer state 保留在 core/runtime 中，disabled ancestor 会抑制 activation。`View::on_drag_with_frame` 还会传入已布局 content frame，用于 frame-relative controlled widget。 |
| `View::transition` / `View::presence` | `core/view.mbt` | N/A | present 时保留 child semantics | `core/animation_wbtest.mbt` | Showcase visual card | 将 `TransitionSpec` 采样进现有 opacity、offset、scale 和 foreground modifier；`presence` 会保持 exiting content mounted，直到 controlled progress 完成，并尊重 reduced motion。 |

## Feedback And States

| Constructor | Source | Theme | Semantics | Tests | 示例覆盖 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `ToastQueue` / `ToastQueueItem` | `views/feedback_state.mbt` | N/A | N/A | `views/tests/smoke` | Showcase Feedback | 纯 app-owned state helper，用于 transient notification。App push、expire，并把 queued item 转成 `ToastStackItem` row，而 timer 和 host notification 留在 `views` 之外。 |
| `toast` / `toast_stack` / `snackbar` | `views/feedback_transient.mbt` | FeedbackStyle | 带可选 dismiss action 的 Group | `views/tests/smoke` | Showcase Feedback | App-owned transient/status surface。`toast_stack` 渲染 app-owned notification queue，支持可选 per-item action 和 dismiss 消息；`ToastQueue` 可提供这些 row，而 timer 留在 app model 中。 |
| `banner` / `callout` | `views/feedback_guidance.mbt` | FeedbackStyle | Group | `views/tests/smoke` | Showcase Feedback | 带可选 action 的 inline status 和 guidance surface。 |
| `progress_status` | `views/feedback_progress.mbt` | FeedbackStyle/ProgressStyle/ButtonStyle/BadgeStyle | 带嵌套 progress 和 status badge 的 Group | `views/tests/smoke` | Showcase Feedback | App-owned task progress card，包含 title、`status_badge`、message、progress bar 和可选 action。Task lifecycle 和 progress value 留在 app model 中。 |
| `inline_error` | `views/feedback_status.mbt` | FeedbackStyle/BadgeStyle/ButtonStyle | Invalid group | `views/tests/smoke` | Showcase Feedback | 面向 full state panel 之外的 app-owned validation 或 workflow failure 的紧凑 inline error row。 |
| `empty_state` / `loading_state` / `error_state` | `views/feedback_status.mbt` | FeedbackStyle | Group | `views/tests/smoke` | Showcase Feedback | 使用可选 `StateViewAction` 的可复用 workflow state panel。 |
| `status_badge` / `badge` / `stat_card` | `views/feedback_badge.mbt` | BadgeStyle/FeedbackStyle | 带显式 status label 的 Text/group | `views/tests/smoke` | Showcase Feedback | `status_badge` 用 `Status: ...` accessibility label 和可选 detail description 包装紧凑 status text。`badge` 仍是通用 metadata chip，`stat_card` 覆盖紧凑 metric。 |
| `presence_dot` | `views/views.mbt` | Theme colors | core 中的 Image role | `views/tests/smoke` | Showcase Data | Fluent 2 PresenceBadge 状态点（Available/Away/Busy/Offline/Unknown），是带对比 border 的实心圆，可覆盖在 avatar 上。 |
| `drop_zone` / `file_import_panel` | `views/file_import.mbt` | Surface/button/text | Button-like drop target/group | `views/tests/smoke` | Showcase Interaction Lab | Drag/drop 通过 `View::on_file_drop` 映射；browse button 发出 app 消息，使应用可以调用 `AppServices::files().open_file(...)`，并用 `ServiceTask::effect` 把 typed result 转为 `Msg`，而不让 `views` 依赖 backend 包或向 model 暴露 request id。Web host 可以暴露浏览器文件名或 handle，而 native host 可以暴露 filesystem path。 |

## Data Display

| Constructor | Source | Theme | Semantics | Tests | 示例覆盖 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `description_list` | `views/data_display.mbt`、`views/data_display_state.mbt` | Text/theme spacing | Group | `views/tests/smoke` | Showcase Data | 来自 `DescriptionItem` descriptor 的 term/detail metadata row。 |
| `data_filter_bar` / `data_filter` | `views/data_filter_bar.mbt`、`views/data_filter_state.mbt` | Search field/chips/ButtonStyle | 带 selected/disabled filter chip 的 Group | `views/tests/smoke` | Showcase Data、Data Table | 表格和列表 surface 的受控 search/filter toolbar。Query、selected filter、result count 和 clear policy 由 app 拥有。 |
| `DataSortState` / `PaginationState` / `ColumnVisibilityState` / `ColumnWidthState` / `ColumnOrderState` / `SelectionState` | `views/data_sort_pagination.mbt`、`views/data_table_visibility_state.mbt`、`views/data_table_width_state.mbt`、`views/data_table_order_state.mbt`、`views/data_selection_state.mbt` | N/A | N/A | `views/tests/smoke` | Showcase Data、Data Table | 常见 data workflow 的纯 app-owned helper：sort toggle、page clamp 与 slicing bound、visible/locked column、clamped column width、column order 和 selected id。它们的 storage 保持不透明；app 通过聚焦 method 观察和更新，而不是 field access。它们有意不拥有 filtering predicate、request、timer、pointer-specific header gesture 或 bulk effect。 |
| `selection_toolbar` | `views/data_selection_toolbar.mbt` | ButtonStyle/text/surface | 带 selected state 的 Group | `views/tests/smoke` | Showcase Data、Data Table | 受控 selected-row summary，带 `ActionItem` bulk action button 和可选 clear action。App 通常传入 `SelectionState::count()`，并在 app model 中保留 selected row id 和 action effect。 |
| `table` / `table_column` | `views/data_table.mbt`、`views/data_table_rendering.mbt`、`views/data_table_state.mbt` | Surface/text/border/ButtonStyle | 带 selectable row item 和可选 sortable header button 的 Grid | `views/tests/smoke` | Showcase Data、Data Table | 受控 text table，支持可选 custom cell view、selected row、row-select message、sortable header state 和 empty state；`DataSortState`、`ColumnWidthState` 和 `ColumnOrderState` 可驱动 header state、width 和 order，而 sorting rule、filtering 和 persistence 留给 app 拥有。 |
| `column_visibility_panel` | `views/data_filter_column_visibility.mbt` | Checkbox/text/surface | 带 selected 和 disabled column item 的 Group | `views/tests/smoke` | Showcase Data、Data Table | 面向 table workflow 的受控 column visibility chooser。`ColumnVisibilityState` 通过 accessor 暴露 visible 和 locked id；当 table workflow 还需要 app-owned resizing 和 reordering 时，把它与 `ColumnWidthState` 和 `ColumnOrderState` 配对。 |
| `selectable_list` | `views/data_selectable_list.mbt`、`views/data_selection_state.mbt` | Surface/text/ButtonStyle | 带 selected/disabled list item 的 List | `views/descriptor_helpers_test.mbt`、`views/tests/smoke` | Showcase Data | 从 `selectable_list_item` descriptor、title/subtitle/detail row、selected id、disabled row、类型化 item message 和 empty state 构建的受控 application data list。Filtering、grouping 和 selected-id storage 由 app 拥有。 |
| `pagination` | `views/data_pagination.mbt` | ButtonStyle/text | 带 disabled edge button 的 Group | `views/tests/smoke` | Showcase Data、Data Table | 受控 pagination bar；`PaginationState` 可以 clamp page 并暴露 slicing bound，而 page indexing 和 data slicing 仍由 app 拥有。 |
| `detail_panel` | `views/data_display.mbt` | Surface/text/ButtonStyle | Group | `views/tests/smoke` | Showcase Data、Data Table | 由 `DescriptionItem` row、可选 empty content 和可选 action 构建的紧凑 selected-record detail。 |
| `tree_view` / `tree_item` | `views/data_tree.mbt`、`views/data_tree_state.mbt` | Button/text | List/list item | `views/tests/smoke` | Showcase Data | 从 expanded id 和 selected id 进行受控 tree rendering；toggle/select message 由 app 提供。 |
| `avatar` / `avatar_group` | `views/data_avatar.mbt` | Theme colors/image | Labeled image/text group | `views/tests/smoke` | Showcase Data | Initials 或 image avatar，以及紧凑 overflow group。 |

## Forms

| Constructor | Source | Theme | Semantics | Tests | 示例覆盖 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `form` / `form_section` | `views/form_layout.mbt` | Theme spacing/surface | Group | `views/tests/smoke` | Showcase Forms | grouped TEA-controlled field 的 layout shell。 |
| `form_field` | `views/form_field.mbt`、`views/form_field_support.mbt` | Theme typography/colors | 带 accessibility label 的 Group | `views/tests/smoke` | Showcase Forms | 在不改变 renderer 的情况下组合 label、required marker、helper text、validation message、validating、disabled 和 read-only state。`FormFieldStatus::Validating` 会宣布 checking state，而 async validation 由 app 拥有。 |
| `form_field_state` | `views/form/form_field_state.mbt` | Theme typography/colors | 带 accessibility label 的 Group | `views/form/form_validation_test.mbt` | Showcase Forms | 将 `@views.FormFieldState` validation 桥接进 view helper，同时保留直接 string-error constructor。 |
| `form_validation_summary` | `views/form_validation.mbt` | FormValidationStyle/text/ButtonStyle | Invalid group | `views/tests/smoke` | Showcase Forms | 渲染 app/core-owned `FormValidationSummary`，包含 first-invalid state、field error 和可选 focus/review action。Validation rule 和 focus orchestration 留在 view helper 之外。 |
| `form_actions` | `views/form_workflow.mbt` | ButtonStyle/surface/text | 带 disabled action state 的 Group | `views/tests/smoke` | Showcase Forms | 可复用 save/cancel action row，支持可选 status text 和 app-controlled disabled submit state。Validation 和 submit policy 留在 app model 中。 |
| `form_workflow_bar` | `views/form_workflow.mbt` | FormValidationStyle/surface/text/ButtonStyle | 带 invalid state 的 Group | `views/tests/smoke` | Showcase Forms | 将 validation summary、first-invalid focus action、`FocusScope` Enter/Escape target status 和 submit-guarded action row 组合成一个可复用 form footer。实际 focus movement 仍由 app/runtime 拥有。 |
| `form_error` / `form_helper_text` | `views/form_support_text.mbt` | FormValidationStyle/theme typography/colors | Text | `views/tests/smoke` | Showcase Forms | app-local form layout 的可复用 support text helper。`form_error` 可以消费中立 validation style，而 `form_helper_text` 保持 muted-theme text。 |
| `input_group` | `views/input_group_shell.mbt` | Theme surface/border | Child semantics | `views/tests/smoke` | Showcase Forms | app-owned input 的 prefix/suffix shell。 |
| `clearable_text_field` / `password_field` | `views/views.mbt` | TextFieldStyle/ButtonStyle | Text field 加 button semantics | `views/tests/smoke` | Showcase Forms | 受控 wrapper；password reveal state 仍由 app 拥有。 |
| `number_field` / `stepper` | `views/input_number.mbt` | TextFieldStyle/ButtonStyle | Text field 和 button semantics | `views/tests/smoke` | Showcase Forms | 保持 parsing 和 numeric state 在 app model 中。 |
| `text_area` | `views/text_area.mbt` | TextFieldStyle | Text field semantics | `views/tests/smoke` | Showcase Forms | 用于 multi-line layout 的固定高度 text area，不添加 editor engine。 |

## Layout And Containers

| Constructor | Source | Theme | Semantics | Tests | 示例覆盖 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `container` / `card` | `views/views.mbt` | SurfaceStyle | 通过 child 形成 Group | `views/tests/smoke` | Counter、Showcase、Markdown Editor | Styled container primitive；`card` 是简单 app 的 raised、padded 入口。 |
| `empty` | `views/views.mbt` | N/A | None | `views/tests/smoke` | Showcase | optional/slot composition 的 zero-size placeholder leaf。 |
| `toolbar` / `command_bar` / `button_group` / `status_bar` | `views/toolbar.mbt` | ButtonStyle/text/surface | Group | `views/descriptor_helpers_test.mbt`、`views/tests/smoke`、Showcase 测试 | Showcase Navigation Shell | 从 `action_item` descriptor、button、text 和 surface 构建的 app-owned command 和 status surface。 |
| `command_palette` | `views/views.mbt` | ButtonStyle/text/surface | Menu | `views/tests/smoke`、`core/gesture_action_wbtest.mbt`、Showcase 测试 | Showcase Navigation Shell | 将 `@views.ActionCommand` metadata（`group`、`description`、shortcut label、enabled state）渲染成 TEA-controlled palette，无需 native menu 或 renderer 变化。 |
| `row` / `column` | `views/views.mbt` | 基于 child/modifier | 通过 children 形成 Group/list | `views/tests/smoke` | 所有示例 | Flex layout primitive。 |
| `center` | `views/views.mbt` | 可选 background | Child semantics | `views/tests/smoke` | Counter | 单 child layout helper，将内容居中放在可用空间中。 |
| `spacer` | `views/views.mbt` | N/A | None | `views/tests/smoke` | Showcase | Flexible space primitive。 |
| `divider` | `views/views.mbt` | Theme colors/thickness | core 中的 Separator | `views/tests/smoke` | Showcase | 水平/垂直 divider line，支持可选 thickness、color 和 inset。 |
| `frame` | `views/views.mbt` | N/A | Child semantics | `views/tests/smoke` | Showcase | Constraint wrapper。 |
| `padding` / `padding_insets` | `views/views.mbt` | N/A | Child semantics | `views/tests/smoke`、`core/advanced_layout_test.mbt` | 所有示例 | 有序 layout modifier wrapper。 |
| `padding_edges` / `padding_xy` | `views/views.mbt` | N/A | Child semantics | `views/tests/smoke` | Showcase | 基于同一个有序 modifier 的 per-edge 和 symmetric horizontal/vertical padding convenience wrapper。 |
| `stack` / `overlay` | `views/views.mbt` | 基于 child/modifier | Children preserved | `views/tests/smoke` | Showcase、Dialog host、Tooltip | Overlay layout primitive。 |
| `popover` | `views/popover_overlay.mbt` | SurfaceStyle | Anchor 加可选 overlay content | `views/tests/smoke` | Showcase Interaction Lab | 使用现有 stack、align 和 container primitive 的 view-level floating overlay。可选 `trap_focus=true` 路径应用 `View::focus_trap`；默认情况下 popover 保持 non-modal。Native context menu 通过 host service。 |
| `scroll_view` | `views/views.mbt` | N/A | Child semantics | `views/tests/smoke`、`core/advanced_layout_test.mbt` | Showcase、Markdown Editor | 通过 core 发出 clip/offset 行为，并可通过 `on_scroll` 报告 wheel delta。 |
| `grid` | `views/views.mbt` | N/A | Children preserved | `views/tests/smoke` | Showcase | 固定列 layout。 |
| `list` | `views/views.mbt` | N/A | 通过 core 的 List/list item role | `views/tests/smoke`、`core/semantics_test.mbt` | Showcase Todo pattern | Eager list layout。 |
| `lazy_list` | `views/views.mbt` | N/A | List output | `views/tests/smoke` | Showcase | 从 data 取窗口可见 row。 |
| `lazy_grid` | `views/views.mbt` | N/A | List/grid output | `views/tests/smoke` | Showcase | 从 data 取窗口可见 grid row。 |
| `virtual_list` / `sectioned_list` / `scroll_to_index` | `views/views.mbt`、`views/views.mbt` | N/A | List output | `views/tests/smoke`、Showcase 测试 | Showcase Layout | 基于现有 scroll/list primitive 的 overscanned windowed list、grouped section header、empty state 和 controlled offset intent。 |
| `accordion` / `disclosure` / `collapsible_panel` | `views/views.mbt` | ButtonStyle/surface/text | Group | `views/tests/smoke`、Showcase 测试 | Showcase Feedback | 受控 disclosure container；expanded state 和 toggle behavior 留在 app model 中。 |
| `resizable_panel` | `views/views.mbt` | SurfaceStyle | Group | `views/tests/smoke`、Showcase 测试 | Showcase Layout | 带视觉 handle 和可选 drag callback 的 controlled-size panel；app 仍拥有 size value。 |

## Navigation And Presentation

| Constructor | Source | Theme | Semantics | Tests | 示例覆盖 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `navigation_destination` | `views/views.mbt` | N/A | N/A | `views/tests/smoke` | N/A | navigation stack 的 route/view pair。 |
| `navigation_stack` / `navigation_stack_selected` | `views/views.mbt` | 基于 child | Selected child semantics | `views/tests/smoke` | N/A | 从 `NavigationState` 或 TEA-owned route string 中选择一个 view。 |
| `router_stack` | `views/views.mbt` | 基于 child | Selected child semantics | `views/tests/smoke`、`views/navigation/navigation_routing_test.mbt` | N/A | 从 `@views.RouterState` 中选择 destination，保留 query param 和 restoration snapshot，同时保持在 renderer 之上。 |
| `@views.RouteHistoryState` / `RouteHistoryEntry` | `views/navigation/navigation_routing.mbt` | N/A | N/A | `views/navigation/navigation_routing_test.mbt`、Showcase 测试 | Showcase Navigation Shell | App-owned、可序列化 route/deep-link history，带 back/forward cursor、新 push 时截断 forward，以及 `RouterSnapshot` restoration。它不会自行更新 browser history 或 native URL/deep-link handler。 |
| `route_header` | `views/navigation_route_header.mbt` | Surface/text/ButtonStyle | Group | `views/tests/smoke`、Showcase 测试 | Showcase Navigation Shell | 受控 page header，用于 app-owned route title、subtitle 和 `ActionItem` button；routing、deep link 和 history 留在 view helper 之外。 |
| `section_nav` | `views/navigation_section_nav.mbt` | ButtonStyle/text/surface | 带 selected/disabled list item 的 List | `views/descriptor_helpers_test.mbt`、`views/tests/smoke`、Showcase 测试 | Showcase Navigation Shell | 从 `section_nav_item` descriptor 构建的受控 section switcher。App 拥有 selected id、routing effect、history 和 unavailable-section policy。 |
| `sidebar` / `breadcrumb` | `views/navigation_sidebar.mbt`、`views/navigation_breadcrumb.mbt` | ButtonStyle/text/surface | List/group | `views/descriptor_helpers_test.mbt`、`views/tests/smoke`、Showcase 测试 | Showcase Navigation Shell | 从 `sidebar_item` 和 `breadcrumb_item` descriptor 加上 button、text 和 surface primitive 构建的受控 navigation shell helper。 |
| `split_view` / `master_detail` / `resizable_split_view` | `views/navigation_split.mbt` | 基于 child | 带可选 drag handle 的 Group | `views/tests/smoke`、Showcase 测试 | Showcase Navigation Shell | 面向 master/detail layout 的 fixed-width 和 controlled drag-resizable shell composition。`resizable_split_view` 通过 `on_drag` 发出 clamp 后 primary width；app model 仍拥有 persistence、snapping 和 route-specific pane sizing。 |
| `wizard` / `wizard_step` | `views/navigation_presentation.mbt` | ButtonStyle/surface | 带 tab-like step button 的 Group | `views/tests/smoke`、Showcase 测试 | Showcase Navigation Shell | 使用 `WizardStep` descriptor 和 app-owned current step 的受控 wizard workflow。 |
| `tab_item` | `views/views.mbt` | N/A | N/A | `views/tests/smoke` | Showcase | Tab descriptor。 |
| `tab_view` | `views/views.mbt` | ButtonStyle default | Tab button | `views/tests/smoke` | Showcase | TEA 优先 tab selection。 |
| `dialog` | `views/dialog_shell.mbt` | SurfaceStyle/ButtonStyle | Dialog | `views/tests/smoke`、Showcase 测试 | Showcase Navigation Shell | 可复用 custom-content dialog shell，包含 title、subtitle、可选 primary/secondary action 和可选 dismiss action。用 `PresentationSpec(kind=Dialog)` 放进 `overlay_host` 呈现；host-modal semantics 仍是后续工作。 |
| `alert` | `views/dialog_alert.mbt` | SurfaceStyle/ButtonStyle | Dialog | `views/tests/smoke`、Showcase 测试 | Showcase | 可复用 alert content，带 primary 和可选 secondary action；用 `PresentationSpec(kind=Dialog)` 放进 `overlay_host` 呈现。 |
| `sheet` | `views/popover/sheet.mbt` | Brush、radius、shadow | Sheet presentation | `views/tests/smoke` | Showcase | 可复用 sheet content。用 `PresentationSpec(kind=Sheet)` 放进 `overlay_host` 呈现；不存在第二个 sheet host。Presented sheet 默认应用 focus trap，而 host-modal deep binding 仍是平台后续工作。 |

## Theme And Environment

| Constructor | Source | Theme | Semantics | Tests | 示例覆盖 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `theme` | `views/views.mbt` | 创建 Theme | N/A | `views/tests/smoke` | Showcase | 自定义 `@moui.Theme` token 的 convenience constructor，包含 palette、spacing、radius、typography、shadow、motion，以及在可选 base theme 上的 surface override。 |
| `environment` | `views/views.mbt` | 创建 Environment | N/A | `views/tests/smoke` | Showcase | Runtime environment helper。Showcase Runtime 还显示注入的 `@host.HostCapabilitySummary`，让 app 无需依赖 renderer 包即可比较 service、input、window、text-input、IME、drag/drop、async-service 和 accessibility readiness。 |
| `light_theme` / `dark_theme` | `views/views.mbt` | 创建 Theme | N/A | `views/tests/smoke` | Showcase | Convenience theme preset。 |
| `default_theme` | `views/views.mbt` | 创建 Theme | N/A | `views/tests/smoke` | Showcase | 未提供 ambient theme 时使用的中立 fallback theme；`light_theme`/`dark_theme` 会在其上解析 Minimal preset。 |
| `@material.light_theme` / `@carbon.light_theme` / `@primer.light_theme` / `@fluent.light_theme` / package `dark_theme` / `high_contrast_theme` / `system_theme` / package `tokens` / `tokens_for_variant` / `report` / `manifest` / `component_token_matrix` / shared `@common.custom` / `@common.custom_tokens` / `DesignPreset::*_report` shared resolver APIs | `moui_theme/common/*.mbt`、`moui_theme/material/theme.mbt`、`moui_theme/carbon/theme.mbt`、`moui_theme/primer/theme.mbt`、`moui_theme/fluent/theme.mbt` | 通过 package entrypoint 创建 source-mapped official-system preview Theme 值，并暴露共享 semantic/component token 和 report model | N/A | `moui_theme/material/theme_test.mbt`、official-system entrypoint package 测试、Design Systems 测试 | Design Systems 示例 | MoUI 的可选 design-system addon。Material、Carbon、Primer 和 Fluent 通过各自 package-local entrypoint 请求；`moui_theme/common` 拥有共享 token struct、source/golden/coverage/report model、resolver helper 和 generic customization helper。当前外部系统保持 source-mapped preview，直到测试证明 full official source import、stable source lock、official-token anchor coverage、token taxonomy parity、semantic palette parity、typography parity、density/variant parity、component-token matrix coverage、runtime token alignment、customization parity、adaptation closure 和 golden/source-import integrity。View 仍只消费 `@moui.Theme` 或中立 style contract。 |
| `@sickle.light_theme` / `@sickle.dark_theme` / `@sickle.skeuo_theme` / `@sickle.flat_theme` / `@sickle.hybrid_theme` / `@sickle.palette` | `moui_theme/sickle/theme.mbt` | 创建一方 Sickle Theme 值 | N/A | `moui_theme/sickle/theme_test.mbt` | Addon package 测试 | Smartisan-inspired 混合视觉主题，具备精确桌面拟物和扁平 semantic control。`Hybrid` 和 `Skeuo` 模式使用分层 surface gradient、更强 shadow、内嵌 text-field focus edge 和 metal/cream neutral ramp；`Flat` 模式保持相同 Sickle red brand palette，同时移除 depth 和 shadow。它是 MoUI theme addon，不是 source-mapped official design-system preset。 |

`DesignPreset::semantic_palette_role_report` 位于 `moui_theme/audit/design_system_semantic_palette.mbt`，会把 semantic palette 分解为 foreground/background/surface/primary/status/focus/scrim role row。这些 row 将每个 `DesignSemanticPalette` 字段关联到中立 `@core.ColorPalette` 或 `@core.SemanticColorScale` destination、存在时的直接 official token/source-import coverage，以及当 preset 只有更宽泛 token-group adapter 时的显式 role-level parity gap。

`DesignPreset::typography_role_report` 位于 `moui_theme/audit/design_system_typography.mbt`，会把 typography 分解为 body/title/caption/control role row。这些 row 将每个 `DesignTypographyTokens` font slot 关联到中立 `@core.TypographyScale` destination、存在时的直接 official token/source-import alignment，以及 line-height 等导入 source property 目前还没有中立 `FontSpec` field 时的显式 destination gap。

`DesignPreset::component_token_matrix` row 暴露每个 component 的 mapped 和 required token count，以及相关 pinned source-import 和 runtime-aligned coverage count。这些 coverage count 刻意与 mapped/required matrix 分开，因此 source-import 进展可以展示出来，而不会声称完整 official component matrix 已闭合。

`DesignSystemTokens::core_component_styles`、`DesignButtonTokens::core_styles`、`DesignTextFieldTokens::core_styles`、`DesignSurfaceComponentTokens::core_styles`、`DesignChoiceControlTokens::core_style`、`DesignProgressTokens::core_style`、`DesignSliderTokens::core_style`、`DesignPickerTokens::core_style`、`DesignFeedbackTokens::core_style`、`DesignBadgeTokens::core_style` 和 `DesignFormValidationTokens::core_style` 将 component-token override 暴露为中立 `@core` style contract；text-field token 包含解析后的 font，因此 custom design-system token bundle 可以把 typography 带入 text-field style conversion，而不向 `core` 或 `views` 添加 design-system 名称。通用 `views` 控件、feedback/status surface、badge 和 validation helper 可以通过可选 `style`、`badge_style` 或 `progress_style` 参数消费这些中立 style contract，同时仍默认使用普通 `@moui.Theme`。

## Advanced Helpers

| Constructor | Source | Theme | Semantics | Tests | 示例覆盖 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| `expanded` / `flexible` | `views/views.mbt` | N/A | Child semantics | `views/tests/smoke` | Showcase | Flex child modifier。 |
| `layout_priority` | `views/views.mbt` | N/A | Child semantics | `views/tests/smoke`、`core/advanced_layout_test.mbt` | Showcase | 为 custom layout delegate 提供 priority metadata。 |
| `wrap` / `flow` / `responsive_grid` / `baseline_form_rows` | `views/layout_flow.mbt`、`views/views.mbt`、`views/views.mbt` | N/A | Group | `views/tests/smoke`、Showcase 测试 | Showcase Layout | 用 `custom_children_layout` 构建 responsive wrapping、adaptive grid column 和 baseline-aligned form row；无需 renderer 变化。 |
| `align` | `views/views.mbt` | N/A | Child semantics | `views/tests/smoke`、`core/advanced_layout_wbtest.mbt` | Showcase、Dialog host、Tooltip | 使用请求的 alignment 将 child 放入 parent frame。 |
| `aspect_ratio` | `views/views.mbt` | N/A | Child semantics | `views/tests/smoke` | Showcase | Ratio constraint wrapper。 |
| `intrinsic_width` / `intrinsic_height` | `views/views.mbt` | N/A | Child semantics | `views/tests/smoke` | Showcase | Intrinsic measurement wrapper。 |
| `custom_layout` | `views/views.mbt` | Caller-defined | Caller-defined | `views/tests/smoke` | Showcase Advanced Rendering | 构建 custom `View[Msg]`；Showcase 用它发出 layer/blend、filter、shader、path、transform 和 opacity draw command。 |
| `custom_children_layout` | `views/views.mbt` | Caller-defined | Caller-defined | `views/tests/smoke`、`core/advanced_layout_wbtest.mbt` | Showcase | 构建 custom child-layout `View[Msg]`，带 child size、baseline、priority 和 placement callback。 |
| `component` | `views/views.mbt` | 基于 ComponentContext | Built child semantics | `views/tests/smoke` | 通过 app component 的示例 | 包装 `@core.Component::new`。 |

## 维护清单

添加或修改公开 view constructor 时：

1. 保持 constructor 位于 `views/`，并返回 `@moui.View[Msg]`。
2. 将可复用的具体 custom view 行为放在 `moui/views`；尽可能复用现有 style、binding 和 modifier。
3. 在 `views/tests/smoke` 中添加或更新聚焦测试。
4. 当 view 面向用户且具有视觉意义时，添加 Showcase 覆盖。
5. 如果 API、theme support、semantics 或 example coverage 变化，更新本 catalog。
6. 公开 API 变化后运行 `moon info`，并审阅 `views/pkg.generated.mbti`。

不要从 `moui` 或 `moui/views` 重导出 `ViewNode`，也不要为新 widget 添加 `@core.View::primitive_*_view` constructor、`ViewLoweringSink` 或 runtime lowering arm。
