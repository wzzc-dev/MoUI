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
  program : @ir.MomaoProgram,
  from : String,
  to : String,
) -> @ir.MomaoProgram {
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
    if handler.control_name == from {
      handlers.push(@ir.Handler::{ ..handler, control_name: to, })
    } else {
      handlers.push(handler)
    }
  }
  @ir.MomaoProgram::{ ..program, controls, handlers, }
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
          @momao_lang.parse_handler_body(
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
        code_draft: @momao_lang.render_handler(
          handler,
          model.language.dsl_language(),
        ),
        code_error: "",
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
      let switched = sync_code_draft({ ..model, mode, })
      Some((switched, @moui.Effect::none()))
    }
    SelectHandler(key) =>
      Some(
        (
          sync_code_draft({ ..model, selected_handler: key, }),
          @moui.Effect::none(),
        ),
      )
    EditCode(source) =>
      Some(({ ..model, code_draft: source, }, @moui.Effect::none()))
    SelectTemplate(index) => {
      let samples = @proposals.all_samples()
      let program = if index >= 0 && index < samples.length() {
        samples[index]
      } else {
        model.program
      }
      let next = {
        ..model,
        program,
        pending: None,
        run: None,
        // 积木选择态随模板重置：旧 handler 的语句草稿不再有效
        selected_block: -1,
        block_draft: "",
        runtime_values: @momao_lang.initial_values(program),
        runtime_texts: @momao_lang.initial_texts(program),
      }
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
    _ => None
  }
}

///|
/// 设计域消息处理：画布点选/拖拽、属性检查器、控件增删。
fn update_design_msgs(model : Model, msg : Msg) -> (Model, @moui.Effect[Msg])? {
  match msg {
    SelectControl(name) =>
      Some(({ ..model, selected_control: name, }, @moui.Effect::none()))
    CanvasPress(x, y) => {
      let hit = hit_test_control(model.program.controls, x, y)
      match hit {
        Some(control) => {
          // 命中即选中并建立拖拽态：记录按下点相对控件原点的偏移
          let drag = DragState::{
            control: control.name,
            offset_x: x.to_int() - control.x,
            offset_y: y.to_int() - control.y,
          }
          Some(
            (
              { ..model, selected_control: control.name, drag: Some(drag), },
              @moui.Effect::none(),
            ),
          )
        }
        None =>
          Some(
            (
              { ..model, selected_control: "", drag: None, },
              @moui.Effect::none(),
            ),
          )
      }
    }
    CanvasDragTo(x, y) =>
      // 拖拽移动选中控件；夹取规则在 @ir（控件完整落在设计画布内）
      match model.drag {
        None => Some((model, @moui.Effect::none()))
        Some(drag) => {
          let controls : Array[@ir.Control] = []
          for control in model.program.controls {
            if control.name == drag.control {
              controls.push(
                control
                .with_rect_field(@ir.RectX, x.to_int() - drag.offset_x)
                .with_rect_field(@ir.RectY, y.to_int() - drag.offset_y),
              )
            } else {
              controls.push(control)
            }
          }
          Some(
            (
              { ..model, program: { ..model.program, controls, }, },
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
    SetControlText(name, value) => {
      let controls : Array[@ir.Control] = []
      for control in model.program.controls {
        if control.name == name {
          controls.push(@ir.Control::{ ..control, text: value, })
        } else {
          controls.push(control)
        }
      }
      Some(
        (
          { ..model, program: { ..model.program, controls, }, },
          @moui.Effect::none(),
        ),
      )
    }
    SetControlName(name, value) => {
      if value == "" || @ir.find_control(model.program, value) is Some(_) {
        return Some((model, @moui.Effect::none()))
      }
      if !@ir.control_name_syntax_valid(value) {
        return Some((model, @moui.Effect::none()))
      }
      let program = rename_control_everywhere(model.program, name, value)
      let next = {
        ..model,
        program,
        selected_control: value,
        selected_handler: match handler_control_of(model.selected_handler) {
          Some(current) =>
            if current == name {
              handler_key(
                value,
                handler_event_of(model.selected_handler).unwrap_or("on_click"),
              )
            } else {
              model.selected_handler
            }
          None => model.selected_handler
        },
      }
      Some((sync_code_draft(next), @moui.Effect::none()))
    }
    SetControlItems(name, value) => {
      let items = split_lines(value)
      let controls : Array[@ir.Control] = []
      for control in model.program.controls {
        if control.name == name {
          controls.push(@ir.Control::{ ..control, items, })
        } else {
          controls.push(control)
        }
      }
      Some(
        (
          { ..model, program: { ..model.program, controls, }, },
          @moui.Effect::none(),
        ),
      )
    }
    SetControlRect(name, field, raw) =>
      // 属性框整数解析失败（空串/非数字）即忽略本次输入
      match parse_design_int(raw) {
        None => Some((model, @moui.Effect::none()))
        Some(value) => {
          let controls : Array[@ir.Control] = []
          for control in model.program.controls {
            if control.name == name {
              controls.push(control.with_rect_field(field, value))
            } else {
              controls.push(control)
            }
          }
          Some(
            (
              { ..model, program: { ..model.program, controls, }, },
              @moui.Effect::none(),
            ),
          )
        }
      }
    AddControl(kind) => {
      let id = @ir.next_control_id(model.program)
      let name = fresh_control_name(model.program, kind)
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
      Some(
        (
          {
            ..model,
            program: {
              ..model.program,
              controls: append_control(model.program.controls, control),
            },
            selected_control: name,
          },
          @moui.Effect::none(),
        ),
      )
    }
    DeleteControl(name) => {
      let controls : Array[@ir.Control] = []
      for control in model.program.controls {
        if control.name != name {
          controls.push(control)
        }
      }
      let handlers : Array[@ir.Handler] = []
      for handler in model.program.handlers {
        if handler.control_name != name {
          handlers.push(handler)
        }
      }
      Some(
        (
          {
            ..model,
            program: { ..model.program, controls, handlers, },
            selected_control: "",
            selected_handler: match handler_control_of(model.selected_handler) {
              Some(current) =>
                if current == name {
                  ""
                } else {
                  model.selected_handler
                }
              None => model.selected_handler
            },
          },
          @moui.Effect::none(),
        ),
      )
    }
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
  program : @ir.MomaoProgram,
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
