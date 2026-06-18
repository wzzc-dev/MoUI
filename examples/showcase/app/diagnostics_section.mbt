///|
fn ShowcaseModel::diagnostics_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
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
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
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
    runtime.last_scheduled_effect_summary.descriptors[0].label()
  } else {
    "none"
  }
  let active_subscription_label = if runtime.active_subscriptions.length() > 0 {
    runtime.active_subscriptions[0].label()
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
  counts : Array[@runtime.SubscriptionKindCount],
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
fn showcase_inspector_snapshot(
  theme : @moui.Theme,
) -> @runtime.InspectorSnapshot {
  ignore(theme)
  let effect_summary = showcase_inspector_effect_summary()
  let subscription_summary = showcase_inspector_subscription_summary()
  let no_effect : @moui.Effect[ShowcaseMsg] = @moui.Effect::none()
  let no_effect_summary = @runtime.effect_plan_summary(no_effect)
  let dirty_state = @runtime.RuntimeDirtyStateSummary::{
    dirty_count: 0,
    dirty_element_ids: [],
    dirty_build_count: 0,
    dirty_build_element_ids: [],
    dirty_layout_count: 0,
    dirty_layout_element_ids: [],
    dirty_paint_count: 0,
    dirty_paint_element_ids: [],
    needs_rebuild: false,
    needs_layout: false,
    needs_paint: false,
    needs_redraw: true,
    has_pending_work: true,
    reason: "redraw requested",
    reasons: ["redraw requested"],
    damage_kind: "full",
    damage_rect_count: 0,
    damage_full_reason: "redraw requested",
    cache_epoch: 1,
    cached_layer_count: 0,
  }
  @runtime.InspectorSnapshot::{
    runtime: @runtime.RuntimeInspectorSnapshot::{
      size: @moui.Size::new(width=220.0, height=120.0),
      dirty_count: 0,
      dirty_element_ids: [],
      dirty_build_count: 0,
      dirty_build_element_ids: [],
      dirty_layout_count: 0,
      dirty_layout_element_ids: [],
      dirty_paint_count: 0,
      dirty_paint_element_ids: [],
      dirty_state,
      needs_rebuild: false,
      needs_layout: false,
      needs_paint: false,
      needs_redraw: true,
      draw_command_count: 8,
      rebuild_pass_count: 1,
      layout_pass_count: 1,
      paint_pass_count: 1,
      draw_command_build_count: 1,
      program_dispatched_count: 1,
      program_update_count: 1,
      ignored_program_dispatch_count: 0,
      program_message_enqueue_count: 1,
      program_message_drain_count: 1,
      program_pending_message_count: 0,
      program_max_pending_message_count: 1,
      program_effect_plan_count: 2,
      program_effect_count: 2,
      program_effect_none_count: 1,
      program_effect_batch_count: 1,
      program_effect_send_count: 0,
      program_effect_dispatch_count: 0,
      program_effect_run_count: 1,
      program_effect_task_count: 1,
      duplicate_effect_descriptor_key_count: 0,
      duplicate_effect_descriptor_keys: [],
      last_effect_summary: no_effect_summary,
      last_scheduled_effect_summary: effect_summary,
      active_effect_task_count: 1,
      started_effect_task_count: 1,
      completed_effect_task_count: 0,
      cancelled_effect_task_count: 0,
      ignored_effect_task_dispatch_count: 0,
      active_effect_tasks: [effect_summary.descriptors[1]],
      effect_task_lifecycle: [
        @runtime.EffectTaskLifecycleSnapshot::{
          key: "diagnostics:task",
          kind: "inspector",
          label: "Inspector task",
          status: @runtime.EffectTaskLifecycleStatus::EffectTaskActive,
          cancel_reason: None,
        },
      ],
      program_subscription_plan_count: 2,
      last_subscription_plan_summary: subscription_summary,
      active_subscription_count: 2,
      started_subscription_count: 2,
      reused_subscription_count: 0,
      cancelled_subscription_count: 0,
      duplicate_subscription_key_count: 1,
      duplicate_subscription_keys: ["diagnostics:tick"],
      ignored_subscription_dispatch_count: 0,
      active_subscriptions: [
        subscription_summary.descriptors[0],
        subscription_summary.descriptors[2],
      ],
      active_subscription_kind_counts: [
        @runtime.SubscriptionKindCount::{ kind: "animation", count: 1 },
        @runtime.SubscriptionKindCount::{ kind: "host-event", count: 1 },
      ],
      subscription_lifecycle: [
        @runtime.SubscriptionLifecycleSnapshot::{
          key: "diagnostics:tick",
          kind: "animation",
          label: "Inspector tick",
          status: @runtime.SubscriptionLifecycleStatus::SubscriptionActive,
          cancel_reason: None,
        },
        @runtime.SubscriptionLifecycleSnapshot::{
          key: "diagnostics:host",
          kind: "host-event",
          label: "Inspector host event",
          status: @runtime.SubscriptionLifecycleStatus::SubscriptionActive,
          cancel_reason: None,
        },
      ],
      rebuild_reason: "redraw requested",
      dirty_reasons: ["redraw requested"],
    },
    view_tree: @runtime.ViewTreeInspectorSnapshot::{
      root_kind: "component",
      node_count: 6,
      component_count: 1,
      control_count: 2,
      modified_count: 1,
      dirty_build_count: 0,
      dirty_layout_count: 0,
      dirty_paint_count: 0,
      nodes: [
        @runtime.ViewInspectorSummary::{
          element_id: @core.ElementId::new(1),
          kind: "component",
          key: "inspector-root",
          child_count: 1,
          needs_build: false,
          needs_layout: false,
          needs_paint: false,
        },
        @runtime.ViewInspectorSummary::{
          element_id: @core.ElementId::new(2),
          kind: "surface",
          key: "inspector-surface",
          child_count: 1,
          needs_build: false,
          needs_layout: false,
          needs_paint: false,
        },
        @runtime.ViewInspectorSummary::{
          element_id: @core.ElementId::new(3),
          kind: "column",
          key: "inspector-column",
          child_count: 3,
          needs_build: false,
          needs_layout: false,
          needs_paint: false,
        },
      ],
    },
    layout: @runtime.LayoutInspectorSnapshot::{
      root_frame: @core.Rect::new(x=0.0, y=0.0, width=220.0, height=120.0),
      node_count: 6,
      leaf_count: 3,
      max_depth: 3,
      bounds: [
        @runtime.LayoutBoundsInspectorEntry::{
          element_id: @core.ElementId::new(1),
          frame: @core.Rect::new(x=0.0, y=0.0, width=220.0, height=120.0),
          depth: 0,
          child_count: 1,
        },
        @runtime.LayoutBoundsInspectorEntry::{
          element_id: @core.ElementId::new(2),
          frame: @core.Rect::new(x=8.0, y=8.0, width=180.0, height=104.0),
          depth: 1,
          child_count: 1,
        },
        @runtime.LayoutBoundsInspectorEntry::{
          element_id: @core.ElementId::new(3),
          frame: @core.Rect::new(x=16.0, y=16.0, width=150.0, height=80.0),
          depth: 2,
          child_count: 3,
        },
      ],
    },
    render: @runtime.RenderInspectorSnapshot::{
      command_count: 8,
      text_count: 3,
      image_count: 0,
      clip_depth: 1,
      open_clip_depth: 0,
      layer_depth: 1,
      open_layer_depth: 0,
      filter_depth: 0,
      open_filter_depth: 0,
      path_count: 0,
      shader_count: 0,
      unbalanced_pop_count: 0,
    },
    semantics: @runtime.SemanticsInspectorSnapshot::{
      root_role: @core.SemanticsRole::Group,
      node_count: 4,
      focusable_count: 1,
      action_count: 1,
      max_depth: 3,
      selected_count: 0,
      checked_count: 0,
      expanded_count: 0,
      invalid_count: 1,
      required_count: 0,
      described_count: 1,
    },
  }
}

///|
fn showcase_inspector_effect_summary() -> @runtime.EffectPlanSummary {
  let effect : @moui.Effect[ShowcaseMsg] = @moui.Effect::batch([
    @moui.Effect::run(
      key="diagnostics:boot",
      kind="inspector",
      label="Inspector boot",
      run=dispatch => dispatch(ToggleActive),
    ),
    @moui.Effect::task(
      key="diagnostics:task",
      kind="inspector",
      label="Inspector task",
      start=_dispatch => Some(() => ()),
    ),
  ])
  @runtime.effect_plan_summary(effect)
}

///|
fn showcase_inspector_subscription_summary() -> @runtime.SubscriptionPlanSummary {
  let subscriptions : @moui.Subscription[ShowcaseMsg] = @moui.Subscription::batch([
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
    ],
  )
  @runtime.subscription_plan_summary(subscriptions)
}

///|
fn ShowcaseModel::diagnostics_route_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  title : String,
  summary : String,
  route : String,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
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
