# MoMao（墨卯）App Notes

## Package

- `examples/momao`（module `examples/momao`，2026-09-27 建立）：中英双语可视化
  编程 IDE，单一程序 IR 支撑「窗体设计 / 积木编排 / 双语代码」三视图 + 结构化
  AI 提案 + 闸门化运行 + 独立应用导出。计划：`docs/plans/active/momao.md`。
  前身 `examples/moeui_studio` / `examples/moblocks_studio` 已删除（git 历史
  e7cfe78e2 / a29eb8e3d 可查），salvage 映射见计划第 11 节。
- 结构（计划口径）：`domain/{ir,momao_lang,codec,blocks,proposals}` 零 UI 依赖、
  `services/{export,model_provider,provider_native}`、`app/`（TEA + 五视图，
  native+wasm-gc）、`web_wasm/` + `macos_skia/` 薄入口、`tools/{sync_kernel,
  emit_bundle}`。
- 最小循环：`moon test examples/momao/app --target native|wasm-gc`、
  `moon build examples/momao/web_wasm --target wasm-gc`、
  `node scripts/generate-i18n-catalogs.mjs ... --check`、
  `moon run examples/momao/tools/sync_kernel --target native -- --check`。

## 产品决策（重写时不要推翻）

- IR 是语句级（Assign/If/CountLoop/WhileLoop/Break/Call），不是自由图；
  积木与代码都是 IR 的投影，代码视图是文本真身。
- DSL 关键字是 catalog 数据（`domain/momao_lang/keywords.mbt` 中英两张表），
  解释器内禁止 `keyword == "如果"` 式硬编码分支；往返测试
  `parse(render_zh(ir)) == ir == parse(render_en(ir))` 是硬门。
- 内核语言中立：ParseError/RunError 只给结构化 `{kind,line,col,token?}`，
  可读文案全部由界面层经 `moui_i18n` catalog 解析（key 不进领域层）。
- `提交数据` 是闸门化模拟动作（确认卡 + 审计），v1 不发起真实网络请求；
  web 端只走确定性假模型，真实 OpenAI 兼容 provider 仅 native。
- 真实模型默认配置：阶跃星辰 StepFun，endpoint
  `https://api.stepfun.com/step_plan/v1`，model `step-5-preview`。**凭据
  唯一来源是 gitignored 的 `examples/momao/.config.json`**
  （`{provider:{endpoint,model,api_key}}`，根 .gitignore 第 52 行登记）：
  native 组合根启动读取预填面板；`services/provider_native` 的
  `load_provider_config` + live smoke 测试（配置缺失即跳过）。key 禁止进
  源码/项目文件/导出 bundle（有测试断言）；endpoint/model 可改，默认模式
  仍是假模型。
- 可读性是一等目标：AI 生成的每个 handler 必带双语 `note`（意图说明），
  命名必须自解释（`a1`/`tmp` 类被校验拒绝），同一 IR 渲染逐字节稳定，
  AI 面板「解释这个程序」逐语句产出当前语言讲解。
- 框架扩展按需允许：新控件走 `moui/views` 具体 `ViewNode` +
  `View::from_node`（core 不加枚举变体），带测试与文档，decision log 记录
  理由；默认优先用现有控件组合。
- i18n：语言存 app model + settings 快照（mo_desktop 模式），入口经宿主回调
  同步 `Environment.locale`（website 模式）；shared app 不 import runtime。

## 工具链陷阱（2026-09-25/26 实测，moon 0.1.20260920）

- `derive(Eq, Debug)` 在新模块触发 `implicit_impl_as_method` 警告（每个 derive
  一条，原因未定位）。**对策：app 包默认零 derive**（counter 风格），枚举比较
  用 `is` 模式，断言用 `assert_true(x is Variant)`。
- `Map::new()`→`Map([], capacity=16)`；`Array::new(capacity=n)`；
  `Option.or(x)`→`unwrap_or(x)`；`not(expr)`→`!expr`；`derive(Show)` 废弃
  （用 Debug）。`assert_eq` 需要 `Eq + Debug`。
- 测试文件（`*_test.mbt`）是独立包：同包函数须 `@app.` 前缀（否则
  test_unqualified_package 警告），枚举构造器可裸用；跨包 struct 字面量要求
  `pub(all) struct`。
- `@json.parse(text) catch { _ => ... }` 可直接接 String；`Json::stringify()`
  是紧凑格式（断言别带空格）；`Number(Double, repr~)` 双字段。
