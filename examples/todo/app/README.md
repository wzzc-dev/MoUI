# MoUI Todo 示例

`examples/todo/app` 是可复用的 Todo 应用包。当前 Web 主线只使用 `wasm-gc`，不再保留 JS target Web 示例；Todo 的可运行入口目前是 Windows native。

## 运行 Windows Native

从仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1 -BuildOnly
moon build examples/todo/windows --target native
.\_build\native\debug\build\examples\todo\windows\windows.exe
```

输入框支持点击聚焦、键盘输入、Backspace 删除，以及按 Enter 添加 Todo。

## Web Wasm-GC 说明

Web host 已切到单一路径：`examples/counter/web_wasm --target wasm-gc`。Todo 如果需要 Web 入口，应按 `examples/counter/web_wasm` 的模式新增 `examples/todo/web_wasm`，直接复用 `backend/web` 和 `render/webgpu_adapter`，不要走 JS target fallback。

当前 Web 示例从仓库根目录启动：

```powershell
moon build examples/counter/web_wasm --target wasm-gc
python -m http.server 8080 --bind 127.0.0.1
```

然后打开：

```text
http://127.0.0.1:8080/examples/counter/web_wasm/index.html
```

## 验证

```powershell
moon test examples/todo/app --target native
moon build examples/todo/windows --target native
moon build examples/counter/web_wasm --target wasm-gc
```
