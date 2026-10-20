///|
/// Shared control sizes and small composite widgets.
///
/// The product used to size every button by hand, which is how "改 / 删 / 分叉"
/// ended up 32×22 next to 88×40 primaries: three different scales in one row.
/// Everything that composes buttons now goes through these sizes, so a new
/// control inherits the scale instead of inventing a fourth one.
///
/// Sizes follow the theme's 8px spacing rhythm:
///
/// | token         | height | use                                          |
/// |---------------|--------|----------------------------------------------|
/// | `button_hero` | 40     | the primary action of a page (发送 / 保存)     |
/// | `button_md`   | 32     | ordinary actions (重新生成 / 创建角色)         |
/// | `button_sm`   | 28     | standalone small actions (离开场景 / 保存)     |
/// | `button_xs`   | 24     | inline affordances inside a caption row       |
///
/// The per-line action row (‹ › 改 删 分叉) sits below `button_xs`: the product
/// halved it, and `row_action_height` + `compact_action_theme` are what make the
/// half height real instead of being floored by the control font.
///
/// Widths stay with the caller because label length varies by locale; heights,
/// paddings, and gaps are what make a row read as one control group.

///|
pub let button_hero_height : Double = 40.0

///|
pub let button_md_height : Double = 32.0

///|
pub let button_sm_height : Double = 28.0

///|
pub let button_xs_height : Double = 24.0

///|
/// Gap between buttons in an action row. One value, so rows that sit next to
/// each other line up.
pub let action_gap : Double = 8.0

///|
/// A secondary row action in the per-line action row (改 / 删 / 分叉 / ‹ ›).
/// `Outline` draws the hairline border that makes a row action read as a
/// button; `Ghost` made the row
/// look like a line of underlined text, which is what "按钮不太好看" was about.
///
/// Row actions render at half the height the product originally asked for
/// (14px requested, ~16px rendered): the default control font plus the default
/// 8px vertical paddings would floor the height at ~32px no matter what the
/// caller requests, because `button` treats `height` as a *minimum*. The
/// compact theme shrinks the metrics, not the palette, so the row keeps its
/// colours while the buttons actually halve.
fn compact_action_theme() -> @moui.Theme {
  let base = @views.default_theme()
  let label = @text.FontSpec::new(size=10.5, weight=600)
  base
  .with_spacing_scale({ xs: 1.0, sm: 1.0, md: 8.0, lg: 10.0, xl: 16.0, })
  .with_typography({ ..base.typography, label, control: label, })
}

///|
/// Requested height of a row action: half of the old `button_sm_height`.
fn row_action_height() -> Double {
  button_sm_height / 2.0
}

///|
fn action_button(
  label : String,
  on_click : Msg,
  width~ : Double,
  height~ : Double = row_action_height(),
) -> @moui.View[Msg] {
  button(
    label,
    on_click~,
    variant=Outline,
    theme=compact_action_theme(),
    width~,
    height~,
  )
}

///|
/// A destructive row action (删). Same shape as `action_button`, with the danger
/// colour on the label so the row reads at a glance without a filled red block.
fn destructive_button(
  label : String,
  on_click : Msg,
  width~ : Double,
  height~ : Double = row_action_height(),
) -> @moui.View[Msg] {
  button(
    label,
    on_click~,
    width~,
    height~,
    theme=compact_action_theme(),
    style=destructive_ghost_style(),
  )
}

///|
/// Ghost geometry with the palette's danger colour as the foreground.
///
/// Built once from the default theme: a `ButtonStyle` cannot read the
/// environment theme at paint time, so the colour has to be chosen here. A red
/// *label* stays legible in both schemes, where a hardcoded red *fill* would not.
fn destructive_ghost_style() -> @views.ButtonStyle {
  let danger = @views.default_theme().palette.danger
  let transparent = @graphics.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
  let border = @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(danger.multiply_alpha(0.45)),
    width=1.0,
  )
  let normal = @views.new_control_state_style(
    foreground=danger,
    background=@graphics.Brush::solid(transparent),
    border~,
    radius=6.0,
  )
  let hovered = @views.new_control_state_style(
    foreground=danger,
    background=@graphics.Brush::solid(danger.multiply_alpha(0.10)),
    border~,
    radius=6.0,
  )
  let pressed = @views.new_control_state_style(
    foreground=danger,
    background=@graphics.Brush::solid(danger.multiply_alpha(0.18)),
    border~,
    radius=6.0,
  )
  let disabled = @views.new_control_state_style(
    foreground=danger.multiply_alpha(0.38),
    background=@graphics.Brush::solid(transparent),
    radius=6.0,
  )
  @views.ButtonStyle::new(normal~, hovered~, pressed~, disabled~)
}

///|
/// A section heading with an optional action on the same row.
///
/// The action sits at the right edge of the section's own width, so headings in
/// different rails still align with their content instead of drifting.
fn section_header(
  title : String,
  width~ : Double,
  action? : @moui.View[Msg],
) -> @moui.View[Msg] {
  let label = text(
    title,
    role=Subtitle,
    width=width - 112.0,
    height=28.0,
    align=TextStart,
  )
  match action {
    Some(view) => row([label, view], spacing=action_gap, align=Center)
    None => row([label], spacing=0.0)
  }
}
