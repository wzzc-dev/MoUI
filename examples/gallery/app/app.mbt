///|
/// Visual gallery: the reference surface for the Desktop preset. Everything
/// here is default tokens (layout scale, type scale, elevation, state layers)
/// plus stock controls, so a screenshot of this app is a screenshot of the
/// framework's default look. Keep example-local styling to layout only — no
/// per-control colors, fonts or radii.
using @views {
  badge,
  button,
  card,
  checkbox,
  choice_item,
  column,
  divider,
  icon,
  icon_svg,
  lucide_icon,
  sf_symbol_icon,
  padding,
  progress,
  row,
  scroll_view,
  segmented_control,
  sidebar,
  sidebar_item,
  slider,
  spacer,
  stat_card,
  tag,
  text,
  text_field,
  toggle,
}

///|
pub struct Model {
  dark : Bool
  service_name : String
  notifications : Bool
  volume : Double
}

///|
pub(all) enum Msg {
  SetDark(Bool)
  SetServiceName(String)
  SetNotifications(Bool)
  SetVolume(Double)
}

///|
pub fn Model::new() -> Model {
  {
    dark: false,
    service_name: "api-gateway",
    notifications: true,
    volume: 64.0,
  }
}

///|
pub fn Model::update(self : Model, msg : Msg) -> Model {
  update(self, msg)
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    SetDark(dark) => { ..model, dark, }
    SetServiceName(name) => { ..model, service_name: name, }
    SetNotifications(on) => { ..model, notifications: on, }
    SetVolume(volume) => { ..model, volume, }
  }
}

///|
fn gallery_theme(model : Model) -> @moui.Theme {
  if model.dark {
    @views.desktop_dark_theme()
  } else {
    @views.desktop_light_theme()
  }
}

///|
fn set_name_msg(value : String) -> Msg {
  SetServiceName(value)
}

///|
fn set_notifications_msg(value : Bool) -> Msg {
  SetNotifications(value)
}

///|
fn set_volume_msg(value : Double) -> Msg {
  SetVolume(value)
}

///|
fn set_dark_msg(value : Bool) -> Msg {
  SetDark(value)
}

///|
fn page_header(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  row(
    [
      column(
        [
          text("MoUI Gallery", role=Display, theme~),
          text(
            "Desktop preset · 14 px body · 32 px controls · layered elevation",
            role=Caption,
            theme~,
          ),
        ],
        spacing=2.0,
        align=Start,
      ),
      spacer(weight=1.0),
      segmented_control(
        [choice_item("light", "Light"), choice_item("dark", "Dark")],
        selected=if model.dark { "dark" } else { "light" },
        on_select=id => SetDark(id == "dark"),
        theme~,
      ),
      button("Primary action", on_click=SetDark(model.dark), theme~),
    ],
    spacing=12.0,
    align=Center,
  )
}

///|
fn typography_section(theme : @moui.Theme) -> @moui.View[Msg] {
  column(
    [
      text("Typography", role=Headline, theme~),
      text(
        "Display 32 / 650 — Ship interfaces that read as native",
        role=Display,
        theme~,
      ),
      text("Headline 24 / 650 — Section heading", role=Headline, theme~),
      text("Title 18 / 600 — Card and panel title", role=Title, theme~),
      text(
        "Body 14 / 400 — The default copy size. Dense enough for desktop, still comfortable across a full-width paragraph.",
        role=Body,
        theme~,
      ),
      text(
        "Caption 12 / 400 — metadata, status bars, helper text",
        role=Caption,
        theme~,
      ),
      text("OVERLINE 11 / 600", role=Overline, theme~),
    ],
    spacing=6.0,
    align=Start,
  )
}

///|
fn buttons_section(theme : @moui.Theme) -> @moui.View[Msg] {
  let noop : Msg = SetDark(false)
  column(
    [
      text("Buttons", role=Title, theme~),
      row(
        [
          button("Primary", on_click=noop, variant=Primary, theme~),
          button("Tonal", on_click=noop, variant=Tonal, theme~),
          button("Outline", on_click=noop, variant=Outline, theme~),
          button("Ghost", on_click=noop, variant=Ghost, theme~),
          button("Subtle", on_click=noop, variant=Subtle, theme~),
          button("Disabled", on_click=noop, theme~).disabled(disabled=true),
        ],
        spacing=8.0,
        align=Center,
      ),
      row(
        [
          badge("Stable", tone=Success, theme~),
          badge("Beta", tone=Accent, theme~),
          badge("Deprecated", tone=Warning, theme~),
          tag("v0.7.0", theme~),
          text(
            "Badges, tags and status colors share the semantic palette.",
            role=Caption,
            theme~,
          ),
        ],
        spacing=8.0,
        align=Center,
      ),
    ],
    spacing=12.0,
    align=Start,
  )
}

