# Plan: MoUI Studio 积木独立——OnStart 启动事件 + 语句/内建补全

- **Status**: active（OnStart + ForEach + 内建补全已落地；全套 4846/4846 绿）
- **Goal**: 「启动」窗体级事件让纯逻辑程序成为可能（不依赖控件:装填后立即
  执行,两轨同语义,差分门禁覆盖）;语句面补齐 for-each 与列表/字符串/数学内建,
  语句骨架表全类目可达。
- **Non-goals**: 声音/画笔/克隆/多角色;多窗体。

## 已核实事实

| 事实 | 锚点 |
|---|---|
| 窗体级事件 = control_name == ""，现仅 OnTimer/OnBroadcast | `domain/ir/invariants.mbt:124` |
| CreateHandler 门控复制同清单;inspector 窗体级入口枚举同清单 | `app/update.mbt:692`、`app/ide_context.mbt:1192` |
| DSL 只渲染 handler **体**（事件头由 IR 挂载）——OnStart 无需新语法 | `domain/studio_lang/printer.mbt:16` |
| 运行语义 = 装填不执行;OnStart 在装填后立即执行（广播 drain 同款 merge） | `app/update_run.mbt:99`、`1250` |
| diff 门按 handler 体驱动（`diff_case(program, handler, …)`）——OnStart 体天然覆盖 | `services/diff/matrix_test.mbt:361` |
| 导出 runner 按 (control,tag) 派发,`Model::new` 末尾补发 OnStart 即得 | `tools/export_runner_template/runner.mbt:88` |
| 导出内核内嵌一份 IR 文本（kernel_ir.mbt）需同步枚举 | `services/export/kernel_ir.mbt:66-88` |

## 设计

1. **OnStart（G7.1a/b）**：`EventKind::OnStart`（tag `on_start`）；
   invariants/CreateHandler 门/inspector 枚举三处同步；解释轨
   `start_run` 装填后 fire（`fire_onstart_interp`，广播 drain 同款
   vars/texts 回写）；编译轨 `start_compiled_run` fire
   （`lower_handler`+`run_handler`）；导出 runner `Model::new` 末尾
   `run_event("", on_start)`；i18n `event.on_start`（当程序启动/On start）。
2. **语句补全（G7.1c/d，九面全套）**：
   - `ForEach(列表, 元素变量, 体)` 语句;
   - 列表内建：`插入列表(表,i,v)` / `删除列表(表,i)` / `替换列表(表,i,v)` /
     `查找列表(表,v)`（返回下标或 0）;
   - 字符串内建：`连接(a,b)` / `取字符(s,i)` / `大写(s)` / `小写(s)`;
   - 数学内建：`正弦(x)` / `余弦(x)` / `对数(x)`;
   - 每构造过九面：parser/printer（双语）/interp/codegen/compiled_runtime/
     blocks/codec/signature + 双轨差分门用例;语句骨架表补到全类目可达。
3. **验收**：无控件纯 OnStart 程序可写可跑，两轨审计逐位一致;门禁新用例绿。

## 实施记录（2026-10-07）

- OnStart：全链落地（IR/invariants/创建门/inspector/两轨装填后派发/导出 runner/门禁用例），commit 9b879870a。
- ForEach：九面全套（含 FeInit/FeCheck 指令、隐藏列表槽 @i{n}#l 内部命名、blocks BkForEach、kernel 同步再生），commit 7427bb33b。
- 内建补全：insert_list/remove_list/replace_list/index_of_list/join/letter/upper/lower/sin/cos/log 十一个，五面（目录/解释/编译/codegen/blocks 端口类型）+ 面板骨架 + i18n；正弦/余弦/对数用本地级数实现（两轨逐字同实现保位型一致），门禁用例 builtins-g7 守住。
- 骨架表：for_each/内建 11 条全部可解析可达（blocks_slot 两条不变式自动守住）。

## 边界声明

- 积木视图对 OnStart handler 的呈现复用「选中即编辑」通道（selected_handler
  键），帽块沿用事件分类;专属「启动 hat」外观随后续形状切片打磨。
- 本计划先落 OnStart;语句补全（1c/d）按九面节奏逐构造提交。
