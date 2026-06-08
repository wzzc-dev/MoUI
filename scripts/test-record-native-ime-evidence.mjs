#!/usr/bin/env node

import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = process.cwd();
const tmp = mkdtempSync(join(tmpdir(), "moui-native-ime-evidence-"));
const recorder = "scripts/record-native-ime-evidence.mjs";
const artifactRoot = join(repoRoot, "artifacts/platform-evidence");

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
  macos: {
    name: "macos",
    status: "pending",
    host: "macOS host pending",
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
    windowEvidenceCommand:
      ".local_repos/window/scripts/record_moui_evidence.sh macos --status pending",
    consumerCommand: "pending",
    observations: { ...pendingObservations },
    artifacts: ["artifacts/platform-evidence/macos/README.md"],
    notes: ["matching-host macOS runtime evidence pending"],
  },
  windows: {
    name: "windows",
    status: "pending",
    host: "Windows MSVC host pending",
    routineCommands: [
      "moon test moui/backend/windows --target native",
      "powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly",
      "powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows_msvc.ps1 -Package examples/markdown_editor/windows_skia -BuildOnly",
      "powershell -ExecutionPolicy Bypass -File scripts/windows/package_windows_app_msvc.ps1 -Package examples/showcase/windows_skia",
    ],
    runtimeEvidenceCommands: [
      "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\"",
      "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }\"",
    ],
    exampleTargets: [
      "examples/showcase/windows_skia",
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
  generatedBy: "scripts/test-record-native-ime-evidence.mjs",
  windowEvidenceSource: ".local_repos/window/scripts/record_moui_evidence.sh",
  platforms: [platformEntries[platform]],
});

const writeManifest = (name, platform) => {
  const path = join(tmp, name);
  writeFileSync(path, `${JSON.stringify(manifestFor(platform), null, 2)}\n`);
  return path;
};

