# Mission layer of ARKA mission 5 "Upadek Tarsonis" (Tarsonis, 2500): Mengsk's psi emitters already call the Zerg into
# New Gettysburg; the Allies land in the crater on the outskirts (Raynor's transports wait there) and walk civilians out
# of four districts that fall one after another (at least 30 of 48 must board); Tanya may blow up the emitters (each one
# feeds its own stream of Zerg waves); Kerrigan calls for help from the Protoss landing site, Mengsk orders the retreat
# and the player arrives too late on purpose; then the last transport has to hold the landing zone till take-off.
# Reads the terrain map built by build-arka05-tarsonis.ps1 (Maps\Custom\arka05_tarsonis.map, read-only) and writes
# Maps\Missions\arka05.map. Waypoints 10-64 of the terrain map are the contract (wiki missions/arka-05-tarsonis).
#
#   powershell -NoProfile -File .\build-arka05-mission.ps1            # build + checks
#   powershell -NoProfile -File .\build-arka05-mission.ps1 -Render    # also render %TEMP%\arka05-mission\arka05_mission.png
#
# Counting civilians (the engine cannot count units): every group of 6 has its own house (Cyw1-8), its team script sets
# a local when it reaches the landing zone and deletes the group ("boarded"); a trigger then gives 6 credits to the
# counter house Allies2, and "Credits exceed" triggers of that house announce 6, 12 ... 48 (30 = objective done). Lost
# groups (house wiped out before boarding, or a district fallen before the player came) give credits to the counter
# house Soviet1; 4 lost groups = fewer than 30 can still be saved = defeat.
# StarCraft types are copied into the map with their dependency closure, like in missions 1-4. Texts: ASCII Polish,
# [Tutorial] numbers 9501-9599. Time units: Elapsed Time counts game seconds (what the on-screen timer shows).
param(
    [string]$Terrain = "",
    [string]$Out = "",
    [switch]$Render,
    [switch]$NoBattle
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Terrain) { $Terrain = "$game\Maps\Custom\arka05_tarsonis.map" }
if (-not $Out) { $Out = "$game\Maps\Missions\arka05.map" }
$work = "$env:TEMP\arka05-mission"
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
    # section -> ordered key/value; repeated sections merge and the later key wins (as the client does)
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
. "$tools\MapCode.ps1"   # the faction map code is a chain of layers (INI/Map Code/SC Factions)
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

# closure: the requested SC types plus every SC section their keys name
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
    'SCZLNG', 'SCZHYL', 'SCZULT', 'SCZMUT', 'SCZINF', 'SCZOVL', 'SCZCRP', 'SCZSUN', 'SCZBRD',   # the swarm
    'SCMARINE', 'SCFIRE', 'SCGOLI', 'SCSIEGE', 'SCGHOST', 'SCDROP', 'SCVULT', 'SCRAYN',                   # Sons of Korhal, Kerrigan, Raynor
    'SCCC', 'SCDEPO', 'SCBARR', 'SCACAD', 'SCFACT', 'SCSTAR', 'SCMTUR', 'SCBUNK', 'SCCOMS',     # the Confederate districts, emitters
    'SCEBAY', 'SCARMO', 'SCSCIF', 'SCMSHP', 'SCCTWR', 'SCPHYS', 'SCCOVO',                       # themed districts and add-ons
    'SCPZEAL', 'SCPDRAG', 'SCPPYL', 'SCPGAT', 'SCPCAN', 'SCPCARR', 'SCPSCOU')                   # Protoss landing site and fleet
