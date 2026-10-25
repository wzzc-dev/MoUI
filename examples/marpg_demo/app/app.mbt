///|
using @views {canvas}

// The driving half of the slice: a fixed-step engine frame, the keys that feed it,
// and the battle menu the arena needs a host for.  The rules themselves -- damage,
// growth, ATB, opcode semantics -- live in `battle.mbt` and `vm.mbt`; this file is
// only the scheduler and the panel.

///|
/// Battle panel stages.  `bs_menu`/`bs_slot`/`bs_target` wait for a key,
/// `bs_actor`/`bs_line` wait for the engine frame, `bs_over` hands the result back.
pub let bs_none : Int32 = 0

///|
pub let bs_actor : Int32 = 1

///|
pub let bs_menu : Int32 = 2

///|
pub let bs_slot : Int32 = 3

///|
pub let bs_target : Int32 = 4

///|
pub let bs_line : Int32 = 5

///|
pub let bs_over : Int32 = 6

///|
/// One engine frame.  The original moved a sprite `step_px` pixels per frame on a
/// J2ME canvas, so the cadence belongs to the content: at 100 ms a 16 px tile takes
/// three frames (~300 ms) and crossing the 240 px view about four seconds.  The
/// subscription that wakes the app runs at 16 ms and is *not* the engine clock --
/// `steps` counts engine frames, not display frames, and no frame rate is claimed.
let step_ms : Double = 100.0

///|
let catch_up : Int32 = 4

///|
let tick_key : String = "marpg-demo:engine"

///|
/// How long a resolved action stays on screen before the ATB advances, in engine
/// frames, and how long a strip banner stays up.
let line_frames : Int32 = 3

///|
let banner_frames : Int32 = 20

///|
/// The battle panel's cursor and stage -- the arena is a pure model, so the menu
/// state it does not own lives here.
pub struct Panel {
  mut stage : Int32
  mut actor : Int32
  mut cursor : Int32
  mut action : Int32
  mut slot : Int32
  mut target : Int32
  mut log : String
  mut hold : Int32
} derive(Eq, @debug.Debug)

///|
pub fn Panel::new() -> Panel {
  {
    stage: bs_none,
    actor: -1,
    cursor: 0,
    action: atk_attack,
    slot: 0,
    target: 0,
    log: "",
    hold: 0,
  }
}

///|
/// The app model: the virtual machine (which owns the world and the arena) plus the
/// scheduler's own arithmetic.  A restart rebuilds the machine, so `vm` and `panel`
/// are the two fields that can be swapped.
pub struct Model {
  mut vm : Vm
  mut panel : Panel
  mut accum : Double
  mut steps : Int32
  mut notice : String
  mut notice_left : Int32
  mut last_map : Int32
}

///|
/// A game whose cartridge could not be decoded raises out of `program` rather than
/// painting an error card: the content is a checked-in fixture that
/// `cartridge_wbtest` verifies, so a decode failure means the build is broken, not
/// that the player should be told about it.
pub fn Model::boot() -> Model raise {
  Model::from_vm(Vm::new(load_cartridge()))
}

///|
pub fn Model::from_vm(vm : Vm) -> Model {
  {
    vm,
    panel: Panel::new(),
    accum: 0.0,
    steps: 0,
    notice: "",
    notice_left: 0,
    last_map: vm.world.map,
  }
}

///|
pub(all) enum Msg {
  Frame(Double)
  Walk(Int32)
  Turn(Int32)
  Confirm
  Back
  Save
  Saved(@services.ServiceTaskResult[Unit])
  Load
  Loaded(@services.ServiceTaskResult[String?])
  Restart
} derive(Eq, @debug.Debug)

