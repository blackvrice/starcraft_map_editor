# Windows-only resource inspection. Never execute or import package binaries.
param(
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
if (!$IsWindows) { throw 'Windows PowerShell 7 is required.' }
$expectedHash = '87113da1cf8ad48c7ed81ee26a9db47ae236274d74e8f0f24addf0e2ab8280b3'
$destination = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $destination) { throw 'Choose a new output file.' }
# Keep the same handle open without write sharing from hashing through inspection.
$archive = [IO.File]::Open((Resolve-Path -LiteralPath $ZipPath).Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$zip = $null
try {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { $actualHash = [Convert]::ToHexString($algorithm.ComputeHash($archive)).ToLowerInvariant() }
    finally { $algorithm.Dispose() }
    if ($actualHash -ne $expectedHash) { throw 'Archive SHA-256 differs from the pinned official release.' }
    $archive.Position = 0
    $zip = [IO.Compression.ZipArchive]::new($archive, [IO.Compression.ZipArchiveMode]::Read, $true)
    $binaries = @()
    foreach ($entry in ($zip.Entries | Sort-Object -Property FullName -CaseSensitive)) {
        if ($entry.FullName -notmatch '\.(exe|dll|pyd)$') { continue }
        if ($entry.Length -gt 33554432) { throw 'Binary exceeds 32 MiB.' }
        # Use an OS-created flat temporary file, never a path taken from the ZIP.
        $temporary = [IO.Path]::GetTempFileName()
        try {
            $inputStream = $entry.Open()
            try {
                $outputStream = [IO.File]::Open($temporary, [IO.FileMode]::Truncate, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
            } finally { $inputStream.Dispose() }
            $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($temporary)
            $fields = [ordered]@{path=$entry.FullName; size=$entry.Length; sha256=(Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()}
            # Fixed numeric versions avoid localized resource text and local file paths.
            $hasVersion = ![string]::IsNullOrEmpty($version.FileVersion)
            $fields['versionResource'] = $hasVersion
            $fields['fileVersion'] = if ($hasVersion) { "$($version.FileMajorPart).$($version.FileMinorPart).$($version.FileBuildPart).$($version.FilePrivatePart)" } else { $null }
            $fields['productVersion'] = if ($hasVersion) { "$($version.ProductMajorPart).$($version.ProductMinorPart).$($version.ProductBuildPart).$($version.ProductPrivatePart)" } else { $null }
            $binaries += $fields
        } finally {
            # Delete only the single file created by GetTempFileName; never recurse.
            [IO.File]::Delete($temporary)
        }
    }
    $report = [ordered]@{artifactSha256=$expectedHash; method='Windows FileVersionInfo fixed version resources'; executableRun=$false; provenanceVerified=$false; binaries=$binaries}
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($report | ConvertTo-Json -Depth 6) + "`n")
    $output = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $output.Write($bytes, 0, $bytes.Length) } finally { $output.Dispose() }
    Write-Output "Inspected $($binaries.Count) binaries without execution. Resource versions are not proof of provenance."
} finally {
    if ($null -ne $zip) { $zip.Dispose() }
    $archive.Dispose()
}
