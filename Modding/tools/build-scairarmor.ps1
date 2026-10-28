# General rules for StarCraft flyers (user 2026-10-28):
#   1. Allied anti-air does not fire at SC flyers on its own (no guard acquisition, no retaliation); a turret or unit that
#      the player orders to attack one fires and hits.
#   2. Dragoons cannot shoot the Overlord at all (not even on an order).
# Done with Vinifera armor types (Rules [ArmorTypes]; warhead keys Modifier/ForceFire/Retaliate/PassiveAcquire.<armor>,
# looked up per hit: a value the warhead does not set comes from the armor's BaseArmor, recursively; Vinifera
# src/new/verses/verses.h Get_Value). Vinifera runs [ArmorTypes] in every rules pass (Rules, game options, map code,
# map: "Rules: Processing ArmorTypes" 4x in the log), so new armors work from the faction file and from a mission map.
#   - every SC flyer (ID SC*, Fly or Jumpjet locomotor: lifted Terran buildings) gets sc_air_<its old armor> with BaseArmor=<old armor>: every other warhead
#     does exactly what it did; the Overlords (SCZOVL, SCZOVL2, Yggdrasill SCZHYG) get sc_overlord (BaseArmor=sc_air_heavy)
#   - Allied AA (types owned only by Allies/GDI1 with an AA=yes weapon: RAAGUN, MFLAK, CTNK, PTNK, TTNKMSL, FRIGATE,
#     HVCT) fire copies of their warheads (AL_<warhead>) with PassiveAcquire.sc_air_*=no, Retaliate.sc_air_*=no,
#     ForceFire=yes; where the plain warhead did 0% to a flyer armor (FlakWH: wood 0%, light -> BaseArmor wood) the copy
#     does what it does to medium, so an ordered shot hurts. A weapon used by other owners too is copied (AL_<weapon>)
#     and only the Allied type gets the copy; a weapon used only by Allied types gets the new warhead in place.
#   - the Dragoon weapons (SCPPhase, SCPPhaseU) get SCPDragWH, a copy of SCPPhaseWH (shared with the Arbiter) with
#     Modifier/ForceFire/Retaliate/PassiveAcquire.sc_overlord off.
# Writes the block "; >>> SC air armor" at the end of INI/Map Code/Terran Faction.ini and INI/Game Options/StarCraft.ini
# (each with the SC types that file defines; later keys win). ARKA missions copy the SC types into the map and get the
# rest from Add-ScAirArmor (tools/MissionKit.ps1, reads this block). Re-run after any SC generator that adds flyers or
# changes their Armor=, then rebuild the ARKA missions. Wiki: engine/air-armor.
# Usage: build-scairarmor.ps1 [-WhatIf]
param([switch]$WhatIf)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path "$PSScriptRoot\..\..").Path
$faction = "$game\INI\Map Code\Terran Faction.ini"; $scopt = "$game\INI\Game Options\StarCraft.ini"; $rulesPath = "$game\INI\Rules.ini"
$latin = [Text.Encoding]::GetEncoding(28591)
$begin = '; >>> SC air armor'; $end = '; <<< SC air armor'
$flyLoco = '{4A582746-9839-11d1-B709-00A024DDAFD1}', '{92612C46-F71F-11d1-AC9F-006008055BB5}'   # Fly; Jumpjet (lifted Terran buildings)
$alliedHouses = 'Allies', 'Allies1', 'Allies2', 'GDI1'
$overlords = 'SCZOVL', 'SCZOVL2', 'SCZHYG'
$dragoonWeapons = 'SCPPhase', 'SCPPhaseU'

