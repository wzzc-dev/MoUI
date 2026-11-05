///|
test "nearest-rank percentiles are deterministic" {
  let values = [1.0, 10.0, 2.0, 9.0, 3.0, 8.0, 4.0, 7.0, 5.0, 6.0]
  inspect(performance_nearest_rank(values, 50), content="5")
  inspect(performance_nearest_rank(values, 95), content="10")
  inspect(performance_nearest_rank(values, 99), content="10")
}

///|
test "p99 ignores the single worst sample below 100-sample runs" {
  let values = [1.0, 10.0, 2.0, 9.0, 3.0, 8.0, 4.0, 7.0, 5.0, 200.0]
  inspect(performance_p99_nearest_rank(values), content="10")
  let long : Array[Double] = []
  for index in 0..<102 {
    long.push(index.to_double() + 1.0)
  }
  long.push(1000.0)
  inspect(performance_p99_nearest_rank(long), content="102")
}

///|
fn performance_test_timing_budget() -> String {
  let value =
    #|{"p50":10,"p95":20,"p99":30,"maxRegressionPercent":10}
  value
}

///|
fn performance_test_resource_low() -> String {
  let value =
    #|{"baseline":100,"maxRegressionPercent":10,"higherIsBetter":false}
  value
}

///|
fn performance_test_resource_high() -> String {
  let value =
    #|{"baseline":0.8,"maxRegressionPercent":10,"higherIsBetter":true}
  value
}

///|
fn performance_test_scenario_budget() -> String {
  let timing = performance_test_timing_budget()
  let resource_low = performance_test_resource_low()
  let resource_high = performance_test_resource_high()
  "{\"minimumSamples\":5,\"timings\":{\"buildMs\":\{timing},\"layoutMs\":\{timing},\"paintMs\":\{timing},\"drawMs\":\{timing},\"presentMs\":\{timing},\"frameMs\":\{timing},\"totalMs\":\{timing}},\"resources\":{\"peakRssBytes\":\{resource_low},\"allocationCount\":\{resource_low},\"cacheHitRate\":\{resource_high},\"startupMs\":\{resource_low},\"packageBytes\":\{resource_low}}}"
}

///|
fn performance_test_catalog_json() -> String {
  let scenario = performance_test_scenario_budget()
  let leaf =
    #|{"nodes":1001,"mapLayers":1,"maxNodeBuildsPerFrame":2,"minBuilderCacheHitRate":0.99,"maxBuilderCacheMissesPerFrame":1,"minRenderCacheHitRate":0.99}
  let scroll =
    #|{"minLayoutCacheHitRate":0.2,"maxLayoutCacheMissesPerFrame":20,"minRenderCacheHitRate":0.1,"maxRenderCacheMissesPerFrame":20}
  let structural = "{\"minimumFrames\":5,\"artifactRunsForReview\":2,\"varianceRule\":\"two matching-run artifacts before any timing ratchet\",\"leafScenarios\":{\"leaf-update-1k-builder-cache\":\{leaf},\"leaf-update-10k-builder-cache\":\{leaf}},\"scrollScenarios\":{\"showcase-runtime-scroll\":\{scroll}}}"
  "{\"schemaVersion\":2,\"runner\":\"native-skia-raster\",\"updatePolicy\":{\"owner\":\"runtime\",\"requiredApprovals\":1,\"reasonRequired\":true},\"structural\":\{structural},\"scenarios\":{\"showcase-runtime-scroll\":\{scenario},\"excel-grid-navigation\":\{scenario},\"virtual-list-100k\":\{scenario},\"multi-window-4\":\{scenario},\"deep-tree-env-toggle\":\{scenario}}}"
}

///|
fn performance_test_leaf_result(node_builds : Int32) -> String {
  "{\"nodes\":1001,\"frames\":5,\"mapLayers\":1,\"constructionMode\":\"builder-cache\",\"build\":{\"nodeBuilds\":\{node_builds}},\"builderCache\":{\"buildCount\":5,\"hitCount\":4995,\"missCount\":5,\"entryCount\":1000},\"cache\":{\"renderHits\":995,\"renderMisses\":5}}"
}

///|
fn performance_test_result_json(node_builds : Int32) -> String {
  performance_test_result_json_with_scroll_misses(
    node_builds,
    layout_misses=75,
    render_misses=80,
  )
}

