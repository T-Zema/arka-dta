# Mission layer of ARKA mission 3 "Sygnal z nieba" (Antiga Prime, 2499): a covert mission (user 2026-10-30: "more
# covert, less base building, different from the other maps"). Kerrigan (a cloaked hero Ghost) blinds two Confederate
# observation towers by walking up to them; if the guards detect her or a tower is shot at, the garrison raises the
# alarm and sends bigger squads. Then the prison camp on the SW shore, the psi emitter that Kerrigan's team put by the
# garrison (Zerg come mid-mission; destroy it or leave it, Mengsk remembers) and the garrison's Command Center.
# No construction yard: the small base of mission 4 by the ARKA (without Einstein's laboratory), barracks, war factory,
# helipad. Reads the terrain map built by build-arka03-antiga.ps1 (Maps\Custom\arka03_antiga.map, read-only) and
# mission 4's map (the base layout, moved by the terrain's cell shift); writes Maps\Missions\arka03.map.
# Waypoints 10-61 of the terrain map are the contract (wiki missions/arka-03-sygnal).
#
#   powershell -NoProfile -File .\build-arka03-mission.ps1            # build + checks
#   powershell -NoProfile -File .\build-arka03-mission.ps1 -Render    # also render %TEMP%\arka03-mission\arka03_mission.png
#
# Texts: ASCII Polish, [Tutorial] numbers 9301-9399. Time units: Elapsed Time counts game seconds.
param(
    [string]$Terrain = "",
    [string]$Out = "",
    [switch]$Render,
    [switch]$NoBattle
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Terrain) { $Terrain = "$game\Maps\Custom\arka03_antiga.map" }
if (-not $Out) { $Out = "$game\Maps\Missions\arka03.map" }
$work = "$env:TEMP\arka03-mission"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\TsMap.cs" -ReferencedAssemblies System.Drawing
$enc = [Text.Encoding]::GetEncoding(1252)

$ini = [Ini]::Load($Terrain)
$log = New-Object Collections.Generic.List[string]
# mission 4's base: same cells as mission 4, moved by the terrain's cell shift (build-arka03-antiga.ps1: $CellDX/$CellDY)
$CellDX = -48; $CellDY = -120
$m4map = "$game\Maps\Missions\arka04.map"
if (-not (Test-Path $m4map)) { throw "mission 4 map $m4map is missing (the base layout comes from it)" }

