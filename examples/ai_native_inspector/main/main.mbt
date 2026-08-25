///|
/// Headless MCP entrypoint for local QA and CI. It serves the same semantic,
/// policy, trace and replay surface as the windowed reference application.
async fn main {
  let runtime = @app.runtime()
  let host = @app.agent_host(runtime)
  while @stdio.stdin.read_until("\n") is Some(line) {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    let parsed = @json.parse(trimmed) catch {
      _ => {
        @stdio.stdout.write(
          (@mcp.rpc_error_no_id(-32700, "Parse error") : Json).stringify() +
          "\n",
        )
        continue
      }
    }
    let response = @app.route_agent(host, parsed)
    @stdio.stdout.write((response : Json).stringify() + "\n")
  }
}
