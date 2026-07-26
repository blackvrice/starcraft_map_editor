$ErrorActionPreference = 'Stop'

$requestText = [Console]::In.ReadLine()
$request = $requestText | ConvertFrom-Json
$mode = [IO.Path]::GetFileNameWithoutExtension([string]$request.sourcePath)

$baseResponse = [ordered]@{
    protocolVersion = 1
    requestId = [string]$request.requestId
    operation = [string]$request.operation
    helperVersion = '0.1.0'
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

[byte[]]$scenarioBytes = 86, 69, 82, 32, 2, 0, 0, 0, 59, 0
[IO.File]::WriteAllBytes(
    [string]$request.scenarioOutputPath,
    $scenarioBytes
)

$baseResponse.status = 'success'
$baseResponse.archive = [ordered]@{
    sizeBytes = 128
    totalEntryCount = 2
}
$baseResponse.scenario = [ordered]@{
    archivePath = 'staredit\scenario.chk'
    uncompressedSizeBytes = $scenarioBytes.Length
    compressedSizeBytes = $scenarioBytes.Length
}
[Console]::Out.WriteLine(($baseResponse | ConvertTo-Json -Compress -Depth 5))
