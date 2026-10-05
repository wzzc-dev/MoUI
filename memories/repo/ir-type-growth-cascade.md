# IR 类型生长(穷举 match 生态)安全操作

MoUI Studio 的 `domain/ir` 类型生长(加变体/加字段)会打破全仓穷举 match。
M5-5c(struct/VStruct/FieldAccess)已完成;M5-5d(enum+match)尝试后回滚。

## 已验证流程

1. 先写九面变更清单(参考 `docs/plans/active/moui-studio-workbench.md` Progress
   2026-10-04 M5-5c 规格行),一次一个面提交,每步跑 `moon check` + 包测试。
2. 类型定义与构造点同 commit;字面量补字段用精确 Read+Edit,
   **禁用盲目脚本插入**——`structs: [],` 曾被误插进 RunState 字面量、函数签名、
   FuncDef 字面量(MoonBit 把 `structs:` 解析为新绑定,产生连锁 parse error)。
3. 花括号深度配对插入必须先剥离字符串字面量内容再计数
   (`re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)`),测试文件里有孤立 `{`/`}` 的
   JSON/代码字符串,裸计数会插错位置。
4. StudioProgram 字面量含 `..program` 展开时不需要补新字段(展开已携带)。

## 当前状态(2026-10-04)

- **M5-5c 全部完成**:IR(FieldAccess/StructDecl/structs 字段)、VStruct 运行时
  (interp + compiled_runtime 求值/get_field/codegen lowering)、parser(`.`
  字段访问 + 顶层 struct 声明,类型词表 text/number/int/bool 双语宽进、IR 存
  规范 id)、printer(render_struct_declarations 往返硬门)、codec(structs
  可选段,旧文件兼容)、blocks(字段访问唯一洞口 = 基底 slot 0)、语义校验
  (validate_program_language 把关类型词表)。
- **M5-5d 也已完成**(2026-10-04,规格先行、一面一面提交):枚举标签 v1
  (无载荷)——`EnumDecl{name,cases}`、`Expr::EnumTag`(canonical
  `花色::红桃`,lexer DoubleColon)、`Stmt::Match(subject,arms,else 必在可空,
  arms=[MatchArm])`、`Value::VEnum(e,c)`、解释轨 `CaseOf` 指令(subject 单次
  求值,审计 `canonical -> case` 与 if 同格式)、codegen 生成
  `match rt.enum_case(...)`、blocks 线性路径(section i=arm i,n=else)、
  blocks_code 分派审计行诚实 non_editable(OpCondition 标记)。
- **M5-5e 已完成**(2026-10-04):代码视图默认 MoonBit 外观
  (`generate_handler_source` 同源显示),中英 DSL 降级为显示外观
  (`CodeAppearance` + `CycleCodeAppearance`);编译轨 handler 改从 IR 推导
  (`traced_from_stmts`),不再解析显示草稿——显示与运行轨解耦。
  编辑语义(提交/诊断/块断言)在 DSL 外观下验证。
- **未做**: M6(教学切换)、M7(拼图外观)、M8(收尾)。
- 验证基线: app 308/308 双目标;模块全量 native 4722、wasm-gc 3130;
  静态门六项全绿;改 domain/studio_lang 或 codec 后必须跑
  `moon run examples/moui_studio/tools/sync_kernel --target native`
  (kernel 是逐字节镜像,`--check` 报 DRIFT)。
- **维护基线坑**: 文件超 1800 行(未跟踪阈值)会挂
  validate-maintenance-baseline——domain 文件长大时需在
  `tools/moui/validate_maintenance_baseline/line_budget_catalog.mbt`
  加带 reason 的 ratchet 条目。