# the Protoss landing site lives in its own file (Protoss AI build-up, 2026-10-28): it may add SC roots ($ProtossRoots)
# and defines Add-ProtossLanding (objects, called below instead of the static site) and Add-ProtossTriggers
$protossFile = "$tools\arka05-protoss.ps1"; $ProtossRoots = @()
if (Test-Path $protossFile) { . $protossFile }
# the Zerg nest north of Kerrigan with its own AI (2026-10-28) lives in its own file too: $ZergRoots, Add-ZergNest,
# Add-ZergTriggers (wp 71 Hatchery, 72 crystal field and mine, 73 rally)
$zergFile = "$tools\arka05-zerg.ps1"; $ZergRoots = @()
if (Test-Path $zergFile) { . $zergFile }
$scRoots = @($scRoots) + @($ProtossRoots) + @($ZergRoots) + @('SCSIEGB') | Select-Object -Unique
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
        $ini.Set($ln, ('ARKA5{0}{1:D3}' -f $ln.Substring(0, 2).ToUpper(), $nList[$ln]), $s)
        # mission-only types: the player has the full Allied tech (tech level 10) and must not find StarCraft
        # units or buildings in the sidebar
        if ($ln -in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') { $ini.Set($s, 'TechLevel', '-1') }
    }
}
$log.Add("SC types copied into the map: $($scTypes.Count) sections (" + (($nList.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', ') + ")")
# hatched-at flags of the Zerg flyers mean nothing here (mission 1: suspected to keep weapons off flyers)
foreach ($t in 'SCZMUT', 'SCZINF', 'SCZOVL') {
    $s = $ini.Section($t); for ($i = $s.Count - 1; $i -ge 0; $i--) { if ($s[$i].Key -in 'Naval', 'BuiltAt', 'Factory', 'WeaponsFactory', 'ExclusiveFactory') { $s.RemoveAt($i) } }
}
# the Zerg come in by Overlord (user 2026-10-27): in this map the Overlord is a transport like the Dropship and the
# Shuttle (engine/transports): 8 places, vehicles too (the Infested Terran is an SHP vehicle). A team whose first
# member is the Overlord is created with the cargo already inside (cr06 / ARKA 0 pattern), flies to the drop point
# (3,N) and unloads (8,2: the Overlord leaves the team, the cargo goes on with the rest of the script)
$ini.Set('SCZOVL', 'Passengers', '8'); $ini.Set('SCZOVL', 'IsVehicleTransport', 'yes'); $ini.Set('SCZOVL', 'PipScale', 'Passengers')
# ...and killable: 4000 HP, heavy armour and fast self-healing made the Photon Cannons (250 a shot) useless against it
# (user 2026-10-28: "photon cannon nic nie robi overlordowi")
# it still heals, slower: the mod-wide Zerg healing is 40% slower since 2026-10-28 (Terran Faction.ini, SC balance block:
# Overlord 16 -> 10 HP a step)
$ini.Set('SCZOVL', 'Strength', '1800')
# anti-air as in missions 1-4: rockets and Gauss rifles hit air AND ground whichever weapon the engine picks
function Resolve-Rules($sec) { $chain = @(); $s = $sec; while ($s -and $rules.ContainsKey($s) -and $chain.Count -lt 5) { $chain = , $s + $chain; $s = $rules[$s]['$Inherits'] }; $m = [ordered]@{}; foreach ($c in $chain) { foreach ($k in $rules[$c].Keys) { if ($k -ne '$Inherits') { $m[$k] = $rules[$c][$k] } } }; $m }
$aag = Resolve-Rules 'AGHeatSeeker'; $aag['AA'] = 'yes'; $aag['AG'] = 'yes'
foreach ($k in $aag.Keys) { $ini.Set('ARKA5AAG', $k, $aag[$k]) }
foreach ($w in '70mmMsl', '70mmMslRA', 'AA70mmMsl', 'AA70mmMslRA') { if ($rules.ContainsKey($w)) { $ini.Set($w, 'Projectile', 'ARKA5AAG') } }
foreach ($w in 'SCGauss', 'SCGaussS') { if ($ini.Has($w)) { $ini.Set($w, 'Projectile', 'Invisible3') } }

# ================================================================ foundations (Art.ini, Image= from the rules)
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
# buildings never stand on a street (the streets lead somewhere and must stay open); units may
$noStreet = $false
function Buildable($x, $y) { $i = $y * $GW + $x; $c = $code[$i]; ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -and -not $block[$i] -and -not ($noStreet -and $street[$i]) }

$wp = @{}; foreach ($kv in $ini.Section('Waypoints')) { $v = [int]$kv.Value; $wp[[int]$kv.Key] = @(($v % 1000), [Math]::Floor($v / 1000)) }
foreach ($n in (10..38 + 40..64) | Where-Object { $_ -ne 39 }) { if (-not $wp.ContainsKey($n)) { throw "terrain map has no waypoint $n (contract 10-64 broken)" } }
function WpLetter([int]$n) { $s = ''; $n++; while ($n -gt 0) { $n--; $s = [char](65 + $n % 26) + $s; $n = [Math]::Floor($n / 26) }; $s }

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

# ================================================================ object writers
$structs = $ini.Section('Structures'); $sIdx = $structs.Count
$units = $ini.Section('Units'); $infs = $ini.Section('Infantry')
function Add-Building($house, $type, $x, $y, $tag = 'None', $sell = 1, $hp = 256) {
    $f = Foundation $type; Occupy $x $y $f[0] $f[1]
    $script:structs.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$script:sIdx", "$house,$type,$hp,$x,$y,64,$tag,$sell,0,1,0,0,None,None,None,0,0"))
    $script:sIdx++; $log.Add("building $house $type @ $x,$y ($($f[0])x$($f[1])) hp=$hp tag=$tag")
}
function Place-AtWp($house, $type, [int]$n, $m = 1, $tag = 'None', $hp = 256, $sell = 0, $dx = 0, $dy = 0) {
    $f = Foundation $type
    $script:noStreet = $true
    try { $s = Find-Spot ($wp[$n][0] + $dx - [Math]::Floor($f[0] / 2)) ($wp[$n][1] + $dy - [Math]::Floor($f[1] / 2)) $f[0] $f[1] $m $true }
    finally { $script:noStreet = $false }
    Add-Building $house $type $s[0] $s[1] $tag $sell $hp
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
# SC Marines, Ghosts, Firebats and the Infested Terran are SHP *vehicles* in the mod, so they go to [Units]
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
function Smudges([int]$n, [int]$count, [double]$r0, [double]$r1) {
    for ($i = 0; $i -lt $count; $i++) {
        $a = $rnd.NextDouble() * 6.283; $r = $r0 + $rnd.NextDouble() * ($r1 - $r0)
        $sx = [int]($wp[$n][0] + [Math]::Cos($a) * $r); $sy = [int]($wp[$n][1] + [Math]::Sin($a) * $r)
        if (-not (Buildable $sx $sy) -or $street[$sy * $GW + $sx]) { continue }
        $ini.Set('Smudge', "$script:smN", ('CR{0}{1},{2},{3},0' -f (1 + $rnd.Next(6)), [char](65 + $rnd.Next(5)), $sx, $sy)); $script:smN++
    }
}
$smN = 0; $rnd = New-Object Random 2500

# ================================================================ mission types
# Jim Raynor on his Vulture (as in missions 1-4: Image=SCVULT, self-healing, Raynor's own SC voices); HP: +20% over the
# Vulture, then +300% (user 2026-10-28, all ARKA missions: "szybko pada"), x4.8
$ray = [ordered]@{ Name = 'Jim Raynor (Vulture)'; Image = 'SCVULT'; Strength = [string][int]([int]$scSec['SCVULT']['Strength'] * 4.8); TechLevel = '-1'; Owner = 'Allies'
    SelfHealing = 'yes'; SelfHealingCap = '1.0'; SelfHealingStep = '5' }
foreach ($k in 'VoiceSelect', 'VoiceMove', 'VoiceAttack', 'VoiceFeedback', 'VoiceDie') { if ($scSec['SCRAYN'].Contains($k)) { $ray[$k] = $scSec['SCRAYN'][$k] } }
Copy-Type 'ARKRAYN' 'SCVULT' $ray
# Sarah Kerrigan: the SC Ghost picture in the gold of the Sons of Korhal (GDI1), not cloaked (the Ghost's Cloakable=yes
# hid her, user 2026-10-27), three times as tough with a gun three times as strong, self-healing. Immune: she holds her
# position against the swarm all mission long and only leaves the map when the swarm takes her (action 115 on her tag)
Copy-Type 'ARKKERR' 'SCGHOST' ([ordered]@{ Name = 'Sarah Kerrigan'; Image = 'SCGHOST'; Strength = [string]([int]$scSec['SCGHOST']['Strength'] * 3); TechLevel = '-1'; Owner = 'GDI1'
    Cloakable = $null; Immune = 'yes'; Primary = 'ARKKerrGun'; SelfHealing = 'yes'; SelfHealingCap = '1.0'; SelfHealingStep = '10' })
foreach ($k in $scSec['SCC10'].Keys) { $ini.Set('ARKKerrGun', $k, $scSec['SCC10'][$k]) }
$ini.Set('ARKKerrGun', 'Damage', [string]([int]$scSec['SCC10']['Damage'] * 3))
# psi emitter: the Comsat Station picture (a dish) as a building of its own, Mengsk's gear. Repairable=yes or Tanya's
# C4 never works on it (InfantryClass::What_Action, mission 2); ThreatPosed=0, so the player's units leave it alone
# unless ordered (destroying it is a choice)
Copy-Type 'ARKPSIE' 'SCCOMS' ([ordered]@{ Name = 'Psi-nadajnik'; Description = 'Psi-nadajnik Synow Korhalu. Wabi Zergi z calej planety.'; Image = 'SCCOMS'
    Radar = $null; Sensors = $null; Powered = 'false'; Power = '0'; Strength = '2500'; Armor = 'concrete'; TechLevel = '-1'; Owner = 'Nod2'
    Capturable = 'false'; Crewed = 'no'; Repairable = 'yes'; ClickRepairable = 'no'; ThreatPosed = '0'; Adjacent = $null; Cost = '0'; Points = '0' })
$ini.Set('VehicleTypes', 'ARKA5V01', 'ARKRAYN'); $ini.Set('VehicleTypes', 'ARKA5V02', 'ARKKERR')
$ini.Set('BuildingTypes', 'ARKA5B01', 'ARKPSIE')
$fcache['ARKPSIE'] = Foundation 'SCCOMS'
# creep-sowing Overlord (user 2026-10-28: "specjalne overlordy ktore sieja creepem" while Kerrigan holds out): the
# Overlord picture (its SHP has 2 fire frames per facing, build-sczergbase layout) with the Guardian's acid glob. The
# warhead's only animation is the creep shard SCZCRSHL (mods/zerg-creep): where a glob lands, the shard plants a
# Veinhole Monster in its own cell (patch-vinifera-veins), the 5x5 ring and the growth queue come from patch-veins
# place 6, the veins grow ~8 cells round it. Holes keep 3 cells apart (engine), so a long fight sows a carpet, not a
# hole per shot. The holes stay after the Overlords die (no building under them, as a Creep Tumor's)
Copy-Type 'ARKOVLC' 'SCZOVL' ([ordered]@{ Name = 'Overlord siejacy creep'; Image = 'SCZOVL'; TechLevel = '-1'; Owner = 'Nod1'
    Primary = 'ARKA5CrpSpit'; Strength = '1400'; SelfHealing = 'no'; ThreatPosed = '10'; Cost = '0'; Points = '0'
    Description = 'Overlord zmutowany przez roj: zamiast desantu pluje sluzem, z ktorego wyrasta creep.' })
$ini.Set('VehicleTypes', 'ARKA5V03', 'ARKOVLC')
foreach ($k in $scSec['SCZFAcidSpore'].Keys) { $ini.Set('ARKA5CrpSpit', $k, $scSec['SCZFAcidSpore'][$k]) }
$ini.Set('ARKA5CrpSpit', 'Damage', '8'); $ini.Set('ARKA5CrpSpit', 'ROF', '90'); $ini.Set('ARKA5CrpSpit', 'Range', '6'); $ini.Set('ARKA5CrpSpit', 'Warhead', 'ARKA5CrpWH')
foreach ($k in $scSec['SCZGAcidProj'].Keys) { $ini.Set($scSec['SCZFAcidSpore']['Projectile'], $k, $scSec['SCZGAcidProj'][$k]) }
foreach ($k in $scSec['SCZFAcidWH'].Keys) { $ini.Set('ARKA5CrpWH', $k, $scSec['SCZFAcidWH'][$k]) }
$ini.Set('ARKA5CrpWH', 'AnimList', 'SCZCRSHL'); $ini.Set('ARKA5CrpWH', 'CellSpread', '0')
# civilians of New Gettysburg: the civilian C2/C8 resolved, tougher and not panicking (a panicking civilian leaves its
# team and never reaches the landing zone), and Civilian=no: the "Destroyed, Units, All" event that tells a lost group
# leaves civilian objects out (FSData), so a group of real civilians would count as dead from the start
$civHouses = 1..8 | ForEach-Object { "Cyw$_" }
$civN = 0
foreach ($src in 'C2', 'C8') {
    $civN++; $cv = Resolve-Rules $src
    $cv['Name'] = 'Cywil z Tarsonis'; $cv['Image'] = $(if ($rules[$src]['Image']) { $rules[$src]['Image'] } else { $src }); $cv['Strength'] = '200'
    $cv['Fraidycat'] = 'no'; $cv['Insignificant'] = 'no'; $cv['Civilian'] = 'no'; $cv['TechLevel'] = '-1'; $cv['Owner'] = $civHouses -join ','; $cv['EditorName'] = "Cywil $civN (ARKA)"
    $ini.Set('InfantryTypes', "ARKA5I0$civN", "ARKCIV$civN"); foreach ($k in $cv.Keys) { $ini.Set("ARKCIV$civN", $k, $cv[$k]) }
}

# tech of mission 5 (plan): the full Allied tech without superweapons: no Chronosphere, no missile silo
foreach ($t in 'RAPDOX', 'RAMSLO') { $ini.Set($t, 'TechLevel', '-1') }
# crystals instead of ore (user 2026-10-27): the terrain map has a blue-crystal mine OREMINE2 on the west plain
# (TiberiumToSpawn=6 = BlueGems, as in mission 4), and blue crystals grow slowly so the mine is worth holding
$ini.Set('OREMINE2', 'Name', 'Kopalnia krysztalow'); $ini.Set('OREMINE2', 'TiberiumToSpawn', '6')
$ini.Set('BlueGems', 'Growth', '3000'); $ini.Set('BlueGems', 'GrowthPercentage', '.05')

# ================================================================ houses
$ini.Sections.Remove('Houses') | Out-Null; $ini.Order.Remove('Houses') | Out-Null
$hl = @('GDI', 'Nod', 'Allies', 'Soviet', 'Neutral', 'Special', 'GDI1', 'Nod1', 'GDI2', 'Nod2', 'Allies1', 'Allies2', 'Soviet1', 'Soviet2') + $civHouses
for ($i = 0; $i -lt $hl.Count; $i++) { $ini.Set('Houses', "$i", $hl[$i]) }
$H = @{}; for ($i = 0; $i -lt $hl.Count; $i++) { $H[$hl[$i]] = $i }
function House($name, $side, $color, $allies, $credits, $actsLike, $player, $edge = 'North', $iq = 0, $tl = 10) {
    $v = [ordered]@{ IQ = $iq; Edge = $edge; Side = $side; Color = $color; Allies = $allies; Credits = $credits; ActsLike = $actsLike
        NodeCount = 0; TechLevel = $tl; PercentBuilt = 100; PlayerControl = $player }
    foreach ($k in $v.Keys) { $ini.Set($name, $k, "$($v[$k])") }
}
$civ = $civHouses -join ','
$friends = "Allies,Soviet,GDI1,GDI2,Allies1,Soviet2,$civ"
House 'Allies'  'AlliesSide'   'AlliedBlue' $friends 60 2 'yes' 'South' 0 10  # player: 6000 credits, full tech
House 'Soviet'  'GDISide'      'Gold'       "$friends,Nod2" 0 3 'no'          # Sons of Korhal (the outposts by the landing zone)
House 'GDI1'    'GDISide'      'Gold'       $friends 0 6 'no'                 # Kerrigan and her holdout (Marines, bunkers, depots)
# Raynor's transports on the landing zone: everybody's ally, so nobody shoots them
House 'GDI2'    'GDISide'      'Blue'       "$friends,GDI,Nod1,Nod2" 0 8 'no'
House 'Allies1' 'GDISide'      'DarkRed'    $friends 0 2 'no'                 # New Gettysburg: Confederate buildings and bunkers
House 'Soviet2' 'GDISide'      'NeonBlue'   "$friends,GDI,Nod1,Nod2" 0 3 'no' # the Protoss fleet over the burning city (ending)
foreach ($c in $civHouses) { House $c 'AlliesSide' 'LightGrey' $friends 0 2 'no' }
House 'Nod1'    'NodSide'      'Purple'     'Nod1,Nod2,GDI2,Soviet2' 0 7 'no' 'West' 3   # the Zerg
House 'Nod2'    'NodSide'      'Gold'       'Nod2,Nod1,Soviet,GDI2,Soviet2' 0 9 'no'      # Mengsk's psi emitters
House 'GDI'     'GDISide'      'NeonBlue'   'GDI,GDI2,Soviet2' 0 0 'no' 'East' 3         # Protoss landing site: against all
House 'Allies2' 'AlliesSide'   'Grey'       'Allies2' 0 2 'no'                # counter: civilians saved (credits)
House 'Soviet1' 'AlliesSide'   'Grey'       'Soviet1' 0 3 'no'                # counter: groups lost (credits)
House 'Nod'     'NodSide'      'Purple'     'Nod' 0 1 'no'
House 'Neutral' 'CivilianSide' 'Grey'       'Neutral' 0 4 'no'                # civilian houses of the city (no guns)
House 'Special' 'SpecialSide'  'Grey'       'Special' 0 5 'no'

# ================================================================ the landing zone (crater) and the player's start
foreach ($n in 10, 11, 12) { Reserve $wp[$n][0] $wp[$n][1] 2 }
# Raynor's two transports beside the landing zone (wp 69 and 70), not on wp 10: the civilians walk to wp 10, and a
# Dropship standing there could keep a group from arriving, so its script would never say "boarded" (mission 2)
foreach ($d in @(@(69, 4, -1), @(70, -2, 3))) {
    $s = Find-Spot ($wp[10][0] + $d[1]) ($wp[10][1] + $d[2]) 1 1 0 $true; Occupy $s[0] $s[1] 1 1
    $wp[$d[0]] = $s; $ini.Set('Waypoints', "$($d[0])", "$($s[1] * 1000 + $s[0])"); $log.Add("Raynor's transport wp $($d[0]) = $($s[0]),$($s[1])")
    Add-Unit 'GDI2' 'SCDROP' $s[0] $s[1] 'Guard'
}
$p = $wp[11]
$crate = Find-Spot ($p[0] + 3) ($p[1] + 2) 1 1 0 $false; Occupy $crate[0] $crate[1] 1 1
Add-Unit 'Allies' 'AMCV' $wp[12][0] $wp[12][1] 'Guard'
foreach ($t in '2TNK', '2TNK', '2TNK', '1TNK', '1TNK', 'RANG') { Add-Unit 'Allies' $t ($p[0] + 2) ($p[1] - 2) 'Guard' }
Add-Unit 'Allies' 'ARKRAYN' ($p[0] - 1) ($p[1] - 3) 'Guard' 'ARKA5G02'
Squad 'Allies' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE') 11 -3 -1
NewCell; Add-Inf 'Allies' 'TANYA' ($p[0] + 1) ($p[1] + 1) 'Guard' 'ARKA5G01' 256 100
# Tanya 2500 HP in every ARKA mission (user 2026-10-28; first +50%, then 2.5x)
$ini.Set('TANYA', 'Strength', "$([int]([int]$rules['TANYA']['Strength'] * 2.5))")
Squad 'Allies' @('E1', 'E1', 'E1') 11 1 3
Squad 'Allies' @('E1', 'E1', 'E1') 11 -1 3
Squad 'Allies' @('E3', 'E3', 'E3') 11 3 2
Squad 'Allies' @('MEDIC', 'ENGINEER', 'ENGINEER') 11 4 0
# Sons of Korhal: a bunker and a squad on each side of the landing zone. Their units carry the tag of "the Sons of
# Korhal fly away" (Mengsk's retreat order erases them, action 115); the bunkers stay behind
foreach ($n in 13, 14) {
    Place-AtWp 'Soviet' 'SCBUNK' $n 0 'None' 256 0 0 -2
    Squad 'Soviet' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCGOLI', 'SCSIEGE') $n 0 1 'Area Guard' 256 'ARKA5G09'
}
Smudges 16 6 0 3   # the crater wreck

# ================================================================ New Gettysburg: four districts
# k = 1 Delta (NW), 2 Nova (NE), 3 Omega (SW), 4 Gamma (E). Fall times (game seconds) in the order of their distance
# from the landing zone (Omega 71 cells, Gamma 72, Nova 120, Delta 139): the player has to keep moving. Spaced 500 s
# apart (user 2026-10-27: the attacks on the city came too fast; were 1500/1900/2300/2700).
$D = @(
    $null,
    @{ Name = 'Delta'; Sq = 20; Cc = 21; Pack = 23; Crate = 24; Fall = 3300; Dir = 'polnocny zachod'; Cash = 3000; Loot = 'Skarbiec banku Delty' },
    @{ Name = 'Nova';  Sq = 25; Cc = 26; Pack = 28; Crate = 29; Fall = 2800; Dir = 'polnocny wschod'; Cash = 2500; Loot = 'Kasa pancerna zbrojowni Novej' },
    @{ Name = 'Omega'; Sq = 30; Cc = 31; Pack = 33; Crate = 34; Fall = 1800; Dir = 'poludniowy zachod'; Cash = 2500; Loot = 'Sejf magazynu Omegi' },
    @{ Name = 'Gamma'; Sq = 35; Cc = 36; Pack = 37; Crate = 38; Fall = 2300; Dir = 'wschod'; Cash = 2000; Loot = 'Kasa ratusza Gammy' }
)
for ($k = 1; $k -le 4; $k++) { foreach ($n in $D[$k].Sq, $D[$k].Cc) { Reserve $wp[$n][0] $wp[$n][1] 2 } }
# the exit of each district: a free cell on its square (wp 65-68), where the civilians come out
for ($k = 1; $k -le 4; $k++) {
    $s = Find-Spot $wp[$D[$k].Sq][0] ($wp[$D[$k].Sq][1] + 1) 1 1 0 $true; Occupy $s[0] $s[1] 1 1
    $wp[64 + $k] = $s; $ini.Set('Waypoints', "$(64 + $k)", "$($s[1] * 1000 + $s[0])"); $log.Add("district $($D[$k].Name): civilians come out at wp $(64 + $k) = $($s[0]),$($s[1])")
}
# creep-sowing Overlords along the south edge of the map (user 2026-10-28: over Kerrigan they died at once, "na probe po
# krawedziach mapy"): wp 77 the south-east corner where they come in (not wp 45, which passes the Protoss cannons), wp
# 78-81 the spots they spit at, south of Kerrigan's holdout, out of her Marines' reach. SC tile -> cell: the affine map
# of the terrain conversion (zoom 1.25), fitted exactly on 8 edge waypoints. A spot needs 3x3 flat clear ground
# without an overlay (the Veinhole Monster's test), the nearest such cell within 6 is taken
function Sc-Cell($sx, $sy) { @([int][Math]::Round(7.85 + 0.625 * $sx + 1.25 * $sy), [int][Math]::Round(87.46 - 0.625 * $sx + 1.25 * $sy)) }
function Hole-Ground($x, $y) { for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { $i = ($y + $dy) * $GW + $x + $dx; $c = $code[$i]; if (-not ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -or $block[$i]) { return $false } } }; $true }
foreach ($e in @(@(77, 124, 125, 'SE corner'), @(78, 100, 123, 'creep spot 1'), @(79, 86, 124, 'creep spot 2'), @(80, 70, 124, 'creep spot 3'), @(81, 55, 123, 'creep spot 4'))) {
    $c = Sc-Cell $e[1] $e[2]; $best = $null; $bd = 1e9
    # the south edge itself is sea (terrain code 9), so the spot is the nearest land by the shore within 16 cells
    for ($x = $c[0] - 16; $x -le $c[0] + 16; $x++) { for ($y = $c[1] - 16; $y -le $c[1] + 16; $y++) {
        # ($dist, not $d: PowerShell names ignore case and $D is the district table). Kept 14+ cells from Kerrigan's
        # holdout (wp 48), 18+ from the Protoss site (wp 50), or the Overlords die again, and 6+ from another spot
        $dist = ($x - $c[0]) * ($x - $c[0]) + ($y - $c[1]) * ($y - $c[1])
        $far = [Math]::Max([Math]::Abs($x - $wp[48][0]), [Math]::Abs($y - $wp[48][1])) -ge 14 -and [Math]::Max([Math]::Abs($x - $wp[50][0]), [Math]::Abs($y - $wp[50][1])) -ge 18
        for ($k2 = 78; $k2 -lt $e[0]; $k2++) { if ($wp.ContainsKey($k2) -and [Math]::Max([Math]::Abs($x - $wp[$k2][0]), [Math]::Abs($y - $wp[$k2][1])) -lt 6) { $far = $false } }
        if ($dist -lt $bd -and $code[$y * $GW + $x] -ge 0 -and ($e[0] -eq 77 -or ($far -and (Hole-Ground $x $y)))) { $bd = $dist; $best = @($x, $y) }
    } }
    if (-not $best) { $log.Add("wp $($e[0]) ($($e[3])): only sea near $($c -join ','), no Overlord there"); continue }
    $wp[$e[0]] = $best; $ini.Set('Waypoints', "$($e[0])", "$($best[1] * 1000 + $best[0])"); $log.Add("wp $($e[0]) $($e[3]) = $($best -join ',') (SC $($e[1]),$($e[2]); aimed at $($c -join ','), off by $([int][Math]::Sqrt($bd)))")
}
# New Gettysburg is built of StarCraft Terran buildings (user 2026-10-28: the DTA city blocks CITY* "do not fit"; more
# Supply Depots and other Terran buildings, add-ons by theme). Every district has its own theme:
#   Delta (NW) the Confederate administration: Command Center + Comsat, Engineering Bay, Academy
#   Nova  (NE) industry: three Factories with Machine Shops, two Armories
#   Omega (SW) the garrison: Command Center, three Barracks, Academy, Engineering Bay, bunkers
#   Gamma (E)  the spaceport: two Starports with Control Towers, Science Facilities with Physics Lab and Covert Ops
# and Supply Depots everywhere. House Allies1 (friendly to the player, an enemy the Zerg drops attack with 0,2),
# damaged. Entry: type, waypoint, dx, dy, hp[, add-on]. No Nuclear Silo: it would give the house a superweapon
$conf = @{
    1 = @(@('SCCC', 21, 0, 0, 150, 'SCCOMS'), @('SCEBAY', 20, -7, -3, 140), @('SCACAD', 20, 6, -4, 120), @('SCDEPO', 20, -6, 3, 120), @('SCDEPO', 20, -3, 7, 100),
          @('SCDEPO', 24, -3, 2, 130), @('SCDEPO', 20, 8, 3, 90), @('SCDEPO', 21, -4, -5, 150), @('SCBUNK', 20, 4, 4, 256), @('SCMTUR', 20, -3, 6, 200), @('SCMTUR', 20, 7, -1, 200))
    2 = @(@('SCCC', 26, 0, 0, 140), @('SCFACT', 25, -7, -3, 130, 'SCMSHP'), @('SCFACT', 29, 0, 0, 110, 'SCMSHP'), @('SCFACT', 25, 6, -6, 150, 'SCMSHP'), @('SCARMO', 25, -4, 6, 120),
          @('SCARMO', 26, 5, 5, 100), @('SCDEPO', 25, 8, 1, 130), @('SCDEPO', 25, -8, 2, 110), @('SCDEPO', 29, -5, 4, 90), @('SCDEPO', 26, -6, -2, 140), @('SCBUNK', 25, 3, 4, 256), @('SCMTUR', 25, 6, 3, 200))
    3 = @(@('SCCC', 31, 0, 0, 130), @('SCBARR', 30, 6, -5, 120), @('SCBARR', 30, -7, -2, 110), @('SCBARR', 34, 3, 2, 100), @('SCACAD', 30, 6, 4, 110), @('SCEBAY', 31, -5, 5, 120),
          @('SCDEPO', 30, -3, 7, 100), @('SCDEPO', 34, -4, -2, 80), @('SCDEPO', 30, 1, -7, 130), @('SCBUNK', 30, -4, -5, 256), @('SCBUNK', 30, 8, 0, 256), @('SCMTUR', 30, 0, 6, 200))
    4 = @(@('SCSCIF', 36, 0, 0, 140, 'SCPHYS'), @('SCSTAR', 35, -7, -3, 120, 'SCCTWR'), @('SCSTAR', 38, 2, 1, 110, 'SCCTWR'), @('SCSCIF', 35, 5, -6, 100, 'SCCOVO'), @('SCDEPO', 35, -4, 5, 150),
          @('SCDEPO', 35, 3, 6, 120), @('SCDEPO', 38, -4, -3, 100), @('SCDEPO', 35, -8, 2, 130), @('SCBUNK', 35, -5, 3, 256), @('SCMTUR', 35, 4, -5, 200))
}
# a building with its add-on (2x2) against its right side, flush with the bottom edge, as in StarCraft: one free spot
# for both, so the add-on never ends up apart from its building
function Place-WithAddon($house, $type, $addon, [int]$n, $dx, $dy, $hp) {
    $f = Foundation $type; $fa = Foundation $addon
    $script:noStreet = $true
    try { $s = Find-Spot ($wp[$n][0] + $dx - [Math]::Floor($f[0] / 2)) ($wp[$n][1] + $dy - [Math]::Floor($f[1] / 2)) ($f[0] + $fa[0]) ([Math]::Max($f[1], $fa[1])) 0 $true }
    finally { $script:noStreet = $false }
    Add-Building $house $type $s[0] $s[1] 'None' 0 $hp
    Add-Building $house $addon ($s[0] + $f[0]) ($s[1] + $f[1] - $fa[1]) 'None' 0 ([Math]::Min(256, $hp + 30))
}
# Supply Depots along the streets, by the checkpoints
$streetb = @{ 61 = @('SCDEPO', 'SCDEPO'); 62 = @('SCDEPO', 'SCDEPO'); 63 = @('SCDEPO', 'SCDEPO'); 64 = @('SCDEPO', 'SCDEPO') }
for ($k = 1; $k -le 4; $k++) {
    foreach ($b in $conf[$k]) {
        if ($b.Count -gt 5) { Place-WithAddon 'Allies1' $b[0] $b[5] $b[1] $b[2] $b[3] $b[4] }
        else { Place-AtWp 'Allies1' $b[0] $b[1] 0 'None' $b[4] 0 $b[2] $b[3] }
    }
    Smudges $D[$k].Sq 8 3 8
}
# the swarm in the districts (Nod1): a pack by every district, a smaller one on its square
$L = 'SCZLNG'; $Hy = 'SCZHYL'; $In = 'SCZINF'; $Ul = 'SCZULT'; $Mu = 'SCZMUT'; $Br = 'SCZBRD'
Squad 'Nod1' @($L, $L, $L, $L, $L, $L, $Hy, $Hy) 23 0 0 'Area Guard'
Squad 'Nod1' @($L, $L, $L, $L, $L, $Hy, $Hy, $Hy) 28 0 0 'Area Guard'
Squad 'Nod1' @($L, $L, $L, $L, $L, $L, $In, $In) 33 0 0 'Area Guard'
Squad 'Nod1' @($L, $L, $L, $L, $L, $Hy, $Hy) 37 0 0 'Area Guard'
foreach ($k in 1..4) { Squad 'Nod1' @($L, $L, $L) $D[$k].Sq -4 -3 'Area Guard' }
# the city still fights (user 2026-10-27: "wiecej walk miedzy sojuszniczymi jednostkami terranow a zergami"): a
# Confederate squad on every square, and checkpoints on the streets (bunker + Marines) with a Zerg pack a few cells
# away that engages them at once; repeated Overlord drops and militia keep it going (triggers amb/mil below)
Squad 'Allies1' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE', 'SCFIRE', 'SCGOLI', 'SCSIEGE') 20 3 -3 'Area Guard'
Squad 'Allies1' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE', 'SCGOLI', 'SCSIEGE') 25 -3 3 'Area Guard'
Squad 'Allies1' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE', 'SCFIRE', 'SCGOLI') 30 3 3 'Area Guard'
Squad 'Allies1' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE', 'SCGOLI') 35 -3 -2 'Area Guard'
foreach ($n in 61, 62, 63, 64) {
    Place-AtWp 'Allies1' 'SCBUNK' $n 0 'None' 200 0 2 -2
    Place-AtWp 'Allies1' $streetb[$n][0] $n 0 'None' (170 + $rnd.Next(80)) 0 -4 -3
    Place-AtWp 'Allies1' $streetb[$n][1] $n 0 'None' (170 + $rnd.Next(80)) 0 5 3
    Squad 'Allies1' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE') $n 1 1 'Area Guard'
    Squad 'Nod1' @($L, $L, $L, $L, $Hy) $n -5 4 'Area Guard'
}

# ================================================================ the psi emitters (Nod2) and the swarm round them
$psiTags = 'ARKA5G03', 'ARKA5G04', 'ARKA5G05'
for ($e = 0; $e -lt 3; $e++) {
    $n = 40 + $e; Place-AtWp 'Nod2' 'ARKPSIE' $n 1 $psiTags[$e] 256
    Place-AtWp 'Nod1' 'SCZSUN' $n 0 'None' 256 0 3 3
    Place-AtWp 'Nod1' 'SCZCRP' $n 0 'None' 256 0 -3 2
    Squad 'Nod1' @($L, $L, $L, $L, $Hy, $Hy) $n 2 -4 'Area Guard'
}

# ================================================================ the Protoss landing site (GDI, against everybody)
if (Get-Command Add-ProtossLanding -ErrorAction SilentlyContinue) { Add-ProtossLanding } else {
Place-AtWp 'GDI' 'SCPPYL' 50 1 'ARKA5G06'
Place-AtWp 'GDI' 'SCPGAT' 50 1 'None' 256 0 4 2
Place-AtWp 'GDI' 'SCPPYL' 50 1 'None' 256 0 -4 3
Place-AtWp 'GDI' 'SCPPYL' 50 1 'None' 256 0 3 -4
foreach ($c in @(@(-6, -2), @(-5, 5), @(2, 6))) { Place-AtWp 'GDI' 'SCPCAN' 50 0 'None' 256 0 $c[0] $c[1] }
Squad 'GDI' @('SCPZEAL', 'SCPZEAL', 'SCPZEAL', 'SCPZEAL', 'SCPDRAG', 'SCPDRAG', 'SCPDRAG') 51 0 0 'Area Guard'
}

if (Get-Command Add-ZergNest -ErrorAction SilentlyContinue) { Add-ZergNest }

# ================================================================ Kerrigan's holdout (GDI1, the place the user marked on the render)
# 3 bunkers and 3 Supply Depots of the Sons of Korhal, Kerrigan and 14 Marines; the swarm presses them from the start
# (drops on wp 59/60, triggers kerPress). Kerrigan and her Marines share the tag of "the swarm takes them" (action 115)
foreach ($b in @(@(4, -2), @(-4, 3), @(3, 4))) { Place-AtWp 'GDI1' 'SCBUNK' 48 0 'None' 256 0 $b[0] $b[1] }
foreach ($b in @(@(-4, -3), @(-6, 1), @(0, -5))) { Place-AtWp 'GDI1' 'SCDEPO' 58 0 'None' (180 + $rnd.Next(70)) 0 $b[0] $b[1] }
Add-Unit 'GDI1' 'ARKKERR' $wp[48][0] $wp[48][1] 'Guard' 'ARKA5G08' 256 2
foreach ($c in @(@(2, 0), @(-2, 1), @(1, 3), @(-1, -3))) {
    Squad 'GDI1' @('SCMARINE', 'SCMARINE', 'SCMARINE') 48 $c[0] $c[1] 'Guard' 256 'ARKA5G08'
}
Squad 'GDI1' @('SCMARINE', 'SCMARINE') 58 1 1 'Guard' 256 'ARKA5G08'
# heavier support (user 2026-10-28): two Goliaths and a Siege Tank already deployed (the building SCSIEGB, which can
# pack up into SCSIEGE), all with the same tag
Squad 'GDI1' @('SCGOLI', 'SCGOLI') 48 -3 -2 'Guard' 256 'ARKA5G08'
Place-AtWp 'GDI1' 'SCSIEGB' 48 0 'ARKA5G08' 256 0 -1 2
Smudges 48 8 2 7
# the slime trail from Kerrigan's position into the swarm (scorch marks)
for ($i = 0; $i -le 6; $i++) {
    $sx = [int]($wp[48][0] + ($wp[49][0] - $wp[48][0]) * $i / 6); $sy = [int]($wp[48][1] + ($wp[49][1] - $wp[48][1]) * $i / 6)
    if (Buildable $sx $sy) { $ini.Set('Smudge', "$smN", ('BURN{0:D2},{1},{2},0' -f (1 + $rnd.Next(6)), $sx, $sy)); $smN++ }
}

# ================================================================ more creep-sowing Overlords (user 2026-10-28)
# "przy wezwaniu Kerrigan 2 overlordy co pluja creepem": wp 82/83 on hole ground by the swarm's drop points east and
# south of her holdout (wp 59/60). "Plujace overlordy po mapie, nie tak gesto, ale tak by sie zlaczyly z creepem
# budynkow": one spot per Zerg cluster, two at the nest (wp 84+), 11-14 cells from its centre, so the Overlord's vein
# circle (~8.5) meets the circle of the buildings' holes. Among the spots in that ring the one farthest from what would
# shoot it down (landing zone, district squares, checkpoints, Kerrigan, the Protoss) and from the other spots
function Cheb($a, $b) { [Math]::Max([Math]::Abs($a[0] - $b[0]), [Math]::Abs($a[1] - $b[1])) }
$creepSpots = New-Object Collections.Generic.List[object]   # wp, entry wp, label
$nextWp = 82
foreach ($k in @(@(59, 47), @(60, 45))) {
    $c = $wp[$k[0]]; $best = $null; $bd = 1e9
    for ($x = $c[0] - 6; $x -le $c[0] + 6; $x++) { for ($y = $c[1] - 6; $y -le $c[1] + 6; $y++) {
        $dist = ($x - $c[0]) * ($x - $c[0]) + ($y - $c[1]) * ($y - $c[1])
        if ($dist -lt $bd -and (Hole-Ground $x $y) -and -not @($creepSpots | Where-Object { (Cheb $wp[$_[0]] @($x, $y)) -lt 5 }).Count) { $bd = $dist; $best = @($x, $y) }
    } }
    if (-not $best) { $log.Add("WARN no hole ground near wp $($k[0]) for Kerrigan's creep Overlord"); continue }
    $wp[$nextWp] = $best; $ini.Set('Waypoints', "$nextWp", "$($best[1] * 1000 + $best[0])"); $creepSpots.Add(@($nextWp, $k[1], "przy Kerrigan (wp $($k[0]))"))
    $log.Add("wp $nextWp creep spot at Kerrigan's call = $($best -join ',') (by wp $($k[0]))"); $nextWp++
}
$kerSpots = @(); foreach ($s in $creepSpots) { $kerSpots += , $s }   # (a pipeline would flatten the pairs)
$threat = @(10, 20, 25, 30, 35, 48, 50, 51, 61, 62, 63, 64 | ForEach-Object { , $wp[$_] })
$need = @{ 0 = 18; 5 = 14; 6 = 18; 7 = 18 }   # index in $threat -> min distance (others 12)
$entries = 43, 44, 45, 46, 47, 55, 56, 57
$mapSpots = @()
foreach ($cl in @(@(71, 'gniazdo'), @(71, 'gniazdo'), @(40, 'nadajnik W'), @(41, 'nadajnik SW'), @(42, 'nadajnik SE'))) {
    $c = $wp[$cl[0]]; $best = $null; $bs = -1
    for ($x = $c[0] - 14; $x -le $c[0] + 14; $x++) { for ($y = $c[1] - 14; $y -le $c[1] + 14; $y++) {
        $r2 = ($x - $c[0]) * ($x - $c[0]) + ($y - $c[1]) * ($y - $c[1]); if ($r2 -lt 121 -or $r2 -gt 196) { continue }
        if (-not (Hole-Ground $x $y)) { continue }
        $p = @($x, $y); $ok = $true; $score = 1e9
        for ($t = 0; $t -lt $threat.Count; $t++) { $dd = Cheb $p $threat[$t]; $min = if ($need.ContainsKey($t)) { $need[$t] } else { 12 }; if ($dd -lt $min) { $ok = $false; break }; $score = [Math]::Min($score, $dd - $min) }
        foreach ($s in $creepSpots) { $dd = Cheb $p $wp[$s[0]]; if ($dd -lt 10) { $ok = $false }; $score = [Math]::Min($score, $dd - 10) }
        if ($ok -and $score -gt $bs) { $bs = $score; $best = $p }
    } }
    if (-not $best) { $log.Add("creep Overlord at $($cl[1]): no safe hole ground 11-14 cells from wp $($cl[0])"); continue }
    # the nearest entry whose straight flight keeps 16+ cells from the Protoss cannons (wp 50) and 12+ from Kerrigan's
    # Marines (wp 48); the nearest at all if none does
    $safe = @($entries | Where-Object {
        $a = $wp[$_]; $okF = $true
        for ($t2 = 0; $t2 -le 20; $t2++) { $q2 = @(($a[0] + ($best[0] - $a[0]) * $t2 / 20), ($a[1] + ($best[1] - $a[1]) * $t2 / 20)); if ((Cheb $q2 $wp[50]) -lt 16 -or (Cheb $q2 $wp[48]) -lt 12) { $okF = $false } }
        $okF })
    $en = @($(if ($safe.Count) { $safe } else { $entries }) | Sort-Object { Cheb $wp[$_] $best })[0]
    $wp[$nextWp] = $best; $ini.Set('Waypoints', "$nextWp", "$($best[1] * 1000 + $best[0])"); $creepSpots.Add(@($nextWp, $en, $cl[1])); $mapSpots += $nextWp
    $log.Add("wp $nextWp creep spot by the $($cl[1]) = $($best -join ',') (entry wp $en, margin $bs)"); $nextWp++
}

# ================================================================ cell-tag zones (one tag per cell; inner zones first)
function Zone($tag, [int]$n, [int]$rMin, [int]$rMax) {
    $cx = $wp[$n][0]; $cy = $wp[$n][1]; $c = 0
    for ($x = $cx - $rMax; $x -le $cx + $rMax; $x++) { for ($y = $cy - $rMax; $y -le $cy + $rMax; $y++) {
        $d = [Math]::Max([Math]::Abs($x - $cx), [Math]::Abs($y - $cy))
        if ($d -lt $rMin -or $code[$y * $GW + $x] -lt 0) { continue }
        $key = "$($y * 1000 + $x)"; if ($ini.Get('CellTags', $key, $null)) { continue }
        $ini.Set('CellTags', $key, $tag); $c++
    } }
    $log.Add("zone $tag around wp $n r $rMin-$rMax : $c cells")
}
for ($k = 1; $k -le 4; $k++) { Zone ('ARKA5G1{0}' -f ($k - 1)) $D[$k].Sq 0 5 }   # the player on the district square
Zone 'ARKA5G14' 48 0 6                                                               # Kerrigan's position

# ================================================================ dialogue ([Tutorial] of the map, numbers 9501-9599)
$textNo = 9500
function Say([string]$s) { if ($s -match '[^\x20-\x7E]') { throw "non-ASCII text: $s" }; $script:textNo++; if ($script:textNo -gt 9599) { throw "text numbers above 9599" }; $ini.Set('Tutorial', "$script:textNo", $s); $script:textNo }

# ================================================================ taskforces, scripts, teams
$tfN = 0; $tmN = 0
function Team($name, $house, $spawnWp, [string[]]$members, [string[]]$script, $tag = $null) {
    $script:tfN++; $script:tmN++
    $tf = 'ARKA5F{0:D2}' -f $script:tfN; $sc = 'ARKA5S{0:D2}' -f $script:tfN; $tm = 'ARKA5M{0:D2}' -f $script:tmN
    $ini.Set('TaskForces', "$($script:tfN - 1)", $tf); $ini.Set('ScriptTypes', "$($script:tfN - 1)", $sc); $ini.Set('TeamTypes', "$($script:tmN - 1)", $tm)
    $grp = @($members | Group-Object | ForEach-Object { "$($_.Count),$($_.Name)" })
    for ($i = 0; $i -lt $grp.Count; $i++) { $ini.Set($tf, "$i", $grp[$i]) }
    $ini.Set($tf, 'Name', $name); $ini.Set($tf, 'Group', '-1')
    for ($i = 0; $i -lt $script.Count; $i++) { $ini.Set($sc, "$i", $script[$i]) }
    $ini.Set($sc, 'Name', $name)
    $v = [ordered]@{ Max = 0; Full = 'no'; Name = $name; Group = -1; House = $house; Script = $sc; Whiner = 'no'; Droppod = 'no'; Suicide = 'no'
        Loadable = 'no'; Prebuild = 'no'; Priority = 5; Waypoint = (WpLetter $spawnWp); Annoyance = 'no'; IonImmune = 'no'; Recruiter = 'no'
        Reinforce = 'no'; TaskForce = $tf; TechLevel = 0; Aggressive = 'yes'; Autocreate = 'no'; GuardSlower = 'no'; OnTransOnly = 'no'
        AvoidThreats = 'no'; LooseRecruit = 'no'; VeteranLevel = 1; IsBaseDefense = 'no'; OnlyTargetHouseEnemy = 'no'
        TransportsReturnOnUnload = 'no'; AreTeamMembersRecruitable = 'no' }
    if ($tag) { $v['Tag'] = $tag }
    foreach ($k in $v.Keys) { $ini.Set($tm, $k, "$($v[$k])") }
    $tm
}
# locals ([VariableNames]); the civilian teams set "boarded" themselves (script 39)
$vars = 'Gracz w Delcie', 'Gracz w Novej', 'Gracz w Omedze', 'Gracz w Gammie', 'Delta padla', 'Nova padla', 'Omega padla', 'Gamma padla',
    'Delta A na pokladzie', 'Delta B na pokladzie', 'Nova A na pokladzie', 'Nova B na pokladzie', 'Omega A na pokladzie', 'Omega B na pokladzie', 'Gamma A na pokladzie', 'Gamma B na pokladzie',
    'Delta otwarta', 'Nova otwarta', 'Omega otwarta', 'Gamma otwarta', 'Nadajnik W zniszczony', 'Nadajnik SW zniszczony', 'Nadajnik SE zniszczony', 'Mengsk ostrzegl',
    'Kerrigan wzywa', 'Kerrigan porwana', 'Gracz przy Kerrigan', 'Scena Kerrigan', '30 cywilow', 'Ewakuacja'
for ($i = 0; $i -lt $vars.Count; $i++) { $ini.Set('VariableNames', "$i", "$($vars[$i]),0") }
$V = @{ Near = 0; Fall = 4; Saved = 8; Rel = 16; Psi = 20; Warned = 23; Call = 24; Taken = 25; KerNear = 26; Scene = 27; Done30 = 28; Evac = 29 }

# script lines: 3,N move; 16,N patrol = attack-move; 0,3 attack harvesters; 11,14 hunt; 11,10 area guard; 5,N guard
# N x 6 s; 39,N set local N; 37 delete members. NOT 1,N for ground teams (they stop there for good, ARKA 0 test);
# 1,N only for flyers
$civ6 = @('ARKCIV1', 'ARKCIV1', 'ARKCIV1', 'ARKCIV2', 'ARKCIV2', 'ARKCIV2')
$tmCiv = @{}
for ($g = 1; $g -le 8; $g++) {
    $k = [int][Math]::Ceiling($g / 2); $ab = if ($g % 2) { 'A' } else { 'B' }
    $tmCiv[$g] = Team "Cywile $($D[$k].Name) $ab" "Cyw$g" (64 + $k) $civ6 @('3,10', "39,$($V.Saved + $g - 1)", '37,0')
}
# Zerg drops: an Overlord carrying up to 8 flies from its entry point to the drop point and unloads (3,N + 8,2); the
# cargo goes on with the rest of the script (user 2026-10-27: the Zerg come in by Overlord)
$escortOf = @{}
function Drop($name, [int]$spawn, [int]$drop, [string[]]$cargo, [string[]]$after) {
    if ($cargo.Count -gt 8) { throw "drop '$name': $($cargo.Count) passengers, the Overlord takes 8" }
    $tm = Team $name 'Nod1' $spawn (@('SCZOVL') + $cargo) (@("3,$drop", '8,2') + $after)
    # two empty Overlords fly along (user 2026-10-28: so that a drop reads as an attack): to the drop point, hover 12 s,
    # back to their entry point and gone; created with every reinforcement of the real drop (see below)
    $script:escortOf[$tm] = Team "$name (eskorta)" 'Nod1' $spawn @('SCZOVL', 'SCZOVL') @("3,$drop", '5,2', "3,$spawn", '37,0')
    $tm
}
# the swarm that takes Kerrigan (at the call), and the pressure on her holdout before it
$tmSwarm = @(
    (Drop 'Roj na Kerrigan: wschod'  47 59 @($L, $L, $L, $L, $L, $L, $Hy, $Hy) @('16,48', '11,14')),
    (Drop 'Roj na Kerrigan: poludnie' 45 60 @($L, $L, $L, $L, $Ul, $Hy, $Hy) @('16,48', '11,14')),
    (Drop 'Roj na Kerrigan: z gory'   55 48 @($Hy, $Hy, $Hy, $Hy, $L, $L, $L, $L) @('16,48', '11,14')))
# heavier fights at the holdout (user 2026-10-28): three Overlords at a time, Hydralisks and an Ultralisk among them
$tmPress = @(
    (Drop 'Napor na Kerrigan: wschod'  45 59 @($L, $L, $L, $L, $L, $L, $Hy, $Hy) @('16,48', '11,14')),
    (Drop 'Napor na Kerrigan: poludnie' 44 60 @($L, $L, $L, $L, $L, $Hy, $Hy, $Hy) @('16,48', '11,14')),
    (Drop 'Napor na Kerrigan: polnoc'   47 48 @($Ul, $Hy, $Hy, $L, $L, $L, $L, $L) @('16,48', '11,14')))
# creep-sowing Overlords (ARKOVLC) while Kerrigan holds out. First version flew over her position and died at once
# (user 2026-10-28), so now one Overlord per spot along the south edge (wp 78-81): in at the SE corner (wp 77), west
# along the edge, then "attack waypoint" (1,N; a flyer, the check allows it) spits at the ground of its spot for good:
# one hole there, its veins grow 30 cells (this mission only, see the creep block)
$tmCreep = @(78, 79, 80, 81 | Where-Object { $wp.ContainsKey($_) } | ForEach-Object { Team "Overlord siejacy creep (wp $_)" 'Nod1' 77 @('ARKOVLC') @("3,$_", "1,$_") })
# the same, one Overlord per spot of $creepSpots (wp, entry wp, label): two at Kerrigan's call, the rest by the nests
$tmCreepAt = @{}
foreach ($s in $creepSpots) { $tmCreepAt[$s[0]] = Team "Overlord siejacy creep ($($s[2]))" 'Nod1' $s[1] @('ARKOVLC') @("3,$($s[0])", "1,$($s[0])") }
# streams fed by the emitters: each goes for the economy first (a crystal field, the harvesters), then the landing zone
$tmStr = @{
    1 = Drop 'Roj z zachodu (nadajnik W)'               43 52 @($L, $L, $L, $L, $L, $L, $Hy, $Hy) @('0,3', '16,10', '11,14')
    2 = Drop 'Roj z poludniowego zachodu (nadajnik SW)' 44 30 @($L, $L, $L, $L, $In, $In, $Hy, $Hy) @('0,3', '16,10', '11,14')
    3 = Drop 'Roj z poludniowego wschodu (nadajnik SE)' 45 53 @($L, $L, $L, $L, $L, $L, $Hy, $Hy) @('0,3', '16,10', '11,14')
}
# the north waves only drop Zerglings and Broodlings (user 2026-10-28)
$tmNorth  = Drop 'Najazd z polnocy' 46 15 @($L, $L, $L, $L, $Br, $Br, $Br, $Br) @('0,3', '11,14')
# Zerglings running in over the north edge (no Overlord): for the civilians' way and the crystals by the crater
$tmTopA   = Team 'Zerglingi z polnocy (zachod)' 'Nod1' 46 @($L, $L, $L, $L, $Br, $Br) @('16,15', '0,3', '16,10', '11,14')
$tmTopB   = Team 'Zerglingi z polnocy (wschod)' 'Nod1' 55 @($L, $L, $L, $L, $Br, $Br) @('16,25', '16,10', '11,14')
$tmMuta   = Team 'Mutaliski'                'Nod1' 55 @($Mu, $Mu, $Mu) @('1,10', '11,14')
# the city: a fallen district, drops on the fighting squares and street checkpoints, Confederate militia
$dropFrom = @{ 1 = 46; 2 = 55; 3 = 44; 4 = 47 }
$tmFall = @{}; $tmAmb = @{}; $tmMil = @{}
for ($k = 1; $k -le 4; $k++) {
    $nm = $D[$k].Name
    $tmFall[$k] = Drop "Roj w dzielnicy $nm" $dropFrom[$k] $D[$k].Sq @($L, $L, $L, $L, $L, $L, $Hy, $Hy) @('11,10')
    $tmAmb[$k]  = Drop "Desant na $nm" $dropFrom[$k] $D[$k].Sq @($L, $L, $L, $L, $Hy, $Hy) @("16,$($D[$k].Sq)", '0,2', '11,10')
    $tmMil[$k]  = Team "Milicja $nm" 'Allies1' $D[$k].Sq @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE') @('11,10')
}
$cpFrom = @{ 61 = 46; 62 = 44; 63 = 47; 64 = 55 }
$tmCp = @{}; foreach ($n in 61, 62, 63, 64) { $tmCp[$n] = Drop "Desant na posterunek $n" $cpFrom[$n] $n @($L, $L, $L, $L, $L, $Hy) @("16,$n", '11,10') }
# the last waves: two Overlords from every side whose emitter still stands, each dropping by the crater
$tmFin = @{
    1 = Drop 'Ostatnia fala: zachod'            43 18 @($L, $L, $L, $L, $L, $L, $Hy, $Hy) @('16,10', '11,14')
    2 = Drop 'Ostatnia fala: poludniowy zachod' 44 17 @($L, $L, $L, $L, $In, $In, $Hy, $Hy) @('16,10', '11,14')
    3 = Drop 'Ostatnia fala: poludniowy wschod' 45 19 @($L, $L, $L, $L, $L, $Ul, $Hy, $Hy) @('16,10', '11,14')
}
$tmFinN   = Drop 'Ostatnia fala: polnoc' 46 15 @($L, $L, $L, $L, $L, $Br, $Br, $Br) @('16,10', '11,14')
$tmFinM   = Team 'Ostatnia fala: mutaliski'   'Nod1' 55 @($Mu, $Mu, $Mu, $Mu, $Mu) @('1,10', '11,14')
$tmFleet  = Team 'Flota Protossow'            'Soviet2' 56 @('SCPCARR', 'SCPCARR', 'SCPSCOU', 'SCPSCOU', 'SCPSCOU', 'SCPSCOU') @('3,57', '37,0')

# ================================================================ triggers
$trN = 0; $trig = [ordered]@{}
function Ev([int]$id, $p = 0) { "$id,0,$p" }
function Act([int]$id, $p = 0, [int]$kind = 0, [int]$w = 0) { "$id,$kind,$p,0,0,0,0,$(WpLetter $w)" }
function Text($s) { Act 11 (Say $s) }
function Reinf($team, $w) { Act 80 $team 1 $w }
function Enable($t) { Act 53 $t 2 }
function Disable($t) { Act 54 $t 2 }
function Credits($house, [int]$amount) { "106,0,$($H[$house]),$amount,0,0,0,A" }
# -Semi: semi-persistent tag (1), springs once every object it is attached to has sprung it (a team tag + event 48 =
# "the whole team is dead")
function Trigger($key, $name, [string[]]$events, [string[]]$actions, $house = 'Allies', [switch]$Disabled, [switch]$Repeat, $tag = $null, $diff = '1,1,1', [switch]$Semi) {
    $script:trN++; $id = 'ARKA5T{0:D2}' -f $script:trN
    $name = $name -replace ',', ' -'
    if (-not $tag) { $tag = 'ARKA5G{0:D2}' -f (30 + $script:trN) }
    $script:trig[$key] = @{ Id = $id; Name = $name; House = $house; Events = $events; Actions = $actions; Disabled = [bool]$Disabled; Repeat = [bool]$Repeat; Tag = $tag; Diff = $diff; Semi = [bool]$Semi }
}
. "$tools\MissionKit.ps1"   # reveal crate, money crates, one text per trigger, dialogue gaps from text length, timeline check
Add-ScAirArmor             # SC flyer armors: Allied AA fires at SC flyers only on order, Dragoons cannot hit the Overlord
# the creep-sowing Overlord is an Overlord too: the same armor
$ovArm = $ini.Get('SCZOVL', 'Armor', $null); if ($ovArm -and $ini.Has('ARKOVLC')) { $ini.Set('ARKOVLC', 'Armor', $ovArm) }
# the spit hurts nothing (user 2026-10-28: the Overlords killed their own holes): 0% against every armor (the base ones,
# Rules [ArmorTypes] and the SC ones Add-ScAirArmor just added). The weapon keeps Damage=8: the warhead animation (the
# creep shard) is picked from the weapon's damage, so Damage=0 could cost the shard; 0% only zeroes what a target takes
$arms = @('none', 'wood', 'light', 'medium', 'heavy', 'concrete') + @($rules['ArmorTypes'].Values) + @($ini.Section('ArmorTypes') | ForEach-Object { $_.Value })
foreach ($a in ($arms | Where-Object { $_ } | Sort-Object -Unique)) { $ini.Set('ARKA5CrpWH', "Modifier.$a", '0%') }
Add-RevealCrate $crate[0] $crate[1]
for ($k = 1; $k -le 4; $k++) {
    $c = Find-Spot $wp[$D[$k].Crate][0] $wp[$D[$k].Crate][1] 1 1 0 $true; Occupy $c[0] $c[1] 1 1
    Add-MoneyCrate $c[0] $c[1] $D[$k].Cash "$($D[$k].Loot): $($D[$k].Cash) kredytow."
}

# --- opening: the bridge of the Hyperion, Raynor's landing zone, the objectives
Trigger 'intro' 'Start: Tarsonis' @((Ev 13 1)) @((Act 48 1 0 10),
    (Text 'Tarsonis, 2500. Synowie Korhalu uderzyli na stolice Konfederacji. Mengsk mowil o ataku na system obrony planety.'), (Enable 'intro2'))
Trigger 'intro2' 'Start 2: Einstein' @((Ev 13 5)) @((Text 'Einstein (radio, z mostka Hyperiona): Pan postawil te pudla w miescie. Tam sa miliony ludzi.'), (Enable 'intro3')) -Disabled
Trigger 'intro3' 'Start 3: Mengsk' @((Ev 13 5)) @((Text 'Mengsk (radio): Historia wybacza zwyciezcom, profesorze.'), (Enable 'intro4')) -Disabled
Trigger 'intro4' 'Start 4: Einstein' @((Ev 13 5)) @((Text 'Einstein (radio): Nie, panie Mengsk. Historia ich tylko zapisuje.'), (Enable 'intro5')) -Disabled
Trigger 'intro5' 'Start 5: Raynor' @((Ev 13 5)) @((Act 55 2 0 10),
    (Text 'Jim Raynor: Nadajniki juz wyja i Zergi zlatuja sie do miasta. Moje transportowce czekaja tu, na ladowisku w kraterze.'), (Enable 'intro6')) -Disabled
Trigger 'intro6' 'Start 6: cel 1' @((Ev 13 5)) @((Act 55 6 0 20), (Act 55 6 0 25), (Act 55 6 0 30), (Act 55 6 0 35),
    (Text 'Cel 1: doprowadz na ladowisko co najmniej 30 cywilow. Wyjda, gdy twoje oddzialy dotra na plac ich dzielnicy.'), (Enable 'intro7')) -Disabled
Trigger 'intro7' 'Start 7: dzielnice' @((Ev 13 5)) @(
    (Text 'Dzielnice: Omega (poludniowy zachod), Gamma (wschod), Nova (polnocny wschod) i Delta (polnocny zachod). Padna w tej kolejnosci.'), (Enable 'intro8')) -Disabled
Trigger 'intro8' 'Start 8: grupy' @((Ev 13 5)) @(
    (Text 'W kazdej dzielnicy czekaja dwie grupy po 6 osob. Cywile sami ida na ladowisko, ale Zergi poluja na nich po drodze.'), (Enable 'intro9')) -Disabled
Trigger 'intro9' 'Start 9: nadajniki' @((Ev 13 5)) @((Act 55 6 0 40), (Act 55 6 0 41), (Act 55 6 0 42),
    (Text 'Tanya: Nadajniki stoja na zachodzie, na poludniowym zachodzie i na poludniowym wschodzie. Mam C4, Komandorze.'), (Enable 'intro10')) -Disabled
Trigger 'intro10' 'Start 10: cel dodatkowy' @((Ev 13 5)) @(
    (Text 'Cel dodatkowy: zniszcz psi-nadajniki (najlepiej C4 Tanyi). Kazdy zniszczony to mniej Zergow z jego strony.'), (Enable 'intro11')) -Disabled
Trigger 'intro11' 'Start 11: straty' @((Ev 13 5)) @((Text 'Tanya i Raynor musza przetrwac. Synowie Korhalu pilnuja ladowiska razem z wami.'), (Enable 'intro12')) -Disabled
Trigger 'intro12' 'Start 12: Mengsk' @((Ev 13 5)) @(
    (Act 55 6 0 48), (Text 'Mengsk (radio): Porucznik Kerrigan trzyma pozycje na poludniu, przed nadajnikiem. Nadajniki zostaja, Komandorze.')) -Disabled

# --- losing
Trigger 'tanLost' 'Tanya zginela' @((Ev 29)) @((Text 'Jim Raynor: Tanya nie zyje... Bez niej nikt nas stad nie wyciagnie.'), (Act 2 $H.Allies)) -tag 'ARKA5G01'
Trigger 'rayLost' 'Raynor zginal' @((Ev 29)) @((Text 'Tanya: Kowboj nie zyje. Jego ludzie nie poleca bez niego.'), (Act 2 $H.Allies)) -tag 'ARKA5G02'
Trigger 'allLost' 'Wszystko stracone' @((Ev 11 $H.Allies)) @((Act 2 $H.Allies))
Trigger 'failLost' 'Za malo cywilow' @((Ev 12 3)) @(
    (Text 'Jim Raynor: Nie zostalo dosc ludzi, zeby uratowac trzydziestu. Przegralismy to miasto.'), (Act 2 $H.Allies)) -house 'Soviet1'

# --- the districts: the player on the square opens it, a fallen district stays shut
$warnText = @{ 1 = 'Jim Raynor: Delta dlugo nie wytrzyma. Jesli chcemy tych ludzi, to teraz, polnocny zachod!'
    2 = 'Jim Raynor: Nova sie sypie. Ktos musi isc na polnocny wschod, zanim bedzie za pozno!'
    3 = 'Jim Raynor: Omega dlugo nie wytrzyma! Poludniowy zachod, szybko!'
    4 = 'Jim Raynor: Gamma wzywa pomocy. Na wschodzie zostalo niewiele czasu!' }
for ($k = 1; $k -le 4; $k++) {
    $nm = $D[$k].Name; $gA = 2 * $k - 1; $gB = 2 * $k
    Trigger "near$k" "$nm - gracz na placu" @((Ev 1 $H.Allies)) @((Act 56 ($V.Near + $k - 1))) -tag ('ARKA5G1{0}' -f ($k - 1))
    Trigger "open$k" "$nm otwarta" @((Ev 36 ($V.Near + $k - 1)), (Ev 37 ($V.Fall + $k - 1))) @(
        (Act 56 ($V.Rel + $k - 1)), (Reinf $tmCiv[$gA] (64 + $k)), (Enable "arm$gA"), (Enable "civB$k"), (Act 55 2 0 (64 + $k)),
        (Text "Cywile ($nm): Wojsko! Idziemy na ladowisko, tylko nas nie zostawiajcie!"))
    Trigger "civB$k" "$nm - druga grupa" @((Ev 13 90)) @((Reinf $tmCiv[$gB] (64 + $k)), (Enable "arm$gB")) -Disabled
    Trigger "warn$k" "$nm - ostrzezenie" @((Ev 13 ($D[$k].Fall - 360)), (Ev 37 ($V.Rel + $k - 1))) @((Act 55 4 0 $D[$k].Sq), (Text $warnText[$k]))
    Trigger "fall$k" "$nm padla" @((Ev 13 $D[$k].Fall), (Ev 37 ($V.Rel + $k - 1))) @(
        (Act 56 ($V.Fall + $k - 1)), (Credits 'Soviet1' 2), (Reinf $tmFall[$k] $D[$k].Sq), (Act 55 4 0 $D[$k].Sq),
        (Text "Dzielnica $nm padla. Nikt stamtad juz nie wyjdzie."))
}
# --- the city keeps fighting (no texts, no radar events: this is background, not the player's alarm): Overlord drops
# on every district square and street checkpoint, Confederate militia from the district's Command Center; a district's
# own fights stop when it falls, all of them at the evacuation
for ($k = 1; $k -le 4; $k++) {
    $nm = $D[$k].Name
    Trigger "amb$k" "$nm - desant na plac" @((Ev 13 (600 + 60 * $k)), (Ev 37 ($V.Fall + $k - 1))) @((Reinf $tmAmb[$k] $dropFrom[$k])) -Repeat -Disabled
    Trigger "mil$k" "$nm - milicja" @((Ev 13 (600 + 45 * $k)), (Ev 37 ($V.Fall + $k - 1))) @((Reinf $tmMil[$k] $D[$k].Sq)) -Repeat -Disabled
}
foreach ($n in 61, 62, 63, 64) { Trigger "cp$n" "Desant na posterunek $n" @((Ev 13 (780 + 60 * ($n - 60)))) @((Reinf $tmCp[$n] $cpFrom[$n])) -Repeat -Disabled }
# a calm start (user 2026-10-28): the city's own fights start only at 15:00, the street checkpoints at 18:20
Trigger 'cityOn' 'Walki w miescie: start' @((Ev 13 900)) @(1..4 | ForEach-Object { Enable "amb$_"; Enable "mil$_" })
Trigger 'cpOn' 'Posterunki: start' @((Ev 13 1100)) @(61..64 | ForEach-Object { Enable "cp$_" })

# --- the groups: boarded (credits to the counter house Allies2) or lost (credits to Soviet1)
for ($g = 1; $g -le 8; $g++) {
    $k = [int][Math]::Ceiling($g / 2); $nm = $D[$k].Name
    # the lost test waits 5 s after the group appears (an empty house would count as destroyed at once)
    Trigger "arm$g" "Grupa $g pilnowana" @((Ev 13 5)) @((Enable "lost$g")) -Disabled
    Trigger "lost$g" "Grupa $g stracona" @((Ev 9 $H["Cyw$g"]), (Ev 37 ($V.Saved + $g - 1))) @(
        (Credits 'Soviet1' 1), (Text "Tanya: Stracilismy grupe cywilow z dzielnicy $nm.")) -Disabled
    Trigger "saved$g" "Grupa $g na pokladzie" @((Ev 36 ($V.Saved + $g - 1))) @((Disable "lost$g"), (Credits 'Allies2' 6))
}
# --- the count: "Credits exceed" of the counter house (6 per group; thresholds 6n-1 work for > and for >=)
for ($c = 1; $c -le 8; $c++) {
    $acts = @((Text "Pilot Raynora: Na pokladzie $(6 * $c) cywilow.$(if ($c -lt 5) { ' Potrzebujemy trzydziestu.' })"))
    if ($c -eq 5) { $acts = @((Act 56 $V.Done30), (Text 'Cel 1 wykonany: 30 cywilow na pokladzie. Kazdy nastepny to kolejne uratowane zycie.')) }
    if ($c -eq 8) { $acts = @((Text 'Pilot Raynora: Wszystkich 48! Nikt z czterech dzielnic nie zostal.')) }
    Trigger "count$c" "Licznik: $(6 * $c) cywilow" @((Ev 12 (6 * $c - 1))) $acts -house 'Allies2'
}

# --- the psi emitters: each destroyed one stops its stream of waves; Mengsk notices the first
$psiName = @{ 1 = 'zachodni'; 2 = 'poludniowo-zachodni'; 3 = 'poludniowo-wschodni' }
for ($e = 1; $e -le 3; $e++) {
    Trigger "psi$e" "Nadajnik $e zniszczony" @((Ev 48)) @((Act 56 ($V.Psi + $e - 1)), (Disable "str${e}R"),
        (Text "Tanya: Nadajnik $($psiName[$e]) poszedl w powietrze. Z tamtej strony bedzie ich mniej.")) -house 'Nod2' -tag $psiTags[($e - 1)]
    Trigger "mengsk$e" "Mengsk widzi ($e)" @((Ev 36 ($V.Psi + $e - 1)), (Ev 37 $V.Warned)) @((Act 56 $V.Warned),
        (Text 'Mengsk (radio): Komandorze, ten nadajnik byl wlasnoscia Synow Korhalu. Zapamietam to sobie.'),
        (Text 'Tanya (cicho): Niech zapamieta. Ja tez mam dobra pamiec.'))
}
Trigger 'psiAll' 'Wszystkie nadajniki zniszczone' @((Ev 36 $V.Psi), (Ev 36 ($V.Psi + 1)), (Ev 36 ($V.Psi + 2))) @(
    (Text 'Jim Raynor: Ostatnie pudlo Mengska ucichlo. Zergi beda teraz tylko glodne, a nie wsciekle.'))

# --- harass on the economy (workflow/mission-design): each emitter feeds a stream from its own side, repeated till
# the emitter dies; a north raid and Mutalisks besides. Text only with the first wave of each kind
# spaced out after the user's remark (2026-10-27: too fast; were 560/700/850 every 330/360/300, north 1250/420, Mutalisks 1700/540)
# calmer again (user 2026-10-28: a calmer start and middle): first drops 1000 / 1300 / 1600, repeats 720 / 780 / 660
$strAt = @{ 1 = @(1000, 720, 'EVA: Overlordy od zachodu, zrzucaja Zergi na pole krysztalow na zachodniej rowninie.'); 2 = @(1300, 780, 'EVA: Overlordy od poludniowego zachodu, zrzucaja Zergi na Omege.'); 3 = @(1600, 660, 'EVA: Overlordy od poludniowego wschodu, zrzucaja Zergi na pole krysztalow na wschodzie.') }
$strWp = @{ 1 = 43; 2 = 44; 3 = 45 }
for ($e = 1; $e -le 3; $e++) {
    Trigger "str$e" "Strumien $e (pierwsza fala)" @((Ev 13 $strAt[$e][0]), (Ev 37 ($V.Psi + $e - 1))) @((Reinf $tmStr[$e] $strWp[$e]), (Act 55 3 0 $strWp[$e]), (Text $strAt[$e][2]), (Enable "str${e}R"))
    Trigger "str${e}R" "Strumien $e (powtarzany)" @((Ev 13 $strAt[$e][1]), (Ev 37 ($V.Psi + $e - 1))) @((Reinf $tmStr[$e] $strWp[$e]), (Act 55 3 0 $strWp[$e])) -Repeat -Disabled
    Trigger "strH$e" "Strumien $e (trudny)" @((Ev 13 ($strAt[$e][0] + 900)), (Ev 37 ($V.Psi + $e - 1)), (Ev 27 12)) @((Reinf $tmStr[$e] $strWp[$e]))
}
Trigger 'north1' 'Najazd z polnocy (pierwszy)' @((Ev 13 1900)) @((Reinf $tmNorth 46), (Act 55 3 0 46), (Text 'EVA: Overlordy od polnocy, zrzucaja Zergi na pole krysztalow przy kraterze.'), (Enable 'northR'))
# north waves 30% less often (user 2026-10-28): every 900 / 0.7 = 1290 s, the Zerglings over the edge 300/360 -> 430/515
Trigger 'northR' 'Najazd z polnocy (powtarzany)' @((Ev 13 1290)) @((Reinf $tmNorth 46), (Act 55 3 0 46)) -Repeat -Disabled
# Zergling harassment over the north edge once 12 civilians are on board (user 2026-10-28), two entry points
Trigger 'topOn' 'Zerglingi z polnocy: start' @((Ev 12 11)) @((Act 55 3 0 46), (Text 'EVA: Zerglingi wbiegaja od polnocnej krawedzi.'), (Enable 'topA'), (Enable 'topB')) -house 'Allies2'
Trigger 'topA' 'Zerglingi z polnocy (zachod)' @((Ev 13 430)) @((Reinf $tmTopA 46)) -Repeat -Disabled
Trigger 'topB' 'Zerglingi z polnocy (wschod)' @((Ev 13 515)) @((Reinf $tmTopB 55)) -Repeat -Disabled
Trigger 'muta1' 'Mutaliski (pierwsze)' @((Ev 13 2400)) @((Reinf $tmMuta 55), (Act 55 3 0 55), (Text 'Tanya: Latajace! Rakiety w gore!'), (Enable 'mutaR'))
Trigger 'mutaR' 'Mutaliski (powtarzane)' @((Ev 13 1000)) @((Reinf $tmMuta 55), (Act 55 3 0 55)) -Repeat -Disabled

# --- the Protoss landing site (seen for the first time)
Trigger 'protoss' 'Protossi odkryci' @((Ev 4)) @((Text 'Tanya: Zlote zbroje i niebieskie ostrza... To Protossi. Strzelaja do wszystkiego, co sie rusza.')) -house 'GDI' -tag 'ARKA5G06'

# --- Kerrigan: her holdout under pressure from the start, the call (3 groups boarded after 20:00, at the latest
# 43:20), the retreat, too late on purpose
Trigger 'kerPress1' 'Napor na Kerrigan (pierwszy)' @((Ev 13 120)) @((Reinf $tmPress[0] 45), (Reinf $tmPress[1] 44), (Enable 'kerPressR'), (Enable 'kerPressR2'))
Trigger 'kerPressR' 'Napor na Kerrigan (powtarzany)' @((Ev 13 210), (Ev 37 $V.Call)) @((Reinf $tmPress[0] 45), (Reinf $tmPress[1] 44)) -Repeat -Disabled
Trigger 'kerPressR2' 'Napor na Kerrigan (z polnocy)' @((Ev 13 330), (Ev 37 $V.Call)) @((Reinf $tmPress[2] 47)) -Repeat -Disabled
# creep-sowing Overlords: once, at 3:00, with a word from Kerrigan (they stay on their spots; a repeat would only stack
# more Overlords over the same holes)
Trigger 'kerCreep1' 'Overlordy siejace creep' @((Ev 13 180), (Ev 37 $V.Call)) (@($tmCreep | ForEach-Object { Reinf $_ 77 }) +
    @((Text 'Kerrigan (radio): Overlordy na poludniu nic nie zrzucaja, tylko pluja na ziemie. A tam, gdzie pluna, ziemia zaczyna zyc.')))
# one creep Overlord by every Zerg cluster (two at the nest), its creep meets the creep of the buildings
if ($mapSpots.Count) {
    Trigger 'mapCreep' 'Overlordy siejace creep przy gniazdach' @((Ev 13 480)) (@($creepSpots | Where-Object { $mapSpots -contains $_[0] } | ForEach-Object { Reinf $tmCreepAt[$_[0]] $_[1] }) +
        @((Text 'Tanya: Nad gniazdami Zergow wisza Overlordy i pluja sluzem. Ten ich dywan rosnie.')))
}
# later (user 2026-10-28: the mission was won too fast): 4 groups on board and 35:00, at the latest 50:00
Trigger 'kerA' 'Kerrigan wzywa (4 grupy)' @((Ev 12 23), (Ev 13 2100)) @((Enable 'call'), (Disable 'kerT')) -house 'Allies2'
Trigger 'kerT' 'Kerrigan wzywa (czas)' @((Ev 13 3000)) @((Enable 'call'), (Disable 'kerA'))
Trigger 'call' 'Kerrigan: wezwanie' @((Ev 13 1)) @((Act 56 $V.Call), (Act 57 $V.KerNear),
    (Reinf $tmSwarm[0] 47), (Reinf $tmSwarm[1] 45), (Reinf $tmSwarm[2] 55), (Disable 'kerPressR'), (Disable 'kerPressR2'), (Enable 'kerGone'), (Act 17 48), (Act 55 4 0 48),
    (Text 'Kerrigan (radio): Jim? Chlopaki, mamy tu maly problem...'), (Enable 'call1b')) -Disabled
# two creep-sowing Overlords come with the swarm at her call (user 2026-10-28), east and south of her holdout
$trig['call'].Actions = @($trig['call'].Actions) + @($kerSpots | ForEach-Object { Reinf $tmCreepAt[$_[0]] $_[1] })
# why the Protoss are there (user 2026-10-27)
Trigger 'call1b' 'Kerrigan 1b: Protossi' @((Ev 13 5)) @((Text 'Kerrigan (radio): Protossi laduja na poludniowym wschodzie i pala wszystko wokol roju. A roj idzie prosto na nas.'), (Enable 'call2')) -Disabled
Trigger 'call2' 'Kerrigan 2: Raynor' @((Ev 13 5)) @((Text 'Jim Raynor: Sarah? Trzymaj sie, juz jedziemy!'), (Enable 'call3')) -Disabled
Trigger 'call3' 'Kerrigan 3: Mengsk' @((Ev 13 5)) @((Enable 'sokGone'), (Text 'Mengsk (radio): Wszystkie jednostki: odwrot. Tarsonis jest stracone.'), (Enable 'call4')) -Disabled
Trigger 'call4' 'Kerrigan 4: Raynor' @((Ev 13 5)) @((Text 'Jim Raynor: Mengsk! Ona tam jest!'), (Enable 'call5')) -Disabled
Trigger 'call5' 'Kerrigan 5: Tanya' @((Ev 13 5)) @((Text 'Tanya: Synowie Korhalu odlatuja. Zostajemy sami, kowboju.'), (Enable 'call6')) -Disabled
Trigger 'call6' 'Kerrigan 6: cel 2' @((Ev 13 5)) @((Text 'Cel 2: dotrzyj do pozycji Kerrigan (poludnie, przed nadajnikiem poludniowo-wschodnim).')) -Disabled
# Mengsk's retreat: the Sons of Korhal units by the landing zone are erased (their tag; the bunkers stay)
Trigger 'sokGone' 'Synowie Korhalu odlatuja' @((Ev 13 15)) @('115,0,0,0,0,0,0,A') -house 'Soviet' -Disabled -tag 'ARKA5G09'
# the swarm takes her: a minute after the call Kerrigan and her Marines (shared tag) leave the map (action 115, used by
# DTA missions with Elapsed Time in 7 triggers, action 32 in 34), and the local tells the scene she is gone
Trigger 'kerGone' 'Roj zabiera Kerrigan' @((Ev 13 60)) @('115,0,0,0,0,0,0,A', (Act 56 $V.Taken)) -house 'GDI1' -Disabled -tag 'ARKA5G08'
Trigger 'taken' 'Kerrigan porwana' @((Ev 36 $V.Taken)) @((Text 'Lacznosc z oddzialem Kerrigan zerwana.'))
Trigger 'kerNear' 'Gracz przy pozycji Kerrigan' @((Ev 1 $H.Allies)) @((Act 56 $V.KerNear)) -tag 'ARKA5G14' -Repeat
Trigger 'scene' 'Kerrigan: za pozno' @((Ev 36 $V.Call), (Ev 36 $V.Taken), (Ev 36 $V.KerNear)) @((Act 48 1 0 48),
    (Text 'Na miejscu zostal tylko karabin Kerrigan. Sluzowaty slad prowadzi w glab roju.'), (Enable 'scene2'))
Trigger 'scene2' 'Kerrigan: Raynor' @((Ev 13 5)) @((Text 'Jim Raynor: Sarah! SARAH!'), (Enable 'scene3')) -Disabled
Trigger 'scene3' 'Kerrigan: Tanya' @((Ev 13 5)) @((Text 'Tanya (cicho): Przykro mi, kowboju.'), (Enable 'scene4')) -Disabled
Trigger 'scene4' 'Kerrigan: Raynor do Mengska' @((Ev 13 5)) @((Text 'Jim Raynor (do ekranu): Zostawiles ja. Ty sukinsynu, zostawiles ja.'), (Enable 'scene5')) -Disabled
Trigger 'scene5' 'Kerrigan: cel 2' @((Ev 13 5)) @((Act 56 $V.Scene), (Text 'Cel 2 zakonczony. Kerrigan zaginela.')) -Disabled
Trigger 'hint' 'Za malo na pokladzie' @((Ev 36 $V.Scene), (Ev 37 $V.Done30)) @(
    (Text 'Jim Raynor: Nie odlecimy z pustymi ladowniami. Potrzebujemy jeszcze cywilow, zanim padna ostatnie dzielnice.'))

# --- the evacuation: Kerrigan's scene done and 30 on board -> 7:00 on the timer, the swarm on the landing zone
$evOff = @('northR', 'mutaR', 'str1R', 'str2R', 'str3R', 'kerPressR', 'kerPressR2', 'topA', 'topB') + @(1..4 | ForEach-Object { "amb$_", "mil$_" }) + @(61..64 | ForEach-Object { "cp$_" })
Trigger 'evac' 'Ewakuacja: start' @((Ev 36 $V.Scene), (Ev 36 $V.Done30)) (@((Act 56 $V.Evac), (Act 27 420), (Act 23), (Act 20 44), (Act 48 1 0 10), (Act 55 4 0 10),
    (Text 'Jim Raynor: Ostatni transport startuje za siedem minut. Wszyscy na ladowisko!'), (Enable 'evac2'),
    (Enable 'fin1'), (Enable 'fin2'), (Enable 'fin3'), (Enable 'finN'), (Enable 'finM'), (Enable 'finH'), (Enable 'evacEnd')) + @($evOff | ForEach-Object { Disable $_ }))
Trigger 'evac2' 'Ewakuacja: cel 3' @((Ev 13 5)) @((Text 'Cel 3: utrzymaj ladowisko do startu ostatniego transportu. Tanya i Raynor musza przetrwac.')) -Disabled
Trigger 'fin1' 'Ostatnia fala: zachod' @((Ev 13 40), (Ev 37 $V.Psi)) @((Reinf $tmFin[1] 43), (Reinf $tmFin[1] 43), (Act 55 3 0 43)) -Disabled
Trigger 'fin2' 'Ostatnia fala: poludniowy zachod' @((Ev 13 100), (Ev 37 ($V.Psi + 1))) @((Reinf $tmFin[2] 44), (Reinf $tmFin[2] 44), (Act 55 3 0 44)) -Disabled
Trigger 'fin3' 'Ostatnia fala: poludniowy wschod' @((Ev 13 160), (Ev 37 ($V.Psi + 2))) @((Reinf $tmFin[3] 45), (Reinf $tmFin[3] 45), (Act 55 3 0 45)) -Disabled
Trigger 'finN' 'Ostatnia fala: polnoc' @((Ev 13 220)) @((Reinf $tmFinN 46), (Reinf $tmFinN 46), (Act 55 3 0 46), (Text 'Tanya: Overlordy ze wszystkich stron! Trzymac ladowisko!')) -Disabled
Trigger 'finM' 'Ostatnia fala: mutaliski' @((Ev 13 280)) @((Reinf $tmFinM 55), (Act 55 3 0 55)) -Disabled
Trigger 'finH' 'Ostatnia fala: trudny' @((Ev 13 330), (Ev 27 12)) @((Reinf $tmFinN 46), (Reinf $tmFin[1] 43), (Reinf $tmFinM 55)) -Disabled
$noLoss = @('tanLost', 'rayLost', 'allLost', 'failLost')
Trigger 'evacEnd' 'Ewakuacja: start transportu' @((Ev 14)) (@($noLoss | ForEach-Object { Disable $_ }) + @(
    (Act 64 10), (Act 65 69), (Act 65 70), (Text 'Pilot Raynora: Wszyscy na pokladzie. Startujemy!'), (Enable 'end1'))) -Disabled
Trigger 'end1' 'Koniec 1: Tarsonis plonie' @((Ev 13 5)) @((Reinf $tmFleet 56), (Act 55 6 0 56),
    (Text 'Tarsonis plonie. Nad miastem pojawia sie flota Protossow.'), (Enable 'end2')) -Disabled
Trigger 'end2' 'Koniec 2: okret' @((Ev 13 5)) @((Text 'Jeden z okretow skreca w strone Antigi Prime. Prosto na ARKE.'), (Enable 'end3')) -Disabled
Trigger 'end3' 'Koniec 3: noc' @((Ev 13 5)) @((Text 'Tej nocy Raynor pierwszy raz slyszy we snie jej glos.'), (Enable 'end4')) -Disabled
Trigger 'end4' 'Koniec 4: sen' @((Ev 13 5)) @((Text 'Kerrigan (we snie): Jim... przyjdz po mnie.'), (Enable 'endWin')) -Disabled
Trigger 'endWin' 'Wygrana' @((Ev 13 40)) @((Act 1 $H.Allies)) -Disabled

if (Get-Command Add-ProtossTriggers -ErrorAction SilentlyContinue) { Add-ProtossTriggers }
if (Get-Command Add-ZergTriggers -ErrorAction SilentlyContinue) { Add-ZergTriggers }

Split-MultiText; Set-DialoguePacing
$textWarn = Test-TextTimeline

# every reinforcement of an Overlord drop also brings its empty escort (same waypoint)
foreach ($k in @($trig.Keys)) {
    $tr = $trig[$k]; $acts = @()
    foreach ($a in $tr.Actions) { $acts += $a; $p = $a -split ','; if ($p[0] -eq '80' -and $escortOf.ContainsKey($p[2])) { $p[2] = $escortOf[$p[2]]; $acts += ($p -join ',') } }
    $tr.Actions = $acts
}

# long action lists go to continuation triggers: the game reads a trigger's [Actions] line into a fixed stack buffer,
# and the 33 actions (774 characters) of "Ewakuacja: start" crashed the mission while loading (C0000409, stack buffer
# overrun; test 2026-10-28). At most 12 actions (~300 characters) per trigger; a continuation is disabled, fires one
# second after the original enables it, belongs to the same house
$maxActs = 12
foreach ($k in @($trig.Keys)) {
    $t = $trig[$k]; $part = 1
    while (@($t.Actions).Count -gt $maxActs) {
        $acts = @($t.Actions); $keep = $acts[0..($maxActs - 2)]; $rest = $acts[($maxActs - 1)..($acts.Count - 1)]
        $ck = "$k~a$part"; $part++
        Trigger $ck "$($t.Name) (ciag $part)" @((Ev 13 1)) $rest -house $t.House -Disabled | Out-Null
        $t.Actions = @($keep) + @(Enable $ck)
        $t = $trig[$ck]
    }
}

# resolve symbolic trigger references and write [Triggers]/[Events]/[Actions]/[Tags]
$idOf = @{}; foreach ($k in $trig.Keys) { $idOf[$k] = $trig[$k].Id }
foreach ($k in $trig.Keys) {
    $t = $trig[$k]
    $acts = foreach ($a in $t.Actions) { $p = $a -split ','; if ($p[1] -eq '2') { if (-not $idOf.ContainsKey($p[2])) { throw "unknown trigger '$($p[2])' in $k" }; $p[2] = $idOf[$p[2]] }; $p -join ',' }
    $ini.Set('Triggers', $t.Id, "$($t.House),<none>,$($t.Name),$([int]$t.Disabled),$($t.Diff),0")
    $ini.Set('Events', $t.Id, "$($t.Events.Count)," + ($t.Events -join ','))
    $ini.Set('Actions', $t.Id, "$(@($acts).Count)," + (@($acts) -join ','))
    $ini.Set('Tags', $t.Tag, "$(if ($t.Repeat) { 2 } elseif ($t.Semi) { 1 } else { 0 }),$($t.Name) 1,$($t.Id)")
}

# ================================================================ Zerg creep (mods/zerg-creep), as ARKA 4
# A campaign mission does not load the faction map code with the creep block, so: vein growth on, the growth and shrink
# rates, buildable veins, the spreader animations in the list (the Zerg buildings' ActiveAnims in Art.ini, and the
# shard of the creep-sowing Overlords), and ImmuneToVeins=yes on every type (the veins hurt whatever stands on them).
$ini.Set('Basic', 'VeinGrowthEnabled', 'yes')
$ini.Set('General', 'VeinholeGrowthRate', '60')
$ini.Set('General', 'VeinholeShrinkRate', '8')      # creep of a dead nest recedes in ~a minute
# only in this mission (user 2026-10-28): the creep of a hole made in game (the Overlords' spit) grows to 30 cells, not
# ~8.5 (patch-veins.ps1 site 14 reads the unused VeinholeMonsterStrength, 1-100 = radius); the holes under the
# buildings keep ~8.5. A 30-cell circle is ~2830 cells, the growth stops at MaxVeinholeGrowth - 40 (DTA 2000)
$ini.Set('General', 'VeinholeMonsterStrength', '30')
$ini.Set('General', 'MaxVeinholeGrowth', '3000')
foreach ($o in 'VEINS', 'VEINHOLEDUMMY') { $ini.Set($o, 'Insignificant', 'yes') }
$an = 0; $haveAnim = @($ini.Section('Animations') | ForEach-Object { $_.Value })
foreach ($a in 'SCZCRSPL', 'SCZCRSHL', 'SCZCRSPS', 'SCZCRSHS') { if ($haveAnim -contains $a) { continue }; $an++; $ini.Set('Animations', "ARKA5ZC0$an", $a); $ini.Set($a, 'Name', "Zerg creep $a") }
$nImm = 0
foreach ($ln in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') {
    $names = @(); if ($rules.ContainsKey($ln)) { $names += @($rules[$ln].Values) }; $names += @($ini.Section($ln) | ForEach-Object { $_.Value })
    foreach ($t in ($names | Sort-Object -Unique)) { if ($t -and $t -notmatch '^\d') { $ini.Set($t, 'ImmuneToVeins', 'yes'); $nImm++ } }
}
$log.Add("creep: vein growth on, $an spreader animations listed, ImmuneToVeins on $nImm types")
# creep from the start under the Zerg buildings (the nest of Nod, the colonies of Nod1 by the emitters): a Veinhole
# Monster in the map under every creep building (Hatchery at foundation cell (1,1), colonies at (0,0); holes 3+ cells
# apart), overlay 167 + 8x 178 round it, and fully grown VEINS (126, data 48) on a disc of radius 5 round each hole
# and on every cell of every Zerg building plus a 1-cell margin; only clear ground without an overlay or a tree, cells
# of non-Zerg buildings stay free. Written after the crates (Add-MoneyCrate refuses a cell with an overlay)
$o = [Pack]::Unpack($ini.Joined('OverlayPack'), $false); $od = [Pack]::Unpack($ini.Joined('OverlayDataPack'), $false)
$tree = @{}; foreach ($kv in $ini.Section('Terrain')) { $tree[[int]$kv.Key] = $true }
$foreign = @{}; $zb = @()
foreach ($kv in $structs) {
    $p = $kv.Value -split ','; $f = Foundation $p[1]; $bx = [int]$p[3]; $by = [int]$p[4]
    if ($p[0] -match '^Nod[12]?$' -and $p[1] -like 'SCZ*') { $zb += , @($p[1], $bx, $by, $f[0], $f[1]); continue }
    for ($i = $bx; $i -lt $bx + $f[0]; $i++) { for ($j = $by; $j -lt $by + $f[1]; $j++) { $foreign[$j * 512 + $i] = $true } }
}
function Creep-Free($x, $y) { $c = $code[$y * $GW + $x]; $i = $y * 512 + $x; ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -and $o[$i] -eq 255 -and -not $tree[$y * 1000 + $x] -and -not $foreign[$i] }
# A hole under EVERY Zerg building, not only under the spreaders (user 2026-10-28: "creep overlordow canceluje creep
# budynkow"). A map hole floods all its connected veins only at map load; from its first AI on it is a building's hole
# ('ZG', patch-veins place 10) and owns just its circle (dx2 + dy2 <= 72, place 12). The first hole made in the game
# (a creep Overlord's) rebuilds every queue (place 6) and veins that no circle holds vanish: the creep under the Pool,
# the Den, the Extractor and the links between the circles went the moment the Overlords' creep came up. Spreaders
# first (their holes sit where their own spawner puts them), then the other buildings
$holes = @(); $nVein = 0
$spreader = 'SCZHAT', 'SCZHIV', 'SCZCRP', 'SCZSUN', 'SCZSPO'
foreach ($b in @($zb | Where-Object { $_[0] -in $spreader }) + @($zb | Where-Object { $_[0] -notin $spreader })) {
    $hx = $b[1]; $hy = $b[2]; if ($b[0] -in 'SCZHAT', 'SCZHIV') { $hx++; $hy++ }
    if (@($holes | Where-Object { [Math]::Max([Math]::Abs($_[0] - $hx), [Math]::Abs($_[1] - $hy)) -lt 3 }).Count) { continue }
    # the spreader's own cell first, then the other cells of the foundation (a colony by a rock ledge; ARKA 2 pattern)
    $cand = @(, @($hx, $hy)); for ($x = $b[1]; $x -lt $b[1] + $b[3]; $x++) { for ($y = $b[2]; $y -lt $b[2] + $b[4]; $y++) { $cand += , @($x, $y) } }
    $at = $null
    foreach ($cc in $cand) {
        if (@($holes | Where-Object { [Math]::Max([Math]::Abs($_[0] - $cc[0]), [Math]::Abs($_[1] - $cc[1])) -lt 3 }).Count) { continue }
        $ok = $true; for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { $c = $code[($cc[1] + $dy) * $GW + $cc[0] + $dx]; if (-not ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -or $o[($cc[1] + $dy) * 512 + $cc[0] + $dx] -ne 255) { $ok = $false } } }
        if ($ok) { $at = $cc; break }
    }
    if (-not $at) { $log.Add("creep: no hole under $($b[0]) @ $hx,$hy (ground or overlay)"); continue }
    if ($at[0] -ne $hx -or $at[1] -ne $hy) { $log.Add("creep: hole of $($b[0]) @ $hx,$hy moved to $($at[0]),$($at[1])") }
    $hx = $at[0]; $hy = $at[1]; $holes += , @($hx, $hy)
    for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { $i = ($hy + $dy) * 512 + $hx + $dx; $o[$i] = $(if ($dx -eq 0 -and $dy -eq 0) { 167 } else { 178 }); $od[$i] = 0 } }
}
$veinAt = { param($x, $y) if (Creep-Free $x $y) { $i = $y * 512 + $x; $o[$i] = 126; $od[$i] = 48; $script:nVein++ } }
# ($hole, not $h or $hl: PowerShell names ignore case; $H is the house index, $hl the house list)
foreach ($hole in $holes) { for ($dx = -5; $dx -le 5; $dx++) { for ($dy = -5; $dy -le 5; $dy++) { if ($dx * $dx + $dy * $dy -le 25) { & $veinAt ($hole[0] + $dx) ($hole[1] + $dy) } } } }
foreach ($b in $zb) { for ($x = $b[1] - 1; $x -le $b[1] + $b[3]; $x++) { for ($y = $b[2] - 1; $y -le $b[2] + $b[4]; $y++) { & $veinAt $x $y } } }
# veins not 4-connected to a hole would go at map load (Place_Monsters; a Pool or Extractor away from the discs kept
# bare ground): each loose patch gets a line of veins to the nearest connected vein within 15 cells (ARKA 2 pattern)
$conn = New-Object 'bool[]' $o.Length
$fill = { param($starts) $q = New-Object Collections.Generic.Queue[int]; foreach ($s in $starts) { if (-not $conn[$s]) { $conn[$s] = $true; $q.Enqueue($s) } }
    while ($q.Count) { $i = $q.Dequeue(); foreach ($nb in -1, 1, -512, 512) { $j = $i + $nb; if (-not $conn[$j] -and ($o[$j] -eq 126 -or $o[$j] -eq 178)) { $conn[$j] = $true; $q.Enqueue($j) } } } }
