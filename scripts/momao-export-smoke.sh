#!/bin/sh
# MoMao 导出回归 smoke：最小项目 → emit_bundle → 工作区外独立构建（wasm-gc）。
#
# 目的：导出内核快照、Web 运行时闭包或 ABI 垫片发生漂移时，工作区内的
# moon test 发现不了「外部独立构建断裂」（内核互调泄漏到非内核文件、
# moon.mod 版本约束漂移等只在 workspace 外构建才报错）。本门让这类
# 漂移大声失败。
#
# 项目 JSON 按 docs/ir-schema.md 手写最小问候样例——schema 漂移时本门
# 同样大声失败，这是特性。
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d /tmp/momao-export-smoke.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/project.momao.json" <<'JSON'
{
  "format": "momao.project",
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
          { "t": "str", "v": "你好，MoMao！" } ] }
      ]
    }
  ]
}
JSON

cd "$REPO_ROOT"
moon run examples/momao/tools/emit_bundle --target native -- \
  "$TMP/project.momao.json" momao_hello_export "$TMP/bundle"

# 产物在 <target-dir>/<app-name>/ 子目录（app 名经模块名安全化，
# 下划线转连字符——用唯一子目录通配，不依赖命名细节）
BUNDLE_DIR=$(echo "$TMP"/bundle/*/ | head -1)
[ -f "$BUNDLE_DIR/moon.mod" ] || { echo "bundle layout unexpected"; exit 1; }
cd "$BUNDLE_DIR"
moon update
moon build --target wasm-gc
echo "momao export smoke: ok ($BUNDLE_DIR)"
