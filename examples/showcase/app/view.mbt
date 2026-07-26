///|
using @views {
  button,
  column,
  container,
  row,
  scroll_view,
  spacer,
  split_view,
  text,
  text_field,
}

///|
let shell_compact_breakpoint : Double = 820.0

///|
let shell_sidebar_width : Double = 280.0

///|
/// Title row + Back/Forward controls. Keep a hard budget so body height is not
/// over-claimed (under-budget top bars clip the bottom of both rails).
let shell_top_budget : Double = 52.0

///|
/// Bottom inset inside scroll content so the last item is not flush/clipped.
let shell_scroll_end_inset : Double = 28.0

///|
/// `scroll_view(shows_indicator=true)` paints a 3px thumb near the right edge
/// as an overlay. Reserve a content gutter so rows/controls are not covered.
let shell_scroll_indicator_gutter : Double = 12.0

///|
pub fn ShowcaseModel::view(
  self : ShowcaseModel,
  env : @moui.ViewEnvironment,
) -> @moui.View[ShowcaseMsg] {
  let theme = @views.light_theme()
  let size = env.viewport_size()
  let width = size.width.max(320.0)
  let height = size.height.max(320.0)
  let compact = width < shell_compact_breakpoint
  container(
    if compact {
      mobile_shell(self, theme, width, height, env)
    } else {
      desktop_shell(self, theme, width, height, env)
    },
    width~,
    height~,
    variant=@views.ContainerVariant::Base,
    background=theme.palette.background,
    theme~,
  )
}

///|
/// Available height for the split body after outer padding, top bar, and column gap.
fn shell_body_height(total_height : Double, theme : @moui.Theme) -> Double {
  let pad = theme.spacing_scale.md
  // pad top + pad bottom + gap under top bar + top bar budget
  (total_height - pad * 2.0 - theme.spacing_scale.md - shell_top_budget).max(
    240.0,
  )
}

///|
/// Classic Showcase / Story layout: left category rail + detail canvas.
fn desktop_shell(
  model : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
  env : @moui.ViewEnvironment,
) -> @moui.View[ShowcaseMsg] {
  let pad = theme.spacing_scale.md
  let body_height = shell_body_height(height, theme)
  let detail_width = (width - shell_sidebar_width - pad * 3.0).max(360.0)
  column(
    [
      shell_top_bar(model, theme, (width - pad * 2.0).max(280.0), compact=false),
      split_view(
        primary=shell_sidebar(model, theme, shell_sidebar_width, body_height),
        detail=shell_detail(model, theme, detail_width, body_height, env),
        primary_width=shell_sidebar_width,
        detail_width~,
        height=body_height,
        spacing=pad,
      ),
    ],
    spacing=pad,
    align=@views.CrossAlign::Stretch,
  )
  .padding(pad)
  .frame(width~, height~)
}

///|
fn mobile_shell(
  model : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
  env : @moui.ViewEnvironment,
) -> @moui.View[ShowcaseMsg] {
  let pad = theme.spacing_scale.md
  let inner = (width - pad * 2.0).max(280.0)
  let body_height = shell_body_height(height, theme)
  column(
    [
      shell_top_bar(model, theme, inner, compact=true),
      if model.mobile_showing_detail {
        mobile_detail(model, theme, inner, body_height, env)
      } else {
        mobile_catalog_list(model, theme, inner, body_height)
      },
    ],
    spacing=pad,
    align=@views.CrossAlign::Stretch,
  )
  .padding(pad)
  .frame(width~, height~)
}

