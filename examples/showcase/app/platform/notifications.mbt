///|
fn start_permission_request(
  model : Model,
  services : @services.AppServices,
) -> (Model, @moui.Effect[Msg]) {
  let generation = model.next_service
  (
    {
      ..model,
      pending_service: Some(generation),
      next_service: generation + 1,
      last_event: "Requesting notification permission...",
    },
    services
    .platform()
    .permissions()
    .request(@services.PermissionKind::Notifications)
    .effect(map=result => PermissionCompleted(generation, result)),
  )
}

///|
fn start_notification(
  model : Model,
  services : @services.AppServices,
) -> (Model, @moui.Effect[Msg]) {
  let generation = model.next_service
  let id = "showcase-notification-\{generation}"
  (
    {
      ..model,
      pending_service: Some(generation),
      next_service: generation + 1,
      notification_id: id,
      last_event: "Sending notification...",
    },
    services
    .platform()
    .notifications()
    .notify(
      @services.NotificationRequest::new(
        id~,
        title="MoUI Showcase",
        body="Hello from the platform service probe",
      ),
    )
    .effect(map=result => NotificationCompleted(generation, result)),
  )
}

///|
fn start_notification_cancel(
  model : Model,
  services : @services.AppServices,
) -> (Model, @moui.Effect[Msg]) {
  if model.notification_id == "" {
    (
      { ..model, last_event: "No notification to cancel", },
      @moui.Effect::none(),
    )
  } else {
    let generation = model.next_service
    (
      {
        ..model,
        pending_service: Some(generation),
        next_service: generation + 1,
        last_event: "Cancelling notification...",
      },
      services
      .platform()
      .notifications()
      .cancel(model.notification_id)
      .effect(map=result => NotificationCancelCompleted(generation, result)),
    )
  }
}

///|
fn complete_notification(
  model : Model,
  generation : Int32,
  result : @services.ServiceTaskResult[Unit],
) -> Model {
  if model.pending_service != Some(generation) {
    return model
  }
  match result {
    Success(_) =>
      {
        ..model,
        pending_service: None,
        notification_count: model.notification_count + 1,
        last_event: "Notification sent #\{model.notification_count + 1}",
      }
    Failure(error) =>
      {
        ..model,
        pending_service: None,
        notification_id: "",
        last_event: "Notification unavailable: " + error.message,
      }
    Cancelled =>
      {
        ..model,
        pending_service: None,
        notification_id: "",
        last_event: "Notification cancelled by host",
      }
  }
}

///|
fn complete_notification_cancel(
  model : Model,
  generation : Int32,
  result : @services.ServiceTaskResult[Unit],
) -> Model {
  if model.pending_service != Some(generation) {
    return model
  }
  match result {
    Success(_) =>
      {
        ..model,
        pending_service: None,
        notification_id: "",
        last_event: "Notification cancelled",
      }
    Failure(error) =>
      {
        ..model,
        pending_service: None,
        last_event: "Cancel unavailable: " + error.message,
      }
    Cancelled =>
      {
        ..model,
        pending_service: None,
        last_event: "Cancel cancelled by host",
      }
  }
}

///|
fn complete_permission_request(
  model : Model,
  generation : Int32,
  result : @services.ServiceTaskResult[@services.PermissionStatus],
) -> Model {
  if model.pending_service != Some(generation) {
    return model
  }
  match result {
    Success(status) => {
      let (label, event) = match status {
        @services.PermissionStatus::Granted =>
          ("granted", "Notification permission granted")
        @services.PermissionStatus::Denied =>
          ("denied", "Notification permission denied")
        @services.PermissionStatus::Restricted =>
          (
            "restricted", "Respond to the system prompt, then request permission again",
          )
      }
      {
        ..model,
        pending_service: None,
        notification_permission: label,
        last_event: event,
      }
    }
    Failure(error) =>
      {
        ..model,
        pending_service: None,
        notification_permission: "unavailable",
        last_event: "Permission unavailable: " + error.message,
      }
    Cancelled =>
      {
        ..model,
        pending_service: None,
        last_event: "Permission request cancelled",
      }
  }
}

///|
fn notification_card(model : Model) -> @moui.View[Msg] {
  card(
    column([
      text("Notifications sent: \{model.notification_count}"),
      text("Permission: \{model.notification_permission}"),
      text(
        if model.notification_id == "" {
          "Active notification: (none)"
        } else {
          "Active notification: \{model.notification_id}"
        },
      ),
      row([
        button("Request permission", on_click=RequestNotificationPermission),
        button("Notify", on_click=Notify),
        button("Cancel", on_click=CancelNotification),
      ]),
    ]),
  )
}
