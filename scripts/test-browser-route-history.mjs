#!/usr/bin/env node

import {
  browserRouteFromLocation,
  browserRouteUrl,
  normalizeWebRouteString,
} from "../moui/backend/web/browser_runtime.js";

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const location = {
  href: "https://example.test/MoUI/?debug=1&section=docs/getting-started&lang=zh-Hans&anchor=install",
  search: "?debug=1&section=docs/getting-started&lang=zh-Hans&anchor=install",
  hash: "",
};

assert(
  browserRouteFromLocation(location) === "docs/getting-started?lang=zh-Hans&anchor=install",
  "section routes must include non-routing query values",
);
assert(
  browserRouteFromLocation({ search: "?route=docs/getting-started%3Flang%3Dzh-Hans", hash: "" }) === "docs/getting-started?lang=zh-Hans",
  "legacy route parameter must remain readable",
);
assert(
  normalizeWebRouteString("/docs/getting-started?lang=zh-Hans/") === "docs/getting-started?lang=zh-Hans",
  "route normalization must trim path separators",
);
const url = browserRouteUrl("docs/getting-started?lang=zh-Hans&anchor=install", location);
assert(
  url.search === "?debug=1&section=docs%2Fgetting-started&lang=zh-Hans&anchor=install",
  "route serialization must preserve section, language, anchor, and debug separately",
);
assert(
  browserRouteFromLocation(url) === "docs/getting-started?lang=zh-Hans&anchor=install",
  "serialized locale route must round-trip",
);

console.log("browser route history tests: ok");
