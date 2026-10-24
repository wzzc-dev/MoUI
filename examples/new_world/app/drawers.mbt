///|
/// The side drawers: everything the old permanent right rail showed, now on
/// demand. The stage keeps its full width for reading; the drawers answer
/// "who is this character", "what do they remember", "which model is
/// answering", and "what happened" without any of it occupying the screen
/// while you are simply *being* with the character.
///
/// The framework's presentation system owns placement and dismissal: the
/// drawer is a `Popover` anchored to the viewport's right edge, non-modal
/// with an outside-tap barrier, so tapping the transcript closes it. The app
/// model owns only *which* drawer is open (`WorldModel::drawer`).

///|
/// The drawer presentations for the current model state: exactly one when a
/// drawer is open, none otherwise.
fn drawer_specs(
  model : WorldModel,
  screen : Screen,
) -> Array[@views.PresentationSpec[Msg]] {
  match model.drawer {
    None => []
    Some(kind) =>
      [
        @views.PresentationSpec::new(
          id="new-world:drawer",
          kind=Popover,
          // Each presentation carries the theme: the overlay host is a sibling
          // of the app now, so the environment does not reach it on its own.
          content=drawer_content(model, screen, kind).theme(
            app_theme_for(model.config.appearance()),
          ),
          anchor=Viewport(@geometry.Point::new(x=screen.width, y=0.0)),
          placement=Some(
            @views.PresentationPlacement::new(
              candidates=[RightStart],
              viewport_insets=@geometry.Insets::all(10.0),
            ),
          ),
          modality=NonModal,
          dismiss=@views.PresentationDismissPolicy::new(
            outside_tap=true,
            escape=true,
            message=Some(CloseDrawer),
          ),
          presented=true,
        ),
      ]
  }
}

///|
/// The drawer's panel for one kind: a titled card over a scrolling body.
fn drawer_content(
  model : WorldModel,
  screen : Screen,
  kind : DrawerKind,
) -> @moui.View[Msg] {
  let width = screen.drawer_width
  let title = match kind {
    Profile => "角色档案"
    Memory => "长久记忆"
    Model => "模型状态"
    Events => "事件"
    Prompt => "这一轮的提示词"
    WorldBook => "世界书"
  }
  let body : @moui.View[Msg] = match kind {
    Profile => profile_body(model, width)
    Memory => memory_body(model, width)
    Model => model_body(model, width)
    Events => events_body(model, width)
    Prompt => prompt_body(model, width)
    WorldBook => world_book_body(model, width)
  }
  card(
    column(
      [
        row(
          [
            text(
              title,
              role=Subtitle,
              width=width - 96.0,
              height=28.0,
              align=TextStart,
            ),
            button(
              "关闭",
              on_click=CloseDrawer,
              variant=Ghost,
              width=64.0,
              height=button_sm_height,
            ),
          ],
          spacing=action_gap,
          align=Center,
        ),
        // The drawer is one place with four panels: the switcher sits here so
        // the memory book, the model status, the event log and the prompt
        // preview are all one click away.
        drawer_switcher(model, kind, width),
        divider(),
        scroll_view(
          body,
          width=width - 24.0,
          height=(screen.height - 190.0).max(200.0),
        ),
      ],
      spacing=8.0,
    ),
    width~,
    padding=12.0,
  )
}

///|
/// The drawer's own switcher: the panels of the right-hand drawer, as chips.
fn drawer_switcher(
  model : WorldModel,
  current : DrawerKind,
  width : Double,
) -> @moui.View[Msg] {
  let theme = app_theme_for(model.config.appearance())
  let panels : Array[(String, DrawerKind)] = [
    ("角色档案", Profile),
    ("长久记忆", Memory),
    ("模型状态", Model),
    ("事件", Events),
    ("提示词", Prompt),
    ("世界书", WorldBook),
  ]
  let chips : Array[@moui.View[Msg]] = []
  for panel in panels {
    let (label, kind) = panel
    chips.push(
      chip(
        label,
        selected=kind == current,
        on_click=Some(OpenDrawer(kind)),
        theme~,
        width=chip_width(label),
        height=button_sm_height,
      ),
    )
  }
  wrap(chips, width=width - 24.0, spacing=6.0, row_spacing=6.0)
}

