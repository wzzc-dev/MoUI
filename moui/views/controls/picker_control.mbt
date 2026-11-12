///|
priv struct PickerOption {
  id : String
  label : String
}

///|
fn PickerOption::new(id~ : String, label~ : String) -> PickerOption {
  { id, label, }
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
  expanded~ : Bool,
  on_expanded_change~ : (Bool) -> Msg,
  placeholder~ : String,
  theme? : @core.Theme,
  style? : @style.PickerStyle,
  max_height~ : Double,
  kind~ : String = "Picker",
  key~ : String? = None,
) -> @core.View[Msg] {
  let items_snapshot = items.copy()
  let selected_snapshot = selected.value()
  let trigger = @core.View::from_node(
    PickerTrigger::{
      items: items_snapshot,
      selected: selected_snapshot,
      placeholder,
      theme,
      style,
      expanded,
      on_expanded_change,
      on_select: id => selected.changed(id),
      kind,
      key,
    },
    event=(node, ctx) => picker_trigger_event(node, ctx),
    semantics_actions=node => {
      [
        @core.ViewSemanticsActionHandler::activate(_ctx => {
          @core.ViewSemanticsActionResult::message(
            (node.on_expanded_change)(!node.expanded),
          )
        }),
      ]
    },
  )
  let popup_content = @core.View::from_node(
    PickerPopup::{
      items: items_snapshot,
      on_select: id => selected.changed(id),
      close: on_expanded_change(false),
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
    event=(node, ctx) => picker_popup_event(node, ctx),
  )
  let popup = @presentation.PresentationSpec::new(
    id="picker-popup",
    kind=Popover,
    content=popup_content,
    anchor=HostBase,
    placement=Some(
      @presentation.PresentationPlacement::new(
        candidates=[BelowStart, AboveStart],
        viewport_insets=@core.Insets::all(0.0),
      ),
    ),
    modality=NonModal,
    dismiss=@presentation.PresentationDismissPolicy::new(
      outside_tap=true,
      escape=true,
      system_back=true,
      host_close=true,
      message=Some(on_expanded_change(false)),
    ),
    transition=Fade,
    presented=expanded,
  )
  @presentation.popup_host(trigger, [popup])
}

///|
/// The picker trigger. Opening/closing is app-owned presentation state; the
/// popup itself lives in `popup_host`, not in this node's child layout.
priv struct PickerTrigger[Msg] {
  items : Array[PickerOption]
  selected : String
  placeholder : String
  theme : @core.Theme?
  style : @style.PickerStyle?
  expanded : Bool
  on_expanded_change : (Bool) -> Msg
  on_select : (String) -> Msg
  kind : String
  key : String?
}

///|
impl[Msg] @core.ViewNode for PickerTrigger[Msg] with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl[Msg] @core.ViewNode for PickerTrigger[Msg] with fn layout(_self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(@core.Size::new(width=200.0, height=40.0)),
  )
}

///|
impl[Msg] @core.ViewNode for PickerTrigger[Msg] with fn paint(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
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
    expanded=self.expanded,
    theme=resolved_theme,
  )
  { ..@core.ViewPaintPlan::empty(), commands, }
}

///|
impl[Msg] @core.ViewNode for PickerTrigger[Msg] with fn semantics(self) {
  @core.ViewSemanticsInfo::leaf(
    role=Menu,
    label=self.placeholder,
    value=picker_selected_label(self.items, self.selected, self.placeholder),
  )
}

///|
impl[Msg] @core.ViewNode for PickerTrigger[Msg] with fn focusable(_self) {
  true
}

///|
fn picker_trigger_press_slot() -> @core.ViewStateSlot[Bool] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.picker.trigger-pressed"),
    initial=false,
  )
}

///|

