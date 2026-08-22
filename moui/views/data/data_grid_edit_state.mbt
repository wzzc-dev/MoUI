///|
pub struct DataGridEditCommit {
  cell : DataGridCell
  value : String
} derive(Eq, Debug, ToJson)

///|
pub struct DataGridEditState {
  active : DataGridCell?
  original : String
  draft : String
} derive(Eq, Debug, ToJson)

///|
pub fn DataGridEditState::idle() -> DataGridEditState {
  { active: None, original: "", draft: "" }
}

///|
pub fn DataGridEditState::begin(
  _self : DataGridEditState,
  cell : DataGridCell,
  value : String,
) -> DataGridEditState {
  { active: Some(cell), original: value, draft: value }
}

///|
pub fn DataGridEditState::update(
  self : DataGridEditState,
  draft : String,
) -> DataGridEditState {
  if self.active is Some(_) {
    { ..self, draft, }
  } else {
    self
  }
}

///|
pub fn DataGridEditState::cancel(
  _self : DataGridEditState,
) -> DataGridEditState {
  DataGridEditState::idle()
}

///|
pub fn DataGridEditState::active_cell(
  self : DataGridEditState,
) -> DataGridCell? {
  self.active
}

///|
pub fn DataGridEditState::draft(self : DataGridEditState) -> String {
  self.draft
}

///|
pub fn DataGridEditState::is_dirty(self : DataGridEditState) -> Bool {
  self.active is Some(_) && self.draft != self.original
}

///|
pub fn DataGridEditState::commit(
  self : DataGridEditState,
) -> DataGridEditCommit? {
  match self.active {
    Some(cell) => Some({ cell, value: self.draft })
    None => None
  }
}

///|
pub fn DataGridEditCommit::cell(self : DataGridEditCommit) -> DataGridCell {
  self.cell
}

///|
pub fn DataGridEditCommit::value(self : DataGridEditCommit) -> String {
  self.value
}
