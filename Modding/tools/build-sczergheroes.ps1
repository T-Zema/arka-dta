# Zerg HEROES and SPECIAL BUILDINGS for the Zerg faction (house Nod1), user 2026-10-25: "dokoncz pozostale konwersje".
#   .\build-sczergheroes.ps1           -> MIX/ECACHE82.MIX (SHP, buildups, cameos, AUD) + previews in -PreviewDir
#   .\build-sczergheroes.ps1 -Install  -> also the INI side: block "Zerg heroes" at the end of INI/Map Code/Terran Faction.ini,
#                                         INI/Art.ini, INI/Sound.ini ([SoundList] 1700+), INI/Rules.ini (superweapon of the Overmind)
# Buildings (Drone + DeploysInto, SC cocoon, like build-sczergbase.ps1): Overmind (no shell, SC unit 148), Overmind with shell
# (SC 147, superweapon "Overmind's Wrath"), Cerebrate (SC 151), Cerebrate Daggoth (SC 152, gold), Mature Chrysalis (SC 150).
# Heroes (SC 48-57, 104, gold, BuildLimit=1): Devouring One, Hunter Killer, Torrasque, Unclean One, Infested Kerrigan,
# Infested Duran (infantry, Spawning Pool), Kukulza (Mutalisk), Kukulza (Guardian), Matriarch, Yggdrasill (Fly vehicles, Hatchery).
# Hero sections are copies of the "Zerg faction" units (resolved at run time), so re-run this after build-sczergbase.ps1 -Install.
# The client merges repeated sections (Modding/wiki/engine/ini-layering.md), so the block has its own list sections.
# Variable names: PowerShell is case-insensitive ($Bldgs/$bd, never $b/$B). Wiki: Modding/wiki/mods/zerg-heroes.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\sczergheroes-preview",
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScBuild.cs", "$tools\ScBuildings.cs", "$tools\ScInfantry.cs", "$tools\ScZerg.cs", "$tools\ScUnits.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null
$casc  = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"
$latin = [Text.Encoding]::GetEncoding(28591)

$scPal    = [Pal]::ReadWpe($casc.ReadFile('TileSet/jungle.wpe'))
$unitPal  = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$cameoPal = [Pal]::ReadTs($mixes.Read('CAMEO.PAL'))
$w = 0; $h = 0; $tpal = $null
$tunit = [Pal]::ReadPcx($casc.ReadFile('game/tunit.pcx'), [ref]$w, [ref]$h, [ref]$tpal)
$ramp = New-Object 'System.Drawing.Color[]' 8
for ($i = 0; $i -lt 8; $i++) { $ramp[$i] = $tpal[$tunit[$i]] }
$map     = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)
$dmgMap  = [ScBuildings]::DamageMap($map, $unitPal)
$mapGold = [ScUnits]::TintMap($scPal, $unitPal, $ramp, 1.35, 1.15, 0.45)        # same gold as the Terran heroes (Duke)
$dmgGold = [ScBuildings]::DamageMap($mapGold, $unitPal)
$scGold  = [ScUnits]::TintPalette($scPal, 1.35, 1.15, 0.45)
$purple  = [Drawing.Color]::FromArgb(150, 60, 140)

$grpCache = @{}
function G($name) {
    $path = if ($name.Contains('/')) { "unit/$name.grp" } else { "unit/zerg/$name.grp" }
    if (-not $grpCache.ContainsKey($name)) { $grpCache[$name] = [Grp]::Read($casc.ReadFile($path)) }
    return $grpCache[$name]
}
function Layers { $l = New-Object 'System.Collections.Generic.List[ScLayer]'; foreach ($a in $args) { if ($a) { $l.Add($a) } }; return ,$l }
function L($grp, $frame, $shadow = $false) { return New-Object ScLayer (G $grp), $frame, $shadow }
$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$cameoFrames = New-Object 'System.Collections.Generic.List[Frame]'

# gold frame around a cameo (heroes), like the "Upgraded" cameos but without the chevrons
$gold = [Pal]::Nearest([Drawing.Color]::FromArgb(230, 180, 40), $cameoPal, 1, 255)
function GoldFrame($shp) {
    $f = $shp.Frames[0]
    for ($x = 0; $x -lt $f.W; $x++) { foreach ($y in 0, 1, ($f.H - 2), ($f.H - 1)) { $f.Pixels[$y * $f.W + $x] = $gold } }
    for ($y = 0; $y -lt $f.H; $y++) { foreach ($x in 0, 1, ($f.W - 2), ($f.W - 1)) { $f.Pixels[$y * $f.W + $x] = $gold } }
    return $shp
}

