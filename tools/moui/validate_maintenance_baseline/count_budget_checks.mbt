///|
struct CountBudgetOverflow {
  kind : String
  label : String
  count : Int
  max_count : Int
}

///|
fn record_count_budget_overflow(
  budget : CountBudget,
  count : Int,
  overflows : Array[CountBudgetOverflow],
) -> Unit {
  if count > budget.max_count {
    overflows.push({
      kind: budget.kind,
      label: budget.label,
      count,
      max_count: budget.max_count,
    })
  }
}

///|
fn count_pub_all_in_tree(
  repo_root : String,
  root : String,
  failures : Array[String],
) -> Int {
  let files : Array[String] = []
  collect_mbt_files(repo_root, root, files, failures)
  let mut count = 0
  for path in files {
    if !generated_fixture_path(path) {
      match read_repo_text(repo_root, path) {
        Ok(text) => count += count_lines_containing_token(text, "pub(all)")
        Err(message) => failures.push(message)
      }
    }
  }
  count
}

///|
fn collect_count_budget_overflows(
  repo_root : String,
  failures : Array[String],
) -> Array[CountBudgetOverflow] {
  let overflows : Array[CountBudgetOverflow] = []
  for budget in pub_all_budgets() {
    let count = count_pub_all_in_tree(repo_root, budget.path, failures)
    record_count_budget_overflow(budget, count, overflows)
  }
  let root_budget = root_facade_forward_budget()
  match read_repo_text(repo_root, root_budget.path) {
    Ok(text) =>
      record_count_budget_overflow(
        root_budget,
        count_root_facade_forwards(text),
        overflows,
      )
    Err(message) => failures.push(message)
  }
  sort_count_budget_overflows(overflows)
  overflows
}

///|
fn sort_count_budget_overflows(overflows : Array[CountBudgetOverflow]) -> Unit {
  overflows.sort_by((left, right) => {
    let by_kind = left.kind.compare(right.kind)
    if by_kind != 0 {
      by_kind
    } else {
      left.label.compare(right.label)
    }
  })
}

///|
fn count_budget_overflow_message(overflow : CountBudgetOverflow) -> String {
  overflow.kind +
  " budget exceeded: " +
  overflow.label +
  " count=\{overflow.count} max=\{overflow.max_count}"
}

///|
fn count_budget_overflow_messages(
  overflows : Array[CountBudgetOverflow],
) -> Array[String] {
  sort_count_budget_overflows(overflows)
  overflows.map(count_budget_overflow_message)
}
