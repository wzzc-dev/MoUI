///|
pub fn[Msg] toast(
  message : String,
  tone? : FeedbackTone = FeedbackTone::Neutral,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  feedback_surface(
    message,
    tone~,
    action~,
    theme~,
    width~,
    title="",
    height=52.0,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
pub fn[Msg] toast_stack(
  items : Array[ToastStackItem[Msg]],
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 360.0,
  spacing? : Double = @core.Theme::default().spacing_scale.sm,
) -> @core.View[Msg] {
  if items.length() == 0 {
    empty()
  } else {
    let rows : Array[@core.View[Msg]] = []
    for item in items {
      rows.push(toast_stack_row(item, theme~, width~, spacing~))
    }
    column(rows, spacing~, align=CrossAlign::Stretch)
    .semantics_role(@core.SemanticsRole::Group)
    .accessibility_label("Toast stack")
  }
}

///|
pub fn[Msg] snackbar(
  message : String,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 360.0,
) -> @core.View[Msg] {
  feedback_surface(
    message,
    tone=FeedbackTone::Neutral,
    action~,
    theme~,
    width~,
    title="",
    height=56.0,
  )
}

///|
pub fn[Msg] banner(
  title : String,
  message : String,
  tone? : FeedbackTone = FeedbackTone::Info,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 420.0,
) -> @core.View[Msg] {
  feedback_surface(message, tone~, action~, theme~, width~, title~, height=92.0)
}

///|
pub fn[Msg] callout(
  title : String,
  message : String,
  tone? : FeedbackTone = FeedbackTone::Info,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 360.0,
) -> @core.View[Msg] {
  feedback_surface(
    message,
    tone~,
    action=None,
    theme~,
    width~,
    title~,
    height=86.0,
  )
}

///|
pub fn[Msg] empty_state(
  title : String,
  message : String,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  state_panel(
    title,
    message,
    action~,
    theme~,
    width~,
    tone=FeedbackTone::Neutral,
  )
}

///|
pub fn[Msg] loading_state(
  title? : String = "Loading",
  message? : String = "Please wait while content is prepared.",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  state_panel(
    title,
    message,
    action=None,
    theme~,
    width~,
    tone=FeedbackTone::Info,
  )
}

///|
pub fn[Msg] error_state(
  title : String,
  message : String,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 320.0,
) -> @core.View[Msg] {
  state_panel(
    title,
    message,
    action~,
    theme~,
    width~,
    tone=FeedbackTone::Danger,
  )
}

///|
pub fn[Msg] inline_error(
  message : String,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 360.0,
) -> @core.View[Msg] {
  let action_width = match action {
    Some(_) => 86.0
    None => 0.0
  }
  let message_width = views_max_double(
    96.0,
    width - 72.0 - action_width - theme.spacing_scale.sm,
  )
  let body : Array[@core.View[Msg]] = [
    badge("Error", tone=BadgeTone::Danger, theme~, width=64.0),
    text(
      message,
      role=TextRole::Caption,
      theme~,
      width=message_width,
      height=28.0,
    ).foreground(feedback_accent(FeedbackTone::Danger, theme)),
  ]
  match action {
    Some(action) =>
      body.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Ghost,
          theme~,
          width=86.0,
          height=32.0,
        ),
      )
    None => ()
  }
  surface(
    row(body, spacing=theme.spacing_scale.sm, align=CrossAlign::Center),
    width~,
    height=44.0,
    background=feedback_background(FeedbackTone::Danger, theme),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.xs,
  )
  .border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(
        feedback_accent(FeedbackTone::Danger, theme).multiply_alpha(0.72),
      ),
      width=1.0,
    ),
  )
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_invalid()
  .accessibility_label("Error: " + message)
}

