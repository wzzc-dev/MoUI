// Turn-based battle.  Every formula here was re-read from `decompiled/d.java`
// (line references in the comments); the numbers it computes with come from the
// self-authored `tbl_combatant`/`tbl_skill` rows, so the arithmetic shape is the
// original's and the values are not.

///|
/// Sides, in the order `Battle::units` holds them: the party first, then the
/// group's monsters.
pub let side_party : Int32 = 0

///|
pub let side_enemy : Int32 = 1

///|
/// `eA = Math.max(spd) * 20` @ d.java:5812-5814 -- the ATB threshold.
pub let atb_multiplier : Int32 = 20

///|
/// `bQ[V_BATTLE_RESULT]` values as this slice's scripts read them: 0 means the
/// party is still standing.  (The original's `d.eD[3]` polarity is the reverse --
/// 1 on victory @ d.java:6019, 0 on flee @6129 -- and the scripts never read it
/// directly; the script-visible convention is the slice's own.)
pub let battle_win : Int32 = 0

///|
pub let battle_loss : Int32 = 1

///|
/// `tbl_combatant` columns, which are also the stat indexes op38 addresses
/// (`bQ[db2] = t(db0).aH[db1]` @ d.java:2609).
pub let c_id : Int32 = 0

///|
pub let c_name : Int32 = 1

///|
pub let c_hp : Int32 = 2

///|
pub let c_mp : Int32 = 3

///|
pub let c_atk : Int32 = 4

///|
pub let c_def : Int32 = 5

///|
pub let c_spd : Int32 = 6

///|
pub let c_agl : Int32 = 7

///|
pub let c_exp : Int32 = 8

///|
pub let c_gold : Int32 = 9

///|
/// The slice's own two columns: which sheet and which animation record draw this
/// combatant in the arena.  The original kept sprites in a separate table; here the
/// combatant row carries it so the arena needs no second index.
pub let c_sheet : Int32 = 10

///|
pub let c_anim : Int32 = 11

///|
/// `tbl_item` columns (`id, name, kind, potency`) and the four kinds the slice's
/// items carry.
pub let i_kind : Int32 = 2

///|
pub let i_potency : Int32 = 3

///|
pub let item_hp : Int32 = 0

///|
pub let item_mp : Int32 = 1

///|
pub let item_revive : Int32 = 2

///|
pub let item_key : Int32 = 3

///|
/// `tbl_skill` columns.
pub let s_mp : Int32 = 2

///|
pub let s_power : Int32 = 3

///|
pub let s_target : Int32 = 4

///|
pub let s_crit : Int32 = 5

///|
pub let s_kind : Int32 = 6

///|
pub let skill_hit : Int32 = 0

///|
pub let skill_heal : Int32 = 1

///|
pub let skill_revive : Int32 = 2

///|
/// The level cap and the experience needed to leave a level.  The original read
/// both from the class table (`cA[n][4] - 1`, `cC[n][n2][1]` @ d.java:4200-4216);
/// the slice has one progression curve because it has one party.
pub let level_cap : Int32 = 10

///|
pub fn exp_needed(level : Int32) -> Int32 {
  level * level * 20
}

///|
/// One combatant.  `aH[]` equivalents: hp 4, mp 5, hp max 7, mp max 8, atk 9,
/// def 11, agl 13, spd 14, level 17, exp 1.
pub struct Fighter {
  row : Int32
  side : Int32
  mut hp : Int32
  mut hp_max : Int32
  mut mp : Int32
  mut mp_max : Int32
  mut atk : Int32
  mut def : Int32
  mut spd : Int32
  mut agl : Int32
  mut level : Int32
  mut exp : Int32
  mut exp_next : Int32
  /// `aH[30]`, the ATB accumulator.
  mut gauge : Int32
} derive(Eq, @debug.Debug)

///|
pub fn Fighter::from_row(
  cart : Cartridge,
  row : Int32,
  side : Int32,
) -> Fighter {
  let table = cart.combatant
  {
    row,
    side,
    hp: table.cell(row, c_hp),
    hp_max: table.cell(row, c_hp),
    mp: table.cell(row, c_mp),
    mp_max: table.cell(row, c_mp),
    atk: table.cell(row, c_atk),
    def: table.cell(row, c_def),
    spd: table.cell(row, c_spd),
    agl: table.cell(row, c_agl),
    level: 1,
    exp: 0,
    exp_next: exp_needed(1),
    gauge: 0,
  }
}

