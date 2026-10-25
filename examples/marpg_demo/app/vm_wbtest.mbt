// White-box tests for the script VM: the loader's arming, the per-frame thread
// pump, the wait states and the opcode bodies, driven through the content the
// generator emits.  Instruction indexes quoted in the comments are the elder
// thread's (`tools/marpg/gen_content.py`), which is the branch showcase.

///|
fn vm_new() -> Vm raise {
  Vm::new(load_cartridge())
}

///|
/// Pump frames until an overlay owns the screen, and stop.
fn pump(vm : Vm, budget : Int32) -> Unit {
  let mut i = 0
  while i < budget && !vm.ui.active {
    vm.tick()
    i = i + 1
  }
}

///|
/// Frames with the confirm edge pressed, closing whatever appears -- the shape a
/// player mashing A produces.
fn drive(vm : Vm, frames : Int32) -> Unit {
  for i = 0; i < frames; i = i + 1 {
    vm.press_key(key_confirm)
    vm.tick()
    if vm.ui.active {
      vm.close_overlay()
    }
  }
}

///|
/// Boot chain plus the one-shot arrival message: after this the map driver owns
/// the screen and every class-1/2 thread is armed and waiting.
fn to_the_map(vm : Vm) -> Unit {
  vm.tick()
  vm.close_overlay()
  vm.tick()
  vm.close_overlay()
  vm.tick()
}

///|
/// Teleport the hero one cell to the right of a sprite, which is inside both the
/// proximity rect and the auto-talk rect.
fn stand_right_of(vm : Vm, slot : Int32) -> Unit {
  let s = vm.world.sprite(slot).unwrap()
  vm.world.place_hero(s.map, s.x.div(tile_size) + 1, s.y.div(tile_size))
}

///|
test "the boot thread opens the title card and the rest of the list waits" {
  let vm = vm_new()
  inspect(vm.threads[0].state, content="0")
  inspect(vm.threads[1].state, content="-1")
  inspect(vm.modal_owner, content="-1")
  vm.tick()
  let ui = vm.ui
  inspect(ui.kind, content="4")
  inspect(ui.body, content="0")
  inspect(ui.active, content="true")
  inspect(vm.modal_owner, content="0")
  // the arrival thread is class 0 -- always ready -- but the frame the title took
  // the screen is where the pump stops, so it cannot overwrite the card.
  inspect(vm.threads[1].state, content="-1")
  inspect(vm.world.hero.x, content="0")
}

///|
test "closing the card finishes the boot chain and hands the screen to the next ready thread" {
  let vm = vm_new()
  vm.tick()
  vm.close_overlay()
  vm.tick()
  // TITLE parked at pc 1; this frame ran VAR bQ[0]=0 and SCENE 0,(11,13),down.
  inspect(vm.get_var(v_scene), content="0")
  inspect(vm.world.map, content="0")
  inspect(vm.world.hero.x, content="176")
  inspect(vm.world.hero.y, content="208")
  inspect(vm.world.hero.dir, content="2")
  // a class-4 thread parks rather than re-arming.
  inspect(vm.threads[0].state, content="6")
  // ... and the arrival message is what now owns the screen.
  inspect(vm.ui.kind, content="3")
  inspect(vm.ui.body, content="61")
  inspect(vm.modal_owner, content="1")
  vm.close_overlay()
  vm.tick()
  // op2 KILL parks a class-0 thread for good, and the map driver has the screen.
  inspect(vm.threads[1].state, content="6")
  inspect(vm.modal_owner, content="-1")
  inspect(vm.ui.active, content="false")
}

///|
test "the marker scan only matches at depth zero" {
  let vm = vm_new()
  // elder thread: IF@0 ... IF@5 ... ELSE@12 ENDIF@15 ELSE@16 ENDIF@18 KILL@19
  inspect(vm.cart().scripts.threads[2].insns.length(), content="20")
  vm.threads[2].pc = 0
  inspect(vm.scan_marker(2, Else), content="16")
  inspect(vm.scan_marker(2, Endif), content="18")
  // from inside the nested branch its own ENDIF is the first marker at depth 0.
  vm.threads[2].pc = 5
  inspect(vm.scan_marker(2, Endif), content="15")
  // a missing marker runs to the end of the thread, which is what parks it.
  vm.threads[2].pc = 19
  inspect(vm.scan_marker(2, Endif), content="20")
}

