///|
fn key_from_runtime_string(key : String?) -> Key? {
  match key {
    Some(key) => Some(Key::new(key))
    None => None
  }
}

///|
fn[Msg] lower_view_for_runtime(
  view : @core.View[Msg],
  emit : (Msg) -> Unit,
) -> ViewSpec {
  view.lower_for_runtime(
    @core.ViewLoweringSink::new(
      empty=() => ViewSpec::EmptySpec,
      text=(key, text, size, font, color) => {
        TextSpec({ key: key_from_runtime_string(key), text, size, font, color })
      },
      button=(
        key,
        text,
        size,
        font,
        foreground,
        background,
        hovered_background,
        pressed_background,
        border,
        shadow,
        corner_radius,
        message,
      ) => {
        ButtonSpec({
          key: key_from_runtime_string(key),
          text,
          size,
          font,
          foreground,
          background,
          hovered_background,
          pressed_background,
          border,
          shadow,
          corner_radius,
          on_click: match message {
            Some(message) => Some(() => emit(message))
            None => None
          },
        })
      },
      text_field=(
        key,
        value,
        placeholder,
        size,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        message,
      ) => {
        TextFieldSpec({
          key: key_from_runtime_string(key),
          value,
          placeholder,
          size,
          font,
          foreground,
          placeholder_color,
          background,
          border,
          focused_border,
          cursor_color,
          corner_radius,
          on_submit: match message {
            Some(message) => Some(() => emit(message))
            None => None
          },
        })
      },
      controlled_text_field=(
        key,
        value,
        on_input,
        placeholder,
        size,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        on_submit,
      ) => {
        TextFieldSpec({
          key: key_from_runtime_string(key),
          value: Binding::new(get=() => value, set=value => {
            emit(on_input(value))
          }),
          placeholder,
          size,
          font,
          foreground,
          placeholder_color,
          background,
          border,
          focused_border,
          cursor_color,
          corner_radius,
          on_submit: match on_submit {
            Some(message) => Some(() => emit(message))
            None => None
          },
        })
      },
      rich_text_editor=(
        key,
        value,
        placeholder,
        size,
        format,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        selection,
        prefix,
        input_transform,
        accepts_tab_input,
      ) => {
        RichTextEditorSpec({
          key: key_from_runtime_string(key),
          value,
          placeholder,
          size,
          format,
          font,
          foreground,
          placeholder_color,
          background,
          border,
          focused_border,
          cursor_color,
          corner_radius,
          on_selection_change: match selection {
            Some(handler) => Some((caret, range) => emit(handler(caret, range)))
            None => None
          },
          on_prefix_click: match prefix {
            Some(handler) => Some(offset => emit(handler(offset)))
            None => None
          },
          input_transform,
          accepts_tab_input,
        })
      },
      controlled_rich_text_editor=(
        key,
        value,
        on_input,
        placeholder,
        size,
        format,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        selection,
        prefix,
        input_transform,
        accepts_tab_input,
      ) => {
        RichTextEditorSpec({
          key: key_from_runtime_string(key),
          value: Binding::new(get=() => value, set=value => {
            emit(on_input(value))
          }),
          placeholder,
          size,
          format,
          font,
          foreground,
          placeholder_color,
          background,
          border,
          focused_border,
          cursor_color,
          corner_radius,
          on_selection_change: match selection {
            Some(handler) => Some((caret, range) => emit(handler(caret, range)))
            None => None
          },
          on_prefix_click: match prefix {
            Some(handler) => Some(offset => emit(handler(offset)))
            None => None
          },
          input_transform,
          accepts_tab_input,
        })
      },
      image=(key, source, size, opacity, corner_radius, fit) => {
        ImageSpec({
          key: key_from_runtime_string(key),
          source,
          size,
          opacity,
          corner_radius,
          fit,
        })
      },
      checkbox=(key, label, checked, font, foreground, check_color, size) => {
        CheckboxSpec({
          key: key_from_runtime_string(key),
          label,
          checked,
          font,
          foreground,
          check_color,
          size,
        })
      },
      controlled_checkbox=(
        key,
        label,
        checked,
        on_change,
        font,
        foreground,
        check_color,
        size,
      ) => {
        CheckboxSpec({
          key: key_from_runtime_string(key),
          label,
          checked: Binding::new(get=() => checked, set=checked => {
            emit(on_change(checked))
          }),
          font,
          foreground,
          check_color,
          size,
        })
      },
      picker=(
        key,
        items,
        selected,
        placeholder,
        font,
        foreground,
        background,
        cornerRadius,
        maxHeight,
      ) => {
        PickerSpec({
          key: key_from_runtime_string(key),
          items,
          selected,
          placeholder,
          font,
          foreground,
          background,
          cornerRadius,
          maxHeight,
        })
      },
      controlled_picker=(
        key,
        items,
        selected,
        on_select,
        placeholder,
        font,
        foreground,
        background,
        cornerRadius,
        maxHeight,
      ) => {
        PickerSpec({
          key: key_from_runtime_string(key),
          items,
          selected: Binding::new(get=() => selected, set=selected => {
            emit(on_select(selected))
          }),
          placeholder,
          font,
          foreground,
          background,
          cornerRadius,
          maxHeight,
        })
      },
      datepicker=(
        key,
        selected,
        mode,
        placeholder,
        font,
        foreground,
        background,
        corner_radius,
        min_date,
        max_date,
      ) => {
        DatePickerSpec({
          key: key_from_runtime_string(key),
          selected,
          mode,
          placeholder,
          font,
          foreground,
          background,
          corner_radius,
          min_date,
          max_date,
        })
      },
      controlled_datepicker=(
        key,
        selected,
        on_select,
        mode,
        placeholder,
        font,
        foreground,
        background,
        corner_radius,
        min_date,
        max_date,
      ) => {
        DatePickerSpec({
          key: key_from_runtime_string(key),
          selected: Binding::new(get=() => selected, set=selected => {
            emit(on_select(selected))
          }),
          mode,
          placeholder,
          font,
          foreground,
          background,
          corner_radius,
          min_date,
          max_date,
        })
      },
      search_bar=(
        key,
        query,
        placeholder,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        submit,
        clear,
      ) => {
        SearchBarSpec({
          key: key_from_runtime_string(key),
          query,
          placeholder,
          font,
          foreground,
          placeholder_color,
          background,
          border,
          focused_border,
          cursor_color,
          corner_radius,
          on_submit: match submit {
            Some(message) => Some(() => emit(message))
            None => None
          },
          on_clear: match clear {
            Some(message) => Some(() => emit(message))
            None => None
          },
        })
      },
      controlled_search_bar=(
        key,
        query,
        on_input,
        placeholder,
        font,
        foreground,
        placeholder_color,
        background,
        border,
        focused_border,
        cursor_color,
        corner_radius,
        submit,
        clear,
      ) => {
        SearchBarSpec({
          key: key_from_runtime_string(key),
          query: Binding::new(get=() => query, set=query => {
            emit(on_input(query))
          }),
          placeholder,
          font,
          foreground,
          placeholder_color,
          background,
          border,
          focused_border,
          cursor_color,
          corner_radius,
          on_submit: match submit {
            Some(message) => Some(() => emit(message))
            None => None
          },
          on_clear: match clear {
            Some(message) => Some(() => emit(message))
            None => None
          },
        })
      },
      web_view=(key, data, event_handler) => {
        WebViewHostSpec({
          key: key_from_runtime_string(key),
          id: data.id,
          url: data.url,
          width: data.width,
          height: data.height,
          title: data.title,
          policy: data.policy,
          on_event: match event_handler {
            Some(handler) => Some(event => emit(handler(event)))
            None => data.on_event
          },
        })
      },
      sheet=(
        key,
        content,
        presentation_mode,
        background,
        corner_radius,
        shadow,
        dismiss,
      ) => {
        SheetSpec({
          key: key_from_runtime_string(key),
          content,
          presentation_mode,
          background,
          corner_radius,
          shadow,
          on_dismiss: match dismiss {
            Some(message) => Some(() => emit(message))
            None => None
          },
        })
      },
      flex=(
        key,
        axis,
        spacing,
        main_axis_alignment,
        cross_axis_alignment,
        children,
      ) => {
        FlexSpec({
          key: key_from_runtime_string(key),
          axis,
          spacing,
          main_axis_alignment,
          cross_axis_alignment,
          children,
        })
      },
      padding=(key, insets, child) => {
        PaddingSpec({ key: key_from_runtime_string(key), insets, child })
      },
      container=(key, size, background, border, corner_radius, shadow, child) => {
        ContainerSpec({
          key: key_from_runtime_string(key),
          size,
          background,
          border,
          corner_radius,
          shadow,
          child,
        })
      },
      spacer=(key, min_length, weight) => {
        SpacerSpec({ key: key_from_runtime_string(key), min_length, weight })
      },
      frame=(
        key,
        width,
        height,
        min_width,
        min_height,
        max_width,
        max_height,
        child,
      ) => {
        FrameSpec({
          key: key_from_runtime_string(key),
          width,
          height,
          min_width,
          min_height,
          max_width,
          max_height,
          child,
        })
      },
      stack=(key, children) => {
        StackSpec({ key: key_from_runtime_string(key), children })
      },
      scroll=(key, offset, viewport, state, scroll, child) => {
        ScrollSpec({
          key: key_from_runtime_string(key),
          offset: match state {
            Some(state) => state.offset()
            None => offset
          },
          viewport,
          on_scroll: match (state, scroll) {
            (Some(state), Some(handler)) =>
              Some(delta => {
                state.scroll_to(
                  x=0.0,
                  y=max_scroll_offset(0.0, state.offset().y - delta.y),
                )
                emit(handler(delta))
              })
            (Some(state), None) =>
              Some(delta => {
                state.scroll_to(
                  x=0.0,
                  y=max_scroll_offset(0.0, state.offset().y - delta.y),
                )
              })
            (None, Some(handler)) => Some(delta => emit(handler(delta)))
            (None, None) => None
          },
          scroll_state: state,
          scroll_activates: scroll is Some(_),
          child,
        })
      },
      grid=(key, columns, row_spacing, column_spacing, children) => {
        GridSpec({
          key: key_from_runtime_string(key),
          columns,
          row_spacing,
          column_spacing,
          children,
        })
      },
      list=(key, spacing, children) => {
        ListSpec({ key: key_from_runtime_string(key), spacing, children })
      },
      key=(key, child) => child.with_key(Key::new(key)),
      padding_modifier=(insets, child) => {
        child.modified(PaddingModifier(insets))
      },
      frame_modifier=(
        width,
        height,
        min_width,
        min_height,
        max_width,
        max_height,
        child,
      ) => {
        child.modified(
          FrameModifier({
            width,
            height,
            min_width,
            min_height,
            max_width,
            max_height,
          }),
        )
      },
      background_modifier=(brush, child) => {
        child.modified(BackgroundModifier(brush))
      },
      foreground_modifier=(color, child) => {
        child.modified(ForegroundModifier(color))
      },
      font_modifier=(font, child) => child.modified(FontModifier(font)),
      corner_radius_modifier=(radius, child) => {
        child.modified(CornerRadiusModifier(radius))
      },
      opacity_modifier=(opacity, child) => {
        child.modified(OpacityModifier(opacity))
      },
      shadow_modifier=(style, child) => child.modified(ShadowModifier(style)),
      border_modifier=(style, child) => child.modified(BorderModifier(style)),
      offset_modifier=(dx, dy, child) => child.modified(OffsetModifier(dx, dy)),
      clip_modifier=child => child.modified(ClipModifier),
      scale_modifier=(sx, sy, child) => child.modified(ScaleModifier(sx, sy)),
      disabled_modifier=(disabled, child) => {
        child.modified(DisabledModifier(disabled))
      },
      accessibility_label_modifier=(label, child) => {
        child.modified(AccessibilityLabelModifier(label))
      },
      semantics_role_modifier=(role, child) => {
        child.modified(SemanticsRoleModifier(role))
      },
      semantics_selected_modifier=(selected, child) => {
        child.modified(SemanticsSelectedModifier(selected))
      },
      semantics_pressed_modifier=(pressed, child) => {
        child.modified(SemanticsPressedModifier(pressed))
      },
      semantics_checked_modifier=(checked, child) => {
        child.modified(SemanticsCheckedModifier(checked))
      },
      semantics_expanded_modifier=(expanded, child) => {
        child.modified(SemanticsExpandedModifier(expanded))
      },
      semantics_invalid_modifier=(invalid, child) => {
        child.modified(SemanticsInvalidModifier(invalid))
      },
      semantics_required_modifier=(required, child) => {
        child.modified(SemanticsRequiredModifier(required))
      },
      semantics_description_modifier=(description, child) => {
        child.modified(SemanticsDescriptionModifier(description))
      },
      semantics_action_modifier=(action, child) => {
        child.modified(SemanticsActionModifier(action))
      },
      focusable_modifier=(focusable, child) => {
        child.modified(FocusableModifier(focusable))
      },
      focus_trap_modifier=(enabled, child) => {
        child.modified(FocusTrapModifier(enabled))
      },
      on_tap_modifier=(message, child) => child.on_tap(() => emit(message)),
      on_long_press_modifier=(message, child) => {
        child.on_long_press(() => emit(message))
      },
      on_double_tap_modifier=(message, child) => {
        child.on_double_tap(() => emit(message))
      },
      on_drag_modifier=(handler, child) => {
        child.on_drag(event => emit(handler(event)))
      },
      on_drag_with_frame_modifier=(handler, child) => {
        child.on_drag_with_frame((event, frame) => emit(handler(event, frame)))
      },
      on_file_drop_modifier=(handler, child) => {
        child.on_file_drop((files, point) => emit(handler(files, point)))
      },
      keyboard_shortcut_modifier=(shortcut, child) => {
        child.modified(KeyboardShortcutModifier(shortcut))
      },
      flexible_modifier=(weight, child) => {
        child.modified(FlexibleModifier(weight))
      },
      layout_priority_modifier=(priority, child) => {
        child.modified(LayoutPriorityModifier(priority))
      },
      align_modifier=(alignment, child) => {
        child.modified(AlignModifier(alignment))
      },
      spacing_modifier=(spacing, child) => child.spacing(spacing),
      main_axis_alignment_modifier=(alignment, child) => {
        child.main_axis_alignment(alignment)
      },
      cross_axis_alignment_modifier=(alignment, child) => {
        child.cross_axis_alignment(alignment)
      },
      theme_modifier=(theme, child) => child.theme(theme),
      environment_modifier=(environment, child) => {
        child.environment(environment)
      },
      on_tap_handler_modifier=(handler, child) => child.on_tap(handler),
      on_long_press_handler_modifier=(handler, child) => {
        child.on_long_press(handler)
      },
      on_double_tap_handler_modifier=(handler, child) => {
        child.on_double_tap(handler)
      },
      on_drag_handler_modifier=(handler, child) => child.on_drag(handler),
      on_drag_with_frame_handler_modifier=(handler, child) => {
        child.on_drag_with_frame(handler)
      },
      on_file_drop_handler_modifier=(handler, child) => {
        child.on_file_drop(handler)
      },
      aspect_ratio_modifier=(ratio, child) => {
        child.modified(AspectRatioModifier(ratio))
      },
      intrinsic_width_modifier=child => child.modified(IntrinsicWidthModifier),
      intrinsic_height_modifier=child => child.modified(IntrinsicHeightModifier),
      repaint_boundary_modifier=child => child.modified(RepaintBoundaryModifier),
      custom=(key, measure, paint, semantics_role, semantics_label) => {
        CustomSpec({
          key: key_from_runtime_string(key),
          measure,
          paint,
          semantics_role,
          semantics_label,
        })
      },
      custom_layout=(
        key,
        children,
        cache,
        measure,
        place,
        paint,
        semantics_role,
        semantics_label,
      ) => {
        CustomLayoutSpec({
          key: key_from_runtime_string(key),
          children,
          cache,
          measure,
          place,
          paint,
          semantics_role,
          semantics_label,
        })
      },
      component=build => {
        ViewSpec::component(
          Component::new(ctx => lower_view_for_runtime(build(ctx), emit)),
        )
      },
    ),
  )
}

///|
fn max_scroll_offset(min : Double, value : Double) -> Double {
  if value < min {
    min
  } else {
    value
  }
}