function Backup([string]$path) { if (-not (Test-Path "$path.bak")) { Copy-Item $path "$path.bak" } }
function Nl([string]$path) { if ([IO.File]::ReadAllText($path, $latin).Contains("`r`n")) { "`r`n" } else { "`n" } }
function Set-Block([string]$path, [string]$body) {
    $nl = Nl $path
    $t = [IO.File]::ReadAllText($path, $latin)
    $block = ($begin + $nl + ($body.TrimEnd() -replace "`r?`n", $nl) + $nl + $end + $nl)
    $a = $t.IndexOf($begin)
    if ($a -ge 0) { $b = $t.IndexOf($end, $a); $b = $t.IndexOf("`n", $b) + 1; $t = $t.Substring(0, $a) + $block + $t.Substring($b) }
    else { if (-not $t.EndsWith("`n")) { $t += $nl }; $t += $nl + $block }
    [IO.File]::WriteAllText($path, $t, $latin)
}
# section -> key -> value (repeated sections merged, later key wins, as the client does), ignoring this script's own block
function Read-Sections([string]$path) {
    $t = [IO.File]::ReadAllText($path, $latin); $a = $t.IndexOf($begin)
    if ($a -ge 0) { $b = $t.IndexOf("`n", $t.IndexOf($end, $a)) + 1; $t = $t.Substring(0, $a) + $t.Substring($b) }
    $d = @{}; $sec = $null
    foreach ($l in ($t -split "`r?`n")) {
        if ($l -match '^\[([^\]]+)\]') { $sec = $Matches[1]; if (-not $d.ContainsKey($sec)) { $d[$sec] = [ordered]@{} }; continue }
        if ($sec -and $l -match '^\s*([^;=\s][^;=]*?)\s*=\s*([^;\t]*)') { $d[$sec][$Matches[1]] = $Matches[2].Trim() }
    }
    return $d
}
$rules = Read-Sections $rulesPath
$sco = Read-Sections $scopt
$fac = Read-Sections $faction
# effective view: Rules, then StarCraft.ini, then the faction file ($Inherits resolved inside Rules, where DTA uses it)
function Resolve([string]$sec) {
    $chain = @(); $s = $sec
    while ($s -and $rules.ContainsKey($s) -and $chain.Count -lt 6) { $chain = , $s + $chain; $s = $rules[$s]['$Inherits'] }
    $m = [ordered]@{}
    foreach ($c in $chain) { foreach ($k in $rules[$c].Keys) { if ($k -ne '$Inherits') { $m[$k] = $rules[$c][$k] } } }
    foreach ($f in $sco, $fac) { if ($f.ContainsKey($sec)) { foreach ($k in $f[$sec].Keys) { $m[$k] = $f[$sec][$k] } } }
    return $m
}
function Has([string]$sec) { $rules.ContainsKey($sec) -or $sco.ContainsKey($sec) -or $fac.ContainsKey($sec) }

# ---------------------------------------------------------------- armor table (for the 0% check)
$vanilla = 'none', 'wood', 'light', 'heavy', 'concrete'   # order of the old Verses= list
$armorBase = @{}; $armorMod = @{}
foreach ($a in @($vanilla) + @($rules['ArmorTypes'].Values)) {
    $s = if ($rules.ContainsKey($a)) { $rules[$a] } else { @{} }
    $armorBase[$a] = $s['BaseArmor']; $armorMod[$a] = if ($s['Modifier']) { $s['Modifier'] } else { '100%' }
}
function Pct([string]$v) { $v = $v.Trim(); if ($v.EndsWith('%')) { [double]$v.TrimEnd('%') } else { 100 * [double]$v } }
function Mod($wh, [string]$armor) {
    if ($wh.Contains("Modifier.$armor")) { return Pct $wh["Modifier.$armor"] }
    $i = [array]::IndexOf($vanilla, $armor)
    if ($i -ge 0 -and $wh['Verses']) { $v = @($wh['Verses'] -split ','); if ($i -lt $v.Count -and $v[$i].Trim()) { return Pct $v[$i] } }
    if ($armorBase[$armor]) { return Mod $wh $armorBase[$armor] }
    return Pct $armorMod[$armor]
}

