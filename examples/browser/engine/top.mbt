///|
/// One-call entry point for app code: parse + layout HTML with crater and
/// translate the resulting paint tree into MoUI `DrawCommand`s.
pub fn render_html(
  html : String,
  width : Double,
  height : Double,
) -> Array[@core.DrawCommand] {
  let tree = @crater.render_html_to_paint_tree(
    html,
    @values.Size::new(width, height),
  )
  @translate.paint_node_to_commands(tree)
}
