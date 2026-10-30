# ARKA mission 6 "Ogien z nieba" (Antiga Prime, 2500): mission layer on top of the terrain of build-arka06-antiga.ps1.
# STAGE 1 (2026-10-30): static objects only, for the user to judge the layout on a render: ARKA on its landing pad and
# the Antigan colony Antioch on the SE island, built of StarCraft Terran buildings in themed districts with add-ons
# (user rule: SC-world cities = SC Terran buildings, not the DTA CITY* blocks). No houses, teams, triggers or texts yet.
#
#   powershell -NoProfile -File .\build-arka06-mission.ps1 -Render    # also render %TEMP%\arka06-mission\arka06_mission.png
#
# Wiki: Modding/wiki/missions/arka-06-ogien-z-nieba.md
param(
    [string]$Terrain = "",
    [string]$Out = "",
    [switch]$Render
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Terrain) { $Terrain = "$game\Maps\Custom\arka06_antiga.map" }
if (-not $Out) { $Out = "$game\Maps\Missions\arka06.map" }
$work = "$env:TEMP\arka06-mission"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\TsMap.cs" -ReferencedAssemblies System.Drawing
$enc = [Text.Encoding]::GetEncoding(1252)

$ini = [Ini]::Load($Terrain)
$log = New-Object Collections.Generic.List[string]

# ================================================================ terrain occupancy (what may hold a building or unit)
$mixes = New-Object MixSet "$game\MIX"
$th    = New-Object Theater "$game\INI\Temperat.ini", "tem", $mixes
$GW = 512
$code = New-Object 'int[]' ($GW * $GW); for ($i = 0; $i -lt $code.Length; $i++) { $code[$i] = -1 }   # -1 = off map
$street = New-Object 'bool[]' ($GW * $GW)                                                          # Paved Road LAT
$hgt = New-Object 'int[]' ($GW * $GW)                                                              # cell height
foreach ($t in [IsoMap]::Decode([Pack]::Unpack($ini.Joined('IsoMapPack5'), $true))) {
    $tile = if ($t.Tile -lt 0 -or $t.Tile -ge 65535) { 0 } else { $t.Tile }
    $tmp = $th.Get($tile); $c = 0; $h = $t.Level
    if ($tmp -and $t.Sub -lt $tmp.Cells.Length -and $tmp.Cells[$t.Sub]) { $c = $tmp.Cells[$t.Sub].Terrain; $h += $tmp.Cells[$t.Sub].Height }
    $code[$t.Y * $GW + $t.X] = $c; $hgt[$t.Y * $GW + $t.X] = $h
    $set = $th.SetOf($tile); if ($set -and $set.Name -match 'Paved Road') { $street[$t.Y * $GW + $t.X] = $true }
}
$block = New-Object 'bool[]' ($GW * $GW)
$ovl = [Pack]::Unpack($ini.Joined('OverlayPack'), $false)
for ($i = 0; $i -lt $ovl.Length -and $i -lt $block.Length; $i++) { if ($ovl[$i] -ne 255) { $block[$i] = $true } }
foreach ($kv in $ini.Section('Terrain')) { $v = [int]$kv.Key; $block[[Math]::Floor($v / 1000) * $GW + $v % 1000] = $true }