///|
fn form_section(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  card(
    column(
      [
        text("Form", role=Title, theme~),
        row(
          [
            column(
              [
                text("Service name", role=Label, theme~),
                text_field(
                  model.service_name,
                  on_input=set_name_msg,
                  placeholder="service-name",
                  theme~,
                  width=300.0,
                ),
              ],
              spacing=6.0,
              align=Start,
            ),
            column(
              [
                text("Volume", role=Label, theme~),
                slider(
                  model.volume,
                  label="",
                  value_text="\{model.volume.to_int()}%",
                  theme~,
                  width=300.0,
                  on_change=Some(set_volume_msg),
                ),
              ],
              spacing=6.0,
              align=Start,
            ),
          ],
          spacing=24.0,
          align=Start,
        ),
        row(
          [
            checkbox(
              "Send telemetry",
              checked=model.notifications,
              on_change=set_notifications_msg,
              theme~,
            ),
            toggle(
              "Dark appearance",
              model.dark,
              on_change=set_dark_msg,
              theme~,
            ),
          ],
          spacing=24.0,
          align=Center,
        ),
      ],
      spacing=14.0,
      align=Start,
    ),
    theme~,
    width=976.0,
    padding=20.0,
  )
}

///|
fn metrics_section(theme : @moui.Theme) -> @moui.View[Msg] {
  column(
    [
      text("Data", role=Title, theme~),
      row(
        [
          stat_card(
            "Active users",
            "12,408",
            caption="+8.2% vs last week",
            theme~,
            width=312.0,
          ),
          stat_card(
            "p95 latency",
            "41 ms",
            caption="within budget",
            tone=Success,
            theme~,
            width=312.0,
          ),
          stat_card(
            "Error rate",
            "0.12%",
            caption="+0.03 pts",
            tone=Danger,
            theme~,
            width=312.0,
          ),
        ],
        spacing=20.0,
        align=Start,
      ),
    ],
    spacing=10.0,
    align=Start,
  )
}

///|
fn surfaces_section(theme : @moui.Theme) -> @moui.View[Msg] {
  card(
    row(
      [
        sidebar(
          "Workspace",
          [
            sidebar_item(id="inbox", label="Inbox", message=SetDark(false)),
            sidebar_item(
              id="deploys",
              label="Deployments",
              message=SetDark(false),
            ),
            sidebar_item(
              id="settings",
              label="Settings",
              message=SetDark(false),
            ),
          ],
          selected="inbox",
          theme~,
          width=220.0,
          height=236.0,
        ),
        column(
          [
            text("Surfaces and elevation", role=Title, theme~),
            text(
              "Cards take the small elevation tier, popovers the middle tier and dialogs the large tier. Selected rows use the tonal accent tint, not a solid primary fill.",
              role=Body,
              theme~,
            ),
            progress(
              0.62,
              label="Rollout",
              value_text="62%",
              theme~,
              width=480.0,
            ),
            row(
              [
                button("Confirm", on_click=SetDark(false), theme~),
                button(
                  "Cancel",
                  on_click=SetDark(false),
                  variant=Outline,
                  theme~,
                ),
              ],
              spacing=8.0,
              align=Center,
            ),
          ],
          spacing=12.0,
          align=Start,
        ),
      ],
      spacing=24.0,
      align=Start,
    ),
    theme~,
    width=976.0,
    padding=20.0,
  )
}

///|
fn icons_section(theme : @moui.Theme) -> @moui.View[Msg] {
  column(
    [
      text("Icons", role=Title, theme~),
      row(
        [
          icon(Check, size=20.0),
          icon(Search, size=20.0),
          icon(Settings, size=20.0),
          icon(Trash, size=20.0),
          icon(FolderOpen, size=20.0),
          icon(Save, size=20.0),
          icon_svg(
            "<svg viewBox=\"0 0 24 24\"><path d=\"M22 12h-4l-3 9L9 3l-3 9H2\"/></svg>",
            size=20.0,
            color=theme.palette.foreground,
          ),
          lucide_icon("zap", size=20.0, color=theme.palette.foreground),
          sf_symbol_icon(
            "house.fill",
            size=20.0,
            color=theme.palette.foreground,
          ),
        ],
        spacing=16.0,
        align=Center,
      ),
      text(
        "Built-in 24×24 stroke set, arbitrary SVG path data, a vendored Lucide glyph, and an SF Symbols name resolved through the adapter.",
        role=Caption,
        theme~,
      ),
    ],
    spacing=10.0,
    align=Start,
  )
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  let theme = gallery_theme(model)
  let page = column(
    [
      page_header(model, theme),
      divider(theme~),
      typography_section(theme),
      buttons_section(theme),
      form_section(model, theme),
      metrics_section(theme),
      surfaces_section(theme),
      icons_section(theme),
    ],
    spacing=24.0,
    align=Start,
  )
  scroll_view(padding(page, 32.0), width=1040.0, height=780.0).theme(theme)
}

///|
pub fn program_with_model(model : Model) -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=model, update~, view~)
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  program_with_model(Model::new())
}
