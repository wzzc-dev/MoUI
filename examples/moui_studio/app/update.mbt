///|
/// 纯状态转移骨架：共享助手 + 外壳/设计域消息。
/// 运行 / 积木 / AI 三域分别在 update_run / update_blocks / update_ai，
/// 由 update_pure 链式分发（消息构造器互斥，先后顺序不影响语义）。

///|
/// 当前语言的翻译器（视图与状态消息共用）。
pub fn translator(model : Model) -> @i18n.Translator {
  translator_for(model.language)
}

///|
/// 选中 handler 的程序对象（按 控件名@事件 反查）。
pub fn current_handler(model : Model) -> @ir.Handler? {
  let control = handler_control_of(model.selected_handler)
  let event = handler_event_of(model.selected_handler)
  match (control, event) {
    (Some(name), Some(tag)) =>
      match @ir.parse_event_kind(tag) {
        Some(event_kind) => @ir.find_handler(model.program, name, event_kind)
        None => None
      }
    _ => None
  }
}

///|
/// **当前正在编辑的语句体**——统一「事件子程序」与「自定义积木」。
///
/// # 为什么需要这一层
///
/// 积木画布、插入面板、键盘导航、值编辑、上下文菜单全都建在
/// `current_handler` 上（30 处调用）。自定义积木（`FuncDef`）的**体**
/// 也是一串语句，但它不是 handler——于是建出来的积木**没有编辑面**：
/// 看得见、改不了名、放不进语句，等于半个功能。
///
/// 这里给两者一个公共视图（体 + 写回），让积木界面**同一个画布**编辑
/// 两种目标。写回按目标类型分派，界面层不必知道自己在编辑哪一种。
pub(all) struct EditTarget {
  /// 体所在的对象名（handler 的 `控件.事件` 键，或函数名）
  label : String
  body : Array[@ir.Stmt]
  /// 该体属于自定义积木（函数体的语句规则与事件体不同：可以有 `return`）
  is_function : Bool
}

///|
/// 取当前编辑目标：优先自定义积木（若树里选中了它），否则事件子程序。
pub fn current_target(model : Model) -> EditTarget? {
  match selected_function(model) {
    Some(func) =>
      Some(EditTarget::{ label: func.name, body: func.body, is_function: true, })
    None =>
      match current_handler(model) {
        Some(handler) =>
          Some(EditTarget::{
            label: "\{handler.control_name}@\{handler.event.tag()}",
            body: handler.body,
            is_function: false,
          })
        None => None
      }
  }
}

///|
/// 把新的体写回它所属的对象（函数或 handler）。
///
/// 与 `replace_handler_body` 同一纪律：克隆后替换、不就地改共享数组。
pub fn replace_target_body(
  model : Model,
  label : String,
  body : Array[@ir.Stmt],
) -> Model {
  // 先看是不是自定义积木（按名字定位）
  let mut func_hit = false
  for func in model.program.functions {
    if func.name == label {
      func_hit = true
    }
  }
  if func_hit {
    let functions : Array[@ir.FuncDef] = []
    for func in model.program.functions {
      if func.name == label {
        functions.push(@ir.FuncDef::{ ..func, body, })
      } else {
        functions.push(func)
      }
    }
    return { ..model, program: { ..model.program, functions, }, }
  }
  // 否则按 handler 键写回
  let handlers : Array[@ir.Handler] = []
  for handler in model.program.handlers {
    let key = "\{handler.control_name}@\{handler.event.tag()}"
    if key == label {
      handlers.push(@ir.Handler::{ ..handler, body, })
    } else {
      handlers.push(handler)
    }
  }
  { ..model, program: { ..model.program, handlers, }, }
}

///|
fn handler_control_of(key : String) -> String? {
  let chars : Array[Char] = []
  for c in key {
    chars.push(c)
  }
  let mut at = -1
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '@' {
      at = i
      break
    }
    i = i + 1
  }
  if at <= 0 {
    None
  } else {
    let buf = StringBuilder()
    let mut j = 0
    while j < at {
      buf.write_char(chars[j])
      j = j + 1
    }
    Some(buf.to_string())
  }
}

///|
fn handler_event_of(key : String) -> String? {
  let chars : Array[Char] = []
  for c in key {
    chars.push(c)
  }
  let mut at = -1
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '@' {
      at = i
      break
    }
    i = i + 1
  }
  if at < 0 || at + 1 >= chars.length() {
    None
  } else {
    let buf = StringBuilder()
    let mut j = at + 1
    while j < chars.length() {
      buf.write_char(chars[j])
      j = j + 1
    }
    Some(buf.to_string())
  }
}

///|
/// 控件支持的事件清单（供新建子程序下拉）。
pub fn control_events(control : @ir.Control) -> Array[@ir.EventKind] {
  let events : Array[@ir.EventKind] = []
  if control.kind.supports_event(@ir.OnClick) {
    events.push(@ir.OnClick)
  }
  if control.kind.supports_event(@ir.OnChange) {
    events.push(@ir.OnChange)
  }
  if control.kind.supports_event(@ir.OnInputDone) {
    events.push(@ir.OnInputDone)
  }
  events
}

