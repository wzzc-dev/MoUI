///|
/// 终端键盘透传节点:聚焦后捕获 Keyboard/TextInput 事件并转为消息。
/// 按仓库边界规则,自定义 ViewNode 放在 addon 包。
pub struct TerminalKeyboardNode {}

///|
impl @core.ViewNode for TerminalKeyboardNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="TerminalKeyboardInput")
}

///|
impl @core.ViewNode for TerminalKeyboardNode with fn layout(_self, ctx) {
  let child_size = if ctx.child_sizes.length() > 0 {
    ctx.child_sizes[0]
  } else {
    @core.Size::new(width=0.0, height=0.0)
  }
  @core.ViewLayoutResult::new(size=child_size, child_frames=[
    @core.Rect::new(
      x=0.0,
      y=0.0,
      width=child_size.width,
      height=child_size.height,
    ),
  ])
}

///|
impl @core.ViewNode for TerminalKeyboardNode with fn focusable(_self) {
  true
}

///|
/// 键盘透传包装:子节点照常渲染,本节点捕获键盘/文本输入。
pub fn[Msg] keyboard_input(
  content : @moui.View[Msg],
  on_key : (@core.KeyboardEvent) -> Msg?,
  on_text : (String) -> Msg?,
) -> @moui.View[Msg] {
  @core.View::from_node(
    TerminalKeyboardNode::{  },
    children=_node => [content],
    event=(_node, ctx) => {
      match ctx.event {
        @core.AppEvent::Keyboard(event) =>
          if !event.pressed {
            @core.ViewEventResult::ignored()
          } else {
            match on_key(event) {
              Some(msg) => @core.ViewEventResult::message(msg)
              None => @core.ViewEventResult::ignored()
            }
          }
        @core.AppEvent::TextInput(event) => {
          let text = match event {
            @core.TextInputEvent::InsertText(t) => Some(t)
            _ => None
          }
          match text {
            Some(t) =>
              match on_text(t) {
                Some(msg) => @core.ViewEventResult::message(msg)
                None => @core.ViewEventResult::ignored()
              }
            None => @core.ViewEventResult::ignored()
          }
        }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}
