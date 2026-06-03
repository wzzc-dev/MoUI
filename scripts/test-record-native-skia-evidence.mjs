#!/usr/bin/env node

import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = process.cwd();
const tmp = mkdtempSync(join(tmpdir(), "moui-native-skia-evidence-"));
const recorder = "scripts/record-native-skia-evidence.mjs";
const artifactRoot = join(
  repoRoot,
  "artifacts/platform-evidence",
);

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
};

const platformEntries = {
  windows: {
    name: "windows",
    status: "pending",
    host: "Windows MSVC host pending",
    routineCommands: [
      "moon test moui/backend/windows --target native",
      "powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly",
      "powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows_msvc.ps1 -Package examples/markdown_editor/windows_skia -BuildOnly",
      "powershell -ExecutionPolicy Bypass -File scripts/windows/package_windows_app_msvc.ps1 -Package examples/showcase/windows",
    ],
    runtimeEvidenceCommands: [
      "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows --target native }\"",
      "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\"",
      "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/markdown_editor/windows --target native }\"",
      "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }\"",
    ],
    exampleTargets: [
      "examples/showcase/windows",
      "examples/showcase/windows_skia",
      "examples/markdown_editor/windows",
      "examples/markdown_editor/windows_skia",
    ],
    windowEvidenceCommand:
      ".local_repos/window/scripts/record_moui_evidence.sh windows --status pending",
    consumerCommand: "pending",
    observations: { ...pendingObservations },
    artifacts: ["artifacts/platform-evidence/windows/README.md"],
    notes: ["matching-host Windows runtime evidence pending"],
  },
  linux: {
    name: "linux",
    status: "pending",
    host: "Linux Wayland host pending",
    routineCommands: [
      "sh scripts/dev-check.sh --platform-examples-test",
      "moon build examples/showcase/linux --target native",
      "moon build examples/showcase/linux_skia --target native",
      "moon build examples/markdown_editor/linux_skia --target native",
    ],
    runtimeEvidenceCommands: [
      "moon run examples/showcase/linux --target native",
      "moon run examples/showcase/linux_skia --target native",
      "moon run examples/markdown_editor/linux_skia --target native",
    ],
    exampleTargets: [
      "examples/showcase/linux",
      "examples/showcase/linux_cosmic",
      "examples/showcase/linux_skia",
      "examples/markdown_editor/linux_skia",
    ],
    windowEvidenceCommand:
      ".local_repos/window/scripts/record_moui_evidence.sh linux --status pending",
    consumerCommand: "pending",
    observations: { ...pendingObservations },
    artifacts: ["artifacts/platform-evidence/linux/README.md"],
    notes: ["matching-host Linux runtime evidence pending"],
  },
};

const manifestFor = platform => ({
  schemaVersion: 2,
  mode: "platform-runtime-evidence",
  generatedBy: "scripts/test-record-native-skia-evidence.mjs",
  windowEvidenceSource: ".local_repos/window/scripts/record_moui_evidence.sh",
  platforms: [platformEntries[platform]],
});

const writeManifest = (name, platform) => {
  const path = join(tmp, name);
  writeFileSync(path, `${JSON.stringify(manifestFor(platform), null, 2)}\n`);
  return path;
};

const writeArtifact = (platform, name, content) => {
  const dir = join(artifactRoot, platform, "test-record-native-skia-evidence");
  mkdirSync(dir, { recursive: true });
  const path = join(dir, name);
  writeFileSync(path, content);
  return relative(repoRoot, path);
};

