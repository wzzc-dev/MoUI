///|
pub fn[Msg] button(
  text : String,
  on_click? : Msg,
  variant? : @style.ButtonVariant = @style.ButtonVariant::Primary,
  theme? : @core.Theme,
  style? : @style.ButtonStyle,
  icon? : @style.IconName? = None,
  width? : Double = 100.0,
  height? : Double = 40.0,
) -> @core.View[Msg] {
  button_control(
    text~,
    variant~,
    min_size=@core.Size::new(width~, height~),
    theme?,
    style?,
    leading_icon=icon,
    on_click~,
  )
}

///|
fn[Msg] button_control(
  text~ : String,
  variant~ : @style.ButtonVariant,
  min_size~ : @core.Size,
  theme? : @core.Theme,
  style? : @style.ButtonStyle,
  leading_icon? : @style.IconName? = None,
  on_click? : Msg? = None,
  kind? : String = "Button",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::from_node(
    Button::{
      text,
      variant,
      min_size,
      theme,
      style,
      leading_icon,
      has_on_click: on_click is Some(_),
      kind,
      key,
    },
    event=(_node, ctx) => button_event(ctx, on_click),
    semantics_actions=_node => {
      match on_click {
        Some(message) =>
          [
            @core.ViewSemanticsActionHandler::activate(_ctx => {
              @core.ViewSemanticsActionResult::message(message)
            }),
          ]
        None => []
      }
    },
  )
}

///|
priv struct Button {
  text : String
  variant : @style.ButtonVariant
  min_size : @core.Size
  theme : @core.Theme?
  style : @style.ButtonStyle?
  leading_icon : @style.IconName?
  has_on_click : Bool
  kind : String
  key : String?
}

///|
impl @core.ViewNode for Button with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl @core.ViewNode for Button with fn declaration(self) {
  let layout_key = @common.view_record_key("Button.layout", [
    ("text", @core.DeclarationKey::string(self.text)),
    ("min_size", @common.view_size_key(self.min_size)),
    (
      "leading_icon",
      @core.DeclarationKey::option(
        self.leading_icon.map(name => {
          @core.DeclarationKey::string(@icon.icon_label(name))
        }),
      ),
    ),
  ])
  let paint_key = @common.view_record_key("Button.paint", [
    (
      "variant",
      @core.DeclarationKey::int(
        match self.variant {
          @style.ButtonVariant::Primary => 0
          @style.ButtonVariant::Tonal => 1
          @style.ButtonVariant::Outline => 2
          @style.ButtonVariant::Ghost => 3
          @style.ButtonVariant::Subtle => 4
          @style.ButtonVariant::SubtleBrand => 5
        },
      ),
    ),
    (
      "leading_icon",
      @core.DeclarationKey::option(
        self.leading_icon.map(name => {
          @core.DeclarationKey::string(@icon.icon_label(name))
        }),
      ),
    ),
  ])
  @common.view_declaration(
    layout=if self.theme is Some(_) {
      @core.DeclarationChannel::Uncacheable
    } else {
      @common.view_exact_channel(layout_key)
    },
    paint=if self.theme is Some(_) || self.style is Some(_) {
      @core.DeclarationChannel::Uncacheable
    } else {
      @common.view_exact_channel(paint_key)
    },
    semantics=@common.view_exact_channel(
      @common.view_record_key("Button.semantics", [
        ("label", @core.DeclarationKey::string(self.text)),
        ("activate", @core.DeclarationKey::bool(self.has_on_click)),
      ]),
    ),
  )
}

///|
impl @core.ViewNode for Button with fn layout(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let font = resolved_theme.typography.control
  let padding_horizontal = resolved_theme.spacing_scale.lg
  let padding_vertical = resolved_theme.spacing_scale.sm
  let icon_size = font.size
  let icon_gap = padding_horizontal * 0.5
  let icon_block_width = match self.leading_icon {
    Some(_) => icon_size + icon_gap
    None => 0.0
  }
  let measured = ctx.text_system.measure_text(
    @core.TextLayoutInput::new(text=self.text, font~),
  )
  let content_width = @common.view_max_double(
    self.min_size.width,
    icon_block_width + measured.size.width + padding_horizontal * 2.0,
  )
  let content_height = @common.view_max_double(
    self.min_size.height,
    measured.size.height + padding_vertical * 2.0,
  )
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=content_width, height=content_height),
    ),
  )
}

