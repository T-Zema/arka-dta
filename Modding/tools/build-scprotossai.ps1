# Skirmish AI for the Protoss faction (house GDI2, HouseType index 8, ActsLike=8) under DTA's Advanced AI (Vinifera.dll,
# src/new/advai; wiki engine/advanced-ai). Counterpart of build-scterranai.ps1 (same file, same rules, own block).
# Without this the AI Protoss has no army (no House=8 tactics), no buildings (all AIBuildThis=no), and its AdvAI lookups
# "first entry the ActLike house owns" return DTA types (TDHARV, TDPROC have GDI2 in Owner), so it would never count its
# Assimilators/Probes.
# Writes the block "; >>> Protoss AI" at the end of INI/Game Options/StarCraft.ini (after "; >>> Terran AI"):
#   - pure SC Protoss (like the Terran, user 2026-10-30): every non-SC type loses GDI2 from Owner=
#   - AIBuildThis=yes for the Protoss buildings and research upgrades (AdvAI's last build step takes one of each)
#   - Protoss types appended to the [AI] Build* lists (the Pylon is basic and advanced power at once; Robotics Facility =
#     war factory for the HAS_WAR_FACTORY conditions; Robotics + Stargate = "naval yards": their units are Naval=yes vehicles,
#     AdvAI builds those only for naval teams, which need an owned BuildNavalYard)
#   - ground tactics (House=8) after SC's Protoss AI (aiscript.bin PMCx melee, PHIx campaign): Zealot rush, 12-Zealot wave,
#     Dark Templar raids on workers, Zealot/Dragoon/Templar army, home guard when outnumbered; "naval" tactics = the
#     Robotics/Stargate army (Reaver/Archon push, Scout/Corsair harass, Carrier fleet growing with time)
# Needs tools/patch-vinifera-navalai.ps1: AdvAI queues a replacement Probe / Nexus warp-in (Naval=yes) in the land queue,
# where nothing builds it, and the AI then stops producing and building.
# Enum names are checked against Vinifera.dll (an unknown name ends the game: Emergency_Exit).
# Usage: build-scprotossai.ps1 [-WhatIf] [-Report]   (-WhatIf prints the block instead of writing it; -Report lists which
# Protoss units AdvAI can value: primary weapon with an AG=yes projectile)
param([switch]$WhatIf, [switch]$Report)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path "$PSScriptRoot\..\..").Path
. "$PSScriptRoot\MapCode.ps1"
$scopt = "$game\INI\Game Options\StarCraft.ini"
$latin = [Text.Encoding]::GetEncoding(28591)
$begin = '; >>> Protoss AI'; $end = '; <<< Protoss AI'
$house = 'GDI2'; $heapId = 8

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
# section -> key -> value (repeated sections merged, later key wins), without this script's own block
function Read-Sections([string]$text) {
    $a = $text.IndexOf($begin)
    if ($a -ge 0) { $b = $text.IndexOf("`n", $text.IndexOf($end, $a)) + 1; $text = $text.Substring(0, $a) + $text.Substring($b) }
    $d = @{}; $sec = $null
    foreach ($l in ($text -split "`r?`n")) {
        if ($l -match '^\[([^\]]+)\]') { $sec = $Matches[1]; if (-not $d.ContainsKey($sec)) { $d[$sec] = [ordered]@{} }; continue }
        if ($sec -and $l -match '^\s*([^;=\s][^;=]*?)\s*=\s*([^;\t]*)') { $d[$sec][$Matches[1]] = $Matches[2].Trim() }
    }
    return $d
}
# merge order of a skirmish game with the faction (wiki mods/terran-ai): Rules, Enhance, faction map code, Advanced AI.ini,
# StarCraft.ini (with the Terran AI block, without this one). $Inherits is resolved inside Rules (where DTA uses it).
$rules = Read-Sections ([IO.File]::ReadAllText("$game\INI\Rules.ini", $latin))
$over = @(
    (Read-Sections ([IO.File]::ReadAllText("$game\INI\Enhance.ini", $latin))),
    (Read-Sections (Read-MapCodeText)),
    (Read-Sections ([IO.File]::ReadAllText("$game\INI\Game Options\Advanced AI.ini", $latin))),
    (Read-Sections ([IO.File]::ReadAllText($scopt, $latin))))