///|
/// `Math.max(aH[4], 0)` -- a fighter is dead at 0 hp and nothing clamps damage to
/// leave it standing (@ d.java:7176).
pub fn Fighter::is_alive(self : Fighter) -> Bool {
  self.hp > 0
}

///|
/// op46 `a(false)` @ d.java:4265: a fighter that is already down stays down; the
/// rest come back to full hp/mp.
pub fn Fighter::restore(self : Fighter) -> Unit {
  if self.is_alive() {
    self.hp = self.hp_max
    self.mp = self.mp_max
  }
}

///|
/// The stat array op38 indexes.  Columns 8/9 (exp, gold) belong to the monster's
/// own row and are read at settlement, so they are not exposed as stats here.
pub fn Fighter::stat(self : Fighter, column : Int32) -> Int32 {
  if column == c_hp {
    self.hp
  } else if column == c_mp {
    self.mp
  } else if column == c_atk {
    self.atk
  } else if column == c_def {
    self.def
  } else if column == c_spd {
    self.spd
  } else if column == c_agl {
    self.agl
  } else if column == c_name {
    self.row
  } else {
    0
  }
}

///|
/// One arena.  `party` is shared by reference with `Vm`'s roster, so damage and
/// level-ups written here are what the map and the save see afterwards.
pub struct Battle {
  cart : Cartridge
  rng : Rng
  party_size : Int32
  units : Array[Fighter]
  mut over : Bool
  mut result : Int32
  /// Loot handed to the party when the arena closes (`cB[..][3]`/`[5]` sums @
  /// d.java:6478-6493 and @6531-6562).
  mut gold : Int32
  mut exp_total : Int32
  mut rounds : Int32
}

///|
/// op21 `k(3int)` @ d.java:5873 starts the arena from a `tbl_group` row; the two
/// flag operands are kept on `Ui` untouched because their meaning in the original
/// (written to `eD[0]`/`eD[1]`) is not established.
pub fn Battle::begin(
  cart : Cartridge,
  rng : Rng,
  group : Int32,
  party : Array[Fighter],
) -> Battle {
  let units : Array[Fighter] = []
  for fighter in party {
    units.push(fighter)
  }
  let count = cart.group.cell(group, 5)
  for i = 0; i < count; i = i + 1 {
    let column = if i == 0 { 2 } else if i == 1 { 3 } else { 4 }
    let row = cart.group.cell(group, column)
    if row >= 0 {
      units.push(Fighter::from_row(cart, row, side_enemy))
    }
  }
  {
    cart,
    rng,
    party_size: party.length(),
    units,
    over: false,
    result: battle_win,
    gold: 0,
    exp_total: 0,
    rounds: 0,
  }
}

///|
pub fn Battle::unit(self : Battle, index : Int32) -> Fighter {
  self.units[index]
}

///|
pub fn Battle::unit_count(self : Battle) -> Int32 {
  self.units.length()
}

///|
pub fn Battle::side(self : Battle, index : Int32) -> Int32 {
  if index < self.party_size {
    side_party
  } else {
    side_enemy
  }
}

///|
pub fn Battle::alive_count(self : Battle, side : Int32) -> Int32 {
  let mut total = 0
  for i = 0; i < self.units.length(); i = i + 1 {
    let unit = self.units[i]
    if unit.side == side && unit.is_alive() {
      total = total + 1
    }
  }
  total
}

///|
/// Indices of the living units on one side.
pub fn Battle::alive_of(self : Battle, side : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  for i = 0; i < self.units.length(); i = i + 1 {
    let unit = self.units[i]
    if unit.side == side && unit.is_alive() {
      out.push(i)
    }
  }
  out
}

///|
/// `eA` @ d.java:5812: the threshold is the fastest combatant's speed times 20.
fn Battle::threshold(self : Battle) -> Int32 {
  let mut fastest = 1
  for unit in self.units {
    if unit.is_alive() && unit.spd > fastest {
      fastest = unit.spd
    }
  }
  fastest * atb_multiplier
}

