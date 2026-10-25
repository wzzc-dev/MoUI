// The played path at the message level: the same `update` a runtime drives, fed
// only the messages a view delivers -- arrow keys, confirm, and the engine's own
// `Frame(100.0)` ticks.  Save and load go through `AppServices` settings for real
// (`FakeAppServices`), and the task effects are run the way the runtime runs them,
// so `Saved`/`Loaded` arrive as messages rather than being simulated.
//
// The one thing this cannot cover is the presentation itself: a green run here is
// not evidence that the window shows anything (that is the macOS smoke's job) and
// no frame rate is claimed anywhere below.

///|
/// The service desk a played session runs against.  The fake keeps settings in
/// memory and records every call, so `calls()` is what proves the save really went
/// through the settings service instead of a test-side side channel.
struct Desk {
  fake : @services.FakeAppServices
  env : @services.AppEnvironment
}

///|
fn play_desk() -> Desk {
  let fake = @services.FakeAppServices::new()
  { fake, env: @services.AppEnvironment::new(services=fake.services()), }
}

///|
/// Deliver one message, then run whatever effect it produced.  A service task is
/// run with its completion fed back in as the next message -- the hand-back the
/// runtime performs, minus the platform.
fn play_msg(
  model : Model,
  msg : Msg,
  environment : @services.AppEnvironment,
) -> Model {
  let (next, effect) = update(model, msg, environment~)
  play_effect(next, effect, environment)
}

///|
/// The slice's `update` returns `Send`, `Batch` or a `Task`; it never dispatches a
/// runtime action or runs a descriptor effect, so those arms are unreachable here.
fn play_effect(
  model : Model,
  effect : @moui.Effect[Msg],
  environment : @services.AppEnvironment,
) -> Model {
  match effect {
    @core.NoEffect => model
    @core.Batch(effects) => {
      let mut state = model
      for one in effects {
        state = play_effect(state, one, environment)
      }
      state
    }
    @core.Send(message) => play_msg(model, message, environment)
    @core.Dispatch(_) => model
    @core.Run(_, _) => model
    @core.Task(_, start) => {
      let inbox : Array[Msg] = []
      let _ = start(message => inbox.push(message))
      let mut state = model
      for message in inbox {
        state = play_msg(state, message, environment)
      }
      state
    }
  }
}

///|
/// Boot and leave the map driver on screen, the way the key stream does it: one
/// engine frame raises the title card (a script event, not the first paint),
/// confirm drops it, the next frame runs the boot thread's `SCENE` and the arrival
/// strip, confirm closes the strip, and one more frame parks the arrival thread.
fn open_map(desk : Desk) -> Model raise {
  let mut model = Model::boot()
  model = play_msg(model, Frame(step_ms), desk.env)
  model = play_msg(model, Confirm, desk.env)
  model = play_msg(model, Frame(step_ms), desk.env)
  model = play_msg(model, Confirm, desk.env)
  play_msg(model, Frame(step_ms), desk.env)
}

///|
/// One tile, played as an arrow key: the step plan starts on the message and the
/// engine frames carry it.  `hero.mode` is the engine's own `aG[0]`, so the loop
/// ends when the sprite is standing again rather than after a guessed count.
fn step_tile(model : Model, desk : Desk, dir : Int32) -> Model {
  let mut state = play_msg(model, Walk(dir), desk.env)
  let mut frames = 0
  while frames < 8 && state.vm.world.hero.mode != 0 {
    state = play_msg(state, Frame(step_ms), desk.env)
    frames = frames + 1
  }
  state
}

///|
fn walk_cells(model : Model, desk : Desk, dirs : Array[Int32]) -> Model {
  let mut state = model
  for dir in dirs {
    state = step_tile(state, desk, dir)
  }
  state
}

///|
fn is_fighting(model : Model) -> Bool {
  match model.vm.battle {
    None => false
    Some(_) => true
  }
}

