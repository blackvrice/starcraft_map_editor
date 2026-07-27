# Self-authored euddraft smoke map

`eud-smoke-self-authored.scx` is a synthetic 32x32 MPQ map used only by the
opt-in official euddraft build smoke test. Every CHK byte is produced by
`tool/generate_eud_smoke_fixture.dart`; the archive is cloned from the
project-authored minimal MPQ fixture and contains no Blizzard or third-party
map assets.

The CHK includes the fixed-size sections that eudplib 0.80.6 reads or rewrites,
an ASCII title and description, a tile-one terrain grid, and empty unit and
trigger sections. It is a compiler integration input, not a gameplay fixture.

## Regeneration

Build the Windows helper, choose a new scratch output, and run:

```powershell
$helper = Resolve-Path `
  "build/windows/x64/map_archive_helper/Debug/map_archive_helper.exe"
$scratch = Join-Path $env:TEMP `
  ("starcraft-map-editor-eud-smoke-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $scratch | Out-Null
$generated = Join-Path $scratch "eud-smoke-self-authored.scx"

dart run tool/generate_eud_smoke_fixture.dart `
  --helper $helper `
  --output $generated

Get-FileHash $generated -Algorithm SHA256
```

The generator refuses to overwrite its output. Compare the generated map and
hash with the repository fixture before replacing it, then update
`manifest.json` only for an intentional byte change.

## License

The fixture, generator, epScript source, and all generated payload bytes are
distributed under the repository's MIT license.
