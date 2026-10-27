# Zerg creep from TS veins (user 2026-10-27): the Veinhole Monster is the "organism" that grows veins around itself.
#   - Creep Tumor: a Drone deploys into SCZTUM, a Wall=yes building whose art has ToOverlay=VEINHOLE. BuildingClass::Unlimbo
#     turns a wall building into its overlay at once, and overlay 167 (VEINHOLE) creates a Veinhole Monster.
#   - Hatchery / Lair / Hive / Creep, Sunken and Spore Colony keep standing; an invisible ActiveAnim (DTA tiberium spreader
#     pattern, TIBSPRDR4) keeps dropping a shard with TiberiumSpawnType=VEINHOLE. ActiveAnimX/Y put it on a cell inside the
#     foundation and the shard does not fly, so the Veinhole Monster appears UNDER the building (monsters are drawn before
#     buildings, so the building hides the hole) and the creep starts from the building (user 2026-10-27). patch-veins.ps1
#     lets VEINHOLE seed under a building. A new monster appears after the old one is killed.
#   - Every infantry, vehicle, aircraft and building type gets ImmuneToVeins=yes (user: the creep harms nobody; veins also
#     attack buildings standing on them).
#   - [Basic] VeinGrowthEnabled=yes (most DTA maps say no, then no monster grows veins), [General] VeinholeGrowthRate=60
#     (faster than Rules' 300), Creep Colony Storage=100 (silo like the Supply Depot / Pylon, user 2026-10-27).
#   - Overlays VEINS and VEINHOLEDUMMY get Insignificant=yes: DTA's game.exe lets buildings be placed on insignificant overlays
#     (cave 0x86C0F0 in CellClass::Is_Clear_To_Build), [Weeds] is already Buildable=yes.
# Needs the game.exe patch tools/patch-veins.ps1 (in patch-game.ps1): no Veinhole Monster can appear during the game without it.
# Writes: block "; >>> Zerg creep" at the end of INI/Map Code/Terran Faction.ini and INI/Art.ini, and ActiveAnim lines
# (comment "Zerg creep") inside the Zerg building art sections of the "Zerg faction" block.
# Re-run after build-sczergbase.ps1 -Install (it rewrites those art sections) or after any generator adds unit types.
# Wiki: Modding/wiki/mods/zerg-creep.md, engine/veins.
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path "$PSScriptRoot\..\..").Path
$latin = [Text.Encoding]::GetEncoding(28591)
$begin = '; >>> Zerg creep'; $end = '; <<< Zerg creep'
$fac = "$game\INI\Map Code\Terran Faction.ini"; $art = "$game\INI\Art.ini"
function Backup([string]$path) { if (-not (Test-Path "$path.bak")) { Copy-Item $path "$path.bak" } }
function Set-Block([string]$path, [string]$body) {
    $t = [IO.File]::ReadAllText($path, $latin)
    $block = ($begin + "`r`n" + ($body.TrimEnd() -replace "`r?`n", "`r`n") + "`r`n" + $end + "`r`n")
    $a = $t.IndexOf($begin)
    if ($a -ge 0) { $z = $t.IndexOf($end, $a); $z = $t.IndexOf("`n", $z) + 1; $t = $t.Substring(0, $a) + $block + $t.Substring($z) }
    else { if (-not $t.EndsWith("`n")) { $t += "`r`n" }; $t += "`r`n" + $block }
    [IO.File]::WriteAllText($path, $t, $latin)
}
# entries inside an existing section, after its last key line; old entries matching $own are removed first
function Set-SectionEntries([string]$path, [string]$section, [string[]]$entries, [string]$own) {
    $t = [IO.File]::ReadAllText($path, $latin)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.AddRange([string[]]($t -split "`n"))
    $s = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimEnd("`r") -eq "[$section]") { $s = $i; break } }
    if ($s -lt 0) { throw "[$section] not found in $path" }
    $e = $lines.Count; for ($j = $s + 1; $j -lt $lines.Count; $j++) { if ($lines[$j].StartsWith('[')) { $e = $j; break } }
    for ($i = $e - 1; $i -gt $s; $i--) { if ($lines[$i] -match $own) { $lines.RemoveAt($i); $e-- } }
    $last = $s; for ($j = $s + 1; $j -lt $e; $j++) { $x = $lines[$j].Trim(); if ($x -and -not $x.StartsWith(';')) { $last = $j } }
    $lines.InsertRange($last + 1, [string[]]($entries | ForEach-Object { $_ + "`r" }))
    [IO.File]::WriteAllText($path, ($lines -join "`n"), $latin)
}
# section -> key -> value (repeated sections merged, later key wins, like the client), without this script's own block
function Read-Ini([string]$path, $d) {
    $t = [IO.File]::ReadAllText($path, $latin); $a = $t.IndexOf($begin)
    if ($a -ge 0) { $z = $t.IndexOf("`n", $t.IndexOf($end, $a)) + 1; $t = $t.Substring(0, $a) + $t.Substring($z) }
    $sec = $null
    foreach ($l in ($t -split "`r?`n")) {
        if ($l -match '^\[([^\]]+)\]') { $sec = $Matches[1]; if (-not $d.Contains($sec)) { $d[$sec] = [ordered]@{} }; continue }
        if ($sec -and $l -match '^\s*([^;=\s][^=]*?)\s*=\s*([^;\t]*)') { $d[$sec][$Matches[1]] = $Matches[2].Trim() }
    }
}

