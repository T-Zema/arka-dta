# Mission layer of the ARKA campaign prelude "Ostatnia brama" (Gibraltar 1953): houses, the ARKA building, the Allied
# base, starting units, teams, triggers and dialogue. Reads the terrain map built by build-arka-gibraltar.ps1
# (Maps\Custom\arka00_gibraltar.map, read-only; owned by the map session) and writes Maps\Missions\arka00.map.
# Waypoints 10-45 of the terrain map are the contract between the two layers (wiki missions/arka-00-gibraltar).
#
#   powershell -NoProfile -File .\build-arka00-mission.ps1            # build + checks
#   powershell -NoProfile -File .\build-arka00-mission.ps1 -Render    # also render %TEMP%\arka00-mission\*.png
#
# Texts: in-game strings are Windows-1252 and the TS font has no Polish letters, so all dialogue is ASCII Polish.
# Time units: Elapsed Time / Timer Set count game seconds (the on-screen timer); 1500 = 25:00 on the timer.
param(
    [string]$Terrain = "",
    [string]$Out = "",
    [switch]$Render,
    [switch]$NoBattle
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Terrain) { $Terrain = "$game\Maps\Custom\arka00_gibraltar.map" }
if (-not $Out) { $Out = "$game\Maps\Missions\arka00.map" }
$work = "$env:TEMP\arka00-mission"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\TsMap.cs" -ReferencedAssemblies System.Drawing

$ini = [Ini]::Load($Terrain)
$log = New-Object Collections.Generic.List[string]

# ================================================================ terrain occupancy (what may hold a building or unit)
$mixes = New-Object MixSet "$game\MIX"
$th    = New-Object Theater "$game\INI\Temperat.ini", "tem", $mixes
$GW = 512
$code = New-Object 'int[]' ($GW * $GW); for ($i = 0; $i -lt $code.Length; $i++) { $code[$i] = -1 }   # -1 = off map
foreach ($t in [IsoMap]::Decode([Pack]::Unpack($ini.Joined('IsoMapPack5'), $true))) {
    $tile = if ($t.Tile -lt 0 -or $t.Tile -ge 65535) { 0 } else { $t.Tile }
    $tmp = $th.Get($tile); $c = 0
    if ($tmp -and $t.Sub -lt $tmp.Cells.Length -and $tmp.Cells[$t.Sub]) { $c = $tmp.Cells[$t.Sub].Terrain }
    $code[$t.Y * $GW + $t.X] = $c   # DTA terrain is flat (Level 0 everywhere): the Rock's levels are cliff tiles, code 7/8
}
$block = New-Object 'bool[]' ($GW * $GW)
$ovl = [Pack]::Unpack($ini.Joined('OverlayPack'), $false)
for ($i = 0; $i -lt $ovl.Length -and $i -lt $block.Length; $i++) { if ($ovl[$i] -ne 255) { $block[$i] = $true } }
foreach ($kv in $ini.Section('Terrain')) { $v = [int]$kv.Key; $block[[Math]::Floor($v / 1000) * $GW + $v % 1000] = $true }

# foundations from Art.ini (Image= from Rules.ini when present)
$artText = [IO.File]::ReadAllLines("$game\INI\Art.ini"); $rulesText = [IO.File]::ReadAllLines("$game\INI\Rules.ini")
function Find-Key($lines, $sec, $key) {
    $in = $false
    foreach ($l in $lines) {
        if ($l -match '^\[([^\]]+)\]') { if ($in) { break }; $in = $matches[1] -eq $sec; continue }
        if ($in -and $l -match "^$key\s*=\s*([^;\s]+)") { return $matches[1] }
    }
    $null
}
$fcache = @{}
function Foundation($type) {
    if ($fcache.ContainsKey($type)) { return $fcache[$type] }
    $img = Find-Key $rulesText $type 'Image'; if (-not $img) { $img = $type }
    $f = Find-Key $artText $img 'Foundation'
    for ($k = 0; -not $f -and $k -lt 3; $k++) { $img = Find-Key $artText $img '\$Inherits'; if (-not $img) { break }; $f = Find-Key $artText $img 'Foundation' }
    if (-not $f) { $f = '1x1' }
    $p = $f -split 'x'; $fcache[$type] = @([int]$p[0], [int]$p[1]); $fcache[$type]
}
$fcache['ARKACORE'] = @(2, 2); $fcache['AFACT'] = @(3, 3)   # AFACT: $Inherits GFACT -> Image RAFACT (3x3)
foreach ($kv in $ini.Section('Structures')) {
    $p = $kv.Value -split ','; $f = Foundation $p[1]
    for ($dx = 0; $dx -lt $f[0]; $dx++) { for ($dy = 0; $dy -lt $f[1]; $dy++) { $block[([int]$p[4] + $dy) * $GW + [int]$p[3] + $dx] = $true } }
}
# code 11 = road (Paved Roads A/B/C, 2 cells wide): buildable, but searched building plots keep off it ($noRoad)
$noRoad = $false
function Buildable($x, $y) { $c = $code[$y * $GW + $x]; ($c -eq 0 -or ($c -ge 11 -and $c -le 14 -and -not ($script:noRoad -and $c -eq 11))) -and -not $block[$y * $GW + $x] }

# waypoints of the terrain layer
$wp = @{}; foreach ($kv in $ini.Section('Waypoints')) { $v = [int]$kv.Value; $wp[[int]$kv.Key] = @(($v % 1000), [Math]::Floor($v / 1000)) }
foreach ($n in 10..45) { if (-not $wp.ContainsKey($n)) { throw "terrain map has no waypoint $n (contract 10-45 broken)" } }
function WpLetter([int]$n) { $s = ''; $n++; while ($n -gt 0) { $n--; $s = [char](65 + $n % 26) + $s; $n = [Math]::Floor($n / 26) }; $s }

# reserved plots: placement of other buildings keeps out of them
$reserved = New-Object 'bool[]' ($GW * $GW)
function Reserve($cx, $cy, $r) { for ($x = $cx - $r; $x -le $cx + $r; $x++) { for ($y = $cy - $r; $y -le $cy + $r; $y++) { $reserved[$y * $GW + $x] = $true } } }
Reserve $wp[10][0] $wp[10][1] 4
foreach ($n in 11..14) { Reserve $wp[$n][0] $wp[$n][1] 2 }

