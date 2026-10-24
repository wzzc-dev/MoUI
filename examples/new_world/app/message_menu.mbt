///|
/// The per-line "more" menu: the always-visible action row (‹ › 改 删 分叉)
/// retired into a quiet `⋯` that opens a context menu.
///
/// The framework's presentation system owns the placement and the dismissal:
/// `popup_host` anchors the menu to the button's own frame (escaping the
/// transcript's scroll clip), a `NonModal` + `outside_tap` barrier closes it
/// on any tap elsewhere, and the app model only owns *which* line is open
/// (`WorldModel::message_menu`). Every item dispatches a message that already
/// existed — swipe, edit, delete, branch, regenerate — so the dead-UI gate
/// sees real construction sites and no new protocol is invented.

///|
/// How many recent lines still render as Markdown; older history degrades to
/// plain wrapped text. The transcript is capped at `chat_history_limit`, so
/// this bounds the viewer count without a virtualization scheme.
pub let markdown_recent_lines : Int32 = 12

///|
/// The `⋯` button for one line, wrapped in its own popup host when this
/// line's menu is the open one.
///
/// The host is the button, so the menu opens anchored to it and closes when
/// the player taps anywhere else — including on another line's `⋯`, which
/// simply opens that line's menu instead. The host (and its menu content) is
/// only built while the menu is open, so a closed menu costs nothing and
/// never appears in the tree.
fn more_button(model : WorldModel, index : Int32) -> @moui.View[Msg] {
  let trigger = button(
    "⋯",
    on_click=OpenMessageMenu(index),
    variant=Ghost,
    width=28.0,
    height=20.0,
  )
  if model.message_menu == Some(index) {
    popup_host(trigger, [message_menu_spec(model, index)])
  } else {
    trigger
  }
}

///|
/// The menu's presentation declaration. `presented` is exactly "this line's
/// menu is the open one", so at most one menu exists in the tree at a time.
fn message_menu_spec(
  model : WorldModel,
  index : Int32,
) -> @views.PresentationSpec[Msg] {
  @views.PresentationSpec::new(
    id="new-world:message-menu",
    kind=ContextMenu,
    content=message_menu_content(model, index).theme(
      app_theme_for(model.config.appearance()),
    ),
    anchor=HostBase,
    placement=Some(
      @views.PresentationPlacement::new(
        candidates=[BelowEnd, AboveEnd],
        viewport_insets=@geometry.Insets::all(6.0),
      ),
    ),
    modality=NonModal,
    dismiss=@views.PresentationDismissPolicy::new(
      outside_tap=true,
      escape=true,
      message=Some(CloseMessageMenu),
    ),
    presented=model.message_menu == Some(index),
  )
}

///|
/// The menu itself: a quiet card of text buttons. Regenerate only appears on
/// the newest character line (the only one a regeneration can replace), the
/// swipe pair only when candidates exist, and every item closes the menu on
/// the way out.
fn message_menu_content(model : WorldModel, index : Int32) -> @moui.View[Msg] {
  let theme = app_theme_for(model.config.appearance())
  let conversation = model.conversations.for_character(
    match model.scene_location() {
      Some(location) => scene_key(location)
      None =>
        match model.selected {
          Some(id) => id
          None => ""
        }
    },
  )
  let lines = conversation.lines()
  let line = if index >= 0 && index < lines.length() {
    Some(lines[index])
  } else {
    None
  }
  let rows : Array[@moui.View[Msg]] = []
  match line {
    None => ()
    Some(entry) => {
      let last_character = index == lines.length() - 1 &&
        entry.speaker() is Character(_)
      if last_character {
        rows.push(menu_item("重新生成", RegenerateReply, theme))
      }
      if entry.has_alternatives() {
        rows.push(menu_item("上一版", SwipeReply(index, -1), theme))
        rows.push(menu_item("下一版", SwipeReply(index, 1), theme))
      }
      rows.push(menu_item("改这句", EditLine(index), theme))
      rows.push(destructive_item("删这句", DeleteLine(index), theme))
      rows.push(menu_item("从此分叉", BranchAt(index), theme))
    }
  }
  rows.push(menu_item("关闭", CloseMessageMenu, theme))
  card(column(rows, spacing=2.0), padding=6.0)
}

///|
/// One menu row: full-width, left-aligned, quiet. A button rather than a
/// `MenuItem` so the labels read as sentences ("改这句") and the tree stays
/// assertable without a renderer. The compact theme keeps the row's metrics
/// tight; the palette is the appearance's.
fn menu_item(
  label : String,
  on_click : Msg,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  button(
    label,
    on_click~,
    variant=Ghost,
    theme=compact_action_theme(theme),
    width=132.0,
    height=button_sm_height,
  )
}

///|
/// The destructive menu row: same shape as `menu_item`, wearing the danger
/// colour so "删这句" reads at a glance without a filled red block.
fn destructive_item(
  label : String,
  on_click : Msg,
  theme : @moui.Theme,
) -> @moui.View[Msg] {
  button(
    label,
    on_click~,
    variant=Ghost,
    theme=compact_action_theme(theme),
    style=destructive_ghost_style(theme),
    width=132.0,
    height=button_sm_height,
  )
}
