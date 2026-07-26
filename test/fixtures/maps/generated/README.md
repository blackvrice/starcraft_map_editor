# Generated map fixtures

`minimal-self-authored.scx` is a synthetic MPQ archive created entirely from
project-authored bytes. It is not copied from StarCraft, Blizzard, or a
third-party map and contains no game assets.

The fixture contains:

- `staredit\scenario.chk`, matching
  `test/fixtures/chk/metadata.chk.hex`;
- `staredit\units.dat`, containing the four test bytes `01 02 03 04`;
- the StormLib-generated `(listfile)`.

It exists to exercise the real bundled archive helper, `ProcessMapArchiveGateway`,
and Save As round-tripping against a stable repository input. It is a minimal
archive integration fixture, not a playable StarCraft map.

## Regeneration

Build the Windows debug app, then run the native test fixture builder:

```powershell
$fixtureBuilder = Resolve-Path `
  "build/windows/x64/map_archive_helper/Debug/map_archive_helper_native_test.exe"
$scratch = Join-Path $env:TEMP `
  ("starcraft-map-editor-fixture-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$generatedFixture = Join-Path $scratch "minimal-self-authored.scx"

& $fixtureBuilder `
  --create-fixture `
  $generatedFixture `
  (Join-Path $scratch "scenario.chk")

Get-FileHash $generatedFixture -Algorithm SHA256
```

The builder deliberately refuses to overwrite an existing output. Compare the
generated file and hash first, then replace the repository fixture only after
review. Update `manifest.json` only if the reviewed archive bytes changed
intentionally. The fixture's CHK bytes are defined by `ScenarioBytes` in
`native/map_archive_helper/test/archive_extractor_test.cpp` and must remain
identical to `test/fixtures/chk/metadata.chk.hex`.

## License

The fixture and its project-authored payloads are distributed under the
repository's MIT license. StormLib is used only to construct the MPQ container;
its pinned revision and MIT license are documented in the native helper.
