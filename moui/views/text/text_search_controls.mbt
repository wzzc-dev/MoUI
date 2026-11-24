///|
fn[Msg] search_bar_control(
  query~ : String,
  placeholder~ : String,
  theme? : @core.Theme,
  variant~ : @style.TextFieldVariant = Filled,
  style? : @style.TextFieldStyle,
  on_input~ : ((String) -> Msg)? = None,
  on_submit~ : Msg? = None,
  on_clear~ : Msg? = None,
  kind~ : String = "SearchBar",
  key~ : String? = None,
) -> @core.View[Msg] {
  let query_snapshot = query
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
      single_line_text_event(
        node,
        ctx,
        query,
        on_input,
        on_submit,
        on_clear,
        None,
      )
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
        @core.ViewSemanticsActionHandler::set_selection((ctx, selection) => {
          let selection = @core.normalize_grapheme_range(
            @core.TextGraphemeBoundaries::new(text=query),
            selection,
          )
          @core.ViewSemanticsActionResult::accepted(
            text_control=Some({
              ..ctx.text_control,
              caret: selection.end,
              selection: if selection.is_collapsed() {
                None
              } else {
                Some(selection)
              },
              text_selection_anchor: if selection.is_collapsed() {
                None
              } else {
                Some(selection.start)
              },
            }),
            dirty=ViewPaintDirty,
          )
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
  variant~ : @style.TextFieldVariant = Filled,
  style? : @style.TextFieldStyle,
  on_submit~ : Msg? = None,
  on_clear~ : Msg? = None,
  kind~ : String = "SearchBar",
  key~ : String? = None,
) -> @core.View[Msg] {
  search_bar_control(
    query~,
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
