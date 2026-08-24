///|
fn ShowcaseModel::interaction_lab_section(
  self : ShowcaseModel,
  theme : @moui.Theme,
  metrics : ShowcaseMetrics,
) -> @moui.View[ShowcaseMsg] {
  let card_width = if metrics.compact { metrics.body_width } else { 300.0 }
  self.section_panel(
    theme,
    "Interaction Lab",
    "Tooltip, file drop, focus, shortcuts, variants, and image lifecycle states.",
    grid(
      [
        self.tooltip_demo_card(theme, card_width),
        self.file_drop_card(theme, card_width, self.last_drop_label),
        self.focus_shortcut_card(theme, card_width),
        self.gesture_card(theme, card_width, self.gesture_label),
        self.popover_dropdown_card(theme, card_width),
        self.variant_gallery_card(theme, card_width),
        self.image_lifecycle_card(theme, card_width),
        self.dialog_demo_card(theme, card_width),
        self.sheet_demo_card(theme, card_width),
      ],
      columns=if metrics.compact { 1 } else { 2 },
      row_spacing=theme.spacing_scale.md,
      column_spacing=theme.spacing_scale.md,
    ),
    metrics~,
    eyebrow=showcase_route_eyebrow("interaction-lab"),
  )
}

///|
fn ShowcaseModel::tooltip_demo_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text("Tooltip", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        tooltip(
          button(
            "Hover target",
            variant=@views.ButtonVariant::Tonal,
            theme~,
            width=140.0,
          ),
          "Tooltip: Meta+K",
          visible=true,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=136.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::file_drop_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  drop_label : String,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  showcase_soft_card(
    theme,
    file_import_panel(
      selection=@views.FileSelection::new(paths=[]),
      on_drop=paths => RecordFileDrop(paths),
      on_browse=Some(RecordFileDrop([])),
      title="File Drop",
      drop_title="Drop files here",
      empty_message=drop_label,
      theme~,
      width=width - 32.0,
    ),
    width~,
    height=288.0,
    padding=theme.spacing_scale.sm,
  )
}

///|
fn ShowcaseModel::gesture_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
  gesture_label : String,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text("Gestures", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        container(
          text("Press, double tap, or drag", width=width - 64.0, height=24.0)
          .font(theme.typography.body)
          .foreground(theme.palette.foreground),
          width=width - 32.0,
          height=46.0,
          background=theme.palette.surface_variant.multiply_alpha(0.44),
          corner_radius=theme.radius_scale.sm,
          padding=8.0,
        )
        .on_long_press(RecordGesture("Long press"))
        .on_double_tap(RecordGesture("Double tap"))
        .on_drag(event => RecordGesture(event.phase.label())),
        text(gesture_label, width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=146.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::focus_shortcut_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  let focus_scope = @state.FocusScope::new(
    current=Some("name"),
    default_action="save",
    dismiss_action="cancel",
    items=[
      @state.FocusScopeItem::new(id="name"),
      @state.FocusScopeItem::new(id="archived", enabled=false),
      @state.FocusScopeItem::new(id="email"),
      @state.FocusScopeItem::new(id="save", focusable=false),
    ],
  )
  let validation_summary = @views.FormValidationSummary::from_errors([
    @views.FormFieldError::new(name="email", message="Email required"),
  ])
  showcase_soft_card(
    theme,
    column(
      [
        text("Focus + Shortcut", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        shortcut_button(
          "Focusable action",
          on_click=ToggleActive,
          shortcut=@views.KeyboardShortcut::new(
            key="k",
            modifiers=@views.KeyModifiers::new(meta=true),
          ),
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=260.0,
        ).focusable(),
        text("Keyboard shortcut: Meta+K", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        row(
          [
            focus_ring(
              text("Name field", width=82.0, height=22.0)
              .font(theme.typography.caption)
              .foreground(theme.palette.foreground),
              focused=true,
              label="Focus target: name",
              theme~,
              width=126.0,
              height=38.0,
            ),
            focus_ring(
              text("Email field", width=82.0, height=22.0)
              .font(theme.typography.caption)
              .foreground(theme.palette.foreground),
              focused=false,
              label="Focus target: email",
              theme~,
              width=126.0,
              height=38.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Center,
        ),
        text("Focus ring: name", width=width - 32.0, height=22.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        row(
          [
            button(
              "Pressed",
              variant=@views.ButtonVariant::Tonal,
              theme~,
              width=78.0,
              height=32.0,
            ).semantics_pressed(),
            button(
              "Selected",
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=82.0,
              height=32.0,
            ).semantics_selected(),
            button(
              "Disabled",
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=82.0,
              height=32.0,
            ).disabled(),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Center,
        ),
        text(
          "Semantic states: pressed selected disabled",
          width=width - 32.0,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text("Focus order: name -> email", width=width - 32.0, height=22.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        row(
          [
            button(
              "Trap A",
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=82.0,
              height=32.0,
            ).focusable(),
            button(
              "Trap B",
              variant=@views.ButtonVariant::Outline,
              theme~,
              width=82.0,
              height=32.0,
            ).focusable(),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Center,
        ).focus_trap(),
        text("Runtime trap: active", width=width - 32.0, height=22.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(
          "Tab next: " + focus_scope.next().unwrap_or("none"),
          width=width - 32.0,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(
          "First invalid: " +
          focus_scope
          .focus_target_or_first(validation_summary.first_invalid_id)
          .unwrap_or("none"),
          width=width - 32.0,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(
          "Enter target: " +
          focus_scope
          .command_target(@views.CommandIntent::Submit)
          .unwrap_or("none"),
          width=width - 32.0,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text(
          "Escape target: " +
          focus_scope
          .command_target(@views.CommandIntent::Cancel)
          .unwrap_or("none"),
          width=width - 32.0,
          height=22.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=412.0,
    padding=theme.spacing_scale.md,
  )
  .semantics_role(@core.SemanticsRole::Group)
  .accessibility_label("Focus scope keyboard rules")
}

///|
fn ShowcaseModel::popover_dropdown_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  let items = [
    menu_item(id="native", label="Native", message=PickerSelected("native")),
    menu_item(id="web", label="Web", message=PickerSelected("web")),
    menu_item(
      id="test",
      label="Test",
      message=PickerSelected("test"),
      enabled=false,
    ),
  ]
  showcase_soft_card(
    theme,
    column(
      [
        text("Popover + Dropdown", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        text(
          "Expanded semantics: selected + disabled options",
          width=width - 32.0,
          height=24.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        dropdown(
          "Renderer",
          items,
          state=@views.DropdownState::new(
            expanded=true,
            selected=self.picker_value,
          ),
          on_toggle=ToggleActive,
          theme~,
          width=width - 32.0,
          max_height=92.0,
        ),
        combobox(
          self.draft,
          on_input=value => DraftChanged(value),
          items,
          expanded=self.active,
          on_toggle=ToggleActive,
          placeholder="Combobox",
          theme~,
          width=width - 32.0,
          max_height=82.0,
        ),
        autocomplete(
          self.filter,
          on_input=value => FilterChanged(value),
          items,
          expanded=true,
          placeholder="Autocomplete",
          theme~,
          width=width - 32.0,
          max_height=82.0,
        ),
        overlay_host(
          button(
            "Inline popover",
            on_click=ToggleActive,
            variant=@views.ButtonVariant::Tonal,
            theme~,
            width=160.0,
          ),
          [
            PresentationSpec::new(
              id="interaction-popover",
              kind=PresentationKind::Popover,
              content=text("Popover content", width=160.0, height=24.0),
              anchor=PresentationAnchor::Viewport(
                @core.Point::new(x=0.0, y=0.0),
              ),
              placement=Some(PresentationPlacement::viewport()),
              presented=true,
            ),
          ],
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=334.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::variant_gallery_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  showcase_soft_card(
    theme,
    column(
      [
        text("Variants", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        row(
          [
            button(
              "Primary",
              variant=@views.ButtonVariant::Primary,
              theme~,
              width=82.0,
              height=34.0,
            ),
            button(
              "Tonal",
              variant=@views.ButtonVariant::Tonal,
              theme~,
              width=76.0,
              height=34.0,
            ),
            button(
              "Ghost",
              variant=@views.ButtonVariant::Ghost,
              theme~,
              width=76.0,
              height=34.0,
            ),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Center,
        ),
        text_field(
          self.draft,
          on_input=value => DraftChanged(value),
          placeholder="Outline",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=width - 32.0,
          height=36.0,
        ),
        text("Outline", width=width - 32.0, height=18.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text_field(
          self.draft,
          on_input=value => DraftChanged(value),
          placeholder="Plain",
          variant=@views.TextFieldVariant::Plain,
          theme~,
          width=width - 32.0,
          height=32.0,
        ),
        text("Plain", width=width - 32.0, height=18.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        row(
          [
            container_variant_tile(theme, "Base", @views.ContainerVariant::Base),
            container_variant_tile(
              theme,
              "Overlay",
              @views.ContainerVariant::Overlay,
            ),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=228.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn container_variant_tile(
  theme : @moui.Theme,
  label : String,
  variant : @views.ContainerVariant,
) -> @moui.View[ShowcaseMsg] {
  container(
    text(label, width=80.0, height=22.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.foreground),
    width=92.0,
    height=34.0,
    variant~,
    theme~,
    padding=6.0,
  )
}

///|
fn ShowcaseModel::image_lifecycle_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text("Image Lifecycle", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        row(
          [
            image_lifecycle_tile(theme, "Ready", showcase_image_source()),
            image_lifecycle_tile(theme, "Loading", ""),
            image_lifecycle_tile(theme, "Failed", "missing://showcase-image"),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Start,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=142.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn image_lifecycle_tile(
  theme : @moui.Theme,
  label : String,
  source : String,
) -> @moui.View[ShowcaseMsg] {
  column(
    [
      image(
        source,
        width=72.0,
        height=44.0,
        opacity=if label == "Loading" { 0.36 } else { 1.0 },
        corner_radius=theme.radius_scale.sm,
        fit=@graphics.ImageFit::Cover,
      )
      .background(theme.palette.surface_variant.multiply_alpha(0.5))
      .clip(),
      text(label, width=72.0, height=20.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn ShowcaseModel::dialog_demo_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text("Dialog", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        @views.dialog(
          "Showcase dialog",
          content=text("Custom modal content here", width=300.0, height=48.0),
          primary_action=Some(
            @views.StateViewAction::new(label="Close", message=HideDialog),
          ),
          theme~,
          width=440.0,
          height=240.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=220.0,
    padding=theme.spacing_scale.md,
  )
}

///|
fn ShowcaseModel::sheet_demo_card(
  self : ShowcaseModel,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ShowcaseMsg] {
  ignore(self)
  showcase_soft_card(
    theme,
    column(
      [
        text("Bottom Sheet", width=width - 32.0, height=24.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.foreground),
        sheet(
          content=text("Sheet content", width=240.0, height=30.0),
          presentation_mode=@views.SheetPresentationMode::BottomSheet,
          background=theme.palette.surface,
          corner_radius=theme.radius_scale.lg,
          shadow=Some(theme.shadow_scale.lg),
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Start,
    ),
    width~,
    height=180.0,
    padding=theme.spacing_scale.md,
  )
}
