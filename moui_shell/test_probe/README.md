# MoUI Shell Test Probe

This is a repository-only managed-shell plugin fixture. It is not part of any
production canonical shell and is installed only by shell shell CI configs.

The PlatformView fixture records create, resize, rectangular clip, event, and
dispose observations. The Host Channel fixture supports `success`, `error`,
`cancel`, `exactly-once`, and `late-after-dispose` operations. A `snapshot`
request returns the fixture counters for matching-device smoke assertions.
Every accepted counter transition also emits one normalized
`moui-shell test-probe snapshot=<json>` line with the same 12 counter names on
Android, iOS, and HarmonyOS. The runtime recorder marks an observation `yes`
only when its counter is greater than zero; plugin staging and API availability
are not runtime evidence.

The plugin does not fabricate PlatformView or Host Channel traffic. An app
fixture must publish placements and channel requests before those observations
can pass. GPU recovery and stress remain separate matching-device observations,
so a run without those producers is intentionally `partial` even when the
managed shell builds and the service smoke completes.

The service probe is disabled unless the shell exposes the unified launch
option `moui.shell.testProbe` as true. Matching-host recorders map it from an
Android Intent string extra with the same name, the iOS process environment
variable `MOUI_EMBEDDING_TEST_PROBE`, or a HarmonyOS Ability Want string parameter
with the same unified name. Once enabled, the plugin waits for exact semantics
labels before driving accessibility, IME, copy, clipboard seed, paste, and cut
through a dispatcher bound to the current runtime session.

The manifest id uses `dev.wzzc.moui.shell.test-probe`; the `moui.*` namespace
remains reserved for framework-owned runtime protocols.
