///|
fn ShowcaseModel::navigation_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  section_panel(
    theme,
    "Navigation",
    "Navigation stack, sidebar shells, breadcrumbs, wizard steps, dialog host, and sheet host are wired together.",
    column(
      [
        breadcrumb(
          [
            @views.BreadcrumbItem::new(
              id="catalog",
              label="Catalog",
              message=Some(SelectSection("overview")),
            ),
            @views.BreadcrumbItem::new(id="navigation", label="Navigation Shell"),
          ],
          theme~,
        ),
        @views.tab_view(
          self.tab,
          [
            @views.tab_item(
              route="form",
              label="Routes",
              view=text(
                "Current route: " + self.selected_section,
                width=300.0,
                height=28.0,
              ).foreground(theme.palette.foreground),
            ),
            @views.tab_item(
              route="values",
              label="Presentation",
              view=row(
                [
                  button(
                    "Open dialog",
                    on_click=ShowDialog,
                    variant=@views.ButtonVariant::Primary,
                    theme~,
                    width=128.0,
                  ),
                  button(
                    "Open sheet",
                    on_click=ShowSheet,
                    variant=@views.ButtonVariant::Outline,
                    theme~,
                    width=128.0,
                  ),
                ],
                spacing=theme.spacing_scale.sm,
              ),
            ),
          ],
          on_select=route => TabSelected(route),
        ),
        text(
          "Dialog host and sheet host wrap the whole Showcase shell.",
          width=360.0,
          height=28.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        self.navigation_shell_card(theme, metrics),
        self.navigation_wizard_card(theme, metrics),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    metrics~,
  )
}

///|
fn ShowcaseModel::navigation_shell_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  ignore(metrics)
  let items = [
    @views.SidebarItem::new(
      id="overview",
      label="Overview",
      message=SelectSection("overview"),
    ),
    @views.SidebarItem::new(
      id="forms",
      label="Forms",
      message=SelectSection("forms"),
    ),
    @views.SidebarItem::new(
      id="data",
      label="Data",
      message=SelectSection("examples"),
      enabled=false,
    ),
  ]
  master_detail(
    master=sidebar(
      "Navigation Shell",
      items,
      selected=self.selected_section,
      theme~,
      width=190.0,
      height=184.0,
    ),
    detail=surface(
      column(
        [
          text("Master Detail", role=@views.TextRole::Control, theme~, width=220.0, height=28.0),
          text(
            "Current section: " + self.selected_section,
            role=@views.TextRole::Caption,
            theme~,
            width=260.0,
            height=28.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      width=300.0,
      height=184.0,
      variant=@views.SurfaceVariant::Raised,
      theme~,
      padding=theme.spacing_scale.md,
    ),
    master_width=190.0,
    detail_width=300.0,
    height=184.0,
    spacing=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::navigation_wizard_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  ignore(metrics)
  ignore(self)
  wizard(
    [
      @views.WizardStep::new(
        id="profile",
        title="Profile",
        subtitle="Basics",
        content=text("Wizard Step: Profile", width=320.0, height=32.0),
      ),
      @views.WizardStep::new(
        id="permissions",
        title="Permissions",
        subtitle="Access",
        content=text("Wizard Step: Permissions", width=320.0, height=32.0),
      ),
      @views.WizardStep::new(
        id="review",
        title="Review",
        subtitle="Confirm",
        content=text("Wizard Step: Review", width=320.0, height=32.0),
        enabled=false,
      ),
    ],
    current="profile",
    on_select=route => TabSelected(route),
    theme~,
    width=520.0,
    height=154.0,
  )
}

///|
