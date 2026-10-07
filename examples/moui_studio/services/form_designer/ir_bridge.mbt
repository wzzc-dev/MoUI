///|
/// FormModel ↔ @ir.Control 数据桥(M4-2):让设计器画布复用 canvas.mbt
/// 的拖拽栈(命中/四角手柄/对齐参考线/吸附)——那些纯函数全部吃
/// `Array[@ir.Control]` 的矩形字段。桥是**视图投影**:拖拽结束后按
/// FormModel 的 span 补丁回写 form.mbt,ir 镜像只在画布层消费。

///|
/// FormModel 控件 → @ir.Control 镜像(坐标取整;kind 按映射表)。
pub fn form_controls_to_ir(model : FormModel) -> Array[@ir.Control] {
  let controls : Array[@ir.Control] = []
  let mut index = 1
  for control in model.controls {
    let kind : @ir.ControlKind = match control.kind {
      FkButton => @ir.Button
      FkText => @ir.Label
      FkTextField => @ir.TextField
      FkCheckBox => @ir.CheckBox
      FkImage => @ir.Image
    }
    controls.push(@ir.Control::{
      props: control.props,
      id: index,
      kind,
      name: form_control_name(control.kind, index),
      text: control.text,
      x: control.x.to_int(),
      y: control.y.to_int(),
      width: control.width.to_int(),
      height: control.height.to_int(),
      items: [],
    })
    index = index + 1
  }
  controls
}

///|
fn form_control_name(kind : FormKind, index : Int) -> String {
  "\{kind.tag()}_\{index}"
}

///|
/// 更新一个控件的矩形(拖拽/缩放后):按索引替换坐标字段,返回新模型。
pub fn form_model_move(
  model : FormModel,
  index : Int,
  x : Double,
  y : Double,
) -> FormModel {
  if index < 0 || index >= model.controls.length() {
    return model
  }
  let controls : Array[FormControl] = []
  let mut i = 0
  for control in model.controls {
    if i == index {
      controls.push({ ..control, x, y, })
    } else {
      controls.push(control)
    }
    i = i + 1
  }
  { ..model, controls, }
}

///|
/// 更新一个控件的尺寸(缩放后)。
pub fn form_model_resize(
  model : FormModel,
  index : Int,
  width : Double,
  height : Double,
) -> FormModel {
  if index < 0 || index >= model.controls.length() {
    return model
  }
  let controls : Array[FormControl] = []
  let mut i = 0
  for control in model.controls {
    if i == index {
      controls.push({ ..control, width, height, })
    } else {
      controls.push(control)
    }
    i = i + 1
  }
  { ..model, controls, }
}

///|
/// @ir 程序窗口与控件 → FormModel（M6①：代码工程生成器的 form.mbt 腿）。
/// 形状不在 form 子集内的控件（列表框/表格/下拉/进度条）按子集边界
/// 诚实跳过；OnClick 事件绑定到 handlers.mbt 的同名函数。
pub fn ir_controls_to_form_model(
  window : @ir.WindowSpec,
  controls : Array[@ir.Control],
  handlers : Array[@ir.Handler],
  handler_name_of : (@ir.Handler, Int) -> String,
) -> FormModel {
  let form_controls : Array[FormControl] = []
  for control in controls {
    let kind : FormKind = match control.kind {
      @ir.Button => FkButton
      @ir.Label => FkText
      @ir.TextField => FkTextField
      @ir.CheckBox => FkCheckBox
      @ir.Image => FkImage
      // 列表框/表格/下拉/进度条不在 form 子集内
      _ => continue
    }
    let mut handler : String? = None
    for index, candidate in handlers {
      if candidate.control_name == control.name &&
        candidate.event.tag() == "on_click" {
        handler = Some(handler_name_of(candidate, index + 1))
      }
    }
    form_controls.push(FormControl::{
      props: control.props,
      kind,
      text: control.text,
      handler,
      x: control.x.to_double(),
      y: control.y.to_double(),
      width: control.width.to_double(),
      height: control.height.to_double(),
    })
  }
  FormModel::{
    stage_width: window.width.to_double(),
    stage_height: window.height.to_double(),
    controls: form_controls,
  }
}
