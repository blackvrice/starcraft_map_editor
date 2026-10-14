$ErrorActionPreference = 'Stop'
$request = [Console]::In.ReadLine() | ConvertFrom-Json
if ($request.installationPath -like '*hang*') { Start-Sleep -Seconds 30; exit 0 }
if ($request.installationPath -like '*overflow*') { [Console]::Out.WriteLine(('x' * 10000)); exit 0 }
if ($request.installationPath -like '*invalid*') { [Console]::Out.WriteLine('{bad'); exit 0 }
if ($request.installationPath -like '*failure*') { [Console]::Error.WriteLine('SC_CASC_STORAGE_OPEN_FAILED'); exit 3 }
if ($request.operation -eq 'readTerrainPlacement') {
  $names = @('badlands','platform','install','ashworld','jungle','desert','ice','twilight')
  $name = $names[$request.tileset]
  $references = @(for ($i=0; $i -lt 4096; $i++) { ,@(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,65535) })
  $response = @{
    protocolVersion=3; helperVersion='0.13.0'; cascLibRevision='4971d363e665551ac4142f541e5f2d71f1cda653'
    requestId=$request.requestId; operation=$request.operation; status='success'
    snapshotVersion=1; tileset=$request.tileset
    installation=@{path=$request.installationPath; storageProduct='synthetic'; storageBuildNumber=1}
    assets=@(
      @{path="tileset\$name.cv5"; bytes=(4096*52); sha256=('a'*64)},
      @{path="tileset\$name.vf4"; bytes=(65536*32); sha256=('b'*64)}
    )
    groupBuildable=@(for ($i=0; $i -lt 4096; $i++) { $i % 2 -eq 0 })
    megaTileReferences=$references
    walkableMasks=@(for ($i=0; $i -lt 65536; $i++) { $i })
  }
  if ($request.installationPath -like '*mismatch*') { $response.snapshotVersion=2 }
  [Console]::Error.WriteLine('synthetic placement snapshot log')
  [Console]::Out.WriteLine(($response | ConvertTo-Json -Depth 8 -Compress))
  exit 0
}
$count = 2048
$groups = @(for ($i=0; $i -lt $count; $i++) {
  @{ group=$i; terrainTypeWord=65535; flagsWord=32769; linkWords=@(0,48,64,65535); stackWords=@(0,1,2,3); megaTileReferences=@(1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1); renderableMembers=@(0,3,15) }
})
$response = @{
 protocolVersion=3; helperVersion='0.13.0'; cascLibRevision='4971d363e665551ac4142f541e5f2d71f1cda653'
 requestId=$request.requestId; operation=$request.operation; status='success'
 snapshotVersion=2; tileset=0; isomShapesResolved=$false
 installation=@{ path=$request.installationPath; storageProduct='synthetic'; storageBuildNumber=1 }
 assets=@(
   @{path='tileset\badlands.cv5'; bytes=($count*52); sha256=('a'*64)},
   @{path='tileset\badlands.vx4ex'; bytes=64; sha256=('b'*64)},
   @{path='tileset\badlands.vr4'; bytes=64; sha256=('c'*64)},
   @{path='tileset\badlands.wpe'; bytes=1024; sha256=('d'*64)}
 )
 groups=$groups
}
[Console]::Error.WriteLine('synthetic snapshot log')
[Console]::Out.WriteLine(($response | ConvertTo-Json -Depth 8 -Compress))
