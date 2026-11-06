# Views API 指南

MoUI 应用代码在编写普通 UI 时，应优先使用根 `moui` facade 加上 `views` 包。`core` 仍是更低层的 contract、layout、paint、rich text、geometry 和高级测试表面；runtime 构造属于 `moui/runtime`。

## 本地 DSL Import

在应用和示例 UI 包中，只 import 该包使用的 `views` 函数：

```moonbit
using @views { column, text, container, scroll_view }
```

MoonBit 包会在文件之间共享顶层标识符，因此多文件包应把这些 import 放在一个很小的包级 DSL 文件中，而不是在每个文件里重复同一个 `using` block。

然后调用这些函数时不带 `@views.` 前缀：

```moonbit
container(
  column([...], align=@views.CrossAlign::Start),
  variant=@views.ContainerVariant::Raised,
  theme~,
)
```

默认保持 enum 和 type 名称带限定前缀：

```moonbit
align=@views.CrossAlign::Start
variant=@views.ButtonVariant::Primary
variant=@views.ContainerVariant::Raised
```

这样 DSL 保持紧凑，同时让较大文件中的 `Start`、`Raised` 等 variant 名称保持明确。

## Descriptor Helper

许多可复用 view 会接收小型 descriptor 值，用于 action、menu、sidebar、breadcrumb、navigation card 和 selectable-list row。在 app DSL 代码中优先使用自由 helper constructor，让普通 view tree 读起来像组合：

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

然后在消费它们的 view 旁边构建 descriptor：

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

只有当 `Type::new` 形式能让类型标注或跨包 API 边界更清楚时才使用它。这样普通 app 包可以保持在 `moui + views` 上，同时让更低层的 runtime、host 和 renderer 包不出现在 view 代码中。

## 消息类型与 `View::map` 成本

`View::map` 在每次 view 调用时重建整个被包装子树：每层都会为每个节点重新创建 adapter、复制 children 与 semantics-handler 数组，并包装 event closure。原生 leaf benchmark 记录的是确定性结构成本：30 帧内，1k/10k 树的一层 map 会产生 30,060/300,060 次 adapter 复制；两层 map 翻倍。帧耗时只作为诊断，因为共享 runner 的波动大于该复制增量（`benchmarks/performance_budget/native/main.mbt`）。`full_cycle` 中的 `F-deep-click` 与 `G-deep-dblmap-click` 提供同一成本的 wall-clock 对照。

Program 顶层优先使用扁平的 `Msg` enum，并直接在 parent view（或普通构造 helper）中生成子消息，不要在 feature module 内层层嵌套 `map`。`map` 适合真实组合边界：把拥有独立 `Msg` 的 standalone feature view 挂到 app；但任意 root-to-leaf 路径上的 map 层数应保持很小。构造时的快照是已承诺的所有权契约（`from_node` 必须承受 producer 随后修改 `children` 数组，由 `moui/core/view_node_test.mbt` 固定），不是可以随意去掉的额外开销。ADR 0058 记录当前语言为什么无法安全实现非复制 transform chain；债务和重开条件位于 `docs/plans/debt/message-transform-chain.md`。

## 边界

普通 app authoring 使用 `views`：控件、layout、surface、scrolling 和简单组合。

平台入口 runtime 设置和 white-box runtime smoke 测试使用 `moui/runtime`。只有在需要低层 state 与 binding 类型、custom paint/layout、rich text model、geometry 计算，以及根 alias 或 `views` helper 未覆盖的高级测试断言时，才直接使用 `core`。

当自定义 layout 和 navigation destination 构造等高级 helper 让调用点更清楚时，可以继续写成带限定前缀的 `@views.*`。
