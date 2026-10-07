///|
/// 内核容器测试：用一个假插件（假模型/假消息/假贡献项）验证 Plugin 契约
/// 的四个机械件——事件总线（注册序派发/纯监听器）、outbox 排空、服务容器
/// （denied 语义）、贡献点（提升后可收进同构数组并被壳调用）。

///|
/// 假域消息：包装变体形态（根 Msg 收子 Msg，与真实 app 同构）。
pub(all) enum FakeMsg {
  FakeNoop
  FakeInner(FakeInnerMsg)
  FakePing(String)
} derive(Eq, Debug)

///|
pub extend FakeMsg with Debug::{to_repr}

///|
pub extend FakeMsg with Eq::{not_equal, equal}

///|
pub(all) enum FakeInnerMsg {
  FakeAsked(String)
} derive(Eq, Debug)

///|
pub extend FakeInnerMsg with Debug::{to_repr}

///|
pub extend FakeInnerMsg with Eq::{not_equal, equal}

///|
/// 假域状态切片。
pub(all) struct FakeState {
  asked : String
}

///|
/// 假根模型：根自有字段 + 一个状态切片字段（lens 目标）。
pub(all) struct FakeModel {
  title : String
  state : FakeState
}

///|
/// 假事件：事件载荷显式携带事实（消费方不需要回查模型）。
pub(all) enum FakeEvent {
  EvAsked(String)
  EvSilent
} derive(Eq, Debug)

///|
pub extend FakeEvent with Debug::{to_repr}

///|
pub extend FakeEvent with Eq::{not_equal, equal}

///|
fn assert_no_effect(effect : @moui.Effect[FakeMsg]) -> Unit {
  match effect {
    @moui.Effect::NoEffect => ()
    _ => abort("expected NoEffect")
  }
}

///|
/// 假插件状态切片的 update（TEA 五元组的 update 臂）。
fn fake_state_update(
  _state : FakeState,
  message : FakeInnerMsg,
) -> (FakeState, @moui.Effect[FakeInnerMsg]) {
  match message {
    FakeAsked(question) => ({ asked: question, }, @moui.Effect::none())
  }
}

///|
/// 假面板视图（切片消息类型）：真实 @views 视图。
fn fake_inner_view() -> @moui.View[FakeInnerMsg] {
  @views.text(
    "fake-plugin",
    theme=@views.light_theme(),
    width=40.0,
    height=16.0,
  )
}

///|
/// 假插件的 Feature（契约第 1 件：状态切片 + 五元组）。
fn fake_feature() -> @moui.Feature[FakeState, FakeInnerMsg] {
  @moui.Feature::new(
    init=() => ({ asked: "", }, @moui.Effect::none()),
    update=fake_state_update,
    view=_state => fake_inner_view(),
  )
}

///|
/// 假插件的 scope（组合根挂载形态：lens 对 + wrap）。
fn fake_scope() -> @moui.ScopedFeature[
  FakeModel,
  FakeState,
  FakeInnerMsg,
  FakeMsg,
] {
  fake_feature().scope(
    read=model => model.state,
    write=(state, model) => { ..model, state, },
    wrap=message => FakeMsg::FakeInner(message),
  )
}

///|
/// 假面板视图（根消息类型）：切片视图经 wrap 提升——与组合根的提升同形。
fn fake_root_view() -> @moui.View[FakeMsg] {
  fake_inner_view().map(message => FakeMsg::FakeInner(message))
}

///|
/// 测试 1：scope 委托——根消息经包装臂进入切片 update，lens 写回。
test "kernel/fake plugin scope delegates through lens" {
  let model : FakeModel = { title: "root", state: { asked: "", }, }
  let (next, effect) = fake_scope().update(model, FakeAsked("hi"))
  assert_eq(next.state.asked, "hi")
  assert_eq(next.title, "root")
  assert_no_effect(effect)
}

///|
/// 测试 2：事件总线按注册序派发，监听器是纯函数（可直断言）。
test "kernel/event bus dispatches in registration order" {
  let bus : EventBus[FakeEvent, FakeMsg] = EventBus::new()
  bus.on("first", fn(event) {
    match event {
      EvAsked(question) => [FakeMsg::FakePing("first:\{question}")]
      _ => []
    }
  })
  bus.on("second", fn(event) {
    match event {
      EvAsked(question) => [FakeMsg::FakePing("second:\{question}")]
      _ => []
    }
  })
  assert_eq(bus.listener_names(), ["first", "second"])
  let messages = bus.messages_for(EvAsked("q"))
  assert_eq(messages.length(), 2)
  assert_eq(messages[0], FakeMsg::FakePing("first:q"))
  assert_eq(messages[1], FakeMsg::FakePing("second:q"))
  // 不匹配的事件：零产出（诚实空，不装作处理过）
  assert_eq(bus.messages_for(EvSilent).length(), 0)
}

