# Phase 2 plan — compile once, validate many (compact)

Decisions (locked): keep one-shot `Validate` as a thin wrapper (Ada
compatibility norm); index buckets mirror the spec's target taxonomy;
`sh:detail` included via child indices into the append-only table.

1. `Eval`: `Compiled_Shapes` = table + three `(shape_idx, target_pos)`
   pointer arrays (class / subjects-of / objects-of; `targetNode` needs
   no scan, implicit-class fallback unchanged). `Compile` builds them in
   one dedup pass, fail-closed. `Validate (Compiled, …)` runs one data
   pass per distinct class/predicate; old `Validate (Shape_Table, …)`
   compiles inline per call (cold path).
2. `Violation`: `Detail_Count` + 4 child result-indices (`0` = none).
   On `sh:node` failure with emit on: re-run inner with `Emit=True`,
   emit parent, link first 4 children. Boolean contexts keep
   `Emit=False`. Parent-dedup-hit skips linking.
3. Correctness: indexed-vs-wrapper differential must agree exactly on
   all 86 corpus cases, plus a `sh:node` detail assertion case.
4. Bench: corpus-aggregate nodes/sec, README number (informational).
5. Docs: SPEC rows, DESIGN rationale, ROADMAP, CHANGELOG. Gate: build +
   two-phase proof + 86/86 (line numbers derived, not pinned).
