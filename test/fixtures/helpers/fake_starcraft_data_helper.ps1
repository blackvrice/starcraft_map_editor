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
    protocolVersion = 3
    requestId = $request.requestId
    operation = $request.operation
    helperVersion = "0.4.0"
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

if ($request.operation -eq "inspectInstallation") {
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

    if ($request.installationPath -like "*manifest-mismatch*") {
        $base.assets.foundCount = 39
        $base.assets.missingPaths = @("tileset\unknown.cv5")
    }
    if ($request.installationPath -like "*size-mismatch*") {
        $base.assets.totalBytes = 268435457
    }
}
elseif ($request.operation -eq "renderTileAtlas") {
    if ($request.installationPath -like "*asset-error*") {
        $base.status = "error"
        $base.error = [ordered]@{
            code = "SC_CASC_TILE_ASSET_INVALID"
            message = "A required tile rendering asset is unreadable."
            stage = "read-assets"
            nativeError = 13
        }
        [Console]::Out.WriteLine(($base | ConvertTo-Json -Depth 8 -Compress))
        [Console]::Error.WriteLine("SC_CASC_TILE_ASSET_INVALID")
        exit 3
    }

    $supported = @($request.rawValues | Where-Object { [int]$_ -lt 0x5000 })
    $unsupported = @($request.rawValues | Where-Object { [int]$_ -ge 0x5000 })
    $tileCount = $supported.Count
    $columns = if ($tileCount -eq 0) { 0 } else { [Math]::Min($tileCount, 64) }
    $rows = if ($tileCount -eq 0) { 0 } else { [int][Math]::Ceiling($tileCount / [double]$columns) }
    $entryBytes = $tileCount * 4
    $pixelBytes = $columns * $rows * 32 * 32 * 4

    $stream = [IO.MemoryStream]::new()
    $writer = [IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([byte[]](0x53, 0x43, 0x54, 0x52, 0x47, 0x42, 0x41, 0x00))
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint16]$columns)
        $writer.Write([uint16]$rows)
        $writer.Write([uint32]$tileCount)
        $writer.Write([uint32]$entryBytes)
        $writer.Write([uint32]$pixelBytes)
        $writer.Write([uint32]0)
        foreach ($rawValue in $supported) {
            $writer.Write([uint16]$rawValue)
            $writer.Write([uint16]0)
        }
        if ($pixelBytes -gt 0) {
            $writer.Write([byte[]]::new($pixelBytes))
        }
        $writer.Flush()
        $atlasBytes = $stream.ToArray()
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }

    if ($request.installationPath -like "*atlas-header-mismatch*") {
        $atlasBytes[0] = 0
    }
    if (($request.installationPath -like "*atlas-entry-mismatch*") -and $tileCount -gt 0) {
        $atlasBytes[32] = 0xFE
        $atlasBytes[33] = 0x3F
    }
    if ($request.installationPath -notlike "*atlas-output-missing*") {
        [IO.File]::WriteAllBytes(
            (Join-Path (Get-Location) "tile-atlas.rgba"),
            $atlasBytes
        )
    }

    $base.status = "success"
    $base.installation = [ordered]@{
        path = $request.installationPath
        storageProduct = "s1"
        storageBuildNumber = 13515
    }
    $base.tileset = [int]$request.tileset
    $base.assets = [ordered]@{
        readCount = 4
        totalBytes = 1048576
    }
    $base.atlas = [ordered]@{
        fileName = "tile-atlas.rgba"
        fileBytes = $atlasBytes.Length
        formatVersion = 1
        tileSize = 32
        columns = $columns
        rows = $rows
        tileCount = $tileCount
    }
    $base.unsupportedRawValues = $unsupported

    if ($request.installationPath -like "*tileset-mismatch*") {
        $base.tileset = ([int]$request.tileset + 1) % 8
    }
    if ($request.installationPath -like "*atlas-size-mismatch*") {
        $base.atlas.fileBytes++
    }
    if ($request.installationPath -like "*atlas-output-name-mismatch*") {
        $base.atlas.fileName = "other.rgba"
    }
    if ($request.installationPath -like "*unsupported-mismatch*") {
        $base.unsupportedRawValues = @()
    }
    if ($request.installationPath -like "*asset-size-mismatch*") {
        $base.assets.totalBytes = 0
    }
}
elseif ($request.operation -eq "renderObjectAtlas") {
    if ($request.installationPath -like "*object-error*") {
        $base.status = "error"
        $base.error = [ordered]@{
            code = "SC_CASC_OBJECT_PALETTE_INVALID"
            message = "The object palette is invalid."
            stage = "decode-palette"
            nativeError = 13
        }
        [Console]::Out.WriteLine(($base | ConvertTo-Json -Depth 8 -Compress))
        [Console]::Error.WriteLine("SC_CASC_OBJECT_PALETTE_INVALID")
        exit 3
    }

    $supported = @($request.objects | Where-Object { [int]$_.id -lt 500 })
    $unsupported = @($request.objects | Where-Object { [int]$_.id -ge 500 })
    $entryCount = $supported.Count
    $entryBytes = $entryCount * 32
    $frameBytes = 2 * 3 * 4
    $pixelBytes = $entryCount * $frameBytes

    $stream = [IO.MemoryStream]::new()
    $writer = [IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([byte[]](0x53, 0x43, 0x4F, 0x52, 0x47, 0x42, 0x41, 0x00))
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$entryCount)
        $writer.Write([uint32]$entryBytes)
        $writer.Write([uint32]$pixelBytes)
        $writer.Write([uint32]0)
        $writer.Write([uint32]0)
        $pixelOffset = 0
        foreach ($object in $supported) {
            $kind = if ($object.kind -eq "unit") { 0 } else { 1 }
            $playerColor = if ($null -eq $object.playerColor) { 255 } else { [int]$object.playerColor }
            $spriteId = if ($kind -eq 0) { [int]$object.id + 1 } else { [int]$object.id }
            $writer.Write([byte]$kind)
            $writer.Write([byte]$playerColor)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]$object.id)
            $writer.Write([uint16]$spriteId)
            $writer.Write([uint16]([int]$object.id + 2))
            $writer.Write([uint16]2)
            $writer.Write([uint16]3)
            $writer.Write([int16]-1)
            $writer.Write([int16]2)
            $writer.Write([uint16]0)
            $writer.Write([uint32]$pixelOffset)
            $writer.Write([uint32]$frameBytes)
            $writer.Write([uint32]0)
            $pixelOffset += $frameBytes
        }
        foreach ($object in $supported) {
            $pixels = [byte[]]::new($frameBytes)
            for ($index = 0; $index -lt $frameBytes; $index += 4) {
                $pixels[$index] = [byte]([int]$object.id % 255)
                $pixels[$index + 1] = 80
                $pixels[$index + 2] = 160
                $pixels[$index + 3] = 255
            }
            $writer.Write($pixels)
        }
        $writer.Flush()
        $atlasBytes = $stream.ToArray()
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }

    if ($request.installationPath -like "*object-atlas-header-mismatch*") {
        $atlasBytes[0] = 0
    }
    if (($request.installationPath -like "*object-atlas-entry-mismatch*") -and $entryCount -gt 0) {
        $atlasBytes[36] = 0xFE
        $atlasBytes[37] = 0x3F
    }
    if ($request.installationPath -notlike "*object-atlas-output-missing*") {
        [IO.File]::WriteAllBytes(
            (Join-Path (Get-Location) "object-atlas.rgba"),
            $atlasBytes
        )
    }

    $unsupportedObjects = @(
        $unsupported | ForEach-Object {
            [ordered]@{
                kind = $_.kind
                id = [int]$_.id
                playerColor = $_.playerColor
                direction = [int]$_.direction
                code = "SC_CASC_OBJECT_ID_UNSUPPORTED"
            }
        }
    )
    $base.status = "success"
    $base.installation = [ordered]@{
        path = $request.installationPath
        storageProduct = "s1"
        storageBuildNumber = 13515
    }
    $base.tileset = [int]$request.tileset
    $base.assets = [ordered]@{
        readCount = 8
        totalBytes = 1048576
    }
    $base.atlas = [ordered]@{
        fileName = "object-atlas.rgba"
        fileBytes = $atlasBytes.Length
        formatVersion = 1
        entryCount = $entryCount
        tileset = [int]$request.tileset
    }
    $base.unsupportedObjects = $unsupportedObjects

    if ($request.installationPath -like "*object-tileset-mismatch*") {
        $base.atlas.tileset = ([int]$request.tileset + 1) % 8
    }
    if ($request.installationPath -like "*object-atlas-size-mismatch*") {
        $base.atlas.fileBytes++
    }
    if ($request.installationPath -like "*object-atlas-output-name-mismatch*") {
        $base.atlas.fileName = "other.rgba"
    }
    if ($request.installationPath -like "*object-unsupported-mismatch*") {
        $base.unsupportedObjects = @()
    }
    if ($request.installationPath -like "*object-asset-size-mismatch*") {
        $base.assets.totalBytes = 0
    }
}
else {
    $base.status = "error"
    $base.error = [ordered]@{
        code = "SC_CASC_PROTOCOL_OPERATION_UNSUPPORTED"
        message = "Unsupported operation."
        stage = "protocol"
        nativeError = 50
    }
    [Console]::Out.WriteLine(($base | ConvertTo-Json -Depth 8 -Compress))
    exit 2
}

if ($request.installationPath -like "*protocol-mismatch*") {
    $base.protocolVersion = 1
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

[Console]::Out.WriteLine(($base | ConvertTo-Json -Depth 8 -Compress))
exit 0
