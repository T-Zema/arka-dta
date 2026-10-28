# Shared helpers of the ARKA mission generators (build-arka0*-mission.ps1). Dot-source after the generator's DSL
# exists (Trigger, Ev, Act, Text, Enable and the $trig table) and $ini is loaded:
#   . "$tools\MissionKit.ps1"
#   Add-RevealCrate $x $y                 # crate next to the base: picking it up reveals the whole map
#   Add-MoneyCrate $x $y 5000 'text'      # wood crate: picking it up pays a fixed sum (loot worth leaving the base for)
#   Split-MultiText; Set-DialoguePacing   # before resolving $trig: one text per trigger, gaps from text length
#   Test-TextTimeline                     # after: logs the text timeline, WARN where two texts overlap
#   Add-ScAirArmor                        # after the SC types are copied: SC flyer armors, Allied AA, Dragoon vs Overlord
# Wiki: engine/triggers-and-dialogue (Tempo dialogow), workflow/mission-maps.

# ---------------------------------------------------------------- reading time
# Elapsed Time counts game seconds of 15 logic frames, and the game runs faster than 15 frames/s (skirmish measured
# 45-60), so 7 "seconds" between two lines read as about 2 real seconds (user test of ARKA 0, 2026-10-27: "text goes
# too fast"). One real second = $GameSecPerReal game seconds (niezweryfikowane: tune after the next test).
$GameSecPerReal = 3
$ReadCharsPerSec = 12
function Get-ReadSecs([string[]]$texts) {
    $c = 0; foreach ($s in $texts) { $c += $s.Length }
    [int][Math]::Ceiling((3 + $c / $ReadCharsPerSec) * $GameSecPerReal)
}
function Get-TriggerTexts($t) {
    foreach ($a in $t.Actions) { $p = $a -split ','; if ($p[0] -eq '11') { $ini.Get('Tutorial', $p[2], '') } }
}

# ---------------------------------------------------------------- one text per trigger
# A trigger with several Text actions shows them all in the same frame. The second and later texts move to new
# disabled triggers chained by Elapsed Time; the Enable actions move to the last part, so a dialogue chain continues
# only after the last line. Everything else (reinforcements, radar events, house changes) stays in the original.
# The new parts belong to the player's house: the original's house may be a survivor house emptied by All change house.
function Split-MultiText($player = 'Allies') {
    foreach ($k in @($trig.Keys)) {
        $t = $trig[$k]
        $texts = @($t.Actions | Where-Object { ($_ -split ',')[0] -eq '11' })
        if ($texts.Count -lt 2 -or $t.Repeat) { continue }
        $enables = @($t.Actions | Where-Object { ($_ -split ',')[0] -eq '53' })
        $later = $texts[1..($texts.Count - 1)]
        $t.Actions = @($t.Actions | Where-Object { $_ -notin $later -and $_ -notin $enables })
        $prev = $t
        for ($i = 1; $i -lt $texts.Count; $i++) {
            $key = "$k~$i"
            $acts = @($texts[$i]); if ($i -eq $texts.Count - 1) { $acts += $enables }
            Trigger $key "$($t.Name) ($($i + 1))" @((Ev 13 1)) $acts -house $player -Disabled | Out-Null
            $prev.Actions = @($prev.Actions) + @(Enable $key)
            $prev = $trig[$key]
        }
    }
}

# ---------------------------------------------------------------- gaps from text length
# A disabled trigger that shows a text and is enabled by a trigger that showed a text waits at least the reading
# time of that text. Longer waits written in the generator stay (an explicit Ev 13 above the reading time wins).
function Set-DialoguePacing {
    foreach ($k in @($trig.Keys)) {
        $t = $trig[$k]; $tx = @(Get-TriggerTexts $t); if (-not $tx.Count) { continue }
        $gap = Get-ReadSecs $tx
        foreach ($a in $t.Actions) {
            $p = $a -split ','; if ($p[0] -ne '53') { continue }
            $n = $trig[$p[2]]; if (-not $n -or -not $n.Disabled -or -not @(Get-TriggerTexts $n).Count) { continue }
            $ev = @($n.Events)
            for ($i = 0; $i -lt $ev.Count; $i++) { $e = $ev[$i] -split ','; if ($e[0] -eq '13' -and [int]$e[2] -lt $gap) { $ev[$i] = "13,0,$gap" } }
            $n.Events = $ev
        }
    }
}