# ================================================================ INI sources: Rules (base) and the StarCraft rules files (as mission 5)
function Read-IniFile($path) {
    $d = @{}; $order = New-Object Collections.Generic.List[string]; $sec = $null
    foreach ($raw in [IO.File]::ReadAllLines($path, $enc)) {
        $l = $raw; $sc = $l.IndexOf(';'); if ($sc -ge 0) { $l = $l.Substring(0, $sc) }; $l = $l.Trim()
        if ($l -match '^\[([^\]]+)\]') { $sec = $matches[1]; if (-not $d.ContainsKey($sec)) { $d[$sec] = [ordered]@{}; $order.Add($sec) }; continue }
        if (-not $sec) { continue }
        $eq = $l.IndexOf('='); if ($eq -le 0) { continue }
        $d[$sec][$l.Substring(0, $eq).Trim()] = $l.Substring($eq + 1).Trim()
    }
    @{ Sec = $d; Order = $order }
}
$rules = (Read-IniFile "$game\INI\Rules.ini").Sec
$art   = (Read-IniFile "$game\INI\Art.ini").Sec
$scSec = @{}
. "$tools\MapCode.ps1"
foreach ($f in @("$game\INI\Game Options\StarCraft.ini") + @(Get-MapCodeLayers)) {
    $r = Read-IniFile $f
    foreach ($s in $r.Order) { if (-not $scSec.ContainsKey($s)) { $scSec[$s] = [ordered]@{} }; foreach ($k in $r.Sec[$s].Keys) { $scSec[$s][$k] = $r.Sec[$s][$k] } }
}
$listNames = 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes', 'Animations', 'Particles', 'ParticleSystems', 'VoxelAnims', 'Warheads', 'SuperWeaponTypes'
$listOf = @{}
foreach ($ln in $listNames) { if ($scSec.ContainsKey($ln)) { foreach ($v in $scSec[$ln].Values) { $listOf[$v] = $ln } } }
foreach ($ln in $listNames) { if ($rules.ContainsKey($ln)) { foreach ($v in $rules[$ln].Values) { if (-not $listOf.ContainsKey($v)) { $listOf[$v] = "Rules:$ln" } } } }
$notTypes = @('General', 'AI', 'Sides', 'Houses', 'PrerequisiteGroups', 'Nod1', 'GDI1', 'GDI2', 'Nod2', 'ZergSide', 'ProtossSide', 'TerranSide', 'CombatDamage', 'AudioVisual') + $listNames
$noFollow = @('Prerequisite', 'PrerequisiteOverride', 'BuiltAt', 'Owner', 'RequiredHouses', 'ForbiddenHouses', 'Image', 'Name', 'Description', 'UIName', 'AIBasePlanningSide')
function Get-ScClosure([string[]]$roots) {
    $inc = [ordered]@{}; $q = New-Object Collections.Generic.Queue[string]
    foreach ($r in $roots) { if (-not $scSec.ContainsKey($r)) { throw "SC type $r is not defined in StarCraft.ini / the faction map code" }; $q.Enqueue($r) }
    while ($q.Count) {
        $s = $q.Dequeue(); if ($inc.Contains($s)) { continue }; $inc[$s] = $true
        foreach ($k in $scSec[$s].Keys) {
            if ($noFollow -contains $k -or $k -like 'Prerequisite*') { continue }
            foreach ($tok in ($scSec[$s][$k] -split ',')) {
                $tok = $tok.Trim()
                if ($tok -and $scSec.ContainsKey($tok) -and $notTypes -notcontains $tok -and -not $inc.Contains($tok)) { $q.Enqueue($tok) }
            }
        }
    }
    @($inc.Keys)
}
$scRoots = @(
    'SCCC', 'SCCOMS', 'SCACAD', 'SCEBAY', 'SCDEPO', 'SCBUNK', 'SCMTUR',   # Antioch: civic district
    'SCSTAR', 'SCCTWR', 'SCSCIF', 'SCPHYS',                               # Antioch: spaceport
    'SCFACT', 'SCMSHP', 'SCARMO')                                         # Antioch: mining district
