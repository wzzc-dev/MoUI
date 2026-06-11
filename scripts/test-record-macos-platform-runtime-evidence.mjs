#!/usr/bin/env node

import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = process.cwd();
const tmp = mkdtempSync(join(tmpdir(), "moui-macos-platform-runtime-evidence-"));
const recorder = "scripts/record-macos-platform-runtime-evidence.mjs";
const artifactRoot = join(repoRoot, "artifacts/platform-evidence/macos/test-record-macos-platform-runtime-evidence");

const nativeImeObservationKeys = [
  "imeCandidateAnchor",
  "imeSurroundingText",
  "imeCompositionVisual",
  "imeCommitDelete",
  "imeCursorUpdate",
  "imeScrollAnchor",
  "imeScaleDprAnchor",
  "imeResizeAnchor",
];
const skiaObservationKeys = [
  "providerPreflight",
  "fallbackUnavailable",
  "realRendererSmoke",
  "asyncImageSecondFrame",
  "showcaseFirstFrame",
];

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
  ...Object.fromEntries(nativeImeObservationKeys.map(key => [key, "pending"])),
};

const passedSkiaEvidence = {
  status: "passed",
  boundary:
    "Provider/preflight evidence proves native Skia package wiring only; runtime smoke evidence must come from MoUI Skia entrypoints on the named macOS host.",
  providerCommands: [
    "moon test moui/render/skia --target native",
    "moon test moui/backend/macos/skia --target native",
  ],
  runtimeSmokeCommands: [
    "scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke",
  ],
  observations: Object.fromEntries(skiaObservationKeys.map(key => [key, "yes"])),
  artifacts: [
    "artifacts/platform-evidence/macos/skia-renderer-smoke.log",
    "artifacts/platform-evidence/macos/showcase-macos-skia-first-frame.log",
  ],
  notes: ["matching-host macOS Skia route evidence passed"],
  evidenceProvenance: {
    kind: "matching-host-artifact",
    host: "macOS Darwin local host",
    artifacts: [
      "artifacts/platform-evidence/macos/skia-renderer-smoke.log",
      "artifacts/platform-evidence/macos/showcase-macos-skia-first-frame.log",
    ],
    notes: ["macOS Skia evidence came from matching-host artifacts"],
  },
};

const baseManifest = ({ imePassed = true, skiaPassed = true } = {}) => ({
  schemaVersion: 2,
  mode: "platform-runtime-evidence",
  generatedBy: "scripts/test-record-macos-platform-runtime-evidence.mjs",
  windowEvidenceSource: "wzzc-dev/window@0.5.1-fork.3",
  platforms: [
    {
      name: "macos",
      status: "pending",
      host: "macOS Darwin host pending",
      routineCommands: [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/macos_skia --target native",
      ],
      runtimeEvidenceCommands: [
        "moon run examples/showcase/macos_skia --target native",
      ],
      exampleTargets: [
        "examples/showcase/macos_skia",
      ],
      windowEvidenceCommand:
        "wzzc-dev/window@0.5.1-fork.3 package evidence macos --status pending",
      consumerCommand: "pending",
      observations: {
        ...pendingObservations,
        ...Object.fromEntries(
          nativeImeObservationKeys.map(key => [key, imePassed ? "yes" : "pending"]),
        ),
      },
      skiaEvidence: skiaPassed
        ? passedSkiaEvidence
        : { ...passedSkiaEvidence, status: "pending" },
      artifacts: ["artifacts/platform-evidence/macos/ime-complete.log"],
      notes: ["matching-host macOS IME evidence passed"],
    },
  ],
});

const writeManifest = (name, options) => {
  const path = join(tmp, name);
  writeFileSync(path, `${JSON.stringify(baseManifest(options), null, 2)}\n`);
  return path;
};

