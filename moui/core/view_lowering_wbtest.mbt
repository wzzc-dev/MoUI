///|
enum LoweringTestMsg {
  LoweringPressed
}

///|
fn optional_lowering_key(key : String?) -> String {
  match key {
    Some(key) => key
    None => "_"
  }
}

///|
fn lowering_test_sink() -> ViewLoweringSink[LoweringTestMsg, String] {
  ViewLoweringSink::new(
    empty=() => "empty",
    text=(key, text, _, _, _) => {
      "text(" + optional_lowering_key(key) + "," + text + ")"
    },
    button=(key, text, _, _, _, _, _, _, _, _, _, message) => {
      let pressed = match message {
        Some(LoweringPressed) => "pressed"
        None => "idle"
      }
      "button(" + optional_lowering_key(key) + "," + text + "," + pressed + ")"
    },
    text_field=(key, _, placeholder, _, _, _, _, _, _, _, _, _, submit) => {
      let state = match submit {
        Some(LoweringPressed) => "submit"
        None => "idle"
      }
      "text_field(" +
      optional_lowering_key(key) +
      "," +
      placeholder +
      "," +
      state +
      ")"
    },
    controlled_text_field=(
      key,
      value,
      _,
      placeholder,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      submit,
    ) => {
      let state = match submit {
        Some(LoweringPressed) => "submit"
        None => "idle"
      }
      "controlled_text_field(" +
      optional_lowering_key(key) +
      "," +
      value +
      "," +
      placeholder +
      "," +
      state +
      ")"
    },
    rich_text_editor=(
      key,
      _,
      placeholder,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
    ) => "rich_text(" + optional_lowering_key(key) + "," + placeholder + ")",
    controlled_rich_text_editor=(
      key,
      value,
      _,
      placeholder,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
    ) => {
      "controlled_rich_text(" +
      optional_lowering_key(key) +
      "," +
      value +
      "," +
      placeholder +
      ")"
    },
    image=(key, source, _, _, _, _) => {
      "image(" + optional_lowering_key(key) + "," + source + ")"
    },
    checkbox=(key, label, _, _, _, _, _) => {
      "checkbox(" + optional_lowering_key(key) + "," + label + ")"
    },
    controlled_checkbox=(key, label, checked, _, _, _, _, _) => {
      "controlled_checkbox(" +
      optional_lowering_key(key) +
      "," +
      label +
      "," +
      checked.to_string() +
      ")"
    },
    picker=(key, items, _, placeholder, _, _, _, _, _) => {
      "picker(" +
      optional_lowering_key(key) +
      "," +
      items.length().to_string() +
      "," +
      placeholder +
      ")"
    },
    controlled_picker=(key, items, selected, _, placeholder, _, _, _, _, _) => {
      "controlled_picker(" +
      optional_lowering_key(key) +
      "," +
      items.length().to_string() +
      "," +
      selected +
      "," +
      placeholder +
      ")"
    },
    datepicker=(key, _, _, placeholder, _, _, _, _, _, _) => {
      "datepicker(" + optional_lowering_key(key) + "," + placeholder + ")"
    },
    controlled_datepicker=(key, _, _, _, placeholder, _, _, _, _, _, _) => {
      "controlled_datepicker(" +
      optional_lowering_key(key) +
      "," +
      placeholder +
      ")"
    },
    search_bar=(key, _, placeholder, _, _, _, _, _, _, _, _, submit, clear) => {
      let submit_label = match submit {
        Some(LoweringPressed) => "submit"
        None => "idle"
      }
      let clear_label = match clear {
        Some(LoweringPressed) => "clear"
        None => "idle"
      }
      "search(" +
      optional_lowering_key(key) +
      "," +
      placeholder +
      "," +
      submit_label +
      "," +
      clear_label +
      ")"
    },
    controlled_search_bar=(
      key,
      query,
      _,
      placeholder,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      submit,
      clear,
    ) => {
      let submit_label = match submit {
        Some(LoweringPressed) => "submit"
        None => "idle"
      }
      let clear_label = match clear {
        Some(LoweringPressed) => "clear"
        None => "idle"
      }
      "controlled_search(" +
      optional_lowering_key(key) +
      "," +
      query +
      "," +
      placeholder +
      "," +
      submit_label +
      "," +
      clear_label +
      ")"
    },
    web_view=(key, _, _) => "web_view(" + optional_lowering_key(key) + ")",
    sheet=(key, content, _, _, _, _, dismiss) => {
      let state = match dismiss {
        Some(LoweringPressed) => "dismiss"
        None => "idle"
      }
      "sheet(" + optional_lowering_key(key) + "," + state + "," + content + ")"
    },
    flex=(key, axis, spacing, _, _, children) => {
      let axis_label = match axis {
        Axis::Horizontal => "h"
        Axis::Vertical => "v"
      }
      "flex(" +
      optional_lowering_key(key) +
      "," +
      axis_label +
      "," +
      spacing.to_string() +
      ",[" +
      children.join("|") +
      "])"
    },
    padding=(key, insets, child) => {
      "padding(" +
      optional_lowering_key(key) +
      "," +
      insets.left.to_string() +
      "," +
      child +
      ")"
    },
    container=(key, _, _, _, _, _, child) => {
      let child_label = match child {
        Some(child) => child
        None => "none"
      }
      "container(" + optional_lowering_key(key) + "," + child_label + ")"
    },
    spacer=(key, min_length, weight) => {
      "spacer(" +
      optional_lowering_key(key) +
      "," +
      min_length.to_string() +
      "," +
      weight.to_string() +
      ")"
    },
    frame=(key, _, _, _, _, _, _, child) => {
      "frame(" + optional_lowering_key(key) + "," + child + ")"
    },
    stack=(key, children) => {
      "stack(" + optional_lowering_key(key) + ",[" + children.join("|") + "])"
    },
    scroll=(key, _, _, _, _, child) => {
      "scroll(" + optional_lowering_key(key) + "," + child + ")"
    },
    grid=(key, columns, _, _, children) => {
      "grid(" +
      optional_lowering_key(key) +
      "," +
      columns.to_string() +
      ",[" +
      children.join("|") +
      "])"
    },
    list=(key, spacing, children) => {
      "list(" +
      optional_lowering_key(key) +
      "," +
      spacing.to_string() +
      ",[" +
      children.join("|") +
      "])"
    },
    key=(key, child) => "key(" + key + "," + child + ")",
    padding_modifier=(insets, child) => {
      "padding_modifier(" + insets.left.to_string() + "," + child + ")"
    },
    frame_modifier=(_, _, _, _, _, _, child) => "frame_modifier(" + child + ")",
    background_modifier=(_, child) => "background(" + child + ")",
    foreground_modifier=(_, child) => "foreground(" + child + ")",
    font_modifier=(_, child) => "font(" + child + ")",
    corner_radius_modifier=(_, child) => "corner(" + child + ")",
    opacity_modifier=(_, child) => "opacity(" + child + ")",
    shadow_modifier=(_, child) => "shadow(" + child + ")",
    border_modifier=(_, child) => "border(" + child + ")",
    offset_modifier=(_, _, child) => "offset(" + child + ")",
    clip_modifier=child => "clip(" + child + ")",
    scale_modifier=(_, _, child) => "scale(" + child + ")",
    disabled_modifier=(disabled, child) => {
      "disabled(" + disabled.to_string() + "," + child + ")"
    },
    accessibility_label_modifier=(label, child) => {
      "accessibility(" + label + "," + child + ")"
    },
    semantics_role_modifier=(_, child) => "semantics_role(" + child + ")",
    semantics_selected_modifier=(_, child) => {
      "semantics_selected(" + child + ")"
    },
    semantics_pressed_modifier=(_, child) => "semantics_pressed(" + child + ")",
    semantics_checked_modifier=(_, child) => "semantics_checked(" + child + ")",
    semantics_expanded_modifier=(_, child) => {
      "semantics_expanded(" + child + ")"
    },
    semantics_invalid_modifier=(_, child) => "semantics_invalid(" + child + ")",
    semantics_required_modifier=(_, child) => {
      "semantics_required(" + child + ")"
    },
    semantics_description_modifier=(_, child) => {
      "semantics_description(" + child + ")"
    },
    semantics_action_modifier=(_, child) => "semantics_action(" + child + ")",
    focusable_modifier=(_, child) => "focusable(" + child + ")",
    focus_trap_modifier=(_, child) => "focus_trap(" + child + ")",
    on_tap_modifier=(message, child) => {
      match message {
        LoweringPressed => "tap(" + child + ")"
      }
    },
    on_long_press_modifier=(_, child) => "long_press(" + child + ")",
    on_double_tap_modifier=(_, child) => "double_tap(" + child + ")",
    on_drag_modifier=(_, child) => "drag(" + child + ")",
    on_drag_with_frame_modifier=(_, child) => "drag_frame(" + child + ")",
    on_file_drop_modifier=(_, child) => "file_drop(" + child + ")",
    keyboard_shortcut_modifier=(_, child) => "shortcut(" + child + ")",
    flexible_modifier=(weight, child) => {
      "flexible(" + weight.to_string() + "," + child + ")"
    },
    layout_priority_modifier=(priority, child) => {
      "priority(" + priority.to_string() + "," + child + ")"
    },
    align_modifier=(_, child) => "align(" + child + ")",
    spacing_modifier=(spacing, child) => {
      "spacing(" + spacing.to_string() + "," + child + ")"
    },
    main_axis_alignment_modifier=(_, child) => "main_axis(" + child + ")",
    cross_axis_alignment_modifier=(_, child) => "cross_axis(" + child + ")",
    theme_modifier=(_, child) => "theme(" + child + ")",
    environment_modifier=(_, child) => "environment(" + child + ")",
    on_tap_handler_modifier=(_, child) => "tap_handler(" + child + ")",
    on_long_press_handler_modifier=(_, child) => {
      "long_press_handler(" + child + ")"
    },
    on_double_tap_handler_modifier=(_, child) => {
      "double_tap_handler(" + child + ")"
    },
    on_drag_handler_modifier=(_, child) => "drag_handler(" + child + ")",
    on_drag_with_frame_handler_modifier=(_, child) => {
      "drag_frame_handler(" + child + ")"
    },
    on_file_drop_handler_modifier=(_, child) => {
      "file_drop_handler(" + child + ")"
    },
    aspect_ratio_modifier=(_, child) => "aspect(" + child + ")",
    intrinsic_width_modifier=child => "intrinsic_width(" + child + ")",
    intrinsic_height_modifier=child => "intrinsic_height(" + child + ")",
    repaint_boundary_modifier=child => "repaint(" + child + ")",
    custom=(key, _, _, _, label) => {
      "custom(" + optional_lowering_key(key) + "," + label + ")"
    },
    custom_layout=(key, children, _, _, _, _, _, label) => {
      "custom_layout(" +
      optional_lowering_key(key) +
      "," +
      label +
      ",[" +
      children.join("|") +
      "])"
    },
    component=_ => "component",
  )
}

