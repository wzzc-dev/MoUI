# TUI 输出路径(moui_tui / moui_tui_renderer / moui_terminal_host)

- 终端是**输出路径**,不是平台 route:`checks/platform-matrix.json` 是「canonical 14 routes」契约,`tools/moui/validate_platform_matrix` 会断言数量,并且每条 route 都带 pixel 语义字段(showcasePackage/evidenceFile/renderer+target)。非窗口类输出应写成 `docs/platform-readiness-declaration.md` 里的 variant 段落(先例:`linux-skia-riscv64`),不要加第 15 条 route。矩阵 doc 块 `<!-- BEGIN/END GENERATED PLATFORM TIER MATRIX -->` 由 `generated_docs.mbt` 再生成,内部手改必被 gate 打回。
- `checks/release-modules.json` 只有 name/directory/publication/role/releaseStage,**没有** ready/experimental 布尔。`ready=false` 的诚实声明去处是 `docs/release-readiness.md` 与 `docs/platform-readiness-declaration.md`。
- 给 `tools_product/moui/validate_renderer_capability_consistency` 的 `moon.pkg` 加 renderer 依赖**不够**,必须同时在 `tools_product/moon.mod` 的 imports 加模块,否则 solve 报 "containing module is not imported by wzzc-dev/moui_product_tools"。能力表校验通过的 cells 数 = 17 features × 自报列数(当前 4 列 = 68);新增列会改这个数,文档里引用它要一起改。
- 投影 damage 不能由「写时 dirty」决定:同一 frame 内同一 cell 会被写多次(边框 → 内容抢占 → 帧末清扫),写时 `mark_row` 会把最终内容完全相同的行标脏。正确做法是把 `take_damage()` 当**候选行集**,逐行与「上次真正写进终端的 grid」比对,只发真正不同的行(`Canvas::present_update`)。副作用可复验:树不变 → 0 字节。
- `@moui_tui.TermScreen::resize` 是**终端语义**(保留内容、溢出行进 scrollback),而投影层把 `line_at(y)` 当「可见第 y 行」读——shrink 之后会把 scrollback 快照发出去,并且旧布局残格因 `prev_owners` 复位而扫不到。修在 renderer:`Canvas::resize` 里 `clear_all` 并按新尺寸重建 `sent`。不要为了投影去改 buffer 的终端等价性(`examples/terminal` 的流式 app 依赖它)。
- 键位路由策略化(capture/bubble + 认领结果)**不需要**改 `moui/runtime`:五趟顺序里 pass 3 是 app 可用的 `Program::with_commands` + `ActionCommand`/`KeyboardShortcut`,binding 每次 update 从 model 重算,所以「谁有焦点谁拿方向键」用现有 API 就能表达。
- 「**视觉盒 = 命中盒**」是 cell 投影的硬不变量:宿主把一次点击换成**格中心**那一个点(`y = (row + 0.5) * cell.height`,见 `moui_terminal_host/input_channel.mbt`),所以 `moui_tui_renderer/project.mbt` 的 `quantize` 只能保留「中心落在帧内」的格。外扩规则(顶边 `floor`、底边 `ceil`)在 `frame_top mod cell_height >= 半格` 时把标签画到点不着的那一行(counter 54x11 实测:标签第 6 行、能点的第 7–8 行)。修这条只允许动 renderer:改命中测试属于 `moui/runtime`(owner 门禁),把宿主点击点挪到格左上角只是把 contested 边换到底边,不解决问题。
- cell 栅格里一根边框要吃一整格,而像素 padding 常小于半格(本仓 demo 是 4px < 8px),所以「边框那一圈格子」和「框里的第一行内容」天然抢同一批格。**规则是继承范围分两条**(`moui_tui_renderer/project.mbt` 的 `Clip`):`chrome` 给区域的边框(等于旧的单一范围,所以 `List`/`Tree` 的框仍和它所属 `ScrollView` 同圈,不会套出第二道框),`content` 是那一圈的内侧,给所有字形与高亮带。只有 `ScrollView` 收窄;框小到没有内侧(43x11 量化成相邻两行)时 `content` 退回整栏,否则窗口一矮两栏就空了。高亮带另外走 `quantize_box`(**没有**残格兜底):一个中心都不属于它的格子不许反白 —— 没有字的色块不是选中。**不要**用「让边框赢」修(外框 `Group` 的环在 12 行窗口里正好占第 0 行标题栏与第 11 行键位提示,边框抢到就是擦掉两者),也不要在 `moui/core`/`moui/runtime` 修(像素侧裁剪本来就是对的,偏差只由量化产生)。
- 证明这条不变量必须用「标签就是控件」的 app(`Button` 自己写 `[`+label+`]`),载体是 `examples/counter/terminal`;`examples/tui_split` 的标签住在 ListItem/TreeItem 的子节点里,行号偏移被子节点定位吃掉,旧规则也照样绿 —— 100x30 的 PTY 套件因此从没抓到过这个错位。`scripts/tui-pty-smoke.sh` 因此构建并导出**三个**产物(`MOUI_TUI_SMOKE_BIN` + `MOUI_TUI_COUNTER_BIN` + `MOUI_TUI_LAYERS_BIN`),少一个就 exit 1,不能让它静默跳过。
- PTY smoke(`sh scripts/tui-pty-smoke.sh`,gate `tui.pty-interaction-smoke`)的完整性判定是时序事实(quiet window 内无新字节)。moon 测试默认并发,多个 PTY 子进程争用同一事件循环会让帧在窗口内迟到 → 用**一把 mutex 串行化 session**,不要靠调大 `QUIET_MS`(只把阈值挪走,且慢 7 倍)。`MOUI_TUI_SMOKE_BIN` 缺失时脚本必须拒绝假通过。
- 样式覆盖层(`Canvas::style_range`)与归属层是**两套规则**,不要合并:反白/底色是**色带**,要整幅铺满量化盒(`Item` 角色自己不写字,S0 规则,文字都在子节点上;盒内格子 `owners==0` 是常态,削掉色带就等于削掉整行高亮)。但 `underline` 这类**跟着字形走的装饰**必须只压在 `owners[y][x] != 0` 的格子上 —— 量化盒比标签宽(counter 焦点按钮 3 行 x 13 格 vs 标签 1 行 3 格),整段照抄 attrs 会在空白行上画出悬空横线(用户报的「点完按钮两根黄线」)。**不要**用「删掉焦点样式里的 underline」或「把高亮带缩到实际写出来的字」修:前者是去掉焦点与选中的唯一视觉区分,后者要 projector 根本没维护的 per-node 绘制跨度。
- 覆盖层因为不认领格子,还欠**自己的擦除账**:`sweep_stale` 只扫 `prev_owners != 0` 的格子,带移走后空格子上的反白/加粗永久残留(2026-10-15 用户报「点过的区域留着无字青块」;40px 行高的带尾是其载体,启动选中的残留最完整)。修在 `Canvas::sweep_stale_bands`:`style_range` 打 `bands`/`prev_bands` 掩码,帧末对「上帧有带、这帧没带也不被画笔认领」的格子刷回默认 attrs。**不要**给覆盖层发归属(会吃兄弟字形),也不要指望 presentation diff(残留格永不再变,那正是缺陷本身)。
- 高亮带是整体覆写 attrs,所以**多带重叠时必须按主权排顺序,不能按绘制序**:点击选中的条目同时收进一个带焦点的内嵌按钮(左栏 ghost 按钮与行同框,右栏标签按钮的盒子从缩进+折叠钮之后才开始),按单遍绘制序按钮带会吃掉行带——实测三个症状:点选的行整行无带(左栏)、点选的树行只剩折叠钮前面一小块反白(右栏)、焦点让位的那一帧里旧选中行闪现反白(左栏「闪一下」)。修在 `project_payload`:样式带拆两小遍,**焦点带先刷、选中带后刷**——选中行整行稳定反白,点哪行哪行亮、死区点击(焦点散了)不再引起带的闪现/消失。焦点与选中同挂一个节点时 `attrs_for` 本来就把两个状态合成一组 attrs,两遍只是重刷同一组;**不要**改回单遍或按绘制序,那等于让按钮的临时焦点态压过行持久的选中态。列表/树断言必须**按列区间**量反白:终端同一行被左右两栏共用,对面的合法选中带不能计进对面栏的断言(否则整行清零断言永远误红)。
- 断言覆盖层只能白盒:`Canvas` 是 `priv`,`moui_tui_renderer/*_test.mbt` 是**黑盒**包(所以现有用例都写 `@moui_tui_renderer.xxx`),引用 `Canvas` 直接编译失败 `The type/trait ... is not found`。新增的 `canvas_wbtest.mbt` 是同包白盒,能直接 `Canvas::new` / `canvas.screen.line_at(y).cells[x].attrs`,而且包内 `imports` 的 `@tui` 别名照样可用。别为了测试把 `Canvas` 晋升成包外 API。
- 焦点带的 PTY 断言必须读在**下一次点击之前**:counter 用例第二次点击落在命中盒外,实测会让焦点带从整屏消失(任何行都没有 underlined cell),放在它后面断言就是拿「焦点已被清掉」当渲染回归查。

