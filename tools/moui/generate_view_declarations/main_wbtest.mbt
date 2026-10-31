///|
fn fixture_node(text : String) -> NodeSpec {
  let json = @json.parse(text) catch { _ => abort("fixture is not valid JSON") }
  match parse_node(json, "test") {
    Ok(node) => node
    Err(message) => abort(message)
  }
}

///|
fn node_fixture() -> NodeSpec {
  fixture_node(
    (
      #|{
      #|  "node": "Demo",
      #|  "package": "moui/views/demo",
      #|  "declaration": {
      #|    "layout": {
      #|      "kind": "exact",
      #|      "record": "Demo",
      #|      "fields": [
      #|        { "name": "spacing", "enc": "double", "path": "spacing" }
      #|      ]
      #|    },
      #|    "paint": {
      #|      "kind": "theme_pinned",
      #|      "style_pins_uncacheable": true,
      #|      "record": "Demo.paint",
      #|      "fields": [
      #|        { "name": "checked", "enc": "bool", "path": "checked" },
      #|        {
      #|          "name": "box_shape",
      #|          "enc": "enum_option",
      #|          "path": "box_shape",
      #|          "arms": ["Square", "Circle"]
      #|        },
      #|        {
      #|          "name": "style",
      #|          "enc": "record_option",
      #|          "path": "style",
      #|          "record": "DemoStyle",
      #|          "fields": [
      #|            { "name": "radius", "enc": "double", "path": "radius" }
      #|          ]
      #|        }
      #|      ]
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "parse_node decodes channels and whole-declaration shortcuts" {
  let node = node_fixture()
  assert_eq(node.node, "Demo")
  assert_eq(node.pkg, "moui/views/demo")
  assert_eq(node.whole, "")
  assert_eq(node.channels.length(), 2)
  let paint = match node.channels.get(1) {
    Some((name, channel)) => {
      assert_eq(name, "paint")
      channel
    }
    None => abort("missing paint channel")
  }
  assert_eq(paint.kind, "theme_pinned")
  assert_eq(paint.style_pins_uncacheable, true)
  let shortcut = fixture_node(
    (
      #|{
      #|  "node": "Panel",
      #|  "package": "moui/views/form",
      #|  "generic": true,
      #|  "self": "_self",
      #|  "declaration": "uncacheable"
      #|}
    ),
  )
  assert_eq(shortcut.whole, "uncacheable")
  assert_eq(shortcut.generic, true)
  assert_eq(shortcut.self_param, "_self")
}

///|
test "validate_node accepts the demo node and rejects path traversal" {
  let node = node_fixture()
  assert_eq(validate_node(node), Ok(()))
  let traversal = fixture_node(
    (
      #|{
      #|  "node": "Escape",
      #|  "package": "../examples",
      #|  "declaration": "constant"
      #|}
    ),
  )
  match validate_node(traversal) {
    Ok(_) => fail("path traversal must be rejected")
    Err(_) => ()
  }
}

///|
test "emit_node renders channels, gates, and enum arms" {
  let node = node_fixture()
  let out = StringBuilder()
  emit_node(emit_context(node.pkg), node, out)
  let text = out.to_string()
  assert_true(
    text.contains("impl @core.ViewNode for Demo with fn declaration(self) {"),
  )
  assert_true(text.contains("layout=@common.view_exact_channel("))
  assert_true(text.contains("paint=if self.style is Some(_) {"))
  assert_true(text.contains("match box_shape {"))
  assert_true(text.contains("Square => 0"))
  assert_true(text.contains("Circle => 1"))
  assert_true(text.contains("@common.view_record_key(\"DemoStyle\", ["))
  assert_true(text.contains(", self.theme)"))
}

///|
test "emit_context drops the @common receiver inside moui/views/common" {
  assert_eq(emit_context("moui/views/button").common, "@common.")
  assert_eq(emit_context("moui/views/common").common, "")
  let node = fixture_node(
    (
      #|{
      #|  "node": "Flex",
      #|  "package": "moui/views/common",
      #|  "declaration": {
      #|    "layout": {
      #|      "kind": "exact",
      #|      "record": "Flex",
      #|      "fields": [
      #|        { "name": "spacing", "enc": "double", "path": "spacing" }
      #|      ]
      #|    }
      #|  }
      #|}
    ),
  )
  let out = StringBuilder()
  emit_node(emit_context(node.pkg), node, out)
  let text = out.to_string()
  assert_true(text.contains("view_layout_declaration("))
  assert_false(text.contains("@common.view_layout_declaration"))
}

///|
test "whole-declaration shortcuts emit ViewDeclaration constants" {
  let node = fixture_node(
    (
      #|{
      #|  "node": "Panel",
      #|  "package": "moui/views/form",
      #|  "generic": true,
      #|  "self": "_self",
      #|  "declaration": "constant"
      #|}
    ),
  )
  let out = StringBuilder()
  emit_node(emit_context(node.pkg), node, out)
  let text = out.to_string()
  assert_true(
    text.contains(
      "impl[Msg] @core.ViewNode for Panel[Msg] with fn declaration(_self) {",
    ),
  )
  assert_true(text.contains("@core.ViewDeclaration::constant()"))
}
