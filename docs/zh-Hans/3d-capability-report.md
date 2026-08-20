# 3D 能力报告

`moui_3d` 是一个独立的实验性 3D viewer addon，当前提供静态 glTF/GLB
解析、轨道相机、CPU 拾取和最新值视口快照绑定。

当前 GPU 路线包括：

- macOS 原生 WGPU：通过 CAMetalLayer 子表面呈现；
- Web wasm-gc WebGPU：通过独立的 secondary canvas 呈现。

该 addon 不改变 MoUI 的 2D draw contract，也不提供 CPU 3D fallback。代码和
协议测试可以在本地运行，但在匹配设备上完成真实呈现和非空像素验证之前，仍保持
实验性状态。