///|
test "an auto-talk thread needs the switch, the contact rect and a confirm edge" {
  let vm = vm_new()
  to_the_map(vm)
  inspect(vm.world.sprite(0).unwrap().auto_talk, content="true")
  stand_right_of(vm, 0)
  vm.tick()
  // in contact but no key: the thread stays armed.
  inspect(vm.threads[2].state, content="-1")
  inspect(vm.talk_slot, content="-1")
  vm.press_key(key_confirm)
  vm.tick()
  inspect(vm.threads[2].state, content="3")
  inspect(vm.talk_slot, content="0")
  inspect(vm.ui.kind, content="1")
  inspect(vm.ui.portrait, content="1")
  inspect(vm.ui.body, content="33")
  inspect(vm.ui.name, content="25")
  inspect(vm.modal_owner, content="2")
  // the talking sprite turns to face the hero before the box opens: the hero is one
  // cell to the right, so the elder ends up facing right.
  inspect(vm.world.sprite(0).unwrap().dir, content="1")
}

///|
test "a sprite on another map cannot trigger even when its rect covers the hero" {
  let vm = vm_new()
  to_the_map(vm)
  // The village hero's spawn (176,208) sits inside the cave chief's contact rect
  // (144,192) because `bb()` @ d.java:12399 puts every map's placements in one flat
  // table in one coordinate space -- the same table `l(int n)` @ 2975 reads without
  // asking which map the pixels belong to.
  let chief = vm.world.sprite(6).unwrap()
  inspect(chief.map, content="2")
  inspect(vm.world.map, content="0")
  inspect(vm.world.in_contact(chief, false), content="true")
  inspect(vm.world.triggerable(chief), content="false")
  pump(vm, 4)
  inspect(vm.ui.active, content="false")
  inspect(vm.talk_slot, content="-1")
  inspect(vm.threads[9].state, content="-1")
}

///|
test "the elder branch: dialogue, choice, reward, key wait, battle, re-arm" {
  let vm = vm_new()
  to_the_map(vm)
  let key_row = vm.world.sprite(0).unwrap().reward_thing
  stand_right_of(vm, 0)
  vm.press_key(key_confirm)
  vm.tick()
  inspect(vm.ui.body, content="33")
  vm.close_overlay()
  vm.tick()
  inspect(vm.ui.portrait, content="0")
  inspect(vm.ui.body, content="34")
  vm.close_overlay()
  vm.tick()
  // DIALOG@2 then VAR@3 (met=1) then CHOICE@4 in one chain.
  inspect(vm.get_var(v_elder_met), content="1")
  inspect(vm.ui.kind, content="2")
  inspect(vm.ui.option_count, content="2")
  inspect(vm.ui.options[0], content="37")
  inspect(vm.ui.options[1], content="38")
  inspect(vm.ui.choice_var, content="2")
  vm.pick_option(0)
  inspect(vm.get_var(v_choice), content="0")
  vm.tick()
  // IF@5 holds, VAR@6 takes the key and GIVE@7 hands out the reward list; op40's
  // `bl = false` @ d.java:2637 ends the frame there, so MESSAGE@8 -- which the
  // reward is announced by -- opens one frame later.
  inspect(vm.get_var(v_key_taken), content="1")
  inspect(key_row, content="3")
  inspect(vm.item_count(key_row), content="1")
  inspect(vm.ui.active, content="false")
  vm.tick()
  inspect(vm.ui.kind, content="3")
  inspect(vm.ui.body, content="39")
  inspect(vm.ui.bold, content="true")
  vm.close_overlay()
  vm.tick()
  inspect(vm.ui.body, content="60")
  vm.close_overlay()
  vm.tick()
  // KEY_WAIT@10 on group 1 with no timeout: op71 clears bQ[24] on entry.
  inspect(vm.threads[2].state, content="4")
  inspect(vm.get_var(v_key_flag), content="0")
  inspect(vm.ui.active, content="false")
  vm.press_key(key_confirm)
  vm.tick()
  inspect(vm.get_var(v_key_flag), content="1")
  // ... and the chain ran on into BATTLE@11, which opens the arena.
  inspect(vm.ui.kind, content="5")
  inspect(vm.ui.battle_group, content="0")
  inspect(vm.modal_owner, content="2")
  let arena = vm.battle.unwrap()
  inspect(arena.unit_count(), content="5")
  inspect(arena.alive_count(side_enemy), content="2")
  vm.finish_battle(battle_win)
  inspect(vm.get_var(v_battle_result), content="0")
  // two wolves: 22 gold each, 14 exp each, so the leader crosses one level.
  inspect(vm.money_at(0), content="44")
  inspect(vm.party[0].level, content="2")
  inspect(vm.party[0].exp, content="28")
  // ELSE@12 skips the refusal branch, ELSE@16 skips the repeat branch, KILL@19
  // parks, and the bundle's mark 1 re-arms it for the next conversation.
  for i = 0; i < 4; i = i + 1 {
    vm.tick()
  }
  inspect(vm.threads[2].pc, content="0")
  inspect(vm.threads[2].state, content="-1")
}

