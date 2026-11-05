///|
priv enum ShowcaseDevtoolsProbeMsg {
  ShowcaseDevtoolsToggle
}

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
  let probe = @runtime.AppRuntime::new_program(
    program=@moui.Program::new(
      init=() => (false, @moui.Effect::none()),
      update=(model, message) => {
        match message {
          ShowcaseDevtoolsToggle => (!model, @moui.Effect::none())
        }
      },
      view=model => {
        let label = if model { "Trace: On" } else { "Trace: Off" }
        @views.column(
          [
            @views.button(
              label,
              on_click=ShowcaseDevtoolsToggle,
              width=120.0,
              height=40.0,
            ),
            @views.button(
              label,
              on_click=ShowcaseDevtoolsToggle,
              width=120.0,
              height=40.0,
            ),
          ],
          spacing=0.0,
        )
      },
    ),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  ignore(probe.draw_frame())
  let trace = @moui_devtools.DevtoolsTrace::new(
    capacity=8,
    semantics_diff_limit=16,
  )
  ignore(trace.record(probe.inspector_snapshot()))
  for phase in [@core.PointerPhase::Down, @core.PointerPhase::Up] {
    ignore(
      probe.dispatch_pointer_input(
        @core.PointerEvent::new(
          position=@core.Point::new(x=12.0, y=12.0),
          phase~,
        ),
      ),
    )
  }
  let clock = Ref(0.0)
  let profiled = probe.profile_draw_frame(() => {
    clock.val = clock.val + 1.0
    clock.val
  })
  let snapshot = probe.inspector_snapshot()
  ignore(trace.record_frame(snapshot, timing=profiled.timing()))
  @diagnostics.ShowcaseDevToolsReport::new(
    summary_text=@moui_devtools.snapshot_summary(snapshot).text(),
    report_text=@moui_devtools.inspector_report_text(snapshot) +
      "\n\n" +
      @moui_devtools.trace_report_text(trace),
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
        Partial | Gap => true
        _ => false
      }
    })
    let priority = if gap_or_partial {
      @diagnostics.ShowcaseCapabilityPriority::GapOrPartial
    } else if entry.needs_follow_up() {
      FollowUp
    } else {
      Complete
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