///|
/// 控件重命名：同步其 handler 的 control_name（程序内引用一致）。
fn rename_control_everywhere(
  program : @ir.StudioProgram,
  from : String,
  to : String,
) -> @ir.StudioProgram {
  let controls : Array[@ir.Control] = []
  for control in program.controls {
    if control.name == from {
      controls.push(@ir.Control::{ ..control, name: to, })
    } else {
      controls.push(control)
    }
  }
  let handlers : Array[@ir.Handler] = []
  for handler in program.handlers {
    let body = handler.body.map(stmt => rename_control_in_stmt(stmt, from, to))
    if handler.control_name == from {
      handlers.push(@ir.Handler::{ ..handler, control_name: to, body, })
    } else {
      handlers.push(@ir.Handler::{ ..handler, body, })
    }
  }
  @ir.StudioProgram::{ ..program, controls, handlers, }
}

///|
/// Rename control references inside handler bodies as part of a control rename.
/// A bare Var/StrLit in a control-name slot is an identifier, while variables
/// and strings in ordinary expression slots keep their original meaning.
fn rename_control_in_stmt(
  stmt : @ir.Stmt,
  from : String,
  to : String,
) -> @ir.Stmt {
  match stmt {
    @ir.Declare(name, expr) =>
      @ir.Declare(name, rename_control_in_expr(expr, from, to))
    @ir.Assign(name, expr) =>
      @ir.Assign(name, rename_control_in_expr(expr, from, to))
    @ir.SetIndex(name, index, value) =>
      @ir.SetIndex(
        name,
        rename_control_in_expr(index, from, to),
        rename_control_in_expr(value, from, to),
      )
    @ir.Call(name, args) =>
      @ir.Call(name, rename_control_in_args(name, args, from, to))
    @ir.If(cond, then_body, else_ifs, else_body) => {
      let arms : Array[(@ir.Expr, Array[@ir.Stmt])] = []
      for arm in else_ifs {
        arms.push(
          (
            rename_control_in_expr(arm.0, from, to),
            arm.1.map(stmt => rename_control_in_stmt(stmt, from, to)),
          ),
        )
      }
      @ir.If(
        rename_control_in_expr(cond, from, to),
        then_body.map(stmt => rename_control_in_stmt(stmt, from, to)),
        arms,
        else_body.map(stmt => rename_control_in_stmt(stmt, from, to)),
      )
    }
    @ir.CountLoop(times, loop_var, body) =>
      @ir.CountLoop(
        rename_control_in_expr(times, from, to),
        loop_var,
        body.map(stmt => rename_control_in_stmt(stmt, from, to)),
      )
    @ir.WhileLoop(cond, body) =>
      @ir.WhileLoop(
        rename_control_in_expr(cond, from, to),
        body.map(stmt => rename_control_in_stmt(stmt, from, to)),
      )
    @ir.Break => @ir.Break
    @ir.Return(expr) =>
      @ir.Return(
        match expr {
          Some(value) => Some(rename_control_in_expr(value, from, to))
          None => None
        },
      )
    @ir.Match(subject, arms, else_body) =>
      @ir.Match(
        rename_control_in_expr(subject, from, to),
        arms.map(arm =>
          @ir.MatchArm::{
            case_name: arm.case_name,
            body: arm.body.map(stmt => rename_control_in_stmt(stmt, from, to)),
          }),
        else_body.map(stmt => rename_control_in_stmt(stmt, from, to)),
      )
  }
}

///|
fn rename_control_in_expr(
  expr : @ir.Expr,
  from : String,
  to : String,
) -> @ir.Expr {
  match expr {
    @ir.NumLit(_)
    | @ir.IntLit(_)
    | @ir.StrLit(_)
    | @ir.BoolLit(_)
    | @ir.Var(_) => expr
    @ir.Not(inner) => @ir.Not(rename_control_in_expr(inner, from, to))
    @ir.EnumTag(_, _) => expr
    @ir.FieldAccess(base, field) =>
      @ir.FieldAccess(rename_control_in_expr(base, from, to), field)
    @ir.Neg(inner) => @ir.Neg(rename_control_in_expr(inner, from, to))
    @ir.ListLit(items) => {
      let copy : Array[@ir.Expr] = []
      for item in items {
        copy.push(rename_control_in_expr(item, from, to))
      }
      @ir.ListLit(copy)
    }
    @ir.Index(base, index) =>
      @ir.Index(
        rename_control_in_expr(base, from, to),
        rename_control_in_expr(index, from, to),
      )
    @ir.Binary(op, left, right) =>
      @ir.Binary(
        op,
        rename_control_in_expr(left, from, to),
        rename_control_in_expr(right, from, to),
      )
    @ir.Call(name, args) =>
      @ir.Call(name, rename_control_in_args(name, args, from, to))
  }
}

///|
fn rename_control_in_args(
  name : String,
  args : Array[@ir.Expr],
  from : String,
  to : String,
) -> Array[@ir.Expr] {
  let renamed : Array[@ir.Expr] = []
  let mut index = 0
  for arg in args {
    let control_slot = (
        index == 0 &&
        (
          name == "set_text" ||
          name == "append_row" ||
          name == "get_text" ||
          name == "get_number" ||
          name == "row_count" ||
          name == "row_at" ||
          name == "selected_row"
        )
      ) ||
      (name == "submit_data" && index == 1)
    let value = if control_slot {
      match arg {
        @ir.Var(value) => if value == from { @ir.Var(to) } else { arg }
        @ir.StrLit(value) => if value == from { @ir.StrLit(to) } else { arg }
        _ => rename_control_in_expr(arg, from, to)
      }
    } else {
      rename_control_in_expr(arg, from, to)
    }
    renamed.push(value)
    index = index + 1
  }
  renamed
}

