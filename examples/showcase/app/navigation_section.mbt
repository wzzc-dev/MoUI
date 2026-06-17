///|
fn ShowcaseModel::navigation_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  let route_focus_store = @views.RouteFocusStore::new()
  route_focus_store.remember(
    route="overview",
    focus_key="sidebar-item-overview",
  )
  route_focus_store.remember(
    route="navigation",
    focus_key="section-nav-button-navigation",
  )
  route_focus_store.remember(
    route="forms",
    focus_key="section-nav-button-forms",
  )
  route_focus_store.remember(route="data", focus_key="section-nav-button-data")
  let restore_key = route_focus_store
    .focus_key(self.selected_section)
    .unwrap_or("section-nav-button-overview")
  self.section_panel(
    theme,
    "Navigation",
    "Navigation stack, sidebar shells, breadcrumbs, wizard steps, dialog host, and sheet host are wired together.",
    column(
      [
        route_header(
          "Navigation Shell",
          subtitle="Current route: " + self.selected_section,
          actions=[
            @views.MenuItem::new(
              id="dialog",
              label="Dialog",
              message=ShowDialog,
            ),
            @views.MenuItem::new(id="sheet", label="Sheet", message=ShowSheet),
          ],
          theme~,
          width=520.0,
        ),
        breadcrumb(
          [
            @views.BreadcrumbItem::new(
              id="catalog",
              label="Catalog",
              message=Some(SelectSection("overview")),
            ),
            @views.BreadcrumbItem::new(
              id="navigation",
              label="Navigation Shell",
            ),
          ],
          theme~,
        ),
        surface(
          column(
            [
              text(
                "Route focus restore: " + restore_key,
                role=@views.TextRole::Caption,
                theme~,
                width=500.0,
                height=22.0,
              ),
              text(
                "Restore call: runtime.focus_key(\"" + restore_key + "\")",
                role=@views.TextRole::Caption,
                theme~,
                width=500.0,
                height=22.0,
              ),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          width=520.0,
          height=54.0,
          variant=@views.SurfaceVariant::Base,
          theme~,
          padding=theme.spacing_scale.xs,
        ),
        self.navigation_history_card(theme),
        self.navigation_transition_card(theme),
        section_nav(
          "Section Nav",
          [
            @views.SectionNavItem::new(
              id="navigation",
              label="Navigation",
              summary="Shell routes",
              message=SelectSection("navigation"),
            ),
            @views.SectionNavItem::new(
              id="forms",
              label="Forms",
              summary="Validation",
              message=SelectSection("forms"),
            ),
            @views.SectionNavItem::new(
              id="data",
              label="Data",
              summary="Tables",
              message=SelectSection("data"),
            ),
            @views.SectionNavItem::new(
              id="native-menu",
              label="Native menu",
              summary="Host gap",
              message=ToggleActive,
              enabled=false,
            ),
          ],
          selected=self.selected_section,
          theme~,
          width=520.0,
          item_width=120.0,
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
        self.navigation_command_card(theme, metrics),
        self.navigation_palette_card(theme, metrics),
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
fn ShowcaseModel::navigation_history_card(
  self : ShowcaseModel,
  theme : @core.Theme,
) -> @core.View[ShowcaseMsg] {
  surface(
    column(
      [
        row(
          [
            button(
              "Back",
              on_click=RouteBack,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=88.0,
              height=34.0,
            ).disabled(disabled=!self.route_history.can_go_back()),
            button(
              "Forward",
              on_click=RouteForward,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=96.0,
              height=34.0,
            ).disabled(disabled=!self.route_history.can_go_forward()),
            button(
              "Open link",
              on_click=OpenRouteLink("navigation?panel=history"),
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=116.0,
              height=34.0,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
        text(
          "Deep link: " + self.route_history.current_route(),
          role=@views.TextRole::Caption,
          theme~,
          width=500.0,
          height=22.0,
        ),
        text(
          "History: " + showcase_route_history_label(self.route_history),
          role=@views.TextRole::Caption,
          theme~,
          width=500.0,
          height=22.0,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Start,
    ),
    width=520.0,
    height=104.0,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn ShowcaseModel::navigation_transition_card(
  self : ShowcaseModel,
  theme : @core.Theme,
) -> @core.View[ShowcaseMsg] {
  let transition = @core.TransitionSpec::new(
    from=@core.TransitionStyle::identity()
      .with_opacity(0.72)
      .with_offset(dx=-18.0, dy=0.0),
    to=@core.TransitionStyle::identity()
      .with_opacity(1.0)
      .with_offset(dx=0.0, dy=0.0),
    duration_ms=180.0,
    easing=@core.Easing::EaseOut,
  )
  let progress = clamp_double(self.slider_value, 0.0, 1.0)
  surface(
    column(
      [
        text(
          "Route transition: fade + slide",
          role=@views.TextRole::Control,
          theme~,
          width=500.0,
          height=24.0,
        ),
        text(
          "Transition route: " + self.route_history.current_route(),
          role=@views.TextRole::Caption,
          theme~,
          width=500.0,
          height=22.0,
        ),
        text(
          "Transition state: host route subscription mirrors browser history",
          role=@views.TextRole::Caption,
          theme~,
          width=500.0,
          height=22.0,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Start,
    ),
    width=520.0,
    height=88.0,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.sm,
  ).transition(spec=transition, progress~)
}

///|
fn showcase_route_history_label(history : @views.RouteHistoryState) -> String {
  let routes : Array[String] = []
  for entry in history.entries {
    routes.push(entry.route)
  }
  routes.join(" -> ")
}

///|
fn ShowcaseModel::navigation_command_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  ignore(metrics)
  let commands = [
    @views.MenuItem::new(id="new", label="New", message=ShowDialog),
    @views.MenuItem::new(id="open", label="Open", message=ShowSheet),
    @views.MenuItem::new(
      id="archive",
      label="Archive",
      message=ToggleActive,
      enabled=false,
    ),
  ]
  let mode_items = [
    @views.MenuItem::new(
      id="overview",
      label="Overview",
      message=SelectSection("overview"),
    ),
    @views.MenuItem::new(id="data", label="Data", message=SelectSection("data")),
  ]
  let command_sections = [
    @views.CommandMenuSection::new(title="File", commands=[
      @core.ActionCommand::new(intent=@core.CommandIntent::Submit, label="Save"),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Cancel,
        label="Archive",
        enabled=false,
      ),
    ]),
  ]
  surface(
    column(
      [
        toolbar(
          [
            menu_bar(
              mode_items,
              active=self.selected_section,
              theme~,
              width=220.0,
            ),
            command_bar(commands, theme~, width=260.0),
          ],
          theme~,
          width=520.0,
        ),
        context_menu_region(
          child=text("Context menu fallback", width=240.0, height=28.0).foreground(
            theme.palette.foreground,
          ),
          menu=command_menu(
            command_sections,
            on_select=_intent => ToggleActive,
            theme~,
            width=260.0,
            max_height=120.0,
          ),
          visible=self.active,
          theme~,
        ),
        status_bar(
          ["Ready", "3 commands", "Renderer neutral"],
          theme~,
          width=520.0,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Start,
    ),
    width=520.0,
    height=156.0,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=0.0,
  )
}

///|
fn ShowcaseModel::navigation_palette_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  ignore(self)
  ignore(metrics)
  let commands = [
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Submit,
      label="Save Showcase",
      shortcut=Some(
        @core.KeyboardShortcut::new(
          key="s",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
      group="File",
      description="Persist local showcase state.",
    ),
    @core.ActionCommand::new(
      intent=@core.CommandIntent::OpenContextMenu,
      label="Open Context Menu",
      shortcut=Some(
        @core.KeyboardShortcut::new(
          key="k",
          modifiers=@core.KeyModifiers::new(meta=true),
        ),
      ),
      group="View",
      description="Show command choices near the current region.",
    ),
    @core.ActionCommand::new(
      intent=@core.CommandIntent::Cancel,
      label="Close Overlay",
      enabled=false,
      group="Window",
      description="Disabled rows stay visible but inert.",
    ),
  ]
  command_palette(
    commands,
    query="",
    on_select=_intent => ToggleActive,
    theme~,
    width=520.0,
    max_height=190.0,
  )
}

///|
fn ShowcaseModel::navigation_shell_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  let min_master_width = 150.0
  let max_master_width = 260.0
  let master_range = max_master_width - min_master_width
  let master_width = clamp_double(
    min_master_width + self.slider_value * master_range,
    min_master_width,
    max_master_width,
  )
  let shell_width = min_showcase_double(metrics.body_width, 520.0)
  let detail_width = max_showcase_double(
    220.0,
    shell_width - master_width - 8.0 - theme.spacing_scale.md * 2.0,
  )
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
  resizable_split_view(
    primary=sidebar(
      "Navigation Shell",
      items,
      selected=self.selected_section,
      theme~,
      width=master_width,
      height=184.0,
    ),
    detail=surface(
      column(
        [
          text(
            "Master Detail",
            role=@views.TextRole::Control,
            theme~,
            width=220.0,
            height=28.0,
          ),
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
    primary_width=master_width,
    detail_width~,
    height=184.0,
    min_primary_width=min_master_width,
    max_primary_width=max_master_width,
    spacing=theme.spacing_scale.md,
    theme~,
    on_drag=width => SliderChanged((width - min_master_width) / master_range),
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
