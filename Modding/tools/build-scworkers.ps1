# StarCraft workers (SCV, Zerg Drone, Probe) like in SC:
#  1. gathering animation from SC's iscript.bin (anim 15 of the unit image, read with tools/ScIscript.cs, not guessed):
#       SCV   (scv.grp)   w1 f34 ATTACK w1 f17 loop   -> body sets 2/1 alternating + bullet\scvspark.grp (10 frames)
#       Drone (drone.grp) f85 w2 f102 w2 f119 w2 f136 w2 loop -> body sets 5,6,7,8
#       Probe (probe.grp) ATTACK w1 loop              -> body set 0 + bullet\ephFire.grp (12 frames, drawn through bfire.pcx)
#     The spark/beam (SC draws it on the mineral) is baked in front of the worker. Played through Vinifera's idle animation
#     (Art IdleRate/StartIdleFrame/IdleFrames); tools/patch-vinifera-workers.ps1 limits it to harvesters that are harvesting.
#  2. Main buildings as drop-off points (CC, Nexus, Hatchery: Refinery=yes) were tried on 2026-10-26 and removed at the user's
#     request: workers use their faction's refinery only. The Terran Refinery comes with two SCVs instead of the DTA harvester
#     (FreeUnit=SCSCV + game.exe patch tools/patch-freescv.ps1, run here too).
#  3. UnloadingClass=<itself>: without it Vinifera draws a docked harvester as Rules [General] UnloadingHarvester=HORV
#     (the GDI voxel harvester) while it unloads.
# New SHPs under new names (SCSCVW, SCZWORKW, SCPPROBEW in MIX/ECACHE78.MIX), used through Rules Image=, so the generators of
# the faction sessions (build-scunits/-sczergbase/-scprotoss) and their MIX files stay untouched.
#   .\build-scworkers.ps1            -> ECACHE78.MIX + preview PNGs in -PreviewDir
#   .\build-scworkers.ps1 -Install   -> + blocks "; >>> SC workers" in Art.ini, StarCraft.ini, Terran Faction.ini and the DLL patch
# Wiki: Modding/wiki/mods/sc-workers.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\scworkers-preview",
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScBuild.cs", "$tools\ScBuildings.cs", "$tools\ScUnits.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null
if ($Install -and (Get-Process -Name game -ErrorAction SilentlyContinue)) { throw "game.exe is running: close the game first" }

$casc  = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"
$scPal   = [Pal]::ReadWpe($casc.ReadFile('TileSet/jungle.wpe'))
$unitPal = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$w = 0; $h = 0; $tpal = $null
$tunit = [Pal]::ReadPcx($casc.ReadFile('game/tunit.pcx'), [ref]$w, [ref]$h, [ref]$tpal)
$ramp = New-Object 'System.Drawing.Color[]' 8
for ($i = 0; $i -lt 8; $i++) { $ramp[$i] = $tpal[$tunit[$i]] }
$map = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)
# ephFire is drawn by SC through the remap table bfire.pcx (images.dat draw function 9, remap 3): row = GRP index - 1,
# column = background; baked over a black background, too-dark pixels dropped (same as the muzzle flashes in build-scunits.ps1)
$w = 0; $h = 0; $bpal = $null
$bfire = [Pal]::ReadPcx($casc.ReadFile('TileSet/jungle/bfire.pcx'), [ref]$w, [ref]$h, [ref]$bpal)
$mapBlue = New-Object byte[] 256
for ($i = 1; $i -le $h; $i++) { $c = $scPal[$bfire[($i - 1) * 256]]; if ([Math]::Max($c.R, [Math]::Max($c.G, $c.B)) -ge 40) { $mapBlue[$i] = [Pal]::Nearest($c, $unitPal, 32, 254) } }
function G($path) { return [Grp]::Read($casc.ReadFile("unit/$path.grp")) }