///|
/// 用当前语言的规范源码替换某 handler 的 body（代码视图提交）。
fn commit_code(model : Model) -> Model {
  // MoonBit 外观是显示投影，不承担编辑提交（M5-5e）：IR 已是真源，
  // 草稿会在下一次 sync 重新推导，跳过 DSL 解析避免误报。
  if model.code_appearance is AppMoonBit {
    return { ..model, code_error: "", code_diagnostics: [], }
  }
  match current_handler(model) {
    None => with_draft_diagnostics(model)
    Some(handler) =>
      if model.code_draft.trim().to_owned() == "" {
        with_draft_diagnostics(model)
      } else {
        match
          @studio_lang.parse_handler_body(
            model.code_draft,
            model.language.dsl_language(),
          ) {
          Err(_) => with_draft_diagnostics(model)
          Ok(body) => {
            let updated = @ir.Handler::{
              ..handler,
              body: body.map(t => t.stmt),
            }
            let handlers : Array[@ir.Handler] = []
            for existing in model.program.handlers {
              if existing.control_name == handler.control_name &&
                existing.event.tag() == handler.event.tag() {
                handlers.push(updated)
              } else {
                handlers.push(existing)
              }
            }
            with_draft_diagnostics({
              ..model,
              program: { ..model.program, handlers, },
            })
          }
        }
      }
  }
}

///|
/// 草稿诊断重算：编辑即校验——`code_error`（单条错误条文案）与
/// `code_diagnostics`（结构化、行内标记 + 问题面板用）来自同一次
/// `check_syntax`，不会互相矛盾。
fn with_draft_diagnostics(model : Model) -> Model {
  if model.code_appearance is AppMoonBit {
    // MoonBit 显示不做 DSL 语法诊断（形状不同，误报无意义）
    return { ..model, code_error: "", code_diagnostics: [], }
  }
  match
    @studio_lang.check_syntax(model.code_draft, model.language.dsl_language()) {
    None => { ..model, code_error: "", code_diagnostics: [], }
    Some(error) => {
      let diagnostics : Array[@code_editor.CodeDiagnostic] = [
        {
          range: lang_error_line_range(model.code_draft, error),
          severity: @code_editor.Error,
          message: error_message(translator(model), error),
        },
      ]
      {
        ..model,
        code_error: diagnostics[0].message,
        code_diagnostics: diagnostics,
      }
    }
  }
}

///|
/// LangError 的行号 → 源码内的偏移区间（整行）。行号越界或为 0 时
/// 退化为整段源码。
fn lang_error_line_range(
  source : String,
  error : @studio_lang.LangError,
) -> @core.TextRange {
  let line = error.line()
  let lines = split_line_texts(source)
  if line <= 0 || line > lines.length() {
    return { start: 0, end: source.length(), }
  }
  let mut start = 0
  for index in 0..<(line - 1) {
    start = start + lines[index].length() + 1
  }
  { start, end: start + lines[line - 1].length(), }
}

///|
/// 初始播种：把选中子程序渲染成当前语言的源码草稿。
pub fn seed_code_draft(model : Model) -> Model {
  sync_code_draft(model)
}

///|
/// 选中 handler 变化时刷新代码草稿（用当前语言渲染）。
fn sync_code_draft(model : Model) -> Model {
  match current_handler(model) {
    None => { ..model, code_draft: "", code_error: "", code_diagnostics: [], }
    Some(handler) =>
      {
        ..model,
        code_draft: render_code_appearance(model, handler),
        code_error: "",
        code_diagnostics: [],
      }
  }
}

///|
/// 当前外观下的代码草稿渲染（M5-5e）：
/// - MoonBit：codegen 的 handler 子集源码（与导出/编译同源的形状）；
/// - DSL：中英教学渲染（降级后的显示外观，仍是 IR 的投影）。
fn render_code_appearance(model : Model, handler : @ir.Handler) -> String {
  match model.code_appearance {
    AppMoonBit =>
      @export.generate_handler_source(
        handler,
        1,
        functions=model.program.functions,
      ).source
    AppDsl => @studio_lang.render_handler(handler, model.language.dsl_language())
  }
}