# ------------------------------------------------------------------ special buildings (SC cocoon morph, see build-sczergbase.ps1)
# GRP/shadow names from SC's data (units.dat -> images.tbl): Overmind 148 = Over2/zo2shad (no shell), 147 = Over1/zo1shad (shell),
# Cerebrate = UCereb/zucShad, Mature Chrysalis = neutral\kerrChry/nkoShad. Footprints = SC placement boxes (32 px cells).
$GameFps = 45
$TicksPerScSecond = 0.63 * $GameFps
$Bldgs = @(
    @{ Id = 'SCZOVM'; Name = 'Overmind';                 Grp = 'Over2';            Shad = 'zo2shad';         Fw = 5; Fh = 3; Size = 3; Sec = 150; Height = 2 }
    @{ Id = 'SCZOVS'; Name = 'Overmind (Shelled)';       Grp = 'Over1';            Shad = 'zo1shad';         Fw = 5; Fh = 3; Size = 3; Sec = 180; Height = 2 }
    @{ Id = 'SCZCRB'; Name = 'Cerebrate';                Grp = 'UCereb';           Shad = 'zucShad';         Fw = 3; Fh = 2; Size = 2; Sec = 80;  Height = 1 }
    @{ Id = 'SCZDAG'; Name = 'Cerebrate Daggoth';        Grp = 'UCereb';           Shad = 'zucShad';         Fw = 3; Fh = 2; Size = 2; Sec = 100; Height = 1; Gold = $true }
    @{ Id = 'SCZCHR'; Name = 'Mature Chrysalis';         Grp = 'neutral/kerrChry'; Shad = 'neutral/nkoShad'; Fw = 2; Fh = 2; Size = 1; Sec = 60;  Height = 1 }
)
foreach ($bd in $Bldgs) { $bd.Ticks = [int][Math]::Round($bd.Sec * $TicksPerScSecond) }
function MorphSchedule([int]$size, [int]$ticks) {
    $loops  = @(@(2..9 + 8..3), @(13..19 + 18..14), @(22..27 + 26..23))
    $bursts = @(@(10, 11, 12), @(20, 21), @(28, 29, 30))
    $fixed = 6 + 12
    for ($i = 0; $i -lt $size; $i++) { $fixed += 3 * $bursts[$i].Count }
    $perLoop = [Math]::Max(3, [int][Math]::Floor(($ticks - $fixed) / $size))
    $extra = [Math]::Max(0, ($ticks - $fixed) - $perLoop * $size)
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
$spawnOf = @{ 1 = 'zspawn01'; 2 = 'zspawn02'; 3 = 'zspawn03' }
$bodies = @{}
foreach ($bd in $Bldgs) {
    $bm = if ($bd.Gold) { $mapGold } else { $map }; $bdm = if ($bd.Gold) { $dmgGold } else { $dmgMap }
    $spawn = $spawnOf[$bd.Size]
    $sizes = @($bd.Grp, $bd.Shad, 'zbuild', 'zbshad', $spawn) | % { G $_ }
    $maxW = ($sizes | % { $_.Width } | Measure-Object -Maximum).Maximum
    $maxH = ($sizes | % { $_.Height } | Measure-Object -Maximum).Maximum
    $shape = New-Object ScBuildingShape $bd.Fw, $bd.Fh, $maxW, $maxH, 0
    $body = Layers (L $bd.Grp 0); $shad = Layers (L $bd.Shad 0 $true)
    $bodies[$bd.Id] = $body
    $bldg = $shape.Building($body, $shad, $bm, $bdm)
    $uBodies  = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[ScLayer]]'
    $uShadows = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[ScLayer]]'
    $keyIdx = @{}; $order = New-Object System.Collections.Generic.List[int]; $repeat = New-Object System.Collections.Generic.List[int]
    foreach ($step in (MorphSchedule $bd.Size $bd.Ticks)) {
        $key = $step[0]
        if (-not $keyIdx.ContainsKey($key)) {
            $k = if ($key -ne 'b') { [int]$key.Substring(1) } else { 0 }
            switch ($key[0]) {
                'z' { $uBodies.Add((Layers (L 'zbuild' $k))); $uShadows.Add((Layers (L 'zbshad' $k $true))) }
                's' { $uBodies.Add((Layers (L $bd.Grp 0) (L $spawn $k))); $uShadows.Add($shad) }
                'b' { $uBodies.Add($body); $uShadows.Add($shad) }
            }
            $keyIdx[$key] = $uBodies.Count - 1
        }
        $order.Add($keyIdx[$key]); $repeat.Add($step[1])
    }
    $mk = [ScZerg]::BuildupCached($shape, $uBodies, $uShadows, $order.ToArray(), $repeat.ToArray(), $bm)
    $files["$($bd.Id).SHP"]   = $bldg.Write()
    $files["$($bd.Id)MK.SHP"] = [ScZerg]::WriteShared($mk)
    $cameo = [ScBuildings]::Cameo($body, $(if ($bd.Gold) { $scGold } else { $scPal }), $ramp, $cameoPal)
    if ($bd.Gold) { $cameo = GoldFrame $cameo }
    $files["$($bd.Id)IC.SHP"] = $cameo.Write(); $cameoFrames.Add($cameo.Frames[0])
    [ScBuildings]::FitPreview($bldg, 0, 2, $shape, $unitPal, 1, "$PreviewDir\fit_$($bd.Id).png")
    $n = $mk.Frames.Count / 2
    "{0,-7} {1}x{2} canvas {3}x{4} morph {5} ticks = {6:N1} s" -f $bd.Id, $bd.Fw, $bd.Fh, $shape.Cw, $shape.Ch, $n, ($n / $GameFps)
}
# superweapon icon: the shelled Overmind
$swIcon = [ScBuildings]::Cameo($bodies['SCZOVS'], $scPal, $ramp, $cameoPal)
$files['SCZWRATH.SHP'] = $swIcon.Write(); $cameoFrames.Add($swIcon.Frames[0])

# Drones that morph into them (same as build-sczergbase.ps1: one SHP copy per Drone type, cameo = building + Drone)
$droneBytes = $mixes.Read('SCZWORK.SHP'); if (-not $droneBytes) { throw 'SCZWORK.SHP not found (MIX/ECACHE86.MIX of build-sczergbase.ps1)' }
$droneRaw = G 'drone'; $bb = [ScZerg]::Bounds($droneRaw); $drone = [ScZerg]::Crop($droneRaw, $bb[0], $bb[1])
$DroneFor = @(
    @{ Id = 'SCZDOVM'; B = 'SCZOVM'; Pre = 'ZLAIRUP';         Limit = 1; What = 'The mind of the Swarm: huge sight, reveals cloaked units. Needed for Cerebrates and the shelled Overmind.' }
    @{ Id = 'SCZDOVS'; B = 'SCZOVS'; Pre = 'SCZOVM,ZHIVEUP';  Limit = 1; What = 'The Overmind in its armoured shell: superweapon Overmind''s Wrath.' }
    @{ Id = 'SCZDCRB'; B = 'SCZCRB'; Pre = 'SCZOVM';          Limit = 0; What = 'Commands a brood: needed for every Zerg hero.' }
    @{ Id = 'SCZDDAG'; B = 'SCZDAG'; Pre = 'SCZCRB,ZHIVEUP';  Limit = 1; What = 'Cerebrate of the Tiamat Brood: needed for Torrasque, Unclean One and Kukulza (Guardian).' }
    @{ Id = 'SCZDCHR'; B = 'SCZCHR'; Pre = 'SCZCRB,SCZNES';   Limit = 1; What = 'Kerrigan''s cocoon: needed for Infested Kerrigan.' }
)
foreach ($dr in $DroneFor) {
    $files["$($dr.Id).SHP"] = $droneBytes
    $c = [ScZerg]::DroneCameo($bodies[$dr.B], $drone, 12, $scPal, $ramp, $cameoPal)
    $files["$($dr.Id)I.SHP"] = $c.Write(); $cameoFrames.Add($c.Frames[0])
}

