///|
/// 设计器画布接线(M4-2):form.mbt 的加载/编辑/保存链。
///
/// 会话状态:`FormDesignerSession`——工程的 form.mbt 文本 + 解析产物 +
/// span。画布拖拽(Stage 原语上的 place 视图,拖拽手势由画布回调产出)
/// 结束时经 `form_design_move_msg` 生成 span 补丁,写回 form.mbt;
/// 补丁后画面由 stage 原语直接重渲(代码即真源,零二次投影)。

///|
/// 设计器会话:一份已加载的 form.mbt。
pub(all) struct FormDesignerSession {
  root : String
  /// form.mbt 的工程相对路径(如 "app/form.mbt")
  form_rel : String
  source : String
  parsed : @form_designer.ParsedForm
}

///|
/// 从工程探测 form.mbt 的相对路径(程序包文件列表里找;无则 None)。
pub fn form_design_rel(project : ProjectRecord) -> String? {
  let program_rel = match project.scanned.program_packages {
    [first, ..] => first
    [] => return None
  }
  for pkg in project.scanned.packages {
    if pkg.rel_path == program_rel {
      for name in pkg.files {
        if name == "form.mbt" {
          return Some("\{program_rel}/form.mbt")
        }
      }
    }
  }
  None
}

///|
/// 打开设计器:读取 form.mbt 文本(文件服务)。
pub fn form_design_load_task(
  files : @services.FileServices,
  root : String,
  form_rel : String,
) -> @services.ServiceTask[String] {
  let path = "\{root}/\{form_rel}"
  @services.ServiceTask::new(
    key="form-design:load:\{path}",
    label="读取 form.mbt",
    start=complete => {
      let _ = (files.read_text_fn)(path).start(result => {
        match result {
          @services.Success(text) => complete(@services.Success(text))
          @services.Failure(error) => complete(@services.Failure(error))
          @services.Cancelled => complete(@services.Cancelled)
        }
      })
      None
    },
  )
}

///|
/// 拖拽结束:按 span 补丁源码并返回 (新源码文本, 是否有变化)。
/// dx/dy 是拖拽位移(设计坐标;由画布手势按 fit 缩放换算)。
pub fn form_design_apply_move(
  session : FormDesignerSession,
  index : Int,
  dx : Double,
  dy : Double,
) -> (FormDesignerSession, Bool) {
  let controls = session.parsed.model.controls
  if index < 0 || index >= controls.length() {
    return (session, false)
  }
  let control = controls[index]
  let new_x = control.x + dx
  let new_y = control.y + dy
  // span 补丁:x/y 两个字段(补丁后重解析得到权威内存模型)
  let spans = session.parsed.spans[index]
  let source = session.source
  let source = @form_designer.apply_number_patch(
    source,
    spans.x,
    spans.x + @form_designer.number_len(source, spans.x),
    @form_designer.double_literal(new_x),
  )
  let source = @form_designer.apply_number_patch(
    source,
    spans.y,
    spans.y + @form_designer.number_len(source, spans.y),
    @form_designer.double_literal(new_y),
  )
  // 重新解析(span 位移到新位置)——解析失败则回退原会话
  match @form_designer.parse_form(source) {
    Err(_) => (session, false)
    Ok(parsed) => ({ ..session, source, parsed, }, true)
  }
}

///|
/// 尺寸缩放:同 move,补 width/height 两个字段。
pub fn form_design_apply_resize(
  session : FormDesignerSession,
  index : Int,
  width : Double,
  height : Double,
) -> (FormDesignerSession, Bool) {
  let controls = session.parsed.model.controls
  if index < 0 || index >= controls.length() {
    return (session, false)
  }
  let control = controls[index]
  let new_w = control.width + width
  let new_h = control.height + height
  let spans = session.parsed.spans[index]
  let source = session.source
  let source = @form_designer.apply_number_patch(
    source,
    spans.width,
    spans.width + @form_designer.number_len(source, spans.width),
    @form_designer.double_literal(new_w),
  )
  let source = @form_designer.apply_number_patch(
    source,
    spans.height,
    spans.height + @form_designer.number_len(source, spans.height),
    @form_designer.double_literal(new_h),
  )
  match @form_designer.parse_form(source) {
    Err(_) => (session, false)
    Ok(parsed) => ({ ..session, source, parsed, }, true)
  }
}

///|
/// 工程的 form.mbt 相对路径(转发到 preview_semantics 的探测)。
pub fn form_design_rel_of(model : Model) -> String? {
  match active_project_of(model) {
    Some(project) => form_design_rel(project)
    None => None
  }
}

///|
/// 拖拽/缩放后的写回 effect:session.source 已补丁,写回 form.mbt,
/// 回执 FormDesignSaved(写完即代码真源更新,重渲自动生效)。
pub fn form_design_write_effect(
  model : Model,
  next_session : FormDesignerSession,
  files : @services.FileServices,
) -> (Model, @moui.Effect[Msg]) {
  let path = "\{next_session.root}/\{next_session.form_rel}"
  (
    { ..model, form_designer: Some(next_session), },
    (files.write_text_fn)(path, next_session.source).effect(map=r => {
      FormDesignSaved(r)
    }),
  )
}