///|
pub fn program(
  environment~ : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[Model, Msg] raise {
  let model = Model::boot()
  @moui.Program::new(
    init=() => (model, @moui.Effect::none()),
    update=(model, msg) => update(model, msg, environment~),
    view=model => view(model),
    subscriptions=model => engine_subscription(environment.timer(), model),
  ).with_commands(commands=model => program_commands(model))
}

///|
/// The engine ticks always: the walk clock, the script timers and the boot thread's
/// own frame loop all advance per frame, so the subscription stays armed under a
/// modal overlay -- which is what the title driver expects.
fn engine_subscription(
  timer : @services.TimerSource?,
  _model : Model,
) -> @moui.Subscription[Msg] {
  match timer {
    Some(source) =>
      source.subscription(
        interval_ms=16.0,
        key=tick_key,
        label="marpg engine frame",
        map=frame => Frame(frame.delta_ms),
      )
    None => @moui.Subscription::none()
  }
}

///|
/// Keys are claimed per pane, the way the engine read one `ay` mode at a time: an
/// arrow is a step on the map and a cursor move while a choice list or the battle
/// menu owns the screen.  Structural actions are `Ctrl` chords because a terminal
/// decoder emits a printable byte as both a key and a text input -- a bare `s` would
/// be claimed twice.
pub fn program_commands(model : Model) -> Array[@moui.ProgramCommand[Msg]] {
  let structure = [
    key_command("Confirm", "Enter", Confirm),
    key_command("Confirm", " ", Confirm),
    key_command("Back", "Escape", Back),
    key_command("Save", "s", Save, control=true),
    key_command("Load", "l", Load, control=true),
    key_command("Restart", "r", Restart, control=true),
  ]
  if chooses_keys(model) {
    [
      key_command("Cursor up", "ArrowUp", Turn(-1)),
      key_command("Cursor left", "ArrowLeft", Turn(-1)),
      key_command("Cursor down", "ArrowDown", Turn(1)),
      key_command("Cursor right", "ArrowRight", Turn(1)),
    ] +
    structure
  } else {
    [
      key_command("Walk up", "ArrowUp", Walk(0)),
      key_command("Walk right", "ArrowRight", Walk(1)),
      key_command("Walk down", "ArrowDown", Walk(2)),
      key_command("Walk left", "ArrowLeft", Walk(3)),
    ] +
    structure
  }
}

///|
/// The overlays with a cursor.  A dialog, a message strip or the title take the
/// same confirm edge, so their arrows stay with the engine.
fn chooses_keys(model : Model) -> Bool {
  let ui = model.vm.ui
  ui.active && (ui.kind == ov_choice || ui.kind == ov_battle)
}

///|
fn key_command(
  label : String,
  key : String,
  message : Msg,
  shift~ : Bool = false,
  control~ : Bool = false,
  meta~ : Bool = false,
) -> @moui.ProgramCommand[Msg] {
  @moui.ProgramCommand::new(
    command=@views.ActionCommand::new(
      intent=@views.CommandIntent::Activate,
      label~,
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key~,
          modifiers=@views.KeyModifiers::new(shift~, control~, meta~),
        ),
      ),
    ),
    message~,
  )
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  canvas(
    measure=_ => {
      @geometry.Size::new(width=view_w.to_double(), height=view_h.to_double())
    },
    draw=(ctx, frame) => paint_screen(ctx, frame, model),
    semantics_label="仙剑问情 引擎竖切",
  )
}

