///|
/// The stage: the character on it, their world's atmosphere, and the reading
/// surface. This is the product's center — the left rail chooses *who*, the
/// stage is *being with them*.
///
/// The stage is three parts:
///
/// 1. the **scene header** — the character's face, name, and identity, the
///    scene title ("清虚洞府 · 夜深"), and the quiet actions: 氛围 (the
///    full-screen map), 档案 (the profile drawer), 入夜/白天 (appearance);
/// 2. the **transcript** — the novel-style reading surface
///    (`transcript_view.mbt`), optionally over a low atmosphere band;
/// 3. the **composer** — pinned to the bottom, the same at every length.
///
/// A scene (several characters at one location) reuses the same three parts
/// with a cast strip and the scenario map between header and transcript: the
/// map is the scene's spatial view, and it is the bridge to the full-screen
/// atmosphere view (`ambient_view.mbt`).

///|
/// Pan offset kept out of the app model: it is transient view state driven by
/// the drag modifier, so it cannot leak into persistence or replay. Shared
/// with the atmosphere view, which paints the same map full-screen.
priv struct PanState {
  origin : @geometry.Point
}

///|
let pan_state : Ref[PanState] = Ref({
  origin: @geometry.Point::new(x=0.0, y=0.0),
})

///|
fn pan_origin() -> @geometry.Point {
  pan_state.val.origin
}

///|
/// Clamp panning so the map cannot be dragged entirely off-screen.
///
/// `width`/`height` are the current viewport, not package constants: a
/// phone-sized map that clamped against the desktop viewport would either
/// allow panning into empty space or refuse to pan at all.
fn clamp_origin(
  point : @geometry.Point,
  model : WorldModel,
  width~ : Double,
  height~ : Double,
) -> @geometry.Point {
  let max_x = model.scenario.map_width() - width
  let max_y = model.scenario.map_height() - height
  let x = if max_x <= 0.0 { 0.0 } else { clamp(point.x, 0.0, max_x) }
  let y = if max_y <= 0.0 { 0.0 } else { clamp(point.y, 0.0, max_y) }
  @geometry.Point::new(x~, y~)
}

///|
/// The stage column for the current selection, with the optional map backdrop
/// painted underneath it: a low-interference canvas behind the transcript,
/// switched from the scene header's 背景 toggle. The transcript stays the
/// reading surface; the map is a whisper of place behind it.
fn stage_view(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let content = match model.scene_location() {
    Some(location) => scene_stage(model, screen, location)
    None => private_stage(model, screen)
  }
  if model.backdrop() {
    stack([backdrop_canvas(model, screen), content])
  } else {
    content
  }
}

///|
/// The backdrop canvas: the scenario at `Backdrop` strength, no labels, no
/// interaction — it never intercepts a tap meant for the transcript.
fn backdrop_canvas(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let scenario = model.scenario
  let width = screen.stage
  let height = (screen.height - 140.0).max(240.0)
  canvas(
    measure=fn(_constraints : @geometry.Constraints) -> @geometry.Size {
      { width, height, }
    },
    draw=fn(ctx : PaintContext, frame : @geometry.Rect) -> Unit {
      draw_scenario(ctx, frame, scenario, pan_origin(), model.selected, style=Backdrop)
    },
    semantics_label="Scenario backdrop",
  )
}

///|
/// The private chat: one character, one continuous story.
fn private_stage(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let width = screen.stage
  let rows : Array[@moui.View[Msg]] = [scene_header(model, screen)]
  match model.selected {
    None =>
      rows.push(
        column(
          [
            text(
              "在左侧选一个角色，开始一段属于你们的演绎。",
              role=Caption,
              width~,
              height=24.0,
              align=TextStart,
            ),
            spacer(weight=1.0),
            composer(model, screen, enabled=false),
          ],
          spacing=6.0,
        ),
      )
    Some(id) =>
      match model.scenario.character(id) {
        None =>
          rows.push(
            column(
              [
                text(
                  "这个角色已不在当前世界里。重新选一个角色吧。",
                  role=Caption,
                  width~,
                  height=24.0,
                  align=TextStart,
                ),
                spacer(weight=1.0),
                composer(model, screen, enabled=false),
              ],
              spacing=6.0,
            ),
          )
        Some(_card) => {
          let conversation = model.conversations.for_character(id)
          rows.push(transcript_view(model, conversation, width~))
          rows.push(
            composer(
              model,
              screen,
              enabled=true,
              waiting=conversation.pending(),
            ),
          )
        }
      }
  }
  column(rows, spacing=8.0)
}

