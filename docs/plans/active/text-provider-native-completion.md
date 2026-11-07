# Plan: Native text provider completion (DirectWrite / fontconfig)

- **Status**: active
- **Goal**: Finish the two scaffolded native text providers so Windows and
  Linux stop leaning on the Cosmic fallback for shaping/measurement, and
  record the matching-host Windows IME evidence the platform declaration
  still lacks.
- **Environment prerequisite**: a Windows host with Visual Studio C++ build
  tools + vcpkg (`zlib:x64-windows`) for DirectWrite builds and IME evidence
  collection, and an Ubuntu 24.04+ Wayland host for fontconfig/HarfBuzz
  validation. Neither is available in a headless agent session; the slices
  below are ordered so pure-MoonBit preparation lands first.

## Starting point (verified 2026-11-07)

- `moui_text_providers/directwrite` is a scaffold: the binding surface exists
  (`docs/text-system.md` "DirectWrite remains a scaffold... until the real
  DirectWrite engine") and no measurement routes through it.
- `moui_text_providers/fontconfig` has a narrow native color-emoji path;
  broader shaping, measurement, and non-emoji raster still fall back to
  Cosmic until the full fontconfig/HarfBuzz path is implemented.
- `TextLayoutInput.direction` exists (RTL step 1, 2026-11-07) and the
  fallback provider mirrors carets for it — the native providers are the
  natural first consumers once they shape for real.

## Slices

1. **DirectWrite measure path**: font enumeration via `IDWriteFontCollection`,
   glyph advances/cluster mapping via `IDWriteTextAnalyzer` for
   `measure_text`, behind the existing `native_text` protocol seam. L1 unit
   tests compare advances against the Cosmic fallback within tolerance on a
   fixture matrix (Latin, CJK, emoji, RTL run).
2. **DirectWrite IME request plumbing**: wire `Ime` request surface through
   the Windows backend the way macOS routes `NSTextInputClient`
   (`appkit-setMarkedText` / `appkit-insertText` markers).
3. **fontconfig/HarfBuzz measure path**: `FcFontMatch` + `hb_shape` for
   measurement and caret clusters, replacing the Cosmic fallback for
   non-emoji runs; keep the emoji fallback.
4. **Windows matching-host evidence**: run the Showcase native entrypoint
   with `MOUI_WINDOWS_NATIVE_IME_EVIDENCE=1` on a real Windows host; fold
   candidate-anchor / surrounding-text / composition / commit-delete /
   cursor observations with `record-native-ime-evidence.mjs`, then promote
   the Windows platform entry per `docs/platform-readiness-declaration.md`.

## Acceptance

- [ ] `moui_text_providers/directwrite` shapes the fixture matrix without
      the Cosmic fallback; L1 tolerance tests green on Windows.
- [ ] `moui_text_providers/fontconfig` shapes non-emoji runs through
      HarfBuzz; `docs/text-system.md` drops the Cosmic-fallback caveat.
- [ ] Windows native IME evidence recorded with matching-host provenance and
      the Windows platform entry promoted.
- [ ] Both providers consume `TextLayoutInput.direction` (RTL step 3
      crossover — coordinate with `rtl-step3-native-base-direction.md`).

## Validation

```sh
moon test moui_text_providers --target native
sh scripts/check.sh --profile platform
scripts/record-native-ime-evidence.mjs --platform windows ...
```
