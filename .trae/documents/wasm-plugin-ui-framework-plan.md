# WASM 插件式 UI 框架实现计划

## 概述

基于设计文档，构建一个跨语言、插件化的 UI 框架：MoonBit 编写 UI 逻辑 → WIT 定义接口 → Wasmtime 运行 → Rust 桥接 → gpui 渲染。

## 当前状态分析

- 项目为空仓库，仅含 `LICENSE.md`（MIT）
- 无任何源代码、配置文件或依赖
- 需要从零搭建整个项目结构

## 关键技术决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| 数据协议 | WIT Component Model | 设计文档最终形态，MoonBit 已官方支持，跳过 JSON 中间步骤 |
| UI 协议策略 | 全量 Node Tree | MVP 推荐，每次 render 返回完整 UI tree，后续优化为 diff/patch |
| gpui 来源 | git 依赖 zed 仓库 | gpui 未发布到 crates.io，需通过 git 引用；同时依赖 gpui-component |
| 节点类型 | view + text + button + input | 覆盖基本展示和交互场景 |
| 事件模型 | ID 驱动 | UI 绑定 event-id，Rust 捕获事件后调用 WASM handler |

## 项目结构

```
MoUI/
├── Cargo.toml                    # Rust workspace 根配置
├── wit/                          # WIT 接口定义（共享）
│   └── ui-plugin.wit
├── crates/
│   ├── moui-host/                # Rust 宿主层（Wasmtime + 桥接）
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── runtime.rs        # Wasmtime 运行时管理
│   │       ├── bridge.rs         # WASM ↔ Rust 数据桥接
│   │       └── types.rs          # Rust 侧 UI 类型定义
│   ├── moui-renderer/            # gpui 渲染层
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── app.rs            # gpui 应用入口
│   │       ├── renderer.rs       # Node tree → gpui Element 转换
│   │       └── event.rs          # gpui 事件 → event-id 转换
│   └── moui-cli/                 # CLI 入口（加载插件并启动）
│       ├── Cargo.toml
│       └── src/
│           └── main.rs
├── plugins/                      # MoonBit 插件目录
│   └── counter/                  # 示例计数器插件
│       ├── wit/                  # WIT 定义（符号链接或复制）
│       ├── moon.mod.json
│       ├── gen/                  # wit-bindgen 生成代码
│       ├── ffi/
│       └── src/                  # 插件业务逻辑
│           └── top.mbt
└── examples/                     # 示例
    └── counter/                  # 计数器示例（使用 plugins/counter）
```

## 实现步骤

### 阶段 1：WIT 接口定义

**目标**：定义 UI 插件的跨语言接口契约

**文件**：`wit/ui-plugin.wit`

```wit
package moui:plugin@0.1.0;

enum node-kind {
    view,
    text,
    button,
    input
}

record color {
    r: u8,
    g: u8,
    b: u8,
    a: u8
}

record props {
    width: option<f32>,
    height: option<f32>,
    padding: option<f32>,
    background-color: option<color>,
    text: option<string>,
    value: option<string>,
    on-click: option<u32>,
    on-input: option<u32>
}

record node {
    id: u32,
    kind: node-kind,
    props: props,
    children: list<node>
}

world ui-plugin {
    export render: func() -> node;
    export handle-event: func(event-id: u32, payload: option<string>) -> node;
}
```

**要点**：
- `node` 递归类型通过 `list<node>` children 实现树结构
- `props` 使用 `option<T>` 表示可选属性
- 事件通过 `event-id` + `payload` 传递，WASM 返回新 node tree
- `background-color` 字段名使用 kebab-case（WIT 规范）

### 阶段 2：Rust Workspace 初始化

**目标**：搭建 Rust workspace 和基础 crate 结构

**步骤**：
1. 创建根 `Cargo.toml` workspace 配置
2. 创建 `crates/moui-host` crate
3. 创建 `crates/moui-renderer` crate
4. 创建 `crates/moui-cli` crate
5. 配置 gpui 和 wasmtime 依赖

**关键依赖**：
- `wasmtime`：WASM 运行时（~v30+）
- `wasmtime-wasi`：WASI 支持
- `wit-bindgen`：WIT 绑定生成
- `gpui`：git 依赖 `https://github.com/zed-industries/zed.git`
- `gpui-component`：git 依赖 `https://github.com/longbridge/gpui-component.git`（可选，视基础组件需求）

