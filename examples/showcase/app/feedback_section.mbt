///|
fn ShowcaseModel::feedback_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
  let action = @views.StateViewAction::new(label="Retry", message=ToggleActive)
  let queued_toasts : Array[@views.ToastQueueItem[ShowcaseMsg]] = []
  if !showcase_string_array_contains(self.feedback_dismissed_toasts, "saved") {
    queued_toasts.push(
      @views.ToastQueueItem::new(
        id="saved",
        message="Workspace saved",
        tone=@views.FeedbackTone::Success,
        dismiss=Some(FeedbackToastDismissed("saved")),
        created_at_ms=0.0,
        ttl_ms=5000.0,
      ),
    )
  }
  queued_toasts.push(
    @views.ToastQueueItem::new(
      id="queued",
      message="Sync queued for retry",
      tone=@views.FeedbackTone::Warning,
      action=Some(action),
      created_at_ms=1000.0,
      ttl_ms=0.0,
    ),
  )
  let toast_queue : @views.ToastQueue[ShowcaseMsg] = @views.ToastQueue::new(
    items=queued_toasts,
  )
  let toast_items = toast_queue.to_stack_items()
  let main_width = metrics.body_width
  let columns = showcase_grid_columns(main_width, metrics.compact, 2)
  let card_width = showcase_grid_card_width(
    main_width,
    columns,
    theme.spacing_scale.md,
  )
  let badge_views : Array[@moui.View[ShowcaseMsg]] = [
    @views.badge("Beta", tone=@views.BadgeTone::Accent, theme~),
    @views.status_badge(
      "Ready",
      tone=@views.BadgeTone::Success,
      detail="Sync is healthy",
      theme~,
    ),
    @views.status_badge(
      "Queued",
      tone=@views.BadgeTone::Warning,
      detail="Waiting for host service",
      theme~,
    ),
    @views.status_badge(
      "Failed",
      tone=@views.BadgeTone::Danger,
      detail="Last operation failed",
      theme~,
    ),
  ]
  let badges = if metrics.compact {
    column(
      badge_views,
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    )
  } else {
    row(
      badge_views,
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    )
  }
  self.section_panel(
    theme,
    "Feedback",
    "Status, notification, badge, and empty-state components for app workflows.",
    column(
      [
        grid(
          [
            toast(
              "Saved settings",
              tone=@views.FeedbackTone::Success,
              theme~,
              width=card_width,
            ),
            toast(
              "Sync warning",
              tone=@views.FeedbackTone::Warning,
              theme~,
              width=card_width,
            ),
          ],
          columns~,
          row_spacing=theme.spacing_scale.md,
          column_spacing=theme.spacing_scale.md,
        ),
        text(
          "ToastQueue helper: \{toast_items.length()} active items; app timers own ttl",
          role=@views.TextRole::Caption,
          theme~,
          width=main_width,
          height=22.0,
        ),
        toast_stack(toast_items, theme~, width=main_width),
        banner(
          "Connection interrupted",
          "Changes are queued until the host service reconnects.",
          tone=@views.FeedbackTone::Warning,
          action=Some(action),
          theme~,
          width=main_width,
        ),
        callout(
          "Tip",
          "Use callouts for contextual guidance without adding a modal.",
          tone=@views.FeedbackTone::Info,
          theme~,
          width=main_width,
        ),
        inline_error(
          "Email is already used by another workspace member.",
          action=Some(action),
          theme~,
          width=main_width,
        ),
        progress_status(
          "Exporting report",
          value=0.62,
          message="Preparing CSV rows from the current filter.",
          status="Running",
          action=Some(
            @views.StateViewAction::new(label="Cancel", message=ToggleActive),
          ),
          theme~,
          width=main_width,
        ),
        grid(
          [
            empty_state(
              "No files",
              "Drop files here or open a picker.",
              action=Some(action),
              theme~,
              width=card_width,
            ),
            loading_state(
              title="Loading preview",
              message="The app model owns async state.",
              theme~,
              width=card_width,
            ),
            error_state(
              "Import failed",
              "The selected file could not be read.",
              action=Some(action),
              theme~,
              width=card_width,
            ),
            stat_card(
              "Completed",
              "18",
              caption="Tasks today",
              tone=@views.FeedbackTone::Success,
              theme~,
              width=card_width,
            ),
          ],
          columns~,
          row_spacing=theme.spacing_scale.md,
          column_spacing=theme.spacing_scale.md,
        ),
        text(
          "Status Badge",
          role=@views.TextRole::Control,
          theme~,
          width=main_width,
          height=24.0,
        ),
        badges,
        accordion(
          [
            @views.WizardStep::new(
              id="details",
              title="Disclosure Details",
              subtitle="Controlled by app state",
              content=text(
                "Expanded content stays in the view tree.",
                width=320.0,
                height=28.0,
              ),
            ),
            @views.WizardStep::new(
              id="queue",
              title="Queue Status",
              subtitle="Collapsed until selected",
              content=text(
                "Queued notifications remain app-owned.",
                width=320.0,
                height=28.0,
              ),
            ),
          ],
          expanded=if self.active { ["details", "queue"] } else { ["details"] },
          on_toggle=_id => ToggleActive,
          theme~,
          width=main_width,
        ),
        disclosure(
          "Inline Disclosure",
          content=text("Inline disclosure content", width=300.0, height=28.0),
          expanded=true,
          on_toggle=ToggleActive,
          subtitle="No renderer changes",
          theme~,
          width=main_width,
        ),
        collapsible_panel(
          "Collapsible Panel",
          content=text(
            "Panel content remains controlled by the app.",
            width=320.0,
            height=28.0,
          ),
          expanded=self.active,
          on_toggle=ToggleActive,
          subtitle="Collapsed when inactive",
          theme~,
          width=main_width,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ).frame(width=main_width),
    metrics~,
  )
}