function Free($x, $y, $w, $h, $m, [bool]$useReserved) {
    for ($i = $x - $m; $i -lt $x + $w + $m; $i++) { for ($j = $y - $m; $j -lt $y + $h + $m; $j++) {
        if (-not (Buildable $i $j)) { return $false }
        if (-not $useReserved -and $reserved[$j * $GW + $i]) { return $false }
    } }
    $true
}
function Occupy($x, $y, $w, $h) { for ($i = $x; $i -lt $x + $w; $i++) { for ($j = $y; $j -lt $y + $h; $j++) { $block[$j * $GW + $i] = $true } } }
# nearest free top-left corner to (tx, ty) within radius 25
function Find-Spot($tx, $ty, $w, $h, $m, [bool]$useReserved) {
    for ($r = 0; $r -le 25; $r++) {
        $best = $null; $bd = 1e9
        for ($x = $tx - $r; $x -le $tx + $r; $x++) { for ($y = $ty - $r; $y -le $ty + $r; $y++) {
            if ([Math]::Max([Math]::Abs($x - $tx), [Math]::Abs($y - $ty)) -ne $r) { continue }
            if (Free $x $y $w $h $m $useReserved) { $d = ($x - $tx) * ($x - $tx) + ($y - $ty) * ($y - $ty); if ($d -lt $bd) { $bd = $d; $best = @($x, $y) } }
        } }
        if ($best) { return $best }
    }
    throw "no free ${w}x$h spot near $tx,$ty"
}

# ================================================================ object writers
$structs = $ini.Section('Structures'); $sIdx = $structs.Count
$units = $ini.Section('Units'); $infs = $ini.Section('Infantry')
function Add-Building($house, $type, $x, $y, $tag = 'None', $sell = 1, $hp = 256) {
    $f = Foundation $type; Occupy $x $y $f[0] $f[1]
    $script:structs.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$script:sIdx", "$house,$type,$hp,$x,$y,64,$tag,$sell,0,1,0,0,None,None,None,0,0"))
    $script:sIdx++; $log.Add("building $house $type @ $x,$y ($($f[0])x$($f[1])) tag=$tag")
}
function Place-Building($house, $type, $tx, $ty, $m = 1, $tag = 'None', $sell = 1) {
    $f = Foundation $type; $script:noRoad = $true
    try { $s = Find-Spot $tx $ty $f[0] $f[1] $m $false } finally { $script:noRoad = $false }
    Add-Building $house $type $s[0] $s[1] $tag $sell
}
function Add-Unit($house, $type, $tx, $ty, $mission = 'Guard', $tag = 'None') {
    $s = Find-Spot $tx $ty 1 1 0 $true; Occupy $s[0] $s[1] 1 1
    $script:units.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$($script:units.Count)", "$house,$type,256,$($s[0]),$($s[1]),64,$mission,$tag,0,-1,0,-1,0,0"))
}
# infantry: up to 3 per cell (sub-cells 1-3)
$infCell = $null; $infSub = 4
function Add-Inf($house, $type, $tx, $ty, $mission = 'Guard', $tag = 'None') {
    if ($script:infSub -gt 3 -or $script:infCell[2] -ne "$tx,$ty") {
        $s = Find-Spot $tx $ty 1 1 0 $true; Occupy $s[0] $s[1] 1 1; $script:infCell = @($s[0], $s[1], "$tx,$ty"); $script:infSub = 1
    }
    $script:infs.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$($script:infs.Count)", "$house,$type,256,$($script:infCell[0]),$($script:infCell[1]),$($script:infSub),$mission,64,$tag,0,-1,0,0,0"))
    $script:infSub++
}
function NewCell($n) { $script:infSub = 4; $null }   # start a fresh cell for the next infantry group

# ================================================================ the ARKA (Giga-Chronosphere): a non-buildable RAPDOX copy
$ini.Set('BuildingTypes', 'ARKA0B1', 'ARKACORE')
$arka = [ordered]@{
    Name = 'ARKA (Giga-Chronosfera)'; Image = 'RAPDOX'; Nominal = 'yes'; Strength = '20000'; Armor = 'heavy'
    TechLevel = '-1'; Adjacent = '1'; Sight = '10'; Owner = 'Allies'; Cost = '2800'; Points = '28'; Power = '-200'
    Capturable = 'false'; Crewed = 'yes'; Unsellable = 'yes'; Explosion = 'FBALL1,FBALL2,FBALL3'
    ScrapExplosion = 'FBALL1_SCRAP,FBALL2_SCRAP,FBALL3_SCRAP'; MaxDebris = '0'
    DamageParticleSystems = 'SmallGreySSys,BigGreySmokeSys'; Powered = 'yes'; AIBuildThis = 'no'; ClickRepairable = 'no'
}
foreach ($k in $arka.Keys) { $ini.Set('ARKACORE', $k, $arka[$k]) }

# ================================================================ houses
$ini.Sections.Remove('Houses') | Out-Null; $ini.Order.Remove('Houses') | Out-Null
$hl = 'GDI', 'Nod', 'Allies', 'Soviet', 'Neutral', 'Special', 'GDI1', 'Nod1', 'GDI2', 'Nod2', 'Allies1', 'Allies2', 'Soviet1', 'Soviet2'
for ($i = 0; $i -lt $hl.Count; $i++) { $ini.Set('Houses', "$i", $hl[$i]) }
$H = @{ Allies = 2; Soviet = 3; Nod = 1; Neutral = 4; Nod2 = 9; Allies1 = 10 }
function House($name, $side, $color, $allies, $credits, $actsLike, $player, $edge = 'North', $iq = 5) {
    $v = [ordered]@{ IQ = $iq; Edge = $edge; Side = $side; Color = $color; Allies = $allies; Credits = $credits; ActsLike = $actsLike
        NodeCount = 0; TechLevel = 10; PercentBuilt = 100; PlayerControl = $player }
    foreach ($k in $v.Keys) { $ini.Set($name, $k, "$($v[$k])") }
}
House 'Allies'  'AlliesSide'  'AlliedBlue' 'Allies,Allies1,Nod2'            100 2 'yes' 'South' 0
House 'Soviet'  'SovietSide'  'DarkRed'    'Soviet,Nod,Allies1,Special,Nod2' 0  3 'no'
House 'Nod'     'NodSide'     'Metallic'   'Nod,Soviet,Allies1,Special,Nod2' 0  1 'no'
# Nod2 = the Nod agent alone: allied to everyone, so nobody targets him on the way to the core (user 2026-10-27);
# the "infiltration" is a cell-tag ring round the ARKA, not a real spy entry (script 15,N did nothing in the test)
House 'Nod2'    'NodSide'     'Metallic'   'Nod2,Allies,Soviet,Nod,Special' 0   1 'no'
House 'Neutral' 'CivilianSide' 'Grey'      'Neutral'                        0   4 'no'
House 'Special' 'SpecialSide' 'Grey'       'Special'                        0   5 'no'
# Allies1 = Tanya before the rescue: allied to everyone, so the Soviet guards ignore her until she joins the player
House 'Allies1' 'AlliesSide'  'Gold'       'Allies1,Allies,Soviet,Nod'      0   2 'no'

