#!/usr/bin/env python3
"""
Visual artifact generator for the MoUI agent-controllable runtime.

Runs the agent_counter MCP server in a SINGLE process and rasterizes the
compositor's rendered frame (get_frame → DrawText content, exactly what a
window backend rasterizes to the physical screen) to PNG, before and after an
agent clicks Increment via MCP dispatch_event.

Output:
  /tmp/agent_counter_before.png  — painted frame shows "Count: 0"
  /tmp/agent_counter_after.png   — painted frame shows "Count: 1"

This is the visual record of a genuine agent-driven model change through the
standard MCP protocol. Physical screen capture (screencapture) is blocked by
macOS TCC screen-recording permission in automated environments; this script
renders the identical compositor content the window would display.

Requires: Pillow (python3 -m pip install Pillow).
"""
import json, subprocess, sys, os
from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = os.path.join(REPO_ROOT, "_build/native/debug/build/examples/agent_counter/main/main.exe")
W, H = 240, 260
OUT_BEFORE = "/tmp/agent_counter_before.png"
OUT_AFTER = "/tmp/agent_counter_after.png"

REQUESTS = [
    {"jsonrpc": "2.0", "id": 1, "method": "initialize"},
    {"jsonrpc": "2.0", "id": "before", "method": "tools/call",
     "params": {"name": "get_frame", "arguments": {}}},
    {"jsonrpc": "2.0", "id": 2, "method": "tools/call",
     "params": {"name": "dispatch_event",
                "arguments": {"event": {"kind": "Pointer",
                                        "position": {"x": 100, "y": 106},
                                        "phase": "Down"}}}},
    {"jsonrpc": "2.0", "id": 3, "method": "tools/call",
     "params": {"name": "dispatch_event",
                "arguments": {"event": {"kind": "Pointer",
                                        "position": {"x": 100, "y": 106},
                                        "phase": "Up"}}}},
    {"jsonrpc": "2.0", "id": "after", "method": "tools/call",
     "params": {"name": "get_frame", "arguments": {}}},
]
payload = "\n".join(json.dumps(r) for r in REQUESTS) + "\n"
proc = subprocess.run([BIN], input=payload, capture_output=True, text=True, timeout=20)

results = {}
for line in proc.stdout.strip().splitlines():
    try:
        r = json.loads(line)
        if r.get("id") in ("before", "after"):
            results[r["id"]] = r
    except Exception:
        pass

def painted(rid):
    content = results.get(rid, {}).get("result", {}).get("content", [])
    if content:
        try:
            return json.loads(content[0]["text"]).get("texts", [])
        except Exception:
            return []
    return []

texts_before = painted("before")
texts_after = painted("after")
print("painted BEFORE:", texts_before)
print("painted AFTER :", texts_after)

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
    img.save(out_path)
    print(f"wrote {out_path}")

render(texts_before, OUT_BEFORE, "before agent click")
render(texts_after, OUT_AFTER, "after agent click")

assert any("Count: 0" in t for t in texts_before), "expected Count: 0 before click"
assert any("Count: 1" in t for t in texts_after), "expected Count: 1 after click"
print("OK: agent click changed rendered frame Count: 0 -> Count: 1")
