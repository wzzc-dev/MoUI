///|
pub(all) enum FileImportAvailability {
  Available
  Unavailable(String)
  Pending
} derive(Eq, Debug)

///|
pub fn FileImportAvailability::to_string(
  self : FileImportAvailability,
) -> String {
  match self {
    Available => "available"
    Unavailable(_) => "unavailable"
    Pending => "pending"
  }
}

///|
pub struct FileSelection {
  paths : Array[String]
}

///|
pub fn FileSelection::new(paths~ : Array[String]) -> FileSelection {
  { paths, }
}

///|
fn FileSelection::is_empty(self : FileSelection) -> Bool {
  self.paths.is_empty()
}

///|
fn FileSelection::summary(
  self : FileSelection,
  empty? : String = "No files selected",
) -> String {
  if self.paths.is_empty() {
    empty
  } else if self.paths.length() == 1 {
    self.paths[0]
  } else {
    "\{self.paths.length()} files selected"
  }
}
