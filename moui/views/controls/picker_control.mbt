///|
priv struct PickerOption {
  id : String
  label : String
}

///|
fn PickerOption::new(id~ : String, label~ : String) -> PickerOption {
  { id, label }
}

///|
fn PickerOption::id(self : PickerOption) -> String {
  self.id
}

///|
fn PickerOption::label(self : PickerOption) -> String {
  self.label
}

///|
fn[Msg] picker_control(
  items~ : Array[PickerOption],
  selected~ : @core.ControlledValue[String, Msg],
  placeholder~ : String,
  theme? : @core.Theme,
  style? : @style.PickerStyle,
  max_height~ : Double,
  kind? : String = "Picker",
  key? : String? = None,
) -> @core.View[Msg] {
  let items_snapshot = items.copy()
  let selected_snapshot = selected.value()
  @core.View::from_node(
    Picker::{
      items: items_snapshot,
      selected: selected_snapshot,
      placeholder,
      theme,
      style,
      max_height,
      kind,
      key,
    },
    event=(node, ctx) => picker_event(node, ctx, selected),
    semantics_actions=_node => {
      [
        @core.ViewSemanticsActionHandler::activate(ctx => {
          @core.ViewSemanticsActionResult::accepted(
            state=Some({ ..ctx.state, expanded: !ctx.state.expanded }),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
          )
        }),
      ]
    },
  )
}

///|
priv struct Picker {
  items : Array[PickerOption]
  selected : String
  placeholder : String
  theme : @core.Theme?
  style : @style.PickerStyle?
  max_height : Double
  kind : String
  key : String?
}

///|
impl @core.ViewNode for Picker with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for Picker with fn declaration(self) {
  let paint_key = @common.view_record_key("Picker.paint", [
    ("items", picker_items_key(self.items)),
    ("selected", @core.DeclarationKey::string(self.selected)),
    ("placeholder", @core.DeclarationKey::string(self.placeholder)),
    ("max_height", @core.DeclarationKey::double(self.max_height)),
  ])
  @common.view_declaration(
    paint=if self.theme is Some(_) || self.style is Some(_) {
      @core.DeclarationChannel::Uncacheable
    } else {
      @common.view_exact_channel(paint_key)
    },
    semantics=@common.view_exact_channel(
      @common.view_record_key("Picker.semantics", [
        ("items", picker_items_key(self.items)),
        ("selected", @core.DeclarationKey::string(self.selected)),
        ("placeholder", @core.DeclarationKey::string(self.placeholder)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for Picker with fn layout(_self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(@core.Size::new(width=200.0, height=40.0)),
  )
}

///|
impl @core.ViewNode for Picker with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => @style.PickerStyle::default(theme=resolved_theme)
  }
  let commands : Array[@core.DrawCommand] = []
  let overlay_commands : Array[@core.DrawCommand] = []
  append_picker_commands(
    commands,
    overlay_commands,
    frame=ctx.frame,
    items=self.items,
    selected_id=self.selected,
    placeholder=self.placeholder,
    font=resolved_style.font,
    foreground=resolved_style.foreground,
    background=resolved_style.background,
    corner_radius=resolved_style.radius,
    max_height=self.max_height,
    expanded=ctx.state.expanded,
    theme=resolved_theme,
  )
  {
    commands,
    child_layers: [],
    post_commands: [],
    overlay_commands,
    repaint_boundary: false,
    animating: false,
  }
}

///|
impl @core.ViewNode for Picker with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Menu,
    label=self.placeholder,
    value=picker_selected_label(self.items, self.selected, self.placeholder),
  )
}

///|
impl @core.ViewNode for Picker with fn focusable(_self) {
  true
}

///|
fn[Msg] picker_event(
  node : Picker,
  ctx : @core.ViewEventContext,
  selected : @core.ControlledValue[String, Msg],
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      handle_picker_pointer(
        ctx.state,
        event,
        frame=ctx.frame,
        items=node.items,
        selected~,
        max_height=node.max_height,
      )
    @core.AppEvent::Keyboard(event) =>
      handle_picker_keyboard(ctx.state, event, items=node.items, selected~)
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn append_picker_commands(
  commands : Array[@core.DrawCommand],
  overlay_commands : Array[@core.DrawCommand],
  frame~ : @core.Rect,
  items~ : Array[PickerOption],
  selected_id~ : String,
  placeholder~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  corner_radius~ : Double,
  max_height~ : Double,
  expanded~ : Bool,
  theme~ : @core.Theme,
) -> Unit {
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  commands.push(
    @core.DrawCommand::StrokeRoundedRectBrush(
      rounded,
      @core.Brush::solid(theme.palette.outline.multiply_alpha(0.6)),
      1.0,
    ),
  )
  let selected_label = picker_selected_label(items, selected_id, placeholder)
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=selected_label,
        frame=frame.inset(
          @core.Insets::symmetric(horizontal=12.0, vertical=0.0),
        ),
        font~,
        color=foreground,
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
  let arrow_size = 12.0
  let arrow_frame = @core.Rect::new(
    x=frame.origin.x + frame.size.width - arrow_size - 12.0,
    y=frame.origin.y + (frame.size.height - arrow_size) / 2.0,
    width=arrow_size,
    height=arrow_size,
  )
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=if expanded { "▲" } else { "▼" },
        frame=arrow_frame,
        font=@core.FontSpec::new(size=arrow_size * 0.9, weight=400),
        color=foreground,
        align=@core.TextAlign::TextCenter,
      ),
    ),
  )
  if expanded {
    append_picker_popup_commands(
      overlay_commands,
      frame~,
      items~,
      selected_id~,
      font~,
      foreground~,
      background~,
      corner_radius~,
      max_height~,
      theme~,
    )
  }
}

