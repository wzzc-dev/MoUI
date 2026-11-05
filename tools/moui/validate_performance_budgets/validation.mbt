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
  Some({ p50, p95, p99, max_regression_percent: regression, })
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
  Some({ baseline, max_regression_percent: regression, higher_is_better, })
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
      label + ".timings must contain exactly " + required_timing_metric_label,
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
  Some({ minimum_samples, timings, resources, })
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
fn performance_parse_leaf_structural_budget(
  value : Json?,
  label : String,
  failures : Array[String],
) -> LeafStructuralBudget? {
  let fields = match performance_json_object(value) {
    Some(fields) => fields
    None => {
      performance_push(failures, label + " must be an object")
      return None
    }
  }
  let nodes = performance_json_number(fields.get("nodes"))
    .unwrap_or(-1.0)
    .to_int()
  let map_layers = performance_json_number(fields.get("mapLayers"))
    .unwrap_or(-1.0)
    .to_int()
  let max_node_builds_per_frame = performance_json_number(
    fields.get("maxNodeBuildsPerFrame"),
  ).unwrap_or(-1.0)
  let min_builder_cache_hit_rate = performance_json_number(
    fields.get("minBuilderCacheHitRate"),
  ).unwrap_or(-1.0)
  let max_builder_cache_misses_per_frame = performance_json_number(
    fields.get("maxBuilderCacheMissesPerFrame"),
  ).unwrap_or(-1.0)
  let min_render_cache_hit_rate = performance_json_number(
    fields.get("minRenderCacheHitRate"),
  ).unwrap_or(-1.0)
  if nodes < 2 {
    performance_push(failures, label + ".nodes must be at least 2")
  }
  if map_layers < 1 {
    performance_push(failures, label + ".mapLayers must be at least 1")
  }
  if max_node_builds_per_frame < 0.0 {
    performance_push(
      failures,
      label + ".maxNodeBuildsPerFrame must be non-negative",
    )
  }
  if min_builder_cache_hit_rate < 0.0 || min_builder_cache_hit_rate > 1.0 {
    performance_push(
      failures,
      label + ".minBuilderCacheHitRate must be in [0, 1]",
    )
  }
  if max_builder_cache_misses_per_frame < 0.0 {
    performance_push(
      failures,
      label + ".maxBuilderCacheMissesPerFrame must be non-negative",
    )
  }
  if min_render_cache_hit_rate < 0.0 || min_render_cache_hit_rate > 1.0 {
    performance_push(
      failures,
      label + ".minRenderCacheHitRate must be in [0, 1]",
    )
  }
  Some({
    nodes,
    map_layers,
    max_node_builds_per_frame,
    min_builder_cache_hit_rate,
    max_builder_cache_misses_per_frame,
    min_render_cache_hit_rate,
  })
}

///|
fn performance_parse_scroll_structural_budget(
  value : Json?,
  label : String,
  failures : Array[String],
) -> ScrollStructuralBudget? {
  let fields = match performance_json_object(value) {
    Some(fields) => fields
    None => {
      performance_push(failures, label + " must be an object")
      return None
    }
  }
  let min_layout_cache_hit_rate = performance_json_number(
    fields.get("minLayoutCacheHitRate"),
  ).unwrap_or(-1.0)
  let max_layout_cache_misses_per_frame = performance_json_number(
    fields.get("maxLayoutCacheMissesPerFrame"),
  ).unwrap_or(-1.0)
  let min_render_cache_hit_rate = performance_json_number(
    fields.get("minRenderCacheHitRate"),
  ).unwrap_or(-1.0)
  let max_render_cache_misses_per_frame = performance_json_number(
    fields.get("maxRenderCacheMissesPerFrame"),
  ).unwrap_or(-1.0)
  if min_layout_cache_hit_rate < 0.0 || min_layout_cache_hit_rate > 1.0 {
    performance_push(
      failures,
      label + ".minLayoutCacheHitRate must be in [0, 1]",
    )
  }
  if max_layout_cache_misses_per_frame < 0.0 {
    performance_push(
      failures,
      label + ".maxLayoutCacheMissesPerFrame must be non-negative",
    )
  }
  if min_render_cache_hit_rate < 0.0 || min_render_cache_hit_rate > 1.0 {
    performance_push(
      failures,
      label + ".minRenderCacheHitRate must be in [0, 1]",
    )
  }
  if max_render_cache_misses_per_frame < 0.0 {
    performance_push(
      failures,
      label + ".maxRenderCacheMissesPerFrame must be non-negative",
    )
  }
  Some({
    min_layout_cache_hit_rate,
    max_layout_cache_misses_per_frame,
    min_render_cache_hit_rate,
    max_render_cache_misses_per_frame,
  })
}

