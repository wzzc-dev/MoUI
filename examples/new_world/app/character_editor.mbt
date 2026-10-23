///|
/// The six-block character editor: the creation form's serious sibling.
///
/// The product's promise is a character who stays themselves across a long
/// run, and that takes more than "name + persona": the editor organises the
/// card into the six blocks the prompt consumes — 身份与背景, 性格与行为原则,
/// 说话风格与示例台词, 与用户的关系, 当前情境与开场白, 隐藏信息与记忆规则 — plus
/// 外貌与立绘, one block on screen at a time so a full card never reads as an
/// endless form. Example lines are edited as prose (one per line); the
/// preview strip at the bottom shows the assembled card the way the prompt
/// will see it.
///
/// The editor is a full-screen page (`character_editor_spec`), opened from the
/// profile drawer's 编辑角色 button. It is a **page, not a floating card**: it
/// carries its own opaque surface, so nothing of the stage behind it shows
/// through and the form reads as one document.
///
/// Layout rules the page follows, shared with the read-only drawer:
///
/// - one measure: the form's columns are capped at `editor_measure` and
///   centred, so a wide window does not stretch a line of prose;
/// - one spacing scale: 14 between blocks, 6 between a label and its field,
///   10 between fields;
/// - one radius vocabulary: 12 for frames and cards, the framework's own
///   radius for controls;
/// - the portrait always sits in a frame (`portrait_frame`), so a
///   transparent PNG never mixes with the text under it.

///|
/// The reading measure of the editor's form: a form line of prose wants a
/// measure, not the whole window.
pub let editor_measure : Double = 720.0

///|
/// The editor's presentation: a non-modal Dialog whose content is a
/// full-viewport page. Escape leaves without saving; only 保存 writes.
fn character_editor_spec(
  model : WorldModel,
  screen : Screen,
) -> @views.PresentationSpec[Msg] {
  @views.PresentationSpec::new(
    id="new-world:editor",
    kind=Dialog,
    content=editor_content(model, screen).theme(
      app_theme_for(model.config.appearance()),
    ),
    modality=NonModal,
    dismiss=@views.PresentationDismissPolicy::new(
      outside_tap=false,
      escape=true,
      message=Some(CloseEditor),
    ),
    presented=true,
  )
}

///|
/// The editor names, in block order. The tab codes are their indexes.
fn editor_tabs() -> Array[String] {
  [
    "身份与背景",
    "性格与行为原则",
    "说话风格与示例台词",
    "与用户的关系",
    "当前情境与开场白",
    "隐藏信息与记忆规则",
    "外貌与立绘",
  ]
}

///|
/// The editor page: an opaque full-viewport surface, a header, the block
/// switcher, the visible block, the assembled preview, and the footer.
fn editor_content(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let theme = app_theme_for(model.config.appearance())
  let page = column(
    [
      editor_header(model, screen),
      editor_tab_chips(model, screen),
      editor_scroller(model, screen),
      editor_footer(),
    ],
    spacing=10.0,
  )
  // The page's own surface: the stage behind the editor must not show
  // through the form.
  container(
    page,
    width=screen.width,
    height=screen.height,
    background=theme.palette.background,
  )
}

///|
/// The header: what is being edited, and the way out.
fn editor_header(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let width = screen.width - screen.page_padding * 2.0
  let (name, identity) = match model.editor_target {
    Some(id) =>
      match model.scenario.character(id) {
        Some(card) => (card.name(), card.relationship().user_identity())
        None => (id, "")
      }
    None => ("（未选择角色）", "")
  }
  row(
    [
      column(
        [
          text(
            "编辑角色",
            role=Title,
            width=width - 200.0,
            height=30.0,
            align=TextStart,
          ),
          text(
            if identity != "" {
              name + " · " + identity
            } else {
              name
            },
            role=Caption,
            width=width - 200.0,
            height=18.0,
            align=TextStart,
          ),
        ],
        spacing=2.0,
      ),
      spacer(weight=1.0),
      button(
        "关闭",
        on_click=CloseEditor,
        variant=Ghost,
        width=72.0,
        height=button_sm_height,
      ),
    ],
    spacing=action_gap,
    align=Center,
  )
}

