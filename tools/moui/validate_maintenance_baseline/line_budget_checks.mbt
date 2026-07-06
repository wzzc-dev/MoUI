///|
struct LineBudgetOverflow {
  path : String
  lines : Int
}

///|
fn tracked_budget_paths() -> Array[String] {
  let paths : Array[String] = []
  for budget in file_budgets() {
    paths.push(budget.path)
  }
  paths
}

///|
fn record_file_budget_overflow(
  repo_root : String,
  budget : FileBudget,
  overflows : Array[LineBudgetOverflow],
  failures : Array[String],
) -> Unit {
  let text = match read_repo_text(repo_root, budget.path) {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  let lines = line_count(text)
  if lines > budget.max_lines {
    overflows.push({ path: budget.path, lines })
  }
}

///|
fn record_untracked_oversized_files(
  repo_root : String,
  overflows : Array[LineBudgetOverflow],
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  for root in monitored_roots() {
    collect_mbt_files(repo_root, root, files, failures)
  }
  let tracked_paths = tracked_budget_paths()
  for path in files {
    if !generated_fixture_path(path) && !array_contains(tracked_paths, path) {
      let text = match read_repo_text(repo_root, path) {
        Ok(value) => value
        Err(message) => {
          failures.push(message)
          continue
        }
      }
      let lines = line_count(text)
      if lines > oversized_file_threshold() {
        overflows.push({ path, lines })
      }
    }
  }
}

///|
fn sort_line_budget_overflows(overflows : Array[LineBudgetOverflow]) -> Unit {
  overflows.sort_by((left, right) => {
    let by_lines = right.lines - left.lines
    if by_lines != 0 {
      by_lines
    } else {
      right.path.compare(left.path)
    }
  })
}

///|
fn line_budget_overflow_paths(
  overflows : Array[LineBudgetOverflow],
) -> Array[String] {
  sort_line_budget_overflows(overflows)
  overflows.map(overflow => overflow.path)
}

///|
fn collect_line_budget_overflows(
  repo_root : String,
  failures : Array[String],
) -> Array[LineBudgetOverflow] {
  let overflows : Array[LineBudgetOverflow] = []
  for budget in file_budgets() {
    record_file_budget_overflow(repo_root, budget, overflows, failures)
  }
  record_untracked_oversized_files(repo_root, overflows, failures)
  sort_line_budget_overflows(overflows)
  overflows
}
