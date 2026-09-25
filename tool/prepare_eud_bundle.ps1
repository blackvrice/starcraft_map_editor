param(
    [string]$ArchivePath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [switch]$WriteInventory
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$expectedHash = '87113da1cf8ad48c7ed81ee26a9db47ae236274d74e8f0f24addf0e2ab8280b3'
$sourceUrl = 'https://github.com/armoha/euddraft/releases/download/v0.10.2.5/euddraft0.10.2.5.zip'
$output = [IO.Path]::GetFullPath($OutputDirectory)
$inventoryFile = Join-Path $PSScriptRoot 'eud_bundle/manifest.json'
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Hash-File([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Inventory([string]$directory) {
    $files = [ordered]@{}
    foreach ($file in (Get-ChildItem -LiteralPath $directory -Recurse -Force | Sort-Object FullName)) {
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Bundle links are forbidden.' }
        if ($file.PSIsContainer) { continue }
        $relative = $file.FullName.Substring($directory.Length + 1).Replace('\', '/')
        $files[$relative] = [ordered]@{ size = $file.Length; sha256 = (Hash-File $file.FullName) }
    }
    return $files
}
function Verify([string]$directory) {
    $expected = Get-Content -LiteralPath $inventoryFile -Raw | ConvertFrom-Json
    $actual = Inventory $directory
    if ($actual.Count -ne @($expected.files.PSObject.Properties).Count) { throw 'Bundle file count mismatch. Recreate the build bundle in a new directory.' }
    foreach ($entry in $expected.files.PSObject.Properties) {
        $value = $actual[$entry.Name]
        if ($null -eq $value -or $value.size -ne $entry.Value.size -or $value.sha256 -ne $entry.Value.sha256) {
            throw "Bundle integrity mismatch: $($entry.Name). Recreate the build bundle in a new directory."
        }
    }
}
if (Test-Path -LiteralPath $output) {
    if ($WriteInventory) { throw 'Inventory creation requires a new output directory.' }
    Verify $output
    Write-Output "Verified managed EUD bundle: $output"
    exit 0
}
if (-not $ArchivePath) {
    $cache = Join-Path $repo 'build/eud-downloads'
    New-Item -ItemType Directory -Force -Path $cache | Out-Null
    $ArchivePath = Join-Path $cache 'euddraft0.10.2.5.zip'
    if (-not (Test-Path -LiteralPath $ArchivePath)) {
        Invoke-WebRequest -Uri $sourceUrl -OutFile $ArchivePath -UseBasicParsing
    }
}
$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
if ((Hash-File $archive) -ne $expectedHash) { throw 'Official archive SHA-256 mismatch. No bundle written.' }
# The pinned archive is still extracted through a path traversal check.
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    New-Item -ItemType Directory -Path $output | Out-Null
    foreach ($entry in $zip.Entries) {
        if (-not $entry.Name) { continue }
        $target = [IO.Path]::GetFullPath((Join-Path $output $entry.FullName))
        if (-not $target.StartsWith($output + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe archive path.' }
        New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
    }
} finally { $zip.Dispose() }
$library = Join-Path $output 'lib/library.zip'
$temporaryLibrary = Join-Path $output 'lib/library.managed.zip'
$inputZip = [IO.Compression.ZipFile]::OpenRead($library)
$outputZip = [IO.Compression.ZipFile]::Open($temporaryLibrary, [IO.Compression.ZipArchiveMode]::Create)
try {
    $updaters = @($inputZip.Entries | Where-Object { $_.FullName -eq 'autoupdate.pyc' })
    if ($updaters.Count -ne 1) { throw 'Expected exactly one upstream updater module.' }
    foreach ($entry in $inputZip.Entries) {
        if ($entry.FullName -eq 'autoupdate.pyc') { continue }
        $copy = $outputZip.CreateEntry($entry.FullName, [IO.Compression.CompressionLevel]::NoCompression)
        $copy.LastWriteTime = [DateTimeOffset]::new(2025, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        $src = $entry.Open(); $dst = $copy.Open()
        try { $src.CopyTo($dst) } finally { $src.Dispose(); $dst.Dispose() }
    }
    $copy = $outputZip.CreateEntry('autoupdate.py', [IO.Compression.CompressionLevel]::NoCompression)
    $copy.LastWriteTime = [DateTimeOffset]::new(2025, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
    $dst = $copy.Open()
    try {
        $source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'eud_bundle/autoupdate.py')).Replace("`r`n", "`n")
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($source)
        $dst.Write($bytes, 0, $bytes.Length)
    } finally { $dst.Dispose() }
} finally { $inputZip.Dispose(); $outputZip.Dispose() }
# Replace only the newly created bundle's exact library file; no recursive deletion.
[IO.File]::Delete($library)
[IO.File]::Move($temporaryLibrary, $library)
$notice = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'eud_bundle/BUNDLE-NOTICE.txt')).Replace("`r`n", "`n")
[IO.File]::WriteAllText((Join-Path $output 'BUNDLE-NOTICE.txt'), $notice, [Text.UTF8Encoding]::new($false))
$noticesOutput = Join-Path $output 'editor-licenses'
New-Item -ItemType Directory -Path $noticesOutput | Out-Null
foreach ($file in (Get-ChildItem (Join-Path $PSScriptRoot 'eud_bundle/licenses') -File)) {
    $text = [IO.File]::ReadAllText($file.FullName).Replace("`r`n", "`n")
    [IO.File]::WriteAllText((Join-Path $noticesOutput $file.Name), $text, [Text.UTF8Encoding]::new($false))
}
if ($WriteInventory) {
    $manifest = [ordered]@{ format = 'starcraft-map-editor-eud-tool'; schemaVersion = 1; version = '0.10.2.5'; artifactSha256 = $expectedHash; sourceUrl = $sourceUrl; files = (Inventory $output) }
    $json = ($manifest | ConvertTo-Json -Depth 8).Replace("`r`n", "`n") + "`n"
    [IO.File]::WriteAllText($inventoryFile, $json, [Text.UTF8Encoding]::new($false))
    $dart = "// Generated by tool/prepare_eud_bundle.ps1 -WriteInventory. Review before commit.`nconst bundledEudManifestJson = r'''`n" + $json + "''';`n"
    [IO.File]::WriteAllText((Join-Path $repo 'lib/infrastructure/compiler/bundled_eud_manifest.dart'), $dart, [Text.UTF8Encoding]::new($false))
}
Verify $output
Write-Output "Prepared managed EUD bundle: $output"