///|
/// The overture both outcomes share: boot, walk the four tiles up and one left the
/// village's collision layer leaves open, talk the elder through both cards and the
/// choice, take the copper key, and let the script open the arena.  The landmarks
/// are asserted here because they are the path's contract, not this file's private
/// business.
fn reach_the_arena(desk : Desk) -> Model raise {
  let mut model = open_map(desk)
  inspect(model.vm.ui.active, content="false")
  inspect(model.vm.world.map, content="0")
  inspect(model.vm.world.hero.col(), content="11")
  inspect(model.vm.world.hero.row(), content="13")
  // the village is 26 tiles wide, so the 240px viewport can scroll 176px
  inspect(model.vm.world.map_of().width, content="26")
  model = walk_cells(model, desk, [0, 0, 0, 0, 3])
  inspect(model.vm.world.hero.col(), content="10")
  inspect(model.vm.world.hero.row(), content="9")
  inspect(model.vm.world.hero.mode, content="0")
  inspect(model.vm.world.hero.dir, content="3")
  // confirm with no overlay is the engine's own key edge: the auto-talk thread
  // reads it together with the contact rect, so the card is the thread's doing
  model = play_msg(model, Confirm, desk.env)
  model = play_msg(model, Frame(step_ms), desk.env)
  inspect(model.vm.ui.kind, content="1")
  inspect(model.vm.ui.body, content="33")
  inspect(model.vm.modal_owner, content="2")
  model = play_msg(model, Confirm, desk.env)
  model = play_msg(model, Frame(step_ms), desk.env)
  inspect(model.vm.ui.kind, content="1")
  inspect(model.vm.ui.body, content="34")
  inspect(model.vm.ui.pose, content="1")
  model = play_msg(model, Confirm, desk.env)
  model = play_msg(model, Frame(step_ms), desk.env)
  // the second card's close releases the chain: met=1 lands, the list opens
  inspect(model.vm.get_var(v_elder_met), content="1")
  inspect(model.vm.ui.kind, content="2")
  inspect(model.vm.ui.option_count, content="2")
  inspect(model.panel.cursor, content="0")
  model = play_msg(model, Turn(1), desk.env)
  inspect(model.panel.cursor, content="1")
  model = play_msg(model, Turn(1), desk.env)
  inspect(model.panel.cursor, content="0")
  model = play_msg(model, Confirm, desk.env)
  inspect(model.vm.get_var(v_choice), content="0")
  model = play_msg(model, Frame(step_ms), desk.env)
  // the true branch: the key is taken, handed over by GIVE, and GIVE ends the
  // frame there, so its strip arrives one frame later
  inspect(model.vm.get_var(v_key_taken), content="1")
  let key_row = model.vm.world.sprite(0).unwrap().reward_thing
  inspect(model.vm.item_count(key_row), content="1")
  inspect(model.vm.ui.active, content="false")
  model = play_msg(model, Frame(step_ms), desk.env)
  inspect(model.vm.ui.kind, content="3")
  inspect(model.vm.ui.body, content="39")
  model = play_msg(model, Confirm, desk.env)
  model = play_msg(model, Frame(step_ms), desk.env)
  inspect(model.vm.ui.body, content="60")
  model = play_msg(model, Confirm, desk.env)
  model = play_msg(model, Frame(step_ms), desk.env)
  // the chain is parked on the real key wait, with the screen already free
  inspect(model.vm.threads[2].state, content="4")
  inspect(model.vm.ui.active, content="false")
  model = play_msg(model, Confirm, desk.env)
  model = play_msg(model, Frame(step_ms), desk.env)
  inspect(model.vm.get_var(v_key_flag), content="1")
  inspect(model.vm.ui.kind, content="5")
  inspect(model.vm.modal_owner, content="2")
  // the driver attaches to the arena in the same frame it opens, and the ATB
  // hands the first turn to the party
  inspect(model.panel.stage, content="2")
  inspect(model.vm.get_var(v_battle_result), content="0")
  inspect(is_fighting(model), content="true")
  model
}

///|
/// Play the arena through the menu: wait for the ATB to hand a party member the
/// cursor, take the first row (attack), take the first living enemy.  Bounded so a
/// stuck stage fails instead of spinning.
fn play_arena(model : Model, desk : Desk) -> Model raise {
  let mut state = model
  let mut rounds = 0
  let mut stuck = false
  while rounds < 60 && is_fighting(state) && !stuck {
    let mut waited = 0
    while waited < 120 && is_fighting(state) && state.panel.stage != bs_menu {
      state = play_msg(state, Frame(step_ms), desk.env)
      waited = waited + 1
    }
    if state.panel.stage == bs_menu {
      state = play_msg(state, Confirm, desk.env)
      inspect(state.panel.stage, content="4")
      state = play_msg(state, Confirm, desk.env)
      rounds = rounds + 1
    } else {
      stuck = true
    }
  }
  state
}

///|
/// The losing policy: spend every turn on the self-heal, which buys time until the
/// caster's mp runs out and the cast is refused.  A refused cast still spends the
/// turn, so the wolves keep swinging and eventually take the party down -- the other
/// half of the battle result the scripts can read.  (Pointing a revive at nobody is
/// not a turn: the target screen has no candidates and bounces back to the menu.)
fn waste_arena(model : Model, desk : Desk) -> Model raise {
  let mut state = model
  let mut turns = 0
  let mut stuck = false
  while turns < 200 && is_fighting(state) && !stuck {
    let mut waited = 0
    while waited < 120 && is_fighting(state) && state.panel.stage != bs_menu {
      state = play_msg(state, Frame(step_ms), desk.env)
      waited = waited + 1
    }
    if state.panel.stage == bs_menu {
      state = play_msg(state, Turn(1), desk.env) // attack -> skill page
      state = play_msg(state, Confirm, desk.env)
      inspect(state.panel.stage, content="3")
      state = play_msg(state, Turn(2), desk.env) // guard: heal, self-target
      state = play_msg(state, Confirm, desk.env)
      // a self-targeted row skips the target screen and resolves straight away
      inspect(state.panel.stage, content="5")
      turns = turns + 1
    } else {
      stuck = true
    }
  }
  state
}

