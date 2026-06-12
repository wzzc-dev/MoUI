///|
fn test_runtime(root : @core.View[Unit]) -> @core.AppRuntime {
  @core.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=640.0, height=480.0),
  )
}

///|
test "controls and modifiers expose semantics" {
  let runtime = test_runtime(
    @views.column([
      @views.toggle_switch("Enabled", true, on_change=_value => ()),
      @views.progress(0.6, width=120.0),
      @views.text("Tip").semantics_role(@core.SemanticsRole::Tooltip),
    ]),
  )
  let semantics = runtime.semantics()
  inspect(semantics.children.length() > 0, content="true")
}

test "controlled and binding view facades build together" {
  let enabled = @core.State::new(false)
  let draft = @core.State::new("draft")
  let query = @core.State::new("query")
  let choice = @core.State::new("alpha")
  let selected_date = @core.State::new(
    @core.DateValue::new(year=2026, month=5, day=21),
  )
  let tabs = [
    @views.tab_item(route="alpha", label="Alpha", view=@views.text("Tab Alpha")),
    @views.tab_item(route="beta", label="Beta", view=@views.text("Tab Beta")),
  ]
  let picker_items = [
    @views.picker_item("alpha", "Alpha"),
    @views.picker_item("beta", "Beta"),
  ]
  let runtime = test_runtime(
    @views.column(
      [
        @views.text_field("Draft", on_input=_value => ()),
        @views.text_field_binding(draft.binding()),
        @views.searchbar(query="Query", on_input=_value => ()),
        @views.searchbar_binding(query=query.binding()),
        @views.checkbox("Enabled", checked=enabled.get(), on_change=_value => ()),
        @views.checkbox_binding("Enabled binding", checked=enabled.binding()),
        @views.toggle("Toggle", enabled.get(), on_change=_value => ()),
        @views.toggle_binding("Toggle binding", enabled.binding()),
        @views.toggle_switch_binding("Toggle switch binding", enabled.binding()),
        @views.radio("Radio", enabled.get(), on_change=_value => ()),
        @views.radio_binding("Radio binding", enabled.binding()),
        @views.picker(picker_items, selected=choice.get(), on_select=_value => {
          ()
        }),
        @views.picker_binding(picker_items, selected=choice.binding()),
        @views.datepicker(selected=selected_date.get(), on_select=_value => ()),
        @views.datepicker_binding(selected=selected_date.binding()),
        @views.tab_view("alpha", tabs, on_select=_value => ()),
        @views.tab_view_binding(choice.binding(), tabs, on_select=_value => ()),
        @views.rich_text_editor_binding(
          draft.binding(),
          text => @core.RichTextDocument::plain(text),
          placeholder="Rich",
          width=240.0,
          height=96.0,
        ),
        @views.markdown_editor_binding(
          draft.binding(),
          text => @core.RichTextDocument::plain(text),
          placeholder="Markdown",
          width=240.0,
          height=96.0,
        ),
      ],
      spacing=8.0,
    ),
  )
  inspect(runtime.layout().children.length() > 0, content="true")
}
