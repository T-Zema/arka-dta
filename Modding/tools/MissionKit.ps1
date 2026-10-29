# Shared helpers of the ARKA mission generators (build-arka0*-mission.ps1). Dot-source after the generator's DSL
# exists (Trigger, Ev, Act, Text, Enable and the $trig table) and $ini is loaded:
#   . "$tools\MissionKit.ps1"
#   Add-RevealCrate $x $y                 # crate next to the base: picking it up reveals the whole map
#   Add-MoneyCrate $x $y 5000 'text'      # wood crate: picking it up pays a fixed sum (loot worth leaving the base for)
#   Split-MultiText; Set-DialoguePacing   # before resolving $trig: one text per trigger, gaps from text length
#   Test-TextTimeline                     # after: logs the text timeline, WARN where two texts overlap
#   Add-ScAirArmor                        # after the SC types are copied: SC flyer armors, Allied AA, Dragoon vs Overlord
#   Add-Difficulty                        # after Set-DialoguePacing: Easy/Medium waves and money from the client's level
#   Add-ObjectiveReminder / Add-CountProgress   # before Split-MultiText: objective reminders, "k of n" progress lines
# Wiki: engine/triggers-and-dialogue (Tempo dialogow, Poziom trudnosci), workflow/mission-maps.

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
function Get-TriggerTimes {
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
    $at
}
function Test-TextTimeline {
    $at = Get-TriggerTimes
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

# ---------------------------------------------------------------- quiet dialogue (user, ARKA 0, 2026-10-29)
# "When the texts run, let the player read them, then raise the pace." A dialogue = a timed chain of 2+ texts (a text
# trigger that enables the next text trigger); no enemy may arrive between its first line and the end of reading its last
# one, except in the chain's own triggers (a wave announced by its first line is fine). Enemy arrivals: 7/80 with a team
# of a house that is not on the player's Allies list, in timed triggers and in repeating Elapsed triggers enabled from
# them (all firings up to $horizon). Call after Set-DialoguePacing and BEFORE Add-Difficulty (which moves the waves into
# helper triggers). Returns the WARN count.
function Test-QuietDialogue($player = 'Allies', [int]$horizon = 4000) {
    $friends = @($ini.Get($player, 'Allies', $player) -split ',' | ForEach-Object { $_.Trim() })
    $at = Get-TriggerTimes
    $isEnemy = { param($t) foreach ($a in $t.Actions) { $p = $a -split ','; if ($p[0] -in '7', '80' -and $p[1] -eq '1' -and $ini.Get($p[2], 'House', '') -notin $friends) { return $true } }; $false }
    $nextText = { param($t) foreach ($a in $t.Actions) { $p = $a -split ','; if ($p[0] -eq '53' -and $trig[$p[2]] -and $trig[$p[2]].Disabled -and -not $trig[$p[2]].Repeat -and @(Get-TriggerTexts $trig[$p[2]]).Count) { return $p[2] } }; $null }   # a repeating objective reminder is not the next line
    $arrivals = New-Object Collections.Generic.List[object]
    foreach ($k in $at.Keys) {
        if (& $isEnemy $trig[$k]) { $arrivals.Add(@($at[$k], $k)) }
        foreach ($a in $trig[$k].Actions) {   # repeating raids switched on here
            $p = $a -split ','; if ($p[0] -ne '53') { continue }; $r = $trig[$p[2]]
            if (-not $r -or -not $r.Repeat -or -not (& $isEnemy $r)) { continue }
            $ev = @($r.Events); if ($ev.Count -ne 1 -or ($ev[0] -split ',')[0] -ne '13') { continue }
            $gap = [int](($ev[0] -split ',')[2]); for ($s = $at[$k] + $gap; $gap -gt 0 -and $s -le $horizon; $s += $gap) { $arrivals.Add(@($s, $p[2])) }
        }
    }
    $heads = @{}; foreach ($k in $at.Keys) { if (@(Get-TriggerTexts $trig[$k]).Count) { $heads[$k] = $true } }
    foreach ($k in $at.Keys) { $n = & $nextText $trig[$k]; if ($n -and @(Get-TriggerTexts $trig[$k]).Count) { $heads.Remove($n) } }
    $warn = 0
    foreach ($h in $heads.Keys) {
        $chain = @($h); $k = $h
        while (($n = & $nextText $trig[$k]) -and $at.ContainsKey($n) -and $n -notin $chain) { $chain += $n; $k = $n }
        if ($chain.Count -lt 2) { continue }
        $from = $at[$h]; $to = $at[$k] + (Get-ReadSecs @(Get-TriggerTexts $trig[$k]))
        foreach ($e in $arrivals) {
            if ($e[0] -gt $from -and $e[0] -lt $to -and $e[1] -notin $chain) {
                $log.Add("WARN enemy '$($e[1])' arrives at $($e[0])s during the dialogue '$h' ($from-${to}s)"); $warn++
            }
        }
    }
    $warn
}

# ---------------------------------------------------------------- difficulty levels
# The client appends the trigger DifficultyGlobal to every mission (spawnmap.ini; the same block as INI/Map Code/
# Difficulty *.ini): Easy sets globals 10+13, Medium 11+13+14, Hard 12+14. The mission as written is Hard (user
# 2026-10-28), also when no global is set (a test without the client). Easy: enemy reinforcements (actions 80/7) at
# half strength and the player's money doubled (start credits and every 106 Give Credits to the player); Medium: 3/4
# and +50%. A trigger that brings enemies or pays the player enables helpers instead: one disabled repeating trigger per
# level, gated by its global, 1 s later (the client's trigger runs first), with that level's teams and bonus; it then
# disables itself. House multipliers (Armor = more HP) cannot follow the level: in a campaign Vinifera's
# HouseClassExt::_Assign_Handicap takes them only from the Rules sections [Easy]/[PlayerNormal]/[Difficult], which a map
# cannot override, and the human on Easy would share [Easy] with the computer on Hard.
$DiffLevels = @(
    @{ Key = 'E'; Name = 'latwy';  Wave = 0.5;  Money = 1.0; Events = @('13,0,1', '27,0,10') },
    @{ Key = 'M'; Name = 'sredni'; Wave = 0.75; Money = 0.5; Events = @('13,0,1', '27,0,11') },
    @{ Key = 'H'; Name = 'trudny'; Wave = 1.0;  Money = 0.0; Events = @('13,0,1', '28,0,10', '28,0,11') })
$rulesPass = $null
function Test-Transport($type) {   # a transport line (NLST, Overlord) keeps its count, only the cargo shrinks
    $v = $ini.Get($type, 'Passengers', '')
    if (-not $v) {
        if ($null -eq $script:rulesPass) {
            $script:rulesPass = @{}; $sec = $null
            foreach ($l in [IO.File]::ReadAllLines("$((Resolve-Path "$PSScriptRoot\..\..").Path)\INI\Rules.ini", [Text.Encoding]::GetEncoding(28591))) {
                if ($l -match '^\[([^\]]+)\]') { $sec = $Matches[1] } elseif ($sec -and $l -match '^Passengers\s*=\s*(\d+)') { $script:rulesPass[$sec] = $Matches[1] }
            }
        }
        $v = $script:rulesPass[$type]
    }
    [int]("0" + ($v -replace '\D.*$', '')) -gt 0
}
# Taskforce lines scaled by $f: the cargo total rounds up (at least 1) and is shared by largest remainder; $null if
# nothing changes
function Get-ScaledTaskForce($tf, [double]$f) {
    $lines = @(); $i = 0
    while ($v = $ini.Get($tf, "$i", '')) { $p = $v -split ','; $lines += , @([int]$p[0], $p[1].Trim(), (Test-Transport $p[1].Trim())); $i++ }
    $n = 0; foreach ($l in $lines) { if (-not $l[2]) { $n += $l[0] } }
    if (-not $n) { return $null }
    $target = [Math]::Max(1, [int][Math]::Ceiling($n * $f))
    if ($target -ge $n) { return $null }
    $alloc = @{}; $rest = @(); $given = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i][2]) { continue }
        $exact = $lines[$i][0] * $target / $n; $alloc[$i] = [int][Math]::Floor($exact); $given += $alloc[$i]
        $rest += [pscustomobject]@{ I = $i; R = $exact - $alloc[$i] }
    }
    foreach ($r in @($rest | Sort-Object R -Descending | Select-Object -First ($target - $given))) { $alloc[$r.I]++ }
    @(for ($i = 0; $i -lt $lines.Count; $i++) {
        $c = if ($lines[$i][2]) { $lines[$i][0] } else { $alloc[$i] }
        if ($c -gt 0) { "$c,$($lines[$i][1])" }
    })
}
# the team at one level: a copy with suffix E/M and the scaled taskforce (the script is shared); the same id if the
# taskforce does not shrink (one Ultralisk stays one)
function Get-LevelTeam($tm, $lv) {
    $tm2 = "$tm$($lv.Key)"
    if ($ini.Has($tm2)) { return $tm2 }
    $tf = $ini.Get($tm, 'TaskForce', '')
    $new = Get-ScaledTaskForce $tf $lv.Wave
    if (-not $new) { return $tm }
    $new = @($new)   # one line comes back as a string, and $new[0] would be its first character
    $tf2 = "$tf$($lv.Key)"
    $ini.Set('TaskForces', "$(@($ini.Section('TaskForces')).Count)", $tf2)
    for ($i = 0; $i -lt $new.Count; $i++) { $ini.Set($tf2, "$i", $new[$i]) }
    $ini.Set($tf2, 'Name', "$($ini.Get($tf, 'Name', $tf)) ($($lv.Name))"); $ini.Set($tf2, 'Group', '-1')
    $ini.Set('TeamTypes', "$(@($ini.Section('TeamTypes')).Count)", $tm2)
    foreach ($kv in @($ini.Section($tm))) { $ini.Set($tm2, $kv.Key, $kv.Value) }
    $ini.Set($tm2, 'TaskForce', $tf2); $ini.Set($tm2, 'Name', "$($ini.Get($tm, 'Name', $tm)) ($($lv.Name))")
    $script:diffTeams++
    $tm2
}
function Add-Difficulty($player = 'Allies', $playerNo = 2) {
    $friends = @($ini.Get($player, 'Allies', $player) -split ',' | ForEach-Object { $_.Trim() })
    # teams named by any other action (Create Team of the Zerg builder, Destroy Team) keep one size everywhere
    $fixed = @{}
    foreach ($k in $trig.Keys) { foreach ($a in $trig[$k].Actions) { $p = $a -split ','; if ($p[1] -eq '1' -and $p[0] -notin '7', '80') { $fixed[$p[2]] = $true } } }
    $script:diffTeams = 0; $nWave = 0; $nPay = 0; $long = 0
    foreach ($k in @($trig.Keys)) {
        $t = $trig[$k]; $keep = @(); $waves = @(); $pays = @(); $at = -1
        foreach ($a in $t.Actions) {
            $p = $a -split ','
            if ($p[0] -in '7', '80' -and $p[1] -eq '1' -and -not $fixed[$p[2]] -and $ini.Get($p[2], 'House', '') -notin $friends) {
                if ($at -lt 0) { $at = $keep.Count }; $waves += $a; continue
            }
            if ($p[0] -eq '106' -and $p[2] -eq "$playerNo") { $pays += $a }
            $keep += $a
        }
        if (-not $waves.Count -and -not $pays.Count) { continue }
        if ($at -lt 0) { $at = $keep.Count }
        $en = @()
        foreach ($lv in $DiffLevels) {
            $acts = @(foreach ($a in $waves) { $p = $a -split ','; if ($lv.Wave -lt 1) { $p[2] = Get-LevelTeam $p[2] $lv }; $p -join ',' })
            if ($lv.Money -gt 0) { $acts += @(foreach ($a in $pays) { $p = $a -split ','; $p[3] = "$([int]([int]$p[3] * $lv.Money))"; $p -join ',' }) }
            if (-not $acts.Count) { continue }
            $hk = "$k~d$($lv.Key)"
            Trigger $hk "$($t.Name) ($($lv.Name))" $lv.Events (@($acts) + @(Disable $hk)) -house $player -Disabled -Repeat | Out-Null
            $en += Enable $hk
        }
        $t.Actions = @(for ($i = 0; $i -le $keep.Count; $i++) { if ($i -eq $at) { $en }; if ($i -lt $keep.Count) { $keep[$i] } })
        if ($waves.Count) { $nWave++ }; if ($pays.Count) { $nPay++ }
        # the [Actions] line with real ids (about 10 characters): above ~500 bytes the game crashes at load (pitfall 16)
        $len = ("$($t.Actions.Count)," + (@($t.Actions | ForEach-Object { $q = $_ -split ','; if ($q[1] -eq '2') { $q[2] = 'ARKA0T0000' }; $q -join ',' }) -join ',')).Length
        if ($len -gt 400) { $log.Add("WARN difficulty: trigger '$k' has an action line of ~$len characters"); $long++ }
    }
    $cr = [int]$ini.Get($player, 'Credits', '0') * 100
    foreach ($lv in $DiffLevels) {
        if ($lv.Money -le 0 -or $cr -le 0) { continue }
        Trigger "diffStart$($lv.Key)" "Trudnosc: kredyty na start ($($lv.Name))" $lv.Events @("106,0,$playerNo,$([int]($cr * $lv.Money)),0,0,0,A") -house $player | Out-Null
    }
    $log.Add("difficulty: $nWave triggers with enemy waves, $nPay paying the player, $script:diffTeams scaled teams (E 1/2, M 3/4); start credits $cr +100%/+50%; $long long action lines")
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

# ---------------------------------------------------------------- objective reminders and progress (user 2026-10-29)
# "Add objective reminders and their progress to all missions, but do not overdo it." Call before Split-MultiText (the
# Enable goes to the last line of the $From chain, so the reminder starts after the objective has been read).
#   Add-ObjectiveReminder 'remNest' 'Cel: zniszcz gniazdo...' -From 'nestObj' -Until 7
# A disabled repeating trigger shows the line every $Every game seconds (900 = 15:00 on the timer, a few real minutes;
# Elapsed Time restarts on every firing, as DTA's repeating raids) from the moment $From enables it; a one-shot trigger
# switches it off once every local in $Until is set (or the generator disables $Key itself). Repeating, so the text
# timeline check leaves it out: keep the line short.
function Add-ObjectiveReminder([string]$Key, [string]$Text, [string[]]$From, [int[]]$Until = @(), [int]$Every = 900, $player = 'Allies') {
    foreach ($f in $From) { if (-not $trig.Contains($f)) { throw "Add-ObjectiveReminder: no trigger '$f'" } }
    Trigger $Key "Przypomnienie celu $Key" @((Ev 13 $Every)) @((Text $Text)) -house $player -Disabled -Repeat | Out-Null
    foreach ($f in $From) { $trig[$f].Actions = @($trig[$f].Actions) + @(Enable $Key) }   # several = alternatives (zone or time)
    if ($Until.Count) { Trigger "$Key~off" "Przypomnienie celu $Key wylaczone" @($Until | ForEach-Object { Ev 36 $_ }) @((Disable $Key)) -house $player | Out-Null }
    $script:reminders++
}
# One progress line when the k-th of n locals gets set (k = 1..n-1), in any order: a one-shot trigger per k-subset of the
# locals (all events must hold, AND), the first one of each k switches off its siblings. The line for n of n is the
# generator's own "objective done" text. $Line gets k and n:
#   Add-CountProgress 'surv' @(0, 1, 2) { param($k, $n) "Rozbitkowie: $k z $n zebranych." }
function Add-CountProgress([string]$Key, [int[]]$Locals, [scriptblock]$Line, $player = 'Allies') {
    $n = $Locals.Count; if ($n -lt 2 -or $n -gt 4) { throw "Add-CountProgress: 2-4 locals, got $n" }
    for ($k = 1; $k -lt $n; $k++) {
        $sets = @(for ($m = 1; $m -lt (1 -shl $n); $m++) { $s = @(for ($i = 0; $i -lt $n; $i++) { if ($m -band (1 -shl $i)) { $Locals[$i] } }); if ($s.Count -eq $k) { , $s } })
        $tx = Text (& $Line $k $n)
        $keys = @(for ($i = 0; $i -lt $sets.Count; $i++) { "$Key~$k~$i" })
        for ($i = 0; $i -lt $sets.Count; $i++) {
            $off = @(for ($j = 0; $j -lt $sets.Count; $j++) { if ($j -ne $i) { Disable $keys[$j] } })
            Trigger $keys[$i] "Postep $Key $k z $n ($i)" @($sets[$i] | ForEach-Object { Ev 36 $_ }) (@($tx) + $off) -house $player | Out-Null
        }
    }
    $script:progressLines += $n - 1
}
