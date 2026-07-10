///|
fn Model::website_overlay_hosts(
  self : Model,
  shell : @moui.View[Msg],
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let mobile_menu = self.mobile_menu_sheet(theme, metrics)
  let with_mobile_menu = @views.sheet_host(
    child=shell,
    sheet=Some(mobile_menu),
    presented=self.mobile_menu_open,
    presentation_mode=@views.SheetPresentationMode::BottomSheet,
    theme~,
    on_dismiss=Some(CloseMobileMenu),
  )
  let docs_sheet = self.docs_drawer_sheet(theme, metrics)
  @views.sheet_host(
    child=with_mobile_menu,
    sheet=Some(docs_sheet),
    presented=self.docs_drawer_open,
    presentation_mode=@views.SheetPresentationMode::BottomSheet,
    theme~,
    on_dismiss=Some(CloseDocsDrawer),
  )
}

///|
fn Model::mobile_menu_sheet(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let width = metrics.viewport.width
  let item_width = width - 40.0
  @views.sheet(
    content=container(
      column(
        [
          docs_start_text(
            "Navigate",
            width=item_width,
            height=30.0,
            font=@text.FontSpec::new(size=20.0, weight=780),
            color=theme.palette.foreground,
          )
          .semantics_role(@core.SemanticsRole::Heading)
          .semantics_level(2),
          button(
            "Home",
            on_click=OpenHome,
            variant=@views.ButtonVariant::Ghost,
            theme~,
            width=item_width,
            height=40.0,
          ),
          button(
            "Tour",
            on_click=OpenHomeAnchor("tour"),
            variant=@views.ButtonVariant::Ghost,
            theme~,
            width=item_width,
            height=40.0,
          ),
          button(
            "Quick Start",
            on_click=OpenHomeAnchor("quick-start"),
            variant=@views.ButtonVariant::Ghost,
            theme~,
            width=item_width,
            height=40.0,
          ),
          button(
            "Showcases",
            on_click=OpenShowcases,
            variant=@views.ButtonVariant::Ghost,
            theme~,
            width=item_width,
            height=40.0,
          ),
          button(
            "Docs",
            on_click=OpenDocs,
            variant=@views.ButtonVariant::Ghost,
            theme~,
            width=item_width,
            height=40.0,
          ),
          button(
            "GitHub",
            on_click=OpenRepository,
            variant=@views.ButtonVariant::Ghost,
            theme~,
            width=item_width,
            height=40.0,
          )
          .semantics_role(@core.SemanticsRole::Link)
          .semantics_url(moui_repository_url()),
          button(
            if self.dark {
              "Light theme"
            } else {
              "Dark theme"
            },
            on_click=ToggleDark,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=item_width,
            height=40.0,
          ),
        ],
        spacing=4.0,
        align=@views.CrossAlign::Start,
      ),
      width~,
      height=390.0,
      background=theme.palette.surface,
      corner_radius=8.0,
      theme~,
      padding=20.0,
    ).semantics_role(@core.SemanticsRole::Navigation),
    presentation_mode=@views.SheetPresentationMode::BottomSheet,
    theme~,
    on_dismiss=Some(CloseMobileMenu),
  )
}

///|
fn Model::docs_drawer_sheet(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let width = metrics.viewport.width
  @views.sheet(
    content=container(
      self.docs_sidebar(
        theme,
        width - 24.0,
        min_website_double(580.0, metrics.viewport.height * 0.72),
      ),
      width~,
      height=min_website_double(620.0, metrics.viewport.height * 0.78),
      background=theme.palette.surface,
      corner_radius=8.0,
      theme~,
      padding=12.0,
    ),
    presentation_mode=@views.SheetPresentationMode::BottomSheet,
    theme~,
    on_dismiss=Some(CloseDocsDrawer),
  )
}
