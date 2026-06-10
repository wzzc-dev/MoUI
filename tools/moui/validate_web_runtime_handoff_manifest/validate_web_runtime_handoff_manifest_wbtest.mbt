///|
let valid_manifest =
  #|{
  #|  "schemaVersion": 1,
  #|  "mode": "web-runtime-handoff",
  #|  "generatedBy": "scripts/validate-web-runtime-handoff.mjs",
  #|  "root": ".",
  #|  "baseUrl": "",
  #|  "evidenceBoundary": "Static HTML/runtime/wasm delivery and compiled WebAssembly export audit only; not browser WebGPU device, wasm instantiation, canvas presentation, or pixel evidence.",
  #|  "runtimeAssets": [
  #|    "moui/backend/web/runtime.js",
  #|    "moui/backend/web/browser_runtime.js"
  #|  ],
  #|  "targets": [
  #|    {
  #|      "name": "showcase-web-wasm",
  #|      "packagePath": "examples/showcase/web_wasm",
  #|      "htmlPath": "examples/showcase/web_wasm/index.html",
  #|      "wasmPath": "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm",
  #|      "requiredWasmExports": [
  #|        "web_dispatch_event",
  #|        "web_complete_async_clipboard_read",
  #|        "web_complete_async_file_dialog"
  #|      ],
  #|      "compiledWasmExports": [
  #|        "web_dispatch_event",
  #|        "web_complete_async_clipboard_read",
  #|        "web_complete_async_file_dialog",
  #|        "_start"
  #|      ],
  #|      "htmlRuntimeImport": "../../../moui/backend/web/runtime.js",
  #|      "canvasHostSelector": "#canvas-host",
  #|      "wasmBytes": 2048
  #|    },
  #|    {
  #|      "name": "markdown-editor-web-wasm",
  #|      "packagePath": "examples/markdown_editor/web_wasm",
  #|      "htmlPath": "examples/markdown_editor/web_wasm/index.html",
  #|      "wasmPath": "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm",
  #|      "requiredWasmExports": [
  #|        "web_dispatch_event",
  #|        "web_complete_async_clipboard_read",
  #|        "web_complete_async_file_dialog"
  #|      ],
  #|      "compiledWasmExports": [
  #|        "web_dispatch_event",
  #|        "web_complete_async_clipboard_read",
  #|        "web_complete_async_file_dialog",
  #|        "_start"
  #|      ],
  #|      "htmlRuntimeImport": "../../../moui/backend/web/runtime.js",
  #|      "canvasHostSelector": "#canvas-host",
  #|      "wasmBytes": 2048
  #|    }
  #|  ],
  #|  "checks": [
  #|    { "kind": "file", "path": "moui/backend/web/runtime.js", "bytes": 1024 },
  #|    { "kind": "file", "path": "moui/backend/web/browser_runtime.js", "bytes": 1024 },
  #|    { "kind": "file", "path": "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm", "bytes": 2048 },
  #|    { "kind": "file", "path": "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm", "bytes": 2048 }
  #|  ]
  #|}

///|
test "accepts valid web runtime handoff manifest" {
  inspect(validate_manifest_text(valid_manifest).is_empty(), content="true")
}

///|
test "rejects missing expected target" {
  let markdown_target =
    #|    {
    #|      "name": "markdown-editor-web-wasm",
    #|      "packagePath": "examples/markdown_editor/web_wasm",
    #|      "htmlPath": "examples/markdown_editor/web_wasm/index.html",
    #|      "wasmPath": "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm",
    #|      "requiredWasmExports": [
    #|        "web_dispatch_event",
    #|        "web_complete_async_clipboard_read",
    #|        "web_complete_async_file_dialog"
    #|      ],
    #|      "compiledWasmExports": [
    #|        "web_dispatch_event",
    #|        "web_complete_async_clipboard_read",
    #|        "web_complete_async_file_dialog",
    #|        "_start"
    #|      ],
    #|      "htmlRuntimeImport": "../../../moui/backend/web/runtime.js",
    #|      "canvasHostSelector": "#canvas-host",
    #|      "wasmBytes": 2048
    #|    }
    #|
  let manifest = valid_manifest
    .replace(old=markdown_target, new="")
    .replace(old="    },\n  ],", new="    }\n  ],")
  inspect(
    validate_manifest_text(manifest).contains(
      "targets must include 'markdown-editor-web-wasm'",
    ),
    content="true",
  )
}

///|
test "rejects missing compiled wasm export" {
  let compiled_with_dispatch =
    #|      "compiledWasmExports": [
    #|        "web_dispatch_event",
    #|        "web_complete_async_clipboard_read",
    #|        "web_complete_async_file_dialog",
    #|        "_start"
    #|      ],
    #|
  let compiled_without_dispatch =
    #|      "compiledWasmExports": [
    #|        "web_complete_async_clipboard_read",
    #|        "web_complete_async_file_dialog",
    #|        "_start"
    #|      ],
    #|
  let manifest = valid_manifest.replace(
    old=compiled_with_dispatch,
    new=compiled_without_dispatch,
  )
  inspect(
    validate_manifest_text(manifest).contains(
      "targets[0].compiledWasmExports must include 'web_dispatch_event'",
    ),
    content="true",
  )
}

///|
test "rejects weak evidence boundary" {
  let manifest = valid_manifest.replace(
    old="Static HTML/runtime/wasm delivery and compiled WebAssembly export audit only; not browser WebGPU device, wasm instantiation, canvas presentation, or pixel evidence.",
    new="Static handoff evidence.",
  )
  inspect(
    validate_manifest_text(manifest).contains(
      "evidenceBoundary must explicitly exclude browser WebGPU device, wasm instantiation, and pixel evidence",
    ),
    content="true",
  )
}

///|
test "rejects nonlocal http url" {
  let last_file_check =
    #|    { "kind": "file", "path": "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm", "bytes": 2048 }
    #|
  let file_and_http_check =
    #|    { "kind": "file", "path": "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm", "bytes": 2048 },
    #|    { "kind": "http", "label": "external", "path": "examples/showcase/web_wasm/index.html", "url": "https://example.com/examples/showcase/web_wasm/index.html", "bytes": 2048 }
    #|
  let manifest = valid_manifest.replace(
    old=last_file_check,
    new=file_and_http_check,
  )
  inspect(
    validate_manifest_text(manifest).contains(
      "checks[4].url must be a local HTTP URL",
    ),
    content="true",
  )
}
