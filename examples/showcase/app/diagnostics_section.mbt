///|
fn ShowcaseModel::diagnostics_section(
  self : ShowcaseModel,
  theme : @core.Theme,
  metrics : ShowcaseMetrics,
) -> @core.View[ShowcaseMsg] {
  let card_width = if metrics.compact { metrics.body_width } else { 300.0 }
  section_panel(
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
  let card_height = if stat_columns == 1 { 468.0 } else { 248.0 }
  let snapshot = showcase_inspector_snapshot(theme)
  let scope_caption = "Open scopes " +
    snapshot.render.open_clip_depth.to_string() +
    "/" +
    snapshot.render.open_layer_depth.to_string() +
    "/" +
    snapshot.render.open_filter_depth.to_string()
  showcase_soft_card(
    theme,
    column(
      [
        text("Inspector Snapshot", width=inner_width, height=28.0)
        .font(theme.typography.control)
        .foreground(theme.palette.foreground),
        text(
          "View/component summary, layout bounds, semantics, and dirty reasons",
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
        text(
          "Dirty: " + snapshot.runtime.rebuild_reason,
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
fn showcase_inspector_snapshot(theme : @core.Theme) -> @core.InspectorSnapshot {
  let runtime = @core.AppRuntime::new_view(
    root=surface(
        column(
          [
            text("Inspector sample", theme~, width=150.0, height=24.0),
            button(
              "Inspect",
              on_click=ToggleActive,
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
        height=76.0,
        variant=@views.SurfaceVariant::Base,
        theme~,
        padding=theme.spacing_scale.sm,
      )
      .semantics_invalid(invalid=true)
      .semantics_description("Inspector sample surface"),
    size=@core.Size::new(width=220.0, height=120.0),
  )
  runtime.inspector_snapshot()
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
