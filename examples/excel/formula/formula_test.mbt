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
  inspect(evaluate("=PRODUCT(A1:C1)", lookup).to_display(), content="6")
  inspect(evaluate("=MEDIAN(A1:C1)", lookup).to_display(), content="2")
}

///|
test "formula references handle multi-letter columns" {
  let lookup = fn(ref_str) {
    match @cell.parse_ref(ref_str) {
      Some(addr) =>
        if addr.key() == "AA10" {
          @cell.CellValue::Number(7.0)
        } else {
          @cell.CellValue::Empty
        }
      None => @cell.CellValue::Empty
    }
  }
  inspect(evaluate("=AA10*3", lookup).to_display(), content="21")
  inspect(evaluate("=$AA$10*3", lookup).to_display(), content="21")
}

///|
test "formula reference extraction expands ranges" {
  inspect(
    extract_references("=SUM(A1:B2)+C3").join(","),
    content="A1,B1,A2,B2,C3",
  )
  inspect(
    extract_references("=SUM($A$1:B$2)+$C3").join(","),
    content="A1,B1,A2,B2,C3",
  )
}

///|
test "formula evaluator preserves ref errors" {
  let lookup = fn(_) { @cell.CellValue::Empty }
  inspect(evaluate("=#REF!", lookup).to_display(), content="#REF!")
  inspect(evaluate("=#REF!+A1", lookup).to_display(), content="#REF!")
}

///|
test "formula evaluator supports common aggregate functions" {
  let cells : Map[String, @cell.CellValue] = {
    "A1": @cell.CellValue::Number(2.0),
    "B1": @cell.CellValue::Number(4.0),
    "C1": @cell.CellValue::Number(6.0),
    "D1": @cell.CellValue::Number(8.0),
  }
  let lookup = fn(ref_str) {
    match cells.get(ref_str) {
      Some(value) => value
      None => @cell.CellValue::Empty
    }
  }
  inspect(evaluate("=PRODUCT(A1:D1)", lookup).to_display(), content="384")
  inspect(evaluate("=MEDIAN(A1:D1)", lookup).to_display(), content="5")
}

///|
test "formula evaluator supports logical functions" {
  let cells : Map[String, @cell.CellValue] = {
    "A1": @cell.CellValue::Number(4.0),
    "B1": @cell.CellValue::Number(0.0),
  }
  let lookup = fn(ref_str) {
    match cells.get(ref_str) {
      Some(value) => value
      None => @cell.CellValue::Empty
    }
  }
  inspect(evaluate("=AND(A1>0, B1=0)", lookup).to_display(), content="1")
  inspect(evaluate("=AND(A1>0, B1>0)", lookup).to_display(), content="0")
  inspect(evaluate("=OR(A1=0, B1=0)", lookup).to_display(), content="1")
  inspect(evaluate("=NOT(B1>0)", lookup).to_display(), content="1")
  inspect(
    evaluate("=IF(AND(A1>0,B1=0), 9, 1)", lookup).to_display(),
    content="9",
  )
}
