///|
pub struct ShowcaseApp {
  dark : @core.State[Bool]
  active : @core.State[Bool]
  dialog_visible : @core.State[Bool]
  feature_enabled : @core.State[Bool]
  draft : @core.State[String]
  tab : @core.State[String]
  slider_value : @core.State[Double]
  navigation : @core.NavigationState
  list_scroll : @core.ScrollState
}

///|
pub fn ShowcaseApp::new() -> ShowcaseApp {
  {
    dark: @core.State::new(false),
    active: @core.State::new(false),
    dialog_visible: @core.State::new(false),
    feature_enabled: @core.State::new(true),
    draft: @core.State::new("Visual polish"),
    tab: @core.State::new("form"),
    slider_value: @core.State::new(0.64),
    navigation: @core.NavigationState::new(initial="overview"),
    list_scroll: @core.ScrollState::new(),
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
pub fn ShowcaseApp::show_dialog(self : ShowcaseApp) -> Unit {
  self.dialog_visible.set(true)
}

///|
pub fn ShowcaseApp::hide_dialog(self : ShowcaseApp) -> Unit {
  self.dialog_visible.set(false)
}

///|
pub fn ShowcaseApp::root(
  self : ShowcaseApp,
  ctx : @core.BuildContext,
) -> @core.ViewSpec {
  let dark = ctx.watch(self.dark)
  let active = ctx.watch(self.active)
  let dialog_visible = ctx.watch(self.dialog_visible)
  let draft = ctx.binding(self.draft)
  let tab = ctx.binding(self.tab)
  let slider = ctx.binding(self.slider_value)
  let enabled = ctx.binding(self.feature_enabled)
  ignore(ctx.watch_navigation(self.navigation))
  ignore(ctx.watch_scroll(self.list_scroll))
  let theme = if dark { @core.Theme::dark() } else { @core.Theme::light() }
  let offset = if active { 14.0 } else { 0.0 }
  let opacity = if active { 1.0 } else { 0.68 }
  let content = @views.navigation_stack(self.navigation, [
    @views.navigation_destination(
      route="overview",
      view=@views.column(
        [
          @views.row(
            [
              self.visual_card(theme, active, offset, opacity),
              self.gallery_card(theme, slider),
              self.capability_card(theme),
            ],
            spacing=theme.spacing_scale.lg,
            cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
          ),
          self.visual_correctness_card(theme, active, opacity),
        ],
        spacing=theme.spacing_scale.lg,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
      ),
    ),
    @views.navigation_destination(
      route="controls",
      view=self.controls_card(theme, draft, tab, slider, enabled),
    ),
  ])
  let shell = @views.surface(
    @views.column(
      [self.header(theme, dark, active), content],
      spacing=theme.spacing_scale.lg,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStretch,
    ),
    style=@core.SurfaceStyle::default(theme~),
  )
  @views.dialog_host(
    shell,
    dialog=Some(self.dialog(theme)),
    presented=dialog_visible,
  )
}

///|
fn ShowcaseApp::visual_correctness_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  active : Bool,
  opacity : Double,
) -> @core.ViewSpec {
  ignore(self)
  let image = showcase_image_source()
  let transform_offset = if active { 18.0 } else { 6.0 }
  @views.surface(
    @views.column(
      [
        @views.text("Visual correctness", width=260.0, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        @views.row(
          [
            @views.image(
              image,
              width=120.0,
              height=72.0,
              opacity=1.0,
              corner_radius=theme.radius_scale.md,
              fit=@core.ImageFit::Contain,
            ).clip(),
            @views.image(
              image,
              width=120.0,
              height=72.0,
              opacity~,
              corner_radius=theme.radius_scale.md,
              fit=@core.ImageFit::Cover,
            ).clip(),
            @views.image(
              image,
              width=120.0,
              height=72.0,
              opacity=0.78,
              corner_radius=theme.radius_scale.lg,
              fit=@core.ImageFit::Cover,
            )
            .clip()
            .scale(sx=0.92, sy=0.92)
            .offset(dx=transform_offset, dy=0.0),
          ],
          spacing=theme.spacing_scale.md,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width=760.0,
    height=142.0,
    style=@core.SurfaceStyle::raised(theme~),
  )
}

///|
fn showcase_image_source() -> String {
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAASCAYAAAA6yNxSAAACK0lEQVR42u3Uu6okVRQG4HqIfoXqulBdt66iLt1nZo6nuyr1GTQwMDAQDAwMFEcZFS94YVScEbVRn0gUERER8QVEhPJDOKIwHkcxnOAL1l4L1h/svYPw0Z+WNRExCSkZG3IKSipqtjS0dPQMjOzYc8Y1rnODcy44cGRiJggf+3FZExGTkJKxIaegpKJmS0NLR8/AyI49Z1zjOjc454IDRyZmgvDxH5Y1ETEJKRkbcgpKKmq2NLR09AyM7Nhzxs+//PqHc/UFB45MzAThE98vayJiElIyNuQUlFTUbGlo6egZGNmx58/LL104P3BkYiYIn/xuWRMRk5CSsSGnoKSiZktDS0fPwMiOPWf85R9QX3DgyMRMsPr8tDz08CP/yurd07K6zTu8zVu8yRu8zmu8yiu8zEt/v+P3AKvP+PSfg6zeN/fe6T8FWN3ixdPVAVYnPuFjPuJD7nKHD07/S4DVC9zkeZ47PQjwIMDyG/KhyFi81CXIAAAAAElFTkSuQmCC"
}

///|
fn ShowcaseApp::header(
  self : ShowcaseApp,
  theme : @core.Theme,
  dark : Bool,
  active : Bool,
) -> @core.ViewSpec {
  @views.row(
    [
      @views.column(
        [
          @views.text("MoUI Gallery", width=240.0, height=34.0)
          .font(theme.typography.title)
          .foreground(theme.palette.foreground),
          @views.text(
            if active {
              "State-driven visuals are active"
            } else {
              "SwiftUI, Flutter, and Compose ideas in MoonBit"
            },
            width=360.0,
            height=28.0,
          )
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
        ],
        spacing=theme.spacing_scale.xs,
        cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
      ),
      @views.scroll_view(
        @views.row(
          [
            @views.button(
              "Overview",
              on_click=() => self.navigation.replace("overview"),
              style=@core.ButtonStyle::tonal(theme~),
              width=104.0,
            ),
            @views.button(
              "Controls",
              on_click=() => self.navigation.replace("controls"),
              style=@core.ButtonStyle::tonal(theme~),
              width=104.0,
            ),
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
            @views.menu_button(
              "Dialog",
              on_click=() => self.show_dialog(),
              style=@core.ButtonStyle::outline(theme~),
              width=104.0,
            ).keyboard_shortcut(
              @core.KeyboardShortcut::new(
                key="k",
                modifiers=@core.KeyModifiers::new(meta=true),
              ),
            ),
          ],
          spacing=theme.spacing_scale.sm,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
        ),
        width=432.0,
        height=46.0,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
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
          showcase_image_source(),
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
fn ShowcaseApp::gallery_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  slider : @core.Binding[Double],
) -> @core.ViewSpec {
  @views.surface(
    @views.column(
      [
        @views.text("Lazy gallery", width=220.0, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        @views.progress(slider.get(), width=220.0),
        @views.lazy_list(
          self.gallery_items(),
          item => item,
          item => {
            @views.text(item, width=220.0, height=28.0).foreground(
              theme.palette.foreground,
            )
          },
          state=self.list_scroll,
          item_height=30.0,
          viewport_height=96.0,
          spacing=4.0,
        ),
        @views.tooltip(
          @views.menu_button(
            "Shortcut",
            on_click=() => self.show_dialog(),
            style=@core.ButtonStyle::ghost(theme~),
            width=140.0,
          ),
          "Keyboard: Meta+K",
          visible=true,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width=284.0,
    height=284.0,
    style=@core.SurfaceStyle::raised(theme~),
  )
}

///|
fn ShowcaseApp::capability_card(
  self : ShowcaseApp,
  theme : @core.Theme,
) -> @core.ViewSpec {
  ignore(self)
  let rows : Array[@core.ViewSpec] = []
  for entry in @render.renderer_feature_capability_report() {
    rows.push(capability_row(entry, theme))
  }
  @views.surface(
    @views.column(
      [
        @views.text("Renderer capability", width=220.0, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        @views.column(
          rows,
          spacing=theme.spacing_scale.xs,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
        ),
      ],
      spacing=theme.spacing_scale.md,
      cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
    ),
    width=244.0,
    height=284.0,
    style=@core.SurfaceStyle::raised(theme~),
  )
}

///|
fn capability_row(
  entry : @render.RendererFeatureCapability,
  theme : @core.Theme,
) -> @core.ViewSpec {
  let status = capability_status_label(entry)
  @views.row(
    [
      @views.text(entry.feature.label(), width=92.0, height=22.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.foreground),
      @views.text(status, width=112.0, height=22.0)
      .font(theme.typography.caption)
      .foreground(capability_status_color(entry, theme)),
    ],
    spacing=theme.spacing_scale.xs,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossCenter,
  )
}

///|
fn capability_status_label(entry : @render.RendererFeatureCapability) -> String {
  if entry.native_status == entry.web_status {
    entry.native_status.label()
  } else {
    "native " +
    entry.native_status.label() +
    " · web " +
    entry.web_status.label()
  }
}

///|
fn capability_status_color(
  entry : @render.RendererFeatureCapability,
  theme : @core.Theme,
) -> @core.Color {
  if entry.native_status.needs_follow_up() || entry.web_status.needs_follow_up() {
    theme.palette.primary
  } else {
    theme.palette.muted
  }
}

///|
fn ShowcaseApp::controls_card(
  self : ShowcaseApp,
  theme : @core.Theme,
  draft : @core.Binding[String],
  tab : @core.Binding[String],
  slider : @core.Binding[Double],
  enabled : @core.Binding[Bool],
) -> @core.ViewSpec {
  @views.surface(
    @views.tab_view(tab, [
      @views.tab_item(
        route="form",
        label="Form",
        view=@views.column(
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
            @views.toggle(
              "Enabled",
              enabled,
              foreground=theme.palette.foreground,
            ),
            @views.slider(slider, width=220.0),
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
                ).disabled(disabled=!enabled.get()),
              ],
              spacing=theme.spacing_scale.sm,
            ),
          ],
          spacing=theme.spacing_scale.md,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
        ),
      ),
      @views.tab_item(
        route="status",
        label="Status",
        view=@views.column(
          [
            @views.radio("Native renderer parity", enabled),
            @views.progress(slider.get(), width=220.0),
            @views.text(
              "Tokens: radius, shadow, opacity",
              width=240.0,
              height=24.0,
            )
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
          ],
          spacing=theme.spacing_scale.md,
          cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
        ),
      ),
    ]),
    width=620.0,
    height=284.0,
    style=@core.SurfaceStyle::raised(theme~),
  )
}

///|
fn ShowcaseApp::dialog(
  self : ShowcaseApp,
  theme : @core.Theme,
) -> @core.ViewSpec {
  @views.column(
    [
      @views.text("Gallery dialog", width=240.0, height=30.0)
      .font(theme.typography.control)
      .foreground(theme.palette.foreground),
      @views.text(
        "Dialogs, shortcuts, and semantics share the same ViewSpec tree.",
        width=280.0,
        height=52.0,
      )
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      @views.button(
        "Close",
        on_click=() => self.hide_dialog(),
        style=@core.ButtonStyle::filled(theme~),
        width=120.0,
      ),
    ],
    spacing=theme.spacing_scale.md,
    cross_axis_alignment=@core.CrossAxisAlignment::CrossStart,
  )
}

///|
fn ShowcaseApp::gallery_items(self : ShowcaseApp) -> Array[String] {
  ignore(self)
  [
    "State holders", "Modifier order", "Lazy list rows", "Keyboard shortcut", "Dialog host",
    "Accessible controls",
  ]
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
