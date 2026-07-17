///|
priv struct LauncherEntry {
  label : String
  detail : String
  icon : @views.IconName
  color : @graphics.Color
  message : Msg
}

///|
fn app_launcher(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let compact = viewport_width < 620.0
  let width = if compact {
    (viewport_width - 20.0).max(272.0)
  } else {
    (viewport_width - 120.0).min(760.0)
  }
  let height = if compact {
    (viewport_height - 112.0).max(360.0)
  } else {
    (viewport_height - 170.0).min(500.0).max(410.0)
  }
  let inner_width = width - 32.0
  let entries = launcher_entries(model).filter(entry => {
    model.launcher_query == "" ||
    entry.label.contains(model.launcher_query) ||
    entry.detail.contains(model.launcher_query)
  })
  let results = if entries.is_empty() {
    @views.column(
      [
        @views.text(
          "No apps or actions found",
          role=@views.TextRole::Title,
          theme~,
          width=inner_width,
          height=34.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.foreground),
        @views.button(
          "Clear Search",
          on_click=LauncherQueryChanged(""),
          variant=@views.ButtonVariant::Tonal,
          theme~,
          width=126.0,
          height=38.0,
        ),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Center,
    )
  } else {
    @views.responsive_grid(
      entries.map(entry => {
        launcher_tile(
          entry,
          if compact {
            112.0
          } else {
            142.0
          },
          palette,
          theme,
        )
      }),
      width=inner_width,
      min_column_width=if compact { 112.0 } else { 142.0 },
      row_spacing=16.0,
      column_spacing=16.0,
    )
  }
  let panel = glass_panel(
    @views.column(
      [
        overlay_header("Apps", DismissOverlay, inner_width, palette, theme),
        @views.text_field(
          model.launcher_query,
          on_input=value => LauncherQueryChanged(value),
          placeholder="Search apps and actions",
          theme~,
          width=inner_width,
          height=40.0,
        ),
        @views.segmented_control(
          [
            @views.choice_item("apps", "Apps"),
            @views.choice_item("actions", "Actions"),
          ],
          selected=model.launcher_tab,
          on_select=value => LauncherTabSelected(value),
          theme~,
          width=inner_width,
        ),
        results,
      ],
      spacing=14.0,
      align=@views.CrossAlign::Stretch,
    ),
    width,
    height,
    palette,
    radius=20.0,
    padding=16.0,
  )
  @views.stack([
    color_layer(viewport_width, viewport_height, palette.scrim).on_tap(
      DismissOverlay,
    ),
    panel
    .align(alignment=@geometry.Alignment::center())
    .offset(dy=-8.0)
    .frame(width=viewport_width, height=viewport_height),
  ])
}

///|
fn launcher_entries(model : DesktopModel) -> Array[LauncherEntry] {
  if model.launcher_tab == "actions" {
    [
      {
        label: if model.dark_mode {
          "Light Mode"
        } else {
          "Dark Mode"
        },
        detail: "Appearance",
        icon: @views.IconName::Eye,
        color: rgba8(104, 87, 214),
        message: ToggleDarkMode,
      },
      {
        label: "Lock Screen",
        detail: "Secure this session",
        icon: @views.IconName::Focus,
        color: rgba8(45, 166, 153),
        message: LockDesktop,
      },
      {
        label: "Close Window",
        detail: "Return to desktop",
        icon: @views.IconName::Close,
        color: rgba8(238, 82, 83),
        message: CloseWindow,
      },
      {
        label: "Mark Read",
        detail: "Clear inbox badge",
        icon: @views.IconName::Check,
        color: rgba8(244, 137, 53),
        message: MarkNotificationsRead,
      },
    ]
  } else {
    [
      {
        label: "Finder",
        detail: "Browse local files",
        icon: @views.IconName::FolderOpen,
        color: rgba8(33, 150, 243),
        message: OpenFinder,
      },
      {
        label: "Safari",
        detail: "Search the Web",
        icon: @views.IconName::Link,
        color: rgba8(36, 177, 216),
        message: OpenSafari,
      },
      {
        label: "Control Center",
        detail: "Display and sound",
        icon: @views.IconName::Settings,
        color: rgba8(91, 99, 112),
        message: ToggleControlCenter,
      },
      {
        label: "Notifications",
        detail: "Messages and tasks",
        icon: @views.IconName::Info,
        color: rgba8(236, 72, 118),
        message: ToggleNotificationCenter,
      },
    ]
  }
}

///|
fn launcher_tile(
  entry : LauncherEntry,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.column(
      [
        @views.container(
          desktop_icon(entry.icon, 30.0, @graphics.Color::white()),
          width=64.0,
          height=64.0,
          background=entry.color,
          corner_radius=15.0,
          border=Some(desktop_hairline(palette)),
          padding=16.0,
        ),
        @views.text(
          entry.label,
          role=@views.TextRole::Label,
          theme~,
          width=width - 12.0,
          height=24.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.foreground),
        @views.text(
          entry.detail,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 12.0,
          height=20.0,
          align=@text.TextAlign::TextCenter,
        ).foreground(palette.muted),
      ],
      spacing=5.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=132.0,
    background=palette.glass_strong,
    corner_radius=14.0,
    border=Some(desktop_hairline(palette)),
    padding=10.0,
  )
  .on_tap(entry.message)
  .accessibility_label(entry.label)
}

///|
fn control_center(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let compact = viewport_width < 520.0
  let width = if compact { (viewport_width - 20.0).max(272.0) } else { 390.0 }
  let height = (viewport_height - 70.0).min(548.0).max(480.0)
  let inner_width = width - 28.0
  let connectivity = if compact {
    @views.column(
      [
        connectivity_toggle(
          "Wi-Fi",
          "HomeNet-5G",
          model.wifi_enabled,
          value => WifiChanged(value),
          inner_width,
          palette,
          theme,
        ),
        connectivity_toggle(
          "Bluetooth",
          "On",
          model.bluetooth_enabled,
          value => BluetoothChanged(value),
          inner_width,
          palette,
          theme,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Stretch,
    )
  } else {
    @views.row(
      [
        connectivity_toggle(
          "Wi-Fi",
          "HomeNet-5G",
          model.wifi_enabled,
          value => WifiChanged(value),
          (inner_width - 8.0) / 2.0,
          palette,
          theme,
        ),
        connectivity_toggle(
          "Bluetooth",
          "On",
          model.bluetooth_enabled,
          value => BluetoothChanged(value),
          (inner_width - 8.0) / 2.0,
          palette,
          theme,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Stretch,
    )
  }
  let panel = glass_panel(
    @views.column(
      [
        overlay_header(
          "Control Center",
          DismissOverlay,
          inner_width,
          palette,
          theme,
        ),
        connectivity,
        control_slider_section(
          "Display",
          model.brightness,
          value => BrightnessChanged(value),
          inner_width,
          palette,
          theme,
        ),
        @views.button(
          if model.dark_mode {
            "Use Light Mode"
          } else {
            "Use Dark Mode"
          },
          on_click=ToggleDarkMode,
          variant=@views.ButtonVariant::Tonal,
          theme~,
          width=inner_width,
          height=38.0,
        ),
        control_slider_section(
          "Sound",
          model.volume,
          value => VolumeChanged(value),
          inner_width,
          palette,
          theme,
        ),
        solid_panel(
          @views.row(
            [
              @views.column(
                [
                  @views.text(
                    "86% Battery",
                    role=@views.TextRole::Label,
                    theme~,
                    width=(inner_width - 132.0).max(110.0),
                    height=22.0,
                  ).foreground(palette.foreground),
                  @views.text(
                    "MacBook Pro",
                    role=@views.TextRole::Caption,
                    theme~,
                    width=(inner_width - 132.0).max(110.0),
                    height=18.0,
                  ).foreground(palette.muted),
                ],
                spacing=1.0,
                align=@views.CrossAlign::Start,
              ),
              @views.spacer(min_length=8.0),
              @views.toggle(
                "Low Power",
                model.low_power_mode,
                on_change=value => LowPowerModeChanged(value),
                theme~,
              ),
            ],
            spacing=8.0,
            align=@views.CrossAlign::Center,
          ),
          inner_width,
          70.0,
          palette,
          radius=14.0,
          padding=12.0,
        ),
        @views.button(
          "Lock Screen",
          on_click=LockDesktop,
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=inner_width,
          height=38.0,
        ),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Stretch,
    ),
    width,
    height,
    palette,
    radius=20.0,
    padding=14.0,
  )
  let aligned = if compact {
    panel
    .align(alignment=@geometry.Alignment::top_leading())
    .offset(dx=10.0, dy=42.0)
  } else {
    panel
    .align(alignment=@geometry.Alignment::top_trailing())
    .offset(dx=-12.0, dy=42.0)
  }
  @views.stack([
    color_layer(viewport_width, viewport_height, rgba8(0, 0, 0, a=0.02)).on_tap(
      DismissOverlay,
    ),
    aligned.frame(width=viewport_width, height=viewport_height),
  ])
}

///|
fn connectivity_toggle(
  label : String,
  detail : String,
  enabled : Bool,
  on_change : (Bool) -> Msg,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  solid_panel(
    @views.column(
      [
        @views.toggle(label, enabled, on_change~, theme~),
        @views.text(
          if enabled {
            detail
          } else {
            "Off"
          },
          role=@views.TextRole::Caption,
          theme~,
          width=width - 24.0,
          height=18.0,
        ).foreground(palette.muted),
      ],
      spacing=2.0,
      align=@views.CrossAlign::Start,
    ),
    width,
    70.0,
    palette,
    radius=14.0,
    padding=10.0,
  )
}

///|
fn control_slider_section(
  label : String,
  value : Double,
  on_change : (Double) -> Msg,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  solid_panel(
    @views.column(
      [
        @views.row(
          [
            @views.text(
              label,
              role=@views.TextRole::Label,
              theme~,
              width=width - 92.0,
              height=22.0,
            ).foreground(palette.foreground),
            @views.text(
              "\{(value * 100.0).to_int()}%",
              role=@views.TextRole::Caption,
              theme~,
              width=48.0,
              height=22.0,
              align=@text.TextAlign::TextEnd,
            ).foreground(palette.muted),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Center,
        ),
        @views.slider(
          value,
          min=0.0,
          max=1.0,
          width=width - 24.0,
          theme~,
          foreground=palette.accent,
          on_change=Some(on_change),
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Stretch,
    ),
    width,
    78.0,
    palette,
    radius=14.0,
    padding=10.0,
  )
}

///|
fn notification_center(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  let compact = viewport_width < 520.0
  let width = if compact { (viewport_width - 20.0).max(272.0) } else { 380.0 }
  let height = (viewport_height - 72.0).min(520.0).max(440.0)
  let inner_width = width - 28.0
  let panel = glass_panel(
    @views.column(
      [
        @views.row(
          [
            @views.text(
              "Notifications",
              role=@views.TextRole::Title,
              theme~,
              width=(inner_width - 154.0).max(120.0),
              height=30.0,
            )
            .font(@text.FontSpec::new(size=18.0, weight=650))
            .foreground(palette.foreground),
            @views.spacer(min_length=6.0),
            @views.button(
              if model.notifications_read {
                "Read"
              } else {
                "Mark Read"
              },
              on_click=MarkNotificationsRead,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=92.0,
              height=32.0,
            ),
            @views.button(
              "x",
              on_click=DismissOverlay,
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=32.0,
              height=32.0,
            ).accessibility_label("Close Notification Center"),
          ],
          spacing=5.0,
          align=@views.CrossAlign::Center,
        ),
        notification_card(
          "Design Review",
          "Maya left feedback on the desktop polish pass.",
          "8m",
          !model.notifications_read,
          inner_width,
          palette,
          theme,
        ),
        notification_card(
          "Calendar",
          "Sprint planning starts tomorrow at 9:30 AM.",
          "1h",
          !model.notifications_read,
          inner_width,
          palette,
          theme,
        ),
        @views.row(
          [
            @views.text(
              "Today",
              role=@views.TextRole::Label,
              theme~,
              width=120.0,
              height=24.0,
            ).foreground(palette.foreground),
            @views.spacer(min_length=8.0),
            @views.badge(
              "\{model.remaining_tasks()} remaining",
              tone=@views.BadgeTone::Accent,
              theme~,
              width=92.0,
              height=24.0,
            ),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Center,
        ),
        notification_task(
          "Review desktop polish",
          model.first_task_done,
          0,
          inner_width,
          palette,
          theme,
        ),
        notification_task(
          "Reply to Maya",
          model.second_task_done,
          1,
          inner_width,
          palette,
          theme,
        ),
        notification_task(
          "Plan Tahoe photos",
          model.third_task_done,
          2,
          inner_width,
          palette,
          theme,
        ),
      ],
      spacing=9.0,
      align=@views.CrossAlign::Stretch,
    ),
    width,
    height,
    palette,
    radius=20.0,
    padding=14.0,
  )
  let aligned = if compact {
    panel
    .align(alignment=@geometry.Alignment::top_leading())
    .offset(dx=10.0, dy=42.0)
  } else {
    panel
    .align(alignment=@geometry.Alignment::top_trailing())
    .offset(dx=-12.0, dy=42.0)
  }
  @views.stack([
    color_layer(viewport_width, viewport_height, rgba8(0, 0, 0, a=0.02)).on_tap(
      DismissOverlay,
    ),
    aligned.frame(width=viewport_width, height=viewport_height),
  ])
}

///|
fn overlay_header(
  title : String,
  close_message : Msg,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.row(
    [
      @views.text(
        title,
        role=@views.TextRole::Title,
        theme~,
        width=(width - 50.0).max(120.0),
        height=30.0,
      )
      .font(@text.FontSpec::new(size=18.0, weight=650))
      .foreground(palette.foreground),
      @views.spacer(min_length=6.0),
      @views.button(
        "x",
        on_click=close_message,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=32.0,
        height=32.0,
      ).accessibility_label("Close " + title),
    ],
    spacing=6.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn notification_card(
  title : String,
  detail : String,
  time : String,
  unread : Bool,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  solid_panel(
    @views.row(
      [
        @views.container(
          desktop_icon(@views.IconName::Info, 18.0, @graphics.Color::white()),
          width=38.0,
          height=38.0,
          background=if unread { palette.accent } else { palette.muted },
          corner_radius=10.0,
          padding=10.0,
        ),
        @views.column(
          [
            @views.text(
              title,
              role=@views.TextRole::Label,
              theme~,
              width=(width - 102.0).max(120.0),
              height=22.0,
            ).foreground(palette.foreground),
            @views.text(
              detail,
              role=@views.TextRole::Caption,
              theme~,
              width=(width - 102.0).max(120.0),
              height=36.0,
            ).foreground(palette.muted),
          ],
          spacing=1.0,
          align=@views.CrossAlign::Start,
        ),
        @views.spacer(min_length=4.0),
        @views.text(
          time,
          role=@views.TextRole::Caption,
          theme~,
          width=28.0,
          height=20.0,
          align=@text.TextAlign::TextEnd,
        ).foreground(palette.muted),
      ],
      spacing=9.0,
      align=@views.CrossAlign::Start,
    ),
    width,
    76.0,
    palette,
    background=if unread { palette.glass_strong } else { palette.sidebar },
    radius=14.0,
    padding=10.0,
  )
}

///|
fn notification_task(
  label : String,
  done : Bool,
  index : Int,
  width : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  solid_panel(
    @views.row(
      [
        @views.text(
          label,
          role=@views.TextRole::Body,
          theme~,
          width=(width - 100.0).max(130.0),
          height=28.0,
        ).foreground(if done { palette.muted } else { palette.foreground }),
        @views.spacer(min_length=6.0),
        if done {
          @views.badge(
            "Done",
            tone=@views.BadgeTone::Success,
            theme~,
            width=58.0,
            height=26.0,
          )
        } else {
          @views.button(
            "Done",
            on_click=CompleteTask(index),
            variant=@views.ButtonVariant::Tonal,
            theme~,
            width=68.0,
            height=30.0,
          )
        },
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    width,
    44.0,
    palette,
    radius=10.0,
    padding=7.0,
  )
}
