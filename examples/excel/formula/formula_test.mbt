///|
test "formula evaluator resolves arithmetic references and ranges" {
  let cells : Map[String, @cell.CellValue] = {
    "A1": @cell.CellValue::Number(1.0),
    "B1": @cell.CellValue::Number(2.0),
    "C1": @cell.CellValue::Number(3.0),
  }
  let lookup = fn(ref_str) {
    match cells.get(ref_str) {
      Some(value) => value
      None => @cell.CellValue::Empty
    }
  }
  inspect(evaluate("=A1+B1*2", lookup).to_display(), content="5")
  inspect(evaluate("=SUM(A1:C1)", lookup).to_display(), content="6")
  inspect(evaluate("=AVG(A1:C1)", lookup).to_display(), content="2")
}

///|
test "formula references handle multi-letter columns" {
  let lookup = fn(ref_str) {
    if ref_str == "AA10" {
      @cell.CellValue::Number(7.0)
    } else {
      @cell.CellValue::Empty
    }
  }
  inspect(evaluate("=AA10*3", lookup).to_display(), content="21")
}

///|
test "formula reference extraction expands ranges" {
  inspect(
    extract_references("=SUM(A1:B2)+C3").join(","),
    content="A1,B1,A2,B2,C3",
  )
}
