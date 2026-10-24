///|
/// The atmosphere view: the scenario map, full-screen.
///
/// The map used to sit beside the transcript as a *workbench* — something to
/// drag and click while reading. The product's center is the character, so the
/// map moved here: an immersive backdrop you enter deliberately (the scene
/// header's 氛围 button), look around, and leave. Tapping a person returns to
/// their private chat; tapping a place enters that place's scene.
///
/// The map paints at `Ambient` strength — the same geography as the scene
/// stage's interactive map, half strength, no name plates — and the mood
/// chips re-tint it (and the whole product's accents) without leaving the
/// view.

///|
/// The atmosphere presentation: a non-modal Dialog that fills the viewport.
/// Escape or the 退出 button leaves; the dismiss message is the same
/// `ToggleAtmosphere` the entry button dispatches, so enter and exit share one
/// piece of model state.
fn atmosphere_spec(
  model : WorldModel,
  screen : Screen,
) -> @views.PresentationSpec[Msg] {
  @views.PresentationSpec::new(
    id="new-world:atmosphere",
    kind=Dialog,
    content=atmosphere_content(model, screen).theme(
      app_theme_for(model.config.appearance()),
    ),
    modality=NonModal,
    dismiss=@views.PresentationDismissPolicy::new(
      outside_tap=false,
      escape=true,
      message=Some(ToggleAtmosphere),
    ),
    presented=true,
  )
}

///|
/// The mood chips: one per variant, the active one filled. The chip set is
/// deliberately one-character words — they sit in a row beside the exit, not
/// a panel of their own.
fn mood_switcher(mood : SceneMood) -> @moui.View[Msg] {
  let moods : Array[(String, MoodVariant)] = [
    ("静", Calm),
    ("紧", Tense),
    ("暖", Warm),
    ("寒", Cold),
    ("幽", Mysterious),
  ]
  let chips : Array[@moui.View[Msg]] = []
  for pair in moods {
    let label = pair.0
    let variant = pair.1
    // `is` on the scrutinee needs a pattern, not a binding: compare by the
    // wire form instead so the active chip is the current mood.
    let active = mood.variant().wire() == variant.wire()
    chips.push(
      button(
        (if active { "·" } else { "" }) + label,
        on_click=SetMood(variant),
        variant=if active { Tonal } else { Ghost },
        width=52.0,
        height=button_sm_height,
      ),
    )
  }
  row(chips, spacing=4.0, align=Center)
}

///|
/// The full-screen map with its own top bar: the scene title on the left, the
/// mood chips and the 退出 button on the right.
fn atmosphere_content(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let width = screen.width - screen.page_padding * 2.0
  let mood = scene_mood_of(model)
  let title = if mood.title() != "" {
    mood.title()
  } else {
    model.scenario.name()
  }
  column(
    [
      row(
        [
          text(
            title +
            (if mood.time_label() != "" {
              " · \{mood.time_label()}"
            } else {
              ""
            }),
            role=Subtitle,
            width=width - 104.0,
            height=32.0,
            align=TextStart,
          ),
          button(
            "退出",
            on_click=ToggleAtmosphere,
            variant=Ghost,
            width=72.0,
            height=button_md_height,
          ),
        ],
        spacing=action_gap,
        align=Center,
      ),
      row(
        [
          wrapped_caption(
            "拖动平移 · 点角色私聊 · 点地点进入场景 · 氛围",
            width=width - 300.0,
          ),
          mood_switcher(mood),
        ],
        spacing=6.0,
        align=Center,
      ),
      flexible(ambient_map(model, screen), weight=1.0),
    ],
    spacing=8.0,
  )
}

///|
/// The map surface itself: the same scenario drawing and hit-testing as the
/// scene stage's map, at atmosphere strength, sized to the viewport.
fn ambient_map(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let scenario = model.scenario
  let width = screen.width - screen.page_padding * 2.0
  let height = (screen.height - 160.0).max(240.0)
  let surface = canvas(
    measure=fn(_constraints : @geometry.Constraints) -> @geometry.Size {
      { width, height, }
    },
    draw=fn(ctx : PaintContext, frame : @geometry.Rect) -> Unit {
      draw_scenario(
        ctx,
        frame,
        scenario,
        pan_origin(),
        model.selected,
        style=Ambient,
      )
    },
    semantics_label="Scenario map",
  )
  let dragged = surface.on_drag(event => {
    let next = @geometry.Point::new(
      x=pan_state.val.origin.x - event.delta.x,
      y=pan_state.val.origin.y - event.delta.y,
    )
    pan_state.val = { origin: clamp_origin(next, model, width~, height~), }
    PanMap
  })
  dragged.on_tap_with_frame((position, frame) => {
    let point = @geometry.Point::new(
      x=position.x - frame.origin.x,
      y=position.y - frame.origin.y,
    )
    // A tap on a person returns to their private chat (and leaves the
    // atmosphere view); a tap on a place enters that place's scene.
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
