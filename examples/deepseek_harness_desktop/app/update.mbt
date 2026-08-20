///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    WebViewEvent(event) =>
      match event {
        @webview_host.WebViewEvent::NavigationRequested(url) =>
          { ..model, url, status: "loading" }
        @webview_host.WebViewEvent::NavigationStarted(navigation) =>
          { ..model, url: navigation.url, status: "loading" }
        @webview_host.WebViewEvent::NavigationCommitted(navigation) =>
          { ..model, url: navigation.url, status: "loaded" }
        @webview_host.WebViewEvent::NavigationFinished(navigation) =>
          { ..model, url: navigation.url, status: "ready" }
        @webview_host.WebViewEvent::NavigationFailed(_, _url, reason) =>
          { ..model, status: "failed: " + reason.message }
        @webview_host.WebViewEvent::TitleChanged(title) => { ..model, title, }
        @webview_host.WebViewEvent::CanGoBackChanged(_)
        | @webview_host.WebViewEvent::CanGoForwardChanged(_)
        | @webview_host.WebViewEvent::Message(_)
        | @webview_host.WebViewEvent::Request(_)
        | @webview_host.WebViewEvent::Ready(_)
        | @webview_host.WebViewEvent::HostPatchReported(_)
        | @webview_host.WebViewEvent::Diagnostic(_)
        | @webview_host.WebViewEvent::Disposed => model
      }
    SettingsLoaded(result) => {
      let harness = match result {
        @services.ServiceTaskResult::Success(Some(value)) =>
          normalize_request_url(value).unwrap_or(model.harness_url)
        _ => model.harness_url
      }
      {
        ..model,
        url: if model.active_site == Harness {
          harness
        } else {
          model.url
        },
        configured_url: harness,
        harness_url: harness,
        request_url_input: harness,
        harness_settings_ready: true,
        settings_ready: model.chat_settings_ready && model.theme_settings_ready,
        settings_error: "",
      }
    }
    ThemeModeLoaded(result) => {
      let mode = match result {
        @services.ServiceTaskResult::Success(Some(value)) =>
          theme_mode_from_id(value)
        _ => model.theme_mode
      }
      {
        ..model,
        theme_mode: mode,
        theme_mode_input: mode,
        theme_settings_ready: true,
        settings_ready: model.harness_settings_ready &&
        model.chat_settings_ready,
        settings_error: "",
      }
    }
    SystemColorSchemeLoaded(result) =>
      match result {
        @services.ServiceTaskResult::Success(value) =>
          { ..model, system_color_scheme: value }
        _ => model
      }
    ChatSettingsLoaded(result) => {
      let chat = match result {
        @services.ServiceTaskResult::Success(Some(value)) =>
          normalize_request_url(value).unwrap_or(model.chat_url)
        _ => model.chat_url
      }
      {
        ..model,
        url: if model.active_site == Chat {
          chat
        } else {
          model.url
        },
        chat_url: chat,
        chat_url_input: chat,
        chat_settings_ready: true,
        settings_ready: model.harness_settings_ready &&
        model.theme_settings_ready,
        settings_error: "",
      }
    }
    OpenSettings =>
      {
        ..model,
        settings_presented: true,
        request_url_input: model.harness_url,
        chat_url_input: model.chat_url,
        theme_mode_input: model.theme_mode,
        settings_error: "",
        settings_saving: false,
        settings_writes_pending: 0,
      }
    RequestUrlChanged(value) if !model.settings_saving =>
      { ..model, request_url_input: value, settings_error: "" }
    ChatUrlChanged(value) if !model.settings_saving =>
      { ..model, chat_url_input: value, settings_error: "" }
    ThemeModeChanged(value) if !model.settings_saving =>
      {
        ..model,
        theme_mode_input: theme_mode_from_id(value),
        settings_error: "",
      }
    RequestUrlChanged(_) | ChatUrlChanged(_) | ThemeModeChanged(_) => model
    SaveSettings => {
      let harness_ok = normalize_request_url(model.request_url_input) is Some(_)
      let chat_ok = normalize_request_url(model.chat_url_input) is Some(_)
      if !harness_ok || !chat_ok {
        {
          ..model,
          settings_error: "Enter valid HTTP or HTTPS URLs.",
          settings_saving: false,
        }
      } else {
        {
          ..model,
          request_url_input: normalize_request_url(model.request_url_input).unwrap_or(
            model.harness_url,
          ),
          chat_url_input: normalize_request_url(model.chat_url_input).unwrap_or(
            model.chat_url,
          ),
          theme_mode_input: model.theme_mode_input,
          settings_error: "",
          settings_saving: true,
          settings_writes_pending: 3,
        }
      }
    }
    CancelSettings =>
      {
        ..model,
        settings_presented: false,
        request_url_input: model.harness_url,
        chat_url_input: model.chat_url,
        theme_mode_input: model.theme_mode,
        settings_error: "",
        settings_saving: false,
        settings_writes_pending: 0,
      }
    SettingsBackdropPressed => model
    SwitchSite if !model.settings_presented => {
      let next_site = match model.active_site {
        Harness => Chat
        Chat => Harness
      }
      let next_url = match next_site {
        Harness => model.harness_url
        Chat => model.chat_url
      }
      {
        ..model,
        active_site: next_site,
        url: next_url,
        status: "loading",
        // A click on the visible tab also expands a docked button.
        floating_collapsed: false,
      }
    }
    SwitchSite => model
    ToggleFloating => { ..model, floating_enabled: !model.floating_enabled }
    FloatingSecondaryTap =>
      update({ ..model, floating_collapsed: false }, OpenSettings)
    FloatingDragged(event) => update_floating_drag(model, event, None, None)
    FloatingDraggedInViewport(event, width, height) =>
      update_floating_drag(model, event, Some(width), Some(height))
    HarnessSettingsSaved(value, result) =>
      apply_settings_result(model, Harness, value, result)
    ChatSettingsSaved(value, result) =>
      apply_settings_result(model, Chat, value, result)
    ThemeModeSaved(mode, result) => apply_theme_mode_result(model, mode, result)
    // Kept for callers/tests using the original single-setting message.
    SettingsSaved(value, result) =>
      apply_settings_result(
        { ..model, settings_writes_pending: 1 },
        Harness,
        value,
        result,
      )
  }
}

