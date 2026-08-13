///|
fn probe_semantic_id(value : String) -> @moui.SemanticId {
  @moui.SemanticId::parse(value).unwrap()
}

///|
/// Stable fixture consumed by L1 contracts and native accessibility clients.
fn accessibility_probe(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let tree_items = [
    @views.tree_item(id="root", label="Project", children=[
      @views.tree_item(id="child", label="README"),
    ]),
  ]
  component_demo_section(
    "Accessibility Probe",
    "Stable cross-platform fixture for native accessibility and Agent evidence.",
    column(
      [
        button(
          "Open probe dialog",
          on_click=ProbeDialogOpen,
          theme~,
          width=180.0,
        ).semantic_id(probe_semantic_id("a11y.button")),
        checkbox(
          "Enable feature",
          checked=model.feature_enabled,
          on_change=value => ProbeFeatureToggled(value),
          theme~,
        ).semantic_id(probe_semantic_id("a11y.checkbox")),
        @views.slider(
          model.slider_value,
          min=0.0,
          max=1.0,
          step=0.1,
          label="Coverage",
          value_text="\{(model.slider_value * 100.0).to_int()} percent",
          width=inner,
          on_change=Some(value => ProbeSliderChanged(value)),
        ).semantic_id(probe_semantic_id("a11y.slider")),
        text_field(
          model.probe_text,
          on_input=value => ProbeTextChanged(value),
          on_submit=Some(ProbeSubmit),
          placeholder="Probe text",
          theme~,
          width=inner,
        ).semantic_id(probe_semantic_id("a11y.textfield")),
        if model.probe_dialog_open {
          @views.dialog(
            "Probe dialog",
            content=text("Dialog body", theme~, width=inner.min(320.0)),
            primary_action=Some(
              @views.StateViewAction::new(
                label="Done",
                message=ProbeDialogClose,
              ),
            ),
            dismiss_action=Some(
              @views.StateViewAction::new(
                label="Dismiss",
                message=ProbeDialogClose,
              ),
            ),
            width=inner.min(420.0),
            height=200.0,
            theme~,
          )
          .semantics_state(modal=true)
          .focus_trap()
          .key("a11y.dialog")
          .semantic_id(probe_semantic_id("a11y.dialog"))
        } else {
          @views.empty()
        },
        @views.tree_view(
          tree_items,
          expanded=["root"],
          selected="child",
          on_select=Some(_id => ProbeAction),
          on_toggle=Some(_id => ProbeAction),
          theme~,
          width=inner,
        )
        .semantics_collection(
          @core.SemanticsCollectionInfo::new(set_size=2, set_position=1),
        )
        .semantic_id(probe_semantic_id("a11y.tree")),
        responsive_grid(
          [
            text("A1", theme~, width=96.0).semantics_role(
              @core.SemanticsRole::Cell,
            ),
            text("B1", theme~, width=96.0).semantics_role(
              @core.SemanticsRole::Cell,
            ),
          ],
          width=inner,
          min_column_width=96.0,
        )
        .semantics_role(@core.SemanticsRole::Grid)
        .semantics_collection(
          @core.SemanticsCollectionInfo::new(row_count=1, column_count=2),
        )
        .semantic_id(probe_semantic_id("a11y.grid")),
        scroll_view(
          column(
            [text("Scrollable content", theme~, width=inner - 16.0)],
            spacing=4.0,
          ),
          width=inner,
          height=72.0,
          shows_indicator=true,
          on_scroll=Some(_offset => ProbeAction),
        )
        .accessibility_label("Probe scroll area")
        .semantic_id(probe_semantic_id("a11y.scroll")),
        text("Actions: \{model.probe_action_count}", theme~, width=inner)
        .semantics_role(@core.SemanticsRole::Status)
        .semantics_live(@core.SemanticsLive::Polite, live_atomic=true)
        .semantic_id(probe_semantic_id("a11y.status")),
        text("Probe alert", theme~, width=inner)
        .semantics_role(@core.SemanticsRole::Alert)
        .semantics_live(@core.SemanticsLive::Assertive, live_atomic=true)
        .semantic_id(probe_semantic_id("a11y.alert")),
        @views.image(
          "assets/moonbit.svg",
          width=64.0,
          height=64.0,
          accessibility_label="MoonBit logo",
        ).semantic_id(probe_semantic_id("a11y.image")),
        @views.divider(theme~, inset=0.0).semantic_id(
          probe_semantic_id("a11y.separator"),
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    theme,
    width,
  )
}
