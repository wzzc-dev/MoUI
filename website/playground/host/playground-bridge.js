const STORAGE_KEY = "moui.playground.project.v1";

export class PlaygroundBridge {
  constructor({ workerUrl }) {
    this.worker = new Worker(workerUrl);
    this.listeners = new Set();
    this.latestRevision = 0;
    this.wasmExports = undefined;
    this.pendingResult = undefined;
    this.pendingProject = undefined;
    this.worker.addEventListener("message", event => {
      if (event.data?.type === "compile-result") this.emit(event.data.result);
    });
    this.worker.addEventListener("error", error => {
      this.emit({
        revision: this.latestRevision,
        status: "unavailable",
        diagnostics: [{ severity: "error", message: String(error.message || error) }],
      });
    });
  }

  attach(target) {
    target.addEventListener("moui-playground-compile", event => {
      if (event.detail) this.compile(event.detail);
    });
    target.__mouiPlaygroundBridge = this;
    const params = new URLSearchParams(window.location.search);
    if (params.has("project")) this.loadFromShareUrl();
    else if (params.has("example")) this.loadFromExample(params.get("example"));
    else this.loadFromStorage();
  }

  onResult(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  emit(result) {
    window.__mouiPlaygroundLastResult = result;
    this.sendResultToMoonBit(result);
    for (const listener of this.listeners) listener(result);
    window.dispatchEvent(new CustomEvent("moui-playground-compile-result", { detail: result }));
    this.saveResult(result);
  }

  compile({ revision, files, lessonId }) {
    this.latestRevision = Number(revision);
    this.save({
      files: Object.entries(files || {}).map(([path, source]) => ({ path, source })),
      lesson_id: lessonId || "",
    });
    this.worker.postMessage({ type: "compile", revision, files, lessonId });
  }

  setWasmExports(wasmExports) {
    this.wasmExports = wasmExports;
    if (this.pendingResult) {
      const result = this.pendingResult;
      this.pendingResult = undefined;
      this.sendResultToMoonBit(result);
    }
    if (this.pendingProject) this.sendProjectToMoonBit(this.pendingProject);
  }

  sendResultToMoonBit(result) {
    const begin = this.wasmExports?.playground_begin_compile_result;
    const append = this.wasmExports?.playground_append_compile_result_char;
    const finish = this.wasmExports?.playground_finish_compile_result;
    if (!begin || !append || !finish) {
      this.pendingResult = result;
      return;
    }
    const status = result.status === "success"
      ? "Success"
      : result.status === "unavailable" ? "Unavailable" : "Failed";
    const payload = JSON.stringify({
      revision: Number(result.revision || 0),
      status,
      diagnostics: (result.diagnostics || []).map(item => ({
        severity: String(item.severity || "error"),
        message: String(item.message || "Compiler error"),
        file: String(item.file || "main.mbt"),
        line: Number(item.line || 1),
        column: Number(item.column || 1),
        end_line: Number(item.endLine || item.line || 1),
        end_column: Number(item.endColumn || item.column || 1),
      })),
    });
    begin();
    for (const character of payload) append(character.codePointAt(0));
    finish();
  }

  sendProjectToMoonBit(project) {
    const begin = this.wasmExports?.playground_begin_project_load;
    const append = this.wasmExports?.playground_append_project_load_char;
    const finish = this.wasmExports?.playground_finish_project_load;
    if (!begin || !append || !finish) return;
    const payload = JSON.stringify(project);
    begin();
    for (const character of payload) append(character.codePointAt(0));
    finish();
    this.pendingProject = undefined;
  }

  status(message) {
    window.dispatchEvent(new CustomEvent("moui-playground-status", { detail: String(message) }));
  }

  save(project) {
    const payload = { schema_version: 1, ...project };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
    return payload;
  }

  queueProject(value) {
    if (!value || !Array.isArray(value.files)) return;
    const project = {
      schema_version: Number(value.schema_version ?? value.schemaVersion ?? 1),
      files: value.files,
      lesson_id: String(value.lesson_id ?? value.lessonId ?? ""),
    };
    if (project.schema_version !== 1) return;
    this.pendingProject = project;
    if (this.wasmExports) this.sendProjectToMoonBit(project);
  }

  loadFromStorage() {
    try {
      const value = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
      if (value) this.queueProject(value);
    } catch {
      localStorage.removeItem(STORAGE_KEY);
    }
  }

  loadFromShareUrl() {
    const encoded = new URLSearchParams(window.location.search).get("project");
    if (!encoded) return;
    try {
      const padded = encoded.replaceAll("-", "+").replaceAll("_", "/")
        + "=".repeat((4 - encoded.length % 4) % 4);
      const value = JSON.parse(decodeURIComponent(escape(atob(padded))));
      this.queueProject(value);
    } catch {
      this.status("The shared project link is invalid.");
    }
  }

  async loadFromExample(id) {
    if (!/^[a-z0-9-]+$/.test(String(id || ""))) return;
    try {
      const root = `./lessons/${id}`;
      const [main, pkg] = await Promise.all([
        fetch(`${root}/main.mbt`).then(response => response.ok ? response.text() : Promise.reject(new Error("Lesson source is unavailable."))),
        fetch(`${root}/moon.pkg`).then(response => response.ok ? response.text() : Promise.reject(new Error("Lesson package is unavailable."))),
      ]);
      this.queueProject({
        schema_version: 1,
        lesson_id: id,
        files: [{ path: "main.mbt", source: main }, { path: "moon.pkg", source: pkg }],
      });
    } catch (error) {
      this.status(error instanceof Error ? error.message : String(error));
    }
  }

  selectExample(id) {
    const value = String(id || "");
    if (!/^[a-z0-9-]+$/.test(value)) return;
    const url = new URL(window.location.href);
    url.searchParams.delete("project");
    url.searchParams.set("example", value);
    window.history.replaceState({}, "", url);
    void this.loadFromExample(value);
  }

  createShareUrl(project) {
    const json = JSON.stringify({ schema_version: 1, ...project });
    const encoded = btoa(unescape(encodeURIComponent(json))).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
    if (encoded.length > 64000) throw new Error("The project is too large for a share URL.");
    const url = new URL(window.location.href);
    url.searchParams.set("project", encoded);
    return url.toString();
  }

  saveResult(result) {
    if (result.status === "success") {
      window.dispatchEvent(new CustomEvent("moui-playground-progress", { detail: result }));
    }
  }
}
