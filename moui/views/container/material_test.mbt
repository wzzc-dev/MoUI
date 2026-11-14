///|
test "material paints a backdrop-blur shader effect" {
  let view : @core.View[Unit] = @container.material(
    width=120.0,
    height=40.0,
    blur_radius=8.0,
    corner_radius=6.0,
    tint=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.4),
  )
  let layout = view.layout(
    center_layout_context(
      constraints=@core.Constraints::loose(
        @core.Size::new(width=400.0, height=400.0),
      ),
      child_size=@core.Size::new(width=0.0, height=0.0),
    ),
  )
  inspect(layout.size.width, content="120")
  inspect(layout.size.height, content="40")
  let plan = view.paint(
    themed_paint_context(
      frame=@core.Rect::new(x=0.0, y=0.0, width=120.0, height=40.0),
      theme=@core.Theme::neutral(),
    ),
  )
  match plan.commands[0] {
    DrawShaderEffect(spec) => {
      inspect(spec.name, content="backdrop-blur")
      inspect(spec.uniforms[0], content="8")
      inspect(spec.uniforms[1], content="6")
      inspect(spec.fallback.fallback_color().a, content="0.4")
    }
    _ => abort("expected DrawShaderEffect")
  }
}

///|
test "material defaults its tint from the theme surface" {
  let view : @core.View[Unit] = @container.material(width=80.0, height=32.0)
  let plan = view.paint(
    themed_paint_context(
      frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=32.0),
      theme=@core.Theme::neutral(),
    ),
  )
  match plan.commands[0] {
    DrawShaderEffect(spec) =>
      inspect(spec.fallback.fallback_color().a, content="0.65")
    _ => abort("expected DrawShaderEffect")
  }
}