///|
/// 外壳域消息处理：语言/模式/选择/代码草稿/模板。
fn update_shell_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
    CycleCodeAppearance => {
      // 外观切换（M5-5e）：MoonBit ⇄ DSL。DSL 外观切换前先提交旧草稿
      //（与 SwitchLanguage 同口径）；MoonBit 外观是显示投影，无需提交。
      let next = match model.code_appearance {
        AppMoonBit => { ..model, code_appearance: AppDsl, }
        AppDsl => { ..model, code_appearance: AppMoonBit, }
      }
      Some((sync_code_draft(next), @moui.Effect::none()))
    }
    SwitchLanguage => {
      let committed = commit_code(model)
      let switched = { ..committed, language: switch(model.language), }
      let next = if committed.code_error == "" {
        sync_code_draft(switched)
      } else {
        switched
      }
      Some((next, @moui.Effect::none()))
    }
    SetMode(mode) => {
      let committed = commit_code(model)
      let switched = { ..committed, mode, }
      let next = if committed.code_error == "" {
        sync_code_draft(switched)
      } else {
        switched
      }
      Some((next, @moui.Effect::none()))
    }
    SetDesignZoom(zoom) =>
      Some(({ ..model, design_zoom: zoom, }, @moui.Effect::none()))
    Noop => Some((model, @moui.Effect::none()))
    CommandPaletteOpen =>
      Some(
        (
          { ..model, command_palette_open: true, command_palette_query: "", },
          @moui.Effect::none(),
        ),
      )
    CommandPaletteClose =>
      Some(({ ..model, command_palette_open: false, }, @moui.Effect::none()))
    CommandPaletteQuery(query) =>
      Some(({ ..model, command_palette_query: query, }, @moui.Effect::none()))
    HoverStudioCommand(id) =>
      Some(({ ..model, hover_studio_command: id, }, @moui.Effect::none()))
    HoverHint(hint) =>
      Some(({ ..model, hover_hint: hint, }, @moui.Effect::none()))
    SelectHandler(key) => {
      let committed = commit_code(model)
      if committed.code_error != "" {
        // Keep the invalid draft visible so the user can repair it; changing
        // handlers must not silently discard unsaved source.
        Some((committed, @moui.Effect::none()))
      } else {
        Some(
          (
            sync_code_draft(select_handler_key(committed, key)),
            @moui.Effect::none(),
          ),
        )
      }
    }
    GotoProblem(key, line) =>
      // 工具链诊断行(build:/compile: 前缀):跳**资源管理器**定位文件
      // (M0-7 阶段文件内容查看未接编辑面,先做文件级定位;M1 接编辑面后
      // 这里升级为文件+行号跳转)。
      if key.has_prefix("build:") || key.has_prefix("compile:") {
        let file = if key.has_prefix("build:") {
          key[6:].to_owned()
        } else {
          key[9:].to_owned()
        }
        Some(
          (
            {
              ..model,
              left_view: LeftProject,
              selected_project_file: Some(file),
            },
            @moui.Effect::none(),
          ),
        )
      } else {
        Some(goto_problem_program(model, key, line))
      }
    EditCode(source) =>
      Some(
        (
          with_draft_diagnostics({ ..model, code_draft: source, }),
          @moui.Effect::none(),
        ),
      )
    EditorCaretMoved(caret, selection) =>
      Some(
        (
          { ..model, code_caret: caret, code_selection: selection, },
          @moui.Effect::none(),
        ),
      )
    EditorScrolled(y) =>
      Some(
        (
          { ..model, code_scroll: @geometry.Point::new(x=0.0, y~), },
          @moui.Effect::none(),
        ),
      )
    SelectTemplate(index) => {
      let samples = @proposals.all_samples()
      let program = if index >= 0 && index < samples.length() {
        samples[index]
      } else {
        model.program
      }
      let next = with_recent_undo_point(
        model,
        text(translator(model), "app.recent.action.template"),
        "app.recent.action.template",
        m => {
          ..m,
          program,
          pending: None,
          run: None,
          // 积木选择态随模板重置：旧 handler 的语句草稿不再有效
          selected_block: -1,
          block_draft: "",
          runtime_values: @studio_lang.initial_values(program),
          runtime_texts: @studio_lang.initial_texts(program),
          runtime_rows: @studio_lang.initial_rows(program),
          runtime_selections: Map([], capacity=4),
          // 代码工程骨架待落盘（M6①）：组合根据此写 form.mbt/handlers.mbt
          pending_code_project: true,
        },
      )
      Some(
        (
          sync_code_draft({
            ..next,
            selected_control: first_control_name(program.controls),
            selected_handler: first_handler_key(program.handlers),
          }),
          @moui.Effect::none(),
        ),
      )
    }
    // notice 的消费入口也走同一漏斗（非空文本补推 toast）——settings
    // 写入的哑回调传空串，只清字段不弹 toast。
    SetNotice(notice) =>
      Some((with_notice(model, notice, false), @moui.Effect::none()))
    // 新建空白程序：与切模板同一纪律——旧程序进撤销栈可找回，运行态、
    // 选中态、积木草稿全部重置；空程序没有控件与子程序，选中清空。
    NewBlankProgram => {
      let program = empty_program()
      let next = with_recent_undo_point(
        model,
        text(translator(model), "app.recent.action.new"),
        "app.recent.action.new",
        m => {
          ..m,
          program,
          pending: None,
          run: None,
          selected_block: -1,
          block_draft: "",
          runtime_values: @studio_lang.initial_values(program),
          runtime_texts: @studio_lang.initial_texts(program),
          runtime_rows: @studio_lang.initial_rows(program),
          runtime_selections: Map([], capacity=4),
        },
      )
      Some(
        (
          sync_code_draft({
            ..next,
            selected_control: first_control_name(program.controls),
            selected_handler: first_handler_key(program.handlers),
          }),
          @moui.Effect::none(),
        ),
      )
    }
    Undo => Some((apply_undo(model), @moui.Effect::none()))
    Redo => Some((apply_redo(model), @moui.Effect::none()))
    _ => None
  }
}

