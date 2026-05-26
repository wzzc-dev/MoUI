# Views API Guide

MoUI application code should prefer the `views` package for ordinary UI. `core`
remains the lower-level runtime, layout, paint, rich text, and testing surface.

## Local DSL Imports

In application and example UI packages, import only the `views` functions the
package uses:

```moonbit
using @views { column, text, surface, scroll_view }
```

MoonBit packages share top-level identifiers across files, so multi-file
packages should keep these imports in one small package-level DSL file instead
of repeating the same `using` block in every file.

Then call those functions without the `@views.` prefix:

```moonbit
surface(
  column([...], align=@views.CrossAlign::Start),
  variant=@views.SurfaceVariant::Raised,
  theme~,
)
```

Keep enum and type names qualified by default:

```moonbit
align=@views.CrossAlign::Start
variant=@views.ButtonVariant::Primary
variant=@views.SurfaceVariant::Raised
```

This keeps the DSL compact while making `Start`, `Raised`, and similar variant
names unambiguous in larger files.

## Boundary

Use `views` for ordinary app authoring: controls, layout, surfaces, scrolling,
and simple composition.

Use `core` directly for runtime setup, state and binding types, custom
paint/layout, rich text models, geometry calculations, and test assertions.

Advanced helpers such as custom layout and navigation destination construction
may stay qualified as `@views.*` when that makes the call site clearer.
