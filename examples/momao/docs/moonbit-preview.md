# MoonBit 源码预览（毕业通道 v1.1）

MoMao 的第四个模式 tab「MoonBit」把当前程序渲染成**人可读的 MoonBit 源码预览**。
它回答教学里最常见的问题："我做的这个东西，真代码长什么样？"

## 边界（先说清楚）

- **只生成文本，不是可编译产物**。预览用于学习与审阅；程序唯一事实来源是 `.momao.json` 程序 IR。
- 生成结果**逐字节确定**（快照测试锁定 `services/export/moonbit_preview_test.mbt`）。
- 预览随三视图同源更新：改设计/积木/代码，MoonBit 预览即时反映。

## 映射规则

| IR | 预览 |
|---|---|
| 窗口/控件/变量 | 注释清单（id、类型、名、矩形、文本、选项数） |
| 事件子程序 | `fn handler_<序号>_<控件id>_<事件>()`，双语 note 作意图注释 |
| `Declare(x, e)` | `let x = e` |
| `Assign(x, e)` | `x = e` |
| `If(c, then, else_ifs, else)` | `if c { } else if c { } else { }` |
| `CountLoop(n, i, body)` | `for i in 0..<n { }`（无循环变量用 `_`） |
| `WhileLoop(c, body)` | `while c { }` |
| `Break` | `break` |
| `Call(cmd, args)` | `cmd(arg, …)`（内建规范名） |
| 表达式 | 中缀括号形式，运算符用规范符号（`+ - * / = <> < > <= >= and or`） |

函数名用 ASCII 安全形式（MoonBit 标识符约束），控件/变量的人类语义保留在注释行与表达式名里。

## API

`@export.moonbit_preview(program : @ir.MomaoProgram) -> String`（`services/export/moonbit_preview.mbt`，纯函数、零 UI 依赖）。