///|
fn update_floating_drag(
  model : Model,
  event : @views.DragGestureEvent,
  viewport_width : Double?,
  viewport_height : Double?,
) -> Model {
  if event.phase == @views.DragGesturePhase::Cancelled {
    // Cancellation is terminal. Keep the last committed position; a lost
    // pointer stream must not snap the button back to an edge.
    return model
  }
  // A collapsed button starts with its visible tab offset. Promote it to
  // the full button as soon as a real drag crosses the gesture slop, then
  // continue applying deltas from that expanded position.
  let base_x = if event.phase == @views.DragGesturePhase::Started &&
    model.floating_collapsed {
    if model.floating_left {
      -(floating_button_size - floating_peek_size)
    } else {
      floating_button_size - floating_peek_size
    }
  } else {
    model.floating_x
  }
  let raw_x = base_x + event.delta.x
  let raw_y = model.floating_y + event.delta.y
  let next_y = match viewport_height {
    Some(height) =>
      raw_y.clamp(min=0.0, max=(height - floating_button_size).max(0.0))
    None => raw_y.max(0.0)
  }
  if event.phase == @views.DragGesturePhase::Ended {
    // `position.x` is in window coordinates, so the left edge is
    // unambiguous. For a right-anchored button, the horizontal offset also
    // identifies the right edge. Once a user has moved freely from the
    // left edge we preserve that anchor until they intentionally return to
    // the left; this avoids surprising snaps in the middle of the window.
    let near_left = event.position.x <= floating_edge_threshold
    let near_right = match viewport_width {
      Some(width) => event.position.x >= width - floating_edge_threshold
      None => !model.floating_left && raw_x >= -floating_edge_threshold
    }
    let docked = near_left || near_right
    let dock_left = if near_left {
      true
    } else if near_right {
      false
    } else {
      // Once the button is on the left side, keep using that coordinate
      // system for free positions. This lets a user pull a left peek tab
      // back into the window without a jump caused by an unknown viewport
      // width.
      model.floating_left
    }
    // Preserve the free position. A docked button stores the expanded
    // edge anchor and derives the hidden offset in `view`.
    {
      ..model,
      floating_x: if docked {
        0.0
      } else {
        clamp_floating_x(raw_x, model.floating_left, viewport_width)
      },
      floating_y: next_y,
      floating_left: dock_left,
      floating_collapsed: docked,
    }
  } else {
    {
      ..model,
      floating_x: clamp_floating_x(raw_x, model.floating_left, viewport_width),
      floating_y: next_y,
      floating_collapsed: false,
    }
  }
}

