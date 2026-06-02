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
};

const passedObservations = Object.fromEntries(
  Object.keys(pendingObservations).map(key => [key, "yes"]),
);

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
        "moon build examples/showcase/macos --target native",
        "moon build examples/markdown_editor/macos --target native",
      ],
      runtimeEvidenceCommands: [
        "moon run examples/showcase/macos --target native",
        "moon run examples/markdown_editor/macos --target native",
      ],
      exampleTargets: [
        "examples/showcase/macos",
        "examples/showcase/macos_skia",
        "examples/markdown_editor/macos",
      ],
    }),
    baseEntry({
      name: "windows",
      host: "Windows MSVC host pending",
      routineCommands: [
        "moon test moui/backend/windows --target native",
        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\build_windows_msvc.ps1 -Package examples/showcase/windows -BuildOnly",
        "powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\package_windows_app_msvc.ps1 -Package examples/showcase/windows",
      ],
      runtimeEvidenceCommands: [
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows --target native }\"",
        "powershell -ExecutionPolicy Bypass -Command \"& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/markdown_editor/windows --target native }\"",
      ],
      exampleTargets: [
        "examples/showcase/windows",
        "examples/showcase/windows_skia",
        "examples/markdown_editor/windows",
      ],
    }),
    baseEntry({
      name: "linux",
      host: "Linux Wayland host pending",
      routineCommands: [
        "sh scripts/dev-check.sh --platform-examples-test",
        "moon build examples/showcase/linux --target native",
        "moon build examples/showcase/linux_skia --target native",
      ],
      runtimeEvidenceCommands: [
        "moon run examples/showcase/linux --target native",
        "moon run examples/showcase/linux_skia --target native",
      ],
      exampleTargets: [
        "examples/showcase/linux",
        "examples/showcase/linux_cosmic",
        "examples/showcase/linux_skia",
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
          consumerCommand: "moon run examples/showcase/windows --target native",
          observations: { ...passedObservations },
          artifacts: [
            "artifacts/platform-evidence/windows/window-smoke.md",
            "artifacts/platform-evidence/windows/showcase-run.log",
          ],
          notes: ["matching-host Windows evidence observed"],
        }
      : entry,
  ),
};
expectPass(
  "valid windows passed manifest",
  runValidator(writeFixture("valid-windows-passed.json", windowsPassed)),
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
