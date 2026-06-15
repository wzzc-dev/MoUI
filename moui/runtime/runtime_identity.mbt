///|
priv struct Key {
  value : String
} derive(Eq)

///|
priv struct DirtyFlags {
  mut needs_build : Bool
  mut needs_layout : Bool
  mut needs_paint : Bool
}

///|
fn Key::new(value : String) -> Key {
  { value, }
}

///|
fn DirtyFlags::all() -> DirtyFlags {
  { needs_build: true, needs_layout: true, needs_paint: true }
}

///|
fn DirtyFlags::mark_build(self : DirtyFlags) -> Unit {
  self.needs_build = true
  self.needs_layout = true
  self.needs_paint = true
}

///|
fn DirtyFlags::mark_layout(self : DirtyFlags) -> Unit {
  self.needs_layout = true
  self.needs_paint = true
}

///|
fn DirtyFlags::mark_paint(self : DirtyFlags) -> Unit {
  self.needs_paint = true
}

///|
fn DirtyFlags::clear(self : DirtyFlags) -> Unit {
  self.needs_build = false
  self.needs_layout = false
  self.needs_paint = false
}