///|
/// The world book panel: the world's own keyword-triggered lore.
///
/// The book used to be a file only: the player had to open `world_book.md`
/// in an editor to change what the world remembers. Here the entries are
/// listed, edited and saved in place.
fn world_book_body(model : WorldModel, width : Double) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  let entries = model.world_book_draft()
  rows.push(
    wrapped_caption(
      "关键词出现在对话里时，这一段会进入提示词。世界书是世界的记忆，也是它最有力的工具。",
      width~,
    ),
  )
  if entries.is_empty() {
    rows.push(
      wrapped_caption(
        "还没有条目。加一条，世界的细节就有了自己的位置。",
        width~,
      ),
    )
  }
  let editing = model.world_book_edit()
  for index, entry in entries {
    let is_open = editing == index
    rows.push(
      column(
        [
          button(
            (if is_open { "▾ " } else { "▸ " }) +
            (if entry.keys().is_empty() {
              "（无关键词）"
            } else {
              join_keys(entry)
            }),
            on_click=WorldBookEdit(index),
            variant=if is_open { Tonal } else { Ghost },
            width=(width - 24.0).max(120.0),
            height=button_sm_height,
          ),
          if is_open {
            column(
              [
                text(
                  "关键词（用逗号分隔）",
                  role=Caption,
                  width~,
                  height=18.0,
                  align=TextStart,
                ),
                text_field(
                  join_keys(entry),
                  on_input=value => WorldBookKeysChanged(value),
                  width=(width - 24.0).max(120.0),
                  height=button_md_height,
                ),
                text(
                  "内容",
                  role=Caption,
                  width~,
                  height=18.0,
                  align=TextStart,
                ),
                text_area(
                  entry.content(),
                  on_input=value => WorldBookContentChanged(value),
                  lines=4,
                  width=(width - 24.0).max(120.0),
                ),
                button(
                  "删除这条",
                  on_click=WorldBookDelete(index),
                  variant=Ghost,
                  width=96.0,
                  height=button_sm_height,
                ),
              ],
              spacing=4.0,
            )
          } else {
            wrapped_caption(entry.content(), width~)
          },
        ],
        spacing=4.0,
      ),
    )
  }
  rows.push(
    row(
      [
        button(
          "＋ 新条目",
          on_click=WorldBookAdd,
          variant=Ghost,
          width=104.0,
          height=button_md_height,
        ),
        spacer(weight=1.0),
        button(
          "保存",
          on_click=WorldBookSave,
          width=88.0,
          height=button_md_height,
        ),
      ],
      spacing=action_gap,
      align=Center,
    ),
  )
  column(rows, spacing=8.0)
}

///|

///|
/// The prompt preview: what the model will actually receive, message by
/// message.
///
/// The point is trust: the app never hides what it sends. The player can read
/// the system prompt, the world rules, the memories and the history, and
/// carry the whole thing to another tool.
fn prompt_body(model : WorldModel, width : Double) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  let messages = prompt_preview_messages(model, model.say_draft())
  if messages.is_empty() {
    rows.push(
      wrapped_caption(
        "先在舞台上选一个角色，这里会显示真正发给模型的内容。",
        width~,
      ),
    )
  } else {
    rows.push(
      wrapped_caption(
        "下面就是这一轮真正发给模型的内容（按角色分块，顺序即发送顺序）。",
        width~,
      ),
    )
    for message in messages {
      let (role, body) = message
      rows.push(
        text(
          prompt_role_label(role),
          role=Caption,
          width~,
          height=18.0,
          align=TextStart,
        ),
      )
      rows.push(wrapped_body(body, width~))
    }
    rows.push(
      button(
        "复制全部",
        on_click=CopyPromptPreview,
        width=104.0,
        height=button_md_height,
      ),
    )
  }
  column(rows, spacing=8.0)
}

///|

