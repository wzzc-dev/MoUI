///|
let valid_manifest =
  #|{
  #|  "schemaVersion": 1,
  #|  "mode": "web-runtime-presentation",
  #|  "generatedBy": "scripts/record-web-runtime-presentation.mjs",
  #|  "baseUrl": "http://127.0.0.1:18080",
  #|  "cdpUrl": "http://127.0.0.1:9223",
  #|  "overallStatus": "passed",
  #|  "evidenceBoundary": "Browser-local WebGPU, wasm app startup, canvas sizing, resize/input event-bridge, target close, and screenshot evidence for the named browser session; this does not prove cross-browser compatibility, deterministic pixels, or native platform runtime behavior.",
  #|  "browser": {
  #|    "product": "Chrome/148.0.7778.216",
  #|    "userAgent": "Mozilla/5.0 HeadlessChrome/148.0.0.0",
  #|    "protocolVersion": "1.3"
  #|  },
  #|  "platformObservations": {
  #|    "windowOpened": "yes",
  #|    "resizeRedraw": "yes",
  #|    "representativeInput": "yes",
  #|    "cleanExit": "yes",
  #|    "surface": "yes",
  #|    "redraw": "yes",
  #|    "resizeScale": "yes",
  #|    "consumerInput": "yes",
  #|    "textInput": "yes",
  #|    "rendererHandle": "yes",
  #|    "cleanShutdown": "yes"
  #|  },
  #|  "targets": [
  #|    {
  #|      "name": "showcase-web-wasm",
  #|      "packagePath": "examples/showcase/web_wasm",
  #|      "path": "examples/showcase/web_wasm/index.html",
  #|      "url": "http://127.0.0.1:18080/examples/showcase/web_wasm/index.html?debug=1&section=advanced-rendering",
  #|      "status": "passed",
  #|      "title": "MoUI Showcase Wasm GC",
  #|      "statusText": "Running",
  #|      "bodyFailed": false,
  #|      "navigatorGpu": true,
  #|      "canvas": {
  #|        "count": 1,
  #|        "hostWidth": 1280,
  #|        "hostHeight": 800,
  #|        "canvasWidth": 1280,
  #|        "canvasHeight": 800
  #|      },
  #|      "runtimeSignals": {
  #|        "adapterRequested": true,
  #|        "deviceRequested": true,
  #|        "wasmStarted": true,
  #|        "running": true
  #|      },
  #|      "screenshot": {
  #|        "artifact": "artifacts/conformance/web-runtime-presentation/showcase-web-wasm.png",
  #|        "width": 1280,
  #|        "height": 800,
  #|        "totalPixels": 1024000,
  #|        "contentPixels": 50000,
  #|        "distinctColorBuckets": 18,
  #|        "transformPixels": {
  #|          "required": true,
  #|          "passed": true,
  #|          "hotPinkPixels": 72,
  #|          "cyanPixels": 96,
  #|          "goldPixels": 18,
  #|          "matchedMarkers": 3
  #|        },
  #|        "radialGradient": {
  #|          "required": true,
  #|          "passed": true,
  #|          "evidence": ["center-mid-edge-pixels", "shader-payload"],
  #|          "matchedMarkers": 2
  #|        },
  #|        "colorEmojiPixels": {
  #|          "required": true,
  #|          "passed": true,
  #|          "evidence": ["high-saturation-pixels", "glyph-or-raster", "font-metadata", "glyph-metadata"],
  #|          "matchedMarkers": 4,
  #|          "glyphHighSaturationPixels": 42,
  #|          "glyphAlphaPixels": 120,
  #|          "metadata": {
  #|            "font": {
  #|              "family": "system-ui, emoji",
  #|              "source": "browser-canvas",
  #|              "textSystem": "webgpu-wasm"
  #|            },
  #|            "glyph": {
  #|              "format": "rgba",
  #|              "glyphCount": 1,
  #|              "clusterCount": 1,
  #|              "highSaturationPixels": 42,
  #|              "alphaPixels": 120,
  #|              "key": "1|normal|400|24|system-ui|rgba|\\ud83d\\udc69\\u200d\\ud83d\\udcbb",
  #|              "width": 24,
  #|              "height": 24
  #|            }
  #|          }
  #|        },
  #|        "zwjGrapheme": {
  #|          "required": true,
  #|          "passed": true,
  #|          "evidence": ["single-grapheme-cluster", "no-interior-caret"],
  #|          "matchedMarkers": 2,
  #|          "logicalClusters": 1,
  #|          "visualClusters": 1
  #|        },
  #|        "bidiLayout": {
  #|          "required": true,
  #|          "passed": true,
  #|          "evidence": ["visual-order"],
  #|          "matchedMarkers": 1,
  #|          "logicalClusters": ["A", "B", "C", " ", "\\u05d0", "\\u05d1", "\\u05d2"],
  #|          "visualClusters": ["A", "B", "C", " ", "\\u05d2", "\\u05d1", "\\u05d0"]
  #|        },
  #|        "paragraphWrapping": {
  #|          "required": true,
  #|          "passed": true,
  #|          "evidence": ["line-metrics", "later-line-pixels"],
  #|          "matchedMarkers": 2,
  #|          "paragraphLineCount": 3,
  #|          "paragraphRows": 3,
  #|          "darkRows": 8
  #|        },
  #|        "selectionRects": {
  #|          "required": true,
  #|          "passed": true,
  #|          "evidence": ["selection-rects", "line-range"],
  #|          "matchedMarkers": 2
  #|        },
  #|        "graphemeEditing": {
  #|          "required": true,
  #|          "passed": true,
  #|          "evidence": ["grapheme-boundaries", "edit-actions"],
  #|          "matchedMarkers": 2
  #|        },
  #|        "imeCandidateAnchor": {
  #|          "required": true,
  #|          "passed": true,
  #|          "evidence": ["candidate-anchor", "surrounding-text"],
  #|          "matchedMarkers": 2
  #|        },
  #|        "imeCompositionVisual": {
  #|          "required": true,
  #|          "passed": true,
  #|          "evidence": ["composition-range", "preedit-pixels"],
  #|          "matchedMarkers": 2
  #|        },
  #|        "asyncImageSecondFrame": {
  #|          "required": true,
  #|          "passed": true,
  #|          "evidence": ["late-completion", "repaint-request", "second-frame-pixels"],
  #|          "matchedMarkers": 3,
  #|          "eventIndexes": {
  #|            "placeholder": 4,
  #|            "load": 6,
  #|            "change": 7,
  #|            "repaint": 8,
  #|            "ready": 10,
  #|            "present": [5, 11]
  #|          }
  #|        }
  #|      },
  #|      "evidenceEvents": [
  #|        { "kind": 10, "name": "resize" },
  #|        { "kind": 23, "name": "pointer_down" },
  #|        { "kind": 40, "name": "key_down" },
  #|        { "kind": 42, "name": "ime_commit" },
  #|        { "kind": 94, "name": "text_color_glyph" },
  #|        { "kind": 95, "name": "text_grapheme_layout" },
  #|        { "kind": 96, "name": "text_bidi_layout" },
  #|        { "kind": 97, "name": "text_paragraph_line" },
  #|        { "kind": 98, "name": "image_placeholder_frame" },
  #|        { "kind": 100, "name": "present_frame" },
  #|        { "kind": 90, "name": "image_load" },
  #|        { "kind": 92, "name": "image_resource_change" },
  #|        { "kind": 93, "name": "image_repaint_request" },
  #|        { "kind": 99, "name": "image_ready_frame" },
  #|        { "kind": 100, "name": "present_frame" }
  #|      ],
  #|      "observations": {
  #|        "pageLoaded": "yes",
  #|        "webGpuAvailable": "yes",
  #|        "adapterRequested": "yes",
  #|        "deviceRequested": "yes",
  #|        "wasmStarted": "yes",
  #|        "statusRunning": "yes",
  #|        "canvasCreated": "yes",
  #|        "canvasSized": "yes",
  #|        "nonblankScreenshot": "yes",
  #|        "cleanConsole": "yes",
  #|        "resizeEvent": "yes",
  #|        "resizedCanvas": "yes",
  #|        "pointerInput": "yes",
  #|        "keyboardInput": "yes",
  #|        "textInput": "yes",
  #|        "radialGradient": "yes",
  #|        "transformPixels": "yes",
  #|        "colorEmojiPixels": "yes",
  #|        "zwjGrapheme": "yes",
  #|        "bidiLayout": "yes",
  #|        "paragraphWrapping": "yes",
  #|        "selectionRects": "yes",
  #|        "graphemeEditing": "yes",
  #|        "imeCandidateAnchor": "yes",
  #|        "imeCompositionVisual": "yes",
  #|        "asyncImageSecondFrame": "yes",
  #|        "targetClosed": "yes"
  #|      },
  #|      "consoleErrors": [],
  #|      "notes": ["browser evidence captured"]
  #|    }
  #|  ]
  #|}