# ---- every unit type the skirmish rules can know, in load order (Rules.ini, then the files the client appends)
$all = [ordered]@{}
foreach ($p in "$game\INI\Rules.ini", "$game\INI\Enhance.ini", "$game\INI\Game Options\Super Mod.ini", "$game\INI\Game Options\StarCraft.ini", $fac) { Read-Ini $p $all }
$types = New-Object System.Collections.Generic.List[string]
# BuildingTypes too: the vein attack (CellClass at 0x45C5C0, AnimClass at 0x4166C0) hits every techno in the cell whose type lacks
# ImmuneToVeins, buildings included (in-game test 5, 2026-10-27: the creep destroyed buildings standing on it).
foreach ($list in 'InfantryTypes', 'VehicleTypes', 'AircraftTypes', 'BuildingTypes') {
    foreach ($v in $all[$list].Values) { if ($v -and -not $types.Contains($v)) { $types.Add($v) } }
}
$needImmune = @($types | Where-Object { -not ($all.Contains($_) -and $all[$_]['ImmuneToVeins'] -match '^(yes|true|1)') })

# ---- the Creep Tumor Drone: a copy of "Drone: Creep Colony" (same picture), deploys into the tumor
$drone = $all['SCZDCRP']; if (-not $drone) { throw "[SCZDCRP] not found: run build-sczergbase.ps1 -Install first" }
$set = [ordered]@{
    Name = 'Drone: Creep Tumor'
    Description = 'Morphs into: Creep Tumor. Move it there and DEPLOY: it sinks into the ground and becomes a creep hole that keeps spreading creep.@@Must stand on creep, on flat ground (3x3), 3 cells from the next hole. Harms nobody.'
    Image = 'SCZDCRP'
    Prerequisite = 'ZHATCHERY'
    DeploysInto = 'SCZTUM'
    Cost = '200'
    ImmuneToVeins = 'yes'
}
$droneIni = "[SCZDTUM]`r`n"
foreach ($k in $set.Keys) { $droneIni += "$k=$($set[$k])`r`n" }
foreach ($k in $drone.Keys) { if (-not $set.Contains($k)) { $droneIni += "$k=$($drone[$k])`r`n" } }

$body = @"
; Zerg creep (Modding/tools/build-sczergcreep.ps1, 2026-10-27). Creep = TS veins grown by a neutral Veinhole Monster ("organism").
; Creep Tumor: Drone SCZDTUM deploys into SCZTUM (Wall=yes + art ToOverlay=VEINHOLE), which becomes a Veinhole Monster at once.
; Hatchery/Lair/Hive and Creep/Sunken/Spore Colony: invisible ActiveAnim SCZCRSP* drops shards SCZCRSH* (TiberiumSpawnType=VEINHOLE)
; that put a Veinhole Monster under the building. Needs game.exe patch tools/patch-veins.ps1. A hole needs flat Clear 3x3 ground
; and keeps 3 cells from the next one. ImmuneToVeins=yes for every unit and building type below: the creep harms nobody.
; Wiki: Modding/wiki/mods/zerg-creep.md, engine/veins.

; veins only grow when the map allows it: VeinholeMonsterClass::Grow checks Scenario VeinGrowthEnabled, and 357 DTA maps have
; [Basic] VeinGrowthEnabled=no (first in-game test: holes appeared, veins never grew). The client appends this file to the map,
; so these keys win.
[Basic]
VeinGrowthEnabled=yes

; growth timer in frames (Rules.ini 300); every growth step adds 1-5 vein cells. User: faster creep.
[General]
VeinholeGrowthRate=60

; Creep Colony stores resources like a silo (user 2026-10-27; same as the Supply Depot / Pylon silos of the SC factions)
[SCZCRP]
Storage=100

; buildings can be placed on creep: DTA's game.exe allows insignificant overlays under buildings ([Weeds] is Buildable=yes)
[VEINS]
Insignificant=yes

[VEINHOLEDUMMY]
Insignificant=yes

[Animations]
ZCA01=SCZCRSPL
ZCA02=SCZCRSHL
ZCA03=SCZCRSPS
ZCA04=SCZCRSHS