function Resolve([string]$sec) {
    $chain = @(); $s = $sec
    while ($s -and $rules.ContainsKey($s) -and $chain.Count -lt 6) { $chain = , $s + $chain; $s = $rules[$s]['$Inherits'] }
    $m = [ordered]@{}
    foreach ($c in $chain) { foreach ($k in $rules[$c].Keys) { if ($k -ne '$Inherits') { $m[$k] = $rules[$c][$k] } } }
    foreach ($f in $over) { if ($f.ContainsKey($sec)) { foreach ($k in $f[$sec].Keys) { $m[$k] = $f[$sec][$k] } } }
    return $m
}
function List([string]$sec) { $v = @(); foreach ($f in @($rules) + $over) { if ($f.ContainsKey($sec)) { $v += $f[$sec].Values } }; @($v | Select-Object -Unique) }
function Split([string]$v) { @($v -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Owned([string]$type) { (Split (Resolve $type)['Owner']) -contains $house }

$types = @(); foreach ($l in 'BuildingTypes', 'VehicleTypes', 'InfantryTypes', 'AircraftTypes') { $types += List $l }
$types = @($types | Select-Object -Unique)

# ---------------------------------------------------------------- report: which units AdvAI can build for teams
if ($Report) {
    foreach ($t in @($types | Where-Object { $_ -like 'SCP*' -and (Owned $_) })) {
        $r = Resolve $t; if ($r['Harvester'] -eq 'yes') { continue }
        if ((List 'BuildingTypes') -contains $t) { continue }
        $w = $r['Primary']; $p = if ($w) { (Resolve $w)['Projectile'] } else { '' }
        $ag = if ($p) { (Resolve $p)['AG'] } else { '' }
        '{0,-10} TL={1,-3} Naval={2,-4} Primary={3,-22} Projectile={4,-16} AG={5}' -f $t, $r['TechLevel'], $r['Naval'], $w, $p, $ag
    }
    return
}

$sb = New-Object Text.StringBuilder
function W([string]$s = '') { [void]$sb.AppendLine($s) }
W '; Generated by Modding/tools/build-scprotossai.ps1 - do not edit by hand. Wiki: engine/advanced-ai, mods/protoss-ai.'
W '; Advanced AI for the Protoss faction (GDI2 = [Houses] index 8). Needs the STARCRAFT checkbox (it is in this file) and'
W '; the Vinifera.dll patch tools/patch-vinifera-navalai.ps1 (Probe and Nexus warp-in in the naval queue).'

# ---------------------------------------------------------------- pure SC Protoss: GDI2 owns only SC types
$strip = @($types | Where-Object { $_ -notlike 'SC*' -and (Owned $_) })
W; W '; Pure SC Protoss: GDI2 removed from the Owner= of every non-SC type (TDHARV/TDPROC shadowed the Probe/Assimilator in'
W '; the AdvAI "first owned entry" lookups).'
foreach ($t in $strip) {
    $o = @(Split (Resolve $t)['Owner'] | Where-Object { $_ -ne $house })
    if (-not $o.Count) { $o = @('Special') }
    W "[$t]"; W "Owner=$($o -join ',')"
}

# ---------------------------------------------------------------- buildings the AI may pick
$aiBuild = 'SCPPYL', 'SCPASM', 'SCPGAT', 'SCPFOR', 'SCPCAN', 'SCPCYB', 'SCPROB', 'SCPBAT', 'SCPSTG', 'SCPCIT', 'SCPRSB',
    'SCPOBS', 'SCPARC', 'SCPFLB', 'SCPTRB'
# research = building upgrades owned by GDI2 (layer "Protoss research")
$research = @($types | Where-Object { $_ -like 'SCQ*' -and (Owned $_) -and (Resolve $_)['PowersUpBuilding'] })
W; W '; AdvAI builds only AIBuildThis=yes types; its last step takes one of each (so the research upgrades too, like SC'
W '; PMCx "upgrade" threads). The Nexus stays AIBuildThis=no: a lost one comes back as SCPDNEX from the Robotics Facility.'
foreach ($t in @($aiBuild) + $research) {
    if (-not (Owned $t)) { throw "$t is not owned by $house" }
    W "[$t]"; W 'AIBuildThis=yes'
}
# AdvAI values a defence building by IsBaseDefense=yes + its weapon (DTA's defences all have it)
if ((Resolve 'SCPCAN')['IsBaseDefense'] -ne 'yes') { W '[SCPCAN]'; W 'IsBaseDefense=yes' }

# ---------------------------------------------------------------- [AI] lists
# AdvAI picks: power = first and last buildable entry (one Pylon = both), refinery/AA/PDefense = last buildable, refinery
# counting = first entry owned by the ActLike house. Protoss types go last (after the Terran block's entries).
$add = [ordered]@{
    BuildPower = 'SCPPYL'; BuildRefinery = 'SCPASM'; BuildBarracks = 'SCPGAT'; BuildWeapons = 'SCPROB'
    BuildDefense = 'SCPCAN'; BuildPDefense = 'SCPCAN'; BuildAA = 'SCPCAN'; BuildNavalYard = 'SCPROB', 'SCPSTG'
}
W; W '; Protoss entries at the end of the AdvAI lists. Robotics Facility and Stargate as "naval yards": the Probe, Reaver,'
W '; Archon, Scout, Carrier... are Naval=yes vehicles (built next to them by the naval-yard exit).'
W '[AI]'
foreach ($k in $add.Keys) {
    $cur = @(Split (Resolve 'AI')[$k] | Where-Object { $add[$k] -notcontains $_ })
    W "$k=$((@($cur) + $add[$k]) -join ',')"
}

# ---------------------------------------------------------------- tactics
# Same format as build-scterranai.ps1. Team: ADVAITT,IsSuicide,IsTransportTeam,AvoidThreats,MaxCost,RTTI,Override.
# Ground teams get the Gateway infantry (Zealot, Dragoon, Templars); the Robotics/Stargate units come only in naval teams.
$grow = [ordered]@{ FrameBasedDurationIncrease = 1000; FrameBasedDurationTimeStep = 8000; FrameBasedDurationIncreaseMax = 4000 }
$ground = [ordered]@{
    # SC PMCx/PLOx: Zealots straight away (Protoss rush), not into Soviet early defences
    PROTOSS_EARLY_ZEALOT_RUSH = [ordered]@{ PrimaryTacticType = 'TACTIC_RUSH_ATTACK'; MinimumExpectedDuration = 2000; ScaleDurationByBuildTime = 'no'
        C = 'TACTICCOND_HOUSE_TACTICAL_VALUE_BELOW,0,4', 'TACTICCOND_ENEMY_IS_NOT_HOUSETYPE,3,0', 'TACTICCOND_FRAME_LESS_THAN,2500,0'
        T = 'ADVAITT_RUSH,0,0,1,-1,Infantry,none' }
    PROTOSS_EARLY_SCOUT = [ordered]@{ PrimaryTacticType = 'TACTIC_SCOUT'; MinimumExpectedDuration = 300; ScaleDurationByBuildTime = 'yes'
        C = 'TACTICCOND_HOUSE_TACTICAL_VALUE_BELOW,0,11', 'TACTICCOND_FRAME_LESS_THAN,2000,0'
        T = 'ADVAITT_SCOUT,0,0,0,400,Infantry,none'
        X = [ordered]@{ SetTacticalValueIndex = 0; SetTacticalValueMin = 11; SetTacticalValueChance = 50 } }
    # SC PHIx: 2 Zealots + Dragoon stay home
    PROTOSS_EARLY_DEFEND = [ordered]@{ PrimaryTacticType = 'TACTIC_DEFEND'; MinimumExpectedDuration = 1000; ScaleDurationByBuildTime = 'no'
        C = 'TACTICCOND_HOUSE_TACTICAL_VALUE_ABOVE,0,10', 'TACTICCOND_FRAME_LESS_THAN,2000,0'
        T = 'ADVAITT_DEFEND,0,0,0,1700,Infantry,none' }
    # SC PMCx attack 1: 12 Zealots
    PROTOSS_ZEALOT_WAVE = [ordered]@{ PrimaryTacticType = 'TACTIC_RUSH_ATTACK'; MinimumExpectedDuration = 2500; MaximumExpectedDuration = 3500; ScaleDurationByBuildTime = 'yes'
        C = 'TACTICCOND_FRAME_MORE_THAN,2000,0', 'TACTICCOND_FRAME_LESS_THAN,7000,0', 'TACTICCOND_IS_NOT_OUTNUMBERED,0,0', 'TACTICCOND_PERCENT_CHANCE,60,0'
        T = 'ADVAITT_RUSH,0,0,0,4800,Infantry,none' }
    # SC: Dark Templar into the worker line (cloaked units are valued x2, so DTs once the Templar Archives stand)
    PROTOSS_DARK_TEMPLAR_RAID = [ordered]@{ PrimaryTacticType = 'TACTIC_ATTACK_HARVESTERS'; MinimumExpectedDuration = 1500; MaximumExpectedDuration = 3000; ScaleDurationByBuildTime = 'yes'
        C = 'TACTICCOND_FRAME_MORE_THAN,6000,0', 'TACTICCOND_ENEMY_HARVESTER_COUNT_EXCEEDS,1,0', 'TACTICCOND_NOT_REPEATED_FOR_FRAMES,6000,0',
            'TACTICCOND_ENEMY_HAS_NO_SENSORS,0,0', 'TACTICCOND_PERCENT_CHANCE,40,0'
        T = 'ADVAITT_ATTACK_HARVESTERS,1,0,0,2600,Infantry,none'; G = 1 }
    PROTOSS_FLANK_ATTACK = [ordered]@{ PrimaryTacticType = 'TACTIC_ATTACK_REFINERIES'; MinimumExpectedDuration = 3000; MaximumExpectedDuration = 6000; ScaleDurationByBuildTime = 'yes'
        C = 'TACTICCOND_NOT_REPEATED_FOR_FRAMES,6000,0', 'TACTICCOND_ENEMY_VULNERABLE_REFINERIES,0,0', 'TACTICCOND_PERCENT_CHANCE,75,0'
        T = 'ADVAITT_ATTACK_REFINERIES,0,0,1,-1,<none>,none'; G = 1 }
    # SC defensebuild/defenseuse: home guard when the enemy army is twice ours (one at a time)
    PROTOSS_HOLD_THE_LINE = [ordered]@{ PrimaryTacticType = 'TACTIC_DEFEND'; MinimumExpectedDuration = 1500; ScaleDurationByBuildTime = 'yes'
        C = 'TACTICCOND_IS_OUTNUMBERED,0,0', 'TACTICCOND_FRAME_MORE_THAN,4000,0', 'TACTICCOND_PERCENT_CHANCE,50,0'
        T = 'ADVAITT_DEFEND,0,0,0,3000,<none>,none'; X = [ordered]@{ MaxInstances = 1 } }
    # SC PMCx attack 2: Zealots + Dragoons + Templars, growing with time
    PROTOSS_GATEWAY_ARMY = [ordered]@{ PrimaryTacticType = 'TACTIC_DIRECT_ATTACK_REGULAR'; MinimumExpectedDuration = 3000; MaximumExpectedDuration = 6000; ScaleDurationByBuildTime = 'yes'
        C = 'TACTICCOND_FRAME_MORE_THAN,6000,0', 'TACTICCOND_PERCENT_CHANCE,50,0'
        T = 'ADVAITT_DIRECT_ATTACK,0,0,0,-1,Infantry,none'; G = 1 }
    PROTOSS_DIRECT_ATTACK = [ordered]@{ PrimaryTacticType = 'TACTIC_DIRECT_ATTACK_REGULAR'; MinimumExpectedDuration = 3000; MaximumExpectedDuration = 6000; ScaleDurationByBuildTime = 'yes'
        C = 'TACTICCOND_PERCENT_CHANCE,50,0'; T = 'ADVAITT_DIRECT_ATTACK,0,0,0,-1,<none>,none'; G = 1 }
    # catch-all: some tactic always matches
    PROTOSS_FAST_ATTACK = [ordered]@{ PrimaryTacticType = 'TACTIC_DIRECT_ATTACK_FAST'; MinimumExpectedDuration = 3000; MaximumExpectedDuration = 6000; ScaleDurationByBuildTime = 'yes'
        T = 'ADVAITT_DIRECT_ATTACK,0,0,0,-1,<none>,none'; G = 1 }
}
# Robotics/Stargate army as a "naval" fleet; naval teams take only ADVAITT_DIRECT_ATTACK
$naval = [ordered]@{
    # SC PHIx: 6 Zealots + 4 Dragoons + Reaver; here the Robotics part (Reavers, Archons)
    PROTOSS_ROBOTICS_PUSH = [ordered]@{ PrimaryTacticType = 'NAVALTACTIC_DIRECT_ATTACK'; MinimumExpectedDuration = 2000; MaximumExpectedDuration = 3000
        C = 'TACTICCOND_FRAME_MORE_THAN,5000,0', 'TACTICCOND_PERCENT_CHANCE,40,0'; T = 'ADVAITT_DIRECT_ATTACK,0,0,0,6000,Unit,none' }
    # SC PMCx attack 3: Scouts + Corsairs
    PROTOSS_FLEET_HARASS = [ordered]@{ PrimaryTacticType = 'NAVALTACTIC_DIRECT_ATTACK'; MinimumExpectedDuration = 1500
        C = 'TACTICCOND_PERCENT_CHANCE,40,0'; T = 'ADVAITT_DIRECT_ATTACK,0,0,0,4500,Unit,none' }
    # SC PMCx late loop: Scouts, Corsairs and Carriers, bigger with time
    PROTOSS_FLEET_ATTACK = [ordered]@{ PrimaryTacticType = 'NAVALTACTIC_DIRECT_ATTACK'; MinimumExpectedDuration = 2000; MaximumExpectedDuration = 4000
        T = 'ADVAITT_DIRECT_ATTACK,0,0,0,-1,Unit,none'; G = 1 }
}

# every enum name must exist in Vinifera.dll
$dllText = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes("$game\Vinifera.dll"))
$valid = @{}; foreach ($m in [regex]::Matches($dllText, '(?<![A-Z_])(TACTICCOND|TACTIC|ADVAITT|AIRTACTIC|NAVALTACTIC)_[A-Z_]+(?=\x00)')) { $valid[$m.Value] = 1 }
if ($valid.Count -lt 40) { throw "only $($valid.Count) AdvAI enum names found in Vinifera.dll" }
function Check([string]$name) { if (-not $valid.ContainsKey($name)) { throw "unknown AdvAI name '$name' (would end the game)" } }

function Write-Tactic([string]$name, $t) {
    W "[$name]"
    Check $t.PrimaryTacticType
    foreach ($k in 'PrimaryTacticType', 'MinimumExpectedDuration', 'MaximumExpectedDuration', 'ScaleDurationByBuildTime') { if ($t.Contains($k)) { W "$k=$($t[$k])" } }
    if ($t.G) { foreach ($k in $grow.Keys) { W "$k=$($grow[$k])" } }
    W "House=$heapId"
    $i = 0; foreach ($c in @($t.C | Where-Object { $_ })) { Check ($c -split ',')[0]; W "Conditions.$i=$c"; $i++ }
    $i = 0; foreach ($tt in @($t.T)) {
        $f = $tt -split ','; Check $f[0]; if ($f.Count -ne 7) { throw "$name team '$tt' needs 7 fields" }
        if ($f[6] -ne 'none') { Check $f[6] }
        W "AdvAITeamTypes.$i=$tt"; $i++
    }
    if ($t.X) { foreach ($k in $t.X.Keys) { W "$k=$($t.X[$k])" } }
}
foreach ($n in $naval.Keys) { if (@($naval[$n].T | Where-Object { $_ -notlike 'ADVAITT_DIRECT_ATTACK,*' }).Count) { throw "$n naval team must be ADVAITT_DIRECT_ATTACK" } }
foreach ($n in @($ground.Keys) + @($naval.Keys)) { if ((List 'AdvancedAIGroundTactics') + (List 'AdvancedAINavalTactics') -contains $n) { throw "tactic $n already listed elsewhere" } }
W; W '; Tactics for House=8 (the stock ones in Advanced AI.ini are House=0..3). First matching tactic wins.'
W '[AdvancedAIGroundTactics]'
$i = 0; foreach ($n in $ground.Keys) { W "PRT$i=$n"; $i++ }
W '[AdvancedAINavalTactics]'
$i = 0; foreach ($n in $naval.Keys) { W "PRT$i=$n"; $i++ }
foreach ($n in $ground.Keys) { W; Write-Tactic $n $ground[$n] }
foreach ($n in $naval.Keys) { W; Write-Tactic $n $naval[$n] }

# ---------------------------------------------------------------- checks of the result (owner lists as written above)
$ownedAfter = { param($t) if ($strip -contains $t) { $false } else { Owned $t } }
function FirstOwned([string]$list, [string]$key) {
    $v = if ($list -eq 'AI') { @(Split (Resolve 'AI')[$key] | Where-Object { $add[$key] -notcontains $_ }) + $add[$key] } else { Split (Resolve $list)[$key] }
    foreach ($t in $v) { if (& $ownedAfter $t) { return $t } }
}
foreach ($k in $add.Keys) { foreach ($t in $add[$k]) { if (-not (Owned $t)) { throw "[AI] $k entry $t is not owned by $house" } } }
$expect = @{ 'BuildRefinery' = 'SCPASM'; 'BuildPower' = 'SCPPYL'; 'BuildConst' = 'SCPNEX' }
foreach ($k in $expect.Keys) {
    $v = if ($add.Contains($k)) { FirstOwned 'AI' $k } else { $x = $null; foreach ($t in (Split (Resolve 'AI')[$k])) { if (& $ownedAfter $t) { $x = $t; break } }; $x }
    if ($v -ne $expect[$k]) { throw "first GDI2 entry of [AI] $k is '$v', expected $($expect[$k])" }
}
$h = $null; foreach ($t in (Split (Resolve 'General')['HarvesterUnit'])) { if (& $ownedAfter $t) { $h = $t; break } }
if ($h -ne 'SCPPROBE') { throw "first GDI2 entry of [General] HarvesterUnit is '$h', expected SCPPROBE" }
$mcv = @($types | Where-Object { $_ -like 'SC*' -and (Owned $_) -and (Resolve $_)['DeploysInto'] -eq 'SCPNEX' -and [int](Resolve $_)['TechLevel'] -ge 0 })
if (-not $mcv.Count) { throw 'no buildable GDI2 unit deploys into SCPNEX (AdvAI could not rebuild the Nexus)' }

if ($WhatIf) { $sb.ToString(); return }
Backup $scopt
Set-Block $scopt $sb.ToString()
"written block '$begin' to StarCraft.ini: $($strip.Count) types lose GDI2, $($aiBuild.Count) buildings + $($research.Count) research AIBuildThis=yes, $($ground.Count) ground + $($naval.Count) naval tactics, Nexus rebuild: $($mcv -join ',')"
