# Mission layer of ARKA mission 1 "Obcy piasek" (Mar Sara, 2499): houses, the ARKA wreck, survivors, the damaged MCV,
# the Mar Sara colony with Jim Raynor, the Zerg nest, waves, dialogue and the client entry. Reads the terrain map built
# by build-arka01-marsara.ps1 (Maps\Custom\arka01_marsara.map, read-only) and writes Maps\Missions\arka01.map.
# Waypoints 10-45 of the terrain map are the contract between the two layers (wiki missions/arka-01-marsara).
#
#   powershell -NoProfile -File .\build-arka01-mission.ps1            # build + checks
#   powershell -NoProfile -File .\build-arka01-mission.ps1 -Render    # also render %TEMP%\arka01-mission\arka01_mission.png
#
# StarCraft types: a campaign mission does not load the StarCraft checkbox (INI\Game Options\StarCraft.ini) nor the
# faction map code (INI\Map Code\Terran Faction.ini), so the rules of every SC type used here are copied into the map,
# with everything they reference (weapons, projectiles, warheads, anims, deploy partners). Art, sounds and MIX files are
# global and need nothing. Texts: ASCII Polish (Windows-1252 font), [Tutorial] numbers 9101-9199 (= mission 1).
# Time units: Elapsed Time counts game seconds (the on-screen timer).
param(
    [string]$Terrain = "",
    [string]$Out = "",
    [switch]$Render,
    [switch]$NoBattle
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Terrain) { $Terrain = "$game\Maps\Custom\arka01_marsara.map" }
if (-not $Out) { $Out = "$game\Maps\Missions\arka01.map" }
$work = "$env:TEMP\arka01-mission"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\TsMap.cs" -ReferencedAssemblies System.Drawing
$enc = [Text.Encoding]::GetEncoding(1252)

$ini = [Ini]::Load($Terrain)
$log = New-Object Collections.Generic.List[string]

# ================================================================ terrain occupancy (what may hold a building or unit)
$mixes = New-Object MixSet "$game\MIX"
$th    = New-Object Theater "$game\INI\Desert.ini", "des", $mixes
$GW = 512
$code = New-Object 'int[]' ($GW * $GW); for ($i = 0; $i -lt $code.Length; $i++) { $code[$i] = -1 }   # -1 = off map
foreach ($t in [IsoMap]::Decode([Pack]::Unpack($ini.Joined('IsoMapPack5'), $true))) {
    $tile = if ($t.Tile -lt 0 -or $t.Tile -ge 65535) { 0 } else { $t.Tile }
    $tmp = $th.Get($tile); $c = 0
    if ($tmp -and $t.Sub -lt $tmp.Cells.Length -and $tmp.Cells[$t.Sub]) { $c = $tmp.Cells[$t.Sub].Terrain }
    $code[$t.Y * $GW + $t.X] = $c
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
# which list registers a section ([InfantryTypes], [Animations], ...)
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
    'SCZLNG', 'SCZHYL', 'SCZMUT', 'SCZOVL',                         # Zerg units
    'SCZHAT', 'SCZPOL', 'SCZCRP', 'SCZSUN',                         # Zerg nest
    'SCMARINE', 'SCFIRE', 'SCVULT', 'SCSCV',                        # colony units (Raynor = SCVULT copy below)
    'SCCC', 'SCBARR', 'SCACAD', 'SCBUNK', 'SCDEPO', 'SCFACT', 'SCREFI',   # colony buildings (factory + refinery: the colony AI produces and mines)
    'SCPOBSV')                                                      # Protoss Observer (epilogue)
$scTypes = Get-ScClosure $scRoots
$known = @{}; foreach ($s in $scTypes) { $known[$s] = $true }
$nList = @{}
foreach ($s in $scTypes) {
    foreach ($k in $scSec[$s].Keys) {
        $v = $scSec[$s][$k]
        # prerequisites/factories naming SC types or groups that are not in the map would point at nothing: keep only
        # names that exist here (copied SC types or Rules sections); nobody builds these types in the mission anyway
        if ($k -like 'Prerequisite*' -or $k -eq 'BuiltAt') {
            # the generic groups FACTORY/BARRACKS become the Terran buildings themselves: the colony AI built its bunkers but
            # no units (test 2026-10-27), most likely because FACTORY did not resolve to the Terran Factory in a mission
            $v = (($v -split ',' | ForEach-Object { $t = $_.Trim(); if ($t -eq 'FACTORY') { 'SCFACT' } elseif ($t -eq 'BARRACKS') { 'SCBARR' } else { $t } }) -join ',')
            $keep = @($v -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($known.ContainsKey($_) -or ($rules.ContainsKey($_) -and -not $scSec.ContainsKey($_)) -or $_ -match '^(POWER|FACTORY|BARRACKS|RADAR|TECH|PROC|none)$') })
            if ($keep.Count -eq 0) { continue }
            $v = $keep -join ','
        }
        $ini.Set($s, $k, $v)
    }
    if ($listOf.ContainsKey($s) -and $listOf[$s] -notlike 'Rules:*') {
        $ln = $listOf[$s]; $nList[$ln] = 1 + [int]$nList[$ln]
        $ini.Set($ln, ('ARKA1{0}{1:D3}' -f $ln.Substring(0, 2).ToUpper(), $nList[$ln]), $s)
    }
}
$log.Add("SC types copied into the map: $($scTypes.Count) sections (" + (($nList.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', ') + ")")

# prerequisite groups: SC Marines/SCVs/Firebats/Vultures need FACTORY = a Terran Factory, which only the StarCraft.ini [General]
# adds to PrerequisiteFactory; without it the colony AI could build nothing. Names that do not exist here are dropped.
foreach ($k in $scSec['General'].Keys) {
    if ($k -notlike 'Prerequisite*') { continue }
    $keep = @($scSec['General'][$k] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($known.ContainsKey($_) -or $rules.ContainsKey($_)) })
    $ini.Set('General', $k, ($keep -join ','))
}
# AI lists (global [AI]/[General] keys, kept with their Rules values): the colony rebuilds with the Command Center
# (Vinifera builds structures only with a BuildConst type) and replaces lost SCVs (IQ Harvester)
$ini.Set('AI', 'BuildConst', $rules['AI']['BuildConst'] + ',SCCC')
$ini.Set('AI', 'BuildRefinery', $rules['AI']['BuildRefinery'] + ',SCREFI')
$ini.Set('AI', 'BuildBarracks', $rules['AI']['BuildBarracks'] + ',SCBARR')
$ini.Set('AI', 'BuildWeapons', $rules['AI']['BuildWeapons'] + ',SCFACT')
$ini.Set('General', 'HarvesterUnit', $rules['General']['HarvesterUnit'] + ',SCSCV')

# anti-air (test 2026-10-27: Rocket Soldiers could not shoot the Mutalisks down; Marines should hit flyers too).
# Zerg flyers are Fly-locomotor vehicles with Naval=yes only so that a Hatchery can hatch them; nobody hatches them in
# this mission, so the flag goes (suspected to keep weapons from targeting them). The rocket and Gauss weapons also get a
# projectile that hits air AND ground, whichever of the two weapons the engine picks against a flyer.
foreach ($t in 'SCZMUT', 'SCZOVL') {
    $s = $ini.Section($t); for ($i = $s.Count - 1; $i -ge 0; $i--) { if ($s[$i].Key -in 'Naval', 'BuiltAt') { $s.RemoveAt($i) } }
}
function Resolve-RulesSec($sec) { $chain = @(); $s = $sec; while ($s -and $rules.ContainsKey($s) -and $chain.Count -lt 5) { $chain = , $s + $chain; $s = $rules[$s]['$Inherits'] }; $m = [ordered]@{}; foreach ($c in $chain) { foreach ($k in $rules[$c].Keys) { if ($k -ne '$Inherits') { $m[$k] = $rules[$c][$k] } } }; $m }
$aag = Resolve-RulesSec 'AGHeatSeeker'; $aag['AA'] = 'yes'; $aag['AG'] = 'yes'
foreach ($k in $aag.Keys) { $ini.Set('ARKA1AAG', $k, $aag[$k]) }
foreach ($w in '70mmMsl', '70mmMslRA', 'AA70mmMsl', 'AA70mmMslRA') { if ($rules.ContainsKey($w)) { $ini.Set($w, 'Projectile', 'ARKA1AAG') } }
foreach ($w in 'SCGauss', 'SCGaussS') { if ($ini.Has($w)) { $ini.Set($w, 'Projectile', 'Invisible3') } }   # Invisible3: AA=yes, AG=yes (Rules)

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
function Buildable($x, $y) { $c = $code[$y * $GW + $x]; ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -and -not $block[$y * $GW + $x] }