# ------------------------------------------------------------------ heroes
# Infantry (Spawning Pool): frame sets from SC's iscript.bin (playfram = set*17+dir), like build-sczerg.ps1. Kerrigan (uikerr):
# stand set 8, walk 9-15 + 8, attack 0-7 and back (melee at 7). Duran = SC Ghost image (terran\ghost): stand 3, walk 4-11,
# attack 0,1,2,12 (ATTACK at 12), death frames 221-228 + tghDeath. The other sets are the same as the base units.
# Scale: HP = SC hero HP x 20 x 2, damage = base weapon x SC hero/base ratio x 1.5, cost about 3-4x the base unit.
$InfHeroes = @(
    @{ Id = 'SCZHDO'; Base = 'SCZLNG'; Name = 'Devouring One';     Grp = 'zergling'; Shadow = 'zzeshad'; Remains = 'zzedeath'; Stand = 5; Walk = 5..11; Fire = 0, 0, 1, 1, 2, 2, 3, 3, 4, 4
       DeathUnit = 289..295; DeathRemains = 0..4; FireFrame = 4; Flh = '0,0,20'; HP = 7200; DmgX = 3.0; RangeX = 1.3; Speed = 10; Cost = 1500; Pre = 'SCZCRB'
       Desc = 'HERO. Zergling of legend: huge claws with a long reach, very tough hide.@@Regenerates. One at a time.' }   # user 2026-10-25: -30% speed, +50% HP, +30% range
    @{ Id = 'SCZHHK'; Base = 'SCZHYL'; Name = 'Hunter Killer';     Grp = 'hydra'; Shadow = 'zhyshad'; Remains = 'zhydeath'; Stand = 0; Walk = 5..11; Fire = 0, 0, 1, 1, 2, 2, 3, 3, 3, 3, 4, 4, 3, 3, 2, 2, 1, 1, 0, 0
       DeathUnit = @(); DeathRemains = 0, 0, 1, 1, 2, 3; FireFrame = 10; Flh = '40,0,60'; HP = 6400; DmgX = 3.0; RangeX = 1.25; Speed = 8; Cost = 2500; Pre = 'SCZCRB'
       Desc = 'HERO. Hydralisk hunter: double needle spines, longer reach, hits ground and air.@@Regenerates. One at a time.' }
    @{ Id = 'SCZHTQ'; Base = 'SCZULT'; Name = 'Torrasque';         Grp = 'ultra'; Shadow = 'zulshad'; Remains = 'zuldeath'; Stand = 0; Walk = 0..8; Fire = 14, 14, 14, 14, 13, 13, 13, 12, 12, 12, 11, 11, 11, 12, 12, 12, 13, 13, 13
       DeathUnit = 255..264; DeathRemains = 0..4; FireFrame = 7; Flh = '60,0,40'; HP = 32000; DmgX = 3.75; Speed = 12; Cost = 6000; Pre = 'SCZCRB,SCZDAG'
       Desc = 'HERO. The Torrasque, Ultralisk champion of the Tiamat Brood: giant Kaiser blades.@@Regenerates. One at a time.' }
    @{ Id = 'SCZHUO'; Base = 'SCZDFL'; Name = 'Unclean One';       Grp = 'defiler'; Shadow = 'defiler'; Remains = 'zdedeath'; Stand = 0; Walk = 0..7; Fire = 0, 0, 0, 1, 1, 1, 2, 2, 2, 1, 1, 1
       DeathUnit = 136, 153, 170, 187; DeathRemains = 0..5; FireFrame = 1; Flh = '30,0,40'; HP = 12000; DmgX = 2.5; Cost = 2000; Pre = 'SCZCRB,SCZDAG'
       Proj = @{ Projectile = 'SCZUOProj'; Speed = 25; Warhead = 'SCZUOWH' }   # user 2026-10-25: a real projectile, -50% cost, +20% HP
       Desc = 'HERO. Defiler of the Tiamat Brood: spits burning Plague bolts that burst into a toxic cloud.@@Regenerates. One at a time.' }
    @{ Id = 'SCZHKE'; Base = 'SCZLNG'; Name = 'Infested Kerrigan'; Grp = 'uikerr'; Shadow = 'uikShad'; Remains = 'zbrdeath'; Stand = 8; Walk = @(9..15 + 8); Fire = 0, 1, 2, 3, 4, 5, 6, 7, 7, 6, 5, 4, 3, 2, 1, 0
       DeathUnit = @(); DeathRemains = 0..4; FireFrame = 7; Flh = '0,0,20'; HP = 64000; Speed = 12; Sight = 9; Cost = 4000; Pre = 'SCZCRB,SCZCHR'; Voice = 'SCKI'
       # user 2026-10-25: +300% HP, +50% damage (195 -> 293), +20% range (1.75 -> 2.1), -50% cost, a spectacular melee hit
       Weapon = @{ Id = 'SCZHKClaw'; Damage = 293; ROF = 20; Range = 2.1; Projectile = 'Invisible'; Warhead = 'SCZHKWH'; Report = 'SCKIFIRE' }
       Desc = 'HERO. The Queen of Blades: every strike of her claws unleashes a psionic storm around the target.@@Regenerates. One at a time.' }
    @{ Id = 'SCZHDU'; Base = 'SCZHYL'; Name = 'Infested Duran';    Grp = 'terran/ghost'; Shadow = 'terran/tghShad'; Remains = 'terran/tghDeath'; Stand = 3; Walk = 4..11; Fire = 0, 1, 2, 12, 12, 2, 1, 0
       DeathUnit = 221..228; DeathRemains = 0..7; FireFrame = 3; Flh = '40,0,60'; HP = 12000; Speed = 9; Sight = 11; Cost = 3000; Pre = 'SCZCRB,SCZICC'; Voice = 'SCDU'
       Weapon = @{ Id = 'SCZHDRifle'; Damage = 98; ROF = 29; Range = 9; Projectile = 'Invisible3'; Warhead = 'SCZFNormalWH'; Report = 'SCDUFIRE' }
       # user 2026-10-25: -40% cost, ALWAYS cloaked, also while firing (Vinifera DecloakToFire=no); only detectors (Sensors) reveal him
       Extra = [ordered]@{ Cloakable = 'yes'; DecloakToFire = 'no' }
       Desc = 'HERO. Samir Duran, infested: C-10 canister rifle against ground and air.@@Permanently cloaked, even while firing: only detectors see him.@@Regenerates. One at a time.' }
)
$FlyHeroes = @(
    @{ Id = 'SCZHKM'; Base = 'SCZMUT'; Name = 'Kukulza (Mutalisk)'; Grp = 'mutalid';  Walk = 0..4; HP = 12000; DmgX = 3.0; Cost = 4000; Pre = 'SCZCRB'
       Proj = @{ Projectile = 'SCZMGlaveProj'; Speed = 40; Warhead = 'SCZMGlaveWH' }   # glave wurm projectile like every Mutalisk (see $glave)
       Desc = 'HERO. Kukulza, Mutalisk of the Overmind: double glave wurms, ground and air.@@Regenerates. One at a time.' }
    @{ Id = 'SCZHKG'; Base = 'SCZGRD'; Name = 'Kukulza (Guardian)'; Grp = 'guardian'; Walk = 0..6; HP = 16000; DmgX = 3.0; Cost = 5000; Pre = 'SCZCRB,SCZDAG'
       Desc = 'HERO. Kukulza as a Guardian: huge acid spores against ground targets.@@Regenerates. One at a time.' }
    @{ Id = 'SCZHMA'; Base = 'SCZQUN'; Name = 'Matriarch';          Grp = 'queen';    Walk = 0..4; HP = 12000; DmgX = 2.5; RofX = 0.75; Cost = 4000; Pre = 'SCZCRB'
       Desc = 'HERO. The Matriarch, Queen of the Swarm: fast, strong broodling acid.@@Regenerates. One at a time.' }
    @{ Id = 'SCZHYG'; Base = 'SCZOVL'; Name = 'Yggdrasill';         Grp = 'overlord'; Walk = 0..3; HP = 40000; DmgX = 1.0; SpeedX = 2.5; SightAdd = 4; SensorsAdd = 6; Cost = 2000; Pre = 'SCZCRB'
       Desc = 'HERO. Yggdrasill, the great Overlord: very tough, fast, sees and detects very far.@@Regenerates. One at a time.' }
)
$layouts = @{}
foreach ($hr in $InfHeroes) {
    $body = G $hr.Grp; $shad = G $hr.Shadow; $rem = G $hr.Remains
    $death = New-Object 'System.Collections.Generic.List[Frame]'
    foreach ($i in $hr.DeathUnit) { $death.Add($body.Frames[$i]) }
    foreach ($i in $hr.DeathRemains) { if ($i -lt $rem.Frames.Count) { $death.Add($rem.Frames[$i]) } }
    $lay = $null
    $shp = [ScInfantry]::Build($body, $shad, $mapGold, $hr.Stand, [int[]]$hr.Walk, [int[]]$hr.Fire, $death, [ref]$lay)
    $layouts[$hr.Id] = $lay
    $files["$($hr.Id).SHP"] = $shp.Write()
    $cm = GoldFrame ([ScInfantry]::Cameo($body.Frames[$hr.Stand * 17 + 12], $body.Width, $body.Height, $scGold, $ramp, $cameoPal, $purple))
    $files["$($hr.Id)I.SHP"] = $cm.Write(); $cameoFrames.Add($cm.Frames[0])
    $idx = @(0..7) + @(($lay.Walk + 6 * $lay.WalkFrames)..($lay.Walk + 7 * $lay.WalkFrames - 1)) + @(($lay.Fire + 6 * $lay.FireFrames)..($lay.Fire + 7 * $lay.FireFrames - 1)) + @($lay.Death..($lay.Death + $lay.DeathFrames - 1))
    [Pal]::Sheet($shp.Frames, [int[]]$idx, $shp.Width, $shp.Height, $unitPal, 2, 12, "$PreviewDir\$($hr.Id).png")
    "{0,-7} infantry {1}x{2}, {3} frames" -f $hr.Id, $shp.Width, $shp.Height, $lay.Total
}
foreach ($fh in $FlyHeroes) {
    $raw = G $fh.Grp; $fb = [ScZerg]::Bounds($raw); $g2 = [ScZerg]::Crop($raw, $fb[0], $fb[1])
    $shp = [ScBuild]::BuildUnit($g2, $g2, $mapGold, [int[]]$fh.Walk, 0, 0)
    $files["$($fh.Id).SHP"] = $shp.Write()
    $cm = GoldFrame ([ScInfantry]::Cameo($g2.Frames[12], $g2.Width, $g2.Height, $scGold, $ramp, $cameoPal, $purple))
    $files["$($fh.Id)I.SHP"] = $cm.Write(); $cameoFrames.Add($cm.Frames[0])
    [Pal]::Sheet($shp.Frames, [int[]](0, 4, 8, 12, 16, 20, 24, 28, 32, 33), $shp.Width, $shp.Height, $unitPal, 2, 10, "$PreviewDir\$($fh.Id).png")
    "{0,-7} flyer {1} frames {2}x{3}" -f $fh.Id, $shp.Frames.Count, $shp.Width, $shp.Height
}
[Pal]::Sheet($cameoFrames, [int[]](0..($cameoFrames.Count - 1)), 64, 48, $cameoPal, 2, 8, "$PreviewDir\cameos.png")

