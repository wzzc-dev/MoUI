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
    children=_node => {
      [
        picker_popup_view(
          items=items_snapshot,
          selected=selected_snapshot,
          theme?,
          style?,
          max_height~,
        ),
      ]
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
  let own = ctx.constraints.constrain(@core.Size::new(width=200.0, height=40.0))
  // The popup is a real child subtree. When collapsed it receives no frame at
  // all: it is not placed, painted, hit-tested, or exposed to semantics. When
  // expanded the post-layout placement pass resolves its absolute frame via
  // `place_overlays`.
  let child_frames = if ctx.state.expanded {
    let popup_size = if ctx.child_sizes.length() > 0 {
      ctx.child_sizes[0]
    } else {
      @core.Size::new(width=0.0, height=0.0)
    }
    [
      // Off-screen sentinel: the placement pass always moves it to the
      // resolved anchor-relative rect, and the sentinel guarantees the
      // override diff engages even when both coincide on screen.
      @core.Rect::new(
        x=0.0,
        y=-100000.0,
        width=popup_size.width,
        height=popup_size.height,
      ),
    ]
  } else {
    []
  }
  @core.ViewLayoutResult::new(size=own, child_frames~)
}

///|
impl @core.ViewNode for Picker with fn child_constraints(_self, _constraints) {
  // The popup sizes to its own content; parent constraints (tight at place
  // time) must not clamp it.
  @core.Constraints::unbounded()
}

///|
impl @core.ViewNode for Picker with fn place_overlays(_self, context) {
  if !context.state.expanded {
    return None
  }
  if context.child_sizes.is_empty() {
    return None
  }
  let content_size = context.child_sizes[0]
  let placement = @presentation.PresentationPlacement::new(
    candidates=[
      @presentation.PresentationPlacementCandidate::BelowStart,
      @presentation.PresentationPlacementCandidate::AboveStart,
    ],
    viewport_insets=@core.Insets::all(0.0),
  )
  let frame = placement.resolve(
    context.host_frame,
    context.viewport,
    content_size,
  )
  Some([(0, frame)])
}

///|
impl @core.ViewNode for Picker with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => @style.PickerStyle::default(theme=resolved_theme)
  }
  let commands : Array[@core.DrawCommand] = []
  append_picker_commands(
    commands,
    frame=ctx.frame,
    items=self.items,
    selected_id=self.selected,
    placeholder=self.placeholder,
    font=resolved_style.font,
    foreground=resolved_style.foreground,
    background=resolved_style.background,
    corner_radius=resolved_style.radius,
    expanded=ctx.state.expanded,
    theme=resolved_theme,
  )
  { ..@core.ViewPaintPlan::empty(), commands, }
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
        popup_frame=ctx.child_frames.get(0),
        items=node.items,
        selected~,
      )
    @core.AppEvent::Keyboard(event) =>
      handle_picker_keyboard(ctx.state, event, items=node.items, selected~)
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn append_picker_commands(
  commands : Array[@core.DrawCommand],
  frame~ : @core.Rect,
  items~ : Array[PickerOption],
  selected_id~ : String,
  placeholder~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  corner_radius~ : Double,
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
}

