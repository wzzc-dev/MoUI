///|
fn split_lines(text : String) -> Array[String] {
  text.split("\n").map(v => v.to_owned()).collect()
}

///|
test "struct_open detects multi-line and same-line structs" {
  assert_eq(struct_open("priv struct Demo {"), Some(("Demo", true)))
  assert_eq(
    struct_open("pub(struct) struct Demo[Msg] {}"),
    Some(("Demo", false)),
  )
  assert_eq(struct_open("  priv struct Indented {"), None)
  assert_eq(struct_open("priv enum Demo { A }"), None)
}

///|
test "struct_fields reads names, exemption markers, and stops at brace" {
  let raw =
    #|  text : String
    #|  hidden : Bool // declaration-exempt: event closure carries it
    #|  missed : Int
    #|}
    #|
    #|struct Next {
  let lines = split_lines(raw)
  let (fields, next) = struct_fields(lines, 0)
  assert_eq(fields.map(f => f.name), ["text", "hidden", "missed"])
  assert_eq(fields.map(f => f.exempt), [false, true, false])
  assert_eq(next, 4)
}

///|
test "contains_identifier respects identifier boundaries" {
  assert_eq(contains_identifier("self.text + text", "text"), true)
  assert_eq(contains_identifier("context", "text"), false)
  assert_eq(contains_identifier("min_size", "size"), false)
  assert_eq(contains_identifier("layout_key(", "layout_key"), true)
  assert_eq(contains_identifier("", "text"), false)
}

///|
test "contains_identifier ignores literals, comments, and label positions" {
  assert_eq(contains_identifier("(\"text\", other)", "text"), false)
  assert_eq(contains_identifier("paint=chan(self.paint)", "paint"), true)
  assert_eq(contains_identifier("paint=chan", "paint"), false)
  assert_eq(contains_identifier("x = 1 // text", "text"), false)
  assert_eq(contains_identifier("(\"value\", self.value)", "value"), true)
}

///|
test "scan and coverage flag uncovered fields only" {
  let fixture =
    #|priv struct Demo {
    #|  text : String
    #|  hidden : Bool // declaration-exempt: event closure carries it
    #|  missed : Int
    #|}
    #|
    #|impl @core.ViewNode for Demo with fn identity(self) {
    #|  ViewIdentity::new(kind="Demo")
    #|}
    #|
    #|impl @core.ViewNode for Demo with fn declaration(self) {
    #|  view_record_key("Demo.layout", [
    #|    ("text", DeclarationKey::string(self.text)),
    #|  ])
    #|}
    #|
    #|impl @core.ViewNode for Demo with fn layout(self, ctx) {
    #|  ViewLayoutResult::new(size=ctx.constraints.constrain(Size::zero()))
    #|}
  let (structs, impls) = scan_file_lines(
    "moui/views/demo",
    split_lines(fixture),
  )
  let struct_def = structs.get("Demo").unwrap()
  assert_eq(struct_def.fields.map(f => f.name), ["text", "hidden", "missed"])
  let entry = impls.get("moui/views/demo|Demo").unwrap()
  assert_eq(entry.has_view_node, true)
  assert_eq(entry.has_declaration, true)
  let violations = struct_violations(
    "moui/views/demo/demo.mbt", struct_def, entry,
  )
  assert_eq(violations.map(v => v.field), ["missed"])
}

///|
test "nodes without a declaration override are safe by default" {
  let fixture =
    #|priv struct Bare {
    #|  value : Int
    #|}
    #|
    #|impl @core.ViewNode for Bare with fn layout(self, ctx) {
    #|  ViewLayoutResult::new(size=ctx.constraints.constrain(Size::zero()))
    #|}
  let (structs, impls) = scan_file_lines(
    "moui/views/bare",
    split_lines(fixture),
  )
  let struct_def = structs.get("Bare").unwrap()
  let entry = impls.get("moui/views/bare|Bare").unwrap()
  assert_eq(entry.has_declaration, false)
  assert_eq(
    struct_violations("moui/views/bare/bare.mbt", struct_def, entry).length(),
    0,
  )
}

///|
test "apply_waivers filters active violations and detects stale waivers" {
  let violations = [
    { path: "moui/views/demo/demo.mbt", node: "Demo", field: "missed" },
  ]
  let waived = {
    waived: [
      {
        pkg: "moui/views/demo",
        node: "Demo",
        field: "missed",
        reason: "tracked in plan",
      },
      {
        pkg: "moui/views/gone",
        node: "Gone",
        field: "field",
        reason: "fixed already",
      },
    ],
  }
  let (active, stale) = apply_waivers(violations, waived)
  assert_eq(active.length(), 0)
  assert_eq(stale.map(w => w.node), ["Gone"])
}

///|
test "package_of strips the file name" {
  assert_eq(package_of("moui/views/button/button.mbt"), "moui/views/button")
  assert_eq(package_of("root.mbt"), ".")
}