# ================================================================ base: ARKA, 4 power plants, the core of an Allied base
$ax = $wp[10][0]; $ay = $wp[10][1]
$tags = $ini.Section('Tags')   # filled below; objects only need the tag id
# on the waypoint when the footprint is free; after a terrain rebuild moved things, the nearest free spot (WARN)
function Place-OnWaypoint($type, $x, $y, $tag) {
    $f = Foundation $type
    if (-not (Free $x $y $f[0] $f[1] 0 $true)) { $s = Find-Spot $x $y $f[0] $f[1] 0 $true; $log.Add("WARN $type moved from $x,$y to $($s[0]),$($s[1]) (footprint blocked)"); $x = $s[0]; $y = $s[1] }
    Add-Building 'Allies' $type $x $y $tag 0
}
Place-OnWaypoint 'ARKACORE' ($ax - 1) ($ay - 1) 'ARKA0G01'
for ($k = 1; $k -le 4; $k++) { $p = $wp[10 + $k]; Place-OnWaypoint 'RAPOWR' ($p[0] - 1) ($p[1] - 1) ("ARKA0G0" + (1 + $k)) }
# west of the ARKA (screen west = -x +y), north-west for the factories, refinery towards the airfield ore
Place-Building 'Allies' 'AFACT'  ($ax - 8)  ($ay + 4)
Place-Building 'Allies' 'RATENT' ($ax - 5)  ($ay - 8)
Place-Building 'Allies' 'RAPROC' ($ax - 14) ($ay - 6)
Place-Building 'Allies' 'AWEAP'  ($ax - 12) ($ay + 10)
Place-Building 'Allies' 'RADOME' ($ax - 2)  ($ay + 8)
# gate defences: two pillboxes and a turret just inside each gate (towards the base)
foreach ($g in 15, 16) {
    $gx = $wp[$g][0]; $gy = $wp[$g][1]
    Place-Building 'Allies' 'RAPBOX' ($gx + 1) ($gy + 4) 0
    Place-Building 'Allies' 'RAPBOX' ($gx + 4) ($gy + 1) 0
    Place-Building 'Allies' 'RAGUN'  ($gx + 3) ($gy + 3) 0
}

# reveal-map crate by the Construction Yard (cell kept free here, the overlay and its trigger are written by
# Add-RevealCrate once the trigger DSL exists)
$script:noRoad = $true
try { $crate = Find-Spot ($ax - 5) ($ay + 1) 1 1 0 $false } finally { $script:noRoad = $false }
Occupy $crate[0] $crate[1] 1 1

# starting force around the ARKA; a refinery placed in the map comes without its free Ore Truck (user test 2026-10-27)
Add-Unit 'Allies' 'RAHARV' ($ax - 12) ($ay - 2) 'Harvest'
foreach ($t in '2TNK', '2TNK', '2TNK', '1TNK', '1TNK', 'RANG') { Add-Unit 'Allies' $t ($ax - 6) ($ay - 3) }
NewCell 0; foreach ($t in 'E1', 'E1', 'E1', 'E1', 'E1', 'E1') { Add-Inf 'Allies' $t ($ax - 3) ($ay + 4) }
NewCell 0; foreach ($t in 'E3', 'E3', 'E3', 'MEDIC', 'ENGINEER') { Add-Inf 'Allies' $t ($ax + 1) ($ay + 5) }
# Tanya behind enemy lines (La Linea park, wp 17) and her Soviet guards
$tx = $wp[17][0]; $ty = $wp[17][1]
NewCell 0; Add-Inf 'Allies1' 'TANYA' $tx $ty 'Sleep' 'ARKA0G11'   # tag: her line on reaching the ARKA (trigger tanyaHome)
NewCell 0; foreach ($t in 'E1', 'E1', 'E2', 'DOG') { Add-Inf 'Soviet' $t ($tx + 4) ($ty + 2) 'Area Guard' }
NewCell 0; foreach ($t in 'E1', 'E3', 'DOG') { Add-Inf 'Soviet' $t ($tx - 3) ($ty + 4) 'Area Guard' }
Add-Unit 'Soviet' '3TNK' ($tx + 2) ($ty + 6) 'Area Guard'
# rescue zone: cell tags in a radius of 3 around Tanya
$ct = $ini.Section('CellTags')
for ($x = $tx - 3; $x -le $tx + 3; $x++) { for ($y = $ty - 3; $y -le $ty + 3; $y++) { if ($code[$y * $GW + $x] -ge 0) { $ini.Set('CellTags', "$($y * 1000 + $x)", 'ARKA0G10') } } }

# ================================================================ dialogue ([Tutorial] of the map, numbers 9000-9099 = mission 0)
$textNo = 9000
function Say([string]$s) { $script:textNo++; $ini.Set('Tutorial', "$script:textNo", $s); $script:textNo }