///|
fn[Msg] picker_trigger_event(
  node : PickerTrigger[Msg],
  ctx : @core.ViewEventContext,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    Pointer(event) =>
      if event.phase == Down && ctx.frame.contains(event.position) {
        @common.view_event_result(
          changed=true,
          focused=true,
          captured=true,
          state=Some(ctx.state.with_slot(picker_trigger_press_slot(), true)),
        )
      } else if event.phase == Up && ctx.frame.contains(event.position) {
        if ctx.state.read_slot(picker_trigger_press_slot()) {
          @common.view_event_result(
            changed=true,
            focused=true,
            captured=true,
            state=Some(ctx.state.without_slot(picker_trigger_press_slot())),
            messages=[(node.on_expanded_change)(!node.expanded)],
            dirty=ViewPaintDirty,
          )
        } else {
          // An Up without its own Down belongs to a gesture the popup
          // already dismissed (click-through); do not reopen the popup.
          @core.ViewEventResult::ignored()
        }
      } else if ctx.state.read_slot(picker_trigger_press_slot()) {
        @common.view_event_result(
          state=Some(ctx.state.without_slot(picker_trigger_press_slot())),
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    Keyboard(event) =>
      if event.pressed &&
        (event.key == "Enter" || event.key == "Space" || event.key == " ") {
        if node.expanded {
          match picker_selected_id_or_first(node.items, node.selected) {
            Some(id) =>
              @common.view_event_result(
                changed=true,
                focused=true,
                captured=true,
                messages=[
                  (node.on_select)(id),
                  (node.on_expanded_change)(false),
                ],
                dirty=ViewPaintDirty,
              )
            None =>
              @common.view_event_result(
                changed=true,
                focused=true,
                captured=true,
                messages=[(node.on_expanded_change)(false)],
                dirty=ViewPaintDirty,
              )
          }
        } else {
          @common.view_event_result(
            changed=true,
            focused=true,
            captured=true,
            messages=[(node.on_expanded_change)(true)],
            dirty=ViewPaintDirty,
          )
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    _ => @core.ViewEventResult::ignored()
  }
}

///|
/// The popup content frame: owns item hit-testing and returns both the
/// selection message and the close message. The rows themselves stay pure
/// paint/semantics nodes.
priv struct PickerPopup[Msg] {
  items : Array[PickerOption]
  on_select : (String) -> Msg
  close : Msg
}

///|
impl[Msg] @core.ViewNode for PickerPopup[Msg] with fn identity(_self) {
  @core.ViewIdentity::new(kind="PickerPopup")
}

///|
impl[Msg] @core.ViewNode for PickerPopup[Msg] with fn layout(_self, ctx) {
  let child_size = match ctx.child_sizes.get(0) {
    Some(size) => size
    None => @core.Size::new(width=198.0, height=0.0)
  }
  @core.ViewLayoutResult::new(size=ctx.constraints.constrain(child_size), child_frames=[
    @core.Rect::new(
      x=0.0,
      y=0.0,
      width=child_size.width,
      height=child_size.height,
    ),
  ])
}

///|
fn[Msg] picker_popup_event(
  node : PickerPopup[Msg],
  ctx : @core.ViewEventContext,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    Pointer(event) =>
      if event.phase == Up && ctx.frame.contains(event.position) {
        match
          picker_item_id_at_position(ctx.frame, event.position, node.items) {
          Some(id) =>
            @common.view_event_result(
              changed=true,
              focused=true,
              captured=true,
              messages=[(node.on_select)(id), node.close],
            )
          None => @core.ViewEventResult::ignored()
        }
      } else if ctx.frame.contains(event.position) {
        @common.view_event_result(changed=true, captured=true)
      } else {
        @core.ViewEventResult::ignored()
      }
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
  commands.push(FillRoundedRectBrush(rounded, background))
  commands.push(
    StrokeRoundedRectBrush(
      rounded,
      @core.Brush::solid(theme.palette.outline.multiply_alpha(0.6)),
      1.0,
    ),
  )
  let selected_label = picker_selected_label(items, selected_id, placeholder)
  commands.push(
    DrawText(
      @core.TextRun::new(
        text=selected_label,
        frame=frame.inset(
          @core.Insets::symmetric(horizontal=12.0, vertical=0.0),
        ),
        font~,
        color=foreground,
        align=TextStart,
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
    DrawText(
      @core.TextRun::new(
        text=if expanded { "▲" } else { "▼" },
        frame=arrow_frame,
        font=@core.FontSpec::new(size=arrow_size * 0.9, weight=400),
        color=foreground,
        align=TextCenter,
      ),
    ),
  )
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
  theme : @core.Theme // declaration-exempt: consumed only by the Uncacheable paint channel
  foreground : @core.Color // declaration-exempt: consumed only by the Uncacheable paint channel
}

///|
impl @core.ViewNode for PickerRow with fn identity(self) {
  @core.ViewIdentity::new(kind="PickerRow", key=Some(self.label))
}

///|
/// Rows keep a stable identity while their selection flips during wheel
/// scrolling, so every channel must key on the mutable state; the resolved
/// theme has no cheap key and keeps paint uncacheable (views convention).

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
      FillRoundedRectBrush(
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
    DrawText(
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
        align=TextStart,
      ),
    ),
  )
  { ..@core.ViewPaintPlan::empty(), commands, }
}

///|
impl @core.ViewNode for PickerRow with fn semantics(self) {
  @core.ViewSemanticsInfo::leaf(
    role=Option,
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
    variant=Overlay,
    theme=resolved_theme,
    padding=0.0,
  )
  .shadow(
    @style.views_ambient_control_theme(resolved_theme).surface.overlay_shadow.unwrap_or(
      resolved_theme.shadow_scale.md,
    ),
  )
  .semantics_role(Menu)
}
