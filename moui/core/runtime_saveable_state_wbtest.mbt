///|
test "saveable strings survive rebuild resize and root remount by stable component id" {
  let value = State::new("first")
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let current = ctx.watch(value)
      ctx.save_string(key="draft", current)
      ViewSpec::TextSpec({
        key: None,
        text: ctx.restore_string(key="draft").unwrap_or("missing"),
        size: Size::new(width=120.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=20.0),
  )
  guard runtime.build_draw_commands()[1] is DrawText({ text: "first", .. }) else {
    fail("expected initial saved value")
  }
  value.set("second")
  guard runtime.build_draw_commands()[1] is DrawText({ text: "second", .. }) else {
    fail("expected saved value after rebuild")
  }
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=160.0, height=30.0)))
  guard runtime.build_draw_commands()[1] is DrawText({ text: "second", .. }) else {
    fail("expected saved value after resize")
  }
  runtime.mount(runtime.root_spec)
  guard runtime.build_draw_commands()[1] is DrawText({ text: "second", .. }) else {
    fail("expected saved value after same-root remount")
  }
}

///|
test "saveable store preserves bools and ints through string storage" {
  let store = SaveableStateStore::new()
  store.set_bool("enabled", true)
  store.set_int("count", -7)
  store.set_string("bad-int", "12x")
  match store.get_bool("enabled") {
    Some(true) => ()
    _ => fail("expected saved bool")
  }
  match store.get_int("count") {
    Some(-7) => ()
    _ => fail("expected saved int")
  }
  match store.get_int("bad-int") {
    None => ()
    _ => fail("expected invalid int payload to be ignored")
  }
}

///|
test "saveable codecs expose encode decode and store snapshots" {
  let codec = SaveableCodec::new(
    encode=(value : Int) => "score:" + value.to_string(),
    decode=value => {
      if value.length() > 6 && value[:6].to_owned() == "score:" {
        parse_saveable_score(value[6:].to_owned())
      } else {
        None
      }
    },
  )
  inspect(codec.encode_value(12), content="score:12")
  match codec.decode_value("score:34") {
    Some(34) => ()
    _ => fail("expected custom decode")
  }
  match codec.decode_value("bad") {
    None => ()
    _ => fail("expected invalid custom decode to return none")
  }
  let store = SaveableStateStore::new()
  store.set("score", 8, codec)
  store.set_bool("enabled", true)
  let snapshot = store.snapshot()
  store.set("score", 9, codec)
  store.remove("enabled")
  store.restore(snapshot)
  match store.get("score", codec) {
    Some(8) => ()
    _ => fail("expected restored score")
  }
  match store.get_bool("enabled") {
    Some(true) => ()
    _ => fail("expected restored bool")
  }
}

