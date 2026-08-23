///|
pub fn diagnostics_input(
  host_summary : @host.HostCapabilitySummary,
  renderer_providers : Array[@render.RendererProvider],
) -> @diagnostics.ShowcaseDiagnosticsInput {
  @diagnostics.ShowcaseDiagnosticsInput::new(
    host={
      label: host_summary.label,
      backend_label: host_summary.backend.label(),
      service_count: host_summary.service_count(),
      service_capacity: 5,
      service_labels: host_summary.services.enabled_labels(),
      input_count: host_summary.input_count(),
      input_capacity: 7,
      input_labels: host_summary.input.enabled_labels(),
      multi_window: host_summary.multi_window,
      window_lifecycle: host_summary.window_lifecycle,
    },
    renderer_features=renderer_diagnostics(renderer_providers),
    inspector=inspector_diagnostics(),
    devtools=devtools_report(),
  )
}

///|
fn devtools_report() -> @diagnostics.ShowcaseDevToolsReport {
  let probe = @runtime.new_view(
    root=(
      @views.padding(@views.text("DevTools Inspector probe"), 12.0) :
      @moui.View[Unit]),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  ignore(probe.draw_commands())
  ignore(
    probe.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=16.0, y=16.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  let snapshot = probe.inspector_snapshot()
  @diagnostics.ShowcaseDevToolsReport::new(
    summary_text=@moui_devtools.snapshot_summary(snapshot).text(),
    report_text=@moui_devtools.inspector_report_text(snapshot),
    json_text=@moui_devtools.snapshot_report_json(snapshot, indent=2),
  )
}

///|
fn renderer_diagnostics(
  providers : Array[@render.RendererProvider],
) -> Array[@diagnostics.ShowcaseRendererFeatureDiagnostic] {
  @render_common.renderer_feature_capability_report(providers).map(entry => {
    let gap_or_partial = entry.providers.any(provider => {
      match provider.status {
        @render.RendererFeatureStatus::Partial
        | @render.RendererFeatureStatus::Gap => true
        _ => false
      }
    })
    let priority = if gap_or_partial {
      @diagnostics.ShowcaseCapabilityPriority::GapOrPartial
    } else if entry.needs_follow_up() {
      @diagnostics.ShowcaseCapabilityPriority::FollowUp
    } else {
      @diagnostics.ShowcaseCapabilityPriority::Complete
    }
    {
      feature_label: entry.feature.label(),
      providers: entry.providers.map(provider => {
        provider_id: provider.provider_id,
        status_label: provider.status.label(),
        needs_follow_up: provider.status.needs_follow_up(),
      }),
      priority,
    }
  })
}

///|
fn inspector_diagnostics() -> @diagnostics.ShowcaseInspectorDiagnostics {
  let effect : @moui.Effect[Unit] = @moui.Effect::batch([
    @moui.Effect::run(
      key="diagnostics:boot",
      kind="inspector",
      label="Inspector boot",
      run=dispatch => dispatch(()),
    ),
    @moui.Effect::task(
      key="diagnostics:task",
      kind="inspector",
      label="Inspector task",
      start=_dispatch => Some(() => ()),
    ),
  ])
  let effect_summary = @runtime.effect_plan_summary(effect)
  let subscriptions : @moui.Subscription[Unit] = @moui.Subscription::batch([
    @moui.Subscription::animation_tick(
      key="diagnostics:tick",
      label="Inspector tick",
      start=_dispatch => Some(() => ()),
    ),
    @moui.Subscription::animation_tick(
      key="diagnostics:tick",
      label="Duplicate tick ignored",
      start=_dispatch => Some(() => ()),
    ),
    @moui.Subscription::host_event(
      key="diagnostics:host",
      label="Inspector host event",
      start=_dispatch => Some(() => ()),
    ),
  ])
  let subscription_summary = @runtime.subscription_plan_summary(subscriptions)
  {
    scheduled_effect_label: match effect_summary.descriptors() {
      [descriptor, ..] => descriptor.label()
      [] => "none"
    },
    duplicate_effect_keys: effect_summary.duplicate_descriptor_keys(),
    subscription_source_count: subscription_summary.source_count(),
    active_subscription_label: match subscription_summary.descriptors() {
      [descriptor, ..] => descriptor.label()
      [] => "none"
    },
    duplicate_subscription_keys: subscription_summary.duplicate_keys(),
  }
}
