# 3D 能力报告

wzzc-dev/moui_3d 是独立的实验性 addon。0.1.10 是 breaking release，不改变
MoUI 的 2D draw contract，也不改变 Native Skia 主线。

| 能力 | 状态 | 证据 |
|---|---|---|
| CPU 数学、齐次变换、场景树、AABB、射线拾取 | 已实现 | moon test moui_3d --target native |
| glTF/GLB 校验与 accessor 解码 | 已实现（文档子集） | loader tests；data URI、sparse accessor、sampler/camera/scene、skin、morph 覆盖 |
| PBR 材质与 base/normal/occlusion/emissive 纹理字段 | 已实现 | 材质层级回归测试 |
| STEP/LINEAR/CUBICSPLINE 动画通道 | 已实现（CPU） | animation tests 与 loader |
| renderer-neutral packet 与稳定资源驻留 | 已实现 | moon test moui_3d/render --target native |
| Native WGPU 深度测试 forward pass | 实验性/已编译 | renderer 测试与构建；真实像素证据待补 |
| WebGPU secondary canvas 深度测试 pass | 实验性/已编译 | wasm-gc renderer 测试与构建；浏览器像素证据待补 |
| macOS 3D child-surface plugin | 实验性/已编译 | moui_3d/backend/macos |
| Web 3D secondary-canvas plugin | 实验性/已编译 | moui_3d/backend/web |
| Physics neutral contracts | 实验性/仅契约 | moui_3d_physics tests |
| Rapier adapter | 已实现/实验性 | `Milky2018/moon_rapier@0.5.1`；native gravity、碰撞、变换与 ray-query 测试 |
| WebXR/OpenXR | 实验性/仅契约 | moui_3d_xr descriptor tests |

loader 现在会把 skin joints/inverse-bind、vertex joints/weights 与 morph delta
带入 CPU scene 和 packet；具体 GPU deformation 仍是实验性后续。punctual lights、
IBL、阴影、tone mapping 和 FXAA 也不在本 slice。Native WGPU 已在 session 内缓存 vertex buffer，并跳过
相同 payload 的重复上传；Native/Web host 已收到材质、纹理、sampler 的中立驻留
通知，但具体 image upload 与浏览器像素证据仍在 active 0.1.10 plan 中跟踪。

所有平台在 GPU host 不可用时返回 typed unavailable/failure，不宣称 CPU 3D
fallback。完成 macOS、Web、Windows、Linux 匹配设备上的非空颜色和深度遮挡
smoke 之前，产品 readiness 继续保持 ready=false。
