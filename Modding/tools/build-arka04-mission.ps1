# Mission layer of ARKA mission 4 "Zielony krysztal" (Antiga Prime, 2499): Einstein analyses the green crystal from the
# ARKA core in a laboratory by the ARKA while the Zerg, drawn by the sample, raid the base; Mengsk sends the player to
# the crashed Norad II to save General Duke (Duke then fights for the player as a hero Marine); a last wave of
# Mutalisks and Guardians on the laboratory. A calm, economic mission (user 2026-10-27): no visible 20-minute timer
# (Einstein reports his progress instead), no rush to Norad II (Duke has dug in), a thin home field and rich
# expansions (NW, the centre nest, the Hive in the north, and Stickler Woods in the NE, where the ore grows back).
# Reads the terrain map built by build-arka04-antiga.ps1 (Maps\Custom\arka04_antiga.map, read-only) and writes
# Maps\Missions\arka04.map. Waypoints 10-62 of the terrain map are the contract (wiki missions/arka-04-zielony-krysztal).
#
#   powershell -NoProfile -File .\build-arka04-mission.ps1            # build + checks
#   powershell -NoProfile -File .\build-arka04-mission.ps1 -Render    # also render %TEMP%\arka04-mission\arka04_mission.png
#
# StarCraft types are copied into the map with their dependency closure, like in missions 1-2. Texts: ASCII Polish,
# [Tutorial] numbers 9401-9499. Time units: Elapsed Time counts game seconds (what the on-screen timer would show).
param(
    [string]$Terrain = "",
    [string]$Out = "",
    [int]$AnalysisSecs = 1200,   # "20 minut" of Einstein's analysis, silent (no timer on screen)
    [switch]$Render,
    [switch]$NoBattle
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Terrain) { $Terrain = "$game\Maps\Custom\arka04_antiga.map" }
if (-not $Out) { $Out = "$game\Maps\Missions\arka04.map" }
$work = "$env:TEMP\arka04-mission"
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
# not SCZLAI: the Zerg research mod reuses that section ("Melee Attacks & Carapace"), so the centre nest has a Hatchery
$scRoots = @(
    'SCZLNG', 'SCZHYL', 'SCZULT', 'SCZMUT', 'SCZGRD', 'SCZOVL', 'SCZINF', 'SCZBRD',  # Zerg units
    'SCCC',                                                                          # Raynor's flying Command Center (SCCCF)
    'SCZEXT', 'SCZWORK',                                                             # the Hive's Extractor and its harvesting Drone
    'SCZHAT', 'SCZHIV', 'SCZPOL', 'SCZHDN', 'SCZEVO', 'SCZSPI', 'SCZCRP', 'SCZSUN', 'SCZSPO',   # nests and colonies
    'SCZDCRP', 'SCZDSUN', 'SCZDSPO', 'SCZDEVO', 'SCZDHDN',                    # Drones the nests build with (Add-ZergBuilder)
    'SCMARINE', 'SCGOLI', 'SCDROP', 'SCBUNK', 'SCVULT',                              # Duke's men, Sons of Korhal, bunkers
    'SCRAYN', 'SCHERO', 'SCBCF')                                                     # Raynor/Duke heroes, Norad II
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
        $ini.Set($ln, ('ARKA4{0}{1:D3}' -f $ln.Substring(0, 2).ToUpper(), $nList[$ln]), $s)
    }
}
$log.Add("SC types copied into the map: $($scTypes.Count) sections (" + (($nList.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', ') + ")")
# hatched-at flags of the Zerg flyers mean nothing here (mission 1: suspected to keep weapons off flyers)
foreach ($t in 'SCZMUT', 'SCZGRD', 'SCZOVL', 'SCZINF') {
    $s = $ini.Section($t); for ($i = $s.Count - 1; $i -ge 0; $i--) { if ($s[$i].Key -in 'Naval', 'BuiltAt', 'Factory', 'WeaponsFactory', 'ExclusiveFactory') { $s.RemoveAt($i) } }
}
# anti-air as in missions 1-2: rockets and Gauss rifles hit air AND ground whichever weapon the engine picks
function Resolve-Rules($sec) { $chain = @(); $s = $sec; while ($s -and $rules.ContainsKey($s) -and $chain.Count -lt 5) { $chain = , $s + $chain; $s = $rules[$s]['$Inherits'] }; $m = [ordered]@{}; foreach ($c in $chain) { foreach ($k in $rules[$c].Keys) { if ($k -ne '$Inherits') { $m[$k] = $rules[$c][$k] } } }; $m }
$aag = Resolve-Rules 'AGHeatSeeker'; $aag['AA'] = 'yes'; $aag['AG'] = 'yes'
foreach ($k in $aag.Keys) { $ini.Set('ARKA4AAG', $k, $aag[$k]) }
foreach ($w in '70mmMsl', '70mmMslRA', 'AA70mmMsl', 'AA70mmMslRA') { if ($rules.ContainsKey($w)) { $ini.Set($w, 'Projectile', 'ARKA4AAG') } }
foreach ($w in 'SCGauss', 'SCGaussS') { if ($ini.Has($w)) { $ini.Set($w, 'Projectile', 'Invisible3') } }
# the Allied AA gun (RAAGUN, ZSU-23 -> FlakWH) did nothing to Mutalisks (user test 2026-10-27): Mutalisk Armor=light,
# [light] BaseArmor=wood in Rules [ArmorTypes], and FlakWH has Modifier.wood=0%. Light flyers take what medium ones do
$ini.Set('FlakWH', 'Modifier.light', '770%')

# ================================================================ Zerg creep (mods/zerg-creep) in a campaign map
# The creep spreaders are Art.ini ActiveAnims of the Zerg buildings (global), but the rest of the creep block lives in
# the faction map code, which a campaign mission does not load (user test 2026-10-27: no creep). So: the animation
# list entries, vein growth on, buildable veins, and ImmuneToVeins=yes for every type (the veins damage whatever stands
# on them; the faction block does the same for 516 types)
$ini.Set('Basic', 'VeinGrowthEnabled', 'yes')
$ini.Set('General', 'VeinholeGrowthRate', '60')
$ini.Set('General', 'VeinholeShrinkRate', '8')      # creep of a dead nest recedes in ~a minute (Rules 100: ~10 min; 5 was 40% too fast)
foreach ($o in 'VEINS', 'VEINHOLEDUMMY') { $ini.Set($o, 'Insignificant', 'yes') }
# (the animations are defined in Art.ini only; a rules section with a name just keeps the list check honest)
$an = 0; foreach ($a in 'SCZCRSPL', 'SCZCRSHL', 'SCZCRSPS', 'SCZCRSHS') { $an++; $ini.Set('Animations', "ARKA4ZC0$an", $a); $ini.Set($a, 'Name', "Zerg creep $a") }
$nImm = 0
foreach ($ln in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') {
    $names = @(); if ($rules.ContainsKey($ln)) { $names += @($rules[$ln].Values) }; $names += @($ini.Section($ln) | ForEach-Object { $_.Value })
    foreach ($t in ($names | Sort-Object -Unique)) { if ($t -and $t -notmatch '^\d') { $ini.Set($t, 'ImmuneToVeins', 'yes'); $nImm++ } }
}
$log.Add("creep: vein growth on, 4 spreader animations, ImmuneToVeins on $nImm types")

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
foreach ($n in 10..62) { if (-not $wp.ContainsKey($n)) { throw "terrain map has no waypoint $n (contract 10-62 broken)" } }
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
# SC Marines, Firebats, SCVs and the Infested Terran are SHP *vehicles* in the mod, so they go to [Units]
function Is-Vehicle($type) { $listOf[$type] -eq 'VehicleTypes' -or $listOf[$type] -eq 'Rules:VehicleTypes' -or @($ini.Section('VehicleTypes') | Where-Object { $_.Value -eq $type }).Count }
function Squad($house, [string[]]$types, [int]$n, $dx = 0, $dy = 0, $mission = 'Guard', $hp = 256) {
    NewCell
    foreach ($t in $types) {
        if (Is-Vehicle $t) { Add-Unit $house $t ($wp[$n][0] + $dx) ($wp[$n][1] + $dy) $mission 'None' $hp }
        else { Add-Inf $house $t ($wp[$n][0] + $dx) ($wp[$n][1] + $dy) $mission 'None' $hp }
    }
}
function Copy-Type($dst, $src, $over) {
    $m = [ordered]@{}; foreach ($k in $scSec[$src].Keys) { $m[$k] = $scSec[$src][$k] }
    foreach ($k in 'Prerequisite', 'BuiltAt', 'BuildLimit', 'Naval', 'DeploysInto', 'UndeploysInto') { $m.Remove($k) }
    foreach ($k in $over.Keys) { if ($null -eq $over[$k]) { $m.Remove($k) } else { $m[$k] = $over[$k] } }
    $m['ImmuneToVeins'] = 'yes'
    foreach ($k in $m.Keys) { $ini.Set($dst, $k, "$($m[$k])") }
}

# ================================================================ mission types
# Tanya: 2500 HP in every ARKA mission (user 2026-10-28: first +50%, then 2500; Rules 1000)
$ini.Set('TANYA', 'Strength', "$([int]([int]$rules['TANYA']['Strength'] * 2.5))")
# ARKA: the Chronosphere RAPDOX overridden in this map (the core holds again since the jump); no superweapon, no power,
# indestructible: its loss is not part of this mission, and a calm mission needs no extra ways to lose
$fcache['RAPDOX'] = @(2, 2)
$arka = [ordered]@{
    Name = 'ARKA'; Strength = '20000'; Armor = 'heavy'; TechLevel = '-1'; Sight = '8'; Power = '0'; Powered = 'no'; Capturable = 'false'
    Crewed = 'no'; Unsellable = 'yes'; Repairable = 'no'; ClickRepairable = 'no'; SuperWeapon = 'none'; NukeSilo = 'no'; AIBuildThis = 'no'; Immune = 'yes'
}
foreach ($k in $arka.Keys) { $ini.Set('RAPDOX', $k, $arka[$k]) }
# Einstein's laboratory: the TD Bio Research Lab (BIO) overridden; Einstein works inside, so its loss = his death
$lab = [ordered]@{
    Name = 'Laboratorium Einsteina'; Strength = '4000'; Armor = 'concrete'; Owner = 'Allies'; TechLevel = '-1'; Power = '0'; Capturable = 'false'
    Insignificant = 'no'; RadarInvisible = 'no'; Unsellable = 'yes'; Sight = '6'; Repairable = 'yes'; ClickRepairable = 'yes'; Storage = '0'
}
foreach ($k in $lab.Keys) { $ini.Set('BIO', $k, $lab[$k]) }
# Jim Raynor on his Vulture (as in missions 1-2: Image=SCVULT, self-healing, Raynor's own SC voices); HP +20%, then
# +300% (user 2026-10-28, all ARKA missions: "szybko pada"), x4.8
$ray = [ordered]@{ Name = 'Jim Raynor (Vulture)'; Image = 'SCVULT'; Strength = [string][int]([int]$scSec['SCVULT']['Strength'] * 4.8); TechLevel = '-1'; Owner = 'Allies'
    SelfHealing = 'yes'; SelfHealingCap = '1.0'; SelfHealingStep = '5' }
foreach ($k in 'VoiceSelect', 'VoiceMove', 'VoiceAttack', 'VoiceFeedback', 'VoiceDie') { if ($scSec['SCRAYN'].Contains($k)) { $ray[$k] = $scSec['SCRAYN'][$k] } }
Copy-Type 'ARKRAYN' 'SCVULT' $ray
# Edmund Duke WITHOUT his siege tank (user 2026-10-27): a hero Marine with Raynor's hero-Marine health (SCRAYN, 4000)
# and 50% more damage than Raynor's gun (45 -> 68), the same stimpack, Duke's own SC voices (from SCHERO)
$dk = [ordered]@{ Name = 'Edmund Duke (Marine)'; Image = 'SCRAYN'; Primary = 'ARKDukeGun'; TechLevel = '-1'; Owner = 'GDI,Allies'; TransformsInto = 'ARKDUKES'
    SelfHealing = 'yes'; SelfHealingCap = '1.0'; SelfHealingStep = '5'; Cost = '0' }
foreach ($k in 'VoiceSelect', 'VoiceMove', 'VoiceAttack') { $dk[$k] = $scSec['SCHERO'][$k] }
Copy-Type 'ARKDUKE' 'SCRAYN' $dk
$dk['Name'] = 'Edmund Duke (Stimpack)'; $dk['Image'] = 'SCRAYNS'; $dk['Primary'] = 'ARKDukeGunS'; $dk['TransformsInto'] = 'ARKDUKE'
Copy-Type 'ARKDUKES' 'SCRAYNS' $dk
foreach ($w in @(@('ARKDukeGun', 'SCRaynGun'), @('ARKDukeGunS', 'SCRaynGunS'))) {
    foreach ($k in $scSec[$w[1]].Keys) { $ini.Set($w[0], $k, $scSec[$w[1]][$k]) }
    $ini.Set($w[0], 'Damage', [string][int][Math]::Round([int]$scSec[$w[1]]['Damage'] * 1.5))
}
# Norad II: the SC Battlecruiser picture lying on the ground (a vehicle with a ground locomotor and no guns that
# nobody orders around); the crew and Duke hold out round it
Copy-Type 'ARKNORAD' 'SCBCF' ([ordered]@{ Name = 'Norad II (wrak krazownika)'; Image = 'SCBCF'; Primary = $null; Secondary = $null; FlightLevel = $null
    Locomotor = '{4A582741-9839-11d1-B709-00A024DDAFD1}'; MovementZone = 'Normal'; SpeedType = 'Track'; Speed = '1'; ROT = '1'; Strength = '9000'
    TechLevel = '-1'; Owner = 'Soviet2'; Sight = '6'; Crusher = 'no'; Insignificant = 'no'; DamageParticleSystems = 'SparkSys,SmallGreySSys,BigGreySmokeSys' })
# the secret: a Zerg with a green crystal growing out of its carapace, a capturable and indestructible building of the
# Neutral house in the NE nest (as the ARKA wreck of mission 1: the engineer's capture springs its tag)
Copy-Type 'ARKZKRY' 'SCZCRP' ([ordered]@{ Name = 'Zerg z zielonym krysztalem'; Image = 'SCZCRP'; Owner = 'Neutral'; TechLevel = '-1'; Capturable = 'true'
    Immune = 'yes'; Primary = $null; SelfHealing = 'no' })
$nV = 0; foreach ($t in 'ARKRAYN', 'ARKDUKE', 'ARKDUKES', 'ARKNORAD') { $nV++; $ini.Set('VehicleTypes', "ARKA4V0$nV", $t) }
$ini.Set('BuildingTypes', 'ARKA4B01', 'ARKZKRY')

# crystal mines (user 2026-10-27): the terrain map puts OREMINE2 by every crystal field; here it seeds blue crystals
# ([Tiberiums] 6 = BlueGems) instead of ore. Blue crystals inherit Gems (Growth 10000, GrowthPercentage 0: they never
# grow), so the seeded ones would stay at stage 0; a slow growth makes the mines worth something
# (niezweryfikowane w grze: whether a map may override [BlueGems] and what stage a mine seeds)
$ini.Set('OREMINE2', 'Name', 'Kopalnia niebieskich krysztalow'); $ini.Set('OREMINE2', 'TiberiumToSpawn', '6')
$ini.Set('BlueGems', 'Growth', '3000'); $ini.Set('BlueGems', 'GrowthPercentage', '.05')

# tech of mission 4: the Allies up to tech level 6 with helicopters (from mission 3 on), no Chronosphere
# (RAPDOX is the ARKA here), no missile silo
foreach ($t in 'RAMSLO', 'DTRK') { $ini.Set($t, 'TechLevel', '-1') }

# Zerg AI that really builds the Zerg way (user 2026-10-27): the nests hatch Drones that walk to a spot on the creep and
# morph (Add-ZergBuilder in MissionKit.ps1, below). The Drones must be buildable by both nest houses at their
# Hatchery/Hive: Owner with both houses, a TechLevel they reach, no prerequisites (the faction's [PrerequisiteGroups]
# like ZHATCHERY do not exist in a campaign map)
$zDrones = 'SCZDCRP', 'SCZDSUN', 'SCZDSPO', 'SCZDEVO', 'SCZDHDN'
foreach ($t in $zDrones) {
    $ini.Set($t, 'TechLevel', '1'); $ini.Set($t, 'Owner', 'Nod1,Nod2')
    $s = $ini.Section($t); for ($i = $s.Count - 1; $i -ge 0; $i--) { if ($s[$i].Key -like 'Prerequisite*') { $s.RemoveAt($i) } }
}
# the centre nest hatches harassment squads (user 2026-10-28: Zerglings, Broodlings, Hydralisks): Zerglings and
# Hydralisks keep their Pool/Hydra Den prerequisites (the nest has both), the Broodling loses its Queen's Nest one
$ini.Set('SCZBRD', 'TechLevel', '1')
# both nests hatch them (the Hive wakes up when the centre nest falls, user 2026-10-28)
foreach ($t in 'SCZLNG', 'SCZHYL', 'SCZBRD') { $ini.Set($t, 'Owner', 'Nod1,Nod2') }
$s = $ini.Section('SCZBRD'); for ($i = $s.Count - 1; $i -ge 0; $i--) { if ($s[$i].Key -like 'Prerequisite*') { $s.RemoveAt($i) } }
# Raynor's Command Center arrives flying (SCCCF, jumpjet) and lands as SCCC, a construction yard: a second building site
# for the player's expansion (user 2026-10-28). Nobody builds one from the sidebar here
$ini.Set('SCCC', 'TechLevel', '-1')

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
$friends = 'Allies,GDI,Soviet,Soviet2'
# Neutral is a Zerg ally: the green-crystal Zerg of the secret is a Neutral, indestructible building, and the Zerg kept
# shooting it for ever (user test 2026-10-27: "Zergs attack some colony up north")
$zerg = 'Nod,Nod1,Nod2,Neutral'
House 'Allies'  'AlliesSide'   'AlliedBlue' $friends 30 2 'yes' 'South' 0 6   # player: 3000 credits, tech level 6
House 'GDI'     'GDISide'      'DarkRed'    $friends 0  0 'no'                 # Duke and the Norad II crew (Alpha Squadron)
House 'Soviet2' 'GDISide'      'DarkRed'    $friends 0  0 'no'                 # the hull of Norad II
House 'Soviet'  'GDISide'      'Gold'       $friends 0  3 'no'                 # Sons of Korhal (the evacuation Dropship)
# the two nests BUILD (IQ 5 = [IQ] Production; Add-ZergBuilder: Production Begins, then Drones for their credits)
House 'Nod1'    'NodSide'      'Purple'     $zerg 400 7 'no' 'West' 5          # Zerg: centre nest, colony field at Norad II, NE nest, raids (credits: Drones + harassment squads)
House 'Nod2'    'NodSide'      'Purple'     $zerg 250 7 'no' 'North' 5         # Zerg: the Hive in the north and its raids (credits: Drones + waves after the centre falls)
House 'Nod'     'NodSide'      'Purple'     $zerg 0 1 'no' 'North' 3           # Zerg: the last wave (all dead = victory)
House 'Neutral' 'CivilianSide' 'Grey'       'Neutral,Nod,Nod1,Nod2' 0 4 'no'
House 'Special' 'SpecialSide'  'Grey'       'Special' 0 5 'no'

# ================================================================ the Allied base by the ARKA (SW)
foreach ($n in 10, 12, 13, 14, 15, 16, 17, 18) { Reserve $wp[$n][0] $wp[$n][1] 2 }
Place-AtWp 'Allies' 'RAPDOX' 10 1 'None' 256
Place-AtWp 'Allies' 'BIO'    12 1 'ARKA4G01' 256
Place-AtWp 'Allies' 'AFACT'  13 1 'None' 256 1
Place-AtWp 'Allies' 'RATENT' 14 1 'None' 256 1
Place-AtWp 'Allies' 'AWEAP'  16 1 'None' 256 1
Place-AtWp 'Allies' 'RAPOWR' 17 0 'None' 256 1
Place-AtWp 'Allies' 'RAPOWR' 18 0 'None' 256 1
Place-AtWp 'Allies' 'RADOME' 18 1 'None' 256 1 4 3
# refinery by the home crystal field (thin on purpose), with its truck (a refinery placed in a map gets no free truck)
$gem = @(); for ($i = 0; $i -lt $ovl.Length; $i++) { if ($ovl[$i] -ge 27 -and $ovl[$i] -le 38) { $gx = $i % 512; $gy = [Math]::Floor($i / 512); if ([Math]::Abs($gx - $wp[15][0]) -le 16 -and [Math]::Abs($gy - $wp[15][1]) -le 16) { $gem += , @($gx, $gy) } } }
if ($gem.Count -eq 0) { throw "no crystal field near the base (wp 15)" }
$gcx = [int](($gem | ForEach-Object { $_[0] } | Measure-Object -Average).Average); $gcy = [int](($gem | ForEach-Object { $_[1] } | Measure-Object -Average).Average)
$f = Foundation 'RAPROC'; $s = Find-Spot ([int](($gcx + $wp[15][0]) / 2)) ([int](($gcy + $wp[15][1]) / 2)) $f[0] $f[1] 1 $true; Add-Building 'Allies' 'RAPROC' $s[0] $s[1] 'None' 1
Add-Unit 'Allies' 'RAHARV' $gcx $gcy 'Harvest'
$log.Add("home crystals: $($gem.Count) cells round $gcx,$gcy")
# SC Bunkers left by Raynor's Marines on the two ways into the base
foreach ($b in @(@(47, -3, 0), @(47, 3, 1), @(48, 0, -2), @(48, 1, 3))) {
    $s = Find-Spot ($wp[$b[0]][0] + $b[1]) ($wp[$b[0]][1] + $b[2]) 3 2 0 $true; Add-Building 'Allies' 'SCBUNK' $s[0] $s[1] 'None' 1
}

# where Duke has to get out by the laboratory: three free cells round it, waypoints 63-65 ("comes near waypoint")
$lb = @($structs | Where-Object { $_.Value -like 'Allies,BIO,*' })[0].Value -split ','; $lf = Foundation 'BIO'
$k = 63
foreach ($d in @(@(($lf[0] + 1), 1), @(1, ($lf[1] + 1)), @(-2, 0))) {
    $s = Find-Spot ([int]$lb[3] + $d[0]) ([int]$lb[4] + $d[1]) 1 1 0 $false; Occupy $s[0] $s[1] 1 1
    $wp[$k] = $s; $ini.Set('Waypoints', "$k", "$($s[1] * 1000 + $s[0])"); $log.Add("lab pad wp $k = $($s[0]),$($s[1])"); $k++
}

# ================================================================ player start force (wp 11), heroes, the second MCV (wp 19)
$p = $wp[11]
$crate = Find-Spot ($p[0] + 3) ($p[1] + 2) 1 1 0 $false; Occupy $crate[0] $crate[1] 1 1
foreach ($t in '2TNK', '2TNK', '1TNK', '1TNK', 'RANG') { Add-Unit 'Allies' $t ($p[0] + 2) ($p[1] - 2) 'Guard' }
Squad 'Allies' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE') 11 -2 -2
Add-Unit 'Allies' 'ARKRAYN' ($p[0] - 1) ($p[1] - 3) 'Guard' 'ARKA4G02'
NewCell; Add-Inf 'Allies' 'TANYA' ($wp[12][0] + 3) ($wp[12][1] + 2) 'Guard' 'ARKA4G03' 256 100
Squad 'Allies' @('E1', 'E1', 'E1') 11 1 2
Squad 'Allies' @('E3', 'E3', 'E3') 11 -1 3
Squad 'Allies' @('MEDIC', 'ENGINEER', 'ENGINEER') 11 3 1
Add-Unit 'Allies' 'AMCV' $wp[19][0] $wp[19][1] 'Guard'
# Raynor's flying Command Center (user 2026-10-28): wp 66 = where it stops by the second MCV (a free spot for the CC
# foundation, so it can land right there), wp 67 = where it comes from, the south edge of the map (last cell on the map
# going "down the screen" from the base, x - y fixed)
$f = Foundation 'SCCC'; $s = Find-Spot ($wp[19][0] + 3) ($wp[19][1] - 4) $f[0] $f[1] 1 $false; Occupy $s[0] $s[1] $f[0] $f[1]
$wp[66] = @(($s[0] + [Math]::Floor($f[0] / 2)), ($s[1] + [Math]::Floor($f[1] / 2)))
$d = $wp[19][0] - $wp[19][1] + 14; $edge = $null
for ($sum = $wp[19][0] + $wp[19][1]; $sum -lt 1000; $sum += 2) { $x = ($sum + $d) / 2; $y = ($sum - $d) / 2; if ($x -lt 0 -or $y -lt 0 -or $x -ge $GW -or $y -ge $GW -or $code[$y * $GW + $x] -lt 0) { break }; $edge = @($x, $y) }
if (-not $edge) { throw "no map edge south of wp 19" }
$wp[67] = $edge
foreach ($n in 66, 67) { $ini.Set('Waypoints', "$n", "$($wp[$n][1] * 1000 + $wp[$n][0])"); $log.Add("CC wp $n = $($wp[$n][0]),$($wp[$n][1])") }

# ================================================================ Norad II (SE basin): the hull, Duke, the crew, two bunkers
foreach ($n in 34, 35) { Reserve $wp[$n][0] $wp[$n][1] 1 }
Add-Unit 'Soviet2' 'ARKNORAD' $wp[34][0] $wp[34][1] 'Sleep' 'ARKA4G05' 200 0 96
Add-Unit 'GDI' 'ARKDUKE' $wp[35][0] $wp[35][1] 'Guard' 'ARKA4G04'
Squad 'GDI' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE') 35 1 1
Squad 'GDI' @('SCGOLI', 'SCGOLI') 35 3 -1
Place-AtWp 'GDI' 'SCBUNK' 36 0 'None' 180
Place-AtWp 'GDI' 'SCBUNK' 37 0 'None' 160
$smN = 0; $rnd = New-Object Random 2499
foreach ($i in 0..13) {
    $a = $rnd.NextDouble() * 6.283; $r = 2 + $rnd.NextDouble() * 5
    $sx = [int]($wp[34][0] + [Math]::Cos($a) * $r); $sy = [int]($wp[34][1] + [Math]::Sin($a) * $r)
    if (-not (Buildable $sx $sy)) { continue }
    $ini.Set('Smudge', "$smN", ('CR{0}{1},{2},{3},0' -f (1 + $rnd.Next(6)), [char](65 + $rnd.Next(5)), $sx, $sy)); $smN++
}
# the colony field round the basin (Nod1): sunken and spore colonies far enough (>= 18 cells) from the hull that
# nobody fights before the player comes, and Zerg packs on guard
foreach ($n in 52, 53, 54, 57, 58) { Place-AtWp 'Nod1' 'SCZSUN' $n 0 }
foreach ($n in 55, 56) { Place-AtWp 'Nod1' 'SCZSPO' $n 0 }
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL') 49 0 0 'Area Guard'
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL', 'SCZHYL') 50 0 0 'Area Guard'
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZINF', 'SCZINF') 51 0 0 'Area Guard'
# a denser siege round the basin (user 2026-10-28: more Sunken/Spore and Zerg round Norad II): a ring of colonies and
# packs 13-20 cells from the hull, every 30 degrees, Sunken and Spore in turn; nothing closer than 13 cells to the hull
# or to Duke, so the siege still waits for the player (Sunken GuardRange 8)
$ringN = 0; $packN = 0
$siege = @(@('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL'), @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG'),
    @('SCZHYL', 'SCZHYL', 'SCZHYL', 'SCZLNG', 'SCZLNG'), @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZINF', 'SCZINF', 'SCZHYL'), @('SCZULT', 'SCZLNG', 'SCZLNG', 'SCZLNG'))
function FarFromHull($x, $y, $r) { foreach ($n in 34, 35) { if (($x - $wp[$n][0]) * ($x - $wp[$n][0]) + ($y - $wp[$n][1]) * ($y - $wp[$n][1]) -lt $r * $r) { return $false } }; $true }
for ($deg = 0; $deg -lt 360; $deg += 30) {
    $rad = $deg * [Math]::PI / 180
    $type = if (($deg / 30) % 2) { 'SCZSPO' } else { 'SCZSUN' }
    $tx = [int]($wp[34][0] + [Math]::Cos($rad) * 16); $ty = [int]($wp[34][1] + [Math]::Sin($rad) * 16)
    if ($code[$ty * $GW + $tx] -lt 0) { continue }
    try { $s = Find-Spot $tx $ty 2 2 0 $true } catch { continue }
    if (-not (FarFromHull $s[0] $s[1] 13) -or (FarFromHull $s[0] $s[1] 21)) { continue }
    Add-Building 'Nod1' $type $s[0] $s[1]; $ringN++
    # a pack beside every second colony
    if ($deg % 60 -eq 0) {
        $pk = $siege[$packN % $siege.Count]; $packN++
        try { $q = Find-Spot ($s[0] + 3) ($s[1] + 1) 1 1 0 $true } catch { continue }
        if (FarFromHull $q[0] $q[1] 13) { NewCell; foreach ($t in $pk) { if (Is-Vehicle $t) { Add-Unit 'Nod1' $t $q[0] $q[1] 'Area Guard' } else { Add-Inf 'Nod1' $t $q[0] $q[1] 'Area Guard' } } }
    }
}
$log.Add("Norad II siege ring: $ringN colonies, $packN packs")
# more static defence (user 2026-10-28, screenshot of the basin's north rim): 3 colonies on the plateau NW of the basin
# (round cell 135,118). All 13+ cells from the hull and Duke, as the ring. (Two Sunkens at the north entrance, 156,113
# and 160,112, were removed again: "too close to Norad" on the render)
$extraN = 0
foreach ($c in @(@('SCZSUN', 132, 116), @('SCZSPO', 135, 119), @('SCZSUN', 137, 116))) {
    $s = Find-Spot $c[1] $c[2] 2 2 0 $true
    if (-not (FarFromHull $s[0] $s[1] 13)) { $log.Add("WARN extra $($c[0]) near $($c[1]),$($c[2]) too close to the hull, skipped"); continue }
    Add-Building 'Nod1' $c[0] $s[0] $s[1]; $extraN++
}
$log.Add("Norad II rim: $extraN extra colonies")
# and the open ground north of those colonies (user 2026-10-28, second screenshot, round cell 130,93): 2 Sunkens, a Spore
# and two packs on guard
foreach ($c in @(@('SCZSUN', 130, 97), @('SCZSPO', 129, 90), @('SCZSUN', 136, 91))) {
    $s = Find-Spot $c[1] $c[2] 2 2 0 $true; Add-Building 'Nod1' $c[0] $s[0] $s[1]; $extraN++
}
foreach ($pk in @(@(134, 96, @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL', 'SCZHYL')), @(124, 89, @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL')))) {
    NewCell; foreach ($t in $pk[2]) { if (Is-Vehicle $t) { Add-Unit 'Nod1' $t $pk[0] $pk[1] 'Area Guard' } else { Add-Inf 'Nod1' $t $pk[0] $pk[1] 'Area Guard' } }
}
$log.Add("north of the rim: 3 colonies, 2 packs (total extra colonies $extraN)")

# ================================================================ the centre nest (Nod1): the closest raids; its field is expansion 2
Place-AtWp 'Nod1' 'SCZHAT' 22 1 'ARKA4G06'
Place-AtWp 'Nod1' 'SCZPOL' 23 1
Place-AtWp 'Nod1' 'SCZHDN' 24 1
Place-AtWp 'Nod1' 'SCZEVO' 25 1
Place-AtWp 'Nod1' 'SCZSPI' 26 1
Place-AtWp 'Nod1' 'SCZSUN' 27 0
Place-AtWp 'Nod1' 'SCZSUN' 21 0 'None' 256 0 3 4
Place-AtWp 'Nod1' 'SCZSPO' 22 0 'None' 256 0 -4 3
Place-AtWp 'Nod1' 'SCZCRP' 22 0 'None' 256 0 4 -3
Place-AtWp 'Nod1' 'SCZCRP' 22 0 'None' 256 0 -6 0
Place-AtWp 'Nod1' 'SCZSUN' 60 0 'None' 256 0 2 -2
foreach ($t in 'SCZOVL', 'SCZOVL') { Add-Unit 'Nod1' $t ($wp[22][0] - 4) ($wp[22][1] - 3) 'Guard' }
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL', 'SCZHYL') 60 0 0 'Area Guard'
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') 21 2 2 'Area Guard'
# expansion 1 (NW): a light guard, one Sunken Colony
Place-AtWp 'Nod1' 'SCZSUN' 61 0
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG') 61 2 -3 'Area Guard'
# the NE nest at Stickler Woods (Nod1) with the green-crystal Zerg (Neutral, the secret)
Place-AtWp 'Neutral' 'ARKZKRY' 40 1 'ARKA4G08'
Place-AtWp 'Nod1' 'SCZSUN' 40 0 'None' 256 0 -3 4
Place-AtWp 'Nod1' 'SCZCRP' 40 0 'None' 256 0 3 2
Squad 'Nod1' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL') 40 -2 5 'Area Guard'

# ================================================================ the Hive in the north (Nod2): late raids, the richest field
Place-AtWp 'Nod2' 'SCZHIV' 28 1 'ARKA4G07'
Place-AtWp 'Nod2' 'SCZPOL' 29 1
Place-AtWp 'Nod2' 'SCZHDN' 30 1
Place-AtWp 'Nod2' 'SCZSPI' 31 1
Place-AtWp 'Nod2' 'SCZEVO' 28 1 'None' 256 0 6 4
foreach ($n in 32, 33) { Place-AtWp 'Nod2' 'SCZSUN' $n 0 }
Place-AtWp 'Nod2' 'SCZSPO' 41 0 'None' 256 0 -3 3
Place-AtWp 'Nod2' 'SCZSPO' 28 0 'None' 256 0 -5 -2
Place-AtWp 'Nod2' 'SCZCRP' 28 0 'None' 256 0 7 -1
Place-AtWp 'Nod2' 'SCZSUN' 62 0 'None' 256 0 3 3
Place-AtWp 'Nod2' 'SCZCRP' 30 0 'None' 256 0 -4 3
foreach ($t in 'SCZOVL', 'SCZOVL', 'SCZOVL') { Add-Unit 'Nod2' $t ($wp[28][0] + 3) ($wp[28][1] + 5) 'Guard' }
# the Hive's Extractor between its crystal field (wp 41) and the Hive: the drop-off of the one Drone that starts
# harvesting when the centre nest falls (a refinery placed in a map gets no FreeUnit)
$hg = @(); for ($i = 0; $i -lt $ovl.Length; $i++) { if ($ovl[$i] -ge 27 -and $ovl[$i] -le 38) { $gx = $i % 512; $gy = [Math]::Floor($i / 512); if ([Math]::Abs($gx - $wp[41][0]) -le 10 -and [Math]::Abs($gy - $wp[41][1]) -le 10) { $hg += , @($gx, $gy) } } }
if ($hg.Count -eq 0) { throw "no crystal field near the Hive field (wp 41)" }
$hgx = [int](($hg | ForEach-Object { $_[0] } | Measure-Object -Average).Average); $hgy = [int](($hg | ForEach-Object { $_[1] } | Measure-Object -Average).Average)
$f = Foundation 'SCZEXT'; $s = Find-Spot ([int](($hgx * 2 + $wp[28][0]) / 3)) ([int](($hgy * 2 + $wp[28][1]) / 3)) $f[0] $f[1] 0 $true; Add-Building 'Nod2' 'SCZEXT' $s[0] $s[1]
$log.Add("Hive crystals: $($hg.Count) cells round $hgx,$hgy; Extractor @ $($s[0]),$($s[1])")

# ================================================================ build plan: where the nests' Drones will morph (Add-ZergBuilder below)
# New buildings within ~8 cells of the Hatchery/Hive (its creep circle; patch-zergbuild.ps1 needs creep under every
# cell of a Zerg building), in the order they are built. Spots are reserved now (with a 1-cell margin from Find-Spot),
# so nothing else is placed there.
# Creep sources (mods/zerg-creep): the hole of a Hatchery/Hive sits on its foundation cell (1,1), of a Creep/Sunken/Spore
# Colony on (0,0), and the veins grow in a circle of radius ~8.5 (patch-veins.ps1 place 9). A spot is taken only if
# every cell of the building lies within 7.5 cells of a source: the Zerg buildings already in the map or a colony
# planned earlier (built earlier, so its creep is there in time). Among those, the spot nearest the wanted offset.
$creepSrc = New-Object Collections.Generic.List[object]
foreach ($kv in $structs) {
    $p = $kv.Value -split ','; if ($p[0] -notmatch '^Nod[12]$') { continue }
    if ($p[1] -in 'SCZHAT', 'SCZHIV') { $creepSrc.Add(@(([int]$p[3] + 1), ([int]$p[4] + 1))) } elseif ($p[1] -in 'SCZCRP', 'SCZSUN', 'SCZSPO') { $creepSrc.Add(@([int]$p[3], [int]$p[4])) }
}
function On-Creep($x, $y, $w, $h) {
    for ($i = $x; $i -lt $x + $w; $i++) { for ($j = $y; $j -lt $y + $h; $j++) {
        $ok = $false; foreach ($c in $creepSrc) { if (($i - $c[0]) * ($i - $c[0]) + ($j - $c[1]) * ($j - $c[1]) -le 56.25) { $ok = $true; break } }
        if (-not $ok) { return $false }
    } }
    $true
}
$nodes = @{ Nod1 = New-Object Collections.Generic.List[object]; Nod2 = New-Object Collections.Generic.List[object] }
function Plan-Node($house, $type, [int]$n, $dx, $dy) {
    $f = Foundation $type
    $tx = $wp[$n][0] + $dx - [Math]::Floor($f[0] / 2); $ty = $wp[$n][1] + $dy - [Math]::Floor($f[1] / 2)
    $best = $null; $bd = 1e9
    for ($x = $tx - 12; $x -le $tx + 12; $x++) { for ($y = $ty - 12; $y -le $ty + 12; $y++) {
        $d = ($x - $tx) * ($x - $tx) + ($y - $ty) * ($y - $ty); if ($d -ge $bd) { continue }
        if ((Free $x $y $f[0] $f[1] 1 $true) -and (On-Creep $x $y $f[0] $f[1])) { $bd = $d; $best = @($x, $y) }
    } }
    if (-not $best) { $log.Add("WARN no spot on creep for $house $type near wp $n $dx,$dy"); return }
    Occupy $best[0] $best[1] $f[0] $f[1]; $nodes[$house].Add(@($type, $best[0], $best[1]))
    if ($type -in 'SCZCRP', 'SCZSUN', 'SCZSPO') { $creepSrc.Add(@($best[0], $best[1])) }
}
foreach ($p in @(@('SCZCRP', 5, 3), @('SCZSUN', -5, 5), @('SCZSPO', 2, 6), @('SCZSUN', 6, -4), @('SCZCRP', -2, -6), @('SCZSPO', -6, -3), @('SCZEVO', 6, 6), @('SCZSUN', 0, 7))) {
    Plan-Node 'Nod1' $p[0] 22 $p[1] $p[2]
}
foreach ($p in @(@('SCZSUN', 5, 7), @('SCZSPO', -3, 7), @('SCZCRP', 8, 3), @('SCZSUN', -7, 4), @('SCZHDN', 4, -4), @('SCZSPO', 9, 6), @('SCZSUN', 0, 9), @('SCZCRP', -8, 0))) {
    Plan-Node 'Nod2' $p[0] 28 $p[1] $p[2]
}

Squad 'Nod2' @('SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZLNG', 'SCZHYL', 'SCZHYL', 'SCZHYL', 'SCZHYL') 62 0 0 'Area Guard'
Squad 'Nod2' @('SCZULT', 'SCZHYL', 'SCZHYL') 28 0 6 'Area Guard'
Squad 'Nod2' @('SCZHYL', 'SCZHYL', 'SCZLNG', 'SCZLNG') 41 0 3 'Area Guard'

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
Zone 'ARKA4G10' 34 0 9      # the Norad II basin: the player has arrived
Zone 'ARKA4G10' 38 0 4
Zone 'ARKA4G11' 39 0 5      # Stickler Woods: Stavros on the ore that grows back

# ================================================================ dialogue ([Tutorial] of the map, numbers 9401-9499)
$textNo = 9400
function Say([string]$s) { if ($s -match '[^\x20-\x7E]') { throw "non-ASCII text: $s" }; $script:textNo++; if ($script:textNo -gt 9499) { throw "text numbers above 9499" }; $ini.Set('Tutorial', "$script:textNo", $s); $script:textNo }

# ================================================================ taskforces, scripts, teams
$tfN = 0; $tmN = 0
function Team($name, $house, $spawnWp, [string[]]$members, [string[]]$script, $tag = $null) {
    $script:tfN++; $script:tmN++
    $tf = 'ARKA4F{0:D2}' -f $script:tfN; $sc = 'ARKA4S{0:D2}' -f $script:tfN; $tm = 'ARKA4M{0:D2}' -f $script:tmN
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
# script lines: 3,N move; 16,N patrol = attack-move; 11,14 hunt; 37 delete members. NOT 1,N for ground teams (they
# stop there for good, ARKA 0 test); 1,N only for flyers
$toLab = '16,12', '11,14'
$toNorad = '16,34', '11,14'
$air = '1,12', '11,14'
$L = 'SCZLNG'; $Hy = 'SCZHYL'
$tmRaidC1 = Team 'Najazd z centrum 1'   'Nod1' 60 @($L, $L, $L, $L, $L) $toLab
# repeating raids go for the economy (workflow/mission-design: 16 on a field, 0,3 = harvesters, then hunt)
$tmRaidC2 = Team 'Najazd z centrum na pole NW' 'Nod1' 60 @($L, $L, $L, $L, $L, $Hy, $Hy, $Hy) @('16,20', '0,3', '11,14')
$tmRaidW  = Team 'Fala od zachodu'      'Nod1' 42 @($L, $L, $L, $L, $L, $L, $Hy, $Hy) $toLab
$tmRaidE  = Team 'Fala od wschodu'      'Nod1' 48 @($L, $L, $L, $L, $Hy, $Hy) $toLab
$tmRaidH1 = Team 'Najazd z Hive 1'      'Nod2' 62 @($L, $L, $L, $L, $L, $L, $Hy, $Hy, $Hy, $Hy) $toLab
$tmRaidH2 = Team 'Najazd z Hive na Stickler' 'Nod2' 62 @($L, $L, $L, $L, $L, $L, $Hy, $Hy, $Hy, $Hy, 'SCZULT') @('16,39', '0,3', '11,14')
$tmRaidWE = Team 'Rajd na zbieracze od zachodu' 'Nod1' 42 @($L, $L, $L, $L, $Hy, $Hy) @('16,15', '0,3', '11,14')
$tmMutaH  = Team 'Mutaliski z Hive'     'Nod2' 59 @('SCZMUT', 'SCZMUT', 'SCZMUT') $air
# the hold at Norad II (3:00)
$tmN1     = Team 'Norad II: fala 1'     'Nod1' 50 @($L, $L, $L, $L, $L, $L, $L, $L) $toNorad
$tmN2     = Team 'Norad II: fala 2'     'Nod1' 44 @($L, $L, $L, $L, $L, $L, $Hy, $Hy, $Hy) $toNorad
$tmN3     = Team 'Norad II: fala 3'     'Nod1' 45 @($L, $L, $L, $L, $L, $L, 'SCZINF', 'SCZINF', 'SCZINF') $toNorad
$tmN4     = Team 'Norad II: fala 4 (trudny)' 'Nod1' 49 @($Hy, $Hy, $Hy, $Hy, $L, $L, $L, $L) $toNorad
# the Sons of Korhal Dropship takes the crew away (flies to the ARKA and is gone)
$tmEvac   = Team 'Dropship ewakuacja'   'Soviet' 35 @('SCDROP') @('3,10', '37,0')
# ...and leaves one for the player: Duke boards it and the player flies him to the laboratory (user 2026-10-27)
$tmDukeDrop = Team 'Dropship dla Duke''a' 'Allies' 35 @('SCDROP') @('11,5')
# Mengsk's reward for the centre nest: a squad of the Sons of Korhal for the player
$tmSoK    = Team 'Synowie Korhalu'      'Allies' 11 @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCGOLI', 'SCGOLI') @('11,5')
# harassment from the centre nest (user 2026-10-28): squads PRODUCED by the nest ("4 Create Team": the Spawning Pool
# hatches them for Nod1's credits, as the Drones of Add-ZergBuilder), fast ones on the harvesters, the others on the base
$Br = 'SCZBRD'
$tmHarA = Team 'Nekanie z centrum: zbieracze' 'Nod1' 22 @($L, $L, $L, $L, $Br, $Br, $Br, $Br) @('16,15', '0,3', '11,14')
$tmHarB = Team 'Nekanie z centrum: baza' 'Nod1' 22 @($L, $L, $L, $L, $Br, $Br, $Hy, $Hy, $Hy) @('16,47', '11,14')
# the centre nest also hatches small squads that go to Norad II (user 2026-10-28): they join the siege north of the basin
# (wp 50) and stand guard there, so they fight once the player comes, not before (Duke must not fall without the player)
$tmHarC = Team 'Z centrum pod Norad II' 'Nod1' 22 @($L, $L, $L, $Br, $Br, $Br) @('3,50', '11,10')
# the Hive after the centre nest falls (user 2026-10-28): one Drone harvests the Hive field for its Extractor, and the
# Hive hatches waves, mostly Zerglings and Broodlings with a few Hydralisks: the Stickler Woods expansion first, then
# the main base
$tmUpDrone = Team 'Hive: dron na krysztaly' 'Nod2' 28 @('SCZWORK') @('11,9')
$tmUpA = Team 'Hive: fala na Stickler (zerglingi)' 'Nod2' 28 @($L, $L, $L, $L, $L, $L, $Br, $Br, $Br, $Br) @('16,39', '16,12', '11,14')
$tmUpB = Team 'Hive: fala na Stickler (z hydrami)' 'Nod2' 28 @($L, $L, $L, $L, $Br, $Br, $Br, $Hy, $Hy) @('16,39', '16,12', '11,14')
# Raynor's Command Center flies in from the south edge and stops by the second MCV; it is the player's (team house)
$tmCC = Team 'Centrum Dowodzenia Raynora' 'Allies' 67 @('SCCCF') @('1,66')
# the last wave (house Nod: all dead = victory)
$tmF1     = Team 'Ostatnia fala: mutaliski' 'Nod' 59 @('SCZMUT', 'SCZMUT', 'SCZMUT', 'SCZMUT', 'SCZMUT', 'SCZMUT') $air
$tmF2     = Team 'Ostatnia fala: guardiany' 'Nod' 59 @('SCZGRD', 'SCZGRD', 'SCZGRD') $air
$tmF3     = Team 'Ostatnia fala: roj z polnocy' 'Nod' 62 @($L, $L, $L, $L, $L, $L, $L, $L, $Hy, $Hy, $Hy, $Hy) $toLab
$tmF4     = Team 'Ostatnia fala: od zachodu' 'Nod' 42 @($L, $L, $L, $L, $L, $L, 'SCZULT') $toLab
$tmF5     = Team 'Ostatnia fala: dodatkowa (trudny)' 'Nod' 59 @('SCZMUT', 'SCZMUT', 'SCZMUT', 'SCZGRD') $air

# ================================================================ triggers
$vars = 'Analiza gotowa', 'Duke uratowany', 'Gniazdo w centrum zniszczone', 'Hive zniszczony', 'Gracz przy Norad II', 'Ostatnia fala',
    'Sekret', 'Cel 2 aktywny', 'Ewakuacja Norad II'
for ($i = 0; $i -lt $vars.Count; $i++) { $ini.Set('VariableNames', "$i", "$($vars[$i]),0") }
$trN = 0; $trig = [ordered]@{}
function Ev([int]$id, $p = 0) { "$id,0,$p" }
function Act([int]$id, $p = 0, [int]$kind = 0, [int]$w = 0) { "$id,$kind,$p,0,0,0,0,$(WpLetter $w)" }
function Text($s) { Act 11 (Say $s) }
function Reinf($team, $w) { Act 80 $team 1 $w }
function Enable($t) { Act 53 $t 2 }
function Disable($t) { Act 54 $t 2 }
# -link: the second field of [Triggers] (pitfall 13 in engine/triggers-and-dialogue): one object tag (repeating) drives
# a chain of triggers, as DTA's cra12 does; used for Duke ("near the laboratory" -> ... -> "Duke died")
function Trigger($key, $name, [string[]]$events, [string[]]$actions, $house = 'Allies', [switch]$Disabled, [switch]$Repeat, $tag = $null, $diff = '1,1,1', $link = $null) {
    $script:trN++; $id = 'ARKA4T{0:D2}' -f $script:trN
    $name = $name -replace ',', ' -'
    if (-not $tag) { $tag = 'ARKA4G{0:D2}' -f (30 + $script:trN) }
    $script:trig[$key] = @{ Id = $id; Name = $name; House = $house; Events = $events; Actions = $actions; Disabled = [bool]$Disabled; Repeat = [bool]$Repeat; Tag = $tag; Diff = $diff; Link = $link }
}
. "$tools\MissionKit.ps1"   # reveal crate, one text per trigger, dialogue gaps from text length, timeline check
Add-ScAirArmor             # SC flyer armors: Allied AA fires at SC flyers only on order, Dragoons cannot hit the Overlord
Add-RevealCrate $crate[0] $crate[1]
# loot worth leaving the base for (workflow/mission-design): the Norad II wreck, the centre plain, Stickler Woods, the NW field
foreach ($mc in @(@(34, 5, 3, 3000, 'Szczatki Norad II: zapasy Konfederacji. +3000 kredytow.'), @(46, 0, 0, 2000, 'Porzucony konwoj winiarzy z Antigi: +2000 kredytow.'),
        @(39, 6, 4, 2500, 'Obozowisko drwali w lasach Stickler: +2500 kredytow.'), @(20, -4, 3, 1500, 'Skrytka powstancow z Andasar: +1500 kredytow.'))) {
    $s = Find-Spot ($wp[$mc[0]][0] + $mc[1]) ($wp[$mc[0]][1] + $mc[2]) 1 1 0 $false; Occupy $s[0] $s[1] 1 1
    Add-MoneyCrate $s[0] $s[1] $mc[3] $mc[4]
}

# --- opening: the laboratory, the alarm, the objective, the economy
Trigger 'intro' 'Start: laboratorium' @((Ev 13 1)) @((Act 48 1 0 12),
    (Text 'Einstein: Laboratorium gotowe, Komandorze. Odlamek z rdzenia lezy na stole od tygodnia i nie urosl ani o wlos.'), (Enable 'intro2'))
Trigger 'intro2' 'Start 2: alarm' @((Ev 13 5)) @((Act 55 4 0 12),
    (Text 'Plk Stavros: Profesorze, radar! Zergi ruszaja ze wszystkich stron. Ida prosto na nasz namiot.'), (Enable 'intro3')) -Disabled
Trigger 'intro3' 'Start 3: Einstein' @((Ev 13 5)) @((Text 'Einstein: One nie ida na nas. Ida na probke. One ja czuja.'), (Enable 'intro4')) -Disabled
Trigger 'intro4' 'Start 4: analiza' @((Ev 13 5)) @((Text 'Einstein: Potrzebuje okolo dwudziestu minut. Prosze nie wpuscic ich do laboratorium.'), (Enable 'intro5')) -Disabled
Trigger 'intro5' 'Start 5: cel 1' @((Ev 13 5)) @((Act 55 2 0 12),
    (Text 'Cel 1: bron laboratorium Einsteina, az skonczy analize (ok. 20 minut, Einstein bedzie meldowal postepy).'), (Enable 'intro6')) -Disabled
Trigger 'intro6' 'Start 6: straty' @((Ev 13 5)) @((Text 'Laboratorium (z Einsteinem w srodku), Tanya i Raynor musza przetrwac.'), (Enable 'intro7')) -Disabled
Trigger 'intro7' 'Start 7: krysztaly' @((Ev 13 5)) @((Act 55 6 0 20),
    (Text 'Plk Stavros: Pole krysztalow przy bazie jest ubogie. Bogatsze leza na polnocnym zachodzie i w centrum, przy gniezdzie.'), (Enable 'intro8')) -Disabled
Trigger 'intro8' 'Start 8: MCV' @((Ev 13 5)) @((Text 'Plk Stavros: Mamy drugie MCV. Rozstawcie je przy nowym polu, zanim skonczy sie nam gotowka.'), (Enable 'cc1')) -Disabled
# a few minutes in (user 2026-10-28): Raynor's flying Command Center comes to help the expansion; Mengsk follows it
Trigger 'cc1' 'Centrum Dowodzenia Raynora' @((Ev 13 30)) @((Reinf $tmCC 67), (Act 55 4 0 66),
    (Text 'Jim Raynor: Komandorze, moi chlopcy przyprowadzili wam latajace Centrum Dowodzenia. Posadzcie je przy nowym polu i budujcie tam dalej.'), (Enable 'cc2')) -Disabled
Trigger 'cc2' 'Centrum Dowodzenia: jak' @((Ev 13 5)) @((Text 'Centrum Dowodzenia: zaznacz je, przelec nad wolne miejsce i rozstaw (D). Dziala jak drugi plac budowy.'), (Enable 'mengsk1')) -Disabled

# --- objective 2 from Mengsk: Norad II (no hurry: Duke has dug in)
Trigger 'mengsk1' 'Mengsk: Norad II' @((Ev 13 60)) @((Act 17 34), (Act 55 6 0 34),
    (Text 'Mengsk (ekran): Mam dla was jeszcze jedno zadanie. Okret flagowy Konfederacji, Norad II, rozbil sie dwadziescia kilometrow od was.'), (Enable 'mengsk2')) -Disabled
Trigger 'mengsk2' 'Mengsk 2' @((Ev 13 5)) @((Text 'Mengsk (ekran): Na pokladzie jest general Duke. Uratujcie go.'), (Enable 'mengsk3')) -Disabled
Trigger 'mengsk3' 'Mengsk 3: Raynor' @((Ev 13 5)) @((Text 'Jim Raynor: Duke? Ten, ktory chcial nas aresztowac?'), (Enable 'mengsk4')) -Disabled
Trigger 'mengsk4' 'Mengsk 4' @((Ev 13 5)) @((Text 'Mengsk (ekran): Ten, ktory zna wszystkie kody Konfederacji.'), (Enable 'mengsk5')) -Disabled
Trigger 'mengsk5' 'Mengsk 5: cel 2' @((Ev 13 5)) @((Act 56 7),
    (Text 'Cel 2: dotrzyj do Norad II (niecka na poludniowym wschodzie) i trzymaj tam pozycje, az zaloga sie ewakuuje.'), (Enable 'mengsk6')) -Disabled
Trigger 'mengsk6' 'Mengsk 6: Duke' @((Ev 13 5)) @((Text 'Edmund Duke (radio): Okopalismy sie przy kadlubie. Wytrzymamy. Ale nie przyslijcie mi znowu muzeum, Mengsk.'), (Enable 'mengsk7')) -Disabled
Trigger 'mengsk7' 'Mengsk 7: Stickler' @((Ev 13 5)) @((Act 55 6 0 39),
    (Text 'Plk Stavros: Miejscowi mowia o lasach Stickler na polnocnym wschodzie. Krysztaly tam odrastaja. Gniazdo pilnuje ich jak skarbu.')) -Disabled

# --- losing
Trigger 'labLost' 'Laboratorium zniszczone' @((Ev 29)) @((Text 'Plk Stavros: Laboratorium zniszczone... Einstein byl w srodku. Bez niego nikt z nas nie wroci do domu.'), (Act 2 $H.Allies)) -tag 'ARKA4G01'
Trigger 'rayLost' 'Raynor zginal' @((Ev 29)) @((Text 'Plk Stavros: Marszalek Raynor zginal. Bez niego nie mamy tu przyjaciol.'), (Act 2 $H.Allies)) -tag 'ARKA4G02'
Trigger 'tanLost' 'Tanya zginela' @((Ev 29)) @((Text 'Plk Stavros: Tanya nie zyje. Tracimy najlepszego zolnierza, jakiego mielismy.'), (Act 2 $H.Allies)) -tag 'ARKA4G03'
# Duke's tag (repeating) drives a chain: near one of the three pads by the laboratory -> "home"; destroyed -> lost
$dukeAtLab = @((Disable 'dukeHome1'), (Disable 'dukeHome2'), (Disable 'dukeHome3'), (Disable 'dukeHomeT'), (Act 56 1), (Act 48 1 0 12), (Enable 'duke2'))
Trigger 'dukeHome1' 'Duke przy laboratorium (E)' @((Ev 34 63)) $dukeAtLab -tag 'ARKA4G04' -Repeat -link 'dukeHome2'
Trigger 'dukeHome2' 'Duke przy laboratorium (S)' @((Ev 34 64)) $dukeAtLab -link 'dukeHome3'
Trigger 'dukeHome3' 'Duke przy laboratorium (W)' @((Ev 34 65)) $dukeAtLab -link 'dukeLost'
Trigger 'dukeLost' 'Duke zginal' @((Ev 29)) @((Text 'Mengsk (radio): General Duke nie zyje, a z nim wszystkie kody Konfederacji. Zawiedliscie mnie.'), (Act 2 $H.Allies)) -house 'GDI'
Trigger 'noradLost' 'Norad II zniszczony' @((Ev 29)) @((Text 'Edmund Duke (radio): Kadlub poszedl! Zaloga... nikt nie wyszedl.'), (Act 2 $H.Allies)) -tag 'ARKA4G05' -house 'Soviet2'
Trigger 'allLost' 'Wszystko stracone' @((Ev 11 $H.Allies)) @((Act 2 $H.Allies))

# --- Einstein's silent progress (no timer on screen, user 2026-10-27: the 20 minutes must not annoy the player)
$a = $AnalysisSecs
Trigger 'ana50' 'Analiza: polowa' @((Ev 13 ([int]($a / 2)))) @((Text 'Einstein (laboratorium): Polowa analizy. Sam odlamek spi, ale pyl z pekniecia wsypany do grudki ziemi... on rosnie.'))
Trigger 'ana75' 'Analiza: trzy czwarte' @((Ev 13 ([int]($a * 3 / 4)))) @((Text 'Einstein (laboratorium): Trzy czwarte. Krzemiany, zelazo, miedz, nikiel, cynk. I pierwiastki, ktorych nie ma w zadnej mojej tabeli.'))
Trigger 'anaDone' 'Analiza gotowa' @((Ev 13 $a)) @((Act 56 0), (Act 48 1 0 12),
    (Text 'Einstein: Analiza skonczona! Pyl wysysa metale z gruntu i odklada je w sobie, jak gabka.'), (Enable 'ana1'))
Trigger 'ana1' 'Analiza 1' @((Ev 13 5)) @((Text 'Plk Stavros: Czyli to ruda?'), (Enable 'ana2')) -Disabled
Trigger 'ana2' 'Analiza 2' @((Ev 13 5)) @((Text 'Einstein: Ruda nie truje zolnierzy, ktorzy ja niosa. Dla nas to trucizna. Dla tych stworzen to pokarm.'), (Enable 'ana3')) -Disabled
Trigger 'ana3' 'Analiza 3' @((Ev 13 5)) @((Text 'Plk Stavros: Skoro pyl rosnie, czemu caly odlamek nie? Czemu nie zarosl nam rdzenia?'), (Enable 'ana4')) -Disabled
Trigger 'ana4' 'Analiza 4' @((Ev 13 5)) @((Text 'Einstein: Bo ktos go wydestylowal. Sprasowal tak gesto, ze nie ma w nim miejsca na wzrost. To bateria, nie nasiono.'), (Enable 'ana5')) -Disabled
Trigger 'ana5' 'Analiza 5' @((Ev 13 5)) @((Text 'Einstein: Dlatego moc rdzenia skoczyla o cztery tysiace procent.'), (Enable 'ana6')) -Disabled
Trigger 'ana6' 'Analiza 6' @((Ev 13 5)) @((Text 'Tanya: Czyli dopoki jest w jednym kawalku, spi.'), (Enable 'ana7')) -Disabled
Trigger 'ana7' 'Analiza 7' @((Ev 13 5)) @((Text 'Einstein: Dopoki jest w jednym kawalku i nikt nie sypie go do ziemi.'), (Enable 'ana8')) -Disabled
Trigger 'ana8' 'Analiza 8' @((Ev 13 5)) @((Text 'Tanya: Czyli spiacy zielony szajs.'), (Enable 'ana9')) -Disabled
Trigger 'ana9' 'Analiza 9' @((Ev 13 5)) @((Text 'Einstein: W raporcie napisze: Krysztal X. Ale tak, panno Adams. Zielony szajs.'), (Enable 'ana10')) -Disabled
Trigger 'ana10' 'Analiza 10: cel 1' @((Ev 13 5)) @((Text 'Cel 1 wykonany: analiza gotowa. Laboratorium wciaz musi przetrwac.'), (Enable 'anaWait')) -Disabled
Trigger 'anaWait' 'Analiza: czekamy na Duke''a' @((Ev 13 5), (Ev 37 1)) @((Text 'Einstein: Probka wciaz spiewa, a one wciaz slysza. Sprowadzcie Duke''a, zanim zlecie sie tu caly roj.')) -Disabled

# --- Norad II: the player in the basin + objective 2 on -> hold 3:00 (visible timer: a short, clear goal)
Trigger 'noradNear' 'Gracz przy Norad II' @((Ev 1 $H.Allies)) @((Act 56 4)) -tag 'ARKA4G10'
Trigger 'hold' 'Norad II: obrona' @((Ev 36 4), (Ev 36 7)) @((Act 56 8), (Act 27 180), (Act 23), (Act 48 1 0 34), (Act 55 4 0 34),
    (Text 'Edmund Duke: No prosze. Muzealnicy.'), (Enable 'holdEnd'), (Enable 'hN1'), (Enable 'hN2'), (Enable 'hN3'), (Enable 'hN4'), (Enable 'hold2'))
Trigger 'hold2' 'Norad II: obrona 2' @((Ev 13 5)) @((Text 'Edmund Duke: Zaloga potrzebuje trzech minut, zeby dobiec do dropshipa Mengska. Trzymajcie Zergi z dala od kadluba.'), (Enable 'hold3')) -Disabled
Trigger 'hold3' 'Norad II: obrona 3' @((Ev 13 5)) @((Text 'Cel 2: trzymaj pozycje przy Norad II przez 3 minuty. Kadlub i Duke musza przetrwac.')) -Disabled
Trigger 'hN1' 'Norad II: fala 1' @((Ev 13 15)) @((Reinf $tmN1 50), (Act 55 3 0 50)) -Disabled
Trigger 'hN2' 'Norad II: fala 2' @((Ev 13 70)) @((Reinf $tmN2 44), (Act 55 3 0 44)) -Disabled
Trigger 'hN3' 'Norad II: fala 3' @((Ev 13 120)) @((Reinf $tmN3 45), (Act 55 3 0 45)) -Disabled
Trigger 'hN4' 'Norad II: fala 4 (trudny)' @((Ev 13 90), (Ev 27 12)) @((Reinf $tmN4 49), (Act 55 3 0 49)) -Disabled
# timer zero: the crew is away, Duke and his men join the player. Pitfall 6 (engine/triggers-and-dialogue): a house
# change springs "destroyed" on the tags, so the loss triggers go off first and Duke's comes back 8 s later
# timer zero: the crew flies off with Mengsk's Dropship, Duke and his men join the player, and a second Dropship is the
# player's: Duke boards it and the player flies him to the laboratory (user 2026-10-27); the story goes on when Duke
# gets out by the laboratory. Pitfall 6: a house change springs "destroyed" on the tags, so Duke's loss trigger is off
# for 8 s round it
Trigger 'holdEnd' 'Norad II: ewakuacja' @((Ev 14)) @((Disable 'dukeLost'), (Disable 'noradLost'), (Act 24),
    (Reinf $tmEvac 35), (Reinf $tmDukeDrop 35), (Text 'Edmund Duke: Zaloga na pokladzie. ...Dziekuje. Nie przyzwyczajajcie sie.'),
    (Enable 'dukeJoin'), (Enable 'dukeArm'), (Enable 'drop2'), (Enable 'dukeHomeT')) -Disabled
Trigger 'dukeJoin' 'Duke dolacza' @((Ev 13 2)) @((Act 36 $H.Allies)) -house 'GDI' -Disabled
Trigger 'dukeArm' 'Duke: porazka znow wlaczona' @((Ev 13 8)) @((Enable 'dukeLost')) -Disabled
Trigger 'drop2' 'Dropship dla Duke''a' @((Ev 13 5)) @((Act 48 1 0 35),
    (Text 'Edmund Duke: Mengsk zostawil wam drugi dropship. Zabierzcie mnie do laboratorium, chce zobaczyc te wasza probke.'), (Enable 'drop3')) -Disabled
Trigger 'drop3' 'Dropship: cel' @((Ev 13 5)) @((Act 55 2 0 63), (Act 55 2 0 35),
    (Text 'Cel 2: zatrzymaj Dropship przy Duke''u, zaladuj go i wysadz przy laboratorium Einsteina. Jego oddzial jest teraz wasz.')) -Disabled
# no soft lock if Duke never gets out by the laboratory (the pads or event 34 fail): he walks in on his own later
Trigger 'dukeHomeT' 'Duke dociera sam' @((Ev 13 1500), (Ev 37 1)) (@($dukeAtLab | Where-Object { $_ -notmatch '^53,' }) + @(
    (Text 'Plk Stavros: Duke dotarl do laboratorium na wlasnych nogach. Upierdliwy jak zawsze.'), (Enable 'duke2'))) -Disabled
Trigger 'duke2' 'Duke 2: probka' @((Ev 13 3)) @((Text 'Edmund Duke: Wiec to jest ta wasza probka. Wyglada jak tani szmaragd.'), (Enable 'duke3')) -Disabled
Trigger 'duke3' 'Duke 3: Einstein' @((Ev 13 5)) @((Text 'Einstein: Ten tani szmaragd, generale, wlasnie przyciaga do nas pol planety.'), (Enable 'duke4')) -Disabled
Trigger 'duke4' 'Duke 4: Raynor' @((Ev 13 5)) @((Text 'Jim Raynor: Duke w naszej bazie. Swiat sie konczy.'), (Enable 'duke5')) -Disabled
Trigger 'duke5' 'Duke 5: cel 2' @((Ev 13 5)) @((Text 'Cel 2 wykonany: Duke jest w bazie. Duke musi przetrwac.')) -Disabled

# --- raids on the laboratory: modest and spaced (a calm mission); each nest's raids stop with its Hatchery/Hive
Trigger 'w1' 'Najazd 1 (centrum)' @((Ev 13 560), (Ev 37 2)) @((Reinf $tmRaidC1 60), (Act 55 3 0 60), (Text 'EVA: Zergi nadciagaja z centrum.'))
Trigger 'w2' 'Fala od zachodu' @((Ev 13 760)) @((Reinf $tmRaidW 42), (Act 55 3 0 42), (Text 'EVA: Wrog od zachodu.'))
Trigger 'wC' 'Najazd z centrum (powtarzany)' @((Ev 13 600), (Ev 37 2)) @((Reinf $tmRaidC2 60), (Act 55 3 0 60)) -Repeat -Disabled
Trigger 'wCon' 'Najazdy z centrum wlaczone' @((Ev 13 900)) @((Enable 'wC'))
Trigger 'wE' 'Fala od wschodu' @((Ev 13 1150)) @((Reinf $tmRaidE 48), (Act 55 3 0 48), (Text 'EVA: Wrog od wschodu.'))
Trigger 'wH1' 'Najazd z Hive 1' @((Ev 13 1050), (Ev 37 3)) @((Reinf $tmRaidH1 62), (Act 55 3 0 62), (Text 'EVA: Wrog nadciaga z polnocy.'))
Trigger 'wH' 'Najazd z Hive (powtarzany)' @((Ev 13 720), (Ev 37 3)) @((Reinf $tmRaidH2 62), (Act 55 3 0 62)) -Repeat -Disabled
Trigger 'wHon' 'Najazdy z Hive wlaczone' @((Ev 13 1500)) @((Enable 'wH'))
Trigger 'muta' 'Mutaliski z Hive' @((Ev 13 1560), (Ev 37 3)) @((Reinf $tmMutaH 59), (Act 55 3 0 59), (Text 'Tanya: Latajace! Rakiety w gore!'))
Trigger 'wW' 'Rajd na zbieracze (powtarzany)' @((Ev 13 540)) @((Reinf $tmRaidWE 42), (Act 55 3 0 42)) -Repeat -Disabled
Trigger 'wWon' 'Rajdy na zbieracze wlaczone' @((Ev 13 1300)) @((Enable 'wW'))
# harassment produced by the centre nest: squad A from ~360+240 s, squad B from ~480+240 s, each every 240 s, while the
# nest stands (local 2 clear) and until the last wave (local 5 clear)
Trigger 'harA' 'Nekanie z centrum: zbieracze' @((Ev 13 240), (Ev 37 2), (Ev 37 5)) @((Act 4 $tmHarA 1)) -house 'Nod1' -Repeat -Disabled
Trigger 'harB' 'Nekanie z centrum: baza' @((Ev 13 240), (Ev 37 2), (Ev 37 5)) @((Act 4 $tmHarB 1)) -house 'Nod1' -Repeat -Disabled
Trigger 'harAon' 'Nekanie z centrum: start A' @((Ev 13 360)) @((Enable 'harA')) -house 'Nod1'
Trigger 'harBon' 'Nekanie z centrum: start B' @((Ev 13 480)) @((Enable 'harB')) -house 'Nod1'
# squads from the centre to the siege of Norad II: from ~420+300 s, every 300 s, while the nest stands
Trigger 'harC' 'Z centrum pod Norad II' @((Ev 13 300), (Ev 37 2), (Ev 37 5)) @((Act 4 $tmHarC 1)) -house 'Nod1' -Repeat -Disabled
Trigger 'harCon' 'Z centrum pod Norad II: start' @((Ev 13 420)) @((Enable 'harC')) -house 'Nod1'
Trigger 'wHard' 'Fala dodatkowa (trudny)' @((Ev 13 880), (Ev 27 12)) @((Reinf $tmRaidW 42), (Reinf $tmRaidC1 60))

# --- the nests: optional objectives with rewards
Trigger 'nestC' 'Gniazdo w centrum zniszczone' @((Ev 29)) @((Act 56 2), (Disable 'wC'),
    (Text 'Plk Stavros: Wylegarnia w centrum plonie! Najazdy z tamtej strony ustana, a pole krysztalow jest wolne.'), (Enable 'sok')) -house 'Nod1' -tag 'ARKA4G06'
Trigger 'sok' 'Synowie Korhalu w nagrode' @((Ev 13 5)) @((Reinf $tmSoK 11), (Act 55 2 0 11),
    (Text 'Mengsk (radio): Imponujace. Przysylam wam oddzial Synow Korhalu. Traktujcie ich dobrze.'), (Enable 'sok2')) -Disabled
# Antiga Prime lore (StarCraft wiki, given by the user 2026-10-27): in 2478 the Confederacy wiped out Andasar City
Trigger 'sok2' 'Synowie Korhalu 2: Andasar' @((Ev 13 5)) @((Text 'Sierzant Synow Korhalu: Moj ojciec byl z Andasar. W 78 Konfederacja wyrznela tam cale miasto. Chetnie postrzelamy.'), (Enable 'upWake')) -Disabled
# the Hive wakes up when the centre nest falls (user 2026-10-28): a Drone on its crystals, then waves every 150 s
# (A and B in turn, 75 s apart) on Stickler Woods and on to the base, while the Hive stands (local 3) and until the
# last wave (local 5)
Trigger 'upWake' 'Hive sie budzi' @((Ev 13 20), (Ev 37 3)) @((Reinf $tmUpDrone 28), (Enable 'upA'), (Enable 'upBon'), (Act 55 3 0 39),
    (Text 'Plk Stavros: Hive na polnocy sie ruszyl. Wysyla drony po krysztaly i wykluwa nowe fale. Pierwsze pojda na lasy Stickler.')) -Disabled
Trigger 'upA' 'Hive: fala A' @((Ev 13 150), (Ev 37 3), (Ev 37 5)) @((Act 4 $tmUpA 1)) -house 'Nod2' -Repeat -Disabled
Trigger 'upB' 'Hive: fala B' @((Ev 13 150), (Ev 37 3), (Ev 37 5)) @((Act 4 $tmUpB 1)) -house 'Nod2' -Repeat -Disabled
Trigger 'upBon' 'Hive: fala B start' @((Ev 13 75)) @((Enable 'upB')) -house 'Nod2' -Disabled
Trigger 'hive' 'Hive zniszczony' @((Ev 29)) @((Act 56 3), (Disable 'wH'), '106,0,2,3000,0,0,0,A',
    (Text 'Plk Stavros: Hive na polnocy zniszczony! Najazdy z polnocy ustana.'), (Enable 'hive2')) -house 'Nod2' -tag 'ARKA4G07'
Trigger 'hive2' 'Hive 2: premia' @((Ev 13 5)) @((Text 'Mengsk (radio): Za Hive place premie. Przelew juz poszedl.')) -Disabled
# the nests build: a Drone every 110 s (centre) / 130 s (Hive) from 300 s, each hatched for the house's credits
Add-ZergBuilder 'Nod1' $H.Nod1 22 $nodes['Nod1'] 300 110 'zbC'
Add-ZergBuilder 'Nod2' $H.Nod2 28 $nodes['Nod2'] 330 130 'zbH'
Trigger 'zergBuild2' 'Zergi buduja: Stavros' @((Ev 13 660)) @((Text 'Plk Stavros: Zwiad melduje, ze Zergi rozbudowuja gniazda. Kazda nowa kolonia to kolejna przeszkoda. Lepiej uderzyc wczesnie.'))
Trigger 'stickler' 'Lasy Stickler' @((Ev 1 $H.Allies)) @((Text 'Plk Stavros: Lasy Stickler. Krysztaly odrastaja tu powoli, ale same. Warto postawic tu rafinerie.')) -tag 'ARKA4G11'

# --- secret: an engineer in the green-crystal Zerg (the capture springs its tag; it is Immune, so only that)
Trigger 'secretHit' 'Sekret: inzynier w gniezdzie' @((Ev 48)) @((Act 56 6), (Enable 'secret')) -house 'Neutral' -tag 'ARKA4G08'
Trigger 'secret' 'Sekret: zielony krysztal' @((Ev 13 2)) @((Text 'Inzynier: Komandorze, w tym gniezdzie jest Zerg, ktoremu z pancerza wyrasta zielony krysztal.'), (Enable 'secret2')) -Disabled
Trigger 'secret2' 'Sekret 2' @((Ev 13 5)) @((Text 'Einstein: To nie mogla byc nasza probka. Ona nie opuszczala laboratorium. Ktos je karmi.')) -Disabled

# --- the last wave: analysis done AND Duke saved -> warning, then Mutalisks, Guardians and a swarm on the laboratory
Trigger 'finalWarn' 'Ostatnia fala: ostrzezenie' @((Ev 36 0), (Ev 36 1)) @((Disable 'anaWait'), (Act 55 3 0 59),
    (Text 'Einstein: Probka spiewa coraz glosniej. Radar widzi cos ciezkiego nad polnocnym horyzontem.'), (Enable 'finalWarn2'), (Enable 'final'))
Trigger 'finalWarn2' 'Ostatnia fala: ostrzezenie 2' @((Ev 13 5)) @((Text 'Plk Stavros: Mutaliski i cos wiekszego. Mamy dwie, moze trzy minuty. Dzialka przeciwlotnicze i rakiety!'), (Enable 'finalWarn3')) -Disabled
Trigger 'finalWarn3' 'Ostatnia fala: cel 3' @((Ev 13 5)) @((Text 'Cel 3: przetrwaj ostatni atak na laboratorium i zniszcz caly roj.')) -Disabled
Trigger 'final' 'Ostatnia fala' @((Ev 13 240)) @((Act 56 5), (Disable 'wC'), (Disable 'wH'), (Disable 'wW'), (Disable 'wCon'), (Disable 'wHon'), (Disable 'wWon'), (Reinf $tmF1 59), (Reinf $tmF2 59), (Reinf $tmF3 62), (Reinf $tmF4 42), (Act 55 3 0 59), (Act 48 1 0 12),
    (Text 'Tanya: Ida! Wszyscy na stanowiska!'), (Enable 'finalArm'), (Enable 'finalHard')) -Disabled
Trigger 'finalHard' 'Ostatnia fala: trudny' @((Ev 13 30), (Ev 27 12)) @((Reinf $tmF5 59)) -Disabled
Trigger 'finalArm' 'Ostatnia fala: uzbrojona' @((Ev 13 20)) @((Enable 'win'), (Enable 'winT')) -Disabled
# victory: every unit of the last wave dead, or (fallback, a stuck flyer) 12 minutes after it came
$noLoss = @('labLost', 'rayLost', 'tanLost', 'dukeLost', 'noradLost', 'allLost')
$winActs = @($noLoss | ForEach-Object { Disable $_ }) + @((Act 48 1 0 12), (Text 'Einstein: Odparte! Probka cala, laboratorium stoi.'), (Enable 'end1'))
Trigger 'win' 'Ostatnia fala rozbita' @((Ev 9 $H.Nod)) ($winActs + @((Disable 'winT'))) -Disabled
Trigger 'winT' 'Ostatnia fala: roj sie wycofuje' @((Ev 13 720)) ($winActs + @((Disable 'win'))) -Disabled
Trigger 'end1' 'Koniec 1: Mengsk' @((Ev 13 5)) @((Text 'Mengsk (ekran): Generale Duke. Konfederacja zostawila pana na smierc tak samo jak Mar Sare. Ma pan wybor.'), (Enable 'end2')) -Disabled
Trigger 'end2' 'Koniec 2: Duke' @((Ev 13 5)) @((Text 'Edmund Duke: Konfederacja i tak tonie. Wchodze w to, Mengsk.'), (Enable 'end3')) -Disabled
Trigger 'end3' 'Koniec 3: Mengsk' @((Ev 13 5)) @((Text 'Mengsk (ekran): Swietnie. A pana, profesorze, prosze o kawalek tego krysztalu. Do badan.'), (Enable 'end4')) -Disabled
Trigger 'end4' 'Koniec 4: Einstein' @((Ev 13 5)) @((Text 'Einstein (do Tanyi, gdy ekran gasnie): Dam mu kawalek szkla. Zielonego.'), (Enable 'end5')) -Disabled
Trigger 'end5' 'Koniec 5: Tanya' @((Ev 13 5)) @((Text 'Tanya: Profesorze, zaczyna mi sie pan podobac.'), (Enable 'endWin')) -Disabled
Trigger 'endWin' 'Wygrana' @((Ev 13 40)) @((Act 1 $H.Allies)) -Disabled

Split-MultiText; Set-DialoguePacing
Add-Difficulty   # client level: Easy = half waves + double money, Medium = 3/4 + 50%, Hard = as written (MissionKit)
$textWarn = Test-TextTimeline

# resolve symbolic trigger references and write [Triggers]/[Events]/[Actions]/[Tags]
$idOf = @{}; foreach ($k in $trig.Keys) { $idOf[$k] = $trig[$k].Id }
foreach ($k in $trig.Keys) {
    $t = $trig[$k]
    $acts = foreach ($a in $t.Actions) { $p = $a -split ','; if ($p[1] -eq '2') { if (-not $idOf.ContainsKey($p[2])) { throw "unknown trigger '$($p[2])' in $k" }; $p[2] = $idOf[$p[2]] }; $p -join ',' }
    $ln = '<none>'; if ($t.Link) { if (-not $idOf.ContainsKey($t.Link)) { throw "unknown linked trigger '$($t.Link)' in $k" }; $ln = $idOf[$t.Link] }
    $ini.Set('Triggers', $t.Id, "$($t.House),$ln,$($t.Name),$([int]$t.Disabled),$($t.Diff),0")
    $ini.Set('Events', $t.Id, "$($t.Events.Count)," + ($t.Events -join ','))
    $ini.Set('Actions', $t.Id, "$(@($acts).Count)," + (@($acts) -join ','))
    $ini.Set('Tags', $t.Tag, "$(if ($t.Repeat) { 2 } else { 0 }),$($t.Name) 1,$($t.Id)")
}

# ================================================================ Zerg creep from the start (user 2026-10-28: "creep fundament")
# Without it the Zerg buildings stood on bare ground until their spawner made a hole and the veins grew, and the
# buildings without a spawner (Pool, Hydra Den, Evolution Chamber, Spire) never got creep under them. As ARKA 2 does:
# a Veinhole Monster in the map under every creep building (Hatchery/Hive at foundation cell (1,1), colonies at (0,0);
# holes 3+ cells apart, the engine's rule), overlay 167 + 8x 178 round it, and fully grown VEINS (126, data 48) on a
# disc of radius 5 round each hole and on every cell of every Zerg building plus a 1-cell margin. At map load
# Place_Monsters floods the veins connected to a hole and removes the others, so the carpet must touch a hole (the
# discs do that inside a nest). Only clear ground without an overlay or a tree; cells of non-Zerg buildings stay free.
# Written last, after the crates (Add-MoneyCrate refuses a cell with an overlay).
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
    $ok = $true; for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { $c = $code[($hy + $dy) * $GW + $hx + $dx]; if (-not ($c -eq 0 -or ($c -ge 11 -and $c -le 14)) -or $o[($hy + $dy) * 512 + $hx + $dx] -ne 255) { $ok = $false } } }
    if (-not $ok) { $log.Add("creep: no hole under $($b[0]) @ $hx,$hy (ground or overlay)"); continue }
    $holes += , @($hx, $hy)
    for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { $i = ($hy + $dy) * 512 + $hx + $dx; $o[$i] = $(if ($dx -eq 0 -and $dy -eq 0) { 167 } else { 178 }); $od[$i] = 0 } }
}
$veinAt = { param($x, $y) if (Creep-Free $x $y) { $i = $y * 512 + $x; $o[$i] = 126; $od[$i] = 48; $script:nVein++ } }
foreach ($h in $holes) { for ($dx = -5; $dx -le 5; $dx++) { for ($dy = -5; $dy -le 5; $dy++) { if ($dx * $dx + $dy * $dy -le 25) { & $veinAt ($h[0] + $dx) ($h[1] + $dy) } } } }
foreach ($b in $zb) { for ($x = $b[1] - 1; $x -le $b[1] + $b[3]; $x++) { for ($y = $b[2] - 1; $y -le $b[2] + $b[4]; $y++) { & $veinAt $x $y } } }
$ini.SetPack('OverlayPack', [Pack]::PackData($o, $false, 8192)); $ini.SetPack('OverlayDataPack', [Pack]::PackData($od, $false, 8192))
$log.Add("creep at start: $($holes.Count) holes under $($zb.Count) Zerg buildings, $nVein vein cells")

