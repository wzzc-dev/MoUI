///|
using @views {
  button,
  center,
  column,
  data_filter,
  data_filter_bar,
  row,
  surface,
  text,
}

///|
pub struct Model {
  query : String
  active : Bool
  review : Bool
  blocked : Bool
  clicks : Int
  last_action : String
  previous_action : String
}

///|
pub(all) enum Msg {
  QueryChanged(String)
  ToggleActive
  ToggleReview
  ToggleBlocked
  ClearFilters
  PrimaryPulse
  TonalPulse
} derive(Eq, Debug, ToJson)

///|
pub fn Model::new() -> Model {
  {
    query: "",
    active: true,
    review: false,
    blocked: true,
    clicks: 0,
    last_action: "ready",
    previous_action: "",
  }
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    QueryChanged(query) =>
      model.record("query=" + query, query=Some(query), count_click=false)
    ToggleActive => model.record("toggle active", active=Some(!model.active))
    ToggleReview => model.record("toggle review", review=Some(!model.review))
    ToggleBlocked =>
      model.record("toggle blocked", blocked=Some(!model.blocked))
    ClearFilters =>
      model.record(
        "clear filters",
        query=Some(""),
        active=Some(false),
        review=Some(false),
        blocked=Some(false),
      )
    PrimaryPulse => model.record("primary pulse")
    TonalPulse => model.record("tonal pulse")
  }
}

///|
fn Model::record(
  self : Model,
  action : String,
  query? : String? = None,
  active? : Bool? = None,
  review? : Bool? = None,
  blocked? : Bool? = None,
  count_click? : Bool = true,
) -> Model {
  {
    query: query.unwrap_or(self.query),
    active: active.unwrap_or(self.active),
    review: review.unwrap_or(self.review),
    blocked: blocked.unwrap_or(self.blocked),
    clicks: if count_click {
      self.clicks + 1
    } else {
      self.clicks
    },
    last_action: action,
    previous_action: self.last_action,
  }
}

///|
pub fn view(model : Model) -> @core.View[Msg] {
  let theme = probe_theme()
  center(
    surface(
      column(
        [
          text(
            "Button Freeze Probe",
            role=@views.TextRole::Title,
            theme~,
            width=432.0,
            height=34.0,
          ),
          text(
            model.summary(),
            role=@views.TextRole::Caption,
            theme~,
            width=432.0,
            height=24.0,
          ).foreground(theme.palette.muted),
          data_filter_bar(
            query=model.query,
            on_query=value => QueryChanged(value),
            filters=[
              data_filter(
                id="active",
                label="Active",
                selected=model.active,
                message=ToggleActive,
              ),
              data_filter(
                id="review",
                label="Review",
                selected=model.review,
                message=ToggleReview,
              ),
              data_filter(
                id="blocked",
                label="Blocked",
                selected=model.blocked,
                message=ToggleBlocked,
              ),
            ],
            result_count=model.result_count(),
            on_clear=Some(ClearFilters),
            placeholder="Search rows",
            theme~,
            width=432.0,
          ),
          row(
            [
              button(
                "Primary",
                on_click=PrimaryPulse,
                variant=@views.ButtonVariant::Primary,
                theme~,
                width=120.0,
                height=36.0,
              ),
              button(
                "Tonal",
                on_click=TonalPulse,
                variant=@views.ButtonVariant::Tonal,
                theme~,
                width=120.0,
                height=36.0,
              ),
            ],
            spacing=theme.spacing_scale.sm,
            align=@views.CrossAlign::Center,
          ),
          text(
            "last=\{model.last_action}; previous=\{model.previous_action}",
            role=@views.TextRole::Mono,
            theme~,
            width=432.0,
            height=26.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      width=480.0,
      height=296.0,
      variant=@views.SurfaceVariant::Raised,
      theme~,
      padding=theme.spacing_scale.md,
    ),
    width=560.0,
    height=360.0,
    background=theme.palette.background,
    theme~,
  )
}

///|
fn probe_theme() -> @core.Theme {
  @core.Theme::light().with_accent(@core.Color::rgba(r=0.78, g=0.10, b=0.12))
}

///|
fn Model::summary(self : Model) -> String {
  "clicks=\{self.clicks}; active=\{self.active}; review=\{self.review}; blocked=\{self.blocked}; results=\{self.result_count()}"
}

///|
fn Model::result_count(self : Model) -> Int {
  if self.query == "" && !self.active && !self.review && !self.blocked {
    10
  } else if self.active && self.review && self.blocked {
    1
  } else if self.active && self.review {
    3
  } else if self.active && self.blocked {
    2
  } else if self.review || self.blocked {
    4
  } else {
    6
  }
}

///|
pub fn runtime(
  width? : Double = 560.0,
  height? : Double = 360.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::simple(init=Model::new(), update~, view~),
    size=@core.Size::new(width~, height~),
  )
}

///|
test "button freeze probe toggles selected filters" {
  let first = update(Model::new(), ToggleActive)
  inspect(first.active, content="false")
  inspect(first.clicks, content="1")
  inspect(first.last_action, content="toggle active")
  let second = update(first, ToggleReview)
  inspect(second.review, content="true")
  inspect(second.clicks, content="2")
  inspect(second.previous_action, content="toggle active")
}

///|
test "button freeze probe query and clear update model" {
  let queried = update(Model::new(), QueryChanged("abc"))
  inspect(queried.query, content="abc")
  inspect(queried.clicks, content="0")
  let cleared = update(queried, ClearFilters)
  inspect(cleared.query, content="")
  inspect(cleared.active, content="false")
  inspect(cleared.review, content="false")
  inspect(cleared.blocked, content="false")
  inspect(cleared.clicks, content="1")
}