///|
pub fn[Msg] progress_status(
  title : String,
  value~ : Double,
  message? : String = "",
  status? : String = "",
  tone? : FeedbackTone = FeedbackTone::Info,
  action? : StateViewAction[Msg]? = None,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 420.0,
) -> @core.View[Msg] {
  let inner_width = views_max_double(
    120.0,
    width - theme.spacing_scale.md * 2.0,
  )
  let status_text = if status == "" {
    progress_status_label(value)
  } else {
    status
  }
  let status_width = views_max_double(
    72.0,
    status_text.to_array().length().to_double() * 8.0 + 22.0,
  )
  let title_width = views_max_double(80.0, inner_width - status_width - 10.0)
  let rows : Array[@core.View[Msg]] = [
    row(
      [
        text(
          title,
          role=TextRole::Control,
          theme~,
          width=title_width,
          height=24.0,
        ),
        status_badge(
          status_text,
          tone=progress_status_badge_tone(tone),
          detail="Progress status for " + title,
          theme~,
          width=status_width,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=CrossAlign::Center,
    ),
  ]
  if message != "" {
    rows.push(
      text(
        message,
        role=TextRole::Caption,
        theme~,
        width=inner_width,
        height=28.0,
      ),
    )
  }
  rows.push(
    progress(
      value,
      width=inner_width,
      height=8.0,
      foreground=feedback_accent(tone, theme),
      background=theme.palette.surface_variant,
    ),
  )
  match action {
    Some(action) =>
      rows.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Tonal,
          theme~,
          width=128.0,
          height=34.0,
        ),
      )
    None => ()
  }
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start),
    width~,
    height=progress_status_height(message != "", action is Some(_)),
    background=feedback_background(tone, theme),
    corner_radius=theme.radius_scale.md,
    theme~,
    padding=theme.spacing_scale.md,
  )
  .border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(
        feedback_accent(tone, theme).multiply_alpha(0.64),
      ),
      width=1.0,
    ),
  )
  .semantics_role(@core.SemanticsRole::Group)
  .semantics_description(status_text)
  .accessibility_label("Progress: " + title)
}

///|
pub fn[Msg] badge(
  label : String,
  tone? : BadgeTone = BadgeTone::Neutral,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 72.0,
  height? : Double = 24.0,
) -> @core.View[Msg] {
  surface(
    text(
      label,
      role=TextRole::Caption,
      theme~,
      width=width - 12.0,
      height=height - 6.0,
    ).foreground(badge_foreground(tone, theme)),
    width~,
    height~,
    background=badge_background(tone, theme),
    corner_radius=height / 2.0,
    padding=3.0,
  ).semantics_role(@core.SemanticsRole::Text)
}

///|
pub fn[Msg] status_badge(
  label : String,
  tone? : BadgeTone = BadgeTone::Neutral,
  detail? : String = "",
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 72.0,
  height? : Double = 24.0,
) -> @core.View[Msg] {
  let base = badge(label, tone~, theme~, width~, height~).accessibility_label(
    "Status: " + label,
  )
  if detail == "" {
    base
  } else {
    base.semantics_description(detail)
  }
}

