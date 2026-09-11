# MoUI Brand Assets

The MoUI identity combines a moon crescent with a small application window. The
moon connects the framework to MoonBit; the window makes the UI category clear
at a glance. Both the logo and mascot use the same rounded geometry and four
flat colors so they remain legible in product UI, documentation, and community
artwork.

## Assets

| File | Use |
|---|---|
| `moui-mark.svg` / `.png` | App icon, avatar, favicon, and square placements |
| `moui-logo.svg` / `.png` | Primary horizontal lockup |
| `moui-logo-reversed.svg` / `.png` | Horizontal lockup for dark backgrounds |
| `moonbud-mascot.svg` / `.png` | Onboarding, empty states, release notes, events |
| `moonbud-mascot-100.svg` / `.png` | Fixed 100 px Moonbud for README headers, avatars, and small UI slots |
| `moui-brand-board.svg` / `.png` | Design overview and presentation preview |

The SVG files are the editable sources. PNG files are generated previews and
should not replace the SVGs in scalable contexts.

The 100 px Moonbud reuses the `0 0 720 720` viewBox from `moonbud-mascot.svg`,
so it stays on the shared coordinate grid and only declares `width="100"
height="100"` as its default display size. Regenerate the preview with:

```sh
rsvg-convert -w 100 -h 100 -a -o moonbud-mascot-100.png moonbud-mascot-100.svg
```

## Palette

| Token | Hex | Role |
|---|---|---|
| Orbit Ink | `#101820` | Primary dark, outline, typography |
| Moon Mint | `#70E0BC` | Primary brand color |
| Signal Amber | `#F3B64C` | Warm highlight and notification accent |
| Action Coral | `#F06C5B` | Human detail and action accent |
| Moon White | `#F7F8F3` | Light surface and reversed foreground |

## Usage

- Keep clear space around the mark equal to one quarter of its width.
- Use the square mark at 24 px or larger. Use the horizontal logo at 120 px or
  larger.
- Keep the supplied colors and proportions intact. Do not rotate, stretch,
  outline, or place the mark over visually noisy artwork.
- On light backgrounds, use the supplied logo. On dark backgrounds, use the
  mark as supplied and set the wordmark to Moon White when creating a reversed
  lockup.
- Moonbud is a supporting character, not a replacement for the primary mark.
  Crop it only when the face and crescent silhouette remain recognizable.

## Mascot

The mascot is named **Moonbud**. It is the MoUI mark brought to life: the body
uses the same crescent silhouette and the face is the same window panel. One
small leaf and two feet are enough to make it friendly while keeping the shape
legible at small sizes and consistent with the primary identity.