$wp = @{}; foreach ($kv in $ini.Section('Waypoints')) { $v = [int]$kv.Value; $wp[[int]$kv.Key] = @(($v % 1000), [Math]::Floor($v / 1000)) }
foreach ($n in 10..45) { if (-not $wp.ContainsKey($n)) { throw "terrain map has no waypoint $n (contract 10-45 broken)" } }
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
    # field 15 = AI repairable (DTA missions set 1 on computer bases); the colony AI must repair its buildings
    $rep = if ($house -eq 'GDI1') { 1 } else { 0 }
    $script:structs.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$script:sIdx", "$house,$type,$hp,$x,$y,64,$tag,$sell,0,1,0,0,None,None,None,$rep,0"))
    $script:sIdx++; $log.Add("building $house $type @ $x,$y ($($f[0])x$($f[1])) hp=$hp tag=$tag")
}
# building centred on a waypoint (nearest free footprint, margin $m)
function Place-AtWp($house, $type, [int]$n, $m = 1, $tag = 'None', $hp = 256, $sell = 0) {
    $f = Foundation $type
    $s = Find-Spot ($wp[$n][0] - [Math]::Floor($f[0] / 2)) ($wp[$n][1] - [Math]::Floor($f[1] / 2)) $f[0] $f[1] $m $true
    Add-Building $house $type $s[0] $s[1] $tag $sell $hp
}
function Add-Unit($house, $type, $tx, $ty, $mission = 'Guard', $tag = 'None', $hp = 256, $vet = 0) {
    $s = Find-Spot $tx $ty 1 1 0 $true; Occupy $s[0] $s[1] 1 1
    $script:units.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$($script:units.Count)", "$house,$type,$hp,$($s[0]),$($s[1]),64,$mission,$tag,$vet,-1,0,-1,0,0"))
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
# SC Marines and SCVs are SHP *vehicles* in the mod (stimpack = TransformsInto), so they go to [Units]
function Is-Vehicle($type) { $listOf[$type] -eq 'VehicleTypes' -or $listOf[$type] -eq 'Rules:VehicleTypes' }
function Squad($house, [string[]]$types, [int]$n, $dx = 0, $dy = 0, $mission = 'Guard', $hp = 256) {
    NewCell
    foreach ($t in $types) {
        if (Is-Vehicle $t) { Add-Unit $house $t ($wp[$n][0] + $dx) ($wp[$n][1] + $dy) $mission 'None' $hp }
        else { Add-Inf $house $t ($wp[$n][0] + $dx) ($wp[$n][1] + $dy) $mission 'None' $hp }
    }
}

# ================================================================ mission types
# Tanya: 2500 HP in every ARKA mission (user 2026-10-28: first +50%, then 2500; Rules 1000)
$ini.Set('TANYA', 'Strength', "$([int]([int]$rules['TANYA']['Strength'] * 2.5))")
# ARKA wreck = the real Chronosphere type RAPDOX, overridden in this map: it starts NEUTRAL and capturable so that an
# engineer can be sent INTO the wreck (secret: the cracked green crystal), no superweapon, no power, not repairable.
# A Rules type, not a new one, because the triggers test "building exists" by type INDEX, and only Rules indices are
# fixed (types made on demand shift the indices of map-added types: 514 in the game log instead of 507).
# History (2026-10-27): player-owned wreck = no way in for the engineer; then a separate house "ARKA" moved by
# Change House = mission failed on capture (the capture springs the tag before the owner changes).
$wrakType = 'RAPDOX'; $fcache[$wrakType] = @(2, 2)
$wrak = [ordered]@{
    Name = 'Wrak ARKI'; Strength = '20000'; Armor = 'heavy'; TechLevel = '-1'; Sight = '8'; Power = '0'; Powered = 'no'; Capturable = 'true'
    Crewed = 'no'; Unsellable = 'yes'; Repairable = 'no'; ClickRepairable = 'no'; SuperWeapon = 'none'; NukeSilo = 'no'; AIBuildThis = 'no'
    Immune = 'yes'   # test 4 (2026-10-27): the engineer's capture still lost the mission; an indestructible wreck needs no judges
}
foreach ($k in $wrak.Keys) { $ini.Set($wrakType, $k, $wrak[$k]) }
# index of RAPDOX in [BuildingTypes] = order of first appearance in the Rules list (matches DTA's own "#n" comments)
$wrakIdx = -1; $bi = 0; $seenB = @{}; $inB = $false
foreach ($l in [IO.File]::ReadAllLines("$game\INI\Rules.ini", $enc)) {
    if ($l -match '^\s*\[([^\]]+)\]') { if ($inB) { break }; $inB = $matches[1] -eq 'BuildingTypes'; continue }
    if ($inB -and $l -match '^[^;=]*=\s*([A-Za-z0-9_]+)') {
        $n = $matches[1]; if ($seenB.ContainsKey($n)) { continue }; $seenB[$n] = $bi
        if ($l -match '#(\d+)' -and [int]$matches[1] -ne $bi -and $n -ne 'RAPROC') { throw "BuildingTypes index of $n is $bi, DTA comment says $($matches[1])" }
        $bi++
    }
}
$wrakIdx = $seenB[$wrakType]; if ($null -eq $wrakIdx) { throw "$wrakType not in Rules [BuildingTypes]" }
$log.Add("wreck type $wrakType = BuildingTypes index $wrakIdx")
# Einstein: the Scientist (CHAN <- C2) resolved by hand, because $Inherits does not reach from a map into Rules.ini
function Resolve-Rules($sec) { $chain = @(); $s = $sec; while ($s -and $rules.ContainsKey($s) -and $chain.Count -lt 5) { $chain = , $s + $chain; $s = $rules[$s]['$Inherits'] }; $m = [ordered]@{}; foreach ($c in $chain) { foreach ($k in $rules[$c].Keys) { if ($k -ne '$Inherits') { $m[$k] = $rules[$c][$k] } } }; $m }
$ein = Resolve-Rules 'CHAN'
$ein['Name'] = 'Albert Einstein'; $ein['Image'] = $(if ($art.ContainsKey('CHAN')) { 'CHAN' } else { 'C2' }); $ein['Strength'] = '400'; $ein['Insignificant'] = 'no'
$ein['Owner'] = 'Allies'; $ein['TechLevel'] = '-1'; $ein['EditorName'] = 'Einstein (ARKA)'
$ein['Fraidycat'] = 'no'   # a VIP that panics and runs into the Zerglings would lose the mission by itself
$ini.Set('InfantryTypes', 'ARKA1I01', 'ARKEINST'); foreach ($k in $ein.Keys) { $ini.Set('ARKEINST', $k, $ein[$k]) }
# Jim Raynor on his Vulture: the SC Vulture with 40% more HP (user, 2026-10-27; first 20%). Image= is required: the art section is
# looked up by the image name, and without it the game looked for [ARKRAYN] in Art.ini and drew nothing
$ray = [ordered]@{}; foreach ($k in $scSec['SCVULT'].Keys) { $ray[$k] = $scSec['SCVULT'][$k] }
$ray['Name'] = 'Jim Raynor (Vulture)'; $ray['Image'] = 'SCVULT'; $ray['Strength'] = [string][int]([int]$ray['Strength'] * 5.6)   # +40%, then +300% (user 2026-10-28, all ARKA: "szybko pada"); $ray['TechLevel'] = '-1'; $ray['Owner'] = 'GDI2'
$ray['SelfHealing'] = 'yes'; $ray['SelfHealingCap'] = '1.0'; $ray['SelfHealingStep'] = '5'
# Raynor speaks with his own SC voice (the hero Marine SCRAYN), not the Vulture pilot's (user, 2026-10-27)
foreach ($k in 'VoiceSelect', 'VoiceMove', 'VoiceAttack', 'VoiceFeedback', 'VoiceDie') { if ($scSec['SCRAYN'].Contains($k)) { $ray[$k] = $scSec['SCRAYN'][$k] } }
$ray.Remove('Prerequisite'); $ray.Remove('BuiltAt')
foreach ($k in @($ray.Keys)) { if ($k -match '^(DeploysInto|UndeploysInto|Deployer)$') { $ray.Remove($k) } }
$ini.Set('VehicleTypes', 'ARKA1V01', 'ARKRAYN'); foreach ($k in $ray.Keys) { $ini.Set('ARKRAYN', $k, $ray[$k]) }

# tech of mission 1: early Allied tech only (barracks, refinery, factory, radar); no tech centre, air, navy, Chronosphere
foreach ($t in 'RAATEK', 'AHPAD', 'ASYRD', 'RAPDOX', 'RAGAP', 'HELI', 'TRAN', 'APC') { $ini.Set($t, 'TechLevel', '-1') }

# ================================================================ houses
$ini.Sections.Remove('Houses') | Out-Null; $ini.Order.Remove('Houses') | Out-Null
$hl = 'GDI', 'Nod', 'Allies', 'Soviet', 'Neutral', 'Special', 'GDI1', 'Nod1', 'GDI2', 'Nod2', 'Allies1', 'Allies2', 'Soviet1', 'Soviet2'
for ($i = 0; $i -lt $hl.Count; $i++) { $ini.Set('Houses', "$i", $hl[$i]) }
$H = @{ GDI = 0; Nod = 1; Allies = 2; Soviet = 3; Neutral = 4; Special = 5; GDI1 = 6; Nod1 = 7; GDI2 = 8; Nod2 = 9; Allies1 = 10; Allies2 = 11; Soviet1 = 12; Soviet2 = 13 }
function House($name, $side, $color, $allies, $credits, $actsLike, $player, $edge = 'North', $iq = 0, $tl = 10) {
    $v = [ordered]@{ IQ = $iq; Edge = $edge; Side = $side; Color = $color; Allies = $allies; Credits = $credits; ActsLike = $actsLike
        NodeCount = 0; TechLevel = $tl; PercentBuilt = 100; PlayerControl = $player }
    foreach ($k in $v.Keys) { $ini.Set($name, $k, "$($v[$k])") }
}
$friends = 'Allies,Allies1,Allies2,Soviet1,Soviet2,GDI1,GDI2,Soviet'
House 'Allies'  'AlliesSide'   'AlliedBlue' $friends 30 2 'yes' 'South' 0 3   # player: 3000 credits, tech level 3
House 'Allies1' 'AlliesSide'   'LightBlue'  $friends 0  2 'no'                # survivors 1 (west strip)
House 'Allies2' 'AlliesSide'   'LightBlue'  $friends 0  2 'no'                # survivors 2 (central valley)
House 'Soviet1' 'AlliesSide'   'LightBlue'  $friends 0  2 'no'                # survivors 3 (east plateau)
House 'Soviet2' 'AlliesSide'   'LightBlue'  $friends 0  2 'no'                # MCV crew (south)
House 'GDI1'    'GDISide'      'Orange'     $friends 40 6 'no' 'North' 5      # Mar Sara colony: computer ally, IQ 5 = produces and rebuilds by itself
House 'GDI2'    'GDISide'      'LightGold'  $friends 0  6 'no'                # Jim Raynor and his Marines
House 'Nod1'    'NodSide'      'Purple'     'Nod1,Nod2,Soviet' 0 7 'no' 'North' 3   # Zerg nest
House 'Nod2'    'NodSide'      'Purple'     'Nod1,Nod2,Soviet' 0 7 'no' 'North' 3   # Zerg swarm on the colony
House 'Soviet'  'SovietSide'   'Gold'       'Soviet,Allies,Allies1,Allies2,Soviet1,Soviet2,GDI1,GDI2,Nod1,Nod2' 0 3 'no'   # Protoss Observer
House 'Neutral' 'CivilianSide' 'Grey'       'Neutral' 0 4 'no'
House 'Special' 'SpecialSide'  'Grey'       'Special' 0 5 'no'

# ================================================================ crash site: the ARKA wreck in a crater, the core, wrecked buildings
foreach ($n in 10, 12, 27, 28, 13, 17, 19) { Reserve $wp[$n][0] $wp[$n][1] 2 }
Place-AtWp 'Neutral' $wrakType 10 1 'ARKA1G01' 90          # 35% HP; wp 12 (the former separate core) is no longer used
Place-AtWp 'Neutral' 'RATENT'   27 1 'None' 100             # wrecked barracks: capture with an engineer
Place-AtWp 'Neutral' 'RAPOWR'   28 1 'None' 80              # wrecked power plant
# crater and scorch smudges round the wreck
$smN = 0
$rnd = New-Object Random 1953
foreach ($i in 0..13) {
    $a = $rnd.NextDouble() * 6.283; $r = 2 + $rnd.NextDouble() * 4
    $sx = [int]($wp[10][0] + [Math]::Cos($a) * $r); $sy = [int]($wp[10][1] + [Math]::Sin($a) * $r)
    if (-not (Buildable $sx $sy)) { continue }
    $ini.Set('Smudge', "$smN", ('CR{0}{1},{2},{3},0' -f (1 + $rnd.Next(6)), [char](65 + $rnd.Next(5)), $sx, $sy)); $smN++
}

# ================================================================ player start force (around wp 11)
$p = $wp[11]
# reveal-map crate by the start (cell kept free here; overlay + trigger by Add-RevealCrate from MissionKit.ps1)
$crate = Find-Spot ($p[0] - 3) ($p[1] + 2) 1 1 0 $false; Occupy $crate[0] $crate[1] 1 1
foreach ($t in '1TNK', '1TNK', '1TNK', 'RANG') { Add-Unit 'Allies' $t ($p[0] + 2) ($p[1] - 2) 'Guard' }
NewCell; Add-Inf 'Allies' 'TANYA' $p[0] $p[1] 'Guard' 'ARKA1G02' 256 100
NewCell; Add-Inf 'Allies' 'ARKEINST' ($p[0] - 2) ($p[1] + 1) 'Guard' 'ARKA1G03'
Squad 'Allies' @('E1', 'E1', 'E1') 11 1 2
Squad 'Allies' @('E1', 'E3', 'E3') 11 -1 3
Squad 'Allies' @('MEDIC', 'ENGINEER') 11 3 1

# ================================================================ survivors (each group its own house; joins when the player arrives)
Squad 'Allies1' @('E1', 'E1', 'E1') 14 0 0 'Guard' 180
Squad 'Allies1' @('E3', 'ENGINEER') 14 1 1 'Guard' 200
Squad 'Allies2' @('E1', 'E1', 'MEDIC') 15 0 0 'Guard' 200
Add-Unit 'Allies2' '2TNK' ($wp[15][0] + 2) $wp[15][1] 'Guard' 'None' 120
Squad 'Soviet1' @('E1', 'E1', 'E3') 16 0 0 'Guard' 220
Squad 'Soviet1' @('E3', 'ENGINEER') 16 -1 1 'Guard' 220
Add-Unit 'Soviet1' '1TNK' ($wp[16][0] + 1) ($wp[16][1] - 2) 'Guard' 'None' 150
# the damaged MCV and its crew in the south
Add-Unit 'Soviet2' 'AMCV' $wp[13][0] $wp[13][1] 'Sleep' 'None' 110
Squad 'Soviet2' @('E1', 'E1', 'ENGINEER') 13 2 1 'Guard' 200

# ================================================================ Mar Sara colony (NW plateau) and Raynor
# the colony is a computer ally that plays: SCVs mine the crystals by the Command Center into a Refinery, the Terran
# Factory builds Marines/Firebats/Vultures/SCVs (all SHP vehicles in the mod), lost buildings are rebuilt from base nodes
$colBase = $sIdx
Place-AtWp 'GDI1' 'SCCC'   17 1 'ARKA1G04'
Place-AtWp 'GDI1' 'SCBARR' 40 1
Place-AtWp 'GDI1' 'SCACAD' 39 1
Place-AtWp 'GDI1' 'SCDEPO' 41 0
Place-AtWp 'GDI1' 'SCDEPO' 41 0
Place-AtWp 'GDI1' 'SCDEPO' 41 0
foreach ($n in 36, 37, 38) { Place-AtWp 'GDI1' 'SCBUNK' $n 0 }
# refinery between the Command Center and the nearest crystal field, factory between the CC and the barracks
$gem = @(); for ($i = 0; $i -lt $ovl.Length; $i++) { if ($ovl[$i] -ge 27 -and $ovl[$i] -le 38) { $gx = $i % 512; $gy = [Math]::Floor($i / 512); if ([Math]::Abs($gx - $wp[17][0]) -le 18 -and [Math]::Abs($gy - $wp[17][1]) -le 18) { $gem += , @($gx, $gy) } } }
if ($gem.Count -eq 0) { throw "no crystal field near the colony (wp 17)" }
$gcx = [int](($gem | ForEach-Object { $_[0] } | Measure-Object -Average).Average); $gcy = [int](($gem | ForEach-Object { $_[1] } | Measure-Object -Average).Average)
$f = Foundation 'SCREFI'; $s = Find-Spot ([int](($gcx + $wp[17][0]) / 2)) ([int](($gcy + $wp[17][1]) / 2)) $f[0] $f[1] 1 $true; Add-Building 'GDI1' 'SCREFI' $s[0] $s[1] 'None' 0
$f = Foundation 'SCFACT'; $s = Find-Spot ([int](($wp[17][0] + $wp[40][0]) / 2)) ([int](($wp[17][1] + $wp[40][1]) / 2) + 3) $f[0] $f[1] 1 $true; Add-Building 'GDI1' 'SCFACT' $s[0] $s[1] 'None' 0
$log.Add("colony crystals: $($gem.Count) cells round $gcx,$gcy")
# base nodes: what the colony AI rebuilds ("000=TYPE,x,y" in the house section)
$nodes = @($structs | Select-Object -Skip $colBase | Where-Object { $_.Value -like 'GDI1,*' })
$ini.Set('GDI1', 'NodeCount', "$($nodes.Count)")
for ($i = 0; $i -lt $nodes.Count; $i++) { $p = $nodes[$i].Value -split ','; $ini.Set('GDI1', ('{0:D3}' -f $i), "$($p[1]),$($p[3]),$($p[4])") }
foreach ($t in 'SCSCV', 'SCSCV', 'SCSCV') { Add-Unit 'GDI1' $t $gcx $gcy 'Harvest' }
Squad 'GDI1' @('C2', 'C2', 'C2') 17 -2 4 'Guard'
Squad 'GDI1' @('C2', 'C2') 39 2 2 'Guard'
Add-Unit 'GDI2' 'ARKRAYN' $wp[18][0] $wp[18][1] 'Guard' 'ARKA1G05' 256 100
Squad 'GDI2' @('SCMARINE', 'SCMARINE', 'SCMARINE') 18 2 1 'Guard'
Squad 'GDI2' @('SCMARINE', 'SCMARINE', 'SCMARINE') 18 -1 2 'Guard'
Squad 'GDI2' @('SCMARINE', 'SCMARINE') 36 1 2 'Guard'

# ================================================================ Zerg nest (NE plateau) and Zerg packs
Place-AtWp 'Nod1' 'SCZHAT' 19 1 'ARKA1G06'
Place-AtWp 'Nod1' 'SCZPOL' 30 1
foreach ($n in 31, 32, 33) { Place-AtWp 'Nod1' 'SCZCRP' $n 0 }
foreach ($n in 34, 35) { Place-AtWp 'Nod1' 'SCZSUN' $n 0 }
foreach ($t in 'SCZOVL', 'SCZOVL') { Add-Unit 'Nod1' $t ($wp[19][0] - 4) ($wp[19][1] + 3) 'Guard' }
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG') 20 0 0 'Area Guard'
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG') 20 3 2 'Area Guard'
Squad 'Nod1' @('SCZHYL', 'SCZHYL', 'SCZHYL') 19 -3 4 'Area Guard'
Squad 'Nod1' @('SCZHYL', 'SCZHYL') 34 2 -2 'Area Guard'
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG') 45 0 0 'Area Guard'    # north ravine exit
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG') 21 0 0 'Area Guard'    # central valley (no Hydralisk before Einstein's line about them)
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG') 29 0 0 'Area Guard'    # by the MCV
Squad 'Nod1' @('SCZLNG') 29 2 1 'Area Guard'

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
Zone 'ARKA1G10' 14 0 3      # survivors 1 join
Zone 'ARKA1G11' 15 0 3      # survivors 2 join
Zone 'ARKA1G12' 16 0 3      # survivors 3 join
Zone 'ARKA1G13' 13 0 4      # MCV crew join
Zone 'ARKA1G14' 14 4 9      # first contact: zerglings on survivors 1
Zone 'ARKA1G15' 18 10 15    # approach to the colony: the Zerg siege starts