# Worker SHP: stand 0-31 (set 0), walk (W per facing), [fire 2 per facing], idle = gathering (N per facing), shadows in the
# second half (body silhouette moved down: SC draws these workers' shadows from the body).
#   $gather: list of @(bodySet, sparkFrame or -1) for one cycle
function Worker($id, $grp, [int[]]$walkSets, [bool]$fire, $gather, $spark, $sparkMap, [int]$sparkR, [int]$shadowDy, [int]$cw) {
    $u = New-Object UnitBuilder $cw, $cw, $map
    $sp = New-Object UnitBuilder $cw, $cw, $sparkMap
    $add = { param($set, $f, $sf)
        $b = $u.Layer($u.New(), $grp, $set, $f, $true, $null, 0, 0, $false)
        $s = $u.Silhouette($b, 0, $shadowDy)
        if ($sf -ge 0) {
            # the spark lies on the resource in front of the worker: facing f (clockwise from north), ground plane 2:1
            $a = $f * [Math]::PI / 16
            $dx = [int][Math]::Round([Math]::Sin($a) * $sparkR); $dy = [int][Math]::Round(-[Math]::Cos($a) * $sparkR * 0.6) + 2
            $k = $sp.LayerAt($sp.New(), $spark, $sf, $false, $dx, $dy, $false)
            $behind = [Math]::Cos($a) -gt 0.35       # facing away from the viewer: the spark is behind the body
            for ($i = 0; $i -lt $b.Pixels.Length; $i++) { if ($k.Pixels[$i] -ne 0 -and (-not $behind -or $b.Pixels[$i] -eq 0)) { $b.Pixels[$i] = $k.Pixels[$i] } }
        }
        $u.Add($b, $s)
    }
    for ($f = 0; $f -lt 32; $f++) { & $add 0 $f -1 }
    for ($f = 0; $f -lt 32; $f++) { foreach ($s in $walkSets) { & $add $s $f -1 } }
    if ($fire) { for ($f = 0; $f -lt 32; $f++) { & $add 0 $f -1; & $add 0 $f -1 } }
    $idle = $u.Frames.Count
    for ($f = 0; $f -lt 32; $f++) { foreach ($g in $gather) { & $add $g[0] $f $g[1] } }
    $shp = $u.ToShp()
    $n = $gather.Count
    $prev = [int[]](@(0, 8, 16, 24) + @(0..($n - 1) | ForEach-Object { $idle + 12 * $n + $_ }) + @(0..($n - 1) | ForEach-Object { $idle + 20 * $n + $_ }))
    [Pal]::Sheet($shp.Frames, $prev, $cw, $cw, $unitPal, 2, [Math]::Max(4, $n), "$PreviewDir\$id.png")
    "{0,-9} {1,4} frames {2}x{2}, idle from {3}, {4} per facing" -f $id, $shp.Frames.Count, $cw, $idle, $n
    return @{ Shp = $shp; Idle = $idle; N = $n }
}

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$scvGather = @(0..9 | ForEach-Object { , @($(if ($_ % 2) { 1 } else { 2 }), $_) })
$scv = Worker 'SCSCVW' (G 'terran/scv') ([int[]]@()) $false $scvGather (G 'bullet/scvspark') $map 16 5 96
$droneGather = @(5, 6, 7, 8 | ForEach-Object { , @($_, -1) })
$drone = Worker 'SCZWORKW' (G 'zerg/drone') ([int[]](0..4)) $true $droneGather $null $map 0 6 96
$probeGather = @(0..11 | ForEach-Object { , @(0, $_) })
$probe = Worker 'SCPPROBEW' (G 'protoss/probe') ([int[]]@(0)) $true $probeGather (G 'bullet/ephFire') $mapBlue 16 8 96
foreach ($p in @(@('SCSCVW', $scv), @('SCZWORKW', $drone), @('SCPPROBEW', $probe))) { $files["$($p[0]).SHP"] = $p[1].Shp.Write() }
[Mix]::Write("$game\MIX\ECACHE78.MIX", $files)
"ECACHE78.MIX: $($files.Count) files; previews in $PreviewDir"
if (-not $Install) { return }

