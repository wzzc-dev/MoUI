# RFC 0001: Root Facade `run_app`

Status: Accepted

The root `wzzc-dev/moui` facade re-exports `run_app` as the application
composition entry. It may depend on `moui/runtime`, `moui/render`, and the
neutral `moui/backend/host` contract, but it must not depend on any platform
backend package. Applications
assemble a renderer and a platform backend in their executable composition
root through the `AppBuilder` chain.

The structural gate is `scripts/validate-root-facade-deps.mjs`, which walks the
`moui` package dependency closure and rejects platform `moui/backend/**`
imports (the neutral `moui/backend/host` contract is explicitly allowed).