///|
/// The profile drawer: the whole card, block by block, in the same six-block
/// order the editor edits. Read-only here — the editor is the write path.
fn profile_body(model : WorldModel, width : Double) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  match model.selected {
    None =>
      rows.push(
        wrapped_caption(
          "先在舞台上选一个角色。这里会是 TA 的完整档案。",
          width~,
        ),
      )
    Some(id) =>
      match model.scenario.character(id) {
        None =>
          rows.push(
            wrapped_caption("这个角色已不在当前世界里。", width~),
          )
        Some(card) => {
          // The drawer's primary action comes first: the player opens a
          // dossier to change something, not to scroll to the bottom.
          rows.push(
            row(
              [
                button(
                  "编辑角色",
                  on_click=EditCharacter(id),
                  variant=Tonal,
                  width=104.0,
                  height=button_md_height,
                ),
                // The name takes what the button leaves, minus the card's
                // own padding: the drawer is a card, and its content is
                // narrower than the drawer itself.
                text(
                  card.name(),
                  role=Subtitle,
                  width=(width - 104.0 - action_gap - 24.0).max(48.0),
                  height=button_md_height,
                  align=TextEnd,
                ),
              ],
              spacing=action_gap,
              align=Center,
            ),
          )
          // The portrait in the same frame the editor uses, so the read-only
          // view and the edit view show the character the same way.
          rows.push(
            column(
              [
                portrait_frame(model, card, 120.0, 180.0, radius=10.0),
                wrapped_caption("立绘", width=120.0),
              ],
              spacing=6.0,
            ),
          )
          rows.push(profile_row("身份与背景", card.persona(), width~))
          rows.push(
            profile_row("性格与行为原则", card.principles(), width~),
          )
          rows.push(profile_row("说话风格", card.voice(), width~))
          if !card.examples().is_empty() {
            rows.push(
              profile_row("示例台词", card.examples().join("\n"), width~),
            )
          }
          let relationship = card.relationship()
          let relationship_text = [
              if relationship.user_identity() != "" {
                "玩家身份：\{relationship.user_identity()}"
              } else {
                ""
              },
              if relationship.user_name() != "" {
                "玩家称呼：\{relationship.user_name()}"
              } else {
                ""
              },
              if relationship.boundary() != "" {
                "边界：\{relationship.boundary()}"
              } else {
                ""
              },
            ]
            .filter(line => line != "")
            .join("\n")
          rows.push(
            profile_row("与用户的关系", relationship_text, width~),
          )
          rows.push(profile_row("当前情境", card.setting(), width~))
          rows.push(profile_row("开场白", card.opening(), width~))
          rows.push(profile_row("TA想要的", card.goal(), width~))
          rows.push(
            profile_row("秘密（不会主动说出）", card.secret(), width~),
          )
          rows.push(profile_row("记忆规则", card.memory_rules(), width~))
          let hint = portrait_prompt_hint(card)
          if hint != "" {
            rows.push(wrapped_caption(hint, width~))
          }
        }
      }
  }
  column(rows, spacing=10.0)
}

///|
/// One profile block: a small caption and the prose under it.
fn profile_row(
  title : String,
  body : String,
  width~ : Double,
) -> @moui.View[Msg] {
  if body == "" {
    return empty()
  }
  column(
    [wrapped_caption(title, width~), wrapped_body(body, width~)],
    spacing=2.0,
  )
}

///|
/// The memory drawer: what this character and the player have lived through.
/// The player owns the record — every entry can be pinned (always rides in
/// the prompt) or deleted, and new ones are written right here. The model may
/// only *propose*; its drafts wait below for an explicit adopt.
fn memory_body(model : WorldModel, width : Double) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  match model.selected {
    None =>
      rows.push(
        wrapped_caption(
          "选一个角色，这里会是 TA 与你的共同记忆。",
          width~,
        ),
      )
    Some(id) => {
      let entries = model.memories.for_character(id).entries()
      if entries.is_empty() {
        rows.push(
          wrapped_caption(
            "还没有记下什么。共同的经历会在这里慢慢累积，也可以现在就记一条。",
            width~,
          ),
        )
      }
      // The newest state of every progression topic; the older ones are
      // history the model does not read (but the player still can).
      let current = latest_per_topic(entries)
      for index, entry in entries {
        let pin_label = if entry.pinned() { "取消固定" } else { "固定" }
        let hidden_label = if entry.hidden() {
          "送进上下文"
        } else {
          "不进上下文"
        }
        let superseded = entry.topic() != "" && !current.contains(entry)
        rows.push(
          column(
            [
              wrapped_body(
                (if entry.pinned() { "📌 " } else { "" }) +
                (if entry.hidden() { "🔇 " } else { "" }) +
                entry.content(),
                width~,
              ),
              if entry.topic() != "" {
                wrapped_caption(
                  "进展 · " +
                  entry.topic() +
                  (if superseded {
                    "（已被更新）"
                  } else {
                    "（当前状态）"
                  }),
                  width~,
                )
              } else {
                empty()
              },
              row(
                [
                  button(
                    pin_label,
                    on_click=ToggleMemoryPin(index),
                    variant=Tonal,
                    width=88.0,
                    height=button_sm_height,
                  ),
                  button(
                    hidden_label,
                    on_click=ToggleMemoryHidden(index),
                    variant=Ghost,
                    width=96.0,
                    height=button_sm_height,
                  ),
                  button(
                    "删除",
                    on_click=DeleteMemory(index),
                    variant=Ghost,
                    width=64.0,
                    height=button_sm_height,
                  ),
                ],
                spacing=6.0,
              ),
            ],
            spacing=4.0,
          ),
        )
      }
      // The write line: what should this character always remember?
      rows.push(divider())
      rows.push(
        row(
          [
            text_field(
              model.memory_topic_input(),
              on_input=value => MemoryTopicDraftChanged(value),
              placeholder="主题（可选）",
              width=(width * 0.28).max(60.0),
              height=button_md_height,
            ),
            text_field(
              model.memory_input(),
              on_input=value => MemoryDraftChanged(value),
              on_submit=Some(AddMemory),
              placeholder="要 TA 永远记得的事…",
              width=(width * 0.72 - 88.0).max(80.0),
              height=button_md_height,
            ),
            button(
              "记住",
              on_click=AddMemory,
              width=72.0,
              height=button_md_height,
            ),
          ],
          spacing=6.0,
          align=Center,
        ),
      )
      rows.push(
        wrapped_caption(
          "同一个主题只保留最新的一条进上下文——设定会随时间变化。",
          width~,
        ),
      )
      // Pending proposals: the model suggested remembering something, and
      // nothing reaches the memory book without an explicit adopt here.
      if !model.memory_drafts().is_empty() {
        rows.push(divider())
        rows.push(wrapped_caption("AI 提议记住：", width~))
        for index, entry in model.memory_drafts() {
          rows.push(
            column(
              [
                wrapped_body(entry.content(), width~),
                row(
                  [
                    button(
                      "采纳",
                      on_click=AcceptMemory(index),
                      width=72.0,
                      height=button_sm_height,
                    ),
                    button(
                      "忽略",
                      on_click=DiscardMemory(index),
                      variant=Tonal,
                      width=72.0,
                      height=button_sm_height,
                    ),
                  ],
                  spacing=6.0,
                ),
              ],
              spacing=4.0,
            ),
          )
        }
      }
    }
  }
  column(rows, spacing=8.0)
}

