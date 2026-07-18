# Web Wasm-GC 平台说明

Web 路径是规范浏览器目标：`wasm-gc + window/web + browser WebGPU host imports`。它需要浏览器 WebGPU。如果 `navigator.gpu`、adapter 或 device 不可用，启动会明确失败。没有 JS-target fallback 分支。浏览器 Canvas 测量和 WebGPU 字形绘制共享由 `FontSpec` 生成的同一 CSS `system-ui` 字体栈；应用注册的嵌入字体可以通过浏览器字体 API 暴露，但远程字体加载不属于后端契约。
当 canvas 页面需要对已绘制静态文本使用浏览器原生选择/复制时，WebGPU 入口点可以选择启用 `webgpu.textSelection.enabled`。这会从每个已呈现帧的 `DrawText` 边界创建透明 DOM 文本层，同时让渲染、滚轮滚动和应用交互继续走 canvas 路径。该层上的短点击始终重新分派合成 canvas `pointerdown`/`pointerup`，因此交互式 overlay 文本（picker/datepicker 行和其他界面框架）仍会激活；只有拖动超过 click slop 才被视为原生文本选择并抑制激活。普通点击导致浏览器 selection 文本变化时，不得中止合成激活。
活动 Web 运行时服务桥通过浏览器宿主 import 打开外部 URL，该 import 调用 `window.open(..., "_blank", "noopener,noreferrer")`，并在浏览器阻止弹窗或 API 不可用时报告失败。Web copy/cut 快捷键从隐藏文本输入转发到运行时，并通过使用用户手势 `document.execCommand("copy")` 路径的浏览器宿主 import 写入选中文本。聚焦的浏览器文本输入仍可通过普通 input 事件粘贴；应用层异步剪贴板读取使用 `navigator.clipboard.readText()`，并在浏览器权限允许时通过 `HostServiceAsyncQueue` 完成。
Web 宿主现在公布 IME 就绪，因为本地 `window/web` 桥支持浏览器 composition 生命周期事件，并接受 MoUI `TextInputSession` IME 请求，用于启用输入、更新光标区域和更新 surrounding-text。这是浏览器文本输入观察；它不会使跨浏览器文本 shaping 具有确定性。
活动 Web 运行时现在把 pending 异步服务请求 drain 到浏览器回调中。剪贴板读取通过导出的 wasm 回调函数完成。当 `showOpenFilePicker` 可用时，打开文件选择会保留浏览器文件句柄，读取所选 `File.text()`，并把内容缓存在浏览器暴露的文件名下，使应用拥有的 handler 可以在文件对话框选择后继续使用共享文本文件读取服务。隐藏文件 input 仍是 fallback open/directory 路径；fallback open 可以导入文本，但不会产生可写句柄，而目录选择仍返回浏览器暴露的相对名称。类型化 completion 通过 `HostAppServices::completion_subscription` 交付。保存对话框在 `showSaveFilePicker` 可用时使用 File System Access API，保留所选句柄，并把后续 Web 文本文件写入路由到 `createWritable()`；没有可写句柄时，写入以 unavailable 完成。取消的 file picker 返回空选择。
浏览器宿主 import 在启动时读取 `prefers-color-scheme`，并通过 `window/web` 监听 media-query 变化；MoUI 把这些事件映射为运行时环境 color-scheme 更新。
canvas 上的浏览器文件拖放事件会通过 `HostEvent::DragDrop` 归一化，并分派给 `View::on_file_drop` 目标。Web 平台接收浏览器暴露的文件名或相对名称，而不是原生文件系统路径。
Web 后端刻意不使用 iframe overlay 实现 `web_view`。浏览器 wasm-gc 宿主报告原生 WebView 不可用，共享 WebView 应用逻辑的示例应在 Web 上渲染 fallback 表面。
Web 浏览器运行时从 `?route=`、`?section=` 或 hash 归一化初始 route，监听 `popstate`，并通过传入 `WebAppOptions` 的可选 `HostRouteSource` 分派这些 route 事件。入口点可以在 Web 边缘把抽象 route 命令翻译成 `web_history_push_route`、`web_history_replace_route`、`web_history_back` 和 `web_history_forward`，从而让共享应用逻辑保持平台中立。
共享运行时和渲染器文本契约见[文本系统](../text-system.md)。

可复用浏览器运行时资产位于 `backend/web/*.js` 下。每个 `examples/*/web_wasm/` 包只是应用特定 Web 入口点，并提供示例特定 wasm URL。canvas 宿主在 DPR 映射后报告逻辑事件坐标，并避免 CSS transform、border 和 padding，使 resize 和输入坐标保持稳定。当浏览器支持 `PointerEvent` 时，浏览器运行时把原生 pointer 事件视为权威，并且不会在该模式下从兼容 mouse/click fallback 合成 MoUI pointer activation。不支持 pointer-event 的旧环境仍使用带 transaction 去重的 mouse/click fallback，包括圆整坐标略有漂移的延迟 fallback 事件。这避免按钮释放后的慢速应用重建把同一浏览器点击重放为第二次 MoUI pointer activation。
canvas 上的触摸拖动会先合成 wheel 风格滚动 delta，然后才交给浏览器 fallback panning，因此网站首页等 `scroll_view` 表面可以通过移动端滑动手势滚动，同时仍使用与桌面滚轮和触控板相同的应用拥有 `on_scroll` 路径。