///|
test "the played path: title, walk, elder, choice, wolves, save, load" {
  let desk = play_desk()
  let mut model = reach_the_arena(desk)
  model = play_arena(model, desk)
  // the arena closed through the driver's own hand-back, not a test-side call
  inspect(is_fighting(model), content="false")
  inspect(model.vm.ui.active, content="false")
  inspect(model.vm.get_var(v_battle_result), content="0")
  inspect(model.vm.money_at(0), content="44")
  inspect(model.vm.unknown_opcodes, content="0")
  // the chain finished, parked, and the bundle's mark 1 re-armed the NPC
  for i = 0; i < 4; i = i + 1 {
    model = play_msg(model, Frame(step_ms), desk.env)
  }
  inspect(model.vm.threads[2].pc, content="0")
  inspect(model.vm.threads[2].state, content="-1")
  // the save is a real settings write whose result comes back as `Saved`
  let saved = snapshot_text(model.vm)
  model = play_msg(model, Save, desk.env)
  inspect(model.notice, content="已存档。")
  inspect(model.notice_left, content=banner_frames.to_string())
  inspect(
    seen_in(desk.fake.calls(), "settings:write:" + save_key),
    content="true",
  )
  // Perturb after the save so the restore has something to undo.  The teleport is
  // test-only and is not a played action: what is under test is the read path, and
  // walking to the wildpath just to dirty the state would test the walk again.
  let saved_hp = model.vm.party[0].hp
  let saved_key = model.vm.item_count(
    model.vm.world.sprite(0).unwrap().reward_thing,
  )
  model.vm.world.place_hero(1, 3, 3)
  model.vm.set_var(v_elder_met, 0)
  model.vm.party[0].hp = 1
  ignore(model.vm.spend_item(3))
  model = play_msg(model, Load, desk.env)
  inspect(model.notice, content="读档成功。")
  inspect(
    seen_in(desk.fake.calls(), "settings:read:" + save_key),
    content="true",
  )
  inspect(model.vm.world.map, content="0")
  inspect(model.vm.world.hero.col(), content="10")
  inspect(model.vm.world.hero.row(), content="9")
  inspect(model.vm.get_var(v_elder_met), content="1")
  inspect(model.vm.party[0].hp, content=saved_hp.to_string())
  inspect(model.vm.item_count(3), content=saved_key.to_string())
  // every field in the snapshot came back, so the round trip is exact
  inspect(snapshot_text(model.vm), content=saved)
}

///|
test "a lost arena still hands the result back and lets the npc re-arm" {
  let desk = play_desk()
  let mut model = reach_the_arena(desk)
  model = waste_arena(model, desk)
  inspect(is_fighting(model), content="false")
  inspect(model.vm.ui.active, content="false")
  // the script reads 0 for victory, so this is the loss the arena settled
  inspect(model.vm.get_var(v_battle_result), content="1")
  // a loss pays nothing, and the key that was granted before the fight stays
  inspect(model.vm.money_at(0), content="0")
  inspect(model.vm.get_var(v_key_taken), content="1")
  for i = 0; i < 4; i = i + 1 {
    model = play_msg(model, Frame(step_ms), desk.env)
  }
  inspect(model.vm.threads[2].pc, content="0")
  inspect(model.vm.threads[2].state, content="-1")
  // the repeat branch is what a met elder says now: one card, no second reward
  model = play_msg(model, Confirm, desk.env)
  model = play_msg(model, Frame(step_ms), desk.env)
  inspect(model.vm.ui.kind, content="1")
  inspect(model.vm.ui.body, content="35")
}

///|
test "a save is refused while a card owns the screen" {
  let desk = play_desk()
  let mut model = Model::boot()
  model = play_msg(model, Frame(step_ms), desk.env)
  inspect(model.vm.ui.kind, content="4")
  model = play_msg(model, Save, desk.env)
  inspect(model.notice, content="此刻不能存档。")
  inspect(
    seen_in(desk.fake.calls(), "settings:write:" + save_key),
    content="false",
  )
}

///|
test "a load with nothing stored says so instead of resetting the run" {
  let desk = play_desk()
  let mut model = Model::boot()
  model = play_msg(model, Frame(step_ms), desk.env)
  model = play_msg(model, Load, desk.env)
  inspect(model.notice, content="还没有存档。")
  inspect(model.vm.ui.kind, content="4")
  inspect(
    seen_in(desk.fake.calls(), "settings:read:" + save_key),
    content="true",
  )
}
