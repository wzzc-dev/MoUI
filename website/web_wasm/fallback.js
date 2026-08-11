// website/web_wasm/fallback.js
// 静态降级视图:当浏览器不支持 WebAssembly 或缺少 wasm-gc 扩展时,
// index.html 调用 window.mouiShowFallback({ reason })。本文件渲染:
//   1. Canvas2D 品牌 hero(渐变 + 标题 + 徽章)
//   2. 文档目录(来自 docs/catalog.json 或 docs/zh-Hans/catalog.json)+ 极简 markdown 阅读视图
//   3. Canvas2D showcase 截图画廊(assets/screenshots/*.webp)
// 不依赖任何外部库;markdown 渲染为白名单子集(标题/段落/列表/表格/代码块/链接/粗斜体/引用)。
(function () {
  "use strict";

  const I18N = {
    en: {
      badge: "Static view",
      title: "MoUI",
      subtitle: "MoonBit GUI Framework",
      noWasmTitle: "WebAssembly is not available",
      noWasm:
        "This browser does not support WebAssembly, so the interactive MoUI application cannot run here.",
      noWasmGcTitle: "wasm-gc is not supported by this browser",
      noWasmGc:
        "This browser supports WebAssembly, but not the wasm-gc (WebAssembly GC) extension the interactive app requires. A static view of the documentation is shown instead.",
      cta: "Upgrade to a recent version of Chrome, Edge, Firefox, or Safari to get the full interactive experience.",
      docsTitle: "Documentation",
      back: "← Back to index",
      galleryTitle: "Showcases",
      galleryHint: "Static screenshots (interactive demos need a wasm-gc browser)",
      loadError: "Failed to load content. If you are viewing this page from the repository, serve it over HTTP.",
      languageName: "English",
    },
    zh: {
      badge: "静态视图",
      title: "MoUI",
      subtitle: "MoonBit GUI Framework",
      noWasmTitle: "当前浏览器不支持 WebAssembly",
      noWasm:
        "当前浏览器不支持 WebAssembly,无法在此运行 MoUI 交互应用。以下为静态文档视图。",
      noWasmGcTitle: "当前浏览器缺少 wasm-gc 支持",
      noWasmGc:
        "当前浏览器支持 WebAssembly,但不支持交互应用所需的 wasm-gc(WebAssembly GC)扩展。已切换为静态文档视图。",
      cta: "升级到最新版 Chrome / Edge / Firefox / Safari,可体验完整交互。",
      docsTitle: "文档",
      back: "← 返回目录",
      galleryTitle: "示例展示",
      galleryHint: "静态截图(交互演示需要支持 wasm-gc 的浏览器)",
      loadError: "内容加载失败。若从仓库目录直接打开,请改用 HTTP 方式访问本页。",
      languageName: "简体中文",
    },
  };

  const SHOWCASES = [
    ["Showcase", "assets/screenshots/showcase.webp"],
    ["Markdown Editor", "assets/screenshots/markdown_editor.webp"],
    ["Mo Workbench", "assets/screenshots/mo_workbench.webp"],
    ["Excel", "assets/screenshots/excel.webp"],
    ["WebView", "assets/screenshots/webview.webp"],
    ["Android", "assets/screenshots/android-componentgallery.webp"],
    ["iOS", "assets/screenshots/ios-componentgallery.webp"],
    ["HarmonyOS", "assets/screenshots/harmonyos-componentgallery.webp"],
  ];

  const CATALOG_PATHS = { en: "docs/catalog.json", zh: "docs/zh-Hans/catalog.json" };

  let view = null;
  let lang = "en";
  let t = I18N.en;
  let reason = "no-wasm-gc";
  const images = new Map(); // url -> HTMLImageElement | null(加载失败缓存 null)

  // ---------------------------------------------------------------- i18n

  function pickLang() {
    const nav = typeof navigator !== "undefined" ? navigator : null;
    const l = (nav && (nav.language || nav.userLanguage)) || "";
    return /^zh/i.test(l) ? "zh" : "en";
  }

  function applyLang() {
    t = I18N[lang];
    const buttons = view.querySelectorAll(".fallback-langs button");
    buttons.forEach((b) => b.classList.toggle("active", b.dataset.lang === lang));
  }

  // ---------------------------------------------------------------- helpers

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  async function fetchText(url) {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`HTTP ${response.status} for ${url}`);
    return response.text();
  }

  // ---------------------------------------------------------------- markdown subset renderer

  function renderInline(text) {
    // 先抽出行内代码,避免其内容被后续 bold/italic/链接规则污染。
    const codes = [];
    let out = text.replace(/`([^`]+)`/g, (_, code) => {
      codes.push(code);
      return `\u0000${codes.length - 1}\u0000`;
    });
    out = escapeHtml(out);
    // 图片 ![alt](url)(url/alt 已随整体 escapeHtml 转义)
    out = out.replace(
      /!\[([^\]]*)\]\(([^)\s]+)\)/g,
      (_, alt, url) => `<img src="${url}" alt="${alt}" loading="lazy">`,
    );
    // 链接 [text](url)
    out = out.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, label, url) => {
      const external = /^https?:\/\//.test(url);
      return (
        `<a href="${url}" data-md-link="${external ? "external" : "internal"}"` +
        (external ? ' target="_blank" rel="noopener"' : "") +
        `>${label}</a>`
      );
    });
    // 粗体
    out = out.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    // 斜体(不与粗体冲突的 *x*)
    out = out.replace(/(^|[^*])\*([^*\s][^*]*)\*/g, "$1<em>$2</em>");
    // 还原行内代码
    out = out.replace(/\u0000(\d+)\u0000/g, (_, index) => `<code>${escapeHtml(codes[Number(index)])}</code>`);
    return out;
  }

  function renderMarkdown(md) {
    if (!md.endsWith("\n")) md += "\n"; // 表格/代码块正则依赖行尾换行
    const placeholders = [];
    // 代码块(先提取,占位)
    md = md.replace(/```[^\n]*\n([\s\S]*?)```/g, (_, code) => {
      const id = placeholders.length;
      placeholders.push(`<pre class="fallback-markdown">${escapeHtml(code.replace(/\n$/, ""))}</pre>`);
      return `__MOUI_BLOCK_${id}__\n`; // 尾部换行保证占位符独立成行
    });
    // 表格(表头行 + 分隔行 + 数据行)
    md = md.replace(
      /(^\|.+\|\s*\n)(^\|[\s:|-]+\|\s*\n(?:\|.+\|\s*\n)+)/gm,
      (block) => {
        const id = placeholders.length;
        const lines = block.trim().split("\n");
        const parseRow = (line) => line.replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim());
        const header = parseRow(lines[0]);
        const rows = lines.slice(2).map(parseRow);
        let html =
          '<table class="fallback-table"><thead><tr>' +
          header.map((h) => `<th>${renderInline(h)}</th>`).join("") +
          "</tr></thead><tbody>";
        for (const row of rows) {
          html += "<tr>" + row.map((c) => `<td>${renderInline(c)}</td>`).join("") + "</tr>";
        }
        html += "</tbody></table>";
        placeholders.push(html);
        return `__MOUI_BLOCK_${id}__\n`; // 尾部换行保证占位符独立成行
      },
    );

    const out = [];
    let list = null;
    const flushList = () => {
      if (!list) return;
      const tag = list.ordered ? "ol" : "ul";
      out.push(
        `<${tag}>` + list.items.map((i) => `<li>${renderInline(i)}</li>`).join("") + `</${tag}>`,
      );
      list = null;
    };
    for (const rawLine of md.split("\n")) {
      const line = rawLine.replace(/\s+$/, "");
      const block = line.match(/^__MOUI_BLOCK_(\d+)__$/);
      if (block) {
        flushList();
        out.push(placeholders[Number(block[1])]);
        continue;
      }
      if (/^\s*$/.test(line)) {
        flushList();
        continue;
      }
      const heading = line.match(/^(#{1,6})\s+(.*)$/);
      if (heading) {
        flushList();
        const level = heading[1].length;
        out.push(`<h${level}>${renderInline(heading[2])}</h${level}>`);
        continue;
      }
      if (/^\s*(---|\*\*\*+)\s*$/.test(line)) {
        flushList();
        out.push("<hr>");
        continue;
      }
      const quote = line.match(/^\s*>\s?(.*)$/);
      if (quote) {
        flushList();
        out.push(`<blockquote>${renderInline(quote[1])}</blockquote>`);
        continue;
      }
      const ul = line.match(/^\s*[-*]\s+(.*)$/);
      if (ul) {
        if (!list || list.ordered) {
          flushList();
          list = { ordered: false, items: [] };
        }
        list.items.push(ul[1]);
        continue;
      }
      const ol = line.match(/^\s*\d+[.)]\s+(.*)$/);
      if (ol) {
        if (!list || !list.ordered) {
          flushList();
          list = { ordered: true, items: [] };
        }
        list.items.push(ol[1]);
        continue;
      }
      flushList();
      out.push(`<p>${renderInline(line)}</p>`);
    }
    flushList();
    return out.join("\n");
  }

  function resolveDocPath(basePath, href) {
    if (/^https?:\/\//.test(href) || href.startsWith("#")) return href;
    const clean = href.replace(/^\//, "");
    const baseDir = basePath.includes("/") ? basePath.slice(0, basePath.lastIndexOf("/") + 1) : "";
    const parts = (baseDir + clean).split("/");
    const result = [];
    for (const part of parts) {
      if (part === "" || part === ".") continue;
      if (part === "..") result.pop();
      else result.push(part);
    }
    return result.join("/");
  }

  // ---------------------------------------------------------------- canvas drawing

  function setupCanvas(canvas, width, height) {
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(1, Math.round(width * dpr));
    canvas.height = Math.max(1, Math.round(height * dpr));
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    const ctx = canvas.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return ctx;
  }

  function drawHero() {
    const canvas = view.querySelector("#fallback-hero");
    if (!canvas) return;
    const width = view.clientWidth;
    const height = 300;
    const ctx = setupCanvas(canvas, width, height);

    const gradient = ctx.createLinearGradient(0, 0, width, height);
    gradient.addColorStop(0, "#0b1120");
    gradient.addColorStop(0.55, "#172554");
    gradient.addColorStop(1, "#1e3a8a");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);

    // 装饰圆
    ctx.save();
    ctx.globalAlpha = 0.08;
    ctx.fillStyle = "#ffffff";
    ctx.beginPath();
    ctx.arc(width - 60, 40, 150, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(40, height - 40, 110, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    ctx.font = '600 15px "SFMono-Regular", ui-monospace, Menlo, Consolas, monospace';
    const badgeText = `MoUI · ${t.badge}`;
    const badgeWidth = ctx.measureText(badgeText).width + 28;
    ctx.fillStyle = "rgba(255,255,255,0.12)";
    ctx.beginPath();
    ctx.roundRect(24, 26, badgeWidth, 30, 15);
    ctx.fill();
    ctx.fillStyle = "#93c5fd";
    ctx.fillText(badgeText, 24 + 14, 46);

    ctx.fillStyle = "#f8fafc";
    ctx.font = '700 64px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif';
    ctx.fillText(t.title, 24, 130);

    ctx.fillStyle = "#93c5fd";
    ctx.font = '400 22px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif';
    ctx.fillText(t.subtitle, 26, 168);

    ctx.fillStyle = "rgba(226,232,240,0.85)";
    ctx.font = '400 14px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif';
    const title = reason === "no-wasm" ? t.noWasmTitle : t.noWasmGcTitle;
    ctx.fillText(title, 26, 222);
    ctx.fillStyle = "rgba(148,163,184,0.9)";
    ctx.font = '400 13px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif';
    ctx.fillText(t.cta, 26, 248);
  }

  function loadScreenshot(url, onDone) {
    if (images.has(url)) {
      onDone();
      return;
    }
    const img = new Image();
    img.onload = () => {
      images.set(url, img);
      onDone();
    };
    img.onerror = () => {
      images.set(url, null);
      onDone();
    };
    img.src = url;
  }

  function drawGallery() {
    const canvas = view.querySelector("#fallback-gallery-canvas");
    if (!canvas) return;
    const width = view.clientWidth;
    const gap = 16;
    const cols = width < 640 ? 2 : 4;
    const cardW = Math.max(120, (width - (cols + 1) * gap) / cols);
    const cardH = cardW * 0.68;
    const titleH = 26;
    const rows = Math.ceil(SHOWCASES.length / cols);
    const height = rows * (cardH + titleH) + (rows + 1) * gap;
    const ctx = setupCanvas(canvas, width, height);

    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = "#0f172a";
    ctx.fillRect(0, 0, width, height);

    SHOWCASES.forEach(([label, url], index) => {
      const col = index % cols;
      const row = Math.floor(index / cols);
      const x = gap + col * (cardW + gap);
      const y = gap + row * (cardH + titleH + gap);
      const img = images.get(url) || null;
      // 卡片背景
      ctx.fillStyle = "#1e293b";
      ctx.beginPath();
      ctx.roundRect(x, y, cardW, cardH, 10);
      ctx.fill();
      if (img) {
        ctx.save();
        ctx.beginPath();
        ctx.roundRect(x, y, cardW, cardH, 10);
        ctx.clip();
        // cover 裁剪
        const scale = Math.max(cardW / img.naturalWidth, cardH / img.naturalHeight);
        const dw = img.naturalWidth * scale;
        const dh = img.naturalHeight * scale;
        ctx.drawImage(img, x - (dw - cardW) / 2, y - (dh - cardH) / 2, dw, dh);
        ctx.restore();
      } else {
        ctx.fillStyle = "#334155";
        ctx.font = '12px "SFMono-Regular", ui-monospace, Menlo, Consolas, monospace';
        ctx.fillText(img === null ? "unavailable" : "loading…", x + 10, y + cardH / 2);
      }
      ctx.fillStyle = "#cbd5e1";
      ctx.font = '600 13px -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif';
      ctx.fillText(label, x, y + cardH + 18);
    });
  }

  function redraw() {
    drawHero();
    drawGallery();
  }

  // ---------------------------------------------------------------- doc view

  let currentDocPath = "";

  function openDoc(path, backTo) {
    currentDocPath = path;
    const docEl = view.querySelector("#fallback-doc");
    const navEl = view.querySelector("#fallback-nav");
    const galleryEl = view.querySelector("#fallback-gallery");
    docEl.hidden = false;
    navEl.hidden = true;
    galleryEl.hidden = true;
    docEl.innerHTML = `<p class="fallback-loading">…</p>`;
    fetchText(path)
      .then((md) => {
        docEl.innerHTML = renderMarkdown(md);
        docEl.scrollTop = 0;
      })
      .catch((error) => {
        docEl.innerHTML = `<p class="fallback-error">${escapeHtml(t.loadError)}<br><code>${escapeHtml(
          error && error.message ? error.message : String(error),
        )}</code></p>`;
      });
    const back = view.querySelector("#fallback-back");
    back.hidden = false;
    back.onclick = () => {
      docEl.hidden = true;
      back.hidden = true;
      navEl.hidden = false;
      galleryEl.hidden = false;
      if (backTo) backTo();
    };
  }

  function bindDocLinks() {
    const docEl = view.querySelector("#fallback-doc");
    docEl.addEventListener("click", (event) => {
      const anchor = event.target.closest("a[data-md-link]");
      if (!anchor) return;
      if (anchor.dataset.mdLink === "external") return; // target=_blank 已处理
      event.preventDefault();
      const path = resolveDocPath(currentDocPath, anchor.getAttribute("href"));
      if (path.endsWith(".md")) {
        openDoc(path);
      } else {
        window.location.href = anchor.getAttribute("href");
      }
    });
  }

  async function renderDocs(language) {
    const navEl = view.querySelector("#fallback-nav");
    navEl.innerHTML = "";
    navEl.appendChild(el("h2", "fallback-section-title", t.docsTitle));
    let catalog;
    try {
      catalog = JSON.parse(await fetchText(CATALOG_PATHS[language]));
    } catch (error) {
      navEl.appendChild(el("p", "fallback-error", `${t.loadError} (${CATALOG_PATHS[language]})`));
      return;
    }
    const groupTitle = (id) => {
      const group = (catalog.groups || []).find((g) => g.id === id);
      return group ? group.title : id;
    };
    const byGroup = {};
    for (const entry of catalog.entries || []) {
      (byGroup[entry.group] = byGroup[entry.group] || []).push(entry);
    }
    for (const group of catalog.groups || []) {
      const entries = byGroup[group.id] || [];
      if (entries.length === 0) continue;
      navEl.appendChild(el("h3", "fallback-group", groupTitle(group.id)));
      for (const entry of entries) {
        const button = el("button", "fallback-entry");
        button.type = "button";
        const titleNode = el("span", "t", entry.title);
        const summaryNode = el("span", "s", entry.summary || "");
        button.appendChild(titleNode);
        if (entry.summary) button.appendChild(summaryNode);
        button.onclick = () => openDoc(entry.path);
        navEl.appendChild(button);
      }
    }
  }

  // ---------------------------------------------------------------- gallery boot

  function bootGallery() {
    const galleryEl = view.querySelector("#fallback-gallery");
    galleryEl.appendChild(el("h2", "fallback-section-title fallback-gallery-title", t.galleryTitle));
    galleryEl.appendChild(el("p", "fallback-hint", t.galleryHint));
    const canvas = el("canvas");
    canvas.id = "fallback-gallery-canvas";
    galleryEl.appendChild(canvas);
    let pending = SHOWCASES.length;
    const done = () => {
      pending -= 1;
      if (pending <= 0) drawGallery();
    };
    for (const [, url] of SHOWCASES) loadScreenshot(url, done);
  }

  // ---------------------------------------------------------------- mount

  function mount() {
    view = document.getElementById("fallback-view");
    if (!view || view.dataset.mounted) return;
    view.dataset.mounted = "1";
    view.innerHTML = "";

    const hero = el("canvas");
    hero.id = "fallback-hero";
    view.appendChild(hero);

    const content = el("div", "fallback-content");
    view.appendChild(content);

    const langs = el("div", "fallback-langs");
    for (const code of ["zh", "en"]) {
      const button = el("button", "", I18N[code].languageName);
      button.dataset.lang = code;
      button.type = "button";
      button.onclick = () => {
        lang = code;
        applyLang();
        redraw();
        const galleryTitle = view.querySelector(".fallback-gallery-title");
        if (galleryTitle) galleryTitle.textContent = t.galleryTitle;
        const galleryHint = view.querySelector("#fallback-gallery .fallback-hint");
        if (galleryHint) galleryHint.textContent = t.galleryHint;
        renderDocs(lang);
      };
      langs.appendChild(button);
    }
    content.appendChild(langs);

    const notice = el("div", "fallback-notice");
    content.appendChild(notice);

    const back = el("button", "fallback-back", t.back);
    back.id = "fallback-back";
    back.type = "button";
    back.hidden = true;
    content.appendChild(back);

    const nav = el("nav", "");
    nav.id = "fallback-nav";
    content.appendChild(nav);

    const doc = el("article", "fallback-doc");
    doc.id = "fallback-doc";
    doc.hidden = true;
    content.appendChild(doc);

    const gallery = el("section", "");
    gallery.id = "fallback-gallery";
    content.appendChild(gallery);

    bindDocLinks();
    window.addEventListener("resize", () => {
      if (!view.hidden) redraw();
    });
  }

  function show(options) {
    reason = (options && options.reason) || "no-wasm-gc";
    lang = pickLang();
    mount();
    // 老浏览器(无 wasm-gc 的引擎普遍早于 2022)可能没有 ctx.roundRect。
    if (typeof CanvasRenderingContext2D !== "undefined" && !CanvasRenderingContext2D.prototype.roundRect) {
      CanvasRenderingContext2D.prototype.roundRect = function (x, y, w, h, r) {
        const radius = typeof r === "number" ? r : (r && r.length ? r[0] : 0);
        this.moveTo(x + radius, y);
        this.arcTo(x + w, y, x + w, y + h, radius);
        this.arcTo(x + w, y + h, x, y + h, radius);
        this.arcTo(x, y + h, x, y, radius);
        this.arcTo(x, y, x + w, y, radius);
        this.closePath();
        return this;
      };
    }
    applyLang();
    const notice = view.querySelector(".fallback-notice");
    notice.innerHTML = "";
    notice.appendChild(el("strong", "", reason === "no-wasm" ? t.noWasmTitle : t.noWasmGcTitle));
    notice.appendChild(el("div", "", reason === "no-wasm" ? t.noWasm : t.noWasmGc));
    notice.appendChild(el("div", "fallback-hint", t.cta));
    bootGallery();
    redraw();
    renderDocs(lang);
  }

  window.mouiShowFallback = show;
})();
