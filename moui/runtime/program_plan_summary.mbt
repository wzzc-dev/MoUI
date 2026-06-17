///|
pub(all) enum EffectPlanKind {
  EffectPlanNone
  EffectPlanBatch
  EffectPlanSend
  EffectPlanDispatch
  EffectPlanRun
  EffectPlanTask
} derive(Eq, Debug, ToJson)

///|
pub(all) struct EffectPlanSummary {
  root_kind : EffectPlanKind
  none_count : Int
  batch_count : Int
  send_count : Int
  dispatch_count : Int
  run_count : Int
  task_count : Int
  scheduled_count : Int
  max_depth : Int
  descriptors : Array[@core.EffectDescriptor]
  duplicate_descriptor_key_count : Int
  duplicate_descriptor_keys : Array[String]
} derive(Eq, Debug, ToJson)

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
  descriptors : Array[@core.SubscriptionDescriptor]
} derive(Eq, Debug, ToJson)

///|
pub fn EffectPlanSummary::empty() -> EffectPlanSummary {
  {
    root_kind: EffectPlanKind::EffectPlanNone,
    none_count: 0,
    batch_count: 0,
    send_count: 0,
    dispatch_count: 0,
    run_count: 0,
    task_count: 0,
    scheduled_count: 0,
    max_depth: 0,
    descriptors: [],
    duplicate_descriptor_key_count: 0,
    duplicate_descriptor_keys: [],
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
pub fn[Msg] effect_plan_summary(
  effect : @core.Effect[Msg],
) -> EffectPlanSummary {
  summarize_effect(effect, depth=1)
}

///|
fn[Msg] summarize_effect(
  effect : @core.Effect[Msg],
  depth~ : Int,
) -> EffectPlanSummary {
  match effect {
    @core.Effect::NoEffect =>
      {
        root_kind: EffectPlanKind::EffectPlanNone,
        none_count: 1,
        batch_count: 0,
        send_count: 0,
        dispatch_count: 0,
        run_count: 0,
        task_count: 0,
        scheduled_count: 0,
        max_depth: depth,
        descriptors: [],
        duplicate_descriptor_key_count: 0,
        duplicate_descriptor_keys: [],
      }
    @core.Effect::Send(_) =>
      {
        root_kind: EffectPlanKind::EffectPlanSend,
        none_count: 0,
        batch_count: 0,
        send_count: 1,
        dispatch_count: 0,
        run_count: 0,
        task_count: 0,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [],
        duplicate_descriptor_key_count: 0,
        duplicate_descriptor_keys: [],
      }
    @core.Effect::Dispatch(_) =>
      {
        root_kind: EffectPlanKind::EffectPlanDispatch,
        none_count: 0,
        batch_count: 0,
        send_count: 0,
        dispatch_count: 1,
        run_count: 0,
        task_count: 0,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [],
        duplicate_descriptor_key_count: 0,
        duplicate_descriptor_keys: [],
      }
    @core.Effect::Run(descriptor, _) =>
      {
        root_kind: EffectPlanKind::EffectPlanRun,
        none_count: 0,
        batch_count: 0,
        send_count: 0,
        dispatch_count: 0,
        run_count: 1,
        task_count: 0,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [descriptor],
        duplicate_descriptor_key_count: 0,
        duplicate_descriptor_keys: [],
      }
    @core.Effect::Task(descriptor, _) =>
      {
        root_kind: EffectPlanKind::EffectPlanTask,
        none_count: 0,
        batch_count: 0,
        send_count: 0,
        dispatch_count: 0,
        run_count: 0,
        task_count: 1,
        scheduled_count: 1,
        max_depth: depth,
        descriptors: [descriptor],
        duplicate_descriptor_key_count: 0,
        duplicate_descriptor_keys: [],
      }
    @core.Effect::Batch(effects) => {
      let mut none_count = 0
      let mut batch_count = 1
      let mut send_count = 0
      let mut dispatch_count = 0
      let mut run_count = 0
      let mut task_count = 0
      let mut scheduled_count = 0
      let mut max_depth = depth
      let descriptors : Array[@core.EffectDescriptor] = []
      for child in effects {
        let child_summary = summarize_effect(child, depth=depth + 1)
        none_count = none_count + child_summary.none_count
        batch_count = batch_count + child_summary.batch_count
        send_count = send_count + child_summary.send_count
        dispatch_count = dispatch_count + child_summary.dispatch_count
        run_count = run_count + child_summary.run_count
        task_count = task_count + child_summary.task_count
        scheduled_count = scheduled_count + child_summary.scheduled_count
        if child_summary.max_depth > max_depth {
          max_depth = child_summary.max_depth
        }
        descriptors.append(child_summary.descriptors)
      }
      {
        root_kind: EffectPlanKind::EffectPlanBatch,
        none_count,
        batch_count,
        send_count,
        dispatch_count,
        run_count,
        task_count,
        scheduled_count,
        max_depth,
        descriptors,
        duplicate_descriptor_key_count: duplicate_effect_descriptor_key_count(
          descriptors,
        ),
        duplicate_descriptor_keys: duplicate_effect_descriptor_keys(descriptors),
      }
    }
  }
}

///|
pub fn[Msg] subscription_plan_summary(
  subscription : @core.Subscription[Msg],
) -> SubscriptionPlanSummary {
  let mut root_kind = SubscriptionPlanKind::SubscriptionPlanNone
  let mut seen_root = false
  let mut none_count = 0
  let mut batch_count = 0
  let mut source_count = 0
  let mut max_depth = 0
  let descriptors : Array[@core.SubscriptionDescriptor] = []
  subscription.runtime_visit(
    depth => {
      if !seen_root {
        root_kind = SubscriptionPlanKind::SubscriptionPlanNone
        seen_root = true
      }
      none_count = none_count + 1
      max_depth = runtime_plan_max_int(max_depth, depth + 1)
    },
    (depth, _child_count) => {
      if !seen_root {
        root_kind = SubscriptionPlanKind::SubscriptionPlanBatch
        seen_root = true
      }
      batch_count = batch_count + 1
      max_depth = runtime_plan_max_int(max_depth, depth + 1)
    },
    (depth, descriptor) => {
      if !seen_root {
        root_kind = SubscriptionPlanKind::SubscriptionPlanSource
        seen_root = true
      }
      source_count = source_count + 1
      max_depth = runtime_plan_max_int(max_depth, depth + 1)
      descriptors.push(descriptor)
    },
  )
  {
    root_kind,
    none_count,
    batch_count,
    source_count,
    duplicate_key_count: duplicate_subscription_key_count(descriptors),
    duplicate_keys: duplicate_subscription_keys(descriptors),
    max_depth,
    descriptors,
  }
}

///|
fn duplicate_effect_descriptor_keys(
  descriptors : Array[@core.EffectDescriptor],
) -> Array[String] {
  let seen_keys : Array[String] = []
  let duplicate_keys : Array[String] = []
  for descriptor in descriptors {
    if seen_keys.any(key => key == descriptor.key()) {
      if !duplicate_keys.any(key => key == descriptor.key()) {
        duplicate_keys.push(descriptor.key())
      }
    } else {
      seen_keys.push(descriptor.key())
    }
  }
  duplicate_keys
}

///|
fn duplicate_effect_descriptor_key_count(
  descriptors : Array[@core.EffectDescriptor],
) -> Int {
  let seen_keys : Array[String] = []
  let mut duplicate_count = 0
  for descriptor in descriptors {
    if seen_keys.any(key => key == descriptor.key()) {
      duplicate_count = duplicate_count + 1
    } else {
      seen_keys.push(descriptor.key())
    }
  }
  duplicate_count
}

///|
fn duplicate_subscription_keys(
  descriptors : Array[@core.SubscriptionDescriptor],
) -> Array[String] {
  let seen_keys : Array[String] = []
  let duplicate_keys : Array[String] = []
  for descriptor in descriptors {
    if seen_keys.any(key => key == descriptor.key()) {
      if !duplicate_keys.any(key => key == descriptor.key()) {
        duplicate_keys.push(descriptor.key())
      }
    } else {
      seen_keys.push(descriptor.key())
    }
  }
  duplicate_keys
}

///|
fn duplicate_subscription_key_count(
  descriptors : Array[@core.SubscriptionDescriptor],
) -> Int {
  let seen_keys : Array[String] = []
  let mut duplicate_count = 0
  for descriptor in descriptors {
    if seen_keys.any(key => key == descriptor.key()) {
      duplicate_count = duplicate_count + 1
    } else {
      seen_keys.push(descriptor.key())
    }
  }
  duplicate_count
}

///|
fn runtime_plan_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
