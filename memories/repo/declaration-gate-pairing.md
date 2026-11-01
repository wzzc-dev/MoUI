# Declaration coverage gate pairing (P17)

- **Plan**: `docs/plans/done/hot-path-invalidation-boilerplate-convergence.md`
  (H1), ADR 0034.

## Standing facts

- `tools/moui/validate_viewnode_declaration_coverage` pairs `ViewNode`
  structs with their `declaration()` impls **per package**, not per file.
  It previously paired per file, so generated implementations
  (`declarations.generated.mbt`) in a different file from the struct
  escaped the gate entirely (scanned=0) while the validator stayed green.
- The pairing semantics must be proven with an end-to-end drill, not by
  reading the validator: delete one field from
  `checks/viewnode-declarations.json`, regenerate, and the gate must trip
  (`[P17] Button.variant`). A green validator with scanned=0 is a hole,
  not coverage.
- Generated declaration files are listed in
  `checks/source-file-policy.json` under `generated`; the drift gate is
  `scripts/generate-view-declarations.mjs --check` in the pr profile.
  Adding a control means adding a manifest entry and regenerating —
  see `docs/view-catalog.md` "Authoring new controls".