///|
fn shell_top_bar(
  model : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  compact~ : Bool,
) -> @moui.View[ShowcaseMsg] {
  row(
    [
      text("MoUI Showcase", role=@views.TextRole::Title, theme~),
      @views.spacer(weight=1.0),
      if !compact {
        text(
          model.current_route_string(),
          role=@views.TextRole::Caption,
          theme~,
        )
      } else {
        @views.spacer(min_length=0.0)
      },
      button(
        "Back",
        on_click=RouteBack,
        variant=@views.ButtonVariant::Ghost,
        theme~,
      ),
      if !compact {
        button(
          "Forward",
          on_click=RouteForward,
          variant=@views.ButtonVariant::Ghost,
          theme~,
        )
      } else {
        @views.spacer(min_length=0.0)
      },
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  ).frame(width~)
}

///|
/// Shared group→item story list used by both the desktop sidebar and the
/// mobile catalog. Visual differences (selected variant, group title role,
/// whether rows carry a `.key`) are parameters; the loop body is written once.
fn catalog_list_rows(
  model : ShowcaseModel,
  theme : @moui.Theme,
  list_width : Double,
  row_height : Double,
  selected_variant~ : @views.ButtonVariant,
  unselected_variant~ : @views.ButtonVariant,
  group_role~ : @views.TextRole,
  key_rows~ : Bool,
) -> Array[@moui.View[ShowcaseMsg]] {
  let items = model.filtered_catalog_items()
  let groups = model.catalog_groups()
  let selected = match model.current_catalog_item() {
    Some(item) => item.route()
    None => model.current_route_string()
  }
  let rows : Array[@moui.View[ShowcaseMsg]] = []
  for group in groups {
    let group_items = items.filter(item => item.group_id == group.id)
    if group_items.length() == 0 {
      continue
    }
    rows.push(
      text(group.title, role=group_role, theme~, width=list_width),
    )
    for item in group_items {
      let is_selected = item.route() == selected
      let btn = button(
        item.title,
        on_click=Navigate(item.route()),
        variant=if is_selected {
          selected_variant
        } else {
          unselected_variant
        },
        theme~,
        width=list_width,
        height=row_height,
      )
      let btn = btn.semantics_selected(selected=is_selected)
      rows.push(if key_rows {
        btn.key("story-" + item.route())
      } else {
        btn
      })
    }
  }
  if items.length() == 0 {
    rows.push(
      text(
        "No matching stories",
        role=@views.TextRole::Caption,
        theme~,
        width=list_width,
      ),
    )
  }
  // Trailing inset so the last story is not clipped by the scroll clip edge.
  rows.push(spacer(min_length=shell_scroll_end_inset))
  rows
}

///|
fn shell_sidebar(
  model : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[ShowcaseMsg] {
  let rail_width = (width - 8.0).max(160.0)
  // List rows leave a right gutter so the overlay scroll thumb does not cover
  // labels/buttons; the scroll_view itself keeps full rail width for the track.
  let list_width = (rail_width - shell_scroll_indicator_gutter).max(140.0)
  // Search stays fixed above the scrollable story list (left rail).
  // Do NOT use @views.sidebar per group: it defaults height=320 and leaves
  // large empty gaps under short sections like Start.
  let list_rows = catalog_list_rows(
    model,
    theme,
    list_width,
    34.0,
    selected_variant=@views.ButtonVariant::Primary,
    unselected_variant=@views.ButtonVariant::Ghost,
    group_role=@views.TextRole::Caption,
    key_rows=true,
  )
  // Stories title (~32) + search field (~40) + two column gaps + safety.
  let header_block = 32.0 + 40.0 + theme.spacing_scale.sm * 2.0 + 12.0
  let list_height = (height - header_block).max(120.0)
  column(
    [
      text(
        "Stories",
        role=@views.TextRole::Subtitle,
        theme~,
        width=rail_width,
        height=28.0,
      ),
      text_field(
        model.nav_query,
        on_input=value => NavQueryChanged(value),
        placeholder="Search stories…",
        theme~,
        width=rail_width,
      ),
      scroll_view(
        column(
          list_rows,
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Start,
        ),
        width=rail_width,
        height=list_height,
        state=Some(model.sidebar_scroll),
        shows_indicator=true,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Stretch,
  ).frame(width~, height~)
}

///|
fn shell_detail(
  model : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
  env : @moui.ViewEnvironment,
) -> @moui.View[ShowcaseMsg] {
  let title = match model.current_catalog_item() {
    Some(item) => item.title
    None => model.route_id
  }
  let summary = match model.current_catalog_item() {
    Some(item) => item.summary
    None => "Story page"
  }
  let badge = match model.current_catalog_item() {
    Some(item) => item.workspace
    None => model.workspace.slug()
  }
  // Content is narrower than the scroll viewport so the overlay indicator sits
  // in empty space instead of covering demo controls.
  let content_width = (width - shell_scroll_indicator_gutter).max(240.0)
  scroll_view(
    column(
      [
        @views.route_header(
          title,
          subtitle=summary + " · " + badge,
          theme~,
          width=content_width,
        ),
        feature_body(model, env, content_width),
        // Keep the last demo controls clear of the clip / window edge.
        spacer(min_length=shell_scroll_end_inset),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    state=Some(model.detail_scroll),
    shows_indicator=true,
  ).frame(width~, height~)
}

///|
fn mobile_catalog_list(
  model : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[ShowcaseMsg] {
  let list_width = (width - shell_scroll_indicator_gutter).max(200.0)
  let list_rows = catalog_list_rows(
    model,
    theme,
    list_width,
    40.0,
    selected_variant=@views.ButtonVariant::Primary,
    unselected_variant=@views.ButtonVariant::Outline,
    group_role=@views.TextRole::Subtitle,
    key_rows=false,
  )
  // Search field + gap + safety (mobile list has no Stories subtitle row).
  let header_block = 40.0 + theme.spacing_scale.sm + 12.0
  let list_height = (height - header_block).max(120.0)
  column(
    [
      text_field(
        model.nav_query,
        on_input=value => NavQueryChanged(value),
        placeholder="Search stories…",
        theme~,
        width~,
      ),
      scroll_view(
        column(
          list_rows,
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Start,
        ),
        width~,
        height=list_height,
        state=Some(model.sidebar_scroll),
        shows_indicator=true,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Stretch,
  ).frame(width~, height~)
}

///|
fn mobile_detail(
  model : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  height : Double,
  env : @moui.ViewEnvironment,
) -> @moui.View[ShowcaseMsg] {
  let title = match model.current_catalog_item() {
    Some(item) => item.title
    None => model.route_id
  }
  let content_width = (width - shell_scroll_indicator_gutter).max(240.0)
  scroll_view(
    column(
      [
        button(
          "All stories",
          on_click=ShowMobileCatalog,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=content_width,
        ),
        @views.route_header(title, theme~, width=content_width),
        feature_body(model, env, content_width),
        spacer(min_length=shell_scroll_end_inset),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height~,
    state=Some(model.detail_scroll),
    shows_indicator=true,
  ).frame(width~, height~)
}

///|
fn feature_body(
  model : ShowcaseModel,
  env : @moui.ViewEnvironment,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  match model.workspace {
    Components =>
      @components.view_body(model.components, env, width~).map(msg => {
        ComponentsMsg(msg)
      })
    Patterns =>
      @patterns.view_body(model.patterns, env, width~).map(msg => {
        PatternsMsg(msg)
      })
    Platform =>
      @platform.view_body(model.platform, width~).map(msg => PlatformMsg(msg))
    Diagnostics =>
      model.diagnostics.view_body(env, width~).map(msg => DiagnosticsMsg(msg))
  }
}
