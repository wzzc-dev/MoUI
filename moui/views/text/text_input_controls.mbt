///|
fn[Msg] text_field_control(
  value~ : @core.Binding[String],
  placeholder~ : String,
  size~ : @core.Size,
  theme? : @core.Theme,
  variant? : @style.TextFieldVariant = @style.TextFieldVariant::Filled,
  style? : @style.TextFieldStyle,
  on_input? : ((String) -> Msg)? = None,
  on_submit? : Msg? = None,
  kind? : String = "TextField",
  key? : String? = None,
) -> @core.View[Msg] {
  let value_snapshot = value.get()
  @core.View::from_node(
    SingleLineTextInput::{
      value: value_snapshot,
      placeholder,
      size,
      theme,
      variant,
      style,
      search_bar: false,
      has_on_submit: on_submit is Some(_),
      has_on_clear: false,
      kind,
      key,
    },
    event=(node, ctx) => {
      single_line_text_event(node, ctx, value, on_input, on_submit, None)
    },
    text_command=(_node, ctx, intent, paste_text) => {
      handle_text_field_command(ctx, value~, on_input~, intent, paste_text~)
    },
    semantics_actions=_node => {
      let handlers : Array[@core.ViewSemanticsActionHandler[Msg]] = [
        @core.ViewSemanticsActionHandler::set_text((ctx, next) => {
          text_semantics_set_text(ctx, value, on_input, next)
        }),
      ]
      match on_submit {
        Some(message) =>
          handlers.push(
            @core.ViewSemanticsActionHandler::submit(_ctx => {
              @core.ViewSemanticsActionResult::message(message)
            }),
          )
        None => ()
      }
      handlers
    },
  )
}

///|
fn[Msg] single_line_text_event(
  node : SingleLineTextInput,
  ctx : @core.ViewEventContext,
  value : @core.Binding[String],
  on_input : ((String) -> Msg)?,
  on_submit : Msg?,
  on_clear : Msg?,
) -> @core.ViewEventResult[Msg] {
  handle_text_field_event(
    ctx,
    value~,
    on_input~,
    on_submit~,
    search_bar=node.search_bar,
    on_clear~,
  )
}

///|
fn[Msg] controlled_text_field_control(
  value~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  size~ : @core.Size,
  theme? : @core.Theme,
  variant? : @style.TextFieldVariant = @style.TextFieldVariant::Filled,
  style? : @style.TextFieldStyle,
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
  variant? : @style.TextFieldVariant = @style.TextFieldVariant::Filled,
  style? : @style.TextFieldStyle,
  on_input? : ((String) -> Msg)? = None,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
  kind? : String = "SearchBar",
  key? : String? = None,
) -> @core.View[Msg] {
  let query_snapshot = query.get()
  @core.View::from_node(
    SingleLineTextInput::{
      value: query_snapshot,
      placeholder,
      size: @core.Size::new(width=240.0, height=40.0),
      theme,
      variant,
      style,
      search_bar: true,
      has_on_submit: on_submit is Some(_),
      has_on_clear: on_clear is Some(_),
      kind,
      key,
    },
    event=(node, ctx) => {
      single_line_text_event(node, ctx, query, on_input, on_submit, on_clear)
    },
    text_command=(_node, ctx, intent, paste_text) => {
      handle_text_field_command(
        ctx,
        value=query,
        on_input~,
        intent,
        paste_text~,
      )
    },
    semantics_actions=_node => {
      let handlers : Array[@core.ViewSemanticsActionHandler[Msg]] = [
        @core.ViewSemanticsActionHandler::set_text((ctx, next) => {
          text_semantics_set_text(ctx, query, on_input, next)
        }),
      ]
      match on_submit {
        Some(message) =>
          handlers.push(
            @core.ViewSemanticsActionHandler::submit(_ctx => {
              @core.ViewSemanticsActionResult::message(message)
            }),
          )
        None => ()
      }
      handlers
    },
  )
}

///|
pub fn[Msg] controlled_search_bar_control(
  query~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  theme? : @core.Theme,
  variant? : @style.TextFieldVariant = @style.TextFieldVariant::Filled,
  style? : @style.TextFieldStyle,
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
