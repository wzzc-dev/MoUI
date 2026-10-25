// Loading the self-authored cartridge: one `.pak` whose entries are addressed
// by index, exactly like the original engine's `data.pak`.  The index order is
// authored by `tools/marpg/gen_content.py` (`ENTRIES`), and `cartridge_entries`
// carries the matching names so a reordered generator fails the drift guard
// instead of silently mis-decoding a map as a table.

///|
/// Entry indexes, in the order the generator packs them.
pub enum Entry {
  Village
  Wildpath
  Cave
  Combatant
  Skill
  Item
  Group
  Place
  Warp
  Strings
  Scripts
  Anim
} derive(Eq, @debug.Debug)

///|
pub fn Entry::index(self : Entry) -> Int32 {
  match self {
    Village => 0
    Wildpath => 1
    Cave => 2
    Combatant => 3
    Skill => 4
    Item => 5
    Group => 6
    Place => 7
    Warp => 8
    Strings => 9
    Scripts => 10
    Anim => 11
  }
}

///|
/// Every container the slice needs, already decoded.  The engine holds these in
/// static arrays after one startup pass (`bF`/`fY`/`a.d[]` on the original side),
/// so decoding happens once and the rest of the app works on typed handles.
pub struct Cartridge {
  maps : Array[GameMap]
  combatant : NumTable
  skill : NumTable
  item : NumTable
  group : NumTable
  place : NumTable
  warp : NumTable
  scripts : ScriptSet
  anims : Array[AnimRecord]
}

///|
pub fn Cartridge::anim(self : Cartridge, id : Int32) -> AnimRecord? {
  let mut found : AnimRecord? = None
  for record in self.anims {
    if record.id == id {
      found = Some(record)
      break
    }
  }
  found
}

///|
pub fn load_cartridge() -> Cartridge raise FormatError {
  let packed = decode_base64(CARTRIDGE_B64)
  let entries = pak_unpack(packed)
  if entries.length() != cartridge_entries.length() {
    raise BadShape(
      "cartridge holds " +
      entries.length().to_string() +
      " entries, table lists " +
      cartridge_entries.length().to_string(),
    )
  }
  let village = map_decode(entries[Entry::Village.index()])
  let wildpath = map_decode(entries[Entry::Wildpath.index()])
  let cave = map_decode(entries[Entry::Cave.index()])
  let combatant = table_decode(entries[Entry::Combatant.index()])
  let skill = table_decode(entries[Entry::Skill.index()])
  let item = table_decode(entries[Entry::Item.index()])
  let group = table_decode(entries[Entry::Group.index()])
  let place = table_decode(entries[Entry::Place.index()])
  let warp = table_decode(entries[Entry::Warp.index()])
  strings_verify(entries[Entry::Strings.index()], string_pool)
  let scripts = script_decode(entries[Entry::Scripts.index()], opcode_arity)
  let anims = anim_decode(entries[Entry::Anim.index()])
  {
    maps: [village, wildpath, cave],
    combatant,
    skill,
    item,
    group,
    place,
    warp,
    scripts,
    anims,
  }
}
