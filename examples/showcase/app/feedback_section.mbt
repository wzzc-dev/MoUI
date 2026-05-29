///|
fn ShowcaseModel::feedback_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  let action = @views.StateViewAction::new(label="Retry", message=ToggleActive)
  section_panel(
    theme,
    "Feedback",
    "Status, notification, badge, and empty-state components for app workflows.",
    column(
      [
        row(
          [
            toast(
              "Saved settings",
              tone=@views.FeedbackTone::Success,
              theme~,
              width=240.0,
            ),
            toast(
              "Sync warning",
              tone=@views.FeedbackTone::Warning,
              theme~,
              width=240.0,
            ),
          ],
          spacing=theme.spacing_scale.md,
          align=@views.CrossAlign::Start,
        ),
        banner(
          "Connection interrupted",
          "Changes are queued until the host service reconnects.",
          tone=@views.FeedbackTone::Warning,
          action=Some(action),
          theme~,
          width=520.0,
        ),
        callout(
          "Tip",
          "Use callouts for contextual guidance without adding a modal.",
          tone=@views.FeedbackTone::Info,
          theme~,
          width=520.0,
        ),
        grid(
          [
            empty_state(
              "No files",
              "Drop files here or open a picker.",
              action=Some(action),
              theme~,
              width=240.0,
            ),
            loading_state(
              title="Loading preview",
              message="The app model owns async state.",
              theme~,
              width=240.0,
            ),
            error_state(
              "Import failed",
              "The selected file could not be read.",
              action=Some(action),
              theme~,
              width=240.0,
            ),
            stat_card(
              "Completed",
              "18",
              caption="Tasks today",
              tone=@views.FeedbackTone::Success,
              theme~,
              width=180.0,
            ),
          ],
          columns=2,
          row_spacing=theme.spacing_scale.md,
          column_spacing=theme.spacing_scale.md,
        ),
        row(
          [
            @views.badge("Beta", tone=@views.BadgeTone::Accent, theme~),
            @views.badge("Ready", tone=@views.BadgeTone::Success, theme~),
            @views.badge("Queued", tone=@views.BadgeTone::Warning, theme~),
            @views.badge("Failed", tone=@views.BadgeTone::Danger, theme~),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Center,
        ),
        accordion(
          [
            @views.WizardStep::new(
              id="details",
              title="Disclosure Details",
              subtitle="Controlled by app state",
              content=text("Expanded content stays in the view tree.", width=320.0, height=28.0),
            ),
            @views.WizardStep::new(
              id="queue",
              title="Queue Status",
              subtitle="Collapsed until selected",
              content=text("Queued notifications remain app-owned.", width=320.0, height=28.0),
            ),
          ],
          expanded=if self.active { ["details", "queue"] } else { ["details"] },
          on_toggle=_id => ToggleActive,
          theme~,
          width=520.0,
        ),
        disclosure(
          "Inline Disclosure",
          content=text("Inline disclosure content", width=300.0, height=28.0),
          expanded=true,
          on_toggle=ToggleActive,
          subtitle="No renderer changes",
          theme~,
          width=520.0,
        ),
        collapsible_panel(
          "Collapsible Panel",
          content=text("Panel content remains controlled by the app.", width=320.0, height=28.0),
          expanded=self.active,
          on_toggle=ToggleActive,
          subtitle="Collapsed when inactive",
          theme~,
          width=520.0,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ).frame(width=metrics.body_width),
    metrics~,
  )
}