///|
pub fn[Msg] stat_card(
  label : String,
  value : String,
  caption? : String = "",
  tone? : FeedbackTone = FeedbackTone::Neutral,
  theme? : @core.Theme = @core.Theme::default(),
  width? : Double = 180.0,
  height? : Double = 116.0,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = [
    text(label, role=TextRole::Caption, theme~, width=width - 24.0, height=22.0),
    text(value, role=TextRole::Title, theme~, width=width - 24.0, height=34.0).foreground(
      feedback_accent(tone, theme),
    ),
  ]
  if caption != "" {
    rows.push(
      text(
        caption,
        role=TextRole::Caption,
        theme~,
        width=width - 24.0,
        height=22.0,
      ),
    )
  }
  surface(
    column(rows, spacing=theme.spacing_scale.xs, align=CrossAlign::Start),
    width~,
    height~,
    variant=SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn[Msg] toast_stack_row(
  item : ToastStackItem[Msg],
  theme~ : @core.Theme,
  width~ : Double,
  spacing~ : Double,
) -> @core.View[Msg] {
  match item.dismiss {
    Some(message) => {
      let dismiss_width = 86.0
      row(
        [
          toast(
            item.message,
            tone=item.tone,
            action=item.action,
            theme~,
            width=views_max_double(120.0, width - dismiss_width - spacing),
          ),
          button(
            "Dismiss",
            on_click=message,
            variant=ButtonVariant::Ghost,
            theme~,
            width=dismiss_width,
            height=36.0,
          ).semantics_dismiss_action(),
        ],
        spacing~,
        align=CrossAlign::Center,
      ).frame(width~, height=52.0)
    }
    None =>
      toast(item.message, tone=item.tone, action=item.action, theme~, width~)
  }
}

///|
fn[Msg] feedback_surface(
  message : String,
  tone~ : FeedbackTone,
  action~ : StateViewAction[Msg]?,
  theme~ : @core.Theme,
  width~ : Double,
  title~ : String,
  height~ : Double,
) -> @core.View[Msg] {
  let text_width = match action {
    Some(_) => width - 128.0
    None => width - 28.0
  }
  let rows : Array[@core.View[Msg]] = []
  if title != "" {
    rows.push(
      text(title, role=TextRole::Control, theme~, width=text_width, height=24.0),
    )
  }
  rows.push(
    text(message, role=TextRole::Caption, theme~, width=text_width, height=28.0),
  )
  let body = column(
    rows,
    spacing=theme.spacing_scale.xs,
    align=CrossAlign::Start,
  )
  let content : @core.View[Msg] = match action {
    Some(action) =>
      row(
        [
          body.expanded(),
          button(
            action.label,
            on_click=action.message,
            variant=ButtonVariant::Tonal,
            theme~,
            width=92.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=CrossAlign::Center,
      )
    None => body
  }
  surface(
    content,
    width~,
    height~,
    background=feedback_background(tone, theme),
    corner_radius=theme.radius_scale.md,
    theme~,
    padding=theme.spacing_scale.sm,
  ).border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(
        feedback_accent(tone, theme).multiply_alpha(0.72),
      ),
      width=1.0,
    ),
  )
}

///|
fn[Msg] state_panel(
  title : String,
  message : String,
  action~ : StateViewAction[Msg]?,
  theme~ : @core.Theme,
  width~ : Double,
  tone~ : FeedbackTone,
) -> @core.View[Msg] {
  let rows : Array[@core.View[Msg]] = [
    text(title, role=TextRole::Control, theme~, width=width - 32.0, height=28.0),
    text(
      message,
      role=TextRole::Caption,
      theme~,
      width=width - 32.0,
      height=42.0,
    ),
  ]
  match action {
    Some(action) =>
      rows.push(
        button(
          action.label,
          on_click=action.message,
          variant=ButtonVariant::Primary,
          theme~,
          width=128.0,
        ),
      )
    None => ()
  }
  surface(
    column(rows, spacing=theme.spacing_scale.sm, align=CrossAlign::Start),
    width~,
    height=148.0,
    background=feedback_background(tone, theme),
    corner_radius=theme.radius_scale.md,
    theme~,
    padding=theme.spacing_scale.md,
  ).semantics_role(@core.SemanticsRole::Group)
}

///|
fn progress_status_label(value : Double) -> String {
  let normalized = clamp_view_double(value, 0.0, 1.0)
  if normalized <= 0.0 {
    "Pending"
  } else if normalized >= 1.0 {
    "Complete"
  } else {
    "In progress"
  }
}

///|
fn progress_status_badge_tone(tone : FeedbackTone) -> BadgeTone {
  match tone {
    Success => BadgeTone::Success
    Warning => BadgeTone::Warning
    Danger => BadgeTone::Danger
    Neutral | Info => BadgeTone::Accent
  }
}

///|
fn progress_status_height(has_message : Bool, has_action : Bool) -> Double {
  86.0 +
  (if has_message { 32.0 } else { 0.0 }) +
  (if has_action { 42.0 } else { 0.0 })
}

///|
fn feedback_accent(tone : FeedbackTone, theme : @core.Theme) -> @core.Color {
  match tone {
    Neutral => theme.palette.muted
    Info => theme.palette.primary
    Success => @core.Color::rgba(r=0.08, g=0.48, b=0.28)
    Warning => @core.Color::rgba(r=0.76, g=0.44, b=0.06)
    Danger => form_error_color(theme)
  }
}

///|
fn feedback_background(tone : FeedbackTone, theme : @core.Theme) -> @core.Color {
  feedback_accent(tone, theme).multiply_alpha(
    match theme.scheme {
      @core.ColorScheme::Light => 0.12
      @core.ColorScheme::Dark => 0.22
    },
  )
}

///|
fn badge_background(tone : BadgeTone, theme : @core.Theme) -> @core.Color {
  match tone {
    Neutral => theme.palette.surface_variant
    Accent => theme.palette.primary
    Success => @core.Color::rgba(r=0.08, g=0.48, b=0.28)
    Warning => @core.Color::rgba(r=0.76, g=0.44, b=0.06)
    Danger => form_error_color(theme)
  }
}

///|
fn badge_foreground(tone : BadgeTone, theme : @core.Theme) -> @core.Color {
  match tone {
    Neutral => theme.palette.foreground
    Accent | Success | Warning | Danger => @core.Color::white()
  }
}
