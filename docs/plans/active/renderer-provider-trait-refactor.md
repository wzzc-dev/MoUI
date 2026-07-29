# Renderer Provider Trait Refactor — superseded

- **Status**: superseded on 2026-07-29
- **Successor**: Phase E of
  [`moui-architecture-convergence.md`](moui-architecture-convergence.md)

The former standalone plan described an intermediate renderer-provider
refactor. Its remaining work is now implemented and governed as Phase E of the
architecture-convergence plan: provider bindings are assembled by platform
composition roots, capability reports are supplied by registered provider IDs,
and the central registry selector is removed directly.

Do not revive this document as an implementation checklist. New renderer work
must follow the successor plan, the provider open-extension validator, and the
current `moui/render` contract tests.