# ------------------------------------------------------------------ INI side
$latin = [Text.Encoding]::GetEncoding(28591)
$begin = '; >>> SC workers'; $end = '; <<< SC workers'
function Backup([string]$path) { if (-not (Test-Path "$path.bak")) { Copy-Item $path "$path.bak" } }
function Nl([string]$path) { if ([IO.File]::ReadAllText($path, $latin).Contains("`r`n")) { "`r`n" } else { "`n" } }
function Set-Block([string]$path, [string]$body) {
    Backup $path; $nl = Nl $path
    $t = [IO.File]::ReadAllText($path, $latin)
    $block = ($begin + $nl + ($body.Trim() -replace "`r?`n", $nl) + $nl + $end + $nl)
    $a = $t.IndexOf($begin)
    if ($a -ge 0) { $b = $t.IndexOf($end, $a); $b = $t.IndexOf("`n", $b) + 1; $t = $t.Substring(0, $a) + $block + $t.Substring($b) }
    else { if (-not $t.EndsWith("`n")) { $t += $nl }; $t += $nl + $block }
    [IO.File]::WriteAllText($path, $t, $latin)
}

Set-Block "$game\INI\Art.ini" @"
; StarCraft workers with the SC gathering animation (tools/build-scworkers.ps1, MIX/ECACHE78.MIX, wiki mods/sc-workers).
; Idle frames = gathering; Vinifera.dll patch (tools/patch-vinifera-workers.ps1): only while the worker is harvesting.
; IdleRate in game ticks per frame (about 45 per second; SC: 1 iscript wait = 42 ms).
[SCSCVW]
Cameo=SCSCVI
Voxel=no
Remapable=yes
Facings=32
StartStandFrame=0
StandingFrames=1
StartWalkFrame=0
WalkFrames=1
StartIdleFrame=$($scv.Idle)
IdleFrames=$($scv.N)
IdleRate=2
PrimaryFireFLH=48,0,40

[SCZWORKW]
Cameo=SCZWORKI
Voxel=no
Remapable=yes
Facings=32
StartStandFrame=0
StandingFrames=1
StartWalkFrame=32
WalkFrames=5
StartFiringFrame=192
FiringFrames=2
StartIdleFrame=$($drone.Idle)
IdleFrames=$($drone.N)
IdleRate=4

[SCPPROBEW]
Cameo=SCPPROBEI
Voxel=no
Remapable=yes
Facings=32
StartStandFrame=0
StandingFrames=1
StartWalkFrame=32
WalkFrames=1
StartFiringFrame=64
FiringFrames=2
StartIdleFrame=$($probe.Idle)
IdleFrames=$($probe.N)
IdleRate=2
"@

Set-Block "$game\INI\Game Options\StarCraft.ini" @"
; SC workers (tools/build-scworkers.ps1, wiki mods/sc-workers): gathering animation (Image=, Art [SCSCVW]) and the SCV drawn as
; itself while unloading (UnloadingClass; default would be HORV). The client merges repeated sections, later keys win.
; User 2026-10-26: the Command Center is NOT a drop-off point (SCVs use the Refinery), and the Refinery comes with two SCVs
; instead of the DTA harvester (FreeUnit=SCSCV; the second SCV is the game.exe patch tools/patch-freescv.ps1).
[SCSCV]
Image=SCSCVW
UnloadingClass=SCSCV

[SCREFI]
FreeUnit=SCSCV
Description=Processes Tiberium, Ore and Gems brought by SCVs.@@Comes with two SCVs when built.
"@

Set-Block "$game\INI\Map Code\Terran Faction.ini" @"
; SC workers (tools/build-scworkers.ps1, wiki mods/sc-workers): gathering animation (Image=, Art [SCZWORKW]/[SCPPROBEW]),
; workers drawn as themselves while unloading (UnloadingClass; default would be HORV).
; User 2026-10-26: Hatchery/Lair/Hive and Nexus are NOT drop-off points; Drones use the Extractor, Probes the Assimilator
; (Dock= of the faction blocks).
[SCZWORK]
Image=SCZWORKW
UnloadingClass=SCZWORK

[SCPPROBE]
Image=SCPPROBEW
UnloadingClass=SCPPROBE
"@
"INI blocks written (Art.ini, StarCraft.ini, Terran Faction.ini)"
& "$tools\patch-vinifera-workers.ps1"
& "$tools\patch-freescv.ps1"
