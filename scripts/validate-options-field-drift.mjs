#!/usr/bin/env node

/**
 * validate-options-field-drift.mjs
 *
 * Long-term gate for the host options pass-through contract (ADR 0019 /
 * renderer-backend-decoupling plan, re-derived after
 * backend-renderer-extraction deleted the 12 forwarding structs).
 *
 * Every `*Options` struct declared under moui/backend is the composition
 * root's configuration surface. A field that is declared and settable but
 * never read by any backend code is drift: the option silently does nothing.
 *
 * Rule: each struct field must have at least one accessor-style read
 * (`.field`) in production MoonBit sources, excluding the accessor
 * boilerplate itself (`self.field` inside the declaring package's getter).
 *
 * Exits 1 with the lost-field list when drift is found. `--root PATH` runs
 * the same analysis against a fixture tree (spec test support).
 */

import { readFileSync, readdirSync } from "node:fs";
import { join, relative } from "node:path";


export function analyzeOptionsFieldDrift(repoRoot) {
  const backendDir = join(repoRoot, "moui", "backend");
  const walk = (dir) => {
    let out = [];
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return out;
    }
    for (const entry of entries) {
      if (
        entry.name.startsWith(".") ||
        entry.name === "_build" ||
        entry.name === "node_modules"
      ) continue;
      const path = join(dir, entry.name);
      if (entry.isDirectory()) out = out.concat(walk(path));
      else out.push(path);
    }
    return out;
  };

  const backendFiles = walk(backendDir).filter(
    (file) => file.endsWith(".mbt") && !/(?:_test|_wbtest)\.mbt$/.test(file),
  );

  const structs = [];
  for (const file of backendFiles) {
    const content = readFileSync(file, "utf8");
    const structPattern =
      /pub(?:\(all\))?\s+struct\s+(\w*Options)\s*\{([^}]*)\}/g;
    let match;
    while ((match = structPattern.exec(content))) {
      const fields = [];
      for (const line of match[2].split("\n")) {
        const fieldMatch = line.match(/^\s*(?:priv\s+)?(\w+)\s*:/);
        if (fieldMatch) fields.push(fieldMatch[1]);
      }
      structs.push({ name: match[1], file, fields });
    }
  }

  const corpus = walk(repoRoot).filter(
    (file) =>
      file.endsWith(".mbt") &&
      !/(?:_test|_wbtest)\.mbt$/.test(file) &&
      !file.endsWith("pkg.generated.mbti"),
  );
  const corpusSources = corpus.map((file) => ({
    file,
    content: readFileSync(file, "utf8"),
  }));

  const lost = [];
  for (const struct of structs) {
    for (const field of struct.fields) {
      // Accessor boilerplate (`self.<field>`) is the getter itself, not a
      // consumption site; a genuine read goes through an options value.
      const readPattern = new RegExp(`(?<!self)\\.${field}\\b`);
      const read = corpusSources.some(({ content }) =>
        readPattern.test(content),
      );
      if (!read) {
        lost.push({
          struct: struct.name,
          field,
          declared: relative(repoRoot, struct.file),
        });
      }
    }
  }

  return { structs, lost };
}

function isMain() {
  // Sandboxed runners may omit argv[1] (direct execution); a basename check
  // stays robust against relative vs resolved script paths.
  if (!process.argv[1]) return true;
  return process.argv[1].endsWith("validate-options-field-drift.mjs");
}

if (isMain()) {
  const rootArgIndex = process.argv.indexOf("--root");
  const repoRoot =
    rootArgIndex >= 0 ? process.argv[rootArgIndex + 1] : process.cwd();
  const { structs, lost } = analyzeOptionsFieldDrift(repoRoot);
  if (structs.length === 0) {
    console.error(
      "options field drift: no *Options structs found under moui/backend — analyzer broken?",
    );
    process.exit(1);
  }
  if (lost.length > 0) {
    console.error("Options field drift (declared but never read):");
    for (const entry of lost) {
      console.error(`- ${entry.struct}.${entry.field} (${entry.declared})`);
    }
    process.exit(1);
  }
  console.log(
    `options field drift: ok (${structs.length} options structs, 0 lost fields)`,
  );
}
