// Callback table and the registration surface of `Sketch`. Split out of
// sketch.mbt so the lifecycle/state half stays inside the source-file policy
// logic budget; both files share the package scope.

///|
/// Callbacks installed by the app. Each receives the sketch.
priv struct SketchCallbacks {
  mut setup : (Sketch) -> Unit
  mut draw : (Sketch) -> Unit
  mut mouse_pressed : (Sketch) -> Unit
  mut mouse_released : (Sketch) -> Unit
  mut mouse_clicked : (Sketch) -> Unit
  mut double_clicked : (Sketch) -> Unit
  mut mouse_moved : (Sketch) -> Unit
  mut mouse_dragged : (Sketch) -> Unit
  mut mouse_wheel : (Sketch, Double) -> Unit
  mut key_pressed : (Sketch) -> Unit
  mut key_released : (Sketch) -> Unit
  mut key_typed : (Sketch) -> Unit
  mut touch_started : (Sketch) -> Unit
  mut touch_moved : (Sketch) -> Unit
  mut touch_ended : (Sketch) -> Unit
  mut text_input : (Sketch, String) -> Unit
  mut composition_start : (Sketch) -> Unit
  mut composition_update : (Sketch, String) -> Unit
  mut composition_end : (Sketch, String) -> Unit
}

///|
fn no_setup(_ : Sketch) -> Unit {

}

///|
fn no_draw(_ : Sketch) -> Unit {

}

///|
/// Installs the `setup` callback (run once before the first draw).
pub fn Sketch::setup(self : Sketch, callback : (Sketch) -> Unit) -> Unit {
  self.callbacks.setup = callback
}

///|
/// Installs the `draw` callback (run once per frame).
pub fn Sketch::draw(self : Sketch, callback : (Sketch) -> Unit) -> Unit {
  self.callbacks.draw = callback
}

///|
pub fn Sketch::on_mouse_pressed(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.mouse_pressed = callback
}

///|
pub fn Sketch::on_mouse_released(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.mouse_released = callback
}

///|
pub fn Sketch::on_mouse_clicked(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.mouse_clicked = callback
}

///|
pub fn Sketch::on_double_clicked(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.double_clicked = callback
}

///|
pub fn Sketch::on_mouse_moved(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.mouse_moved = callback
}

///|
pub fn Sketch::on_mouse_dragged(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.mouse_dragged = callback
}

///|
pub fn Sketch::on_mouse_wheel(
  self : Sketch,
  callback : (Sketch, Double) -> Unit,
) -> Unit {
  self.callbacks.mouse_wheel = callback
}

///|
pub fn Sketch::on_key_pressed(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.key_pressed = callback
}

///|
pub fn Sketch::on_key_released(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.key_released = callback
}

///|
pub fn Sketch::on_key_typed(self : Sketch, callback : (Sketch) -> Unit) -> Unit {
  self.callbacks.key_typed = callback
}

///|
pub fn Sketch::on_touch_started(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.touch_started = callback
}

///|
pub fn Sketch::on_touch_moved(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.touch_moved = callback
}

///|
pub fn Sketch::on_touch_ended(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.touch_ended = callback
}

///|
/// Called for committed text input (`InsertText`/`ReplaceText`), with the
/// inserted text. The sketch is not required to be composing.
pub fn Sketch::on_text_input(
  self : Sketch,
  callback : (Sketch, String) -> Unit,
) -> Unit {
  self.callbacks.text_input = callback
}

///|
pub fn Sketch::on_composition_start(
  self : Sketch,
  callback : (Sketch) -> Unit,
) -> Unit {
  self.callbacks.composition_start = callback
}

///|
pub fn Sketch::on_composition_update(
  self : Sketch,
  callback : (Sketch, String) -> Unit,
) -> Unit {
  self.callbacks.composition_update = callback
}

///|
pub fn Sketch::on_composition_end(
  self : Sketch,
  callback : (Sketch, String) -> Unit,
) -> Unit {
  self.callbacks.composition_end = callback
}
