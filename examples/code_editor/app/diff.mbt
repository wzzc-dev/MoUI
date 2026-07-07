///|
pub(all) enum CodeDiffLineKind {
  Context
  Added
  Removed
}

///|
pub fn CodeDiffLineKind::label(self : CodeDiffLineKind) -> String {
  match self {
    Context => "Context"
    Added => "Added"
    Removed => "Removed"
  }
}

///|
pub(all) struct CodeDiffLine {
  kind : CodeDiffLineKind
  old_line : Int?
  new_line : Int?
  text : String
}

///|
pub(all) struct CodeDiff {
  original : String
  modified : String
  lines : Array[CodeDiffLine]
}

///|
pub fn code_diff(original : String, modified : String) -> CodeDiff {
  let old_lines = split_lines(original)
  let new_lines = split_lines(modified)
  let table = diff_lcs_table(old_lines, new_lines)
  let columns = new_lines.length() + 1
  let lines : Array[CodeDiffLine] = []
  let mut i = old_lines.length()
  let mut j = new_lines.length()
  while i > 0 || j > 0 {
    if i > 0 && j > 0 && old_lines[i - 1] == new_lines[j - 1] {
      lines.push({
        kind: Context,
        old_line: Some(i),
        new_line: Some(j),
        text: old_lines[i - 1],
      })
      i = i - 1
      j = j - 1
    } else if j > 0 &&
      (
        i == 0 ||
        table[diff_table_index(i, j - 1, columns)] >=
        table[diff_table_index(i - 1, j, columns)]
      ) {
      lines.push({
        kind: Added,
        old_line: None,
        new_line: Some(j),
        text: new_lines[j - 1],
      })
      j = j - 1
    } else {
      lines.push({
        kind: Removed,
        old_line: Some(i),
        new_line: None,
        text: old_lines[i - 1],
      })
      i = i - 1
    }
  }
  { original, modified, lines: reverse_diff_lines(lines) }
}

///|
fn diff_lcs_table(
  old_lines : Array[String],
  new_lines : Array[String],
) -> Array[Int] {
  let columns = new_lines.length() + 1
  let table = Array::make((old_lines.length() + 1) * columns, 0)
  for i in 1..<=old_lines.length() {
    for j in 1..<=new_lines.length() {
      let index = diff_table_index(i, j, columns)
      if old_lines[i - 1] == new_lines[j - 1] {
        table[index] = table[diff_table_index(i - 1, j - 1, columns)] + 1
      } else {
        let up = table[diff_table_index(i - 1, j, columns)]
        let left = table[diff_table_index(i, j - 1, columns)]
        table[index] = if up > left { up } else { left }
      }
    }
  }
  table
}

///|
fn diff_table_index(row : Int, column : Int, columns : Int) -> Int {
  row * columns + column
}

///|
fn reverse_diff_lines(lines : Array[CodeDiffLine]) -> Array[CodeDiffLine] {
  let reversed : Array[CodeDiffLine] = []
  let mut i = lines.length()
  while i > 0 {
    i = i - 1
    reversed.push(lines[i])
  }
  reversed
}

///|
fn split_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  let current : Array[Char] = []
  for ch in source.to_array() {
    if ch == '\n' {
      lines.push(String::from_array(current))
      current.clear()
    } else {
      current.push(ch)
    }
  }
  if current.length() > 0 || source == "" {
    lines.push(String::from_array(current))
  }
  lines
}