& $fill @($holes | ForEach-Object { $_[1] * 512 + $_[0] })
$nLoose = 0; $dead = New-Object 'bool[]' $o.Length
for ($i0 = 0; $i0 -lt $o.Length; $i0++) {
    if ($o[$i0] -ne 126 -or $conn[$i0] -or $dead[$i0]) { continue }
    # shortest walk over veins or free ground (BFS, 15 cells round the patch cell) to a connected vein, then veins on it
    $lx = $i0 % 512; $ly = [int][Math]::Floor($i0 / 512); $from = @{ $i0 = -1 }; $q = New-Object Collections.Generic.Queue[int]; $q.Enqueue($i0); $hit = -1
    while ($q.Count -and $hit -lt 0) {
        $i = $q.Dequeue(); foreach ($nb in -1, 1, -512, 512) {
            $j = $i + $nb; $x = $j % 512; $y = [int][Math]::Floor($j / 512)
            if ($from.ContainsKey($j) -or [Math]::Abs($x - $lx) -gt 15 -or [Math]::Abs($y - $ly) -gt 15) { continue }
            if ($conn[$j]) { $from[$j] = $i; $hit = $j; break }
            if ($o[$j] -eq 126 -or $o[$j] -eq 178 -or (Creep-Free $x $y)) { $from[$j] = $i; $q.Enqueue($j) }
        }
    }
    if ($hit -ge 0) { for ($i = $from[$hit]; $i -ne $i0; $i = $from[$i]) { if ($o[$i] -ne 126 -and $o[$i] -ne 178) { & $veinAt ($i % 512) ([int][Math]::Floor($i / 512)) } }; & $fill @($i0) }
    else {   # no way out (cut off by a cliff): the game would drop the patch at load, so it goes here already
        $nLoose++; $q.Enqueue($i0); $dead[$i0] = $true; $n0 = 0
        while ($q.Count) { $i = $q.Dequeue(); $o[$i] = 255; $od[$i] = 0; $n0++; foreach ($nb in -1, 1, -512, 512) { $j = $i + $nb; if (-not $dead[$j] -and $o[$j] -eq 126) { $dead[$j] = $true; $q.Enqueue($j) } } }
        $log.Add("creep: loose veins at $lx,$ly ($n0 cells, no path to a hole) removed")
    }
}
# what the game keeps after the first rebuild: each hole floods its connected veins (8 directions, Build_Growth_Queue)
# only inside its circle dx2 + dy2 <= 72; whatever no hole holds that way goes now, so the creep at the start is the
# creep that stays
$own = New-Object 'bool[]' $o.Length
foreach ($hole in $holes) {
    $q = New-Object Collections.Generic.Queue[int]; $s0 = $hole[1] * 512 + $hole[0]; $seen = @{ $s0 = $true }; $q.Enqueue($s0)
    while ($q.Count) {
        $i = $q.Dequeue(); $own[$i] = $true
        foreach ($nb in -513, -512, -511, -1, 1, 511, 512, 513) {
            $j = $i + $nb; if ($seen.ContainsKey($j)) { continue }; $seen[$j] = $true
            $ddx = ($j % 512) - $hole[0]; $ddy = [int][Math]::Floor($j / 512) - $hole[1]
            if ($ddx * $ddx + $ddy * $ddy -le 72 -and ($o[$j] -eq 126 -or $o[$j] -eq 178)) { $q.Enqueue($j) }
        }
    }
}
$nCut = 0; for ($i = 0; $i -lt $o.Length; $i++) { if ($o[$i] -eq 126 -and -not $own[$i]) { $o[$i] = 255; $od[$i] = 0; $nCut++ } }
$ini.SetPack('OverlayPack', [Pack]::PackData($o, $false, 8192)); $ini.SetPack('OverlayDataPack', [Pack]::PackData($od, $false, 8192))
$log.Add("creep at start: $($holes.Count) holes under $($zb.Count) Zerg buildings, $nVein vein cells, $nLoose loose patches removed, $nCut cells out of every hole's circle removed")