$scTypes = Get-ScClosure $scRoots
$known = @{}; foreach ($s in $scTypes) { $known[$s] = $true }
$nList = @{}
foreach ($s in $scTypes) {
    foreach ($k in $scSec[$s].Keys) {
        $v = $scSec[$s][$k]
        if ($k -like 'Prerequisite*' -or $k -eq 'BuiltAt') {
            $v = (($v -split ',' | ForEach-Object { $t = $_.Trim(); if ($t -eq 'FACTORY') { 'SCFACT' } elseif ($t -eq 'BARRACKS') { 'SCBARR' } else { $t } }) -join ',')
            $keep = @($v -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($known.ContainsKey($_) -or ($rules.ContainsKey($_) -and -not $scSec.ContainsKey($_)) -or $_ -match '^(POWER|FACTORY|BARRACKS|RADAR|TECH|PROC|none)$') })
            if ($keep.Count -eq 0) { continue }
            $v = $keep -join ','
        }
        $ini.Set($s, $k, $v)
    }
    if ($listOf.ContainsKey($s) -and $listOf[$s] -notlike 'Rules:*') {
        $ln = $listOf[$s]; $nList[$ln] = 1 + [int]$nList[$ln]
        $ini.Set($ln, ('ARKA6{0}{1:D3}' -f $ln.Substring(0, 2).ToUpper(), $nList[$ln]), $s)
        # mission-only types: the player must not find StarCraft buildings in the sidebar
        if ($ln -in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') { $ini.Set($s, 'TechLevel', '-1') }
    }
}
$log.Add("SC types copied into the map: $($scTypes.Count) sections (" + (($nList.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', ') + ")")

# ================================================================ foundations, free spots, object writers (as mission 5)
$fcache = @{}
function Foundation($type) {
    if ($fcache.ContainsKey($type)) { return $fcache[$type] }
    $img = $null
    foreach ($src in $ini.Get($type, 'Image', $null), $(if ($scSec.ContainsKey($type)) { $scSec[$type]['Image'] }), $(if ($rules.ContainsKey($type)) { $rules[$type]['Image'] })) { if ($src) { $img = $src; break } }
    if (-not $img) { $img = $type }
    $f = $null
    for ($k = 0; $k -lt 4 -and $img; $k++) { if ($art.ContainsKey($img)) { $f = $art[$img]['Foundation']; if ($f) { break }; $img = $art[$img]['$Inherits'] } else { break } }
    if (-not $f) { $f = '1x1' }
    $p = $f -split 'x'; $fcache[$type] = @([int]$p[0], [int]$p[1]); $fcache[$type]
}
# buildings never stand on a street (the streets lead somewhere and must stay open), and one level per building
$noStreet = $false
function Buildable($x, $y) { $i = $y * $GW + $x; $c = $code[$i]; ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -and -not $block[$i] -and -not ($noStreet -and $street[$i]) }
$wp = @{}; foreach ($kv in $ini.Section('Waypoints')) { $v = [int]$kv.Value; $wp[[int]$kv.Key] = @(($v % 1000), [Math]::Floor($v / 1000)) }
foreach ($n in @(10, 19, 38, 39) + (50..53)) { if (-not $wp.ContainsKey($n)) { throw "terrain map has no waypoint $n (rebuild build-arka06-antiga.ps1)" } }
function Free($x, $y, $w, $h, $m) {
    $z0 = $hgt[$y * $GW + $x]
    for ($i = $x - $m; $i -lt $x + $w + $m; $i++) { for ($j = $y - $m; $j -lt $y + $h + $m; $j++) {
        if (-not (Buildable $i $j)) { return $false }
        if ($i -ge $x -and $i -lt $x + $w -and $j -ge $y -and $j -lt $y + $h -and $hgt[$j * $GW + $i] -ne $z0) { return $false }
    } }
    $true
}
function Occupy($x, $y, $w, $h) { for ($i = $x; $i -lt $x + $w; $i++) { for ($j = $y; $j -lt $y + $h; $j++) { $block[$j * $GW + $i] = $true } } }
function Find-Spot($tx, $ty, $w, $h, $m) {
    for ($r = 0; $r -le 25; $r++) {
        $best = $null; $bd = 1e9
        for ($x = $tx - $r; $x -le $tx + $r; $x++) { for ($y = $ty - $r; $y -le $ty + $r; $y++) {
            if ([Math]::Max([Math]::Abs($x - $tx), [Math]::Abs($y - $ty)) -ne $r) { continue }
            if (Free $x $y $w $h $m) { $d = ($x - $tx) * ($x - $tx) + ($y - $ty) * ($y - $ty); if ($d -lt $bd) { $bd = $d; $best = @($x, $y) } }
        } }
        if ($best) { return $best }
    }
    throw "no free ${w}x$h spot near $tx,$ty"
}
$structs = $ini.Section('Structures'); $sIdx = $structs.Count
function Add-Building($house, $type, $x, $y, $tag = 'None', $sell = 1, $hp = 256) {
    $f = Foundation $type; Occupy $x $y $f[0] $f[1]
    $script:structs.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$script:sIdx", "$house,$type,$hp,$x,$y,64,$tag,$sell,0,1,0,0,None,None,None,0,0"))
    $script:sIdx++; $log.Add("building $house $type @ $x,$y ($($f[0])x$($f[1])) hp=$hp tag=$tag")
}
function Place-AtWp($house, $type, [int]$n, $m = 1, $tag = 'None', $hp = 256, $sell = 0, $dx = 0, $dy = 0) {
    $f = Foundation $type
    $script:noStreet = $true
    try { $s = Find-Spot ($wp[$n][0] + $dx - [Math]::Floor($f[0] / 2)) ($wp[$n][1] + $dy - [Math]::Floor($f[1] / 2)) $f[0] $f[1] $m }
    finally { $script:noStreet = $false }
    Add-Building $house $type $s[0] $s[1] $tag $sell $hp
}
# a building with its add-on (2x2) against its right side, flush with the bottom edge, as in StarCraft (mission 5)
function Place-WithAddon($house, $type, $addon, [int]$n, $dx, $dy, $hp) {
    $f = Foundation $type; $fa = Foundation $addon
    $script:noStreet = $true
    try { $s = Find-Spot ($wp[$n][0] + $dx - [Math]::Floor($f[0] / 2)) ($wp[$n][1] + $dy - [Math]::Floor($f[1] / 2)) ($f[0] + $fa[0]) ([Math]::Max($f[1], $fa[1])) 0 }
    finally { $script:noStreet = $false }
    Add-Building $house $type $s[0] $s[1] 'None' 0 $hp
    Add-Building $house $addon ($s[0] + $f[0]) ($s[1] + $f[1] - $fa[1]) 'None' 0 ([Math]::Min(256, $hp + 30))
}

# ================================================================ ARKA on its landing pad
# Since mission 6 the Terrans' jet engines let ARKA lift off and land like a Terran building (user 2026-10-30); here it
# simply stands on the pad. RAPDOX = the Allied Chronosphere picture (the renderer does not draw it, mission 4).
Place-AtWp 'Allies' 'RAPDOX' 10 0 'None' 256 0

# ================================================================ Antioch, the Antigan colony on the SE island
# StarCraft Terran buildings in themed districts with their add-ons (user rule, mission 5). House Neutral: the colony
# sits the war out. Entry: type, waypoint, dx, dy, hp[, add-on]. No Nuclear Silo (a superweapon for its house).
#   51 civic district:   Command Center + Comsat Station, Academy, Engineering Bay, missile turrets, a bunker
#   52 spaceport:        two Starports with Control Towers, Science Facility with Physics Lab
#   53 mining district:  Factory with Machine Shop, Armory, Supply Depots by the crystals on the mesa
#   50 main square:      Supply Depots round it (the colonists' housing)
# plus the SC neutral buildings (tools/build-scneutral.ps1, MIX/ECACHE75.MIX, art name = section name; template from
# build-arka03-mission.ps1): the colony's Power Generators and a Starbase by the spaceport (wiki mods/sc-neutral-buildings)
$neutralSc = [ordered]@{
    SCNGEN = [ordered]@{ Name = 'Generator Antiochu'; Strength = '1500'; Armor = 'concrete'; Owner = 'Neutral' }
    SCNSTB = [ordered]@{ Name = 'Stacja kosmiczna Antiochu'; Strength = '2000'; Armor = 'concrete'; Owner = 'Neutral' }
}
$nb = 0
foreach ($t in $neutralSc.Keys) {
    if (-not $art.ContainsKey($t)) { throw "no [$t] in Art.ini: run build-scneutral.ps1 first" }
    $v = $neutralSc[$t]
    foreach ($k in $v.Keys) { $ini.Set($t, $k, $v[$k]) }
    foreach ($kv in @(@('TechLevel', '-1'), @('Power', '0'), @('Capturable', 'false'), @('Crewed', 'yes'), @('Sight', '5'), @('ThreatPosed', '0'), @('Cost', '0'), @('Points', '5'), @('ImmuneToVeins', 'yes'))) { $ini.Set($t, $kv[0], $kv[1]) }
    $nb++; $ini.Set('BuildingTypes', ('ARKA6N{0:D2}' -f $nb), $t)
}
$colony = @(
    @('SCCC', 51, 0, 0, 230, 'SCCOMS'), @('SCACAD', 51, 6, -3, 220), @('SCEBAY', 51, -6, -2, 210), @('SCMTUR', 51, 3, 5, 256), @('SCMTUR', 51, -4, 4, 256), @('SCBUNK', 51, 5, 3, 256),
    @('SCSTAR', 52, -4, 0, 220, 'SCCTWR'), @('SCSTAR', 52, 5, -3, 230, 'SCCTWR'), @('SCSCIF', 52, 2, 5, 220, 'SCPHYS'), @('SCDEPO', 52, -6, 5, 240),
    @('SCFACT', 53, 0, -4, 220, 'SCMSHP'), @('SCARMO', 53, -5, 2, 210), @('SCDEPO', 53, 4, 3, 240), @('SCDEPO', 53, -2, 6, 230),
    @('SCDEPO', 50, -5, -3, 240), @('SCDEPO', 50, 5, 3, 240), @('SCDEPO', 50, -4, 5, 230), @('SCDEPO', 50, 6, -4, 240),
    @('SCNGEN', 51, -2, 7, 240), @('SCNGEN', 53, 5, -3, 230), @('SCNSTB', 52, -1, -6, 250))
foreach ($b in $colony) {
    if ($b.Count -gt 5) { Place-WithAddon 'Neutral' $b[0] $b[5] $b[1] $b[2] $b[3] $b[4] }
    else { Place-AtWp 'Neutral' $b[0] $b[1] 0 'None' $b[4] 0 $b[2] $b[3] }
}

# ================================================================ write, render
$ini.Set('Basic', 'Name', 'ARKA #6: Ogien z nieba')
$ini.Set('Basic', 'Author', 'Zema')
[IO.File]::WriteAllText($Out, $ini.Write(), $enc)
$log.Add("written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB): $($structs.Count) buildings")
$log | Set-Content "$work\log.txt" -Encoding UTF8
$log | Select-Object -Last 3
if ($Render) {
    $dir = "$game\Map Editor\Map Renderer"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$Out`" -o arka06_mission -d `"$work`" -p -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "renderer timed out" }
    "render: $work\arka06_mission.png"
}
