#!/bin/sh
# S5/S7/H4/H5 终端真机冒烟:在真 PTY 会话里驱动 examples 的 terminal 入口,
# 逐项验收焦点流转、列表选择、树折叠、瞬时按键、鼠标、resize 重排与主题接线。
#
# 为什么要脚本门而不是普通 moon test:被测对象是「终端上最终出现的那一屏」,
# 断言靠回放 ANSI 字节流反解栅格,所以必须先有 native 可执行文件,再把它们的
# 绝对路径交给测试。没设置对应的 MOUI_TUI_*_BIN 时用例整体跳过 —— 普通
# `moon test` 不该依赖构建产物存在,但那条跳过在这里就是假绿,所以这里
# 显式 build + 校验产物,并拒绝在没有终端类型的环境下跑。
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_ROOT"

LAYERS_BIN="$REPO_ROOT/_build/native/debug/build/examples/tui_layers/terminal/terminal.exe"
COUNTER_BIN="$REPO_ROOT/_build/native/debug/build/examples/counter/terminal/terminal.exe"
LOG_DIR="$REPO_ROOT/artifacts/smoke/tui-pty-smoke"

moon build examples/tui_layers/terminal --target native
moon build examples/counter/terminal --target native
# 八项合一 demo 是双栏交互、即时按键、only-visible 与主题接线这些门的载体。
# 少了这个产物,对应用例会因为环境变量没设而整体跳过 —— 跳过在这里等于
# 假绿,所以要停。
if [ ! -f "$LAYERS_BIN" ]; then
  echo "TUI PTY smoke: built executable missing: $LAYERS_BIN" >&2
  exit 1
fi
# 标签行=命中行那条不变量只能在 counter 上测:双栏 demo 的标签都住在条目内部,
# 行号偏移被子节点定位吃掉。少了这个产物,那条用例会静默跳过。
if [ ! -f "$COUNTER_BIN" ]; then
  echo "TUI PTY smoke: built executable missing: $COUNTER_BIN" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

# 被测程序按 TERM 选 SGR 扩展;反解器只认 xterm 族转义,别继承一个陌生的值。
TERM=xterm-256color
export TERM
MOUI_TUI_LAYERS_BIN="$LAYERS_BIN"
export MOUI_TUI_LAYERS_BIN
MOUI_TUI_COUNTER_BIN="$COUNTER_BIN"
export MOUI_TUI_COUNTER_BIN
# 只在断言失败时落盘:最后一次失败会话的原始字节流,用来复盘反解器看到的 screen。
MOUI_TUI_SMOKE_LOG="$LOG_DIR/raw-stream.log"
export MOUI_TUI_SMOKE_LOG

moon test moui_tests/tui_pty_smoke --target native

echo "MoUI TUI PTY smoke passed. Failure stream (if any): $MOUI_TUI_SMOKE_LOG"