///|
/// 设计域消息处理：画布点选/拖拽、属性检查器、控件增删。
fn update_design_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
    SelectControl(name) =>
      // 三条选中槽的互斥由 `select_control_by_name` 单一漏斗保证
      // （见 update_selection.mbt）。
      Some((select_control_by_name(model, name), @moui.Effect::none()))
    ClearSelection =>
      // 三条槽一起清（`clear_selection`）。只清控件的话右栏会退回显示上一个
      // handler 的属性（`context_head` 在无控件时回退到 `current_handler`），
      // 用户看到的是「点了清除但内容没变」。清干净才是 `#clearSel` 的语义。
      Some((clear_selection(model), @moui.Effect::none()))
    CreateHandler(control_name, event) =>
      // 新建子程序：控件存在 + 事件受支持 + 不重复 + 预算内，
      // 建空子程序并选中（note 留空——可读性契约的必填约束针对 AI 提案）
      // 窗体级事件（control_name = ""）：仅定时器/广播（切片 G）
      if control_name == "" {
        if !(event is @ir.OnTimer) && !(event is @ir.OnBroadcast) {
          Some((model, @moui.Effect::none()))
        } else if @ir.find_handler(model.program, control_name, event)
          is Some(_) {
          Some((model, @moui.Effect::none()))
        } else if model.program.handlers.length() >= @ir.MAX_HANDLERS {
          Some(
            (
              with_notice(
                model,
                text(translator(model), "app.status.handlers_limit"),
                true,
              ),
              @moui.Effect::none(),
            ),
          )
        } else {
          Some(
            (
              with_recent_undo_point(
                model,
                "窗体",
                "app.recent.action.handler",
                m => {
                  let handlers : Array[@ir.Handler] = []
                  for existing in m.program.handlers {
                    handlers.push(existing)
                  }
                  handlers.push(@ir.Handler::{
                    control_name: "",
                    event,
                    note_zh: "",
                    note_en: "",
                    body: [],
                  })
                  let next = {
                    ..m,
                    program: { ..m.program, handlers, },
                    selected_handler: handler_key("", event.tag()),
                  }
                  sync_code_draft(next)
                },
              ),
              @moui.Effect::none(),
            ),
          )
        }
      } else {
        create_control_handler(model, control_name, event)
      }
    CanvasPress(x, y) => {
      // 手柄优先：角手柄只画在选中控件上，按上手柄即进入缩放拖拽
      let handle_hit : @ir.DragCorner? = match find_selected_control(model) {
        Some(selected) => hit_test_handle(selected, x, y)
        None => None
      }
      match handle_hit {
        Some(corner) =>
          Some(
            (
              {
                ..model,
                drag: Some(DragState::{
                  control: model.selected_control,
                  kind: Resize(corner),
                }),
              },
              @moui.Effect::none(),
            ),
          )
        None =>
          // 命中控件即选中并建立移动拖拽态：记录按下点相对控件原点的偏移
          match hit_test_control(model.program.controls, x, y) {
            Some(control) =>
              Some(
                (
                  {
                    ..model,
                    selected_control: control.name,
                    drag: Some(DragState::{
                      control: control.name,
                      kind: Move(x.to_int() - control.x, y.to_int() - control.y),
                    }),
                  },
                  @moui.Effect::none(),
                ),
              )
            None =>
              Some(
                (
                  { ..model, selected_control: "", drag: None, },
                  @moui.Effect::none(),
                ),
              )
          }
      }
    }
    CanvasDragTo(x, y) =>
      // 拖拽移动/缩放控件；夹取规则在 @ir（控件完整落在设计画布内、最小边长）。
      // 移动带吸附：靠近参考线目标 ≤4px 时原点平移到精确对齐（吸附后仍过夹取）。
      // 整段手势共享一个撤销还原点（coalesce key = move/resize + 控件名）。
      match model.drag {
        None => Some((model, @moui.Effect::none()))
        Some(drag) =>
          match drag.kind {
            Move(offset_x, offset_y) =>
              Some(
                (
                  with_undo_point(model, "move:\{drag.control}", m => {
                    let controls : Array[@ir.Control] = []
                    for control in m.program.controls {
                      if control.name == drag.control {
                        let (snapped_x, snapped_y) = snap_move_position(
                          m.program.controls,
                          drag.control,
                          (x.to_int() - offset_x).to_double(),
                          (y.to_int() - offset_y).to_double(),
                          control.width.to_double(),
                          control.height.to_double(),
                        )
                        controls.push(
                          control
                          .with_rect_field(@ir.RectX, snapped_x.to_int())
                          .with_rect_field(@ir.RectY, snapped_y.to_int()),
                        )
                      } else {
                        controls.push(control)
                      }
                    }
                    { ..m, program: { ..m.program, controls, }, }
                  }),
                  @moui.Effect::none(),
                ),
              )
            Resize(corner) =>
              Some(
                (
                  with_undo_point(model, "resize:\{drag.control}", m => {
                    let controls : Array[@ir.Control] = []
                    for control in m.program.controls {
                      if control.name == drag.control {
                        // 缩放边缘吸附：移动边向参考线/网格钳制后再缩放
                        let (snapped_x, snapped_y) = snap_resize_position(
                          m.program.controls,
                          drag.control,
                          control,
                          corner,
                          x,
                          y,
                        )
                        controls.push(
                          control.resize_from_corner(
                            corner,
                            snapped_x.to_int(),
                            snapped_y.to_int(),
                          ),
                        )
                      } else {
                        controls.push(control)
                      }
                    }
                    { ..m, program: { ..m.program, controls, }, }
                  }),
                  @moui.Effect::none(),
                ),
              )
          }
      }
    CanvasRelease(_x, _y) =>
      Some(({ ..model, drag: None, }, @moui.Effect::none()))
    CanvasTap(x, y) =>
      // 单击点选。拖拽松手也会触发 tap（同一 Up 事件）：drag 仍在时说明
      // 这是一次拖拽结束，不要改动选中态。
      match hit_test_control(model.program.controls, x, y) {
        Some(control) =>
          if model.drag is Some(_) {
            Some((model, @moui.Effect::none()))
          } else {
            Some(
              (
                { ..model, selected_control: control.name, },
                @moui.Effect::none(),
              ),
            )
          }
        None =>
          if model.drag is Some(_) {
            Some((model, @moui.Effect::none()))
          } else {
            Some(({ ..model, selected_control: "", }, @moui.Effect::none()))
          }
      }
    SetControlText(name, value) =>
      Some(
        (
          with_undo_point(model, "text:\{name}", m => {
            let controls : Array[@ir.Control] = []
            for control in m.program.controls {
              if control.name == name {
                controls.push(@ir.Control::{ ..control, text: value, })
              } else {
                controls.push(control)
              }
            }
            { ..m, program: { ..m.program, controls, }, }
          }),
          @moui.Effect::none(),
        ),
      )
    SetControlName(name, value) => {
      if value == "" ||
        @studio_lang.is_reserved(value) ||
        @ir.find_control(model.program, value) is Some(_) {
        return Some((model, @moui.Effect::none()))
      }
      if !@ir.control_name_syntax_valid(value) {
        return Some((model, @moui.Effect::none()))
      }
      Some(
        (
          with_undo_point(model, "rename:\{name}", m => {
            let program = rename_control_everywhere(m.program, name, value)
            let next = {
              ..m,
              program,
              selected_control: value,
              selected_handler: match handler_control_of(m.selected_handler) {
                Some(current) =>
                  if current == name {
                    handler_key(
                      value,
                      handler_event_of(m.selected_handler).unwrap_or("on_click"),
                    )
                  } else {
                    m.selected_handler
                  }
                None => m.selected_handler
              },
            }
            sync_code_draft(next)
          }),
          @moui.Effect::none(),
        ),
      )
    }
    SetControlItems(name, value) => {
      let items = split_lines(value)
      Some(
        (
          with_undo_point(model, "items:\{name}", m => {
            let controls : Array[@ir.Control] = []
            for control in m.program.controls {
              if control.name == name {
                controls.push(@ir.Control::{ ..control, items, })
              } else {
                controls.push(control)
              }
            }
            { ..m, program: { ..m.program, controls, }, }
          }),
          @moui.Effect::none(),
        ),
      )
    }
    SetControlRect(name, field, raw) =>
      // 属性框整数解析失败（空串/非数字）即忽略本次输入
      match parse_design_int(raw) {
        None => Some((model, @moui.Effect::none()))
        Some(value) =>
          Some(
            (
              with_undo_point(model, "rect:\{name}", m => {
                let controls : Array[@ir.Control] = []
                for control in m.program.controls {
                  if control.name == name {
                    controls.push(control.with_rect_field(field, value))
                  } else {
                    controls.push(control)
                  }
                }
                { ..m, program: { ..m.program, controls, }, }
              }),
              @moui.Effect::none(),
            ),
          )
      }
    AddControl(kind) => {
      // 控件预算防呆：与 decode/提案/导出共用同一 MAX_CONTROLS 常量
      if model.program.controls.length() >= @ir.MAX_CONTROLS {
        return Some(
          (
            with_notice(
              model,
              text(translator(model), "app.status.controls_limit"),
              true,
            ),
            @moui.Effect::none(),
          ),
        )
      }
      Some(
        (
          with_recent_undo_point(
            model,
            text(translator(model), control_kind_key(kind)),
            "app.recent.action.insert",
            m => {
              let id = @ir.next_control_id(m.program)
              let name = fresh_control_name(m.program, kind)
              let control = @ir.Control::{
                id,
                kind,
                name,
                text: "",
                x: 40 + id % 5 * 30,
                y: 40 + id % 7 * 30,
                width: match kind {
                  @ir.Button => 100
                  @ir.Label => 140
                  @ir.TextField => 160
                  @ir.CheckBox => 110
                  @ir.ListBox => 140
                  @ir.Table => 200
                  @ir.Dropdown => 140
                  @ir.ProgressBar => 160
                  @ir.Image => 120
                },
                height: match kind {
                  @ir.Button => 32
                  @ir.Label => 30
                  @ir.TextField => 30
                  @ir.CheckBox => 26
                  @ir.ListBox => 110
                  @ir.Table => 120
                  @ir.Dropdown => 30
                  @ir.ProgressBar => 18
                  @ir.Image => 90
                },
                items: [],
              }
              {
                ..m,
                program: {
                  ..m.program,
                  controls: append_control(m.program.controls, control),
                },
                selected_control: name,
              }
            },
          ),
          @moui.Effect::none(),
        ),
      )
    }
    DuplicateControl(name) =>
      // 复制控件：新 id/新名字（类型+序号）、位置级联偏移 16px 后夹取、items 深拷贝
      match @ir.find_control(model.program, name) {
        None => Some((model, @moui.Effect::none()))
        Some(source) =>
          if model.program.controls.length() >= @ir.MAX_CONTROLS {
            return Some(
              (
                with_notice(
                  model,
                  text(translator(model), "app.status.controls_limit"),
                  true,
                ),
                @moui.Effect::none(),
              ),
            )
          } else {
            Some(
              (
                with_recent_undo_point(
                  model,
                  name,
                  "app.recent.action.duplicate",
                  m => {
                    let id = @ir.next_control_id(m.program)
                    let copy_name = fresh_control_name(m.program, source.kind)
                    let items : Array[String] = []
                    for item in source.items {
                      items.push(item)
                    }
                    let control = @ir.Control::{
                      ..source,
                      id,
                      name: copy_name,
                      x: source.x + 16,
                      y: source.y + 16,
                      items,
                    }
                    let control = control
                      .with_rect_field(@ir.RectX, control.x)
                      .with_rect_field(@ir.RectY, control.y)
                    {
                      ..m,
                      program: {
                        ..m.program,
                        controls: append_control(m.program.controls, control),
                      },
                      selected_control: copy_name,
                    }
                  },
                ),
                @moui.Effect::none(),
              ),
            )
          }
      }
    DeleteControl(name) =>
      Some(
        (
          with_recent_undo_point(model, name, "app.recent.action.delete", m => {
            let controls : Array[@ir.Control] = []
            for control in m.program.controls {
              if control.name != name {
                controls.push(control)
              }
            }
            let handlers : Array[@ir.Handler] = []
            for handler in m.program.handlers {
              if handler.control_name != name {
                handlers.push(handler)
              }
            }
            // 被删控件的子程序正是当前选中时，清除选中并同步代码草稿；
            // 其余情况不动草稿——代码视图里未提交的编辑不因删除别的控件而丢失
            let next_handler = match handler_control_of(m.selected_handler) {
              Some(current) =>
                if current == name {
                  ""
                } else {
                  m.selected_handler
                }
              None => m.selected_handler
            }
            let next = {
              ..m,
              program: { ..m.program, controls, handlers, },
              selected_control: if m.selected_control == name {
                ""
              } else {
                m.selected_control
              },
              selected_handler: next_handler,
            }
            if next_handler != m.selected_handler {
              sync_code_draft(next)
            } else {
              next
            }
          }),
          @moui.Effect::none(),
        ),
      )
    _ => None
  }
}

