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
          desktop_month_year(model.clock),
          role=@views.TextRole::Title,
          theme~,
          width=222.0,
          height=28.0,
        )
        .font(@text.FontSpec::new(size=18.0, weight=650))
        .foreground(rgba8(255, 69, 58)),
        calendar_row(["S", "M", "T", "W", "T", "F", "S"], None, palette, theme),
        calendar_month_grid(model.clock, palette, theme),
        @views.text(
          "Today  |  \{desktop_clock_lock_date(model.clock)}",
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
    268.0,
    palette,
  )
  let weather = widget_panel(
    @views.column(
      [
        // Top row: location + a large weather glyph (using the closest
        // available icon — Focus reads as a sun disc) + current temperature.
        @views.row(
          [
            @views.column(
              [
                @views.text(
                  "Cupertino",
                  role=@views.TextRole::Label,
                  theme~,
                  width=96.0,
                  height=22.0,
                ).foreground(palette.foreground),
                @views.text(
                  "Clear  |  H:83  L:56",
                  role=@views.TextRole::Caption,
                  theme~,
                  width=110.0,
                  height=20.0,
                ).foreground(palette.muted),
              ],
              spacing=2.0,
              align=@views.CrossAlign::Start,
            ),
            @views.spacer(min_length=2.0),
            @views.container(
              desktop_icon(@views.IconName::Focus, 24.0, rgba8(255, 180, 40)),
              width=32.0,
              height=32.0,
              padding=4.0,
            ),
            @views.text(
              "68",
              role=@views.TextRole::Display,
              theme~,
              width=42.0,
              height=42.0,
              align=@text.TextAlign::TextCenter,
            )
            .font(@text.FontSpec::new(size=30.0, weight=300))
            .foreground(palette.foreground),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Center,
        ),
        @views.spacer(min_length=4.0),
        // Hourly forecast strip: a glanceable row of the next few hours with
        // a tiny glyph and the expected high, like macOS's weather widget.
        @views.row(
          [
            weather_hour_cell("Now", 68.0, palette, theme),
            weather_hour_cell("1PM", 70.0, palette, theme),
            weather_hour_cell("2PM", 72.0, palette, theme),
            weather_hour_cell("3PM", 71.0, palette, theme),
            weather_hour_cell("4PM", 68.0, palette, theme),
          ],
          spacing=8.0,
          justify=@views.MainAlign::Between,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Stretch,
    ),
    250.0,
    150.0,
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
/// A full month grid: weekday header row + up to 6 numbered rows. The 1st of
/// the month is offset by an inferred first-weekday stub (real macOS would
/// query the host; we derive it from the current weekday/day so the grid is
/// locally consistent). Today is highlighted with the accent capsule.
fn calendar_month_grid(
  clock : DesktopClock,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  // Approximate the weekday of day 1 by walking back from today's weekday.
  // weekday: Sunday=0..Saturday=6. Offset days back to day 1, mod 7.
  let first_weekday = {
    let back = (clock.day - 1) % 7
    (clock.weekday - back + 7) % 7
  }
  let days_in_month = desktop_days_in_month(clock.month, clock.year)
  // Build a flat 42-slot grid: leading blanks for the stub, then 1..N, then
  // trailing blanks so every row is 7 cells.
  let cells : Array[String] = []
  for _index in 0..<first_weekday {
    cells.push("")
  }
  for day in 1..<=days_in_month {
    cells.push(day.to_string())
  }
  while cells.length() % 7 != 0 {
    cells.push("")
  }
  // Slice into rows of 7 and render each.
  let rows : Array[@moui.View[Msg]] = []
  let row_count = cells.length() / 7
  for row_index in 0..<row_count {
    let row_cells : Array[String] = []
    for col in 0..<7 {
      row_cells.push(cells[row_index * 7 + col])
    }
    rows.push(calendar_row(row_cells, Some(clock.day), palette, theme))
  }
  @views.column(rows, spacing=4.0, align=@views.CrossAlign::Start)
}

///|
/// Days in a civil month, accounting for leap years on February.
fn desktop_days_in_month(month : Int, year : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    _ =>
      // February: leap if divisible by 4 and (not by 100, or divisible by 400).
      if (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 {
        29
      } else {
        28
      }
  }
}

///|
fn calendar_row(
  labels : Array[String],
  selected_day : Int?,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.row(
    labels.map(label => {
      let today = match selected_day {
        Some(day) => label == day.to_string()
        None => false
      }
      if today {
        @views.container(
          @views.text(
            label,
            role=@views.TextRole::Caption,
            theme~,
            width=22.0,
            height=16.0,
            align=@text.TextAlign::TextCenter,
          )
          .font(@text.FontSpec::new(size=11.0, weight=650))
          .foreground(@graphics.Color::white()),
          width=24.0,
          height=24.0,
          background=palette.accent,
          corner_radius=12.0,
          padding=4.0,
        )
      } else {
        @views.text(
          label,
          role=@views.TextRole::Caption,
          theme~,
          width=25.0,
          height=18.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=11.0, weight=500))
        .foreground(palette.muted)
      }
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
  // More translucent frosted plates so wallpaper shows through like macOS
  // desktop widgets, with a pale rim instead of a heavy outline. The
  // panel clips so inner text cannot bleed outside the rounded corners
  // when a fixed-width label overflows (Cupertino 68° + hourly strip).
  let glass = palette.glass.multiply_alpha(0.72)
  @views.container(
    child,
    width~,
    height~,
    background=glass,
    corner_radius=20.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(palette.outline.multiply_alpha(0.85)),
        width=1.0,
      ),
    ),
    padding=14.0,
  )
  .clip()
  .shadow(
    @graphics.ShadowStyle::new(
      color=palette.shadow.multiply_alpha(0.55),
      offset=@geometry.Point::new(x=0.0, y=10.0),
      blur_radius=24.0,
      spread=0.0,
    ),
  )
}

///|
/// One hourly forecast cell: tiny hour label, a sun disc glyph, and the
/// expected temperature. Stacked vertically and glanceable like macOS's
/// weather widget hourly strip.
fn weather_hour_cell(
  hour : String,
  temp : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.column(
    [
      @views.text(
        hour,
        role=@views.TextRole::Caption,
        theme~,
        width=36.0,
        height=14.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=10.0, weight=520))
      .foreground(palette.muted),
      @views.container(
        desktop_icon(@views.IconName::Focus, 14.0, rgba8(255, 180, 40)),
        width=18.0,
        height=18.0,
        padding=2.0,
      ),
      @views.text(
        "\{temp.to_int()}\u00B0",
        role=@views.TextRole::Caption,
        theme~,
        width=36.0,
        height=16.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=12.0, weight=600))
      .foreground(palette.foreground),
    ],
    spacing=2.0,
    align=@views.CrossAlign::Center,
  )
}

///|
/// A macOS Reminders-style circular checkbox: empty ring when open, filled
/// accent capsule with a check glyph when done.
fn task_checkbox(
  done : Bool,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let size = 18.0
  if done {
    @views.stack([
      @views.container(
        @views.spacer(min_length=0.0, weight=0.0),
        width=size,
        height=size,
        background=palette.accent,
        corner_radius=size / 2.0,
        padding=0.0,
      ),
      @views.text(
        "✓",
        role=@views.TextRole::Caption,
        theme~,
        width=size,
        height=size,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=11.0, weight=700))
      .foreground(@graphics.Color::white())
      .align(alignment=@geometry.Alignment::center())
      .frame(width=size, height=size),
    ]).frame(width=size, height=size)
  } else {
    @views.container(
      @views.spacer(min_length=0.0, weight=0.0),
      width=size,
      height=size,
      background=rgba8(0, 0, 0, a=0.0),
      corner_radius=size / 2.0,
      border=Some(
        @graphics.BorderStyle::new(
          brush=@graphics.Brush::solid(palette.muted),
          width=1.5,
        ),
      ),
      padding=0.0,
    )
  }
}

///|
fn task_preview(
  label : String,
  done : Bool,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  // macOS Reminders row: a leading circular checkbox, the task label inline,
  // muted when completed. The row still selects the same action so the widget
  // remains a glanceable preview rather than a live toggle surface.
  @views.row(
    [
      task_checkbox(done, palette, theme),
      @views.text(
        label,
        role=@views.TextRole::Body,
        theme~,
        width=196.0,
        height=18.0,
      )
      .font(@text.FontSpec::new(size=13.0, weight=520))
      .foreground(if done { palette.muted } else { palette.foreground }),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn desktop_files(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[Msg] {
  // Each icon carries its persisted placement offset and a drag surface so
  // the layout survives relaunch via the desktop snapshot.
  let tahoe_offset = model.icon_placement("Tahoe Trip")
  let welcome_offset = model.icon_placement("Welcome.txt")
  @views.column(
    [
      desktop_file(
        "Tahoe Trip",
        true,
        OpenFinder,
        tahoe_offset.0,
        tahoe_offset.1,
        palette,
        theme,
      ),
      desktop_file(
        "Welcome.txt",
        false,
        SelectFinderLocation(Documents),
        welcome_offset.0,
        welcome_offset.1,
        palette,
        theme,
      ),
    ],
    spacing=20.0,
    align=@views.CrossAlign::Center,
  )
  .frame(width=112.0, height=230.0)
  .align(alignment=@geometry.Alignment::top_trailing())
  .offset(dx=-18.0, dy=56.0)
  .frame(width~, height=300.0)
}

///|
fn desktop_file(
  label : String,
  is_folder : Bool,
  message : Msg,
  offset_x : Double,
  offset_y : Double,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  // Folder: soft blue plate. Document: white paper glyph with TXT badge.
  let glyph = if is_folder {
    @views.container(
      desktop_icon(@views.IconName::FolderOpen, 28.0, @graphics.Color::white()),
      width=56.0,
      height=48.0,
      background=rgba8(52, 148, 246),
      corner_radius=12.0,
      border=Some(
        @graphics.BorderStyle::new(
          brush=@graphics.Brush::solid(rgba8(255, 255, 255, a=0.40)),
          width=1.0,
        ),
      ),
      padding=12.0,
    ).shadow(
      @graphics.ShadowStyle::new(
        color=palette.shadow.multiply_alpha(0.40),
        offset=@geometry.Point::new(x=0.0, y=3.0),
        blur_radius=8.0,
        spread=0.0,
      ),
    )
  } else {
    @views.stack([
      @views.container(
        @views.spacer(min_length=0.0, weight=0.0),
        width=46.0,
        height=56.0,
        background=rgba8(252, 253, 255),
        corner_radius=8.0,
        border=Some(
          @graphics.BorderStyle::new(
            brush=@graphics.Brush::solid(rgba8(210, 218, 228, a=0.95)),
            width=1.0,
          ),
        ),
        padding=0.0,
      ).shadow(
        @graphics.ShadowStyle::new(
          color=palette.shadow.multiply_alpha(0.35),
          offset=@geometry.Point::new(x=0.0, y=2.0),
          blur_radius=6.0,
          spread=0.0,
        ),
      ),
      @views.container(
        @views.text(
          "TXT",
          role=@views.TextRole::Caption,
          theme~,
          width=30.0,
          height=12.0,
          align=@text.TextAlign::TextCenter,
        )
        .font(@text.FontSpec::new(size=8.5, weight=700))
        .foreground(@graphics.Color::white()),
        width=30.0,
        height=14.0,
        background=rgba8(52, 148, 246),
        corner_radius=3.0,
        padding=1.0,
      )
      .align(alignment=@geometry.Alignment::bottom_leading())
      .offset(dx=8.0, dy=-16.0),
    ]).frame(width=46.0, height=56.0)
  }
  @views.column(
    [
      glyph,
      @views.text(
        label,
        role=@views.TextRole::Caption,
        theme~,
        width=104.0,
        height=30.0,
        align=@text.TextAlign::TextCenter,
      )
      .font(@text.FontSpec::new(size=11.5, weight=500))
      .foreground(@graphics.Color::white())
      .shadow(
        @graphics.ShadowStyle::new(
          color=rgba8(0, 0, 0, a=0.58),
          offset=@geometry.Point::new(x=0.0, y=1.0),
          blur_radius=2.0,
          spread=0.0,
        ),
      ),
    ],
    spacing=6.0,
    align=@views.CrossAlign::Center,
  )
  .on_tap(message)
  .on_drag(event => {
    let name = label
    MoveDesktopIcon(name, event.delta.x, event.delta.y)
  })
  .offset(dx=offset_x, dy=offset_y)
  .accessibility_label(
    "Open " + label + ", at \{offset_x.round()}, \{offset_y.round()}",
  )
}
