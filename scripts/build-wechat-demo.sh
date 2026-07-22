#!/usr/bin/env bash
# Build the WeChat Mini Program demo app.
# Compiles MoonBit to wasm-gc and stages the Mini Program project structure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP="${1:-counter}"
BUILD_DIR="${PROJECT_ROOT}/_build/wechat/${APP}"
TEMPLATE_DIR="${PROJECT_ROOT}/window/wechat/template"
WASM_SRC="${PROJECT_ROOT}/_build/wasm/debug/build/examples/${APP}/wechat_canvas/wechat_canvas.wasm"

echo "=== Building WeChat Mini Program Demo: ${APP} ==="

# Step 1: Compile MoonBit to wasm
echo "[1/4] Compiling MoonBit to wasm..."
moon build "examples/${APP}/wechat_canvas" --target wasm

# Step 2: Prepare output directory
echo "[2/4] Preparing output directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/moui"
mkdir -p "${BUILD_DIR}/pages/index"
mkdir -p "${BUILD_DIR}/utils"

# Step 3: Copy template files
echo "[3/4] Copying template files..."
cp "${TEMPLATE_DIR}/app.js" "${BUILD_DIR}/"
cp "${TEMPLATE_DIR}/app.json" "${BUILD_DIR}/"
cp "${TEMPLATE_DIR}/app.wxss" "${BUILD_DIR}/"
cp "${TEMPLATE_DIR}/project.config.json" "${BUILD_DIR}/"
cp "${TEMPLATE_DIR}/sitemap.json" "${BUILD_DIR}/"
cp "${TEMPLATE_DIR}/pages/index/index.js" "${BUILD_DIR}/pages/index/"
cp "${TEMPLATE_DIR}/pages/index/index.json" "${BUILD_DIR}/pages/index/"
cp "${TEMPLATE_DIR}/pages/index/index.wxml" "${BUILD_DIR}/pages/index/"
cp "${TEMPLATE_DIR}/pages/index/index.wxss" "${BUILD_DIR}/pages/index/"
cp "${TEMPLATE_DIR}/utils/moui-runtime.js" "${BUILD_DIR}/utils/"

# Step 4: Lower non-MVP wasm features and copy output
echo "[4/4] Lowering non-MVP wasm features for WXWebAssembly..."
WASM_OPT="$(which wasm-opt 2>/dev/null || echo /opt/homebrew/opt/binaryen/bin/wasm-opt)"
"${WASM_OPT}" \
  --enable-bulk-memory --enable-multivalue --enable-nontrapping-float-to-int \
  --no-validation \
  --llvm-memory-copy-fill-lowering \
  --llvm-nontrapping-fptoint-lowering \
  "${WASM_SRC}" -o "${BUILD_DIR}/moui/moui.wasm"

echo ""
echo "=== Build complete! ==="
echo "Output: ${BUILD_DIR}"
echo "Wasm size: $(du -h "${BUILD_DIR}/moui/moui.wasm" | cut -f1)"
echo ""
echo "Next steps:"
echo "  1. Open WeChat Developer Tools"
echo "  2. Import project from: ${BUILD_DIR}"
echo "  3. Enable Skyline rendering engine in project settings"
echo "  4. Click Preview or Compile"