## S7 `examples/tui_layers` 实测事实(2026-10-15)

- `caret_positions` **允许整条为空**是契约(`moui/core/text_layout.mbt` 的 fallback 与本包点击命中都按空防过),但 `clamp_int(_, 0, len - 1)` 对空数组正好**造出**合法下标 0,后面按下标取就是 panic —— 真终端里点一下文本框整个 app 崩掉走的是这条。修在两侧:cell 文本系统报逐字符格列(`moui_tui_renderer/cell.mbt`),views 的六个取点处统一走 `caret_offset` 退回盒起点。
- headless 的 `press()` 只发 `Keyboard`,真终端一个可打印字节同时发 `Keyboard` + `TextInput`(`moui_terminal_host/decode.mbt::emit_text_key`)。所以「过滤态松开 Space/Enter」这类规则**只有 PTY 门能证**:同一个 Space 在 `app_test.mbt` 里是 no-op(`rows=1`),在真终端里把空格写进框(`rows=0`,`hide=` 不动)。
- 崩溃会让 PTY 读起来像「事件路由没通」:进程死后最后一帧不再变,`filter=-` 永远不动。先确认进程还活着(整屏重放里找 panic/退出),再怀疑路由 —— 这次就是这么误判的,实际没有任何 runtime 缺陷。
- 滚轮按**悬停**那一栏路由,与键盘焦点无关:焦点已在文本框时滚列表行仍然 `row=1 file=0`。100x30 下 8 行列表的滚动上限就是 1 格(内容只超出一个行距),所以断言写「+1 再回 0」,不能连按两下指望 `row=2`。
- `row_height` 是**下限而不是行距**:行内固有内容 36px,实际行距 = `row_height + 4`。视口能放几行、内容会不会溢出,都按行距算,别拿 `row_height` 直接除。
- 折叠/展开会让 content-sized 的 scroll viewport 重新居中,剩余行整体位移 → 重复同一手势前**必须重新读帧**,第二次点击否则会落在原来的空档上(`right_click_row` 每次都重取 `row_frame`)。
- 状态行宽 560px = 56 格,但 `Canvas::write_boxed` 把双空格折成单格,100 格下整行只占 53 格;43 格时尾部 `only=`/`hide=` 会被截掉。窄档断言只能用 `sel=`/`rows=` 这些头部针尖。
- 框线归属这条门(`"S7 a short pane keeps its ring free of rows and bands"`,190x12)必须**按格**断言而不是数 ANSI:反白带的行序是 damage 的标记顺序,不保证升序,按字节切行会把「哪一格被反白」读错。两处判据各自做过变异验证 —— 去掉 `content` 轨 → 红在「both panes drew a ring」(顶边框被 `[▾] ─[src]` 吃掉,只剩一个 `╭`),只去掉横向内收 → 红在「the band never covers the ring」。回归用例不验证会红就等于没写。

