///|
pub struct ShowcaseApp {
  dark : @core.State[Bool]
  active : @core.State[Bool]
  draft : @core.State[String]
}

///|
pub fn ShowcaseApp::new() -> ShowcaseApp {
  {
    dark: @core.State::new(false),
    active: @core.State::new(false),
    draft: @core.State::new("Visual polish"),
  }
}

///|
pub fn ShowcaseApp::toggle_scheme(self : ShowcaseApp) -> Unit {
  self.dark.update(value => !value)
}

///|
pub fn ShowcaseApp::toggle_active(self : ShowcaseApp) -> Unit {
  self.active.update(value => !value)
}

///|
pub fn ShowcaseApp::root(
  self : ShowcaseApp,
  ctx : @core.BuildContext,
) -> @core.ViewSpec {
  let dark = ctx.watch(self.dark)
  let active = ctx.watch(self.active)
  let draft = ctx.binding(self.draft)
  let theme = if dark { @core.Theme::dark() } else { @core.Theme::light() }
  let offset = if active { 14.0 } else { 0.0 }
  let opacity = if active { 1.0 } else { 0.68 }
  @views.surface(
    @views.column(
      [
        @views.row(
          [
            @views.column(
              [
                @views.text("MoUI Showcase", width=240.0, height=34.0)
                .font(theme.typography.title)
                .foreground(theme.palette.foreground),
                @views.text(
                  if active {
                    "State-driven visuals are active"
                  } else {
                    "Theme, motion, image, and modifiers"
                  },
                  width=300.0,
                  height=28.0,
                )
                .font(theme.typography.caption)
                .foreground(theme.palette.muted),
              ],
              spacing=theme.spacing_scale.xs,
              cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
            ),
            @views.spacer(),
            @views.button(
              if dark {
                "Light"
              } else {
                "Dark"
              },
              on_click=() => self.toggle_scheme(),
              style=@core.ButtonStyle::tonal(theme~),
              width=96.0,
            ),
          ],
          spacing=theme.spacing_scale.md,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
        ),
        @views.row(
          [
            self.visual_card(theme, active, offset, opacity),
            self.controls_card(theme, draft),
          ],
          spacing=theme.spacing_scale.lg,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
        ),
      ],
      spacing=theme.spacing_scale.lg,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStretch,
    ),
    style=@core.SurfaceStyle::default(theme~),
  )
}

///|
fn ShowcaseApp::visual_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  active : Bool,
  offset : Double,
  opacity : Double,
) -> @core.ViewSpec {
  let gradient = @core.Brush::linear_gradient(
    start=@core.Point::new(x=0.0, y=0.0),
    end=@core.Point::new(x=260.0, y=160.0),
    start_color=theme.palette.primary.multiply_alpha(0.92),
    end_color=theme.palette.surface_variant,
  )
  @views.surface(
    @views.column(
      [
        @views.image(
          "showcase://gradient-photo",
          width=248.0,
          height=96.0,
          opacity~,
          corner_radius=theme.radius_scale.lg,
          fit=@core.ImageFit::Cover,
        )
        .background_brush(gradient)
        .corner_radius(theme.radius_scale.lg)
        .clip()
        .opacity(opacity)
        .offset(dx=offset, dy=0.0),
        @views.text(
          if active {
            "Raised card with motion"
          } else {
            "Layered card with image"
          },
          width=260.0,
          height=28.0,
        )
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        @views.button(
          if active {
            "Settle"
          } else {
            "Animate"
          },
          on_click=() => self.toggle_active(),
          style=@core.ButtonStyle::filled(theme~),
          width=140.0,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    style=@core.SurfaceStyle::raised(theme~),
  )
}

///|
fn ShowcaseApp::controls_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  draft : @core.Binding[String],
) -> @core.ViewSpec {
  @views.surface(
    @views.column(
      [
        @views.text("Controls", width=220.0, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        @views.text_field(
          draft,
          placeholder="Type a label",
          style=@core.TextFieldStyle::outline(theme~),
          width=220.0,
        ),
        @views.row(
          [
            @views.button(
              "Primary",
              on_click=() => self.toggle_active(),
              style=@core.ButtonStyle::filled(theme~),
              width=104.0,
            ),
            @views.button(
              "Outline",
              on_click=() => self.toggle_scheme(),
              style=@core.ButtonStyle::outline(theme~),
              width=104.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
        ),
        @views.text("Tokens: radius, shadow, opacity", width=240.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width=284.0,
    height=236.0,
    style=@core.SurfaceStyle::raised(theme~),
  )
}

///|
pub fn ShowcaseApp::runtime(
  self : ShowcaseApp,
  width? : Double = 760.0,
  height? : Double = 420.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_component(
    root=@core.Component::new(ctx => self.root(ctx)),
    size=@core.Size::new(width~, height~),
  )
}
