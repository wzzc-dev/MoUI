///|
/// Studio 内核·贡献点：插件向壳「贡献」UI 与命令的类型化面（dsh bundle
/// 里 `contributes` 块的 MoonBit 形态）。全部泛型于 `(Model, Msg)`——插件
/// 包产出自己类型的贡献项，组合根经各插件自己的 wrap 完成提升后，把**已
/// 提升到根类型**的贡献项收进壳渲染的数组（同构性在这一层恢复，所以可以
/// 进同一个数组）。
///
/// 图标用**符号名**（String）而不是具体字形类型：内核不耦合 @views 的图标
/// 枚举，壳负责符号名 → 字形的映射（与命令 id 同一风格）。

///|
/// 面板视图贡献：一个可挂进左/右/中心区域的区域化视图。
/// `render` 收（根模型快照, 区域宽, 区域高），返回根消息类型的视图。
pub(all) struct PanelView[Model, Msg] {
  id : String
  render : (Model, Double, Double) -> @moui.View[Msg]
}

///|
/// 活动栏项贡献：一根栏里的一个槽。`active` 是激活态判定（高亮如实反映
/// 状态的来源），`on_click` 收模型快照产出消息（壳据此统一裁决「再点当前
/// = 收起宿主」一类语义）。
pub(all) struct ActivityItem[Model, Msg] {
  id : String
  icon : String
  label_key : String
  active : (Model) -> Bool
  on_click : (Model) -> Msg
}

///|
/// 底栏页签贡献：页签头单元格 + 页签体。徽标计数是「这里有没有等你处理的
/// 东西」的读数（0 = 不画）。
pub(all) struct BottomTab[Model, Msg] {
  id : String
  label_key : String
  badge : (Model) -> Int
  selected : (Model) -> Bool
  on_select : (Model) -> Msg
  render_body : (Model, Double, Double) -> @moui.View[Msg]
}

///|
/// 命令贡献：命令面板/键盘命令表的条目。`run` 收模型快照产出消息；
/// 返回 None 表示当前状态下命令不可用（面板灰显）。
pub(all) struct CommandContribution[Model, Msg] {
  id : String
  label_key : String
  run : (Model) -> Msg?
}

///|
/// 模式预设（perspective）：三模式工作台的**一行事实**——进入该模式时四
/// 个区域各由哪个贡献项承载。`left/right` 用面板 id，空串 = 收起该栏；
/// `apply` 是进模式时的一次性纯置位（壳调用；模式内的临时收放不回写预设，
/// 见设计契约 3）。
pub(all) struct Perspective[Model] {
  id : String
  label_key : String
  left_panel : String
  center : String
  right_panel : String
  bottom_tab : String
  apply : (Model) -> Model
}