///|
fn performance_parse_structural_budget(
  catalog : Map[String, Json],
  failures : Array[String],
) -> StructuralBudget {
  let fields = match performance_json_object(catalog.get("structural")) {
    Some(fields) => fields
    None => {
      performance_push(failures, "structural must be an object")
      return {
        minimum_frames: 0,
        leaf_scenarios: Map([]),
        scroll_scenarios: Map([]),
      }
    }
  }
  let minimum_frames = performance_json_number(fields.get("minimumFrames"))
    .unwrap_or(0.0)
    .to_int()
  let artifact_runs_for_review = performance_json_number(
      fields.get("artifactRunsForReview"),
    )
    .unwrap_or(0.0)
    .to_int()
  let variance_rule = performance_json_string(fields.get("varianceRule")).unwrap_or(
    "",
  )
  if minimum_frames < 5 {
    performance_push(failures, "structural.minimumFrames must be at least 5")
  }
  if artifact_runs_for_review < 2 {
    performance_push(
      failures, "structural.artifactRunsForReview must be at least 2",
    )
  }
  if variance_rule == "" {
    performance_push(
      failures, "structural.varianceRule must describe the ratchet evidence",
    )
  }
  let leaf_fields = performance_json_object(fields.get("leafScenarios")).unwrap_or(
    Map([]),
  )
  let leaf_scenarios : Map[String, LeafStructuralBudget] = Map([])
  for scenario in required_structural_leaf_scenarios {
    match leaf_fields.get(scenario) {
      Some(value) =>
        match
          performance_parse_leaf_structural_budget(
            Some(value),
            "structural.leafScenarios." + scenario,
            failures,
          ) {
          Some(budget) => leaf_scenarios[scenario] = budget
          None => ()
        }
      None =>
        performance_push(
          failures,
          "structural.leafScenarios missing scenario: " + scenario,
        )
    }
  }
  if !performance_has_exact_keys(
      leaf_fields, required_structural_leaf_scenarios,
    ) {
    performance_push(
      failures, "structural.leafScenarios must contain exactly the required builder-cache workloads",
    )
  }
  let scroll_fields = performance_json_object(fields.get("scrollScenarios")).unwrap_or(
    Map([]),
  )
  let scroll_scenarios : Map[String, ScrollStructuralBudget] = Map([])
  for scenario in required_structural_scroll_scenarios {
    match scroll_fields.get(scenario) {
      Some(value) =>
        match
          performance_parse_scroll_structural_budget(
            Some(value),
            "structural.scrollScenarios." + scenario,
            failures,
          ) {
          Some(budget) => scroll_scenarios[scenario] = budget
          None => ()
        }
      None =>
        performance_push(
          failures,
          "structural.scrollScenarios missing scenario: " + scenario,
        )
    }
  }
  if !performance_has_exact_keys(
      scroll_fields, required_structural_scroll_scenarios,
    ) {
    performance_push(
      failures, "structural.scrollScenarios must contain exactly the required scroll workloads",
    )
  }
  { minimum_frames, leaf_scenarios, scroll_scenarios, }
}

