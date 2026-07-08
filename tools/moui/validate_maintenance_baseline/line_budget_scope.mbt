///|
fn line_budget_file_budgets(scope : String) -> Array[FileBudget] {
  let budgets = file_budgets()
  if scope == "full" {
    budgets.append(full_workspace_file_budgets())
  }
  budgets
}

///|
fn tracked_budget_paths(scope? : String = "daily") -> Array[String] {
  let paths : Array[String] = []
  for budget in line_budget_file_budgets(scope) {
    paths.push(budget.path)
  }
  paths
}
