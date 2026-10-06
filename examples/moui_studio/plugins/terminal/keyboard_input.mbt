///|
/// vendor 自 examples/terminal/addon（M8②）：终端键盘透传节点——聚焦后
/// 捕获 Keyboard/TextInput 事件并转为消息，实现 VS Code 式直通交互。
/// 焦点获取：节点 identity key = "terminal-input"，组合根经
/// runtime.focus_key 聚焦（Ctrl+T / AI 模式进入时触发）；指针按下亦
/// 声明焦点（点击终端屏即聚焦）。

///|
pub struct TerminalKeyboardNode {}

///|
impl @core.ViewNode for TerminalKeyboardNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="TerminalKeyboardInput", key=Some("terminal-input"))
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
/// 指针按下即声明键盘焦点（点击终端屏后键入直通）。
pub fn[Msg] keyboard_input(
  content : @moui.View[Msg],
  on_key : (@core.KeyboardEvent) -> Msg?,
  on_text : (String) -> Msg?,
) -> @moui.View[Msg] {
  @core.View::from_node(
    TerminalKeyboardNode::{ },
    children=_node => [content],
    event=(_node, ctx) => {
      match ctx.event {
        Pointer(event) =>
          if event.phase is @core.PointerPhase::Down {
            {
              changed: true,
              activated: false,
              focused: true,
              captured: true,
              state: Some(
                {
                  focused: true,
                  hovered: false,
                  pressed: true,
                  selected: false,
                  checked: false,
                  expanded: false,
                  disabled: false,
                  slots: @core.ViewStateSlots::empty(),
                },
              ),
              text_control: None,
              dirty: @core.ViewPaintDirty,
              messages: [],
            }
          } else {
            @core.ViewEventResult::ignored()
          }
        Keyboard(event) =>
          if !event.pressed {
            @core.ViewEventResult::ignored()
          } else {
            match on_key(event) {
              Some(msg) => @core.ViewEventResult::message(msg)
              None => @core.ViewEventResult::ignored()
            }
          }
        TextInput(event) => {
          let text = match event {
            InsertText(t) => Some(t)
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
