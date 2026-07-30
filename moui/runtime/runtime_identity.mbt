///|
pub(all) struct ElementId {
  value : Int
} derive(Eq, Debug)

///|
fn ElementId::new(value : Int) -> ElementId {
  { value, }
}

///|
fn ElementId::value(self : ElementId) -> Int {
  self.value
}

///|
impl ToJson for ElementId with fn to_json(self) {
  self.value.to_json()
}

///|
priv struct DirtyFlags {
  mut needs_build : Bool
  mut needs_layout : Bool
  mut needs_paint : Bool
  mut needs_semantics : Bool
  mut needs_platform : Bool
  mut descendant_build : Bool
  mut descendant_layout : Bool
  mut descendant_paint : Bool
  mut descendant_semantics : Bool
  mut descendant_platform : Bool
}

///|
fn DirtyFlags::all() -> DirtyFlags {
  {
    // Mount eagerly materializes component children, so no build work remains.
    needs_build: false,
    needs_layout: true,
    needs_paint: true,
    needs_semantics: true,
    needs_platform: true,
    descendant_build: false,
    descendant_layout: false,
    descendant_paint: false,
    descendant_semantics: false,
    descendant_platform: false,
  }
}

///|
fn DirtyFlags::mark_build(self : DirtyFlags) -> Unit {
  self.needs_build = true
  self.needs_layout = true
  self.needs_paint = true
  self.needs_semantics = true
  self.needs_platform = true
}

///|
fn DirtyFlags::mark_build_only(self : DirtyFlags) -> Unit {
  self.needs_build = true
}

///|
fn DirtyFlags::mark_layout(self : DirtyFlags) -> Unit {
  self.needs_layout = true
  self.needs_paint = true
  self.needs_semantics = true
  self.needs_platform = true
}

///|
fn DirtyFlags::mark_paint(self : DirtyFlags) -> Unit {
  self.needs_paint = true
}

///|
fn DirtyFlags::mark_semantics(self : DirtyFlags) -> Unit {
  self.needs_semantics = true
}

///|
fn DirtyFlags::mark_platform(self : DirtyFlags) -> Unit {
  self.needs_platform = true
}

///|
fn DirtyFlags::mark_build_descendant(self : DirtyFlags) -> Unit {
  self.descendant_build = true
}

///|
fn DirtyFlags::mark_layout_descendant(self : DirtyFlags) -> Unit {
  self.descendant_layout = true
  self.descendant_paint = true
  self.descendant_semantics = true
  self.descendant_platform = true
}

///|
fn DirtyFlags::mark_paint_descendant(self : DirtyFlags) -> Unit {
  self.descendant_paint = true
}

///|
fn DirtyFlags::mark_semantics_descendant(self : DirtyFlags) -> Unit {
  self.descendant_semantics = true
}

///|
fn DirtyFlags::mark_platform_descendant(self : DirtyFlags) -> Unit {
  self.descendant_platform = true
}

///|
fn DirtyFlags::has_build(self : DirtyFlags) -> Bool {
  self.needs_build || self.descendant_build
}

///|
fn DirtyFlags::has_layout(self : DirtyFlags) -> Bool {
  self.needs_layout || self.descendant_layout
}

///|
fn DirtyFlags::has_paint(self : DirtyFlags) -> Bool {
  self.needs_paint || self.descendant_paint
}

///|
fn DirtyFlags::has_semantics(self : DirtyFlags) -> Bool {
  self.needs_semantics || self.descendant_semantics
}

///|
fn DirtyFlags::has_platform(self : DirtyFlags) -> Bool {
  self.needs_platform || self.descendant_platform
}

///|
