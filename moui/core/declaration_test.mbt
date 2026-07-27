///|
fn declaration_change_tuple(
  changes : @core.DeclarationChanges,
) -> (Bool, Bool, Bool, Bool) {
  (changes.layout(), changes.paint(), changes.semantics(), changes.platform())
}

///|
fn declaration_with_channel(
  layout? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
  paint? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
  semantics? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
  platform? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
) -> @core.ViewDeclaration {
  @core.ViewDeclaration::channels(layout~, paint~, semantics~, platform~)
}

///|
test "DeclarationKey: canonical primitive encodings preserve exact values" {
  inspect(
    @core.DeclarationKey::string("ab") == @core.DeclarationKey::string("cd"),
    content="false",
  )
  inspect(
    @core.DeclarationKey::int(-1) == @core.DeclarationKey::uint(0xFFFFFFFF),
    content="false",
  )
  inspect(
    @core.DeclarationKey::bool(false) == @core.DeclarationKey::int(0),
    content="false",
  )
  inspect(
    @core.DeclarationKey::bytes(b"same") == @core.DeclarationKey::string("same"),
    content="false",
  )
  inspect(
    @core.DeclarationKey::int64(-1L) ==
    @core.DeclarationKey::uint64(0xFFFFFFFFFFFFFFFFUL),
    content="false",
  )
  inspect(
    @core.DeclarationKey::string("same") == @core.DeclarationKey::string("same"),
    content="true",
  )
}

///|
test "DeclarationKey: option presence and payload changes are exact" {
  let none = @core.DeclarationKey::option(None)
  let some_a = @core.DeclarationKey::option(
    Some(@core.DeclarationKey::string("a")),
  )
  let some_b = @core.DeclarationKey::option(
    Some(@core.DeclarationKey::string("b")),
  )
  inspect(none == some_a, content="false")
  inspect(some_a == some_b, content="false")
  inspect(
    some_a ==
    @core.DeclarationKey::option(Some(@core.DeclarationKey::string("a"))),
    content="true",
  )
}

///|
test "DeclarationKey: Double encoding preserves adjacent bits and signed zero" {
  inspect(
    @core.DeclarationKey::double(1.0) ==
    @core.DeclarationKey::double(1.0000000000000002),
    content="false",
  )
  inspect(
    @core.DeclarationKey::double(0.0) == @core.DeclarationKey::double(-0.0),
    content="false",
  )
}

///|
test "DeclarationKey: framing prevents delimiter and nesting ambiguity" {
  let delimiter_in_name = @core.DeclarationKey::record(type_tag="Record", fields=[
    ("a|b", @core.DeclarationKey::string("c")),
  ])
  let delimiter_in_value = @core.DeclarationKey::record(type_tag="Record", fields=[
    ("a", @core.DeclarationKey::string("b|c")),
  ])
  let split_fields = @core.DeclarationKey::record(type_tag="Record", fields=[
    ("a", @core.DeclarationKey::string("b")),
    ("c", @core.DeclarationKey::string("")),
  ])
  inspect(delimiter_in_name == delimiter_in_value, content="false")
  inspect(delimiter_in_value == split_fields, content="false")
  inspect(
    delimiter_in_value ==
    @core.DeclarationKey::record(type_tag="OtherRecord", fields=[
      ("a", @core.DeclarationKey::string("b|c")),
    ]),
    content="false",
  )
  inspect(
    @core.DeclarationKey::array([
      @core.DeclarationKey::string("ab"),
      @core.DeclarationKey::string("c"),
    ]) ==
    @core.DeclarationKey::array([
      @core.DeclarationKey::string("a"),
      @core.DeclarationKey::string("bc"),
    ]),
    content="false",
  )
}

///|
test "DeclarationKey: equality checks the complete encoded bytes" {
  let prefix : Array[@core.DeclarationKey] = []
  for index in 0..<64 {
    prefix.push(@core.DeclarationKey::int(index))
  }
  let left_values = prefix.copy()
  left_values.push(@core.DeclarationKey::bytes(b"tail-a"))
  let right_values = prefix.copy()
  right_values.push(@core.DeclarationKey::bytes(b"tail-b"))
  inspect(
    @core.DeclarationKey::array(left_values) ==
    @core.DeclarationKey::array(right_values),
    content="false",
  )
}

