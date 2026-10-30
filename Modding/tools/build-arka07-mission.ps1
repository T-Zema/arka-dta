# Mission layer of ARKA mission 7 "Zdrada" (Antiga Prime, 2500): Mengsk crowns himself emperor of the Terran Dominion
# and demands the ARKA; the Allied base round the ARKA is surrounded by the Dominion; Raynor's squad stands inside the
# Dominion city by the spaceport, breaks into the port where Mengsk's flagship Hyperion is docked, Tanya blows the three
# docking clamps and the Hyperion becomes the player's hero Battlecruiser; then Einstein charges the jump for 20 minutes
# under Duke's siege tanks and attacks from three sides.
# Reads the terrain map built by build-arka07-antiga.ps1 (Maps\Custom\arka07_antiga.map, read-only) and writes
# Maps\Missions\arka07.map. Waypoints 10-63 of the terrain map are the contract (wiki missions/arka-07-zdrada).
#
# STAGE 1 (this version, 2026-10-30): the map with its objects only: houses, StarCraft types copied into the map, the
# Dominion city of StarCraft Terran buildings in themed districts, the spaceport with the Hyperion and its clamps, Duke's
# forts and siege positions, the Allied base and the start forces. No triggers, no texts, no BattleE.ini entry yet.
#
#   powershell -NoProfile -File .\build-arka07-mission.ps1            # build + checks
#   powershell -NoProfile -File .\build-arka07-mission.ps1 -Render    # also render %TEMP%\arka07-mission\arka07_mission.png
param(
    [string]$Terrain = "",
    [string]$Out = "",
    [switch]$Render
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Terrain) { $Terrain = "$game\Maps\Custom\arka07_antiga.map" }
if (-not $Out) { $Out = "$game\Maps\Missions\arka07.map" }
$work = "$env:TEMP\arka07-mission"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\TsMap.cs" -ReferencedAssemblies System.Drawing
$enc = [Text.Encoding]::GetEncoding(1252)

$ini = [Ini]::Load($Terrain)
$log = New-Object Collections.Generic.List[string]

# ================================================================ terrain occupancy (as build-arka05-mission.ps1)
$mixes = New-Object MixSet "$game\MIX"
$th    = New-Object Theater "$game\INI\Temperat.ini", "tem", $mixes
$GW = 512
$code = New-Object 'int[]' ($GW * $GW); for ($i = 0; $i -lt $code.Length; $i++) { $code[$i] = -1 }
$street = New-Object 'bool[]' ($GW * $GW)
foreach ($t in [IsoMap]::Decode([Pack]::Unpack($ini.Joined('IsoMapPack5'), $true))) {
    $tile = if ($t.Tile -lt 0 -or $t.Tile -ge 65535) { 0 } else { $t.Tile }
    $tmp = $th.Get($tile); $c = 0
    if ($tmp -and $t.Sub -lt $tmp.Cells.Length -and $tmp.Cells[$t.Sub]) { $c = $tmp.Cells[$t.Sub].Terrain }
    $code[$t.Y * $GW + $t.X] = $c
    $set = $th.SetOf($tile); if ($set -and $set.Name -match 'Paved Road') { $street[$t.Y * $GW + $t.X] = $true }
}
$block = New-Object 'bool[]' ($GW * $GW)
$ovl = [Pack]::Unpack($ini.Joined('OverlayPack'), $false)
for ($i = 0; $i -lt $ovl.Length -and $i -lt $block.Length; $i++) { if ($ovl[$i] -ne 255) { $block[$i] = $true } }
foreach ($kv in $ini.Section('Terrain')) { $v = [int]$kv.Key; $block[[Math]::Floor($v / 1000) * $GW + $v % 1000] = $true }