///|
fn[Msg] handle_picker_pointer(
  state : @core.ViewStateContext,
  event : @core.PointerEvent,
  frame~ : @core.Rect,
  popup_frame~ : @core.Rect?,
  items~ : Array[PickerOption],
  selected~ : @core.ControlledValue[String, Msg],
) -> @core.ViewEventResult[Msg] {
  let inside_button = frame.contains(event.position)
  let inside_popup = match popup_frame {
    Some(popup) => popup.contains(event.position)
    None => false
  }
  let claim_focus = event.phase == @core.PointerPhase::Down &&
    (inside_button || (state.expanded && inside_popup))
  if state.expanded {
    if event.phase == @core.PointerPhase::Up && inside_popup {
      let hit_id = match popup_frame {
        Some(popup) => picker_item_id_at_position(popup, event.position, items)
        None => None
      }
      match hit_id {
        Some(id) =>
          @common.view_event_result(
            changed=true,
            activated=true,
            focused=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewLayoutDirty,
            messages=[selected.changed(id)],
          )
        None =>
          @common.view_event_result(
            changed=true,
            focused=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewLayoutDirty,
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
      dirty=@core.ViewDirtyHint::ViewLayoutDirty,
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
            dirty=@core.ViewDirtyHint::ViewLayoutDirty,
            messages=[selected.changed(id)],
          )
        None =>
          @common.view_event_result(
            changed=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewLayoutDirty,
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
  list_frame : @core.Rect,
  position : @core.Point,
  items : Array[PickerOption],
) -> String? {
  let index = ((position.y - list_frame.origin.y) / picker_item_height()).to_int()
  if index >= 0 && index < items.length() {
    Some(items[index].id())
  } else {
    None
  }
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

///|
/// A non-activating popup option row. Pointer selection and keyboard
/// navigation stay on the picker node (so the popup can close through the
/// picker's own control state); the row exists to paint and expose semantics
/// as a real subtree instead of hand-drawn draw commands.
priv struct PickerRow {
  label : String
  is_selected : Bool
  width : Double
  theme : @core.Theme
  foreground : @core.Color
}

///|
impl @core.ViewNode for PickerRow with fn identity(self) {
  @core.ViewIdentity::new(kind="PickerRow", key=Some(self.label))
}

///|
impl @core.ViewNode for PickerRow with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for PickerRow with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=picker_item_height()),
    ),
  )
}

///|
impl @core.ViewNode for PickerRow with fn paint(self, ctx) {
  let commands : Array[@core.DrawCommand] = []
  if self.is_selected {
    commands.push(
      @core.DrawCommand::FillRoundedRectBrush(
        @core.RoundedRect::new(
          rect=@core.Rect::new(
            x=ctx.frame.origin.x + 4.0,
            y=ctx.frame.origin.y + 2.0,
            width=ctx.frame.size.width - 8.0,
            height=ctx.frame.size.height - 4.0,
          ),
          radius=4.0,
        ),
        @core.Brush::solid(self.theme.palette.primary.with_alpha(0.1)),
      ),
    )
  }
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=self.label,
        frame=ctx.frame.inset(
          @core.Insets::symmetric(horizontal=12.0, vertical=0.0),
        ),
        font=@core.FontSpec::new(size=14.0, weight=400),
        color=if self.is_selected {
          self.theme.palette.primary
        } else {
          self.foreground
        },
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
  { ..@core.ViewPaintPlan::empty(), commands, }
}

///|
impl @core.ViewNode for PickerRow with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Option,
    label=self.label,
    selected=self.is_selected,
  )
}

///|
/// The picker popup as a real child subtree: themed overlay panel, real rows
/// with option semantics, escape-from-clipping handled by the runtime's
/// overlay placement hoist.
fn[Msg] picker_popup_view(
  items~ : Array[PickerOption],
  selected~ : String,
  theme? : @core.Theme,
  style? : @style.PickerStyle,
  max_height~ : Double,
) -> @core.View[Msg] {
  let resolved_theme = theme.unwrap_or(@core.Theme::neutral())
  let resolved_style = match style {
    Some(value) => value
    None => @style.PickerStyle::default(theme=resolved_theme)
  }
  let width = 200.0
  let rows : Array[@core.View[Msg]] = []
  for item in items {
    rows.push(
      @core.View::from_node(PickerRow::{
        label: item.label(),
        is_selected: item.id() == selected,
        width: width - 2.0,
        theme: resolved_theme,
        foreground: resolved_style.foreground,
      }),
    )
  }
  let list_height = @common.view_min_double(
    max_height,
    items.length().to_double() * picker_item_height(),
  )
  @container.container(
    @layout.column(rows, spacing=0.0),
    width=width - 2.0,
    height=list_height,
    variant=@style.ContainerVariant::Overlay,
    theme=resolved_theme,
    padding=0.0,
  )
  .shadow(
    @style.views_ambient_control_theme(resolved_theme).surface.overlay_shadow.unwrap_or(
      resolved_theme.shadow_scale.md,
    ),
  )
  .semantics_role(@core.SemanticsRole::Menu)
}
