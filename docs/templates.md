# Package And Plugin Templates

Use these templates when adding packages, platform service bridges, renderer
capabilities, or Showcase coverage. Keep each new slice independently testable.
For end-user app skeletons, use [App templates](app-templates.md); this file is
for repository maintenance patterns.

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
- Update `docs/text-system.md` too when the renderer capability is text-related.

## Showcase Entry Template

Checklist:

- Category and searchable label.
- Preview view spec.
- Constructor/API note.
- Semantics note.
- Test coverage note.
- Renderer/platform note when relevant.

## Documentation And Guidance Template

Checklist:

- Keep the root `README.md` as the short entrypoint; its source is
  `moui/README.mbt.md`.
- Put setup and command loops in `docs/development.md`.
- Put platform caveats in `docs/platform-notes.md`.
- Put text architecture in `docs/text-system.md`.
- Put Markdown Editor behavior in `docs/markdown-editor.md`.
- Put validation policy in `docs/testing.md`.
- Check `AGENTS.md` and `skills/` when guidance could become stale.
