///|
pub struct Subscription[Msg] {
  priv node : SubscriptionNode[Msg]
}

///|
priv enum SubscriptionNode[Msg] {
  SubscriptionNone
  SubscriptionBatch(Array[Subscription[Msg]])
  SubscriptionSource(SubscriptionSource[Msg])
}

///|
priv struct SubscriptionSource[Msg] {
  key : String
  kind : String
  label : String
  start : ((Msg) -> Unit) -> (() -> Unit)?
}

///|
pub struct SubscriptionRuntimeSource[Msg] {
  priv source : SubscriptionSource[Msg]
}

///|
struct SubscriptionDescriptor {
  key : String
  kind : String
  label : String
} derive(Eq, Debug, ToJson)

///|
pub fn SubscriptionDescriptor::key(self : SubscriptionDescriptor) -> String {
  self.key
}

///|
pub fn SubscriptionDescriptor::kind(self : SubscriptionDescriptor) -> String {
  self.kind
}

///|
pub fn SubscriptionDescriptor::label(self : SubscriptionDescriptor) -> String {
  self.label
}

///|
pub fn[Msg] Subscription::none() -> Subscription[Msg] {
  { node: SubscriptionNone }
}

///|
pub fn[Msg] Subscription::batch(
  subscriptions : Array[Subscription[Msg]],
) -> Subscription[Msg] {
  { node: SubscriptionBatch(subscriptions) }
}

///|
pub fn[Msg] Subscription::run(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  kind? : String = "custom",
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind~, label~)
}

///|
pub fn[Msg] Subscription::listen(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  kind? : String = "custom",
  label? : String = "",
) -> Subscription[Msg] {
  { node: SubscriptionSource({ key, kind, label, start }) }
}

///|
pub fn[Msg] Subscription::timer(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="timer", label~)
}

///|
pub fn[Msg] Subscription::animation_tick(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="animation", label~)
}

///|
pub fn[Msg] Subscription::window_event(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="window-event", label~)
}

///|
pub fn[Msg] Subscription::host_event(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="host-event", label~)
}

///|
pub fn[Msg] Subscription::route_event(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="route-event", label~)
}

///|
pub fn[Msg, NextMsg] Subscription::map(
  self : Subscription[Msg],
  map : (Msg) -> NextMsg,
) -> Subscription[NextMsg] {
  match self.node {
    SubscriptionNone => Subscription::none()
    SubscriptionBatch(subscriptions) =>
      Subscription::batch(
        subscriptions.map(subscription => subscription.map(map)),
      )
    SubscriptionSource(source) =>
      Subscription::listen(
        key=source.key,
        kind=source.kind,
        label=source.label,
        start=dispatch => (source.start)(message => dispatch(map(message))),
      )
  }
}

///|
pub fn[Msg] Subscription::descriptors(
  self : Subscription[Msg],
) -> Array[SubscriptionDescriptor] {
  self.sources().map(source => source.descriptor())
}

///|
pub fn[Msg] Subscription::runtime_sources(
  self : Subscription[Msg],
) -> Array[SubscriptionRuntimeSource[Msg]] {
  self.sources().map(source => { source, })
}

///|
pub fn[Msg] SubscriptionRuntimeSource::key(
  self : SubscriptionRuntimeSource[Msg],
) -> String {
  self.source.key
}

///|
pub fn[Msg] SubscriptionRuntimeSource::kind(
  self : SubscriptionRuntimeSource[Msg],
) -> String {
  self.source.kind
}

///|
pub fn[Msg] SubscriptionRuntimeSource::label(
  self : SubscriptionRuntimeSource[Msg],
) -> String {
  self.source.label
}

///|
pub fn[Msg] SubscriptionRuntimeSource::descriptor(
  self : SubscriptionRuntimeSource[Msg],
) -> SubscriptionDescriptor {
  self.source.descriptor()
}

///|
pub fn[Msg] SubscriptionRuntimeSource::start(
  self : SubscriptionRuntimeSource[Msg],
  dispatch : (Msg) -> Unit,
) -> (() -> Unit)? {
  (self.source.start)(dispatch)
}

///|
pub fn[Msg] Subscription::runtime_visit(
  self : Subscription[Msg],
  none : (Int) -> Unit,
  batch : (Int, Int) -> Unit,
  source : (Int, SubscriptionDescriptor) -> Unit,
) -> Unit {
  self.runtime_visit_depth(0, none, batch, source)
}

///|
fn[Msg] Subscription::runtime_visit_depth(
  self : Subscription[Msg],
  depth : Int,
  none : (Int) -> Unit,
  batch : (Int, Int) -> Unit,
  source : (Int, SubscriptionDescriptor) -> Unit,
) -> Unit {
  match self.node {
    SubscriptionNone => none(depth)
    SubscriptionBatch(subscriptions) => {
      batch(depth, subscriptions.length())
      for subscription in subscriptions {
        subscription.runtime_visit_depth(depth + 1, none, batch, source)
      }
    }
    SubscriptionSource(subscription_source) =>
      source(depth, subscription_source.descriptor())
  }
}

///|
fn[Msg] Subscription::sources(
  self : Subscription[Msg],
) -> Array[SubscriptionSource[Msg]] {
  match self.node {
    SubscriptionNone => []
    SubscriptionBatch(subscriptions) => {
      let sources : Array[SubscriptionSource[Msg]] = []
      for subscription in subscriptions {
        sources.append(subscription.sources())
      }
      sources
    }
    SubscriptionSource(source) => [source]
  }
}

///|
fn[Msg] SubscriptionSource::descriptor(
  self : SubscriptionSource[Msg],
) -> SubscriptionDescriptor {
  { key: self.key, kind: self.kind, label: self.label }
}
