///|
pub fn[Msg] focus_ring(
  child : @core.View[Msg],
  focused~ : Bool,
  label? : String = "Focused item",
  theme? : @core.Theme,
  width? : Double,
  height? : Double,
  padding? : Double = 3.0,
  radius? : Double = 8.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let ring = @core.BorderStyle::new(
    brush=@core.Brush::solid(
      if focused {
        resolved_theme.palette.primary
      } else {
        resolved_theme.palette.outline.multiply_alpha(0.42)
      },
    ),
    width=if focused { 2.0 } else { 1.0 },
  )
  let wrapped = @layout.container_box(
    child=Some(child.padding(padding)),
    size=None,
    border=Some(ring),
    corner_radius=radius,
  )
  let framed = match (width, height) {
    (None, None) => wrapped
    _ => wrapped.frame(width?, height?)
  }
  framed
  .focusable()
  .semantics_selected(selected=focused)
  .semantics_description(if focused { "Focused" } else { "Not focused" })
  .accessibility_label(label)
}

///|
pub fn[Msg] menu_button(
  label : String,
  on_click? : Msg,
  variant? : @style.ButtonVariant = Tonal,
  theme? : @core.Theme,
  width? : Double = 160.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  let resolved_theme = @common.views_ambient_theme(theme)
  let spec = match on_click {
    Some(message) =>
      @button.button(
        label,
        on_click=message,
        variant~,
        theme=resolved_theme,
        width~,
        height~,
      )
    None =>
      @button.button(label, variant~, theme=resolved_theme, width~, height~)
  }
  spec.semantics_role(Menu)
}

///|
/// 悬停提示浮层：把 `child` 作为锚点，在它旁边弹一小块提示。
///
/// **尺寸必须由内容决定**。旧实现把文字塞进固定 `180×24` 的框、再套 `Raised`
/// 容器（该变体的 `padding` 是 `spacing_scale.lg = 16`，四边各 16）——于是一个
/// 三字提示（「检查器」）渲染成 **212×56** 的方块，比它指向的图标还大（用户报的
/// 「小 tips 弹出的现在有点太大了」）。提示是**线索**不是面板，尺寸跟着内容走：
/// 一行小字 + 6/3 内衬 + 4pt 圆角，底色取主题的 `Overlay` 面（比面板亮一档，
/// 语义就是「浮在上面」，与卡片用的 `Raised` 区分开）。
pub fn[Msg] tooltip(
  child : @core.View[Msg],
  message : String,
  visible? : Bool = false,
  theme? : @core.Theme,
) -> @core.View[Msg] {
  if !visible {
    return child
  }
  // 内容宽：ASCII 7.9 / 全角 13.0（与 `@chrome.text_estimate_width` 同源口径），
  // **留 15% 余量**——估算偏窄时文字会自己长宽顶破小浮层（本仓已为「估算比实渲
  // 偏窄」付过代价；提示框小，按更保守的余量走）。
  let mut ascii = 0
  let mut wide = 0
  for c in message {
    if c.to_int() < 0x80 {
      ascii = ascii + 1
    } else {
      wide = wide + 1
    }
  }
  let text_w = (ascii.to_double() * 7.9 + wide.to_double() * 13.0) * 1.15
  let resolved = @common.views_ambient_theme(theme)
  @presentation.popup_host(child, [
    @presentation.PresentationSpec::new(
      id="tooltip:\{message}",
      kind=Tooltip,
      anchor=HostBase,
      placement=Some(
        @presentation.PresentationPlacement::new(
          candidates=[AboveEnd, BelowEnd, AboveStart, BelowStart],
          viewport_insets=@core.Insets::all(0.0),
        ),
      ),
      content=@layout.container_box(
        child=Some(
          @layout.padding_xy(
            @text.text(
              message,
              width=text_w,
              height=14.0,
              align=@core.TextAlign::TextCenter,
            ),
            horizontal=6.0,
            vertical=2.0,
          ),
        ),
        size=Some(@core.Size::new(width=text_w.max(24.0) + 12.0, height=18.0)),
        background=Some(resolved.surface_brush(Overlay)),
        border=Some(
          @core.BorderStyle::new(
            brush=@core.Brush::solid(
              resolved.palette.outline.multiply_alpha(0.7),
            ),
            width=1.0,
          ),
        ),
        corner_radius=4.0,
      ).semantics_role(Tooltip),
    ),
  ])
}
