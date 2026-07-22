# Showcase

<div align="center">
  <img src="../../resource/screenshots/showcase.png" width="600px" alt="Showcase screenshot"/>
</div>

Showcase is MoUI's unified learning app with **one product shell** and four
isolated feature packages:

| Package | Role |
|---|---|
| `app/` | Single chrome: workspace switcher, catalog sidebar/list, route history |
| `app/components/` | `@views` demos (body only when hosted) |
| `app/patterns/` | Counter/Todo/forms/data/navigation/workflow patterns |
| `app/platform/` | Host recipes, canvas, **Mobile Service Probe** |
| `app/diagnostics/` | Runtime/renderer labs only (may import core/runtime/render) |

## Shell (Story / classic Showcase)

Single app chrome, **left category rail + right detail** (same idea as
gpui-component `crates/story` and the historical Showcase sidebar):

| Category | Content |
|---|---|
| Start | Welcome pages |
| Controls / Feedback / Display / Layout | Component demos |
| Patterns | Counter, Todo, forms, workflows… |
| Platform | Host services, canvas, mobile probe |
| Runtime | Diagnostics / renderer labs only |

- **Desktop:** title bar + search · left grouped stories · detail body  
- **Mobile:** searchable story list ↔ detail (“All stories”)  
- Defaults: desktop `components/welcome`, mobile `platform/mobile-service-probe`  
- Routes stay `components|patterns|platform|diagnostics/<id>` for package isolation  

Feature packages only export catalog rows + `view_body` (no second sidebar).

## Entrypoints

- Skia mainline: `macos_skia`, `linux_skia`, `windows_skia`
- Diagnostic: `*_wgpu`, `*_sun`
- Web: `web_wasm`
- Mobile: `android_window_hosted`, `ios_window_hosted`, `harmonyos_window_hosted`

Identity: `dev.wzzc.moui.showcase` / MoUI Showcase.

## Run

```sh
moon run examples/showcase/macos_skia --target native
moon build examples/showcase/web_wasm --target wasm-gc
moui build android showcase --mobile-config "$PWD/examples/showcase/moui.mobile.json"
```