**根 Cargo.toml 示例**：
```toml
[workspace]
members = [
    "crates/moui-host",
    "crates/moui-renderer",
    "crates/moui-cli",
]
resolver = "2"

[workspace.dependencies]
wasmtime = "30"
wasmtime-wasi = "30"
anyhow = "1"
```

### 阶段 3：Rust 宿主层（moui-host）

**目标**：实现 Wasmtime 运行时管理和 WASM ↔ Rust 数据桥接

**模块拆分**：

#### 3.1 `types.rs` — Rust 侧 UI 类型

定义与 WIT 对应的 Rust 类型：

```rust
pub enum NodeKind {
    View,
    Text,
    Button,
    Input,
}

pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

pub struct Props {
    pub width: Option<f32>,
    pub height: Option<f32>,
    pub padding: Option<f32>,
    pub background_color: Option<Color>,
    pub text: Option<String>,
    pub value: Option<String>,
    pub on_click: Option<u32>,
    pub on_input: Option<u32>,
}

pub struct Node {
    pub id: u32,
    pub kind: NodeKind,
    pub props: Props,
    pub children: Vec<Node>,
}
```

#### 3.2 `runtime.rs` — Wasmtime 运行时

核心职责：
- 加载 WASM 组件文件
- 配置 WASI 环境
- 实例化组件
- 调用 `render()` 和 `handle-event()` 导出函数

```rust
pub struct PluginRuntime {
    engine: wasmtime::Engine,
    store: wasmtime::Store<WasiCtx>,
    component: wasmtime::Component,
    instance: Option<Instance>,
}
```

关键流程：
1. `new()` — 创建 Engine、配置 WASI
2. `load(path)` — 加载 .wasm 组件文件
3. `render()` — 调用组件导出的 `render()` 函数，返回 Node tree
4. `handle_event(event_id, payload)` — 调用组件导出的 `handle-event()` 函数

#### 3.3 `bridge.rs` — 数据桥接

核心职责：
- 将 WIT 生成的绑定类型转换为 Rust 内部 Node 类型
- 处理 `list<node>` 递归结构的转换
- 处理 `option<T>` 类型的映射

使用 `wit-bindgen` 在宿主侧生成绑定代码，然后编写 `From` trait 实现进行类型转换。

### 阶段 4：gpui 渲染层（moui-renderer）

**目标**：将 Node tree 转换为 gpui 可渲染的 Element

**模块拆分**：

#### 4.1 `app.rs` — gpui 应用入口

- 初始化 gpui Application
- 创建窗口
- 管理 PluginRuntime 生命周期
- 协调渲染循环

```rust
pub fn run(plugin_path: &Path) -> anyhow::Result<()> {
    let runtime = PluginRuntime::new()?;
    runtime.load(plugin_path)?;
    let root_node = runtime.render()?;

    gpui::App::new().run(|cx| {
        cx.open_window(WindowOptions::default(), |cx| {
            cx.new_view(|_cx| {
                MoUIView::new(root_node, runtime)
            })
        });
    });
}
```

#### 4.2 `renderer.rs` — Node → gpui Element 转换

递归遍历 Node tree，根据 `node-kind` 创建对应的 gpui Element：

```rust
pub fn render_node(node: &Node, cx: &mut ViewContext<MoUIView>) -> impl IntoElement {
    match node.kind {
        NodeKind::View => div()
            .width(node.props.width)
            .height(node.props.height)
            .padding(node.props.padding)
            .children(node.children.iter().map(|c| render_node(c, cx))),
        NodeKind::Text => div().text(node.props.text.clone()),
        NodeKind::Button => div()
            .child(node.props.text.clone())
            .on_click(cx.listener(move |this, _, cx| {
                if let Some(event_id) = node.props.on_click {
                    this.dispatch_event(event_id, None, cx);
                }
            })),
        NodeKind::Input => { /* input 元素渲染 */ }
    }
}
```

#### 4.3 `event.rs` — 事件处理

- gpui 捕获用户交互事件（click、input change）
- 将事件转换为 `(event-id, payload)` 格式
- 调用 `PluginRuntime::handle_event()`
- 用返回的新 Node tree 更新 UI

