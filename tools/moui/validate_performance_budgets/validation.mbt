///|
fn performance_push(failures : Array[String], message : String) -> Unit {
  failures.push(message)
}

///|
fn performance_parse_percentile_budget(
  value : Json?,
  label : String,
  failures : Array[String],
) -> PercentileBudget? {
  let fields = match performance_json_object(value) {
    Some(fields) => fields
    None => {
      performance_push(failures, label + " must be an object")
      return None
    }
  }
  let p50 = performance_json_number(fields.get("p50")).unwrap_or(-1.0)
  let p95 = performance_json_number(fields.get("p95")).unwrap_or(-1.0)
  let p99 = performance_json_number(fields.get("p99")).unwrap_or(-1.0)
  let regression = performance_json_number(fields.get("maxRegressionPercent")).unwrap_or(
    -1.0,
  )
  if p50 < 0.0 || p95 < p50 || p99 < p95 {
    performance_push(failures, label + " must satisfy 0 <= p50 <= p95 <= p99")
  }
  if regression < 0.0 || regression > 100.0 {
    performance_push(
      failures,
      label + ".maxRegressionPercent must be in [0, 100]",
    )
  }
  Some({ p50, p95, p99, max_regression_percent: regression })
}

///|
fn performance_parse_resource_budget(
  value : Json?,
  label : String,
  failures : Array[String],
) -> ResourceBudget? {
  let fields = match performance_json_object(value) {
    Some(fields) => fields
    None => {
      performance_push(failures, label + " must be an object")
      return None
    }
  }
  let baseline = performance_json_number(fields.get("baseline")).unwrap_or(-1.0)
  let regression = performance_json_number(fields.get("maxRegressionPercent")).unwrap_or(
    -1.0,
  )
  let higher_is_better = performance_json_bool(fields.get("higherIsBetter")).unwrap_or(
    false,
  )
  if baseline < 0.0 {
    performance_push(failures, label + ".baseline must be non-negative")
  }
  if regression < 0.0 || regression > 100.0 {
    performance_push(
      failures,
      label + ".maxRegressionPercent must be in [0, 100]",
    )
  }
  Some({ baseline, max_regression_percent: regression, higher_is_better })
}

///|
fn performance_parse_scenario_budget(
  value : Json,
  scenario : String,
  failures : Array[String],
) -> ScenarioBudget? {
  let label = "scenarios." + scenario
  let fields = match performance_json_object(Some(value)) {
    Some(fields) => fields
    None => {
      performance_push(failures, label + " must be an object")
      return None
    }
  }
  let minimum_samples = performance_json_number(fields.get("minimumSamples"))
    .unwrap_or(0.0)
    .to_int()
  if minimum_samples < 5 {
    performance_push(failures, label + ".minimumSamples must be at least 5")
  }
  let timing_fields = performance_json_object(fields.get("timings")).unwrap_or(
    Map([]),
  )
  let timings : Map[String, PercentileBudget] = Map([])
  for metric in required_timing_metrics {
    match
      performance_parse_percentile_budget(
        timing_fields.get(metric),
        label + ".timings." + metric,
        failures,
      ) {
      Some(budget) => timings[metric] = budget
      None => ()
    }
  }
  if !performance_has_exact_keys(timing_fields, required_timing_metrics) {
    performance_push(
      failures,
      label +
      ".timings must contain exactly buildMs, layoutMs, paintMs, presentMs, and frameMs",
    )
  }
  let resource_fields = performance_json_object(fields.get("resources")).unwrap_or(
    Map([]),
  )
  let resources : Map[String, ResourceBudget] = Map([])
  for metric in required_resource_metrics {
    match
      performance_parse_resource_budget(
        resource_fields.get(metric),
        label + ".resources." + metric,
        failures,
      ) {
      Some(budget) => resources[metric] = budget
      None => ()
    }
  }
  if !performance_has_exact_keys(resource_fields, required_resource_metrics) {
    performance_push(
      failures,
      label +
      ".resources must contain exactly peakRssBytes, allocationCount, cacheHitRate, startupMs, and packageBytes",
    )
  }
  Some({ minimum_samples, timings, resources })
}

///|
fn performance_validate_update_policy(
  catalog : Map[String, Json],
  failures : Array[String],
) -> Unit {
  let policy = match performance_json_object(catalog.get("updatePolicy")) {
    Some(fields) => fields
    None => {
      performance_push(failures, "updatePolicy must be an object")
      return
    }
  }
  if performance_json_string(policy.get("owner")) is None {
    performance_push(failures, "updatePolicy.owner must be non-empty")
  }
  if performance_json_number(policy.get("requiredApprovals")).unwrap_or(0.0) <
    1.0 {
    performance_push(
      failures, "updatePolicy.requiredApprovals must be at least 1",
    )
  }
  if performance_json_bool(policy.get("reasonRequired")) != Some(true) {
    performance_push(failures, "updatePolicy.reasonRequired must be true")
  }
}