const runtimeLogText = [
  "MoUI macOS platform runtime matching-host native-app platform=macos renderer=skia app=showcase",
  "MoUI macOS platform window opened passed window-opened",
  "MoUI macOS platform resize redraw passed resize-redraw",
  "MoUI macOS platform representative input passed representative-input",
  "MoUI macOS platform clean exit passed clean-exit",
  "MoUI macOS platform surface passed surface",
  "MoUI macOS platform redraw passed redraw",
  "MoUI macOS platform resize scale passed resize-scale",
  "MoUI macOS platform consumer input passed consumer-input",
  "MoUI macOS platform text input passed text-input",
  "MoUI macOS platform renderer handle passed renderer-handle",
  "MoUI macOS platform monitor cursor passed monitor-cursor",
  "MoUI macOS platform clean shutdown passed clean-shutdown",
].join("\n");

const windowSmokeLogText = [
  "MOUIMacSmoke: surface size=320x180 scale=2",
  "MOUIMacSmoke: handles window=0x10 content_view=0x20",
  "MOUIMacSmoke: monitors count=1 primary=true current=true",
  "MOUIMacSmoke: cursor Text",
  "MOUIMacSmoke: resize requested size=400x240",
  "MOUIMacSmoke: resize size=400x240",
  "MOUIMacSmoke: redraw pre_present_notify",
  "MOUIMacSmoke: pointer x=24 y=32",
  "MOUIMacSmoke: keyboard text=a",
  "MOUIMacSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true",
  "MOUIMacSmoke: ready",
  "MOUIMacSmoke: destroyed",
  "MOUIMacSmoke: finished",
].join("\n");

const showcaseAppLogText = [
  "macOS renderer presented first frame; exiting by request; title=MoUI Showcase",
].join("\n");

const writeArtifact = (name, content = runtimeLogText) => {
  mkdirSync(artifactRoot, { recursive: true });
  const path = join(artifactRoot, name);
  writeFileSync(path, `${content}\n`);
  return relative(repoRoot, path);
};

const localRecorderEnv = {
  ...process.env,
  GITHUB_ACTIONS: "",
};

const runRecorder = (args, env = localRecorderEnv) =>
  spawnSync(process.execPath, [recorder, ...args], {
    cwd: repoRoot,
    encoding: "utf8",
    env,
  });

const expectPass = (label, result) => {
  if (result.status !== 0) {
    console.error(`${label}: expected recorder to pass`);
    console.error(result.stderr);
    process.exit(1);
  }
};

const expectFail = (label, result, expectedMessage) => {
  if (result.status === 0) {
    console.error(`${label}: expected recorder to fail`);
    process.exit(1);
  }
  if (!result.stderr.includes(expectedMessage)) {
    console.error(`${label}: expected stderr to include '${expectedMessage}'`);
    console.error(result.stderr);
    process.exit(1);
  }
};

const dumpEntry = entry => {
  console.error(
    JSON.stringify(
      {
        status: entry?.status,
        observations: entry?.observations,
        skiaEvidenceStatus: entry?.skiaEvidence?.status,
        evidenceProvenance: entry?.evidenceProvenance,
        artifacts: entry?.artifacts,
        notes: entry?.notes,
      },
      null,
      2,
    ),
  );
};

