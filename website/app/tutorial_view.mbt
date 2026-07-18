///|
priv struct TutorialLesson {
  id : String
  number : String
  title_key : String
  subtitle_key : String
  summary_key : String
  concept_keys : Array[String]
  accent : @graphics.Color
}

///|
fn Model::tutorial_content(
  self : Model,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  column(
    [
      tutorial_intro_section(self.locale, theme, metrics),
      tutorial_course_section(self.locale, theme, metrics),
      tutorial_action_section(self.locale, theme, metrics),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn tutorial_intro_section(
  locale : String,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let summary_width = if metrics.compact {
    metrics.content_width
  } else {
    min_website_double(760.0, metrics.content_width)
  }
  section_shell(
    theme,
    metrics,
    column(
      [
        container(
          spacer(min_length=0.0),
          width=64.0,
          height=4.0,
          background=website_blue(theme),
          corner_radius=2.0,
          theme~,
          padding=0.0,
        ),
        badge(
          website_message(locale, "tutorial.badge"),
          tone=@views.BadgeTone::Accent,
          theme~,
          width=116.0,
          height=26.0,
        ),
        text(
          website_message(locale, "tutorial.title"),
          theme~,
          width=metrics.content_width,
          height=if metrics.compact { 46.0 } else { 54.0 },
          align=@text.TextAlign::TextStart,
        )
        .font(
          @text.FontSpec::new(
            size=if metrics.compact { 34.0 } else { 42.0 },
            weight=850,
          ),
        )
        .foreground(theme.palette.foreground),
        text(
          website_message(locale, "tutorial.subtitle"),
          theme~,
          width=metrics.content_width,
          height=32.0,
          align=@text.TextAlign::TextStart,
        )
        .font(@text.FontSpec::new(size=18.0, weight=720))
        .foreground(website_green(theme)),
        tutorial_wrapped_text(
          theme,
          summary_width,
          website_message(locale, "tutorial.summary"),
          if metrics.compact {
            14.0
          } else {
            15.0
          },
          23.0,
        ),
        row(
          [
            badge(
              website_message_with(locale, "tutorial.lesson_count", [
                ("count", "6"),
              ]),
              theme~,
              width=92.0,
              height=24.0,
            ),
            badge(
              website_message(locale, "tutorial.moonbit_badge"),
              theme~,
              width=84.0,
              height=24.0,
            ),
          ],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Start,
    ).frame(width=metrics.content_width),
    top=if metrics.compact { 48.0 } else { 68.0 },
    bottom=if metrics.compact { 48.0 } else { 64.0 },
    background=Some(showcase_section_background(theme)),
  )
}

///|
fn tutorial_course_section(
  locale : String,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let lessons = tutorial_lessons(theme)
  let lesson_columns = if metrics.compact { 1 } else { 2 }
  let column_spacing = if metrics.compact { 0.0 } else { 16.0 }
  let card_width = (
      metrics.content_width - column_spacing * (lesson_columns - 1).to_double()
    ) /
    lesson_columns.to_double()
  let cards : Array[@moui.View[Msg]] = []
  for lesson in lessons {
    cards.push(
      tutorial_lesson_card(lesson, locale, theme, card_width, metrics.compact),
    )
  }
  section_shell(
    theme,
    metrics,
    column(
      [
        column(
          [
            text(
              website_message(locale, "tutorial.course_map.title"),
              theme~,
              width=metrics.content_width,
              height=40.0,
              align=@text.TextAlign::TextStart,
            )
            .font(@text.FontSpec::new(size=28.0, weight=820))
            .foreground(theme.palette.foreground),
            tutorial_wrapped_text(
              theme,
              metrics.content_width,
              website_message(locale, "tutorial.course_map.summary"),
              14.0,
              22.0,
            ),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Start,
        ),
        grid(cards, columns=lesson_columns, row_spacing=16.0, column_spacing~),
      ],
      spacing=26.0,
      align=@views.CrossAlign::Start,
    ).frame(width=metrics.content_width),
    top=if metrics.compact { 48.0 } else { 64.0 },
    bottom=if metrics.compact { 48.0 } else { 68.0 },
    background=Some(theme.palette.background),
  )
}

///|
fn tutorial_lesson_card(
  lesson : TutorialLesson,
  locale : String,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[Msg] {
  let inner_width = max_website_double(220.0, width - 36.0)
  let id_width = max_website_double(80.0, inner_width - 112.0)
  let tags : Array[@moui.View[Msg]] = []
  for concept_key in lesson.concept_keys {
    tags.push(
      tag(website_message(locale, concept_key), theme~, width=96.0, height=24.0),
    )
  }
  container(
    column(
      [
        container(
          spacer(min_length=0.0),
          width=inner_width,
          height=4.0,
          background=lesson.accent,
          corner_radius=2.0,
          theme~,
          padding=0.0,
        ),
        row(
          [
            badge(
              website_message_with(locale, "tutorial.lesson.badge", [
                ("number", lesson.number),
              ]),
              tone=@views.BadgeTone::Accent,
              theme~,
              width=96.0,
              height=24.0,
            ),
            spacer(min_length=0.0, weight=1.0),
            text(
              lesson.id,
              role=@views.TextRole::Mono,
              theme~,
              width=id_width,
              height=24.0,
              align=@text.TextAlign::TextEnd,
            ).foreground(theme.palette.muted),
          ],
          spacing=8.0,
          align=@views.CrossAlign::Center,
        ).frame(width=inner_width),
        text(
          website_message(locale, lesson.title_key),
          theme~,
          width=inner_width,
          height=28.0,
          align=@text.TextAlign::TextStart,
        )
        .font(@text.FontSpec::new(size=20.0, weight=800))
        .foreground(theme.palette.foreground),
        text(
          website_message(locale, lesson.subtitle_key),
          theme~,
          width=inner_width,
          height=22.0,
          align=@text.TextAlign::TextStart,
        )
        .font(@text.FontSpec::new(size=14.0, weight=650))
        .foreground(lesson.accent),
        tutorial_wrapped_text(
          theme,
          inner_width,
          website_message(locale, lesson.summary_key),
          13.0,
          20.0,
        ),
        row(tags, spacing=8.0, align=@views.CrossAlign::Center),
        button(
          website_message(locale, "action.open_lesson"),
          on_click=OpenPlaygroundLesson(lesson.id),
          variant=@views.ButtonVariant::Tonal,
          icon=Some(@views.IconName::ArrowRight),
          theme~,
          width=154.0,
          height=36.0,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Start,
    ).frame(width=inner_width),
    width~,
    height=if compact { 284.0 } else { 264.0 },
    background=soft_panel_background(theme),
    corner_radius=8.0,
    theme~,
    padding=18.0,
  ).border(website_border(theme))
}

///|
fn tutorial_action_section(
  locale : String,
  theme : @moui.Theme,
  metrics : Metrics,
) -> @moui.View[Msg] {
  let copy_width = if metrics.compact {
    metrics.content_width
  } else {
    max_website_double(320.0, metrics.content_width - 240.0)
  }
  let copy = column(
    [
      text(
        website_message(locale, "tutorial.continue.title"),
        theme~,
        width=copy_width,
        height=34.0,
        align=@text.TextAlign::TextStart,
      )
      .font(@text.FontSpec::new(size=24.0, weight=820))
      .foreground(theme.palette.foreground),
      tutorial_wrapped_text(
        theme,
        copy_width,
        website_message(locale, "tutorial.continue.summary"),
        14.0,
        22.0,
      ),
    ],
    spacing=4.0,
    align=@views.CrossAlign::Start,
  ).frame(width=copy_width)
  let action = button(
    website_message(locale, "action.open_playground"),
    on_click=OpenPlayground,
    variant=@views.ButtonVariant::Primary,
    icon=Some(@views.IconName::ArrowRight),
    theme~,
    width=176.0,
    height=42.0,
  )
  let content = if metrics.compact {
    column([copy, action], spacing=20.0, align=@views.CrossAlign::Start)
  } else {
    row(
      [copy, spacer(min_length=0.0, weight=1.0), action],
      spacing=20.0,
      align=@views.CrossAlign::Center,
    ).frame(width=metrics.content_width)
  }
  section_shell(
    theme,
    metrics,
    content,
    top=44.0,
    bottom=44.0,
    background=Some(theme.palette.primary_container),
  )
}

///|
fn tutorial_lessons(theme : @moui.Theme) -> Array[TutorialLesson] {
  [
    {
      id: "01-hello-world",
      number: "01",
      title_key: "tutorial.lesson.01.title",
      subtitle_key: "tutorial.lesson.01.subtitle",
      summary_key: "tutorial.lesson.01.summary",
      concept_keys: ["tutorial.concept.program", "tutorial.concept.view"],
      accent: website_blue(theme),
    },
    {
      id: "02-layout",
      number: "02",
      title_key: "tutorial.lesson.02.title",
      subtitle_key: "tutorial.lesson.02.subtitle",
      summary_key: "tutorial.lesson.02.summary",
      concept_keys: ["tutorial.concept.row", "tutorial.concept.column"],
      accent: website_green(theme),
    },
    {
      id: "03-state-events",
      number: "03",
      title_key: "tutorial.lesson.03.title",
      subtitle_key: "tutorial.lesson.03.subtitle",
      summary_key: "tutorial.lesson.03.summary",
      concept_keys: ["tutorial.concept.model", "tutorial.concept.msg"],
      accent: website_amber(theme),
    },
    {
      id: "04-theme-styling",
      number: "04",
      title_key: "tutorial.lesson.04.title",
      subtitle_key: "tutorial.lesson.04.subtitle",
      summary_key: "tutorial.lesson.04.summary",
      concept_keys: ["tutorial.concept.theme", "tutorial.concept.tokens"],
      accent: website_blue(theme),
    },
    {
      id: "05-component-composition",
      number: "05",
      title_key: "tutorial.lesson.05.title",
      subtitle_key: "tutorial.lesson.05.subtitle",
      summary_key: "tutorial.lesson.05.summary",
      concept_keys: ["tutorial.concept.component", "tutorial.concept.reuse"],
      accent: website_green(theme),
    },
    {
      id: "06-animation",
      number: "06",
      title_key: "tutorial.lesson.06.title",
      subtitle_key: "tutorial.lesson.06.subtitle",
      summary_key: "tutorial.lesson.06.summary",
      concept_keys: ["tutorial.concept.canvas", "tutorial.concept.now_ms"],
      accent: website_amber(theme),
    },
  ]
}

///|
fn tutorial_wrapped_text(
  theme : @moui.Theme,
  width : Double,
  value : String,
  font_size : Double,
  line_height : Double,
) -> @moui.View[Msg] {
  let font = @text.FontSpec::new(size=font_size, weight=460)
  let lines : Array[@moui.View[Msg]] = []
  for line in website_doc_wrap_lines(value, width, font_size) {
    lines.push(
      text(
        line,
        theme~,
        width~,
        height=line_height,
        align=@text.TextAlign::TextStart,
      )
      .font(font)
      .foreground(theme.palette.muted),
    )
  }
  column(lines, spacing=0.0, align=@views.CrossAlign::Start)
}
