# CHK test fixtures

These fixtures are hand-authored hexadecimal byte streams so their provenance
and exact contents remain reviewable in Git.

- `minimal.chk.hex`: `VER ` and `DIM ` sections.
- `duplicate_unknown.chk.hex`: duplicate `TEST` sections around an unknown,
  empty `UNKN` section.
- `truncated_header.chk.hex`: a section header shorter than eight bytes.
- `out_of_bounds.chk.hex`: a payload length that exceeds the remaining input.

Tests decode whitespace-separated byte pairs. Lines may include comments after
`#`.
