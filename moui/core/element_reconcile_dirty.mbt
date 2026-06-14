///|
fn bool_dirty(changed : Bool, dirty : ReconcileDirtyKind) -> ReconcileDirtyKind {
  if changed {
    dirty
  } else {
    ReconcileDirtyKind::ReconcileClean
  }
}

///|
fn combine_dirty(
  first : ReconcileDirtyKind,
  second : ReconcileDirtyKind,
) -> ReconcileDirtyKind {
  first.combine(second)
}

///|
fn ViewSpec::reconcile_dirty_kind(
  self : ViewSpec,
  next : ViewSpec,
) -> ReconcileDirtyKind {
  match (self, next) {
    (EmptySpec, EmptySpec) => ReconcileClean
    (TextSpec(old), TextSpec(new)) => {
      let layout_changed = old.text != new.text ||
        old.size != new.size ||
        old.font != new.font
      let paint_changed = old.color != new.color
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (ButtonSpec(old), ButtonSpec(new)) => {
      let layout_changed = old.text != new.text ||
        old.size != new.size ||
        old.font != new.font
      let paint_changed = old.foreground != new.foreground ||
        old.background != new.background ||
        old.hovered_background != new.hovered_background ||
        old.pressed_background != new.pressed_background ||
        old.border != new.border ||
        old.shadow != new.shadow ||
        old.corner_radius != new.corner_radius
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (TextFieldSpec(old), TextFieldSpec(new)) =>
      reconcile_text_field_dirty(old, new)
    (RichTextEditorSpec(old), RichTextEditorSpec(new)) =>
      reconcile_rich_text_editor_dirty(old, new)
    (ImageSpec(old), ImageSpec(new)) => {
      let layout_changed = old.size != new.size
      let paint_changed = old.source != new.source ||
        old.opacity != new.opacity ||
        old.corner_radius != new.corner_radius ||
        old.fit != new.fit
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (CheckboxSpec(old), CheckboxSpec(new)) => {
      let layout_changed = old.label != new.label ||
        old.font != new.font ||
        old.size != new.size
      let paint_changed = old.checked.get() != new.checked.get() ||
        old.foreground != new.foreground ||
        old.check_color != new.check_color
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (PickerSpec(old), PickerSpec(new)) => {
      let layout_changed = !picker_items_equal(old.items, new.items) ||
        old.placeholder != new.placeholder ||
        old.font != new.font ||
        old.maxHeight != new.maxHeight
      let paint_changed = old.selected.get() != new.selected.get() ||
        old.foreground != new.foreground ||
        old.background != new.background ||
        old.cornerRadius != new.cornerRadius
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (DatePickerSpec(old), DatePickerSpec(new)) => {
      let layout_changed = old.mode != new.mode ||
        old.placeholder != new.placeholder ||
        old.font != new.font ||
        old.min_date != new.min_date ||
        old.max_date != new.max_date
      let paint_changed = old.selected.get() != new.selected.get() ||
        old.foreground != new.foreground ||
        old.background != new.background ||
        old.corner_radius != new.corner_radius
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (SearchBarSpec(old), SearchBarSpec(new)) =>
      reconcile_searchbar_dirty(old, new)
    (SheetSpec(old), SheetSpec(new)) => {
      let layout_changed = old.presentation_mode != new.presentation_mode
      let paint_changed = old.background != new.background ||
        old.corner_radius != new.corner_radius ||
        old.shadow != new.shadow
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (FlexSpec(old), FlexSpec(new)) =>
      bool_dirty(
        old.axis != new.axis ||
        old.spacing != new.spacing ||
        old.main_axis_alignment != new.main_axis_alignment ||
        old.cross_axis_alignment != new.cross_axis_alignment,
        ReconcileLayout,
      )
    (PaddingSpec(old), PaddingSpec(new)) =>
      bool_dirty(old.insets != new.insets, ReconcileLayout)
    (ContainerSpec(old), ContainerSpec(new)) => {
      let layout_changed = old.size != new.size
      let paint_changed = old.background != new.background ||
        old.border != new.border ||
        old.corner_radius != new.corner_radius ||
        old.shadow != new.shadow
      combine_dirty(
        bool_dirty(layout_changed, ReconcileLayout),
        bool_dirty(paint_changed, ReconcilePaint),
      )
    }
    (SpacerSpec(old), SpacerSpec(new)) =>
      bool_dirty(
        old.min_length != new.min_length || old.weight != new.weight,
        ReconcileLayout,
      )
    (FrameSpec(old), FrameSpec(new)) =>
      bool_dirty(
        old.width != new.width ||
        old.height != new.height ||
        old.min_width != new.min_width ||
        old.min_height != new.min_height ||
        old.max_width != new.max_width ||
        old.max_height != new.max_height,
        ReconcileLayout,
      )
    (StackSpec(_), StackSpec(_)) => ReconcileClean
    (ScrollSpec(old), ScrollSpec(new)) =>
      bool_dirty(
        old.offset != new.offset || old.viewport != new.viewport,
        ReconcileLayout,
      )
    (GridSpec(old), GridSpec(new)) =>
      bool_dirty(
        old.columns != new.columns ||
        old.row_spacing != new.row_spacing ||
        old.column_spacing != new.column_spacing,
        ReconcileLayout,
      )
    (ListSpec(old), ListSpec(new)) =>
      bool_dirty(old.spacing != new.spacing, ReconcileLayout)
    (ModifiedSpec(old), ModifiedSpec(new)) =>
      old.modifier.reconcile_dirty_kind(new.modifier)
    (CustomSpec(_), CustomSpec(_)) => ReconcileLayout
    (CustomLayoutSpec(_), CustomLayoutSpec(_)) => ReconcileLayout
    (ComponentSpec(_), ComponentSpec(_)) => ReconcileClean
    _ => ReconcileLayout
  }
}

///|
fn reconcile_text_field_dirty(
  old : TextFieldViewSpec,
  new : TextFieldViewSpec,
) -> ReconcileDirtyKind {
  let layout_changed = old.value.get() != new.value.get() ||
    old.placeholder != new.placeholder ||
    old.size != new.size ||
    old.font != new.font
  let paint_changed = old.foreground != new.foreground ||
    old.placeholder_color != new.placeholder_color ||
    old.background != new.background ||
    old.border != new.border ||
    old.focused_border != new.focused_border ||
    old.cursor_color != new.cursor_color ||
    old.corner_radius != new.corner_radius
  combine_dirty(
    bool_dirty(layout_changed, ReconcileLayout),
    bool_dirty(paint_changed, ReconcilePaint),
  )
}

///|
fn reconcile_rich_text_editor_dirty(
  old : RichTextEditorViewSpec,
  new : RichTextEditorViewSpec,
) -> ReconcileDirtyKind {
  let layout_changed = old.value.get() != new.value.get() ||
    old.placeholder != new.placeholder ||
    old.size != new.size ||
    old.font != new.font ||
    old.accepts_tab_input != new.accepts_tab_input
  let paint_changed = old.foreground != new.foreground ||
    old.placeholder_color != new.placeholder_color ||
    old.background != new.background ||
    old.border != new.border ||
    old.focused_border != new.focused_border ||
    old.cursor_color != new.cursor_color ||
    old.corner_radius != new.corner_radius
  combine_dirty(
    bool_dirty(layout_changed, ReconcileLayout),
    bool_dirty(paint_changed, ReconcilePaint),
  )
}

///|
fn reconcile_searchbar_dirty(
  old : SearchBarViewSpec,
  new : SearchBarViewSpec,
) -> ReconcileDirtyKind {
  let layout_changed = old.query.get() != new.query.get() ||
    old.placeholder != new.placeholder ||
    old.font != new.font
  let paint_changed = old.foreground != new.foreground ||
    old.placeholder_color != new.placeholder_color ||
    old.background != new.background ||
    old.border != new.border ||
    old.focused_border != new.focused_border ||
    old.cursor_color != new.cursor_color ||
    old.corner_radius != new.corner_radius
  combine_dirty(
    bool_dirty(layout_changed, ReconcileLayout),
    bool_dirty(paint_changed, ReconcilePaint),
  )
}

///|
fn picker_items_equal(old : Array[PickerItem], new : Array[PickerItem]) -> Bool {
  if old.length() != new.length() {
    false
  } else {
    for index, item in old {
      let next = new[index]
      if item.id != next.id || item.label != next.label {
        return false
      }
    }
    true
  }
}

///|
fn frame_modifier_equal(
  old : FrameModifierSpec,
  new : FrameModifierSpec,
) -> Bool {
  old.width == new.width &&
  old.height == new.height &&
  old.min_width == new.min_width &&
  old.min_height == new.min_height &&
  old.max_width == new.max_width &&
  old.max_height == new.max_height
}

///|
fn ViewModifier::reconcile_dirty_kind(
  self : ViewModifier,
  next : ViewModifier,
) -> ReconcileDirtyKind {
  match (self, next) {
    (PaddingModifier(old), PaddingModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (FrameModifier(old), FrameModifier(new)) =>
      bool_dirty(!frame_modifier_equal(old, new), ReconcileLayout)
    (BackgroundModifier(old), BackgroundModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (ForegroundModifier(old), ForegroundModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (FontModifier(old), FontModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (CornerRadiusModifier(old), CornerRadiusModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (OpacityModifier(old), OpacityModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (ShadowModifier(old), ShadowModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (BorderModifier(old), BorderModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (OffsetModifier(old_x, old_y), OffsetModifier(new_x, new_y)) =>
      bool_dirty(old_x != new_x || old_y != new_y, ReconcileLayout)
    (ClipModifier, ClipModifier) => ReconcileClean
    (ScaleModifier(old_x, old_y), ScaleModifier(new_x, new_y)) =>
      bool_dirty(old_x != new_x || old_y != new_y, ReconcilePaint)
    (DisabledModifier(old), DisabledModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (AccessibilityLabelModifier(old), AccessibilityLabelModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsRoleModifier(old), SemanticsRoleModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsSelectedModifier(old), SemanticsSelectedModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsPressedModifier(old), SemanticsPressedModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsCheckedModifier(old), SemanticsCheckedModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsExpandedModifier(old), SemanticsExpandedModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsInvalidModifier(old), SemanticsInvalidModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsRequiredModifier(old), SemanticsRequiredModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsDescriptionModifier(old), SemanticsDescriptionModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (SemanticsActionModifier(old), SemanticsActionModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (FocusableModifier(old), FocusableModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (FocusTrapModifier(old), FocusTrapModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (OnTapModifier(_), OnTapModifier(_)) => ReconcileClean
    (OnLongPressModifier(_), OnLongPressModifier(_)) => ReconcileClean
    (OnDoubleTapModifier(_), OnDoubleTapModifier(_)) => ReconcileClean
    (OnDragModifier(_), OnDragModifier(_)) => ReconcileClean
    (OnDragWithFrameModifier(_), OnDragWithFrameModifier(_)) => ReconcileClean
    (OnFileDropModifier(_), OnFileDropModifier(_)) => ReconcileClean
    (KeyboardShortcutModifier(old), KeyboardShortcutModifier(new)) =>
      bool_dirty(old != new, ReconcilePaint)
    (FlexibleModifier(old), FlexibleModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (LayoutPriorityModifier(old), LayoutPriorityModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (AlignModifier(old), AlignModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (AspectRatioModifier(old), AspectRatioModifier(new)) =>
      bool_dirty(old != new, ReconcileLayout)
    (IntrinsicWidthModifier, IntrinsicWidthModifier) => ReconcileClean
    (IntrinsicHeightModifier, IntrinsicHeightModifier) => ReconcileClean
    (RepaintBoundaryModifier, RepaintBoundaryModifier) => ReconcileClean
    _ => ReconcileLayout
  }
}
