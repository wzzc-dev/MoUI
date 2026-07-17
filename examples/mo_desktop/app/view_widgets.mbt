///|
fn desktop_widgets(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  width : Double,
  height : Double,
) -> @moui.View[Msg] {
  let calendar = widget_panel(
    @views.column(
      [
        @views.text(
          "July 2026",
          role=@views.TextRole::Title,
          theme~,
          width=222.0,
          height=28.0,
        )
        .font(@text.FontSpec::new(size=18.0, weight=650))
        .foreground(rgba8(255, 69, 58)),
        calendar_row(["S", "M", "T", "W", "T", "F", "S"], palette, theme),
        calendar_row(["12", "13", "14", "15", "16", "17", "18"], palette, theme),
        calendar_row(["19", "20", "21", "22", "23", "24", "25"], palette, theme),
        @views.text(
          "Today  |  Design review at 2:00 PM",
          role=@views.TextRole::Caption,
          theme~,
          width=222.0,
          height=22.0,
        ).foreground(palette.muted),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Start,
    ),
    250.0,
    168.0,
    palette,
  )
  let weather = widget_panel(
    @views.row(
      [
        @views.column(
          [
            @views.text(
              "Cupertino",
              role=@views.TextRole::Label,
              theme~,
              width=116.0,
              height=22.0,
            ).foreground(palette.foreground),
            @views.text(
              "Clear  |  H:83  L:56",
              role=@views.TextRole::Caption,
              theme~,
              width=150.0,
              height=20.0,
            ).foreground(palette.muted),
          ],
          spacing=2.0,
          align=@views.CrossAlign::Start,
        ),
        @views.spacer(min_length=4.0),
        @views.text(
          "68",
          role=@views.TextRole::Display,
          theme~,
          width=54.0,
          height=48.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=34.0, weight=300))
        .foreground(palette.foreground),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Center,
    ),
    250.0,
    78.0,
    palette,
  )
  let tasks = widget_panel(
    @views.column(
      [
        @views.row(
          [
            @views.text(
              "Today",
              role=@views.TextRole::Label,
              theme~,
              width=120.0,
              height=22.0,
            ).foreground(palette.foreground),
            @views.spacer(min_length=4.0),
            @views.badge(
              "\{model.remaining_tasks()} left",
              tone=@views.BadgeTone::Accent,
              theme~,
              width=66.0,
              height=24.0,
            ),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Center,
        ),
        task_preview(
          "Review desktop polish",
          model.first_task_done,
          palette,
          theme,
        ),
        task_preview("Reply to Maya", model.second_task_done, palette, theme),
        task_preview("Plan Tahoe photos", model.third_task_done, palette, theme),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Start,
    ),
    250.0,
    126.0,
    palette,
  )
  @views.column(
    [calendar, weather, tasks],
    spacing=12.0,
    align=@views.CrossAlign::Start,
  )
  .frame(width=250.0, height=(height - 118.0).max(420.0))
  .align(alignment=@geometry.Alignment::top_leading())
  .offset(dx=18.0, dy=48.0)
  .frame(width~, height~)
}

///|
fn calendar_row(
  labels : Array[String],
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.row(
    labels.map(label => {
      @views.text(
        label,
        role=@views.TextRole::Caption,
        theme~,
        width=25.0,
        height=18.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=11.0, weight=520))
      .foreground(if label == "17" { palette.accent } else { palette.muted })
    }),
    spacing=7.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn widget_panel(
  child : @moui.View[Msg],
  width : Double,
  height : Double,
  palette : DesktopPalette,
) -> @moui.View[Msg] {
  @views.container(
    child,
    width~,
    height~,
    background=palette.glass,
    corner_radius=18.0,
    border=Some(desktop_hairline(palette)),
    padding=14.0,
  ).shadow(
    @graphics.ShadowStyle::new(
      color=palette.shadow,
      offset=@geometry.Point::new(x=0.0, y=8.0),
      blur_radius=20.0,
      spread=0.0,
    ),
  )
}

///|
fn task_preview(
  label : String,
  done : Bool,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.text(
    (if done { "Done  " } else { "Open  " }) + label,
    role=@views.TextRole::Caption,
    theme~,
    width=220.0,
    height=18.0,
  ).foreground(if done { palette.muted } else { palette.foreground })
}

///|
fn desktop_files(
  palette : DesktopPalette,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  @views.column(
    [
      desktop_file(
        "Tahoe Trip",
        @views.IconName::FolderOpen,
        OpenFinder,
        palette,
        theme,
      ),
      desktop_file(
        "Welcome.txt",
        @views.IconName::FileNew,
        SelectFinderLocation(Documents),
        palette,
        theme,
      ),
    ],
    spacing=18.0,
    align=@views.CrossAlign::Center,
  )
  .frame(width=112.0, height=220.0)
  .align(alignment=@geometry.Alignment::top_trailing())
  .offset(dx=-20.0, dy=58.0)
  .frame(width~, height=300.0)
}

///|
fn desktop_file(
  label : String,
  icon : @views.IconName,
  message : Msg,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.column(
    [
      @views.container(
        desktop_icon(icon, 28.0, @graphics.Color::white()),
        width=58.0,
        height=52.0,
        background=palette.accent,
        corner_radius=12.0,
        border=Some(desktop_hairline(palette)),
        padding=12.0,
      ),
      @views.text(
        label,
        role=@views.TextRole::Caption,
        theme~,
        width=104.0,
        height=30.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=12.0, weight=560))
      .foreground(@graphics.Color::white()),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Center,
  )
  .on_tap(message)
  .accessibility_label("Open " + label)
}
