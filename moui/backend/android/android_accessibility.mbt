// Android accessibility bridge (MoonBit side).
//
// The window embedder's HostedSurfaceView exposes the semantics tree through
// an AccessibilityNodeProvider (see the template's HostedActivity). The
// provider needs plain data, so this file projects the runtime semantics
// snapshot into a flat text encoding pushed over JNI, and accessibility
// activation flows back as a synthesized tap on the existing pointer channel
// (the same interaction a TalkBack "double-tap to activate" produces).
//
// Role ids and flag bits match `harmonyos_accessibility.mbt`; the Java side
// maps them to android.view.View class names and accessibility properties.

///|
/// Role ids must stay in sync with the template's `A11yNode.className`.
fn android_a11y_role_id(role : @core.SemanticsRole) -> Int32 {
  match role {
    Button => 1
    Text => 2
    TextField => 3
    Checkbox => 4
    Switch => 5
    Slider => 6
    List => 7
    ListItem => 8
    Image => 9
    Heading => 10
    Link => 11
    ScrollView => 12
    Group => 13
    _ => 0
  }
}

///|
/// Flag bits must stay in sync with the template's `A11yNode`.
/// 1 focused, 2 selected, 4 checked, 8 enabled, 16 clickable, 32 text input,
/// 64 scroll container.
fn android_a11y_flags(node : @core.SemanticsNode, focused : Bool) -> Int32 {
  let mut flags = if node.state.disabled { 0 } else { 8 }
  if focused || node.state.focused {
    flags = flags | 1
  }
  if node.state.selected {
    flags = flags | 2
  }
  match node.state.checked {
    Some(Checked) => flags = flags | 4
    _ => ()
  }
  if node.actions.contains(Activate) {
    flags = flags | 16
  }
  match node.role {
    TextField => flags = flags | 32
    _ => ()
  }
  if node.state.multiline {
    flags = flags | 32
  }
  match node.role {
    ScrollView | List => flags = flags | 64
    _ => ()
  }
  flags
}

///|
/// Encodes one node: id, parent, role, flags, left, top, right, bottom,
/// label, value, description — fields joined by US (\u001F), records by RS
/// (\u001E). The Java parser splits on both; label text containing the
/// separators degrades to a truncated label, never to a crash.
fn android_a11y_encode_node(
  node : @core.SemanticsNode,
  parent : UInt64,
  focused : Bool,
  builder : StringBuilder,
) -> Unit {
  builder.write_string("\u{1E}")
  builder.write_string(node.node_id.value().to_string())
  builder.write_string("\u{1F}")
  builder.write_string(parent.to_string())
  builder.write_string("\u{1F}")
  builder.write_string(android_a11y_role_id(node.role).to_string())
  builder.write_string("\u{1F}")
  builder.write_string(android_a11y_flags(node, focused).to_string())
  builder.write_string("\u{1F}")
  builder.write_string(node.frame.origin.x.to_string())
  builder.write_string("\u{1F}")
  builder.write_string(node.frame.origin.y.to_string())
  builder.write_string("\u{1F}")
  builder.write_string(
    (node.frame.origin.x + node.frame.size.width).to_string(),
  )
  builder.write_string("\u{1F}")
  builder.write_string(
    (node.frame.origin.y + node.frame.size.height).to_string(),
  )
  builder.write_string("\u{1F}")
  builder.write_string(node.label)
  builder.write_string("\u{1F}")
  builder.write_string(node.value)
  builder.write_string("\u{1F}")
  builder.write_string(node.description)
}

///|
/// Projects a semantics read into the flat text encoding the template
/// publishes through its AccessibilityNodeProvider. Only a `Full` snapshot
/// carries a tree; anything else returns `None` so the provider keeps the
/// node table it already holds.
pub fn android_accessibility_project(read : @apphost.SemanticsRead) -> String? {
  match read {
    Full(snapshot) => {
      let nodes = snapshot.nodes()
      let focused = snapshot.focused()
      let parents : Map[UInt64, UInt64] = Map([])
      for node in nodes {
        for child in node.children {
          parents.set(child.value(), node.node_id.value())
        }
      }
      let builder = StringBuilder()
      builder.write_string("gen=")
      builder.write_string(snapshot.generation().value().to_string())
      builder.write_string("\u{1E}")
      builder.write_string(
        match snapshot.root() {
          Some(id) => id.value().to_string()
          None => "0"
        },
      )
      builder.write_string("\u{1E}")
      builder.write_string(
        match focused {
          Some(id) => id.value().to_string()
          None => "0"
        },
      )
      for node in nodes {
        let parent = match parents.get(node.node_id.value()) {
          Some(parent_value) => parent_value
          None => 0UL
        }
        let is_focused = match focused {
          Some(id) => id == node.node_id
          None => false
        }
        android_a11y_encode_node(node, parent, is_focused, builder)
      }
      Some(builder.to_string())
    }
    _ => None
  }
}

///|
#borrow(tree)
extern "C" fn android_accessibility_publish_bytes(tree : Bytes) -> Int32 = "mbw_android_accessibility_publish"

///|
/// Publishes an encoded snapshot to the template's accessibility provider.
/// Returns whether the JNI bridge accepted it.
pub fn android_accessibility_publish(tree : String) -> Bool {
  android_accessibility_publish_bytes(@utf8.encode(tree, bom=false)) != 0
}
