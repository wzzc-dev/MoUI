///|
fn Model::website_overlay_hosts(
  self : Model,
  shell : @moui.View[Msg],
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let mobile_menu = self.mobile_menu_sheet(theme, metrics)
  let with_mobile_menu = @views.overlay_host(shell, [
    @views.PresentationSpec::new(
      id="mobile-menu",
      kind=@views.PresentationKind::Sheet,
      content=mobile_menu,
      modality=@views.PresentationModality::Modal,
      dismiss=@views.PresentationDismissPolicy::new(
        outside_tap=true,
        message=Some(CloseMobileMenu),
      ),
      presented=self.mobile_menu_open,
    ),
  ])
  let docs_sheet = self.docs_drawer_sheet(theme, metrics)
  @views.overlay_host(with_mobile_menu, [
    @views.PresentationSpec::new(
      id="docs-drawer",
      kind=@views.PresentationKind::Sheet,
      content=docs_sheet,
      modality=@views.PresentationModality::Modal,
      dismiss=@views.PresentationDismissPolicy::new(
        outside_tap=true,
        message=Some(CloseDocsDrawer),
      ),
      presented=self.docs_drawer_open,
    ),
  ])
}

///|
fn Model::mobile_menu_sheet(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let width = metrics.viewport.width
  let item_width = width - 40.0
  let message = key => website_message(self.locale, key)
  @views.sheet(
    content=container(
        column(
          [
            docs_start_text(
              message("nav.navigate"),
              width=item_width,
              height=30.0,
              font=@text.FontSpec::new(size=20.0, weight=780),
              color=theme.palette.foreground,
            )
            .semantics_role(@core.SemanticsRole::Heading)
            .semantics_level(2),
            button(
              message("nav.home"),
              on_click=OpenHome,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=item_width,
              height=40.0,
            ),
            button(
              message("nav.tutorial"),
              on_click=OpenTutorial,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=item_width,
              height=40.0,
            ),
            button(
              message("nav.quick_start"),
              on_click=OpenHomeAnchor("quick-start"),
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=item_width,
              height=40.0,
            ),
            button(
              message("nav.showcases"),
              on_click=OpenShowcases,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=item_width,
              height=40.0,
            ),
            button(
              message("nav.docs"),
              on_click=OpenDocs,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=item_width,
              height=40.0,
            ),
            button(
              message("nav.github"),
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
                message("theme.light")
              } else {
                message("theme.dark")
              },
              on_click=ToggleDark,
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=item_width,
              height=40.0,
            ),
            row(
              [
                button(
                  message("site.english"),
                  on_click=SelectLocale("en-US"),
                  variant=@views.ButtonVariant::Ghost,
                  theme~,
                  width=(item_width - 8.0) / 2.0,
                  height=40.0,
                ).accessibility_label(message("site.english")),
                button(
                  message("site.chinese"),
                  on_click=SelectLocale("zh-Hans"),
                  variant=@views.ButtonVariant::Ghost,
                  theme~,
                  width=(item_width - 8.0) / 2.0,
                  height=40.0,
                ).accessibility_label(message("site.chinese")),
              ],
              spacing=8.0,
              align=@views.CrossAlign::Center,
            ),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Start,
        ),
        width~,
        height=434.0,
        background=theme.palette.surface,
        corner_radius=8.0,
        theme~,
        padding=20.0,
      )
      .semantics_role(@core.SemanticsRole::Navigation)
      .accessibility_label(message("site.navigation")),
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
