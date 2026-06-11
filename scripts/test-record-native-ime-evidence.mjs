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
    ],
    runtimeEvidenceCommands: [
      "moon run examples/showcase/macos_skia --target native",
    ],
    exampleTargets: [
      "examples/showcase/macos_skia",
    ],
    windowEvidenceCommand:
      "wzzc-dev/window@0.5.1-0.1.4 package evidence macos --status pending",
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
      "powershell -ExecutionPolicy Bypass -File scripts/windows/package_windows_app_msvc.ps1 -Package examples/showcase/windows_skia",
    ],
    runtimeEvidenceCommands: [
      "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\"",
    ],
    exampleTargets: [
      "examples/showcase/windows_skia",
    ],
    windowEvidenceCommand:
      "wzzc-dev/window@0.5.1-0.1.4 package evidence windows --status pending",
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
    ],
    runtimeEvidenceCommands: [
      "moon run examples/showcase/linux_skia --target native",
    ],
    exampleTargets: [
      "examples/showcase/linux_skia",
    ],
    windowEvidenceCommand:
      "wzzc-dev/window@0.5.1-0.1.4 package evidence linux --status pending",
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
  windowEvidenceSource: "wzzc-dev/window@0.5.1-0.1.4",
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
      "MoUI native IME runtime matching-host native-app renderer=skia platform-protocol=wayland-text-input app=showcase",
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
      "MoUI native IME runtime matching-host native-app renderer=skia platform-protocol=windows-ime app=showcase",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text",
      "MoUI native IME surrounding text passed surrounding-text selection-anchor utf8-offsets grapheme",
      "MoUI native IME composition visual passed composition-range composition-cursor preedit-underline preedit-pixels selection-highlight",
      "MoUI native IME commit delete passed commit delete selection-replacement",
      "MoUI native IME cursor update passed cursor-area cursor-update caret-rect",
      "MoUI native IME scroll anchor passed scroll candidate-anchor candidate-window",
      "MoUI native IME scale DPR anchor passed scale dpr candidate-anchor candidate-window",
      "MoUI native IME resize anchor passed resize candidate-anchor candidate-window",
    ].join("\n"),
  );
  const windowsConsumerCommand =
    "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }\"";
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
      "--note",
      "matching-host Windows IME helper test",
    ]),
  );
  const windows = JSON.parse(readFileSync(windowsPath, "utf8"));
  const windowsEntry = windows.platforms[0];
  if (
    windowsEntry.status !== "pending" ||
    windowsEntry.observations.imeCandidateAnchor !== "yes" ||
    windowsEntry.observations.windowOpened !== "pending" ||
    windowsEntry.evidenceProvenance?.host !== "Windows MSVC CI" ||
    !windowsEntry.evidenceProvenance.artifacts.includes(windowsAllLog) ||
    !windowsEntry.notes.some(note => note.includes("helper test"))
  ) {
    console.error("record complete Windows IME evidence: manifest was not updated correctly");
    process.exit(1);
  }

  const macosPath = writeManifest("macos-ime-complete.json", "macos");
  const macosAllLog = writeArtifact(
    "macos",
    "ime-complete.log",
    [
      "MoUI native IME runtime matching-host native-app renderer=skia platform-protocol=macos-marked-text NSTextInputClient app=showcase",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text appkit-setMarkedText appkit-firstRectForCharacterRange",
      "MoUI native IME surrounding text passed surrounding-text selection-anchor utf8-offsets grapheme appkit-setMarkedText appkit-firstRectForCharacterRange",
      "MoUI native IME composition visual passed composition-range composition-cursor preedit-underline preedit-pixels selection-highlight appkit-setMarkedText appkit-firstRectForCharacterRange",
      "MoUI native IME commit delete passed commit delete selection-replacement appkit-insertText",
      "MoUI native IME cursor update passed cursor-area cursor-update caret-rect appkit-insertText",
      "MoUI native IME scroll anchor passed scroll candidate-anchor candidate-window appkit-insertText",
      "MoUI native IME scale DPR anchor passed scale dpr candidate-anchor candidate-window appkit-insertText",
      "MoUI native IME resize anchor passed resize candidate-anchor candidate-window appkit-insertText",
    ].join("\n"),
  );
  const macosConsumerCommand =
    "MOUI_MACOS_NATIVE_IME_EVIDENCE=1 moon run examples/showcase/macos_skia --target native";
  expectPass(
    "record complete macOS IME evidence with AppKit markers",
    runRecorder([
      macosPath,
      "macos",
      "--host",
      "macOS Darwin CI",
      "--consumer-command",
      macosConsumerCommand,
      "--candidate-anchor-log",
      macosAllLog,
      "--surrounding-text-log",
      macosAllLog,
      "--composition-visual-log",
      macosAllLog,
      "--commit-delete-log",
      macosAllLog,
      "--cursor-update-log",
      macosAllLog,
      "--scroll-anchor-log",
      macosAllLog,
      "--scale-dpr-anchor-log",
      macosAllLog,
      "--resize-anchor-log",
      macosAllLog,
    ]),
  );
  const macos = JSON.parse(readFileSync(macosPath, "utf8"));
  const macosEntry = macos.platforms[0];
  if (
    macosEntry.status !== "pending" ||
    macosEntry.host !== "macOS Darwin CI" ||
    macosEntry.observations.imeCandidateAnchor !== "yes" ||
    macosEntry.evidenceProvenance?.kind !== "matching-host-artifact" ||
    !macosEntry.evidenceProvenance.artifacts.includes(macosAllLog)
  ) {
    console.error("record complete macOS IME evidence: manifest was not updated correctly");
    process.exit(1);
  }

  const macosWeakLog = writeArtifact(
    "macos",
    "weak-ime-candidate-anchor.log",
    [
      "MoUI native IME runtime matching-host native-app renderer=skia platform-protocol=macos-marked-text app=showcase",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text",
    ].join("\n"),
  );
  expectFail(
    "reject macOS IME log without AppKit markers",
    runRecorder([
      writeManifest("weak-macos-ime-marker.json", "macos"),
      "macos",
      "--host",
      "macOS Darwin CI",
      "--consumer-command",
      macosConsumerCommand,
      "--candidate-anchor-log",
      macosWeakLog,
    ]),
    "candidate anchor log is missing expected marker: NSTextInputClient",
  );

  const macosWeakCursorLog = writeArtifact(
    "macos",
    "weak-ime-cursor-update.log",
    [
      "MoUI native IME runtime matching-host native-app renderer=skia platform-protocol=macos-marked-text NSTextInputClient app=showcase",
      "MoUI native IME cursor update passed cursor-area cursor-update caret-rect",
    ].join("\n"),
  );
  expectFail(
    "reject macOS cursor update log without AppKit insert marker",
    runRecorder([
      writeManifest("weak-macos-cursor-ime-marker.json", "macos"),
      "macos",
      "--host",
      "macOS Darwin CI",
      "--consumer-command",
      macosConsumerCommand,
      "--cursor-update-log",
      macosWeakCursorLog,
    ]),
    "cursor update log is missing expected marker: NSTextInputClient and appkit-insertText markers",
  );

  const badMarkerPath = writeManifest("bad-linux-ime-marker.json", "linux");
  const badMarkerLog = writeArtifact(
    "linux",
    "bad-ime-candidate-anchor.log",
    [
      "MoUI native IME runtime matching-host native-app renderer=skia platform-protocol=wayland-text-input app=showcase",
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

  const runtimeSuffixLog = writeArtifact(
    "linux",
    "runtime-suffix-ime-candidate-anchor.log",
    [
      "MoUI native IME runtime matching-hosted native-app-test renderer=skia platform-protocol=wayland-text-input app=showcase",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text",
    ].join("\n"),
  );
  expectFail(
    "reject IME log with common runtime marker suffixes",
    runRecorder([
      writeManifest("runtime-suffix-ime-marker.json", "linux"),
      "linux",
      "--host",
      "Linux Wayland CI",
      "--consumer-command",
      linuxConsumerCommand,
      "--candidate-anchor-log",
      runtimeSuffixLog,
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
    "consumer-command must name examples/showcase/windows_skia",
  );

  const wrongAppLog = writeArtifact(
    "linux",
    "wrong-app-ime-candidate-anchor.log",
    [
      "MoUI native IME runtime matching-host native-app renderer=skia platform-protocol=wayland-text-input app=markdown-editor",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text",
    ].join("\n"),
  );
  expectFail(
    "reject IME log from a different native app",
    runRecorder([
      writeManifest("wrong-app-ime-marker.json", "linux"),
      "linux",
      "--host",
      "Linux Wayland CI",
      "--consumer-command",
      linuxConsumerCommand,
      "--candidate-anchor-log",
      wrongAppLog,
    ]),
    "candidate anchor log is missing expected marker: MoUI native IME runtime",
  );

  const appSuffixLog = writeArtifact(
    "linux",
    "app-suffix-ime-candidate-anchor.log",
    [
      "MoUI native IME runtime matching-host native-app renderer=skia platform-protocol=wayland-text-input app=showcase-debug",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text",
    ].join("\n"),
  );
  expectFail(
    "reject IME log with app marker suffix",
    runRecorder([
      writeManifest("app-suffix-ime-marker.json", "linux"),
      "linux",
      "--host",
      "Linux Wayland CI",
      "--consumer-command",
      linuxConsumerCommand,
      "--candidate-anchor-log",
      appSuffixLog,
    ]),
    "candidate anchor log is missing expected marker: MoUI native IME runtime",
  );

  const wrongRendererLog = writeArtifact(
    "linux",
    "wrong-renderer-ime-candidate-anchor.log",
    [
      "MoUI native IME runtime matching-host native-app renderer=wgpu platform-protocol=wayland-text-input app=showcase",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text",
    ].join("\n"),
  );
  expectFail(
    "reject IME log from a non-Skia renderer",
    runRecorder([
      writeManifest("wrong-renderer-ime-marker.json", "linux"),
      "linux",
      "--host",
      "Linux Wayland CI",
      "--consumer-command",
      linuxConsumerCommand,
      "--candidate-anchor-log",
      wrongRendererLog,
    ]),
    "candidate anchor log is missing expected marker: MoUI native IME runtime",
  );

  const rendererSuffixLog = writeArtifact(
    "linux",
    "renderer-suffix-ime-candidate-anchor.log",
    [
      "MoUI native IME runtime matching-host native-app renderer=skia-preview platform-protocol=wayland-text-input app=showcase",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text",
    ].join("\n"),
  );
  expectFail(
    "reject IME log with renderer marker suffix",
    runRecorder([
      writeManifest("renderer-suffix-ime-marker.json", "linux"),
      "linux",
      "--host",
      "Linux Wayland CI",
      "--consumer-command",
      linuxConsumerCommand,
      "--candidate-anchor-log",
      rendererSuffixLog,
    ]),
    "candidate anchor log is missing expected marker: MoUI native IME runtime",
  );

  const protocolSuffixLog = writeArtifact(
    "linux",
    "protocol-suffix-ime-candidate-anchor.log",
    [
      "MoUI native IME runtime matching-host native-app renderer=skia platform-protocol=wayland-text-input-v3 app=showcase",
      "MoUI native IME candidate anchor passed candidate-anchor candidate-window caret-rect surrounding-text",
    ].join("\n"),
  );
  expectFail(
    "reject IME log with platform protocol marker suffix",
    runRecorder([
      writeManifest("protocol-suffix-ime-marker.json", "linux"),
      "linux",
      "--host",
      "Linux Wayland CI",
      "--consumer-command",
      linuxConsumerCommand,
      "--candidate-anchor-log",
      protocolSuffixLog,
    ]),
    "candidate anchor log is missing expected marker: MoUI native IME runtime",
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
  rmSync(join(artifactRoot, "macos", "test-record-native-ime-evidence"), {
    recursive: true,
    force: true,
  });
}

console.log("native IME evidence recorder tests: ok");
