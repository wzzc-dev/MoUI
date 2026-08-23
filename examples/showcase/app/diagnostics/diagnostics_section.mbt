///|
priv struct ShowcaseInspectorSnapshot {
  runtime : ShowcaseRuntimeInspectorSnapshot
  view_tree : ShowcaseViewTreeInspectorSnapshot
  layout : ShowcaseLayoutInspectorSnapshot
  render : ShowcaseRenderInspectorSnapshot
  semantics : ShowcaseSemanticsInspectorSnapshot
}

///|
priv struct ShowcaseRuntimeInspectorSnapshot {
  dirty_state : ShowcaseDirtyStateSummary
  program_dispatched_count : Int
  program_update_count : Int
  program_effect_plan_count : Int
  program_effect_run_count : Int
  active_effect_task_count : Int
  completed_effect_task_count : Int
  cancelled_effect_task_count : Int
  scheduled_effect_label : String
  duplicate_effect_keys : Array[String]
  program_subscription_plan_count : Int
  subscription_source_count : Int
  duplicate_subscription_keys : Array[String]
  active_subscription_count : Int
  started_subscription_count : Int
  active_subscriptions : Array[String]
  active_subscription_kind_counts : Array[ShowcaseSubscriptionKindCount]
}

///|
priv struct ShowcaseDirtyStateSummary {
  dirty_count : Int
  reason : String
}

///|
priv struct ShowcaseSubscriptionKindCount {
  kind : String
  count : Int
}

///|
priv struct ShowcaseViewTreeInspectorSnapshot {
  node_count : Int
}

///|
priv struct ShowcaseLayoutInspectorSnapshot {
  bounds_count : Int
  max_depth : Int
}

///|
priv struct ShowcaseRenderInspectorSnapshot {
  command_count : Int
  text_count : Int
  clip_depth : Int
  open_clip_depth : Int
  layer_depth : Int
  open_layer_depth : Int
  filter_depth : Int
  open_filter_depth : Int
  unbalanced_pop_count : Int
}

///|
priv struct ShowcaseSemanticsInspectorSnapshot {
  node_count : Int
  invalid_count : Int
}

///|
fn ShowcaseModel::diagnostics_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
  let card_columns = showcase_grid_columns(
    metrics.body_width,
    metrics.compact,
    2,
  )
  let card_width = showcase_grid_card_width(
    metrics.body_width,
    card_columns,
    theme.spacing_scale.md,
  )
  section_panel(
    theme,
    "Diagnostics",
    "Input, text, renderer, and reusable example diagnostics stay grouped away from the main catalog.",
    column(
      [
        self.inspector_snapshot_card(theme, metrics.body_width),
        self.devtools_inspector_card(theme, metrics.body_width),
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
          ],
          columns=card_columns,
          row_spacing=theme.spacing_scale.md,
          column_spacing=theme.spacing_scale.md,
        ),
        grid(
          [
            layout_tile(theme, "Stack"),
            layout_tile(theme, "Grid"),
            layout_tile(theme, "Split"),
            visual_card(
              theme,
              showcase_image_source(),
              "Reference image",
              "img",
              width=if card_columns >= 2 { 200.0 } else { metrics.body_width },
            ),
          ],
          columns=if card_columns >= 2 { 2 } else { 1 },
          row_spacing=theme.spacing_scale.sm,
          column_spacing=theme.spacing_scale.sm,
        ),
        example_preview(
          theme,
          "Sample card",
          container(
            text("Preview content", width=260.0, height=60.0)
            .font(theme.typography.body)
            .foreground(theme.palette.foreground),
            width=280.0,
            height=100.0,
            variant=@views.ContainerVariant::Base,
            theme~,
            padding=theme.spacing_scale.sm,
          ).border(showcase_card_border(theme)),
          width=metrics.body_width,
        ),
      ],
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    ),
    metrics~,
    scroll_offset=self.diagnostics_panel_scroll,
    on_scroll=Some(offset => DiagnosticsPanelScrolled(offset)),
  )
}

///|
fn ShowcaseModel::inspector_snapshot_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
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
  let snapshot = showcase_inspector_snapshot(self.diagnostics_input.inspector)
  let runtime = snapshot.runtime
  let scope_caption = "Open scopes " +
    snapshot.render.open_clip_depth.to_string() +
    "/" +
    snapshot.render.open_layer_depth.to_string() +
    "/" +
    snapshot.render.open_filter_depth.to_string()
  let scheduled_effect_label = runtime.scheduled_effect_label
  let active_subscription_label = if runtime.active_subscriptions.length() > 0 {
    runtime.active_subscriptions[0]
  } else {
    "none"
  }
  let active_subscription_kinds = subscription_kind_count_summary(
    runtime.active_subscription_kind_counts,
  )
  let duplicate_effect_keys = if runtime.duplicate_effect_keys.length() > 0 {
    runtime.duplicate_effect_keys.join(", ")
  } else {
    "none"
  }
  let duplicate_subscription_keys = if runtime.duplicate_subscription_keys.length() >
    0 {
    runtime.duplicate_subscription_keys.join(", ")
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
              caption="Runtime element tree",
              theme~,
              width=stat_width,
              height=96.0,
            ),
            stat_card(
              "Layout bounds",
              snapshot.layout.bounds_count.to_string(),
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
              caption="Sources " + runtime.subscription_source_count.to_string(),
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
  counts : Array[ShowcaseSubscriptionKindCount],
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
  input : ShowcaseInspectorDiagnostics,
) -> ShowcaseInspectorSnapshot {
  {
    runtime: {
      dirty_state: { dirty_count: 0, reason: "redraw requested" },
      program_dispatched_count: 1,
      program_update_count: 1,
      program_effect_plan_count: 2,
      program_effect_run_count: 1,
      active_effect_task_count: 1,
      completed_effect_task_count: 0,
      cancelled_effect_task_count: 0,
      scheduled_effect_label: input.scheduled_effect_label,
      duplicate_effect_keys: input.duplicate_effect_keys,
      program_subscription_plan_count: 2,
      subscription_source_count: input.subscription_source_count,
      duplicate_subscription_keys: input.duplicate_subscription_keys,
      active_subscription_count: 2,
      started_subscription_count: 2,
      active_subscriptions: [input.active_subscription_label],
      active_subscription_kind_counts: [
        { kind: "animation", count: 1 },
        { kind: "host-event", count: 1 },
      ],
    },
    view_tree: { node_count: 6 },
    layout: { bounds_count: 3, max_depth: 3 },
    render: {
      command_count: 8,
      text_count: 3,
      clip_depth: 1,
      open_clip_depth: 0,
      layer_depth: 1,
      open_layer_depth: 0,
      filter_depth: 0,
      open_filter_depth: 0,
      unbalanced_pop_count: 0,
    },
    semantics: { node_count: 4, invalid_count: 1 },
  }
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
