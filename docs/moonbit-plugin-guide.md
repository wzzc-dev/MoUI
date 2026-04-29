# MoonBit 插件开发指南

本文档介绍如何使用 MoonBit 语言开发 MoUI 插件。

## 目录

- [环境准备](#环境准备)
- [快速开始](#快速开始)
- [核心概念](#核心概念)
- [API 参考](#api-参考)
- [完整示例](#完整示例)
- [构建与运行](#构建与运行)
- [调试技巧](#调试技巧)

---

## 环境准备

### 必需工具

| 工具 | 用途 | 安装方式 |
|------|------|----------|
| MoonBit | 编写插件逻辑 | [官方文档](https://moonbitlang.github.io/moonbit-lang/) |
| wit-bindgen | 生成绑定代码 | `cargo install wit-bindgen` |
| wasm-tools | 构建 WASM 组件 | `cargo install wasm-tools` |
| Rust + Cargo | 运行宿主程序 | [rustup.rs](https://rustup.rs) |

### 验证安装

```bash
moon version
wit-bindgen --version
wasm-tools --version
cargo --version
```

---

## 快速开始

### 1. 创建插件目录

```bash
mkdir -p plugins/my-plugin
cd plugins/my-plugin
```

### 2. 创建 MoonBit 模块配置

创建 `moon.mod.json`：

```json
{
  "name": "moui/plugin",
  "preferred-target": "wasm"
}
```

### 3. 创建 WIT 接口定义

创建 `wit/world.wit`：

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

### 4. 生成绑定代码

```bash
wit-bindgen moonbit wit/ --out-dir gen/
```

此命令会生成以下文件：

```
gen/
├── moon.pkg.json
├── ffi.mbt
├── interface/
│   └── moui/plugin/uiTypes/
│       ├── moon.pkg.json
│       ├── top.mbt
│       └── ffi.mbt
└── world/
    └── uiPlugin/
        ├── moon.pkg.json
        ├── top.mbt
        └── ffi.mbt
```

### 5. 实现插件逻辑

创建 `gen/world/uiPlugin/my_plugin.mbt`：

```moonbit
pub fn render() -> @uiTypes.UiTree {
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
                    background_color: None,
                    text: None,
                    value: None,
                    on_click: None,
                    on_input: None,
                },
            },
            @uiTypes.FlatNode::{
                id: 1U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::TEXT,
                props: @uiTypes.Props::{
                    text: Some("Hello, MoUI!"),
                    ..Default::default()
                },
            },
        ],
    }
}

pub fn handle_event(_event_id: UInt, _payload: String?) -> @uiTypes.UiTree {
    render()
}
```

---

## 核心概念

### UI 树结构

MoUI 使用**扁平化节点列表**表示 UI 树，通过 `parent_id` 建立父子关系：

```
节点树:                    扁平化表示:
┌─ View (id=0)            [FlatNode { id: 0, parent_id: None, ... }]
│  ├─ Text (id=1)    =>   [FlatNode { id: 1, parent_id: Some(0), ... }]
│  └─ Button (id=2)       [FlatNode { id: 2, parent_id: Some(0), ... }]
```

这种设计的优势：
- 避免 WIT 对递归类型的限制
- 简化序列化/反序列化
- 便于增量更新

### 节点类型 (NodeKind)

| 类型 | 用途 | 关键属性 |
|------|------|----------|
| `VIEW` | 容器节点，类似 HTML div | `width`, `height`, `padding`, `background_color` |
| `TEXT` | 文本显示 | `text` |
| `BUTTON` | 可点击按钮 | `text`, `on_click` |
| `INPUT` | 输入框 | `value`, `text`(placeholder), `on_input` |

### 事件机制

MoUI 使用**事件 ID** 驱动的交互模式：

1. 在 `Props` 中设置 `on_click` 或 `on_input` 属性（值为事件 ID）
2. 用户交互时，宿主调用 `handle_event(event_id, payload)`
3. 插件根据 `event_id` 处理逻辑，返回更新后的 UI 树

```
用户点击按钮 → on_click=1 → handle_event(1, None) → 更新状态 → 返回新 UI 树
```

---

## API 参考

### 类型定义

#### NodeKind

```moonbit
pub enum NodeKind {
    VIEW;   // 容器
    TEXT;   // 文本
    BUTTON; // 按钮
    INPUT;  // 输入框
}
```

#### Color

```moonbit
pub struct Color {
    r: Byte;  // 红色通道 (0-255)
    g: Byte;  // 绿色通道 (0-255)
    b: Byte;  // 蓝色通道 (0-255)
    a: Byte;  // 透明度 (0-255)
}
```

#### Props

```moonbit
pub struct Props {
    width: Float?;              // 宽度 (像素)
    height: Float?;             // 高度 (像素)
    padding: Float?;            // 内边距 (像素)
    background_color: Color?;   // 背景颜色
    text: String?;              // 文本内容 / Input 占位符
    value: String?;             // Input 值
    on_click: UInt?;            // 点击事件 ID
    on_input: UInt?;            // 输入事件 ID
}
```

#### FlatNode

```moonbit
pub struct FlatNode {
    id: UInt;           // 节点唯一标识
    parent_id: UInt?;   // 父节点 ID (None 表示根节点)
    kind: NodeKind;     // 节点类型
    props: Props;       // 节点属性
}
```

#### UiTree

```moonbit
pub struct UiTree {
    nodes: Array[FlatNode];  // 扁平化节点列表
}
```

### 导出函数

插件必须实现以下两个导出函数：

#### render

```moonbit
pub fn render() -> @uiTypes.UiTree
```

返回初始 UI 树。宿主程序加载插件后首先调用此函数。

#### handle_event

```moonbit
pub fn handle_event(event_id: UInt, payload: String?) -> @uiTypes.UiTree
```

处理用户交互事件。

**参数**：
- `event_id`: 事件 ID，对应 `on_click` 或 `on_input` 的值
- `payload`: 事件数据
  - 点击事件: `None`
  - 输入事件: `Some(新输入值)`

**返回**：更新后的 UI 树

---

## 完整示例

### 计数器插件

```moonbit
// gen/world/uiPlugin/counter.mbt

let count: Ref[Int] = Ref::new(0)

pub fn render() -> @uiTypes.UiTree {
    let c = count.val
    @uiTypes.UiTree::{
        nodes: [
            // 根容器
            @uiTypes.FlatNode::{
                id: 0U,
                parent_id: None,
                kind: @uiTypes.NodeKind::VIEW,
                props: @uiTypes.Props::{
                    width: Some(300.0),
                    height: Some(200.0),
                    padding: Some(16.0),
                    background_color: Some(@uiTypes.Color::{
                        r: 30b,
                        g: 30b,
                        b: 46b,
                        a: 255b,
                    }),
                    text: None,
                    value: None,
                    on_click: None,
                    on_input: None,
                },
            },
            // 计数显示文本
            @uiTypes.FlatNode::{
                id: 1U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::TEXT,
                props: @uiTypes.Props::{
                    text: Some("Count: \{c}"),
                    ..Default::default()
                },
            },
            // +1 按钮
            @uiTypes.FlatNode::{
                id: 2U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::BUTTON,
                props: @uiTypes.Props::{
                    text: Some("+1"),
                    on_click: Some(1U),
                    ..Default::default()
                },
            },
            // -1 按钮
            @uiTypes.FlatNode::{
                id: 3U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::BUTTON,
                props: @uiTypes.Props::{
                    text: Some("-1"),
                    on_click: Some(2U),
                    ..Default::default()
                },
            },
        ],
    }
}

pub fn handle_event(event_id: UInt, _payload: String?) -> @uiTypes.UiTree {
    match event_id {
        1U => count.val = count.val + 1
        2U => count.val = count.val - 1
        _ => ()
    }
    render()
}
```

### 待办事项插件

```moonbit
// gen/world/uiPlugin/todo.mbt

let todos: Ref[Array[String]] = Ref::new([])
let input_value: Ref[String] = Ref::new("")

pub fn render() -> @uiTypes.UiTree {
    let mut nodes: Array[@uiTypes.FlatNode] = [
        // 标题
        @uiTypes.FlatNode::{
            id: 0U,
            parent_id: None,
            kind: @uiTypes.NodeKind::VIEW,
            props: @uiTypes.Props::{
                width: Some(400.0),
                padding: Some(16.0),
                background_color: Some(@uiTypes.Color::{
                    r: 30b, g: 30b, b: 46b, a: 255b
                }),
                ..Default::default()
            },
        },
        @uiTypes.FlatNode::{
            id: 1U,
            parent_id: Some(0U),
            kind: @uiTypes.NodeKind::TEXT,
            props: @uiTypes.Props::{
                text: Some("Todo List"),
                ..Default::default()
            },
        },
        // 输入框
        @uiTypes.FlatNode::{
            id: 2U,
            parent_id: Some(0U),
            kind: @uiTypes.NodeKind::INPUT,
            props: @uiTypes.Props::{
                text: Some("Add new item..."),
                value: Some(input_value.val),
                on_input: Some(1U),
                ..Default::default()
            },
        },
        // 添加按钮
        @uiTypes.FlatNode::{
            id: 3U,
            parent_id: Some(0U),
            kind: @uiTypes.NodeKind::BUTTON,
            props: @uiTypes.Props::{
                text: Some("Add"),
                on_click: Some(2U),
                ..Default::default()
            },
        },
    ]

    // 渲染待办项
    let mut id: UInt = 4U
    for item in todos.val {
        nodes.push(@uiTypes.FlatNode::{
            id: id,
            parent_id: Some(0U),
            kind: @uiTypes.NodeKind::TEXT,
            props: @uiTypes.Props::{
                text: Some("- \{item}"),
                ..Default::default()
            },
        })
        id = id + 1U
    }

    @uiTypes.UiTree::{ nodes: nodes }
}

pub fn handle_event(event_id: UInt, payload: String?) -> @uiTypes.UiTree {
    match event_id {
        1U => {
            // 输入事件
            input_value.val = payload.unwrap_or("")
        }
        2U => {
            // 添加按钮
            if input_value.val != "" {
                todos.val.push(input_value.val)
                input_value.val = ""
            }
        }
        _ => ()
    }
    render()
}
```

---

## 构建与运行

### 构建 WASM 组件

```bash
cd plugins/my-plugin

# 1. 构建 WASM
moon build --target wasm

# 2. 嵌入 WIT 定义
wasm-tools component embed wit/ target/wasm/release/build/gen/gen.wasm \
    --encoding utf16 -o my-plugin.wasm

# 3. 创建组件
wasm-tools component new my-plugin.wasm -o my-plugin.component.wasm
```

### 运行插件

```bash
# 使用 Cargo
cargo run --bin moui -- plugins/my-plugin/my-plugin.component.wasm

# 或使用编译后的二进制
./target/release/moui plugins/my-plugin/my-plugin.component.wasm
```

### 一键构建脚本

创建 `build.sh`：

```bash
#!/bin/bash
set -e

PLUGIN_NAME=${1:-"my-plugin"}
PLUGIN_DIR="plugins/${PLUGIN_NAME}"

echo "Building ${PLUGIN_NAME}..."

cd "${PLUGIN_DIR}"

moon build --target wasm

wasm-tools component embed wit/ target/wasm/release/build/gen/gen.wasm \
    --encoding utf16 -o "${PLUGIN_NAME}.wasm"

wasm-tools component new "${PLUGIN_NAME}.wasm" \
    -o "${PLUGIN_NAME}.component.wasm"

echo "Build complete: ${PLUGIN_DIR}/${PLUGIN_NAME}.component.wasm"
```

使用方式：

```bash
chmod +x build.sh
./build.sh counter
```

---

## 调试技巧

### 1. 检查 WASM 组件

```bash
# 查看组件导出
wasm-tools print plugins/counter/counter.component.wasm
```

### 2. 常见错误

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `No component loaded` | 未加载 WASM 文件 | 检查文件路径是否正确 |
| `Missing WIT interface` | 接口未实现 | 确保 `render()` 和 `handle_event()` 已导出 |
| `Invalid component format` | 非组件格式 | 使用 `wasm-tools component new` 创建组件 |

### 3. 日志输出

在 MoonBit 中使用 `println` 进行调试：

```moonbit
pub fn handle_event(event_id: UInt, payload: String?) -> @uiTypes.UiTree {
    println("Event received: \{event_id}")
    // ...
}
```

注意：需要 WASI 支持（已在 `moui-host` 中启用）。

### 4. 类型检查

```bash
# 检查 MoonBit 代码
moon check
```

---

## 最佳实践

### 1. 状态管理

使用 `Ref` 管理可变状态：

```moonbit
let state: Ref[MyState] = Ref::new(initial_state)
```

### 2. 节点 ID 分配

使用常量或枚举管理节点 ID：

```moonbit
let ROOT_ID: UInt = 0U
let HEADER_ID: UInt = 1U
let CONTENT_ID: UInt = 2U
```

### 3. 事件 ID 规划

使用有意义的命名：

```moonbit
let EVENT_INCREMENT: UInt = 1U
let EVENT_DECREMENT: UInt = 2U
let EVENT_RESET: UInt = 3U
```

### 4. Props 默认值

创建辅助函数减少重复代码：

```moonbit
fn default_props() -> @uiTypes.Props {
    @uiTypes.Props::{
        width: None,
        height: None,
        padding: None,
        background_color: None,
        text: None,
        value: None,
        on_click: None,
        on_input: None,
    }
}

fn text_props(text: String) -> @uiTypes.Props {
    @uiTypes.Props::{
        text: Some(text),
        ..Default::default()
    }
}
```

---

## 参考资源

- [WIT 规范](https://github.com/WebAssembly/component-model/blob/main/design/mvp/WIT.md)
- [Wasmtime 文档](https://docs.wasmtime.dev/)
- [MoonBit 语言指南](https://moonbitlang.github.io/moonbit-lang/)
- [wit-bindgen 工具](https://github.com/bytecodealliance/wit-bindgen)
