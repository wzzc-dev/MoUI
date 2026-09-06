///|
test "nearest-rank percentiles are deterministic" {
  let values = [1.0, 10.0, 2.0, 9.0, 3.0, 8.0, 4.0, 7.0, 5.0, 6.0]
  inspect(performance_nearest_rank(values, 50), content="5")
  inspect(performance_nearest_rank(values, 95), content="10")
  inspect(performance_nearest_rank(values, 99), content="10")
}

///|
test "catalog and results enforce percentile regressions" {
  let timing =
    #|{"p50":10,"p95":20,"p99":30,"maxRegressionPercent":10}
  let resource_low =
    #|{"baseline":100,"maxRegressionPercent":10,"higherIsBetter":false}
  let resource_high =
    #|{"baseline":0.8,"maxRegressionPercent":10,"higherIsBetter":true}
  let scenario = "{\"minimumSamples\":5,\"timings\":{\"buildMs\":\{timing},\"layoutMs\":\{timing},\"paintMs\":\{timing},\"presentMs\":\{timing},\"frameMs\":\{timing}},\"resources\":{\"peakRssBytes\":\{resource_low},\"allocationCount\":\{resource_low},\"cacheHitRate\":\{resource_high},\"startupMs\":\{resource_low},\"packageBytes\":\{resource_low}}}"
  let catalog = "{\"schemaVersion\":1,\"runner\":\"native-skia-raster\",\"updatePolicy\":{\"owner\":\"runtime\",\"requiredApprovals\":1,\"reasonRequired\":true},\"scenarios\":{\"showcase-runtime-scroll\":\{scenario},\"markdown-editor-text-input\":\{scenario},\"excel-grid-navigation\":\{scenario},\"virtual-list-100k\":\{scenario},\"multi-window-4\":\{scenario},\"deep-tree-env-toggle\":\{scenario}}}"
  guard performance_parse_catalog(catalog) is Ok(budgets) else {
    fail("expected catalog to parse")
  }
  let samples =
    #|{"buildMs":[1,2,3,4,5],"layoutMs":[1,2,3,4,5],"paintMs":[1,2,3,4,5],"presentMs":[1,2,3,4,5],"frameMs":[1,2,3,4,40]}
  let resources =
    #|{"peakRssBytes":10,"allocationCount":10,"cacheHitRate":0.8,"startupMs":10,"packageBytes":10}
  let result = "{\"samples\":\{samples},\"resources\":\{resources}}"
  let report = "{\"schemaVersion\":1,\"runner\":\"native-skia-raster\",\"scenarios\":{\"showcase-runtime-scroll\":\{result},\"markdown-editor-text-input\":\{result},\"excel-grid-navigation\":\{result},\"virtual-list-100k\":\{result},\"multi-window-4\":\{result},\"deep-tree-env-toggle\":\{result}}}"
  let failures = performance_validate_results(report, budgets)
  assert_true(
    failures.any(message => message.contains("frameMs p95=40ms exceeds")),
  )
}
