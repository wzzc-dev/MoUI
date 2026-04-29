# MoUI - WASM 插件式 UI 框架 Code Wiki

## 目录

1. [项目概述](#项目概述)
2. [整体架构](#整体架构)
3. [目录结构](#目录结构)
4. [核心模块详解](#核心模块详解)
   - [moui-host (宿主层)](#moui-host-宿主层)
   - [moui-renderer (渲染层)](#moui-renderer-渲染层)
   - [moui-cli (命令行工具)](#moui-cli-命令行工具)
5. [WIT 接口定义](#wit-接口定义)
6. [关键类与函数说明](#关键类与函数说明)
7. [依赖关系](#依赖关系)
8. [项目运行方式](#项目运行方式)
9. [插件开发指南](#插件开发指南)

---

## 项目概述

**MoUI** 是一个跨语言、插件化的 UI 框架，核心设计理念是：

> **MoonBit 编写 UI 逻辑 → WIT 定义接口 → Wasmtime 运行 → Rust 桥接 → gpui 渲染**

该框架允许开发者使用 MoonBit 语言编写 UI 组件，编译为 WebAssembly 组件，由 Rust 宿主程序加载并通过 gpui 进行原生渲染。

### 核心特性

- **跨语言支持**：通过 WIT (WebAssembly Interface Types) 定义接口契约，支持多种编程语言编写插件
- **插件化架构**：UI 组件作为独立的 WASM 组件运行，与宿主程序隔离
- **声明式 UI**：采用扁平化节点树描述 UI 结构
- **事件驱动**：通过事件 ID 机制实现 UI 交互

---

## 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        MoUI 架构图                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐                                            │
│  │  MoonBit Plugin │  ← UI 逻辑编写 (counter.mbt)               │
│  │   (.wasm 文件)   │                                            │
│  └────────┬────────┘                                            │
│           │ WIT Interface                                       │
│           ▼                                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    moui-host (Rust)                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │  │   runtime    │  │    bridge    │  │    types     │   │   │
│  │  │ (Wasmtime)   │  │ (类型转换)    │  │ (UI类型定义) │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│           │ UiTree                                              │
│           ▼                                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 moui-renderer (Rust)                     │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │  │     app      │  │   renderer   │  │    event     │   │   │
│  │  │ (应用入口)    │  │ (节点渲染)    │  │ (事件处理)   │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│           │ gpui Elements                                       │
│           ▼                                                     │
│  ┌─────────────────┐                                            │
│  │    gpui 渲染     │  ← 原生 UI 渲染                           │
│  └─────────────────┘                                            │
│                                                                 │
│  ┌─────────────────┐                                            │
│  │   moui-cli      │  ← 命令行入口                              │
│  └─────────────────┘                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 数据流

```
用户交互 → gpui 事件 → event-id → moui-host.handle_event() 
    → WASM handle_event() → 新 UiTree → bridge 转换 
    → renderer 渲染 → gpui 更新界面
```

---

## 目录结构

```
MoUI/
├── Cargo.toml                    # Rust workspace 根配置
├── Cargo.lock                    # 依赖锁定文件
├── LICENSE.md                    # MIT 许可证
│
├── wit/                          # WIT 接口定义目录
│   └── ui-plugin.wit             # UI 插件接口定义
│
├── crates/                       # Rust crates 目录
│   ├── moui-host/                # 宿主层 - WASM 运行时管理
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs            # 模块导出
│   │       ├── runtime.rs        # Wasmtime 运行时
│   │       ├── bridge.rs         # 类型桥接转换
│   │       └── types.rs          # Rust 侧 UI 类型
│   │
│   ├── moui-renderer/            # 渲染层 - gpui 渲染
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs            # MoUIView 定义
│   │       ├── app.rs            # 应用入口
│   │       ├── renderer.rs       # 节点渲染器
│   │       └── event.rs          # 事件处理
│   │
│   └── moui-cli/                 # CLI 工具
│       ├── Cargo.toml
│       └── src/
│           └── main.rs           # 命令行入口
│
└── plugins/                      # MoonBit 插件目录
    └── counter/                  # 计数器示例插件
        ├── moon.mod.json         # MoonBit 模块配置
        ├── wit/
        │   └── world.wit         # 插件 WIT 定义
        ├── gen/                  # wit-bindgen 生成的代码
        │   ├── interface/        # 接口类型定义
        │   └── world/            # World 实现
        ├── counter.wasm          # 编译产物
        └── counter.component.wasm # 最终组件
```

---

## 核心模块详解

### moui-host (宿主层)

**职责**：管理 WASM 运行时，加载插件组件，提供 WASM ↔ Rust 数据桥接。

#### 模块结构

| 文件 | 职责 |
|------|------|
| `lib.rs` | 模块入口，导出公共 API |
| `runtime.rs` | Wasmtime 运行时管理 |
| `bridge.rs` | WIT 类型到 Rust 类型的转换 |
| `types.rs` | Rust 侧 UI 类型定义 |

#### runtime.rs - 核心运行时

```rust
pub struct PluginRuntime {
    engine: Engine,           // Wasmtime 引擎
    store: Store<PluginState>, // WASM 状态存储
    component: Option<Component>, // 加载的组件
}
```

**核心方法**：

| 方法 | 功能 |
|------|------|
| `new()` | 创建运行时实例，启用 Component Model |
| `load(path)` | 从文件加载 WASM 组件 |
| `render()` | 调用插件的 `render()` 函数，返回 UiTree |
| `handle_event(event_id, payload)` | 调用插件的事件处理函数 |

#### types.rs - UI 类型系统

```rust
pub enum NodeKind {
    View,    // 容器节点
    Text,    // 文本节点
    Button,  // 按钮节点
    Input,   // 输入框节点
}

pub struct Props {
    pub width: Option<f32>,
    pub height: Option<f32>,
    pub padding: Option<f32>,
    pub background_color: Option<Color>,
    pub text: Option<String>,
    pub value: Option<String>,
    pub on_click: Option<u32>,   // 点击事件 ID
    pub on_input: Option<u32>,   // 输入事件 ID
}

pub struct FlatNode {
    pub id: u32,
    pub parent_id: Option<u32>,  // 父节点 ID（扁平化结构）
    pub kind: NodeKind,
    pub props: Props,
}

pub struct UiTree {
    pub nodes: Vec<FlatNode>,
}
```

**UiTree::build_node_tree()** 方法将扁平化节点列表重建为树形结构。

#### bridge.rs - 类型桥接

使用 `wasmtime::component::bindgen!` 宏从 WIT 定义生成绑定代码，然后实现 `From` trait 进行类型转换。

---

### moui-renderer (渲染层)

**职责**：将 UiTree 转换为 gpui 可渲染的 Element，处理用户交互事件。

#### 模块结构

| 文件 | 职责 |
|------|------|
| `lib.rs` | MoUIView 组件定义 |
| `app.rs` | 应用入口，窗口管理 |
| `renderer.rs` | Node → gpui Element 转换 |
| `event.rs` | 事件分发处理 |

#### MoUIView - 核心视图组件

```rust
pub struct MoUIView {
    pub root_node: Option<Node>,      // 根节点
    pub runtime: Option<PluginRuntime>, // 运行时引用
}
```

#### renderer.rs - 节点渲染

根据 `NodeKind` 创建对应的 gpui Element：

| NodeKind | 渲染函数 | 说明 |
|----------|----------|------|
| View | `render_view()` | Flex 容器，支持尺寸、内边距、背景色 |
| Text | `render_text()` | 文本显示 |
| Button | `render_button()` | 可点击按钮，绑定 on_click 事件 |
| Input | `render_input()` | 输入框（基础实现） |

#### event.rs - 事件处理

```rust
impl MoUIView {
    pub fn dispatch_event(&mut self, event_id: u32, payload: Option<String>, cx: &mut Context<Self>) {
        // 1. 调用 runtime.handle_event()
        // 2. 获取新的 UiTree
        // 3. 更新 root_node
        // 4. cx.notify() 触发重绘
    }
}
```

---

### moui-cli (命令行工具)

**职责**：提供命令行入口，加载并运行 WASM 插件。

```rust
fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let plugin_path = PathBuf::from(&args[1]);
    moui_renderer::run(&plugin_path)
}
```

**使用方式**：
```bash
moui <plugin.wasm>
```

---

## WIT 接口定义

### ui-plugin.wit

```wit
package moui:plugin@0.1.0;

interface ui-types {
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

    record flat-node {
        id: u32,
        parent-id: option<u32>,
        kind: node-kind,
        props: props
    }

    record ui-tree {
        nodes: list<flat-node>
    }
}

world ui-plugin {
    use ui-types.{ui-tree};

    export ui-types;
    export render: func() -> ui-tree;
    export handle-event: func(event-id: u32, payload: option<string>) -> ui-tree;
}
```

### 接口说明

| 导出函数 | 参数 | 返回值 | 说明 |
|----------|------|--------|------|
| `render()` | 无 | `ui-tree` | 返回初始 UI 树 |
| `handle-event()` | `event-id`, `payload` | `ui-tree` | 处理事件，返回更新后的 UI 树 |

### 设计要点

1. **扁平化结构**：使用 `flat-node` 配合 `parent-id` 表示树结构，避免 WIT 对递归类型的限制
2. **可选属性**：所有 UI 属性使用 `option<T>` 表示可选
3. **事件 ID 驱动**：通过 `on-click` 和 `on-input` 属性绑定事件处理

---

## 关键类与函数说明

### Rust 侧

#### PluginRuntime

| 方法 | 签名 | 说明 |
|------|------|------|
| `new` | `fn new() -> Result<Self>` | 创建运行时，启用 Component Model |
| `load` | `fn load(&mut self, path: &Path) -> Result<()>` | 加载 WASM 组件文件 |
| `render` | `fn render(&mut self) -> Result<UiTree>` | 调用插件的 render 函数 |
| `handle_event` | `fn handle_event(&mut self, event_id: u32, payload: Option<String>) -> Result<UiTree>` | 调用插件的事件处理函数 |

#### UiTree

| 方法 | 签名 | 说明 |
|------|------|------|
| `build_node_tree` | `fn build_node_tree(&self) -> Option<Node>` | 将扁平化节点列表重建为树形结构 |

#### render_node

| 函数 | 签名 | 说明 |
|------|------|------|
| `render_node` | `fn render_node(node: &Node, cx: &mut Context<MoUIView>) -> AnyElement` | 将 Node 渲染为 gpui Element |

### MoonBit 侧

#### 插件入口函数

| 函数 | 签名 | 说明 |
|------|------|------|
| `render` | `fn render() -> @uiTypes.UiTree` | 返回 UI 树 |
| `handle_event` | `fn handle_event(event_id: UInt, payload: String?) -> @uiTypes.UiTree` | 处理事件 |

---

## 依赖关系

### Workspace 依赖

```toml
[workspace.dependencies]
moui-host = { path = "crates/moui-host" }
moui-renderer = { path = "crates/moui-renderer" }
anyhow = "1"
wasmtime = "30"
wasmtime-wasi = "30"
```

### 各 Crate 依赖

#### moui-host

| 依赖 | 版本 | 用途 |
|------|------|------|
| wasmtime | 30 | WASM 运行时 |
| wasmtime-wasi | 30 | WASI 支持 |
| anyhow | 1 | 错误处理 |

#### moui-renderer

| 依赖 | 版本 | 用途 |
|------|------|------|
| moui-host | workspace | 宿主层 |
| gpui | 0.2.2 | UI 渲染框架 |
| anyhow | 1 | 错误处理 |

#### moui-cli

| 依赖 | 版本 | 用途 |
|------|------|------|
| moui-host | workspace | 宿主层 |
| moui-renderer | workspace | 渲染层 |
| anyhow | 1 | 错误处理 |

### 依赖图

```
moui-cli
    ├── moui-renderer
    │       ├── moui-host
    │       │       ├── wasmtime
    │       │       └── wasmtime-wasi
    │       └── gpui
    └── anyhow
```

---

## 项目运行方式

### 环境要求

- **Rust**: 2024 Edition
- **MoonBit**: 用于编写插件
- **wasm-tools**: 用于构建 WASM 组件

### 构建 Rust 项目

```bash
# 构建所有 crates
cargo build --release

# 或单独构建
cargo build --release -p moui-cli
```

### 构建 MoonBit 插件

```bash
cd plugins/counter

# 1. 构建 WASM
moon build --target wasm

# 2. 嵌入 WIT 定义
wasm-tools component embed wit/ target/wasm/release/build/gen/gen.wasm --encoding utf16 -o counter.wasm

# 3. 创建组件
wasm-tools component new counter.wasm -o counter.component.wasm
```

### 运行

```bash
# 使用 CLI 运行插件
cargo run --bin moui -- plugins/counter/counter.component.wasm

# 或直接运行编译后的二进制
./target/release/moui plugins/counter/counter.component.wasm
```

---

## 插件开发指南

### 创建新插件

1. **创建插件目录**
   ```bash
   mkdir -p plugins/my-plugin
   ```

2. **创建 WIT 定义** (`wit/world.wit`)
   - 复制 `ui-plugin.wit` 或自定义接口

3. **创建 MoonBit 模块** (`moon.mod.json`)
   ```json
   { "name": "moui/plugin", "preferred-target": "wasm" }
   ```

4. **生成绑定代码**
   ```bash
   wit-bindgen moonbit wit/ --out-dir gen/
   ```

5. **实现插件逻辑**
   - 实现 `render()` 函数返回 UI 树
   - 实现 `handle_event()` 处理用户交互

### Counter 插件示例

```moonbit
let count : Ref[Int] = Ref::new(0)

pub fn render() -> @uiTypes.UiTree {
    let c = count.val
    @uiTypes.UiTree::{
        nodes: [
            @uiTypes.FlatNode::{
                id: 0U,
                parent_id: None,
                kind: @uiTypes.NodeKind::VIEW,
                props: @uiTypes.Props::{
                    width: Some(300.0),
                    height: Some(200.0),
                    padding: Some(16.0),
                    // ... 其他属性
                },
            },
            @uiTypes.FlatNode::{
                id: 1U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::TEXT,
                props: @uiTypes.Props::{
                    text: Some("Count: \{c}"),
                    // ...
                },
            },
            @uiTypes.FlatNode::{
                id: 2U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::BUTTON,
                props: @uiTypes.Props::{
                    text: Some("+1"),
                    on_click: Some(1U),
                    // ...
                },
            },
        ],
    }
}

pub fn handle_event(event_id : UInt, _payload : String?) -> @uiTypes.UiTree {
    match event_id {
        1U => count.val = count.val + 1
        2U => count.val = count.val - 1
        _ => ()
    }
    render()
}
```

### 事件处理流程

1. 用户点击按钮
2. gpui 触发 `on_click` 回调
3. `MoUIView::dispatch_event()` 被调用
4. `PluginRuntime::handle_event()` 调用 WASM 函数
5. WASM 更新状态并返回新 UI 树
6. Rust 侧更新 `root_node` 并触发重绘

---

## 扩展阅读

- [WIT 规范](https://github.com/WebAssembly/component-model/blob/main/design/mvp/WIT.md)
- [Wasmtime 文档](https://docs.wasmtime.dev/)
- [gpui 框架](https://github.com/zed-industries/zed)
- [MoonBit 语言](https://moonbitlang.github.io/moonbit-lang/)

---

*文档生成时间: 2026-04-29*