const writeArtifact = (platform, name, content) => {
  const dir = join(artifactRoot, platform, "test-record-native-ime-evidence");
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
  const linuxPath = writeManifest("partial-linux-ime.json", "linux");
  const linuxCandidateLog = writeArtifact(
    "linux",
    "ime-candidate-anchor.log",
    [
      "MoUI native IME runtime matching-host native-app platform-protocol=wayland-text-input app=showcase",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text source=showcase",
    ].join("\n"),
  );
  const linuxConsumerCommand =
    "MOUI_LINUX_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/linux_skia --target native";
  expectPass(
    "record partial Linux IME evidence",
    runRecorder([
      linuxPath,
      "linux",
      "--host",
      "Linux Wayland CI",
      "--consumer-command",
      linuxConsumerCommand,
      "--candidate-anchor-log",
      linuxCandidateLog,
    ]),
  );
  const linux = JSON.parse(readFileSync(linuxPath, "utf8"));
  const linuxEntry = linux.platforms[0];
  if (
    linuxEntry.status !== "pending" ||
    linuxEntry.host !== "Linux Wayland CI" ||
    linuxEntry.consumerCommand !== linuxConsumerCommand ||
    linuxEntry.observations.imeCandidateAnchor !== "yes" ||
    linuxEntry.observations.imeSurroundingText !== "pending" ||
    linuxEntry.evidenceProvenance?.kind !== "matching-host-artifact" ||
    !linuxEntry.evidenceProvenance.artifacts.includes(linuxCandidateLog) ||
    !linuxEntry.artifacts.includes(linuxCandidateLog)
  ) {
    console.error("record partial Linux IME evidence: manifest was not updated correctly");
    process.exit(1);
  }

  const windowsPath = writeManifest("windows-ime-complete.json", "windows");
  const windowsAllLog = writeArtifact(
    "windows",
    "ime-complete.log",
    [
      "MoUI native IME runtime matching-host native-app platform-protocol=windows-ime app=markdown-editor",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text",
      "MoUI native IME surrounding text passed surrounding-text selection-anchor utf8-offsets grapheme",
      "MoUI native IME composition visual passed composition-range composition-cursor preedit-underline preedit-pixels selection-highlight",
      "MoUI native IME commit delete passed commit delete selection-replacement",
      "MoUI native IME cursor update passed cursor-area cursor-update caret-rect",
      "MoUI native IME scroll anchor passed scroll candidate-anchor candidate-window",
      "MoUI native IME scale DPR anchor passed scale dpr candidate-anchor candidate-window",
      "MoUI native IME resize anchor passed resize candidate-anchor candidate-window",
      "MoUI native IME Markdown Editor passed markdown-editor composition candidate-anchor candidate-window selection-replacement source-mapping",
    ].join("\n"),
  );
  const windowsConsumerCommand =
    "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }\"";
  expectPass(
    "record complete Windows IME evidence without platform promotion",
    runRecorder([
      windowsPath,
      "windows",
      "--host",
      "Windows MSVC CI",
      "--consumer-command",
      windowsConsumerCommand,
      "--candidate-anchor-log",
      windowsAllLog,
      "--surrounding-text-log",
      windowsAllLog,
      "--composition-visual-log",
      windowsAllLog,
      "--commit-delete-log",
      windowsAllLog,
      "--cursor-update-log",
      windowsAllLog,
      "--scroll-anchor-log",
      windowsAllLog,
      "--scale-dpr-anchor-log",
      windowsAllLog,
      "--resize-anchor-log",
      windowsAllLog,
      "--markdown-log",
      windowsAllLog,
      "--note",
      "matching-host Windows IME helper test",
    ]),
  );
  const windows = JSON.parse(readFileSync(windowsPath, "utf8"));
  const windowsEntry = windows.platforms[0];
  if (
    windowsEntry.status !== "pending" ||
    windowsEntry.observations.imeCandidateAnchor !== "yes" ||
    windowsEntry.observations.imeMarkdownEditor !== "yes" ||
    windowsEntry.observations.windowOpened !== "pending" ||
    windowsEntry.evidenceProvenance?.host !== "Windows MSVC CI" ||
    !windowsEntry.evidenceProvenance.artifacts.includes(windowsAllLog) ||
    !windowsEntry.notes.some(note => note.includes("helper test"))
  ) {
    console.error("record complete Windows IME evidence: manifest was not updated correctly");
    process.exit(1);
  }

  const badMarkerPath = writeManifest("bad-linux-ime-marker.json", "linux");
  const badMarkerLog = writeArtifact(
    "linux",
    "bad-ime-candidate-anchor.log",
    [
      "MoUI native IME runtime matching-host native-app platform-protocol=wayland-text-input",
      "host unit test says textInput passed, but no runtime anchor marker",
    ].join("\n"),
  );
  expectFail(
    "reject candidate anchor log without marker",
    runRecorder([
      badMarkerPath,
      "linux",
      "--host",
      "Linux Wayland CI",
      "--consumer-command",
      linuxConsumerCommand,
      "--candidate-anchor-log",
      badMarkerLog,
    ]),
    "candidate anchor log is missing expected marker",
  );

  const packageOnlyPath = writeManifest("package-only-ime-marker.json", "linux");
  const packageOnlyLog = writeArtifact(
    "linux",
    "package-only-ime-candidate-anchor.log",
    "host unit test MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text\n",
  );
  expectFail(
    "reject candidate anchor log without runtime markers",
    runRecorder([
      packageOnlyPath,
      "linux",
      "--host",
      "Linux Wayland CI",
      "--consumer-command",
      linuxConsumerCommand,
      "--candidate-anchor-log",
      packageOnlyLog,
    ]),
    "candidate anchor log is missing expected marker: MoUI native IME runtime",
  );

  expectFail(
    "reject missing consumer command",
    runRecorder([
      writeManifest("missing-consumer-command.json", "windows"),
      "windows",
      "--host",
      "Windows MSVC CI",
      "--candidate-anchor-log",
      windowsAllLog,
    ]),
    "--consumer-command is required",
  );

  expectFail(
    "reject non Skia app consumer command",
    runRecorder([
      writeManifest("bad-consumer-command.json", "windows"),
      "windows",
      "--host",
      "Windows MSVC CI",
      "--consumer-command",
      "moon test moui/backend/windows --target native",
      "--candidate-anchor-log",
      windowsAllLog,
    ]),
    "consumer-command must name examples/showcase/windows_skia or examples/markdown_editor/windows_skia",
  );

  expectFail(
    "reject markdown log with Showcase consumer command",
    runRecorder([
      writeManifest("markdown-log-showcase-consumer.json", "linux"),
      "linux",
      "--host",
      "Linux Wayland CI",
      "--consumer-command",
      linuxConsumerCommand,
      "--markdown-log",
      linuxCandidateLog,
    ]),
    "markdown-log requires --consumer-command to name examples/markdown_editor/linux_skia",
  );

  expectFail(
    "reject mismatched native host",
    runRecorder([
      writeManifest("bad-host.json", "windows"),
      "windows",
      "--host",
      "macOS CI",
      "--consumer-command",
      windowsConsumerCommand,
      "--candidate-anchor-log",
      windowsAllLog,
    ]),
    "host must name a matching windows host",
  );
} finally {
  rmSync(join(artifactRoot, "linux", "test-record-native-ime-evidence"), {
    recursive: true,
    force: true,
  });
  rmSync(join(artifactRoot, "windows", "test-record-native-ime-evidence"), {
    recursive: true,
    force: true,
  });
}

console.log("native IME evidence recorder tests: ok");
