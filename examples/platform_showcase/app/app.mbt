///|
using @views {
  button,
  card,
  checkbox,
  choice_item,
  column,
  container,
  picker,
  picker_item,
  progress_status,
  responsive_grid,
  row,
  scroll_view,
  segmented_control,
  spacer,
  stat_card,
  status_badge,
  text,
  text_field,
}

///|
pub(all) enum PlatformId {
  MacOS
  Linux
  Windows
  Android
  IOS
  Web
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PlatformShowcaseModel {
  active_platform : PlatformId
  selected_platform : PlatformId
  page_scroll : @state.ScrollState
  sample_text : String
  selected_mode : String
  selected_density : String
  feature_enabled : Bool
  slider_value : Double
  counter : Int
}

///|
pub(all) enum PlatformShowcaseMsg {
  SelectPlatform(String)
  SelectMode(String)
  SelectDensity(String)
  SampleTextChanged(String)
  FeatureToggled(Bool)
  SliderChanged(Double)
  Increment
  Decrement
  Reset
} derive(Eq, Debug, ToJson)

///|
priv struct PlatformRuntimeInfo {
  id : PlatformId
  name : String
  route : String
  status : String
  command : String
  tone : @views.FeedbackTone
  badge_tone : @views.BadgeTone
  progress : Double
}

///|
pub fn PlatformShowcaseModel::new(
  active_platform~ : PlatformId,
) -> PlatformShowcaseModel {
  {
    active_platform,
    selected_platform: active_platform,
    page_scroll: @state.ScrollState::new(),
    sample_text: "Launch note",
    selected_mode: "overview",
    selected_density: "regular",
    feature_enabled: true,
    slider_value: 0.68,
    counter: 0,
  }
}

///|
pub fn update(
  model : PlatformShowcaseModel,
  message : PlatformShowcaseMsg,
) -> PlatformShowcaseModel {
  match message {
    SelectPlatform(id) =>
      {
        ..model,
        selected_platform: platform_id_from_string(id).unwrap_or(
          model.selected_platform,
        ),
      }
    SelectMode(id) => { ..model, selected_mode: id }
    SelectDensity(id) => { ..model, selected_density: id }
    SampleTextChanged(value) => { ..model, sample_text: value }
    FeatureToggled(value) => { ..model, feature_enabled: value }
    SliderChanged(value) => { ..model, slider_value: value }
    Increment => { ..model, counter: model.counter + 1 }
    Decrement => { ..model, counter: model.counter - 1 }
    Reset => { ..model, counter: 0, slider_value: 0.68 }
  }
}

///|
pub fn view(
  model : PlatformShowcaseModel,
  env : @moui.ViewEnvironment,
) -> @moui.View[PlatformShowcaseMsg] {
  let theme = @views.light_theme()
  let viewport = env.viewport_size()
  let page_width = responsive_page_width(model.active_platform, viewport.width)
  let compact = page_width < 760.0
  let content_width = (page_width - 32.0).max(320.0)
  let selected = platform_runtime_info(model.selected_platform)
  container(
    scroll_view(
      container(
        column(
          [
            hero_section(model, theme, content_width, compact),
            overview_metrics(model, selected, theme, content_width, compact),
            showcase_workspace(model, selected, theme, content_width, compact),
            runtime_matrix(model, theme, content_width, compact),
          ],
          spacing=theme.spacing_scale.md,
          align=@views.CrossAlign::Stretch,
        ),
        width=page_width,
        background=theme.palette.background,
        padding=16.0,
        theme~,
      ),
      width=page_width,
      height=viewport.height.max(1.0),
      state=Some(model.page_scroll),
    ),
    width=page_width,
    height=viewport.height.max(1.0),
    background=theme.palette.background,
    padding=0.0,
    theme~,
  )
}

///|
pub fn program(
  active_platform~ : PlatformId,
) -> @moui.Program[PlatformShowcaseModel, PlatformShowcaseMsg] {
  @moui.Program::simple_with_environment(
    init=PlatformShowcaseModel::new(active_platform~),
    update~,
    view~,
  )
}

///|
pub fn platform_id_to_string(id : PlatformId) -> String {
  match id {
    PlatformId::MacOS => "macos"
    PlatformId::Linux => "linux"
    PlatformId::Windows => "windows"
    PlatformId::Android => "android"
    PlatformId::IOS => "ios"
    PlatformId::Web => "web"
  }
}

///|
pub fn platform_id_from_string(id : String) -> PlatformId? {
  match id {
    "macos" => Some(PlatformId::MacOS)
    "linux" => Some(PlatformId::Linux)
    "windows" => Some(PlatformId::Windows)
    "android" => Some(PlatformId::Android)
    "ios" => Some(PlatformId::IOS)
    "web" => Some(PlatformId::Web)
    _ => None
  }
}

///|
fn hero_section(
  model : PlatformShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[PlatformShowcaseMsg] {
  let title_width = if compact {
    width - 32.0
  } else {
    (width - 184.0).max(280.0)
  }
  let badge = status_badge(
    platform_display_name(model.active_platform),
    tone=@views.BadgeTone::Accent,
    detail="active host",
    theme~,
    width=148.0,
  )
  let title = text(
    "MoUI Platform Showcase",
    role=@views.TextRole::Title,
    theme~,
    width=title_width,
    height=34.0,
    align=@text.TextAlign::TextStart,
  )
  let subhead = text(
    "Release console for macOS, Linux, Windows, Android, iOS, and Web.",
    role=@views.TextRole::Body,
    theme~,
    width=width - 32.0,
    height=44.0,
    align=@text.TextAlign::TextStart,
  )
  let header = if compact {
    column(
      [title, badge],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Start,
    )
  } else {
    row(
      [title, spacer(weight=1.0), badge],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    )
  }
  card(
    column(
      [
        header,
        subhead,
        row(
          [
            status_badge(
              mode_label(model.selected_mode),
              tone=@views.BadgeTone::Neutral,
              detail="view",
              theme~,
              width=128.0,
            ),
            status_badge(
              density_label(model.selected_density),
              tone=@views.BadgeTone::Neutral,
              detail="density",
              theme~,
              width=148.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    padding=16.0,
    theme~,
  )
}

///|
fn overview_metrics(
  model : PlatformShowcaseModel,
  selected : PlatformRuntimeInfo,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[PlatformShowcaseMsg] {
  let card_width = if compact {
    width
  } else {
    (width - theme.spacing_scale.md * 3.0) / 4.0
  }
  responsive_grid(
    [
      stat_card(
        "Active host",
        platform_display_name(model.active_platform),
        caption="entrypoint selected",
        tone=@views.FeedbackTone::Info,
        theme~,
        width=card_width,
      ),
      stat_card(
        "Readiness",
        "\{readiness_score(model)}%",
        caption=readiness_label(model),
        tone=readiness_tone(model),
        theme~,
        width=card_width,
      ),
      stat_card(
        "Selected route",
        selected.name,
        caption=selected.status,
        tone=selected.tone,
        theme~,
        width=card_width,
      ),
      stat_card(
        "State ticks",
        "\{model.counter}",
        caption="shared update loop",
        tone=@views.FeedbackTone::Success,
        theme~,
        width=card_width,
      ),
    ],
    width~,
    min_column_width=if compact { width } else { 190.0 },
    row_spacing=theme.spacing_scale.md,
    column_spacing=theme.spacing_scale.md,
  )
}

///|
fn showcase_workspace(
  model : PlatformShowcaseModel,
  selected : PlatformRuntimeInfo,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[PlatformShowcaseMsg] {
  let gap = theme.spacing_scale.md
  let main_width = if compact {
    width
  } else {
    ((width - gap) * 0.58).max(420.0)
  }
  let side_width = if compact {
    width
  } else {
    (width - gap - main_width).max(320.0)
  }
  let workflow = workflow_panel(model, selected, theme, main_width)
  let side = column(
    [
      interaction_panel(model, theme, side_width),
      live_status_panel(model, selected, theme, side_width),
    ],
    spacing=gap,
    align=@views.CrossAlign::Stretch,
  )
  if compact {
    column([workflow, side], spacing=gap, align=@views.CrossAlign::Stretch)
  } else {
    row([workflow, side], spacing=gap, align=@views.CrossAlign::Start)
  }
}

///|
fn workflow_panel(
  model : PlatformShowcaseModel,
  selected : PlatformRuntimeInfo,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[PlatformShowcaseMsg] {
  let inner = width - 32.0
  card(
    column(
      [
        row(
          [
            text(
              "Launch Review",
              role=@views.TextRole::Subtitle,
              theme~,
              width=(inner - 128.0).max(160.0),
              height=28.0,
              align=@text.TextAlign::TextStart,
            ),
            spacer(weight=1.0),
            status_badge(
              selected.name,
              tone=selected.badge_tone,
              detail=selected.status,
              theme~,
              width=116.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
        task_row(
          "Adaptive layout",
          "Phone stack, desktop workspace, web canvas",
          "ready",
          @views.BadgeTone::Success,
          theme,
          inner,
        ),
        task_row(
          "Shared controls",
          "Text input, segmented mode, picker, checkbox, slider",
          "live",
          @views.BadgeTone::Accent,
          theme,
          inner,
        ),
        task_row(
          "Mobile shells",
          "Android Activity and UIKit embedded sessions",
          if model.feature_enabled {
            "enabled"
          } else {
            "paused"
          },
          if model.feature_enabled {
            @views.BadgeTone::Warning
          } else {
            @views.BadgeTone::Neutral
          },
          theme,
          inner,
        ),
        task_row(
          "Runtime evidence",
          selected.command,
          selected.status,
          selected.badge_tone,
          theme,
          inner,
        ),
        progress_status(
          "Selected route progress",
          value=selected.progress,
          status=selected.status,
          tone=selected.tone,
          theme~,
          width=inner,
        ),
        text(
          "Note: \{model.sample_text}",
          role=@views.TextRole::Body,
          theme~,
          width=inner,
          height=28.0,
          align=@text.TextAlign::TextStart,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    padding=16.0,
    theme~,
  )
}

///|
fn task_row(
  title : String,
  detail : String,
  status : String,
  tone : @views.BadgeTone,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[PlatformShowcaseMsg] {
  container(
    row(
      [
        column(
          [
            text(
              title,
              role=@views.TextRole::Body,
              theme~,
              width=(width - 116.0).max(160.0),
              height=24.0,
              align=@text.TextAlign::TextStart,
            ),
            text(
              detail,
              role=@views.TextRole::Caption,
              theme~,
              width=(width - 116.0).max(160.0),
              height=22.0,
              align=@text.TextAlign::TextStart,
            ),
          ],
          spacing=2.0,
          align=@views.CrossAlign::Stretch,
        ),
        spacer(weight=1.0),
        status_badge(status, tone~, theme~, width=92.0),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=58.0,
    background=theme.palette.surface_variant.multiply_alpha(0.52),
    corner_radius=theme.radius_scale.md,
    theme~,
    padding=10.0,
  )
}

///|
fn interaction_panel(
  model : PlatformShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[PlatformShowcaseMsg] {
  let inner = width - 32.0
  card(
    column(
      [
        text(
          "Interaction Lab",
          role=@views.TextRole::Subtitle,
          theme~,
          width=inner,
          height=28.0,
          align=@text.TextAlign::TextStart,
        ),
        text_field(
          model.sample_text,
          on_input=value => SampleTextChanged(value),
          placeholder="Release note",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=inner,
        ),
        segmented_control(
          [
            choice_item("overview", "Overview"),
            choice_item("workflow", "Workflow"),
            choice_item("runtime", "Runtime"),
          ],
          selected=model.selected_mode,
          on_select=value => SelectMode(value),
          size=@views.SegmentedControlSize::Regular,
          theme~,
          width=inner,
        ),
        picker(
          [
            picker_item("compact", "Compact density"),
            picker_item("regular", "Regular density"),
            picker_item("comfortable", "Comfortable density"),
          ],
          selected=model.selected_density,
          on_select=value => SelectDensity(value),
          placeholder="Density",
          theme~,
        ).frame(width=inner, height=40.0),
        checkbox(
          "Mobile shell evidence",
          checked=model.feature_enabled,
          on_change=value => FeatureToggled(value),
          theme~,
          check_color=theme.palette.primary,
        ),
        text(
          "Readiness target: \{readiness_score(model)}%",
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=22.0,
          align=@text.TextAlign::TextStart,
        ),
        @views.slider(
          model.slider_value,
          width=inner,
          foreground=theme.palette.primary,
          on_change=Some(value => SliderChanged(value)),
        ),
        row(
          [
            button(
              "-",
              on_click=Decrement,
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=52.0,
            ),
            button(
              "Reset",
              on_click=Reset,
              variant=@views.ButtonVariant::Tonal,
              theme~,
              width=92.0,
            ),
            button(
              "+",
              on_click=Increment,
              variant=@views.ButtonVariant::Primary,
              theme~,
              width=52.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    padding=16.0,
    theme~,
  )
}

///|
fn live_status_panel(
  model : PlatformShowcaseModel,
  selected : PlatformRuntimeInfo,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[PlatformShowcaseMsg] {
  let inner = width - 32.0
  card(
    column(
      [
        text(
          "Live Status",
          role=@views.TextRole::Subtitle,
          theme~,
          width=inner,
          height=28.0,
          align=@text.TextAlign::TextStart,
        ),
        progress_status(
          "Readiness",
          value=model.slider_value,
          message=readiness_label(model),
          status="\{readiness_score(model)}%",
          tone=readiness_tone(model),
          theme~,
          width=inner,
        ),
        progress_status(
          "Mobile route",
          value=if model.feature_enabled { 0.72 } else { 0.38 },
          message=if model.feature_enabled {
            "Android and iOS scaffolds visible"
          } else {
            "Desktop and web routes only"
          },
          status=if model.feature_enabled { "on" } else { "off" },
          tone=if model.feature_enabled {
            @views.FeedbackTone::Warning
          } else {
            @views.FeedbackTone::Neutral
          },
          theme~,
          width=inner,
        ),
        status_badge(
          "\{selected.name} route",
          tone=selected.badge_tone,
          detail=selected.status,
          theme~,
          width=inner,
        ),
        text(
          "Mode: \{mode_label(model.selected_mode)} | Density: \{density_label(model.selected_density)}",
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=24.0,
          align=@text.TextAlign::TextStart,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    padding=16.0,
    theme~,
  )
}

///|
fn runtime_matrix(
  model : PlatformShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[PlatformShowcaseMsg] {
  let card_width = if compact { width } else { 300.0 }
  column(
    [
      section_header(
        "Runtime Matrix", "Six hosts, one app package", theme, width,
      ),
      responsive_grid(
        platform_runtime_infos().map(info => {
          runtime_route_card(model, info, theme, card_width)
        }),
        width~,
        min_column_width=if compact { width } else { 300.0 },
        row_spacing=theme.spacing_scale.md,
        column_spacing=theme.spacing_scale.md,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn section_header(
  title : String,
  detail : String,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[PlatformShowcaseMsg] {
  column(
    [
      text(
        title,
        role=@views.TextRole::Subtitle,
        theme~,
        width~,
        height=28.0,
        align=@text.TextAlign::TextStart,
      ),
      text(
        detail,
        role=@views.TextRole::Caption,
        theme~,
        width~,
        height=24.0,
        align=@text.TextAlign::TextStart,
      ),
    ],
    spacing=2.0,
    align=@views.CrossAlign::Stretch,
  )
}

///|
fn runtime_route_card(
  model : PlatformShowcaseModel,
  info : PlatformRuntimeInfo,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[PlatformShowcaseMsg] {
  let selected = info.id == model.selected_platform
  let active = info.id == model.active_platform
  let border_color = if selected {
    theme.palette.primary
  } else {
    theme.palette.outline.multiply_alpha(0.5)
  }
  let inner = width - 28.0
  container(
    column(
      [
        row(
          [
            text(
              info.name,
              role=@views.TextRole::Subtitle,
              theme~,
              width=(inner - 104.0).max(130.0),
              height=28.0,
              align=@text.TextAlign::TextStart,
            ),
            spacer(weight=1.0),
            status_badge(
              if active {
                "active"
              } else {
                info.status
              },
              tone=if active {
                @views.BadgeTone::Accent
              } else {
                info.badge_tone
              },
              theme~,
              width=92.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Center,
        ),
        text(
          info.route,
          role=@views.TextRole::Caption,
          theme~,
          width=inner,
          height=22.0,
          align=@text.TextAlign::TextStart,
        ),
        text(
          info.command,
          role=@views.TextRole::Mono,
          theme~,
          width=inner,
          height=34.0,
          align=@text.TextAlign::TextStart,
        ),
        progress_status(
          "Evidence",
          value=info.progress,
          status=info.status,
          tone=info.tone,
          theme~,
          width=inner,
        ),
        button(
          "Select",
          on_click=SelectPlatform(platform_id_to_string(info.id)),
          variant=if selected {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Tonal
          },
          theme~,
          width=112.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height=214.0,
    variant=@views.ContainerVariant::Raised,
    theme~,
    padding=14.0,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(border_color),
      width=if selected { 2.0 } else { 1.0 },
    ),
  )
}

///|
fn platform_runtime_infos() -> Array[PlatformRuntimeInfo] {
  [
    {
      id: PlatformId::MacOS,
      name: "macOS",
      route: "examples/platform_showcase/macos",
      status: "mainline",
      command: "moon run examples/platform_showcase/macos --target native",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 1.0,
    },
    {
      id: PlatformId::Linux,
      name: "Linux",
      route: "examples/platform_showcase/linux",
      status: "mainline",
      command: "moon run examples/platform_showcase/linux --target native",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 0.9,
    },
    {
      id: PlatformId::Windows,
      name: "Windows",
      route: "examples/platform_showcase/windows",
      status: "mainline",
      command: "moon run examples/platform_showcase/windows --target native",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 0.9,
    },
    {
      id: PlatformId::Android,
      name: "Android",
      route: "examples/platform_showcase/android + android_app",
      status: "scaffold",
      command: "scripts/build-platform-showcase-android-apk.sh",
      tone: @views.FeedbackTone::Warning,
      badge_tone: @views.BadgeTone::Warning,
      progress: 0.55,
    },
    {
      id: PlatformId::IOS,
      name: "iOS",
      route: "examples/platform_showcase/ios + ios_app",
      status: "scaffold",
      command: "scripts/build-platform-showcase-ios-app.sh",
      tone: @views.FeedbackTone::Warning,
      badge_tone: @views.BadgeTone::Warning,
      progress: 0.55,
    },
    {
      id: PlatformId::Web,
      name: "Web",
      route: "examples/platform_showcase/web",
      status: "mainline",
      command: "moon build examples/platform_showcase/web --target wasm-gc",
      tone: @views.FeedbackTone::Success,
      badge_tone: @views.BadgeTone::Success,
      progress: 0.9,
    },
  ]
}

///|
fn platform_runtime_info(id : PlatformId) -> PlatformRuntimeInfo {
  for info in platform_runtime_infos() {
    if info.id == id {
      return info
    }
  }
  platform_runtime_infos()[0]
}

///|
fn platform_display_name(id : PlatformId) -> String {
  platform_runtime_info(id).name
}

///|
fn mode_label(id : String) -> String {
  match id {
    "overview" => "Overview"
    "workflow" => "Workflow"
    "runtime" => "Runtime"
    _ => "Overview"
  }
}

///|
fn density_label(id : String) -> String {
  match id {
    "compact" => "Compact"
    "regular" => "Regular"
    "comfortable" => "Comfortable"
    _ => "Regular"
  }
}

///|
fn readiness_score(model : PlatformShowcaseModel) -> Int {
  (model.slider_value * 100.0).round().to_int()
}

///|
fn readiness_label(model : PlatformShowcaseModel) -> String {
  if model.slider_value >= 0.82 {
    "release candidate"
  } else if model.slider_value >= 0.55 {
    "active review"
  } else {
    "needs evidence"
  }
}

///|
fn readiness_tone(model : PlatformShowcaseModel) -> @views.FeedbackTone {
  if model.slider_value >= 0.82 {
    @views.FeedbackTone::Success
  } else if model.slider_value >= 0.55 {
    @views.FeedbackTone::Info
  } else {
    @views.FeedbackTone::Warning
  }
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  value.max(min).min(max)
}

///|
fn responsive_page_width(
  platform : PlatformId,
  viewport_width : Double,
) -> Double {
  match platform {
    PlatformId::Android | PlatformId::IOS => viewport_width.max(320.0)
    _ => clamp_double(viewport_width, 360.0, 1040.0)
  }
}
