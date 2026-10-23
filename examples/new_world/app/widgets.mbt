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
/// The per-line action row (‹ › 改 删 分叉) retired into each line's `⋯` menu
/// (`message_menu.mbt`); the compact theme in `themes.mbt` is what that menu's
/// items wear, so the half-height metrics still do their job there.
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
/// A section heading with an optional action on the same row.
///
/// The action sits at the right edge of the section's own width, so headings in
/// different rails still align with their content instead of drifting.
fn section_header(
  title : String,
  width~ : Double,
  action? : @moui.View[Msg],
  action_width~ : Double = 0.0,
) -> @moui.View[Msg] {
  // The heading yields exactly the room its action needs. A fixed reserve made
  // the action too narrow for its own label, and the row overflowed the rail.
  let label = text(
    title,
    role=Subtitle,
    width=(width - action_width - action_gap).max(60.0),
    height=28.0,
    align=TextStart,
  )
  match action {
    Some(view) => row([label, view], spacing=action_gap, align=Center)
    None => row([label], spacing=0.0)
  }
}