# ------------------------------------------------------------------ projectiles and hit effects (user 2026-10-25)
# Mutalisk glave wurm = image of SC weapon 48 (bullet\spores, 10 spinning frames), hit thingy\SporeHit (sound ZQuHit02);
# Unclean One = burning bolt (thingy\consume frames 2-8) bursting into a toxic cloud (thingy\Ensnare);
# Kerrigan's claws = a psionic storm (thingy\psiStorm) on every hit. Impact anims are registered in Rules.ini [Animations].
$fx = [ordered]@{
    SCZMGLAV = @{ Grp = 'bullet/spores';   Frames = @(0..9) }
    SCZMGHIT = @{ Grp = 'thingy/SporeHit'; Frames = @(0..9) }
    SCZUOBOL = @{ Grp = 'thingy/consume';  Frames = @(2..8) }
    SCZUOHIT = @{ Grp = 'thingy/Ensnare';  Frames = @(0..14) }
    SCZHKPSI = @{ Grp = 'thingy/psiStorm'; Frames = @(0..13) }
}
foreach ($id in $fx.Keys) {
    $g = G $fx[$id].Grp; $fr = New-Object 'System.Collections.Generic.List[Frame]'
    foreach ($k in $fx[$id].Frames) { $fr.Add($g.Frames[$k]) }
    $an = [ScBuild]::BuildAnim($fr, $g.Width, $g.Height, $map)
    $files["$id.SHP"] = $an.Write()
    [Pal]::Sheet($an.Frames, [int[]](0..($an.Frames.Count - 1)), $an.Width, $an.Height, $unitPal, 1, 15, "$PreviewDir\fx_$id.png")
}

