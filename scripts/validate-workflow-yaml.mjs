#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { readdirSync } from "node:fs";
import { join } from "node:path";

const usage = () => {
  console.error("Usage: node scripts/validate-workflow-yaml.mjs [--repo-root PATH]");
};

let repoRoot = process.cwd();
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--repo-root") {
    repoRoot = args[index + 1] ?? "";
    if (repoRoot === "") {
      usage();
      process.exit(2);
    }
    index += 1;
  } else if (arg === "--help" || arg === "-h") {
    usage();
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${arg}`);
    usage();
    process.exit(2);
  }
}

let entries;
try {
  entries = readdirSync(join(repoRoot, ".github", "workflows"));
} catch (error) {
  console.error(`Could not read .github/workflows: ${error.message}`);
  process.exit(1);
}

const files = entries
  .filter(name => name.endsWith(".yml") || name.endsWith(".yaml"))
  .sort()
  .map(name => join(".github", "workflows", name));

if (files.length === 0) {
  console.error("No workflow files found under .github/workflows.");
  process.exit(1);
}

// A GitHub workflow is YAML, but CI otherwise only finds out after the file is
// pushed: a plain scalar such as `description: recovery only: rebuild ...`
// makes GitHub reject the whole workflow with zero jobs. Parse every workflow
// offline with PyYAML (installed with yamllint on ubuntu-24.04 runners) so the
// failure is a pr-static step instead. `-I` keeps the cwd off sys.path, so a
// stray `yaml.py` in the repository cannot shadow the real parser.
const parser = String.raw`
import sys

try:
    import yaml
except ImportError:
    sys.stderr.write("PyYAML is required to validate workflow YAML: python3 -c 'import yaml'\n")
    sys.exit(2)

failed = 0
for path in sys.argv[1:]:
    try:
        with open(path, encoding="utf-8") as stream:
            yaml.safe_load(stream)
    except yaml.YAMLError as error:
        failed += 1
        print(f"FAIL {path}", file=sys.stderr)
        print(error, file=sys.stderr)
    except OSError as error:
        failed += 1
        print(f"FAIL {path}: {error}", file=sys.stderr)
    else:
        print(f"ok {path}")

if failed:
    print(f"{failed} workflow file(s) are not valid YAML.", file=sys.stderr)
    sys.exit(1)
print(f"All {len(sys.argv) - 1} workflow files are valid YAML.")
`;

const result = spawnSync("python3", ["-I", "-c", parser, ...files], {
  cwd: repoRoot,
  stdio: "inherit",
  shell: false,
});
if (result.error) {
  console.error(`Could not run python3: ${result.error.message}`);
  process.exit(1);
}
process.exit(result.status ?? 1);
