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
  }
}

///|
fn rename_control_in_expr(
  expr : @ir.Expr,
  from : String,
  to : String,
) -> @ir.Expr {
  match expr {
    @ir.NumLit(_) | @ir.StrLit(_) | @ir.BoolLit(_) | @ir.Var(_) => expr
    @ir.Not(inner) => @ir.Not(rename_control_in_expr(inner, from, to))
    @ir.Neg(inner) => @ir.Neg(rename_control_in_expr(inner, from, to))
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
  match current_handler(model) {
    None => { ..model, code_error: "", }
    Some(handler) =>
      if model.code_draft.trim().to_owned() == "" {
        { ..model, code_error: "", }
      } else {
        match
          @studio_lang.parse_handler_body(
            model.code_draft,
            model.language.dsl_language(),
          ) {
          Err(error) =>
            { ..model, code_error: error_message(translator(model), error), }
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
            {
              ..model,
              program: { ..model.program, handlers, },
              code_error: "",
            }
          }
        }
      }
  }
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
    None => { ..model, code_draft: "", code_error: "", }
    Some(handler) =>
      {
        ..model,
        code_draft: @studio_lang.render_handler(
          handler,
          model.language.dsl_language(),
        ),
        code_error: "",
      }
  }
}

///|
/// 编辑快照（撤销条目）：程序 + 选中态 + 代码草稿。
fn undo_entry_of(model : Model, key : String) -> UndoEntry {
  {
    program: model.program,
    selected_control: model.selected_control,
    selected_handler: model.selected_handler,
    code_draft: model.code_draft,
    coalesce_key: key,
  }
}

///|
/// 撤销栈追加（超 UNDO_DEPTH 丢弃最旧）。
fn undo_stack_push(
  stack : Array[UndoEntry],
  entry : UndoEntry,
) -> Array[UndoEntry] {
  let copy : Array[UndoEntry] = []
  for existing in stack {
    copy.push(existing)
  }
  copy.push(entry)
  if copy.length() > UNDO_DEPTH {
    let trimmed : Array[UndoEntry] = []
    let mut i = 1
    while i < copy.length() {
      trimmed.push(copy[i])
      i = i + 1
    }
    trimmed
  } else {
    copy
  }
}

///|
/// 撤销栈弹出（返回 (栈顶, 余栈)），空栈返回 None。
fn undo_stack_pop(stack : Array[UndoEntry]) -> (UndoEntry, Array[UndoEntry])? {
  if stack.length() == 0 {
    None
  } else {
    let rest : Array[UndoEntry] = []
    let mut i = 0
    while i < stack.length() - 1 {
      rest.push(stack[i])
      i = i + 1
    }
    Some((stack[stack.length() - 1], rest))
  }
}

///|
fn undo_stack_peek_key(stack : Array[UndoEntry]) -> String? {
  if stack.length() == 0 {
    None
  } else {
    Some(stack[stack.length() - 1].coalesce_key)
  }
}

///|
/// 把变更前快照压入 next 的撤销栈。合并规则：key 非空且与栈顶相同时
/// 跳过（连续同类编辑共享一个还原点）；空 key 永不合并。任何新还原点清空重做栈。
fn undo_commit(next : Model, entry : UndoEntry) -> Model {
  let top_key = match undo_stack_peek_key(next.undo_stack) {
    Some(key) => key
    None => ""
  }
  if entry.coalesce_key != "" && top_key == entry.coalesce_key {
    return next
  }
  {
    ..next,
    undo_stack: undo_stack_push(next.undo_stack, entry),
    redo_stack: [],
  }
}

///|
/// 带撤销点的变更：捕获变更前快照 → 应用变更 → 仅当程序签名真的变化时入栈。
/// no-op 变更（解析失败、非法输入、模板重选同一样例）不产生还原点。
fn with_undo_point(
  model : Model,
  key : String,
  mutate : (Model) -> Model,
) -> Model {
  let mark = undo_entry_of(model, key)
  let next = mutate(model)
  if @ir.program_signature(next.program) == @ir.program_signature(model.program) {
    next
  } else {
    undo_commit(next, mark)
  }
}

///|
/// 撤销：弹栈恢复快照；运行期活状态按恢复后的程序重置；积木选择态清空。
fn apply_undo(model : Model) -> Model {
  match undo_stack_pop(model.undo_stack) {
    None => model
    Some((entry, rest)) =>
      {
        ..model,
        program: entry.program,
        selected_control: entry.selected_control,
        selected_handler: entry.selected_handler,
        code_draft: entry.code_draft,
        code_error: "",
        drag: None,
        selected_block: -1,
        block_draft: "",
        runtime_values: @studio_lang.initial_values(entry.program),
        runtime_texts: @studio_lang.initial_texts(entry.program),
        runtime_rows: @studio_lang.initial_rows(entry.program),
        runtime_selections: Map([], capacity=4),
        undo_stack: rest,
        redo_stack: undo_stack_push(model.redo_stack, undo_entry_of(model, "")),
      }
  }
}