# ---------------------------------------------------------------- SC flyers
$typeLists = 'BuildingTypes', 'VehicleTypes', 'InfantryTypes', 'AircraftTypes'
$all = @(); foreach ($ln in $typeLists) { foreach ($f in $rules, $sco, $fac) { if ($f.ContainsKey($ln)) { $all += @($f[$ln].Values) } } }
$all = @($all | Where-Object { $_ } | Select-Object -Unique)
$flyers = [ordered]@{}   # type -> new armor
foreach ($t in $all) {
    if ($t -notlike 'SC*' -or -not (Has $t)) { continue }
    $r = Resolve $t
    if ($flyLoco -notcontains $r['Locomotor']) { continue }
    $old = if ($r['Armor']) { $r['Armor'] } else { 'none' }
    if ($old -like 'sc_*') { throw "[$t] Armor=$old already" }
    $flyers[$t] = if ($overlords -contains $t) { 'sc_overlord' } else { "sc_air_$old" }
}
foreach ($o in $overlords) { if (-not $flyers.Contains($o)) { throw "Overlord type $o is not a flyer here" } }
$airArmors = @($flyers.Values | Where-Object { $_ -ne 'sc_overlord' } | Select-Object -Unique | Sort-Object)
if ($airArmors -notcontains 'sc_air_heavy') { $airArmors += 'sc_air_heavy' }   # base of sc_overlord

# ---------------------------------------------------------------- Allied anti-air
$slots = 'Primary', 'Secondary', 'ElitePrimary', 'EliteSecondary'
function Is-Allied($r) { $o = @($r['Owner'] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }); $o.Count -gt 0 -and $o -contains 'Allies' -and @($o | Where-Object { $alliedHouses -notcontains $_ }).Count -eq 0 }
function Is-AA([string]$w) { if (-not $w -or -not (Has $w)) { return $false }; $p = (Resolve $w)['Projectile']; $p -and (Has $p) -and (Resolve $p)['AA'] -eq 'yes' }
$users = @{}   # weapon -> list of "type" using it in any slot
foreach ($t in $all) { if (-not (Has $t)) { continue }; $r = Resolve $t; foreach ($s in $slots) { $w = $r[$s]; if ($w) { if (-not $users.ContainsKey($w)) { $users[$w] = New-Object Collections.Generic.List[string] }; $users[$w].Add($t) } } }
$alliedAA = @()   # rows: type, slot, weapon
foreach ($t in $all) {
    if (-not (Has $t)) { continue }; $r = Resolve $t
    if (-not (Is-Allied $r)) { continue }
    foreach ($s in $slots) { if (Is-AA $r[$s]) { $alliedAA += [pscustomobject]@{ Type = $t; Slot = $s; Weapon = $r[$s] } } }
}
if ($alliedAA.Count -eq 0) { throw "no Allied anti-air found" }

$out = New-Object Text.StringBuilder
function L([string]$s = '') { [void]$out.AppendLine($s) }
function Sec([string]$name, $keys) { L; L "[$name]"; foreach ($k in $keys.Keys) { L "$k=$($keys[$k])" } }

$newWH = [ordered]@{}     # clone warhead -> keys
$newWeap = [ordered]@{}   # clone weapon -> keys
$weapWH = [ordered]@{}    # weapon edited in place -> new warhead
$typeSlot = [ordered]@{}  # type -> slot -> clone weapon
$rows = @()
foreach ($x in $alliedAA) {
    $w = Resolve $x.Weapon; $wh = $w['Warhead']
    if (-not $wh -or -not (Has $wh)) { throw "weapon $($x.Weapon) has no warhead" }
    $alWH = "AL_$wh"
    if (-not $newWH.Contains($alWH)) {
        $k = Resolve $wh
        foreach ($a in $airArmors) {
            $base = $a.Substring(7)
            if ((Mod $k $base) -le 0) { $med = Mod $k 'medium'; if ($med -gt 0) { $k["Modifier.$a"] = "$med%" } }
            $k["ForceFire.$a"] = 'yes'; $k["Retaliate.$a"] = 'no'; $k["PassiveAcquire.$a"] = 'no'
        }
        $newWH[$alWH] = $k
    }
    $shared = @($users[$x.Weapon] | Where-Object { -not (Is-Allied (Resolve $_)) } | Select-Object -Unique)
    if ($shared.Count -eq 0) { $weapWH[$x.Weapon] = $alWH; $how = 'in place' }
    else {
        $cw = "AL_$($x.Weapon)"
        if (-not $newWeap.Contains($cw)) { $c = Resolve $x.Weapon; $c['Warhead'] = $alWH; $newWeap[$cw] = $c }
        if (-not $typeSlot.Contains($x.Type)) { $typeSlot[$x.Type] = [ordered]@{} }
        $typeSlot[$x.Type][$x.Slot] = $cw; $how = "copy $cw (also: $($shared -join ','))"
    }
    $rows += [pscustomobject]@{ Type = $x.Type; Slot = $x.Slot; Weapon = $x.Weapon; Warhead = "$wh -> $alWH"; How = $how }
}

