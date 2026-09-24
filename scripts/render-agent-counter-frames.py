#!/usr/bin/env python3
"""
Visual artifact generator for the MoUI agent-controllable runtime.

Runs the agent_counter MCP server in a SINGLE process and records the
committed semantics before and after an agent activates the Increment button
through the standard MCP protocol:

  1. tools/call read_semantics               -> full snapshot (generation N)
  2. tools/call perform_action               -> activate the button the agent
                                                located by walking the emitted
                                                hierarchy (role + label)
  3. tools/call read_semantics since=N       -> delta with the changed node

The rasterized PNGs show the same text runs a window backend paints: view
labels are exactly what `DrawText` carries, so this is the visual record of a
genuine agent-driven model change. Physical screen capture (screencapture) is
blocked by macOS TCC screen-recording permission in automated environments;
this script renders the identical content the window would display.

The agent never sends coordinates or synthetic pointer events. It reads the
committed semantics tree, addresses a node inside it, and the runtime invokes
the button's own handler, which emits the same message a real click emits.

Output (pass --output-dir to relocate; the default matches the smoke/gates.json
agent.mcp-counter-protocol artifacts entries):
  artifacts/smoke/agent-mcp-counter-protocol/agent_counter_before.png
  artifacts/smoke/agent-mcp-counter-protocol/agent_counter_after.png

Requires: Pillow (python3 -m pip install Pillow).
"""
import json, subprocess, sys, os
from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = os.path.join(REPO_ROOT, "_build/native/debug/build/examples/agent_counter/main/main.exe")
W, H = 240, 260
DEFAULT_OUTPUT = os.path.join(REPO_ROOT, "artifacts", "smoke", "agent-mcp-counter-protocol")

BUILD = ["moon", "build", "examples/agent_counter/main", "--target", "native"]


def output_dir():
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "--output-dir":
        return args[1] if os.path.isabs(args[1]) else os.path.join(os.getcwd(), args[1])
    if args:
        sys.exit(f"usage: {sys.argv[0]} [--output-dir PATH]")
    return DEFAULT_OUTPUT


OUT_DIR = output_dir()
OUT_BEFORE = os.path.join(OUT_DIR, "agent_counter_before.png")
OUT_AFTER = os.path.join(OUT_DIR, "agent_counter_after.png")

if not os.path.exists(BIN):
    print(f"building {BIN}")
    subprocess.run(BUILD, cwd=REPO_ROOT, check=True)

def read(since=None):
    arguments = {} if since is None else {"since": since}
    return {"jsonrpc": "2.0", "id": "read", "method": "tools/call",
            "params": {"name": "read_semantics", "arguments": arguments}}

ACTIVATE = {"jsonrpc": "2.0", "id": "activate", "method": "tools/call",
            "params": {"name": "perform_action", "arguments": {
                "target": {"kind": "path",
                           "path": [{"role": "button", "label": "Increment"}]},
                "action": {"kind": "activate"},
                "precondition": {"kind": "latest"}}}}

# A single process keeps the committed state, so the generation learned from the
# first read is a valid cursor for the third one.
server = subprocess.Popen(
    [BIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1,
)


def fail(message):
    if server.stderr:
        server.stderr.close()
    server.kill()
    sys.exit(f"FAILED: {message}")


def call(request):
    server.stdin.write(json.dumps(request) + "\n")
    server.stdin.flush()
    line = server.stdout.readline()
    if not line:
        fail("server closed stdout before answering")
    try:
        response = json.loads(line)
    except Exception:
        fail(f"server did not answer with one JSON object: {line[:200]}")
    if "error" in response:
        fail(f"request {request.get('id')} returned a JSON-RPC error: {response['error']}")
    structured = response.get("result", {}).get("structuredContent", {})
    if structured.get("ok") is not True:
        fail(f"request {request.get('id')} failed: {structured.get('error')}")
    return structured["value"]


def texts_of(semantics):
    """The text runs a window backend would paint for this committed snapshot."""
    return [node["label"] for node in semantics.get("nodes", []) if node.get("label")]


before = call(read())
generation = before["generation"]
receipt = call(ACTIVATE)
if receipt.get("before") != generation:
    fail(f"action receipt before={receipt.get('before')} disagrees with read generation={generation}")

# The answer must be a delta, which is what proves the commit is incremental
# rather than a re-render of the same snapshot.
after = call(read(generation))
if after.get("kind") != "delta":
    fail(f"expected a delta for since={generation}, got {after.get('kind')}")
if after.get("from") != generation or after.get("to") != receipt.get("after"):
    fail(f"delta {after.get('from')}->{after.get('to')} disagrees with receipt {receipt}")

server.stdin.close()
server.wait(timeout=30)

# The delta carries only the changed node; merge it onto the snapshot so the
# "after" image shows the full frame the window would paint.
upserted = {node["node_id"]: node for node in after.get("upserted", [])}
after_nodes = [
    upserted.get(node["node_id"], node) for node in before.get("nodes", [])
]
texts_before = texts_of(before)
texts_after = [node["label"] for node in after_nodes if node.get("label")]

print("semantics BEFORE:", texts_before)
print(f"action receipt  : {receipt}")
print(f"delta           : {after.get('from')} -> {after.get('to')}")
print("semantics AFTER :", texts_after)


def render(texts, out_path, caption):
    img = Image.new("RGB", (W, H), (245, 245, 248))
    d = ImageDraw.Draw(img)
    try:
        font_title = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
        font_body = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    except Exception:
        font_title = ImageFont.load_default()
        font_body = font_title
    y = 16
    d.text((12, y), "Agent Counter", fill=(20, 20, 20), font=font_title)
    y += 32
    for t in texts:
        if t == "Agent Counter":
            continue
        d.text((12, y), t, fill=(20, 20, 20), font=font_body)
        y += 28
    d.text((12, H - 20), caption, fill=(120, 120, 120), font=ImageFont.load_default())
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path)
    print(f"wrote {out_path}")


render(texts_before, OUT_BEFORE, "before agent action")
render(texts_after, OUT_AFTER, "after agent action")

assert any("Count: 0" in t for t in texts_before), f"expected Count: 0 before, got {texts_before}"
assert any("Count: 1" in t for t in texts_after), f"expected Count: 1 after, got {texts_after}"
print("OK: agent action changed committed semantics Count: 0 -> Count: 1")