# ---------------------------------------------------------------- timeline check
# Times are known for triggers that start enabled with only Elapsed Time, and for chains Enabled from them; event
# driven triggers (zones, deaths) are left out. WARN when a text starts before the previous one has been read.
function Test-TextTimeline {
    $at = @{}; $queue = New-Object Collections.Queue
    foreach ($k in $trig.Keys) {
        $t = $trig[$k]; $ev = @($t.Events)
        if (-not $t.Disabled -and -not $t.Repeat -and $ev.Count -eq 1 -and ($ev[0] -split ',')[0] -eq '13') { $at[$k] = [int](($ev[0] -split ',')[2]); $queue.Enqueue($k) }
    }
    while ($queue.Count) {
        $k = $queue.Dequeue()
        foreach ($a in $trig[$k].Actions) {
            $p = $a -split ','; if ($p[0] -ne '53') { continue }
            $n = $trig[$p[2]]; if (-not $n -or $at.ContainsKey($p[2])) { continue }
            $ev = @($n.Events); if ($ev.Count -ne 1 -or ($ev[0] -split ',')[0] -ne '13') { continue }
            $at[$p[2]] = $at[$k] + [int](($ev[0] -split ',')[2]); $queue.Enqueue($p[2])
        }
    }
    $rows = foreach ($k in $at.Keys) { $tx = @(Get-TriggerTexts $trig[$k]); if ($tx.Count) { [pscustomobject]@{ T = $at[$k]; Read = (Get-ReadSecs $tx); Key = $k; Text = $tx[0] } } }
    $rows = @($rows | Sort-Object T)
    $warn = 0
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $r = $rows[$i]
        $log.Add(('text {0,5}s (+{1,3}) {2,-12} {3}' -f $r.T, $r.Read, $r.Key, $(if ($r.Text.Length -gt 70) { $r.Text.Substring(0, 70) + '...' } else { $r.Text })))
        if ($i -gt 0 -and $r.T -lt $rows[$i - 1].T + $rows[$i - 1].Read) { $log.Add("WARN text '$($r.Key)' at $($r.T)s starts before '$($rows[$i - 1].Key)' ($($rows[$i - 1].T)s + $($rows[$i - 1].Read)s) is read"); $warn++ }
    }
    foreach ($k in $trig.Keys) { if (@(Get-TriggerTexts $trig[$k]).Count -gt 1) { $log.Add("WARN trigger '$k' shows $(@(Get-TriggerTexts $trig[$k]).Count) texts at once"); $warn++ } }
    $warn
}

# ---------------------------------------------------------------- reveal-map crate
# A steel crate (overlay SCRATE, [OverlayTypes] 61, CrateTrigger=yes) on a free cell. Two ways to the reveal, so it
# works even if one fails: the map's [Powerups] give only Reveal (map rules override Rules.ini; niezweryfikowane for
# [Powerups]), and a cell tag on the crate fires "Entered by <player>" -> Reveal all map + text.
function Add-RevealCrate([int]$x, [int]$y, $player = 'Allies', $playerNo = 2) {
    $i = $y * 512 + $x
    $o = [Pack]::Unpack($ini.Joined('OverlayPack'), $false); $d = [Pack]::Unpack($ini.Joined('OverlayDataPack'), $false)
    if ($o[$i] -ne 255) { throw "crate cell $x,$y already has overlay $($o[$i])" }
    $o[$i] = 61; $d[$i] = 0
    $ini.SetPack('OverlayPack', [Pack]::PackData($o, $false, 8192)); $ini.SetPack('OverlayDataPack', [Pack]::PackData($d, $false, 8192))
    $game = (Resolve-Path "$PSScriptRoot\..\..").Path
    $in = $false
    foreach ($l in [IO.File]::ReadAllLines("$game\INI\Rules.ini")) {
        if ($l -match '^\[([^\]]+)\]') { if ($in) { break }; $in = $matches[1] -eq 'Powerups'; continue }
        if ($in -and $l -match '^(\w+)\s*=\s*\d+\s*,([^;]*)') { $ini.Set('Powerups', $matches[1], "$(if ($matches[1] -eq 'Reveal') { 100 } else { 0 }),$($matches[2].Trim())") }
    }
    Trigger 'revealCrate' 'Skrzynka: odkrycie mapy' @((Ev 1 $playerNo)) @((Act 16), (Text 'Skrzynka zwiadu: mapa odkryta.')) -house $player | Out-Null
    $ini.Set('CellTags', "$($y * 1000 + $x)", $trig['revealCrate'].Tag)
    $log.Add("reveal crate @ $x,$y (tag $($trig['revealCrate'].Tag))")
}