# ================================================================ [Basic], briefing
$basic = [ordered]@{
    Name = 'ARKA #5: Upadek Tarsonis'; Author = 'Zema (teren: Blizzard T10 Operation Silent Scream)'; GameMode = 'Custom Map'; Player = 'Allies'
    Theme = 'TREN226M'; MultiplayerOnly = 'no'; HomeCell = '11'; AltHomeCell = '11'; MaxPlayer = '0'; MinPlayer = '2'; SkipMapSelect = 'yes'
    OneTimeOnly = 'yes'; EndOfGame = 'no'; SkipScore = 'no'; FreeRadar = 'yes'; RequiredAddOn = '1'; NextScenario = ''; AltNextScenario = ''
    # SC-style briefing movie MOVIES\ARKA05B.MP4 from tools\build-briefing.ps1 -Spec ..\briefings\arka05.json
    Brief = 'ARKA05B'
}
foreach ($k in $basic.Keys) { $ini.Set('Basic', $k, $basic[$k]) }
$ini.Sections.Remove('Briefing') | Out-Null; $ini.Order.Remove('Briefing') | Out-Null
$brief = @(
    'Tarsonis, 2500. Synowie Korhalu ruszyli na stolice Konfederacji, a Mengsk mowil Aliantom o ataku na system obrony planety. Prawde Einstein odkryl dopiero na mostku: psi-nadajniki stoja w miescie i wabia Zergi z calej planety.',
    '@@Alianci laduja na obrzezach New Gettysburga, przy transportowcach Raynora. Wyprowadz cywilow z czterech dzielnic, zanim padna. Na pokladzie musi sie znalezc co najmniej 30 osob.',
    '@@Tanya moze wysadzic nadajniki. Mengsk na pewno to zauwazy.')
