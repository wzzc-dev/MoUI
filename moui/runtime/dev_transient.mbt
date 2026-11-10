// Dev-only transient handoff for the restart-based `moui dev` loop (ADR 0068).
//
// The payload is line-oriented so the runtime does not need a JSON dependency.
// Slot entries are opaque `ViewStateSlots` key/value bytes keyed by a stable
// element path; focus and focused text-input selection/composition travel as
// explicit fields. Restoration writes runtime fields directly and never
// dispatches `on_scroll` / `on_change`.

///|
const DEV_TRANSIENT_SCHEMA : String = "moui-dev-transient-v1"

///|
const DEV_TRANSIENT_SAVE_INTERVAL_MS : Double = 500.0

///|
priv struct DevTransientSlot {
  path : String
  key : Bytes
  value : Bytes
}

///|
priv struct DevTransientText {
  path : String
  caret : Int32
  selection : @core.TextRange?
  composition : String?
  composition_cursor : @core.TextRange?
}

///|
priv struct DevTransientSnapshot {
  focus_path : String?
  text : DevTransientText?
  slots : Array[DevTransientSlot]
}

///|
fn dev_hex_digit(value : Int32) -> Char {
  if value < 10 {
    (48 + value).unsafe_to_char()
  } else {
    (87 + value).unsafe_to_char()
  }
}

///|
fn dev_hex_encode(bytes : Bytes) -> String {
  let builder = StringBuilder()
  for byte in bytes {
    let value = byte.to_int()
    builder.write_char(dev_hex_digit(value / 16))
    builder.write_char(dev_hex_digit(value % 16))
  }
  builder.to_string()
}

///|
fn dev_hex_value(unit : UInt16) -> Int32? {
  let value = unit.to_int()
  if value >= 48 && value <= 57 {
    Some(value - 48)
  } else if value >= 97 && value <= 102 {
    Some(value - 87)
  } else if value >= 65 && value <= 70 {
    Some(value - 55)
  } else {
    None
  }
}

///|
fn dev_hex_decode(text : String) -> Bytes? {
  if text.length() % 2 != 0 {
    return None
  }
  let output = Buffer(size_hint=text.length() / 2)
  let mut index = 0
  while index < text.length() {
    let high = match dev_hex_value(text[index]) {
      Some(value) => value
      None => return None
    }
    let low = match dev_hex_value(text[index + 1]) {
      Some(value) => value
      None => return None
    }
    output.write_byte((high * 16 + low).to_byte())
    index += 2
  }
  Some(output.to_bytes())
}

///|
fn dev_parse_int(text : String) -> Int32? {
  if text == "" {
    return None
  }
  let negative = text[0].to_int() == '-'.to_int()
  let start = if negative { 1 } else { 0 }
  if start >= text.length() {
    return None
  }
  let mut value = 0
  for index in start..<text.length() {
    let unit = text[index].to_int()
    if unit < 48 || unit > 57 {
      return None
    }
    value = value * 10 + (unit - 48)
  }
  if negative {
    Some(-value)
  } else {
    Some(value)
  }
}

///|
fn dev_path_segment(node : ElementNode, index : Int32) -> String {
  match node.key {
    Some(key) => "k:" + dev_hex_encode(@utf8.encode(key.value()[:], bom=false))
    None => "i:" + index.to_string()
  }
}

///|
fn dev_child_path(parent : String, node : ElementNode, index : Int32) -> String {
  parent + "/" + dev_path_segment(node, index)
}

