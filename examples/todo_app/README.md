# MoUI Todo 示例

`examples/todo_app` 是可复用的 Todo 应用包，当前通过
`examples/counter_web` 的 WebGPU shell 启动 Web 示例。

## 运行 Web 版本

从仓库根目录执行：

```powershell
moon build examples/counter_web --target js
Copy-Item examples/counter_web/bootstrap.js _build\js\debug\build\examples\counter_web\bootstrap.js -Force
Copy-Item examples/counter_web/index.html _build\js\debug\build\examples\counter_web\index.html -Force
python -m http.server 8080 --bind 127.0.0.1 --directory _build\js\debug\build\examples\counter_web\
```

然后在浏览器打开：

```text
http://127.0.0.1:8080/?app=todo
```

输入框支持点击聚焦、键盘输入、Backspace 删除，以及按 Enter 添加 Todo。

## 运行 Windows native 版本

从仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1 -BuildOnly
moon build examples/todo_windows --target native
.\_build\native\debug\build\examples\todo_windows\todo_windows.exe
```

Windows native 版本复用 `examples/todo_windows` 入口和 `backend/windows`
窗口后端。运行前需要按仓库根目录 `README.md` 准备 MSYS2 UCRT64、Vulkan 和
`wgpu-native` 静态库。

## 验证

```powershell
moon test examples/todo_app --target js
moon test examples/todo_app --target native
moon build examples/todo_windows --target native
```