///|
impl @core.ViewNode for Button with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None =>
      self.variant.style(@style.views_ambient_control_theme(resolved_theme))
  }
  let normal = resolved_style.normal
  let hovered = resolved_style.hovered
  let pressed = resolved_style.pressed
  let font = resolved_theme.typography.control
  let foreground = normal.foreground
  let padding_horizontal = resolved_theme.spacing_scale.lg
  let icon_size = font.size
  let icon_gap = padding_horizontal * 0.5
  let icon_block_width = match self.leading_icon {
    Some(_) => icon_size + icon_gap
    None => 0.0
  }
  let transition_duration_ms = resolved_theme.motion.fast_ms
  let transition_easing = resolved_theme.motion.easing
  let current_state = if ctx.state.pressed {
    @core.PressableState::Pressed
  } else if ctx.state.hovered {
    @core.PressableState::Hovered
  } else {
    @core.PressableState::Normal
  }
  let transition = @common.button_transition(ctx.state)
  let (background_brush, animating) = match transition {
    Some((from_state, start_ms)) =>
      if ctx.environment.reduced_motion ||
        transition_duration_ms <= 0.0 ||
        ctx.now_ms <= 0.0 {
        (
          @common.pressable_state_brush(
            current_state,
            normal.background,
            hovered.background,
            pressed.background,
          ),
          false,
        )
      } else {
        let raw_progress = (ctx.now_ms - start_ms) / transition_duration_ms
        if raw_progress >= 1.0 {
          (
            @common.pressable_state_brush(
              current_state,
              normal.background,
              hovered.background,
              pressed.background,
            ),
            false,
          )
        } else if raw_progress <= 0.0 {
          (
            @common.pressable_state_brush(
              from_state,
              normal.background,
              hovered.background,
              pressed.background,
            ),
            true,
          )
        } else {
          let from_color = @common.pressable_state_color(
            @common.pressable_state_brush(
              from_state,
              normal.background,
              hovered.background,
              pressed.background,
            ),
          )
          let to_color = @common.pressable_state_color(
            @common.pressable_state_brush(
              current_state,
              normal.background,
              hovered.background,
              pressed.background,
            ),
          )
          let blended = @core.animated_color(
            from=from_color,
            to=to_color,
            progress=raw_progress,
            easing=transition_easing,
          )
          (@core.Brush::solid(blended), true)
        }
      }
    None =>
      (
        @common.pressable_state_brush(
          current_state,
          normal.background,
          hovered.background,
          pressed.background,
        ),
        false,
      )
  }
  let commands : Array[@core.DrawCommand] = []
  @style.append_control_background(
    ctx,
    commands,
    background_brush,
    normal.border,
    normal.shadow,
    normal.radius,
  )
  let text_origin_x = ctx.frame.origin.x + padding_horizontal + icon_block_width
  let text_frame = @core.Rect::new(
    x=text_origin_x,
    y=ctx.frame.origin.y,
    width=@common.view_max_double(
      0.0,
      ctx.frame.size.width -
      padding_horizontal -
      icon_block_width -
      padding_horizontal,
    ),
    height=ctx.frame.size.height,
  )
  match self.leading_icon {
    Some(name) => {
      let icon_origin_x = ctx.frame.origin.x + padding_horizontal
      let icon_origin_y = ctx.frame.origin.y +
        (ctx.frame.size.height - icon_size) / 2.0
      let scale = icon_size / 24.0
      let scaled = @icon.icon_scale_verbs(
        @icon.icon_path(name),
        icon_origin_x,
        icon_origin_y,
        scale,
      )
      commands.push(
        @core.DrawCommand::DrawPath(
          @core.PathSpec::new(
            verbs=scaled,
            stroke=Some(@core.Brush::solid(foreground)),
            stroke_width=1.6,
          ),
        ),
      )
    }
    None => ()
  }
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=self.text,
        frame=text_frame,
        font~,
        color=foreground,
      ),
    ),
  )
  if animating {
    @core.ViewPaintPlan::animating_commands(commands)
  } else {
    @core.ViewPaintPlan::commands(commands)
  }
}

///|
impl @core.ViewNode for Button with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Button,
    label=self.text,
  )
}

///|
impl @core.ViewNode for Button with fn focusable(_self) {
  true
}

///|
fn[Msg] button_event(
  ctx : @core.ViewEventContext,
  on_click : Msg?,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) => {
      let inside = ctx.frame.contains(event.position)
      // A stale-hover Exit re-dispatches positionally and can carry a
      // position that is still inside this button; such an Exit must not
      // clear press/hover, or the terminating Up never activates.
      let exit_inside = event.phase == @core.PointerPhase::Exit && inside
      let current = if ctx.state.pressed {
        @core.PressableState::Pressed
      } else if ctx.state.hovered {
        @core.PressableState::Hovered
      } else {
        @core.PressableState::Normal
      }
      let next = if exit_inside {
        current
      } else {
        @common.view_button_next_state(current, inside, event.phase)
      }
      let activated = event.phase == @core.PointerPhase::Up &&
        inside &&
        current == @core.PressableState::Pressed
      let changed = next != current || activated
      // A stale-hover Exit carries the current pointer position; when it
      // lands inside the button the pointer never left, so press/hover must
      // survive it (synthetic Exit cascades re-dispatch positionally and can
      // otherwise clear a button the pointer is still on).
      let is_instant_clear = event.phase == @core.PointerPhase::Exit &&
        current != @core.PressableState::Normal &&
        !inside &&
        !exit_inside
      let next_state = if is_instant_clear {
        @common.button_state_with_transition(
          ctx.state,
          current,
          next,
          ctx.now_ms,
        ).without_slot(@common.button_transition_slot())
      } else if changed {
        @common.button_state_with_transition(
          ctx.state,
          current,
          next,
          ctx.now_ms,
        )
      } else {
        ctx.state
      }
      match (activated, on_click) {
        (true, Some(message)) =>
          @common.view_event_result(
            changed~,
            activated=true,
            captured=true,
            state=Some(next_state),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
            messages=[message],
          )
        (true, None) =>
          @common.view_event_result(
            changed~,
            captured=true,
            state=Some(next_state),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
          )
        (false, _) =>
          @common.view_event_result(
            changed~,
            captured=inside || changed,
            state=if changed { Some(next_state) } else { None },
            dirty=if changed {
              @core.ViewDirtyHint::ViewPaintDirty
            } else {
              @core.ViewDirtyHint::ViewClean
            },
          )
      }
    }
    @core.AppEvent::Keyboard(event) =>
      if event.pressed &&
        (event.key == "Enter" || event.key == "Space" || event.key == " ") {
        match on_click {
          Some(message) =>
            @common.view_event_result(
              changed=true,
              activated=true,
              captured=true,
              dirty=@core.ViewDirtyHint::ViewPaintDirty,
              messages=[message],
            )
          None =>
            @common.view_event_result(
              changed=true,
              activated=true,
              captured=true,
              dirty=@core.ViewDirtyHint::ViewPaintDirty,
            )
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    _ => @core.ViewEventResult::ignored()
  }
}