///|
/// 测试 3：emit 的 Effect 形态——空产出 = NoEffect，产出按序批量 Send。
test "kernel/event bus emit produces ordered send effects" {
  let bus : EventBus[FakeEvent, FakeMsg] = EventBus::new()
  bus.on("pings", fn(event) {
    match event {
      EvAsked(question) => [FakeMsg::FakePing(question), FakeMsg::FakeNoop]
      _ => []
    }
  })
  assert_no_effect(bus.emit(EvSilent))
  // 两条 = Batch[Send, Send]，序保持（Effect 无 Eq，按形状与载荷解构）
  match bus.emit(EvAsked("q")) {
    @moui.Effect::Batch(effects) => {
      assert_eq(effects.length(), 2)
      match effects[0] {
        @moui.Effect::Send(FakeMsg::FakePing("q")) => ()
        _ => abort("expected Send(ping q) first")
      }
      match effects[1] {
        @moui.Effect::Send(FakeMsg::FakeNoop) => ()
        _ => abort("expected Send(noop) second")
      }
    }
    _ => abort("expected Batch of two sends")
  }
}

///|
/// 测试 4：outbox 排空——多事件跨监听器保持事件序，空 outbox = NoEffect。
test "kernel/fire_events drains outbox preserving event order" {
  let bus : EventBus[FakeEvent, FakeMsg] = EventBus::new()
  bus.on("all", fn(event) {
    match event {
      EvAsked(question) => [FakeMsg::FakePing(question)]
      _ => []
    }
  })
  let outbox : Array[FakeEvent] = [EvAsked("a"), EvSilent, EvAsked("b")]
  match fire_events(outbox, bus) {
    @moui.Effect::Batch(effects) => {
      assert_eq(effects.length(), 2)
      match effects[0] {
        @moui.Effect::Send(FakeMsg::FakePing("a")) => ()
        _ => abort("expected first event's ping")
      }
      match effects[1] {
        @moui.Effect::Send(FakeMsg::FakePing("b")) => ()
        _ => abort("expected last event's ping")
      }
    }
    _ => abort("expected Batch of two")
  }
  assert_no_effect(fire_events([], bus))
}

///|
/// 测试 5：服务容器 denied 语义——全部执行器显式失败，web 控制为 noop。
test "kernel/denied services fail explicitly" {
  let services : StudioServices[FakeMsg] = StudioServices::denied()
  // provider：回调收到 Err（闭包同步执行，直接断言）
  let mut provider_error = ""
  (services.provider_submit)(
    {
      endpoint: "",
      key: "",
      model: "",
      system: "",
      prompt: "",
      history: [],
      json_mode: false,
    },
    fn(result) {
      match result {
        Err(message) => provider_error = message
        Ok(_) => abort("denied provider must not succeed")
      }
    },
  )
  assert_eq(provider_error, "真实 provider 未接入")
  // build：同样显式失败
  let mut build_error = ""
  (services.build_submit)(@build.BkFramePreview, "/root", "pkg", fn(result) {
    match result {
      Err(message) => build_error = message
      Ok(_) => abort("denied build must not succeed")
    }
  })
  assert_eq(
    build_error, "本端没有构建执行器:构建仅在 native 入口可达",
  )
  // web 控制：noop 效果
  assert_eq(services.preview_web.port, 0)
  assert_no_effect((services.preview_web.navigate)("http://localhost"))
  assert_no_effect((services.preview_web.reload)())
}

///|
/// 测试 6：贡献点——面板视图可渲染、活动栏项按模型快照判定、模式预设
/// apply 是一次性纯置位。
test "kernel/contributions render and apply are pure" {
  let panel : PanelView[FakeModel, FakeMsg] = {
    id: "fake.panel",
    render: (_model, _width, _height) => fake_root_view(),
  }
  // 渲染调用闭合（视图树深检归渲染层测试）
  let view = (panel.render)(
    { title: "m", state: { asked: "", }, },
    100.0,
    100.0,
  )
  ignore(view)
  let item : ActivityItem[FakeModel, FakeMsg] = {
    id: "fake.activity",
    icon: "focus",
    label_key: "app.ai.title",
    active: model => model.state.asked != "",
    on_click: model => FakeMsg::FakePing(model.state.asked),
  }
  assert_eq((item.active)({ title: "", state: { asked: "", }, }), false)
  assert_eq(
    (item.on_click)({ title: "", state: { asked: "x", }, }),
    FakeMsg::FakePing("x"),
  )
  let perspective : Perspective[FakeModel] = {
    id: "fake.mode",
    label_key: "app.mode.fake",
    left_panel: "fake.panel",
    center: "fake.center",
    right_panel: "",
    bottom_tab: "fake.tab",
    apply: model => { ..model, title: "entered", },
  }
  let entered = (perspective.apply)({ title: "root", state: { asked: "", }, })
  assert_eq(entered.title, "entered")
  assert_eq(entered.state.asked, "")
}
