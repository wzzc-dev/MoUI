///|
let valid_manifest =
  #|{
  #|  "schemaVersion": 2,
  #|  "mode": "platform-runtime-evidence",
  #|  "generatedBy": "scripts/conformance-check.sh --platform-services",
  #|  "windowEvidenceSource": ".local_repos/window/scripts/record_moui_evidence.sh",
  #|  "platforms": [
  #|    {
  #|      "name": "web",
  #|      "status": "pending",
  #|      "host": "Web wasm-gc browser host",
  #|      "routineCommands": [
  #|        "moon test moui/backend/web --target wasm-gc",
  #|        "moon build examples/showcase/web_wasm --target wasm-gc"
  #|      ],
  #|      "runtimeEvidenceCommands": [
  #|        "python3 -m http.server 18080 --bind 127.0.0.1",
  #|        "node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223 --manifest artifacts/conformance/web-runtime-presentation.json --require-passed # opens examples/showcase/web_wasm",
  #|        "node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json web --web-presentation-manifest artifacts/conformance/web-runtime-presentation.json"
  #|      ],
  #|      "exampleTargets": [
  #|        "examples/showcase/web_wasm"
  #|      ],
  #|      "windowEvidenceCommand": ".local_repos/window/scripts/record_moui_evidence.sh web --status pending",
  #|      "consumerCommand": "pending",
  #|      "observations": {
  #|        "windowOpened": "pending",
  #|        "resizeRedraw": "pending",
  #|        "representativeInput": "pending",
  #|        "cleanExit": "pending",
  #|        "surface": "pending",
  #|        "redraw": "pending",
  #|        "resizeScale": "pending",
  #|        "consumerInput": "pending",
  #|        "textInput": "pending",
  #|        "rendererHandle": "pending",
  #|        "monitorCursor": "pending",
  #|        "cleanShutdown": "pending",
  #|        "imeCandidateAnchor": "pending",
  #|        "imeSurroundingText": "pending",
  #|        "imeCompositionVisual": "pending",
  #|        "imeCommitDelete": "pending",
  #|        "imeCursorUpdate": "pending",
  #|        "imeScrollAnchor": "pending",
  #|        "imeScaleDprAnchor": "pending",
  #|        "imeResizeAnchor": "pending"
  #|      },
  #|      "artifacts": ["artifacts/platform-evidence/web/README.md"],
  #|      "notes": ["matching-host runtime evidence pending"]
  #|    },
  #|    {
  #|      "name": "macos",
  #|      "status": "pending",
  #|      "host": "macOS Darwin local host",
  #|      "routineCommands": [
  #|        "sh scripts/dev-check.sh --platform-examples-test",
  #|        "moon build examples/showcase/macos_skia --target native"
  #|      ],
  #|      "runtimeEvidenceCommands": [
  #|        "moon run examples/showcase/macos_skia --target native"
  #|      ],
  #|      "exampleTargets": [
  #|        "examples/showcase/macos_skia"
  #|      ],
  #|      "windowEvidenceCommand": ".local_repos/window/scripts/record_moui_evidence.sh macos --status pending",
  #|      "consumerCommand": "pending",
  #|      "observations": {
  #|        "windowOpened": "pending",
  #|        "resizeRedraw": "pending",
  #|        "representativeInput": "pending",
  #|        "cleanExit": "pending",
  #|        "surface": "pending",
  #|        "redraw": "pending",
  #|        "resizeScale": "pending",
  #|        "consumerInput": "pending",
  #|        "textInput": "pending",
  #|        "rendererHandle": "pending",
  #|        "monitorCursor": "pending",
  #|        "cleanShutdown": "pending",
  #|        "imeCandidateAnchor": "pending",
  #|        "imeSurroundingText": "pending",
  #|        "imeCompositionVisual": "pending",
  #|        "imeCommitDelete": "pending",
  #|        "imeCursorUpdate": "pending",
  #|        "imeScrollAnchor": "pending",
  #|        "imeScaleDprAnchor": "pending",
  #|        "imeResizeAnchor": "pending"
  #|      },
  #|      "skiaEvidence": {
  #|        "status": "pending",
  #|        "boundary": "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named macOS host.",
  #|        "providerCommands": [
  #|          "moon test moui/render/skia --target native",
  #|          "moon test moui/backend/macos/skia --target native"
  #|        ],
  #|        "runtimeSmokeCommands": [
  #|          "scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke"
  #|        ],
  #|        "observations": {
  #|          "providerPreflight": "pending",
  #|          "fallbackUnavailable": "pending",
  #|          "realRendererSmoke": "pending",
  #|          "asyncImageSecondFrame": "pending",
  #|          "showcaseFirstFrame": "pending"
  #|        },
  #|        "artifacts": ["artifacts/platform-evidence/macos/README.md"],
  #|        "notes": ["macOS Skia runtime evidence pending"]
  #|      },
  #|      "artifacts": ["artifacts/platform-evidence/macos/README.md"],
  #|      "notes": ["matching-host runtime evidence pending"]
  #|    },
  #|    {
  #|      "name": "windows",
  #|      "status": "pending",
  #|      "host": "Windows MSVC host pending",
  #|      "routineCommands": [
  #|        "moon test moui/backend/windows --target native",
  #|        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly",
  #|        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\package_windows_app_msvc.ps1 -Package examples/showcase/windows_skia"
  #|      ],
  #|      "runtimeEvidenceCommands": [
  #|        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\""
  #|      ],
  #|      "exampleTargets": [
  #|        "examples/showcase/windows_skia"
  #|      ],
  #|      "windowEvidenceCommand": ".local_repos/window/scripts/record_moui_evidence.sh windows --status pending",
  #|      "consumerCommand": "pending",
  #|      "observations": {
  #|        "windowOpened": "pending",
  #|        "resizeRedraw": "pending",
  #|        "representativeInput": "pending",
  #|        "cleanExit": "pending",
  #|        "surface": "pending",
  #|        "redraw": "pending",
  #|        "resizeScale": "pending",
  #|        "consumerInput": "pending",
  #|        "textInput": "pending",
  #|        "rendererHandle": "pending",
  #|        "monitorCursor": "pending",
  #|        "cleanShutdown": "pending",
  #|        "imeCandidateAnchor": "pending",
  #|        "imeSurroundingText": "pending",
  #|        "imeCompositionVisual": "pending",
  #|        "imeCommitDelete": "pending",
  #|        "imeCursorUpdate": "pending",
  #|        "imeScrollAnchor": "pending",
  #|        "imeScaleDprAnchor": "pending",
  #|        "imeResizeAnchor": "pending"
  #|      },
  #|      "skiaEvidence": {
  #|        "status": "pending",
  #|        "boundary": "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Windows/MSVC host.",
  #|        "providerCommands": [
  #|          "moon test moui/render/skia --target native",
  #|          "moon test moui/backend/windows/skia --target native",
  #|          "build_windows_msvc.ps1 -Package examples/showcase/windows_skia"
  #|        ],
  #|        "runtimeSmokeCommands": [
  #|          "MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/windows_skia --target native"
  #|        ],
  #|        "observations": {
  #|          "providerPreflight": "pending",
  #|          "fallbackUnavailable": "pending",
  #|          "realRendererSmoke": "pending",
  #|          "asyncImageSecondFrame": "pending",
  #|          "showcaseFirstFrame": "pending"
  #|        },
  #|        "artifacts": ["artifacts/platform-evidence/windows/README.md"],
  #|        "notes": ["Windows Skia runtime evidence matching-host pending"]
  #|      },
  #|      "artifacts": ["artifacts/platform-evidence/windows/README.md"],
  #|      "notes": ["matching-host runtime evidence pending"]
  #|    },
  #|    {
  #|      "name": "linux",
  #|      "status": "pending",
  #|      "host": "Linux Wayland host pending",
  #|      "routineCommands": [
  #|        "sh scripts/dev-check.sh --platform-examples-test",
  #|        "moon build examples/showcase/linux_skia --target native"
  #|      ],
  #|      "runtimeEvidenceCommands": [
  #|        "moon run examples/showcase/linux_skia --target native"
  #|      ],
  #|      "exampleTargets": [
  #|        "examples/showcase/linux_skia"
  #|      ],
  #|      "windowEvidenceCommand": ".local_repos/window/scripts/record_moui_evidence.sh linux --status pending",
  #|      "consumerCommand": "pending",
  #|      "observations": {
  #|        "windowOpened": "pending",
  #|        "resizeRedraw": "pending",
  #|        "representativeInput": "pending",
  #|        "cleanExit": "pending",
  #|        "surface": "pending",
  #|        "redraw": "pending",
  #|        "resizeScale": "pending",
  #|        "consumerInput": "pending",
  #|        "textInput": "pending",
  #|        "rendererHandle": "pending",
  #|        "monitorCursor": "pending",
  #|        "cleanShutdown": "pending",
  #|        "imeCandidateAnchor": "pending",
  #|        "imeSurroundingText": "pending",
  #|        "imeCompositionVisual": "pending",
  #|        "imeCommitDelete": "pending",
  #|        "imeCursorUpdate": "pending",
  #|        "imeScrollAnchor": "pending",
  #|        "imeScaleDprAnchor": "pending",
  #|        "imeResizeAnchor": "pending"
  #|      },
  #|      "skiaEvidence": {
  #|        "status": "pending",
  #|        "boundary": "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Linux Wayland host.",
  #|        "providerCommands": [
  #|          "moon test moui/render/skia --target native",
  #|          "moon test moui/backend/linux/skia --target native",
  #|          "moon build examples/showcase/linux_skia --target native"
  #|        ],
  #|        "runtimeSmokeCommands": [
  #|          "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/linux_skia --target native"
  #|        ],
  #|        "observations": {
  #|          "providerPreflight": "pending",
  #|          "fallbackUnavailable": "pending",
  #|          "realRendererSmoke": "pending",
  #|          "asyncImageSecondFrame": "pending",
  #|          "showcaseFirstFrame": "pending"
  #|        },
  #|        "artifacts": ["artifacts/platform-evidence/linux/README.md"],
  #|        "notes": ["Linux Skia runtime evidence matching-host pending"]
  #|      },
  #|      "artifacts": ["artifacts/platform-evidence/linux/README.md"],
  #|      "notes": ["matching-host runtime evidence pending"]
  #|    }
  #|  ]
  #|}