for ($i = 0; $i -lt $brief.Count; $i++) { $ini.Set('Briefing', "$($i + 1)", $brief[$i]) }
$ini.Set('SpecialFlags', 'Visceroids', 'no')
# the ore grows back slowly next to the mine (Rules [Ore] Spread 0: it never leaves its field); crystals do not grow
$ini.Set('SpecialFlags', 'TiberiumGrows', 'yes')
$ini.Set('SpecialFlags', 'TiberiumSpreads', 'no')
foreach ($s in 'Preview', 'PreviewPack') { $ini.Sections.Remove($s) | Out-Null; $ini.Order.Remove($s) | Out-Null }

[IO.File]::WriteAllText($Out, $ini.Write(), $enc)
$log.Add("written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB): $($trig.Count) triggers, $tmN teams, $($textNo - 9500) texts, $($structs.Count) buildings, $($units.Count) units, $($infs.Count) infantry, $smN smudges")

# ================================================================ client entry: INI\BattleE.ini (merge; other ARKA missions keep their entries)
if (-not $NoBattle) {
    $bf = "$game\INI\BattleE.ini"
    $b = if (Test-Path $bf) { [Ini]::Load($bf) } else { New-Object Ini }
    if (-not $b.Get('Battles', 'ARKAH', $null)) { $b.Set('Battles', 'ARKAH', 'HEADER_ARKA'); $b.Set('HEADER_ARKA', 'Description', 'ARKA: Blad znaku'); $b.Set('HEADER_ARKA', 'Categories', 'CAT_SA') }
    $b.Set('Battles', 'ARKA05', 'M_ARKA05')
    $m = [ordered]@{ CD = '-1'; Scenario = 'Maps/Missions/arka05.map'; Description = 'ARKA #5: Upadek Tarsonis'; Author = 'Zema'; RequiredAddon = '1'; Side = '2'
        IconPath = 'alliesicon.png'; PlayerAlwaysOnNormalDifficulty = 'yes'; Categories = 'CAT_SA'
        LongDescription = 'Tarsonis, 2500. Psi-nadajniki Mengska sciagaja Zergi do stolicy Konfederacji. @@Wyprowadz co najmniej 30 cywilow z czterech dzielnic New Gettysburga na ladowisko Raynora, zanim padna, zdecyduj, czy wysadzic nadajniki, i utrzymaj ladowisko do startu ostatniego transportu.' }
    foreach ($k in $m.Keys) { $b.Set('M_ARKA05', $k, $m[$k]) }
    $head = "; ARKA campaign (Claude, Modding/wiki/plans/campaign-arka). Extra battle file read by the client`r`n; (Resources/ClientDefinitions.ini BattleFSFileName=BattleE.ini); written by Modding/tools/build-arka0*-mission.ps1.`r`n"
    [IO.File]::WriteAllText($bf, $head + $b.Write(), [Text.Encoding]::ASCII)
    $log.Add("BattleE.ini: M_ARKA05 merged (entries: " + (($b.Section('Battles') | ForEach-Object { $_.Key }) -join ',') + ")")
}