# ================================================================ taskforces, scripts, teams
$tfN = 0; $scN = 0; $tmN = 0
function Team($name, $house, $spawnWp, [string[]]$members, [string[]]$script) {
    $script:tfN++; $script:scN++; $script:tmN++
    $tf = 'ARKA0F{0:D2}' -f $script:tfN; $sc = 'ARKA0S{0:D2}' -f $script:scN; $tm = 'ARKA0M{0:D2}' -f $script:tmN
    $ini.Set('TaskForces', "$($script:tfN - 1)", $tf); $ini.Set('ScriptTypes', "$($script:scN - 1)", $sc); $ini.Set('TeamTypes', "$($script:tmN - 1)", $tm)
    $grp = @($members | Group-Object | ForEach-Object { "$($_.Count),$($_.Name)" })   # @(): one type must stay an array
    for ($i = 0; $i -lt $grp.Count; $i++) { $ini.Set($tf, "$i", $grp[$i]) }
    $ini.Set($tf, 'Name', $name); $ini.Set($tf, 'Group', '-1')
    for ($i = 0; $i -lt $script.Count; $i++) { $ini.Set($sc, "$i", $script[$i]) }
    $ini.Set($sc, 'Name', $name)
    $v = [ordered]@{ Max = 0; Full = 'no'; Name = $name; Group = -1; House = $house; Script = $sc; Whiner = 'no'; Droppod = 'no'; Suicide = 'no'
        Loadable = 'no'; Prebuild = 'no'; Priority = 5; Waypoint = (WpLetter $spawnWp); Annoyance = 'no'; IonImmune = 'no'; Recruiter = 'no'
        Reinforce = 'no'; TaskForce = $tf; TechLevel = 0; Aggressive = 'no'; Autocreate = 'no'; GuardSlower = 'no'; OnTransOnly = 'no'
        AvoidThreats = 'no'; LooseRecruit = 'no'; VeteranLevel = 1; IsBaseDefense = 'no'; OnlyTargetHouseEnemy = 'no'
        TransportsReturnOnUnload = 'no'; AreTeamMembersRecruitable = 'no' }
    foreach ($k in $v.Keys) { $ini.Set($tm, $k, "$($v[$k])") }
    $tm
}
# script lines: 3,N move to waypoint N; 5,N guard N x 6 s; 16,N patrol (attack-move) to waypoint N; 11,14 hunt;
# 8,2 unload (transport leaves the team); 15,N spy on the building at waypoint N.
# NOT 1,N (attack waypoint) for ground teams: in DTA missions only aircraft use it, and in the user test of 2026-10-27
# every ground team stopped for good at that line (Soviets gathered at the border, landings and Stealth Tanks idle).
# gather at the border crossing, wait ~24 s, attack-move on the ARKA, hunt: only for the infantry of wave 1. A move
# (3,N) ends when EVERY member stands at the waypoint, and a crowd of big tanks never fits round one cell: wave 5
# (Mammoths, Tesla Tanks, V2) waited at the muster to the end of the mission (user test 2026-10-27). Vehicle waves go
# straight for the ARKA.
$north = '3,20', '5,4', '16,10', '11,14'
$ne    = '3,21', '5,4', '16,10', '11,14'
$direct = '16,10', '11,14'
$east  = '3,22', '16,25', '16,33', '16,10', '11,14'   # the east lane round the Rock (Stealth Tanks)
$land  = { param($beach) "3,$beach", '8,2', "16,10", '11,14' }   # NLST landing: sail to the beach, unload, attack
# wave 1 is the "infantry crossing the border" of Stavros' line: infantry only (user 2026-10-27: the tank was out of
# place, +5 riflemen +3 grenadiers instead)
$tmS1 = Team 'Sowieci fala 1'  'Soviet' 18 @('E1', 'E1', 'E1', 'E1', 'E1', 'E1', 'E1', 'E1', 'E1', 'E2', 'E2', 'E2', 'E2', 'E2') $north
$tmS2 = Team 'Sowieci fala 2'  'Soviet' 19 @('3TNK', '3TNK', 'E3', 'E3', 'E3', 'DOG', 'DOG') $direct
$tmS3 = Team 'Sowieci fala 3'  'Soviet' 18 @('3TNK', '3TNK', '3TNK', 'V2RL', 'V2RL') $direct
$tmS4 = Team 'Sowieci fala 4'  'Soviet' 19 @('4TNK', '3TNK', '3TNK', 'SHOK', 'SHOK', 'E4S', 'E4S') $direct
$tmS5 = Team 'Sowieci fala 5'  'Soviet' 18 @('4TNK', '4TNK', 'V2RL', 'V2RL', 'TTNK', 'TTNK') $direct
# the final assault goes straight for the ARKA: no muster, no wait (user: it gathered too slowly)
$tmS6 = Team 'Sowieci szturm'  'Soviet' 19 @('4TNK', '4TNK', '3TNK', '3TNK', '3TNK', 'E1', 'E1', 'E1', 'E1', 'E4S', 'E4S', 'E4S') @('16,10', '11,14')
# one strafing run, then back over the Spanish border and off the map (DTA air-strike pattern: attack | 3,exit | 37,0):
# with Hunt after the attack the Yaks (Ammo=1) hovered over the base for good, there is no Soviet airfield to rearm at
$tmAir = Team 'Sowieckie Jaki' 'Soviet' 18 @('YAK', 'YAK') @('1,10', '3,18', '37,0')
$tmN2 = Team 'Nod Stealth pas wschodni' 'Nod' 22 @('STNK', 'STNK', 'STNK') $east
$tmAgent = Team 'Agent Nod'             'Nod2' 26 @('SPY') @('3,10', '11,10')
# Nod lands only with real transports (pattern of cr06; no hovercraft, user 2026-10-27): the NLST is the first member
# of the taskforce and the reinforcement spawns it loaded with the rest. Sea waypoint -> beach: 41 -> 26 Camp Bay,
# 45 -> 23 Eastern Beach, 42 -> 24 Catalan Bay, 43 -> 27 Europa Point. The map raises NLST to 10 passengers.
$ini.Set('NLST', 'Passengers', '10')
# the agent must be visible: a disguised spy looks exactly like one of the player's own soldiers (user did not see him)
$ini.Set('SPY', 'Disguised', 'no')
$nodInf = @('E1', 'E1', 'E1', 'E1', 'E3', 'E3', 'E3', 'E4', 'E4', 'E4')   # minigunners, rocket and flame infantry
$tmI1 = Team 'Nod piechota Camp Bay'      'Nod' 41 (@('NLST') + $nodInf) (& $land 26)
$tmI2 = Team 'Nod piechota Catalan Bay'   'Nod' 42 (@('NLST') + $nodInf) (& $land 24)
$tmI3 = Team 'Nod piechota Europa Point'  'Nod' 43 (@('NLST') + $nodInf) (& $land 27)
$tmI4 = Team 'Nod piechota Eastern Beach' 'Nod' 45 (@('NLST') + $nodInf) (& $land 23)

# ================================================================ triggers
$trN = 0; $trig = [ordered]@{}
$ini.Set('VariableNames', '0', 'Tanya uratowana,0'); $ini.Set('VariableNames', '1', 'Final,0')
function Ev([int]$id, $p = 0) { "$id,0,$p" }
function Act([int]$id, $p = 0, [int]$kind = 0, [int]$w = 0) { "$id,$kind,$p,0,0,0,0,$(WpLetter $w)" }
function Text($s) { Act 11 (Say $s) }
function Reinf($team, $w) { Act 80 $team 1 $w }
function Enable($t) { Act 53 $t 2 }
function Disable($t) { Act 54 $t 2 }
# -link: the [Triggers] "linked" field. An object carries one tag, and its trigger passes the object's events on to
# the linked trigger too, so one object can drive several triggers (DTA: cra12 "Radar captured" -> "Radar destroyed")
function Trigger($key, $name, [string[]]$events, [string[]]$actions, $house = 'Allies', [switch]$Disabled, [switch]$Repeat, $tag = $null, $link = $null) {
    $script:trN++; $id = 'ARKA0T{0:D2}' -f $script:trN
    $name = $name -replace ',', ' -'   # names are a comma-separated field of [Triggers]/[Tags]
    if (-not $tag) { $tag = 'ARKA0G{0:D2}' -f (20 + $script:trN) }
    $script:trig[$key] = @{ Id = $id; Name = $name; House = $house; Events = $events; Actions = $actions; Disabled = [bool]$Disabled; Repeat = [bool]$Repeat; Tag = $tag; Link = $link }
    $id
}
# ids are needed before the triggers that enable them are written, so reserve them in order of use
$ids = @{}
foreach ($k in 'intro2', 'intro3', 'intro4', 'intro5', 'tanya2', 'tanya3', 'tanya4', 'fin1', 'fin2', 'fin3', 'fin4', 'fin5', 'fin6', 'fin7', 'fin8') { $ids[$k] = $null }
. "$tools\MissionKit.ps1"   # reveal crate, one text per trigger, dialogue gaps from text length, timeline check
Add-RevealCrate $crate[0] $crate[1]

