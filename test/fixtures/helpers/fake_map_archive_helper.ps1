$ErrorActionPreference = 'Stop'

$requestText = [Console]::In.ReadLine()
$request = $requestText | ConvertFrom-Json
$mode = [IO.Path]::GetFileNameWithoutExtension([string]$request.sourcePath)

$baseResponse = [ordered]@{
    protocolVersion = 1
    requestId = [string]$request.requestId
    operation = [string]$request.operation
    helperVersion = '0.3.0'
    stormLibRevision = 'c91595a1a1b7b515567bd62a60af066914a29a6a'
}

if ($mode -eq 'hang') {
    Start-Sleep -Seconds 30
}

if ($mode -eq 'malformed') {
    [Console]::Out.WriteLine('not-json')
    exit 0
}

if ($mode -eq 'error') {
    $baseResponse.status = 'error'
    $baseResponse.error = [ordered]@{
        code = 'ARCHIVE_SCENARIO_NOT_FOUND'
        message = 'The archive does not contain a readable scenario.chk entry.'
        stage = 'extract'
        nativeError = 2
    }
    [Console]::Out.WriteLine(($baseResponse | ConvertTo-Json -Compress -Depth 5))
    [Console]::Error.WriteLine('ARCHIVE_SCENARIO_NOT_FOUND')
    exit 3
}

if ($mode -eq 'large-stderr') {
    [Console]::Error.Write(('x' * 100000))
}

if ([string]$request.operation -eq 'replaceScenario') {
    [IO.File]::Copy(
        [string]$request.sourcePath,
        [string]$request.archiveOutputPath,
        $false
    )
    $baseResponse.status = 'success'
    $archiveSize = (Get-Item -LiteralPath ([string]$request.archiveOutputPath)).Length
    $scenarioSize = (Get-Item -LiteralPath ([string]$request.scenarioInputPath)).Length
    if ($mode -eq 'write-size-mismatch') {
        $archiveSize++
    }
    $baseResponse.output = [ordered]@{
        archiveSizeBytes = $archiveSize
        scenarioSizeBytes = $scenarioSize
    }
    [Console]::Out.WriteLine(($baseResponse | ConvertTo-Json -Compress -Depth 5))
    exit 0
}

[byte[]]$scenarioBytes = 86, 69, 82, 32, 2, 0, 0, 0, 59, 0
[IO.File]::WriteAllBytes(
    [string]$request.scenarioOutputPath,
    $scenarioBytes
)

$baseResponse.status = 'success'
$entries = @(
    [ordered]@{
        path = 'staredit\scenario.chk'
        uncompressedSizeBytes = $scenarioBytes.Length
        compressedSizeBytes = $scenarioBytes.Length
        flags = [uint32]2147484160
        locale = 0
        nameIsSynthetic = $false
    },
    [ordered]@{
        path = '(listfile)'
        uncompressedSizeBytes = 24
        compressedSizeBytes = 20
        flags = [uint32]2147484160
        locale = 0
        nameIsSynthetic = $false
    }
)
$formatVersion = 1
$totalEntryCount = 2
$listingComplete = $true
$listingNativeError = $null

if ($mode -eq 'listing-warning') {
    $entries[1].path = 'File00000001.xxx'
    $entries[1].nameIsSynthetic = $true
    $totalEntryCount = 3
    $listingComplete = $false
    $listingNativeError = 299
}

if ($mode -eq 'format-warning') {
    $formatVersion = 2
}

if ($mode -eq 'encrypted') {
    $entries[0].flags = [uint32]2147549696
}

if ($mode -eq 'duplicate-path') {
    $entries += [ordered]@{
        path = '(LISTFILE)'
        uncompressedSizeBytes = 24
        compressedSizeBytes = 20
        flags = [uint32]2147484160
        locale = 0
        nameIsSynthetic = $false
    }
    $totalEntryCount = 3
}

if ($mode -eq 'invalid-listing') {
    $totalEntryCount = 3
}

$baseResponse.archive = [ordered]@{
    sizeBytes = 128
    formatVersion = $formatVersion
    totalEntryCount = $totalEntryCount
    listingComplete = $listingComplete
    listingNativeError = $listingNativeError
    entries = $entries
}
$baseResponse.scenario = [ordered]@{
    archivePath = 'staredit\scenario.chk'
    uncompressedSizeBytes = $scenarioBytes.Length
    compressedSizeBytes = $scenarioBytes.Length
}
[Console]::Out.WriteLine(($baseResponse | ConvertTo-Json -Compress -Depth 5))