## 已知待批准的 runtime 缺陷

- `moui/runtime/runtime_events.mbt` 的 `[focus-dbg]` println(污染终端 stdout,`git blame` = `8e26cde20a` 2026-10-06 的 `main` 既有缺陷)已于 2026-10-16 经 owner 批准删除(tui-hardening H1)。教训:runtime 的 stdout 对 TUI 宿主就是帧流的一部分,调试打印必须走结构化的诊断通道而不是 println。

## Harness 陷阱(S6 实测)

- `docs/plans/active/<id>.md` 的 **Status 行**由 `validate_guidance_consistency/plan_guidance.mbt` 检查:取前 24 行内第一条含 `Status`/`状态` 的行,`active/` 目录要求它**含 `active` 且不含** `done|complete|superseded|archived`(小写化后匹配)。所以状态行里不要写 "S0–S6 all done",会直接把 guidance guard 打红;正文其它行不受限。
- 新增 workspace 包 / example / 改 public API 后必须 `node scripts/generate-repo-docs.mjs --write`,否则 `--check` 报 `docs/repository-facts.md is stale`。不要直接跑 `moon run tools/moui/generate_repo_docs -- --check`:它会先报 `checks/api-surface-report.check.json is missing`,那是 node wrapper 调 `validate-api-surface.mjs --report …` 生成的临时文件,不是真实失败原因。