///|
/// `aH[30] += aH[14]` per tick, actor = whoever first reaches `eA` @
/// d.java:5795-5796.  The slice resolves the same queue without simulating every
/// tick: advance the gauges by the fewest ticks any living unit still needs, then
/// hand the turn to that unit and zero its gauge.  (Where exactly the original
/// clears `aH[30]` is not established; zeroing the actor is the accumulator's
/// only self-consistent choice.)
pub fn Battle::next_actor(self : Battle) -> Int32 {
  let limit = self.threshold()
  let mut wait = -1
  let mut chosen = -1
  for i = 0; i < self.units.length(); i = i + 1 {
    let unit = self.units[i]
    if unit.is_alive() {
      let speed = if unit.spd < 1 { 1 } else { unit.spd }
      let need = if unit.gauge >= limit {
        0
      } else {
        (limit - unit.gauge + speed - 1).div(speed)
      }
      if wait < 0 || need < wait {
        wait = need
        chosen = i
      }
    }
  }
  if wait > 0 {
    for unit in self.units {
      if unit.is_alive() {
        unit.gauge = unit.gauge + unit.spd * wait
      }
    }
  }
  if chosen >= 0 {
    self.units[chosen].gauge = 0
    if self.units[chosen].side == side_party {
      self.rounds = self.rounds + 1
    }
  }
  chosen
}

///|
/// `d.b` mode 1 @ d.java:11893: `mp = min(mp + flat, mp_max)`.
fn restore_mp(target : Fighter, amount : Int32) -> Unit {
  let up = target.mp + amount
  target.mp = if up > target.mp_max { target.mp_max } else { up }
}

///|
/// An item used from the arena.  The answer is whether the item took effect, so
/// the caller can spend it only on `true`: a key item, a healing herb on a corpse
/// and a revival pill on the living are all refused without being consumed.
pub fn Battle::use_item(
  self : Battle,
  actor : Int32,
  row : Int32,
  target : Int32,
) -> Bool {
  let count = self.units.length()
  if actor < 0 || target < 0 || actor >= count || target >= count {
    false
  } else {
    let unit = self.units[actor]
    let other = self.units[target]
    let kind = self.cart.item.cell(row, i_kind)
    let power = self.cart.item.cell(row, i_potency)
    if !unit.is_alive() || kind == item_key || power <= 0 {
      false
    } else if kind == item_revive {
      if other.is_alive() {
        false
      } else {
        revive_target(other, power)
        self.check_end()
        true
      }
    } else if !other.is_alive() {
      false
    } else if kind == item_mp {
      restore_mp(other, power)
      true
    } else {
      heal_target(other, power)
      true
    }
  }
}

///|
/// `d.j`/`d.k` @ d.java:7113-7176, the whole damage pipeline in one place:
/// mitigation `raw * 200 / (200 + def)`, dodge roll against `min(99, agl)`,
/// variance `c(90, 110)`, crit `roll < min(99, chance)` tripling it, then
/// `damage * n6 / 200` and `hp = max(0, hp - damage)`.
///
/// The original's crit roll reads `aH[12]` (luck); `tbl_combatant` has no luck
/// column, so the slice uses half of agility as the base crit chance.
fn Battle::strike(
  self : Battle,
  attacker : Fighter,
  target : Fighter,
  raw : Int32,
  crit : Int32,
) -> Unit {
  let mitigated = raw * 200 / (200 + target.def)
  let dodge_limit = if target.agl > 99 { 99 } else { target.agl }
  if self.rng.range(0, 100) < dodge_limit {
    target.hp = if target.hp > 0 { target.hp } else { 0 }
  } else {
    let crit_limit = attacker.agl.div(2) + crit
    let capped = if crit_limit > 99 { 99 } else { crit_limit }
    let factor = if self.rng.range(0, 100) < capped { 3 } else { 2 }
    let spread = self.rng.range(90, 110) * factor
    let damage = mitigated * spread / 200
    let left = target.hp - damage
    target.hp = if left < 0 { 0 } else { left }
  }
}

///|
/// `d.b` mode 2 @ d.java:11901: `hp = max(0, min(hp + flat + pct * hp_max / 100))`.
/// The slice's skills carry a flat amount only.
fn heal_target(target : Fighter, amount : Int32) -> Unit {
  let up = target.hp + amount
  target.hp = if up > target.hp_max { target.hp_max } else { up }
}

///|
/// Revive (`kind == 2`): the original raises the corpse to a fraction of its max
/// hp; the slice uses the skill's power directly.
fn revive_target(target : Fighter, amount : Int32) -> Unit {
  if !target.is_alive() {
    let up = if amount > target.hp_max { target.hp_max } else { amount }
    target.hp = up
  }
}