- `guard` 是关键字不能当变量名；`Array` 没有 `find` 方法（手写 for 循环）；
  `Array::fold` 参数顺序易错；MoonBit 字符串里 `{` 字面量就是 `"{"`。
- 源码行预算：`validate-maintenance-baseline` 默认 1800 行/文件硬线；
  `app.mbt` 超 ~1200 行按架构拆 `view.mbt`。

## 画布 / 指针 / 框架坑（全部实测过）

- `@views.canvas(measure, draw)` + `on_drag_with_frame` 足够做命中/拖拽，
  无需自定义 ViewNode；绘制逻辑拆纯数据 draw-plan 后可断言 op 数量做帧基线。
- canvas draw 里必须 `push_clip(ctx, frame)`/`pop_clip`；canvas measure 不要
  狮子大开口（column flex 会被撑爆，用 `frame(scroll_view(...), height=...)`
  封顶）。Transform2D 组合用结构体字面量。
- **`AppServices::new()` 不能在 update 闭包里每次构造**：wasm-gc 下所有指针
  事件静默失效。在 `program()` 构造时捕获一次 `environment.services()`。
- 坐标：canvas 的 `DrawText.frame` 是**画布局部坐标**，指针是屏幕坐标；旧
  测试混用过（偏移 42px 的误判，见 `docs/plans/done/row-child-hit-testing.md`）。
  UI 测试定位控件用 `read_semantics` 找 `semantics_label` 节点的 frame。
- `DragGesturePhase::Started` 发生在第一次越过 3px 阈值的 Move，不是 Down；
  测试先发小步进再发完整位移。画布同名文本用 `+` 前缀消歧。
- `text_field` 首参是当前值、`on_input` 带新值；`scroll_view(view, width~,
  height~)` 裁剪命中区。

## provider IO 要点

- `moonbitlang/async/http` **只有 native 目标**：wasm-gc 下 `@http.post`
  解析不到 → app 只依赖 provider 包的纯函数部分，native 组合根把
  `provider_submit` 闭包传进 `program(provider_submit~)`。
- async 组合：`async fn main` + `@async.all([window_task, worker_task])`，
  窗口侧 `run_async_pump()`，worker 侧 `@async.with_task_group` +
  `queue.get()` + `group.spawn_bg`。HTTP：`@http.post(url, body, headers={
  "Authorization": "Bearer " + key })`，响应 `(resp, data)`。
- `Queue::try_put` 会 raise，`ignore(x catch { _ => false })`；结构体字段里的
  回调调用写 `(job.on_result)(result)`。key 只存会话内存，测试断言 encode
  产物不含 key。

## 导出 bundle（两个硬骨头，2026-09-26 实测解决）

1. **Web 运行时 JS 只能来自 `.mooncakes`**：导出的 `index.html` 引用
   `../.mooncakes/wzzc-dev/moui_web_renderer/runtime.js`（相对 web_wasm/），
   其内部 `../moui/backend/web/browser_runtime.js` 才能解析到 bundle 自己的
   `.mooncakes`。不要把 JS 拷进 bundle 或嵌成 MoonBit 常量（1800 行预算 +
   与 moon.mod 固定版本脱钩）。
2. **wasm 链接器只导出可执行包自身定义的函数**：`link.exports` 只登记符号，
   符号必须在可执行包自己的 `.mbt` 里定义，否则静默 DCE（浏览器报
   `must export web_dispatch_event`）。修法：可执行包含一个机械 `abi.mbt`
   逐个 `pub fn web_xxx(...) { @web.web_xxx(...) }` 转发。
- `#|` 多行字符串**不做 `\{x}` 插值**（原样输出）；sync_kernel 同步内核时
  若加倍反斜杠会静默改变语义——bundle 里的 .mbt 与源文件必须 `cmp` 逐字节
  相同。`moon fmt` 也会造成内核漂移，`--check` 门必须常驻。
- 导出自包含应用的最小充要条件：领域内核（ir/momao_lang/codec，零 UI 依赖，
  只允许 `@graphics.Color` 与 `@json`）+ 一个 ~150-200 行通用 TEA runner。
  内核之间可互调，**不能调用非内核文件里的函数**（workspace 外构建才报错，
  例：`auto_layout` 曾被 ai_generation 持有导致 bundle 编译失败）。
- 浏览器里导出应用的逻辑坐标 == CSS 坐标（宿主按画布尺寸重排），不要再按
  DPR 换算。

## 2026-09-27 P1 落地后新增事实

