param(
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$expectedHash = '87113da1cf8ad48c7ed81ee26a9db47ae236274d74e8f0f24addf0e2ab8280b3'
$sourceUrl = 'https://github.com/armoha/euddraft/releases/download/v0.10.2.5/euddraft0.10.2.5.zip'
$archivePath = (Resolve-Path -LiteralPath $ZipPath).Path
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Archive SHA-256 differs from the pinned official release. No output written.'
}
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $outputPath) { throw 'Choose a new output directory.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-EntryHash($entry) {
    $stream = $entry.Open()
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose(); $stream.Dispose() }
}
function Read-EntryText($entry) {
    if ($entry.Length -gt 1048576) { throw 'Metadata text exceeds 1 MiB.' }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
$zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $files = [ordered]@{}
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $entries = @($zip.Entries | Sort-Object -Property FullName -CaseSensitive)
    if ($entries.Count -gt 4096) { throw 'Too many entries.' }
    $total = [long]0
    foreach ($entry in $entries) {
        if ($entry.FullName.EndsWith('/')) { throw 'Unexpected directory entry in pinned archive.' }
        if (!$names.Add($entry.FullName)) { throw 'Duplicate Windows path.' }
        foreach ($part in $entry.FullName.Split('/')) {
            if ($part -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]*$' -or $part.EndsWith('.') -or $part -match '^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)') { throw 'Unsafe archive path.' }
        }
        $total += $entry.Length
        if ($entry.Length -gt 2147483648 -or $total -gt 4294967296) { throw 'Archive size limit exceeded.' }
        $files[$entry.FullName] = [ordered]@{size=$entry.Length; sha256=(Get-EntryHash $entry)}
    }
    if ((Read-EntryText $zip.GetEntry('VERSION')).Trim() -ne '0.10.2.5') { throw 'Unexpected VERSION.' }
    $components = @()
    $notices = @()
    foreach ($entry in $entries) {
        if ($entry.FullName -match '(?i)(license|licence|copying)') {
            $notices += [ordered]@{path=$entry.FullName; size=$entry.Length; sha256=$files[$entry.FullName].sha256}
        }
    }
    $library = $zip.GetEntry('lib/library.zip')
    if ($library.Length -gt 33554432) { throw 'Nested library exceeds 32 MiB.' }
    $memory = [IO.MemoryStream]::new()
    $stream = $library.Open()
    try { $stream.CopyTo($memory) } finally { $stream.Dispose() }
    $memory.Position = 0
    $inner = [IO.Compression.ZipArchive]::new($memory, [IO.Compression.ZipArchiveMode]::Read)
    try {
        foreach ($entry in ($inner.Entries | Sort-Object -Property FullName -CaseSensitive)) {
            if ($entry.FullName -match '\.dist-info/METADATA$') {
                $metadata = Read-EntryText $entry
                $headers = ($metadata -split '\r?\n\r?\n', 2)[0] -split '\r?\n'
                $fields = [ordered]@{metadataPath=('lib/library.zip!/' + $entry.FullName)}
                foreach ($name in @('Name','Version','License','License-Expression')) {
                    $line = @($headers | Where-Object { $_.StartsWith($name + ': ') })
                    if ($line.Count -gt 0) { $fields[$name] = $line[0].Substring($name.Length + 2) }
                }
                $components += $fields
            }
            if ($entry.FullName -match '(?i)(?:^|/)(license|licence|copying)(?:[./]|$)') {
                if ($entry.Length -gt 1048576) { throw 'Notice exceeds 1 MiB.' }
                $notices += [ordered]@{path=('lib/library.zip!/' + $entry.FullName); size=$entry.Length; sha256=(Get-EntryHash $entry)}
            }
        }
        $innerCount = $inner.Entries.Count
    } finally { $inner.Dispose(); $memory.Dispose() }
    $manifest = [ordered]@{format='starcraft-map-editor-eud-tool'; schemaVersion=1; version='0.10.2.5'; artifactSha256=$expectedHash; sourceUrl=$sourceUrl; files=$files}
    $audit = [ordered]@{artifactSha256=$expectedHash; archiveBytes=(Get-Item -LiteralPath $archivePath).Length; fileCount=$files.Count; unpackedBytes=$total; innerLibraryEntries=$innerCount; components=$components; notices=$notices; redistributionReview='pending'; executableRun=$false}
    New-Item -ItemType Directory -Path $outputPath | Out-Null
    [IO.File]::WriteAllText((Join-Path $outputPath 'euddraft-0.10.2.5.manifest.json'), ($manifest | ConvertTo-Json -Depth 8) + "`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $outputPath 'euddraft-0.10.2.5.audit.json'), ($audit | ConvertTo-Json -Depth 8) + "`n", [Text.UTF8Encoding]::new($false))
    Write-Output "Verified archive: $($files.Count) files, $total unpacked bytes. Audit only; no package code executed."
} finally { $zip.Dispose() }