# ================================================================ INI sources: Rules (base) and the StarCraft rules files
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
# the Dominion city and army (all Terran), Raynor's Raiders, the Hyperion, Duke's hero tank
$scRoots = @(
    'SCCC', 'SCCOMS', 'SCDEPO', 'SCBARR', 'SCACAD', 'SCFACT', 'SCMSHP', 'SCSTAR', 'SCCTWR', 'SCSCIF', 'SCPHYS', 'SCCOVO',
    'SCEBAY', 'SCARMO', 'SCMTUR', 'SCBUNK', 'SCSIEGB',
    'SCMARINE', 'SCFIRE', 'SCGHOST', 'SCGOLI', 'SCSIEGE', 'SCVULT', 'SCRAYN', 'SCHERO', 'SCBCF')
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
        $ini.Set($ln, ('ARKA7{0}{1:D3}' -f $ln.Substring(0, 2).ToUpper(), $nList[$ln]), $s)
        # mission-only for now: the Terran tech of Raynor's Raiders opens in the second half of the mission (plan),
        # the triggers of stage 2 will lift this for the player's house
        if ($ln -in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') { $ini.Set($s, 'TechLevel', '-1') }
    }
}
$log.Add("SC types copied into the map: $($scTypes.Count) sections (" + (($nList.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', ') + ")")

# ================================================================ foundations, placement (as build-arka05-mission.ps1)
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
$noStreet = $false
function Buildable($x, $y) { $i = $y * $GW + $x; $c = $code[$i]; ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -and -not $block[$i] -and -not ($noStreet -and $street[$i]) }
$wp = @{}; foreach ($kv in $ini.Section('Waypoints')) { $v = [int]$kv.Value; $wp[[int]$kv.Key] = @(($v % 1000), [Math]::Floor($v / 1000)) }
foreach ($n in (10..22 + 30..63)) { if (-not $wp.ContainsKey($n)) { throw "terrain map has no waypoint $n (contract 10-63 broken)" } }
$reserved = New-Object 'bool[]' ($GW * $GW)
function Reserve($cx, $cy, $r) { for ($x = $cx - $r; $x -le $cx + $r; $x++) { for ($y = $cy - $r; $y -le $cy + $r; $y++) { $reserved[$y * $GW + $x] = $true } } }
function Free($x, $y, $w, $h, $m, [bool]$useReserved) {
    for ($i = $x - $m; $i -lt $x + $w + $m; $i++) { for ($j = $y - $m; $j -lt $y + $h + $m; $j++) {
        if (-not (Buildable $i $j)) { return $false }
        if (-not $useReserved -and $reserved[$j * $GW + $i]) { return $false }
    } }
    $true
}
function Occupy($x, $y, $w, $h) { for ($i = $x; $i -lt $x + $w; $i++) { for ($j = $y; $j -lt $y + $h; $j++) { $block[$j * $GW + $i] = $true } } }
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
$structs = $ini.Section('Structures'); $sIdx = $structs.Count
$units = $ini.Section('Units'); $infs = $ini.Section('Infantry')
function Add-Building($house, $type, $x, $y, $tag = 'None', $sell = 1, $hp = 256) {
    $f = Foundation $type; Occupy $x $y $f[0] $f[1]
    $script:structs.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$script:sIdx", "$house,$type,$hp,$x,$y,64,$tag,$sell,0,1,0,0,None,None,None,0,0"))
    $script:sIdx++; $log.Add("building $house $type @ $x,$y ($($f[0])x$($f[1])) hp=$hp tag=$tag")
}
# a building near a waypoint; m = free margin round it. City buildings keep off the highway (Paved Road) but may stand
# on the SC platforms (pavement)
function Place-AtWp($house, $type, [int]$n, $m = 1, $tag = 'None', $hp = 256, $sell = 0, $dx = 0, $dy = 0) {
    $f = Foundation $type
    $script:noStreet = $true
    try { $s = Find-Spot ($wp[$n][0] + $dx - [Math]::Floor($f[0] / 2)) ($wp[$n][1] + $dy - [Math]::Floor($f[1] / 2)) $f[0] $f[1] $m $true }
    finally { $script:noStreet = $false }
    Add-Building $house $type $s[0] $s[1] $tag $sell $hp
}
# a building with its add-on (2x2) against its right side, flush with the bottom edge, as in StarCraft (mission 5)
function Place-WithAddon($house, $type, $addon, [int]$n, $dx, $dy, $hp = 256) {
    $f = Foundation $type; $fa = Foundation $addon
    $script:noStreet = $true
    try { $s = Find-Spot ($wp[$n][0] + $dx - [Math]::Floor($f[0] / 2)) ($wp[$n][1] + $dy - [Math]::Floor($f[1] / 2)) ($f[0] + $fa[0]) ([Math]::Max($f[1], $fa[1])) 1 $true }
    finally { $script:noStreet = $false }
    Add-Building $house $type $s[0] $s[1] 'None' 0 $hp
    Add-Building $house $addon ($s[0] + $f[0]) ($s[1] + $f[1] - $fa[1]) 'None' 0 $hp
}
function Add-Unit($house, $type, $tx, $ty, $mission = 'Guard', $tag = 'None', $hp = 256, $vet = 0, $facing = 64) {
    $s = Find-Spot $tx $ty 1 1 0 $true; Occupy $s[0] $s[1] 1 1
    $script:units.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$($script:units.Count)", "$house,$type,$hp,$($s[0]),$($s[1]),$facing,$mission,$tag,$vet,-1,0,-1,0,0"))
}
$infCell = $null; $infSub = 4
function Add-Inf($house, $type, $tx, $ty, $mission = 'Guard', $tag = 'None', $hp = 256, $vet = 0) {
    if ($script:infSub -gt 3 -or $script:infCell[2] -ne "$tx,$ty") {
        $s = Find-Spot $tx $ty 1 1 0 $true; Occupy $s[0] $s[1] 1 1; $script:infCell = @($s[0], $s[1], "$tx,$ty"); $script:infSub = 1
    }
    $script:infs.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$($script:infs.Count)", "$house,$type,$hp,$($script:infCell[0]),$($script:infCell[1]),$($script:infSub),$mission,64,$tag,$vet,-1,0,0,0"))
    $script:infSub++
}
function NewCell { $script:infSub = 4 }
# SC Marines, Ghosts and Firebats are SHP *vehicles* in the mod, so they go to [Units]
function Is-Vehicle($type) { $listOf[$type] -eq 'VehicleTypes' -or $listOf[$type] -eq 'Rules:VehicleTypes' -or @($ini.Section('VehicleTypes') | Where-Object { $_.Value -eq $type }).Count }
function Squad($house, [string[]]$types, [int]$n, $dx = 0, $dy = 0, $mission = 'Guard', $hp = 256, $tag = 'None') {
    NewCell
    foreach ($t in $types) {
        if (Is-Vehicle $t) { Add-Unit $house $t ($wp[$n][0] + $dx) ($wp[$n][1] + $dy) $mission $tag $hp }
        else { Add-Inf $house $t ($wp[$n][0] + $dx) ($wp[$n][1] + $dy) $mission $tag $hp }
    }
}
function Copy-Type($dst, $src, $over) {
    $m = [ordered]@{}; foreach ($k in $scSec[$src].Keys) { $m[$k] = $scSec[$src][$k] }
    foreach ($k in 'Prerequisite', 'BuiltAt', 'BuildLimit', 'Naval', 'DeploysInto', 'UndeploysInto') { $m.Remove($k) }
    foreach ($k in $over.Keys) { if ($null -eq $over[$k]) { $m.Remove($k) } else { $m[$k] = $over[$k] } }
    foreach ($k in $m.Keys) { $ini.Set($dst, $k, "$($m[$k])") }
}
$rnd = New-Object Random 2500

# ================================================================ mission types
# Tanya: 2500 HP in every ARKA mission (user 2026-10-28)
$ini.Set('TANYA', 'Strength', "$([int]([int]$rules['TANYA']['Strength'] * 2.5))")
# ARKA: the Chronosphere RAPDOX overridden (as in mission 4) but losable here (plan: defeat when the ARKA is destroyed),
# so very tough instead of immune; the jump charge of stage 2 is a timer, not the superweapon
$fcache['RAPDOX'] = @(2, 2)
$arka = [ordered]@{
    Name = 'ARKA'; Strength = '28000'; Armor = 'heavy'; TechLevel = '-1'; Sight = '8'; Power = '0'; Powered = 'no'; Capturable = 'false'
    Crewed = 'no'; Unsellable = 'yes'; Repairable = 'yes'; ClickRepairable = 'yes'; SuperWeapon = 'none'; NukeSilo = 'no'; AIBuildThis = 'no'
}
foreach ($k in $arka.Keys) { $ini.Set('RAPDOX', $k, $arka[$k]) }
# Einstein's laboratory (as mission 4: the TD Bio Research Lab)
$lab = [ordered]@{ Name = 'Laboratorium Einsteina'; Strength = '4000'; Armor = 'concrete'; Owner = 'Allies'; TechLevel = '-1'; Power = '0'; Capturable = 'false'
    Insignificant = 'no'; RadarInvisible = 'no'; Unsellable = 'yes'; Sight = '6'; Repairable = 'yes'; ClickRepairable = 'yes'; Storage = '0' }
foreach ($k in $lab.Keys) { $ini.Set('BIO', $k, $lab[$k]) }
# the Hyperion docked in the spaceport: the SC Battlecruiser picture on the ground (as Norad II in mission 4: a vehicle
# with a ground locomotor that nobody orders around), Mengsk's flagship. Stage 2 swaps it for the player's flying hero
# Battlecruiser with the Yamato cannon when the three clamps are gone
Copy-Type 'ARKHYPD' 'SCBCF' ([ordered]@{ Name = 'Hyperion (zadokowany)'; Image = 'SCBCF'; Primary = $null; Secondary = $null; FlightLevel = $null
    Locomotor = '{4A582741-9839-11d1-B709-00A024DDAFD1}'; MovementZone = 'Normal'; SpeedType = 'Track'; Speed = '1'; ROT = '1'; Strength = '9000'
    TechLevel = '-1'; Owner = 'Soviet'; Sight = '6'; Crusher = 'no'; Insignificant = 'no'; Immune = 'yes'; Cost = '0'; Points = '0' })
# docking clamps: the SC Control Tower picture (the Starport's docking add-on) as a building of its own. Repairable=yes or
# Tanya's C4 never works on it (mission 2: InfantryClass::What_Action); ThreatPosed=0 as the psi emitters of mission 5
Copy-Type 'ARKCLAMP' 'SCCTWR' ([ordered]@{ Name = 'Zaczep dokujacy'; Description = 'Zaczep dokujacy Hyperiona. Tanya moze go wysadzic C4.'; Image = 'SCCTWR'
    Strength = '2000'; Armor = 'concrete'; TechLevel = '-1'; Owner = 'Soviet'; Power = '0'; Capturable = 'false'; Crewed = 'no'; Repairable = 'yes'
    ClickRepairable = 'no'; ThreatPosed = '0'; Cost = '0'; Points = '0'; Upgrades = $null })
# Edmund Duke, general of the Dominion: his gold hero siege tank (SCHERO, mini-nuke shells) at his headquarters
$ini.Set('VehicleTypes', 'ARKA7V01', 'ARKHYPD')
$ini.Set('BuildingTypes', 'ARKA7B01', 'ARKCLAMP')
$fcache['ARKCLAMP'] = Foundation 'SCCTWR'
# crystal mines (terrain): blue crystals, growing slowly (as missions 4-5)
$ini.Set('OREMINE2', 'Name', 'Kopalnia krysztalow'); $ini.Set('OREMINE2', 'TiberiumToSpawn', '6')
$ini.Set('BlueGems', 'Growth', '3000'); $ini.Set('BlueGems', 'GrowthPercentage', '.05')
# tech of mission 7 (plan): the full Allied tech; no missile silo, the Chronosphere is the ARKA
foreach ($t in 'RAMSLO') { $ini.Set($t, 'TechLevel', '-1') }

# ================================================================ houses
$ini.Sections.Remove('Houses') | Out-Null; $ini.Order.Remove('Houses') | Out-Null
$hl = @('GDI', 'Nod', 'Allies', 'Soviet', 'Neutral', 'Special', 'GDI1', 'Nod1', 'GDI2', 'Nod2', 'Allies1', 'Allies2', 'Soviet1', 'Soviet2')
for ($i = 0; $i -lt $hl.Count; $i++) { $ini.Set('Houses', "$i", $hl[$i]) }
$H = @{}; for ($i = 0; $i -lt $hl.Count; $i++) { $H[$hl[$i]] = $i }
function House($name, $side, $color, $allies, $credits, $actsLike, $player, $edge = 'North', $iq = 0, $tl = 10) {
    $v = [ordered]@{ IQ = $iq; Edge = $edge; Side = $side; Color = $color; Allies = $allies; Credits = $credits; ActsLike = $actsLike
        NodeCount = 0; TechLevel = $tl; PercentBuilt = 100; PlayerControl = $player }
    foreach ($k in $v.Keys) { $ini.Set($name, $k, "$($v[$k])") }
}
House 'Allies'  'AlliesSide'   'AlliedBlue' 'Allies,GDI2' 60 2 'yes' 'East' 0 10   # player: 6000 credits, full Allied tech
House 'GDI2'    'GDISide'      'Blue'       'GDI2,Allies' 0 8 'no'                 # Raynor's Raiders (stage 2 hands them over)
House 'Soviet'  'GDISide'      'Gold'       'Soviet,GDI' 0 3 'no' 'West' 3          # the Terran Dominion: the city, the port, the army
House 'GDI'     'GDISide'      'DarkRed'    'GDI,Soviet' 0 0 'no' 'North' 3         # General Duke (Alpha Squadron): forts, siege tanks
House 'Nod'     'NodSide'      'Purple'     'Nod' 0 1 'no'
House 'Neutral' 'CivilianSide' 'Grey'       'Neutral' 0 4 'no'
House 'Special' 'SpecialSide'  'Grey'       'Special' 0 5 'no'
# (not $h: PowerShell names ignore case and $H is the house index)
foreach ($hn in 'GDI1', 'Nod1', 'Nod2', 'Allies1', 'Allies2', 'Soviet1', 'Soviet2') { House $hn 'GDISide' 'Grey' $hn 0 0 'no' }

# ================================================================ the Allied base round the ARKA (east plain)
foreach ($n in 10, 12, 13, 14, 16, 17, 18, 22) { Reserve $wp[$n][0] $wp[$n][1] 2 }
Place-AtWp 'Allies' 'RAPDOX' 10 1 'None' 256
Place-AtWp 'Allies' 'BIO'    12 1 'None' 256
Place-AtWp 'Allies' 'AFACT'  13 1 'None' 256 1
Place-AtWp 'Allies' 'RATENT' 14 1 'None' 256 1
Place-AtWp 'Allies' 'AWEAP'  16 1 'None' 256 1
Place-AtWp 'Allies' 'RAPOWR' 17 0 'None' 256 1
Place-AtWp 'Allies' 'RAPOWR' 18 0 'None' 256 1
Place-AtWp 'Allies' 'RADOME' 17 1 'None' 256 1 -4 3
# refinery by the home crystals (the SC minerals under the north plateau, in reach of Duke's tanks), with its truck
$gem = @(); for ($i = 0; $i -lt $ovl.Length; $i++) { if ($ovl[$i] -ge 27 -and $ovl[$i] -le 38) { $gx = $i % 512; $gy = [Math]::Floor($i / 512); if ([Math]::Abs($gx - $wp[15][0]) -le 12 -and [Math]::Abs($gy - $wp[15][1]) -le 12) { $gem += , @($gx, $gy) } } }
if ($gem.Count -eq 0) { throw "no crystal field near the base (wp 15)" }
$gcx = [int](($gem | ForEach-Object { $_[0] } | Measure-Object -Average).Average); $gcy = [int](($gem | ForEach-Object { $_[1] } | Measure-Object -Average).Average)
$f = Foundation 'RAPROC'; $s = Find-Spot ([int](($gcx + $wp[15][0]) / 2)) ([int](($gcy + $wp[15][1]) / 2)) $f[0] $f[1] 1 $true; Add-Building 'Allies' 'RAPROC' $s[0] $s[1] 'None' 1
Add-Unit 'Allies' 'RAHARV' $gcx $gcy 'Harvest'
$log.Add("home crystals: $($gem.Count) cells round $gcx,$gcy")
# the defence ring: pillboxes and AA at the three entrances (north under the plateau, west highway, south scrub)
foreach ($b in @(@(19, 'PBOX', -2, 0), @(19, 'AGUN', 3, 1), @(20, 'PBOX', 0, -3), @(20, 'PBOX', 0, 3), @(21, 'PBOX', -2, 1), @(21, 'GUN', 2, 0))) {
    if ($rules.ContainsKey($b[1])) { Place-AtWp 'Allies' $b[1] $b[0] 0 'None' 256 1 $b[2] $b[3] }
}
# the start army
$p = $wp[11]
foreach ($t in '2TNK', '2TNK', '2TNK', '1TNK', '1TNK', 'ARTY', 'ARTY') { Add-Unit 'Allies' $t ($p[0] + 2) ($p[1] - 2) 'Guard' }
Squad 'Allies' @('E1', 'E1', 'E1') 11 1 3
Squad 'Allies' @('E1', 'E1', 'E1') 11 -1 3
Squad 'Allies' @('E3', 'E3', 'E3') 11 3 2
Squad 'Allies' @('MEDIC', 'ENGINEER', 'ENGINEER') 11 4 0

# ================================================================ the Dominion city on the SC platforms (west)
# Built of StarCraft Terran buildings in themed districts (feedback: SC-world cities, add-ons by theme; the DTA CITY*
# blocks were rejected). StarCraft itself has no Terran civilian buildings as units: its neutral buildings with art are
# Norad II, the Ion Cannon, the Psi Disrupter and the Power Generator; "Cantina", "Independent Command Center/Starport",
# "Mining Platform", "Jump Gate" and "Ruins" are unused entries drawn with the Scout. The badlands town houses and shops
# are terrain doodads (tiles + neon sprites lcshop*), not objects (wiki missions/arka-07-zdrada, "Budynki neutralne SC").
# Entry: type, waypoint, dx, dy[, add-on]
$city = [ordered]@{
    'spaceport' = @(@('SCSTAR', 35, 0, 0, 'SCCTWR'), @('SCSTAR', 35, 1, -7, 'SCCTWR'), @('SCSCIF', 30, 9, 6, 'SCPHYS'),
                    @('SCDEPO', 35, -2, 6), @('SCDEPO', 33, -5, 3), @('SCMTUR', 30, -7, -5), @('SCMTUR', 30, 7, -6), @('SCMTUR', 33, 4, 3),
                    @('SCBUNK', 34, -3, -1), @('SCBUNK', 34, -2, 4))
    'palace'    = @(@('SCCC', 36, 0, 0, 'SCCOMS'), @('SCSCIF', 36, -1, -8, 'SCCOVO'), @('SCACAD', 36, 7, -5), @('SCACAD', 37, 2, -3),
                    @('SCMTUR', 36, -5, 4), @('SCMTUR', 36, 8, 3), @('SCBUNK', 43, -3, -3), @('SCDEPO', 37, -2, 3))
    'industry'  = @(@('SCFACT', 38, 0, 0, 'SCMSHP'), @('SCFACT', 38, -8, 5, 'SCMSHP'), @('SCARMO', 38, 7, -3), @('SCARMO', 38, 6, 5),
                    @('SCEBAY', 38, -6, -4), @('SCDEPO', 38, 2, 8), @('SCMTUR', 38, -2, -6))
    'north'     = @(@('SCBARR', 39, 0, 0), @('SCBARR', 39, 6, 4), @('SCSCIF', 39, -7, 3, 'SCPHYS'), @('SCACAD', 39, 5, -4), @('SCEBAY', 44, -4, -3),
                    @('SCBUNK', 44, 2, 2), @('SCMTUR', 39, -3, -5), @('SCDEPO', 39, -2, 7), @('SCDEPO', 39, 8, -2))
    'housing'   = @(@('SCDEPO', 40, -4, -2), @('SCDEPO', 40, -1, -2), @('SCDEPO', 40, 2, -2), @('SCDEPO', 40, -4, 1), @('SCDEPO', 40, -1, 1), @('SCDEPO', 40, 2, 1),
                    @('SCDEPO', 43, 3, 2), @('SCDEPO', 43, 0, 4), @('SCMTUR', 40, 5, 0))
    'gates'     = @(@('SCBUNK', 41, 2, -1), @('SCMTUR', 41, -2, 2), @('SCDEPO', 41, -3, -3),
                    @('SCBUNK', 42, -3, -2), @('SCBUNK', 42, 2, 3), @('SCMTUR', 42, -2, 3), @('SCDEPO', 42, -5, 0), @('SCDEPO', 42, 4, -2))
}
foreach ($n in 30, 31, 32, 33, 34) { Reserve $wp[$n][0] $wp[$n][1] 2 }
foreach ($d in $city.Keys) {
    $nb = 0
    foreach ($b in $city[$d]) {
        $hp = 256 - $rnd.Next(30)
        if ($b.Count -gt 4) { Place-WithAddon 'Soviet' $b[0] $b[4] $b[1] $b[2] $b[3] $hp; $nb += 2 }
        else { Place-AtWp 'Soviet' $b[0] $b[1] 0 'None' $hp 0 $b[2] $b[3]; $nb++ }
    }
    $log.Add("city district ${d}: $nb buildings")
}
# the spaceport: the Hyperion docked in the middle of the big platform, held by three clamps (wp 31-33)
Add-Unit 'Soviet' 'ARKHYPD' $wp[30][0] $wp[30][1] 'Sleep' 'None' 256 0 96
foreach ($n in 31, 32, 33) { Place-AtWp 'Soviet' 'ARKCLAMP' $n 0 'None' 256 0 }
# Dominion garrisons: a squad in every district, guards at the gates
$M = 'SCMARINE'; $F = 'SCFIRE'; $G = 'SCGOLI'; $T = 'SCSIEGE'; $V = 'SCVULT'; $Gh = 'SCGHOST'
Squad 'Soviet' @($M, $M, $M, $M, $F, $F, $G, $G) 30 -4 3 'Area Guard'
Squad 'Soviet' @($M, $M, $M, $Gh, $G, $T) 36 3 3 'Area Guard'
Squad 'Soviet' @($M, $M, $M, $F, $G, $T) 38 2 -3 'Area Guard'
Squad 'Soviet' @($M, $M, $M, $M, $F, $V, $V) 39 2 -2 'Area Guard'
Squad 'Soviet' @($M, $M, $M, $G) 41 0 2 'Area Guard'
Squad 'Soviet' @($M, $M, $M, $F, $G, $T) 42 0 -3 'Area Guard'
Squad 'Soviet' @($M, $M, $V) 43 2 -1 'Area Guard'

# ================================================================ Raynor's squad inside the Dominion base by the spaceport
# (plan: "Oddzial Raynora stoi w srodku bazy Dominium, przy porcie kosmicznym"): Raynor the hero Marine, his Marines and
# Firebats, and Tanya with her C4 for the clamps. Player's house in this stage (the plan has them fight for the player)
NewCell; Add-Unit 'Allies' 'SCRAYN' $wp[34][0] $wp[34][1] 'Guard' 'None' 256 2
Squad 'Allies' @($M, $M, $M, $M, $M, $M, $F, $F) 34 2 1
NewCell; Add-Inf 'Allies' 'TANYA' ($wp[34][0] + 1) ($wp[34][1] - 2) 'Guard' 'None' 256 100

# ================================================================ General Duke: forts, siege positions, headquarters
Place-WithAddon 'GDI' 'SCFACT' 'SCMSHP' 50 -6 2
Place-AtWp 'GDI' 'SCARMO' 50 0 'None' 256 0 5 4
Place-AtWp 'GDI' 'SCDEPO' 50 0 'None' 256 0 -3 -4
Place-AtWp 'GDI' 'SCDEPO' 50 0 'None' 256 0 0 -5
Place-AtWp 'GDI' 'SCBUNK' 50 0 'None' 256 0 6 -2
Add-Unit 'GDI' 'SCHERO' $wp[50][0] $wp[50][1] 'Guard' 'None' 256 2
# the forts on the north plateau (the SC Confederate bunkers)
foreach ($b in @(@(45, 'SCBUNK', 3, 4), @(45, 'SCBUNK', -4, 5), @(45, 'SCEBAY', 0, -3), @(45, 'SCMTUR', 5, -1), @(60, 'SCDEPO', 0, 0), @(60, 'SCDEPO', 3, 1),
                 @(46, 'SCBUNK', -3, 3), @(46, 'SCBUNK', 3, 4), @(46, 'SCBARR', 0, -4), @(46, 'SCMTUR', 5, 0), @(46, 'SCDEPO', -6, -1))) {
    Place-AtWp 'GDI' $b[1] $b[0] 0 'None' 256 0 $b[2] $b[3]
}
Squad 'GDI' @($M, $M, $M, $M, $G) 45 0 2 'Area Guard'
Squad 'GDI' @($M, $M, $M, $F, $G) 46 0 1 'Area Guard'
# Duke's siege tanks over the base (plan: "Siege Tanki Duke'a ostrzeliwuja obwod"): deployed on the plateau edge north
# of the base, on the centre mesa over the west entrance and on the south mesa, each with a small escort
foreach ($n in 47, 48, 49) {
    Place-AtWp 'GDI' 'SCSIEGB' $n 0 'None' 256 0 0 0
    Place-AtWp 'GDI' 'SCSIEGB' $n 0 'None' 256 0 3 -2
    Squad 'GDI' @($M, $M, $M, $G) $n -2 2 'Area Guard'
}
Place-AtWp 'GDI' 'SCMTUR' 47 0 'None' 256 0 -3 -2

# ================================================================ write
$ini.Set('Basic', 'Name', 'ARKA #7: Zdrada')
$ini.Set('Basic', 'Author', 'Zema')
$ini.Set('Basic', 'Player', 'Allies')
$ini.Set('Basic', 'MultiplayerOnly', '0')
[IO.File]::WriteAllText($Out, $ini.Write(), $enc)
$log.Add("written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB): $($structs.Count) buildings, $($units.Count) units, $($infs.Count) infantry")

# ================================================================ checks
$fail = 0
foreach ($sec in 'Structures', 'Units', 'Infantry') {
    foreach ($kv in $ini.Section($sec)) {
        $p = $kv.Value -split ','
        $typ = $p[1]; if (-not ($rules.ContainsKey($typ) -or $ini.Has($typ))) { $log.Add("FAIL $sec type $typ is defined nowhere"); $fail++ }
        $want = @{ Structures = 'BuildingTypes'; Units = 'VehicleTypes'; Infantry = 'InfantryTypes' }[$sec]
        $isIn = @($ini.Section($want) | Where-Object { $_.Value -eq $typ }).Count -gt 0 -or $listOf[$typ] -eq $want -or $listOf[$typ] -eq "Rules:$want"
        if (-not $isIn) { $log.Add("FAIL $sec holds $typ, which is not in [$want]"); $fail++ }
        if (-not $H.ContainsKey($p[0])) { $log.Add("FAIL $sec owner $($p[0]) is not a house"); $fail++ }
    }
}
foreach ($ln in $listNames) { foreach ($kv in $ini.Section($ln)) { if (-not ($ini.Has($kv.Value) -or $rules.ContainsKey($kv.Value))) { $log.Add("FAIL $ln entry $($kv.Value) has no section"); $fail++ } } }
foreach ($ln in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') {
    foreach ($kv in $ini.Section($ln)) { $img = $ini.Get($kv.Value, 'Image', $kv.Value); if (-not $art.ContainsKey($img)) { $log.Add("FAIL $($kv.Value): no [$img] in Art.ini (would be invisible)"); $fail++ } }
}
foreach ($s in $scTypes) { foreach ($k in 'Prerequisite', 'BuiltAt') { $v = $ini.Get($s, $k, $null); if ($v) { foreach ($tok in ($v -split ',')) { $tok = $tok.Trim(); if ($tok -and $tok -notmatch '^(POWER|FACTORY|BARRACKS|RADAR|TECH|PROC|none)$' -and -not ($ini.Has($tok) -or $rules.ContainsKey($tok))) { $log.Add("FAIL $s $k names $tok"); $fail++ } } } } }
$log.Add($(if ($fail) { "CHECKS: $fail FAIL" } else { 'CHECKS: PASS (types defined and listed, art exists, owners are houses, prerequisites resolve)' }))
$log | Set-Content "$work\log.txt" -Encoding UTF8
$log | Where-Object { $_ -notmatch '^building ' }

if ($Render) {
    $dir = "$game\Map Editor\Map Renderer"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$Out`" -o arka07_mission -d `"$work`" -p -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "renderer timed out" }
    "render: $work\arka07_mission.png"
}