///|
test "accepts valid web runtime presentation manifest" {
  inspect(validate_manifest_text(valid_manifest).is_empty(), content="true")
  inspect(
    validate_manifest_text_with_options(valid_manifest, true).is_empty(),
    content="true",
  )
}

///|
test "rejects missing expected target" {
  let manifest = valid_manifest.replace(
    old="\"name\": \"showcase-web-wasm\"",
    new="\"name\": \"other-web-wasm\"",
  )
  inspect(
    validate_manifest_text(manifest).contains(
      "targets must include 'showcase-web-wasm'",
    ),
    content="true",
  )
}

///|
test "rejects weak evidence boundary" {
  let manifest = valid_manifest.replace(
    old="Browser-local WebGPU, wasm app startup, canvas sizing, resize/input event-bridge, target close, and screenshot evidence for the named browser session; this does not prove cross-browser compatibility, deterministic pixels, or native platform runtime behavior.",
    new="Browser smoke.",
  )
  inspect(
    validate_manifest_text(manifest).contains(
      "evidenceBoundary must include 'WebGPU'",
    ),
    content="true",
  )
}

///|
test "rejects failed platform observation on passed manifest" {
  let manifest = valid_manifest.replace(
    old="\"resizeRedraw\": \"yes\"",
    new="\"resizeRedraw\": \"no\"",
  )
  inspect(
    validate_manifest_text(manifest).contains(
      "platformObservations.resizeRedraw must be yes when overallStatus is passed",
    ),
    content="true",
  )
}

///|
test "rejects missing color emoji metadata" {
  let manifest = valid_manifest.replace(
    old="\"metadata\": {",
    new="\"metadataMissing\": {",
  )
  inspect(
    validate_manifest_text(manifest).any(message => {
      message.contains("screenshot.colorEmojiPixels.metadata")
    }),
    content="true",
  )
}

///|
test "rejects weak async image ordering" {
  let manifest = valid_manifest.replace(
    old="\"placeholder\": 4",
    new="\"placeholder\": 8",
  )
  inspect(
    validate_manifest_text(manifest).contains(
      "targets[0] passed async image smoke requires placeholder, late load, repaint, ready second-frame order",
    ),
    content="true",
  )
}

///|
test "rejects failed status when require-passed is set" {
  let manifest = valid_manifest.replace(
    old="\"overallStatus\": \"passed\"",
    new="\"overallStatus\": \"failed\"",
  )
  inspect(
    validate_manifest_text_with_options(manifest, true).contains(
      "overallStatus must be passed when --require-passed is used",
    ),
    content="true",
  )
}
