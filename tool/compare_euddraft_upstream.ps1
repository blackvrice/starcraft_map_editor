param(
    [Parameter(Mandatory = $true)][string]$EuddraftZip,
    [Parameter(Mandatory = $true)][string]$PythonZip,
    [Parameter(Mandatory = $true)][string]$EudplibWheel,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$destination = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $destination) { throw 'Choose a new output file.' }
$specs = @(
    @{id='euddraft'; path=$EuddraftZip; hash='87113da1cf8ad48c7ed81ee26a9db47ae236274d74e8f0f24addf0e2ab8280b3'; url='https://github.com/armoha/euddraft/releases/download/v0.10.2.5/euddraft0.10.2.5.zip'},
    @{id='python'; path=$PythonZip; hash='7d2650fd9d1b9d002d4a315d5f354247fd6a44f30517c7ef577b08f57a0fb6d9'; url='https://www.python.org/ftp/python/3.13.5/python-3.13.5-embed-amd64.zip'},
    @{id='eudplib'; path=$EudplibWheel; hash='9248b4ea16b3a61cc3a559e56e0be90422c1a77c5b14006c41353bf3d684a30e'; url='https://files.pythonhosted.org/packages/61/f4/77841511fd768bc715f1ee0e210535faa37f618f641acc6ed65d1239fc1c/eudplib-0.80.6-cp310-abi3-win_amd64.whl'}
)
function Get-StreamHash($stream) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}
$handles = @()
$archives = @()
try {
    # Validate every artifact on the same non-write-shared handle used to read it.
    foreach ($spec in $specs) {
        $handle = [IO.File]::Open((Resolve-Path -LiteralPath $spec.path).Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $handles += $handle
        if ((Get-StreamHash $handle) -ne $spec.hash) { throw "Archive SHA-256 differs: $($spec.id)" }
        $handle.Position = 0
        $archives += [IO.Compression.ZipArchive]::new($handle, [IO.Compression.ZipArchiveMode]::Read, $true)
    }
    $inventories = @()
    $artifacts = @()
    for ($i = 0; $i -lt $specs.Count; $i++) {
        $files = @()
        $notices = @()
        foreach ($entry in ($archives[$i].Entries | Sort-Object -Property FullName -CaseSensitive)) {
            $isBinary = $entry.FullName -match '\.(exe|dll|pyd)$'
            $isNotice = $entry.FullName -match '(?i)(?:^|/)(license|licence|copying)(?:[./]|$)'
            if (!$isBinary -and !$isNotice) { continue }
            if ($entry.Length -gt 33554432) { throw 'Entry exceeds 32 MiB.' }
            $stream = $entry.Open()
            try { $hash = Get-StreamHash $stream } finally { $stream.Dispose() }
            $record = [ordered]@{path=$entry.FullName; size=$entry.Length; sha256=$hash}
            if ($isBinary) { $files += $record }
            if ($isNotice) { $notices += $record }
        }
        $inventories += ,$files
        $artifacts += [ordered]@{id=$specs[$i].id; url=$specs[$i].url; sha256=$specs[$i].hash; bytes=$handles[$i].Length; notices=$notices}
    }
    $comparisons = @()
    for ($i = 1; $i -lt $specs.Count; $i++) {
        foreach ($file in $inventories[$i]) {
            $matches = @($inventories[0] | Where-Object { $_.sha256 -eq $file.sha256 -and $_.size -eq $file.size } | ForEach-Object { $_.path })
            $comparisons += [ordered]@{artifact=$specs[$i].id; path=$file.path; size=$file.size; sha256=$file.sha256; identicalBundlePaths=$matches}
        }
    }
    $report = [ordered]@{schemaVersion=1; executableRun=$false; redistributionReview='pending'; artifacts=$artifacts; comparisons=$comparisons}
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($report | ConvertTo-Json -Depth 8) + "`n")
    $output = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $output.Write($bytes, 0, $bytes.Length) } finally { $output.Dispose() }
    Write-Output 'Compared pinned archives without extraction or execution.'
} finally {
    foreach ($archive in $archives) { $archive.Dispose() }
    foreach ($handle in $handles) { $handle.Dispose() }
}
