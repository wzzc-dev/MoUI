///|
/// 一次呈现所需的最小脏信息:整屏重建,或按行增量。
/// `rows` 升序去重;由 `TermScreen::take_damage` 产出并随即清零。
pub(all) struct Damage {
  full : Bool
  rows : Array[Int32]
} derive(Eq, Debug)

///|
pub extend Damage with Debug::{to_repr}

///|
pub extend Damage with Eq::{not_equal, equal}

///|
pub fn Damage::is_empty(self : Damage) -> Bool {
  !self.full && self.rows.is_empty()
}