# ------------------------------------------------------------------ sounds (SD WAV -> AUD): Kerrigan and Duran have their own voices
$sounds = [ordered]@{ SCZMUHIT = 'bullet/zquhit02'; SCZUOPLG = 'zerg/defiler/zdeplg00' }
foreach ($k in 0..3) { $sounds["SCKIWHT$k"] = "zerg/zergkerri/ukiwht0$k"; $sounds["SCKIYES$k"] = "zerg/zergkerri/ukiyes0$k"; $sounds["SCKIPSS$k"] = "zerg/zergkerri/ukipss0$k" }
$sounds['SCKIDTH0'] = 'zerg/zergkerri/ukidth00'; $sounds['SCKIFIRE'] = 'bullet/ukifir00'
foreach ($k in 0..3) { $sounds["SCDUWHT$k"] = "zerg/zergduran/zdnwht0$k"; $sounds["SCDUYES$k"] = "zerg/zergduran/zdnyes0$k" }
foreach ($k in 0..8) { $sounds["SCDUPSS$k"] = "zerg/zergduran/zdnpss0$k" }
$sounds['SCDUDTH0'] = 'zerg/zergduran/zdndth00'; $sounds['SCDUFIRE'] = 'bullet/tghfir00'
$sndOk = [ordered]@{}
foreach ($k in $sounds.Keys) {
    try { $raw = $casc.ReadFile("SD/sound/$($sounds[$k]).wav") } catch { $raw = $null }
    if (-not $raw -and $k -eq 'SCDUDTH0') { $raw = $casc.ReadFile('SD/sound/terran/ghost/tghdth00.wav') }   # fallback: the Ghost's death
    if (-not $raw) { Write-Warning "sound missing: $($sounds[$k])"; continue }
    $rate = 0; $pcm = [Aud]::ReadWav($raw, [ref]$rate); $files["$k.AUD"] = [Aud]::Encode($pcm, $rate, 1.0); $sndOk[$k] = 1
}

$out = "$game\MIX\ECACHE82.MIX"
[Mix]::Write($out, $files)
$check = New-Object MixSet "$game\MIX"
foreach ($k in $files.Keys) { if ($k.EndsWith('.SHP') -and ([Shp]::Read($check.Read($k))).Frames.Count -eq 0) { throw "bad $k" } }
"ECACHE82.MIX: $($files.Count) files, $([Math]::Round((Get-Item $out).Length / 1KB)) KB; previews -> $PreviewDir"
if (-not $Install) { return }

# ------------------------------------------------------------------ INI side
$begin = '; >>> Zerg heroes'; $end = '; <<< Zerg heroes'
function Read-Ini([string[]]$lines) {
    $d = @{}; $sec = $null
    foreach ($ln in $lines) {
        if ($ln -match '^\[([^\]]+)\]') { $sec = $matches[1]; if (-not $d.ContainsKey($sec)) { $d[$sec] = [ordered]@{} }; continue }
        if ($sec -and $ln -match '^([^;=\s][^=]*?)\s*=\s*(.*)$') { $d[$sec][$matches[1].Trim()] = ($matches[2] -replace '\s*;.*$', '').Trim() }
    }
    return $d
}
function Copy-Sec($ini, [string]$name) { if (-not $ini.ContainsKey($name)) { throw "[$name] not found" }; $r = [ordered]@{}; foreach ($k in $ini[$name].Keys) { $r[$k] = $ini[$name][$k] }; return $r }
function Num($s) { return [double]::Parse(($s -replace '%', ''), [Globalization.CultureInfo]::InvariantCulture) }
function Fmt($x) { if ([math]::Abs($x - [math]::Round($x)) -lt 0.001) { return [string][int][math]::Round($x) } else { return ([math]::Round($x, 2)).ToString([Globalization.CultureInfo]::InvariantCulture) } }
function Strip-Block([string]$text) {
    $a = $text.IndexOf($begin); if ($a -lt 0) { return $text }
    $z = $text.IndexOf($end, $a); if ($z -lt 0) { throw "block end marker missing: $end" }
    return $text.Substring(0, $a).TrimEnd() + "`r`n" + $text.Substring($z + $end.Length).TrimStart("`r", "`n")
}
function Sec-Text([string]$name, $keys) { $t = "[$name]`n"; foreach ($k in $keys.Keys) { $t += "$k=$($keys[$k])`n" }; return $t + "`n" }
function Regen($keys, [double]$pct) { $keys['SelfHealing'] = 'yes'; $keys['SelfHealingCap'] = '1.0'; $keys['SelfHealingStep'] = [string][Math]::Max(1, [int][Math]::Round((Num $keys['Strength']) * $pct)) }
function Clip([string]$s) { if ($s.Length -gt 199) { return $s.Substring(0, 199) } else { return $s } }

$facPath = "$game\INI\Map Code\Terran Faction.ini"; $artPath = "$game\INI\Art.ini"; $sndPath = "$game\INI\Sound.ini"; $rulPath = "$game\INI\Rules.ini"
foreach ($p in $facPath, $artPath, $sndPath, $rulPath) { if (-not (Test-Path "$p.bak")) { Copy-Item $p "$p.bak" } }
$facOld = [IO.File]::ReadAllText($facPath, $latin); $nl = if ($facOld.Contains("`r`n")) { "`r`n" } else { "`n" }
$facBase = Strip-Block $facOld
$fac = Read-Ini ($facBase -split "`r?`n")
if (-not $fac.ContainsKey('SCZLNG')) { throw 'Zerg faction block not found: run build-sczergbase.ps1 -Install first' }

$txt = @"
; =====================================================================================================================
; Zerg heroes and special buildings (generated by Modding/tools/build-sczergheroes.ps1, do not edit by hand;
; wiki: Modding/wiki/mods/zerg-heroes.md). Graphics/sounds: MIX/ECACHE82.MIX; superweapon SCZWrathSpecial in Rules.ini.
; Tree: Lair -> Overmind -> Cerebrate -> heroes; + Hive -> Overmind (Shelled) (superweapon), Cerebrate Daggoth;
; Cerebrate + Queen's Nest -> Mature Chrysalis (Infested Kerrigan). Repeated list sections are merged by the client.
; =====================================================================================================================

[BuildingTypes]
$(($Bldgs | ForEach-Object -Begin { $n = 1 } -Process { 'ZHB{0:D2}={1}' -f $n, $_.Id; $n++ }) -join "`n")

[InfantryTypes]
$(($InfHeroes | ForEach-Object -Begin { $n = 1 } -Process { 'ZHI{0:D2}={1}' -f $n, $_.Id; $n++ }) -join "`n")

[VehicleTypes]
$((@($DroneFor | ForEach-Object { $_.Id }) + @($FlyHeroes | ForEach-Object { $_.Id }) | ForEach-Object -Begin { $n = 1 } -Process { 'ZHV{0:D2}={1}' -f $n, $_; $n++ }) -join "`n")