///|
/// 纯转移（文件与网络相关消息由 update_with_services 处理）。
pub fn update_pure(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg]) {
  match update_confirm_msgs(model, msg) {
    Some(result) => result
    None => update_pure_inner(model, msg)
  }
}

///|
/// 纯转移内层链（不含确认守卫层）：ConfirmAccepted 续行原消息时走这里，
/// 避免守卫把续行消息再次拦成确认请求。
fn update_pure_inner(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg]) {
  match update_shell_msgs(model, msg) {
    Some(result) => result
    None =>
      match update_ide_msgs(model, msg) {
        Some(result) => result
        None =>
          match update_design_msgs(model, msg) {
            Some(result) => result
            None =>
              match update_run_msgs(model, msg) {
                Some(result) => result
                None =>
                  match update_blocks_msgs(model, msg) {
                    Some(result) => result
                    None =>
                      match update_ai_msgs(model, msg) {
                        Some(result) => result
                        None =>
                          match update_selection_msgs(model, msg) {
                            Some(result) => result
                            None => (model, @moui.Effect::none())
                          }
                      }
                  }
              }
          }
      }
  }
}

///|
fn switch(language : UiLanguage) -> UiLanguage {
  match language {
    ZhHans => En
    En => ZhHans
  }
}

///|
/// 新控件默认名：类型 + 序号（自解释命名，可读性契约的默认实践）。
fn fresh_control_name(
  program : @ir.StudioProgram,
  kind : @ir.ControlKind,
) -> String {
  let base = match kind {
    @ir.Button => "按钮"
    @ir.Label => "标签"
    @ir.TextField => "输入框"
    @ir.CheckBox => "选择框"
    @ir.ListBox => "列表框"
    @ir.Table => "表格"
    @ir.Dropdown => "下拉框"
    @ir.ProgressBar => "进度条"
    @ir.Image => "图片"
  }
  let mut index = 1
  let mut name = base
  while @ir.find_control(program, name) is Some(_) {
    index = index + 1
    name = "\{base}\{index}"
  }
  name
}

