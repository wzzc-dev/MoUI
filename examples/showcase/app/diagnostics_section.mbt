///|
fn ShowcaseModel::diagnostics_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  let card_width = if metrics.compact { metrics.body_width } else { 300.0 }
  self.section_panel(
    theme,
    "Diagnostics",
    "Input, text, renderer, and reusable example diagnostics stay grouped away from the main catalog.",
    column(
      [
        self.inspector_snapshot_card(theme, metrics.body_width),
        grid(
          [
            self.diagnostics_route_card(
              theme, "Interaction Lab", "Tooltip, file drop, focus trap, gestures, variants, image lifecycle",
              "interaction-lab", card_width,
            ),
            self.diagnostics_route_card(
              theme, "Text Diagnostics", "CJK, bidi, emoji, wrapping, Markdown and rich text samples",
              "text-diagnostics", card_width,
            ),
            self.diagnostics_route_card(
              theme, "Advanced Rendering", "Layer, blend, filter, shader, path, transform and opacity commands",
              "advanced-rendering", card_width,
            ),
            self.diagnostics_route_card(
              theme, "Examples", "Counter and Todo reusable app patterns before dedicated examples land",
              "examples", card_width,
            ),
          ],
          columns=if metrics.compact { 1 } else { 2 },
          row_spacing=theme.spacing_scale.md,
          column_spacing=theme.spacing_scale.md,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    metrics~,
  )
}

///|
fn ShowcaseModel::inspector_snapshot_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  width : Double,
) -> @core.View[ShowcaseMsg] {
  ignore(self)
  let inner_width = max_showcase_double(180.0, width - 32.0)
  let stat_columns = if inner_width < 520.0 { 1 } else { 4 }
  let stat_width = if stat_columns == 1 {
    inner_width
  } else {
    max_showcase_double(
      140.0,
      (inner_width - theme.spacing_scale.sm * 3.0) / 4.0,
    )
  }
  let card_height = if stat_columns == 1 { 930.0 } else { 478.0 }
  let snapshot = showcase_inspector_snapshot(theme)
  let runtime = snapshot.runtime
  let scope_caption = "Open scopes " +
    snapshot.render.open_clip_depth.to_string() +
    "/" +
    snapshot.render.open_layer_depth.to_string() +
    "/" +
    snapshot.render.open_filter_depth.to_string()
  let scheduled_effect_label = if runtime.last_scheduled_effect_summary.descriptors.length() >
    0 {
    runtime.last_scheduled_effect_summary.descriptors[0].label
  } else {
    "none"
  }
  let active_subscription_label = if runtime.active_subscriptions.length() > 0 {
    runtime.active_subscriptions[0].label
  } else {
    "none"
  }
  let active_subscription_kinds = subscription_kind_count_summary(
    runtime.active_subscription_kind_counts,
  )
  let duplicate_effect_keys = if runtime.last_scheduled_effect_summary.duplicate_descriptor_keys.length() >
    0 {
    runtime.last_scheduled_effect_summary.duplicate_descriptor_keys.join(", ")
  } else {
    "none"
  }
  let duplicate_subscription_keys = if runtime.last_subscription_plan_summary.duplicate_keys.length() >
    0 {
    runtime.last_subscription_plan_summary.duplicate_keys.join(", ")
  } else {
    "none"
  }
  showcase_soft_card(
    theme,
    column(
      [
        text("Inspector Snapshot", width=inner_width, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        text(
          "View/component, TEA runtime, layout, semantics, and dirty reasons",
          width=inner_width,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        grid(
          [
            stat_card(
              "View nodes",
              snapshot.view_tree.node_count.to_string(),
              caption="Components " +
                snapshot.view_tree.component_count.to_string(),
              theme~,
              width=stat_width,
              height=96.0,
            ),
            stat_card(
              "Layout bounds",
              snapshot.layout.bounds.length().to_string(),
              caption="Max depth " + snapshot.layout.max_depth.to_string(),
              theme~,
              width=stat_width,
              height=96.0,
            ),
            stat_card(
              "Semantics nodes",
              snapshot.semantics.node_count.to_string(),
              caption="Invalid " + snapshot.semantics.invalid_count.to_string(),
              theme~,
              width=stat_width,
              height=96.0,
            ),
            stat_card(
              "Render commands",
              snapshot.render.command_count.to_string(),
              caption="Text " + snapshot.render.text_count.to_string(),
              theme~,
              width=stat_width,
              height=96.0,
            ),
          ],
          columns=stat_columns,
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.sm,
        ),
        grid(
          [
            stat_card(
              "Program messages",
              runtime.program_dispatched_count.to_string(),
              caption="Updates " + runtime.program_update_count.to_string(),
              theme~,
              width=stat_width,
              height=96.0,
            ),
            stat_card(
              "Effect runs",
              runtime.program_effect_run_count.to_string(),
              caption="Plans " + runtime.program_effect_plan_count.to_string(),
              theme~,
              width=stat_width,
              height=96.0,
            ),
            stat_card(
              "Subscription plans",
              runtime.program_subscription_plan_count.to_string(),
              caption="Sources " +
                runtime.last_subscription_plan_summary.source_count.to_string(),
              theme~,
              width=stat_width,
              height=96.0,
            ),
            stat_card(
              "Active subscriptions",
              runtime.active_subscription_count.to_string(),
              caption="Started " +
                runtime.started_subscription_count.to_string(),
              theme~,
              width=stat_width,
              height=96.0,
            ),
          ],
          columns=stat_columns,
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.sm,
        ),
        text(
          "Dirty: " +
          snapshot.runtime.dirty_state.reason +
          "; elements " +
          snapshot.runtime.dirty_state.dirty_count.to_string(),
          width=inner_width,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.primary),
        text(
          "Render scopes: max clip/layer/filter " +
          snapshot.render.clip_depth.to_string() +
          "/" +
          snapshot.render.layer_depth.to_string() +
          "/" +
          snapshot.render.filter_depth.to_string() +
          "; " +
          scope_caption +
          "; unbalanced pops " +
          snapshot.render.unbalanced_pop_count.to_string(),
          width=inner_width,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(
          "TEA subscriptions: messages " +
          runtime.program_dispatched_count.to_string() +
          "; effect runs " +
          runtime.program_effect_run_count.to_string() +
          "; subscription plans " +
          runtime.program_subscription_plan_count.to_string() +
          "; active " +
          runtime.active_subscription_count.to_string() +
          "; kinds " +
          active_subscription_kinds,
          width=inner_width,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(
          "TEA tasks: active " +
          runtime.active_effect_task_count.to_string() +
          "; completed " +
          runtime.completed_effect_task_count.to_string() +
          "; cancelled " +
          runtime.cancelled_effect_task_count.to_string(),
          width=inner_width,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(
          "TEA descriptors: effect " +
          scheduled_effect_label +
          "; subscription " +
          active_subscription_label,
          width=inner_width,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(
          "TEA duplicate keys: effects " +
          duplicate_effect_keys +
          "; subscriptions " +
          duplicate_subscription_keys,
          width=inner_width,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=card_height,
    padding=theme.spacing_scale.md,
  )
}

///|
fn subscription_kind_count_summary(
  counts : Array[@core.SubscriptionKindCount],
) -> String {
  if counts.length() == 0 {
    "none"
  } else {
    let parts : Array[String] = []
    for count in counts {
      parts.push(count.kind + " " + count.count.to_string())
    }
    parts.join(", ")
  }
}

///|
fn showcase_inspector_snapshot(theme : @core.Theme) -> @core.InspectorSnapshot {
  let runtime = @runtime.AppRuntime::new_program(
    program=diagnostics_inspector_sample_program(theme),
    size=@core.Size::new(width=220.0, height=120.0),
  )
  runtime.inspector_snapshot()
}

///|
priv struct DiagnosticsInspectorSampleModel {
  event_count : Int
}

///|
priv enum DiagnosticsInspectorSampleMsg {
  DiagnosticsInspectorSampleBooted
}

///|
fn diagnostics_inspector_sample_program(
  theme : @core.Theme,
) -> @core.Program[
  DiagnosticsInspectorSampleModel,
  DiagnosticsInspectorSampleMsg,
] {
  @core.Program::new_with_environment(
    init=() => {
      (
        { event_count: 0 },
        @core.Effect::batch([
          @core.Effect::run(
            key="diagnostics:boot",
            kind="inspector",
            label="Inspector boot",
            run=dispatch => dispatch(DiagnosticsInspectorSampleBooted),
          ),
          @core.Effect::task(
            key="diagnostics:task",
            kind="inspector",
            label="Inspector task",
            start=_dispatch => Some(() => ()),
          ),
        ]),
      )
    },
    update=(model, message) => {
      match message {
        DiagnosticsInspectorSampleBooted =>
          ({ event_count: model.event_count + 1 }, @core.Effect::none())
      }
    },
    view=(model, _env) => {
      surface(
        column(
          [
            text("Inspector sample", theme~, width=150.0, height=24.0),
            text(
              "Program events: " + model.event_count.to_string(),
              theme~,
              width=150.0,
              height=22.0,
            ),
            button(
              "Inspect",
              on_click=DiagnosticsInspectorSampleBooted,
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=112.0,
              height=34.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Start,
        ),
        width=180.0,
        height=104.0,
        variant=@views.SurfaceVariant::Base,
        theme~,
        padding=theme.spacing_scale.sm,
      )
      .semantics_invalid(invalid=true)
      .semantics_description("Inspector sample surface")
    },
    subscriptions=model => {
      if model.event_count > 0 {
        @core.Subscription::batch([
          @core.Subscription::animation_tick(
            key="diagnostics:tick",
            label="Inspector tick",
            start=_dispatch => Some(() => ()),
          ),
          @core.Subscription::animation_tick(
            key="diagnostics:tick",
            label="Duplicate tick ignored",
            start=_dispatch => Some(() => ()),
          ),
          @core.Subscription::host_event(
            key="diagnostics:host",
            label="Inspector host event",
            start=_dispatch => Some(() => ()),
          ),
        ])
      } else {
        @core.Subscription::none()
      }
    },
  )
}

///|
fn ShowcaseModel::diagnostics_route_card(
  self : ShowcaseModel,
  theme : @core.Theme,
  title : String,
  summary : String,
  route : String,
  width : Double,
) -> @core.View[ShowcaseMsg] {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text(title, width=width - 32.0, height=24.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        text(summary, width=width - 32.0, height=54.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        button(
          "Open",
          on_click=SelectSection(route),
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=110.0,
          height=34.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=144.0,
    padding=theme.spacing_scale.md,
  )
}