# ================================================================ [Basic], briefing
$basic = [ordered]@{
    Name = 'ARKA #4: Zielony krysztal'; Author = 'Zema (teren: Blizzard T6 Norad II)'; GameMode = 'Custom Map'; Player = 'Allies'
    Theme = 'SEARCH'; MultiplayerOnly = 'no'; HomeCell = '11'; AltHomeCell = '11'; MaxPlayer = '0'; MinPlayer = '2'; SkipMapSelect = 'yes'
    OneTimeOnly = 'yes'; EndOfGame = 'no'; SkipScore = 'no'; FreeRadar = 'yes'; RequiredAddOn = '1'; NextScenario = ''; AltNextScenario = ''
}
foreach ($k in $basic.Keys) { $ini.Set('Basic', $k, $basic[$k]) }
$ini.Sections.Remove('Briefing') | Out-Null; $ini.Order.Remove('Briefing') | Out-Null
$brief = @(
    'Antiga Prime, 2499. ARKA stoi na rowninie za miastem, a Einstein urzadzil w namiocie obok laboratorium i bada odlamek zielonego krysztalu z rdzenia.',
    '@@Zergi czuja probke i ciagna do niej ze wszystkich stron. Mengsk prosi o jeszcze jedno: okret flagowy Konfederacji Norad II rozbil sie w gniezdzie Zergow, a na pokladzie jest general Duke.',
    '@@Bron laboratorium, zbieraj krysztaly i rozbudowuj sie: pole przy bazie jest ubogie. Uratuj Duke''a i przetrwaj ostatni atak roju.')
