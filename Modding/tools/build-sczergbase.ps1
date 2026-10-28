# Zerg FACTION for DTA: every Zerg building and unit of StarCraft: Brood War, built the StarCraft way: every building is
# a Drone vehicle with DeploysInto=<building> and grows from the SC cocoon for its SC build time.
#   .\build-sczergbase.ps1           -> MIX/ECACHE86.MIX (SHP, cameos, AUD) + previews in -PreviewDir
#   .\build-sczergbase.ps1 -Install  -> also the INI side: faction (map code layer INI/Map Code/SC Factions/* Zerg faction.ini,
#                                       block "Zerg faction", + [General] BaseUnit/HarvesterUnit of the bottom layer),
#                                       Art.ini / Sound.ini blocks, StarCraft.ini clean-up, lobby (Resources/GameOptions.ini,
#                                       INI/MPMaps.ini) and side files (SideC08/sidenc08/Speech08, zergicon.png, loading screens).
# Blocks sit between "; >>> Zerg faction" and "; <<< Zerg faction", own list entries use ZRB/ZRG/ZRI keys and [SoundList] 1300+,
# so re-running replaces them. Needs game.exe patched by tools/patch-buildup.ps1 (long buildups). Wiki: Modding/wiki/mods/zerg-faction.md
# Variable names: PowerShell is case-insensitive, so lists and loop variables must differ ($Bldgs/$bd, not $B/$b).
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\sczergbase-preview",
    [string]$OutMix = "",   # default: <game>\MIX\ECACHE86.MIX
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScBuild.cs", "$tools\ScBuildings.cs", "$tools\ScInfantry.cs", "$tools\ScZerg.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null
$casc  = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"

$scPal    = [Pal]::ReadWpe($casc.ReadFile('TileSet/jungle.wpe'))
$unitPal  = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$cameoPal = [Pal]::ReadTs($mixes.Read('CAMEO.PAL'))
$w = 0; $h = 0; $tpal = $null
$tunit = [Pal]::ReadPcx($casc.ReadFile('game/tunit.pcx'), [ref]$w, [ref]$h, [ref]$tpal)
$ramp = New-Object 'System.Drawing.Color[]' 8
for ($i = 0; $i -lt 8; $i++) { $ramp[$i] = $tpal[$tunit[$i]] }
$map    = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)
$dmgMap = [ScBuildings]::DamageMap($map, $unitPal)

$grpCache = @{}
function G($name) {
    $path = if ($name.Contains('/')) { "unit/$name.grp" } else { "unit/zerg/$name.grp" }   # 'terran/control' for the Infested CC
    if (-not $grpCache.ContainsKey($name)) { $grpCache[$name] = [Grp]::Read($casc.ReadFile($path)) }
    return $grpCache[$name]
}
function Layers { $l = New-Object 'System.Collections.Generic.List[ScLayer]'; foreach ($a in $args) { if ($a) { $l.Add($a) } }; return ,$l }
function L($grp, $frame, $shadow = $false) { return New-Object ScLayer (G $grp), $frame, $shadow }

# ------------------------------------------------------------------ buildings
# GRP names from SC's own data (units.dat -> flingy -> sprites -> images.tbl), several are historical: Spawning Pool = chrysal,
# Evolution Chamber = cerebrat, Sunken Colony = Lurker, Hydralisk Den = Snakey, Ultralisk Cavern = RCluster, Defiler Mound =
# Mutapit, Greater Spire = MutaCham. Foundations = SC footprints, except the Extractor (SC 4x2): 4x3 + Bib like every DTA refinery.
# Morph = Buildup: ZBuild.grp = Drone curling up (0-1), small cocoon (2-9), burst (10-12), medium (13-19), burst (20-21),
# large (22-27), burst (28-30); then the building with the zSpawn burst. Size 1/2/3 = how many cocoon stages it goes through.
# Morph TIME: the engine plays a buildup at round(BuildupTime 0.09 min x 900 / frames) ticks per frame (game.exe 0x4403DD), i.e.
# ~81 ticks for every building; tools/patch-buildup.ps1 clamps the rate to >= 1, so a buildup of N > 81 frames lasts N ticks.
# Ticks = SC build time in game seconds x 0.63 (SC "Fastest" real time) x 45: the real game rate MEASURED with
# tools/morphprobe.ps1 is 45.2 frames/s at the default "Game Speed" (GameSpeed=1, labelled "60 FPS" in the lobby).
# (First version used Rules "minutes" = 15 ticks/s and morphed 4x too fast: user test 2026-10-25.) Sec = SC build time.
# The cocoon pulses (each frame 3 ticks, ping-pong); every distinct frame is stored once (ScZerg.BuildupCached/WriteShared).
$GameFps = 45
$TicksPerScSecond = 0.63 * $GameFps
$Bldgs = @(
    @{ Id = 'SCZHAT'; Grp = 'hatchery'; Shad = 'zhashad'; Fw = 4; Fh = 3; Size = 3; Sec = 120 }
    @{ Id = 'SCZHTS'; Grp = 'hatchery'; Shad = 'zhashad'; Fw = 4; Fh = 3; Size = 3; Sec = 0; Ticks = 60 }   # start Hatchery: short morph (~1.3 s)
    @{ Id = 'SCZLAI'; Grp = 'lair';     Shad = 'zlrshad'; Fw = 4; Fh = 3; Size = 3; Sec = 100 }
    @{ Id = 'SCZHIV'; Grp = 'hive';     Shad = 'zhishad'; Fw = 4; Fh = 3; Size = 3; Sec = 120 }
    @{ Id = 'SCZEXT'; Grp = 'extract';  Shad = 'zreshad'; Fw = 4; Fh = 3; Size = 3; Sec = 40 }
    @{ Id = 'SCZPOL'; Grp = 'chrysal';  Shad = 'zchshad'; Fw = 3; Fh = 2; Size = 2; Sec = 80 }
    @{ Id = 'SCZEVO'; Grp = 'cerebrat'; Shad = 'zceshad'; Fw = 3; Fh = 2; Size = 2; Sec = 40 }
    @{ Id = 'SCZHDN'; Grp = 'Snakey';   Shad = 'zsbshad'; Fw = 3; Fh = 2; Size = 2; Sec = 40 }
    @{ Id = 'SCZSPI'; Grp = 'spire';    Shad = 'zspshad'; Fw = 2; Fh = 2; Size = 1; Sec = 120 }
    @{ Id = 'SCZGSP'; Grp = 'MutaCham'; Shad = 'zmcshad'; Fw = 2; Fh = 2; Size = 1; Sec = 120 }
    @{ Id = 'SCZNES'; Grp = 'nest';     Shad = 'zneshad'; Fw = 3; Fh = 2; Size = 2; Sec = 60 }
    @{ Id = 'SCZULC'; Grp = 'RCluster'; Shad = 'zrcshad'; Fw = 3; Fh = 2; Size = 2; Sec = 80 }
    @{ Id = 'SCZDFM'; Grp = 'Mutapit';  Shad = 'zmhshad'; Fw = 4; Fh = 2; Size = 2; Sec = 60 }
    @{ Id = 'SCZNYD'; Grp = 'NydusPit'; Shad = 'znyshad'; Fw = 2; Fh = 2; Size = 1; Sec = 40 }
    @{ Id = 'SCZCRP'; Grp = 'fcolony';  Shad = 'zfcshad'; Fw = 2; Fh = 2; Size = 1; Sec = 20 }
    @{ Id = 'SCZSUN'; Grp = 'Lurker';   Shad = 'zlushad'; Fw = 2; Fh = 2; Size = 1; Sec = 40 }   # Creep Colony 20 + morph 20
    @{ Id = 'SCZSPO'; Grp = 'SColony';  Shad = 'zscshad'; Fw = 2; Fh = 2; Size = 1; Sec = 40 }
    # Infested Command Center (SC unit 130): the Terran CC image with the infestation overlay infest03 (SC data), CC shadow
    @{ Id = 'SCZICC'; Grp = 'terran/control'; Over = 'infest03'; Shad = 'terran/tccshad'; Fw = 4; Fh = 3; Size = 3; Sec = 120 }
)
foreach ($bd in $Bldgs) { if (-not $bd.Ticks) { $bd.Ticks = [int][Math]::Round($bd.Sec * $TicksPerScSecond) } }