///|
test "view lowering seam visits opaque views without runtime specs" {
  let view : View[LoweringTestMsg] = View::primitive_flex_view(
      axis=Axis::Vertical,
      spacing=4.0,
      children=[
        View::primitive_text_view(
          text="Hello",
          size=Size::new(width=40.0, height=16.0),
          font=FontSpec::new(size=12.0),
          color=Color::black(),
        ).key("title"),
        View::primitive_button_view(
          text="Go",
          size=Size::new(width=40.0, height=24.0),
          font=FontSpec::new(size=12.0),
          foreground=Color::black(),
          background=Brush::solid(Color::white()),
          hovered_background=Brush::solid(Color::gray()),
          pressed_background=Brush::solid(Color::black()),
          on_click=Some(LoweringPressed),
        ),
      ],
    )
    .spacing(12.0)
    .theme(Theme::default())
    .on_tap(LoweringPressed)
    .key("root")

  inspect(
    view.lower_for_runtime(lowering_test_sink()),
    content="key(root,tap(theme(spacing(12,flex(_,v,4,[key(title,text(_,Hello))|button(_,Go,pressed)])))))",
  )
}

///|
test "view lowering seam preserves handler modifiers without running them" {
  let ran = State::new(false)
  let view : View[LoweringTestMsg] = modify_view(
    View::primitive_empty_view(),
    PlainModifier(OnTapModifier(() => ran.set(true))),
  )

  inspect(
    view.lower_for_runtime(lowering_test_sink()),
    content="tap_handler(empty)",
  )
  inspect(ran.get(), content="false")
}
