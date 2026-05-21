# Package And Plugin Templates

Use these templates when adding packages, platform service bridges, renderer
capabilities, or Showcase coverage. Keep each new slice independently testable.

## Package Template

```text
<package>/
  moon.pkg
  <feature>.mbt
  <feature>_test.mbt
  pkg.generated.mbti
```

Checklist:

- Keep imports in `moon.pkg`.
- Keep public APIs small and intentional.
- Preserve `///|` delimiters.
- Add package-local tests before wider examples.
- Run `moon info` after public API changes.

## Host Service Template

```moonbit
pub fn platform_service_bridge() -> @host.HostServiceBridge {
  @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(system_theme=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::QuerySystemTheme =>
          @host.HostServiceResponse::SystemTheme(@core.ColorScheme::Light)
        _ => @host.HostServiceResponse::Unavailable(request.unavailable_message())
      }
    },
  )
}
```

Checklist:

- Add shared request and response types in `backend/host` first.
- Keep unavailable services capability-gated.
- Add host and backend tests for success and unavailable paths.

## Renderer Capability Template

Checklist:

- Add the neutral draw command or update the existing one.
- Add feature status in `renderer_feature_capability_report`.
- Add fallback planner coverage for skipped advanced commands.
- Update native/Web adapter tests.
- Update `docs/renderer-capability-report.md`.

## Showcase Entry Template

Checklist:

- Category and searchable label.
- Preview view spec.
- Constructor/API note.
- Semantics note.
- Test coverage note.
- Renderer/platform note when relevant.