///|
/// The scene stage: several characters at one location, with the map as their
/// shared space. Reachable from the rail's scene list and from map taps.
fn scene_stage(
  model : WorldModel,
  screen : Screen,
  location : String,
) -> @moui.View[Msg] {
  let width = screen.stage
  let cast = model.scene_cast()
  let conversation = model.conversations.for_character(scene_key(location))
  let rows : Array[@moui.View[Msg]] = [scene_header(model, screen)]
  // The cast strip: who is in this room, with faces.
  let people : Array[@moui.View[Msg]] = []
  for card in cast {
    people.push(
      column(
        [
          avatar(model, card, size=32.0, radius=16.0),
          wrapped_caption(card.name(), width=72.0),
        ],
        spacing=2.0,
        align=Center,
      ),
    )
  }
  rows.push(wrap(people, width~, spacing=10.0))
  rows.push(
    row(
      [
        wrapped_caption(
          "\{cast.length()} 人在场 · 说一句话，其中一位会回应",
          width=width - 104.0,
        ),
        button(
          "离开场景",
          on_click=LeaveScene,
          variant=Outline,
          width=96.0,
          height=button_sm_height,
        ),
      ],
      spacing=action_gap,
      align=Center,
    ),
  )
  rows.push(scenario_map(model, screen))
  rows.push(transcript_view(model, conversation, width~, label_every=true))
  rows.push(
    composer(model, screen, enabled=true, waiting=conversation.pending()),
  )
  column(rows, spacing=8.0)
}

///|
/// The scene header: who is on stage, where and when, and the quiet actions.
///
/// The name and identity are the character's; the scene line is the world's
/// mood (its title, or the world name when the player never set one) plus the
/// time label. The hairline under the row carries the mood's accent, so the
/// atmosphere is visible without a single HUD widget.
fn scene_header(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let width = screen.stage
  let theme = app_theme_for(model.config.appearance())
  let mood = scene_mood_of(model)
  let (title, identity, face) = match model.scene_location() {
    Some(location) =>
      match model.scenario.location(location) {
        Some(place) => {
          let cast = model.scene_cast()
          let first = if cast.is_empty() {
            None
          } else {
            Some(cast[0])
          }
          (
            place.name(),
            "\{cast.length()} 人在场",
            match first {
              Some(card) => avatar(model, card, size=40.0, radius=20.0)
              None => text("", width=40.0, height=40.0)
            },
          )
        }
        None => ("场景", "", text("", width=40.0, height=40.0))
      }
    None =>
      match model.selected {
        Some(id) =>
          match model.scenario.character(id) {
            Some(card) => (
              card.name(),
              identity_line(card),
              avatar(model, card, size=40.0, radius=20.0),
            )
            None => ("角色", "", text("", width=40.0, height=40.0))
          }
        None => (" New World ", "选一个角色开始", text("", width=40.0, height=40.0))
      }
  }
  // The scene line names the *scene*, not the world: the world's own title
  // already sits in the app's top bar, and repeating it here said nothing.
  let scene_line = mood.title()
  let time_line = mood.time_label()
  // The action buttons, with their widths: the row has to know how much room
  // the actions take before it can give the rest to the name.
  let action_specs : Array[(String, Double, Msg)] = [
    ("氛围", 64.0, ToggleAtmosphere),
    ("档案", 64.0, OpenDrawer(Profile)),
    (
      if model.backdrop() { "背景✓" } else { "背景" },
      72.0,
      SetBackdrop(!model.backdrop()),
    ),
    (
      if model.config.appearance() == "paper" { "入夜" } else { "白天" },
      64.0,
      SetAppearance(
        if model.config.appearance() == "paper" { "ink" } else { "paper" },
      ),
    ),
  ]
  // Medium and compact have no room for a permanent rail, so the header
  // carries the way back to the character list.
  let head_specs : Array[(String, Double, Msg)] = if screen.mode is Wide {
    action_specs
  } else {
    let with_rail : Array[(String, Double, Msg)] = [("角色", 64.0, ToggleRail)]
    for spec in action_specs {
      with_rail.push(spec)
    }
    with_rail
  }
  let actions : Array[@moui.View[Msg]] = []
  let mut actions_width = 0.0
  for spec in head_specs {
    let (label, button_width, message) = spec
    actions.push(
      button(
        label,
        on_click=message,
        variant=Ghost,
        width=button_width,
        height=button_sm_height,
      ),
    )
    actions_width += button_width
  }
  // The name column takes what the actions leave. The header used to size
  // the name and the scene line by a share of the stage and then *append* the
  // action buttons, which needed more room than the stage had and pushed the
  // right-hand actions off the edge.
  let gaps = (head_specs.length() + 2).to_double() * 8.0
  let name_width = if screen.mode is Wide {
    (width - 40.0 - actions_width - gaps).max(140.0)
  } else {
    (width - 48.0).max(120.0)
  }
  // The scene and the time ride under the name rather than in a column of
  // their own: one flexible column cannot overflow.
  let identity_column = column(
    [
      text(title, role=Title, width=name_width, height=28.0, align=TextStart),
      text(
        identity,
        role=Caption,
        width=name_width,
        height=18.0,
        align=TextStart,
      ),
      if scene_line != "" || time_line != "" {
        text(
          scene_line + (if time_line != "" { " · \{time_line}" } else { "" }),
          role=Caption,
          width=name_width,
          height=18.0,
          align=TextStart,
        )
      } else {
        empty()
      },
    ],
    spacing=2.0,
  )
  let head = if screen.mode is Wide {
    row(
      [face, identity_column, spacer(weight=1.0)] + actions,
      spacing=8.0,
      align=Center,
    )
  } else {
    // Narrow: the actions wrap onto their own row instead of squeezing the
    // name into nothing.
    column(
      [
        row([face, identity_column], spacing=8.0, align=Center),
        wrap(actions, width=width, spacing=4.0),
      ],
      spacing=6.0,
    )
  }
  column(
    [
      head,
      // The mood hairline: one pixel of the scene's accent under the header.
      // The container carries the size, and its child is a true zero-size
      // node: a text box is at least one line tall (the "1px" line came out
      // as a fat band), and a divider fills the whole row (which stretched
      // the stage to the window's width).
      container(
        empty(),
        width~,
        height=1.0,
        background=mood_accent(theme, mood.variant()).multiply_alpha(0.5),
        corner_radius=0.0,
      ),
    ],
    spacing=6.0,
  )
}