# ================================================================ dialogue ([Tutorial] of the map, numbers 9101-9199)
$textNo = 9100
function Say([string]$s) { if ($s -match '[^\x20-\x7E]') { throw "non-ASCII text: $s" }; $script:textNo++; $ini.Set('Tutorial', "$script:textNo", $s); $script:textNo }

# ================================================================ taskforces, scripts, teams
$tfN = 0; $tmN = 0
# -AI: a team the house's AI builds and launches through [AITriggerTypes] (members recruitable, Max instances at once)
function Team($name, $house, $spawnWp, [string[]]$members, [string[]]$script, [int]$max = 0, [switch]$AI) {
    $script:tfN++; $script:tmN++
    $tf = 'ARKA1F{0:D2}' -f $script:tfN; $sc = 'ARKA1S{0:D2}' -f $script:tfN; $tm = 'ARKA1M{0:D2}' -f $script:tmN
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
    if ($AI) { $v['Max'] = $max; $v['AreTeamMembersRecruitable'] = 'yes' }
    foreach ($k in $v.Keys) { $ini.Set($tm, $k, "$($v[$k])") }
    $tm
}
# AI trigger (TS format, as in DTA missions cr01/cr05): name, team, house, techlevel, condition -1 = always, object,
# comparator, start/min/max weight, skirmish flag, unused, side, base defence, second team, Easy/Normal/Hard.
# Side is NOT the [Sides] index: AITriggerTypeClass::Process (game.exe 0x4109EF) accepts the trigger only when
# MultiSide == 0 or MultiSide - 1 == house ActLike (HouseClass +0xC0). DTA's Soviet triggers say 4 because Soviet acts
# like house type 3; the colony GDI1 acts like 6, so it needs 7. With 1 (test 2026-10-27) the colony never built a unit.
$aiN = 0
function AITrigger($name, $team, $house, [int]$side) {
    $script:aiN++; $id = 'ARKA1A{0:D2}' -f $script:aiN
    $ini.Set('AITriggerTypes', $id, "$name,$team,$house,1,-1,<none>,$('0' * 64),50,30,70,1,0,$side,0,<none>,1,1,1")
    $ini.Set('AITriggerTypesEnable', $id, 'yes')
}
# script lines: 3,N move to waypoint N; 1,N attack (the building at) waypoint N; 11,14 hunt; 11,10 area guard
# waves go straight for the ARKA wreck (the engine finds the path); the old detour through the central valley (wp 21)
# made a wave walk to the middle of the map first (test 2026-10-27)
# NOT 1,N (attack waypoint) for ground teams: in DTA missions only aircraft use it, ground teams stop there for good
# (ARKA 0 user test 2026-10-27, found by the ARKA 0 session); 16,N = patrol/attack-move, then hunt
$toCrash = '16,10', '11,14'
$tmAmbush = Team 'Pierwszy kontakt'     'Nod1' 24 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') @('3,14', '11,10')
# the siege is Zerglings only: Hydralisks first appear with wave 3 and Einstein's line about "the new ones" (test 2026-10-27)
$tmCol1   = Team 'Oblezenie kolonii 1'  'Nod2' 23 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') @('3,18', '16,17', '11,14')
$tmCol2   = Team 'Oblezenie kolonii 2'  'Nod2' 23 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') @('3,36', '16,17', '11,14')
$tmW1     = Team 'Fala 1: zerglingi'    'Nod1' 20 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') $toCrash
$tmW2     = Team 'Fala 2: zerglingi'    'Nod1' 20 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') $toCrash
$tmRaid   = Team 'Najazd z poludnia'    'Nod1' 29 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') @('16,10', '11,14')
$tmW3     = Team 'Fala 3: hydraliski'   'Nod1' 20 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL', 'SCZHYL') $toCrash
$tmW4     = Team 'Fala 4: hydraliski'   'Nod1' 20 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL', 'SCZHYL', 'SCZHYL', 'SCZHYL') $toCrash
$tmMuta   = Team 'Mutalisk'             'Nod1' 25 @('SCZMUT') @('1,10', '11,14')   # one, with Tanya's "they fly too?!" (user: do not oversaturate)
$tmRep    = Team 'Fala powtarzana'      'Nod1' 20 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL', 'SCZHYL') $toCrash
$tmObs    = Team 'Obserwator Protossow' 'Soviet' 26 @('SCPOBSV') @('11,5')
# colony AI teams: one stays home, two strike the nest (north plateau -> west approach -> Hatchery -> hunt)
$tmColDef = Team 'Kolonia: obrona'        'GDI1' 18 @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE') @('3,18', '11,10') 1 -AI
$tmColAtk = Team 'Kolonia: atak piechoty' 'GDI1' 18 @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE', 'SCFIRE') @('3,23', '3,35', '16,19', '11,14') 2 -AI
$tmColVul = Team 'Kolonia: atak Vulture'  'GDI1' 18 @('SCVULT', 'SCVULT', 'SCVULT', 'SCVULT') @('3,23', '16,31', '16,19', '11,14') 1 -AI
$colSide = [int]$ini.Get('GDI1', 'ActsLike', '6') + 1
AITrigger 'Kolonia obrona'   $tmColDef 'GDI1' $colSide
AITrigger 'Kolonia atak'     $tmColAtk 'GDI1' $colSide
AITrigger 'Kolonia Vulture'  $tmColVul 'GDI1' $colSide