# vehicle landings. Vehicles carried inside an NLST never came out (user tests 2026-10-27: two loaded transports
# stood on Eastern Beach; at Camp Bay the few that left stood idle), infantry unloads fine. So the NLST sails to the
# beach empty and the vehicles appear next to it on arrival: a cell-tag zone round the beach waypoint (Entered by Nod),
# with a time fallback 150 s after the launch in case the zone never fires. Two landings on one beach use separate
# zones: the inner one (r 0-1) and the ring r 2-3 that the transport crosses just before it beaches. The empty
# transport then sails back to its sea waypoint and leaves (37 = delete team members).
function Landing($key, $name, [int]$at, [int]$sea, [int]$beach, [string[]]$cargo, [int]$rMin, [int]$rMax, $text = $null) {
    $tmT = Team "$name (transport)" 'Nod' $sea @('NLST') @("3,$beach", '5,1', "3,$sea", '37,0')
    $tmC = Team "$name (ladunek)" 'Nod' $beach $cargo @('16,10', '11,14')
    $acts = @((Reinf $tmT $sea), (Act 55 3 0 $beach), (Enable "$key-in"), (Enable "$key-late"))
    if ($text) { $acts += Text $text }
    Trigger $key $name @((Ev 13 $at)) $acts | Out-Null
    Trigger "$key-in" "$name - wyladunek" @((Ev 1 $H.Nod)) @((Reinf $tmC $beach), (Disable "$key-late")) -Disabled | Out-Null
    Trigger "$key-late" "$name - wyladunek (czas)" @((Ev 13 150)) @((Reinf $tmC $beach), (Disable "$key-in")) -Disabled | Out-Null
    $bx = $wp[$beach][0]; $by = $wp[$beach][1]; $n = 0
    for ($x = $bx - $rMax; $x -le $bx + $rMax; $x++) { for ($y = $by - $rMax; $y -le $by + $rMax; $y++) {
        $d = [Math]::Max([Math]::Abs($x - $bx), [Math]::Abs($y - $by))
        if ($d -ge $rMin -and $d -le $rMax -and $code[$y * $GW + $x] -ge 0) { $ini.Set('CellTags', "$($y * 1000 + $x)", $trig["$key-in"].Tag); $n++ }
    } }
    $log.Add("landing $key at ${at}s: wp $sea -> $beach, zone r $rMin-$rMax ($n cells), cargo $($cargo -join ' ')")
}

# --- opening: von Esling's briefing, objectives, timer 25:00
Trigger 'intro' 'Start: kamera i von Esling' @((Ev 13 1)) @(
    (Act 48 1 0 10), (Act 20 58),
    (Text 'Gen. von Esling: Komandorze, ARKA potrzebuje 25 minut ladowania. Sowieci ida od strony Hiszpanii, Nod od morza.'),
    (Enable 'intro2')) | Out-Null
Trigger 'intro2' 'Start 2: zamknac drzwi' @((Ev 13 7)) @(
    (Text 'Gen. von Esling: Gdy rdzen osiagnie pelna moc, wszyscy w polu Chronosfery znikna stad. Ja zostaje. Ktos musi zamknac drzwi.'),
    (Enable 'intro3')) -Disabled | Out-Null
Trigger 'intro3' 'Start 3: cele i licznik' @((Ev 13 8)) @(
    (Text 'Cel glowny: utrzymaj ARKE do konca odliczania. Zniszczenie ARKI = porazka.'),
    (Act 27 1500), (Act 23), (Act 17 10),
    (Enable 'intro4')) -Disabled | Out-Null
Trigger 'intro4' 'Start 4: elektrownie' @((Ev 13 6)) @(
    (Text 'Cel: chron 4 elektrownie zasilajace rdzen. Kazda utracona wydluza ladowanie.'),
    (Enable 'intro5')) -Disabled | Out-Null
Trigger 'intro5' 'Start 5: Tanya za liniami' @((Ev 13 12)) @(
    (Text 'Plk Stavros: Tanya Adams zostala zrzucona za liniami wroga, w parku w La Linea. Podobno niesie cos waznego.'),
    (Text 'Cel dodatkowy: odbij Tanye w La Linea (polnocny wschod, za granica).'),
    (Act 55 6 0 17), (Act 17 17)) -Disabled | Out-Null

# --- losing: the ARKA (destroyed, not infiltrated: the Nod agent is allowed to reach it) or everything
Trigger 'arkaLost' 'ARKA zniszczona' @((Ev 29)) @(
    (Text 'Einstein: Rdzen... rdzen jest zniszczony. Nikt stad nie odleci.'), (Act 2 $H.Allies)) -tag 'ARKA0G01' | Out-Null
Trigger 'allLost' 'Wszystko stracone' @((Ev 11 $H.Allies)) @((Act 2 $H.Allies)) | Out-Null

# --- power plants: each loss adds a minute to the countdown
for ($k = 1; $k -le 4; $k++) {
    Trigger "pp$k" "Elektrownia $k stracona" @((Ev 29)) @(
        (Text "Einstein: Stracilismy elektrownie $k! Rdzen traci moc, ladowanie wydluza sie o minute."),
        (Act 25 60), (Act 55 4 0 (10 + $k))) -tag ("ARKA0G0" + (1 + $k)) | Out-Null
}

# --- Tanya: rescued (cell tags round wp 17) or breaks out alone at 15:00
Trigger 'tanya' 'Tanya odbita' @((Ev 1 $H.Allies)) @(
    (Act 36 $H.Allies), (Act 56 0),
    (Text 'Tanya: Najwyzszy czas, Komandorze! Mam cos z sowieckiej kwatery: dokument Nod.'),
    (Disable 'tanyaAlone'), (Enable 'tanyaJoke'), (Enable 'tanyaArm')) -house 'Allies1' -tag 'ARKA0G10' | Out-Null
Trigger 'tanyaJoke' 'Tanya: klop i drzewa' @((Ev 13 7)) @(
    (Text 'Tanya: Klop, drzewo, drugie drzewo, trzecie drzewo... Tarzan by sie zarumienil. Gdzie moj prysznic?'), (Enable 'tanya2')) -Disabled | Out-Null
Trigger 'tanya2' 'Tanya 2: dokument' @((Ev 13 7)) @(
    (Text 'Tanya: Kane wie o ARCE. I chce, zeby wystartowala.'), (Enable 'tanya3')) -Disabled | Out-Null
