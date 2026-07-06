///|
test "cell references and column labels" {
  inspect(column_label(0), content="A")
  inspect(column_label(25), content="Z")
  inspect(column_label(26), content="AA")
  inspect(make_key(2, 27), content="AB3")
  debug_inspect(parse_ref("C3"), content="Some({ row: 2, col: 2 })")
  debug_inspect(parse_ref("aa10"), content="Some({ row: 9, col: 26 })")
  debug_inspect(parse_ref("$C$3"), content="Some({ row: 2, col: 2 })")
  debug_inspect(parse_ref("C$3"), content="Some({ row: 2, col: 2 })")
  debug_inspect(parse_ref("$C3"), content="Some({ row: 2, col: 2 })")
  assert_true(parse_ref("INVALID") is None)
}

///|
test "cell values and number formats" {
  inspect(parse_raw_value("42").to_display(), content="42")
  inspect(
    parse_raw_value("42.5").format_with(NumFormat::Currency),
    content="$42.50",
  )
  inspect(
    parse_raw_value("0.25").format_with(NumFormat::Percent),
    content="25.00%",
  )
  inspect(parse_raw_value("Widget").to_display(), content="Widget")
}