for ($i = 0; $i -lt $brief.Count; $i++) { $ini.Set('Briefing', "$($i + 1)", $brief[$i]) }
$ini.Set('SpecialFlags', 'Visceroids', 'no')
# the blue crystals grow back slowly ([BlueGems] above), the mines seed new ones; no ore on this map
$ini.Set('SpecialFlags', 'TiberiumGrows', 'yes')
$ini.Set('SpecialFlags', 'TiberiumSpreads', 'no')
foreach ($s in 'Preview', 'PreviewPack') { $ini.Sections.Remove($s) | Out-Null; $ini.Order.Remove($s) | Out-Null }

[IO.File]::WriteAllText($Out, $ini.Write(), $enc)
$log.Add("written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB): $($trig.Count) triggers, $tmN teams, $($textNo - 9400) texts, $($structs.Count) buildings, $($units.Count) units, $($infs.Count) infantry, $smN smudges")

# ================================================================ client entry: INI\BattleE.ini (merge; other ARKA missions keep their entries)
if (-not $NoBattle) {
    $bf = "$game\INI\BattleE.ini"
    $b = if (Test-Path $bf) { [Ini]::Load($bf) } else { New-Object Ini }
    if (-not $b.Get('Battles', 'ARKAH', $null)) { $b.Set('Battles', 'ARKAH', 'HEADER_ARKA'); $b.Set('HEADER_ARKA', 'Description', 'ARKA: Blad znaku'); $b.Set('HEADER_ARKA', 'Categories', 'CAT_SA') }
    $b.Set('Battles', 'ARKA04', 'M_ARKA04')
    $m = [ordered]@{ CD = '-1'; Scenario = 'Maps/Missions/arka04.map'; Description = 'ARKA #4: Zielony krysztal'; Author = 'Zema'; RequiredAddon = '1'; Side = '2'
        IconPath = 'alliesicon.png'; PlayerAlwaysOnNormalDifficulty = 'yes'; Categories = 'CAT_SA'
        LongDescription = 'Antiga Prime, 2499. Einstein bada zielony krysztal z rdzenia ARKI, a Zergi ciagna do probki ze wszystkich stron. @@Bron laboratorium, zbieraj krysztaly i rozbudowuj sie po Antidze, uratuj generala Duke''a z wraku Norad II i przetrwaj ostatni atak roju.' }
    foreach ($k in $m.Keys) { $b.Set('M_ARKA04', $k, $m[$k]) }
    $head = "; ARKA campaign (Claude, Modding/wiki/plans/campaign-arka). Extra battle file read by the client`r`n; (Resources/ClientDefinitions.ini BattleFSFileName=BattleE.ini); written by Modding/tools/build-arka0*-mission.ps1.`r`n"
    [IO.File]::WriteAllText($bf, $head + $b.Write(), [Text.Encoding]::ASCII)
    $log.Add("BattleE.ini: M_ARKA04 merged (entries: " + (($b.Section('Battles') | ForEach-Object { $_.Key }) -join ',') + ")")
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
# pitfall 16 (engine/triggers-and-dialogue): a long [Actions] line overflows the game's buffer (ARKA 5 crashed at load)
foreach ($kv in $ini.Section('Actions')) { if ($kv.Value.Length -gt 400) { $log.Add("FAIL [Actions] $($kv.Key) is $($kv.Value.Length) chars (> 400)"); $fail++ } }
foreach ($kv in $ini.Section('Triggers')) { if (($kv.Value -split ',').Count -ne 8) { $log.Add("FAIL trigger $($kv.Key) has $(($kv.Value -split ',').Count) fields"); $fail++ } }
foreach ($ln in $listNames) { foreach ($kv in $ini.Section($ln)) { if (-not ($ini.Has($kv.Value) -or $rules.ContainsKey($kv.Value))) { $log.Add("FAIL $ln entry $($kv.Value) has no section"); $fail++ } } }
foreach ($kv in $ini.Section('TeamTypes')) {
    $tm = $kv.Value; $airN = @($ini.Section($ini.Get($tm, 'TaskForce', '')) | Where-Object { $_.Value -match ',(SCZMUT|SCZGRD|SCZOVL|SCDROP|SCCCF)$' }).Count
    $s1 = @($ini.Section($ini.Get($tm, 'Script', '')) | Where-Object { $_.Key -match '^\d+$' -and $_.Value -match '^1,' }).Count
    if ($s1 -and -not $airN) { $log.Add("FAIL ground team $tm ($($ini.Get($tm, 'Name', ''))) uses script action 1"); $fail++ }
}
foreach ($ln in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') {
    foreach ($kv in $ini.Section($ln)) { $img = $ini.Get($kv.Value, 'Image', $kv.Value); if (-not $art.ContainsKey($img)) { $log.Add("FAIL $($kv.Value): no [$img] in Art.ini (would be invisible)"); $fail++ } }
}
foreach ($t in 'BIO', 'RAPDOX', 'AFACT', 'AWEAP', 'RADOME', 'RATENT', 'RAPOWR', 'RAPROC') { $img = if ($rules[$t]['Image']) { $rules[$t]['Image'] } else { $t }; if (-not $art.ContainsKey($img)) { $log.Add("FAIL $t has no art [$img]"); $fail++ } }
foreach ($s in $scTypes) { foreach ($k in 'Prerequisite', 'BuiltAt') { $v = $ini.Get($s, $k, $null); if ($v) { foreach ($tok in ($v -split ',')) { $tok = $tok.Trim(); if ($tok -and $tok -notmatch '^(POWER|FACTORY|BARRACKS|RADAR|TECH|PROC|none)$' -and -not ($ini.Has($tok) -or $rules.ContainsKey($tok))) { $log.Add("FAIL $s $k names $tok"); $fail++ } } } } }
foreach ($w in 'ARKDukeGun', 'ARKDukeGunS') { $log.Add("$w damage $($ini.Get($w, 'Damage', '?')) (Raynor $($scSec['SCRaynGun']['Damage']))") }
$log.Add("Duke HP $($ini.Get('ARKDUKE', 'Strength', '?')) = Raynor hero Marine $($scSec['SCRAYN']['Strength'])")
$log.Add($(if ($fail) { "CHECKS: $fail FAIL" } else { 'CHECKS: PASS (types defined, teams exist, every tag has a trigger, prerequisites resolve)' }) + "; text timeline: $textWarn WARN")
$log | Set-Content "$work\log.txt" -Encoding UTF8
$log | Where-Object { $_ -notmatch '^building ' }

if ($Render) {
    $dir = "$game\Map Editor\Map Renderer"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$Out`" -o arka04_mission -d `"$work`" -p -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "renderer timed out" }
    "render: $work\arka04_mission.png"
}
