#!/usr/bin/env node

import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const tmp = mkdtempSync(join(tmpdir(), "moui-platform-evidence-"));
const validator = "scripts/validate-platform-evidence-manifest.mjs";

const pendingObservations = {
  windowOpened: "pending",
  resizeRedraw: "pending",
  representativeInput: "pending",
  cleanExit: "pending",
  surface: "pending",
  redraw: "pending",
  resizeScale: "pending",
  consumerInput: "pending",
  textInput: "pending",
  rendererHandle: "pending",
  monitorCursor: "pending",
  cleanShutdown: "pending",
  imeCandidateAnchor: "pending",
  imeSurroundingText: "pending",
  imeCompositionVisual: "pending",
  imeCommitDelete: "pending",
  imeCursorUpdate: "pending",
  imeScrollAnchor: "pending",
  imeScaleDprAnchor: "pending",
  imeResizeAnchor: "pending",
  imeMarkdownEditor: "pending",
};

const passedObservations = Object.fromEntries(
  Object.keys(pendingObservations).map(key => [key, "yes"]),
);

const pendingSkiaObservations = {
  providerPreflight: "pending",
  fallbackUnavailable: "pending",
  realRendererSmoke: "pending",
  asyncImageSecondFrame: "pending",
  showcaseFirstFrame: "pending",
  markdownFirstFrame: "pending",
};

const passedSkiaObservations = Object.fromEntries(
  Object.keys(pendingSkiaObservations).map(key => [key, "yes"]),
);

const matchingHostProvenance = (platform, host, artifacts) => ({
  kind: "matching-host-artifact",
  host,
  artifacts,
  notes: [`${platform} matching-host artifacts prove this passed evidence entry`],
});

const githubActionsProvenance = (platform, host, job, artifacts) => ({
  kind: "github-actions",
  host,
  workflow: "MoUI CI",
  job,
  runUrl: "https://github.com/wzzc-dev/MoUI/actions/runs/123456789",
  runId: "123456789",
  runner: host,
  artifacts,
  notes: [`${platform} evidence was produced by GitHub Actions`],
});

const skiaEvidence = name => {
  if (name === "macos") {
    return {
      status: "pending",
      boundary:
        "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named macOS host.",
      providerCommands: [
        "moon test moui/render/skia --target native",
        "moon test moui/backend/macos/skia --target native",
      ],
      runtimeSmokeCommands: [
        "scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke",
      ],
      observations: { ...pendingSkiaObservations },
      artifacts: ["artifacts/platform-evidence/macos/README.md"],
      notes: ["macOS Skia runtime evidence pending"],
    };
  }
  if (name === "windows") {
    return {
      status: "pending",
      boundary:
        "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Windows/MSVC host.",
      providerCommands: [
        "moon test moui/render/skia --target native",
        "moon test moui/backend/windows/skia --target native",
        "build_windows_msvc.ps1 -Package examples/showcase/windows_skia",
        "build_windows_msvc.ps1 -Package examples/markdown_editor/windows_skia",
      ],
      runtimeSmokeCommands: [
        "MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/windows_skia --target native",
        "MOUI_MARKDOWN_EDITOR_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/markdown_editor/windows_skia --target native",
      ],
      observations: { ...pendingSkiaObservations },
      artifacts: ["artifacts/platform-evidence/windows/README.md"],
      notes: ["Windows Skia runtime evidence matching-host pending"],
    };
  }
  if (name === "linux") {
    return {
      status: "pending",
      boundary:
        "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named Linux Wayland host.",
      providerCommands: [
        "moon test moui/render/skia --target native",
        "moon test moui/backend/linux/skia --target native",
        "moon build examples/showcase/linux_skia --target native",
        "moon build examples/markdown_editor/linux_skia --target native",
      ],
      runtimeSmokeCommands: [
        "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/linux_skia --target native",
        "MOUI_MARKDOWN_EDITOR_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/markdown_editor/linux_skia --target native",
      ],
      observations: { ...pendingSkiaObservations },
      artifacts: ["artifacts/platform-evidence/linux/README.md"],
      notes: ["Linux Skia runtime evidence matching-host pending"],
    };
  }
  return undefined;
};