; ---------------------------------------------------------------- special buildings (created only by a Drone's deploy)

"@
$bldgRole = @{
    SCZOVM = [ordered]@{ Description = 'The Overmind, mind of the Swarm.@@Huge sight, reveals cloaked units. Needed for Cerebrates and the shelled Overmind.'; Strength = 20000; Armor = 'wood'; Cost = 4000; Sight = 20; Sensors = 'yes'; SensorsSight = 20; ThreatPosed = 0 }
    SCZOVS = [ordered]@{ Description = 'The Overmind in its armoured shell.@@Superweapon: Overmind''s Wrath (a psionic blast from the sky anywhere on the map).'; Strength = 40000; Armor = 'heavy'; Cost = 8000; Sight = 20; Sensors = 'yes'; SensorsSight = 20; SuperWeapon = 'SCZWrathSpecial'; ThreatPosed = 0 }
    SCZCRB = [ordered]@{ Description = 'Cerebrate: commands a brood.@@Needed for every Zerg hero. Reveals cloaked units nearby.'; Strength = 12000; Armor = 'wood'; Cost = 2000; Sight = 12; Sensors = 'yes'; SensorsSight = 12; ThreatPosed = 0 }
    SCZDAG = [ordered]@{ Description = 'Daggoth, Cerebrate of the Tiamat Brood (one only).@@Needed for Torrasque, Unclean One and Kukulza (Guardian). Wide detection.'; Strength = 24000; Armor = 'heavy'; Cost = 4000; Sight = 16; Sensors = 'yes'; SensorsSight = 16; ThreatPosed = 0 }
    SCZCHR = [ordered]@{ Description = 'Mature Chrysalis: Kerrigan''s cocoon.@@Needed for Infested Kerrigan.'; Strength = 2000; Armor = 'wood'; Cost = 2400; Sight = 6; ThreatPosed = 0 }
}
foreach ($bd in $Bldgs) {
    $k = [ordered]@{ Name = $bd.Name }
    foreach ($x in $bldgRole[$bd.Id].Keys) { $k[$x] = $bldgRole[$bd.Id][$x] }
    $k['Points'] = [int]($k['Cost'] / 20); $k['Power'] = 0
    foreach ($kv in @('TechLevel=-1', 'Owner=Nod1', 'Capturable=false', 'Crewed=no', 'Unsellable=yes', 'Explosion=FBALL1,FBALL2,FBALL3',
                      'ScrapExplosion=FBALL1,FBALL2,FBALL3', 'MaxDebris=0', 'DeploySound=SCZBPLC', 'DieSound=SCZBDTH', 'AIBuildThis=no', 'Repairable=no')) {
        $p = $kv.Split('=', 2); $k[$p[0]] = $p[1]
    }
    Regen $k 0.002
    $txt += Sec-Text $bd.Id $k
}
$txt += "; ---------------------------------------------------------------- Drones (built at a Hatchery/Lair/Hive, DEPLOY = morph)`n`n"
$tmpl = Copy-Sec $fac 'SCZDEVO'
foreach ($dr in $DroneFor) {
    $bd = $Bldgs | Where-Object { $_.Id -eq $dr.B }
    $k = [ordered]@{}; foreach ($x in $tmpl.Keys) { $k[$x] = $tmpl[$x] }
    $k['Name'] = "Drone: $($bd.Name)"
    $k['Description'] = Clip "Morphs into: $($bd.Name). Move it there and DEPLOY.@@$($dr.What)"
    $k['Prerequisite'] = $dr.Pre; $k['DeploysInto'] = $dr.B; $k['Cost'] = 200 + $bldgRole[$dr.B]['Cost']
    if ($dr.Limit) { $k['BuildLimit'] = $dr.Limit }
    $txt += Sec-Text $dr.Id $k
}
$txt += "; ---------------------------------------------------------------- heroes (gold, BuildLimit=1)`n`n"
$weap = ''
function Hero-Weapons($k, $hr) {
    foreach ($slot in 'Primary', 'Secondary') {
        if (-not $k.Contains($slot) -or -not $k[$slot] -or $k[$slot] -eq 'none') { continue }
        $wn = $k[$slot]; $nw = "${wn}H"
        $wk = Copy-Sec $fac $wn
        if ($hr.DmgX -and $hr.DmgX -ne 1.0 -and $wk.Contains('Damage')) { $wk['Damage'] = Fmt ([math]::Round((Num $wk['Damage']) * $hr.DmgX)) }
        if ($hr.RangeX -and $wk.Contains('Range')) { $wk['Range'] = Fmt ((Num $wk['Range']) * $hr.RangeX) }
        if ($hr.RofX -and $wk.Contains('ROF')) { $wk['ROF'] = Fmt ([math]::Max(1, [math]::Round((Num $wk['ROF']) * $hr.RofX))) }
        if ($hr.Proj) { foreach ($x in $hr.Proj.Keys) { $wk[$x] = $hr.Proj[$x] } }
        $script:weap += Sec-Text $nw $wk
        $k[$slot] = $nw
    }
}
function Hero-Common($k, $hr) {
    $k['Name'] = $hr.Name; $k['Image'] = $hr.Id; $k['Description'] = Clip $hr.Desc
    $basePre = if ($k['Prerequisite'] -and $k['Prerequisite'] -ne 'none') { $k['Prerequisite'] } else { '' }
    $k['Prerequisite'] = (@($basePre -split ',') + @($hr.Pre -split ',') | Where-Object { $_ } | Select-Object -Unique) -join ','
    $k['Strength'] = $hr.HP; $k['Cost'] = $hr.Cost; $k['Points'] = [int]($hr.Cost / 20); $k['BuildLimit'] = 1
    $k['ThreatPosed'] = [int](Num $k['ThreatPosed']) * 2 + 10
    if ($hr.Speed) { $k['Speed'] = $hr.Speed }
    if ($hr.SpeedX) { $k['Speed'] = Fmt ([math]::Round((Num $k['Speed']) * $hr.SpeedX)) }
    if ($hr.Sight) { $k['Sight'] = $hr.Sight }
    if ($hr.SightAdd) { $k['Sight'] = Fmt ((Num $k['Sight']) + $hr.SightAdd) }
    if ($hr.SensorsAdd -and $k.Contains('SensorsSight')) { $k['SensorsSight'] = Fmt ((Num $k['SensorsSight']) + $hr.SensorsAdd) }
    Regen $k 0.004
    if ($hr.Extra) { foreach ($x in $hr.Extra.Keys) { $k[$x] = $hr.Extra[$x] } }
}
foreach ($hr in $InfHeroes) {
    $k = Copy-Sec $fac $hr.Base
    Hero-Common $k $hr
    if ($hr.Weapon) {
        $k['Primary'] = $hr.Weapon.Id
        $wk = [ordered]@{ Damage = $hr.Weapon.Damage; ROF = $hr.Weapon.ROF; Range = $hr.Weapon.Range; Projectile = $hr.Weapon.Projectile; Speed = 100; Warhead = $hr.Weapon.Warhead; Report = $hr.Weapon.Report }
        if ($sndOk.Contains($hr.Weapon.Report) -eq $false) { $wk.Remove('Report') }
        $weap += Sec-Text $hr.Weapon.Id $wk
        if ($k.Contains('Secondary')) { $k.Remove('Secondary') }
    } else { Hero-Weapons $k $hr }
    if ($hr.Voice) {
        $v = $hr.Voice
        $sel = @(0..3 | % { "$($v)WHT$_" }) + @(0..8 | % { "$($v)PSS$_" }) | Where-Object { $sndOk.Contains($_) }
        $yes = @(0..3 | % { "$($v)YES$_" }) | Where-Object { $sndOk.Contains($_) }
        $k['VoiceSelect'] = $sel -join ','; $k['VoiceMove'] = $yes -join ','; $k['VoiceAttack'] = $yes -join ','
        if ($sndOk.Contains("$($v)DTH0")) { $k['VoiceDie'] = "$($v)DTH0" }
    }
    $txt += Sec-Text $hr.Id $k
}
foreach ($fh in $FlyHeroes) {
    $k = Copy-Sec $fac $fh.Base
    Hero-Common $k $fh
    Hero-Weapons $k $fh
    $txt += Sec-Text $fh.Id $k
}
$txt += "; ---------------------------------------------------------------- hero weapons (copies of the Zerg weapons, more damage)`n`n" + $weap
# projectiles and warheads with the SC effects (assets above). [SCZFGlave] repeats the "Zerg faction" weapon section: the client
# merges it (later keys win), so EVERY Mutalisk fires glave wurms (user 2026-10-25); the research copy SCZFGlaveU follows it
# after build-sczergresearch.ps1 runs again.
function WH($base, $extra) { $wk = Copy-Sec $fac $base; foreach ($x in $extra.Keys) { $wk[$x] = $extra[$x] }; return $wk }
$txt += "; ---------------------------------------------------------------- projectiles (Mutalisk glave wurm, Plague bolt) and hit effects`n`n"
$txt += Sec-Text 'SCZFGlave' ([ordered]@{ Projectile = 'SCZMGlaveProj'; Speed = 40; Warhead = 'SCZMGlaveWH' })
$txt += Sec-Text 'SCZMGlaveProj' ([ordered]@{ Image = 'SCZMGLAV'; AA = 'yes'; AG = 'yes'; ROT = 16; Ranged = 'yes'; Shadow = 'no' })
$txt += Sec-Text 'SCZMGlaveWH' (WH 'SCZFNormalWH' ([ordered]@{ AnimList = 'SCZMGHIT' }))
$txt += Sec-Text 'SCZUOProj' ([ordered]@{ Image = 'SCZUOBOL'; AA = 'no'; AG = 'yes'; ROT = 8; Ranged = 'yes'; Shadow = 'no' })
$txt += Sec-Text 'SCZUOWH' (WH 'SCZFPlagueWH' ([ordered]@{ CellSpread = 2; AnimList = 'SCZUOHIT' }))
$txt += Sec-Text 'SCZHKWH' (WH 'SCZFNormalWH' ([ordered]@{ CellSpread = 1; PercentAtMax = 0.5; AffectsAllies = 'no'; AnimList = 'SCZHKPSI' }))
$block = ($begin + $nl + ($txt.TrimEnd() -replace "`r?`n", $nl) + $nl + $end + $nl)
[IO.File]::WriteAllText($facPath, ($facBase.TrimEnd() -replace "`r?`n", $nl) + $nl + $nl + $block, $latin)
"faction: Terran Faction.ini block ($($Bldgs.Count) buildings, $($DroneFor.Count) drones, $($InfHeroes.Count + $FlyHeroes.Count) heroes)"

# ---- Art.ini
$art = Read-Ini ([IO.File]::ReadAllLines($artPath, $latin))
$ab = "; Zerg heroes and special buildings (Modding/tools/build-sczergheroes.ps1, MIX/ECACHE82.MIX)`r`n"
foreach ($bd in $Bldgs) { $ab += "`r`n[$($bd.Id)]`r`nCameo=$($bd.Id)IC`r`nFoundation=$($bd.Fw)x$($bd.Fh)`r`nHeight=$($bd.Height)`r`nRemapable=yes`r`nNewTheater=no`r`nBuildup=$($bd.Id)MK`r`n" }
$droneArt = Copy-Sec $art 'SCZDEVO'
foreach ($dr in $DroneFor) { $a = [ordered]@{}; foreach ($x in $droneArt.Keys) { $a[$x] = $droneArt[$x] }; $a['Cameo'] = "$($dr.Id)I"; $ab += "`r`n" + ((Sec-Text $dr.Id $a) -replace "`n", "`r`n") }
foreach ($hr in $InfHeroes) {
    $lay = $layouts[$hr.Id]
    $ab += "`r`n[$($hr.Id)]`r`nCameo=$($hr.Id)I`r`nSequence=$($hr.Id)Sequence`r`nRemapable=yes`r`nCrawls=no`r`nFireUp=$($hr.FireFrame)`r`nFireProne=$($hr.FireFrame)`r`nPrimaryFireFLH=$($hr.Flh)`r`n"
    $ab += "`r`n[$($hr.Id)Sequence]`r`n" + ($lay.Sequence() -replace "`r?`n", "`r`n")
}
foreach ($fh in $FlyHeroes) {
    $baseArt = Copy-Sec $art $fh.Base
    $nw = $fh.Walk.Count
    $a = [ordered]@{ Cameo = "$($fh.Id)I"; Voxel = 'no'; Remapable = 'yes'; Facings = 32; StartStandFrame = 0; StandingFrames = 1; StartWalkFrame = 32; WalkFrames = $nw
                     StartFiringFrame = 32 + 32 * $nw; FiringFrames = 2 }
    if ($baseArt.Contains('PrimaryFireFLH')) { $a['PrimaryFireFLH'] = $baseArt['PrimaryFireFLH'] }
    $ab += "`r`n" + ((Sec-Text $fh.Id $a) -replace "`n", "`r`n")
}
$ab += "`r`n; projectile images (frame loop) and impact anims`r`n[SCZMGLAV]`r`nAnimLow=0`r`nAnimHigh=9`r`nAnimRate=1`r`n`r`n[SCZUOBOL]`r`nAnimLow=0`r`nAnimHigh=6`r`nAnimRate=2`r`n"
foreach ($an in @(@('SCZMGHIT', 'SCZMUHIT', $false), @('SCZUOHIT', 'SCZUOPLG', $false), @('SCZHKPSI', '', $true))) {
    $ab += "`r`n[$($an[0])]`r`nNormalized=yes`r`nAltPalette=yes`r`n"
    if ($an[1] -and $sndOk.Contains($an[1])) { $ab += "Report=$($an[1])`r`n" }
    if ($an[2]) { $ab += "Translucent=yes`r`n" }
}
$artText = [IO.File]::ReadAllText($artPath, $latin)
$artText = Strip-Block $artText
[IO.File]::WriteAllText($artPath, $artText.TrimEnd() + "`r`n`r`n" + $begin + "`r`n" + $ab.TrimEnd() + "`r`n" + $end + "`r`n", $latin)
"art: Art.ini block"

# ---- Sound.ini: [SoundList] 1700+ (entries inside the existing list, the game reads Sound.ini itself) + priorities
$st = [IO.File]::ReadAllText($sndPath, $latin)
$lines = New-Object System.Collections.Generic.List[string]; $lines.AddRange([string[]]($st -split "`n"))
$s0 = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimEnd("`r") -eq '[SoundList]') { $s0 = $i; break } }
if ($s0 -lt 0) { throw '[SoundList] not found' }
$e0 = $lines.Count; for ($j = $s0 + 1; $j -lt $lines.Count; $j++) { if ($lines[$j].StartsWith('[')) { $e0 = $j; break } }
for ($i = $e0 - 1; $i -gt $s0; $i--) { if ($lines[$i] -match '^17\d\d=SC') { $lines.RemoveAt($i); $e0-- } }
$last = $s0; for ($j = $s0 + 1; $j -lt $e0; $j++) { $x = $lines[$j].Trim(); if ($x -and -not $x.StartsWith(';')) { $last = $j } }
$n = 1700; $ent = @(); foreach ($k in $sndOk.Keys) { $ent += "$n=$k`r"; $n++ }
$lines.InsertRange($last + 1, [string[]]$ent)
$st = Strip-Block ($lines -join "`n")
$sb = "; Zerg heroes (build-sczergheroes.ps1): death screams carry far`r`n"
foreach ($k in 'SCKIDTH0', 'SCDUDTH0') { if ($sndOk.Contains($k)) { $sb += "`r`n[$k]`r`nPriority=50`r`nRange=16`r`nLimit=2`r`n" } }
[IO.File]::WriteAllText($sndPath, $st.TrimEnd() + "`r`n`r`n" + $begin + "`r`n" + $sb.TrimEnd() + "`r`n" + $end + "`r`n", $latin)
"sound: Sound.ini [SoundList] 1700-$($n - 1)"