# ---------------------------------------------------------------- money crate
# A wood crate (overlay CRATE, [OverlayTypes] 179). In a solo mission a wood crate gives [CrateRules] WoodCrate=Money
# (SoloCrateMoney=2000); on top of that a cell tag pays a fixed sum with action 106 Give Credits (ts-patches; DTA cr05,
# a_bridge_too_few: "106,0,<house>,<credits>,0,0,0,A") and shows a line. Review 2026-10-27: give the player loot to
# go for (a crate in the church, cash next to the ore on the Rock). Both paths (niezweryfikowane w grze).
$moneyCrates = 0
function Add-MoneyCrate([int]$x, [int]$y, [int]$credits, [string]$text, $player = 'Allies', $playerNo = 2) {
    $i = $y * 512 + $x
    $o = [Pack]::Unpack($ini.Joined('OverlayPack'), $false); $d = [Pack]::Unpack($ini.Joined('OverlayDataPack'), $false)
    if ($o[$i] -ne 255) { throw "crate cell $x,$y already has overlay $($o[$i])" }
    $o[$i] = 179; $d[$i] = 0
    $ini.SetPack('OverlayPack', [Pack]::PackData($o, $false, 8192)); $ini.SetPack('OverlayDataPack', [Pack]::PackData($d, $false, 8192))
    $script:moneyCrates++; $key = "moneyCrate$script:moneyCrates"
    Trigger $key "Skrzynka z pieniedzmi $script:moneyCrates" @((Ev 1 $playerNo)) @("106,0,$playerNo,$credits,0,0,0,A", (Text $text)) -house $player | Out-Null
    $ini.Set('CellTags', "$($y * 1000 + $x)", $trig[$key].Tag)
    $log.Add("money crate @ $x,${y}: $credits credits (tag $($trig[$key].Tag))")
}