///|
fn performance_parse_catalog(
  text : String,
) -> Result[PerformanceCatalog, Array[String]] {
  let parsed = @json.parse(text) catch {
    _ => return Err(["performance budget catalog is invalid JSON"])
  }
  guard parsed is Json::Object(catalog) else {
    return Err(["performance budget catalog root must be an object"])
  }
  let failures : Array[String] = []
  if performance_json_number(catalog.get("schemaVersion")) != Some(2.0) {
    performance_push(failures, "schemaVersion must be 2")
  }
  if performance_json_string(catalog.get("runner")) !=
    Some(required_performance_runner) {
    performance_push(failures, "runner must be " + required_performance_runner)
  }
  performance_validate_update_policy(catalog, failures)
  let structural = performance_parse_structural_budget(catalog, failures)
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
    Ok({ scenarios: budgets, structural, })
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
      ("p99", performance_p99_nearest_rank(values), metric_budget.p99),
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
      scenario + ".samples must contain exactly " + required_timing_metric_label,
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
fn performance_cache_hit_rate(hits : Double, misses : Double) -> Double {
  let total = hits + misses
  if total <= 0.0 {
    0.0
  } else {
    hits / total
  }
}

///|
fn performance_parse_result_root(
  text : String,
) -> Result[Map[String, Json], Array[String]] {
  let parsed = @json.parse(text) catch {
    _ => return Err(["performance results are invalid JSON"])
  }
  guard parsed is Json::Object(report) else {
    return Err(["performance results root must be an object"])
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
  if failures.is_empty() {
    Ok(report)
  } else {
    Err(failures)
  }
}

///|
fn performance_validate_timing_and_resource_results(
  report : Map[String, Json],
  budgets : Map[String, ScenarioBudget],
  failures : Array[String],
) -> Unit {
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
}

///|
fn performance_validate_leaf_structural_result(
  scenario : String,
  result : Map[String, Json],
  budget : LeafStructuralBudget,
  minimum_frames : Int32,
  failures : Array[String],
) -> Unit {
  let label = "leafUpdate.scenarios." + scenario
  let frames = performance_json_number(result.get("frames"))
    .unwrap_or(-1.0)
    .to_int()
  let nodes = performance_json_number(result.get("nodes"))
    .unwrap_or(-1.0)
    .to_int()
  let map_layers = performance_json_number(result.get("mapLayers"))
    .unwrap_or(-1.0)
    .to_int()
  if frames < minimum_frames {
    performance_push(
      failures,
      "\{label}.frames=\{frames} is below minimum \{minimum_frames}",
    )
  }
  if nodes != budget.nodes {
    performance_push(
      failures,
      "\{label}.nodes=\{nodes} expected \{budget.nodes}",
    )
  }
  if map_layers != budget.map_layers {
    performance_push(
      failures,
      "\{label}.mapLayers=\{map_layers} expected \{budget.map_layers}",
    )
  }
  match performance_json_string(result.get("constructionMode")) {
    Some("builder-cache") => ()
    Some(mode) =>
      performance_push(
        failures,
        label + ".constructionMode=\"" + mode + "\" expected \"builder-cache\"",
      )
    None =>
      performance_push(failures, label + ".constructionMode must be a string")
  }
  let build = performance_json_object(result.get("build")).unwrap_or(Map([]))
  let builder_cache = performance_json_object(result.get("builderCache")).unwrap_or(
    Map([]),
  )
  let cache = performance_json_object(result.get("cache")).unwrap_or(Map([]))
  let node_builds = performance_json_number(build.get("nodeBuilds")).unwrap_or(
    -1.0,
  )
  let builder_builds = performance_json_number(builder_cache.get("buildCount")).unwrap_or(
    -1.0,
  )
  let builder_hits = performance_json_number(builder_cache.get("hitCount")).unwrap_or(
    -1.0,
  )
  let builder_misses = performance_json_number(builder_cache.get("missCount")).unwrap_or(
    -1.0,
  )
  let builder_entries = performance_json_number(builder_cache.get("entryCount"))
    .unwrap_or(-1.0)
    .to_int()
  let render_hits = performance_json_number(cache.get("renderHits")).unwrap_or(
    -1.0,
  )
  let render_misses = performance_json_number(cache.get("renderMisses")).unwrap_or(
    -1.0,
  )
  if frames <= 0 {
    performance_push(failures, label + ".frames must be positive")
    return
  }
  if node_builds < 0.0 {
    performance_push(failures, label + ".build.nodeBuilds must be non-negative")
  } else {
    let per_frame = node_builds / frames.to_double()
    if per_frame > budget.max_node_builds_per_frame {
      performance_push(
        failures,
        "\{label}.build.nodeBuildsPerFrame=\{per_frame} exceeds limit \{budget.max_node_builds_per_frame}",
      )
    }
  }
  if builder_builds < 0.0 || builder_hits < 0.0 || builder_misses < 0.0 {
    performance_push(
      failures,
      label + ".builderCache counters must be non-negative",
    )
  } else {
    if builder_builds != builder_misses {
      performance_push(
        failures,
        "\{label}.builderCache.buildCount=\{builder_builds} expected missCount=\{builder_misses}",
      )
    }
    let misses_per_frame = builder_misses / frames.to_double()
    if misses_per_frame > budget.max_builder_cache_misses_per_frame {
      performance_push(
        failures,
        "\{label}.builderCache.missesPerFrame=\{misses_per_frame} exceeds limit \{budget.max_builder_cache_misses_per_frame}",
      )
    }
    let hit_rate = performance_cache_hit_rate(builder_hits, builder_misses)
    if hit_rate < budget.min_builder_cache_hit_rate {
      performance_push(
        failures,
        "\{label}.builderCache.hitRate=\{hit_rate} is below floor \{budget.min_builder_cache_hit_rate}",
      )
    }
  }
  if builder_entries != budget.nodes - 1 {
    performance_push(
      failures,
      "\{label}.builderCache.entryCount=\{builder_entries} expected \{budget.nodes - 1}",
    )
  }
  if render_hits < 0.0 || render_misses < 0.0 {
    performance_push(
      failures,
      label + ".cache render counters must be non-negative",
    )
  } else {
    let render_hit_rate = performance_cache_hit_rate(render_hits, render_misses)
    if render_hit_rate < budget.min_render_cache_hit_rate {
      performance_push(
        failures,
        "\{label}.cache.renderHitRate=\{render_hit_rate} is below floor \{budget.min_render_cache_hit_rate}",
      )
    }
  }
}

///|
fn performance_validate_scroll_structural_result(
  scenario : String,
  result : Map[String, Json],
  budget : ScrollStructuralBudget,
  minimum_frames : Int32,
  failures : Array[String],
) -> Unit {
  let label = "scenarios." + scenario
  let samples = performance_json_object(result.get("samples")).unwrap_or(
    Map([]),
  )
  let frame_samples = performance_json_number_array(samples.get("frameMs")).unwrap_or([],
  )
  if frame_samples.length() < minimum_frames {
    performance_push(
      failures,
      "\{label}.samples.frameMs has \{frame_samples.length()} samples; expected at least \{minimum_frames}",
    )
  }
  let frame_count = frame_samples.length().to_double()
  let cache = performance_json_object(result.get("cache")).unwrap_or(Map([]))
  let layout_hits = performance_json_number(cache.get("layoutHits")).unwrap_or(
    -1.0,
  )
  let layout_misses = performance_json_number(cache.get("layoutMisses")).unwrap_or(
    -1.0,
  )
  let render_hits = performance_json_number(cache.get("renderHits")).unwrap_or(
    -1.0,
  )
  let render_misses = performance_json_number(cache.get("renderMisses")).unwrap_or(
    -1.0,
  )
  if layout_hits < 0.0 ||
    layout_misses < 0.0 ||
    render_hits < 0.0 ||
    render_misses < 0.0 {
    performance_push(failures, label + ".cache counters must be non-negative")
    return
  }
  let layout_hit_rate = performance_cache_hit_rate(layout_hits, layout_misses)
  let render_hit_rate = performance_cache_hit_rate(render_hits, render_misses)
  if frame_count > 0.0 {
    let layout_misses_per_frame = layout_misses / frame_count
    if layout_misses_per_frame > budget.max_layout_cache_misses_per_frame {
      performance_push(
        failures,
        "\{label}.cache.layoutMissesPerFrame=\{layout_misses_per_frame} exceeds limit \{budget.max_layout_cache_misses_per_frame}",
      )
    }
    let render_misses_per_frame = render_misses / frame_count
    if render_misses_per_frame > budget.max_render_cache_misses_per_frame {
      performance_push(
        failures,
        "\{label}.cache.renderMissesPerFrame=\{render_misses_per_frame} exceeds limit \{budget.max_render_cache_misses_per_frame}",
      )
    }
  }
  if layout_hit_rate < budget.min_layout_cache_hit_rate {
    performance_push(
      failures,
      "\{label}.cache.layoutHitRate=\{layout_hit_rate} is below floor \{budget.min_layout_cache_hit_rate}",
    )
  }
  if render_hit_rate < budget.min_render_cache_hit_rate {
    performance_push(
      failures,
      "\{label}.cache.renderHitRate=\{render_hit_rate} is below floor \{budget.min_render_cache_hit_rate}",
    )
  }
}

///|
fn performance_validate_structural_results(
  report : Map[String, Json],
  structural : StructuralBudget,
  failures : Array[String],
) -> Unit {
  let leaf_update = match performance_json_object(report.get("leafUpdate")) {
    Some(fields) => fields
    None => {
      performance_push(failures, "results.leafUpdate must be an object")
      Map([])
    }
  }
  if performance_json_number(leaf_update.get("schemaVersion")) != Some(2.0) {
    performance_push(failures, "results.leafUpdate.schemaVersion must be 2")
  }
  let leaf_scenarios = performance_json_object(leaf_update.get("scenarios")).unwrap_or(
    Map([]),
  )
  for scenario in required_structural_leaf_scenarios {
    guard structural.leaf_scenarios.get(scenario) is Some(budget) else {
      continue
    }
    match performance_json_object(leaf_scenarios.get(scenario)) {
      Some(result) =>
        performance_validate_leaf_structural_result(
          scenario,
          result,
          budget,
          structural.minimum_frames,
          failures,
        )
      None =>
        performance_push(
          failures,
          "results.leafUpdate.scenarios missing scenario: " + scenario,
        )
    }
  }
  let scenario_results = performance_json_object(report.get("scenarios")).unwrap_or(
    Map([]),
  )
  for scenario in required_structural_scroll_scenarios {
    guard structural.scroll_scenarios.get(scenario) is Some(budget) else {
      continue
    }
    match performance_json_object(scenario_results.get(scenario)) {
      Some(result) =>
        performance_validate_scroll_structural_result(
          scenario,
          result,
          budget,
          structural.minimum_frames,
          failures,
        )
      None =>
        performance_push(
          failures,
          "results.scenarios missing scenario: " + scenario,
        )
    }
  }
}

///|
fn performance_validate_results(
  text : String,
  catalog : PerformanceCatalog,
) -> Array[String] {
  let report = match performance_parse_result_root(text) {
    Ok(report) => report
    Err(failures) => return failures
  }
  let failures : Array[String] = []
  performance_validate_timing_and_resource_results(
    report,
    catalog.scenarios,
    failures,
  )
  performance_validate_structural_results(report, catalog.structural, failures)
  failures
}

///|
fn performance_validate_structural_results_only(
  text : String,
  catalog : PerformanceCatalog,
) -> Array[String] {
  let report = match performance_parse_result_root(text) {
    Ok(report) => report
    Err(failures) => return failures
  }
  let failures : Array[String] = []
  performance_validate_structural_results(report, catalog.structural, failures)
  failures
}