# ---- Rules.ini: superweapon of the shelled Overmind. Own type (every superweapon needs a building of its own) and a UNIQUE
# Action: the map click fires the FIRST superweapon with the same Action (engine/superweapons). NuclearStrike3 = free (AirStrike cursor).
# Type=IonCannon: strikes anywhere instantly, no launch animation needed on the building.
$rt = [IO.File]::ReadAllText($rulPath, $latin)
$rt = Strip-Block $rt
# impact anims must be global ([Animations] in Rules.ini): their SHPs load with the theater, before the map INIs
$rt = [regex]::Replace($rt, '(?m)^(SCZMGHIT|SCZUOHIT|SCZHKPSI)=[^\n]*\n', '')
$anchor = [regex]::Match($rt, '(?m)^SCZSPIKT=[^\n]*\n'); if (-not $anchor.Success) { $anchor = [regex]::Match($rt, '(?m)^SCVKDTH=[^\n]*\n') }
if (-not $anchor.Success) { throw 'Rules.ini: no anchor in [Animations]' }
$rt = $rt.Insert($anchor.Index + $anchor.Length, "SCZMGHIT=SCZMGHIT`t;StarCraft mod: Mutalisk glave wurm hit (build-sczergheroes.ps1)`r`nSCZUOHIT=SCZUOHIT`t;StarCraft mod: Unclean One Plague cloud`r`nSCZHKPSI=SCZHKPSI`t;StarCraft mod: Infested Kerrigan psionic hit`r`n")
if ($rt -notmatch '(?m)^\d+=SCZWrathSpecial') {
    $m = [regex]::Match($rt, '(?ms)^\[SuperWeaponTypes\]\r?\n(.*?)(?=^\r?$|^\[)')
    if (-not $m.Success) { throw '[SuperWeaponTypes] not found' }
    $used = @([regex]::Matches($m.Groups[1].Value, '(?m)^(\d+)=') | ForEach-Object { [int]$_.Groups[1].Value }); $free = 1; while ($used -contains $free) { $free++ }
    $rt = $rt.Insert($m.Index + $m.Length, "$free=SCZWrathSpecial`t;StarCraft mod: Overmind's Wrath of the Zerg faction (build-sczergheroes.ps1)`r`n")
}
$sw = @"
; Zerg faction (Modding/tools/build-sczergheroes.ps1): superweapon of the shelled Overmind SCZOVS (Terran Faction.ini).
[SCZWrathSpecial]
Name=Overmind's Wrath
Description=The Overmind strikes anywhere on the map: instant psionic blast.
IsPowered=false	; the Zerg have no power plants
RechargeVoice=
ChargingVoice=
ImpatientVoice=NOREDY1
SuspendVoice=
RechargeTime=8.5	; like the Ion Cannon
Type=IonCannon
Action=NuclearStrike3	; unique action (NuclearStrike2 = SCNukeSpecial)
SidebarImage=SCZWRATH
"@
[IO.File]::WriteAllText($rulPath, $rt.TrimEnd() + "`r`n`r`n" + $begin + "`r`n" + ($sw -replace "`r?`n", "`r`n") + "`r`n" + $end + "`r`n", $latin)
"rules: [SuperWeaponTypes] SCZWrathSpecial (Type=IonCannon, Action=NuclearStrike3)"
"install done"