///|
test "the repeat branch is what a met flag reads" {
  let vm = vm_new()
  to_the_map(vm)
  vm.set_var(v_elder_met, 1)
  stand_right_of(vm, 0)
  vm.press_key(key_confirm)
  vm.tick()
  // the outer IF@0 fails, the depth-0 ELSE is @16, so the tail lands on DIALOG@17.
  inspect(vm.ui.body, content="35")
  inspect(vm.modal_owner, content="2")
  vm.close_overlay()
  vm.tick()
  // ENDIF@18 then KILL@19; no key, no battle, no second reward.
  inspect(vm.threads[2].state, content="6")
  inspect(vm.get_var(v_key_taken), content="0")
}

///|
test "a false outer IF takes the ELSE branch" {
  let vm = vm_new()
  to_the_map(vm)
  // the chest is key-gated and bQ[3] is still 0.
  inspect(vm.get_var(v_key_taken), content="0")
  vm.world.set_auto_talk(5, true)
  let row = vm.world.sprite(5).unwrap().reward_thing
  stand_right_of(vm, 5)
  vm.press_key(key_confirm)
  vm.tick()
  inspect(vm.ui.body, content="45")
  inspect(vm.is_unlocked(0), content="false")
  inspect(vm.item_count(row), content="0")
  inspect(vm.get_var(v_chest_open), content="0")
}

///|
test "the chest with the key takes the true branch and consumes its reward" {
  let vm = vm_new()
  to_the_map(vm)
  vm.set_var(v_key_taken, 1)
  vm.world.set_auto_talk(5, true)
  let row = vm.world.sprite(5).unwrap().reward_thing
  stand_right_of(vm, 5)
  vm.press_key(key_confirm)
  vm.tick()
  // IF@0 holds; MESSAGE@1 opens first and the rest follows each overlay close.
  inspect(vm.ui.body, content="46")
  vm.close_overlay()
  vm.tick()
  // VAR@2 and GIVE@3 ran in this frame; op40's `bl = false` ends it, so the
  // MESSAGE@4 that names the reward is the next frame's work.
  inspect(vm.get_var(v_chest_open), content="1")
  inspect(vm.item_count(row), content="1")
  // op40 with db1 != 0 draws one weighted pair and consumes it.
  inspect(vm.world.sprite(5).unwrap().reward_count, content="0")
  inspect(vm.ui.active, content="false")
  vm.tick()
  inspect(vm.ui.body, content="47")
  vm.close_overlay()
  vm.tick()
  // UNLOCK@5 then SHOW@6: the flag is set and the chest stops re-triggering.
  inspect(vm.is_unlocked(0), content="true")
  inspect(vm.world.sprite(5).unwrap().auto_talk, content="false")
  inspect(vm.threads[5].state, content="0")
}

///|
test "a proximity thread opens the arena without a key and never re-arms" {
  let vm = vm_new()
  to_the_map(vm)
  stand_right_of(vm, 3)
  vm.tick()
  inspect(vm.ui.kind, content="5")
  inspect(vm.ui.battle_group, content="0")
  inspect(vm.threads[7].state, content="3")
  inspect(vm.modal_owner, content="7")
  vm.finish_battle(battle_win)
  vm.tick()
  // IF@1 holds: JOIN@2 with db1 != 0 removes the sprite, VAR@3 marks it, ELSE@4
  // jumps past ENDIF@6 and op15's `bl = false` @ d.java:2305 ends the frame.
  inspect(vm.world.sprite(3).unwrap().live, content="false")
  inspect(vm.get_var(v_wolf_down), content="1")
  inspect(vm.threads[7].state, content="0")
  vm.tick()
  // KILL@7 parks it, and a class-2 thread parks in the watch state instead...
  inspect(vm.threads[7].state, content="7")
  vm.world.place_hero(0, 1, 1)
  vm.tick()
  // ...and leaves it for good once the hero is off its rect.
  inspect(vm.threads[7].state, content="6")
  vm.tick()
  inspect(vm.threads[7].state, content="6")
}

///|
test "a lost touch encounter ends the game instead of the thread" {
  let vm = vm_new()
  to_the_map(vm)
  stand_right_of(vm, 3)
  vm.tick()
  vm.finish_battle(battle_loss)
  vm.tick()
  inspect(vm.get_var(v_battle_result), content="1")
  inspect(vm.ui.kind, content="6")
  inspect(vm.ui.active, content="true")
  inspect(vm.world.sprite(3).unwrap().live, content="true")
}