///|
fn dev_find_element_path(
  node : ElementNode,
  target : ElementId,
  path : String,
) -> String? {
  if node.id == target {
    return Some(path)
  }
  for index, child in node.children {
    match
      dev_find_element_path(child, target, dev_child_path(path, child, index)) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn dev_find_node_by_path(
  node : ElementNode,
  target : String,
  path : String,
) -> ElementNode? {
  if path == target {
    return Some(node)
  }
  for index, child in node.children {
    match
      dev_find_node_by_path(child, target, dev_child_path(path, child, index)) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn dev_capture_slots(
  node : ElementNode,
  path : String,
  builder : StringBuilder,
) -> Unit {
  for entry in node.control.view_state.slots.entries() {
    builder.write_string(
      "slot " +
      path +
      " " +
      dev_hex_encode(entry.key) +
      " " +
      dev_hex_encode(entry.value) +
      "\n",
    )
  }
  for index, child in node.children {
    dev_capture_slots(child, dev_child_path(path, child, index), builder)
  }
}

///|
fn RuntimeState::capture_dev_transient(self : RuntimeState) -> String {
  let builder = StringBuilder()
  builder.write_string(DEV_TRANSIENT_SCHEMA + "\n")
  let focus_path = match self.animfocus.focused_element {
    Some(id) => dev_find_element_path(self.element_tree.root, id, "r")
    None => None
  }
  match focus_path {
    Some(path) => builder.write_string("focus " + path + "\n")
    None => ()
  }
  match focus_path {
    Some(path) =>
      match dev_find_node_by_path(self.element_tree.root, path, "r") {
        Some(node) => {
          let selection = match node.control.selection {
            Some(range) => range.start.to_string() + " " + range.end.to_string()
            None => "-1 -1"
          }
          let composition = match node.control.composition {
            Some(value) => dev_hex_encode(@utf8.encode(value[:], bom=false))
            None => "-"
          }
          let composition_cursor = match node.control.composition_cursor {
            Some(range) => range.start.to_string() + " " + range.end.to_string()
            None => "-1 -1"
          }
          builder.write_string(
            "text " +
            path +
            " " +
            node.control.caret.to_string() +
            " " +
            selection +
            " " +
            composition +
            " " +
            composition_cursor +
            "\n",
          )
        }
        None => ()
      }
    None => ()
  }
  dev_capture_slots(self.element_tree.root, "r", builder)
  builder.to_string()
}

///|
fn dev_parse_transient(payload : String) -> DevTransientSnapshot? {
  let lines = payload.split("\n").to_array()
  if lines.is_empty() || lines[0] != DEV_TRANSIENT_SCHEMA {
    return None
  }
  let focus : Ref[String?] = Ref(None)
  let text : Ref[DevTransientText?] = Ref(None)
  let slots : Array[DevTransientSlot] = []
  for line in lines {
    if line == "" {
      continue
    }
    let parts = line.split(" ").to_array()
    match parts {
      ["focus", path] => focus.val = Some(path.to_owned())
      [
        "text",
        path,
        caret,
        sel_start,
        sel_end,
        composition,
        comp_start,
        comp_end,
      ] =>
        match
          (
            dev_parse_int(caret.to_owned()),
            dev_parse_int(sel_start.to_owned()),
            dev_parse_int(sel_end.to_owned()),
            dev_parse_int(comp_start.to_owned()),
            dev_parse_int(comp_end.to_owned()),
          ) {
          (
            Some(caret),
            Some(sel_start),
            Some(sel_end),
            Some(comp_start),
            Some(comp_end),
          ) => {
            let selection = if sel_start >= 0 && sel_end >= 0 {
              Some(@core.TextRange::new(start=sel_start, end=sel_end))
            } else {
              None
            }
            let composition_value = if composition == "-" {
              None
            } else {
              match dev_hex_decode(composition.to_owned()) {
                Some(bytes) => Some(@utf8.decode_lossy(bytes, ignore_bom=true))
                None => None
              }
            }
            let composition_cursor = if comp_start >= 0 && comp_end >= 0 {
              Some(@core.TextRange::new(start=comp_start, end=comp_end))
            } else {
              None
            }
            text.val = Some({
              path: path.to_owned(),
              caret,
              selection,
              composition: composition_value,
              composition_cursor,
            })
          }
          _ => ()
        }
      ["slot", path, key, value] =>
        match
          (dev_hex_decode(key.to_owned()), dev_hex_decode(value.to_owned())) {
          (Some(key), Some(value)) =>
            slots.push({ path: path.to_owned(), key, value, })
          _ => ()
        }
      _ => ()
    }
  }
  Some({ focus_path: focus.val, text: text.val, slots, })
}

///|
fn dev_restore_slots(
  node : ElementNode,
  path : String,
  slot_map : Map[String, Array[@core.ViewStateEntry]],
) -> Unit {
  match slot_map.get(path) {
    Some(entries) => {
      let current = node.control.view_state
      let next = {
        ..current,
        slots: @core.ViewStateSlots::from_entries(entries),
      }
      node.control.apply_view_context(next)
    }
    None => ()
  }
  for index, child in node.children {
    dev_restore_slots(child, dev_child_path(path, child, index), slot_map)
  }
}

///|
fn RuntimeState::restore_dev_transient(
  self : RuntimeState,
  payload : String,
) -> Unit {
  let snapshot = match dev_parse_transient(payload) {
    Some(value) => value
    None => return
  }
  let slot_map : Map[String, Array[@core.ViewStateEntry]] = Map([])
  for slot in snapshot.slots {
    let entry : @core.ViewStateEntry = { key: slot.key, value: slot.value, }
    match slot_map.get(slot.path) {
      Some(entries) => entries.push(entry)
      None => slot_map[slot.path] = [entry]
    }
  }
  dev_restore_slots(self.element_tree.root, "r", slot_map)
  match snapshot.focus_path {
    Some(path) =>
      match dev_find_node_by_path(self.element_tree.root, path, "r") {
        Some(node) => ignore(self.commit_focus(Some(node.id)))
        None => ()
      }
    None => ()
  }
  match snapshot.text {
    Some(text) =>
      match dev_find_node_by_path(self.element_tree.root, text.path, "r") {
        Some(node) => {
          node.control.caret = text.caret
          node.control.selection = text.selection
          node.control.composition = text.composition
          node.control.composition_cursor = text.composition_cursor
          node.control.text_revision = node.control.text_revision + 1
          if self.animfocus.focused_element != Some(node.id) {
            ignore(self.commit_focus(Some(node.id)))
          }
          self.mark_dirty(node.id)
          self.mark_semantics_dirty(node.id)
        }
        None => ()
      }
    None => ()
  }
}

///|
fn RuntimeState::save_dev_transient(self : RuntimeState) -> Unit {
  match self.dev_transient_transport {
    Some(transport) => transport.write(self.capture_dev_transient())
    None => ()
  }
}

///|
fn RuntimeState::maybe_save_dev_transient(self : RuntimeState) -> Unit {
  match self.dev_transient_transport {
    Some(_) =>
      if self.animfocus.now_ms - self.dev_transient_last_save_ms >=
        DEV_TRANSIENT_SAVE_INTERVAL_MS {
        self.dev_transient_last_save_ms = self.animfocus.now_ms
        self.save_dev_transient()
      }
    None => ()
  }
}

///|
pub fn AppRuntime::capture_dev_transient(self : AppRuntime) -> String {
  self.state.capture_dev_transient()
}

///|
pub fn AppRuntime::restore_dev_transient(
  self : AppRuntime,
  payload : String,
) -> Unit {
  self.state.restore_dev_transient(payload)
}
