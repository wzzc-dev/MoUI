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

## 边界

普通 app authoring 使用 `views`：控件、layout、surface、scrolling 和简单组合。

平台入口 runtime 设置和 white-box runtime smoke 测试使用 `moui/runtime`。只有在需要低层 state 与 binding 类型、custom paint/layout、rich text model、geometry 计算，以及根 alias 或 `views` helper 未覆盖的高级测试断言时，才直接使用 `core`。

当自定义 layout 和 navigation destination 构造等高级 helper 让调用点更清楚时，可以继续写成带限定前缀的 `@views.*`。
