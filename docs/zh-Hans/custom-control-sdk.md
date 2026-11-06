# 自定义控件 SDK

当一个可复用控件无法用 `@views` constructor 组合表达时，使用本指南。受支持的
扩展边界是实现具体的 `@core.ViewNode`，再通过 `@core.View::from_node` 构造
类型化 view。这里没有动态插件加载器、没有新的 renderer ABI，`moui` 和
`moui/views` 也不会重导出 `ViewNode`。

可运行参考是 [`examples/custom_control`](../../examples/custom_control/)：其中
`widgets` 包实现可编辑步进计数器，`app` 包把值保留在 TEA model 中。

## 选择最小扩展边界

按以下顺序选择：

1. 组合现有 `@views` constructor 和 modifier。
2. 在 app 代码中添加可复用组合 helper。
3. 当控件需要自己的 layout、paint、semantics、focus 或 text-input contract 时，
   在独立包中实现本地 `ViewNode`。
4. 当多个独立 app 需要同一套稳定 API 时，再提议把它做成
   `moui/views` 中的第一方控件。

不要把控件加入 `moui/core`。`core` 拥有 `ViewNode` 协议，不拥有控件词汇。

## 包结构

将可复用 node 与 app 分开：

```text
examples/my_app/
  widgets/
    moon.pkg
    my_control.mbt
    my_control_golden_test.mbt
  app/
    moon.pkg
    app.mbt
    my_app_test.mbt
```

控件包通常需要 `wzzc-dev/moui` 和 `wzzc-dev/moui/core`。共享 app 包保持默认的
`moui + views` 边界；仅当需要注入 app-facing timer、route 或 service source
时再加入 `moui/services`，并导入本地 widgets 包。Runtime import 只应出现在
测试或平台入口中，不能进入共享的 production app。

参考包结构为：

```text
examples/custom_control/
  widgets/editable_counter.mbt
  widgets/editable_counter_golden_test.mbt
  app/app.mbt
  app/custom_control_app_test.mbt
```

## 最小 Node 模板

Node 是不可变的声明数据。类型化 callback 和 `Msg` 位于 `View::from_node`
adapter 中，而不在 node 里。

```moonbit nocheck
priv struct Badge {
  label : String
  count : Int32
  key : String?
}

impl @core.ViewNode for Badge with fn identity(self) {
  @core.ViewIdentity::new(kind="Badge", key=self.key)
}

impl @core.ViewNode for Badge with fn declaration(self) {
  @core.ViewDeclaration::channels(
    layout=Constant,
    paint=Exact(
      @core.DeclarationKey::record(
        type_tag="Badge.paint",
        fields=[
          ("label", @core.DeclarationKey::string(self.label)),
          ("count", @core.DeclarationKey::int(self.count)),
        ],
      ),
    ),
    semantics=Exact(
      @core.DeclarationKey::record(
        type_tag="Badge.semantics",
        fields=[
          ("label", @core.DeclarationKey::string(self.label)),
          ("count", @core.DeclarationKey::int(self.count)),
        ],
      ),
    ),
    platform=Constant,
  )
}

impl @core.ViewNode for Badge with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(@core.Size::new(width=96.0, height=28.0)),
  )
}

impl @core.ViewNode for Badge with fn paint(self, context) {
  let theme = context.environment.theme
  @core.ViewPaintPlan::commands([
    FillRoundedRect(
      @core.RoundedRect::new(rect=context.frame, radius=6.0),
      theme.palette.surface_variant,
    ),
    DrawText(
      @core.TextRun::new(
        text="\{self.label} \{self.count}",
        frame=context.frame,
        font=theme.typography.control,
        color=theme.palette.on_surface,
      ),
    ),
  ])
}

impl @core.ViewNode for Badge with fn semantics(self) {
  @core.ViewSemanticsInfo::leaf(
    role=@core.SemanticsRole::Status,
    label=self.label,
    value=self.count.to_string(),
  )
}

pub fn[Msg] badge(
  label~ : String,
  count~ : Int32,
  key? : String,
) -> @moui.View[Msg] {
  @core.View::from_node(Badge::{ label, count, key })
}
```

编译器只要求实现 `identity` 和 `layout`。其余通道应按需覆盖：

