# Embedding API v1

托管 Android、iOS 和 HarmonyOS shell 使用同一个进程生命周期 C 函数表，该表声明在 `moui_shell/include/moui_embedding_api_v1.h`。平台代码必须调用一次 `moui_embedding_get_api_v1()`，用 `moui_embedding_api_v1_is_compatible()` 验证结果，并且只通过该表分派。MoonBit 对象和字符串绝不跨越 shell 边界。

## 协商与所有权

- `abi_version` 必须为 `1`。
- `struct_size` 必须至少为 `MOUI_EMBEDDING_API_V1_REQUIRED_SIZE`。
- 每个必需 capability 和 function pointer 都必须存在。scroll capability 和 pointer 必须同时存在或同时缺席。
- 输入文本和 byte views 只在一次调用期间借用，并使用显式长度。
- 返回的 UTF-8 buffers 包含显式长度和 release callback。shell 会用原始 context、data 和 length 精确调用一次该 callback。

adapter 拥有所有 MoonBit conversion references，并且每个都只释放一次。Shell 代码不得调用 `moonbit_incref`、`moonbit_decref`，也不得依赖 MoonBit 字符串表示。

`moui_shell/embedding` 拥有进程内 callback state、native adapter 使用的每个
`moui_embedding_*` MoonBit 实现，以及其 `moon.pkg` 中 canonical
`link.native.exports` declaration。当前 MoonBit native dependency package 不会把这些
declaration 提升到最终 executable 的 C symbol table。因此每个移动端 executable 根包
必须在自身 `moon.pkg` 中镜像 canonical 列表，并定义相同的 `embedding_exports.mbt`；
其中每个函数只能调用同名 `@shell_embedding` 函数。这只是 linker reachability shim，
并不转移 ABI ownership：app 根包不得在这里新增 callback state、转换、分支、adapter
构造或 runtime behavior。

## 生命周期

`initialize` 是进程级且幂等的。surface epoch 从 `attach_surface` 开始，到 `detach_surface` 结束。Detach 会释放 presenter、image coordinator、pending host requests 和 epoch generation，但保留 `AppRuntime`。之后的 attach 会在同一 app state 上创建新的 generation。

`destroy_application` 是终止操作，并且只执行一次它的 MoonBit destroy hook。之后每个 session call 都返回
`MOUI_EMBEDDING_API_ERROR_APPLICATION_DESTROYED_V1`。Embedding API v1 支持一个 application scene；canonical shell 必须拒绝第二个并发 scene。

## Host Wire v1

`take_host_update_envelope_json` 返回一个 UTF-8 envelope：

```json
{
  "schemaVersion": 1,
  "sessionGeneration": 42,
  "updates": []
}
```

shell 必须在每个异步 request 和带 revision 的 PlatformView snapshot 中保留 `sessionGeneration`。通用控件响应使用 `dispatch_host_response_envelope`。

PlatformView event 形状如下：

```json
{
  "schemaVersion": 1,
  "sessionGeneration": 42,
  "response": {
    "kind": "platform-view",
    "revision": 7,
    "viewKind": "camera.preview",
    "id": "preview",
    "event": {
      "name": "ready",
      "value": "yes",
      "detail": "",
      "flag": true
    }
  }
}
```

当 PlatformView event 的 generation、snapshot revision、kind 或 id 已过期时，runtime 会拒绝它。

plugin PlatformChannel completion 形状如下：

```json
{
  "schemaVersion": 1,
  "sessionGeneration": 42,
  "response": {
    "kind": "platform-channel",
    "requestId": 19,
    "status": "ok",
    "payload": "{\"started\":true}"
  }
}
```

`status` 为 `ok`、`error` 或 `unavailable`。async queue 会为一个 pending request 接受一次 completion，并拒绝 duplicate、cancelled、unknown 或 late responses。

Clipboard image data 仍是固定 C buffer，而不是 JSON。因此 `complete_clipboard` 函数在 request id 之前接收 `session_generation`；来自已 detach epoch 的 completion 会先被拒绝，不能匹配到新的 request。

所有 runner 都使用 v1 table、update envelope 和 generation-aware clipboard completion。Embedding table 是唯一支持的 shell ABI；不再支持 app-specific legacy exports。