const baseEntry = ({
  name,
  host,
  exampleTargets,
  routineCommands,
  runtimeEvidenceCommands,
}) => ({
  name,
  status: "pending",
  host,
  routineCommands,
  runtimeEvidenceCommands,
  exampleTargets,
  windowEvidenceCommand: `.local_repos/window/scripts/record_moui_evidence.sh ${name} --status pending`,
  consumerCommand: "pending",
  observations: { ...pendingObservations },
  ...(skiaEvidence(name) ? { skiaEvidence: skiaEvidence(name) } : {}),
  artifacts: [`artifacts/platform-evidence/${name}/README.md`],
  notes: ["matching-host runtime evidence pending"],
});

const validManifest = {
  schemaVersion: 2,
  mode: "platform-runtime-evidence",
  generatedBy: "scripts/conformance-check.sh --platform-services",
  windowEvidenceSource: ".local_repos/window/scripts/record_moui_evidence.sh",
  platforms: [
    baseEntry({
      name: "web",
      host: "Web wasm-gc browser host",
      routineCommands: [
        "moon test moui/backend/web --target wasm-gc",
        "moon build examples/showcase/web_wasm --target wasm-gc",
        "moon build examples/markdown_editor/web_wasm --target wasm-gc",
      ],
      runtimeEvidenceCommands: [
        "python3 -m http.server 18080 --bind 127.0.0.1",
        "node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223 --manifest artifacts/conformance/web-runtime-presentation.json --require-passed # opens examples/showcase/web_wasm and examples/markdown_editor/web_wasm",
        "node scripts/record-platform-evidence-manifest.mjs artifacts/conformance/platform-runtime-evidence.json web --web-presentation-manifest artifacts/conformance/web-runtime-presentation.json",
      ],
      exampleTargets: [
        "examples/showcase/web_wasm",
        "examples/markdown_editor/web_wasm",
      ],
    }),
    baseEntry({
      name: "macos",
      host: "macOS Darwin local host",
      routineCommands: [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/macos_skia --target native",
        "moon build examples/markdown_editor/macos_skia --target native",
      ],
      runtimeEvidenceCommands: [
        "moon run examples/showcase/macos_skia --target native",
        "moon run examples/markdown_editor/macos_skia --target native",
      ],
      exampleTargets: [
        "examples/showcase/macos_skia",
        "examples/markdown_editor/macos_skia",
      ],
    }),
    baseEntry({
      name: "windows",
      host: "Windows MSVC host pending",
      routineCommands: [
        "moon test moui/backend/windows --target native",
        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly",
        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\build_windows_msvc.ps1 -Package examples/markdown_editor/windows_skia -BuildOnly",
        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\package_windows_app_msvc.ps1 -Package examples/showcase/windows_skia",
      ],
      runtimeEvidenceCommands: [
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\"",
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }\"",
      ],
      exampleTargets: [
        "examples/showcase/windows_skia",
        "examples/markdown_editor/windows_skia",
      ],
    }),
    baseEntry({
      name: "linux",
      host: "Linux Wayland host pending",
      routineCommands: [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/linux_skia --target native",
        "moon build examples/markdown_editor/linux_skia --target native",
      ],
      runtimeEvidenceCommands: [
        "moon run examples/showcase/linux_skia --target native",
        "moon run examples/markdown_editor/linux_skia --target native",
      ],
      exampleTargets: [
        "examples/showcase/linux_skia",
        "examples/markdown_editor/linux_skia",
      ],
    }),
  ],
};

const writeFixture = (name, manifest) => {
  const path = join(tmp, name);
  writeFileSync(path, JSON.stringify(manifest, null, 2));
  return path;
};