| 通道 | 何时覆盖 |
|---|---|
| `declaration` | 可复用控件始终覆盖；否则每个通道都不可缓存 |
| `paint` | Node 需要自行绘制 |
| `semantics` | 辅助技术或自动化必须观察该 node |
| `focusable` | Node 参与 Tab 或 pointer focus |
| `text_input_state` | Node 接受文本输入或 IME composition |
| `place_overlays` | Node 在 base layout 后定位 overlay children |
| `platform_views` | Node 拥有 native platform child |
| `child_*` | Child constraint/environment/style 不再是简单透传 |
| `flex_weight` | 父 flex layout 需要按权重分配空间 |

## Identity 与 Declaration

这是三个不同标识：

- `ViewIdentity.key` 控制 element 复用。可重排或多实例控件应使用稳定 key。
- `SemanticId` 是稳定的自动化/辅助功能地址，不是 layout cache key，也不能替代
  `ViewIdentity.key`。
- `DeclarationKey` 精确说明哪些不可变字段会使 layout、paint、semantics 和
  platform 工作失效。

Node 的 identity kind 应在版本之间保持稳定。把调用者 key 放进 `identity`，
但不要放进 declaration key。每个通道读取的字段都应包含在该通道的 key 中：

- 改变测量或 child placement 的 layout 字段；
- 改变 command、geometry、color 或 text 的 paint 字段；
- 改变 role、label、value、state、action、numeric metadata 或 relation 的
  semantics 字段。

Focus、hover、pressed、selection、composition、animation clock 和 environment
theme 等环境状态不属于 declaration key；runtime 已经会让相应 pass 失效。
Pinned theme 或 font 不同：它们必须在受影响的通道中留下 fingerprint，或返回
`Uncacheable`。

测试不能只覆盖一个静态样本。至少断言：值变化时 layout 通道保持不变，而 paint
与 semantics 通道变化。参考测试
`editable counter identity and declaration channels stay explicit` 覆盖了这一点。

## Semantics、Action 与辅助功能

`ViewNode::semantics` 描述声明数据；`View::from_node` 另行提供类型化 action
handler，因此对外宣称的能力不会与实际实现漂移。

- 使用 `ViewSemanticsInfo::leaf`、`text_field` 或 `new` 声明 role、label、value、
  state、numeric/text metadata 和 composition。
- 只注册真实存在的 action，例如 `increment`、`decrement`、`set_text`、`select`。
- Handler 返回类型化消息，不要在 action callback 中直接改写 app state。
- 通过已提交的 runtime semantics 和真实 action request 测试，不要只检查 node
  本地 `semantics()` 的返回值。

参考计数器声明 text-field role、editable-text 和 numeric metadata，然后发布
`SetText`、`Increment`、`Decrement`。App 测试通过
`AppRuntime::perform_semantics_action` 驱动这三种 action。

## 多实例状态与生命周期

可复用控件不依赖组件 store 也可以出现多次。参考 app 由父级拥有
`Array[CounterInstance]`；每个已提交值、编辑次数和 auto 标志都留在父 TEA
model 中。实例的稳定字符串 `id` 同时是 model key 和 scoped lifecycle identity
的来源。

- Widget 的 `key` 与 `SemanticId` 都包含 model key，因此重排不会把 focus 或
  自动化目标移到另一个实例。
- `Feature::scope(scope_id="custom-control/<id>", ...)` 通过纯 read/write lens
  投影单个实例。兄弟实例可以声明相同的本地 subscription key；scope prefix
  会让它们的 lifecycle descriptor 保持不同。
- App 通过 program factory 注入可选 `TimerSource`。没有 source 时不产生
  subscription；启用 auto 的实例各自获得 `counter/auto` timer。移除实例会移除
  对应 subscription，陈旧 callback 会被忽略。
- Save/restore 使用 app-owned snapshot DTO。Restore 校验 id、由文本重建值、保留
  顺序，并维护会跳过已有 key 的 fresh-id cursor。Runtime 不保存持久组件状态。

Pilot 的实测成本很具体：两到三个实例需要显式的 child update/lens、snapshot DTO
和稳定 id cursor。这些工作都是线性、类型化且直接可见的 app 代码。在当前的
产品范围内，这属于可接受的摩擦；runtime-owned store 会减少部分 plumbing，
但会引入第二套持久化/codec owner 和隐藏生命周期状态。因此 ADR 0053 继续有效，
只有独立产品证据才能重新评估它。

## Focus、Text 与 IME

可编辑自定义控件有两个状态所有者：

- 父 TEA model 拥有已提交的 text/value；
- Runtime 拥有瞬态 caret、selection、composition 和 reveal 状态。

