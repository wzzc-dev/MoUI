#!/usr/bin/env node

import {
  windowDependencyCacheZip,
  windowDependencyPackage,
  windowDependencyVersion,
} from "./lib/window-dependency.mjs";

const usage = () => {
  console.error("Usage: node scripts/window-dependency-info.mjs --print-version|--print-package|--print-cache-zip");
};

const args = process.argv.slice(2);
if (args.length !== 1 || args[0] === "--help" || args[0] === "-h") {
  usage();
  process.exit(args[0] === "--help" || args[0] === "-h" ? 0 : 2);
}

try {
  if (args[0] === "--print-version") {
    console.log(windowDependencyVersion());
  } else if (args[0] === "--print-package") {
    console.log(windowDependencyPackage());
  } else if (args[0] === "--print-cache-zip") {
    console.log(windowDependencyCacheZip());
  } else {
    usage();
    process.exit(2);
  }
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
