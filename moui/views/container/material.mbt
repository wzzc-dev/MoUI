///|
/// Backdrop material: a frosted panel that blurs what is already painted
/// underneath it. Renderers with backdrop blur (Skia raster) draw the blurred
/// backdrop plus a translucent tint; renderers without it fall back to the
/// tint alone, which is the documented cross-platform degradation.
///
/// The command is a named `ShaderEffect` (`"backdrop-blur"`) so the existing
/// effect dispatch owns it and unknown renderers already have a fallback path.
priv struct BackdropBlur {
  width : Double
  height : Double
  blur_radius : Double
  corner_radius : Double
  tint : @core.Color
  label : String
}

///|
impl @core.ViewNode for BackdropBlur with fn identity(_self) {
  @core.ViewIdentity::new(kind="BackdropBlur")
}

///|
impl @core.ViewNode for BackdropBlur with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=self.height),
    ),
  )
}

///|
impl @core.ViewNode for BackdropBlur with fn paint(self, ctx) {
  @core.ViewPaintPlan::commands([
    DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="backdrop-blur",
        frame=ctx.frame,
        uniforms=[self.blur_radius, self.corner_radius],
        fallback=@core.Brush::solid(self.tint),
      ),
    ),
  ])
}

///|
impl @core.ViewNode for BackdropBlur with fn semantics(self) {
  if self.label == "" {
    @core.ViewSemanticsInfo::transparent()
  } else {
    @core.ViewSemanticsInfo::leaf(role=Image, label=self.label)
  }
}

///|
/// Frosted backdrop panel. `blur_radius` is in DIPs; `corner_radius` shapes the
/// clip where the renderer supports it (Skia). `tint` defaults to the theme
/// surface at 65% so the fallback still reads as a material.
pub fn[Msg] material(
  width~ : Double,
  height~ : Double,
  blur_radius~ : Double = 16.0,
  corner_radius~ : Double = 12.0,
  tint? : @core.Color,
  theme? : @core.Theme,
  label~ : String = "",
) -> @core.View[Msg] {
  let resolved_tint = match tint {
    Some(value) => value
    None => {
      let resolved_theme = @common.views_ambient_theme(theme)
      resolved_theme.palette.surface.multiply_alpha(0.65)
    }
  }
  @core.View::from_node(BackdropBlur::{
    width,
    height,
    blur_radius,
    corner_radius,
    tint: resolved_tint,
    label,
  })
}