///|
test "op14 parks the chain on a countdown slot and op12 drives the pose" {
  let vm = vm_new()
  to_the_map(vm)
  stand_right_of(vm, 1)
  vm.press_key(key_confirm)
  vm.tick()
  inspect(vm.ui.body, content="41")
  vm.close_overlay()
  vm.tick()
  // DIALOG@0 then ANIM@1 (walking group, playing) then TIMER_WAIT@2 for 20 frames.
  inspect(vm.world.sprite(1).unwrap().anim_group, content="1")
  inspect(vm.world.sprite(1).unwrap().mode, content="1")
  inspect(vm.threads[3].state, content="1")
  inspect(vm.threads[3].wait_a, content="0")
  pump(vm, 19)
  inspect(vm.world.timer_expired(0), content="false")
  inspect(vm.threads[3].state, content="1")
  vm.tick()
  inspect(vm.threads[3].state, content="6")
  // ANIM@3 stops the walk, KILL@4 parks and mark 1 re-arms the guard.
  inspect(vm.world.sprite(1).unwrap().mode, content="0")
  drive(vm, 1)
  inspect(vm.threads[3].state, content="-1")
}

///|
test "op13 then op9: the slide finishes before the chain continues" {
  let vm = vm_new()
  to_the_map(vm)
  stand_right_of(vm, 2)
  vm.press_key(key_confirm)
  vm.tick()
  inspect(vm.ui.body, content="42")
  vm.close_overlay()
  vm.tick()
  // DIALOG@0, MONEY@1 (currency slot 3), MESSAGE@2.
  inspect(vm.money_at(3), content="1")
  inspect(vm.ui.body, content="43")
  vm.close_overlay()
  vm.tick()
  // WALK@3 slides left: 48px spread over 16 ticks, so 3px a frame.
  let x0 = vm.world.sprite(2).unwrap().x
  let child = vm.world.sprite(2).unwrap()
  inspect(child.mode, content="2")
  inspect(child.remaining, content="48")
  inspect(child.speed, content="3")
  for i = 0; i < 8; i = i + 1 {
    vm.tick()
  }
  inspect(vm.world.sprite(2).unwrap().x - x0, content="-24")
  // the chain only reaches op9 once the slide opcode's frame is over.
  inspect(vm.threads[4].state, content="2")
  inspect(vm.threads[4].wait_a, content="2")
  for i = 0; i < 8; i = i + 1 {
    vm.tick()
  }
  inspect(vm.world.sprite(2).unwrap().mode, content="0")
  inspect(vm.world.sprite(2).unwrap().x - x0, content="-48")
  // WAIT_SPRITE released, SHOW@5 cleared the switch, KILL@6 parked.
  inspect(vm.threads[4].state, content="6")
  inspect(vm.world.sprite(2).unwrap().auto_talk, content="false")
}

///|
test "op38 reads a stat and a false branch skips the heal" {
  let vm = vm_new()
  to_the_map(vm)
  inspect(vm.party_stat(0, c_hp), content="46")
  vm.world.set_auto_talk(7, true)
  stand_right_of(vm, 7)
  vm.press_key(key_confirm)
  vm.tick()
  inspect(vm.get_var(v_hp), content="46")
  // 46 is not below 30: the outer IF@1 jumps to its depth-0 ELSE@7, so the tail
  // lands on the plain MESSAGE@8 and the nested IF@2 never ran.
  inspect(vm.ui.kind, content="3")
  inspect(vm.ui.body, content="44")
  inspect(vm.ui.bold, content="false")
}

///|
test "the mirror heals a wounded hero through the nested branch" {
  let vm = vm_new()
  to_the_map(vm)
  vm.set_var(v_elder_met, 1)
  vm.party[0].hp = 10
  vm.world.set_auto_talk(7, true)
  stand_right_of(vm, 7)
  vm.press_key(key_confirm)
  vm.tick()
  inspect(vm.get_var(v_hp), content="10")
  inspect(vm.ui.body, content="44")
  inspect(vm.ui.bold, content="true")
  vm.close_overlay()
  vm.tick()
  // ENDIF@4 then DIALOG@5.
  inspect(vm.ui.kind, content="1")
  inspect(vm.ui.body, content="55")
  vm.close_overlay()
  vm.tick()
  // RESTORE@6 brings the standing members back to full.
  inspect(vm.party_stat(0, c_hp), content="46")
}

///|
test "every opcode the content emits has a dispatch arm" {
  let vm = vm_new()
  to_the_map(vm)
  for slot = 0; slot < 8; slot = slot + 1 {
    vm.world.set_auto_talk(slot, true)
    stand_right_of(vm, slot)
    drive(vm, 8)
  }
  inspect(vm.unknown_opcodes, content="0")
  inspect(vm.frame, content="67")
}
