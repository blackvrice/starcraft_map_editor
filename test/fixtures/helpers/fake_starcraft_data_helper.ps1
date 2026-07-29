$ErrorActionPreference = "Stop"

$requestText = [Console]::In.ReadLine()
$request = $requestText | ConvertFrom-Json
$revision = "4971d363e665551ac4142f541e5f2d71f1cda653"

if ($request.installationPath -like "*hang*") {
    Start-Sleep -Seconds 30
    exit 0
}

if ($request.installationPath -like "*large-output*") {
    [Console]::Out.WriteLine(("x" * 4096))
    exit 0
}

if ($request.installationPath -like "*invalid-response*") {
    [Console]::Out.WriteLine("{not-json")
    exit 0
}

$base = [ordered]@{
    protocolVersion = 1
    requestId = $request.requestId
    operation = "inspectInstallation"
    helperVersion = "0.1.0"
    cascLibRevision = $revision
}

if ($request.installationPath -like "*storage-error*") {
    $base.status = "error"
    $base.error = [ordered]@{
        code = "SC_CASC_STORAGE_OPEN_FAILED"
        message = "The StarCraft CASC storage could not be opened."
        stage = "open-storage"
        nativeError = 2
    }
    [Console]::Out.WriteLine(($base | ConvertTo-Json -Depth 8 -Compress))
    [Console]::Error.WriteLine("SC_CASC_STORAGE_OPEN_FAILED")
    exit 3
}

$missingPaths = @()
$invalidAssets = @()
$foundCount = 40
if ($request.installationPath -like "*incomplete*") {
    $missingPaths = @("tileset\badlands.cv5")
    $foundCount = 39
}
if ($request.installationPath -like "*unreadable*") {
    $invalidAssets = @(
        [ordered]@{
            path = "tileset\platform.vf4"
            nativeError = 13
        }
    )
    $foundCount = 39
}

$base.status = "success"
$base.installation = [ordered]@{
    path = $request.installationPath
    storageProduct = "s1"
    storageBuildNumber = 13515
}
$base.assets = [ordered]@{
    requiredCount = 40
    foundCount = $foundCount
    totalBytes = 1048576
    missingPaths = $missingPaths
    invalidAssets = $invalidAssets
}

if ($request.installationPath -like "*protocol-mismatch*") {
    $base.protocolVersion = 2
}
if ($request.installationPath -like "*request-mismatch*") {
    $base.requestId = "another-request"
}
if ($request.installationPath -like "*revision-mismatch*") {
    $base.cascLibRevision = "0000000000000000000000000000000000000000"
}
if ($request.installationPath -like "*path-mismatch*") {
    $base.installation.path = "C:\Different\StarCraft"
}
if ($request.installationPath -like "*manifest-mismatch*") {
    $base.assets.foundCount = 39
    $base.assets.missingPaths = @("tileset\unknown.cv5")
}
if ($request.installationPath -like "*size-mismatch*") {
    $base.assets.totalBytes = 268435457
}

[Console]::Out.WriteLine(($base | ConvertTo-Json -Depth 8 -Compress))
exit 0