const runValidator = (path, extraArgs = []) =>
  spawnSync(process.execPath, [validator, path, ...extraArgs], {
    encoding: "utf8",
  });

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected validator to pass`);
    console.error(result.stderr);
    process.exit(1);
  }
};

const expectFail = (label, result, expectedMessage) => {
  if (result.status === 0) {
    console.error(`${label}: expected validator to fail`);
    process.exit(1);
  }
  if (!result.stderr.includes(expectedMessage)) {
    console.error(`${label}: expected stderr to include '${expectedMessage}'`);
    console.error(result.stderr);
    process.exit(1);
  }
};

expectPass(
  "valid pending platform manifest",
  runValidator(writeFixture("valid-pending.json", validManifest)),
);

expectPass(
  "single-platform validation",
  runValidator(writeFixture("valid-single-platform.json", validManifest), [
    "--platform",
    "windows",
  ]),
);

const windowsPassed = {
  ...validManifest,
  platforms: validManifest.platforms.map(entry =>
    entry.name === "windows"
      ? {
          ...entry,
          status: "passed",
          host: "Windows MSVC CI",
          windowEvidenceCommand:
            ".local_repos/window/scripts/record_moui_evidence.sh windows --status passed --host 'Windows MSVC CI'",
          consumerCommand: "moon run examples/showcase/windows_skia --target native",
          observations: { ...passedObservations },
          skiaEvidence: {
            ...entry.skiaEvidence,
            status: "passed",
            observations: { ...passedSkiaObservations },
            artifacts: [
              "artifacts/platform-evidence/windows/skia-provider.log",
              "artifacts/platform-evidence/windows/showcase-skia-first-frame.log",
              "artifacts/platform-evidence/windows/markdown-skia-first-frame.log",
            ],
            evidenceProvenance: matchingHostProvenance("windows", "Windows MSVC CI", [
              "artifacts/platform-evidence/windows/skia-provider.log",
              "artifacts/platform-evidence/windows/showcase-skia-first-frame.log",
              "artifacts/platform-evidence/windows/markdown-skia-first-frame.log",
            ]),
            notes: ["matching-host Windows Skia first-frame evidence observed"],
          },
          artifacts: [
            "artifacts/platform-evidence/windows/window-smoke.md",
            "artifacts/platform-evidence/windows/showcase-run.log",
          ],
          evidenceProvenance: githubActionsProvenance("windows", "Windows MSVC CI", "Windows MSVC native smoke", [
            "artifacts/platform-evidence/windows/window-smoke.md",
            "artifacts/platform-evidence/windows/showcase-run.log",
          ]),
          notes: ["matching-host Windows evidence observed"],
        }
      : entry,
  ),
};
expectPass(
  "valid windows passed manifest",
  runValidator(writeFixture("valid-windows-passed.json", windowsPassed)),
);

const passedWithPlaceholderArtifact = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows"
      ? {
          ...entry,
          artifacts: ["artifacts/platform-evidence/windows/README.md"],
        }
      : entry,
  ),
};
expectFail(
  "passed platform rejects README placeholder artifact",
  runValidator(writeFixture("passed-placeholder-artifact.json", passedWithPlaceholderArtifact)),
  "artifacts[0] must reference runtime evidence, not README.md placeholder documentation",
);

const passedWithPlaceholderProvenanceArtifact = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows"
      ? {
          ...entry,
          evidenceProvenance: {
            ...entry.evidenceProvenance,
            artifacts: ["artifacts/platform-evidence/windows/README.md"],
          },
        }
      : entry,
  ),
};
expectFail(
  "passed platform rejects README placeholder provenance artifact",
  runValidator(
    writeFixture(
      "passed-placeholder-provenance-artifact.json",
      passedWithPlaceholderProvenanceArtifact,
    ),
  ),
  "evidenceProvenance.artifacts[0] must reference runtime evidence, not README.md placeholder documentation",
);

const passedSkiaWithPlaceholderArtifact = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows"
      ? {
          ...entry,
          skiaEvidence: {
            ...entry.skiaEvidence,
            artifacts: ["artifacts/platform-evidence/windows/README.md"],
          },
        }
      : entry,
  ),
};
expectFail(
  "passed skia evidence rejects README placeholder artifact",
  runValidator(writeFixture("passed-skia-placeholder-artifact.json", passedSkiaWithPlaceholderArtifact)),
  "skiaEvidence.artifacts[0] must reference runtime evidence, not README.md placeholder documentation",
);

const passedWithoutProvenance = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows"
      ? Object.fromEntries(
          Object.entries(entry).filter(([key]) => key !== "evidenceProvenance"),
        )
      : entry,
  ),
};
expectFail(
  "passed platform requires provenance",
  runValidator(writeFixture("passed-without-provenance.json", passedWithoutProvenance)),
  "evidenceProvenance must be recorded when status is passed",
);

const passedSkiaWithoutProvenance = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows"
      ? {
          ...entry,
          skiaEvidence: Object.fromEntries(
            Object.entries(entry.skiaEvidence).filter(([key]) => key !== "evidenceProvenance"),
          ),
        }
      : entry,
  ),
};
expectFail(
  "passed skia evidence requires provenance",
  runValidator(writeFixture("passed-skia-without-provenance.json", passedSkiaWithoutProvenance)),
  "skiaEvidence.evidenceProvenance must be recorded when status is passed",
);

const badGithubRunUrl = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows"
      ? {
          ...entry,
          evidenceProvenance: {
            ...entry.evidenceProvenance,
            runUrl: "https://example.com/not-actions",
          },
        }
      : entry,
  ),
};
expectFail(
  "github provenance requires actions run url",
  runValidator(writeFixture("bad-github-run-url.json", badGithubRunUrl)),
  "evidenceProvenance.runUrl must be a GitHub Actions run URL",
);

const escapedProvenanceArtifact = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows"
      ? {
          ...entry,
          evidenceProvenance: {
            ...entry.evidenceProvenance,
            artifacts: ["artifacts/platform-evidence/linux/showcase-run.log"],
          },
        }
      : entry,
  ),
};
expectFail(
  "provenance artifact path must stay under platform",
  runValidator(writeFixture("escaped-provenance-artifact.json", escapedProvenanceArtifact)),
  "evidenceProvenance.artifacts[0] must stay under artifacts/platform-evidence/windows/",
);

const pendingWithMalformedProvenance = {
  ...validManifest,
  platforms: validManifest.platforms.map(entry =>
    entry.name === "web"
      ? {
          ...entry,
          evidenceProvenance: {
            kind: "unknown",
            host: "Web wasm-gc browser host",
            artifacts: ["artifacts/platform-evidence/web/web-runtime-presentation.json"],
            notes: ["malformed pending provenance should still be validated"],
          },
        }
      : entry,
  ),
};
expectFail(
  "pending malformed provenance is rejected",
  runValidator(writeFixture("pending-malformed-provenance.json", pendingWithMalformedProvenance)),
  "evidenceProvenance.kind must be github-actions or matching-host-artifact",
);

expectFail(
  "missing linux platform",
  runValidator(
    writeFixture("missing-linux.json", {
      ...validManifest,
      platforms: validManifest.platforms.filter(entry => entry.name !== "linux"),
    }),
  ),
  "platforms must include 'linux'",
);

const badWindowsHost = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows" ? { ...entry, host: "macOS CI" } : entry,
  ),
};
expectFail(
  "passed windows requires matching host",
  runValidator(writeFixture("bad-windows-host.json", badWindowsHost)),
  "host must name a matching windows host",
);

const incompletePassed = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows"
      ? {
          ...entry,
          observations: { ...entry.observations, textInput: "pending" },
        }
      : entry,
  ),
};
expectFail(
  "passed evidence requires all observations",
  runValidator(writeFixture("incomplete-passed.json", incompletePassed)),
  "observations.textInput must be yes when status is passed",
);

const incompleteNativeImePassed = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows"
      ? {
          ...entry,
          observations: { ...entry.observations, imeCandidateAnchor: "pending" },
        }
      : entry,
  ),
};
expectFail(
  "passed native evidence requires IME candidate anchor",
  runValidator(writeFixture("incomplete-native-ime-passed.json", incompleteNativeImePassed)),
  "observations.imeCandidateAnchor must be yes when status is passed",
);

const webPassedWithNativeImePending = {
  ...validManifest,
  platforms: validManifest.platforms.map(entry =>
    entry.name === "web"
      ? {
          ...entry,
          status: "passed",
          host: "Web wasm-gc browser host (Chrome/149.0.7827.54)",
          consumerCommand:
            "node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223 --manifest artifacts/conformance/web-runtime-presentation.json --require-passed",
          observations: {
            ...passedObservations,
            monitorCursor: "pending",
            imeCandidateAnchor: "pending",
            imeSurroundingText: "pending",
            imeCompositionVisual: "pending",
            imeCommitDelete: "pending",
            imeCursorUpdate: "pending",
            imeScrollAnchor: "pending",
            imeScaleDprAnchor: "pending",
            imeResizeAnchor: "pending",
            imeMarkdownEditor: "pending",
          },
          artifacts: [
            "artifacts/platform-evidence/web/web-runtime-presentation.json",
            "artifacts/platform-evidence/web/showcase-web-wasm.png",
            "artifacts/platform-evidence/web/markdown-editor-web-wasm.png",
          ],
          evidenceProvenance: matchingHostProvenance("web", "Web wasm-gc browser host (Chrome/149.0.7827.54)", [
            "artifacts/platform-evidence/web/web-runtime-presentation.json",
            "artifacts/platform-evidence/web/showcase-web-wasm.png",
            "artifacts/platform-evidence/web/markdown-editor-web-wasm.png",
          ]),
          notes: ["Web browser-session platform evidence observed"],
        }
      : entry,
  ),
};
expectPass(
  "web passed evidence allows native IME observations to stay pending",
  runValidator(writeFixture("web-passed-native-ime-pending.json", webPassedWithNativeImePending)),
);

const missingSkiaEvidence = {
  ...validManifest,
  platforms: validManifest.platforms.map(entry =>
    entry.name === "linux"
      ? Object.fromEntries(
          Object.entries(entry).filter(([key]) => key !== "skiaEvidence"),
        )
      : entry,
  ),
};
expectFail(
  "native entries require skia evidence",
  runValidator(writeFixture("missing-skia-evidence.json", missingSkiaEvidence)),
  "skiaEvidence must be an object for native Skia evidence",
);

const platformPassedWithoutSkiaPassed = {
  ...windowsPassed,
  platforms: windowsPassed.platforms.map(entry =>
    entry.name === "windows"
      ? {
          ...entry,
          skiaEvidence: {
            ...entry.skiaEvidence,
            status: "pending",
            observations: { ...pendingSkiaObservations },
          },
        }
      : entry,
  ),
};
expectFail(
  "passed native platform requires passed skia evidence",
  runValidator(
    writeFixture("platform-passed-without-skia-passed.json", platformPassedWithoutSkiaPassed),
  ),
  "skiaEvidence.status must be passed when native platform status is passed",
);

const consumerWithoutCommand = {
  ...validManifest,
  platforms: validManifest.platforms.map(entry =>
    entry.name === "linux"
      ? {
          ...entry,
          observations: { ...entry.observations, surface: "yes" },
        }
      : entry,
  ),
};
expectFail(
  "consumer observation requires command",
  runValidator(writeFixture("consumer-without-command.json", consumerWithoutCommand)),
  "consumerCommand must name the MoUI consumer run",
);

const linuxMissingSkiaRuntime = {
  ...validManifest,
  platforms: validManifest.platforms.map(entry =>
    entry.name === "linux"
      ? {
          ...entry,
          runtimeEvidenceCommands: entry.runtimeEvidenceCommands.filter(
            command => !command.includes("examples/showcase/linux_skia"),
          ),
        }
      : entry,
  ),
};
expectFail(
  "linux evidence requires linux_skia runtime command",
  runValidator(writeFixture("linux-missing-skia-runtime.json", linuxMissingSkiaRuntime)),
  "runtimeEvidenceCommands must contain an entry mentioning 'moon run examples/showcase/linux_skia --target native'",
);

const linuxMissingSkiaBuild = {
  ...validManifest,
  platforms: validManifest.platforms.map(entry =>
    entry.name === "linux"
      ? {
          ...entry,
          routineCommands: entry.routineCommands.filter(
            command => !command.includes("examples/showcase/linux_skia"),
          ),
        }
      : entry,
  ),
};
expectFail(
  "linux evidence requires linux_skia build command",
  runValidator(writeFixture("linux-missing-skia-build.json", linuxMissingSkiaBuild)),
  "routineCommands must contain an entry mentioning 'moon build examples/showcase/linux_skia --target native'",
);

const escapedArtifact = {
  ...validManifest,
  platforms: validManifest.platforms.map(entry =>
    entry.name === "linux"
      ? { ...entry, artifacts: ["artifacts/platform-evidence/windows/log.txt"] }
      : entry,
  ),
};
expectFail(
  "artifact path must stay under platform",
  runValidator(writeFixture("escaped-artifact.json", escapedArtifact)),
  "artifacts[0] must stay under artifacts/platform-evidence/linux/",
);

const failedWithoutNo = {
  ...validManifest,
  platforms: validManifest.platforms.map(entry =>
    entry.name === "web" ? { ...entry, status: "failed" } : entry,
  ),
};
expectFail(
  "failed evidence needs negative observation",
  runValidator(writeFixture("failed-without-no.json", failedWithoutNo)),
  "observations must include at least one no when status is failed",
);

console.log("platform evidence manifest validator tests: ok");
