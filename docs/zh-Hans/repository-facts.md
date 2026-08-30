<!-- 由 tools/moui/generate_repo_docs 生成；请勿编辑。 -->

# 仓库事实

此文件由仓库 manifest 和 validator report 生成。

## 工作区成员

| 成员 |
|---|
| ./moui |
| ./moui_skia_renderer |
| ./moui_web_renderer |
| ./moui_wgpu_renderer |
| ./moui_sun_renderer |
| ./moui_tests |
| ./moui_richtext |
| ./moui_webview |
| ./moui_devtools |
| ./moui_agent |
| ./moui_agent_mcp |
| ./examples/agent_counter |
| ./tools |
| ./moui_cli |
| ./moui_skia |
| ./moui_theme |
| ./moui_sun |
| ./examples/counter |
| ./examples/multi_window |
| ./examples/harmonyos_demo |
| ./examples/button_freeze_probe |
| ./examples/showcase |
| ./examples/design_systems |
| ./examples/markdown_editor |
| ./examples/pdf_workbench |
| ./examples/settings |
| ./examples/data_table |
| ./examples/file_importer |
| ./examples/command_palette |
| ./examples/mo_desktop |
| ./examples/mo_workbench |
| ./examples/code_editor |
| ./examples/webview_demo |
| ./benchmarks/app_cached_layer |
| ./benchmarks/full_cycle |
| ./website |

## API Surface

| 包 | Interface 行数 | Public | pub(all) |
|---|---:|---:|---:|
| 根 facade（应用循环语法糖）(moui/pkg.generated.mbti) | 29 | 7 | 0 |
| geometry 语法糖 (moui/geometry/pkg.generated.mbti) | 33 | 9 | 0 |
| graphics 语法糖 (moui/graphics/pkg.generated.mbti) | 47 | 16 | 0 |
| animation 语法糖 (moui/animation/pkg.generated.mbti) | 21 | 3 | 0 |
| text 语法糖 (moui/text/pkg.generated.mbti) | 27 | 6 | 0 |
| state 语法糖 (moui/state/pkg.generated.mbti) | 35 | 10 | 0 |
| runtime facade (moui/runtime/pkg.generated.mbti) | 420 | 281 | 9 |
| core (moui/core/pkg.generated.mbti) | 1830 | 505 | 139 |
| views facade (moui/views/pkg.generated.mbti) | 1213 | 548 | 19 |
| host contract (moui/backend/pkg.generated.mbti) | 1226 | 481 | 73 |
| renderer facade (moui/render/pkg.generated.mbti) | 550 | 148 | 37 |
| skia renderer (moui_skia_renderer/pkg.generated.mbti) | 161 | 93 | 3 |
| sun renderer (moui_sun_renderer/pkg.generated.mbti) | 230 | 138 | 1 |
| webgpu adapter (moui_web_renderer/pkg.generated.mbti) | 143 | 60 | 2 |
| native wgpu renderer (moui_wgpu_renderer/pkg.generated.mbti) | 136 | 65 | 2 |
| native text protocol (moui_wgpu_renderer/text_protocol/pkg.generated.mbti) | 58 | 23 | 0 |

## 工作区示例

| 示例 | 路径 | 是否精选 |
|---|---|---|
| Agent Counter | examples/agent_counter | no |
| Counter | examples/counter | no |
| Multi Window | examples/multi_window | no |
| HarmonyOS Demo | examples/harmonyos_demo | no |
| Button Freeze Probe | examples/button_freeze_probe | no |
| Showcase | examples/showcase | yes |
| Design Systems | examples/design_systems | no |
| Markdown Editor | examples/markdown_editor | yes |
| PDF Workbench | examples/pdf_workbench | no |
| Settings | examples/settings | no |
| Data Table | examples/data_table | no |
| File Importer | examples/file_importer | no |
| Command Palette | examples/command_palette | no |
| Mo Desktop | examples/mo_desktop | yes |
| Mo Workbench | examples/mo_workbench | yes |
| Code Editor | examples/code_editor | no |
| WebView Demo | examples/webview_demo | no |

## 平台状态

| 平台 | 构建/源码 | Renderer L2 | Runtime L3 | Shell | API/ABI | 部署下限 | 工具链下限 | 声明 presenter | 实际 presenter |
|---|---|---|---|---|---|---|---|---|---|
| android | passed | partial | partial | managed-kotlin | 1/1 | Android 23 | AGP 9.2.1 / Kotlin 2.2.10 / Gradle 9.6.1 / JVM 17 / compile SDK 36 / target SDK 35 / NDK 28.2 / CMake 3.22.1 | vulkan-direct | unverified |
| harmonyos | passed | partial | partial | managed-arkts-xcomponent | 1/1 | HarmonyOS API 20 | HarmonyOS SDK API 21 / target API 21 / model 6.0.1 | egl-direct | unverified |
| ios | passed | partial | partial | managed-swiftui | 1/1 | iOS 15.0 | Xcode 15.4 / Swift 5 | metal-direct | unverified |
| linux | passed | passed | passed | native-wayland | 0/0 | Wayland compositor | Clang/GCC with Wayland and Vulkan | vulkan-wayland-direct | vulkan-wayland-direct |
| macos | passed | passed | passed | native-window | 0/0 | current supported macOS runner | Apple Clang with Metal | metal-direct | metal-direct |
| web | passed | passed | passed | browser | 0/0 | WebAssembly GC browser | MoonBit wasm-gc | browser-webgpu | browser-webgpu |
| windows | passed | passed | passed | native-window | 0/0 | Windows 10 | MSVC 2022 | d3d12-direct | d3d12-direct |

## 文档目录

已发布文档：45。

| 分组 | 文档数 |
|---|---:|
| 入门 (get-started) | 5 |
| 指南 (guides) | 9 |
| 示例 (examples) | 4 |
| 平台 (platforms) | 13 |
| 架构与 API (architecture-api) | 5 |
| 贡献 (contributing) | 5 |
| 状态与路线图 (status-roadmap) | 4 |