# ---------------------------------------------------------------- Zerg builder: drones that hatch, walk and morph
# The engine's computer player builds structures only ConYard-style (base nodes + a Factory=BuildingType building in
# [AI] BuildConst): the building grows on the spot. Zerg buildings come from Drones (SCZD<x> with DeploysInto), so a
# Zerg computer player builds the way DTA's cr07 lets the Soviets deploy their base: a team per building with the
# script "4 Move to cell" -> "9 Deploy". Each node: at its time the trigger "4 Create Team" makes the house produce the
# Drone at its Hatchery/Hive (unit factory, larvae = naval-yard production; costs the house's credits; the house needs
# IQ >= [IQ] Production and "3 Production Begins"). A cell tag on the deploy cell sees the Drone arrive; if none came
# within $Watchdog seconds (production failed: no money, no factory, AI quirk), the same team is hatched at $SpawnWp by
# "80" instead, so the base still grows. Building origin = Drone cell + AdjacentCoord[7] (NW, -1,-1;
# UnitClass::Try_To_Deploy, see patch-zergbuild-grid.asm), so pass the TOP-LEFT cell of each planned building.
# The spot must be on creep (patch-zergbuild.ps1: Zerg buildings need creep under every cell, except Hatchery/Lair/Hive)
# and free; a Drone that cannot deploy just stays there.
# Needs the generator's Team/Trigger/Ev/Act/Reinf/Enable/Disable and $ini/$log; types SCZD<x> must be in the map.
#   Add-ZergBuilder 'Nod1' 7 22 @(@('SCZSUN', 81, 114), @('SCZSPO', 88, 114)) 300 120 'zb1'
# ---------------------------------------------------------------- SC flyer armor (engine/air-armor)
# The block "; >>> SC air armor" of the faction file (tools/build-scairarmor.ps1): new armors for SC flyers, Allied AA
# that does not acquire them (an ordered shot hits), Dragoons that cannot shoot the Overlord. The SC type closure has
# already copied the flyers' Armor= and the armor sections; this adds the [ArmorTypes] entries, the Allied AA warheads
# and weapons (Rules types) and the Dragoon warhead. SC sections the map does not have are skipped. Call after the
# SC types are copied: Add-ScAirArmor
function Add-ScAirArmor {
    $enc = [Text.Encoding]::GetEncoding(28591); $b = '; >>> SC air armor'; $e = '; <<< SC air armor'
    . "$tools\MapCode.ps1"   # the block is in the faction map code layer "SC air armor"
    $t = [IO.File]::ReadAllText((Get-MapCodeLayer 'SC air armor'), $enc)
    $a = $t.IndexOf($b); if ($a -lt 0) { throw "Add-ScAirArmor: no '$b' block in the map code layer 'SC air armor' (run build-scairarmor.ps1)" }
    $z = $t.IndexOf($e, $a); $body = $t.Substring($a, $z - $a)
    $scOwn = @{}   # sections the SC files define outside the block (SC types and weapons)
    foreach ($s in [IO.File]::ReadAllText("$game\INI\Game Options\StarCraft.ini", $enc), (Read-MapCodeText)) {
        $i = $s.IndexOf($b); if ($i -ge 0) { $s = $s.Substring(0, $i) + $s.Substring($s.IndexOf("`n", $s.IndexOf($e, $i)) + 1) }
        foreach ($m in [regex]::Matches($s, '(?m)^\[([^\]]+)\]')) { $scOwn[$m.Groups[1].Value] = $true }
    }
    $sec = $null; $skip = $false; $n = 0
    foreach ($l in ($body -split "`r?`n")) {
        if ($l -match '^\[([^\]]+)\]') { $sec = $Matches[1]; $skip = $scOwn.ContainsKey($sec) -and -not $ini.Has($sec); continue }
        if ($sec -and -not $skip -and $l -match '^\s*([^;=\s][^;=]*?)\s*=\s*([^;\t]*)') { $ini.Set($sec, $Matches[1], $Matches[2].Trim()); $n++ }
    }
    $log.Add("SC air armor: $n keys from the faction block (Allied AA ignores SC flyers unless ordered, Dragoons cannot hit the Overlord)")
}
function Add-ZergBuilder($House, [int]$HouseNo, [int]$SpawnWp, $Nodes, [int]$Start, [int]$Every, [string]$Prefix, [int]$Watchdog = 300) {
    Trigger "${Prefix}prod" "Zergi ${House}: produkcja" @((Ev 13 ([Math]::Max(1, $Start - 5)))) @((Act 3 $HouseNo)) -house $House | Out-Null
    for ($k = 0; $k -lt $Nodes.Count; $k++) {
        $type = $Nodes[$k][0]; $x = [int]$Nodes[$k][1]; $y = [int]$Nodes[$k][2]
        $drone = 'SCZD' + $type.Substring(3)
        if (-not $ini.Has($drone)) { throw "Add-ZergBuilder: drone type $drone (for $type) is not in the map" }
        if ($ini.Get($drone, 'DeploysInto', '') -ne $type) { throw "Add-ZergBuilder: $drone does not deploy into $type" }
        $cx = $x + 1; $cy = $y + 1; $cell = $cy * 1000 + $cx
        $tm = Team "$Prefix ${k}: dron $type" $House $SpawnWp @($drone) @("4,$cell", '9,0')
        $b = "${Prefix}b$k"; $w = "${Prefix}w$k"; $a = "${Prefix}a$k"
        Trigger $b "Zergi ${House}: buduj $type nr $k" @((Ev 13 ($Start + $k * $Every))) @((Act 4 $tm 1), (Enable $w)) -house $House | Out-Null
        Trigger $w "Zergi ${House}: dron $k nie doszedl" @((Ev 13 $Watchdog)) @((Reinf $tm $SpawnWp)) -house $House -Disabled | Out-Null
        Trigger $a "Zergi ${House}: dron $k na miejscu" @((Ev 1 $HouseNo)) @((Disable $w)) -house $House | Out-Null
        $key = "$cell"
        if ($ini.Get('CellTags', $key, $null)) { $log.Add("WARN Add-ZergBuilder: cell $cx,$cy already has a cell tag, no arrival check for node $k") }
        else { $ini.Set('CellTags', $key, $trig[$a].Tag) }
        $log.Add("zerg builder $House node ${k}: $drone -> $type at $x,$y (drone cell $cx,$cy) from $($Start + $k * $Every) s")
    }
}