# ================================================================ triggers
$trN = 0; $trig = [ordered]@{}
foreach ($v in @('Rozbitkowie 1,0', 'Rozbitkowie 2,0', 'Rozbitkowie 3,0', 'MCV odzyskany,0', 'Pierwszy kontakt,0', 'Oblezenie kolonii,0', 'Raynor dolaczyl,0', 'Final,0', 'Wrak przejety,0', 'Wrak u gracza,0')) { $ini.Set('VariableNames', "$($trN)", $v); $trN++ }
$trN = 0
function Ev([int]$id, $p = 0) { "$id,0,$p" }
function Act([int]$id, $p = 0, [int]$kind = 0, [int]$w = 0) { "$id,$kind,$p,0,0,0,0,$(WpLetter $w)" }
function Text($s) { Act 11 (Say $s) }
function Reinf($team, $w) { Act 80 $team 1 $w }
function Enable($t) { Act 53 $t 2 }
function Disable($t) { Act 54 $t 2 }
function Trigger($key, $name, [string[]]$events, [string[]]$actions, $house = 'Allies', [switch]$Disabled, [switch]$Repeat, $tag = $null, $diff = '1,1,1') {
    $script:trN++; $id = 'ARKA1T{0:D2}' -f $script:trN
    $name = $name -replace ',', ' -'
    if (-not $tag) { $tag = 'ARKA1G{0:D2}' -f (30 + $script:trN) }
    $script:trig[$key] = @{ Id = $id; Name = $name; House = $house; Events = $events; Actions = $actions; Disabled = [bool]$Disabled; Repeat = [bool]$Repeat; Tag = $tag; Diff = $diff }
}
$wavesOff = @('w1', 'w2', 'raid', 'w3', 'w4', 'muta', 'wHard', 'wRep')
. "$tools\MissionKit.ps1"   # reveal crate, one text per trigger, dialogue gaps from text length, timeline check
Add-ScAirArmor             # SC flyer armors: Allied AA fires at SC flyers only on order, Dragoons cannot hit the Overlord
Add-RevealCrate $crate[0] $crate[1]

