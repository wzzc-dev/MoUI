export const fetchJson = async url => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status} ${response.statusText}`);
  }
  return await response.json();
};

export class CdpSession {
  constructor(webSocketUrl, timeoutMs) {
    this.webSocketUrl = webSocketUrl;
    this.timeoutMs = timeoutMs;
    this.nextId = 1;
    this.pending = new Map();
    this.events = [];
  }

  async connect() {
    this.socket = new WebSocket(this.webSocketUrl);
    this.socket.addEventListener("message", event => this.onMessage(event));
    await new Promise((resolve, reject) => {
      const timer = setTimeout(
        () => reject(new Error(`Timed out connecting to ${this.webSocketUrl}`)),
        this.timeoutMs,
      );
      this.socket.addEventListener("open", () => {
        clearTimeout(timer);
        resolve();
      }, { once: true });
      this.socket.addEventListener("error", error => {
        clearTimeout(timer);
        reject(new Error(`WebSocket connection failed: ${error.message || error.type}`));
      }, { once: true });
    });
  }

  onMessage(event) {
    const message = JSON.parse(event.data);
    if (message.id && this.pending.has(message.id)) {
      const { resolve, reject } = this.pending.get(message.id);
      this.pending.delete(message.id);
      if (message.error) {
        reject(new Error(message.error.message || JSON.stringify(message.error)));
      } else {
        resolve(message.result ?? {});
      }
      return;
    }
    if (message.method) {
      this.events.push(message);
    }
  }

  send(method, params = {}) {
    const id = this.nextId;
    this.nextId += 1;
    const payload = JSON.stringify({ id, method, params });
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Timed out waiting for CDP method ${method}`));
      }, this.timeoutMs);
      this.pending.set(id, {
        resolve: result => {
          clearTimeout(timer);
          resolve(result);
        },
        reject: error => {
          clearTimeout(timer);
          reject(error);
        },
      });
      this.socket.send(payload);
    });
  }

  close() {
    this.socket?.close();
  }
}

export const createPageTarget = async cdpUrl => {
  const response = await fetch(`${cdpUrl.replace(/\/+$/, "")}/json/new?about:blank`, {
    method: "PUT",
  });
  if (!response.ok) {
    throw new Error(`CDP target creation failed: ${response.status} ${response.statusText}`);
  }
  return await response.json();
};

export const closePageTarget = async ({ cdpUrl, id, timeoutMs, sleep }) => {
  try {
    const base = cdpUrl.replace(/\/+$/, "");
    const response = await fetch(`${base}/json/close/${encodeURIComponent(id)}`);
    if (!response.ok) return false;
    const deadline = Date.now() + Math.min(timeoutMs, 2000);
    while (Date.now() < deadline) {
      await sleep(100);
      const targets = await fetchJson(`${base}/json/list`);
      if (!targets.some(target => target?.id === id)) {
        return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
};

export const evaluate = async (session, expression) => {
  const result = await session.send("Runtime.evaluate", {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  if (result.exceptionDetails) {
    throw new Error(
      result.exceptionDetails.text || result.exceptionDetails.exception?.description || "evaluation failed",
    );
  }
  return result.result?.value;
};