Trigger 'tanya3' 'Tanya 3: Einstein' @((Ev 13 7)) @(
    (Text 'Einstein: Nod chce, zebysmy uciekli? To nie ma sensu... Kim jest ten Kane?'), (Enable 'tanya4')) -Disabled | Out-Null
Trigger 'tanya4' 'Tanya 4: zdjecie' @((Ev 13 7)) @(
    (Text 'Tanya: Mamy jedno zdjecie, profesorze. Nic wiecej. Wywiad nie wie nawet, skad sie wzial.')) -Disabled | Out-Null
# Tanya reaches the base: event 34 (attached object comes near a waypoint) on her own tag, waypoint 10 = the ARKA.
# Only she carries the tag, so other units at the base do not fire it; before the rescue she sleeps in La Linea.
# Her tag also has to report her death, and one object has one tag: tanyaHome is linked to tanyaDead. The tag is
# repeating (a one-time tag is dropped from the object once its trigger fires, and the link would go with it), so
# tanyaHome switches itself off after its line.
Trigger 'tanyaHome' 'Tanya w bazie' @((Ev 34 10)) @(
    (Text 'Tanya: Ruscy przeszukali caly park, tylko nie klop i nie korony drzew. Nikt nie patrzy w gore. Zupelnie jak swinie.'),
    (Disable 'tanyaHome')) -tag 'ARKA0G11' -Repeat -link 'tanyaDead' | Out-Null
# Tanya killed = mission failed (user test 2026-10-27: nothing happened). The house change that hands her to the player
# counts as a capture, which fires "destroyed" on her tag (pitfall 6), so tanyaDead is armed only 5 s after it.
Trigger 'tanyaDead' 'Tanya zginela' @((Ev 29)) @(
    (Text 'Plk Stavros: Tanya nie zyje! Stracilismy najlepszego agenta Aliantow... Misja nieudana.'), (Act 2 $H.Allies)) -Disabled | Out-Null
Trigger 'tanyaArm' 'Tanya: uzbroj porazke' @((Ev 13 5)) @((Enable 'tanyaDead')) -Disabled | Out-Null
Trigger 'tanyaAlone' 'Tanya przebija sie sama' @((Ev 13 900), (Ev 37 0)) @(
    (Act 36 $H.Allies),
    (Text 'Tanya: Nie czekam dluzej, przebijam sie sama! Dokument przepadl, ale wracam.'),
    (Act 55 6 0 17), (Disable 'tanya'), (Enable 'tanyaArm')) -house 'Allies1' | Out-Null

# --- waves (elapsed game seconds from the start; the timer starts at about 0:30)
Trigger 'w1' 'Fala 1: Sowieci z polnocy' @((Ev 13 210)) @(   # after the opening dialogue (ends ~200 s)
    (Reinf $tmS1 18), (Act 20 43), (Act 55 3 0 20),
    (Text 'Plk Stavros: Sowiecka piechota przekracza granice! Ida na Landport.')) | Out-Null
Trigger 'w2' 'Fala 2: Sowieci NE' @((Ev 13 300)) @((Reinf $tmS2 19), (Act 55 3 0 21)) | Out-Null
Landing 'n1' 'Nod 1: artyleria Camp Bay' 420 41 26 @('AIARTY', 'AIARTY', 'AILTNK', 'AILTNK', 'AIBGGY', 'AIBGGY') 0 1 `
    'Plk Stavros: Transportowiec Nod w zatoce! Wiezie artylerie na plaze Camp Bay, od poludnia miasta.'
Trigger 'i1' 'Nod: piechota Camp Bay' @((Ev 13 540)) @(
    (Reinf $tmI1 41), (Act 55 3 0 26), (Text 'EVA: Desant piechoty Nod na Camp Bay.')) | Out-Null
Trigger 'i2' 'Nod: piechota Catalan Bay' @((Ev 13 840)) @(
    (Reinf $tmI2 42), (Act 55 3 0 24), (Text 'EVA: Desant piechoty Nod w Catalan Bay, po wschodniej stronie Skaly.')) | Out-Null
Trigger 'i3' 'Nod: piechota Europa Point' @((Ev 13 1200)) @(
    (Reinf $tmI3 43), (Act 55 3 0 27), (Text 'EVA: Desant piechoty Nod na Europa Point.')) | Out-Null
Trigger 'i4' 'Nod: piechota Eastern Beach' @((Ev 13 1310)) @((Reinf $tmI4 45), (Act 55 3 0 23)) | Out-Null
Trigger 'w3' 'Fala 3: Sowieci, V2' @((Ev 13 480)) @((Reinf $tmS3 18), (Act 55 3 0 20)) | Out-Null
Trigger 'air1' 'Jaki nad baza' @((Ev 13 600)) @((Reinf $tmAir 18), (Text 'EVA: Sowieckie lotnictwo nadlatuje od polnocy.')) | Out-Null
Trigger 'w4' 'Fala 4: Sowieci, Mamut' @((Ev 13 720)) @((Reinf $tmS4 19), (Act 55 3 0 21)) | Out-Null
Trigger 'half' 'Polowa ladowania' @((Ev 13 780)) @((Text 'Einstein: Rdzen naladowany w polowie. Prosze ich jeszcze chwile powstrzymac, Komandorze.')) | Out-Null
Trigger 'n2' 'Nod 2: Stealth na pasie wschodnim' @((Ev 13 960)) @(
    (Reinf $tmN2 22),
    (Text 'Einstein: Czujniki rdzenia lapia zaklocenia na wschodnim pasie pod Skala. Cos tam jedzie, czego nie widac.')) | Out-Null
# w5 at 900: 2 min earlier than first planned (user)
Trigger 'w5' 'Fala 5: Sowieci, Tesla' @((Ev 13 900)) @((Reinf $tmS5 18), (Act 55 3 0 20)) | Out-Null
Landing 'n3' 'Nod 3: artyleria Eastern Beach' 1140 45 23 @('AIARTY', 'AIARTY', 'AIARTY', 'AILTNK', 'AILTNK') 2 3
Trigger 'w6' 'Fala 6: sowiecki szturm' @((Ev 13 1260)) @(
    (Reinf $tmS6 19), (Reinf $tmAir 18), (Act 55 3 0 21),
    (Text 'Plk Stavros: Piec minut do skoku! Wszystko, co maja, idzie na nas. Wszystkie jednostki do obwodu ARKI!')) | Out-Null
# 1110: at 1350 the spy (speed 5, ~100 cells from Camp Bay to the ARKA) could not arrive before the jump
Trigger 'agent' 'Agent Nod' @((Ev 13 1110)) @(
    (Reinf $tmAgent 26), (Act 55 6 0 26), (Act 17 26), (Enable 'agentIn'),
    (Text 'Einstein: Komandorze, agent Nod na plazy Camp Bay idzie prosto do rdzenia! Czujniki widza go jako... naszego zolnierza?')) | Out-Null
# the agent at the core: a ring of cell tags round the ARKA, armed only once the agent is on the map (the ARKA's own tag
# already carries the defeat trigger, and one tag drives one trigger). Entering it = "inside the core": a flash, the
# team is disbanded (5 Destroy Team) and the agent turns hostile: Nod2 is allied to everyone, so until now nobody could
# shoot him (user test 2026-10-27). The trigger is owned by Nod2, so 36 All change house moves only him to Nod.
Trigger 'agentIn' 'Agent Nod przy rdzeniu' @((Ev 1 $H.Nod2)) @(
    (Act 65 10), (Act 5 $tmAgent 1), (Act 36 $H.Nod), (Act 55 6 0 10),
    (Text 'Einstein: Ten zolnierz byl w rdzeniu! Odczyty krysztalu skacza, ale ladowanie trwa. Zlapcie go, zanim ucieknie!')) -house 'Nod2' -Disabled | Out-Null
for ($x = $ax - 3; $x -le $ax + 2; $x++) { for ($y = $ay - 3; $y -le $ay + 2; $y++) {
    if ($x -ge $ax - 1 -and $x -le $ax -and $y -ge $ay - 1 -and $y -le $ay) { continue }   # the ARKA's own 2x2
    if ($code[$y * $GW + $x] -ge 0) { $ini.Set('CellTags', "$($y * 1000 + $x)", $trig['agentIn'].Tag) }
} }
Landing 't1' 'Nod: transportowiec Camp Bay' 660 41 26 @('AIBIKE', 'AIBIKE', 'AIBGGY', 'AIBGGY', 'AILTNK', 'AILTNK') 2 3 `
    'Plk Stavros: Transportowiec Nod wplywa do zatoki! Wiezie motocykle, buggy i lekkie czolgi na plaze Camp Bay.'
