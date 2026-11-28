#!/usr/bin/env node

// Host-import contracts for the browser wasm-gc loader.
//
// `window_web` notification imports and the `__moonbit_fs_unstable`
// environment reads are recent additions to the wasm-gc import surface, and a
// loader gap in either one only surfaced in the nightly browser presentation
// smoke. Pin the entry points and their contracts here so the fast gate
// catches the next gap.

import { createWindowWebImports } from "../moui/backend/web/browser_runtime.js";
import { createMoonbitFsImports } from "../moui_web_renderer/runtime.js";

const assert = (condition, message) => {
  if (!condition) throw new Error(`web host imports: ${message}`);
};

const withGlobal = (name, value, body) => {
  const had = Object.prototype.hasOwnProperty.call(globalThis, name);
  const previous = globalThis[name];
  if (value === undefined) {
    delete globalThis[name];
  } else {
    globalThis[name] = value;
  }
  try {
    body();
  } finally {
    if (had) {
      globalThis[name] = previous;
    } else {
      delete globalThis[name];
    }
  }
};

// Build a MoonBit string the way `string_to_extern` does, through the handle
// ABI of the namespace under test (`finish_create_string` returns the extern
// value the MoonBit side then passes back in).
const stringExtern = (imports, value) => {
  const handle = imports.begin_create_string();
  for (let index = 0; index < value.length; index += 1) {
    imports.string_append_char(handle, value.charCodeAt(index));
  }
  return imports.finish_create_string(handle);
};

const fakeNotificationApi = (permission, { throwOnConstruct = false } = {}) => {
  const state = { constructed: [], prompts: 0 };
  class FakeNotification {
    constructor(title, options) {
      if (throwOnConstruct) throw new Error("notification construction failed");
      this.title = title;
      this.options = options;
      this.closed = false;
      state.constructed.push(this);
    }

    close() {
      this.closed = true;
    }
  }
  FakeNotification.permission = permission;
  FakeNotification.requestPermission = () => {
    state.prompts += 1;
    return Promise.resolve(permission);
  };
  return { FakeNotification, state };
};

// --- window_web notifications (`window/web/ffi.mbt`) ---

const windowWeb = createWindowWebImports({ canvasHost: "#canvas-host" });
for (const name of ["notification_permission", "notification_send", "notification_cancel"]) {
  assert(typeof windowWeb[name] === "function", `window_web.${name} must be callable`);
}

withGlobal("Notification", undefined, () => {
  assert(
    windowWeb.notification_permission() === 2,
    "an unavailable Notification API reports default/pending",
  );
  const id = stringExtern(windowWeb, "notice");
  assert(
    windowWeb.notification_send(id, id, id) === 0,
    "send without a Notification API reports failure",
  );
});

for (const [permission, expected] of [["granted", 1], ["denied", 0], ["default", 2]]) {
  const { FakeNotification } = fakeNotificationApi(permission);
  withGlobal("Notification", FakeNotification, () => {
    assert(
      windowWeb.notification_permission() === expected,
      `Notification.permission ${permission} maps to ${expected}`,
    );
  });
}

{
  const { FakeNotification, state } = fakeNotificationApi("granted");
  withGlobal("Notification", FakeNotification, () => {
    const id = stringExtern(windowWeb, "build-1");
    const title = stringExtern(windowWeb, "Build finished");
    const body = stringExtern(windowWeb, "3 targets green");
    assert(windowWeb.notification_send(id, title, body) === 1, "a granted send reports success");
    assert(state.constructed.length === 1, "a granted send constructs one notification");
    const [notification] = state.constructed;
    assert(notification.title === "Build finished", "the title reaches the notification");
    assert(notification.options.body === "3 targets green", "the body reaches the notification");
    assert(notification.options.tag === "build-1", "the notification id becomes the tag");
    assert(
      windowWeb.notification_cancel(stringExtern(windowWeb, "build-1")) === 1,
      "cancel finds the notification by id",
    );
    assert(notification.closed === true, "cancel closes the notification");
    assert(
      windowWeb.notification_cancel(stringExtern(windowWeb, "build-1")) === 0,
      "a second cancel reports the notification as missing",
    );
  });
}

{
  const { FakeNotification, state } = fakeNotificationApi("default");
  withGlobal("Notification", FakeNotification, () => {
    const id = stringExtern(windowWeb, "prompt");
    assert(
      windowWeb.notification_send(id, id, id) === 0,
      "a send under a pending permission reports failure",
    );
    assert(state.prompts === 1, "a pending permission asks the browser once");
    assert(state.constructed.length === 0, "a pending permission constructs no notification");
  });
}

{
  const { FakeNotification, state } = fakeNotificationApi("denied");
  withGlobal("Notification", FakeNotification, () => {
    const id = stringExtern(windowWeb, "denied");
    assert(
      windowWeb.notification_send(id, id, id) === 0,
      "a denied send reports failure",
    );
    assert(state.prompts === 0, "a denied permission does not prompt");
  });
}

{
  const { FakeNotification } = fakeNotificationApi("granted", { throwOnConstruct: true });
  withGlobal("Notification", FakeNotification, () => {
    const id = stringExtern(windowWeb, "boom");
    assert(
      windowWeb.notification_send(id, id, id) === 0,
      "a throwing constructor reports failure",
    );
  });
}

{
  const { FakeNotification } = fakeNotificationApi("granted");
  withGlobal("Notification", FakeNotification, () => {
    const emptyId = stringExtern(windowWeb, "");
    const title = stringExtern(windowWeb, "Title");
    assert(
      windowWeb.notification_send(emptyId, title, title) === 0,
      "an empty notification id reports failure",
    );
  });
}

// --- `__moonbit_fs_unstable` environment reads (`core/env/env_wasm.mbt`) ---

const fsImports = createMoonbitFsImports();
for (const name of ["get_env_var_exists", "get_env_var"]) {
  assert(typeof fsImports[name] === "function", `__moonbit_fs_unstable.${name} must be callable`);
}

const envName = "MOUI_WEB_HOST_IMPORT_TEST";
process.env[envName] = "1";
try {
  assert(
    fsImports.get_env_var_exists(stringExtern(fsImports, envName)) === 1,
    "a set variable reports that it exists",
  );
  assert(
    fsImports.get_env_var(stringExtern(fsImports, envName)) === "1",
    "a set variable reports its value",
  );
  assert(
    fsImports.get_env_var_exists(stringExtern(fsImports, `${envName}_MISSING`)) === 0,
    "a missing variable reports that it does not exist",
  );
  assert(
    fsImports.get_env_var(stringExtern(fsImports, `${envName}_MISSING`)) === "",
    "a missing variable reads as an empty string",
  );
} finally {
  delete process.env[envName];
}

withGlobal("process", undefined, () => {
  assert(
    fsImports.get_env_var_exists(stringExtern(fsImports, envName)) === 0,
    "a browser host has no environment",
  );
  assert(
    fsImports.get_env_var(stringExtern(fsImports, envName)) === "",
    "a browser host reads environment values as empty",
  );
});

console.log("web host import tests: ok");
