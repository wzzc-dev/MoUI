# MoUI Skia Prebuild: Windows Link-Flag Paths

2026-11-19:

- Moon tokenizes `cc-link-flags` (the `link.native` string in `moon.pkg`) with
  shell-style escaping. A Windows path emitted with backslashes
  (`D:\a\MoUI\MoUI\.skia-cache\...`) reaches `link.exe` as `D:aMoUIMoUI...`
  and fails `LNK1181: cannot open input file`.
- Rule: any filesystem path that enters `MOUI_SKIA_CC_LINK_FLAGS` (or any
  `link_configs` string) must use forward slashes. `moui_skia/build.mbtx`
  normalizes `@env.current_dir()` on Windows plus every stub/Skia path it
  picks from the environment or the provider lock (`link_safe_path` /
  `host_path`), so a `D:/a/MoUI/...` root keeps working.
- `@env.current_dir()` is the usual culprit: it returns the native Windows
  separator, and `path_join` only appends `/` after whatever prefix it gets.
- Verify with the Windows CI job step that builds `examples/showcase/windows_skia`
  (`MOUI_SKIA_STUB_MODE=auto` local-compile fallback included). A `moon check`
  on macOS/Linux cannot catch this class of bug because the prebuild output is
  only tokenized on the Windows link line.
- Docs: `docs/platform-notes-windows.md` "Link Flags" states the forward-slash
  rule; plan `governance-ci-docs-and-p5-layering` records the CI run.