Landing 't2' 'Nod: transportowiec Eastern Beach' 1080 45 23 @('AIBIKE', 'AIBIKE', 'AIBIKE', 'AIBGGY', 'AILTNK', 'AILTNK') 0 1 `
    'EVA: Desant Nod na Eastern Beach.'
# (the repeating objective reminder is gone: every 600 s it landed on top of other lines)

# --- finale: timer expired -> jump sequence -> victory
Trigger 'fin0' 'Final: licznik zero' @((Ev 14)) @(
    (Disable 'arkaLost'), (Disable 'allLost'), (Disable 'tanyaArm'), (Disable 'tanyaDead'), (Act 56 1), (Act 46), (Act 48 1 0 10),
    (Text 'EVA: Rdzen ARKI: moc 100 procent. Sekwencja skoku rozpoczeta.'), (Enable 'fin1')) | Out-Null
Trigger 'fin1' 'Final 1' @((Ev 13 5)) @((Text 'Einstein: Wektor czasowy: minus siedem lat... Stavros, prosze odczytac moj zapis.'), (Enable 'fin2')) -Disabled | Out-Null
Trigger 'fin2' 'Final 2' @((Ev 13 6)) @((Text 'Plk Stavros: Plus siedem, profesorze.'), (Enable 'fin3')) -Disabled | Out-Null
Trigger 'fin3' 'Final 3' @((Ev 13 5)) @((Text 'Einstein: ...Plus? Nie, nie, to niemozliwe. Siedem lat do przodu to bylby tylko wstyd, ale...'), (Enable 'fin4')) -Disabled | Out-Null
Trigger 'fin4' 'Final 4: krysztal' @((Ev 13 6)) @(
    (Act 65 10), (Text 'Moc rdzenia skacze o 4000 procent. Krysztal w rdzeniu jarzy sie na zielono.'), (Enable 'fin5')) -Disabled | Out-Null
Trigger 'fin5' 'Final 5: konsola' @((Ev 13 6)) @(
    (Text 'Konsola: ROK DOCELOWY: 2499 | WSPOLRZEDNE: BRAK DOPASOWANIA | WSZECHSWIAT: ???'), (Enable 'fin6')) -Disabled | Out-Null
Trigger 'fin6' 'Final 6: von Esling' @((Ev 13 6)) @(
    (Text 'Gen. von Esling (ostatnia transmisja): Komandorze... gdziekolwiek traficie, nie przegrajcie tej wojny drugi raz.'), (Enable 'fin7')) -Disabled | Out-Null
# fin7 has no text, so the pacing pass does not stretch it: the wait for von Esling's last line is written here
Trigger 'fin7' 'Final 7: blysk' @((Ev 13 (Get-ReadSecs @($ini.Get('Tutorial', "$textNo", ''))))) @((Act 66 10), (Act 64 10), (Enable 'fin8')) -Disabled | Out-Null
Trigger 'fin8' 'Final 8: wygrana' @((Ev 13 10)) @((Act 1 $H.Allies)) -Disabled | Out-Null

Split-MultiText; Set-DialoguePacing
$textWarn = Test-TextTimeline

# resolve symbolic trigger references ('intro2' -> ARKA0Txx) and write [Triggers]/[Events]/[Actions]/[Tags]
$idOf = @{}; foreach ($k in $trig.Keys) { $idOf[$k] = $trig[$k].Id }
foreach ($k in $trig.Keys) {
    $t = $trig[$k]
    $acts = foreach ($a in $t.Actions) { $p = $a -split ','; if ($p[1] -eq '2') { if (-not $idOf.ContainsKey($p[2])) { throw "unknown trigger '$($p[2])' in $k" }; $p[2] = $idOf[$p[2]] }; $p -join ',' }
    $lnk = if ($t.Link) { if (-not $idOf.ContainsKey($t.Link)) { throw "unknown linked trigger '$($t.Link)' in $k" }; $idOf[$t.Link] } else { '<none>' }
    $ini.Set('Triggers', $t.Id, "$($t.House),$lnk,$($t.Name),$([int]$t.Disabled),1,1,1,0")
    $ini.Set('Events', $t.Id, "$($t.Events.Count)," + ($t.Events -join ','))
    $ini.Set('Actions', $t.Id, "$(@($acts).Count)," + (@($acts) -join ','))
    $ini.Set('Tags', $t.Tag, "$(if ($t.Repeat) { 2 } else { 0 }),$($t.Name) 1,$($t.Id)")
}

# ================================================================ [Basic], briefing
$basic = [ordered]@{
    Name = 'ARKA #0: Ostatnia brama'; Author = 'Zema'; GameMode = 'Custom Map'; Player = 'Allies'; Theme = 'AWAIT'
    MultiplayerOnly = 'no'; HomeCell = '10'; AltHomeCell = '10'; MaxPlayer = '0'; MinPlayer = '2'; SkipMapSelect = 'yes'
    OneTimeOnly = 'yes'; EndOfGame = 'no'; SkipScore = 'no'; FreeRadar = 'yes'; RequiredAddOn = '1'; NextScenario = ''; AltNextScenario = ''
}
foreach ($k in $basic.Keys) { $ini.Set('Basic', $k, $basic[$k]) }
$brief = @(
    'Gibraltar, 1953. Alianci przegrali wojne. Londyn padl, a sowiecko-nodyjski walec stoi u bram Twierdzy.',
    '@@Pod Skala prof. Einstein konczy Projekt ARKA: Giga-Chronosfere, ktora przeniesie cala baze z ludzmi w przeszlosc.',
    '@@Rdzen potrzebuje 25 minut ladowania. Utrzymaj ARKE i 4 elektrownie, ktore ja zasilaja. Sowieci nadejda z Hiszpanii, Nod od morza.')
for ($i = 0; $i -lt $brief.Count; $i++) { $ini.Set('Briefing', "$($i + 1)", $brief[$i]) }
$ini.Set('SpecialFlags', 'Visceroids', 'no')

[IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))
$log.Add("written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB): $($trig.Count) triggers, $tmN teams, $($textNo - 9000) texts, $($units.Count) units, $($infs.Count) infantry")

# ================================================================ client entry (INI\BattleE.ini, the client's extra battle file)
if (-not $NoBattle) {
    $battle = @"
; ARKA campaign (Claude, Modding/wiki/plans/campaign-arka). Extra battle file read by the client
; (Resources/ClientDefinitions.ini BattleFSFileName=BattleE.ini); generated by Modding/tools/build-arka00-mission.ps1.
[Battles]
ARKAH=HEADER_ARKA
ARKA00=M_ARKA00

[HEADER_ARKA]
Description=ARKA: Blad znaku
Categories=CAT_SA

[M_ARKA00]
CD=-1
Scenario=Maps/Missions/arka00.map
Description=ARKA #0: Ostatnia brama
Author=Zema
RequiredAddon=1
Side=2
IconPath=alliesicon.png
PlayerAlwaysOnNormalDifficulty=yes
Categories=CAT_SA
LongDescription=Gibraltar, 1953. Alianci przegrali wojne, a ostatni przyczolek trzyma gen. von Esling. Pod Skala prof. Einstein konczy Projekt ARKA: Giga-Chronosfere, ktora ma przeniesc cala baze w przeszlosc. @@Rdzen potrzebuje 25 minut ladowania. Utrzymaj ARKE i 4 elektrownie. Sowieci nadejda z Hiszpanii, Nod od morza.
"@
    # merge: keep the entries of the other ARKA missions (build-arka01-mission.ps1 adds M_ARKA01 to the same file)
    [IO.File]::WriteAllText("$work\BattleE.new.ini", $battle, [Text.Encoding]::ASCII)
    $nb = [Ini]::Load("$work\BattleE.new.ini")
    if (Test-Path "$game\INI\BattleE.ini") {
        $old = [Ini]::Load("$game\INI\BattleE.ini")
        # NOT "$null -eq Get(...)": PowerShell passes $null to the C# string default as "", so Get never returns $null and
        # every other mission's entry was dropped (2026-10-27: M_ARKA01/M_ARKA02 vanished from the client twice)
        foreach ($s in $old.Order) { foreach ($kv in $old.Section($s)) { if (-not $nb.Get($s, $kv.Key, $null)) { $nb.Set($s, $kv.Key, $kv.Value) } } }
    }
    $head = "; ARKA campaign (Claude, Modding/wiki/plans/campaign-arka). Extra battle file read by the client`r`n; (Resources/ClientDefinitions.ini BattleFSFileName=BattleE.ini); written by Modding/tools/build-arka0*-mission.ps1.`r`n"
    [IO.File]::WriteAllText("$game\INI\BattleE.ini", $head + $nb.Write(), [Text.Encoding]::ASCII)
    $log.Add("written $game\INI\BattleE.ini (merged)")
}

# ================================================================ checks
$fail = 0
$wpUsed = 10..45
$sec = { param($n) @($ini.Section($n)).Count }
foreach ($k in $trig.Keys) { foreach ($a in $trig[$k].Actions) { $p = $a -split ','; if ($p[0] -eq '80') { if (-not $ini.Has($p[2])) { $log.Add("FAIL team $($p[2]) missing"); $fail++ } } } }
foreach ($kv in $ini.Section('Structures')) { $p = $kv.Value -split ','; if ($p[6] -ne 'None' -and -not $ini.Get('Tags', $p[6], $null)) { $log.Add("FAIL structure tag $($p[6]) has no [Tags] entry"); $fail++ } }
foreach ($id in ($ini.Section('TaskForces') | ForEach-Object { $_.Value })) { foreach ($kv in $ini.Section($id)) { if ($kv.Key -match '^\d+$' -and $kv.Value -notmatch '^\d+,\w+$') { $log.Add("FAIL taskforce $id entry '$($kv.Value)'"); $fail++ } } }
foreach ($kv in $ini.Section('Triggers')) { if (($kv.Value -split ',').Count -ne 8) { $log.Add("FAIL trigger $($kv.Key) has $(($kv.Value -split ',').Count) fields"); $fail++ } }
# ground teams must not use script action 1 (attack waypoint): they stop there for good (user test 2026-10-27)
foreach ($kv in $ini.Section('TeamTypes')) {
    $tm = $kv.Value; $air = @($ini.Section($ini.Get($tm, 'TaskForce', '')) | Where-Object { $_.Value -match ',(YAK|MIG|ORCA|ORCAB|BADR)$' }).Count
    $s1 = @($ini.Section($ini.Get($tm, 'Script', '')) | Where-Object { $_.Key -match '^\d+$' -and $_.Value -match '^1,' }).Count
    if ($s1 -and -not $air) { $log.Add("FAIL ground team $tm ($($ini.Get($tm, 'Name', ''))) uses script action 1"); $fail++ }
}
# landing waypoints: the transports spawn on water (code 9/1) and sail to a beach cell they can unload on
foreach ($n in 41, 26, 45, 23, 42, 24, 43, 27) { $log.Add("wp $n @ $($wp[$n][0]),$($wp[$n][1]) terrain code $($code[$wp[$n][1] * $GW + $wp[$n][0]])") }
$log.Add($(if ($fail) { "CHECKS: $fail FAIL" } else { 'CHECKS: PASS (teams exist, every object tag has a trigger)' }) + "; text timeline: $textWarn WARN")
$log | Set-Content "$work\log.txt" -Encoding UTF8
$log

if ($Render) {
    $dir = "$game\Map Editor\Map Renderer"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$Out`" -o arka00_mission -d `"$work`" -p -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "renderer timed out" }
    "render: $work\arka00_mission.png"
}
