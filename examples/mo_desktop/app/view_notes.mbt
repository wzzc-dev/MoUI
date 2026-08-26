// Mo Notes: a lightweight persisted notes app. Sidebar list + plain-text
// editor; state lives on the model and rides the desktop snapshot.

///|
fn notes_body(
  model : DesktopModel,
  metrics : WindowMetrics,
  palette : DesktopPalette,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  let body_height = metrics.height - 40.0
  let toolbar_height = 46.0
  let sidebar_width = if metrics.compact { 0.0 } else { 172.0 }
  let editor_width = metrics.width - sidebar_width - 24.0
  let editor_height = body_height - toolbar_height - 24.0
  let has_selection = model.active_note >= 0 &&
    model.active_note < model.notes.length()
  // macOS Notes-style header row: new/delete on the left, count on the right.
  let toolbar = @views.row(
    [
      @views.button(
        "New Note",
        on_click=AddNote,
        icon=Some(@views.IconName::Plus),
        variant=@views.ButtonVariant::Tonal,
        theme~,
        width=104.0,
        height=30.0,
      ),
      if has_selection {
        @views.button(
          "Delete",
          on_click=DeleteNote(model.active_note),
          icon=Some(@views.IconName::Trash),
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=92.0,
          height=30.0,
        )
      } else {
        @views.spacer(min_length=0.0, weight=0.0).frame(width=92.0, height=30.0)
      },
      @views.spacer(min_length=0.0, weight=1.0),
      @views.text(
        "\{model.notes.length()} notes",
        role=@views.TextRole::Caption,
        theme~,
        width=64.0,
        height=22.0,
      ).foreground(palette.muted),
    ],
    spacing=10.0,
    align=@views.CrossAlign::Center,
  ).frame(width=metrics.width - 24.0, height=toolbar_height)
  // The sidebar lists first lines; tapping selects the note for editing.
  let rows : Array[@moui.View[Msg]] = []
  for index, _body in model.notes {
    let selected = index == model.active_note
    rows.push(
      @views.container(
        @views.text(
          model.note_title(index),
          role=@views.TextRole::Body,
          theme~,
          width=sidebar_width - 24.0,
          height=24.0,
        ).foreground(if selected { palette.foreground } else { palette.muted }),
        width=sidebar_width - 12.0,
        height=34.0,
        background=if selected {
          palette.accent_soft
        } else {
          rgba8(0, 0, 0, a=0.0)
        },
        corner_radius=8.0,
        padding=6.0,
      )
      .on_tap(SelectNote(index))
      .accessibility_label("Select note " + model.note_title(index)),
    )
  }
  let sidebar = if sidebar_width > 0.0 {
    @views.column(rows, spacing=2.0, align=@views.CrossAlign::Start)
    .frame(width=sidebar_width, height=editor_height)
    .clip()
  } else {
    @views.spacer(min_length=0.0, weight=0.0).frame(
      width=0.0,
      height=editor_height,
    )
  }
  let editor = @views.text_area(
    model.active_note_body(),
    on_input=value => NoteBodyChanged(value),
    placeholder="Start writing…",
    theme~,
    width=editor_width,
    line_height=26.0,
    lines=(editor_height / 26.0).to_int(),
  ).accessibility_label("Note body")
  @views.column(
    [
      toolbar,
      @views.row(
        [sidebar, editor],
        spacing=12.0,
        align=@views.CrossAlign::Start,
      ).frame(width=metrics.width, height=editor_height),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Start,
  )
}
