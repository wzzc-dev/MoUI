///|
using @views {button, card, center, column, row, text}

///|
/// A keyed, plain-data counter instance. The parent Model owns every instance;
/// the scoped Feature below is pure projection over this value.
pub(all) struct CounterInstance {
  id : String
  value : String
  numeric_value : Double
  edits : Int32
  auto : Bool
}

///|
pub fn CounterInstance::new(id~ : String, value~ : String) -> CounterInstance {
  counter_instance(id, value, 0, false)
}

///|
fn counter_instance(
  id : String,
  value : String,
  edits : Int32,
  auto : Bool,
) -> CounterInstance {
  {
    id,
    value,
    numeric_value: parse_counter_value(value),
    edits: if edits < 0 {
      0
    } else {
      edits
    },
    auto,
  }
}

///|
fn parse_counter_value(value : String) -> Double {
  let number = @string.parse_double(value.trim().to_owned()) catch { _ => 0.0 }
  number.clamp(min=0.0, max=100.0)
}

///|
fn counter_value_text(value : Double) -> String {
  if value == value.floor() {
    value.to_int().to_string()
  } else {
    value.to_string()
  }
}

///|
/// Parent-owned counter collection. `next_id` is only a cursor: fresh ids skip
/// existing keys, so restoring a stale snapshot cannot create a duplicate.
pub(all) struct Model {
  counters : Array[CounterInstance]
  next_id : Int32
}

///|
pub(all) struct CounterSnapshot {
  id : String
  value : String
  edits : Int32
  auto : Bool
}

///|
pub(all) struct ModelSnapshot {
  counters : Array[CounterSnapshot]
  next_id : Int32
}

///|
pub(all) enum CounterMsg {
  Edited(String)
  Step(Int32)
  ToggleAuto
  Reset
}

///|
pub(all) enum Msg {
  Counter(String, CounterMsg)
  AddCounter
  RemoveCounter(String)
  MoveCounter(String, Int32)
}

///|
pub fn Model::new() -> Model {
  {
    counters: [
      CounterInstance::new(id="quantity", value="5"),
      CounterInstance::new(id="discount", value="10"),
    ],
    next_id: 1,
  }
}