///|
/// 控件数组追加（spread 语法不可用，显式拷贝）。
fn append_control(
  controls : Array[@ir.Control],
  control : @ir.Control,
) -> Array[@ir.Control] {
  let copied : Array[@ir.Control] = []
  for existing in controls {
    copied.push(existing)
  }
  copied.push(control)
  copied
}

///|
/// 按换行切分并去空白行（控件选项编辑用）。
pub fn split_lines(value : String) -> Array[String] {
  let lines : Array[String] = []
  let current : Array[Char] = []
  let chars : Array[Char] = []
  for c in value {
    chars.push(c)
  }
  for c in chars {
    if c == '\n' {
      let line = chars_to_string(current).trim().to_owned()
      if line != "" {
        lines.push(line)
      }
      let mut j = current.length()
      while j > 0 {
        ignore(current.pop())
        j = j - 1
      }
    } else {
      current.push(c)
    }
  }
  let tail = chars_to_string(current).trim().to_owned()
  if tail != "" {
    lines.push(tail)
  }
  lines
}

///|
/// 属性框整数解析：仅接受 1-4 位纯数字（负号/小数/空串拒绝）。
fn parse_design_int(raw : String) -> Int? {
  if raw.length() == 0 || raw.length() > 4 {
    return None
  }
  let mut value = 0
  for c in raw {
    let code = c.to_int()
    if code < 0x30 || code > 0x39 {
      return None
    }
    value = value * 10 + (code - 0x30)
  }
  Some(value)
}