# --- opening: the radio, Tanya and Einstein, Stavros, objectives
Trigger 'intro' 'Start: obcy kanal' @((Ev 13 1)) @(
    (Act 48 1 0 10), (Act 20 58), (Act 17 10),
    (Text 'Radio (obcy kanal): ...tu Konfederacja Terranska... Chau Sara przestala istniec... spalona przez nieznanych obcych...'),
    (Enable 'intro2'))
Trigger 'intro2' 'Start 2: radio' @((Ev 13 7)) @((Text 'Radio: ...wszyscy kolonisci Mar Sary pozostaja w gotowosci...'), (Enable 'intro3')) -Disabled
Trigger 'intro3' 'Start 3: Tanya' @((Ev 13 6)) @((Text 'Tanya: Konfederacja? Czyja to konfederacja?'), (Enable 'intro4')) -Disabled
Trigger 'intro4' 'Start 4: Einstein' @((Ev 13 5)) @((Text 'Einstein: Mysle, panno Adams, ze to pytanie brzmi raczej: czyj to wszechswiat?'), (Enable 'intro5')) -Disabled
Trigger 'intro5' 'Start 5: Stavros' @((Ev 13 7)) @(
    (Text 'Plk Stavros (radio): Komandorze, pole Chronosfery rozrzucilo baze po calej pustyni. Mam na radarze trzy grupy naszych i sygnal MCV na poludniu.'),
    (Enable 'intro6')) -Disabled
Trigger 'intro6' 'Start 6: cele' @((Ev 13 7)) @(
    (Text 'Cel: zbierz rozbitkow (3 grupy) i odzyskaj uszkodzony MCV na poludniu.'),
    (Text 'Einstein i Tanya musza przetrwac.'),
    (Act 55 2 0 14), (Act 55 2 0 15), (Act 55 2 0 16), (Act 55 2 0 13), (Act 17 13),
    (Enable 'intro7')) -Disabled
Trigger 'intro7' 'Start 7: wskazowki' @((Ev 13 10)) @(
    (Text 'Plk Stavros: Wraki naszych budynkow przy ARCE mozna przejac inzynierem.'),
    (Text 'Einstein: Rdzen ARKI jest pekniety. Chcialbym wiedziec, co go rozsadzilo. Niech inzynier wejdzie do wraku i zajrzy do srodka.')) -Disabled

# --- losing: Einstein, the wreck, Raynor, everything
Trigger 'einLost' 'Einstein zginal' @((Ev 29)) @((Text 'Plk Stavros: Einstein nie zyje. Bez niego nikt z nas nie wroci do domu.'), (Act 2 $H.Allies)) -tag 'ARKA1G03'
# Tanya is a loss too (user 2026-10-27: losing her gave no Mission Failed)
Trigger 'tanLost' 'Tanya zginela' @((Ev 29)) @((Text 'Plk Stavros: Stracilismy Tanye. Bez niej ta misja nie ma szans.'), (Act 2 $H.Allies)) -tag 'ARKA1G02'
# the wreck (neutral, capturable, Immune since test 4): it cannot be destroyed, so it is no longer a loss condition.
# History: test 3 = judges on the wreck's tag (event 48 = destroyed OR captured) told the two cases apart by
# "building exists"; test 4 (2026-10-27) the engineer's capture still lost the mission (which trigger fired is not
# in the log: TechnoClass::Captured springs event 1 on the tag before the owner changes, see engine/triggers-and-dialogue).
# Now any event on the wreck's tag, or the wreck type showing up among the player's buildings, only starts the secret.
Trigger 'arkaHit' 'Wrak ARKI: inzynier w srodku' @((Ev 48)) @((Act 56 8), (Enable 'secret')) -house 'Neutral' -tag 'ARKA1G01'
Trigger 'arkaCaptured' 'Wrak ARKI przejety' @((Ev 32 $wrakIdx)) @((Act 56 8), (Enable 'secret'))
Trigger 'rayLost' 'Raynor zginal' @((Ev 29)) @((Text 'Plk Stavros: Marszalek Raynor zginal. Kolonisci nie maja juz nikogo, kto by nas zaprowadzil dalej.'), (Act 2 $H.Allies)) -tag 'ARKA1G05'
Trigger 'allLost' 'Wszystko stracone' @((Ev 11 $H.Allies)) @((Act 2 $H.Allies))

# --- survivors: first contact (zerglings on group 1), joining
Trigger 'contact' 'Pierwszy kontakt (strefa)' @((Ev 1 $H.Allies)) @(
    (Reinf $tmAmbush 24), (Act 56 4), (Act 55 3 0 14), (Disable 'contactT'),
    (Text 'Kpr. (rozbitkowie, radio): Cos nas atakuje! Male, szybkie, pelno zebow!'), (Enable 'contact2')) -tag 'ARKA1G14'
Trigger 'contactT' 'Pierwszy kontakt (czas)' @((Ev 13 300), (Ev 37 4)) @(
    (Reinf $tmAmbush 24), (Act 56 4), (Act 55 3 0 14), (Disable 'contact'),
    (Text 'Kpr. (rozbitkowie, radio): Komandorze, na zachodzie! Cos nas atakuje! Male, szybkie, pelno zebow!'), (Enable 'contact2'))
Trigger 'contact2' 'Pierwszy kontakt 2' @((Ev 13 5)) @((Text 'Tanya: Co to, do cholery, jest? Psy?!'), (Enable 'contact3')) -Disabled
Trigger 'contact3' 'Pierwszy kontakt 3' @((Ev 13 5)) @((Text 'Einstein: To nie sa psy, Tanya. To nie jest nawet nasza biologia.')) -Disabled
Trigger 'g1' 'Rozbitkowie 1 dolaczaja' @((Ev 1 $H.Allies)) @(
    (Act 36 $H.Allies), (Act 56 0), (Text 'Kpr. (rozbitkowie): Dzieki Bogu! Myslelismy, ze zostalismy sami na tej planecie.')) -house 'Allies1' -tag 'ARKA1G10'
Trigger 'g2' 'Rozbitkowie 2 dolaczaja' @((Ev 1 $H.Allies)) @(
    (Act 36 $H.Allies), (Act 56 1), (Text 'Sierz. (rozbitkowie): Czolg ledwo jedzie, ale strzela. Meldujemy sie, Komandorze.')) -house 'Allies2' -tag 'ARKA1G11'
Trigger 'g3' 'Rozbitkowie 3 dolaczaja' @((Ev 1 $H.Allies)) @(
    (Act 36 $H.Allies), (Act 56 2), (Text 'Por. (rozbitkowie): Te krysztaly obok nas swieca w nocy na niebiesko. Profesor bedzie zachwycony.')) -house 'Soviet1' -tag 'ARKA1G12'
Trigger 'gAll' 'Wszyscy rozbitkowie' @((Ev 36 0), (Ev 36 1), (Ev 36 2)) @((Text 'Cel wykonany: wszyscy rozbitkowie zebrani.'))

# --- the MCV: join, deploy, the crystal field
Trigger 'mcv' 'MCV odzyskany' @((Ev 1 $H.Allies)) @(
    (Act 36 $H.Allies), (Act 56 3),
    (Text 'Mechanik: MCV oberwal przy ladowaniu, ale silnik chodzi. Prowadzcie, Komandorze!'),
    (Text 'Cel: rozstaw MCV i postaw baze (najlepiej przy wraku ARKI).')) -house 'Soviet2' -tag 'ARKA1G13'
Trigger 'mcvDep' 'MCV rozstawiony' @((Ev 32 2)) @(
    (Text 'Einstein: Te zloza sa krystaliczne, w skladzie bardzo podobne do rudy. Fascynujace!'), (Enable 'mcvDep2'))
Trigger 'mcvDep2' 'MCV rozstawiony 2' @((Ev 13 6)) @((Text 'Plk Stavros: Ekonomisci beda mniej zachwyceni, profesorze. Ale rafineria to przelknie.')) -Disabled