///|
/// 重做：弹重做栈恢复；撤销栈同步回填当前态。
fn apply_redo(model : Model) -> Model {
  match undo_stack_pop(model.redo_stack) {
    None => model
    Some((entry, rest)) =>
      {
        ..model,
        program: entry.program,
        selected_control: entry.selected_control,
        selected_handler: entry.selected_handler,
        code_draft: entry.code_draft,
        code_error: "",
        drag: None,
        selected_block: -1,
        block_draft: "",
        runtime_values: @studio_lang.initial_values(entry.program),
        runtime_texts: @studio_lang.initial_texts(entry.program),
        runtime_rows: @studio_lang.initial_rows(entry.program),
        runtime_selections: Map([], capacity=4),
        undo_stack: undo_stack_push(model.undo_stack, undo_entry_of(model, "")),
        redo_stack: rest,
      }
  }
}

///|
/// 外壳域消息处理：语言/模式/选择/代码草稿/模板。
fn update_shell_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
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
    SetDesignZoom(zoom) => {
      println("dbg setzoom \{zoom}")
      Some(({ ..model, design_zoom: zoom, }, @moui.Effect::none()))
    }
    Noop => Some((model, @moui.Effect::none()))
    SelectHandler(key) => {
      let committed = commit_code(model)
      if committed.code_error != "" {
        // Keep the invalid draft visible so the user can repair it; changing
        // handlers must not silently discard unsaved source.
        Some((committed, @moui.Effect::none()))
      } else {
        Some(
          (
            sync_code_draft({ ..committed, selected_handler: key, }),
            @moui.Effect::none(),
          ),
        )
      }
    }
    EditCode(source) =>
      Some(({ ..model, code_draft: source, }, @moui.Effect::none()))
    SelectTemplate(index) => {
      let samples = @proposals.all_samples()
      let program = if index >= 0 && index < samples.length() {
        samples[index]
      } else {
        model.program
      }
      let next = with_undo_point(model, "", m => {
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
      })
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
    SetNotice(notice) => Some(({ ..model, notice, }, @moui.Effect::none()))
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
      Some(({ ..model, selected_control: name, }, @moui.Effect::none()))
    CreateHandler(control_name, event) =>
      // 新建子程序：控件存在 + 事件受支持 + 不重复 + 预算内，
      // 建空子程序并选中（note 留空——可读性契约的必填约束针对 AI 提案）
      match @ir.find_control(model.program, control_name) {
        None => Some((model, @moui.Effect::none()))
        Some(control) =>
          if !control.kind.supports_event(event) {
            Some((model, @moui.Effect::none()))
          } else if @ir.find_handler(model.program, control_name, event)
            is Some(_) {
            Some((model, @moui.Effect::none()))
          } else if model.program.handlers.length() >= @ir.MAX_HANDLERS {
            Some(
              (
                {
                  ..model,
                  notice: text(translator(model), "app.status.handlers_limit"),
                },
                @moui.Effect::none(),
              ),
            )
          } else {
            Some(
              (
                with_undo_point(model, "", m => {
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
                }),
                @moui.Effect::none(),
              ),
            )
          }
      }
    CanvasPress(x, y) => {
      println("dbg press x=\{x} y=\{y}")
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
    CanvasDragTo(x, y) => {
      println("dbg dragto x=\{x} y=\{y}")
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
    }
    CanvasRelease(_x, _y) =>
      Some(({ ..model, drag: None, }, @moui.Effect::none()))
    CanvasTap(x, y) => {
      println("dbg tap x=\{x} y=\{y}")
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
          with_undo_point(model, "", m => {
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
            {
              ..model,
              notice: text(translator(model), "app.status.controls_limit"),
            },
            @moui.Effect::none(),
          ),
        )
      }
      Some(
        (
          with_undo_point(model, "", m => {
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
              },
              height: match kind {
                @ir.Button => 32
                @ir.Label => 30
                @ir.TextField => 30
                @ir.CheckBox => 26
                @ir.ListBox => 110
                @ir.Table => 120
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
          }),
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
                {
                  ..model,
                  notice: text(translator(model), "app.status.controls_limit"),
                },
                @moui.Effect::none(),
              ),
            )
          } else {
            Some(
              (
                with_undo_point(model, "", m => {
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
                }),
                @moui.Effect::none(),
              ),
            )
          }
      }
    DeleteControl(name) =>
      Some(
        (
          with_undo_point(model, "", m => {
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
  match update_shell_msgs(model, msg) {
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
                    None => (model, @moui.Effect::none())
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
