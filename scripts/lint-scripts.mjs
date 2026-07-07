#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { extname, join, relative, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { repoRoot } from "./lib/window-dependency.mjs";

const usage = () => {
  console.error("Usage: node scripts/lint-scripts.mjs [--profile pr|full]");
};

let profile = "pr";
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--profile") {
    profile = args[index + 1] ?? "";
    index += 1;
  } else if (args[index] === "--help" || args[index] === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${args[index]}`);
    usage();
    process.exit(2);
  }
}

if (!["pr", "full"].includes(profile)) {
  usage();
  process.exit(2);
}

const walk = dir => {
  const files = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === "node_modules" || entry.name === ".git") continue;
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walk(path));
    } else {
      files.push(path);
    }
  }
  return files;
};

const run = (argv, options = {}) => {
  console.log(`\n==> ${argv.join(" ")}`);
  const result = spawnSync(argv[0], argv.slice(1), {
    cwd: repoRoot,
    stdio: "inherit",
    shell: false,
    ...options,
  });
  if (result.status !== 0 || result.error) {
    if (result.error) console.error(result.error.message);
    process.exit(result.status ?? 1);
  }
};

const commandExists = command => {
  const result = spawnSync(command, ["--version"], {
    cwd: repoRoot,
    stdio: "ignore",
    shell: false,
  });
  return result.status === 0;
};

const scriptFiles = walk(resolve(repoRoot, "scripts"));
const nodeFiles = scriptFiles.filter(path => extname(path) === ".mjs").sort();
for (const file of nodeFiles) {
  run(["node", "--check", relative(repoRoot, file)]);
}

const shellFiles = scriptFiles.filter(path => extname(path) === ".sh").sort();
for (const file of shellFiles) {
  const text = readFileSync(file, "utf8");
  const shell = text.startsWith("#!/usr/bin/env bash") || text.startsWith("#!/bin/bash") ? "bash" : "sh";
  run([shell, "-n", relative(repoRoot, file)]);
}

const psFiles = scriptFiles.filter(path => extname(path).toLowerCase() === ".ps1").sort();
if (commandExists("pwsh")) {
  for (const file of psFiles) {
    const rel = relative(repoRoot, file);
    run([
      "pwsh",
      "-NoProfile",
      "-Command",
      `$errors=$null; [System.Management.Automation.Language.Parser]::ParseFile('${rel.replaceAll("'", "''")}', [ref]$null, [ref]$errors) > $null; if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_.Message }; exit 1 }`,
    ]);
  }
  if (profile === "full") {
    const analyzer = spawnSync("pwsh", [
      "-NoProfile",
      "-Command",
      "Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue | Select-Object -First 1",
    ], { cwd: repoRoot, encoding: "utf8" });
    if (analyzer.stdout.trim() === "") {
      console.error("PSScriptAnalyzer is required for --profile full.");
      process.exit(1);
    }
    for (const file of psFiles) {
      run(["pwsh", "-NoProfile", "-Command", `Invoke-ScriptAnalyzer -Path '${relative(repoRoot, file).replaceAll("'", "''")}' -Severity Error`]);
    }
  }
} else if (profile === "full") {
  console.error("pwsh is required for PowerShell syntax checks in --profile full.");
  process.exit(1);
} else {
  console.log("\nSkipping PowerShell syntax checks because pwsh is not available.");
}

if (profile === "full") {
  if (!commandExists("shellcheck")) {
    console.error("shellcheck is required for --profile full.");
    process.exit(1);
  }
  for (const file of shellFiles) {
    run(["shellcheck", relative(repoRoot, file)]);
  }
}

if (!existsSync(resolve(repoRoot, "scripts/check.mjs"))) {
  console.error("scripts/check.mjs is missing.");
  process.exit(1);
}

console.log(`\nScript lint (${profile}) passed.`);