///|
let linux_skia_evidence_block =
  #|      "skiaEvidence": {
  #|        "status": "pending",
  #|        "boundary": "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Linux Wayland host.",
  #|        "providerCommands": [
  #|          "moon test moui/render/skia --target native",
  #|          "moon test moui/backend/linux/skia --target native",
  #|          "moon build examples/showcase/linux_skia --target native"
  #|        ],
  #|        "runtimeSmokeCommands": [
  #|          "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/linux_skia --target native"
  #|        ],
  #|        "observations": {
  #|          "providerPreflight": "pending",
  #|          "fallbackUnavailable": "pending",
  #|          "realRendererSmoke": "pending",
  #|          "asyncImageSecondFrame": "pending",
  #|          "showcaseFirstFrame": "pending"
  #|        },
  #|        "artifacts": ["artifacts/platform-evidence/linux/README.md"],
  #|        "notes": ["Linux Skia runtime evidence matching-host pending"]
  #|      },

///|
test "accepts valid pending platform manifest" {
  inspect(validate_manifest_text(valid_manifest).is_empty(), content="true")
}

///|
test "accepts single-platform validation" {
  inspect(
    validate_manifest_text(valid_manifest, expected_platform="windows").is_empty(),
    content="true",
  )
}

///|
test "rejects missing platform" {
  let manifest = valid_manifest.replace(
    old="\"name\": \"linux\"",
    new="\"name\": \"linux-missing\"",
  )
  inspect(
    validate_manifest_text(manifest).contains("platforms must include 'linux'"),
    content="true",
  )
}

///|
test "rejects native entry without skia evidence" {
  let manifest = valid_manifest.replace(old=linux_skia_evidence_block, new="")
  inspect(
    validate_manifest_text(manifest).contains(
      "platforms[3].skiaEvidence must be an object for native Skia evidence",
    ),
    content="true",
  )
}

///|
test "rejects failed entry without negative observation" {
  let manifest = valid_manifest.replace(
    old="\"name\": \"web\",\n      \"status\": \"pending\"",
    new="\"name\": \"web\",\n      \"status\": \"failed\"",
  )
  inspect(
    validate_manifest_text(manifest).contains(
      "platforms[0].observations must include at least one no when status is failed",
    ),
    content="true",
  )
}