# Morph schedule: list of @(key, ticks); key 'z<k>' = ZBuild frame k, 's<k>' = building + zSpawn frame k, 'b' = building.
function MorphSchedule([int]$size, [int]$ticks) {
    $loops  = @(@(2..9 + 8..3), @(13..19 + 18..14), @(22..27 + 26..23))
    $bursts = @(@(10, 11, 12), @(20, 21), @(28, 29, 30))
    $fixed = 6 + 12
    for ($i = 0; $i -lt $size; $i++) { $fixed += 3 * $bursts[$i].Count }
    $perLoop = [Math]::Max(3, [int][Math]::Floor(($ticks - $fixed) / $size))
    $extra = [Math]::Max(0, ($ticks - $fixed) - $perLoop * $size)   # rounding remainder goes to the first loop
    $sched = New-Object System.Collections.Generic.List[object]
    $sched.Add(@('z0', 3)); $sched.Add(@('z1', 3))
    for ($i = 0; $i -lt $size; $i++) {
        $left = $perLoop + $(if ($i -eq 0) { $extra } else { 0 }); $j = 0
        while ($left -gt 0) { $tk = [Math]::Min(3, $left); $sched.Add(@("z$($loops[$i][$j % $loops[$i].Count])", $tk)); $left -= $tk; $j++ }
        foreach ($k in $bursts[$i]) { $sched.Add(@("z$k", 3)) }
    }
    foreach ($k in 0..2) { $sched.Add(@("s$k", 3)) }
    $sched.Add(@('b', 3))
    return ,$sched
}

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$cameoFrames = New-Object 'System.Collections.Generic.List[Frame]'
$bodies = @{}
$spawnOf = @{ 1 = 'zspawn01'; 2 = 'zspawn02'; 3 = 'zspawn03' }
foreach ($bd in $Bldgs) {
    $spawn = $spawnOf[$bd.Size]
    $sizes = @($bd.Grp, $bd.Shad, 'zbuild', 'zbshad', $spawn, $bd.Over) | ? { $_ } | % { G $_ }
    $maxW = ($sizes | % { $_.Width } | Measure-Object -Maximum).Maximum
    $maxH = ($sizes | % { $_.Height } | Measure-Object -Maximum).Maximum
    $shape = New-Object ScBuildingShape $bd.Fw, $bd.Fh, $maxW, $maxH, 0
    $over = if ($bd.Over) { L $bd.Over 0 } else { $null }
    $body = Layers (L $bd.Grp 0) $over
    $shad = Layers (L $bd.Shad 0 $true)
    $bodies[$bd.Id] = $body
    $bldg = $shape.Building($body, $shad, $map, $dmgMap)

    $uBodies  = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[ScLayer]]'
    $uShadows = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[ScLayer]]'
    $keyIdx = @{}; $order = New-Object System.Collections.Generic.List[int]; $repeat = New-Object System.Collections.Generic.List[int]
    foreach ($step in (MorphSchedule $bd.Size $bd.Ticks)) {
        $key = $step[0]
        if (-not $keyIdx.ContainsKey($key)) {
            $k = if ($key -ne 'b') { [int]$key.Substring(1) } else { 0 }
            switch ($key[0]) {
                'z' { $uBodies.Add((Layers (L 'zbuild' $k))); $uShadows.Add((Layers (L 'zbshad' $k $true))) }
                's' { $uBodies.Add((Layers (L $bd.Grp 0) $over (L $spawn $k))); $uShadows.Add($shad) }
                'b' { $uBodies.Add($body); $uShadows.Add($shad) }
            }
            $keyIdx[$key] = $uBodies.Count - 1
        }
        $order.Add($keyIdx[$key]); $repeat.Add($step[1])
    }
    $mk = [ScZerg]::BuildupCached($shape, $uBodies, $uShadows, $order.ToArray(), $repeat.ToArray(), $map)

    $files["$($bd.Id).SHP"]   = $bldg.Write()
    $files["$($bd.Id)MK.SHP"] = [ScZerg]::WriteShared($mk)
    $cameo = [ScBuildings]::Cameo($body, $scPal, $ramp, $cameoPal)
    $files["$($bd.Id)IC.SHP"] = $cameo.Write()
    if ($bd.Id -ne 'SCZHTS') { $cameoFrames.Add($cameo.Frames[0]) }

    [ScBuildings]::FitPreview($bldg, 0, 2, $shape, $unitPal, 2, "$PreviewDir\fit_$($bd.Id).png")
    $n = $mk.Frames.Count / 2
    [Pal]::Sheet($mk.Frames, [int[]](0, [int]($n / 4), [int]($n / 2), [int](3 * $n / 4), ($n - 4), ($n - 1)), $shape.Cw, $shape.Ch, $unitPal, 1, 6, "$PreviewDir\mk_$($bd.Id).png")
    "{0,-7} {1}x{2} canvas {3}x{4} morph {5} ticks = {6:N1} s at {7} FPS, buildup {8} KB" -f $bd.Id, $bd.Fw, $bd.Fh, $shape.Cw, $shape.Ch, $n, ($n / $GameFps), $GameFps, [Math]::Round($files["$($bd.Id)MK.SHP"].Length / 1KB)
    if ($n -ne $bd.Ticks) { Write-Warning "$($bd.Id): buildup has $n frames, wanted $($bd.Ticks)" }
}

# ------------------------------------------------------------------ Drones
# SHP vehicles (32 facings): 0-31 stand, 32-191 walk (5 per facing, SC walk sets 0-4), 192-255 "fire", then shadows.
# drone.grp has no shadow GRP (SC draws it from the body), so the shadow is the body moved down a little.
$droneRaw = G 'drone'
$bb = [ScZerg]::Bounds($droneRaw)
$drone = [ScZerg]::Crop($droneRaw, $bb[0], $bb[1])
$droneShp = [ScBuild]::BuildUnit($drone, [ScZerg]::Shifted($drone, 6), $map, [int[]](0..4), 0, 0)
$droneBytes = $droneShp.Write()
"Drone   vehicle {0} frames {1}x{2} (from 128x128)" -f $droneShp.Frames.Count, $droneShp.Width, $droneShp.Height
[Pal]::Sheet($droneShp.Frames, [int[]](0, 4, 8, 12, 16, 20, 24, 28 + 32..36 + 256, 260), $droneShp.Width, $droneShp.Height, $unitPal, 2, 15, "$PreviewDir\drone.png")
$files['SCZWORK.SHP'] = $droneBytes
$wc = [ScInfantry]::Cameo($drone.Frames[12], $drone.Width, $drone.Height, $scPal, $ramp, $cameoPal, [Drawing.Color]::FromArgb(120, 70, 40))
$files['SCZWORKI.SHP'] = $wc.Write(); $cameoFrames.Add($wc.Frames[0])

# "Drone: <building>" types: one SHP copy each, because the art section and the cameo follow the image name.
# Id, building, name, prerequisite of the Drone, what it is for. Building cost/HP/keys are in $BldgIni (INI part).
$DroneFor = @(
    @{ Id = 'SCZDHAT'; B = 'SCZHAT'; Name = 'Hatchery';          Pre = 'ZHATCHERY';         What = 'A new Hatchery: more larvae, a forward base.' }
    @{ Id = 'SCZDLAI'; B = 'SCZLAI'; Name = 'Lair';              Pre = 'ZHATCHERY,SCZPOL';  What = 'Hatchery of the second tier: larvae, radar, unlocks Spire, Queen''s Nest, Lurker.' }
    @{ Id = 'SCZDHIV'; B = 'SCZHIV'; Name = 'Hive';              Pre = 'ZLAIRUP,SCZNES';    What = 'Hatchery of the third tier: unlocks Ultralisk Cavern, Defiler Mound, Greater Spire, Nydus Canal.' }
    @{ Id = 'SCZDEXT'; B = 'SCZEXT'; Name = 'Extractor';         Pre = 'ZHATCHERY';         What = 'Refinery for worker Drones; comes with one worker.' }
    @{ Id = 'SCZDPOL'; B = 'SCZPOL'; Name = 'Spawning Pool';     Pre = 'ZHATCHERY';         What = 'Trains Zerglings; unlocks Lair, Hydralisk Den, Sunken Colony.' }
    @{ Id = 'SCZDEVO'; B = 'SCZEVO'; Name = 'Evolution Chamber'; Pre = 'ZHATCHERY';         What = 'Unlocks the Spore Colony.' }
    @{ Id = 'SCZDHDN'; B = 'SCZHDN'; Name = 'Hydralisk Den';     Pre = 'SCZPOL';            What = 'Unlocks Hydralisks (and Lurkers with a Lair).' }
    @{ Id = 'SCZDSPI'; B = 'SCZSPI'; Name = 'Spire';             Pre = 'ZLAIRUP';           What = 'Unlocks Mutalisks and Scourges.' }
    @{ Id = 'SCZDGSP'; B = 'SCZGSP'; Name = 'Greater Spire';     Pre = 'SCZSPI,ZHIVEUP';    What = 'Unlocks Guardians and Devourers.' }
    @{ Id = 'SCZDNES'; B = 'SCZNES'; Name = 'Queen''s Nest';     Pre = 'ZLAIRUP';           What = 'Unlocks Queens, Broodlings, Infested Terrans and the Hive.' }
    @{ Id = 'SCZDULC'; B = 'SCZULC'; Name = 'Ultralisk Cavern';  Pre = 'ZHIVEUP';           What = 'Unlocks Ultralisks.' }
    @{ Id = 'SCZDDFM'; B = 'SCZDFM'; Name = 'Defiler Mound';     Pre = 'ZHIVEUP';           What = 'Unlocks Defilers.' }
    @{ Id = 'SCZDNYD'; B = 'SCZNYD'; Name = 'Nydus Canal';       Pre = 'ZHIVEUP';           What = 'Forward exit for Zerg infantry: trains them anywhere you put it.' }
    @{ Id = 'SCZDCRP'; B = 'SCZCRP'; Name = 'Creep Colony';      Pre = 'ZHATCHERY';         What = 'Wide sight; needed for Sunken and Spore Colonies.' }
    @{ Id = 'SCZDSUN'; B = 'SCZSUN'; Name = 'Sunken Colony';     Pre = 'SCZPOL,SCZCRP';     What = 'Ground defense.' }
    @{ Id = 'SCZDSPO'; B = 'SCZSPO'; Name = 'Spore Colony';      Pre = 'SCZEVO,SCZCRP';     What = 'Anti-air defense; reveals cloaked units.' }
    @{ Id = 'SCZDICC'; B = 'SCZICC'; Name = 'Infested Command Center'; Pre = 'SCZNES';      What = 'Hatches Infested Terrans (in SC a Queen infests a Terran CC).' }
)
foreach ($dr in $DroneFor) {
    $files["$($dr.Id).SHP"] = $droneBytes
    $c = [ScZerg]::DroneCameo($bodies[$dr.B], $drone, 12, $scPal, $ramp, $cameoPal)
    $files["$($dr.Id)I.SHP"] = $c.Write(); $cameoFrames.Add($c.Frames[0])
}