# ================================================================ terrain occupancy (what may hold a building or unit)
$mixes = New-Object MixSet "$game\MIX"
$th    = New-Object Theater "$game\INI\Temperat.ini", "tem", $mixes
$GW = 512
$code = New-Object 'int[]' ($GW * $GW); for ($i = 0; $i -lt $code.Length; $i++) { $code[$i] = -1 }
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
    'SCZLNG', 'SCZHYL', 'SCZULT', 'SCZMUT',                                                          # the Zerg that the emitter calls
    'SCCC', 'SCBARR', 'SCFACT', 'SCMSHP', 'SCSTAR', 'SCDEPO', 'SCACAD', 'SCEBAY', 'SCCOMS', 'SCSCIF',   # garrison, camp, town
    'SCBUNK', 'SCMTUR', 'SCSIEGB',                                                                   # defences
    'SCMARINE', 'SCFIRE', 'SCGOLI', 'SCVULT', 'SCSIEGE', 'SCGHOST', 'SCRAYN')                        # Confederates, Sons of Korhal, Kerrigan, Raynor
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
        $ini.Set($ln, ('ARKA3{0}{1:D3}' -f $ln.Substring(0, 2).ToUpper(), $nList[$ln]), $s)
    }
}
$log.Add("SC types copied into the map: $($scTypes.Count) sections (" + (($nList.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', ') + ")")
foreach ($t in 'SCZMUT') {
    $s = $ini.Section($t); for ($i = $s.Count - 1; $i -ge 0; $i--) { if ($s[$i].Key -in 'Naval', 'BuiltAt', 'Factory', 'WeaponsFactory', 'ExclusiveFactory') { $s.RemoveAt($i) } }
}
# anti-air as in missions 1-4: rockets and Gauss rifles hit air AND ground; the Allied AA gun hurts light flyers
function Resolve-Rules($sec) { $chain = @(); $s = $sec; while ($s -and $rules.ContainsKey($s) -and $chain.Count -lt 5) { $chain = , $s + $chain; $s = $rules[$s]['$Inherits'] }; $m = [ordered]@{}; foreach ($c in $chain) { foreach ($k in $rules[$c].Keys) { if ($k -ne '$Inherits') { $m[$k] = $rules[$c][$k] } } }; $m }
$aag = Resolve-Rules 'AGHeatSeeker'; $aag['AA'] = 'yes'; $aag['AG'] = 'yes'
foreach ($k in $aag.Keys) { $ini.Set('ARKA3AAG', $k, $aag[$k]) }
foreach ($w in '70mmMsl', '70mmMslRA', 'AA70mmMsl', 'AA70mmMslRA') { if ($rules.ContainsKey($w)) { $ini.Set($w, 'Projectile', 'ARKA3AAG') } }
foreach ($w in 'SCGauss', 'SCGaussS') { if ($ini.Has($w)) { $ini.Set($w, 'Projectile', 'Invisible3') } }
$ini.Set('FlakWH', 'Modifier.light', '770%')

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
foreach ($n in (10..48 + 50..61)) { if (-not $wp.ContainsKey($n)) { throw "terrain map has no waypoint $n (contract 10-61 broken)" } }
function WpLetter([int]$n) { $s = ''; $n++; while ($n -gt 0) { $n--; $s = [char](65 + $n % 26) + $s; $n = [Math]::Floor($n / 26) }; $s }
function Dist($a, $b) { [Math]::Sqrt(($a[0] - $b[0]) * ($a[0] - $b[0]) + ($a[1] - $b[1]) * ($a[1] - $b[1])) }

$reserved = New-Object 'bool[]' ($GW * $GW)
function Reserve($cx, $cy, $r) { for ($x = $cx - $r; $x -le $cx + $r; $x++) { for ($y = $cy - $r; $y -le $cy + $r; $y++) { $reserved[$y * $GW + $x] = $true } } }
function Free($x, $y, $w, $hh, $m, [bool]$useReserved) {
    for ($i = $x - $m; $i -lt $x + $w + $m; $i++) { for ($j = $y - $m; $j -lt $y + $hh + $m; $j++) {
        if (-not (Buildable $i $j)) { return $false }
        if (-not $useReserved -and $reserved[$j * $GW + $i]) { return $false }
    } }
    $true
}
function Occupy($x, $y, $w, $hh) { for ($i = $x; $i -lt $x + $w; $i++) { for ($j = $y; $j -lt $y + $hh; $j++) { $block[$j * $GW + $i] = $true } } }
function Find-Spot($tx, $ty, $w, $hh, $m, [bool]$useReserved) {
    for ($r = 0; $r -le 25; $r++) {
        $best = $null; $bd = 1e9
        for ($x = $tx - $r; $x -le $tx + $r; $x++) { for ($y = $ty - $r; $y -le $ty + $r; $y++) {
            if ([Math]::Max([Math]::Abs($x - $tx), [Math]::Abs($y - $ty)) -ne $r) { continue }
            if (Free $x $y $w $hh $m $useReserved) { $d = ($x - $tx) * ($x - $tx) + ($y - $ty) * ($y - $ty); if ($d -lt $bd) { $bd = $d; $best = @($x, $y) } }
        } }
        if ($best) { return $best }
    }
    throw "no free ${w}x$hh spot near $tx,$ty"
}

# ================================================================ object writers
$structs = $ini.Section('Structures'); $sIdx = $structs.Count
$units = $ini.Section('Units'); $infs = $ini.Section('Infantry')
function Add-Building($house, $type, $x, $y, $tag = 'None', $sell = 1, $hp = 256) {
    $f = Foundation $type; Occupy $x $y $f[0] $f[1]
    $script:structs.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$script:sIdx", "$house,$type,$hp,$x,$y,64,$tag,$sell,0,1,0,0,None,None,None,0,0"))
    $script:sIdx++; $log.Add("building $house $type @ $x,$y ($($f[0])x$($f[1])) hp=$hp tag=$tag")
    @($x, $y)
}
function Place-AtWp($house, $type, [int]$n, $m = 1, $tag = 'None', $hp = 256, $sell = 0, $dx = 0, $dy = 0) {
    $f = Foundation $type
    $s = Find-Spot ($wp[$n][0] + $dx - [Math]::Floor($f[0] / 2)) ($wp[$n][1] + $dy - [Math]::Floor($f[1] / 2)) $f[0] $f[1] $m $true
    Add-Building $house $type $s[0] $s[1] $tag $sell $hp
}
function Add-Unit($house, $type, $tx, $ty, $mission = 'Guard', $tag = 'None', $hp = 256, $vet = 0, $facing = 64) {
    $s = Find-Spot $tx $ty 1 1 0 $true; Occupy $s[0] $s[1] 1 1
    $script:units.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$($script:units.Count)", "$house,$type,$hp,$($s[0]),$($s[1]),$facing,$mission,$tag,$vet,-1,0,-1,0,0"))
    @($s[0], $s[1])
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
# SC Marines, Firebats and the rest are SHP *vehicles* in the mod, so they go to [Units]
function Is-Vehicle($type) { $listOf[$type] -eq 'VehicleTypes' -or $listOf[$type] -eq 'Rules:VehicleTypes' -or @($ini.Section('VehicleTypes') | Where-Object { $_.Value -eq $type }).Count }
function Squad($house, [string[]]$types, [int]$n, $dx = 0, $dy = 0, $mission = 'Guard', $hp = 256) {
    NewCell
    foreach ($t in $types) {
        if (Is-Vehicle $t) { Add-Unit $house $t ($wp[$n][0] + $dx) ($wp[$n][1] + $dy) $mission 'None' $hp | Out-Null }
        else { Add-Inf $house $t ($wp[$n][0] + $dx) ($wp[$n][1] + $dy) $mission 'None' $hp }
    }
}
function Copy-Type($dst, $src, $over) {
    $m = [ordered]@{}; foreach ($k in $scSec[$src].Keys) { $m[$k] = $scSec[$src][$k] }
    foreach ($k in 'Prerequisite', 'BuiltAt', 'BuildLimit', 'Naval', 'DeploysInto', 'UndeploysInto', 'Factory') { $m.Remove($k) }
    foreach ($k in $over.Keys) { if ($null -eq $over[$k]) { $m.Remove($k) } else { $m[$k] = $over[$k] } }
    foreach ($k in $m.Keys) { $ini.Set($dst, $k, "$($m[$k])") }
}

# ================================================================ mission types
$ini.Set('TANYA', 'Strength', "$([int]([int]$rules['TANYA']['Strength'] * 2.5))")   # 2500 HP in every ARKA mission
# ARKA: the core holds again since the jump; no superweapon, no power; its loss loses the mission (plan)
$fcache['RAPDOX'] = @(2, 2)
$arka = [ordered]@{
    Name = 'ARKA'; Strength = '20000'; Armor = 'heavy'; TechLevel = '-1'; Sight = '8'; Power = '0'; Powered = 'no'; Capturable = 'false'
    Crewed = 'no'; Unsellable = 'yes'; Repairable = 'yes'; ClickRepairable = 'yes'; SuperWeapon = 'none'; NukeSilo = 'no'; AIBuildThis = 'no'
}
foreach ($k in $arka.Keys) { $ini.Set('RAPDOX', $k, $arka[$k]) }
# Einstein: the Scientist (CHAN <- C2) resolved by hand, as mission 2
$ein = Resolve-Rules 'CHAN'
$ein['Name'] = 'Albert Einstein'; $ein['Image'] = $(if ($art.ContainsKey('CHAN')) { 'CHAN' } else { 'C2' }); $ein['Strength'] = '400'; $ein['Insignificant'] = 'no'
$ein['Owner'] = 'Allies'; $ein['TechLevel'] = '-1'; $ein['EditorName'] = 'Einstein (ARKA)'; $ein['Fraidycat'] = 'no'
$ini.Set('InfantryTypes', 'ARKA3I01', 'ARKEINST'); foreach ($k in $ein.Keys) { $ini.Set('ARKEINST', $k, $ein[$k]) }
# Jim Raynor on his Vulture (missions 1-4)
$ray = [ordered]@{ Name = 'Jim Raynor (Vulture)'; Image = 'SCVULT'; Strength = [string][int]([int]$scSec['SCVULT']['Strength'] * 4.8); TechLevel = '-1'; Owner = 'Allies'
    SelfHealing = 'yes'; SelfHealingCap = '1.0'; SelfHealingStep = '5' }
foreach ($k in 'VoiceSelect', 'VoiceMove', 'VoiceAttack', 'VoiceFeedback', 'VoiceDie') { if ($scSec['SCRAYN'].Contains($k)) { $ray[$k] = $scSec['SCRAYN'][$k] } }
Copy-Type 'ARKRAYN' 'SCVULT' $ray
# Sarah Kerrigan: the Ghost of mission 5 (3x HP, 3x gun, self-healing), here CLOAKED (the covert mission) and mortal
Copy-Type 'ARKKERR' 'SCGHOST' ([ordered]@{ Name = 'Sarah Kerrigan'; Image = 'SCGHOST'; Strength = [string]([int]$scSec['SCGHOST']['Strength'] * 3); TechLevel = '-1'; Owner = 'Allies'
    Cloakable = 'yes'; Primary = 'ARKKerrGun'; SelfHealing = 'yes'; SelfHealingCap = '1.0'; SelfHealingStep = '10'; Cost = '0' })
foreach ($k in $scSec['SCC10'].Keys) { $ini.Set('ARKKerrGun', $k, $scSec['SCC10'][$k]) }
$ini.Set('ARKKerrGun', 'Damage', [string]([int]$scSec['SCC10']['Damage'] * 3))
# the observation tower: the SC Missile Turret picture, no weapon, sees cloaked units (Sensors) round itself
Copy-Type 'ARKTOWR' 'SCMTUR' ([ordered]@{ Name = 'Wieza obserwacyjna Konfederacji'; Image = 'SCMTUR'; Primary = $null; Sensors = 'yes'; Sight = '9'; Strength = '1500'
    TechLevel = '-1'; Owner = 'GDI'; Power = '0'; Capturable = 'false'; ThreatPosed = '0'; IsBaseDefense = 'no'; Adjacent = $null; Cost = '0'; Points = '5'; GuardRange = $null })
# the prison block: the SC Barracks picture, a building of the garrison
Copy-Type 'ARKJAIL' 'SCBARR' ([ordered]@{ Name = 'Oboz jeniecki Konfederacji'; Image = 'SCBARR'; TechLevel = '-1'; Owner = 'GDI'; Strength = '3000'; Capturable = 'false'
    Power = '0'; Cost = '0'; Adjacent = $null })
# the psi emitter: as mission 5 (Comsat Station picture); nobody shoots it on their own, so leaving it is a real choice
Copy-Type 'ARKPSIE' 'SCCOMS' ([ordered]@{ Name = 'Psi-nadajnik'; Description = 'Psi-nadajnik Synow Korhalu. Wabi Zergi.'; Image = 'SCCOMS'
    Radar = $null; Sensors = $null; Powered = 'false'; Power = '0'; Strength = '2500'; Armor = 'concrete'; TechLevel = '-1'; Owner = 'Soviet1'
    Capturable = 'false'; Crewed = 'no'; Repairable = 'yes'; ClickRepairable = 'no'; ThreatPosed = '0'; Adjacent = $null; Cost = '0'; Points = '0' })
foreach ($t in 'ARKTOWR', 'ARKJAIL', 'ARKPSIE') { $fcache[$t] = Foundation ($ini.Get($t, 'Image', $t)) }
# SC neutral buildings (tools/build-scneutral.ps1, MIX/ECACHE75.MIX; art name = section name): the town's power plant and
# space station, and the garrison's planetary Ion Cannon (decoration; it does not fire)
$neutralSc = [ordered]@{
    SCNGEN = [ordered]@{ Name = 'Generator miejski Antigi'; Strength = '1500'; Armor = 'concrete'; Owner = 'Neutral' }
    SCNSTB = [ordered]@{ Name = 'Stacja kosmiczna Antigi'; Strength = '2000'; Armor = 'concrete'; Owner = 'Neutral' }
    SCNION = [ordered]@{ Name = 'Dzialo jonowe Konfederacji'; Strength = '3000'; Armor = 'concrete'; Owner = 'GDI' }
}
$nb = 3
foreach ($t in $neutralSc.Keys) {
    if (-not $art.ContainsKey($t)) { throw "no [$t] in Art.ini: run build-scneutral.ps1 first" }
    $v = $neutralSc[$t]
    foreach ($k in $v.Keys) { $ini.Set($t, $k, $v[$k]) }
    foreach ($kv in @(@('TechLevel', '-1'), @('Power', '0'), @('Capturable', 'false'), @('Crewed', 'yes'), @('Sight', '5'), @('ThreatPosed', '0'), @('Cost', '0'), @('Points', '5'), @('ImmuneToVeins', 'yes'))) { $ini.Set($t, $kv[0], $kv[1]) }
    $nb++; $ini.Set('BuildingTypes', ('ARKA3B{0:D2}' -f $nb), $t)
}
$ini.Set('VehicleTypes', 'ARKA3V01', 'ARKRAYN'); $ini.Set('VehicleTypes', 'ARKA3V02', 'ARKKERR')
$ini.Set('BuildingTypes', 'ARKA3B01', 'ARKTOWR'); $ini.Set('BuildingTypes', 'ARKA3B02', 'ARKJAIL'); $ini.Set('BuildingTypes', 'ARKA3B03', 'ARKPSIE')
# crystal mines (as mission 4): OREMINE2 seeds blue crystals that grow back slowly
$ini.Set('OREMINE2', 'Name', 'Kopalnia niebieskich krysztalow'); $ini.Set('OREMINE2', 'TiberiumToSpawn', '6')
$ini.Set('BlueGems', 'Growth', '3000'); $ini.Set('BlueGems', 'GrowthPercentage', '.05')
# tech: helicopters from this mission on (plan), no base building (a covert mission: no MCV), no missile silo
foreach ($t in 'AMCV', 'RAMSLO', 'DTRK') { $ini.Set($t, 'TechLevel', '-1') }

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
House 'Allies'  'AlliesSide'   'AlliedBlue' 'Allies,Soviet,Allies1,Neutral' 30 2 'yes' 'North' 0 6   # player: 3000 credits, tech level 6
House 'GDI'     'GDISide'      'DarkRed'    'GDI,Soviet1,Allies1,Neutral' 0 0 'no'                    # the Confederate garrison (Alpha Squadron red as Duke's men)
House 'Soviet'  'GDISide'      'Gold'       'Soviet,Allies,Allies1,Soviet1' 0 3 'no' 'West'           # Sons of Korhal (the camp in the west)
House 'Soviet1' 'GDISide'      'Gold'       'Soviet1,GDI,Soviet,Nod1,Allies1' 0 3 'no'                # Mengsk's psi emitter: the garrison does not know, the Zerg love it
House 'Nod1'    'NodSide'      'Purple'     'Nod1,Soviet1,Allies1' 0 7 'no' 'South'                   # the Zerg the emitter calls
House 'Allies1' 'AlliesSide'   'Gold'       'Allies1,Allies,GDI,Soviet,Soviet1,Nod1,Neutral' 0 2 'no'  # the rebels in the prison camp (hidden ally until freed)
House 'Neutral' 'CivilianSide' 'Grey'       'Neutral,Allies,GDI,Allies1' 0 4 'no'
House 'Special' 'SpecialSide'  'Grey'       'Special' 0 5 'no'

# ================================================================ the Allied base by the ARKA: mission 4's buildings on the same cells
# (user 2026-10-30: the start of mission 3 is mission 4's base without Einstein's tent; the ConYard becomes a helipad)
$m4 = [Ini]::Load($m4map)
$baseN = 0
foreach ($kv in $m4.Section('Structures')) {
    $p = $kv.Value -split ','; if ($p[0] -ne 'Allies' -or $p[1] -eq 'BIO') { continue }
    $type = if ($p[1] -eq 'AFACT') { 'AHPAD' } else { $p[1] }
    $x = [int]$p[3] + $CellDX; $y = [int]$p[4] + $CellDY; $f = Foundation $type
    if (-not (Free $x $y $f[0] $f[1] 0 $true)) { $s = Find-Spot $x $y $f[0] $f[1] 0 $true; $log.Add("base: $type moved $x,$y -> $($s[0]),$($s[1])"); $x = $s[0]; $y = $s[1] }
    $tag = if ($type -eq 'RAPDOX') { 'ARKA3G01' } else { 'None' }
    Add-Building 'Allies' $type $x $y $tag $(if ($type -eq 'RAPDOX') { 0 } else { 1 }) | Out-Null; $baseN++
}
$log.Add("base: $baseN buildings from mission 4 (laboratory left out, ConYard -> helipad)")
# the refinery's truck on the home field (a refinery placed in a map gets no free truck)
$gem = @(); for ($i = 0; $i -lt $ovl.Length; $i++) { if ($ovl[$i] -ge 27 -and $ovl[$i] -le 38) { $gx = $i % 512; $gy = [Math]::Floor($i / 512); if ([Math]::Abs($gx - $wp[14][0]) -le 16 -and [Math]::Abs($gy - $wp[14][1]) -le 16) { $gem += , @($gx, $gy) } } }
if ($gem.Count -eq 0) { throw "no crystal field near the base (wp 14)" }
$gcx = [int](($gem | ForEach-Object { $_[0] } | Measure-Object -Average).Average); $gcy = [int](($gem | ForEach-Object { $_[1] } | Measure-Object -Average).Average)
Add-Unit 'Allies' 'RAHARV' $gcx $gcy 'Harvest' | Out-Null
$log.Add("home crystals: $($gem.Count) cells round $gcx,$gcy")

# ================================================================ heroes and the start force (small: a covert operation)
$k0 = Add-Unit 'Allies' 'ARKKERR' $wp[18][0] $wp[18][1] 'Guard' 'ARKA3G04'
NewCell; Add-Inf 'Allies' 'TANYA' ($wp[18][0] + 2) ($wp[18][1] + 1) 'Guard' 'ARKA3G03' 256 100
NewCell; Add-Inf 'Allies' 'ARKEINST' ($wp[10][0] + 1) ($wp[10][1] + 3) 'Guard' 'ARKA3G05'
Add-Unit 'Allies' 'ARKRAYN' ($wp[11][0] - 1) ($wp[11][1] - 3) 'Guard' 'ARKA3G02' | Out-Null
$p = $wp[11]
$crate = Find-Spot ($p[0] + 3) ($p[1] + 2) 1 1 0 $false; Occupy $crate[0] $crate[1] 1 1
foreach ($t in '1TNK', '1TNK', 'RANG') { Add-Unit 'Allies' $t ($p[0] + 2) ($p[1] - 2) 'Guard' | Out-Null }
Squad 'Allies' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE') 11 -2 -2
Squad 'Allies' @('E1', 'E1', 'E1') 11 1 2
Squad 'Allies' @('E3', 'E3') 11 -1 3
Squad 'Allies' @('MEDIC', 'ENGINEER') 11 3 1

# ================================================================ the Sons of Korhal camp (NW, across causeway A)
Place-AtWp 'Soviet' 'SCCC' 22 1 | Out-Null
Place-AtWp 'Soviet' 'SCBARR' 23 1 | Out-Null
foreach ($o in @(@(7, -1), @(7, 3), @(-1, 7))) { Place-AtWp 'Soviet' 'SCDEPO' 22 1 'None' 256 0 $o[0] $o[1] | Out-Null }
foreach ($o in @(@(0, -3), @(0, 3))) { Place-AtWp 'Soviet' 'SCBUNK' 24 0 'None' 256 0 $o[0] $o[1] | Out-Null }
Place-AtWp 'Soviet' 'SCMTUR' 24 0 'None' 256 0 -4 0 | Out-Null
Squad 'Soviet' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE', 'SCFIRE') 24 -2 0 'Guard'
Squad 'Soviet' @('SCGOLI', 'SCMARINE', 'SCMARINE') 23 2 4 'Guard'

# ================================================================ Antiga outskirts (neutral SC buildings) and the Confederate checkpoint
# (user: "add a few buildings down south, you may borrow neutral buildings from SC"; SC-world towns are SC Terran
# buildings, feedback-city-buildings): a spaceport, depots as housing, an academy and a workshop on the plain
# (user 2026-10-30: use the SC neutral Starbase and Power Generator where they fit: the town's station and power plant)
foreach ($b in @(@('SCNSTB', 0, 0), @('SCDEPO', -7, -3), @('SCDEPO', 6, -5), @('SCDEPO', -6, 4), @('SCACAD', 7, 3), @('SCEBAY', -1, 7), @('SCNGEN', 11, -1), @('SCSTAR', -12, 0))) {
    Place-AtWp 'Neutral' $b[0] 35 1 'None' 256 0 $b[1] $b[2] | Out-Null
}
if ($rules.ContainsKey('C1')) { foreach ($o in @(@(3, 3), @(-3, 2), @(2, -4))) { NewCell; Add-Inf 'Neutral' 'C1' ($wp[35][0] + $o[0]) ($wp[35][1] + $o[1]) 'Area Guard'; Add-Inf 'Neutral' 'C2' ($wp[35][0] + $o[0]) ($wp[35][1] + $o[1]) 'Area Guard' } }
Place-AtWp 'GDI' 'SCBUNK' 36 0 | Out-Null
Squad 'GDI' @('SCMARINE', 'SCMARINE', 'SCMARINE') 36 2 2 'Area Guard'

# ================================================================ the two observation towers and their guards
# Guards stand 15+ tiles from their tower: a cloaked Kerrigan is invisible to them unless a sensor sees her, and the
# tower (Sensors, Sight 9) sees her only near itself, where nobody can shoot. Shooting gives her away.
$tw1 = Place-AtWp 'GDI' 'ARKTOWR' 28 1 'ARKA3G06'
$tw2 = Place-AtWp 'GDI' 'ARKTOWR' 30 1 'ARKA3G07'
Squad 'GDI' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCVULT') 29 0 0 'Area Guard'
Squad 'GDI' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE') 57 0 0 'Area Guard'
Squad 'GDI' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCGOLI') 31 0 0 'Area Guard'
foreach ($g in @(@(28, 29), @(28, 57), @(30, 31), @(28, 36))) { $log.Add("tower wp $($g[0]) - guard wp $($g[1]): $([Math]::Round((Dist $wp[$g[0]] $wp[$g[1]]), 1)) cells") }

# ================================================================ the prison camp on the SW shore: a chain-link fence round the cell block
$jl = Place-AtWp 'GDI' 'ARKJAIL' 32 1 'ARKA3G11'
$jf = Foundation 'ARKJAIL'
$fx0 = $jl[0] - 3; $fy0 = $jl[1] - 3; $fx1 = $jl[0] + $jf[0] + 2; $fy1 = $jl[1] + $jf[1] + 2
$fence = New-Object 'Collections.Generic.HashSet[int]'
$border = @()
for ($x = $fx0; $x -le $fx1; $x++) { for ($y = $fy0; $y -le $fy1; $y++) { if ($x -eq $fx0 -or $x -eq $fx1 -or $y -eq $fy0 -or $y -eq $fy1) { $border += , @($x, $y) } } }
# the gate: the two border cells nearest the guard post (wp 34), side by side
$g1 = $null; $bd = 1e9
foreach ($c in $border) { $d = ($c[0] - $wp[34][0]) * ($c[0] - $wp[34][0]) + ($c[1] - $wp[34][1]) * ($c[1] - $wp[34][1]); if ($d -lt $bd) { $bd = $d; $g1 = $c } }
$gate = New-Object Collections.Generic.List[object]; $gate.Add($g1)
foreach ($c in $border) { if ([Math]::Abs($c[0] - $g1[0]) + [Math]::Abs($c[1] - $g1[1]) -eq 1) { $gate.Add($c); break } }
foreach ($c in $border) {
    if (@($gate | Where-Object { $_[0] -eq $c[0] -and $_[1] -eq $c[1] }).Count) { continue }
    if (Buildable $c[0] $c[1]) { [void]$fence.Add($c[1] * 512 + $c[0]) }
}
$fo = [Pack]::Unpack($ini.Joined('OverlayPack'), $false); $fd = [Pack]::Unpack($ini.Joined('OverlayDataPack'), $false)
$fenceId = 1   # CYCL chain link ([OverlayTypes] 001)
foreach ($i in $fence) { $fo[$i] = $fenceId; $block[$i] = $true }
foreach ($i in $fence) { $m = 0; $b = 0; foreach ($d in -512, 1, 512, -1) { if ($fo[$i + $d] -eq $fenceId) { $m = $m -bor (1 -shl $b) }; $b++ }; $fd[$i] = $m }
$ini.SetPack('OverlayPack', [Pack]::PackData($fo, $false, 8192)); $ini.SetPack('OverlayDataPack', [Pack]::PackData($fd, $false, 8192))
$log.Add("prison fence: $($fence.Count) CYCL cells round $fx0,$fy0-$fx1,$fy1, gate at $($gate[0][0]),$($gate[0][1])")
# the rebels inside (hidden ally Allies1 until a player unit walks into the camp)
$rebels = 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE', 'SCFIRE'
$inside = @(); for ($x = $fx0 + 1; $x -lt $fx1; $x++) { for ($y = $fy0 + 1; $y -lt $fy1; $y++) { $inside += , @($x, $y) } }
$ri = 0
foreach ($c in ($inside | Sort-Object { - ($_[0] - $jl[0]) })) {
    if ($ri -ge $rebels.Count) { break }
    if (-not (Buildable $c[0] $c[1])) { continue }
    Occupy $c[0] $c[1] 1 1
    $script:units.Add((New-Object 'Collections.Generic.KeyValuePair[string,string]' "$($script:units.Count)", "Allies1,$($rebels[$ri]),256,$($c[0]),$($c[1]),64,Sleep,None,0,-1,0,-1,0,0")); $ri++
}
$log.Add("prison: $ri rebels inside the fence")
foreach ($o in @(@(-3, 0), @(3, 1))) { Place-AtWp 'GDI' 'SCBUNK' 34 0 'None' 256 0 $o[0] $o[1] | Out-Null }
Squad 'GDI' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCGOLI') 34 0 3 'Area Guard'

# ================================================================ the Confederate garrison on the SE plateau
$cc = Place-AtWp 'GDI' 'SCCC' 37 1 'ARKA3G14'
Place-AtWp 'GDI' 'SCCOMS' 37 0 'None' 256 0 4 1 | Out-Null
Place-AtWp 'GDI' 'SCBARR' 38 1 | Out-Null
Place-AtWp 'GDI' 'SCFACT' 39 1 | Out-Null
Place-AtWp 'GDI' 'SCMSHP' 39 0 'None' 256 0 4 1 | Out-Null
Place-AtWp 'GDI' 'SCSTAR' 41 1 'None' 256 0 5 -1 | Out-Null
Place-AtWp 'GDI' 'SCNION' 42 1 'None' 256 0 -2 -6 | Out-Null   # the garrison's planetary Ion Cannon (SC neutral art)
Place-AtWp 'GDI' 'SCEBAY' 37 1 'None' 256 0 -7 -2 | Out-Null
Place-AtWp 'GDI' 'SCACAD' 38 1 'None' 256 0 6 3 | Out-Null
foreach ($o in @(@(-3, 0), @(1, -4), @(-6, 3), @(2, 4), @(-2, -6))) { Place-AtWp 'GDI' 'SCDEPO' 53 1 'None' 256 0 $o[0] $o[1] | Out-Null }
foreach ($o in @(@(2, -3), @(3, 3))) { Place-AtWp 'GDI' 'SCBUNK' 40 0 'None' 256 0 $o[0] $o[1] | Out-Null }
Place-AtWp 'GDI' 'SCBUNK' 41 0 'None' 256 0 0 -2 | Out-Null
# missile turrets: detectors (as in StarCraft), so the garrison itself sees Kerrigan; the last assault is loud anyway
foreach ($t in @(@(40, 5, 0), @(41, 3, 2), @(37, -3, 5), @(38, -4, 0))) { Place-AtWp 'GDI' 'SCMTUR' $t[0] 0 'None' 256 0 $t[1] $t[2] | Out-Null }
Place-AtWp 'GDI' 'SCSIEGB' 40 0 'None' 256 0 6 -3 | Out-Null
Place-AtWp 'GDI' 'SCSIEGB' 41 0 'None' 256 0 -3 3 | Out-Null
Squad 'GDI' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE') 40 4 1 'Area Guard'
Squad 'GDI' @('SCMARINE', 'SCMARINE', 'SCMARINE', 'SCMARINE', 'SCFIRE', 'SCFIRE') 37 0 5 'Area Guard'
Squad 'GDI' @('SCGOLI', 'SCGOLI', 'SCGOLI') 41 -2 2 'Area Guard'
Squad 'GDI' @('SCVULT', 'SCVULT') 39 0 4 'Area Guard'
Squad 'GDI' @('SCSIEGE') 38 0 4 'Area Guard'
# the psi emitter in the SE valley under the ramp (Mengsk's bait)
Place-AtWp 'Soviet1' 'ARKPSIE' 43 0 'ARKA3G12' | Out-Null

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
Zone 'ARKA3G08' 28 0 3      # tower 1: Kerrigan at the tower
Zone 'ARKA3G09' 30 0 3      # tower 2
$nIn = 0; foreach ($c in $inside) { $key = "$($c[1] * 1000 + $c[0])"; if (-not $ini.Get('CellTags', $key, $null)) { $ini.Set('CellTags', $key, 'ARKA3G10'); $nIn++ } }
foreach ($c in $gate) { $ini.Set('CellTags', "$($c[1] * 1000 + $c[0])", 'ARKA3G10'); $nIn++ }
$log.Add("zone ARKA3G10 (prison camp inside the fence + gate): $nIn cells")
Zone 'ARKA3G13' 43 0 5      # the emitter found
Zone 'ARKA3G15' 35 0 8      # the outskirts
Zone 'ARKA3G16' 24 0 5      # the Sons of Korhal camp

# ================================================================ dialogue ([Tutorial] of the map, numbers 9301-9399)
$textNo = 9300
function Say([string]$s) { if ($s -match '[^\x20-\x7E]') { throw "non-ASCII text: $s" }; $script:textNo++; if ($script:textNo -gt 9399) { throw "text numbers above 9399" }; $ini.Set('Tutorial', "$script:textNo", $s); $script:textNo }

# ================================================================ taskforces, scripts, teams
$tfN = 0; $tmN = 0
function Team($name, $house, $spawnWp, [string[]]$members, [string[]]$script, $tag = $null) {
    $script:tfN++; $script:tmN++
    $tf = 'ARKA3F{0:D2}' -f $script:tfN; $sc = 'ARKA3S{0:D2}' -f $script:tfN; $tm = 'ARKA3M{0:D2}' -f $script:tmN
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
# script lines: 16,N attack-move; 0,3 harvesters; 11,14 hunt. NOT 1,N for ground teams (pitfall 10); 1,N only for flyers
$Ma = 'SCMARINE'; $Zl = 'SCZLNG'; $Zh = 'SCZHYL'
$tmRaid  = Team 'Patrol Konfederacji na rafinerie' 'GDI' 48 @('SCVULT', 'SCVULT', $Ma, $Ma) @('16,14', '0,3', '11,14')
$tmResp  = Team 'Alarm: poscig przy wiezy' 'GDI' 48 @($Ma, $Ma, $Ma, 'SCVULT', 'SCVULT') @('16,28', '16,57', '11,14')
$tmAlarm = Team 'Alarm: oddzial na baze' 'GDI' 48 @($Ma, $Ma, $Ma, $Ma, 'SCGOLI', 'SCGOLI', 'SCSIEGE', 'SCVULT') @('16,21', '16,10', '11,14')
$tmSoK   = Team 'Synowie Korhalu: natarcie od zachodu' 'Soviet' 23 @($Ma, $Ma, $Ma, $Ma, 'SCFIRE', 'SCFIRE', 'SCGOLI') @('16,61', '16,26', '16,58', '16,40', '16,37', '11,14')
$tmZS    = Team 'Zergi z poludnia na garnizon' 'Nod1' 44 @($Zl, $Zl, $Zl, $Zl, $Zl, $Zl, $Zh, $Zh, $Zh) @('16,59', '16,37', '11,14')
$tmZE    = Team 'Zergi ze wschodu na garnizon' 'Nod1' 45 @($Zl, $Zl, $Zl, $Zl, $Zl, $Zl, 'SCZULT') @('16,41', '16,37', '11,14')
$tmZB    = Team 'Zergi na rafinerie gracza' 'Nod1' 46 @($Zl, $Zl, $Zl, $Zl, $Zh, $Zh) @('16,14', '0,3', '11,14')
$tmZM    = Team 'Mutaliski nad garnizon' 'Nod1' 47 @('SCZMUT', 'SCZMUT', 'SCZMUT') @('1,40', '11,14')

# ================================================================ triggers
$vars = 'Wieza 1 wylaczona', 'Wieza 2 wylaczona', 'Alarm', 'Wiezienie otwarte', 'Zergi', 'Nadajnik odkryty', 'Nadajnik zniszczony',
    'Garnizon zniszczony', 'Wieze gotowe', 'Cel garnizonu dany'
for ($i = 0; $i -lt $vars.Count; $i++) { $ini.Set('VariableNames', "$i", "$($vars[$i]),0") }
$trN = 0; $trig = [ordered]@{}
function Ev([int]$id, $p = 0) { "$id,0,$p" }
function Act([int]$id, $p = 0, [int]$kind = 0, [int]$w = 0) { "$id,$kind,$p,0,0,0,0,$(WpLetter $w)" }
function Text($s) { Act 11 (Say $s) }
function Reinf($team, $w) { Act 80 $team 1 $w }
function Enable($t) { Act 53 $t 2 }
function Disable($t) { Act 54 $t 2 }
function Trigger($key, $name, [string[]]$events, [string[]]$actions, $house = 'Allies', [switch]$Disabled, [switch]$Repeat, $tag = $null, $diff = '1,1,1', $link = $null) {
    $script:trN++; $id = 'ARKA3T{0:D2}' -f $script:trN
    $name = $name -replace ',', ' -'
    if (-not $tag) { $tag = 'ARKA3G{0:D2}' -f (30 + $script:trN) }
    $script:trig[$key] = @{ Id = $id; Name = $name; House = $house; Events = $events; Actions = $actions; Disabled = [bool]$Disabled; Repeat = [bool]$Repeat; Tag = $tag; Diff = $diff; Link = $link }
}
. "$tools\MissionKit.ps1"
$GameSecPerReal = 4.5   # ARKA 0 test 2026-10-29: 3 was still too fast to read
Add-ScAirArmor
Add-RevealCrate $crate[0] $crate[1]
foreach ($mc in @(@(50, 2000, 'Kasa celna przedmiesc Antigi: +2000 kredytow.'), @(51, 1500, 'Skrytka przemytnikow na wyspie: +1500 kredytow.'),
        @(52, 2500, 'Skrytka buntownikow z Antigi: +2500 kredytow.'), @(53, 3000, 'Zold garnizonu Konfederacji: +3000 kredytow.'))) {
    $s = Find-Spot $wp[$mc[0]][0] $wp[$mc[0]][1] 1 1 0 $false; Occupy $s[0] $s[1] 1 1
    Add-MoneyCrate $s[0] $s[1] $mc[1] $mc[2]
}

# --- opening: Mengsk introduces Kerrigan, objective 1
Trigger 'i1' 'Start: Kerrigan' @((Ev 13 1)) @((Act 48 1 0 18),
    (Text 'Mengsk (ekran): Antiga powstaje przeciw Konfederacji. Porucznik Sarah Kerrigan poprowadzi zwiad. Prosze jej sluchac jak mnie.'), (Enable 'i2'))
Trigger 'i2' 'Start 2' @((Ev 13 5)) @((Text 'Sarah Kerrigan (do Tanyi, z usmiechem): Myslisz bardzo glosno, panno Adams. Glownie o tym, kogo gdzie zastrzelic.'), (Enable 'i3')) -Disabled
Trigger 'i3' 'Start 3' @((Ev 13 5)) @((Text 'Tanya: Wyjdz z mojej glowy, zanim ja wejde do twojej. Kula.'), (Enable 'i4')) -Disabled
Trigger 'i4' 'Start 4' @((Ev 13 5)) @((Text '(Raynor nie spuszcza Kerrigan z oczu. Kerrigan to widzi.)'), (Enable 'i5')) -Disabled
Trigger 'i5' 'Start 5: garnizon' @((Ev 13 5)) @((Act 17 28), (Act 17 30),
    (Text 'Mengsk (ekran): Garnizon Konfederacji siedzi na plaskowyzu na poludniowym wschodzie. Ale najpierw musi oslepnac.'), (Enable 'i6')) -Disabled
Trigger 'i6' 'Start 6: cel 1' @((Ev 13 5)) @((Act 55 6 0 28), (Act 55 6 0 30),
    (Text 'Cel 1: Kerrigan wylacza 2 wieze obserwacyjne Konfederacji. Wystarczy, ze do nich podejdzie.'), (Enable 'i7')) -Disabled
Trigger 'i7' 'Start 7: maskowanie' @((Ev 13 5)) @((Text 'Wskazowka: Kerrigan jest niewidzialna, dopoki nie strzela. Wieze widza ukrytych z bliska, ale same nie strzelaja. Omin straze.'), (Enable 'i8')) -Disabled
Trigger 'i8' 'Start 8: alarm' @((Ev 13 5)) @((Text 'Jesli straze wykryja Kerrigan albo ktos ostrzela wieze, garnizon oglosi alarm i bedzie wysylal wieksze oddzialy.'), (Enable 'i9')) -Disabled
Trigger 'i9' 'Start 9: baza' @((Ev 13 5)) @((Act 55 6 0 13),
    (Text 'Plk Stavros: Od dzis mamy ladowisko i smiglowce. Placu budowy nie mamy: to ma byc cicha robota, nie oblezenie.'), (Enable 'i10')) -Disabled
Trigger 'i10' 'Start 10: straty' @((Ev 13 5)) @((Text 'Einstein, Tanya, Raynor, Kerrigan i ARKA musza przetrwac.')) -Disabled

# --- losing (the heroes' tags: Kerrigan and Tanya drive chains, see below)
Trigger 'arkaDead' 'ARKA zniszczona' @((Ev 29)) @((Text 'Plk Stavros: Rdzen ARKI zniszczony. Nie ma juz drogi do domu.'), (Act 2 $H.Allies)) -tag 'ARKA3G01'
Trigger 'rayDied' 'Raynor zginal' @((Ev 29)) @((Text 'Plk Stavros: Marszalek Raynor zginal. Bez niego nie mamy tu przyjaciol.'), (Act 2 $H.Allies)) -tag 'ARKA3G02'
Trigger 'einDied' 'Einstein zginal' @((Ev 29)) @((Text 'Plk Stavros: Einstein nie zyje. Nikt inny nie umie poprowadzic ARKI.'), (Act 2 $H.Allies)) -tag 'ARKA3G05'
Trigger 'allLost' 'Wszystko stracone' @((Ev 11 $H.Allies)) @((Act 2 $H.Allies))
# Kerrigan's tag (repeating): shot by the Confederates during the reconnaissance -> alarm; destroyed -> lost
Trigger 'kerAtt' 'Kerrigan wykryta' @((Ev 44 $H.GDI)) @((Act 56 2), (Text 'Sarah Kerrigan: Wykryli mnie! Wycofuje sie.'), (Disable 'kerAtt')) -tag 'ARKA3G04' -Repeat -link 'kerDied'
Trigger 'kerDied' 'Kerrigan zginela' @((Ev 29)) @((Text 'Mengsk (radio): Porucznik Kerrigan nie zyje. Byla mi potrzebna, Komandorze. Bardzo potrzebna.'), (Act 2 $H.Allies))
# Tanya's tag (repeating): finds the emitter once the Zerg come; destroyed -> lost
Trigger 'tanNear' 'Tanya przy nadajniku' @((Ev 34 43), (Ev 36 4)) @((Disable 'emiZone'), (Disable 'emiHint'), (Enable 'emi1'), (Disable 'tanNear')) -tag 'ARKA3G03' -Repeat -link 'tanDied'
Trigger 'tanDied' 'Tanya zginela' @((Ev 29)) @((Text 'Plk Stavros: Tanya nie zyje. Tracimy najlepszego zolnierza, jakiego mielismy.'), (Act 2 $H.Allies))

# --- the towers. A tower's tag (repeating) drives a chain: shot at -> alarm; (enabled by the ring) turned Neutral;
# destroyed -> counts, with the alarm. The ring zone round the tower: a player unit at the tower blinds it quietly. The
# house change runs in the tower's own chain (13 Elapsed 1, the cra12 pattern): a cell-sprung trigger would hand the
# entering unit to Change House. Pitfall 6: the "destroyed" trigger is off before the house change
foreach ($t in @(@(1, 0, 'ARKA3G06', 'ARKA3G08', 'pierwsza'), @(2, 1, 'ARKA3G07', 'ARKA3G09', 'druga'))) {
    $n = $t[0]; $v = $t[1]
    Trigger "tw${n}att" "Wieza $n ostrzelana" @((Ev 6)) @((Act 56 2), (Disable "tw${n}att")) -tag $t[2] -Repeat -link "tw${n}off"
    Trigger "tw${n}off" "Wieza $n slepa" @((Ev 13 1)) @((Disable "tw${n}dead"), (Disable "tw${n}att"), (Act 14 $H.Neutral), (Disable "tw${n}off")) -Disabled -link "tw${n}dead"
    Trigger "tw${n}dead" "Wieza $n zniszczona" @((Ev 29)) @((Act 56 $v), (Act 56 2), (Disable "ring$n"), (Disable "tw${n}att"),
        (Text "Plk Stavros: Wieza $n zniszczona. Halasliwie, ale skutecznie. Garnizon wie, ze tu jestesmy."), (Disable "tw${n}dead"))
    Trigger "ring$n" "Wieza $n wylaczona po cichu" @((Ev 1 $H.Allies), (Ev 37 $v)) @((Act 56 $v), (Disable "tw${n}att"), (Enable "tw${n}off"),
        (Text "Sarah Kerrigan: Wieza $($t[4]) slepa. Nikt niczego nie zauwazyl.")) -tag $t[3]
}
Add-CountProgress 'tow' @(0, 1) { param($k, $n) "Wieze obserwacyjne: $k z $n wylaczone." }
Trigger 'td1' 'Wieze gotowe' @((Ev 36 0), (Ev 36 1)) @((Act 56 8), (Disable 'kerAtt'),
    (Text 'Mengsk (radio): Obie wieze slepe. Swietna robota, poruczniku.'), (Enable 'td2'))
Trigger 'td2' 'Wieze gotowe 2: Synowie Korhalu' @((Ev 13 5)) @((Reinf $tmSoK 23), (Act 55 2 0 24), (Enable 'sokA'),
    (Text 'Mengsk (radio): Moi ludzie ruszaja z obozu na zachodzie. Pojda grobla na poludniowy zachod i uderza na garnizon.'), (Enable 'obj2')) -Disabled
Trigger 'obj2' 'Cel 2: wiezienie' @((Ev 13 5), (Ev 37 3)) @((Act 17 32), (Act 55 6 0 32),
    (Text 'Cel 2: uwolnij buntownikow z obozu jenieckiego Konfederacji na brzegu jeziora (poludniowy zachod). Wejdz za ogrodzenie.')) -Disabled
Trigger 'sokA' 'Synowie Korhalu: kolejne natarcie' @((Ev 13 540), (Ev 37 7)) @((Reinf $tmSoK 23)) -Disabled -Repeat

# --- the alarm: the guards saw Kerrigan or a tower was shot at
Trigger 'alarm' 'Alarm w garnizonie' @((Ev 36 2)) @((Reinf $tmResp 48), (Act 55 4 0 28), (Enable 'aWave'),
    (Text 'Radio Konfederacji: Alarm w garnizonie! Wszystkie oddzialy w gotowosci!'), (Enable 'al2'))
Trigger 'al2' 'Alarm 2' @((Ev 13 5)) @((Text 'Plk Stavros: Wykryli nas. Garnizon bedzie teraz wysylal wieksze oddzialy na baze.')) -Disabled
Trigger 'aWave' 'Alarm: oddzial na baze (powtarzany)' @((Ev 13 420), (Ev 37 7)) @((Reinf $tmAlarm 48), (Act 55 4 0 21)) -Disabled -Repeat

# --- raids on the economy (workflow/mission-design): a Confederate patrol on the refinery every 8 minutes
Trigger 'raid1' 'Patrol Konfederacji' @((Ev 13 700)) @((Reinf $tmRaid 48), (Act 55 3 0 48),
    (Text 'Plk Stavros: Patrol Konfederacji wyszedl z doliny. Idzie na nasza rafinerie.'), (Enable 'raid'))
Trigger 'raid' 'Patrol Konfederacji (powtarzany)' @((Ev 13 480), (Ev 37 7)) @((Reinf $tmRaid 48)) -Disabled -Repeat
Trigger 'raidHard' 'Patrol dodatkowy (trudny)' @((Ev 13 1100), (Ev 27 12)) @((Reinf $tmResp 48))

# --- the prison camp (Allies1 changes to the player as a whole: the trigger belongs to Allies1)
Trigger 'jailFree' 'Oboz jeniecki otwarty' @((Ev 1 $H.Allies)) @((Disable 'jailHit'), (Act 56 3), (Act 36 $H.Allies), (Enable 'jail2')) -house 'Allies1' -tag 'ARKA3G10'
Trigger 'jailHit' 'Blok wiezienny zniszczony' @((Ev 29)) @((Disable 'jailFree'), (Act 56 3), (Act 36 $H.Allies), (Enable 'jail2')) -house 'Allies1' -tag 'ARKA3G11'
Trigger 'jail2' 'Wiezienie 2' @((Ev 13 2)) @((Act 48 1 0 32),
    (Text 'Buntownik z Antigi: Dzieki, ludzie Mengska... czy kimkolwiek jestescie. Idziemy z wami!'), (Enable 'jail3')) -Disabled
Trigger 'jail3' 'Wiezienie 3: cel 2' @((Ev 13 5)) @((Text 'Cel 2 wykonany: buntownicy z obozu dolaczyli do was.')) -Disabled

# --- the garrison objective: after the prison or when the Zerg come, whichever is first
Trigger 'objG1' 'Cel garnizonu: po wiezieniu' @((Ev 36 3)) @((Enable 'objG'))
Trigger 'objG2' 'Cel garnizonu: przy Zergach' @((Ev 36 4)) @((Enable 'objG'))
Trigger 'objG' 'Cel 4: garnizon' @((Ev 13 30), (Ev 37 9)) @((Act 56 9), (Act 55 6 0 37),
    (Text 'Cel 4: zniszcz Command Center garnizonu Konfederacji na plaskowyzu na poludniowym wschodzie.')) -Disabled

# --- mid-mission: the Zerg (towers and prison done, or 30:00 on the clock)
Trigger 'zgo1' 'Zergi: po wiezach i wiezieniu' @((Ev 36 8), (Ev 36 3)) @((Enable 'zerg'))
Trigger 'zgo2' 'Zergi: najpozniej' @((Ev 13 1800)) @((Enable 'zerg'))
Trigger 'zerg' 'Zergi nadciagaja' @((Ev 13 60), (Ev 37 4)) @((Act 56 4), (Act 20 91), (Act 55 3 0 44),
    (Text 'Plk Stavros: Radar! Zergi z poludnia i ze wschodu. Ida prosto na garnizon Konfederacji... i troche na nas.'), (Enable 'zerg2')) -Disabled
Trigger 'zerg2' 'Zergi 2' @((Ev 13 5)) @((Text 'Jim Raynor: Zergi nie wybieraja celow. Cos je tam ciagnie.'), (Enable 'zerg3')) -Disabled
Trigger 'zerg3' 'Zergi 3: fale' @((Ev 13 5)) @((Text 'Sarah Kerrigan: Moze po prostu maja dobry gust, Jim.'),
    (Enable 'zS'), (Enable 'zE'), (Enable 'zB'), (Enable 'zM'), (Enable 'emiHint')) -Disabled
Trigger 'zS' 'Zergi z poludnia (powtarzane)' @((Ev 13 200), (Ev 37 6), (Ev 37 7)) @((Reinf $tmZS 44), (Act 55 3 0 44)) -house 'Nod1' -Disabled -Repeat
Trigger 'zE' 'Zergi ze wschodu (powtarzane)' @((Ev 13 280), (Ev 37 6), (Ev 37 7)) @((Reinf $tmZE 45)) -house 'Nod1' -Disabled -Repeat
Trigger 'zB' 'Zergi na rafinerie (powtarzane)' @((Ev 13 420), (Ev 37 6), (Ev 37 7)) @((Reinf $tmZB 46), (Act 55 3 0 46)) -house 'Nod1' -Disabled -Repeat
Trigger 'zM' 'Mutaliski (powtarzane)' @((Ev 13 620), (Ev 37 6), (Ev 37 7)) @((Reinf $tmZM 47)) -house 'Nod1' -Disabled -Repeat

# --- Kerrigan's box: found by Tanya (her tag), by any unit at it, or shown by Stavros 7 minutes into the Zerg
Trigger 'emiZone' 'Nadajnik znaleziony' @((Ev 1 $H.Allies), (Ev 36 4)) @((Disable 'emiHint'), (Enable 'emi1')) -tag 'ARKA3G13'
Trigger 'emiHint' 'Nadajnik: Stavros' @((Ev 13 420), (Ev 37 5)) @((Act 17 43), (Act 55 6 0 43),
    (Text 'Plk Stavros: Zergi zbiegaja sie w jeden punkt w dolinie pod garnizonem. Cos je tam wola.'), (Enable 'emi1')) -Disabled
Trigger 'emi1' 'Nadajnik 1: Tanya' @((Ev 13 3), (Ev 37 5)) @((Act 56 5), (Act 48 1 0 43),
    (Text 'Tanya (radio): Profesorze, Kerrigan postawila przy bazie Konfederacji jakies pudlo. Zergi leca do niego jak muchy do miodu.'), (Enable 'emi2')) -Disabled
Trigger 'emi2' 'Nadajnik 2: Einstein' @((Ev 13 5)) @((Text 'Einstein: Przyneta. Ten czlowiek uzywa potworow jak artylerii.'), (Enable 'emi3')) -Disabled
Trigger 'emi3' 'Nadajnik 3: Kerrigan' @((Ev 13 5)) @((Text 'Sarah Kerrigan (psionicznie, tylko do Raynora): Nie patrz tak na mnie, Jim. Ja tylko wykonuje rozkazy.'), (Enable 'emi4')) -Disabled
Trigger 'emi4' 'Nadajnik 4: wybor' @((Ev 13 5)) @((Text 'Cel dodatkowy (wybor): zniszcz psi-nadajnik, a Zergi przestana nadciagac, ale Mengsk sie wscieknie. Zostaw go, a bedzie trudniej.'), (Enable 'emi5')) -Disabled
Trigger 'emi5' 'Nadajnik 5: jak' @((Ev 13 5)) @((Text 'Wskazowka: nikt nie strzela do nadajnika sam z siebie. Zniszczysz go tylko rozkazem ataku albo C4 Tanyi.')) -Disabled
Trigger 'emiDead' 'Nadajnik zniszczony' @((Ev 29)) @((Act 56 6), (Disable 'zS'), (Disable 'zE'), (Disable 'zB'), (Disable 'zM'),
    (Text 'Plk Stavros: Nadajnik zniszczony. Zergi traca trop, nowe juz nie nadciagaja.'), (Enable 'emiD2')) -tag 'ARKA3G12'
Trigger 'emiD2' 'Nadajnik zniszczony 2: Mengsk' @((Ev 13 5)) @((Text 'Mengsk (radio): Kto zniszczyl moj nadajnik?! To byla moja przyneta, Komandorze. Zapamietam to.')) -Disabled

# --- town and camp lines (first visit)
Trigger 'town' 'Przedmiescia Antigi' @((Ev 1 $H.Allies)) @((Text 'Plk Stavros: Przedmiescia Antigi. Cywile nie strzelaja, ale posterunek Konfederacji na poludniu juz tak.')) -tag 'ARKA3G15'
Trigger 'camp' 'Oboz Synow Korhalu' @((Ev 1 $H.Allies)) @((Text 'Sierzant Synow Korhalu: Witamy w obozie. Zolnierze Mengska trzymaja zachodni brzeg.')) -tag 'ARKA3G16'

# --- the garrison falls: victory, the choice, the campfire
$waves = 'zS', 'zE', 'zB', 'zM', 'raid', 'aWave', 'sokA'
Trigger 'ccDead' 'Command Center garnizonu zniszczone' @((Ev 48)) (@((Act 56 7)) + @($waves | ForEach-Object { Disable $_ }) + @((Act 48 1 0 37),
    (Text 'Plk Stavros: Command Center garnizonu plonie! Konfederacja traci Antige.'), (Enable 'cc2'))) -tag 'ARKA3G14'
Trigger 'cc2' 'Garnizon 2: bez porazek' @((Ev 13 1)) (@('arkaDead', 'rayDied', 'einDied', 'kerDied', 'tanDied', 'allLost', 'kerAtt', 'tanNear') | ForEach-Object { Disable $_ }) -Disabled
Trigger 'jailAuto' 'Wiezniowie wychodza sami' @((Ev 36 7), (Ev 37 3)) @((Act 56 3), (Act 36 $H.Allies)) -house 'Allies1'
Trigger 'end1' 'Koniec 1: Mengsk' @((Ev 13 5), (Ev 36 7)) @((Text 'Mengsk (do kolonii): Obywatele Antigi! Konfederacja nie ma juz nad wami wladzy. Od dzis jestescie wolni.'), (Enable 'endA'), (Enable 'endB')) -Disabled
$trig['ccDead'].Actions = @($trig['ccDead'].Actions) + @(Enable 'end1')
Trigger 'endA' 'Koniec 2: nadajnik zniszczony' @((Ev 13 5), (Ev 36 6)) @((Text 'Mengsk (prywatnie): A pan, Komandorze, zniszczyl moj nadajnik. Nastepnym razem dostanie pan ode mnie mniej. Duzo mniej.'), (Enable 'fire1')) -Disabled
Trigger 'endB' 'Koniec 2: nadajnik zostal' @((Ev 13 5), (Ev 37 6)) @((Text 'Mengsk (prywatnie): Zostawil pan moj nadajnik. Doceniam zaufanie. Przy nastepnej okazji przysle panu moich ludzi.'), (Enable 'fire1')) -Disabled
Trigger 'fire1' 'Ognisko 1' @((Ev 13 5)) @((Text '(Noc. Raynor i Kerrigan rozmawiaja przy ognisku. Tanya patrzy na nich z daleka.)'), (Enable 'fire2')) -Disabled
Trigger 'fire2' 'Ognisko 2' @((Ev 13 5)) @((Text 'Sarah Kerrigan: Jim, nie wpuszczaj mnie za gleboko do swojej glowy. Tam jest balagan.'), (Enable 'fire3')) -Disabled
Trigger 'fire3' 'Ognisko 3' @((Ev 13 5)) @((Text 'Jim Raynor: Wejdz. Posprzatasz.'), (Enable 'winT')) -Disabled
Trigger 'winT' 'Wygrana' @((Ev 13 60)) @((Act 1 $H.Allies)) -Disabled

# objective reminders (user 2026-10-29: "for every mission, but do not overdo it")
Add-ObjectiveReminder 'remTow' 'Cel 1 (przypomnienie): Kerrigan ma podejsc do obu wiez obserwacyjnych (zaznaczone na radarze).' -From 'i6' -Until 8
Add-ObjectiveReminder 'remJail' 'Cel 2 (przypomnienie): uwolnij buntownikow z obozu jenieckiego na poludniowo-zachodnim brzegu.' -From 'obj2' -Until 3
Add-ObjectiveReminder 'remCC' 'Cel 4 (przypomnienie): zniszcz Command Center garnizonu na plaskowyzu na poludniowym wschodzie.' -From 'objG' -Until 7

Split-MultiText; Set-DialoguePacing
$quietWarn = Test-QuietDialogue
Add-Difficulty
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

# ================================================================ [Basic], briefing
$basic = [ordered]@{
    Name = 'ARKA #3: Sygnal z nieba'; Author = 'Zema (teren: Blizzard T5 Revolution + T6 Norad II)'; GameMode = 'Custom Map'; Player = 'Allies'
    Theme = 'RECN226M'; MultiplayerOnly = 'no'; HomeCell = '11'; AltHomeCell = '11'; MaxPlayer = '0'; MinPlayer = '2'; SkipMapSelect = 'yes'
    OneTimeOnly = 'yes'; EndOfGame = 'no'; SkipScore = 'no'; FreeRadar = 'yes'; RequiredAddOn = '1'; NextScenario = ''; AltNextScenario = ''
}
foreach ($k in $basic.Keys) { $ini.Set('Basic', $k, $basic[$k]) }
$ini.Sections.Remove('Briefing') | Out-Null; $ini.Order.Remove('Briefing') | Out-Null
$brief = @(
    'Antiga Prime, 2499. ARKA stoi na rowninie za miastem, a Antiga powstaje przeciw Konfederacji. Mengsk przedstawia swoja najlepsza agentke, porucznik Sarah Kerrigan.',
    '@@Najpierw zwiad: Kerrigan musi oslepic dwie wieze obserwacyjne garnizonu. Potem oboz jeniecki i sam garnizon na plaskowyzu.',
    '@@To cicha robota: nie ma placu budowy, jest tylko to, co stoi przy ARCE.')
for ($i = 0; $i -lt $brief.Count; $i++) { $ini.Set('Briefing', "$($i + 1)", $brief[$i]) }
$ini.Set('SpecialFlags', 'Visceroids', 'no')
$ini.Set('SpecialFlags', 'TiberiumGrows', 'yes')
$ini.Set('SpecialFlags', 'TiberiumSpreads', 'no')
foreach ($s in 'Preview', 'PreviewPack') { $ini.Sections.Remove($s) | Out-Null; $ini.Order.Remove($s) | Out-Null }

[IO.File]::WriteAllText($Out, $ini.Write(), $enc)
$log.Add("written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB): $($trig.Count) triggers, $tmN teams, $($textNo - 9300) texts, $($structs.Count) buildings, $($units.Count) units, $($infs.Count) infantry")

# ================================================================ client entry: INI\BattleE.ini (merge; other ARKA missions keep their entries)
if (-not $NoBattle) {
    $bf = "$game\INI\BattleE.ini"
    $b = if (Test-Path $bf) { [Ini]::Load($bf) } else { New-Object Ini }
    if (-not $b.Get('Battles', 'ARKAH', $null)) { $b.Set('Battles', 'ARKAH', 'HEADER_ARKA'); $b.Set('HEADER_ARKA', 'Description', 'ARKA: Blad znaku'); $b.Set('HEADER_ARKA', 'Categories', 'CAT_SA') }
    $b.Set('Battles', 'ARKA03', 'M_ARKA03')
    $m = [ordered]@{ CD = '-1'; Scenario = 'Maps/Missions/arka03.map'; Description = 'ARKA #3: Sygnal z nieba'; Author = 'Zema'; RequiredAddon = '1'; Side = '2'
        IconPath = 'alliesicon.png'; PlayerAlwaysOnNormalDifficulty = 'yes'; Categories = 'CAT_SA'
        LongDescription = 'Antiga Prime, 2499. Antiga powstaje, a Mengsk przedstawia porucznik Sarah Kerrigan. @@Cicha robota: Kerrigan oslepia wieze obserwacyjne garnizonu, potem oboz jeniecki, psi-nadajnik i Command Center Konfederacji. Bez placu budowy.' }
    foreach ($k in $m.Keys) { $b.Set('M_ARKA03', $k, $m[$k]) }
    $head = "; ARKA campaign (Claude, Modding/wiki/plans/campaign-arka). Extra battle file read by the client`r`n; (Resources/ClientDefinitions.ini BattleFSFileName=BattleE.ini); written by Modding/tools/build-arka0*-mission.ps1.`r`n"
    [IO.File]::WriteAllText($bf, $head + $b.Write(), [Text.Encoding]::ASCII)
    $log.Add("BattleE.ini: M_ARKA03 merged (entries: " + (($b.Section('Battles') | ForEach-Object { $_.Key }) -join ',') + ")")
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
foreach ($kv in $ini.Section('Actions')) { if ($kv.Value.Length -gt 400) { $log.Add("FAIL [Actions] $($kv.Key) is $($kv.Value.Length) chars (> 400)"); $fail++ } }
foreach ($kv in $ini.Section('Triggers')) { if (($kv.Value -split ',').Count -ne 8) { $log.Add("FAIL trigger $($kv.Key) has $(($kv.Value -split ',').Count) fields"); $fail++ } }
foreach ($ln in $listNames) { foreach ($kv in $ini.Section($ln)) { if (-not ($ini.Has($kv.Value) -or $rules.ContainsKey($kv.Value))) { $log.Add("FAIL $ln entry $($kv.Value) has no section"); $fail++ } } }
foreach ($kv in $ini.Section('TeamTypes')) {
    $tm = $kv.Value; $airN = @($ini.Section($ini.Get($tm, 'TaskForce', '')) | Where-Object { $_.Value -match ',(SCZMUT)$' }).Count
    $s1 = @($ini.Section($ini.Get($tm, 'Script', '')) | Where-Object { $_.Key -match '^\d+$' -and $_.Value -match '^1,' }).Count
    if ($s1 -and -not $airN) { $log.Add("FAIL ground team $tm ($($ini.Get($tm, 'Name', ''))) uses script action 1"); $fail++ }
}
foreach ($ln in 'InfantryTypes', 'VehicleTypes', 'BuildingTypes', 'AircraftTypes') {
    foreach ($kv in $ini.Section($ln)) { $img = $ini.Get($kv.Value, 'Image', $kv.Value); if (-not $art.ContainsKey($img)) { $log.Add("FAIL $($kv.Value): no [$img] in Art.ini (would be invisible)"); $fail++ } }
}
foreach ($t in 'RAPDOX', 'AHPAD', 'AWEAP', 'RADOME', 'RATENT', 'RAPOWR', 'RAPROC') { $img = if ($rules[$t]['Image']) { $rules[$t]['Image'] } else { $t }; if (-not $art.ContainsKey($img)) { $log.Add("FAIL $t has no art [$img]"); $fail++ } }
foreach ($s in $scTypes) { foreach ($k in 'Prerequisite', 'BuiltAt') { $v = $ini.Get($s, $k, $null); if ($v) { foreach ($tok in ($v -split ',')) { $tok = $tok.Trim(); if ($tok -and $tok -notmatch '^(POWER|FACTORY|BARRACKS|RADAR|TECH|PROC|none)$' -and -not ($ini.Has($tok) -or $rules.ContainsKey($tok))) { $log.Add("FAIL $s $k names $tok"); $fail++ } } } } }
$log.Add("Kerrigan HP $($ini.Get('ARKKERR', 'Strength', '?')), cloakable $($ini.Get('ARKKERR', 'Cloakable', '?')); tower sight $($ini.Get('ARKTOWR', 'Sight', '?')) with sensors")
$log.Add($(if ($fail) { "CHECKS: $fail FAIL" } else { 'CHECKS: PASS (types defined, teams exist, every tag has a trigger, prerequisites resolve)' }) + "; text timeline: $textWarn WARN; quiet dialogue: $quietWarn WARN")
$log | Set-Content "$work\log.txt" -Encoding UTF8
$log | Where-Object { $_ -notmatch '^building ' }

if ($Render) {
    $dir = "$game\Map Editor\Map Renderer"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$Out`" -o arka03_mission -d `"$work`" -p -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "renderer timed out" }
    "render: $work\arka03_mission.png"
}