# --- the Mar Sara colony: Raynor's call (approach or 9:00), the siege, Raynor joins
$siege = @((Act 56 5), (Act 17 17), (Act 17 18), (Act 55 4 0 17), (Reinf $tmCol1 23),
    (Text 'Jim Raynor (radio): Tu marszalek Jim Raynor, kolonia Mar Sara! Te bestie wlazly nam do osady. Jesli ktos mnie slyszy, kazda pomoc sie przyda!'),
    (Text 'Cel: pomoz kolonii Mar Sary na polnocnym zachodzie. Raynor musi przezyc.'), (Enable 'col2'))
Trigger 'col' 'Oblezenie kolonii (strefa)' @((Ev 1 $H.Allies)) ($siege + @((Disable 'colT'))) -tag 'ARKA1G15'
Trigger 'colT' 'Oblezenie kolonii (czas)' @((Ev 13 540), (Ev 37 5)) ($siege + @((Disable 'col')))
Trigger 'col2' 'Oblezenie kolonii: druga fala' @((Ev 13 45)) @((Reinf $tmCol2 23), (Act 55 3 0 23), (Enable 'colSaved')) -Disabled
# the house change counts as a capture, and a capture springs "destroyed" on Raynor's tag: rayLost must be off while it
# happens (2026-10-27: killing the last siege Hydralisk lost the mission), and is armed again a few seconds later
Trigger 'colSaved' 'Kolonia ocalona' @((Ev 13 8), (Ev 9 $H.Nod2)) @(
    (Disable 'rayLost'), (Act 36 $H.Allies), (Act 56 6), (Enable 'rayRearm'), (Enable 'colAI'),
    (Text 'Jim Raynor: Nie wiem, kim jestescie ani skad macie czolgi z muzeum, ale strzelacie w dobra strone. Na razie mi to wystarczy.'),
    (Text 'Raynor i jego Marines przechodza pod Twoje dowodzenie.'), (Enable 'colSaved2')) -house 'GDI2' -Disabled
Trigger 'colSaved2' 'Kolonia ocalona 2' @((Ev 13 6)) @((Text 'Tanya: Kowboj na motorze. Tego jeszcze nie widzialam.')) -Disabled
Trigger 'rayRearm' 'Raynor: porazka znow aktywna' @((Ev 13 3)) @((Enable 'rayLost')) -Disabled
# the colony as a computer ally: production and rebuilding from the start, its own attacks once the siege is over
# (or at 15:00 if a straggler of the siege keeps it from ending)
Trigger 'colProd' 'Kolonia: produkcja' @((Ev 13 2)) @((Act 3 $H.GDI1)) -house 'GDI1'
Trigger 'colAI' 'Kolonia: kontratak' @((Ev 13 20)) @(
    (Act 74 $H.GDI1), (Disable 'colAIT'),
    (Text 'Jim Raynor: Kolonisci odbudowuja sie i szkola ludzi. Jak tylko beda gotowi, pojda z wami na gniazdo.')) -house 'GDI1' -Disabled
Trigger 'colAIT' 'Kolonia: kontratak (czas)' @((Ev 13 900)) @((Act 74 $H.GDI1), (Disable 'colAI')) -house 'GDI1'
Trigger 'colFallen' 'Command Center kolonii zniszczone' @((Ev 29)) @((Text 'Jim Raynor: Stracilismy Command Center! Trzymamy sie jeszcze, ale to juz nie osada, tylko ruiny.')) -tag 'ARKA1G04'

# --- the nest objective and the waves (stop when the Hatchery dies)
Trigger 'nestObj' 'Cel: gniazdo' @((Ev 13 400)) @(
    (Text 'Plk Stavros: Zwiad melduje gniazdo tych stworzen na polnocnym wschodzie. Stamtad wychodza.'),
    (Text 'Cel glowny: zniszcz gniazdo Zergow (Wylegarnia, kolonie i Spawning Pool) na polnocnym wschodzie.'),
    (Act 55 6 0 19))
# w1 at 470: after the two lines of the nest objective (400 s + reading time)
Trigger 'w1' 'Fala 1' @((Ev 13 470)) @((Reinf $tmW1 20), (Act 55 3 0 21), (Text 'EVA: Wykryto ruch wroga w centralnej dolinie.'))
Trigger 'w2' 'Fala 2' @((Ev 13 690)) @((Reinf $tmW2 20), (Act 55 3 0 21))
Trigger 'raid' 'Najazd z poludnia' @((Ev 13 840)) @((Reinf $tmRaid 29), (Act 55 3 0 29), (Text 'EVA: Wrog nadciaga od poludnia.'))
Trigger 'w3' 'Fala 3: hydraliski' @((Ev 13 960)) @((Reinf $tmW3 20), (Act 55 3 0 21),
    (Text 'Einstein: Te nowe pluja kolcami na odleglosc. Ewolucja tu sie nie nudzi.'))
Trigger 'w4' 'Fala 4' @((Ev 13 1200)) @((Reinf $tmW4 20), (Act 55 3 0 21))
Trigger 'muta' 'Mutaliski' @((Ev 13 1380)) @((Reinf $tmMuta 25), (Act 55 3 0 25),
    (Text 'Tanya: Teraz jeszcze lataja?! Profesorze, prosze mi powiedziec, ze to koniec niespodzianek.'))
Trigger 'wHard' 'Fala dodatkowa (trudny)' @((Ev 13 1080), (Ev 27 12)) @((Reinf $tmMuta 25), (Reinf $tmW3 20))
Trigger 'wRep' 'Fala powtarzana' @((Ev 13 300)) @((Reinf $tmRep 20), (Act 55 3 0 21)) -Repeat -Disabled
Trigger 'wRepOn' 'Fale powtarzane wlaczone' @((Ev 13 1500)) @((Enable 'wRep'))
Trigger 'hatch' 'Wylegarnia zniszczona' @((Ev 29)) (@((Text 'Plk Stavros: Wylegarnia plonie! Nic juz z niej nie wyjdzie.')) + @($wavesOff | ForEach-Object { Disable $_ }) + @((Disable 'wRepOn'))) -tag 'ARKA1G06'

# --- secret: an engineer inside the wreck (enabled by arkaHit or arkaCaptured, whichever comes first)
Trigger 'secret' 'Sekret: krysztal w rdzeniu' @((Ev 13 2)) @(
    (Text 'Inzynier: Komandorze, w rdzeniu ARKI jest cos, czego tam byc nie powinno. Pekniety zielony krysztal.'), (Enable 'secret2')) -Disabled
Trigger 'secret2' 'Sekret 2' @((Ev 13 6)) @((Text 'Einstein: To nie byl tylko moj blad. Ktos nam pomogl sie pomylic.')) -Disabled

# --- victory: every building of the nest destroyed -> Duke, Raynor, the Observer
Trigger 'win0' 'Gniazdo zniszczone' @((Ev 10 $H.Nod1)) @(
    (Disable 'einLost'), (Disable 'arkaHit'), (Disable 'arkaCaptured'), (Disable 'rayLost'), (Disable 'allLost'), (Act 56 7),
    (Text 'Cel wykonany: gniazdo Zergow zniszczone.'), (Enable 'win1'))
Trigger 'win1' 'Final 1: Duke' @((Ev 13 5)) @(
    (Text 'Por. Edmund Duke (radio): Niezidentyfikowana jednostka wojskowa, przebywacie na terytorium Konfederacji. Zlozyc bron i oczekiwac na eskorte.'),
    (Enable 'win2')) -Disabled
Trigger 'win2' 'Final 2: Raynor' @((Ev 13 7)) @(
    (Text 'Jim Raynor (na prywatnym kanale): Na waszym miejscu nie skladalbym niczego. Duke ma w zwyczaju strzelac przed pytaniami.'),
    (Enable 'win3')) -Disabled
Trigger 'win3' 'Final 3: Obserwator' @((Ev 13 7)) @(
    (Reinf $tmObs 26), (Act 17 26), (Act 48 2 0 26), (Act 64 26),
    (Text 'Na skraju pustyni cos migocze w powietrzu... i znika.'), (Enable 'win4')) -Disabled
Trigger 'win4' 'Final 4: wygrana' @((Ev 13 5)) @((Act 1 $H.Allies)) -Disabled

Split-MultiText; Set-DialoguePacing
Add-Difficulty   # client level: Easy = half waves + double money, Medium = 3/4 + 50%, Hard = as written (MissionKit)
$textWarn = Test-TextTimeline

# resolve symbolic trigger references and write [Triggers]/[Events]/[Actions]/[Tags]
$idOf = @{}; foreach ($k in $trig.Keys) { $idOf[$k] = $trig[$k].Id }
foreach ($k in $trig.Keys) {
    $t = $trig[$k]
    $acts = foreach ($a in $t.Actions) { $p = $a -split ','; if ($p[1] -eq '2') { if (-not $idOf.ContainsKey($p[2])) { throw "unknown trigger '$($p[2])' in $k" }; $p[2] = $idOf[$p[2]] }; $p -join ',' }
    $ini.Set('Triggers', $t.Id, "$($t.House),<none>,$($t.Name),$([int]$t.Disabled),$($t.Diff),0")
    $ini.Set('Events', $t.Id, "$($t.Events.Count)," + ($t.Events -join ','))
    $ini.Set('Actions', $t.Id, "$(@($acts).Count)," + (@($acts) -join ','))
    $ini.Set('Tags', $t.Tag, "$(if ($t.Repeat) { 2 } else { 0 }),$($t.Name) 1,$($t.Id)")
}