///|
fn performance_parse_catalog(
  text : String,
) -> Result[Map[String, ScenarioBudget], Array[String]] {
  let parsed = @json.parse(text) catch {
    _ => return Err(["performance budget catalog is invalid JSON"])
  }
  guard parsed is Json::Object(catalog) else {
    return Err(["performance budget catalog root must be an object"])
  }
  let failures : Array[String] = []
  if performance_json_number(catalog.get("schemaVersion")) != Some(1.0) {
    performance_push(failures, "schemaVersion must be 1")
  }
  if performance_json_string(catalog.get("runner")) !=
    Some(required_performance_runner) {
    performance_push(failures, "runner must be " + required_performance_runner)
  }
  performance_validate_update_policy(catalog, failures)
  let scenario_fields = performance_json_object(catalog.get("scenarios")).unwrap_or(
    Map([]),
  )
  let budgets : Map[String, ScenarioBudget] = Map([])
  for scenario in required_scenarios {
    match scenario_fields.get(scenario) {
      Some(value) =>
        match performance_parse_scenario_budget(value, scenario, failures) {
          Some(budget) => budgets[scenario] = budget
          None => ()
        }
      None =>
        performance_push(failures, "missing required scenario: " + scenario)
    }
  }
  if !performance_has_exact_keys(scenario_fields, required_scenarios) {
    performance_push(
      failures, "scenarios must contain exactly the five required P1 workloads",
    )
  }
  if failures.is_empty() {
    Ok(budgets)
  } else {
    Err(failures)
  }
}

///|
fn performance_validate_timing_samples(
  scenario : String,
  samples : Map[String, Json],
  budget : ScenarioBudget,
  failures : Array[String],
) -> Unit {
  for metric in required_timing_metrics {
    let label = scenario + ".samples." + metric
    let values = match performance_json_number_array(samples.get(metric)) {
      Some(values) => values
      None => {
        performance_push(failures, label + " must be a number array")
        continue
      }
    }
    if values.length() < budget.minimum_samples {
      performance_push(
        failures,
        label +
        " has \{values.length()} samples; expected at least \{budget.minimum_samples}",
      )
      continue
    }
    if values.any(value => value < 0.0) {
      performance_push(failures, label + " contains a negative duration")
      continue
    }
    guard budget.timings.get(metric) is Some(metric_budget) else { continue }
    let observed = [
      ("p50", performance_nearest_rank(values, 50), metric_budget.p50),
      ("p95", performance_nearest_rank(values, 95), metric_budget.p95),
      ("p99", performance_nearest_rank(values, 99), metric_budget.p99),
    ]
    for entry in observed {
      let (name, actual, baseline) = entry
      let limit = performance_limit(
        baseline,
        metric_budget.max_regression_percent,
      )
      if actual > limit {
        performance_push(
          failures,
          "\{scenario} \{metric} \{name}=\{actual}ms exceeds limit \{limit}ms (baseline \{baseline}ms)",
        )
      }
    }
  }
  if !performance_has_exact_keys(samples, required_timing_metrics) {
    performance_push(
      failures,
      scenario + ".samples must contain exactly the five timing metrics",
    )
  }
}

///|
fn performance_validate_resources(
  scenario : String,
  values : Map[String, Json],
  budget : ScenarioBudget,
  failures : Array[String],
) -> Unit {
  for metric in required_resource_metrics {
    let label = scenario + ".resources." + metric
    let actual = match performance_json_number(values.get(metric)) {
      Some(value) if value >= 0.0 => value
      _ => {
        performance_push(failures, label + " must be a non-negative number")
        continue
      }
    }
    guard budget.resources.get(metric) is Some(metric_budget) else { continue }
    if metric_budget.higher_is_better {
      let floor = performance_floor(
        metric_budget.baseline,
        metric_budget.max_regression_percent,
      )
      if actual < floor {
        performance_push(
          failures,
          "\{scenario} \{metric}=\{actual} is below floor \{floor} (baseline \{metric_budget.baseline})",
        )
      }
    } else {
      let limit = performance_limit(
        metric_budget.baseline,
        metric_budget.max_regression_percent,
      )
      if actual > limit {
        performance_push(
          failures,
          "\{scenario} \{metric}=\{actual} exceeds limit \{limit} (baseline \{metric_budget.baseline})",
        )
      }
    }
  }
  if !performance_has_exact_keys(values, required_resource_metrics) {
    performance_push(
      failures,
      scenario + ".resources must contain exactly the five resource metrics",
    )
  }
}

///|
fn performance_validate_results(
  text : String,
  budgets : Map[String, ScenarioBudget],
) -> Array[String] {
  let parsed = @json.parse(text) catch {
    _ => return ["performance results are invalid JSON"]
  }
  guard parsed is Json::Object(report) else {
    return ["performance results root must be an object"]
  }
  let failures : Array[String] = []
  if performance_json_number(report.get("schemaVersion")) != Some(1.0) {
    performance_push(failures, "results.schemaVersion must be 1")
  }
  if performance_json_string(report.get("runner")) !=
    Some(required_performance_runner) {
    performance_push(
      failures,
      "results.runner must be " + required_performance_runner,
    )
  }
  let result_scenarios = performance_json_object(report.get("scenarios")).unwrap_or(
    Map([]),
  )
  for scenario in required_scenarios {
    guard budgets.get(scenario) is Some(budget) else { continue }
    let result = match performance_json_object(result_scenarios.get(scenario)) {
      Some(fields) => fields
      None => {
        performance_push(failures, "results missing scenario: " + scenario)
        continue
      }
    }
    let samples = performance_json_object(result.get("samples")).unwrap_or(
      Map([]),
    )
    let resources = performance_json_object(result.get("resources")).unwrap_or(
      Map([]),
    )
    performance_validate_timing_samples(scenario, samples, budget, failures)
    performance_validate_resources(scenario, resources, budget, failures)
  }
  if !performance_has_exact_keys(result_scenarios, required_scenarios) {
    performance_push(
      failures, "results.scenarios must contain exactly the five required P1 workloads",
    )
  }
  failures
}