///|
/// `cE[eR][2]` check @ d.java:7349-7368 and the deduction @6407: a skill the actor
/// cannot afford is refused rather than partially paid.
pub fn Battle::use_skill(
  self : Battle,
  actor : Int32,
  skill : Int32,
  target : Int32,
) -> Bool {
  let table = self.cart.skill
  let cost = table.cell(skill, s_mp)
  let unit = self.units[actor]
  if actor < 0 || target < 0 || !unit.is_alive() || unit.mp < cost {
    false
  } else {
    unit.mp = unit.mp - cost
    let kind = table.cell(skill, s_kind)
    let power = table.cell(skill, s_power)
    let other = self.units[target]
    if kind == skill_heal {
      heal_target(other, power)
    } else if kind == skill_revive {
      revive_target(other, power)
    } else {
      self.strike(unit, other, power, table.cell(skill, s_crit))
    }
    self.check_end()
    true
  }
}

///|
/// The basic attack is the same pipeline with the attacker's atk as the raw value
/// and a 100 percent multiplier (@ d.java:11868, `aH[22] = fs[6] * n / 100` with
/// `n = 100`).
pub fn Battle::basic_attack(
  self : Battle,
  actor : Int32,
  target : Int32,
) -> Bool {
  let unit = self.units[actor]
  if actor < 0 || target < 0 || !unit.is_alive() {
    false
  } else {
    self.strike(unit, self.units[target], unit.atk, 0)
    self.check_end()
    true
  }
}

///|
/// The monsters in this content have no skill list, so the enemy turn is always a
/// basic attack on a living party member drawn from `c(0, n)` -- the same uniform
/// pick the original's target selector makes for `target == 0`.
pub fn Battle::enemy_step(self : Battle, actor : Int32) -> Unit {
  let targets = self.alive_of(side_party)
  if targets.length() > 0 {
    let pick = self.rng.range(0, targets.length())
    let index = if pick < 0 || pick >= targets.length() { 0 } else { pick }
    let unit = self.units[actor]
    self.strike(unit, self.units[targets[index]], unit.atk, 0)
    self.check_end()
  }
}

///|
pub fn Battle::check_end(self : Battle) -> Unit {
  if self.over {
    ()
  } else if self.alive_count(side_enemy) == 0 {
    self.over = true
    self.result = battle_win
    self.count_loot()
  } else if self.alive_count(side_party) == 0 {
    self.over = true
    self.result = battle_loss
  }
}

///|
/// `d.h(c)` @ d.java:6531-6562 and the gold pass @6478-6493: each living fighter
/// receives the full sum of the monsters' exp/gold columns (the original's
/// over-level damping and `bQ[0]`/`bQ[1]` multipliers are 1 here).
fn Battle::count_loot(self : Battle) -> Unit {
  let table = self.cart.combatant
  for unit in self.units {
    if unit.side == side_enemy {
      self.exp_total = self.exp_total + table.cell(unit.row, c_exp)
      self.gold = self.gold + table.cell(unit.row, c_gold)
    }
  }
}

///|
/// The end-of-battle pass the driver owns (`d.h(c)` @ d.java:6531 plus the gold
/// pass @ 6478), exposed for the hand-back: the view reports the result, the arena
/// marks itself over and counts the loot exactly once.  `check_end` has usually
/// already done that when the last monster fell, so a result handed over afterwards
/// cannot double-count it.
pub fn Battle::report(self : Battle, result : Int32) -> Unit {
  if self.over {
    ()
  } else {
    self.over = true
    self.result = result
    if result == battle_win {
      self.count_loot()
    }
  }
}

///|
/// `d.b(n, n2, false)` @ d.java:4200-4216: add the experience, then while it
/// reaches the threshold and the cap is not hit, raise the level, rebuild the
/// stats and top hp/mp back up.
pub fn Battle::settle(self : Battle) -> Unit {
  if self.result != battle_win {
    ()
  } else {
    for index in self.alive_of(side_party) {
      let unit = self.units[index]
      unit.exp = unit.exp + self.exp_total
      let mut hops = 0
      while unit.exp >= unit.exp_next && unit.level < level_cap && hops < 64 {
        unit.level = unit.level + 1
        unit.exp_next = exp_needed(unit.level)
        unit.hp_max = unit.hp_max + 8
        unit.mp_max = unit.mp_max + 4
        unit.atk = unit.atk + 2
        unit.def = unit.def + 2
        unit.spd = unit.spd + 1
        unit.agl = unit.agl + 1
        unit.hp = unit.hp_max
        unit.mp = unit.mp_max
        hops = hops + 1
      }
    }
  }
}
