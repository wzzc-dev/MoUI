# MoUI Studio DSL 规范 / MoUI Studio DSL Spec

> IR 是唯一事实来源；源码只是渲染。同一 IR 在两种语言间 `parse(render_lang)` 往返一致。

## 语句 / Statements

| 概念 | zh-Hans | en |
|---|---|---|
| 声明变量 | `变量 x = 1` | `let x = 1` |
| 赋值 | `x = x + 1` | `x = x + 1` |
| 分支 | `如果 条件 则 … 否则如果 条件 则 … 否则 … 结束` | `if c then … elseif c then … else … end` |
| 计数循环 | `计次 3 次 为 i … 结束` | `repeat 3 times as i … end` |
| 条件循环 | `当 条件 循环 … 结束` | `while c do … end` |
| 跳出 | `跳出循环` | `break` |

赋值前必须声明（未声明会得到结构化错误 `NotDeclared` 与中文/英文提示）。
`跳出循环` 只能出现在循环内。

## 表达式 / Expressions

- 字面量：`1` `3.5` `"文本"` `真`（`true`）`假`（`false`）
- 运算符：`+ - * /`（`+` 兼作文本拼接）、`= <> < > <= >=`（兼容全角与 `≠ ≤ ≥`）、
  `且`/`and`、`或`/`or`、`非`/`not`、一元 `-`
- 括号分组；右子节点同优先级自动加括号（打印器保证往返保真）
- 全角标点（（），＋－＝＜＞）与全角数字在词法层归一化
- `//` 行注释

## 内建 / Builtins

| 规范 id | zh | en | 种类 | 参数 |
|---|---|---|---|---|
| `message_box` | 信息框 | message_box | 命令 | (文本) |
| `set_text` | 设置文本 | set_text | 命令 | (控件, 文本) |
| `append_row` | 追加行 | append_row | 命令 | (控件, 文本) |
| `get_text` | 取文本 | get_text | 函数 | (控件) |
| `get_number` | 取数值 | get_number | 函数 | (控件) |
| `to_text` | 转文本 | to_text | 函数 | (值) |
| `text_length` | 取长度 | text_length | 函数 | (文本) |
| `contains` | 文本包含 | contains | 函数 | (文本, 子串) |
| `random` | 随机数 | random | 函数 | (上界) |
| `row_count` | 取行数 | row_count | 函数 | (列表框/表格) |
| `row_at` | 取行 | row_at | 函数 | (列表框/表格, 行号) |
| `selected_row` | 取所选行 | selected_row | 函数 | (列表框/表格) |
| `ask` | 询问 | ask | 闸门 | (问题) |
| `submit_data` | 提交数据 | submit_data | 闸门 | (数据, 目标) |

- 控件名参数（`取文本(姓名框)`）是**控件名**（裸标识符），不是变量。
- 命令只能出现在语句位；函数与闸门可以出现在表达式位。
- `ask` 返回逻辑值；`submit_data` 是唯一外发动词，**闸门化模拟**：
  执行到它时程序暂停，展示「送到哪、送什么」，用户确认/拒绝后继续，
  两者都记入执行记录；v1 不发起任何真实网络请求。

## 执行语义 / Execution

- 指令机（不是树遍历）：分支/循环编译为跳转；暂停、单步、聚光灯因此天然支持。
- 步数预算默认 100,000（防死循环冻结 UI）；循环嵌套 ≤ 64；
  单 handler ≤ 512 条语句。
- 随机数由可播种 RNG 驱动（同样输入 → 同样输出，测试可复现）。
- 运行期活状态（变量值、控件文本）跨事件累积——再点一次按钮，
  `营业额` 接着上次的数。

## 错误 / Errors

内核返回结构化错误（`{kind, line, a, b}`），界面层本地化，例如：

- `NotDeclared`：变量「营业额」未声明（请先写：变量 营业额 = …） / Variable `x` is not declared (write `let x = …` first)
- `TypeMismatch` / `ArityMismatch` / `StepBudget` / `DivideByZero` …
