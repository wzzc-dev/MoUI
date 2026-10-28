# MoUI Text Providers

Platform text providers for `wzzc-dev/moui` renderers: `coretext` (macOS/iOS),
`directwrite` (Windows), `fontconfig` (Linux), `cosmic_text` (portable fallback),
and the shared `text_protocol` seam. Each provider implements the renderer-neutral
model in `wzzc-dev/moui/render/native_text`, so any `moui_*_renderer` module can
inject one as its `NativeTextEngine` without depending on another renderer.
