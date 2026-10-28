# Mission layer of ARKA mission 2 "Ewakuacja" (Mar Sara, 2499): the Allied base round the ARKA wreck, Raynor trapped in
# the infested Command Center of Mar Sara City, three shelters of colonists to walk to the landing zone of the Sons of
# Korhal (Mengsk's first appearance), and 15 minutes of charging the jump against the Zerg and a Confederate squad.
# Reads the terrain map built by build-arka02-marsara.ps1 (Maps\Custom\arka02_marsara.map, read-only) and writes
# Maps\Missions\arka02.map. Waypoints 10-55 of the terrain map are the contract (wiki missions/arka-02-ewakuacja).
#
#   powershell -NoProfile -File .\build-arka02-mission.ps1            # build + checks
#   powershell -NoProfile -File .\build-arka02-mission.ps1 -Render    # also render %TEMP%\arka02-mission\arka02_mission.png
#
# StarCraft types are copied into the map with their dependency closure, like in mission 1 (a campaign mission loads
# neither the StarCraft checkbox nor the faction map code). Texts: ASCII Polish, [Tutorial] numbers 9201-9299.
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
if (-not $Terrain) { $Terrain = "$game\Maps\Custom\arka02_marsara.map" }
if (-not $Out) { $Out = "$game\Maps\Missions\arka02.map" }
$work = "$env:TEMP\arka02-mission"
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
$lvl = New-Object 'int[]' ($GW * $GW)   # height level of each cell (the crystal field stays on the city plateau)
foreach ($t in [IsoMap]::Decode([Pack]::Unpack($ini.Joined('IsoMapPack5'), $true))) {
    $tile = if ($t.Tile -lt 0 -or $t.Tile -ge 65535) { 0 } else { $t.Tile }
    $tmp = $th.Get($tile); $c = 0
    if ($tmp -and $t.Sub -lt $tmp.Cells.Length -and $tmp.Cells[$t.Sub]) { $c = $tmp.Cells[$t.Sub].Terrain }
    $code[$t.Y * $GW + $t.X] = $c; $lvl[$t.Y * $GW + $t.X] = $t.Level
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
    'SCZLNG', 'SCZHYL', 'SCZMUT', 'SCZOVL', 'SCZINF',                       # Zerg units (Infested Terrans in the city)
    'SCZHAT', 'SCZPOL', 'SCZHDN', 'SCZSPI', 'SCZCRP', 'SCZSUN', 'SCZICC',   # Zerg nest + the infested Command Center
    'SCMARINE', 'SCFIRE', 'SCVULT', 'SCGOLI', 'SCSIEGE', 'SCDROP',          # Raynor's men, Sons of Korhal, the Confederate squad
    'SCCC', 'SCBARR', 'SCACAD', 'SCBUNK', 'SCDEPO', 'SCREFI',               # Mar Sara City (neutral ruins, shelters = bunkers)
    'SCRAYN')                                                               # Raynor's voices (the Vulture copy below)
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
        $ini.Set($ln, ('ARKA2{0}{1:D3}' -f $ln.Substring(0, 2).ToUpper(), $nList[$ln]), $s)
    }
}
$log.Add("SC types copied into the map: $($scTypes.Count) sections (" + (($nList.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', ') + ")")

# hatched/built-at flags that mean nothing here and may confuse the engine: Zerg flyers and the Infested Terran are
# Naval=yes only so that a Hatchery / the infested CC can hatch them (mission 1: suspected to keep weapons off flyers);
# the infested Command Center is a factory of Infested Terrans that nobody runs in this mission
foreach ($t in 'SCZMUT', 'SCZOVL', 'SCZINF', 'SCZICC') {
    $s = $ini.Section($t); for ($i = $s.Count - 1; $i -ge 0; $i--) { if ($s[$i].Key -in 'Naval', 'BuiltAt', 'Factory', 'WeaponsFactory', 'ExclusiveFactory') { $s.RemoveAt($i) } }
}
# the infested CC: half the skirmish strength, so that tanks can also crack it if Tanya's C4 does not get there
$ini.Set('SCZICC', 'Strength', '6000')
# ...and Repairable=yes, or Tanya's C4 never works on it: InfantryClass::What_Action (0x4D73BA) turns a C4 infantry's
# attack on a building into Sabotage only when the building type has IsRepairable (TechnoTypeClass+0x450, Vinifera.pdb).
# The Zerg buildings of StarCraft.ini say Repairable=no (test 2026-10-27: Tanya could only shoot it). Nod1 has 0 credits,
# so the Zerg never repair it anyway
$ini.Set('SCZICC', 'Repairable', 'yes'); $ini.Set('SCZICC', 'ClickRepairable', 'no')
# anti-air as in mission 1: rockets and Gauss rifles hit air AND ground whichever weapon the engine picks
function Resolve-Rules($sec) { $chain = @(); $s = $sec; while ($s -and $rules.ContainsKey($s) -and $chain.Count -lt 5) { $chain = , $s + $chain; $s = $rules[$s]['$Inherits'] }; $m = [ordered]@{}; foreach ($c in $chain) { foreach ($k in $rules[$c].Keys) { if ($k -ne '$Inherits') { $m[$k] = $rules[$c][$k] } } }; $m }
$aag = Resolve-Rules 'AGHeatSeeker'; $aag['AA'] = 'yes'; $aag['AG'] = 'yes'
foreach ($k in $aag.Keys) { $ini.Set('ARKA2AAG', $k, $aag[$k]) }
foreach ($w in '70mmMsl', '70mmMslRA', 'AA70mmMsl', 'AA70mmMslRA') { if ($rules.ContainsKey($w)) { $ini.Set($w, 'Projectile', 'ARKA2AAG') } }
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
function Buildable($x, $y) { $c = $code[$y * $GW + $x]; ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -and -not $block[$y * $GW + $x] }

$wp = @{}; foreach ($kv in $ini.Section('Waypoints')) { $v = [int]$kv.Value; $wp[[int]$kv.Key] = @(($v % 1000), [Math]::Floor($v / 1000)) }
foreach ($n in 10..55) { if (-not $wp.ContainsKey($n)) { throw "terrain map has no waypoint $n (contract 10-55 broken)" } }
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
    $s = Find-Spot ($wp[$n][0] + $dx - [Math]::Floor($f[0] / 2)) ($wp[$n][1] + $dy - [Math]::Floor($f[1] / 2)) $f[0] $f[1] $m $true
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
# SC Marines, Firebats, SCVs and the Infested Terran are SHP *vehicles* in the mod, so they go to [Units]
function Is-Vehicle($type) { $listOf[$type] -eq 'VehicleTypes' -or $listOf[$type] -eq 'Rules:VehicleTypes' -or @($ini.Section('VehicleTypes') | Where-Object { $_.Value -eq $type }).Count }
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
# ARKA wreck = the Chronosphere RAPDOX overridden in this map, as in mission 1; it belongs to the player since the
# engineer took it at the end of mission 1. No superweapon, no power, not repairable, not capturable.
$wrakType = 'RAPDOX'; $fcache[$wrakType] = @(2, 2)
$wrak = [ordered]@{
    Name = 'Wrak ARKI'; Strength = '20000'; Armor = 'heavy'; TechLevel = '-1'; Sight = '8'; Power = '0'; Powered = 'no'; Capturable = 'false'
    Crewed = 'no'; Unsellable = 'yes'; Repairable = 'no'; ClickRepairable = 'no'; SuperWeapon = 'none'; NukeSilo = 'no'; AIBuildThis = 'no'
}
foreach ($k in $wrak.Keys) { $ini.Set($wrakType, $k, $wrak[$k]) }
# Einstein: the Scientist (CHAN <- C2) resolved by hand ($Inherits does not reach from a map into Rules.ini)
$ein = Resolve-Rules 'CHAN'
$ein['Name'] = 'Albert Einstein'; $ein['Image'] = $(if ($art.ContainsKey('CHAN')) { 'CHAN' } else { 'C2' }); $ein['Strength'] = '400'; $ein['Insignificant'] = 'no'
$ein['Owner'] = 'Allies'; $ein['TechLevel'] = '-1'; $ein['EditorName'] = 'Einstein (ARKA)'; $ein['Fraidycat'] = 'no'
$ini.Set('InfantryTypes', 'ARKA2I01', 'ARKEINST'); foreach ($k in $ein.Keys) { $ini.Set('ARKEINST', $k, $ein[$k]) }
# Mar Sara colonists from the shelters: the civilian C2/C8 resolved, tougher and not panicking (a panicking civilian
# leaves its team and never reaches the landing zone)
$civN = 0
foreach ($src in 'C2', 'C8') {
    $civN++; $cv = Resolve-Rules $src
    $cv['Name'] = 'Kolonista z Mar Sary'; $cv['Image'] = $(if ($rules[$src]['Image']) { $rules[$src]['Image'] } else { $src }); $cv['Strength'] = '200'
    $cv['Fraidycat'] = 'no'; $cv['Insignificant'] = 'no'; $cv['TechLevel'] = '-1'; $cv['Owner'] = 'Allies1,Allies2,Soviet1'; $cv['EditorName'] = "Kolonista $civN (ARKA)"
    $ini.Set('InfantryTypes', "ARKA2I0$($civN + 1)", "ARKCIV$civN"); foreach ($k in $cv.Keys) { $ini.Set("ARKCIV$civN", $k, $cv[$k]) }
}
# Jim Raynor on his Vulture (as in mission 1: Image=SCVULT, +20% HP, self-healing, Raynor's own SC voices)
$ray = [ordered]@{}; foreach ($k in $scSec['SCVULT'].Keys) { $ray[$k] = $scSec['SCVULT'][$k] }
$ray['Name'] = 'Jim Raynor (Vulture)'; $ray['Image'] = 'SCVULT'; $ray['Strength'] = [string][int]([int]$ray['Strength'] * 4.8)   # +20%, then +300% (user 2026-10-28, all ARKA: "szybko pada"); $ray['TechLevel'] = '-1'; $ray['Owner'] = 'GDI2,Allies'
$ray['SelfHealing'] = 'yes'; $ray['SelfHealingCap'] = '1.0'; $ray['SelfHealingStep'] = '5'
foreach ($k in 'VoiceSelect', 'VoiceMove', 'VoiceAttack', 'VoiceFeedback', 'VoiceDie') { if ($scSec['SCRAYN'].Contains($k)) { $ray[$k] = $scSec['SCRAYN'][$k] } }
$ray.Remove('Prerequisite'); $ray.Remove('BuiltAt')
foreach ($k in @($ray.Keys)) { if ($k -match '^(DeploysInto|UndeploysInto|Deployer)$') { $ray.Remove($k) } }
$ini.Set('VehicleTypes', 'ARKA2V01', 'ARKRAYN'); foreach ($k in $ray.Keys) { $ini.Set('ARKRAYN', $k, $ray[$k]) }

# tech of mission 2: Allies up to the medium tank, no air (plan); same list as mission 1
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
$friends = 'Allies,Allies1,Allies2,Soviet1,Soviet2,Soviet,GDI2'
House 'Allies'  'AlliesSide'   'AlliedBlue' $friends 40 2 'yes' 'South' 0 3   # player: 4000 credits, tech level 3
House 'Allies1' 'AlliesSide'   'LightBlue'  $friends 0  2 'no'                # colonists of shelter 1 (and its bunker)
House 'Allies2' 'AlliesSide'   'LightBlue'  $friends 0  2 'no'                # colonists of shelter 2
House 'Soviet1' 'AlliesSide'   'LightBlue'  $friends 0  2 'no'                # colonists of shelter 3
# the ruins of Mar Sara City: friendly, not Neutral (a Neutral SC Bunker has a gun and shot the player, test 2026-10-27)
House 'Soviet2' 'AlliesSide'   'LightBlue'  $friends 0  2 'no'
House 'Soviet'  'GDISide'      'Gold'       $friends 0  3 'no'                # Sons of Korhal (Mengsk)
# Raynor on his way into the city: allied with everybody, so neither the Zerg nor the player shoot him on the road
House 'GDI2'    'GDISide'      'LightGold'  ($friends + ',Nod1,Nod2,GDI') 0 6 'no'
House 'Nod1'    'NodSide'      'Purple'     'Nod1,Nod2,GDI2' 0 7 'no' 'North' 3   # Zerg: nest, Mar Sara City, waves
House 'Nod2'    'NodSide'      'Purple'     'Nod1,Nod2,GDI2' 0 7 'no' 'North' 3   # Zerg packs on the road to the city
House 'GDI'     'GDISide'      'DarkRed'    'GDI,GDI2' 0 0 'no' 'West' 3       # Confederate squad sent to arrest Raynor
House 'Neutral' 'CivilianSide' 'Grey'       'Neutral' 0 4 'no'
House 'Special' 'SpecialSide'  'Grey'       'Special' 0 5 'no'

# ================================================================ overlays written by the mission (crystal expansion, Zerg creep)
$terrCell = @{}; foreach ($kv in $ini.Section('Terrain')) { $terrCell[[int]$kv.Key] = $true }
function Set-Overlays($cells) {   # cells: @(x, y, overlay, data); the packs are rewritten at once (MissionKit reads them later)
    $o = [Pack]::Unpack($ini.Joined('OverlayPack'), $false); $d = [Pack]::Unpack($ini.Joined('OverlayDataPack'), $false)
    foreach ($c in $cells) { $i = $c[1] * 512 + $c[0]; $o[$i] = [byte]$c[2]; $d[$i] = [byte]$c[3]; $script:ovl[$i] = [byte]$c[2]; $block[$c[1] * $GW + $c[0]] = $true }
    $ini.SetPack('OverlayPack', [Pack]::PackData($o, $false, 8192)); $ini.SetPack('OverlayDataPack', [Pack]::PackData($d, $false, 8192))
}
# crystal expansion on the eastern plain, north of the city (user 2026-10-28, marked on the render): blue gems as the
# converter makes them from SC mineral fields (overlay 31-34, data 9-11), on the free clear cells of a disc of radius 3.2
$rnd = New-Object Random 2501
$ex = Find-Spot 123 78 1 1 0 $false
$gems = @(); for ($x = $ex[0] - 4; $x -le $ex[0] + 4; $x++) { for ($y = $ex[1] - 4; $y -le $ex[1] + 4; $y++) {
    if (($x - $ex[0]) * ($x - $ex[0]) + ($y - $ex[1]) * ($y - $ex[1]) -gt 10.5) { continue }
    if (-not (Buildable $x $y) -or $ovl[$y * 512 + $x] -ne 255) { continue }
    $gems += , @($x, $y, (31 + $rnd.Next(4)), (9 + $rnd.Next(3)))
} }
Set-Overlays $gems; $log.Add("crystal expansion: $($gems.Count) gem cells round $($ex[0]),$($ex[1])")

# ================================================================ the Allied base round the ARKA wreck (SW)
foreach ($n in 10, 12, 13, 14, 15, 16, 17, 18, 19) { Reserve $wp[$n][0] $wp[$n][1] 2 }
# where the Sons of Korhal Dropships land: wp 59 and 60 beside the landing zone, not on wp 19 itself (the colonists walk
# to wp 19 and a Dropship standing there could keep them from arriving, so their script would never say "saved")
foreach ($d in @(@(59, 3, -1), @(60, -2, 2))) {
    $s = Find-Spot ($wp[19][0] + $d[1]) ($wp[19][1] + $d[2]) 1 1 0 $true; Occupy $s[0] $s[1] 1 1
    $wp[$d[0]] = $s; $ini.Set('Waypoints', "$($d[0])", "$($s[1] * 1000 + $s[0])"); $log.Add("dropship pad wp $($d[0]) = $($s[0]),$($s[1])")
}
Place-AtWp 'Allies' $wrakType 10 1 'ARKA2G01' 90          # 35% HP, as it was left in mission 1
# the four power plants that feed the core (they survived the crash and stand by the wreck)
$plantTags = 'ARKA2G21', 'ARKA2G22', 'ARKA2G23', 'ARKA2G24'
for ($k = 0; $k -lt 4; $k++) { Place-AtWp 'Allies' 'RAPOWR' (12 + $k) 0 $plantTags[$k] 256 0 }
Place-AtWp 'Allies' 'AFACT'  16 1 'None' 256 1               # the MCV deployed in mission 1
Place-AtWp 'Allies' 'RATENT' 17 1 'None' 256 1
# refinery by the nearest crystal field, with its harvester (a refinery placed in the map gets no free truck)
$gem = @(); for ($i = 0; $i -lt $ovl.Length; $i++) { if ($ovl[$i] -ge 27 -and $ovl[$i] -le 38) { $gx = $i % 512; $gy = [Math]::Floor($i / 512); if ([Math]::Abs($gx - $wp[18][0]) -le 14 -and [Math]::Abs($gy - $wp[18][1]) -le 14) { $gem += , @($gx, $gy) } } }
if ($gem.Count -eq 0) { throw "no crystal field near the base (wp 18)" }
$gcx = [int](($gem | ForEach-Object { $_[0] } | Measure-Object -Average).Average); $gcy = [int](($gem | ForEach-Object { $_[1] } | Measure-Object -Average).Average)
$f = Foundation 'RAPROC'; $s = Find-Spot ([int](($gcx + $wp[18][0]) / 2)) ([int](($gcy + $wp[18][1]) / 2)) $f[0] $f[1] 1 $true; Add-Building 'Allies' 'RAPROC' $s[0] $s[1] 'None' 1
Add-Unit 'Allies' 'RAHARV' $gcx $gcy 'Harvest'
$log.Add("base crystals: $($gem.Count) cells round $gcx,$gcy")
# the base grown since mission 1: a War Factory and SC Bunkers (left by Raynor's Marines) on the mesas round the base:
# the chevron mesa north of the wreck (corners and arm ends) and the landing-zone mesa (all reachable by ramps)
$f = Foundation 'RAWEAP'; $s = Find-Spot 150 193 $f[0] $f[1] 1 $false; Add-Building 'Allies' 'RAWEAP' $s[0] $s[1] 'None' 1
foreach ($b in @(@(125, 169), @(136, 169), @(149, 169), @(125, 177), @(148, 178), @(169, 172))) {
    $s = Find-Spot $b[0] $b[1] 3 2 0 $true; Add-Building 'Allies' 'SCBUNK' $s[0] $s[1] 'None' 1
}
# craters round the wreck (mission 1 scenery)
$smN = 0
$rnd = New-Object Random 2500
foreach ($i in 0..11) {
    $a = $rnd.NextDouble() * 6.283; $r = 2 + $rnd.NextDouble() * 4
    $sx = [int]($wp[10][0] + [Math]::Cos($a) * $r); $sy = [int]($wp[10][1] + [Math]::Sin($a) * $r)
    if (-not (Buildable $sx $sy)) { continue }
    $ini.Set('Smudge', "$smN", ('CR{0}{1},{2},{3},0' -f (1 + $rnd.Next(6)), [char](65 + $rnd.Next(5)), $sx, $sy)); $smN++
}

# ================================================================ player start force (wp 11) and the heroes by the wreck
$p = $wp[11]
$crate = Find-Spot ($p[0] + 3) ($p[1] + 2) 1 1 0 $false; Occupy $crate[0] $crate[1] 1 1
foreach ($t in '2TNK', '2TNK', '1TNK', '1TNK', 'RANG') { Add-Unit 'Allies' $t ($p[0] + 2) ($p[1] - 2) 'Guard' }
# Raynor's Marines stay with the player while he drives ahead (SHP vehicles)
Squad 'Allies' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE') 11 -2 -2
NewCell; Add-Inf 'Allies' 'TANYA' ($wp[10][0] + 3) ($wp[10][1] + 1) 'Guard' 'ARKA2G02' 256 100
NewCell; Add-Inf 'Allies' 'ARKEINST' ($wp[10][0] + 1) ($wp[10][1] + 3) 'Guard' 'ARKA2G03'
Squad 'Allies' @('E1', 'E1', 'E1') 11 1 2
Squad 'Allies' @('E1', 'E3A', 'E3A') 11 -1 3
Squad 'Allies' @('MEDIC', 'ENGINEER') 11 3 1

# ================================================================ Mar Sara City (SE plateau): ruins, shelters, the infested Command Center
foreach ($n in 30, 31, 32, 33, 34) { Reserve $wp[$n][0] $wp[$n][1] 2 }
Place-AtWp 'Nod1' 'SCZICC' 30 1 'ARKA2G06' 256
# wp 61: the cell right in front of (south of) the CC, where Raynor drives in and comes out again
# (user 2026-10-27: wp 31 was too far from the CC)
$cp = $structs[$structs.Count - 1].Value -split ','; $cf = Foundation 'SCZICC'
$rc = Find-Spot ([int]$cp[3] + [Math]::Floor($cf[0] / 2)) ([int]$cp[4] + $cf[1]) 1 1 0 $true; Occupy $rc[0] $rc[1] 1 1
$wp[61] = $rc; $ini.Set('Waypoints', '61', "$($rc[1] * 1000 + $rc[0])"); $log.Add("Raynor's CC door wp 61 = $($rc[0]),$($rc[1])")
# the shelters: SC Bunkers of the colonists' own houses (their guns help against the Zerg, never against the player)
# and an exit cell in front of each one, waypoints 56-58. Not the shelter waypoint itself: it lies under the bunker,
# and the colonists' reinforcement there never showed up (test 2026-10-27)
$shelterHouses = @('Allies1', 'Allies2', 'Soviet1')
for ($k = 0; $k -lt 3; $k++) {
    $n = 32 + $k; Place-AtWp $shelterHouses[$k] 'SCBUNK' $n 0 'None' 170
    $bp = $structs[$structs.Count - 1].Value -split ','; $bx = [int]$bp[3]; $by = [int]$bp[4]
    $ex = Find-Spot ($bx + 1) ($by + 2) 1 1 0 $true; Occupy $ex[0] $ex[1] 1 1
    $wp[56 + $k] = $ex; $ini.Set('Waypoints', "$(56 + $k)", "$($ex[1] * 1000 + $ex[0])")
    $log.Add("shelter $($k + 1): bunker @ $bx,$by, colonists come out at wp $(56 + $k) = $($ex[0]),$($ex[1])")
}
Place-AtWp 'Soviet2' 'SCDEPO' 36 0 'None' 120
Place-AtWp 'Soviet2' 'SCBARR' 37 1 'None' 90
Place-AtWp 'Soviet2' 'SCDEPO' 38 0 'None' 150
Place-AtWp 'Soviet2' 'SCACAD' 39 1 'None' 100
Place-AtWp 'Soviet2' 'SCDEPO' 36 0 'None' 80 0 4 2
Place-AtWp 'Nod1' 'SCZCRP' 52 0
Place-AtWp 'Nod1' 'SCZSUN' 35 0 'None' 256 0 4 3                                       # inside the city gate
foreach ($i in 0..9) {
    $a = $rnd.NextDouble() * 6.283; $r = 3 + $rnd.NextDouble() * 6
    $sx = [int]($wp[30][0] + [Math]::Cos($a) * $r); $sy = [int]($wp[30][1] + [Math]::Sin($a) * $r)
    if (-not (Buildable $sx $sy)) { continue }
    $ini.Set('Smudge', "$smN", ('CR{0}{1},{2},{3},0' -f (1 + $rnd.Next(6)), [char](65 + $rnd.Next(5)), $sx, $sy)); $smN++
}
# the city's Zerg (Nod1): Infested Terrans inside the gate, packs at the shelters
# not at wp 61 (in front of the CC): Raynor comes out there, and an Infested Terran left standing would blow up on him
Squad 'Nod1' @('SCZINF', 'SCZINF', 'SCZINF', 'SCZINF') 35 4 1 'Area Guard'
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') 52 0 0 'Area Guard'
Squad 'Nod1' @('SCZHYL', 'SCZHYL', 'SCZHYL') 36 -2 2 'Area Guard'
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG') 32 3 -2 'Area Guard'
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL') 33 -3 -2 'Area Guard'
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG') 34 -2 2 'Area Guard'
# crystal field below the infested CC (user 2026-10-28): "below" on screen = +x +y from the CC's far corner, the same
# blue gems as the eastern expansion, only on free cells of the CC's own plateau level; placed after the city so that
# nothing else moves
$ccP = @($structs | Where-Object { ($_.Value -split ',')[1] -eq 'SCZICC' })[0].Value -split ','; $ccF = Foundation 'SCZICC'
$ccX = [int]$ccP[3]; $ccY = [int]$ccP[4]; $ccL = $lvl[$ccY * $GW + $ccX]
function Gem-Free($x, $y) { (Buildable $x $y) -and $ovl[$y * 512 + $x] -eq 255 -and -not $reserved[$y * $GW + $x] -and $lvl[$y * $GW + $x] -eq $ccL }
$gc = $null
for ($r = 0; $r -le 8 -and -not $gc; $r++) { for ($x = $ccX + $ccF[0] + 3 - $r; $x -le $ccX + $ccF[0] + 3 + $r -and -not $gc; $x++) { for ($y = $ccY + $ccF[1] + 3 - $r; $y -le $ccY + $ccF[1] + 3 + $r; $y++) { if (Gem-Free $x $y) { $gc = @($x, $y); break } } } }
if (-not $gc) { throw "no free plateau cell for the crystal field below the infested CC ($ccX,$ccY level $ccL)" }
$rndGem = New-Object Random 2502   # own generator: $rnd goes on below, and the other random scenery must not move
$gems = @(); for ($x = $gc[0] - 4; $x -le $gc[0] + 4; $x++) { for ($y = $gc[1] - 4; $y -le $gc[1] + 4; $y++) {
    if (($x - $gc[0]) * ($x - $gc[0]) + ($y - $gc[1]) * ($y - $gc[1]) -gt 10.5 -or -not (Gem-Free $x $y)) { continue }
    $gems += , @($x, $y, (31 + $rndGem.Next(4)), (9 + $rndGem.Next(3)))
} }
Set-Overlays $gems; $log.Add("crystal field below the infested CC ($ccX,$ccY): $($gems.Count) gem cells round $($gc[0]),$($gc[1])")

# ================================================================ Zerg packs on the road (Nod2: "road cleared" = all of them dead)
Squad 'Nod2' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') 51 2 -2 'Area Guard'
Squad 'Nod2' @('SCZINF', 'SCZINF') 51 4 -3 'Area Guard'
Squad 'Nod2' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL') 42 0 0 'Area Guard'
Squad 'Nod2' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') 43 0 0 'Area Guard'
Squad 'Nod2' @('SCZINF', 'SCZINF') 43 2 2 'Area Guard'
Squad 'Nod2' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') 40 0 0 'Area Guard'

# ================================================================ Zerg nest (north): the source of the raids on the base
Place-AtWp 'Nod1' 'SCZHAT' 21 1 'ARKA2G07'
Place-AtWp 'Nod1' 'SCZPOL' 22 1
Place-AtWp 'Nod1' 'SCZHDN' 23 1
Place-AtWp 'Nod1' 'SCZSPI' 24 1
foreach ($n in 25, 26, 27) { Place-AtWp 'Nod1' 'SCZSUN' $n 0 }
foreach ($n in 28, 29) { Place-AtWp 'Nod1' 'SCZCRP' $n 0 }
foreach ($t in 'SCZOVL', 'SCZOVL') { Add-Unit 'Nod1' $t ($wp[21][0] - 4) ($wp[21][1] + 3) 'Guard' }
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') 20 0 0 'Area Guard'
Squad 'Nod1' @('SCZHYL', 'SCZHYL', 'SCZHYL') 21 -3 4 'Area Guard'
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL') 27 2 2 'Area Guard'

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
Zone 'ARKA2G10' 32 0 4      # shelter 1: the player was there (colonists come out once objective 3 is on)
Zone 'ARKA2G11' 33 0 4      # shelter 2
Zone 'ARKA2G12' 34 0 4      # shelter 3
Zone 'ARKA2G13' 30 2 5      # right by the infested CC: Tanya's line
Zone 'ARKA2G14' 35 0 6      # city gate: Raynor's call, the timer starts
Zone 'ARKA2G15' 43 0 4      # before the city (second way in)

# ================================================================ dialogue ([Tutorial] of the map, numbers 9201-9299)
$textNo = 9200
function Say([string]$s) { if ($s -match '[^\x20-\x7E]') { throw "non-ASCII text: $s" }; $script:textNo++; $ini.Set('Tutorial', "$script:textNo", $s); $script:textNo }

# ================================================================ taskforces, scripts, teams
$tfN = 0; $tmN = 0
function Team($name, $house, $spawnWp, [string[]]$members, [string[]]$script, $tag = $null) {
    $script:tfN++; $script:tmN++
    $tf = 'ARKA2F{0:D2}' -f $script:tfN; $sc = 'ARKA2S{0:D2}' -f $script:tfN; $tm = 'ARKA2M{0:D2}' -f $script:tmN
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
    # a team tag goes onto every member it creates (DTA cr07: "Soviet1 MCV" team with the genocide tag)
    if ($tag) { $v['Tag'] = $tag }
    foreach ($k in $v.Keys) { $ini.Set($tm, $k, "$($v[$k])") }
    $tm
}
# script lines: 3,N move; 16,N patrol = attack-move; 11,14 hunt; 11,10 area guard; 39,N set local N; 37 delete members.
# NOT 1,N for ground teams (they stop there for good, ARKA 0 test 2026-10-27); 1,N only for flyers.
$toBase = '16,10', '11,14'
$civ = @('ARKCIV1', 'ARKCIV1', 'ARKCIV1', 'ARKCIV2', 'ARKCIV2', 'ARKCIV2')
# Raynor drives ahead into the city and "goes in" (deleted at the CC): he is the hero locked inside.
# He first waits in the base for 3 minutes (5,30 = guard area 30 x 6 s; user 2026-10-27: he left too soon), drives to
# the door of the CC (wp 61) and sets local 19 "Raynor w CC" there: only then can his radio call come (rayInCC)
$tmRayIn  = Team 'Raynor jedzie do miasta' 'GDI2' 11 @('ARKRAYN') @('5,30', '3,43', '3,31', '3,61', '39,19', '37,0')
# ...and comes out at the same door when the CC blows up: a player team with the tag of "Raynor died" on its member
$tmRayOut = Team 'Raynor wychodzi' 'Allies' 61 @('ARKRAYN') @('11,5') 'ARKA2G05'
# colonists: walk to the landing zone, tell the mission they made it (local 2/3/4), board (deleted)
$tmCiv1   = Team 'Schron 1: kolonisci' 'Allies1' 56 $civ @('3,19', '39,2', '37,0')
$tmCiv2   = Team 'Schron 2: kolonisci' 'Allies2' 57 $civ @('3,19', '39,3', '37,0')
$tmCiv3   = Team 'Schron 3: kolonisci' 'Soviet1' 58 $civ @('3,19', '39,4', '37,0')
$tmSoK    = Team 'Synowie Korhalu' 'Soviet' 54 @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCGOLI', 'SCGOLI') @('11,10')
# the Dropships the colonists board: one team per pad, guarding (they stand on the landing zone till the end)
$tmDrop1  = Team 'Dropship SK 1' 'Soviet' 59 @('SCDROP') @('11,5')
$tmDrop2  = Team 'Dropship SK 2' 'Soviet' 60 @('SCDROP') @('11,5')
# raids on the base before the jump phase (stop when the Hatchery dies or the jump begins)
$tmRaid1  = Team 'Najazd z zachodu'   'Nod1' 46 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') $toBase
$tmRaid2  = Team 'Najazd z gniazda'   'Nod1' 20 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL') $toBase
$tmRaidR  = Team 'Najazd powtarzany'  'Nod1' 20 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL') $toBase
# the jump phase (15:00)
$tmP1     = Team 'Skok: fala 1'       'Nod1' 20 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') $toBase
$tmP2     = Team 'Skok: fala 2'       'Nod1' 46 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL', 'SCZHYL', 'SCZHYL') $toBase
$tmP3     = Team 'Skok: fala 3'       'Nod1' 44 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL', 'SCZHYL', 'SCZHYL', 'SCZINF', 'SCZINF') $toBase
$tmMuta   = Team 'Skok: mutaliski'    'Nod1' 50 @('SCZMUT', 'SCZMUT', 'SCZMUT') @('1,10', '11,14')
$tmConf   = Team 'Konfederacja'       'GDI'  55 @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE', 'SCFIRE', 'SCVULT', 'SCVULT', 'SCGOLI', 'SCGOLI', 'SCSIEGE') $toBase
$tmP5a    = Team 'Skok: fala 5 polnoc' 'Nod1' 20 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL', 'SCZHYL', 'SCZHYL', 'SCZHYL') $toBase
$tmP5b    = Team 'Skok: fala 5 wschod' 'Nod1' 47 @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZINF', 'SCZINF', 'SCZINF') $toBase

# ================================================================ triggers
$vars = 'Raynor wzywa', 'Raynor wolny', 'Schron 1 uratowany', 'Schron 2 uratowany', 'Schron 3 uratowany', 'Schron 1 stracony', 'Schron 2 stracony', 'Schron 3 stracony',
    'Skok', 'Elektrownia 1', 'Elektrownia 2', 'Elektrownia 3', 'Elektrownia 4', 'Droga czysta', 'Tanya przy CC',
    'Schrony: cel', 'Schron 1: gracz byl', 'Schron 2: gracz byl', 'Schron 3: gracz byl', 'Raynor w CC'
for ($i = 0; $i -lt $vars.Count; $i++) { $ini.Set('VariableNames', "$i", "$($vars[$i]),0") }
$trN = 0; $trig = [ordered]@{}
function Ev([int]$id, $p = 0) { "$id,0,$p" }
function Act([int]$id, $p = 0, [int]$kind = 0, [int]$w = 0) { "$id,$kind,$p,0,0,0,0,$(WpLetter $w)" }
function Text($s) { Act 11 (Say $s) }
function Reinf($team, $w) { Act 80 $team 1 $w }
function Enable($t) { Act 53 $t 2 }
function Disable($t) { Act 54 $t 2 }
function Trigger($key, $name, [string[]]$events, [string[]]$actions, $house = 'Allies', [switch]$Disabled, [switch]$Repeat, $tag = $null, $diff = '1,1,1') {
    $script:trN++; $id = 'ARKA2T{0:D2}' -f $script:trN
    $name = $name -replace ',', ' -'
    if (-not $tag) { $tag = 'ARKA2G{0:D2}' -f (30 + $script:trN) }
    $script:trig[$key] = @{ Id = $id; Name = $name; House = $house; Events = $events; Actions = $actions; Disabled = [bool]$Disabled; Repeat = [bool]$Repeat; Tag = $tag; Diff = $diff }
}
. "$tools\MissionKit.ps1"   # reveal crate, one text per trigger, dialogue gaps from text length, timeline check
Add-ScAirArmor             # SC flyer armors: Allied AA fires at SC flyers only on order, Dragoons cannot hit the Overlord
Add-RevealCrate $crate[0] $crate[1]

# --- opening: Raynor's map of the colony, Duke on the radio, Raynor drives ahead
Trigger 'intro' 'Start: Raynor' @((Ev 13 1)) @(
    (Act 48 1 0 10), (Reinf $tmRayIn 11),
    (Text 'Jim Raynor: Zergi weszly do Command Center w Mar Sara City. Ludzie wciaz siedza w schronach dookola. Konfederacja spisala ich na straty.'),
    (Enable 'intro2'))
Trigger 'intro2' 'Start 2: Duke' @((Ev 13 5)) @((Text 'Por. Duke (radio): Marszalku Raynor, zakaz zblizania sie do obiektu. A tych zolnierzy z muzeum prosze aresztowac.'), (Enable 'intro3')) -Disabled
Trigger 'intro3' 'Start 3: Tanya' @((Ev 13 5)) @((Text 'Tanya: Kowboju, oni zawsze sa tacy mili?'), (Enable 'intro4')) -Disabled
Trigger 'intro4' 'Start 4: Raynor' @((Ev 13 5)) @((Text 'Jim Raynor: To i tak lepszy dzien Duke''a. Pojade przodem, tylko sie rozejrze. Moi chlopcy zostaja z wami.'), (Enable 'intro5')) -Disabled
Trigger 'intro5' 'Start 5: Stavros' @((Ev 13 5)) @((Text 'Plk Stavros: Komandorze, do miasta prowadzi brod na poludniu. Zwiad widzi tam pelno tych stworzen.'), (Enable 'intro6')) -Disabled
Trigger 'intro6' 'Start 6: cel 1' @((Ev 13 5)) @(
    (Text 'Cel 1: oczysc droge do Mar Sara City (plaskowyz na wschodzie) z Zerglingow i Infested Terran.'),
    (Act 55 6 0 51), (Act 55 6 0 43), (Act 55 2 0 35), (Enable 'intro7')) -Disabled
Trigger 'intro7' 'Start 7: straty' @((Ev 13 5)) @((Text 'Einstein, Tanya, Raynor, wrak ARKI i cztery elektrownie przy wraku musza przetrwac.'), (Enable 'intro8')) -Disabled
Trigger 'intro8' 'Start 8: gniazdo' @((Ev 13 5)) @((Text 'Plk Stavros: Gniazdo na polnocy wysyla najazdy na baze. Jesli padnie ich Wylegarnia, bedzie spokojniej.'), (Act 55 6 0 21)) -Disabled

# --- losing
Trigger 'einLost' 'Einstein zginal' @((Ev 29)) @((Text 'Plk Stavros: Einstein nie zyje. Bez niego nikt z nas nie wroci do domu.'), (Act 2 $H.Allies)) -tag 'ARKA2G03'
Trigger 'tanLost' 'Tanya zginela' @((Ev 29)) @((Text 'Plk Stavros: Tanya nie zyje. Tracimy najlepszego zolnierza, jakiego mielismy.'), (Act 2 $H.Allies)) -tag 'ARKA2G02'
Trigger 'wreckLost' 'Wrak ARKI zniszczony' @((Ev 29)) @((Text 'Einstein: Rdzen... rdzen przepadl. Utknelismy tu na zawsze.'), (Act 2 $H.Allies)) -tag 'ARKA2G01'
Trigger 'rayLost' 'Raynor zginal' @((Ev 29)) @((Text 'Plk Stavros: Marszalek Raynor zginal. Kolonisci nie maja juz nikogo.'), (Act 2 $H.Allies)) -tag 'ARKA2G05'
Trigger 'allLost' 'Wszystko stracone' @((Ev 11 $H.Allies)) @((Act 2 $H.Allies))

# --- the four power plants of the core: each loss slows the charge, all four = no jump
for ($k = 1; $k -le 4; $k++) {
    Trigger "plant$k" "Elektrownia $k zniszczona" @((Ev 29)) @((Act 56 (8 + $k)), (Act 25 60),
        (Text "Plk Stavros: Stracilismy elektrownie nr $k przy wraku! Ladowanie rdzenia potrwa dluzej.")) -tag $plantTags[$k - 1]
}
Trigger 'plantsAll' 'Wszystkie elektrownie stracone' @((Ev 36 9), (Ev 36 10), (Ev 36 11), (Ev 36 12)) @(
    (Text 'Einstein: Bez elektrowni rdzen nie zaladuje sie nigdy. Zostajemy na tej planecie.'), (Act 2 $H.Allies))

# --- objective 1: the road (all Nod2 packs dead)
Trigger 'road' 'Droga oczyszczona' @((Ev 9 $H.Nod2)) @((Act 56 13), (Text 'Cel 1 wykonany: droga do Mar Sara City czysta.'))

# --- objective 2: Raynor's call at the city gate (or at 20:00), the timer of his health, Tanya's C4
$call = @((Act 56 0), (Act 27 600), (Act 23), (Enable 'rayTimer'), (Act 17 30), (Act 55 4 0 30),
    (Text 'Jim Raynor (radio): Tu Raynor! Siedze w Command Center, a te bestie sa w srodku! Odcieli mnie, dlugo nie wytrzymam!'),
    (Enable 'call2'))
# the zone calls wait for Raynor to be inside (local 19 from his team script), or he would call from the road
Trigger 'callGate' 'Raynor wzywa (brama)' @((Ev 1 $H.Allies)) ($call + @((Disable 'callNear'), (Disable 'callT'))) -tag 'ARKA2G14' -Disabled
Trigger 'callNear' 'Raynor wzywa (przedpole)' @((Ev 1 $H.Allies)) ($call + @((Disable 'callGate'), (Disable 'callT'))) -tag 'ARKA2G15' -Disabled
Trigger 'rayInCC' 'Raynor w Command Center' @((Ev 36 19)) @((Enable 'callGate'), (Enable 'callNear'))
Trigger 'callT' 'Raynor wzywa (czas)' @((Ev 13 1200), (Ev 37 0)) ($call + @((Disable 'callGate'), (Disable 'callNear')))
Trigger 'call2' 'Raynor wzywa 2: cel' @((Ev 13 5)) @(
    (Text 'Cel 2: wysadz zainfekowane Command Center (najlepiej C4 Tanyi), zanim licznik zdrowia Raynora spadnie do zera.')) -Disabled
Trigger 'rayTimer' 'Raynor: licznik zero' @((Ev 14)) @((Text 'Jim Raynor (radio, cicho): Za pozno... Powiedzcie ludziom w schronach, ze probowalem...'), (Act 2 $H.Allies)) -Disabled
Trigger 'tanyaCC' 'Tanya przy Command Center' @((Ev 1 $H.Allies), (Ev 37 1)) @((Act 56 14), (Text 'Tanya: Wylaz, kowboju, zaraz bedzie glosno.')) -tag 'ARKA2G13'
Trigger 'ccDown' 'Command Center wysadzone' @((Ev 48)) @(
    (Act 24), (Disable 'rayTimer'), (Disable 'callGate'), (Disable 'callNear'), (Disable 'callT'), (Act 56 1), (Act 65 30),
    (Reinf $tmRayOut 61),(Text 'Jim Raynor (wyskakuje z ruin): Moglas zapukac!'), (Enable 'ccDown2')) -house 'Nod1' -tag 'ARKA2G06'
Trigger 'ccDown2' 'Command Center 2' @((Ev 13 5)) @((Text 'Jim Raynor (patrzy na kule ognia nad Command Center): ...Cholera. Swietne macie te fajerwerki z muzeum.'), (Enable 'ccDown3')) -Disabled
Trigger 'ccDown3' 'Command Center 3' @((Ev 13 5)) @((Text 'Tanya: Rocznik piecdziesiaty trzeci, kowboju. Robione recznie.'), (Enable 'shelters')) -Disabled

# --- objective 3: the shelters, the Sons of Korhal, Mengsk
Trigger 'shelters' 'Cel 3: schrony' @((Ev 13 5)) @(
    (Text 'Cel 3: wyprowadz kolonistow z 3 schronow i doprowadz ich na ladowisko Synow Korhalu (betonowa plyta obok bazy). Co najmniej 2 schrony.'),
    (Act 55 6 0 32), (Act 55 6 0 33), (Act 55 6 0 34), (Act 55 3 0 19), (Act 56 15), (Enable 'sok')) -Disabled
Trigger 'sok' 'Synowie Korhalu laduja' @((Ev 13 20)) @(
    (Reinf $tmSoK 54), (Reinf $tmDrop1 59), (Reinf $tmDrop2 60), (Act 17 19), (Act 55 2 0 19),
    (Text 'Mengsk (ekran): Arcturus Mengsk, Synowie Korhalu. Konfederacja zostawila tych ludzi na smierc. Ja ich zabiore.'),
    (Enable 'sok2')) -Disabled
Trigger 'sok2' 'Mengsk 2' @((Ev 13 5)) @((Text 'Mengsk (ekran): Was tez, jesli zechcecie. Podobno macie maszyne, ktora przenosi czolgi przez pustke.'), (Enable 'sok3')) -Disabled
Trigger 'sok3' 'Mengsk 3: Einstein' @((Ev 13 5)) @((Text 'Einstein (cicho, do Stavrosa): Ten czlowiek usmiecha sie jak bankier do kogos, kto tonie.')) -Disabled
$civTeams = @($tmCiv1, $tmCiv2, $tmCiv3); $civHouses = @('Allies1', 'Allies2', 'Soviet1')
for ($k = 1; $k -le 3; $k++) {
    # the player at the shelter (cell tag, enabled from the start) only sets a local, and the colonists come out when
    # both locals are set: no disabled cell-tag trigger, and a player already standing by the shelter during the CC
    # fight does not have to walk out and back in (version 1 waited for an entry after the objective: nobody came out)
    Trigger "near$k" "Schron ${k}: gracz na miejscu" @((Ev 1 $H.Allies)) @((Act 56 (15 + $k))) -tag ('ARKA2G1{0}' -f ($k - 1))
    Trigger "civ$k" "Schron $k otwarty" @((Ev 36 15), (Ev 36 (15 + $k))) @(
        (Reinf $civTeams[$k - 1] (55 + $k)), (Enable "civArm$k"),
        (Text "Kolonista (schron $k): Ludzie! Prawdziwi ludzie! Idziemy za wami, tylko nie zostawiajcie nas!"))
    Trigger "civArm$k" "Schron $k pilnowany" @((Ev 13 5)) @((Enable "civLost$k")) -Disabled
    # the group's units all dead and the group not saved = lost (boarding deletes them only after local 2/3/4 is set);
    # units only (Ev 9): the house also owns its bunker
    Trigger "civLost$k" "Schron $k stracony" @((Ev 9 $H[$civHouses[$k - 1]]), (Ev 37 (1 + $k))) @(
        (Act 56 (4 + $k)), (Text "Plk Stavros: Stracilismy kolonistow ze schronu $k.")) -Disabled
    Trigger "civSaved$k" "Schron $k uratowany" @((Ev 36 (1 + $k))) @(
        (Disable "civLost$k"), (Text "Pilot Synow Korhalu: Kolonisci ze schronu $k na pokladzie. Startujemy!"))
}
foreach ($pr in @(@('A', 5, 6), @('B', 5, 7), @('C', 6, 7))) {
    Trigger "civFail$($pr[0])" "Dwa schrony stracone $($pr[0])" @((Ev 36 $pr[1]), (Ev 36 $pr[2])) @(
        (Text 'Einstein: Nie uratowalismy prawie nikogo. Nie po to tu przyszlismy.'), (Act 2 $H.Allies))
}

# --- objective 4: two shelters saved -> charge the jump for 15:00
$p4 = @('p4a', 'p4b', 'p4c')
foreach ($pr in @(@('p4a', 2, 3), @('p4b', 2, 4), @('p4c', 3, 4))) {
    Trigger $pr[0] "Dwa schrony uratowane $($pr[0])" @((Ev 36 $pr[1]), (Ev 36 $pr[2])) (@((Enable 'jumpStart')) + @($p4 | Where-Object { $_ -ne $pr[0] } | ForEach-Object { Disable $_ }))
}
$raidsOff = @('raid1', 'raid2', 'raidRep', 'raidRepOn')
Trigger 'jumpStart' 'Skok: start' @((Ev 13 3)) (@(
    (Act 56 8), (Act 27 900), (Act 23), (Act 20 48), (Act 48 1 0 10), (Act 55 4 0 10),
    (Text 'Einstein: ARKA nie poleci jak statek, ale zrobi jeden krotki skok w przestrzeni. Rdzen potrzebuje 15 minut i pradu z czterech elektrowni.'),
    (Enable 'jump2'), (Enable 'jumpEnd'), (Enable 'p4w1'), (Enable 'p4w2'), (Enable 'p4w3'), (Enable 'p4muta'), (Enable 'p4conf'), (Enable 'p4w5'), (Enable 'p4prot'), (Enable 'p4hard')) +
    @($raidsOff | ForEach-Object { Disable $_ })) -Disabled
Trigger 'jump2' 'Skok: cel' @((Ev 13 5)) @((Text 'Cel 4: bron wraku ARKI i elektrowni, az rdzen sie naladuje. Wszystko w polu ARKI skoczy razem z nami.'), (Enable 'jump3')) -Disabled
Trigger 'jump3' 'Skok: Mengsk' @((Ev 13 5)) @((Text 'Mengsk (radio): Wspolrzedne Antigi Prime macie w komputerze, profesorze. Do zobaczenia po drugiej stronie.')) -Disabled
Trigger 'p4w1' 'Skok: fala 1' @((Ev 13 60)) @((Reinf $tmP1 20), (Act 55 3 0 40)) -Disabled
Trigger 'p4w2' 'Skok: fala 2' @((Ev 13 200)) @((Reinf $tmP2 46), (Act 55 3 0 46), (Text 'EVA: Wrog nadciaga od zachodu.')) -Disabled
Trigger 'p4w3' 'Skok: fala 3' @((Ev 13 330)) @((Reinf $tmP3 44), (Act 55 3 0 40), (Text 'Einstein: Ida ze wszystkich stron. Czuja, ze rdzen sie budzi.')) -Disabled
Trigger 'p4muta' 'Skok: mutaliski' @((Ev 13 440)) @((Reinf $tmMuta 50), (Act 55 3 0 50), (Text 'Tanya: Latajace! Rakiety w gore!')) -Disabled
Trigger 'p4hard' 'Skok: fala dodatkowa (trudny)' @((Ev 13 500), (Ev 27 12)) @((Reinf $tmMuta 50), (Reinf $tmP1 46)) -Disabled
Trigger 'p4conf' 'Skok: Konfederacja' @((Ev 13 540)) @((Reinf $tmConf 55), (Act 55 3 0 55),
    (Text 'Por. Duke (radio): Tu Konfederacja. Marszalek Raynor i obca jednostka wojskowa sa aresztowani. Zlozyc bron!'), (Enable 'p4conf2')) -Disabled
Trigger 'p4conf2' 'Skok: Konfederacja 2' @((Ev 13 5)) @((Text 'Jim Raynor: Duke zawsze mial wyczucie czasu. Odeprzyjcie ich od zachodu!'), (Enable 'p4conf3')) -Disabled
# both Terran sides look alike (same SC units): say which is which (Confederates dark red, Sons of Korhal gold)
Trigger 'p4conf3' 'Skok: Konfederacja 3' @((Ev 13 5)) @((Text 'Tanya: To ci od aresztowania, czy ci od ratowania?'), (Enable 'p4conf4')) -Disabled
Trigger 'p4conf4' 'Skok: Konfederacja 4' @((Ev 13 5)) @((Text 'Jim Raynor: Ci od aresztowania. Ratujacy maja zlote pancerze.')) -Disabled
Trigger 'p4w5' 'Skok: fala 5' @((Ev 13 680)) @((Reinf $tmP5a 20), (Reinf $tmP5b 47), (Act 55 3 0 40), (Act 55 3 0 47)) -Disabled
Trigger 'p4prot' 'Skok: Protossi' @((Ev 13 830)) @((Act 55 6 0 49), (Act 17 49),
    (Text 'Plk Stavros: Na radarze cos wielkiego na orbicie. Nie nasze i nie Konfederacji.'), (Enable 'p4prot2')) -Disabled
Trigger 'p4prot2' 'Skok: Protossi 2' @((Ev 13 5)) @((Text 'Jim Raynor: To ci, ktorzy spalili Chau Sare. Profesorze, wlaczaj to cholerstwo!')) -Disabled

# --- the jump: timer zero -> flash, epilogue on Antiga Prime, win
$noLoss = @('einLost', 'tanLost', 'wreckLost', 'rayLost', 'allLost', 'plantsAll', 'civFailA', 'civFailB', 'civFailC', 'rayTimer') + @(1..4 | ForEach-Object { "plant$_" })
Trigger 'jumpEnd' 'Skok: licznik zero' @((Ev 14)) (@($noLoss | ForEach-Object { Disable $_ }) + @(
    (Act 48 1 0 10), (Act 64 10), (Act 65 10), (Act 66 10),
    (Text 'Einstein: Rdzen naladowany! Wszyscy w pole ARKI... SKOK!'), (Enable 'end1'))) -Disabled
Trigger 'end1' 'Antiga Prime 1' @((Ev 13 5)) @((Act 66 10), (Text 'Antiga Prime. ARKA stoi na rowninie za miastem. Mengsk juz czeka.'), (Enable 'end2')) -Disabled
Trigger 'end2' 'Antiga Prime 2' @((Ev 13 5)) @((Text 'Mengsk: Spozniliscie sie trzy dni, profesorze.'), (Enable 'end3')) -Disabled
Trigger 'end3' 'Antiga Prime 3' @((Ev 13 5)) @((Text 'Einstein: ...Dla nas to byla sekunda.'), (Enable 'end4')) -Disabled
Trigger 'end4' 'Antiga Prime 4' @((Ev 13 5)) @((Text 'Mengsk pokazuje nagrania z orbity Mar Sary. Protossi pala planete.'), (Enable 'end5')) -Disabled
Trigger 'end5' 'Antiga Prime 5' @((Ev 13 5)) @((Text 'Jim Raynor: To byl moj dom.'), (Enable 'end6')) -Disabled
Trigger 'end6' 'Antiga Prime 6' @((Ev 13 5)) @((Text 'Einstein: Przykro mi, marszalku. Wiem, jak to jest patrzec, jak plonie swiat, ktory sie znalo.'), (Enable 'endWin')) -Disabled
Trigger 'endWin' 'Wygrana' @((Ev 13 40)) @((Act 1 $H.Allies)) -Disabled

# --- raids on the base while the player is away (off when the Hatchery dies or the jump starts)
Trigger 'raid1' 'Najazd 1' @((Ev 13 560)) @((Reinf $tmRaid1 46), (Act 55 3 0 46), (Text 'EVA: Baza atakowana od zachodu.'))
Trigger 'raid2' 'Najazd 2' @((Ev 13 1000)) @((Reinf $tmRaid2 20), (Act 55 3 0 40), (Text 'EVA: Wrog nadciaga z polnocy.'))
Trigger 'raidRep' 'Najazd powtarzany' @((Ev 13 450)) @((Reinf $tmRaidR 20), (Act 55 3 0 40)) -Repeat -Disabled
Trigger 'raidRepOn' 'Najazdy powtarzane wlaczone' @((Ev 13 1500)) @((Enable 'raidRep'))
Trigger 'hatch' 'Wylegarnia zniszczona' @((Ev 29)) (@((Text 'Plk Stavros: Wylegarnia na polnocy plonie! Najazdy na baze ustana.')) + @($raidsOff | ForEach-Object { Disable $_ })) -tag 'ARKA2G07'

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

# ================================================================ Zerg creep (mods/zerg-creep) from the start of the mission
# As ARKA 4 does (user 2026-10-28; the first version here had only the 5x5 ring round each hole, so the Pool, Hydra Den,
# Spire and infested CC stood on bare ground). The spreaders (Art.ini ActiveAnims) get their [Animations] entries and
# the veins are buildable, both from the faction map code a mission does not load (vein growth and ImmuneToVeins: see
# [Basic] below). A Veinhole Monster in the map under every creep building (Hatchery at foundation cell (1,1), colonies
# at (0,0); holes 3+ cells apart, the engine's rule), overlay 167 + 8x 178 round it, and fully grown VEINS (126, data 48)
# on a disc of radius 5 round each hole and on every cell of every Zerg building plus a 1-cell margin. At map load
# Place_Monsters floods the veins connected to a hole and removes the others. Only clear ground without an overlay or a
# tree; cells of non-Zerg buildings stay free. Written last, after the crates (they refuse a cell with an overlay).
foreach ($ov in 'VEINS', 'VEINHOLEDUMMY') { $ini.Set($ov, 'Insignificant', 'yes') }
$an = 0; foreach ($a in 'SCZCRSPL', 'SCZCRSHL', 'SCZCRSPS', 'SCZCRSHS') { $an++; $ini.Set('Animations', "ARKA2ZC0$an", $a); $ini.Set($a, 'Name', "Zerg creep $a") }
$o = [Pack]::Unpack($ini.Joined('OverlayPack'), $false); $od = [Pack]::Unpack($ini.Joined('OverlayDataPack'), $false)
$foreign = @{}; $zb = @()
foreach ($kv in $structs) {
    $p = $kv.Value -split ','; $f = Foundation $p[1]; $bx = [int]$p[3]; $by = [int]$p[4]
    if ($p[0] -match '^Nod[12]$' -and $p[1] -like 'SCZ*') { $zb += , @($p[1], $bx, $by, $f[0], $f[1]); continue }
    for ($i = $bx; $i -lt $bx + $f[0]; $i++) { for ($j = $by; $j -lt $by + $f[1]; $j++) { $foreign[$j * 512 + $i] = $true } }
}
function Creep-Free($x, $y) { $c = $code[$y * $GW + $x]; $i = $y * 512 + $x; ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -and $o[$i] -eq 255 -and -not $terrCell[$y * 1000 + $x] -and -not $foreign[$i] }
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
$log.Add("creep: 4 spreader animations; $($holes.Count) holes under $($zb.Count) Zerg buildings, $nVein vein cells, $nLoose loose patches removed")

# ================================================================ [Basic], briefing
$basic = [ordered]@{
    Name = 'ARKA #2: Ewakuacja'; Author = 'Zema (teren: Blizzard T3 Desperate Alliance)'; GameMode = 'Custom Map'; Player = 'Allies'
    Theme = 'RUN1226M'; MultiplayerOnly = 'no'; HomeCell = '11'; AltHomeCell = '11'; MaxPlayer = '0'; MinPlayer = '2'; SkipMapSelect = 'yes'
    OneTimeOnly = 'yes'; EndOfGame = 'no'; SkipScore = 'no'; FreeRadar = 'yes'; RequiredAddOn = '1'; NextScenario = ''; AltNextScenario = ''
    # SC-style briefing movie MOVIES\ARKA02B.MP4 from tools\build-briefing.ps1 (Vinifera resolves ARKA02B.VQA to .MP4)
    Brief = 'ARKA02B'
}
foreach ($k in $basic.Keys) { $ini.Set('Basic', $k, $basic[$k]) }
$ini.Sections.Remove('Briefing') | Out-Null; $ini.Order.Remove('Briefing') | Out-Null
$brief = @(
    'Mar Sara, kilka dni po katastrofie ARKI. Raynor przychodzi do bazy Aliantow z mapa kolonii.',
    '@@Zergi weszly do Command Center w Mar Sara City, a ludzie wciaz siedza w schronach dookola. Konfederacja spisala ich na straty.',
    '@@Oczysc droge do miasta, wyciagnij Raynora, doprowadz kolonistow na ladowisko Synow Korhalu i naladuj rdzen ARKI do skoku. Einstein, Tanya, Raynor i wrak ARKI musza przetrwac.')
for ($i = 0; $i -lt $brief.Count; $i++) { $ini.Set('Briefing', "$($i + 1)", $brief[$i]) }
$ini.Set('SpecialFlags', 'Visceroids', 'no')
$ini.Set('SpecialFlags', 'TiberiumGrows', 'no')
# Zerg creep (mods/zerg-creep): what the creep block of Terran Faction.ini gives a skirmish, which a mission does not
# load: veins grow (357 DTA maps say no), every 60 frames, and every type is immune to the vein attack (or the creep
# eats the player's units and buildings, test 5 of the creep mod)
$ini.Set('Basic', 'VeinGrowthEnabled', 'yes')
$ini.Set('General', 'VeinholeGrowthRate', '60')
$ini.Set('General', 'VeinholeShrinkRate', '8')      # creep of a dead nest recedes in ~a minute (Rules 100: ~10 min; 5 was 40% too fast)
$immune = 0
foreach ($s in $scSec.Keys) {
    if ($scSec[$s]['ImmuneToVeins'] -ne 'yes' -or -not $listOf.ContainsKey($s)) { continue }
    if ($listOf[$s] -like 'Rules:*' -or $known.ContainsKey($s)) { $ini.Set($s, 'ImmuneToVeins', 'yes'); $immune++ }   # in the map: Rules or copied SC
}
foreach ($s in 'ARKRAYN', 'ARKEINST', 'ARKCIV1', 'ARKCIV2', $wrakType) { if ($ini.Has($s)) { $ini.Set($s, 'ImmuneToVeins', 'yes'); $immune++ } }
$log.Add("creep: ImmuneToVeins=yes on $immune types")
foreach ($s in 'Preview', 'PreviewPack') { $ini.Sections.Remove($s) | Out-Null; $ini.Order.Remove($s) | Out-Null }

[IO.File]::WriteAllText($Out, $ini.Write(), $enc)
$log.Add("written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB): $($trig.Count) triggers, $tmN teams, $($textNo - 9200) texts, $($structs.Count) buildings, $($units.Count) units, $($infs.Count) infantry, $smN smudges")

# ================================================================ client entry: INI\BattleE.ini (merge; other ARKA missions keep their entries)
if (-not $NoBattle) {
    $bf = "$game\INI\BattleE.ini"
    $b = if (Test-Path $bf) { [Ini]::Load($bf) } else { New-Object Ini }
    if (-not $b.Get('Battles', 'ARKAH', $null)) { $b.Set('Battles', 'ARKAH', 'HEADER_ARKA'); $b.Set('HEADER_ARKA', 'Description', 'ARKA: Blad znaku'); $b.Set('HEADER_ARKA', 'Categories', 'CAT_SA') }
    $b.Set('Battles', 'ARKA02', 'M_ARKA02')
    $m = [ordered]@{ CD = '-1'; Scenario = 'Maps/Missions/arka02.map'; Description = 'ARKA #2: Ewakuacja'; Author = 'Zema'; RequiredAddon = '1'; Side = '2'
        IconPath = 'alliesicon.png'; PlayerAlwaysOnNormalDifficulty = 'yes'; Categories = 'CAT_SA'
        LongDescription = 'Mar Sara, 2499. Zergi zajely Command Center w Mar Sara City, a kolonisci czekaja w schronach. @@Oczysc droge do miasta, wyciagnij Raynora z zainfekowanego Command Center, doprowadz kolonistow na ladowisko Synow Korhalu i bron ARKI przez 15 minut ladowania skoku.' }
    foreach ($k in $m.Keys) { $b.Set('M_ARKA02', $k, $m[$k]) }
    $head = "; ARKA campaign (Claude, Modding/wiki/plans/campaign-arka). Extra battle file read by the client`r`n; (Resources/ClientDefinitions.ini BattleFSFileName=BattleE.ini); written by Modding/tools/build-arka0*-mission.ps1.`r`n"
    [IO.File]::WriteAllText($bf, $head + $b.Write(), [Text.Encoding]::ASCII)
    $log.Add("BattleE.ini: M_ARKA02 merged (entries: " + (($b.Section('Battles') | ForEach-Object { $_.Key }) -join ',') + ")")
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
foreach ($ln in $listNames) { foreach ($kv in $ini.Section($ln)) { if (-not ($ini.Has($kv.Value) -or $rules.ContainsKey($kv.Value))) { $log.Add("FAIL $ln entry $($kv.Value) has no section"); $fail++ } } }
foreach ($kv in $ini.Section('TeamTypes')) {
    $tm = $kv.Value; $air = @($ini.Section($ini.Get($tm, 'TaskForce', '')) | Where-Object { $_.Value -match ',(SCZMUT|SCZOVL|SCDROP)$' }).Count
    $s1 = @($ini.Section($ini.Get($tm, 'Script', '')) | Where-Object { $_.Key -match '^\d+$' -and $_.Value -match '^1,' }).Count
    if ($s1 -and -not $air) { $log.Add("FAIL ground team $tm ($($ini.Get($tm, 'Name', ''))) uses script action 1"); $fail++ }
}
foreach ($ln in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') {
    foreach ($kv in $ini.Section($ln)) { $img = $ini.Get($kv.Value, 'Image', $kv.Value); if (-not $art.ContainsKey($img)) { $log.Add("FAIL $($kv.Value): no [$img] in Art.ini (would be invisible)"); $fail++ } }
}
foreach ($s in $scTypes) { foreach ($k in 'Prerequisite', 'BuiltAt') { $v = $ini.Get($s, $k, $null); if ($v) { foreach ($tok in ($v -split ',')) { $tok = $tok.Trim(); if ($tok -and $tok -notmatch '^(POWER|FACTORY|BARRACKS|RADAR|TECH|PROC|none)$' -and -not ($ini.Has($tok) -or $rules.ContainsKey($tok))) { $log.Add("FAIL $s $k names $tok"); $fail++ } } } } }
# local variables set by team scripts (39,N) and tested by triggers must exist in [VariableNames]
foreach ($id in ($ini.Section('ScriptTypes') | ForEach-Object { $_.Value })) { foreach ($kv in $ini.Section($id)) { if ($kv.Value -match '^39,(\d+)$' -and -not $ini.Get('VariableNames', $matches[1], $null)) { $log.Add("FAIL script $id sets undeclared local $($matches[1])"); $fail++ } } }
$log.Add($(if ($fail) { "CHECKS: $fail FAIL" } else { 'CHECKS: PASS (types defined, teams exist, every tag has a trigger, prerequisites resolve)' }) + "; text timeline: $textWarn WARN")
$log | Set-Content "$work\log.txt" -Encoding UTF8
$log | Where-Object { $_ -notmatch '^building ' }

if ($Render) {
    $dir = "$game\Map Editor\Map Renderer"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$Out`" -o arka02_mission -d `"$work`" -p -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "renderer timed out" }
    "render: $work\arka02_mission.png"
}