# ================================================================ checks
$fail = 0
foreach ($k in $trig.Keys) { foreach ($a in $trig[$k].Actions) { $p = $a -split ','; if ($p[0] -eq '80' -and -not $ini.Has($p[2])) { $log.Add("FAIL team $($p[2]) missing"); $fail++ } } }
foreach ($sec in 'Structures', 'Units', 'Infantry') {
    $ti = @{ Structures = 6; Units = 7; Infantry = 8 }[$sec]
    foreach ($kv in $ini.Section($sec)) {
        $p = $kv.Value -split ','
        if ($p[$ti] -ne 'None' -and -not $ini.Get('Tags', $p[$ti], $null)) { $log.Add("FAIL $sec tag $($p[$ti]) has no [Tags] entry"); $fail++ }
        $typ = $p[1]; if (-not ($rules.ContainsKey($typ) -or $ini.Has($typ))) { $log.Add("FAIL $sec type $typ is defined nowhere"); $fail++ }
        $want = @{ Structures = 'BuildingTypes'; Units = 'VehicleTypes'; Infantry = 'InfantryTypes' }[$sec]
        $isIn = @($ini.Section($want) | Where-Object { $_.Value -eq $typ }).Count -gt 0 -or $listOf[$typ] -eq $want -or $listOf[$typ] -eq "Rules:$want"
        if (-not $isIn) { $log.Add("FAIL $sec holds $typ, which is not in [$want]"); $fail++ }
        if (-not $ini.Get('Houses', "$($H[$p[0]])", $null) -or -not $H.ContainsKey($p[0])) { $log.Add("FAIL $sec owner $($p[0]) is not a house"); $fail++ }
    }
}
foreach ($ct in ($ini.Section('CellTags') | ForEach-Object { $_.Value } | Sort-Object -Unique)) { if (-not $ini.Get('Tags', $ct, $null)) { $log.Add("FAIL cell tag $ct has no [Tags] entry"); $fail++ } }
foreach ($kv in $ini.Section('TeamTypes')) { $tg = $ini.Get($kv.Value, 'Tag', $null); if ($tg -and -not $ini.Get('Tags', $tg, $null)) { $log.Add("FAIL team $($kv.Value) tag $tg has no [Tags] entry"); $fail++ } }
foreach ($id in ($ini.Section('TaskForces') | ForEach-Object { $_.Value })) {
    foreach ($kv in $ini.Section($id)) {
        if ($kv.Key -notmatch '^\d+$') { continue }
        if ($kv.Value -notmatch '^\d+,(\w+)$') { $log.Add("FAIL taskforce $id entry '$($kv.Value)'"); $fail++; continue }
        if (-not ($rules.ContainsKey($matches[1]) -or $ini.Has($matches[1]))) { $log.Add("FAIL taskforce $id type $($matches[1]) is defined nowhere"); $fail++ }
    }
}
foreach ($kv in $ini.Section('Triggers')) { if (($kv.Value -split ',').Count -ne 8) { $log.Add("FAIL trigger $($kv.Key) has $(($kv.Value -split ',').Count) fields"); $fail++ } }
# no INI line of the trigger sections may come near the game's line buffer (774 characters crashed the game)
foreach ($sn in 'Triggers', 'Events', 'Actions', 'Tags') { foreach ($kv in $ini.Section($sn)) { $len = $kv.Key.Length + 1 + $kv.Value.Length; if ($len -gt 400) { $log.Add("FAIL [$sn] $($kv.Key) is $len characters long (keep under 400)"); $fail++ } } }
foreach ($ln in $listNames) { foreach ($kv in $ini.Section($ln)) { if (-not ($ini.Has($kv.Value) -or $rules.ContainsKey($kv.Value))) { $log.Add("FAIL $ln entry $($kv.Value) has no section"); $fail++ } } }
foreach ($kv in $ini.Section('TeamTypes')) {
    $tm = $kv.Value; $airN = @($ini.Section($ini.Get($tm, 'TaskForce', '')) | Where-Object { $_.Value -match ',(SCZMUT|SCZOVL|ARKOVLC|SCDROP|SCPCARR|SCPSCOU)$' }).Count
    $s1 = @($ini.Section($ini.Get($tm, 'Script', '')) | Where-Object { $_.Key -match '^\d+$' -and $_.Value -match '^1,' }).Count
    if ($s1 -and -not $airN) { $log.Add("FAIL ground team $tm ($($ini.Get($tm, 'Name', ''))) uses script action 1"); $fail++ }
}
foreach ($ln in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') {
    foreach ($kv in $ini.Section($ln)) { $img = $ini.Get($kv.Value, 'Image', $kv.Value); if (-not $art.ContainsKey($img)) { $log.Add("FAIL $($kv.Value): no [$img] in Art.ini (would be invisible)"); $fail++ } }
}
foreach ($t in 'AMCV', 'TANYA') {
    if (-not $rules.ContainsKey($t)) { $log.Add("FAIL $t is not in Rules.ini"); $fail++; continue }
    $img = if ($rules[$t]['Image']) { $rules[$t]['Image'] } else { $t }; if (-not $art.ContainsKey($img)) { $log.Add("FAIL $t has no art [$img]"); $fail++ }
}
foreach ($s in $scTypes) { foreach ($k in 'Prerequisite', 'BuiltAt') { $v = $ini.Get($s, $k, $null); if ($v) { foreach ($tok in ($v -split ',')) { $tok = $tok.Trim(); if ($tok -and $tok -notmatch '^(POWER|FACTORY|BARRACKS|RADAR|TECH|PROC|none)$' -and -not ($ini.Has($tok) -or $rules.ContainsKey($tok))) { $log.Add("FAIL $s $k names $tok"); $fail++ } } } } }
# local variables set by team scripts (39,N) and tested by triggers must exist in [VariableNames]
foreach ($id in ($ini.Section('ScriptTypes') | ForEach-Object { $_.Value })) { foreach ($kv in $ini.Section($id)) { if ($kv.Value -match '^39,(\d+)$' -and -not $ini.Get('VariableNames', $matches[1], $null)) { $log.Add("FAIL script $id sets undeclared local $($matches[1])"); $fail++ } } }
# every house a trigger names exists in [Houses]
foreach ($k in $trig.Keys) { if (-not $H.ContainsKey($trig[$k].House)) { $log.Add("FAIL trigger $k house $($trig[$k].House)"); $fail++ } }
# nothing stands on the landing zone cell the civilians walk to
$lz = "$($wp[10][1] * 1000 + $wp[10][0])"
foreach ($sec in 'Structures', 'Units', 'Infantry') { foreach ($kv in $ini.Section($sec)) { $p = $kv.Value -split ','; if ("$([int]$p[4] * 1000 + [int]$p[3])" -eq $lz) { $log.Add("FAIL $sec $($p[1]) stands on the landing zone wp 10"); $fail++ } } }
$log.Add($(if ($fail) { "CHECKS: $fail FAIL" } else { 'CHECKS: PASS (types defined, teams exist, every tag has a trigger, prerequisites resolve, houses exist)' }) + "; text timeline: $textWarn WARN")
$log | Set-Content "$work\log.txt" -Encoding UTF8
$log | Where-Object { $_ -notmatch '^building ' }

if ($Render) {
    $dir = "$game\Map Editor\Map Renderer"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$Out`" -o arka05_mission -d `"$work`" -p -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "renderer timed out" }
    "render: $work\arka05_mission.png"
}
