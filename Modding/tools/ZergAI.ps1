# General Zerg AI of a mission nest (user 2026-10-29, ARKA 2: "dorob ogolne AI pod niego, ze ma atakowac, bronic sie,
# odpowiadac na ataki gracza ... ale naprawde buduje zergi czy broodlingi"). Wiki: engine/zerg-ai ("Ogolne AI gniazda").
# Dot-source after MissionKit.ps1 (Get-LevelTeam, $DiffLevels, Add-ZergBuilder) and call Add-ZergAI AFTER Add-Difficulty:
# the module scales its squads per level itself (Add-Difficulty would wrap its fallback hatching once more).
# Needs the generator's Team/Trigger/Ev/Act/Reinf/Enable/Disable, $ini, $log, $trig, $H.
#
# What the nest does, all of it with units its Spawning Pool really hatches:
#   - production: the house has IQ 5 ([IQ] Production) and "3 Production Begins"; an order is "4 Create Team" plus
#     "106 Give Credits" with the squad's price (+10%), and the house's AI builds the missing members in its factory
#     (Spawning Pool, Factory=InfantryType; the way ARKA 1's colony filled its teams, confirmed in game). Watchdog: the
#     first script line of every produced team sets the local "produkuje"; while it is clear, a squad still missing
#     $Watchdog seconds after its order hatches at the rally point by "80" (production did not work in game). Once one
#     produced team has started, the fallback never fires again;
#   - attacks: Orders, a timeline of one-shot or repeating orders, each gated by events (mission phase locals);
#   - defense: the player entering the band round the nest (cell tags, Entered by) or hitting a nest building (object
#     tag, 44 Attacked by house) raises an alarm: the nest hatches a defense squad that hunts the attackers and a
#     counter-raid on the player's base (his army is at the nest), then waits Cooldown seconds before the next alarm;
#   - help: Reliefs, other objects (a city of the same Zerg) whose attack makes the nest send a squad there;
#   - growth: Grow, Drones that morph into new colonies (Add-ZergBuilder);
#   - the end: the house loses its nest (tags in LostTags, destroyed by anything) -> no orders, no fallback.
# Difficulty: every order, defense and relief exists once per level of $DiffLevels (Easy 1/2, Medium 3/4 of the squad).
#
#   $zai = Add-ZergAI @{
#       House = 'Nod'; HouseNo = 1; Prefix = 'zai'; Rally = 20; Player = 'Allies'; PlayerNo = 2; Watchdog = 240
#       Squads = [ordered]@{ Raid = @{ Name = 'Gniazdo: najazd'; M = @('SCZLNG', 'SCZLNG'); S = @('16,10', '11,14') } }
#       Orders = @(@{ Sq = 'Raid'; At = 480; Every = 420; When = @('37,0,8') })
#       Alarm = @{ Tag = 'ARKA2Z01'; HitTag = 'ARKA2Z02'; Zone = $cells; Sq = 'Def'; Counter = 'Ctr'; Cooldown = 150; Text = '...' }
#       Reliefs = @(@{ Tag = 'ARKA2Z03'; Sq = 'Rel'; Cooldown = 240; Text = '...' })
#       LostTags = @('ARKA2Z04'); Grow = @{ Wp = 21; Nodes = $plan; Start = 600; Every = 240 }
#   }
#   $zai.Lost   # local set when the nest is lost (add "56,<it>" to the generator's own Hatchery trigger)
# Optional names in the trigger list (defaults = the nest's): Label 'Gniazdo', FallbackWord 'wyklucie', NearText (zone
# trigger). ProtossAI.ps1 (Add-ProtossAI) reuses this module with its own.
function Add-ZergAI($c) {
    $P = $c.Prefix; $hn = $c.House; $hno = [int]$c.HouseNo; $rally = [int]$c.Rally
    $wd = if ($c.Watchdog) { [int]$c.Watchdog } else { 240 }
    # names in the trigger list (other factions: ProtossAI.ps1 sets its own)
    $L = if ($c.Label) { $c.Label } else { 'Gniazdo' }; $Lfb = if ($c.FallbackWord) { $c.FallbackWord } else { 'wyklucie' }
    $Lnear = if ($c.NearText) { $c.NearText } else { 'gracz przy gniezdzie' }
    $pno = if ($c.PlayerNo) { [int]$c.PlayerNo } else { 2 }

    # locals after the generator's own: produced team started, nest lost, alarm, one per relief
    # (the texts wait on their own "seen" local: the alarm local is cleared by the response in the same frame)
    $reliefs = @($c.Reliefs | Where-Object { $_ })
    $last = -1; foreach ($kv in $ini.Section('VariableNames')) { $last = [Math]::Max($last, [int]$kv.Key) }
    $vProd = $last + 1; $vLost = $last + 2; $vAlarm = $last + 3; $vSeen = $last + 4
    $ini.Set('VariableNames', "$vProd", "$L produkuje,0"); $ini.Set('VariableNames', "$vLost", "$L stracone,0")
    $ini.Set('VariableNames', "$vAlarm", "$L atakowane,0"); $ini.Set('VariableNames', "$vSeen", "$L raz atakowane,0")
    $vRel = @(); for ($i = 0; $i -lt $reliefs.Count; $i++) {
        $vRel += $last + 5 + 2 * $i
        $ini.Set('VariableNames', "$($last + 5 + 2 * $i)", "Pomoc $($i + 1) wezwana,0"); $ini.Set('VariableNames', "$($last + 6 + 2 * $i)", "Pomoc $($i + 1) raz wezwana,0")
    }

    # every squad twice: the ordered team (filled by production; up to 3 at once, members recruitable) and its fallback
    # twin hatched by "80" (same squad, the script without the watchdog line); then one copy per level (Get-LevelTeam)
    $tmAI = @{}; $tmFb = @{}
    foreach ($k in $c.Squads.Keys) {
        $q = $c.Squads[$k]
        $tmAI[$k] = Team $q.Name $hn $rally $q.M (@("39,$vProd") + $q.S)
        $ini.Set($tmAI[$k], 'Max', '3'); $ini.Set($tmAI[$k], 'AreTeamMembersRecruitable', 'yes')
        $tmFb[$k] = Team "$($q.Name) ($Lfb)" $hn $rally $q.M $q.S
    }
    $cost = {
        param($tm) $n = 0; $tf = $ini.Get($tm, 'TaskForce', ''); $i = 0
        while ($v = $ini.Get($tf, "$i", '')) { $p = $v -split ','; $n += [int]$p[0] * [int]$ini.Get($p[1].Trim(), 'Cost', '100'); $i++ }
        [int]([Math]::Ceiling($n * 1.1 / 100) * 100)   # a little extra, so a squad never waits for money
    }
    $lvEv = { param($lv) @($lv.Events | Where-Object { $_ -notlike '13,*' }) }   # the level's globals without the 1 s delay
    # the actions of one order at one level: create the team, pay it, arm its fallback
    $order = {
        param($sq, $lv)
        $script:zaiFbN++; $tm = Get-LevelTeam $tmAI[$sq] $lv; $fbTm = Get-LevelTeam $tmFb[$sq] $lv; $fb = "${P}fb$script:zaiFbN"
        Trigger $fb "$($c.Squads[$sq].Name): $Lfb zapasowe ($($lv.Name))" @((Ev 13 $wd), (Ev 37 $vProd), (Ev 37 $vLost)) @(
            (Reinf $fbTm $rally), (Disable $fb)) -house $hn -Disabled -Repeat | Out-Null
        @((Act 4 $tm 1), "106,0,$hno,$(& $cost $tm),0,0,0,A", (Enable $fb))
    }
    $script:zaiFbN = 0

    # production on from the start (the house gets its money with each order)
    Trigger "${P}prod" "$L ${hn}: produkcja" @((Ev 13 1)) @((Act 3 $hno)) -house $hn | Out-Null

    # ---- attacks: one-shot or repeating orders, gated by phase events and by the nest being alive
    $i = 0
    foreach ($o in $c.Orders) {
        $i++; $q = $c.Squads[$o.Sq]; $gate = @((Ev 37 $vLost)) + @($o.When | Where-Object { $_ })
        foreach ($lv in $DiffLevels) {
            $ev = @((Ev 13 ([int]$o.At))) + $gate + @(& $lvEv $lv); $acts = @(& $order $o.Sq $lv)
            if ($o.Every) {
                $rep = "${P}r$i$($lv.Key)"
                Trigger "${P}o$i$($lv.Key)" "$($q.Name) ($($lv.Name))" $ev (@($acts) + @(Enable $rep)) -house $hn | Out-Null
                Trigger $rep "$($q.Name) co $($o.Every) s ($($lv.Name))" (@((Ev 13 ([int]$o.Every))) + $gate + @(& $lvEv $lv)) @(& $order $o.Sq $lv) -house $hn -Disabled -Repeat | Out-Null
            } else {
                Trigger "${P}o$i$($lv.Key)" "$($q.Name) ($($lv.Name))" $ev $acts -house $hn | Out-Null
            }
        }
        $log.Add("Zerg AI order ${i}: $($o.Sq) ($(@($q.M).Count) units, $(& $cost $tmAI[$o.Sq]) credits) at $($o.At) s$(if ($o.Every) { ", then every $($o.Every) s" })$(if ($o.When) { ' when ' + ($o.When -join ' & ') })")
    }

    # ---- defense: the alarm (zone or hit) -> a defense squad and a counter-raid, then a cooldown
    $a = $c.Alarm
    if ($a) {
        $offOn = @("${P}alZone", "${P}alHit")
        Trigger "${P}alZone" "${L}: $Lnear" @((Ev 1 $pno)) @((Act 56 $vAlarm), (Act 56 $vSeen)) -house $hn -Repeat -tag $a.Tag | Out-Null
        Trigger "${P}alHit" "${L}: gracz atakuje budynek" @((Ev 44 $pno)) @((Act 56 $vAlarm), (Act 56 $vSeen)) -house $hn -Repeat -tag $a.HitTag | Out-Null
        foreach ($lv in $DiffLevels) {
            $acts = @(& $order $a.Sq $lv); if ($a.Counter) { $acts += @(& $order $a.Counter $lv) }
            $acts += @((Act 57 $vAlarm)) + @($offOn | ForEach-Object { Disable $_ }) + @(Enable "${P}alRearm")
            Trigger "${P}al$($lv.Key)" "${L}: obrona ($($lv.Name))" (@((Ev 36 $vAlarm), (Ev 37 $vLost)) + @(& $lvEv $lv)) $acts -house $hn -Repeat | Out-Null
        }
        Trigger "${P}alRearm" "${L}: obrona gotowa" @((Ev 13 ([int]$a.Cooldown))) (@($offOn | ForEach-Object { Enable $_ }) + @(Disable "${P}alRearm")) -house $hn -Disabled -Repeat | Out-Null
        if ($a.Text) { Trigger "${P}alText" "${L}: pierwsza obrona" @((Ev 36 $vSeen)) @((Text $a.Text)) -house $c.Player | Out-Null }
        $nz = 0
        foreach ($cell in @($a.Zone)) { $key = "$($cell[1] * 1000 + $cell[0])"; if (-not $ini.Get('CellTags', $key, $null)) { $ini.Set('CellTags', $key, $a.Tag); $nz++ } }
        $log.Add("Zerg AI alarm: zone $nz cells (tag $($a.Tag)), building hits (tag $($a.HitTag)) -> $($a.Sq)$(if ($a.Counter) { " + $($a.Counter)" }), cooldown $($a.Cooldown) s")
    }

    # ---- reliefs: an object of another place attacked by the player -> the nest sends a squad there
    for ($r = 0; $r -lt $reliefs.Count; $r++) {
        $rl = $reliefs[$r]; $v = $vRel[$r]; $when = @($rl.When | Where-Object { $_ }); $k = "${P}rl$r"
        Trigger "${k}Hit" "Pomoc $($r + 1): gracz atakuje" @((Ev 44 $pno)) @((Act 56 $v), (Act 56 ($v + 1))) -house $hn -Repeat -tag $rl.Tag | Out-Null
        foreach ($lv in $DiffLevels) {
            Trigger "$k$($lv.Key)" "Pomoc $($r + 1): wysylka ($($lv.Name))" (@((Ev 36 $v), (Ev 37 $vLost)) + $when + @(& $lvEv $lv)) (
                @(& $order $rl.Sq $lv) + @((Act 57 $v), (Disable "${k}Hit"), (Enable "${k}Rearm"))) -house $hn -Repeat | Out-Null
        }
        Trigger "${k}Rearm" "Pomoc $($r + 1): gotowa" @((Ev 13 ([int]$rl.Cooldown))) @((Enable "${k}Hit"), (Disable "${k}Rearm")) -house $hn -Disabled -Repeat | Out-Null
        if ($rl.Text) { Trigger "${k}Text" "Pomoc $($r + 1): pierwsza" @((Ev 36 ($v + 1))) @((Text $rl.Text)) -house $c.Player | Out-Null }
        $log.Add("Zerg AI relief $($r + 1): tag $($rl.Tag) -> $($rl.Sq), cooldown $($rl.Cooldown) s")
    }

    # ---- the nest lost (destroyed by anything, also captured)
    foreach ($t in @($c.LostTags)) { if ($t) { Trigger "${P}lost$t" "$L stracone" @((Ev 48)) @((Act 56 $vLost)) -house $hn -tag $t | Out-Null } }

    # ---- growth: Drones hatched at the Hatchery morph into planned colonies
    # (not @($c.Grow.Nodes): @() of a List of arrays throws "Argument types do not match")
    if ($c.Grow -and $c.Grow.Nodes -and $c.Grow.Nodes.Count) { Add-ZergBuilder $hn $hno $c.Grow.Wp $c.Grow.Nodes $c.Grow.Start $c.Grow.Every "${P}g" }

    $log.Add("Zerg AI $hn ($P): $(@($c.Orders).Count) order lines, $script:zaiFbN fallbacks, locals produkuje=$vProd stracone=$vLost alarm=$vAlarm")
    @{ Prod = $vProd; Lost = $vLost; Alarm = $vAlarm }
}