///|
fn append_picker_popup_commands(
  overlay_commands : Array[@core.DrawCommand],
  frame~ : @core.Rect,
  items~ : Array[PickerOption],
  selected_id~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  corner_radius~ : Double,
  max_height~ : Double,
  theme~ : @core.Theme,
) -> Unit {
  let list_frame = picker_popup_frame(items, frame, max_height)
  let list_rounded = @core.RoundedRect::new(
    rect=list_frame,
    radius=corner_radius,
  )
  let shadow = @style.views_ambient_control_theme(theme).surface.overlay_shadow.unwrap_or(
    theme.shadow_scale.md,
  )
  overlay_commands.push(
    @core.DrawCommand::DrawShadow(
      @core.ShadowSpec::new(
        rect=list_rounded,
        color=shadow.color,
        offset=shadow.offset,
        blur_radius=shadow.blur_radius,
        spread=shadow.spread,
      ),
    ),
  )
  overlay_commands.push(
    @core.DrawCommand::FillRoundedRectBrush(list_rounded, background),
  )
  for index, item in items {
    let item_frame = picker_item_frame(list_frame, index)
    let is_selected = item.id() == selected_id
    if is_selected {
      overlay_commands.push(
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(
            rect=item_frame.inset(
              @core.Insets::symmetric(horizontal=4.0, vertical=2.0),
            ),
            radius=4.0,
          ),
          @core.Brush::solid(theme.palette.primary.with_alpha(0.1)),
        ),
      )
    }
    overlay_commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text=item.label(),
          frame=item_frame.inset(
            @core.Insets::symmetric(horizontal=12.0, vertical=0.0),
          ),
          font~,
          color=if is_selected { theme.palette.primary } else { foreground },
          align=@core.TextAlign::TextStart,
        ),
      ),
    )
  }
}

