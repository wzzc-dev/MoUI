///|
using @views {column, container, spacer, text}

///|
using @webview_views {web_view}

///|
/// Compatibility entrypoint for callers that render the app without a host
/// environment. Native composition roots use `view_with_environment` below so
/// the floating control can clamp itself to the actual window size.
pub fn view(model : Model) -> @moui.View[Msg] {
  view_with_viewport(model, 1280.0, 820.0, model.system_color_scheme, None)
}

///|
fn view_with_environment(
  model : Model,
  view_environment : @moui.ViewEnvironment,
  controller : @webview_host.WebViewController?,
) -> @moui.View[Msg] {
  let viewport = view_environment.viewport_size()
  view_with_viewport(
    model,
    viewport.width,
    viewport.height,
    view_environment.environment().system_scheme,
    controller,
  )
}

///|
fn view_with_viewport(
  model : Model,
  viewport_width : Double,
  viewport_height : Double,
  system_color_scheme : @state.ColorScheme,
  controller : @webview_host.WebViewController?,
) -> @moui.View[Msg] {
  // Preview the selected mode while Settings is open so the native WebView
  // surface and MoUI dialog use the same appearance before Save.
  let selected_mode = if model.settings_presented {
    model.theme_mode_input
  } else {
    model.theme_mode
  }
  let theme = theme_for_mode(selected_mode, system_color_scheme)
  let content = if model.web_view_available && model.settings_ready {
    match controller {
      Some(controller) =>
        web_view(
          controller~,
          title=model.title,
          background_color=Some(theme.palette.background),
          color_scheme=Some(theme.scheme),
          on_event=Some(event => WebViewEvent(event)),
        )
      None => loading_view(theme)
    }
  } else if model.web_view_available {
    loading_view(theme)
  } else {
    unavailable_view(model, theme)
  }
  let floating = if model.settings_presented || !model.floating_enabled {
    @views.empty()
  } else {
    floating_button(model, theme, viewport_width, viewport_height)
  }
  let body = @views.overlay(content, floating)
  let root = @views.dialog_host(
    body,
    dialog=Some(settings_dialog(model, theme)),
    presented=model.settings_presented,
    on_backdrop=Some(SettingsBackdropPressed),
  )
  root.theme(theme)
}

///|
fn floating_button(
  model : Model,
  _theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  // DeepSeek blue keeps the affordance legible in both light and dark themes.
  let brand_blue = @graphics.Color::rgba(r=0.302, g=0.420, b=0.996, a=1.0)
  let button = @views.container(
      @views.text(
        "D",
        role=@views.TextRole::Control,
        width=floating_button_size,
        height=floating_button_size,
      ).foreground(@graphics.Color::white()),
      width=floating_button_size,
      height=floating_button_size,
      background=brand_blue,
      corner_radius=floating_button_size / 2.0,
      padding=0.0,
      // Keep drag inside the tap modifiers so it receives the terminal Up/Cancel
      // before a child tap consumes a click. Otherwise a click can leave the drag
      // recognizer pending and subsequent pointer moves move the button.
    )
    .on_drag(event => {
      FloatingDraggedInViewport(event, viewport_width, viewport_height)
    })
    .on_secondary_tap(FloatingSecondaryTap)
    .on_tap(SwitchSite)
    .accessibility_label("Switch Chat/DSH site")
  let surface = @views.stack([
    button,
    @views.overlay_marker(
      width=floating_button_size,
      height=floating_button_size,
    ),
  ])
  let placed = if model.floating_left {
    @views.row([surface, @views.spacer(weight=1.0)], spacing=0.0)
  } else {
    @views.row([@views.spacer(weight=1.0), surface], spacing=0.0)
  }
  let horizontal_offset = if model.floating_collapsed {
    if model.floating_left {
      -(floating_button_size - floating_peek_size)
    } else {
      floating_button_size - floating_peek_size
    }
  } else {
    clamp_floating_x(
      model.floating_x,
      model.floating_left,
      Some(viewport_width),
    )
  }
  @views.column([placed], spacing=0.0).offset(
    dx=horizontal_offset,
    dy=model.floating_y.clamp(
      min=0.0,
      max=(viewport_height - floating_button_size).max(0.0),
    ),
  )
}

///|
fn loading_view(theme : @moui.Theme) -> @moui.View[Msg] {
  container(spacer(min_length=1.0, weight=1.0), padding=0.0).background(
    theme.palette.surface,
  )
}

///|
fn settings_dialog(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  let support = if model.settings_error == "" {
    text("HTTP or HTTPS").caption().foreground(theme.palette.muted)
  } else {
    text(model.settings_error).caption().foreground(theme.palette.danger)
  }
  @views.dialog(
    "Settings",
    content=column(
      [
        text("Harness URL").caption(),
        @views.text_field(
          model.request_url_input,
          on_input=value => RequestUrlChanged(value),
          on_submit=Some(SaveSettings),
          placeholder=default_url,
          width=416.0,
          height=40.0,
        ),
        text("Chat URL").caption(),
        @views.text_field(
          model.chat_url_input,
          on_input=value => ChatUrlChanged(value),
          on_submit=Some(SaveSettings),
          placeholder=default_chat_url,
          width=416.0,
          height=40.0,
        ),
        text("Theme").caption(),
        @views.segmented_control(
          [
            @views.choice_item("system", "System"),
            @views.choice_item("dark", "Dark"),
            @views.choice_item("light", "Light"),
          ],
          selected=model.theme_mode_input.id(),
          on_select=value => ThemeModeChanged(value),
          theme~,
          width=416.0,
        ),
        support.frame(width=416.0, height=28.0),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Start,
    ),
    primary_action=Some(
      @views.StateViewAction::new(
        label=if model.settings_saving { "Saving..." } else { "Save" },
        message=SaveSettings,
      ),
    ),
    secondary_action=Some(
      @views.StateViewAction::new(label="Cancel", message=CancelSettings),
    ),
    theme~,
    width=480.0,
    height=404.0,
  )
}

///|
fn unavailable_view(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  container(
    column(
      [
        spacer(min_length=120.0, weight=0.0),
        text("Native WebView unavailable").title(),
        text(model.web_view_description).foreground(theme.palette.muted),
        text("Start a native composition root to open the local DSH Host.")
        .caption()
        .foreground(theme.palette.muted),
        spacer(min_length=120.0, weight=0.0),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Center,
    ),
    padding=24.0,
  ).background(theme.palette.surface_variant.multiply_alpha(0.45))
}
