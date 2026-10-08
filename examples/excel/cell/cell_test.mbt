///|
test "cell references and column labels" {
  inspect(@cell.column_label(0), content="A")
  inspect(@cell.column_label(25), content="Z")
  inspect(@cell.column_label(26), content="AA")
  inspect(@cell.make_key(2, 27), content="AB3")
  debug_inspect(@cell.parse_ref("C3"), content="Some({ row: 2, col: 2 })")
  debug_inspect(@cell.parse_ref("aa10"), content="Some({ row: 9, col: 26 })")
  debug_inspect(@cell.parse_ref("$C$3"), content="Some({ row: 2, col: 2 })")
  debug_inspect(@cell.parse_ref("C$3"), content="Some({ row: 2, col: 2 })")
  debug_inspect(@cell.parse_ref("$C3"), content="Some({ row: 2, col: 2 })")
  assert_true(@cell.parse_ref("INVALID") is None)
}

///|
test "cell values and number formats" {
  inspect(@cell.parse_raw_value("42").to_display(), content="42")
  inspect(
    @cell.parse_raw_value("42.5").format_with(@cell.NumFormat::Currency),
    content="$42.50",
  )
  inspect(
    @cell.parse_raw_value("0.25").format_with(@cell.NumFormat::Percent),
    content="25.00%",
  )
  inspect(@cell.parse_raw_value("Widget").to_display(), content="Widget")
}
