///|
let valid_manifest =
  #|{
  #|  "schemaVersion": 1,
  #|  "mode": "golden",
  #|  "showcaseTarget": "examples/showcase/web_wasm",
  #|  "url": "http://127.0.0.1:18080/examples/showcase/web_wasm/",
  #|  "renderInspectorSource": "Showcase Diagnostics inspector snapshot card backed by @runtime.RenderInspectorSnapshot",
  #|  "renderInspectorCounters": [
  #|    "command_count",
  #|    "text_count",
  #|    "image_count",
  #|    "clip_depth",
  #|    "open_clip_depth",
  #|    "layer_depth",
  #|    "open_layer_depth",
  #|    "filter_depth",
  #|    "open_filter_depth",
  #|    "path_count",
  #|    "shader_count",
  #|    "unbalanced_pop_count"
  #|  ],
  #|  "screenshotArtifacts": [
  #|    {
  #|      "name": "desktop",
  #|      "viewport": "1440x900",
  #|      "path": "artifacts/golden/showcase-web-wasm/desktop.png"
  #|    },
  #|    {
  #|      "name": "tablet",
  #|      "viewport": "1024x768",
  #|      "path": "artifacts/golden/showcase-web-wasm/tablet.png"
  #|    },
  #|    {
  #|      "name": "mobile",
  #|      "viewport": "390x844",
  #|      "path": "artifacts/golden/showcase-web-wasm/mobile.png"
  #|    }
  #|  ],
  #|  "benchmarkMetrics": [
  #|    "startup_ms",
  #|    "frame_time_ms",
  #|    "dirty_count",
  #|    "draw_command_count",
  #|    "memory_bytes",
  #|    "render_inspector_counters"
  #|  ],
  #|  "notes": ["test fixture"]
  #|}

///|
let benchmark_targets =
  #|  "benchmarkTargets": [
  #|    {
  #|      "name": "showcase-web-wasm",
  #|      "target": "examples/showcase/web_wasm",
  #|      "url": "http://127.0.0.1:18080/examples/showcase/web_wasm/",
  #|      "metricsPath": "artifacts/benchmarks/showcase-web-wasm.json"
  #|    },
  #|    {
  #|      "name": "markdown-editor-web-wasm",
  #|      "target": "examples/markdown_editor/web_wasm",
  #|      "url": "http://127.0.0.1:18080/examples/markdown_editor/web_wasm/",
  #|      "metricsPath": "artifacts/benchmarks/markdown-editor-web-wasm.json"
  #|    }
  #|  ]

///|
fn benchmark_manifest() -> String {
  valid_manifest
  .replace(old="\"mode\": \"golden\"", new="\"mode\": \"benchmark\"")
  .replace(old="\n  \"notes\":", new=benchmark_targets + ",\n  \"notes\":")
}

///|
test "accepts valid golden manifest" {
  inspect(
    validate_manifest_text(valid_manifest, "golden").is_empty(),
    content="true",
  )
}

///|
test "accepts valid benchmark manifest" {
  inspect(
    validate_manifest_text(benchmark_manifest(), "benchmark").is_empty(),
    content="true",
  )
}

///|
test "rejects mode mismatch" {
  inspect(
    validate_manifest_text(benchmark_manifest(), "golden").contains(
      "mode must be 'golden'",
    ),
    content="true",
  )
}

///|
test "rejects missing inspector counter" {
  let manifest = valid_manifest.replace(
    old=",\n    \"unbalanced_pop_count\"",
    new="",
  )
  inspect(
    validate_manifest_text(manifest, "golden").contains(
      "renderInspectorCounters must include 'unbalanced_pop_count'",
    ),
    content="true",
  )
}

///|
test "rejects wrong mobile viewport" {
  let manifest = valid_manifest.replace(
    old="\"viewport\": \"390x844\"",
    new="\"viewport\": \"430x932\"",
  )
  let failures = validate_manifest_text(manifest, "golden")
  inspect(
    failures.contains(
      "screenshotArtifacts[2].viewport must be '390x844' for 'mobile'",
    ),
    content="true",
  )
}

///|
test "rejects missing benchmark targets field" {
  let manifest = valid_manifest.replace(
    old="\"mode\": \"golden\"",
    new="\"mode\": \"benchmark\"",
  )
  inspect(
    validate_manifest_text(manifest, "benchmark").contains(
      "field 'benchmarkTargets' must be an array",
    ),
    content="true",
  )
}

///|
test "rejects wrong benchmark metrics path" {
  let manifest = benchmark_manifest().replace(
    old="artifacts/benchmarks/markdown-editor-web-wasm.json",
    new="artifacts/conformance/markdown.json",
  )
  inspect(
    validate_manifest_text(manifest, "benchmark").contains(
      "benchmarkTargets[1].metricsPath must be 'artifacts/benchmarks/markdown-editor-web-wasm.json' for 'markdown-editor-web-wasm'",
    ),
    content="true",
  )
}