# ------------------------------------------------------------------ flyers: SHP vehicles with the Fly locomotor
# Layout: 0-31 stand (set 0), then Walk sets per facing (SC iscript "Walking" anim 11), then 2 fire frames, shadows = silhouettes.
$Flyers = @(
    @{ Id = 'SCZOVL'; Grp = 'overlord'; Walk = 0..3 }
    @{ Id = 'SCZMUT'; Grp = 'mutalid';  Walk = 0..4 }
    @{ Id = 'SCZSCG'; Grp = 'avenger';  Walk = 0..4 }
    @{ Id = 'SCZGRD'; Grp = 'guardian'; Walk = 0..6 }
    @{ Id = 'SCZDEV'; Grp = 'devour';   Walk = 0..5 }
    @{ Id = 'SCZQUN'; Grp = 'queen';    Walk = 0..4 }
)
$flyLayout = @{}
foreach ($fl in $Flyers) {
    $raw = G $fl.Grp; $fb = [ScZerg]::Bounds($raw); $g2 = [ScZerg]::Crop($raw, $fb[0], $fb[1])
    $shp = [ScBuild]::BuildUnit($g2, $g2, $map, [int[]]$fl.Walk, 0, 0)
    $files["$($fl.Id).SHP"] = $shp.Write()
    $nw = $fl.Walk.Count; $flyLayout[$fl.Id] = $nw
    $cm = [ScInfantry]::Cameo($g2.Frames[12], $g2.Width, $g2.Height, $scPal, $ramp, $cameoPal, [Drawing.Color]::FromArgb(150, 60, 140))
    $files["$($fl.Id)I.SHP"] = $cm.Write(); $cameoFrames.Add($cm.Frames[0])
    [Pal]::Sheet($shp.Frames, [int[]](0, 4, 8, 12, 16, 20, 24, 28, 32, 33), $shp.Width, $shp.Height, $unitPal, 2, 10, "$PreviewDir\$($fl.Id).png")
    "{0,-7} flyer {1} frames {2}x{3}" -f $fl.Id, $shp.Frames.Count, $shp.Width, $shp.Height
}
# ------------------------------------------------------------------ Lurker (user 2026-10-25): a vehicle that burrows by deploying
# into a cloaked 1x1 building (SCZLRB) that attacks; deploying the building unburrows it. SC iscript (Zlurker.grp): walk sets 0-6,
# burrow anim sets 11-24 (sound ZLuBurrw), burrowed = set 24. Shadow GRP zzluShad (same frame numbers).
$lrkRaw = G 'Zlurker'; $lb = [ScZerg]::Bounds($lrkRaw)
$lrk = [ScZerg]::Crop($lrkRaw, $lb[0], $lb[1]); $lrkS = [ScZerg]::Crop((G 'zzluShad'), $lb[0], $lb[1])
$lrkShp = [ScBuild]::BuildUnit($lrk, $lrkS, $map, [int[]](0..6), 0, 0)
$files['SCZLRV.SHP'] = $lrkShp.Write()
$lc = [ScInfantry]::Cameo($lrk.Frames[12], $lrk.Width, $lrk.Height, $scPal, $ramp, $cameoPal, [Drawing.Color]::FromArgb(150, 60, 140))
$files['SCZLRVI.SHP'] = $lc.Write(); $files['SCZLRBIC.SHP'] = $lc.Write(); $cameoFrames.Add($lc.Frames[0])
# upgraded Lurker SCZLRV2: same SHP, gold cameo (frame + chevrons like the research variants of build-sczergresearch.ps1)
$files['SCZLRV2.SHP'] = $files['SCZLRV.SHP']
$gc = [Shp]::Read($lc.Write()); $gf = $gc.Frames[0]
$gold = [Pal]::Nearest([Drawing.Color]::FromArgb(230, 180, 40), $cameoPal, 1, 255); $gold2 = [Pal]::Nearest([Drawing.Color]::FromArgb(255, 210, 60), $cameoPal, 1, 255)
for ($x = 0; $x -lt $gf.W; $x++) { foreach ($y in 0, 1, ($gf.H - 2), ($gf.H - 1)) { $gf.Pixels[$y * $gf.W + $x] = $gold } }
for ($y = 0; $y -lt $gf.H; $y++) { foreach ($x in 0, 1, ($gf.W - 2), ($gf.W - 1)) { $gf.Pixels[$y * $gf.W + $x] = $gold } }
foreach ($oy in 4, 9) { for ($k = 0; $k -le 5; $k++) { foreach ($t2 in 0, 1) { $py = $oy + $k + $t2; $gf.Pixels[$py * $gf.W + $gf.W - 14 + $k] = $gold2; $gf.Pixels[$py * $gf.W + $gf.W - 4 - $k] = $gold2 } } }
$files['SCZLRV2I.SHP'] = $gc.Write(); $cameoFrames.Add($gf)
$lshape = New-Object ScBuildingShape 1, 1, (G 'Zlurker').Width, (G 'Zlurker').Height, 0
$lbody = Layers (L 'Zlurker' (24 * 17)); $lshad = Layers (L 'zzluShad' (24 * 17) $true)
$files['SCZLRB.SHP'] = $lshape.Building($lbody, $lshad, $map, $dmgMap).Write()
$lst = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[ScLayer]]'; $lss = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[ScLayer]]'
foreach ($set in 11..24) { $lst.Add((Layers (L 'Zlurker' ($set * 17)))); $lss.Add((Layers (L 'zzluShad' ($set * 17) $true))) }
$lmk = $lshape.Buildup($lst, $lss, [int[]](@(1) * 14), $map)
$files['SCZLRBMK.SHP'] = $lmk.Write()
[Pal]::Sheet($lmk.Frames, [int[]](0, 4, 8, 13), $lshape.Cw, $lshape.Ch, $unitPal, 2, 4, "$PreviewDir\lurker_burrow.png")
"SCZLRV  vehicle {0} frames {1}x{2}; SCZLRB burrowed building, burrow {3} frames" -f $lrkShp.Frames.Count, $lrkShp.Width, $lrkShp.Height, ($lmk.Frames.Count / 2)

# impact animations (registered in Rules.ini [Animations]: anim images load with the theater, before map INIs):
# SCZTENT = Sunken Colony tentacle (bullet\Tentacle.grp 0-5-0, SC weapon image), SCZSPIKE = Lurker spines (bullet\Spike.grp)
foreach ($an in @(@('SCZTENT', 'bullet/tentacle', @(0, 1, 2, 3, 4, 5, 5, 4, 3, 2, 1, 0)), @('SCZSPIKE', 'bullet/Spike', @(0..6 + 6..0)))) {
    $ag = G $an[1]; $fr = New-Object 'System.Collections.Generic.List[Frame]'
    foreach ($k in $an[2]) { $fr.Add($ag.Frames[$k]) }
    $ashp = [ScBuild]::BuildAnim($fr, $ag.Width, $ag.Height, $map)
    $files["$($an[0]).SHP"] = $ashp.Write()
    [Pal]::Sheet($ashp.Frames, [int[]](0..($ashp.Frames.Count - 1)), $ashp.Width, $ashp.Height, $unitPal, 1, 12, "$PreviewDir\anim_$($an[0]).png")
}

# Guardian acid spore (user 2026-10-25: a real projectile, an acid ball): SC weapon 46 image thingy\ep3Shot (2 frames, flight loop
# f0-f1), hit image thingy\ep3Burst (12 frames, sound ZGuHit00). Recoloured acid green (ScZerg.AcidGreen), the ball zoomed 2x.
$gs = New-Object Shp; $gs.Width = 40; $gs.Height = 40
foreach ($k in 0, 1) { $gs.Frames.Add([ScZerg]::AcidGreen((G 'thingy/ep3Shot'), $k, 2, $scPal, $unitPal)) }
$files['SCZGACID.SHP'] = $gs.Write()
$gb = New-Object Shp; $gb.Width = 100; $gb.Height = 100
foreach ($k in 0..11) { $gb.Frames.Add([ScZerg]::AcidGreen((G 'thingy/ep3Burst'), $k, 1, $scPal, $unitPal)) }
$files['SCZGBURST.SHP'] = $gb.Write()
# invisible image of the Lurker spine projectile (only its trailer of spines is seen)
$np = New-Object Shp; $np.Width = 8; $np.Height = 8; $np.Frames.Add((New-Object Frame 0, 0, 8, 8))
$files['SCZSPINP.SHP'] = $np.Write()
[Pal]::Sheet($gs.Frames, [int[]](0, 1), 40, 40, $unitPal, 3, 2, "$PreviewDir\anim_SCZGACID.png")
[Pal]::Sheet($gb.Frames, [int[]](0..11), 100, 100, $unitPal, 1, 12, "$PreviewDir\anim_SCZGBURST.png")

[Pal]::Sheet($cameoFrames, [int[]](0..($cameoFrames.Count - 1)), 64, 48, $cameoPal, 2, 10, "$PreviewDir\cameos.png")

# ------------------------------------------------------------------ sounds (SD WAV -> AUD); attack sounds from SC's iscript
$sounds = [ordered]@{
    SCZBPLC = 'misc/zbldgplc'; SCZBDTH = 'zerg/bldg/zbldgdth'; SCZSUNAT = 'bullet/zlufir00'; SCZDRMIN = 'zerg/drone/zdrmin00'
    SCZOVWH0 = 'zerg/overlord/zovwht00'; SCZOVWH1 = 'zerg/overlord/zovwht01'; SCZOVYE0 = 'zerg/overlord/zovyes00'; SCZOVYE1 = 'zerg/overlord/zovyes01'; SCZOVDTH = 'zerg/overlord/zovdth00'
    SCZMUWH0 = 'zerg/mutalid/zmuwht00'; SCZMUWH1 = 'zerg/mutalid/zmuwht01'; SCZMUYE0 = 'zerg/mutalid/zmuyes00'; SCZMUYE1 = 'zerg/mutalid/zmuyes01'; SCZMUDTH = 'zerg/mutalid/zmudth00'; SCZMUFIR = 'bullet/zmufir00'
    SCZSCWH0 = 'zerg/avenger/zavwht00'; SCZSCWH1 = 'zerg/avenger/zavwht01'; SCZSCYE0 = 'zerg/avenger/zavyes00'; SCZSCYE1 = 'zerg/avenger/zavyes01'; SCZSCDTH = 'zerg/avenger/zavdth00'; SCZSCHIT = 'zerg/avenger/zavhit00'
    SCZGUWH0 = 'zerg/guardian/zguwht00'; SCZGUWH1 = 'zerg/guardian/zguwht01'; SCZGUYE0 = 'zerg/guardian/zguyes00'; SCZGUYE1 = 'zerg/guardian/zguyes01'; SCZGUDTH = 'zerg/guardian/zgudth00'; SCZGUFIR = 'bullet/zgufir00'
    SCZDVWH0 = 'zerg/devourer/ZDvWht00'; SCZDVWH1 = 'zerg/devourer/ZDvWht01'; SCZDVYE0 = 'zerg/devourer/ZDvYes00'; SCZDVYE1 = 'zerg/devourer/ZDvYes01'; SCZDVDTH = 'zerg/devourer/ZDvDth00'; SCZDVFIR = 'zerg/devourer/firesuck'
    SCZQUWH0 = 'zerg/queen/zquwht00'; SCZQUWH1 = 'zerg/queen/zquwht01'; SCZQUYE0 = 'zerg/queen/zquyes00'; SCZQUYE1 = 'zerg/queen/zquyes01'; SCZQUDTH = 'zerg/queen/zqudth00'; SCZQUFIR = 'bullet/zqufir00'
    # Sunken tentacle hit (weapon image Tentacle.grp), Lurker spines fire/hit (weapon image zmarker.grp), Lurker burrow
    SCZSUNHT = 'bullet/zluhit00'; SCZLRKFR = 'bullet/ZLrkFir1'; SCZLRKHT = 'bullet/ZLrkHit1'; SCZLRBUR = 'zerg/lurker/ZLUBURRW'
    SCZGUHIT = 'bullet/zguhit00'   # Guardian acid spore hit (weapon image iscript, death anim)
}
foreach ($k in $sounds.Keys) {
    $rate = 0
    $pcm = [Aud]::ReadWav($casc.ReadFile("SD/sound/$($sounds[$k]).wav"), [ref]$rate)
    $files["$k.AUD"] = [Aud]::Encode($pcm, $rate, 1.0)
}

