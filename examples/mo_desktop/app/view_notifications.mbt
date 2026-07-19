///|
fn notification_center(
  model : DesktopModel,
  palette : DesktopPalette,
  theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  // Keep the notification center as a quiet, narrow glanceable surface. Its
  // only close affordance is the surrounding desktop, just like macOS.
  let compact = viewport_width < 520.0
  let width = if compact { (viewport_width - 20.0).max(272.0) } else { 336.0 }
  let height = if compact {
    (viewport_height - 72.0).min(474.0).max(412.0)
  } else {
    430.0
  }
  let inner_width = width - 32.0
  let body = @views.column(
    [
      @views.row(
        [
          @views.text(
            "Today",
            role=@views.TextRole::Title,
            theme~,
            width=(inner_width - 24.0).max(140.0),
            height=28.0,
          )
          .font(@text.FontSpec::new(size=20.0, weight=680))
          .foreground(palette.foreground),
          @views.spacer(min_length=6.0, weight=1.0),
          @views.container(
            @views.spacer(min_length=0.0, weight=0.0),
            width=8.0,
            height=8.0,
            background=palette.accent.multiply_alpha(
              if model.notifications_read {
                0.55
              } else {
                1.0
              },
            ),
            corner_radius=4.0,
            padding=0.0,
          ).accessibility_label("Unread notification status"),
        ],
        spacing=6.0,
        align=@views.CrossAlign::Center,
      ),
      notification_card(
        "Messages",
        "Design Review",
        "Maya left feedback on the desktop polish pass.",
        "8m ago",
        inner_width,
        rgba8(52, 148, 246),
        palette,
        theme,
      ),
      notification_card(
        "Calendar",
        "Sprint Planning",
        "Sprint planning starts tomorrow at 9:30 AM.",
        "1h ago",
        inner_width,
        rgba8(255, 149, 0),
        palette,
        theme,
      ),
      @views.divider(theme~, color=palette.outline.multiply_alpha(0.85)),
      @views.row(
        [
          @views.text(
            "Today's Tasks",
            role=@views.TextRole::Label,
            theme~,
            width=(inner_width - 64.0).max(140.0),
            height=20.0,
          )
          .font(@text.FontSpec::new(size=13.5, weight=640))
          .foreground(palette.foreground),
          @views.spacer(min_length=4.0, weight=1.0),
          @views.text(
            "View all",
            role=@views.TextRole::Caption,
            theme~,
            width=48.0,
            height=20.0,
            align=@text.TextAlign::TextEnd,
          )
          .font(@text.FontSpec::new(size=12.0, weight=560))
          .foreground(palette.accent)
          // This retains the notification read action while giving it a
          // lightweight, discoverable inline target instead of a button.
          .on_tap(MarkNotificationsRead)
          .accessibility_label("View all tasks"),
        ],
        spacing=4.0,
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
    spacing=10.0,
    align=@views.CrossAlign::Stretch,
  )
  let panel = @views.container(
    body,
    width~,
    height~,
    background=overlay_panel_background(palette),
    corner_radius=22.0,
    border=Some(desktop_hairline(palette)),
    padding=16.0,
  ).shadow(
    @graphics.ShadowStyle::new(
      color=palette.shadow.multiply_alpha(0.68),
      offset=@geometry.Point::new(x=0.0, y=12.0),
      blur_radius=28.0,
      spread=0.0,
    ),
  )
  let aligned = if compact {
    panel
    .align(alignment=@geometry.Alignment::top_leading())
    .offset(dx=10.0, dy=38.0)
  } else {
    panel
    .align(alignment=@geometry.Alignment::top_trailing())
    .offset(dx=-14.0, dy=38.0)
  }
  @views.stack([
    color_layer(viewport_width, viewport_height, rgba8(0, 0, 0, a=0.0)).on_tap(
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
  app : String,
  title : String,
  detail : String,
  time : String,
  width : Double,
  accent : @graphics.Color,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  @views.container(
    @views.column(
      [
        @views.row(
          [
            @views.container(
              desktop_icon(
                @views.IconName::Info,
                13.0,
                @graphics.Color::white(),
              ),
              width=30.0,
              height=30.0,
              background=accent,
              corner_radius=8.0,
              padding=8.5,
            ),
            @views.text(
              app,
              role=@views.TextRole::Caption,
              theme~,
              width=(width - 100.0).max(80.0),
              height=18.0,
            )
            .font(@text.FontSpec::new(size=11.5, weight=620))
            .foreground(palette.muted),
            @views.spacer(min_length=4.0, weight=1.0),
            @views.text(
              time,
              role=@views.TextRole::Caption,
              theme~,
              width=42.0,
              height=18.0,
              align=@text.TextAlign::TextEnd,
            )
            .font(@text.FontSpec::new(size=11.0, weight=460))
            .foreground(palette.muted),
          ],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ),
        @views.text(
          title,
          role=@views.TextRole::Label,
          theme~,
          width=width - 24.0,
          height=20.0,
        )
        .font(@text.FontSpec::new(size=14.0, weight=640))
        .foreground(palette.foreground),
        @views.text(
          detail,
          role=@views.TextRole::Caption,
          theme~,
          width=width - 24.0,
          height=28.0,
        )
        .font(@text.FontSpec::new(size=12.0, weight=460))
        .foreground(palette.muted),
      ],
      spacing=3.0,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=92.0,
    background=overlay_card_background(palette),
    corner_radius=14.0,
    border=Some(overlay_card_outline(palette)),
    padding=12.0,
  )
  .on_tap(MarkNotificationsRead)
  .accessibility_label("Read notification from " + app + ": " + title)
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
  let check = @views.container(
    if done {
      desktop_icon(@views.IconName::Check, 10.0, @graphics.Color::white())
    } else {
      @views.spacer(min_length=0.0, weight=0.0)
    },
    width=18.0,
    height=18.0,
    background=if done { rgba8(40, 200, 64) } else { rgba8(0, 0, 0, a=0.0) },
    corner_radius=9.0,
    border=Some(
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(
          if done {
            rgba8(40, 200, 64)
          } else {
            rgba8(160, 168, 180)
          },
        ),
        width=1.5,
      ),
    ),
    padding=4.0,
  )
  @views.container(
    @views.row(
      [
        check,
        @views.text(
          label,
          role=@views.TextRole::Body,
          theme~,
          width=(width - 54.0).max(140.0),
          height=22.0,
        )
        .font(
          @text.FontSpec::new(size=13.0, weight=if done { 430 } else { 520 }),
        )
        .foreground(if done { palette.muted } else { palette.foreground }),
      ],
      spacing=10.0,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=30.0,
    background=rgba8(0, 0, 0, a=0.0),
    padding=0.0,
  )
  .on_tap(if done { MarkNotificationsRead } else { CompleteTask(index) })
  .accessibility_label(if done { "Done " + label } else { "Complete " + label })
}