///|
fn performance_test_result_json_with_scroll_misses(
  node_builds : Int32,
  layout_misses~ : Int32,
  render_misses~ : Int32,
) -> String {
  let samples =
    #|{"buildMs":[1,2,3,4,5],"layoutMs":[1,2,3,4,5],"paintMs":[1,2,3,4,5],"drawMs":[1,2,3,4,5],"presentMs":[1,2,3,4,5],"frameMs":[1,2,3,4,40],"totalMs":[1,2,3,4,5]}
  let resources =
    #|{"peakRssBytes":10,"allocationCount":10,"cacheHitRate":0.8,"startupMs":10,"packageBytes":10}
  let scroll_cache = "{\"layoutHits\":25,\"layoutMisses\":\{layout_misses},\"renderHits\":20,\"renderMisses\":\{render_misses}}"
  let slide = "{\"samples\":\{samples},\"resources\":\{resources}}"
  let scroll = "{\"samples\":\{samples},\"resources\":\{resources},\"cache\":\{scroll_cache}}"
  let leaf = performance_test_leaf_result(node_builds)
  let leaf_scenarios = "{\"leaf-update-1k-builder-cache\":\{leaf},\"leaf-update-10k-builder-cache\":\{leaf}}"
  "{\"schemaVersion\":1,\"runner\":\"native-skia-raster\",\"scenarios\":{\"showcase-runtime-scroll\":\{scroll},\"excel-grid-navigation\":\{slide},\"virtual-list-100k\":\{slide},\"multi-window-4\":\{slide},\"deep-tree-env-toggle\":\{slide}},\"leafUpdate\":{\"schemaVersion\":2,\"scenarios\":\{leaf_scenarios}}}"
}

///|
test "catalog and results enforce percentile regressions" {
  guard performance_parse_catalog(performance_test_catalog_json())
    is Ok(catalog) else {
    fail("expected catalog to parse")
  }
  let failures = performance_validate_results(
    performance_test_result_json(10),
    catalog,
  )
  assert_true(
    failures.any(message => message.contains("frameMs p95=40ms exceeds")),
  )
}

///|
test "structural-only gate ignores shared-runner timing noise" {
  guard performance_parse_catalog(performance_test_catalog_json())
    is Ok(catalog) else {
    fail("expected catalog to parse")
  }
  let failures = performance_validate_structural_results_only(
    performance_test_result_json(10),
    catalog,
  )
  assert_eq(failures, [])
}

///|
test "structural gate rejects whole-tree leaf rebuilding" {
  guard performance_parse_catalog(performance_test_catalog_json())
    is Ok(catalog) else {
    fail("expected catalog to parse")
  }
  let failures = performance_validate_structural_results_only(
    performance_test_result_json(15),
    catalog,
  )
  assert_true(failures.any(message => message.contains("nodeBuildsPerFrame=3")))
}

///|
test "structural gate rejects absolute scroll cache regressions" {
  guard performance_parse_catalog(performance_test_catalog_json())
    is Ok(catalog) else {
    fail("expected catalog to parse")
  }
  let failures = performance_validate_structural_results_only(
    performance_test_result_json_with_scroll_misses(
      10,
      layout_misses=125,
      render_misses=80,
    ),
    catalog,
  )
  assert_true(
    failures.any(message => message.contains("layoutMissesPerFrame=25")),
  )
}

///|
test "structural catalog requires evidence retention and complete workloads" {
  let incomplete =
    #|{"schemaVersion":2,"runner":"native-skia-raster","updatePolicy":{"owner":"runtime","requiredApprovals":1,"reasonRequired":true},"structural":{"minimumFrames":5,"artifactRunsForReview":1,"varianceRule":"","leafScenarios":{},"scrollScenarios":{}},"scenarios":{}}
  let failures = match performance_parse_catalog(incomplete) {
    Ok(_) => []
    Err(failures) => failures
  }
  assert_true(
    failures.any(message => {
      message.contains("artifactRunsForReview must be at least 2")
    }),
  )
  assert_true(
    failures.any(message => message.contains("varianceRule must describe")),
  )
  assert_true(
    failures.any(message => message.contains("leafScenarios missing scenario")),
  )
}