///|
pub fn update(
  model : Model,
  msg : Msg,
  environment~ : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> (Model, @moui.Effect[Msg]) {
  let idle = @moui.Effect::none()
  match msg {
    Frame(delta_ms) => {
      run_frames(model, delta_ms)
      (model, idle)
    }
    Walk(dir) => {
      walk(model, dir)
      (model, idle)
    }
    Turn(step) => {
      move_cursor(model, step)
      (model, idle)
    }
    Confirm => {
      confirm(model)
      (model, idle)
    }
    Back => {
      back(model)
      (model, idle)
    }
    Restart => {
      restart(model)
      (model, idle)
    }
    Save =>
      if can_save(model) {
        let task = environment
          .services()
          .settings()
          .write(save_key, snapshot_text(model.vm))
        (model, task.effect(map=result => Saved(result)))
      } else {
        banner(model, "此刻不能存档。")
        (model, idle)
      }
    Saved(result) => {
      match result {
        @services.Success(_) => banner(model, "已存档。")
        _ => banner(model, "存档失败。")
      }
      (model, idle)
    }
    Load =>
      (
        model,
        environment
        .services()
        .settings()
        .read(save_key)
        .effect(map=result => Loaded(result)),
      )
    Loaded(result) => {
      match result {
        @services.Success(Some(text)) =>
          if load_snapshot(model, text) {
            banner(model, "读档成功。")
          } else {
            banner(model, "存档不可用。")
          }
        @services.Success(None) => banner(model, "还没有存档。")
        _ => banner(model, "读档失败。")
      }
      (model, idle)
    }
  }
}

///|
/// A save is refused while an overlay owns the screen: a snapshot taken mid-dialog
/// would park the thread that opened it, and a battle in progress has no arena state
/// in the snapshot at all.
fn can_save(model : Model) -> Bool {
  !model.vm.ui.active
}

///|
/// Replace the running world with a snapshot's.  A restore is refused unless the
/// whole field list applies, and it always parks every thread afterwards so the
/// engine's own mark-based re-arm decides which encounters are live again.
fn load_snapshot(model : Model, text : String) -> Bool {
  if restore_snapshot(model.vm, text) {
    park_threads(model.vm)
    model.panel = Panel::new()
    model.last_map = model.vm.world.map
    model.accum = 0.0
    true
  } else {
    false
  }
}

///|
fn banner(model : Model, text : String) -> Unit {
  model.notice = text
  model.notice_left = banner_frames
}

///|
fn restart(model : Model) -> Unit {
  model.vm = Vm::new(model.vm.cart())
  model.panel = Panel::new()
  model.accum = 0.0
  model.notice = ""
  model.notice_left = 0
  model.last_map = model.vm.world.map
}

///|
/// Turn host milliseconds into engine frames.  A backlog longer than `catch_up`
/// frames is dropped rather than replayed: a stalled host should not make the hero
/// run to make up the time.
fn run_frames(model : Model, delta_ms : Double) -> Unit {
  model.accum = model.accum + delta_ms
  let mut caught_up = 0
  while model.accum >= step_ms && caught_up < catch_up {
    model.accum = model.accum - step_ms
    caught_up = caught_up + 1
    one_frame(model)
  }
  if model.accum > step_ms * catch_up.to_double() {
    model.accum = 0.0
  }
}

///|
/// One engine frame: pump the virtual machine, then the panel it owns.
fn one_frame(model : Model) -> Unit {
  model.vm.tick()
  model.steps = model.steps + 1
  let map = model.vm.world.map
  if map != model.last_map {
    model.last_map = map
    banner(model, text_at(map))
  } else if model.notice_left > 0 {
    model.notice_left = model.notice_left - 1
    if model.notice_left == 0 {
      model.notice = ""
    }
  }
  drive_battle(model)
}

///|
fn walk(model : Model, dir : Int32) -> Unit {
  if !model.vm.ui.active {
    let _ = model.vm.world.hero_begin_step(dir)
  }
}

///|
fn move_cursor(model : Model, step : Int32) -> Unit {
  let panel = model.panel
  let ui = model.vm.ui
  if ui.kind == ov_choice {
    if ui.option_count > 0 {
      panel.cursor = wrap_index(panel.cursor + step, ui.option_count)
    }
  } else if ui.kind == ov_battle {
    if panel.stage == bs_menu {
      panel.cursor = wrap_index(panel.cursor + step, action_count)
    } else if panel.stage == bs_slot {
      let rows = slot_rows(model, model.vm.cart())
      if rows.length() > 0 {
        panel.cursor = wrap_index(panel.cursor + step, rows.length())
      }
    } else if panel.stage == bs_target {
      let list = target_candidates(model)
      if list.length() > 0 {
        panel.target = wrap_index(panel.target + step, list.length())
      }
    }
  }
}

///|
fn wrap_index(at : Int32, count : Int32) -> Int32 {
  if count <= 0 {
    0
  } else {
    (at % count + count) % count
  }
}

///|
/// The single confirm edge.  With no overlay it is the engine's `key_confirm`, which
/// is what an auto-talk thread tests; with one it dismisses a card, chooses an
/// option, or advances the battle menu.
fn confirm(model : Model) -> Unit {
  let ui = model.vm.ui
  if !ui.active {
    model.vm.press_key(key_confirm)
  } else if ui.kind == ov_battle {
    confirm_battle(model)
  } else if ui.kind == ov_choice {
    model.vm.pick_option(model.panel.cursor)
    model.panel.cursor = 0
  } else if ui.kind == ov_game_over {
    restart(model)
  } else {
    model.vm.close_overlay()
  }
}

///|
fn back(model : Model) -> Unit {
  let ui = model.vm.ui
  let panel = model.panel
  if !ui.active {
    model.vm.press_key(key_back)
  } else if ui.kind == ov_battle {
    if panel.stage == bs_slot || panel.stage == bs_target {
      panel.stage = bs_menu
      panel.cursor = panel.action
    }
  } else if ui.kind == ov_dialog || ui.kind == ov_message || ui.kind == ov_title {
    model.vm.close_overlay()
  }
}

// === Battle driver ===

///|
fn drive_battle(model : Model) -> Unit {
  let panel = model.panel
  match model.vm.battle {
    None => if panel.stage != bs_none { panel.stage = bs_none }
    Some(arena) =>
      if arena.over {
        if panel.stage != bs_over {
          panel.stage = bs_over
          panel.hold = line_frames
          panel.log = reward_line(arena)
        } else if panel.hold > 0 {
          panel.hold = panel.hold - 1
          if panel.hold == 0 {
            model.vm.finish_battle(arena.result)
            panel.stage = bs_none
          }
        }
      } else if panel.hold > 0 {
        panel.hold = panel.hold - 1
        if panel.hold == 0 && panel.stage == bs_line {
          panel.stage = bs_actor
        }
      } else if panel.stage == bs_actor || panel.stage == bs_none {
        advance_atb(model, arena)
      }
  }
}

///|
/// The ATB only runs on the engine frame, so the enemy turns come out of the same
/// pump the party waits on: whoever fills its gauge first acts, and the menu opens
/// when that someone is in the party.
fn advance_atb(model : Model, arena : Battle) -> Unit {
  let panel = model.panel
  let actor = arena.next_actor()
  if actor < 0 {
    ()
  } else if arena.side(actor) == side_party {
    panel.actor = actor
    panel.action = atk_attack
    panel.cursor = 0
    panel.stage = bs_menu
  } else {
    let before = hp_snapshot(arena)
    arena.enemy_step(actor)
    panel.log = action_line(model, arena, actor, before)
    panel.stage = bs_line
    panel.hold = line_frames
  }
}

///|
fn confirm_battle(model : Model) -> Unit {
  let panel = model.panel
  if panel.stage == bs_line {
    panel.hold = 0
    panel.stage = bs_actor
  } else if panel.stage == bs_over {
    // `drive_battle` only calls `finish_battle` while a positive hold counts
    // down, so skipping the victory line with 0 would park the arena forever.
    panel.hold = 1
  } else if panel.stage == bs_menu {
    panel.action = wrap_index(panel.cursor, action_count)
    panel.target = 0
    if panel.action == atk_attack {
      panel.stage = bs_target
    } else {
      panel.cursor = 0
      panel.stage = bs_slot
    }
  } else if panel.stage == bs_slot {
    choose_slot(model)
  } else if panel.stage == bs_target {
    commit_player_action(model)
  }
}

///|
/// The row under the cursor becomes the pending skill or item.  A self-focused skill
/// skips the target stage: the content marks those with `target == 2`, and pointing
/// at yourself would be a second step for the same answer.
fn choose_slot(model : Model) -> Unit {
  let panel = model.panel
  let rows = slot_rows(model, model.vm.cart())
  if rows.length() == 0 {
    panel.stage = bs_menu
  } else {
    panel.slot = rows[wrap_index(panel.cursor, rows.length())]
    let cart = model.vm.cart()
    if panel.action == atk_skill && cart.skill.cell(panel.slot, s_target) == 2 {
      commit_self(model)
    } else {
      panel.target = 0
      panel.stage = bs_target
    }
  }
}

///|
fn commit_self(model : Model) -> Unit {
  let panel = model.panel
  match model.vm.battle {
    None => ()
    Some(arena) => {
      let before = hp_snapshot(arena)
      let done = arena.use_skill(panel.actor, panel.slot, panel.actor)
      panel.log = if done {
        action_line(model, arena, panel.actor, before)
      } else {
        "灵力不够。"
      }
      panel.stage = bs_line
      panel.hold = line_frames
    }
  }
}

///|
/// The unit indices the cursor can reach.  The chosen row decides the side: an
/// attack or a damaging spell points at the enemies, a heal or an item at the party,
/// and a revival only at the fallen.
pub fn target_candidates(model : Model) -> Array[Int32] {
  let panel = model.panel
  if panel.stage != bs_target {
    return []
  }
  match model.vm.battle {
    None => []
    Some(arena) => {
      let cart = model.vm.cart()
      let allies = chooses_allies(cart, panel.action, panel.slot)
      let fallen = needs_corpse(cart, panel.action, panel.slot)
      let want = if allies { side_party } else { side_enemy }
      let out : Array[Int32] = []
      for i = 0; i < arena.unit_count(); i = i + 1 {
        let unit = arena.unit(i)
        if arena.side(i) == want &&
          ((unit.is_alive() && !fallen) || (fallen && !unit.is_alive())) {
          out.push(i)
        }
      }
      out
    }
  }
}

///|
fn chooses_allies(cart : Cartridge, action : Int32, row : Int32) -> Bool {
  if action == atk_skill {
    cart.skill.cell(row, s_target) != 0
  } else {
    action == atk_item
  }
}

///|
fn needs_corpse(cart : Cartridge, action : Int32, row : Int32) -> Bool {
  if action == atk_skill {
    cart.skill.cell(row, s_kind) == skill_revive
  } else {
    action == atk_item && cart.item.cell(row, i_kind) == item_revive
  }
}

///|
fn commit_player_action(model : Model) -> Unit {
  let panel = model.panel
  match model.vm.battle {
    None => ()
    Some(arena) => {
      let list = target_candidates(model)
      if list.length() == 0 {
        panel.stage = bs_menu
      } else {
        let target = list[wrap_index(panel.target, list.length())]
        let before = hp_snapshot(arena)
        let done = if panel.action == atk_skill {
          arena.use_skill(panel.actor, panel.slot, target)
        } else if panel.action == atk_item {
          let applied = arena.use_item(panel.actor, panel.slot, target)
          if applied {
            let _ = model.vm.spend_item(panel.slot)
          }
          applied
        } else {
          arena.basic_attack(panel.actor, target)
        }
        panel.log = if done {
          action_line(model, arena, panel.actor, before)
        } else if panel.action == atk_item {
          "用不上。"
        } else {
          "灵力不够。"
        }
        panel.stage = bs_line
        panel.hold = line_frames
      }
    }
  }
}

///|
fn hp_snapshot(arena : Battle) -> Array[Int32] {
  let out : Array[Int32] = []
  for i = 0; i < arena.unit_count(); i = i + 1 {
    out.push(arena.unit(i).hp)
  }
  out
}

///|
/// The log line is derived, not authored: whatever the resolution changed is what
/// gets said.  Taking the largest hp drop in the snapshot diff keeps the wording
/// honest for a multi-target spell and for a kill.
fn action_line(
  model : Model,
  arena : Battle,
  actor : Int32,
  before : Array[Int32],
) -> String {
  let cart = model.vm.cart()
  let who = name_of(cart, arena.unit(actor))
  let mut worst = -1
  let mut loss = 0
  for i = 0; i < arena.unit_count(); i = i + 1 {
    let dropped = before[i] - arena.unit(i).hp
    if dropped > loss {
      loss = dropped
      worst = i
    }
  }
  if worst < 0 {
    who + " 出手，却没有打中。"
  } else {
    let target = arena.unit(worst)
    let hit = who +
      " 伤了 " +
      name_of(cart, target) +
      " " +
      loss.to_string() +
      " 点。"
    if target.is_alive() {
      hit
    } else {
      hit + name_of(cart, target) + " 倒下了。"
    }
  }
}

///|
fn reward_line(arena : Battle) -> String {
  if arena.result != battle_win {
    "队伍撑不住了。"
  } else {
    "得铜钱 " +
    arena.gold.to_string() +
    "，经验 " +
    arena.exp_total.to_string() +
    "。"
  }
}

///|
fn name_of(cart : Cartridge, fighter : Fighter) -> String {
  text_at(cart.combatant.cell(fighter.row, c_name))
}