$out = if ($OutMix) { $OutMix } else { "$game\MIX\ECACHE86.MIX" }
# buildups longer than ~81 frames NEVER finish without the rate patch: refuse to install them into an unpatched game
function Test-BuildupPatch { $gx = [IO.File]::ReadAllBytes("$game\game.exe"); $o = 0x440420 - 0x400000
    return ($gx[$o] -eq 0xE8 -and [BitConverter]::ToInt32($gx, $o + 1) -eq (0x6C9FC0 - 0x440425)) }   # call into the cave of patch-buildup.ps1
if (-not $OutMix -and -not (Test-BuildupPatch)) {
    # patch-flyhover.ps1 -FromBackup restores the original game.exe and wipes this patch (happened twice on 2026-10-25): re-apply it
    "game.exe has no buildup patch, applying tools\patch-buildup.ps1"
    powershell -NoProfile -ExecutionPolicy Bypass -File "$tools\patch-buildup.ps1"
    if (-not (Test-BuildupPatch)) { throw "game.exe has no buildup patch and patch-buildup.ps1 failed (game running?): the Zerg morphs would never finish" }
}
[Mix]::Write($out, $files)
$check = New-Object Mix $out
foreach ($k in $files.Keys) { if ($k.EndsWith('.SHP') -and ([Shp]::Read($check.Read($k))).Frames.Count -eq 0) { throw "bad $k" } }
"ECACHE86.MIX: $($files.Count) files, $([Math]::Round((Get-Item $out).Length / 1KB)) KB, round-trip OK; previews -> $PreviewDir"
if (-not $Install) { return }

# ------------------------------------------------------------------ INI side
$latin = [Text.Encoding]::GetEncoding(28591)
$begin = '; >>> Zerg faction'; $end = '; <<< Zerg faction'

function Set-Block([string]$path, [string]$body, [string]$nl) {
    $t = [IO.File]::ReadAllText($path, $latin)
    $block = ($begin + $nl + ($body.TrimEnd() -replace "`r?`n", $nl) + $nl + $end + $nl)
    $a = $t.IndexOf($begin)
    if ($a -ge 0) { $z = $t.IndexOf($end, $a); $z = $t.IndexOf("`n", $z) + 1; $t = $t.Substring(0, $a) + $block + $t.Substring($z) }
    else { if (-not $t.EndsWith("`n")) { $t += $nl }; $t += $nl + $block }
    [IO.File]::WriteAllText($path, $t, $latin)
}

# entries inside an existing section, after its last key line; old entries matching $own are removed first
function Set-SectionEntries([string]$path, [string]$section, [string[]]$entries, [string]$own, [string]$nl) {
    $t = [IO.File]::ReadAllText($path, $latin)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.AddRange([string[]]($t -split "`n"))
    $s0 = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimEnd("`r") -eq "[$section]") { $s0 = $i; break } }
    if ($s0 -lt 0) { throw "[$section] not found in $path" }
    $e = $lines.Count; for ($j = $s0 + 1; $j -lt $lines.Count; $j++) { if ($lines[$j].StartsWith('[')) { $e = $j; break } }
    for ($i = $e - 1; $i -gt $s0; $i--) { if ($lines[$i] -match $own) { $lines.RemoveAt($i); $e-- } }
    $last = $s0; for ($j = $s0 + 1; $j -lt $e; $j++) { $x = $lines[$j].Trim(); if ($x -and -not $x.StartsWith(';')) { $last = $j } }
    $cr = if ($nl -eq "`r`n") { "`r" } else { '' }
    $lines.InsertRange($last + 1, [string[]]($entries | ForEach-Object { $_ + $cr }))
    [IO.File]::WriteAllText($path, ($lines -join "`n"), $latin)
}
function Backup([string]$path) { if (-not (Test-Path "$path.bak")) { Copy-Item $path "$path.bak" } }
function Nl([string]$path) { if ([IO.File]::ReadAllText($path, $latin).Contains("`r`n")) { "`r`n" } else { "`n" } }

# ---- faction map code (appended to skirmish maps by MPMaps.ini MapCodeININame): our layer "Zerg faction" of the BasedOn
# chain (MapCode.ps1). The bottom layer "Terran faction" keeps the keys the factions share ([General] BaseUnit/HarvesterUnit).
. "$tools\MapCode.ps1"
$fac = Get-MapCodeLayer 'Zerg faction'; $facBase = Get-MapCodeLayer 'Terran faction'
Backup $fac; Backup $facBase; $nl = Nl $fac
$protoss = (Read-MapCodeText).Contains('; >>> Protoss faction')
$t = [IO.File]::ReadAllText($facBase, $latin)
$t = [regex]::Replace($t, '(?m)^BaseUnit=SCMCVT,(SCZDH(AT|TS),)?', 'BaseUnit=SCMCVT,SCZDHTS,')
[IO.File]::WriteAllText($facBase, $t, $latin)
Set-SectionEntries $facBase 'General' @("HarvesterUnit=TDHARV,RAHARV,SCZWORK$(if ($protoss) { ',SCPPROBE' })	; Zerg faction") '^HarvesterUnit=' $nl
# [Sides], [VehicleTypes], [InfantryTypes] entries are in our block: the layers merge in chain order, so ZergSide stays side 7
# (after TerranSide of the bottom layer, before ProtossSide of the Protoss layer)
$vt = @('ZRG01=SCZWORK', 'ZRG02=SCZDHTS') + ($DroneFor | ForEach-Object -Begin { $n = 3 } -Process { 'ZRG{0:D2}={1}' -f $n, $_.Id; $n++ })
$vt += @('ZRG40=SCZINF') + ($Flyers | ForEach-Object -Begin { $n = 41 } -Process { 'ZRG{0:D2}={1}' -f $n, $_.Id; $n++ })
$vt += @('ZRG50=SCZLRV', 'ZRG51=SCZLRV2')
# Zerg infantry: own copies (SC prerequisites, independent of the STARCRAFT checkbox)
$Inf = @('SCZLNG', 'SCZHYL', 'SCZULT', 'SCZDFL', 'SCZBRD')   # the Lurker is a vehicle + burrowed building (SCZLRV/SCZLRB)
$it = @($Inf | ForEach-Object -Begin { $n = 1 } -Process { 'ZRI{0:D2}={1}' -f $n, $_; $n++ })

