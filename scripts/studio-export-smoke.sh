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

# 2) native GUI 应用：必须真的构建出一个窗口二进制
#
# 这是「编译出来的东西能不能当应用跑」的唯一硬证据。旧 bundle 只有
# native_smoke（无头探针，打印标记就退出），用户运行后看不到任何界面——
# 本步失败即代表那个缺陷复发。
moon build ./native_app --target native
GUI_ARTIFACT="_build/native/debug/build/native_app/native_app.exe"
[ -f "$GUI_ARTIFACT" ] || { echo "native GUI artifact missing: $GUI_ARTIFACT"; exit 1; }
# GUI 组合根必须链进真实窗口后端与渲染器（不能退化成无头）
if ! strings "$GUI_ARTIFACT" | grep -q "Skia"; then
  echo "native GUI artifact does not look like a Skia-linked app"; exit 1
fi

# 3) 布局门槛：导出应用在**自己的窗口尺寸**下不得有任何内容被裁
#
# 这是「运行的产物窗口显示不全」那个缺陷的唯一硬证据。旧 runner 把整棵树
# 塞进写死 960×600 的卡片，而窗口只有 640×480——内容包围盒 1090×634，
# 右溢出 450pt、下溢出 154pt。这里在真实运行时的绘制命令上量包围盒：
# 任何一条文本/矩形越出视口即失败。
moon build ./native_smoke --target native
mkdir -p layout_probe
cat > layout_probe/main.mbt <<'PROBE'
///|
/// 布局门槛探针：在任何一条绘制命令越出视口时报错退出。
fn main {
  let sizes : Array[(Double, Double)] = [
    (640.0, 480.0), (800.0, 600.0), (1280.0, 800.0), (480.0, 360.0),
  ]
  let mut failures = 0
  for size in sizes {
    let (w, h) = size
    let runtime = @runtime.new_program_with_dimensions(
      program=@app.program(),
      width=w,
      height=h,
    )
    let clipped : Array[String] = []
    for command in runtime.draw_commands() {
      let rect = match command {
        DrawText(run) => Some(run.frame)
        FillRect(r, _) => Some(r)
        FillRoundedRect(rr, _) => Some(rr.rect)
        FillRoundedRectBrush(rr, _) => Some(rr.rect)
        StrokeRect(r, _, _) => Some(r)
        StrokeRoundedRect(rr, _, _) => Some(rr.rect)
        StrokeRoundedRectBrush(rr, _, _) => Some(rr.rect)
        _ => None
      }
      match rect {
        Some(r) =>
          if r.origin.x + r.size.width > w + 0.5 ||
            r.origin.y + r.size.height > h + 0.5 {
            match command {
              DrawText(run) => clipped.push(run.text)
              _ => clipped.push("<rect>")
            }
          }
        None => ()
      }
    }
    if clipped.length() > 0 {
      failures = failures + 1
      println("viewport \{w}x\{h}: \{clipped.length()} item(s) outside the window")
      for item in clipped {
        println("    clipped: \{item}")
      }
    }
  }
  if failures > 0 {
    println("studio export layout: FAILED (\{failures} viewport(s) clip)")
    @sys.exit(1)
  }
  println("studio export layout: ok (no clipping at any probed viewport)")
}
PROBE
cat > layout_probe/moon.pkg <<PROBE_PKG
import {
  "wzzc-dev/moui/runtime",
  "studio-hello-export/app" @app,
  "moonbitlang/x/sys",
}

supported_targets = "native"

pkgtype(kind: "executable")

options(
  targets: { },
)
PROBE_PKG
LAYOUT_OUT=$(moon run ./layout_probe --target native)
case "$LAYOUT_OUT" in
  *"studio export layout: ok"*) ;;
  *) echo "layout gate failed: $LAYOUT_OUT"; exit 1 ;;
esac

# 4) native 无头自检：生成源码必须真参与编译，且产物可启动执行
SMOKE_OUT=$(moon run ./native_smoke --target native)
case "$SMOKE_OUT" in
  *"studio native export smoke: ok handlers=1 ran=1 audit=1"*) ;;
  *) echo "native export smoke marker missing: $SMOKE_OUT"; exit 1 ;;
esac

echo "studio export smoke: ok native-gui+layout+native-smoke+wasm-gc ($BUNDLE_DIR)"