const runRecorder = args =>
  spawnSync(process.execPath, [recorder, ...args], {
    cwd: repoRoot,
    encoding: "utf8",
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

try {
  const partialLinuxPath = writeManifest("partial-linux.json", "linux");
  const linuxShowcaseLog = writeArtifact(
    "linux",
    "showcase-skia-first-frame.log",
    "Linux renderer presented first frame; exiting by request\n",
  );
  expectPass(
    "record partial Linux Skia evidence",
    runRecorder([
      partialLinuxPath,
      "linux",
      "--host",
      "Linux Wayland CI",
      "--showcase-log",
      linuxShowcaseLog,
    ]),
  );
  const partialLinux = JSON.parse(readFileSync(partialLinuxPath, "utf8"));
  const partialLinuxEntry = partialLinux.platforms[0];
  if (
    partialLinuxEntry.status !== "pending" ||
    partialLinuxEntry.skiaEvidence.status !== "pending" ||
    partialLinuxEntry.skiaEvidence.observations.showcaseFirstFrame !== "yes" ||
    partialLinuxEntry.skiaEvidence.observations.markdownFirstFrame !== "pending"
  ) {
    console.error("record partial Linux Skia evidence: manifest boundary changed incorrectly");
    process.exit(1);
  }

  const windowsPath = writeManifest("windows-skia-passed.json", "windows");
  const providerLog = writeArtifact(
    "windows",
    "skia-provider.log",
    "Total tests: 4, passed: 4, failed: 0.\n",
  );
  const fallbackLog = writeArtifact(
    "windows",
    "skia-fallback-unavailable.log",
    "Windows Skia renderer selected, but skia_mbt/native is unavailable; configure real Skia link flags\n",
  );
  const rendererLog = writeArtifact(
    "windows",
    "skia-renderer-smoke.log",
    "MoUI Skia renderer smoke passed\n",
  );
  const showcaseLog = writeArtifact(
    "windows",
    "showcase-skia-first-frame.log",
    "Windows renderer presented first frame; exiting by request\n",
  );
  const markdownLog = writeArtifact(
    "windows",
    "markdown-skia-first-frame.log",
    "Windows renderer presented first frame; exiting by request\n",
  );
  expectPass(
    "record passed Windows Skia evidence",
    runRecorder([
      windowsPath,
      "windows",
      "--host",
      "Windows MSVC CI",
      "--provider-preflight-log",
      providerLog,
      "--fallback-unavailable-log",
      fallbackLog,
      "--renderer-smoke-log",
      rendererLog,
      "--showcase-log",
      showcaseLog,
      "--markdown-log",
      markdownLog,
      "--note",
      "matching-host Windows Skia helper test",
    ]),
  );
  const windows = JSON.parse(readFileSync(windowsPath, "utf8"));
  const windowsEntry = windows.platforms[0];
  if (
    windowsEntry.status !== "pending" ||
    windowsEntry.host !== "Windows MSVC CI" ||
    windowsEntry.skiaEvidence.status !== "passed" ||
    windowsEntry.skiaEvidence.observations.realRendererSmoke !== "yes" ||
    !windowsEntry.skiaEvidence.notes.some(note => note.includes("helper test"))
  ) {
    console.error("record passed Windows Skia evidence: manifest was not updated correctly");
    process.exit(1);
  }

  const badPath = writeManifest("bad-windows-marker.json", "windows");
  const badShowcaseLog = writeArtifact(
    "windows",
    "bad-showcase-skia-first-frame.log",
    "renderer started but no first frame marker\n",
  );
  expectFail(
    "reject first-frame log without marker",
    runRecorder([
      badPath,
      "windows",
      "--host",
      "Windows MSVC CI",
      "--showcase-log",
      badShowcaseLog,
    ]),
    "Showcase first-frame log is missing expected marker",
  );

  expectFail(
    "reject mismatched helper host",
    runRecorder([
      writeManifest("bad-host.json", "linux"),
      "linux",
      "--host",
      "Windows MSVC CI",
      "--showcase-log",
      linuxShowcaseLog,
    ]),
    "--host must name a matching linux host",
  );
} finally {
  rmSync(join(artifactRoot, "linux", "test-record-native-skia-evidence"), {
    recursive: true,
    force: true,
  });
  rmSync(join(artifactRoot, "windows", "test-record-native-skia-evidence"), {
    recursive: true,
    force: true,
  });
}

console.log("native Skia evidence recorder tests: ok");