///|
/// The model drawer: who is answering, and the way into the full settings.
fn model_body(model : WorldModel, width : Double) -> @moui.View[Msg] {
  let config = model.config
  let key_line = if config.api_key() == "" {
    "未填写（对话走本地剧本）"
  } else {
    "••••••••（已保存到世界库 config.json）"
  }
  column(
    [
      wrapped_caption("端点：\{config.endpoint()}", width~),
      wrapped_caption("模型：\{config.model()}", width~),
      wrapped_caption("key：\{key_line}", width~),
      wrapped_caption(
        "温度：\{config.temperature()} · 上下文：\{config.context_preset()} · 外观：\{config.appearance()}",
        width~,
      ),
      wrapped_caption(
        if config.llm_enabled() {
          "当前：回复与 AI 生成来自模型"
        } else {
          "当前：未配置完整，对话走本地剧本"
        },
        width~,
      ),
      button(
        "打开设置",
        on_click=OpenSettings,
        variant=Tonal,
        width=104.0,
        height=button_md_height,
      ),
      // The door to the prompt preview: what the app is about to send.
      button(
        "查看这一轮的提示词",
        on_click=OpenDrawer(Prompt),
        variant=Ghost,
        width=160.0,
        height=button_md_height,
      ),
    ],
    spacing=8.0,
  )
}

///|
/// The events drawer: the world's log, newest first, plus the explicit
/// time-advance action. An action, never a background tick — a provider call
/// costs money and should not be driven by a timer.
fn events_body(model : WorldModel, width : Double) -> @moui.View[Msg] {
  column(
    [
      row(
        [
          text(
            "事件",
            role=Body,
            width=width - 104.0,
            height=28.0,
            align=TextStart,
          ),
          button(
            "推进时间",
            on_click=AdvanceTime,
            variant=Tonal,
            width=96.0,
            height=button_md_height,
          ),
        ],
        spacing=action_gap,
        align=Center,
      ),
      log_panel(model, width),
    ],
    spacing=8.0,
  )
}

///|
/// The world log, newest first.
fn log_panel(model : WorldModel, width : Double) -> @moui.View[Msg] {
  let lines : Array[@moui.View[Msg]] = []
  if model.log().is_empty() {
    lines.push(
      text(
        "还没有事件。",
        role=Caption,
        width=width - 8.0,
        height=20.0,
        align=TextStart,
      ),
    )
  }
  for entry in model.log() {
    lines.push(wrapped_caption(entry, width=width - 8.0))
  }
  scroll_view(column(lines, spacing=2.0), width=width - 8.0, height=200.0)
}
