#!/bin/sh
# MoUI Studio 导出回归 smoke：最小项目 → emit_bundle → 工作区外真编译
# （native 可执行 + wasm-gc 双端构建，native 产物真启动跑生成 handler）。
#
# 目的：导出内核快照、编译轨 codegen、Web 运行时闭包或 ABI 垫片发生漂移时，
# 工作区内的 moon test 发现不了「外部独立构建断裂」（内核互调泄漏到非内核
# 文件、moon.mod 版本约束漂移、生成源码与编译轨运行时签名不一致等只在
# workspace 外构建/运行时才报错）。本门让这类漂移大声失败。
#
# 项目 JSON 按 docs/ir-schema.md 手写最小问候样例——schema 漂移时本门
# 同样大声失败，这是特性。
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/studio-export-smoke.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/project.studio.json" <<'JSON'
{
  "format": "moui.studio.project",
  "version": 1,
  "window": { "title": "问候", "width": 640, "height": 480 },
  "controls": [
    { "id": 1, "kind": "button", "name": "按钮", "text": "点我",
      "x": 40, "y": 40, "width": 100, "height": 32, "items": [] },
    { "id": 2, "kind": "label", "name": "显示", "text": "",
      "x": 40, "y": 100, "width": 140, "height": 30, "items": [] }
  ],
  "variables": [],
  "handlers": [
    {
      "control": "按钮",
      "event": "on_click",
      "note": {
        "zh": "点击按钮后在标签上显示问候语",
        "en": "show a greeting on the label when clicked"
      },
      "body": [
        { "op": "call", "name": "set_text", "args": [
          { "t": "var", "v": "显示" },
          { "t": "str", "v": "你好，MoUI Studio！" } ] }
      ]
    }
  ]
}
JSON

cd "$REPO_ROOT"
moon run examples/moui_studio/tools/emit_bundle --target native -- \
  "$TMP/project.studio.json" studio_hello_export "$TMP/bundle"

# 产物在 <target-dir>/<app-name>/ 子目录（app 名经模块名安全化，
# 下划线转连字符——用唯一子目录通配，不依赖命名细节）
BUNDLE_DIR=$(echo "$TMP"/bundle/*/ | head -1)
[ -f "$BUNDLE_DIR/moon.mod" ] || { echo "bundle layout unexpected"; exit 1; }
cd "$BUNDLE_DIR"
moon update

# 1) wasm-gc：Web 入口 + 编译轨 app 包必须独立构建成功
moon build --target wasm-gc
WASM_ARTIFACT="_build/wasm-gc/debug/build/web_wasm/web_wasm.wasm"
[ -f "$WASM_ARTIFACT" ] || { echo "wasm-gc artifact missing: $WASM_ARTIFACT"; exit 1; }

# 2) native：handlers 生成源码必须真参与编译，且产物可启动执行
moon build ./native_smoke --target native
SMOKE_OUT=$(moon run ./native_smoke --target native)
case "$SMOKE_OUT" in
  *"studio native export smoke: ok handlers=1 ran=1 audit=1"*) ;;
  *) echo "native export smoke marker missing: $SMOKE_OUT"; exit 1 ;;
esac

echo "studio export smoke: ok native+wasm-gc ($BUNDLE_DIR)"