///|
test "saveable codec stores custom values through scoped component state" {
  let codec = SaveableCodec::new(
    encode=(value : Int) => "score:" + value.to_string(),
    decode=value => {
      if value.length() > 6 && value[:6].to_owned() == "score:" {
        parse_saveable_score(value[6:].to_owned())
      } else {
        None
      }
    },
  )
  let score_ref : Ref[State[Int]?] = Ref(None)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let score = ctx.saveable(key="score", 9, codec)
      score_ref.val = Some(score)
      ViewSpec::TextSpec({
        key: None,
        text: "Score \{score.get()}",
        size: Size::new(width=120.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=20.0),
  )
  guard runtime.build_draw_commands()[1] is DrawText({ text: "Score 9", .. }) else {
    fail("expected initial custom saveable state")
  }
  match score_ref.val {
    Some(score) => score.set(17)
    None => fail("missing score state")
  }
  runtime.mount(runtime.root_spec)
  guard runtime.build_draw_commands()[1] is DrawText({ text: "Score 17", .. }) else {
    fail("expected custom saveable state after same-root remount")
  }
}

///|
test "build context saves and restores custom codec values" {
  let source = State::new(11)
  let codec = SaveableCodec::new(
    encode=(value : Int) => "score:" + value.to_string(),
    decode=value => {
      if value.length() > 6 && value[:6].to_owned() == "score:" {
        parse_saveable_score(value[6:].to_owned())
      } else {
        None
      }
    },
  )
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let value = ctx.watch(source)
      ctx.save(key="score", value, codec)
      let restored = ctx.restore(key="score", codec).unwrap_or(0)
      ViewSpec::TextSpec({
        key: None,
        text: "Score \{restored}",
        size: Size::new(width=120.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=20.0),
  )
  guard runtime.build_draw_commands()[1] is DrawText({ text: "Score 11", .. }) else {
    fail("expected initial custom save restore")
  }
  source.set(19)
  guard runtime.build_draw_commands()[1] is DrawText({ text: "Score 19", .. }) else {
    fail("expected updated custom save restore")
  }
}

///|
fn parse_saveable_score(value : String) -> Int? {
  let chars = value.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut parsed = 0
  for char in chars {
    if !char.is_ascii_digit() {
      return None
    }
    parsed = parsed * 10 + char.to_int() - '0'.to_int()
  }
  Some(parsed)
}

///|
test "saveable bool and int states survive rebuild and remount" {
  let count_ref : Ref[State[Int]?] = Ref(None)
  let flag_ref : Ref[State[Bool]?] = Ref(None)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let count = ctx.saveable_int(key="count", 3)
      let flag = ctx.saveable_bool(key="flag", false)
      count_ref.val = Some(count)
      flag_ref.val = Some(flag)
      ViewSpec::TextSpec({
        key: None,
        text: "\{count.get()}:\{flag.get()}",
        size: Size::new(width=120.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=20.0),
  )
  guard runtime.build_draw_commands()[1] is DrawText({ text: "3:false", .. }) else {
    fail("expected initial typed saveable state")
  }
  match count_ref.val {
    Some(count) => count.set(42)
    None => fail("missing count state")
  }
  match flag_ref.val {
    Some(flag) => flag.set(true)
    None => fail("missing flag state")
  }
  guard runtime.build_draw_commands()[1] is DrawText({ text: "42:true", .. }) else {
    fail("expected updated typed saveable state")
  }
  runtime.mount(runtime.root_spec)
  guard runtime.build_draw_commands()[1] is DrawText({ text: "42:true", .. }) else {
    fail("expected typed saveable state after same-root remount")
  }
}

///|
test "stale saveable state subscriptions are cancelled after rebuild" {
  let states : Array[State[Int]] = []
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let count = ctx.saveable_int(key="count", 1)
      states.push(count)
      ViewSpec::TextSpec({
        key: None,
        text: "Count \{count.get()}",
        size: Size::new(width=120.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=20.0),
  )
  guard runtime.build_draw_commands()[1] is DrawText({ text: "Count 1", .. }) else {
    fail("expected initial saveable state")
  }
  guard states.length() == 1 else {
    fail("expected first saveable state handle")
  }
  let stale = states[0]
  stale.set(4)
  guard runtime.build_draw_commands()[1] is DrawText({ text: "Count 4", .. }) else {
    fail("expected active saveable state to rebuild")
  }
  guard states.length() == 2 else {
    fail("expected rebuilt saveable state handle")
  }
  inspect(runtime.needs_rebuild, content="false")
  stale.set(9)
  inspect(runtime.needs_rebuild, content="false")
  runtime.mount(runtime.root_spec)
  guard runtime.build_draw_commands()[1] is DrawText({ text: "Count 4", .. }) else {
    fail("expected stale state write to be ignored")
  }
  let unmounted = states[states.length() - 1]
  let root_spec = runtime.root_spec
  runtime.mount(ViewSpec::EmptySpec)
  unmounted.set(13)
  inspect(runtime.needs_rebuild, content="false")
  runtime.mount(root_spec)
  guard runtime.build_draw_commands()[1] is DrawText({ text: "Count 4", .. }) else {
    fail("expected unmounted state write to be ignored")
  }
}