$Hatcheries = 'SCZHAT,SCZHTS,SCZLAI,SCZHIV'
$unitKeys = @"
Owner=Nod1
Crusher=no
Crewed=no
SelfHealing=yes
Naval=yes	; built at a Hatchery/Lair/Hive only (Vinifera naval-yard exit: appears next to it), see [SCZHAT]
BuiltAt=$Hatcheries
Trainable=yes
VeteranAbilities=STRONGER,FASTER
EliteAbilities=SELF_HEAL,ROF
AllowedToStartInMultiplayer=no
CanShakeScreen=false
Totable=false
VoiceFeedback=
"@
$groundKeys = @"
SpeedType=Track
Locomotor={4A582741-9839-11d1-B709-00A024DDAFD1}
MovementZone=Normal
SlowdownDistance=1
AccelerationFactor=1
Weight=1
"@
$flyKeys = @"
Category=AFV
Locomotor={4A582746-9839-11d1-B709-00A024DDAFD1}
MovementZone=Fly
FlightLevel=450
"@
$droneKeys = @"
Category=Support
Strength=800
Armor=light
Sight=6
Speed=8
ROT=12
Explosion=FBALL1
ScrapExplosion=FBALL1
MaxDebris=0
DieSound=SCDNDTH0
VoiceSelect=SCDNWHT0,SCDNWHT1,SCDNWHT2,SCDNWHT3,SCDNWHT4
VoiceMove=SCDNYES0,SCDNYES1,SCDNYES2,SCDNYES3,SCDNYES4
VoiceAttack=SCDNYES0,SCDNYES1,SCDNYES2,SCDNYES3,SCDNYES4
ThreatPosed=0
$($unitKeys -replace '(?m)^Trainable=yes', 'Trainable=no')
$groundKeys
"@
$bldgKeys = @"
TechLevel=-1	; never in a sidebar: only a Drone's deploy creates it (like DBFRT)
Owner=Nod1
Capturable=false
Crewed=no
Unsellable=yes	; like SC; selling would also replay the whole morph backwards
Explosion=FBALL1,FBALL2,FBALL3
ScrapExplosion=FBALL1,FBALL2,FBALL3
MaxDebris=0
DeploySound=SCZBPLC
DieSound=SCZBDTH
AIBuildThis=no
SelfHealing=yes	; Zerg buildings regenerate like in SC (to full: see Add-ZergRegen)
Repairable=no	; and cannot be repaired (user 2026-10-25)
"@
$hatchKeys = @"
Factory=UnitType
WeaponsFactory=yes
Naval=yes
ExclusiveFactory=yes	; only units with BuiltAt= listing it
Radar=yes
Storage=40
PipScale=Tiberium
Power=50
"@
# Id = Name, Cost ((minerals + 2 x gas) x 4), HP (SC x 8), Armor, extra keys
$BldgIni = [ordered]@{
    SCZHAT = @('Hatchery', 1200, 10000, 'wood', "Description=Zerg hive. Larvae hatch here: Drones, flyers, Infested Terrans.@@Every building is a Drone: build ""Drone: <building>"", move it, DEPLOY.@@Radar, small silo.`n$hatchKeys`nSight=9")
    SCZHTS = @('Hatchery', 1200, 10000, 'wood', "Description=Zerg hive. Larvae hatch here: Drones, flyers, Infested Terrans.@@Every building is a Drone: build ""Drone: <building>"", move it, DEPLOY.@@Radar, small silo.`n$hatchKeys`nSight=9")
    SCZLAI = @('Lair', 1400, 14400, 'wood', "Description=Second-tier hive cluster: larvae like a Hatchery.@@Unlocks Spire, Queen's Nest, Lurkers and the Hive.`n$hatchKeys`nSight=10")
    SCZHIV = @('Hive', 2000, 20000, 'wood', "Description=Third-tier hive cluster: larvae like a Hatchery.@@Unlocks Ultralisk Cavern, Defiler Mound, Greater Spire and Nydus Canal.`n$hatchKeys`nSight=11")
    SCZEXT = @('Extractor', 200, 6000, 'wood', "Description=Zerg refinery: worker Drones bring Tiberium, Ore and Gems here.@@Comes with a worker Drone.`nRefinery=yes`nBib=yes	; every DTA refinery has it: the harvester docks on the bib row`nFreeUnit=SCZWORK`nDockUnload=yes`nStorage=40`nPipScale=Tiberium`nSight=5")
    SCZPOL = @('Spawning Pool', 800, 6000, 'wood', "Description=Zerg breeding pool. Trains Zerg infantry: Zerglings, and with the other buildings Hydralisks, Lurkers, Ultralisks, Defilers, Broodlings.`nFactory=InfantryType`nExitCoord=0,0,0`nGDIBarracks=yes`nSight=5")
    SCZEVO = @('Evolution Chamber', 300, 6000, 'wood', "Description=Zerg evolution chamber.@@Unlocks the Spore Colony.`nSight=5")
    SCZHDN = @('Hydralisk Den', 800, 6800, 'wood', "Description=Zerg den.@@Unlocks Hydralisks, and Lurkers with a Lair.`nSight=5")
    SCZSPI = @('Spire', 2000, 4800, 'wood', "Description=Zerg spire.@@Unlocks Mutalisks and Scourges.`nSight=7")
    SCZGSP = @('Greater Spire', 1600, 8000, 'wood', "Description=Zerg greater spire.@@Unlocks Guardians and Devourers.`nSight=7")
    SCZNES = @('Queen''s Nest', 1400, 6800, 'wood', "Description=Zerg nest.@@Unlocks Queens, Broodlings, Infested Terrans and the Hive.`nSight=5")
    SCZULC = @('Ultralisk Cavern', 2200, 4800, 'wood', "Description=Zerg cavern.@@Unlocks Ultralisks.`nSight=5")
    SCZDFM = @('Defiler Mound', 1200, 6800, 'wood', "Description=Zerg mound.@@Unlocks Defilers.`nSight=5")
    SCZNYD = @('Nydus Canal', 600, 2000, 'wood', "Description=Zerg tunnel.@@Second exit for Zerg infantry: set it as primary and trained infantry comes out here.`nFactory=InfantryType`nExitCoord=0,0,0`nGDIBarracks=yes`nSight=6")
    SCZCRP = @('Creep Colony', 300, 3200, 'wood', "Description=Zerg colony.@@Wide sight. Needed for Sunken and Spore Colonies.`nSight=10")
    SCZSUN = @('Sunken Colony', 500, 3000, 'heavy', "Description=Zerg ground defense.@@A tentacle bursts out under ground targets far away; strong against armor.`nPrimary=SCZSunkenSpine`nSight=12`nGuardRange=8`nBaseNormal=yes`nIsBaseDefense=yes`nSortCameoAsBaseDefense=yes`nHasStupidGuardMode=false`nThreatPosed=30")
    SCZSPO = @('Spore Colony', 500, 3200, 'heavy', "Description=Zerg anti-air defense.@@Seeker spores hit aircraft and flyers only. Reveals cloaked units nearby.`nPrimary=SCZFSporeAA`nSight=9`nGuardRange=9`nSensors=yes`nSensorsSight=8`nBaseNormal=yes`nIsBaseDefense=yes`nSortCameoAsBaseDefense=yes`nHasStupidGuardMode=false`nThreatPosed=30")
    SCZICC = @('Infested Command Center', 1600, 12000, 'wood', "Description=Terran headquarters taken over by the Zerg.@@Hatches Infested Terrans (its only product).`nFactory=UnitType`nWeaponsFactory=yes`nNaval=yes`nExclusiveFactory=yes	; only the Infested Terran (BuiltAt=SCZICC)`nSight=8")
}
$bldgText = ''
foreach ($id in $BldgIni.Keys) {
    $v = $BldgIni[$id]
    $bldgText += "[$id]`nName=$($v[0])`n$($v[4])`nStrength=$($v[2])`nArmor=$($v[3])`nCost=$($v[1])`nPoints=$([int]($v[1] / 20))`n"
    if ($v[4] -notmatch 'Power=') { $bldgText += "Power=0`n" }
    if ($v[4] -notmatch 'ThreatPosed=') { $bldgText += "ThreatPosed=0`n" }
    $bldgText += "$bldgKeys`n"
}
$droneText = ''
foreach ($dr in $DroneFor) {
    $bc = $BldgIni[$dr.B][1]
    $droneText += @"
[$($dr.Id)]
Name=Drone: $($dr.Name)
Description=Morphs into: $($dr.Name). Move it there and DEPLOY; it grows from a cocoon as long as in StarCraft.@@$($dr.What)
Prerequisite=$($dr.Pre)
DeploysInto=$($dr.B)
TechLevel=1
Cost=$(200 + $bc)
BuildTimeMultiplier=0.03	; Vinifera: built in the engine minimum (54 ticks); the time is in the building's morph instead
Points=5
$droneKeys

"@
}

# infantry: same art/sounds as the STARCRAFT-checkbox Zerg units (Image=), own sections and weapons
$infKeys = @"
Category=Soldier
Locomotor={4A582744-9839-11d1-B709-00A024DDAFD1}
MovementZone=Infantry
Owner=Nod1
Fearless=yes
NotHuman=yes
Crushable=no
SelfHealing=yes
Crewed=no
Trainable=yes
PhysicalSize=1
AllowedToStartInMultiplayer=no
IsWebImmune=true
ImmuneToVeins=yes
VeteranAbilities=STRONGER,FASTER
EliteAbilities=SELF_HEAL,ROF
VoiceFeedback=
"@
function InfSec($id, $img, $name, $desc, $pre, $weap, $hp, $armor, $tl, $sight, $speed, $cost, $threat, $v) {
    return "[$id]`nName=$name`nImage=$img`nDescription=$desc`nPrerequisite=$pre`nPrimary=$weap`nStrength=$hp`nArmor=$armor`nTechLevel=$tl`nSight=$sight`nSpeed=$speed`nCost=$cost`nPoints=$([int]($cost / 50) + 1)`nThreatPosed=$threat`nVoiceSelect=$($v)WHT0,$($v)WHT1,$($v)WHT2,$($v)WHT3`nVoiceMove=$($v)YES0,$($v)YES1,$($v)YES2,$($v)YES3`nVoiceAttack=$($v)YES0,$($v)YES1,$($v)YES2,$($v)YES3`nVoiceDie=$($v)DTH0`n$infKeys`n"
}
$infText  = InfSec 'SCZLNG' 'SCZLING' 'Zergling' 'Zerg swarm beast.@@Very fast and cheap; claws hurt everything.@@Regenerates.' 'SCZPOL' 'SCZFClaw' 700 'none' 1 5 12 100 5 'SCZL'
$infText += InfSec 'SCZHYL' 'SCHYDRA' 'Hydralisk' 'Zerg ranged attacker.@@Needle spines hit ground and air.@@Regenerates.' 'SCZPOL,SCZHDN' 'SCZFSpine' 1600 'none' 2 8 6 500 15 'SCHY'   # Speed 6: user 2026-10-25, 30% slower (was 8)
$infText  = $infText -replace 'VoiceSelect=SCHYWHT0,SCHYWHT1,SCHYWHT2,SCHYWHT3', 'VoiceSelect=SCHYWHT0,SCHYWHT1,SCHYWHT2'
$infText += InfSec 'SCZULT' 'SCULTRA' 'Ultralisk' 'Huge Zerg assault beast.@@Kaiser blades cleave everything in melee. Heavily armored.@@Regenerates.' 'SCZULC' 'SCZFKaiser' 10000 'heavy' 6 6 10 2400 40 'SCUL'
$infText += InfSec 'SCZDFL' 'SCDEFIL' 'Defiler' 'Zerg spellcaster.@@Spits Plague: acid that hurts everything in an area.@@Regenerates.' 'SCZDFM' 'SCZFPlague' 1600 'none' 6 8 7 1400 20 'SCDF'
$infText += InfSec 'SCZBRD' 'SCBROOD' 'Broodling' 'Tiny Zerg swarm creature.@@Very fast melee biter.@@Regenerates.' 'SCZNES' 'SCZFBite' 600 'none' 3 5 12 75 3 'SCBL'

function UnitVoices($v, $cnt) { $sel = (0..($cnt - 1) | % { "$($v)WH$_" }) -join ','; $yes = (0..($cnt - 1) | % { "$($v)YE$_" }) -join ','; return "VoiceSelect=$sel`nVoiceMove=$yes`nVoiceAttack=$yes`nDieSound=$($v)DTH" }
function FlySec($id, $name, $desc, $pre, $weap, $hp, $armor, $tl, $sight, $speed, $rot, $cost, $threat, $v, $extra) {
    return "[$id]`nName=$name`nDescription=$desc`nPrerequisite=$pre`n$(if ($weap) { "Primary=$weap`n" })Strength=$hp`nArmor=$armor`nTechLevel=$tl`nSight=$sight`nSpeed=$speed`nROT=$rot`nCost=$cost`nPoints=$([int]($cost / 50) + 1)`nThreatPosed=$threat`nExplosion=FBALL1`nScrapExplosion=FBALL1`nMaxDebris=0`n$(UnitVoices $v 2)`n$flyKeys`n$unitKeys`n$extra`n"
}
$flyText  = FlySec 'SCZOVL' 'Overlord' 'Zerg flying overseer.@@Slow, unarmed; sees far and reveals cloaked units.@@Regenerates.' 'ZHATCHERY' '' 4000 'heavy' 1 11 4 6 400 0 'SCZOV' "Sensors=yes`nSensorsSight=9"
$flyText += FlySec 'SCZMUT' 'Mutalisk' 'Zerg flyer.@@Glave wurms hit ground and air targets.@@Regenerates.' 'ZSPIREUP' 'SCZFGlave' 2400 'light' 4 8 16 24 1200 25 'SCZMU' ''
$flyText += FlySec 'SCZSCG' 'Scourge' 'Zerg suicide flyer.@@Dives into aircraft and flyers and explodes. Air targets only.@@Regenerates.' 'ZSPIREUP' 'SCZFScourge' 500 'light' 4 6 18 28 350 20 'SCZSC' ''
$flyText += FlySec 'SCZGRD' 'Guardian' 'Zerg flying siege beast.@@Long-range acid spores against ground targets only.@@Regenerates.' 'SCZGSP' 'SCZFAcidSpore' 3000 'heavy' 6 11 8 12 2200 35 'SCZGU' ''
$flyText += FlySec 'SCZDEV' 'Devourer' 'Zerg anti-air flyer.@@Corrosive acid against aircraft and flyers only.@@Regenerates.' 'SCZGSP' 'SCZFCorrosive' 5000 'heavy' 6 10 10 12 2200 35 'SCZDV' ''
$flyText += FlySec 'SCZQUN' 'Queen' 'Zerg flying caster.@@Spits broodling acid at ground targets.@@Regenerates.' 'SCZNES' 'SCZFBroodSpit' 2400 'medium' 5 10 14 20 1200 20 'SCZQU' ''

# Zerg regeneration to FULL health (user 2026-10-25). Vinifera self-heal heals while health < SelfHealingCap (default
# ConditionYellow = 50%), SelfHealingStep HP (default 1) every SelfHealingRate (default RepairRate .016 min = ~0.24 s at
# 60 FPS). Same keys as Add-ShieldRegen of build-scprotoss.ps1: units 0.4% of Strength per step (~60 s from zero),
# buildings 0.2% (~2 min). Sections that already set SelfHealingCap keep their own values.
function Add-ZergRegen([string]$text) {
    $parts = [regex]::Split($text, '(?m)(?=^\[)')
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $p = $parts[$i]
        if ($p -notmatch '(?m)^SelfHealing=yes' -or $p -match '(?m)^SelfHealingCap=' -or $p -notmatch '(?m)^Strength=(\d+)') { continue }
        $hp = [int]$Matches[1]
        $isBuilding = $p -match '(?m)^(Unsellable|Foundation|Factory|Power|BaseNormal)='
        $step = [Math]::Max(1, [int][Math]::Round($hp * $(if ($isBuilding) { 0.002 } else { 0.004 })))
        $parts[$i] = $p.TrimEnd() + "`nSelfHealingCap=1.0`t; Zerg regeneration: back to full health (Vinifera)`nSelfHealingStep=$step`n`n"
    }
    return ($parts -join '')
}