# ================================================================ Zerg creep (mods/zerg-creep) from the start (user 2026-10-28)
# As ARKA 4 does. The creep spreaders are Art.ini ActiveAnims of the Zerg buildings (global), the rest of the creep
# block lives in the faction map code, which a campaign mission does not load: the animation list entries, vein growth
# on, buildable veins, ImmuneToVeins=yes for every type (the veins damage whatever stands on them).
$ini.Set('Basic', 'VeinGrowthEnabled', 'yes')
$ini.Set('General', 'VeinholeGrowthRate', '60')
$ini.Set('General', 'VeinholeShrinkRate', '8')      # creep of a dead nest recedes in ~a minute (Rules 100: ~10 min)
foreach ($ov in 'VEINS', 'VEINHOLEDUMMY') { $ini.Set($ov, 'Insignificant', 'yes') }
$an = 0; foreach ($a in 'SCZCRSPL', 'SCZCRSHL', 'SCZCRSPS', 'SCZCRSHS') { $an++; $ini.Set('Animations', "ARKA1ZC0$an", $a); $ini.Set($a, 'Name', "Zerg creep $a") }
$nImm = 0
foreach ($ln in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') {
    $names = @(); if ($rules.ContainsKey($ln)) { $names += @($rules[$ln].Values) }; $names += @($ini.Section($ln) | ForEach-Object { $_.Value })
    foreach ($tn in ($names | Sort-Object -Unique)) { if ($tn -and $tn -notmatch '^\d') { $ini.Set($tn, 'ImmuneToVeins', 'yes'); $nImm++ } }
}
# A Veinhole Monster in the map under every creep building (Hatchery at foundation cell (1,1), colonies at (0,0); holes
# 3+ cells apart, the engine's rule), overlay 167 + 8x 178 round it, and fully grown VEINS (126, data 48) on a disc of
# radius 5 round each hole and on every cell of every Zerg building plus a 1-cell margin. At map load Place_Monsters
# floods the veins connected to a hole and removes the others. Only clear ground without an overlay or a tree; cells of
# non-Zerg buildings stay free. Written last, after the crates (they refuse a cell with an overlay).
$o = [Pack]::Unpack($ini.Joined('OverlayPack'), $false); $od = [Pack]::Unpack($ini.Joined('OverlayDataPack'), $false)
$tree = @{}; foreach ($kv in $ini.Section('Terrain')) { $tree[[int]$kv.Key] = $true }
$foreign = @{}; $zb = @()
foreach ($kv in $structs) {
    $p = $kv.Value -split ','; $f = Foundation $p[1]; $bx = [int]$p[3]; $by = [int]$p[4]
    if ($p[0] -match '^Nod[12]$' -and $p[1] -like 'SCZ*') { $zb += , @($p[1], $bx, $by, $f[0], $f[1]); continue }
    for ($i = $bx; $i -lt $bx + $f[0]; $i++) { for ($j = $by; $j -lt $by + $f[1]; $j++) { $foreign[$j * 512 + $i] = $true } }
}
function Creep-Free($x, $y) { $c = $code[$y * $GW + $x]; $i = $y * 512 + $x; ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -and $o[$i] -eq 255 -and -not $tree[$y * 1000 + $x] -and -not $foreign[$i] }
$holes = @(); $nVein = 0
foreach ($b in $zb) {
    if ($b[0] -notin 'SCZHAT', 'SCZHIV', 'SCZCRP', 'SCZSUN', 'SCZSPO') { continue }
    $hx = $b[1]; $hy = $b[2]; if ($b[0] -in 'SCZHAT', 'SCZHIV') { $hx++; $hy++ }
    if (@($holes | Where-Object { [Math]::Max([Math]::Abs($_[0] - $hx), [Math]::Abs($_[1] - $hy)) -lt 3 }).Count) { continue }
    # the spreader's own cell first, then the other cells of the foundation (a colony by a rock ledge, ARKA 2 city gate)
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
foreach ($hole in $holes) { for ($dx = -5; $dx -le 5; $dx++) { for ($dy = -5; $dy -le 5; $dy++) { if ($dx * $dx + $dy * $dy -le 25) { & $veinAt ($hole[0] + $dx) ($hole[1] + $dy) } } } }   # not $h: it is $H, the house indices
foreach ($b in $zb) { for ($x = $b[1] - 1; $x -le $b[1] + $b[3]; $x++) { for ($y = $b[2] - 1; $y -le $b[2] + $b[4]; $y++) { & $veinAt $x $y } } }
# veins not 4-connected to a hole would go at map load (a Spire or Pool away from the discs kept bare ground): each loose
# patch gets a line of veins to the nearest connected vein within 15 cells
$conn = New-Object 'bool[]' $o.Length
$fill = { param($starts) $q = New-Object Collections.Generic.Queue[int]; foreach ($s in $starts) { if (-not $conn[$s]) { $conn[$s] = $true; $q.Enqueue($s) } }
    while ($q.Count) { $i = $q.Dequeue(); foreach ($d in -1, 1, -512, 512) { $j = $i + $d; if (-not $conn[$j] -and ($o[$j] -eq 126 -or $o[$j] -eq 178)) { $conn[$j] = $true; $q.Enqueue($j) } } } }
& $fill @($holes | ForEach-Object { $_[1] * 512 + $_[0] })
$nLoose = 0; $dead = New-Object 'bool[]' $o.Length
for ($i0 = 0; $i0 -lt $o.Length; $i0++) {
    if ($o[$i0] -ne 126 -or $conn[$i0] -or $dead[$i0]) { continue }
    # shortest walk over veins or free ground (BFS, 15 cells round the patch cell) to a connected vein, then veins on it
    $lx = $i0 % 512; $ly = [int][Math]::Floor($i0 / 512); $from = @{ $i0 = -1 }; $q = New-Object Collections.Generic.Queue[int]; $q.Enqueue($i0); $hit = -1
    while ($q.Count -and $hit -lt 0) {
        $i = $q.Dequeue(); foreach ($d in -1, 1, -512, 512) {
            $j = $i + $d; $x = $j % 512; $y = [int][Math]::Floor($j / 512)
            if ($from.ContainsKey($j) -or [Math]::Abs($x - $lx) -gt 15 -or [Math]::Abs($y - $ly) -gt 15) { continue }
            if ($conn[$j]) { $from[$j] = $i; $hit = $j; break }
            if ($o[$j] -eq 126 -or $o[$j] -eq 178 -or (Creep-Free $x $y)) { $from[$j] = $i; $q.Enqueue($j) }
        }
    }
    if ($hit -ge 0) { for ($i = $from[$hit]; $i -ne $i0; $i = $from[$i]) { if ($o[$i] -ne 126 -and $o[$i] -ne 178) { & $veinAt ($i % 512) ([int][Math]::Floor($i / 512)) } }; & $fill @($i0) }
    else {   # no way out (cut off by a cliff): the game would drop the patch at load, so it goes here already
        $nLoose++; $q.Enqueue($i0); $dead[$i0] = $true; $n0 = 0
        while ($q.Count) { $i = $q.Dequeue(); $o[$i] = 255; $od[$i] = 0; $n0++; foreach ($d in -1, 1, -512, 512) { $j = $i + $d; if (-not $dead[$j] -and $o[$j] -eq 126) { $dead[$j] = $true; $q.Enqueue($j) } } }
        $log.Add("creep: loose veins at $lx,$ly ($n0 cells, no path to a hole) removed")
    }
}
$ini.SetPack('OverlayPack', [Pack]::PackData($o, $false, 8192)); $ini.SetPack('OverlayDataPack', [Pack]::PackData($od, $false, 8192))
$log.Add("creep: vein growth on, 4 spreader animations, ImmuneToVeins on $nImm types; $($holes.Count) holes under $($zb.Count) Zerg buildings, $nVein vein cells, $nLoose loose patches removed")

# ================================================================ [Basic], briefing
$basic = [ordered]@{
    Name = 'ARKA #1: Obcy piasek'; Author = 'Zema (teren: Blizzard T2 Backwater Station)'; GameMode = 'Custom Map'; Player = 'Allies'
    Theme = 'AWAIT'; MultiplayerOnly = 'no'; HomeCell = '11'; AltHomeCell = '11'; MaxPlayer = '0'; MinPlayer = '2'; SkipMapSelect = 'yes'
    OneTimeOnly = 'yes'; EndOfGame = 'no'; SkipScore = 'no'; FreeRadar = 'yes'; RequiredAddOn = '1'; NextScenario = ''; AltNextScenario = ''
}
foreach ($k in $basic.Keys) { $ini.Set('Basic', $k, $basic[$k]) }
$ini.Sections.Remove('Briefing') | Out-Null; $ini.Order.Remove('Briefing') | Out-Null
$brief = @(
    'Mar Sara, rok 2499. ARKA wyskoczyla z rozdarcia nad pustynia w kolorze rdzy. Na niebie wisza dwa ksiezyce.',
    '@@Pole Chronosfery rozpadlo sie przy ladowaniu: baza jest rozsiana po kilku kilometrach, rdzen lezy w kraterze, a MCV utknal w piasku na poludniu.',
    '@@Zbierz rozbitkow, odzyskaj MCV i postaw baze. Na zachodzie jest ludzka osada, na polnocnym wschodzie cos, co gryzie. Einstein i Tanya musza przetrwac.')
for ($i = 0; $i -lt $brief.Count; $i++) { $ini.Set('Briefing', "$($i + 1)", $brief[$i]) }
$ini.Set('SpecialFlags', 'Visceroids', 'no')
$ini.Set('SpecialFlags', 'TiberiumGrows', 'no')
# the lobby preview of the terrain map is useless in a campaign mission (and is 2/3 of the file)
foreach ($s in 'Preview', 'PreviewPack') { $ini.Sections.Remove($s) | Out-Null; $ini.Order.Remove($s) | Out-Null }

[IO.File]::WriteAllText($Out, $ini.Write(), $enc)
$log.Add("written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB): $($trig.Count) triggers, $tmN teams, $($textNo - 9100) texts, $($structs.Count) buildings, $($units.Count) units, $($infs.Count) infantry, $smN smudges")

# ================================================================ client entry: INI\BattleE.ini (merge; other ARKA missions keep their entries)
if (-not $NoBattle) {
    $bf = "$game\INI\BattleE.ini"
    $b = if (Test-Path $bf) { [Ini]::Load($bf) } else { New-Object Ini }
    if (-not $b.Get('Battles', 'ARKAH', $null)) { $b.Set('Battles', 'ARKAH', 'HEADER_ARKA'); $b.Set('HEADER_ARKA', 'Description', 'ARKA: Blad znaku'); $b.Set('HEADER_ARKA', 'Categories', 'CAT_SA') }
    $b.Set('Battles', 'ARKA01', 'M_ARKA01')
    $m = [ordered]@{ CD = '-1'; Scenario = 'Maps/Missions/arka01.map'; Description = 'ARKA #1: Obcy piasek'; Author = 'Zema'; RequiredAddon = '1'; Side = '2'
        IconPath = 'alliesicon.png'; PlayerAlwaysOnNormalDifficulty = 'yes'; Categories = 'CAT_SA'
        LongDescription = 'Mar Sara, 2499. ARKA spadla na obca pustynie pod dwoma ksiezycami, a baza rozsypala sie po okolicy. @@Zbierz rozbitkow, odzyskaj MCV, pomoz ludzkiej kolonii na zachodzie i zniszcz gniazdo obcych na polnocnym wschodzie. Einstein i Tanya musza przetrwac.' }
    foreach ($k in $m.Keys) { $b.Set('M_ARKA01', $k, $m[$k]) }
    $head = "; ARKA campaign (Claude, Modding/wiki/plans/campaign-arka). Extra battle file read by the client`r`n; (Resources/ClientDefinitions.ini BattleFSFileName=BattleE.ini); written by Modding/tools/build-arka0*-mission.ps1.`r`n"
    [IO.File]::WriteAllText($bf, $head + $b.Write(), [Text.Encoding]::ASCII)
    $log.Add("BattleE.ini: M_ARKA01 merged (entries: " + (($b.Section('Battles') | ForEach-Object { $_.Key }) -join ',') + ")")
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
        # the object section must match the type's list (Marines are vehicles, Zerglings infantry)
        $want = @{ Structures = 'BuildingTypes'; Units = 'VehicleTypes'; Infantry = 'InfantryTypes' }[$sec]
        $isIn = @($ini.Section($want) | Where-Object { $_.Value -eq $typ }).Count -gt 0 -or $listOf[$typ] -eq $want -or $listOf[$typ] -eq "Rules:$want"
        if (-not $isIn) { $log.Add("FAIL $sec holds $typ, which is not in [$want]"); $fail++ }
    }
}
foreach ($ct in ($ini.Section('CellTags') | ForEach-Object { $_.Value } | Sort-Object -Unique)) { if (-not $ini.Get('Tags', $ct, $null)) { $log.Add("FAIL cell tag $ct has no [Tags] entry"); $fail++ } }
foreach ($id in ($ini.Section('TaskForces') | ForEach-Object { $_.Value })) {
    foreach ($kv in $ini.Section($id)) {
        if ($kv.Key -notmatch '^\d+$') { continue }
        if ($kv.Value -notmatch '^\d+,(\w+)$') { $log.Add("FAIL taskforce $id entry '$($kv.Value)'"); $fail++; continue }
        if (-not ($rules.ContainsKey($matches[1]) -or $ini.Has($matches[1]))) { $log.Add("FAIL taskforce $id type $($matches[1]) is defined nowhere"); $fail++ }
    }
}
foreach ($kv in $ini.Section('Triggers')) { if (($kv.Value -split ',').Count -ne 8) { $log.Add("FAIL trigger $($kv.Key) has $(($kv.Value -split ',').Count) fields"); $fail++ } }
# every type registered in a list must have its own section (map or Rules)
foreach ($ln in $listNames) { foreach ($kv in $ini.Section($ln)) { if (-not ($ini.Has($kv.Value) -or $rules.ContainsKey($kv.Value))) { $log.Add("FAIL $ln entry $($kv.Value) has no section"); $fail++ } } }
# ground teams must not use script action 1 (attack waypoint): they stop there for good (ARKA 0 user test 2026-10-27)
foreach ($kv in $ini.Section('TeamTypes')) {
    $tm = $kv.Value; $air = @($ini.Section($ini.Get($tm, 'TaskForce', '')) | Where-Object { $_.Value -match ',(SCZMUT|SCZOVL|SCPOBSV)$' }).Count
    $s1 = @($ini.Section($ini.Get($tm, 'Script', '')) | Where-Object { $_.Key -match '^\d+$' -and $_.Value -match '^1,' }).Count
    if ($s1 -and -not $air) { $log.Add("FAIL ground team $tm ($($ini.Get($tm, 'Name', ''))) uses script action 1"); $fail++ }
}# every object type registered by the map must find its art: the art section is named by Image= (or the type itself);
# a renamed copy without Image= is invisible in game (2026-10-27: Raynor's Vulture)
foreach ($ln in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') {
    foreach ($kv in $ini.Section($ln)) { $img = $ini.Get($kv.Value, 'Image', $kv.Value); if (-not $art.ContainsKey($img)) { $log.Add("FAIL $($kv.Value): no [$img] in Art.ini (would be invisible)"); $fail++ } }
}
# AI triggers name existing teams; houses with base nodes name existing building types
foreach ($kv in $ini.Section('AITriggerTypes')) {
    $p = $kv.Value -split ','; $tm = $p[1]; if (-not $ini.Has($tm)) { $log.Add("FAIL AI trigger $($kv.Key) team $tm missing"); $fail++ }
    # side 0 = any, otherwise ActsLike + 1 of the owner (game.exe 0x4109EF); anything else is silently never used
    $want = [int]$ini.Get($p[2], 'ActsLike', '-1') + 1
    if ($p[12] -ne '0' -and [int]$p[12] -ne $want) { $log.Add("FAIL AI trigger $($kv.Key): side $($p[12]), house $($p[2]) needs 0 or $want"); $fail++ }
}
foreach ($kv in $ini.Section('GDI1')) { if ($kv.Key -match '^\d{3}$') { $bt = ($kv.Value -split ',')[0]; if (-not ($ini.Has($bt) -or $rules.ContainsKey($bt))) { $log.Add("FAIL GDI1 node $bt undefined"); $fail++ } } }
# Prerequisite/BuiltAt in copied SC types must name something that exists
foreach ($s in $scTypes) { foreach ($k in 'Prerequisite', 'BuiltAt') { $v = $ini.Get($s, $k, $null); if ($v) { foreach ($tok in ($v -split ',')) { $tok = $tok.Trim(); if ($tok -and $tok -notmatch '^(POWER|FACTORY|BARRACKS|RADAR|TECH|PROC|none)$' -and -not ($ini.Has($tok) -or $rules.ContainsKey($tok))) { $log.Add("FAIL $s $k names $tok"); $fail++ } } } } }
$log.Add($(if ($fail) { "CHECKS: $fail FAIL" } else { 'CHECKS: PASS (types defined, teams exist, every tag has a trigger, prerequisites resolve)' }) + "; text timeline: $textWarn WARN")
$log | Set-Content "$work\log.txt" -Encoding UTF8
$log | Where-Object { $_ -notmatch '^building ' }

if ($Render) {
    $dir = "$game\Map Editor\Map Renderer"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$Out`" -o arka01_mission -d `"$work`" -p -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "renderer timed out" }
    "render: $work\arka01_mission.png"
}