# ---------------------------------------------------------------- Dragoon vs Overlord
$dragWH = 'SCPDragWH'
$dk = $null
foreach ($w in $dragoonWeapons) {
    $r = Resolve $w; if (-not $r['Warhead']) { throw "Dragoon weapon $w not found" }
    if (-not $dk) { $dk = Resolve $r['Warhead']; $dragFrom = $r['Warhead'] }
    elseif ($r['Warhead'] -ne $dragFrom) { throw "Dragoon weapons use different warheads" }
}
$dk['Modifier.sc_overlord'] = '0%'; $dk['ForceFire.sc_overlord'] = 'no'; $dk['Retaliate.sc_overlord'] = 'no'; $dk['PassiveAcquire.sc_overlord'] = 'no'

# ---------------------------------------------------------------- block text per file
function Build([hashtable]$own) {
    # $own: the file's sections; SC types and SC weapons go only into the file that defines them
    $script:out = New-Object Text.StringBuilder
    L '; Generated by Modding/tools/build-scairarmor.ps1 (wiki engine/air-armor): SC flyers get their own Vinifera armor'
    L '; (BaseArmor = old armor, so other warheads hit them as before). Allied AA does not acquire or retaliate against'
    L '; them, an ordered shot hits; Dragoons cannot fire at the Overlord. Do not edit: re-run the script.'
    L '[ArmorTypes]'
    $i = 0; foreach ($a in @($airArmors) + 'sc_overlord') { $i++; L "SCAir$i=$a" }
    foreach ($a in $airArmors) { Sec $a ([ordered]@{ BaseArmor = $a.Substring(7) }) }
    Sec 'sc_overlord' ([ordered]@{ BaseArmor = 'sc_air_heavy' })
    L; L '; SC flyers'
    foreach ($t in $flyers.Keys) { if ($own.ContainsKey($t)) { Sec $t ([ordered]@{ Armor = $flyers[$t] }) } }
    L; L '; Allied anti-air: own warheads that do not acquire SC flyers'
    foreach ($n in $newWH.Keys) { Sec $n $newWH[$n] }
    foreach ($n in $newWeap.Keys) { Sec $n $newWeap[$n] }
    foreach ($w in $weapWH.Keys) { Sec $w ([ordered]@{ Warhead = $weapWH[$w] }) }
    foreach ($t in $typeSlot.Keys) { Sec $t $typeSlot[$t] }
    if (@($dragoonWeapons | Where-Object { $own.ContainsKey($_) }).Count) {
        L; L "; Dragoon: $dragFrom without the Overlord ($dragFrom stays for the Arbiter)"
        Sec $dragWH $dk
        foreach ($w in $dragoonWeapons) { if ($own.ContainsKey($w)) { Sec $w ([ordered]@{ Warhead = $dragWH }) } }
    }
    return $script:out.ToString()
}

$flyers.GetEnumerator() | Group-Object Value | ForEach-Object { "{0,-14} {1}" -f $_.Name, (($_.Group | ForEach-Object Key) -join ' ') }
$rows | Format-Table -AutoSize | Out-String -Width 220
$facBody = Build $fac; $scoBody = Build $sco
if ($WhatIf) { $facBody; return }
if (Get-Process -Name game -ErrorAction SilentlyContinue) { throw "game.exe is running: close the game first" }
Backup $faction; Backup $scopt
Set-Block $faction $facBody
Set-Block $scopt $scoBody
"written: $($flyers.Count) flyers, $($newWH.Count) Allied warheads, $($newWeap.Count) weapon copies, Dragoon warhead (block '$begin' in Terran Faction.ini and StarCraft.ini)"
