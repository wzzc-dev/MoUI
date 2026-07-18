export class PreviewHost {
  constructor(frame, { runtimeSources }) {
    this.frame = frame;
    this.runtimeSources = Promise.resolve(runtimeSources);
    this.nonce = crypto.randomUUID();
    this.runToken = 0;
    this.frame.srcdoc = PreviewHost.idleDocument();
    window.addEventListener("message", event => {
      if (event.source === this.frame.contentWindow && event.data?.nonce === this.nonce) {
        window.dispatchEvent(new CustomEvent("moui-playground-preview", { detail: event.data }));
      }
    });
  }

  async run(wasmBytes) {
    this.stop();
    const token = this.runToken;
    const sources = await this.runtimeSources;
    if (token !== this.runToken) return;
    if (!sources?.runtime || !sources?.browser || !sources?.canvas2d) {
      throw new Error("Preview runtime assets are unavailable.");
    }
    const sourceLiteral = source => JSON.stringify(source).replaceAll("<", "\\u003c");
    const runtimeSource = sourceLiteral(sources.runtime);
    const browserSource = sourceLiteral(sources.browser);
    const canvas2dSource = sourceLiteral(sources.canvas2d);
    const bytes = new Uint8Array(wasmBytes);
    let binary = "";
    for (let offset = 0; offset < bytes.length; offset += 0x8000) {
      binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
    }
    const wasmBase64 = JSON.stringify(btoa(binary));
    const nonce = JSON.stringify(this.nonce);
    this.frame.style.display = "block";
    this.frame.srcdoc = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>*{box-sizing:border-box}html,body{position:fixed;inset:0;margin:0;overflow:hidden;background:#fff}#canvas-host{position:absolute;inset:0;overflow:hidden}canvas{display:block;width:100%;height:100%;touch-action:none}.moui-semantics-layer [role="button"]{pointer-events:auto!important;cursor:pointer}</style></head><body><div id="canvas-host"></div><script type="module">const nonce=${nonce};const report=(kind,value)=>parent.postMessage({nonce,kind,value},"*");window.addEventListener("error",event=>report("error",event.message));window.addEventListener("unhandledrejection",event=>report("error",String(event.reason)));const moduleUrl=source=>URL.createObjectURL(new Blob([source],{type:"text/javascript"}));const browserUrl=moduleUrl(${browserSource});const canvas2dUrl=moduleUrl(${canvas2dSource});const runtimeUrl=moduleUrl(${runtimeSource}.replaceAll("./browser_runtime.js",browserUrl).replaceAll("./canvas2d_runtime.js",canvas2dUrl));const wasmBinary=atob(${wasmBase64});const wasmBytes=Uint8Array.from(wasmBinary,character=>character.charCodeAt(0));const wasmUrl=URL.createObjectURL(new Blob([wasmBytes],{type:"application/wasm"}));window.addEventListener("unload",()=>[browserUrl,canvas2dUrl,runtimeUrl,wasmUrl].forEach(URL.revokeObjectURL));try{const runtime=await import(runtimeUrl);await runtime.bootMouiWasmGcApp({wasmUrl,canvasHost:"#canvas-host",onStatus:value=>report("status",value)});requestAnimationFrame(()=>window.dispatchEvent(new Event("resize")))}catch(error){report("error",error.stack||String(error))}</script></body></html>`;
  }

  stop() {
    this.runToken += 1;
    this.frame.srcdoc = PreviewHost.idleDocument();
    this.frame.style.display = "block";
  }

  static idleDocument() {
    return '<!doctype html><html><head><meta charset="utf-8"><style>html,body{position:fixed;inset:0;margin:0;background:#fff}</style></head><body></body></html>';
  }
}