///|
/// The block switcher: the seven blocks as chips, wrapping when the window is
/// narrow. Chips rather than a segmented control because the labels are
/// sentences — seven of them would not fit in one control at phone width, and
/// the chips wrap instead of squeezing.
fn editor_tab_chips(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let theme = app_theme_for(model.config.appearance())
  let tabs = editor_tabs()
  let chips : Array[@moui.View[Msg]] = []
  for index, label in tabs {
    chips.push(
      chip(
        label,
        selected=index == model.editor_tab,
        on_click=Some(EditorTabChanged(index)),
        theme=theme,
        width=editor_chip_width(label),
        height=button_sm_height,
      ),
    )
  }
  // The row is labelled, so it reads as a set of *options* rather than as a
  // stray line of buttons.
  row(
    [
      text(
        "分区",
        role=Caption,
        width=44.0,
        height=button_sm_height,
        align=TextStart,
      ),
      wrap(
        chips,
        width=screen.width - screen.page_padding * 2.0 - 52.0,
        spacing=6.0,
        row_spacing=6.0,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
/// A chip is wide enough for its label: the CJK glyphs are about 13px at the
/// control font, and the chip adds its own padding on both sides.
fn editor_chip_width(label : String) -> Double {
  label.length().to_double() * 13.0 + 30.0
}

///|
/// The scrolling body: the visible block and the assembled preview, in one
/// measure, centred in the page.
fn editor_scroller(model : WorldModel, screen : Screen) -> @moui.View[Msg] {
  let width = editor_measure.min(screen.width - screen.page_padding * 2.0)
  // Header + chips + footer + the gaps between them.
  let chrome = 30.0 + 18.0 + button_sm_height + button_md_height + 40.0
  let height = (screen.height - chrome).max(200.0)
  scroll_view(
    // The measure is centred in the page: a form on a wide window reads
    // better in one column than stretched across the whole screen.
    center(
      column(
        [
          editor_block(model, model.editor_tab, width~),
          editor_preview(model, width~),
        ],
        spacing=14.0,
      ),
      width=screen.width,
    ),
    width=screen.width,
    height=height,
  )
}

///|
/// The footer: the two ways out of the page.
fn editor_footer() -> @moui.View[Msg] {
  row(
    [
      button(
        "保存",
        on_click=SaveCharacter,
        width=104.0,
        height=button_md_height,
      ),
      button(
        "取消",
        on_click=CloseEditor,
        variant=Tonal,
        width=88.0,
        height=button_md_height,
      ),
      spacer(weight=1.0),
      text(
        "关闭不会保存",
        role=Caption,
        width=160.0,
        height=button_md_height,
        align=TextEnd,
      ),
    ],
    spacing=8.0,
    align=Center,
  )
}

///|
/// One block's fields. Every field writes straight into the working draft;
/// nothing reaches the card until 保存.
fn editor_block(
  model : WorldModel,
  tab : Int32,
  width~ : Double,
) -> @moui.View[Msg] {
  let draft = model.editor_draft
  fn change(update : (CharacterDraft) -> CharacterDraft) -> Msg {
    EditorChanged(update(draft))
  }
  fn field(
    label : String,
    value : String,
    lines_ : Int32,
    update : (CharacterDraft, String) -> CharacterDraft,
  ) -> @moui.View[Msg] {
    column(
      [
        text(label, role=Caption, width=width, height=18.0, align=TextStart),
        if lines_ > 1 {
          text_area(
            value,
            on_input=text => change(draft => update(draft, text)),
            lines=lines_,
            width=width,
          )
        } else {
          text_field(
            value,
            on_input=text => change(draft => update(draft, text)),
            width=width,
          )
        },
      ],
      spacing=4.0,
    )
  }
  let rows : Array[@moui.View[Msg]] = match tab {
    // ① 身份与背景
    0 => [
      field(
        "TA是谁（必填）",
        draft.persona,
        4,
        (d, v) => d.with_persona(v),
      ),
      field(
        "TA想要什么（可选）",
        draft.goal,
        2,
        (d, v) => d.with_goal(v),
      ),
    ]
    // ② 性格与行为原则
    1 => [
      field(
        "行为原则：TA如何判断、如何行动（行为规则比形容词更能稳住人物）",
        draft.principles,
        5,
        (d, v) => d.with_principles(v),
      ),
    ]
    // ③ 说话风格与示例台词
    2 => [
      field("说话方式", draft.voice, 2, (d, v) => d.with_voice(v)),
      wrapped_caption("示例台词（一行一句，像 TA 本人说出口的话）", width~),
      text_area(
        model.editor_examples,
        on_input=text => EditorExamplesChanged(text),
        lines=5,
        width~,
      ),
    ]
    // ④ 与用户的关系
    3 => [
      field("玩家是谁", draft.user_identity, 1, (d, v) => d.with_user_identity(v)),
      field("TA怎么称呼玩家", draft.user_name, 1, (d, v) => d.with_user_name(v)),
      field("关系边界", draft.boundary, 2, (d, v) => d.with_boundary(v)),
    ]
    // ⑤ 当前情境与开场白
    4 => [
      field("当前情境", draft.setting, 3, (d, v) => d.with_setting(v)),
      field(
        "开场白：第一句话，或第一段演绎",
        draft.opening,
        4,
        (d, v) => d.with_opening(v),
      ),
    ]
    // ⑥ 隐藏信息与记忆规则
    5 => [
      field("秘密（不会主动说出）", draft.secret, 3, (d, v) => d.with_secret(v)),
      field(
        "记忆规则：长久互动中必须记住什么",
        draft.memory_rules,
        3,
        (d, v) => d.with_memory_rules(v),
      ),
    ]
    // ⑦ 外貌与立绘
    _ => [
      row(
        [
          // The portrait frame, beside the fields rather than above them, so
          // the picture never pushes the form down.
          editor_portrait(model),
          column(
            [
              field("外貌", draft.appearance, 3, (d, v) => d.with_appearance(v)),
              field(
                "立绘文件名（characters/ 下的图片名，空 = 无）",
                draft.portrait,
                1,
                (d, v) => d.with_portrait(v),
              ),
              field(
                "立绘提示词（拿去生图用）",
                draft.portrait_prompt,
                3,
                (d, v) => d.with_portrait_prompt(v),
              ),
            ],
            spacing=10.0,
          ),
        ],
        spacing=16.0,
        align=Start,
      ),
    ]
  }
  column(rows, spacing=10.0)
}

///|
/// The portrait preview in the editor: a framed picture with a caption.
///
/// The frame keeps a transparent PNG off the form's text; the caption says
/// where the file has to live, so the field and the picture describe the same
/// thing.
fn editor_portrait(model : WorldModel) -> @moui.View[Msg] {
  // An upright frame (2:3), the shape a character portrait has. A picture of
  // another shape is cropped to fill it, equally on both sides.
  let frame_width = 240.0
  let frame_height = 360.0
  let card = match model.editor_target {
    Some(id) => model.scenario.character(id)
    None => None
  }
  let picture = match card {
    Some(entry) => portrait_frame(model, entry, frame_width, frame_height)
    None =>
      container(
        text("", width=frame_width, height=frame_height),
        width=frame_width,
        height=frame_height,
      )
  }
  column(
    [
      picture,
      wrapped_caption("立绘预览（透明底已垫好）", width=frame_width),
    ],
    spacing=6.0,
  )
}

///|
/// The preview strip: the assembled card, the way the prompt will read it.
/// One paragraph per non-empty block, so a player can eyeball the character
/// before saving.
fn editor_preview(model : WorldModel, width~ : Double) -> @moui.View[Msg] {
  let theme = app_theme_for(model.config.appearance())
  let draft = model.editor_draft
  let blocks : Array[String] = []
  if draft.persona != "" {
    blocks.push("【你是\{draft.name}】\{draft.persona}")
  }
  if draft.principles != "" {
    blocks.push("【行为原则】\{draft.principles}")
  }
  if draft.voice != "" {
    blocks.push("【说话方式】\{draft.voice}")
  }
  if draft.user_identity != "" || draft.user_name != "" {
    blocks.push(
      "【与用户的关系】玩家是\{draft.user_identity}，你称呼TA「\{draft.user_name}」",
    )
  }
  if draft.setting != "" {
    blocks.push("【当前情境】\{draft.setting}")
  }
  if draft.opening != "" {
    blocks.push("【开场白】\{draft.opening}")
  }
  if draft.secret != "" {
    blocks.push("【秘密】\{draft.secret}")
  }
  if draft.memory_rules != "" {
    blocks.push("【记忆规则】\{draft.memory_rules}")
  }
  column(
    [
      text(
        "预览（提示词将按此组装）",
        role=Caption,
        width=width,
        height=18.0,
        align=TextStart,
      ),
      container(
        wrapped_body(
          if blocks.is_empty() { "（还没有内容）" } else { blocks.join("\n") },
          width=width - 32.0,
        ),
        width=width,
        background=theme.palette.surface_variant,
        corner_radius=12.0,
        padding=16.0,
      ),
    ],
    spacing=6.0,
  )
}
