# MoUI local patch for mizchi/image

Vendored from mooncakes `mizchi/image@0.4.2` so MoUI can build against
MoonBit 0.10.4 before an upstream release.

## Patch

- Add `derive(Debug)` to public types used with `assert_eq` under the
  MoonBit 0.10.4 `assert_eq : [T : Eq + Debug]` requirement.
- Set `warnings = "-deprecated"` on the module/package so upstream test-only
  `try?` usage does not flood MoUI `moon check` output.

## Integration

`moon.work` lists `./third_party/mizchi_image`, which overrides the
registry package name `mizchi/image` for the workspace.

Remove this vendor once mooncakes ships a 0.10.4-compatible image release.