Set-Block $fac (Add-ZergRegen @"
; =====================================================================================================================
; Zerg faction (map session, 2026-10-25; user: "zrob cala frakcje, kazde budynki i jednostki zergow", tested on a NEW faction).
; Helper house Nod1 (house 7, missions only) becomes the playable "Zerg" in skirmish; side ZergSide = side 7 ->
; SIDEC08.MIX / SIDENC08.MIX / SPEECH08.MIX (copies of Nod). Lobby: Resources/GameOptions.ini Sides=...,Zerg (index 7).
; NO construction yard. Hatchery/Lair/Hive are unit factories ("larvae"): units appear next to them (Vinifera naval-yard exit,
; Naval=yes + BuiltAt=, the Starport pattern). Every building is a Drone vehicle with DeploysInto=<building>: move the Drone,
; deploy, the Drone is consumed and the building grows from the SC cocoon for its SC build time (patched game.exe, see
; Modding/wiki/engine/buildup-timing.md). Spawning Pool / Nydus Canal train the infantry. Groups below: ZHATCHERY = any
; hatchery, ZLAIRUP = Lair or Hive, ZHIVEUP = Hive, ZSPIREUP = Spire or Greater Spire. Graphics/sounds: MIX/ECACHE86.MIX
; (Modding/tools/build-sczergbase.ps1) + the Zerg infantry graphics of MIX/ECACHE80.MIX (Image=), art: Art.ini block
; "Zerg faction", sounds: Sound.ini [SoundList] 1300+. Scale like the other SC blocks: building HP = SC HP x 8, unit HP = SC x 20,
; cost = (minerals + 2 x gas) x 4. Wiki: Modding/wiki/mods/zerg-faction.md
; =====================================================================================================================

[Sides]
ZergSide=Nod1	; side index 7: layers merge in chain order (TerranSide 6 below, ProtossSide 8 above)

[ZergSide]
UIColor=White
OptionsMenuTextColor=200,110,255
ScreenTextColor=200,110,255
ToolTipColor=RAGold
HoverHighlightColor=RAGold
RegularPowerPlant=SCZHAT
AdvancedPowerPlant=SCZHAT

[Nod1]
Name=Zerg
Suffix=ZRG
Prefix=N
ActsLike=7
Multiplay=yes
Side=ZergSide

[PrerequisiteGroups]
ZHATCHERY=$Hatcheries
ZLAIRUP=SCZLAI,SCZHIV
ZHIVEUP=SCZHIV
ZSPIREUP=SCZSPI,SCZGSP

[BuildingTypes]
$(($BldgIni.Keys | ForEach-Object -Begin { $n = 1 } -Process { 'ZRB{0:D2}={1}' -f $n, $_; $n++ }) -join "`n")
ZRB30=SCZLRB
ZRB31=SCZLRB2

[InfantryTypes]
$($it -join "`n")

[VehicleTypes]
$($vt -join "`n")

; ---------------------------------------------------------------- buildings (created only by a Drone's deploy)

$bldgText
; ---------------------------------------------------------------- Drones (SHP vehicles, built in the Hatchery)

[SCZWORK]
Name=Drone
Description=Zerg worker. Gathers Tiberium, Ore and Gems for the Extractor.@@For buildings, build the "Drone: <building>" types instead.@@Regenerates.
Prerequisite=ZHATCHERY
Harvester=yes
Dock=SCZEXT
Storage=10
PipScale=Tiberium
ToProtect=yes
TechLevel=1
Cost=400
Points=10
VoiceHarvest=SCZDRMIN
$($droneKeys -replace '(?m)^AllowedToStartInMultiplayer=no', 'AllowedToStartInMultiplayer=yes	; the starting units for Zerg are worker Drones' -replace '(?m)^Trainable=no', 'Trainable=yes')

; start unit (BaseUnit): grows the start Hatchery SCZHTS quickly (in SC you begin with a Hatchery)
[SCZDHTS]
Name=Drone: Hatchery
Image=SCZDHAT
Description=Zerg Drone. DEPLOY it to grow your first Hatchery.
Prerequisite=none
DeploysInto=SCZHTS
TechLevel=-1
Cost=1400
Points=5
$droneKeys

$droneText
; ---------------------------------------------------------------- infantry (Spawning Pool, Nydus Canal)

$infText
; ---------------------------------------------------------------- Infested Terran (vehicle: Suicide=yes crashes infantry)

[SCZINF]
Name=Infested Terran
Image=SCINFT
Description=Zerg suicide bomber.@@Runs into the target and explodes, hurting everything around it.@@Regenerates.
Prerequisite=SCZICC
Primary=SCZFInfest
Strength=1200
Armor=none
Category=AFV
TechLevel=4
Sight=6
Speed=7
ROT=10
Cost=800
Points=10
Explosion=FBALL1
ScrapExplosion=FBALL1
MaxDebris=0
ThreatPosed=20
VoiceSelect=SCITWHT0,SCITWHT1,SCITWHT2,SCITWHT3
VoiceMove=SCITYES0,SCITYES1,SCITYES2,SCITYES3
VoiceAttack=SCITYES0,SCITYES1,SCITYES2,SCITYES3
$($unitKeys -replace '(?m)^BuiltAt=.*$', 'BuiltAt=SCZICC	; hatched by the Infested Command Center only, like in SC')
$groundKeys

; ---------------------------------------------------------------- Lurker: vehicle (moves, no weapon, like SC) <-> burrowed building
; DEPLOY burrows (DeploysInto, burrow anim = Buildup), DEPLOY on the building unburrows (UndeploysInto; like the Siege Tank, no
; lobby option needed: user test 2026-10-25). Burrowed: Cloakable=yes (hidden unless a detector with Sensors= is near), attacks with
; Range 20.4, Sight 21: it sees what it can hit (Vinifera's From_Sight hook removed the old clamp of 10).
; subterranean spines: a sonic wave (IsSonic, the Disruptor mechanic) that hurts everything along the line, spines at the target.

[SCZLRV]
Name=Lurker
Description=Zerg spine artillery. Cannot attack while moving.@@DEPLOY to burrow: invisible to enemies without detectors, spines hit everything in a line, range like a sieged tank.
Prerequisite=SCZHDN,ZLAIRUP
DeploysInto=SCZLRB
Strength=2500
Armor=medium
Category=AFV
TechLevel=5
Sight=8
Speed=8
ROT=12
Cost=1500
Points=31
ThreatPosed=0
Explosion=FBALL1
ScrapExplosion=FBALL1
MaxDebris=0
VoiceSelect=SCLKWHT0,SCLKWHT1,SCLKWHT2,SCLKWHT3
VoiceMove=SCLKYES0,SCLKYES1,SCLKYES2,SCLKYES3
VoiceAttack=SCLKYES0,SCLKYES1,SCLKYES2,SCLKYES3
DieSound=SCLKDTH0
$($unitKeys -replace '(?m)^BuiltAt=.*$', 'BuiltAt=SCZLAI,SCZHIV	; hatched at a Lair or Hive, like in SC (Lurker needs Lair tech)')
$groundKeys

[SCZLRB]
Name=Lurker (burrowed)
Description=Burrowed Lurker: invisible to enemies without detectors. Spines hit everything in a line.@@DEPLOY to unburrow.
Primary=SCZFLurkSpine
UndeploysInto=SCZLRV
Strength=2500
Armor=medium
TechLevel=-1
Owner=Nod1
Cloakable=yes
Sight=21	; user 2026-10-25: sees as far as it shoots (Vinifera removed the Sight 10 clamp of MapClass::Sight_From)
GuardRange=20.4
Cost=1500
Points=31
Power=0
BaseNormal=no
Capturable=false
Crewed=no
Unsellable=yes
HasStupidGuardMode=false
ThreatPosed=25
Explosion=FBALL1
ScrapExplosion=FBALL1
MaxDebris=0
DeploySound=SCZLRBUR
DieSound=SCLKDTH0
AIBuildThis=no
SelfHealing=yes	; regenerates like every Zerg (to full: Add-ZergRegen)
Repairable=no

; Upgraded Lurker (user 2026-10-25: "ulepszony lurker jako czolg", +33% HP and damage), unlocked by the Missile Attacks research
; SCYMIS of the Zerg research block (Modding/wiki/mods/zerg-research.md). Same burrow mechanic, own pair of types; gold cameo.
[SCZLRV2]
Name=Lurker (Upgraded)
Description=Upgraded Zerg spine artillery: +33% HP and damage. Cannot attack while moving.@@DEPLOY to burrow: invisible without detectors, spines hit everything in a line.
Prerequisite=SCZHDN,ZLAIRUP,SCYMIS
DeploysInto=SCZLRB2
Strength=3325
Armor=medium
Category=AFV
TechLevel=5
Sight=8
Speed=8
ROT=12
Cost=1500
Points=31
ThreatPosed=0
Explosion=FBALL1
ScrapExplosion=FBALL1
MaxDebris=0
VoiceSelect=SCLKWHT0,SCLKWHT1,SCLKWHT2,SCLKWHT3
VoiceMove=SCLKYES0,SCLKYES1,SCLKYES2,SCLKYES3
VoiceAttack=SCLKYES0,SCLKYES1,SCLKYES2,SCLKYES3
DieSound=SCLKDTH0
$($unitKeys -replace '(?m)^BuiltAt=.*$', 'BuiltAt=SCZLAI,SCZHIV	; hatched at a Lair or Hive, like in SC')
$groundKeys

[SCZLRB2]
Name=Lurker (Upgraded, burrowed)
Image=SCZLRB
Description=Burrowed upgraded Lurker (+33% HP and damage): invisible without detectors. Spines hit everything in a line.@@DEPLOY to unburrow.
Primary=SCZFLurkSpineU
UndeploysInto=SCZLRV2
Strength=3325
Armor=medium
TechLevel=-1
Owner=Nod1
Cloakable=yes
Sight=21	; user 2026-10-25: sees as far as it shoots (Vinifera removed the Sight 10 clamp of MapClass::Sight_From)
GuardRange=20.4
Cost=1500
Points=31
Power=0
BaseNormal=no
Capturable=false
Crewed=no
Unsellable=yes
HasStupidGuardMode=false
ThreatPosed=33
Explosion=FBALL1
ScrapExplosion=FBALL1
MaxDebris=0
DeploySound=SCZLRBUR
DieSound=SCLKDTH0
AIBuildThis=no
SelfHealing=yes	; regenerates like every Zerg (to full: Add-ZergRegen)
Repairable=no

; ---------------------------------------------------------------- flyers (SHP vehicles, Fly locomotor; game.exe patch-flyhover.ps1)

$flyText
; ---------------------------------------------------------------- weapons. Damage x Modifier; SC damage x 2.5, cooldown x 1.33.
; Warheads: SC "normal" hurts every armor about the same, "explosive" is better against armor than against infantry.

[SCZFNormalWH]
CellSpread=0
Modifier.none=1000%
Modifier.wood=600%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
InfDeath=1
AnimList=PIFF
ProneDamage=100%

[SCZFExplWH]
CellSpread=0
Modifier.none=600%
Modifier.wood=700%
Modifier.medium=900%
Modifier.heavy=1000%
Modifier.concrete=500%
InfDeath=1
AnimList=PIFFPIFF
ProneDamage=100%

[SCZFSplashWH]
CellSpread=1
PercentAtMax=0.5
Modifier.none=1000%
Modifier.wood=600%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
InfDeath=1
AnimList=PIFFPIFF
ProneDamage=100%

; Kaiser Blades: normal damage + cleave that spares own units (Vinifera AffectsAllies=no)
[SCZFKaiserWH]
CellSpread=1
PercentAtMax=0.5
AffectsAllies=no
Modifier.none=1000%
Modifier.wood=600%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
InfDeath=1
AnimList=PIFF
ProneDamage=100%

[SCZFPlagueWH]
CellSpread=1.5
PercentAtMax=0.6
Modifier.none=800%
Modifier.wood=800%
Modifier.medium=800%
Modifier.heavy=800%
Modifier.concrete=800%
InfDeath=1
AnimList=PIFFPIFF
ProneDamage=100%

[SCZFInfestWH]
CellSpread=2
PercentAtMax=0.3
Modifier.none=600%
Modifier.wood=700%
Modifier.medium=900%
Modifier.heavy=1000%
Modifier.concrete=500%
Wall=yes
Wood=yes
InfDeath=2
AnimList=FBALL1
ProneDamage=100%
Conventional=yes

[SCZFClaw]
Damage=13
ROF=11
Range=1.75
Projectile=Invisible
Speed=100
Warhead=SCZFNormalWH
Report=SCZLATK

[SCZFSpine]
Damage=33
ROF=20
Range=7.8
Projectile=Invisible3
Speed=100
Warhead=SCZFExplWH
Report=SCHYFIRE

; Lurker Subterranean Spines (burrowed only): 2x the first version (user), range of the sieged Siege Tank (SCShockCan 20.4).
; Was IsSonic (Disruptor wave): the wave has a short fixed length, so from far away only the sound played (user test, probe:
; targets at 17-19 cells). Now a projectile that leaves SC spines behind every 3 frames (Trailer=SCZSPIKT + SpawnDelay, both
; read from the image's Art.ini section like [FLMPRJ] - in Rules they are ignored, 2nd test: one spine at the Lurker, nothing
; further); each spine hurts what is next to it (anim Damage/Warhead), the full hit and splash at the target.
; Flight keys copied from FlameProj1E2 (Behemoth flame, travels its full range); Level=yes is dropped.
[SCZFLurkSpine]
Damage=100
ROF=50
Range=20.4
Projectile=SCZSpineProj
Speed=40
Warhead=SCZFLurkWH
Report=SCZLRKFR

[SCZSpineProj]
Image=SCZSPINP
Arm=2
High=yes
Ranged=yes
AA=no
AG=yes
ROT=100
Acceleration=5
SpawnDelay=3
Shadow=no

; damage of every spine along the line (anim SCZSPIKT: Damage per hit, DamageRate in Art.ini); spares own units (Vinifera)
[SCZFLurkTrailWH]
CellSpread=0.6
PercentAtMax=0.6
AffectsAllies=no
Modifier.none=300%
Modifier.wood=200%
Modifier.medium=250%
Modifier.heavy=150%
Modifier.concrete=100%
InfDeath=1
ProneDamage=100%

; upgraded Lurker: +33% damage at the target (the spines along the line are the same anim)
[SCZFLurkSpineU]
Damage=133
ROF=50
Range=20.4
Projectile=SCZSpineProj
Speed=40
Warhead=SCZFLurkWH
Report=SCZLRKFR

[SCZFLurkWH]
CellSpread=0.5
PercentAtMax=0.5
Wood=yes
Modifier.none=1000%
Modifier.wood=600%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
InfDeath=1
AnimList=SCZSPIKE
ProneDamage=100%

[SCZFKaiser]
Damage=120
ROF=20
Range=2.5
Projectile=Invisible
Speed=100
Warhead=SCZFKaiserWH
Report=SCULHIT0,SCULHIT1

[SCZFPlague]
Damage=30
ROF=60
Range=5
Projectile=Invisible
Speed=100
Warhead=SCZFPlagueWH
Report=SCDFATK

[SCZFBite]
Damage=10
ROF=20
Range=1.93
Projectile=Invisible
Speed=100
Warhead=SCZFNormalWH
Report=SCBLATK

; Suicide=yes only on vehicles (on infantry it crashes InfantryClass::AI)
[SCZFInfest]
Damage=800
ROF=10
Range=1.5
Projectile=Invisible
Speed=100
Warhead=SCZFInfestWH
Report=SCITBOOM
Suicide=yes

; Mutalisk Glave Wurm: 9 dmg (+ bounces), cooldown 30, range 3
[SCZFGlave]
Damage=23
ROF=40
Range=4.5
Projectile=Invisible3
Speed=100
Warhead=SCZFNormalWH
Report=SCZMUFIR

; Scourge: 110 dmg suicide, air only
[SCZFScourge]
Damage=280
ROF=10
Range=1.5
Projectile=InvisibleAA
Speed=100
Warhead=SCZFExplWH
Report=SCZSCHIT
Suicide=yes

; Guardian Acid Spore: 20 dmg, cooldown 30, range 8, ground only. User 2026-10-25: a real flying acid ball (SC ep3Shot, recoloured
; green) that splashes on impact (SC ep3Burst + ZGuHit00), instead of the instant invisible shot.
[SCZFAcidSpore]
Damage=50
ROF=40
Range=9
Projectile=SCZGAcidProj
Speed=30
Warhead=SCZFAcidWH
Report=SCZGUFIR

[SCZGAcidProj]
Image=SCZGACID
AA=no
AG=yes
ROT=10
Ranged=yes
Shadow=no

[SCZFAcidWH]
CellSpread=0.3
PercentAtMax=0.5
Modifier.none=1000%
Modifier.wood=600%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
InfDeath=1
AnimList=SCZGBURST
ProneDamage=100%

; Devourer Corrosive Acid: 25 explosive, cooldown 100, range 6, air only
[SCZFCorrosive]
Damage=63
ROF=133
Range=7
Projectile=InvisibleAA
Speed=100
Warhead=SCZFExplWH
Report=SCZDVFIR

; Queen: no weapon in SC; here a broodling spit against ground targets
[SCZFBroodSpit]
Damage=40
ROF=60
Range=6
Projectile=Invisible
Speed=100
Warhead=SCZFNormalWH
Report=SCZQUFIR

; Spore Colony Seeker Spores: 15 dmg, cooldown 15, range 7, air only
[SCZFSporeAA]
Damage=38
ROF=20
Range=8
Projectile=InvisibleAA
Speed=100
Warhead=SCZFNormalWH
Report=SCHYFIRE

; SC Sunken Colony "Subterranean Tentacle": 40 explosive damage, cooldown 32, range 7 cells. User 2026-10-25: hits harder (2x)
; and 2x the range; the SC tentacle bursts out under the target (anim SCZTENT with the SC hit sound), the launch sound on firing.
; User 2026-10-27: too strong, halved both again (160 -> 80, 16 -> 8).
[SCZSunkenSpine]
Damage=80
ROF=42
Range=8
Projectile=Invisible
Speed=100
Warhead=SCZFTentWH
Report=SCZSUNAT

[SCZFTentWH]
CellSpread=0
Modifier.none=600%
Modifier.wood=700%
Modifier.medium=900%
Modifier.heavy=1000%
Modifier.concrete=500%
InfDeath=1
AnimList=SCZTENT
ProneDamage=100%
"@) $nl
"faction: map code layer $(Split-Path $fac -Leaf) (block with [Sides], [VehicleTypes], [InfantryTypes]) + [General] of $(Split-Path $facBase -Leaf)"
# Vinifera keeps 199 characters of Description= (TechnoTypeClassExtension::Description[200])
foreach ($ln in ([IO.File]::ReadAllText($fac, $latin) -split "`n")) { if ($ln -match '^Description=(.*)$' -and $ln.Contains('Zerg') -and $Matches[1].TrimEnd("`r").Length -gt 199) { Write-Warning "Description too long ($($Matches[1].TrimEnd("`r").Length)): $($ln.Substring(0, 60))" } }

# ---- Art.ini
$art = "$game\INI\Art.ini"; Backup $art
$artBody = "; Zerg faction (map session, 2026-10-25): MIX/ECACHE86.MIX from Modding/tools/build-sczergbase.ps1. Buildings: normal,`r`n" +
           "; damaged, 2 shadows; Buildup <ID>MK = SC Drone cocoon (ZBuild.grp) + zSpawn burst, 1 frame per tick (patched game.exe).`r`n" +
           "; Drones and flyers: SHP vehicles, 32 facings. Infantry and the Infested Terran use the art of the Zerg units block (Image=).`r`n"
foreach ($bd in $Bldgs) {
    $artBody += "`r`n[$($bd.Id)]`r`nCameo=$($bd.Id)IC`r`nFoundation=$($bd.Fw)x$($bd.Fh)`r`nHeight=$([Math]::Min(2, $bd.Fh - 1))`r`nRemapable=yes`r`nNewTheater=no`r`nBuildup=$($bd.Id)MK`r`n"
}
foreach ($dId in @('SCZWORK') + @($DroneFor | ForEach-Object { $_.Id })) {
    $artBody += "`r`n[$dId]`r`nCameo=$($dId)I`r`nVoxel=no`r`nRemapable=yes`r`nFacings=32`r`nStartStandFrame=0`r`nStandingFrames=1`r`nStartWalkFrame=32`r`nWalkFrames=5`r`nStartFiringFrame=192`r`nFiringFrames=2`r`n"
}
foreach ($fl in $Flyers) {
    $nw = $flyLayout[$fl.Id]
    $artBody += "`r`n[$($fl.Id)]`r`nCameo=$($fl.Id)I`r`nVoxel=no`r`nRemapable=yes`r`nFacings=32`r`nStartStandFrame=0`r`nStandingFrames=1`r`nStartWalkFrame=32`r`nWalkFrames=$nw`r`nStartFiringFrame=$(32 + 32 * $nw)`r`nFiringFrames=2`r`nPrimaryFireFLH=30,0,0`r`n"
}
$artBody += "`r`n; Lurker: walk sets 0-6, burrowed building 1x1 with the SC burrow animation as Buildup`r`n[SCZLRV]`r`nCameo=SCZLRVI`r`nVoxel=no`r`nRemapable=yes`r`nFacings=32`r`nStartStandFrame=0`r`nStandingFrames=1`r`nStartWalkFrame=32`r`nWalkFrames=7`r`nStartFiringFrame=256`r`nFiringFrames=2`r`n"
$artBody += "`r`n[SCZLRV2]`r`nCameo=SCZLRV2I`r`nVoxel=no`r`nRemapable=yes`r`nFacings=32`r`nStartStandFrame=0`r`nStandingFrames=1`r`nStartWalkFrame=32`r`nWalkFrames=7`r`nStartFiringFrame=256`r`nFiringFrames=2`r`n"
$artBody += "`r`n[SCZLRB]`r`nCameo=SCZLRBIC`r`nFoundation=1x1`r`nHeight=1`r`nRemapable=yes`r`nNewTheater=no`r`nBuildup=SCZLRBMK`r`n"
$artBody += "`r`n; impact anims (also in Rules.ini [Animations]): Sunken tentacle, Lurker spines; unit palette like SCMADTH`r`n"
$artBody += "`r`n[SCZTENT]`r`nNormalized=yes`r`nRate=300`r`nAltPalette=yes`r`nReport=SCZSUNHT`r`n`r`n[SCZSPIKE]`r`nNormalized=yes`r`nRate=300`r`nAltPalette=yes`r`nReport=SCZLRKHT`r`n"
$artBody += "`r`n; Lurker spines along the line: invisible projectile image (Trailer + SpawnDelay = a spine every 3 frames) and the damaging spine`r`n[SCZSPINP]`r`nTrailer=SCZSPIKT`r`nSpawnDelay=3`r`n`r`n[SCZSPIKT]`r`nImage=SCZSPIKE`r`nNormalized=yes`r`nRate=300`r`nAltPalette=yes`r`nDamage=6`r`nDamageRate=180`r`nWarhead=SCZFLurkTrailWH`r`n"
$artBody += "`r`n; Guardian acid spore: projectile image (2 frames, like PLASMORB / SCPDRBUL) and its splash`r`n[SCZGACID]`r`nAnimLow=0`r`nAnimHigh=1`r`nAnimRate=3`r`n`r`n[SCZGBURST]`r`nNormalized=yes`r`nAltPalette=yes`r`nReport=SCZGUHIT`r`n"
Set-Block $art $artBody "`r`n"
"art: Art.ini block ($($Bldgs.Count) buildings, $($DroneFor.Count + 1) drones, $($Flyers.Count) flyers, Lurker, 2 anims)"

# ---- Rules.ini [Animations]: the impact anims must be global, their SHPs load with the theater before the map INIs
$rul = "$game\INI\Rules.ini"; Backup $rul
$rt = [IO.File]::ReadAllText($rul, $latin)
$anims = [ordered]@{ SCZTENT = 'Zerg Sunken Colony tentacle (impact anim, global like SCMADTH)'; SCZSPIKE = 'Zerg Lurker spines (impact anim)'
    SCZGBURST = 'Zerg Guardian acid splash (impact anim)'; SCZSPIKT = 'Zerg Lurker spine left behind its projectile (damaging trailer)' }
$prev = 'SCVKDTH'
foreach ($an in $anims.Keys) {
    if ($rt -notmatch "(?m)^$an=") {
        $anchor = [regex]::Match($rt, "(?m)^$prev=$prev[^\n]*\n")
        if (-not $anchor.Success) { throw "Rules.ini: anchor $prev not found in [Animations]" }
        $rt = $rt.Insert($anchor.Index + $anchor.Length, "$an=$an`t;StarCraft mod: $($anims[$an])`r`n")
        "Rules.ini: $an added to [Animations]"
    }
    $prev = $an
}
[IO.File]::WriteAllText($rul, $rt, $latin)

# ---- Sound.ini
$snd = "$game\INI\Sound.ini"; Backup $snd
$n = 1300; $list = @()
foreach ($k in $sounds.Keys) { $list += "$n=$k"; $n++ }
Set-SectionEntries $snd 'SoundList' $list '^13\d\d=SCZ' "`r`n"
$sndBody = "; Zerg faction (map session): building death, morph start, flyer deaths`r`n`r`n[SCZBDTH]`r`nPriority=40`r`nRange=16`r`nLimit=3`r`n`r`n[SCZBPLC]`r`nPriority=30`r`nLimit=2`r`n"
foreach ($k in 'SCZOVDTH', 'SCZMUDTH', 'SCZSCDTH', 'SCZGUDTH', 'SCZDVDTH', 'SCZQUDTH') { $sndBody += "`r`n[$k]`r`nPriority=40`r`nRange=14`r`nLimit=4`r`n" }
$sndBody += "`r`n[SCZSCHIT]`r`nPriority=60`r`nRange=16`r`nLimit=6`r`n"
Set-Block $snd $sndBody "`r`n"
"sound: Sound.ini [SoundList] 1300-$($n - 1)"

# ---- StarCraft.ini (STARCRAFT checkbox): the Zerg faction has its own units now, so the checkbox Zerg units stay Terran-only
# (GDI1) and the Zerg buildings leave the generic prerequisite groups (both were added by the first version of this script)
$sc = "$game\INI\Game Options\StarCraft.ini"; Backup $sc
$t = [IO.File]::ReadAllText($sc, $latin)
$a = $t.IndexOf('; >>> StarCraft Zerg units'); $z = $t.IndexOf('; <<< StarCraft Zerg units')
if ($a -ge 0 -and $z -gt $a) {
    $mid = $t.Substring($a, $z - $a) -replace '(?m)^(Owner=[^\r\n;]*?),Nod1\b', '$1'
    $t = $t.Substring(0, $a) + $mid + $t.Substring($z)
}
$t = [regex]::Replace($t, '(?m)^(Prerequisite(Barracks|Radar|Tech)=[^\r\n]*?),SCZ(POL|EVO)\b', '$1')
[IO.File]::WriteAllText($sc, $t, $latin)
"StarCraft.ini: checkbox Zerg units without Nod1, Zerg buildings out of the generic groups"

# ---- lobby: 8th side "Zerg" (index 7); every mode without the faction file must disallow it
$go = "$game\Resources\GameOptions.ini"; Backup $go
$t = [IO.File]::ReadAllText($go, $latin)
$t = [regex]::Replace($t, '(?m)^Sides=GDI,Nod,Allies,Soviet,Neutral,Special,Terran(,Zerg)?', 'Sides=GDI,Nod,Allies,Soviet,Neutral,Special,Terran,Zerg')
[IO.File]::WriteAllText($go, $t, $latin)
$mp = "$game\INI\MPMaps.ini"; Backup $mp
$t = [IO.File]::ReadAllText($mp, $latin)
$t = [regex]::Replace($t, '(?m)^DisallowedPlayerSides=4,5,6(,7)?(?=\s*$)', 'DisallowedPlayerSides=4,5,6,7')
[IO.File]::WriteAllText($mp, $t, $latin)
"lobby: GameOptions.ini Sides +Zerg, MPMaps.ini DisallowedPlayerSides 4,5,6 -> 4,5,6,7 (Protoss lines with ,8 untouched)"

# ---- side files (side 7 -> file number 08), copied from Nod (side 1 -> 02); never overwrite
$copies = [ordered]@{ 'MIX\SideC02.mix' = 'MIX\SideC08.mix'; 'MIX\sidenc02.mix' = 'MIX\sidenc08.mix'; 'MIX\Speech02.mix' = 'MIX\Speech08.mix'
    'Resources\nodicon.png' = 'Resources\zergicon.png'; 'Resources\l600s11.pcx' = 'Resources\l600s71.pcx'; 'Resources\l600s12.pcx' = 'Resources\l600s72.pcx'
    'Resources\l480s11.pcx' = 'Resources\l480s71.pcx'; 'Resources\l480s12.pcx' = 'Resources\l480s72.pcx' }
foreach ($k in $copies.Keys) { if (-not (Test-Path "$game\$($copies[$k])")) { Copy-Item "$game\$k" "$game\$($copies[$k])"; "copied $k -> $($copies[$k])" } }
"install done"