[BuildingTypes]
ZCB01=SCZTUM

[VehicleTypes]
ZCV01=SCZDTUM

[SCZTUM]
Name=Creep Tumor
Description=Becomes a creep hole at once.
Wall=yes	; BuildingClass::Unlimbo: a wall building turns into its art ToOverlay= (VEINHOLE) and removes itself
Strength=400
Armor=wood
Cost=200
Points=1
Sight=4
Power=0
TechLevel=-1	; only the Drone's deploy creates it
Owner=Nod1
Capturable=false
Crewed=no
Unsellable=yes
Repairable=no
Insignificant=yes
ThreatPosed=0
AIBuildThis=no
BaseNormal=no
ImmuneToVeins=yes

$droneIni
; ---- ImmuneToVeins=yes for every infantry, vehicle, aircraft and building type without it ($($needImmune.Count) of $($types.Count))
"@
foreach ($t in $needImmune) { $body += "`r`n[$t]`r`nImmuneToVeins=yes`r`n" }

$artBody = @"
; Zerg creep (Modding/tools/build-sczergcreep.ps1, 2026-10-27), rules in INI/Map Code/Terran Faction.ini block "Zerg creep".
; Creep Tumor building: picture of the Creep Colony; it never shows, Unlimbo turns it into the overlay at once.
[SCZTUM]
Image=SCZCRP
Cameo=SCZDCRPI
Foundation=1x1
ToOverlay=VEINHOLE
Remapable=yes
NewTheater=no

; spreaders (DTA "Invisible Tiberium Spreader" TBSPRD_R4 / TBSHARDR4): an invisible loop drops an invisible bouncing shard every
; TrailerSeperation; where it lands it seeds overlay VEINHOLE (patched game.exe: no random +0..3, its own cell, allowed under a
; building), which makes a monster. L = Hatchery/Lair/Hive (4x3), S = colonies (2x2). MaxXYVel=1: the shard drops in place, on
; the cell chosen by the building's ActiveAnimX/Y.
[SCZCRSPL]
Image=CLRANIM
LoopStart=0
LoopEnd=1
LoopCount=-1
Rate=0
Surface=yes
TrailerAnim=SCZCRSHL
TrailerSeperation=60

[SCZCRSHL]
Image=CLRANIM
Elasticity=0.0
MinZVel=10.0
MaxXYVel=1.0
IsTiberium=true
LoopStart=0
LoopEnd=1
LoopCount=-1
Rate=0
Bouncer=yes
TiberiumSpreadRadius=0
TiberiumSpawnType=VEINHOLE

[SCZCRSPS]
Image=CLRANIM
LoopStart=0
LoopEnd=1
LoopCount=-1
Rate=0
Surface=yes
TrailerAnim=SCZCRSHS
TrailerSeperation=60

[SCZCRSHS]
Image=CLRANIM
Elasticity=0.0
MinZVel=10.0
MaxXYVel=1.0
IsTiberium=true
LoopStart=0
LoopEnd=1
LoopCount=-1
Rate=0
Bouncer=yes
TiberiumSpreadRadius=0
TiberiumSpawnType=VEINHOLE
"@

Backup $fac; Backup $art
Set-Block $fac $body
Set-Block $art $artBody
$spread = [ordered]@{ SCZHAT = 'SCZCRSPL'; SCZHTS = 'SCZCRSPL'; SCZLAI = 'SCZCRSPL'; SCZHIV = 'SCZCRSPL'; SCZCRP = 'SCZCRSPS'; SCZSUN = 'SCZCRSPS'; SCZSPO = 'SCZCRSPS' }
# The anim stands at the building's Render_Coord (top corner of the foundation) + ActiveAnimX/Y pixels; a cell is 48x24 px, so
# cell (x,y) centre = X 24*(x-y), Y 12*(x+y+1). 4x3: cell (1,1), the whole 3x3 hole fits inside the foundation. 2x2: cell (0,0),
# the hole sticks out on the top sides, behind the building picture.
$offset = @{ SCZCRSPL = @(0, 36); SCZCRSPS = @(0, 12) }
foreach ($id in $spread.Keys) {
    $xy = $offset[$spread[$id]]
    Set-SectionEntries $art $id @("ActiveAnim=$($spread[$id])`t; Zerg creep (build-sczergcreep.ps1)", "ActiveAnimPowered=no`t; Zerg creep",
        "ActiveAnimX=$($xy[0])`t; Zerg creep: cell inside the foundation", "ActiveAnimY=$($xy[1])`t; Zerg creep") '; Zerg creep'
}
"installed: Creep Tumor (SCZDTUM -> SCZTUM), spreaders on $($spread.Count) buildings, ImmuneToVeins on $($needImmune.Count) of $($types.Count) types"