///|
/// The scene mood in effect for the current selection: the conversation's
/// override when it has one, the world's default otherwise.
fn scene_mood_of(model : WorldModel) -> SceneMood {
  let key = match model.scene_location() {
    Some(location) => scene_key(location)
    None =>
      match model.selected {
        Some(id) => id
        None => ""
      }
  }
  match model.conversations.for_character(key).mood() {
    Some(mood) => mood
    None => model.scenario.mood()
  }
}

///|
/// A card's one-line identity for the header: the first sentence of the
/// persona, or the setting when the persona is empty. Long enough to place
/// the character, short enough to sit under a name.
fn identity_line(card : CharacterCard) -> String {
  let persona = card.persona().trim().to_owned()
  let source = if persona != "" { persona } else { card.setting() }
  if source == "" {
    return ""
  }
  let mut line = ""
  for ch in source {
    if ch == '。' || ch == '；' {
      break
    }
    line += ch.to_string()
  }
  if line.length() > 18 {
    "\{line[0:18]}…"
  } else {
    line
  }
}

///|
/// The draggable scenario map, sized to the screen.
///
/// The scene's spatial view: the map keeps its designed height and the
/// transcript takes the rest. Panning is transient view state driven by the
/// drag modifier, so scrolling never enters the model.
fn scenario_map(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let scenario = model.scenario
  let width = screen.stage
  let aspect = scenario.map_height() / scenario.map_width()
  let height = (width * aspect).min(220.0).max(120.0)
  let surface = canvas(
    measure=fn(_constraints : @geometry.Constraints) -> @geometry.Size {
      { width, height, }
    },
    draw=fn(ctx : PaintContext, frame : @geometry.Rect) -> Unit {
      draw_scenario(ctx, frame, scenario, pan_origin(), model.selected)
    },
    semantics_label="Scenario map",
  )
  let dragged = surface.on_drag(event => {
    let next = @geometry.Point::new(
      x=pan_state.val.origin.x - event.delta.x,
      y=pan_state.val.origin.y - event.delta.y,
    )
    pan_state.val = { origin: clamp_origin(next, model, width~, height~), }
    // Panning is a repaint, not a selection change: dispatching `Select` here
    // re-selected the same character on every drag frame.
    PanMap
  })
  dragged.on_tap_with_frame((position, frame) => {
    let point = @geometry.Point::new(
      x=position.x - frame.origin.x,
      y=position.y - frame.origin.y,
    )
    // A tap on a person opens their private chat; a tap on a place enters that
    // place's scene.
    match character_at(scenario, pan_origin(), point) {
      Some(id) => Select(Some(id))
      None =>
        match location_at(scenario, pan_origin(), point) {
          Some(location) => EnterScene(location)
          None => PanMap
        }
    }
  })
}
