# `.momao.json` — 程序 IR 格式

`format: "momao.project"`，`version: 1`（不匹配整单拒绝；未来版本走显式迁移）。
文件存的是 **IR 本身**，不是任何一门前语言的源码——代码视图只是渲染。

```json
{
  "format": "momao.project",
  "version": 1,
  "window": { "title": "班级点名册", "width": 640, "height": 480 },
  "controls": [
    { "id": 1, "kind": "button", "name": "点名按钮", "text": "随机点名",
      "x": 20, "y": 320, "width": 120, "height": 36, "items": [] },
    { "id": 2, "kind": "list_box", "name": "名单", "text": "",
      "x": 360, "y": 20, "width": 160, "height": 150,
      "items": ["张三", "李四"] }
  ],
  "variables": [ { "name": "人数", "init": "0" } ],
  "handlers": [
    {
      "control": "点名按钮",
      "event": "on_click",
      "note": { "zh": "按名单行数抽一位同学", "en": "pick a random student" },
      "body": [
        { "op": "declare", "name": "人数",
          "expr": { "t": "call", "name": "row_count", "args": [ { "t": "var", "v": "名单" } ] } },
        { "op": "declare", "name": "序号",
          "expr": { "t": "call", "name": "random", "args": [ { "t": "var", "v": "人数" } ] } },
        { "op": "call", "name": "set_text", "args": [
          { "t": "var", "v": "结果" },
          { "t": "call", "name": "row_at", "args": [
            { "t": "var", "v": "名单" }, { "t": "var", "v": "序号" } ] } ] }
      ]
    }
  ]
}
```

## 字段规则 / Field rules

- `controls[].kind`：`button | label | text_field | check_box | list_box | table`
- `handlers[].event`：`on_click`（button/list_box/table）、`on_change`
  （text_field/check_box/list_box）；每对（控件, 事件）唯一。
- `controls[].items`：列表框选项 / 表格初始行。
- `note`：双语「意图说明」。AI 提案新增/修改的 handler **必须**填写
  （可读性契约）；代码视图把它渲染为注释头。
- `body` 语句：`declare | assign | if | count_loop | while | break | call`；
  表达式：`num | str | bool | var | not | neg | bin | call`。
- 不变量（解码即校验）：名称唯一且语法合法、handler 引用存在的控件与
  受支持事件、控件 ≤ 128、变量 ≤ 64、handler ≤ 64、单 handler 语句 ≤ 512、
  总计 ≤ 4096、循环嵌套 ≤ 64、表达式深度 ≤ 32、`break` 在循环内、
  内建名/参数个数合法、命令不出现在表达式位。

## 提案 / Proposals（AI 唯一产出）

```json
{ "version": 1,
  "summary": { "zh": "…", "en": "…" },
  "window": { "…": "可选" },
  "controls":    { "add": [...], "update": [...], "remove": ["名字"] },
  "variables":   { "add": [...], "update": [...], "remove": ["名字"] },
  "handlers":    { "add": [...], "update": [...],
                   "remove": [{"control": "…", "event": "on_click"}] },
  "open_handler": { "control": "…", "event": "on_click" } }
```

校验链：schema → IR 不变量 → 双语 parser → 预算 → 可读性（note 必填、
命名自解释，`a1`/`tmp`/`x` 式命名被拒）。任一失败**整单拒绝**并列出全部原因。
采纳前用户看到字段级 diff（新增/修改/删除 + 旧值 → 新值）。