```rust
impl MoUIView {
    fn dispatch_event(&mut self, event_id: u32, payload: Option<String>, cx: &mut ViewContext<Self>) {
        let new_root = self.runtime.handle_event(event_id, payload);
        self.root_node = new_root;
        cx.notify(); // 触发重新渲染
    }
}
```

### 阶段 5：CLI 入口（moui-cli）

**目标**：提供命令行工具加载和运行插件

```rust
fn main() -> anyhow::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let plugin_path = Path::new(&args[1]);
    moui_renderer::run(plugin_path)
}
```

使用方式：`moui-cli ./plugins/counter/target/counter.component.wasm`

### 阶段 6：MoonBit 示例插件（Counter）

**目标**：实现一个计数器插件验证整个流程

**步骤**：
1. 在 `wit/` 目录定义 WIT 接口
2. 使用 `wit-bindgen moonbit` 生成 MoonBit 绑定代码
3. 实现计数器逻辑：
   - `render()` 返回包含按钮和文本的 UI tree
   - `handle-event()` 处理点击事件，更新计数，返回新 UI tree
4. 构建为 WASM 组件：
   ```bash
   moon build --target wasm
   wasm-tools component embed wit target/wasm/release/build/gen/gen.wasm --encoding utf16 -o counter.wasm
   wasm-tools component new counter.wasm -o counter.component.wasm
   ```

**计数器逻辑伪代码**：
```
let mut count: Int = 0

fn render() -> Node {
    Node {
        id: 0,
        kind: View,
        props: { width: Some(300.0), height: Some(200.0), padding: Some(16.0), .. },
        children: [
            Node {
                id: 1,
                kind: Text,
                props: { text: Some("Count: \{count}"), .. },
                children: []
            },
            Node {
                id: 2,
                kind: Button,
                props: { text: Some("+1"), on_click: Some(1), .. },
                children: []
            }
        ]
    }
}

fn handle_event(event_id: UInt, payload: Option[String]) -> Node {
    if event_id == 1 {
        count = count + 1
    }
    render()
}
```

### 阶段 7：集成测试与验证

**目标**：端到端验证整个流程

**验证清单**：
1. ✅ WIT 定义正确，`wit-bindgen` 可为 Rust 和 MoonBit 生成绑定
2. ✅ MoonBit 插件可编译为 WASM 组件
3. ✅ Rust 宿主可加载 WASM 组件并调用 `render()`
4. ✅ Node tree 可正确转换为 gpui Element
5. ✅ 点击按钮触发事件，WASM 处理后返回新 UI tree
6. ✅ UI 正确更新显示

**测试命令**：
```bash
# 构建 MoonBit 插件
cd plugins/counter
moon build --target wasm
wasm-tools component embed wit/ target/wasm/release/build/gen/gen.wasm --encoding utf16 -o counter.wasm
wasm-tools component new counter.wasm -o counter.component.wasm

# 运行
cd ../..
cargo run --bin moui-cli -- plugins/counter/counter.component.wasm
```

## 假设与风险

### 假设
1. gpui 可通过 git 依赖正常引入（Apache 2.0 许可）
2. MoonBit 的 wit-bindgen 支持递归 record 类型（`list<node>`）
3. Wasmtime 组件模型支持自定义 world（非 wasi:cli/command）
4. gpui 的 `on_click` 等事件可在自定义 View 中正确绑定

### 风险与缓解
1. **gpui 依赖复杂**：gpui 是 Zed 的一部分，git 依赖可能引入大量无关代码。缓解：考虑使用 gpui-component 的方式，仅依赖 gpui crate
2. **WIT 递归类型**：`node` 包含 `list<node>` 可能在某些 wit-bindgen 版本中有问题。缓解：先验证 wit-bindgen 对递归类型的支持
3. **MoonBit 全局状态**：WASM 组件中需要维护状态（如计数器），需确认 MoonBit WASM 组件支持全局可变状态。缓解：使用 MoonBit 的 `let mut` 或 Ref 类型
4. **gpui 事件绑定**：Node tree 每次全量返回，需要重新绑定事件处理器。缓解：使用 gpui 的 `ViewContext` 和 callback 机制

## 实现优先级

1. **P0（核心）**：WIT 定义 → Rust 宿主层 → gpui 渲染层 → CLI
2. **P1（验证）**：MoonBit Counter 插件 → 端到端测试
3. **P2（优化）**：错误处理、日志、配置文件支持
4. **P3（未来）**：Patch/Diff 模式、多插件加载、热重载