///|
fn[Msg] handle_picker_pointer(
  state : @core.ViewStateContext,
  event : @core.PointerEvent,
  frame~ : @core.Rect,
  items~ : Array[PickerOption],
  selected~ : @core.ControlledValue[String, Msg],
  max_height~ : Double,
) -> @core.ViewEventResult[Msg] {
  let inside_button = frame.contains(event.position)
  let popup_frame = picker_popup_frame(items, frame, max_height)
  let inside_popup = popup_frame.contains(event.position)
  let claim_focus = event.phase == @core.PointerPhase::Down &&
    (inside_button || (state.expanded && inside_popup))
  if state.expanded {
    if event.phase == @core.PointerPhase::Up && inside_popup {
      match picker_item_id_at_position(items, popup_frame, event.position) {
        Some(id) =>
          @common.view_event_result(
            changed=true,
            activated=true,
            focused=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewBuildDirty,
            messages=[selected.changed(id)],
          )
        None =>
          @common.view_event_result(
            changed=true,
            focused=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
          )
      }
    } else if event.phase == @core.PointerPhase::Up && inside_button {
      @common.view_event_result(
        changed=true,
        focused=true,
        captured=true,
        state=Some({ ..state, expanded: false }),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    } else if event.phase == @core.PointerPhase::Up {
      @common.view_event_result(
        changed=true,
        captured=true,
        state=Some({ ..state, expanded: false }),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    } else if inside_button || inside_popup {
      @common.view_event_result(
        changed=true,
        focused=claim_focus,
        captured=true,
      )
    } else {
      @core.ViewEventResult::ignored()
    }
  } else if event.phase == @core.PointerPhase::Up && inside_button {
    @common.view_event_result(
      changed=true,
      focused=true,
      captured=true,
      state=Some({ ..state, expanded: true }),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else if claim_focus {
    @common.view_event_result(changed=true, focused=true, captured=true)
  } else {
    @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_picker_keyboard(
  state : @core.ViewStateContext,
  event : @core.KeyboardEvent,
  items~ : Array[PickerOption],
  selected~ : @core.ControlledValue[String, Msg],
) -> @core.ViewEventResult[Msg] {
  if !event.pressed {
    @core.ViewEventResult::ignored()
  } else if event.key == "Escape" && state.expanded {
    @common.view_event_result(
      changed=true,
      captured=true,
      state=Some({ ..state, expanded: false }),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else if event.key == "Enter" || event.key == "Space" || event.key == " " {
    if state.expanded {
      match picker_selected_id_or_first(items, selected.value()) {
        Some(id) =>
          @common.view_event_result(
            changed=true,
            activated=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewBuildDirty,
            messages=[selected.changed(id)],
          )
        None =>
          @common.view_event_result(
            changed=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
          )
      }
    } else {
      @common.view_event_result(
        changed=true,
        captured=true,
        state=Some({ ..state, expanded: true }),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    }
  } else {
    @core.ViewEventResult::ignored()
  }
}

///|
fn picker_selected_label(
  items : Array[PickerOption],
  selected_id : String,
  placeholder : String,
) -> String {
  let mut label = placeholder
  for item in items {
    if item.id() == selected_id {
      label = item.label()
      break
    }
  }
  label
}

///|
fn picker_selected_id_or_first(
  items : Array[PickerOption],
  selected_id : String,
) -> String? {
  let mut selected : String? = None
  for item in items {
    if item.id() == selected_id {
      selected = Some(item.id())
      break
    }
  }
  match selected {
    Some(id) => Some(id)
    None =>
      match items.get(0) {
        Some(item) => Some(item.id())
        None => None
      }
  }
}

///|
fn picker_item_id_at_position(
  items : Array[PickerOption],
  list_frame : @core.Rect,
  position : @core.Point,
) -> String? {
  let index = ((position.y - list_frame.origin.y) / picker_item_height()).to_int()
  if index >= 0 && index < items.length() {
    Some(items[index].id())
  } else {
    None
  }
}

///|
fn picker_popup_frame(
  items : Array[PickerOption],
  frame : @core.Rect,
  max_height : Double,
) -> @core.Rect {
  @core.Rect::new(
    x=frame.origin.x,
    y=frame.origin.y + frame.size.height + 4.0,
    width=frame.size.width,
    height=@common.view_min_double(
      max_height,
      items.length().to_double() * picker_item_height(),
    ),
  )
}

///|
fn picker_item_frame(list_frame : @core.Rect, index : Int) -> @core.Rect {
  @core.Rect::new(
    x=list_frame.origin.x,
    y=list_frame.origin.y + index.to_double() * picker_item_height(),
    width=list_frame.size.width,
    height=picker_item_height(),
  )
}

///|
fn picker_item_height() -> Double {
  36.0
}

///|
fn picker_items_key(items : Array[PickerOption]) -> @core.DeclarationKey {
  @core.DeclarationKey::array(
    items.map(item => {
      @common.view_record_key("PickerOption", [
        ("id", @core.DeclarationKey::string(item.id())),
        ("label", @core.DeclarationKey::string(item.label())),
      ])
    }),
  )
}
