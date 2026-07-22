# HarmonyOS 支持

HarmonyOS 使用 **window-hosted** 移动端路径，目前状态为 `runtime_partial`。
`wzzc-dev/window/harmonyos` 拥有 Stage Ability、XComponent Surface、生命周期与
输入队列；`moui/backend/harmonyos` 将回调适配到 MoUI runtime session。

## 入口

| 部件 | 位置 |
|---|---|
| App 逻辑 | `examples/<app>/app` |
| 移动端元数据 | `examples/<app>/moui.mobile.json` |
| MoonBit 入口 | `examples/<app>/harmonyos_window_hosted` |
| HarmonyOS host 模板 | `wzzc-dev/window/harmonyos/template` |
| MoUI adapter | `moui/backend/harmonyos/window_hosted.mbt` |

XComponent 回调是 Surface、pointer、resize 与 detach 的唯一来源。hosted event loop
将它们转发给 `HarmonyOsWindowHostedApp`；不要注入第二条 Surface 或输入路径。

## 工具链

- `HARMONYOS_SDK_HOME` 指向 DevEco/OpenHarmony SDK
- compatible API 20、target API 21、model `6.0.1`
- SDK/toolchain 中可用 `hvigorw` 与 `ohpm`

构建前运行 `moui doctor --platform harmonyos`。

## 构建与运行

```sh
moon check examples/harmonyos_demo/harmonyos_window_hosted --target native
moui build harmonyos harmonyos_demo \
  --mobile-config "$PWD/examples/harmonyos_demo/moui.mobile.json"
moui run harmonyos harmonyos_demo \
  --mobile-config "$PWD/examples/harmonyos_demo/moui.mobile.json"
```

`--prepare-only` 在执行 hvigor 前停止。`--fallback-skia` 只提供打包诊断覆盖，
不能提升 runtime readiness。

## 验证与证据

```sh
sh scripts/window-hosted-hostsim-smoke.sh
moon test moui/backend/harmonyos --target native
```

设备或 HVD 结论需要首帧、输入、Surface detach/recreate、IME、剪贴板、无障碍和
异步图片观察。签名设备证据到位前，`checks/platforms/harmonyos.json` 不得高于
`partial`。

## 状态

源码路径与 host-sim 已可用，实际呈现和完整 service 证据仍待补齐。边界见
`docs/platform-readiness-declaration.md` 与 `docs/window-hosted-moui.md`。
