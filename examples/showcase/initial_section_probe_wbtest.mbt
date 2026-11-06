///|
test "initial section code 2 lands on the accessibility probe route" {
  let runtime = runtime(
    host_summary=@host.HostCapabilitySummary::unavailable(),
    initial_section_code=2,
  )
  let snapshot = match runtime.read_semantics() {
    Ok(Full(snapshot)) => snapshot
    _ => fail("expected full semantics snapshot")
  }
  let seen : Array[String] = []
  for node in snapshot.nodes() {
    match node.semantic_id {
      Some(id) => seen.push(id.value())
      None => ()
    }
  }
  inspect(seen.contains("a11y.button"), content="true")
  inspect(seen.contains("a11y.slider"), content="true")
}