///|
fn chars_to_string(chars : Array[Char]) -> String {
  let buf = StringBuilder()
  for c in chars {
    buf.write_char(c)
  }
  buf.to_string()
}

///|
/// 首个控件名（空数组安全）。
pub fn first_control_name(controls : Array[@ir.Control]) -> String {
  if controls.length() > 0 {
    controls[0].name
  } else {
    ""
  }
}

///|
/// 首个子程序定位键（空数组安全）。
pub fn first_handler_key(handlers : Array[@ir.Handler]) -> String {
  if handlers.length() > 0 {
    handler_key(handlers[0].control_name, handlers[0].event.tag())
  } else {
    ""
  }
}

///|
/// 控件级子程序创建（原 CreateHandler 主体；窗体级事件走独立分支）。
fn create_control_handler(
  model : Model,
  control_name : String,
  event : @ir.EventKind,
) -> (Model, @moui.Effect[Msg])? {
  match @ir.find_control(model.program, control_name) {
    None => Some((model, @moui.Effect::none()))
    Some(control) =>
      if !control.kind.supports_event(event) {
        Some((model, @moui.Effect::none()))
      } else if @ir.find_handler(model.program, control_name, event) is Some(_) {
        Some((model, @moui.Effect::none()))
      } else if model.program.handlers.length() >= @ir.MAX_HANDLERS {
        Some(
          (
            with_notice(
              model,
              text(translator(model), "app.status.handlers_limit"),
              true,
            ),
            @moui.Effect::none(),
          ),
        )
      } else {
        Some(
          (
            with_recent_undo_point(
              model,
              control_name,
              "app.recent.action.handler",
              m => {
                let handlers : Array[@ir.Handler] = []
                for existing in m.program.handlers {
                  handlers.push(existing)
                }
                handlers.push(@ir.Handler::{
                  control_name,
                  event,
                  note_zh: "",
                  note_en: "",
                  body: [],
                })
                let next = {
                  ..m,
                  program: { ..m.program, handlers, },
                  selected_handler: handler_key(control_name, event.tag()),
                }
                sync_code_draft(next)
              },
            ),
            @moui.Effect::none(),
          ),
        )
      }
  }
}

///|

///|
/// 程序内诊断的跳转主体(GotoProblem 的非工具链分支):提交草稿 → 切
/// handler → 光标钉目标行 + 滚动对齐(行号槽/编辑面/竖尺共享 code_scroll)。
fn goto_problem_program(
  model : Model,
  key : String,
  line : Int,
) -> (Model, @moui.Effect[Msg]) {
  let committed = commit_code(model)
  let next = sync_code_draft(select_handler_key(committed, key))
  let lines = split_line_texts(next.code_draft)
  let target = if line >= 1 && line <= lines.length() { line } else { 1 }
  let mut caret = 0
  for index in 0..<(target - 1) {
    caret = caret + lines[index].length() + 1
  }
  let scroll_y = ((target - 3).to_double() * 20.0).max(0.0)
  (
    {
      ..next,
      code_caret: caret,
      code_selection: None,
      code_scroll: @geometry.Point::new(x=0.0, y=scroll_y),
    },
    @moui.Effect::none(),
  )
}

///|
/// 把光标钉到目标行行首并滚动对齐（GotoProblem 的共用核心）。
fn goto_line(model : Model, line : Int) -> Model {
  let lines = split_line_texts(model.code_draft)
  let target = if line >= 1 && line <= lines.length() { line } else { 1 }
  let mut caret = 0
  for index in 0..<(target - 1) {
    caret = caret + lines[index].length() + 1
  }
  let scroll_y = ((target - 3).to_double() * 20.0).max(0.0)
  {
    ..model,
    code_caret: caret,
    code_selection: None,
    code_scroll: @geometry.Point::new(x=0.0, y=scroll_y),
  }
}