try {
  const runtimeLog = writeArtifact("runtime.log");
  const windowSmokeLog = writeArtifact("window-smoke.log", windowSmokeLogText);
  const showcaseAppLog = writeArtifact("showcase-app.log", showcaseAppLogText);
  const localPath = writeManifest("macos-local.json");
  expectPass(
    "record local macOS platform runtime evidence",
    runRecorder([
      localPath,
      "--host",
      "macOS Darwin local host",
      "--consumer-command",
      "moon run examples/showcase/macos_skia --target native",
      "--runtime-log",
      runtimeLog,
      "--note",
      "matching-host macOS platform runtime helper test",
    ]),
  );
  const local = JSON.parse(readFileSync(localPath, "utf8"));
  const localEntry = local.platforms[0];
  if (
    localEntry.status !== "passed" ||
    localEntry.observations.windowOpened !== "yes" ||
    localEntry.observations.monitorCursor !== "yes" ||
    localEntry.skiaEvidence.status !== "passed" ||
    localEntry.evidenceProvenance?.kind !== "matching-host-artifact" ||
    !localEntry.artifacts.includes(runtimeLog) ||
    !localEntry.notes.some(note => note.includes("helper test"))
  ) {
    console.error("record local macOS platform runtime evidence: manifest was not updated correctly");
    dumpEntry(localEntry);
    process.exit(1);
  }

  const sourcePath = writeManifest("macos-source-logs.json");
  expectPass(
    "record macOS platform runtime evidence from source logs",
    runRecorder([
      sourcePath,
      "--host",
      "macOS Darwin local host",
      "--consumer-command",
      "moon run examples/showcase/macos_skia --target native",
      "--window-smoke-log",
      windowSmokeLog,
      "--app-runtime-log",
      showcaseAppLog,
    ]),
  );
  const source = JSON.parse(readFileSync(sourcePath, "utf8"));
  const sourceEntry = source.platforms[0];
  if (
    sourceEntry.status !== "passed" ||
    sourceEntry.observations.windowOpened !== "yes" ||
    sourceEntry.observations.consumerInput !== "yes" ||
    sourceEntry.observations.cleanShutdown !== "yes" ||
    !sourceEntry.artifacts.includes(windowSmokeLog) ||
    !sourceEntry.artifacts.includes(showcaseAppLog)
  ) {
    console.error("record macOS platform runtime evidence from source logs: manifest was not updated correctly");
    dumpEntry(sourceEntry);
    process.exit(1);
  }

  const ciPath = writeManifest("macos-ci.json");
  const ciEnv = {
    ...process.env,
    GITHUB_ACTIONS: "true",
    GITHUB_SERVER_URL: "https://github.com",
    GITHUB_REPOSITORY: "wzzc-dev/MoUI",
    GITHUB_RUN_ID: "123456789",
    GITHUB_WORKFLOW: "MoUI CI",
    GITHUB_JOB: "macos-platform-runtime-evidence",
    RUNNER_NAME: "GitHub Actions 1",
    RUNNER_OS: "macOS",
    RUNNER_ARCH: "ARM64",
  };
  expectPass(
    "record CI macOS platform runtime evidence",
    runRecorder([
      ciPath,
      "--host",
      "macOS Darwin GitHub Actions",
      "--consumer-command",
      "moon run examples/showcase/macos_skia --target native",
      "--runtime-log",
      runtimeLog,
      "--provenance-kind",
      "github-actions",
    ], ciEnv),
  );
  const ci = JSON.parse(readFileSync(ciPath, "utf8"));
  const ciEntry = ci.platforms[0];
  if (
    ciEntry.status !== "passed" ||
    ciEntry.evidenceProvenance?.kind !== "github-actions" ||
    ciEntry.evidenceProvenance.workflow !== "MoUI CI" ||
    ciEntry.evidenceProvenance.job !== "macos-platform-runtime-evidence" ||
    ciEntry.evidenceProvenance.runUrl !== "https://github.com/wzzc-dev/MoUI/actions/runs/123456789" ||
    !ciEntry.evidenceProvenance.artifacts.includes(runtimeLog)
  ) {
    console.error("record CI macOS platform runtime evidence: provenance was not derived correctly");
    dumpEntry(ciEntry);
    process.exit(1);
  }

  const missingMarkerLog = writeArtifact(
    "missing-marker.log",
    runtimeLogText.replace("renderer-handle", "renderer-handle-debug"),
  );
  expectFail(
    "reject runtime log with marker suffix",
    runRecorder([
      writeManifest("missing-marker.json"),
      "--host",
      "macOS Darwin local host",
      "--consumer-command",
      "moon run examples/showcase/macos_skia --target native",
      "--runtime-log",
      missingMarkerLog,
    ]),
    "missing expected token for rendererHandle",
  );

  const missingCursorLog = writeArtifact(
    "window-smoke-missing-cursor.log",
    windowSmokeLogText.replace("MOUIMacSmoke: cursor Text\n", ""),
  );
  expectFail(
    "reject source window smoke log missing cursor probe",
    runRecorder([
      writeManifest("source-missing-cursor.json"),
      "--host",
      "macOS Darwin local host",
      "--consumer-command",
      "moon run examples/showcase/macos_skia --target native",
      "--window-smoke-log",
      missingCursorLog,
      "--app-runtime-log",
      showcaseAppLog,
    ]),
    "macOS window smoke log is missing expected marker",
  );

  const missingImeProbeLog = writeArtifact(
    "window-smoke-missing-ime-probe.log",
    windowSmokeLogText.replace(
      "MOUIMacSmoke: ime probe enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true\n",
      "",
    ),
  );
  expectFail(
    "reject source window smoke log missing IME probe",
    runRecorder([
      writeManifest("source-missing-ime-probe.json"),
      "--host",
      "macOS Darwin local host",
      "--consumer-command",
      "moon run examples/showcase/macos_skia --target native",
      "--window-smoke-log",
      missingImeProbeLog,
      "--app-runtime-log",
      showcaseAppLog,
    ]),
    "macOS window smoke log is missing expected marker",
  );

  const wrongTitleAppLog = writeArtifact(
    "wrong-title-app.log",
    "macOS renderer presented first frame; exiting by request; title=MoUI Markdown Editor\n",
  );
  expectFail(
    "reject source app runtime log with wrong title",
    runRecorder([
      writeManifest("source-wrong-title.json"),
      "--host",
      "macOS Darwin local host",
      "--consumer-command",
      "moon run examples/showcase/macos_skia --target native",
      "--window-smoke-log",
      windowSmokeLog,
      "--app-runtime-log",
      wrongTitleAppLog,
    ]),
    "macOS app runtime log is missing expected marker",
  );

  expectFail(
    "reject non Skia app consumer command",
    runRecorder([
      writeManifest("bad-consumer-command.json"),
      "--host",
      "macOS Darwin local host",
      "--consumer-command",
      "moon run examples/showcase/web_wasm --target wasm-gc",
      "--window-smoke-log",
      windowSmokeLog,
      "--app-runtime-log",
      showcaseAppLog,
    ]),
    "--consumer-command must name examples/showcase/macos_skia",
  );

  expectFail(
    "reject platform promotion before Skia evidence passed",
    runRecorder([
      writeManifest("skia-pending.json", { skiaPassed: false }),
      "--host",
      "macOS Darwin local host",
      "--consumer-command",
      "moon run examples/showcase/macos_skia --target native",
      "--runtime-log",
      runtimeLog,
    ]),
    "macos.skiaEvidence.status must already be passed",
  );

  expectFail(
    "reject platform promotion before IME evidence passed",
    runRecorder([
      writeManifest("ime-pending.json", { imePassed: false }),
      "--host",
      "macOS Darwin local host",
      "--consumer-command",
      "moon run examples/showcase/macos_skia --target native",
      "--runtime-log",
      runtimeLog,
    ]),
    "macos.observations.imeCandidateAnchor must already be yes",
  );

  const outsideLog = join(tmp, "outside.log");
  writeFileSync(outsideLog, `${runtimeLogText}\n`);
  expectFail(
    "reject runtime artifact outside macOS evidence directory",
    runRecorder([
      writeManifest("outside-artifact.json"),
      "--host",
      "macOS Darwin local host",
      "--consumer-command",
      "moon run examples/showcase/macos_skia --target native",
      "--runtime-log",
      outsideLog,
    ]),
    "macOS runtime artifact must stay under artifacts/platform-evidence/macos/",
  );
} finally {
  rmSync(artifactRoot, { recursive: true, force: true });
  rmSync(tmp, { recursive: true, force: true });
}

console.log("macOS platform runtime evidence recorder tests: ok");