`text_input_state` 必须报告 input frame、当前 caret、selection 和活动 composition。
Caret 必须落在 grapheme boundary 上。

Event adapter 应按控件需要处理：

- pointer down 时根据本地文本几何定位 caret 并取得 focus；
- `InsertText`、`DeleteRange`、`DeleteSurrounding` 和 `ReplaceText`；
- `CompositionStart`、`CompositionUpdate` 和 `CompositionEnd`；
- `SetSelection`；
- 控件声明支持时的 paste/copy/cut。

文本插入或 composition 结束时只发出一条已提交值消息。Composition 更新只修改
`TextControlStateContext` 的瞬态状态，不提前改写 model。不要假设 runtime 的初始
caret 在末尾；应从 pointer 或显式 selection action 初始化。

至少测试一次 pointer-focus 后的 composition begin/update/end，并同时读回
`AppRuntime::focused_text_input()` 和已提交 semantics。

## RTL 与方向

从一个几何源计算 logical leading/trailing 控件：

```moonbit
let leading_x = frame.mirrored_x(
  x=frame.origin.x,
  width=step_width,
  direction=context.environment.layout_direction,
)
```

Paint、hit testing、caret placement 和 golden test 必须共用这份几何。Decrement
始终是 leading action，increment 始终是 trailing action；在 `RightToLeft` 下它们的
物理 x 坐标交换。不要维护两套可能漂移的 LTR/RTL layout 分支。

## Golden Layout 与 Paint Fixture

每个可复用控件至少应有一个确定性 fixture，覆盖：

- 精确的 constrained size；
- child frame，或明确没有 child；
- 一个代表性状态的完整 paint-command 序列；
- 一个独立断言，验证 RTL 下镜像后的 action zone。

除非控件自己拥有 text provider，否则使用 neutral environment 和 fallback text
system。结构性 contract 不应依赖 raster screenshot；pixel smoke 可以补充，但
不能替代 command/layout fixture。

参考测试位于
`examples/custom_control/widgets/editable_counter_golden_test.mbt`。只有 layout 或
paint 变化是有意行为时才更新它们。

## 迁移示例

典型的手写控件会把状态和 cache invalidation 都塞进 widget：

```moonbit nocheck
// Before: node 同时拥有瞬态和已提交状态，任何字段都会引发整节点重建。
struct LegacyCounter {
  mut value : String
  mut hovered : Bool
  mut pressed : Bool
}
```

迁移步骤：

1. 把 `value` 移入父 TEA model，以不可变 node data 传入。
2. 用 `ViewEventContext.state` 替换 hover/pressed 字段。
3. 把 caret/selection/composition 移到 runtime text-control state。
4. 公开返回 `@moui.View[Msg]`、接收类型化 callback 的 constructor。
5. 把 declaration 拆成 layout、paint、semantics 和 platform 通道。
6. 在类型化 handler 旁声明 semantic action。
7. 用与 paint 共用的 geometry helper 替换启发式 hit test。
8. 在删除旧 wrapper 前补齐 golden、semantics/action、focus/IME 和 RTL 测试。

参考 app 按这一形态实现，不提供 component store 或隐藏的 `ComponentContext`。

## 一致性检查清单

- [ ] 控件位于 `core` 之外；app 逻辑仍留在父 model。
- [ ] `identity` 区分 kind，并为实例使用稳定 key。
- [ ] Declaration channel 读取的每个字段都进入该 channel 的 key。
- [ ] Paint 与 text-input 几何来自同一个方向感知的数据源。
- [ ] Semantics 暴露 role、label/value、state，以及真实存在的 action。
- [ ] Pointer focus 会初始化 caret；IME commit 只产生一次 model update。
- [ ] 存在 golden layout、LTR paint 和 RTL 镜像几何 fixture。
- [ ] Runtime semantics/action、focus 和 IME 测试使用公开边界。
- [ ] 如果 widgets 包会发布，运行 `moon info` 并审阅 API surface。

参考实现的聚焦验证：

```sh
moon test examples/custom_control/widgets --target native
moon test examples/custom_control/app --target native
moon check examples/custom_control/app --target wasm-gc
node scripts/validate-viewnode-declaration-coverage.mjs
```

Framework-wide 修改继续执行 `docs/testing.md` 中适用的命令；不要把该 SDK 示例当作
renderer 或平台 smoke。