///|
fn clamp_floating_x(
  value : Double,
  left : Bool,
  viewport_width : Double?,
) -> Double {
  match viewport_width {
    Some(width) => {
      let extent = (width - floating_button_size).max(0.0)
      if left {
        value.clamp(min=0.0, max=extent)
      } else {
        value.clamp(min=-extent, max=0.0)
      }
    }
    None => value
  }
}

///|
fn apply_settings_result(
  model : Model,
  site : Site,
  value : String,
  result : @services.ServiceTaskResult[Unit],
) -> Model {
  if !model.settings_presented || !model.settings_saving {
    return model
  }
  match result {
    @services.ServiceTaskResult::Failure(error) =>
      {
        ..model,
        settings_error: error.message,
        settings_saving: false,
        settings_writes_pending: 0,
      }
    @services.ServiceTaskResult::Cancelled =>
      {
        ..model,
        settings_error: "Saving was cancelled.",
        settings_saving: false,
        settings_writes_pending: 0,
      }
    @services.ServiceTaskResult::Success(_) => {
      let harness = if site == Harness { value } else { model.harness_url }
      let chat = if site == Chat { value } else { model.chat_url }
      let pending = if model.settings_writes_pending > 0 {
        model.settings_writes_pending - 1
      } else {
        0
      }
      let next_url = match model.active_site {
        Harness => harness
        Chat => chat
      }
      if pending > 0 {
        {
          ..model,
          harness_url: harness,
          configured_url: harness,
          chat_url: chat,
          url: next_url,
          settings_writes_pending: pending,
        }
      } else {
        {
          ..model,
          harness_url: harness,
          configured_url: harness,
          chat_url: chat,
          url: next_url,
          request_url_input: harness,
          chat_url_input: chat,
          settings_presented: false,
          settings_error: "",
          settings_saving: false,
          settings_writes_pending: 0,
          status: "loading",
        }
      }
    }
  }
}

///|
fn apply_theme_mode_result(
  model : Model,
  mode : ThemeMode,
  result : @services.ServiceTaskResult[Unit],
) -> Model {
  if !model.settings_presented || !model.settings_saving {
    return model
  }
  match result {
    @services.ServiceTaskResult::Failure(error) =>
      {
        ..model,
        settings_error: error.message,
        settings_saving: false,
        settings_writes_pending: 0,
      }
    @services.ServiceTaskResult::Cancelled =>
      {
        ..model,
        settings_error: "Saving was cancelled.",
        settings_saving: false,
        settings_writes_pending: 0,
      }
    @services.ServiceTaskResult::Success(_) => {
      let pending = if model.settings_writes_pending > 0 {
        model.settings_writes_pending - 1
      } else {
        0
      }
      let next = {
        ..model,
        theme_mode: mode,
        theme_mode_input: mode,
        settings_writes_pending: pending,
      }
      if pending > 0 {
        next
      } else {
        {
          ..next,
          request_url_input: next.harness_url,
          chat_url_input: next.chat_url,
          settings_presented: false,
          settings_error: "",
          settings_saving: false,
          settings_writes_pending: 0,
        }
      }
    }
  }
}

///|
pub fn normalize_request_url(value : String) -> String? {
  let trimmed = value.trim().to_owned()
  let lower = trimmed.to_lower()
  let has_http = lower.has_prefix("http://") && trimmed.length() > 7
  let has_https = lower.has_prefix("https://") && trimmed.length() > 8
  if (has_http || has_https) &&
    !trimmed.contains(" ") &&
    !trimmed.contains("\n") &&
    !trimmed.contains("\t") {
    Some(trimmed)
  } else {
    None
  }
}