///|
fn counter_index(counters : Array[CounterInstance], id : String) -> Int32? {
  let mut index = 0
  while index < counters.length() {
    if counters[index].id == id {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn counter_for_scope(model : Model, id : String) -> CounterInstance {
  match counter_index(model.counters, id) {
    Some(index) => model.counters[index]
    None => CounterInstance::new(id~, value="0")
  }
}

///|
fn counter_write(
  id : String,
  counter : CounterInstance,
  model : Model,
) -> Model {
  match counter_index(model.counters, id) {
    Some(index) => {
      let counters = model.counters.copy()
      counters[index] = counter
      { ..model, counters, }
    }
    None => model
  }
}

///|
fn Model::fresh_counter_id(self : Model) -> (String, Int32) {
  let mut cursor = self.next_id
  let mut id = ""
  while true {
    id = "counter-" + cursor.to_string()
    match counter_index(self.counters, id) {
      None => break
      Some(_) => cursor = cursor + 1
    }
  }
  (id, cursor + 1)
}

///|
fn counter_update(
  model : CounterInstance,
  message : CounterMsg,
) -> (CounterInstance, @moui.Effect[CounterMsg]) {
  let next = match message {
    Edited(value) =>
      counter_instance(model.id, value, model.edits + 1, model.auto)
    Step(delta) => {
      let value = (model.numeric_value + delta.to_double()).clamp(
        min=0.0,
        max=100.0,
      )
      counter_instance(
        model.id,
        counter_value_text(value),
        model.edits + 1,
        model.auto,
      )
    }
    ToggleAuto => { ..model, auto: !model.auto, }
    Reset => counter_instance(model.id, "0", model.edits + 1, model.auto)
  }
  (next, @moui.Effect::none())
}

///|
fn counter_view(model : CounterInstance) -> @moui.View[CounterMsg] {
  column([
    @widgets.editable_counter(
      label="Counter " + model.id,
      value=model.value,
      numeric_value=model.numeric_value,
      on_input=value => Edited(value),
      on_increment=Step(1),
      on_decrement=Step(-1),
      key="counter-" + model.id,
    ).semantic_id("custom.counter." + model.id),
    row([
      text("Edits: \{model.edits}"),
      button(
        if model.auto {
          "Pause auto"
        } else {
          "Run auto"
        },
        on_click=ToggleAuto,
      ),
      button("Reset", on_click=Reset),
    ]),
  ])
}

///|
fn counter_feature(
  id : String,
  timer_source : @services.TimerSource?,
) -> @moui.Feature[CounterInstance, CounterMsg] {
  @moui.Feature::new(
    init=() => (CounterInstance::new(id~, value="0"), @moui.Effect::none()),
    update=counter_update,
    view=counter_view,
    subscriptions=model => {
      match timer_source {
        Some(source) =>
          if model.auto {
            source.subscription(
              interval_ms=1000.0,
              key="counter/auto",
              label="Counter " + model.id + " auto increment",
              map=_frame => Step(1),
            )
          } else {
            @moui.Subscription::none()
          }
        None => @moui.Subscription::none()
      }
    },
  )
}

///|
fn counter_scope(
  id : String,
  timer_source : @services.TimerSource?,
) -> @moui.ScopedFeature[Model, CounterInstance, CounterMsg, Msg] {
  counter_feature(id, timer_source).scope(
    scope_id="custom-control/" + id,
    read=model => counter_for_scope(model, id),
    write=(counter, model) => counter_write(id, counter, model),
    wrap=message => Counter(id, message),
  )
}

///|
pub fn Model::update(self : Model, message : Msg) -> Model {
  match message {
    Counter(id, inner) =>
      match counter_index(self.counters, id) {
        Some(_) => {
          let (next, _effect) = counter_scope(id, None).update(self, inner)
          next
        }
        None => self
      }
    AddCounter => {
      let (id, next_id) = self.fresh_counter_id()
      let counters = self.counters.copy()
      counters.push(CounterInstance::new(id~, value="0"))
      { counters, next_id, }
    }
    RemoveCounter(id) =>
      match counter_index(self.counters, id) {
        Some(index) => {
          let counters = self.counters.copy()
          ignore(counters.remove(index))
          { ..self, counters, }
        }
        None => self
      }
    MoveCounter(id, delta) =>
      if delta == 0 {
        self
      } else {
        match counter_index(self.counters, id) {
          Some(index) => {
            let counters = self.counters.copy()
            let target = index + delta
            let counter = counters.remove(index)
            let clamped = if target < 0 {
              0
            } else if target > counters.length() {
              counters.length()
            } else {
              target
            }
            counters.insert(clamped, counter)
            { ..self, counters, }
          }
          None => self
        }
      }
  }
}

///|
pub fn update(model : Model, message : Msg) -> Model {
  model.update(message)
}

///|
pub fn Model::counter_ids(self : Model) -> Array[String] {
  self.counters.map(counter => counter.id)
}

///|
pub fn Model::save_snapshot(self : Model) -> ModelSnapshot {
  let counters : Array[CounterSnapshot] = []
  for counter in self.counters {
    counters.push({
      id: counter.id,
      value: counter.value,
      edits: counter.edits,
      auto: counter.auto,
    })
  }
  { counters, next_id: self.next_id, }
}

///|
pub fn Model::restore_from_snapshot(snapshot : ModelSnapshot) -> Model {
  let counters : Array[CounterInstance] = []
  for saved in snapshot.counters {
    if saved.id != "" && counter_index(counters, saved.id) is None {
      counters.push(
        counter_instance(saved.id, saved.value, saved.edits, saved.auto),
      )
    }
  }
  {
    counters,
    next_id: if snapshot.next_id < 1 {
      1
    } else {
      snapshot.next_id
    },
  }
}

///|
fn Model::counter_card(
  self : Model,
  counter : CounterInstance,
  environment : @moui.ViewEnvironment,
) -> @moui.View[Msg] {
  let scoped = counter_scope(counter.id, None)
  card(
    column([
      text("Counter " + counter.id).title(),
      scoped.view(self, environment),
      row([
        button("Move up", on_click=MoveCounter(counter.id, -1), width=92.0).semantic_id(
          "custom.move-up." + counter.id,
        ),
        button("Move down", on_click=MoveCounter(counter.id, 1), width=104.0).semantic_id(
          "custom.move-down." + counter.id,
        ),
        button("Remove", on_click=RemoveCounter(counter.id), width=88.0).semantic_id(
          "custom.remove." + counter.id,
        ),
      ]),
    ]),
  )
}

///|
pub fn Model::view_with_environment(
  self : Model,
  environment : @moui.ViewEnvironment,
) -> @moui.View[Msg] {
  let content : Array[@moui.View[Msg]] = [
    text("Custom control SDK").title(),
    text(
      "Committed values stay in the parent model; keyed instances are scoped.",
    ),
    row([
      text("Instances: \{self.counters.length()}"),
      button("Add counter", on_click=AddCounter, width=132.0),
    ]),
  ]
  for counter in self.counters {
    content.push(self.counter_card(counter, environment))
  }
  if self.counters.is_empty() {
    content.push(text("No counters"))
  }
  center(column(content))
}

///|
fn subscriptions(
  model : Model,
  timer_source : @services.TimerSource?,
) -> @moui.Subscription[Msg] {
  match timer_source {
    Some(_) => {
      let subs : Array[@moui.Subscription[Msg]] = []
      for counter in model.counters {
        if counter.auto {
          subs.push(
            counter_scope(counter.id, timer_source).subscriptions(model),
          )
        }
      }
      @moui.Subscription::batch(subs)
    }
    None => @moui.Subscription::none()
  }
}

///|
pub fn Model::program(
  self : Model,
  timer_source~ : @services.TimerSource? = None,
) -> @moui.Program[Model, Msg] {
  @moui.Program::new_with_environment(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => (model.update(message), @moui.Effect::none()),
    view=(model, environment) => model.view_with_environment(environment),
    subscriptions=model => subscriptions(model, timer_source),
  )
}

///|
pub fn program() -> @moui.Program[Model, Msg] {
  Model::new().program()
}
