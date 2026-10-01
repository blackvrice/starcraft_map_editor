$ErrorActionPreference = 'Stop'
$request = [Console]::In.ReadLine() | ConvertFrom-Json
if ($request.installationPath -like '*hang*') { Start-Sleep -Seconds 30; exit 0 }
if ($request.installationPath -like '*invalid*') { [Console]::Out.WriteLine('{bad'); exit 0 }
if ($request.installationPath -like '*failure*') { [Console]::Error.WriteLine('SC_EUD_DAT_MISSING'); exit 3 }
$columns = @{
  'unit.groundWeapon' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.airWeapon' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.flingy' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.seekRange' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.sightRange' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.sizeType' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.baseProperty' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.portrait' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.readySound' = @(for ($i=0; $i -lt 106; $i++) { 0 })
  'unit.whatSoundStart' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.whatSoundEnd' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.pissedSoundStart' = @(for ($i=0; $i -lt 106; $i++) { 0 })
  'unit.pissedSoundEnd' = @(for ($i=0; $i -lt 106; $i++) { 0 })
  'unit.yesSoundStart' = @(for ($i=0; $i -lt 106; $i++) { 0 })
  'unit.yesSoundEnd' = @(for ($i=0; $i -lt 106; $i++) { 0 })
  'weapon.targetFlags' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.cooldown' = @(for ($i=0; $i -lt 130; $i++) { 15 })
  'weapon.damageFactor' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.attackAngle' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.launchSpin' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.removeAfter' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.splashInnerRadius' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.splashMiddleRadius' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.splashOuterRadius' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.behavior' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.explosionType' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.flingy' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'flingy.topSpeed' = @(for ($i=0; $i -lt 209; $i++) { 0 })
  'flingy.acceleration' = @(for ($i=0; $i -lt 209; $i++) { 0 })
  'flingy.haltDistance' = @(for ($i=0; $i -lt 209; $i++) { 0 })
  'flingy.turnSpeed' = @(for ($i=0; $i -lt 209; $i++) { 0 })
  'flingy.movementControl' = @(for ($i=0; $i -lt 209; $i++) { 0 })
  'flingy.sprite' = @(for ($i=0; $i -lt 209; $i++) { 0 })
  'upgrade.mineralCostBase' = @(for ($i=0; $i -lt 61; $i++) { 0 })
  'upgrade.mineralCostFactor' = @(for ($i=0; $i -lt 61; $i++) { 0 })
  'upgrade.gasCostBase' = @(for ($i=0; $i -lt 61; $i++) { 0 })
  'upgrade.gasCostFactor' = @(for ($i=0; $i -lt 61; $i++) { 0 })
  'upgrade.timeCostBase' = @(for ($i=0; $i -lt 61; $i++) { 0 })
  'upgrade.timeCostFactor' = @(for ($i=0; $i -lt 61; $i++) { 0 })
  'upgrade.maxLevel' = @(for ($i=0; $i -lt 61; $i++) { 0 })
  'upgrade.race' = @(for ($i=0; $i -lt 61; $i++) { 0 })
  'tech.race' = @(for ($i=0; $i -lt 44; $i++) { 0 })
  'tech.mineralCost' = @(for ($i=0; $i -lt 44; $i++) { 0 })
  'tech.gasCost' = @(for ($i=0; $i -lt 44; $i++) { 0 })
  'tech.timeCost' = @(for ($i=0; $i -lt 44; $i++) { 0 })
  'tech.energyCost' = @(for ($i=0; $i -lt 44; $i++) { 0 })
  'sprite.image' = @(for ($i=0; $i -lt 517; $i++) { 0 })
  'sprite.isVisible' = @(for ($i=0; $i -lt 517; $i++) { 0 })
  'image.isTurnable' = @(for ($i=0; $i -lt 999; $i++) { 0 })
  'image.isClickable' = @(for ($i=0; $i -lt 999; $i++) { 0 })
  'image.useFullIscript' = @(for ($i=0; $i -lt 999; $i++) { 0 })
  'image.drawIfCloaked' = @(for ($i=0; $i -lt 999; $i++) { 0 })
  'image.drawingFunction' = @(for ($i=0; $i -lt 999; $i++) { 0 })
  'unit.hasShield' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.maxShield' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'weapon.minRange' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.maxRange' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'weapon.damageType' = @(for ($i=0; $i -lt 130; $i++) { 0 })
  'unit.subunit1' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.subunit2' = @(for ($i=0; $i -lt 228; $i++) { 0 })
  'unit.construction_animation' = @(for ($i=0; $i -lt 228; $i++) { 0 })
}
$response = @{
  protocolVersion=3; helperVersion='0.11.0'; cascLibRevision='4971d363e665551ac4142f541e5f2d71f1cda653'
  requestId=$request.requestId; operation=$request.operation; status='success'; snapshotVersion=1
  revision='classic-dat-v1-pyms-bfc5d3a-eudplib-0.80.6'
  installation=@{ path=$request.installationPath; storageProduct='synthetic'; storageBuildNumber=1 }
  assets=@(
    @{path='arr\units.dat'; bytes=19876; sha256=('a'*64)},
    @{path='arr\weapons.dat'; bytes=5460; sha256=('a'*64)},
    @{path='arr\flingy.dat'; bytes=3135; sha256=('a'*64)},
    @{path='arr\upgrades.dat'; bytes=1281; sha256=('a'*64)},
    @{path='arr\techdata.dat'; bytes=836; sha256=('a'*64)},
    @{path='arr\sprites.dat'; bytes=3229; sha256=('a'*64)},
    @{path='arr\images.dat'; bytes=37962; sha256=('a'*64)}
  )
  columns=$columns
}
[Console]::Error.WriteLine('synthetic EUD log')
[Console]::Out.WriteLine(($response | ConvertTo-Json -Depth 8 -Compress))