- **模块已成形**：`examples/momao` 独立 module，五个领域包 + services×3 + tools×2 +
  app + web/macos 入口。全量测试：domain 51 + app 14 + model_provider 5 + export 8
  （双目标）+ provider_native 2（native）。
- **最小循环**：`moon test examples/momao/domain/<pkg> --target native|wasm-gc`、
  `moon test examples/momao/app --target native|wasm-gc`、
  `moon run examples/momao/tools/sync_kernel --target native -- --check`、
  `moon run examples/momao/tools/emit_bundle --target native -- <project.json> <name> <dir>`。
- **IR 是语句级**（Declare/Assign/If/CountLoop/WhileLoop/Break/Call；If 带
  else-if 链数组）；内建 14 个（12 + row_count/row_at）；闸门 2 个
  （ask/submit_data）。IR 存规范 id（英文），源码名按语言表渲染。
- **解释器是指令机**（编译 AST→跳转指令），不是树遍历：聚光灯/闸门暂停/单步/
  审计全部由此而来。闸门恢复 = 预置 answer 后重跑同一指令（表达式位只有闸门
  有副作用，重跑安全）。
- **控件名参数**：`取文本(姓名框)` 的姓名框是控件名（Var 裸标识符），不是变量；
  `RunState::control_name` 处理 Var/StrLit/其它。
- **MoonBit 实战坑（新增）**：enum 声明位不接受 `@pkg.Type`（要用类型别名）；
  `?` 操作符本版本不可用（显式 match 传播）；`[...arr, x]` spread 不可用；
  `String.trim()` 返回 StringView（要 `.to_string()`）；`Array` 无 `at/find/
  find_last`；`StringBuilder` 无 `length`；`String` 无 repeat/join（手写）；
  跨块 mut 捕获会被判 unused_mut（分段构造再拼接）；标签参数调用是 `name=value`
  或 `name~` 简写，不是 `name~=value`；`Json` 布尔构造器是 `True/False`；
  `Translator::new` 要 `Locale` 不是 String；`String.replace` 要 `old=/new=`
  标签参数；`Map.get` 读；`parse_*` 位置 `?` 不行。
- **运行期活状态**：app Model 持有 runtime_values/runtime_texts，跨事件累积；
  运行结束时 merge_run_back 并回。
- **导出 bundle**：内核常量按源文件一个常量一条，但**常量文件仍按行预算拆组**
  （kernel_momao_lang + kernel_momao_lang_rt 两组；1800 行/文件硬线）；bundle
  里 kernel .mbt 必须与源逐字节一致（cmp 验证）；独立构建需 `moon update`
  拉 mooncakes.io。emit_bundle 签名：`<project.json> <app-name> <target-dir>`。
- **i18n**：app 自带 230 条中英 Message（手写 catalog，不走 generate 脚本——
  示例包不引入 JSON 加载）；文案全部 key 化（含 DSL 错误 kind 映射）。
- **假模型**：`fake_model_completion(prompt, current_program)` 全量构建语义
  （先 remove 全部再加），关键词路由中英文混合。

## 2026-09-27 收官两项（verifier 补齐）

- **i18n 生成链**：数据在 `examples/momao/app/i18n/{zh-Hans,en}.json`（manifest
  `catalogs.json`），`node scripts/generate-i18n-catalogs.mjs --input … --out …`
  生成 `i18n_catalog_generated.mbt`（GeneratedI18nCatalog + Text/Plural），
  app/i18n.mbt 只做适配（momao_messages 打平成 @i18n.Message）。`--check` 步骤
  名 "momao i18n catalogs"（checks/profiles.json）；生成文件需同时进
  `checks/source-file-policy.json` 的 generated 白名单（header/maxLines/
  checkCommand 三项照抄 website 条目改路径）。
- **积木编辑回写**：`domain/blocks` 的 BlockItem 带 `path : Array[Int]`
  （If: [i,0,j] then / [i,1,k,j] else-if / [i,2,j] else；循环: [i,2,j]）；
  手术函数 replace_stmt_at/delete_stmt_at/stmt_at 是**就地语义**（数组引用），
  测试里先后读同一数组会互相污染——先固定期望值再操作。
- **测试陷阱**：`@ir.Call` 在 Stmt 数组里与 `@ir.Expr::Call` 歧义，写
  `@ir.Stmt::Call` 消歧；MoonBit for 循环里给 `on_click` 传下标要先
  `let row_index = index` 固定（闭包捕获）。
