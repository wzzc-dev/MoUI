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
pub(all) enum SubscriptionPlanKind {
  SubscriptionPlanNone
  SubscriptionPlanBatch
  SubscriptionPlanSource
} derive(Eq, Debug, ToJson)

///|
pub(all) struct SubscriptionPlanSummary {
  root_kind : SubscriptionPlanKind
  none_count : Int
  batch_count : Int
  source_count : Int
  duplicate_key_count : Int
  duplicate_keys : Array[String]
  max_depth : Int
  descriptors : Array[SubscriptionDescriptor]
} derive(Eq, Debug, ToJson)

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
pub fn[Msg] Subscription::service_completion(
  key~ : String,
  start~ : ((Msg) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> Subscription[Msg] {
  Subscription::listen(key~, start~, kind="host-service", label~)
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
pub fn[Msg] Subscription::plan_summary(
  self : Subscription[Msg],
) -> SubscriptionPlanSummary {
  let summary = subscription_plan_summary(self, depth=1)
  {
    ..summary,
    duplicate_key_count: self.duplicate_key_count(),
    duplicate_keys: self.duplicate_keys(),
  }
}

///|
pub fn SubscriptionPlanSummary::empty() -> SubscriptionPlanSummary {
  {
    root_kind: SubscriptionPlanKind::SubscriptionPlanNone,
    none_count: 0,
    batch_count: 0,
    source_count: 0,
    duplicate_key_count: 0,
    duplicate_keys: [],
    max_depth: 0,
    descriptors: [],
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
fn[Msg] Subscription::duplicate_key_count(self : Subscription[Msg]) -> Int {
  let seen_keys : Array[String] = []
  let mut duplicate_count = 0
  for source in self.sources() {
    if seen_keys.any(key => key == source.key) {
      duplicate_count = duplicate_count + 1
    } else {
      seen_keys.push(source.key)
    }
  }
  duplicate_count
}

///|
fn[Msg] Subscription::duplicate_keys(self : Subscription[Msg]) -> Array[String] {
  let seen_keys : Array[String] = []
  let duplicate_keys : Array[String] = []
  for source in self.sources() {
    if seen_keys.any(key => key == source.key) {
      if !duplicate_keys.any(key => key == source.key) {
        duplicate_keys.push(source.key)
      }
    } else {
      seen_keys.push(source.key)
    }
  }
  duplicate_keys
}

///|
fn[Msg] subscription_plan_summary(
  subscription : Subscription[Msg],
  depth~ : Int,
) -> SubscriptionPlanSummary {
  match subscription.node {
    SubscriptionNone =>
      {
        root_kind: SubscriptionPlanKind::SubscriptionPlanNone,
        none_count: 1,
        batch_count: 0,
        source_count: 0,
        duplicate_key_count: 0,
        duplicate_keys: [],
        max_depth: depth,
        descriptors: [],
      }
    SubscriptionSource(source) =>
      {
        root_kind: SubscriptionPlanKind::SubscriptionPlanSource,
        none_count: 0,
        batch_count: 0,
        source_count: 1,
        duplicate_key_count: 0,
        duplicate_keys: [],
        max_depth: depth,
        descriptors: [source.descriptor()],
      }
    SubscriptionBatch(subscriptions) => {
      let mut none_count = 0
      let mut batch_count = 1
      let mut source_count = 0
      let mut max_depth = depth
      let descriptors : Array[SubscriptionDescriptor] = []
      for child in subscriptions {
        let child_summary = subscription_plan_summary(child, depth=depth + 1)
        none_count = none_count + child_summary.none_count
        batch_count = batch_count + child_summary.batch_count
        source_count = source_count + child_summary.source_count
        if child_summary.max_depth > max_depth {
          max_depth = child_summary.max_depth
        }
        descriptors.append(child_summary.descriptors)
      }
      {
        root_kind: SubscriptionPlanKind::SubscriptionPlanBatch,
        none_count,
        batch_count,
        source_count,
        duplicate_key_count: 0,
        duplicate_keys: [],
        max_depth,
        descriptors,
      }
    }
  }
}

///|
fn[Msg] SubscriptionSource::descriptor(
  self : SubscriptionSource[Msg],
) -> SubscriptionDescriptor {
  { key: self.key, kind: self.kind, label: self.label }
}
