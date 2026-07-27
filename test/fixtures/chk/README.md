# CHK test fixtures

These fixtures are hand-authored hexadecimal byte streams so their provenance
and exact contents remain reviewable in Git.

- `minimal.chk.hex`: `VER ` and `DIM ` sections.
- `duplicate_unknown.chk.hex`: duplicate `TEST` sections around an unknown,
  empty `UNKN` section.
- `metadata.chk.hex`: valid `TYPE`, `VER `, `IVER`, `ERA `, and `DIM ` views.
- `terrain.chk.hex`: a 3x2 `MTXM` grid with reviewable little-endian raw tile
  values.
- `invalid_metadata_sizes.chk.hex`: typed sections with invalid fixed sizes
  around a valid section.
- `strings.chk.hex`: `SPRP` references and a legacy table with a shared offset
  and unreferenced tail bytes.
- `strings_extended.chk.hex`: `SPRP` references and an extended table that
  contains UTF-8 and control bytes.
- `invalid_strings.chk.hex`: truncated headers/offsets and invalid string
  boundaries.
- `truncated_header.chk.hex`: a section header shorter than eight bytes.
- `out_of_bounds.chk.hex`: a payload length that exceeds the remaining input.

Tests decode whitespace-separated byte pairs. Lines may include comments after
`#`.
