///|
fn[Msg] text_field_control(
  value~ : @core.Binding[String],
  placeholder~ : String,
  size~ : @core.Size,
  theme? : @core.Theme,
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  style? : TextFieldStyle,
  on_input? : ((String) -> Msg)? = None,
  on_submit? : Msg? = None,
  kind? : String = "TextField",
  key? : String? = None,
) -> @core.View[Msg] {
  let theme_revision = match theme {
    Some(t) => t.revision_fingerprint()
    None => "context"
  }
  let variant_label = match variant {
    TextFieldVariant::Filled => "filled"
    TextFieldVariant::Outline => "outline"
    TextFieldVariant::Plain => "plain"
  }
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "textfield:\{value.get()}:\{placeholder}:\{view_size_revision(size)}:\{variant_label}:\{theme_revision}:\{on_submit is Some(_)}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      let normal = resolved_style.normal
      let focused = resolved_style.focused
      let commands : Array[@core.DrawCommand] = []
      let overlay_commands : Array[@core.DrawCommand] = []
      append_text_field_commands(
        commands,
        overlay_commands,
        text=value.get(),
        placeholder~,
        size~,
        font=resolved_style.font,
        foreground=normal.foreground,
        placeholder_color=resolved_style.placeholder_color,
        background=normal.background,
        border=normal.border,
        focused_border=focused.border,
        cursor_color=resolved_style.cursor_color,
        corner_radius=normal.radius,
        frame=ctx.frame,
        focused=ctx.focused,
        control=ctx.text_control,
        text_system=ctx.text_system,
        theme=resolved_theme,
        bottom_border_only=normal.bottom_border_only,
        inner_focus_border=if ctx.focused {
          focused.inner_focus_border
        } else {
          None
        },
      )
      {
        commands,
        child_layers: [],
        post_commands: [],
        overlay_commands,
        platform_views: [],
        repaint_boundary: false,
        animating: false,
      }
    },
    event=ctx => {
      handle_text_field_event(
        ctx,
        value~,
        on_input~,
        on_submit~,
        search_bar=false,
        on_clear=None,
      )
    },
    text_input_state=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      Some(
        text_input_state_for_single_line(
          text=value.get(),
          frame=ctx.frame,
          font=resolved_style.font,
          control=ctx.text_control,
          text_system=ctx.text_system,
          search_bar=false,
        ),
      )
    },
    text_command=(ctx, intent, paste_text) => {
      handle_text_field_command(ctx, value~, on_input~, intent, paste_text~)
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::TextField,
        label=placeholder,
        value=value.get(),
        actions=[
          @core.SemanticsAction::Focus,
          @core.SemanticsAction::SetText,
          @core.SemanticsAction::Submit,
        ],
      )
    },
    focusable=() => true,
  )
}

///|
fn[Msg] controlled_text_field_control(
  value~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  size~ : @core.Size,
  theme? : @core.Theme,
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  style? : TextFieldStyle,
  on_submit? : Msg? = None,
  kind? : String = "TextField",
  key? : String? = None,
) -> @core.View[Msg] {
  text_field_control(
    value=@core.Binding::new(get=() => value, set=_next => ()),
    placeholder~,
    size~,
    theme?,
    variant~,
    style?,
    on_input=Some(on_input),
    on_submit~,
    kind~,
    key~,
  )
}

///|
fn[Msg] search_bar_control(
  query~ : @core.Binding[String],
  placeholder~ : String,
  theme? : @core.Theme,
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  style? : TextFieldStyle,
  on_input? : ((String) -> Msg)? = None,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
  kind? : String = "SearchBar",
  key? : String? = None,
) -> @core.View[Msg] {
  let theme_revision = match theme {
    Some(t) => t.revision_fingerprint()
    None => "context"
  }
  let variant_label = match variant {
    TextFieldVariant::Filled => "filled"
    TextFieldVariant::Outline => "outline"
    TextFieldVariant::Plain => "plain"
  }
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "searchbar:\{query.get()}:\{placeholder}:\{variant_label}:\{theme_revision}:\{on_submit is Some(_)}:\{on_clear is Some(_)}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=240.0, height=40.0),
        ),
      )
    },
    paint=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      let normal = resolved_style.normal
      let focused = resolved_style.focused
      let commands : Array[@core.DrawCommand] = []
      let overlay_commands : Array[@core.DrawCommand] = []
      append_searchbar_commands(
        commands,
        overlay_commands,
        text=query.get(),
        placeholder~,
        font=resolved_style.font,
        foreground=normal.foreground,
        placeholder_color=resolved_style.placeholder_color,
        background=normal.background,
        border=normal.border,
        focused_border=focused.border,
        cursor_color=resolved_style.cursor_color,
        corner_radius=normal.radius,
        frame=ctx.frame,
        focused=ctx.focused,
        control=ctx.text_control,
        text_system=ctx.text_system,
        theme=resolved_theme,
      )
      {
        commands,
        child_layers: [],
        post_commands: [],
        overlay_commands,
        platform_views: [],
        repaint_boundary: false,
        animating: false,
      }
    },
    event=ctx => {
      handle_text_field_event(
        ctx,
        value=query,
        on_input~,
        on_submit~,
        search_bar=true,
        on_clear~,
      )
    },
    text_input_state=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      Some(
        text_input_state_for_single_line(
          text=query.get(),
          frame=ctx.frame,
          font=resolved_style.font,
          control=ctx.text_control,
          text_system=ctx.text_system,
          search_bar=true,
        ),
      )
    },
    text_command=(ctx, intent, paste_text) => {
      handle_text_field_command(
        ctx,
        value=query,
        on_input~,
        intent,
        paste_text~,
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::TextField,
        label=placeholder,
        value=query.get(),
        actions=[
          @core.SemanticsAction::Focus,
          @core.SemanticsAction::SetText,
          @core.SemanticsAction::Submit,
        ],
      )
    },
    focusable=() => true,
  )
}

///|
fn[Msg] controlled_search_bar_control(
  query~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  theme? : @core.Theme,
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  style? : TextFieldStyle,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
  kind? : String = "SearchBar",
  key? : String? = None,
) -> @core.View[Msg] {
  search_bar_control(
    query=@core.Binding::new(get=() => query, set=_next => ()),
    placeholder~,
    theme?,
    variant~,
    style?,
    on_input=Some(on_input),
    on_submit~,
    on_clear~,
    kind~,
    key~,
  )
}