///|
test "ViewDeclaration: channel accessors preserve exact declarations" {
  let key = @core.DeclarationKey::string("v1")
  let declaration = declaration_with_channel(
    layout=@core.DeclarationChannel::Exact(key),
    paint=@core.DeclarationChannel::Uncacheable,
  )
  inspect(
    declaration.layout() == @core.DeclarationChannel::Exact(key),
    content="true",
  )
  inspect(
    declaration.paint() == @core.DeclarationChannel::Uncacheable,
    content="true",
  )
  inspect(
    declaration.semantics() == @core.DeclarationChannel::Constant,
    content="true",
  )
  inspect(
    declaration.platform() == @core.DeclarationChannel::Constant,
    content="true",
  )
}

///|
test "ViewDeclaration: four channels classify independently" {
  let old = @core.ViewDeclaration::constant()
  debug_inspect(
    declaration_change_tuple(old.changes_from(old)),
    content="(false, false, false, false)",
  )
  inspect(old.changes_from(old).is_clean(), content="true")
  debug_inspect(
    declaration_change_tuple(
      declaration_with_channel(
        paint=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::string("paint"),
        ),
      ).changes_from(old),
    ),
    content="(false, true, false, false)",
  )
  debug_inspect(
    declaration_change_tuple(
      declaration_with_channel(
        semantics=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::string("semantics"),
        ),
      ).changes_from(old),
    ),
    content="(false, false, true, false)",
  )
  debug_inspect(
    declaration_change_tuple(
      declaration_with_channel(
        platform=@core.DeclarationChannel::Exact(
          @core.DeclarationKey::string("platform"),
        ),
      ).changes_from(old),
    ),
    content="(false, false, false, true)",
  )
}

///|
test "ViewDeclaration: layout invalidation implies all downstream channels" {
  let old = @core.ViewDeclaration::constant()
  let next = declaration_with_channel(
    layout=@core.DeclarationChannel::Exact(
      @core.DeclarationKey::string("layout"),
    ),
  )
  debug_inspect(
    declaration_change_tuple(next.changes_from(old)),
    content="(true, true, true, true)",
  )
}

///|
test "ViewDeclaration: exact and uncacheable channel matrix" {
  let exact_a = @core.DeclarationChannel::Exact(
    @core.DeclarationKey::string("a"),
  )
  let exact_b = @core.DeclarationChannel::Exact(
    @core.DeclarationKey::string("b"),
  )
  let old = declaration_with_channel(paint=exact_a)
  debug_inspect(
    declaration_change_tuple(
      declaration_with_channel(paint=exact_a).changes_from(old),
    ),
    content="(false, false, false, false)",
  )
  debug_inspect(
    declaration_change_tuple(
      declaration_with_channel(paint=exact_b).changes_from(old),
    ),
    content="(false, true, false, false)",
  )
  let uncacheable = declaration_with_channel(
    semantics=@core.DeclarationChannel::Uncacheable,
  )
  debug_inspect(
    declaration_change_tuple(uncacheable.changes_from(uncacheable)),
    content="(false, false, true, false)",
  )
  debug_inspect(
    declaration_change_tuple(
      @core.ViewDeclaration::uncacheable().changes_from(
        @core.ViewDeclaration::uncacheable(),
      ),
    ),
    content="(true, true, true, true)",
  )
}

///|
test "ViewDeclaration: every channel policy transition is explicit" {
  let key_a = @core.DeclarationKey::string("a")
  let key_b = @core.DeclarationKey::string("b")
  let policies : Array[@core.DeclarationChannel] = [
    @core.DeclarationChannel::Constant,
    @core.DeclarationChannel::Exact(key_a),
    @core.DeclarationChannel::Exact(key_b),
    @core.DeclarationChannel::Uncacheable,
  ]
  let expected : Array[Array[Bool]] = [
    [false, true, true, true],
    [true, false, true, true],
    [true, true, false, true],
    [true, true, true, true],
  ]
  for previous_index, previous in policies {
    for next_index, next in policies {
      let changes = declaration_with_channel(paint=next).changes_from(
        declaration_with_channel(paint=previous),
      )
      assert_eq(changes.paint(), expected[previous_index][next_index])
      assert_false(changes.layout())
      assert_false(changes.semantics())
      assert_false(changes.platform())
    }
  }
}
