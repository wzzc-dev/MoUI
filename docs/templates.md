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
          @host.HostServiceResponse::SystemTheme(@moui.ColorScheme::Light)
        _ => @host.HostServiceResponse::Unavailable(request.unavailable_message())
      }
    },
  )
}
```

Checklist:

- Add shared request and response types in `backend` first.
- Keep unavailable services capability-gated.
- Add host and backend tests for success and unavailable paths.

## Third-Party Control Template

Use a package-local `ViewNode` implementation and expose one constructor from
`moui/views` only when the control is intended for ordinary app code. Register
the control in `checks/component-quality.json` with one of `stable`, `preview`,
or `experimental` levels and point `evidence` at focused tests and guidance.
Keep app state and domain behavior in the consumer app package; the control
should emit typed messages and remain renderer-neutral.

## Host-Service Extension Template

Add a neutral request/response DTO to `moui/backend`, route it through the
`PlatformChannel` extension point, and add a typed facade under `moui/services`.
Concrete OS behavior belongs in the platform backend. The default must return
`ServiceError::unavailable` until a matching-host implementation and evidence
exist. Add success, cancellation, and unavailable tests before changing a
platform capability summary.

## Renderer Capability Template

Checklist:

- Add the neutral draw command or update the existing one.
- Add feature status to the concrete provider's capability closure so the
  composition-root report can aggregate it by provider ID.
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

- Keep the root `README.md` as the short entrypoint and canonical source.
- Put setup and command loops in `docs/development.md`.
- Put platform caveats in `docs/platform-notes-<platform>.md` (e.g., `platform-notes-linux.md`).
  Cross-platform host contracts go in `docs/platform-notes.md`.
- Put text architecture in `docs/text-system.md`.
- Put Markdown Editor behavior in `docs/markdown-editor.md`.
- Put validation policy in `docs/testing.md`.
- Check `AGENTS.md` and `skills/` when guidance could become stale.
