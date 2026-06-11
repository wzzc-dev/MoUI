# MoUI MoonBit Tools

This module contains MoonBit implementations for repository maintenance tools
that used to live as inline Python, shell, or PowerShell script bodies.

Keep the split aligned with future repository boundaries:

- `tools/` owns shared helpers that can be copied or extracted when MoUI and
  `moui_skia` are split into separate repositories.
- `tools/moui/` is reserved for MoUI framework-specific tools.
- `tools/moui_skia/` owns `moui_skia` binding-specific tools.

Existing `scripts/` and `moui_skia/scripts/` entrypoints should remain as thin
compatibility wrappers when CI, documentation, or users call those paths.
