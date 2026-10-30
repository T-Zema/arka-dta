# General Protoss AI of a mission base (user 2026-10-30: "dorob AI protossow, inspiruj sie AI ze SC ... docelowo ma dzialac
# w misji 6"). Missions do not run DTA's Advanced AI (wiki engine/advanced-ai: it would take every computer house and the
# AITriggers are dead under it), so a mission base is triggers, like the Zerg nest: this module is Add-ZergAI (ZergAI.ps1:
# ordered teams filled by the house's production, fallback, timeline, alarm, reliefs) with Protoss squads and SC timing.
# Wiki: mods/protoss-ai ("Misje"), plans/protoss-ai, engine/zerg-ai.
# Dot-source after MissionKit.ps1 and ZergAI.ps1; call Add-ProtossAI AFTER Add-Difficulty (like Add-ZergAI).
#
# SC model (aiscript.bin, campaign scripts PLOx/PMEx/PHIx = Easy/Medium/Difficult): a fixed base that is rebuilt, a home
# guard of 2 Zealots + Dragoon, and timed waves every ~126 s that grow: 3 Zealots -> 4 Zealots + 2 Dragoons -> 6 Zealots +
# 4 Dragoons -> + Reaver -> Templars. Here:
#   - production: the house (IQ 5) builds its squads at the Gateway (infantry) and the Robotics Facility (Reaver: Naval=yes
#     vehicle, classic AI_Naval_Unit), paid by "106 Give Credits" with each order;
#   - "warp-in": a squad still missing $Watchdog s after its order appears by reinforcement at the rally Pylon;
#   - the Pylons: when ALL tagged Pylons are destroyed (Pylons = @(tags)) the base is "lost": no more orders, no warp-ins
#     (ARKA 6: "3 Pylony zniszczone = koniec dosylania"). LostTags (e.g. the Nexus) still end it at once.
# The member types must be buildable by the house in the map (TechLevel 0..house level, Owner= with the house, the factory
# in the map for the house): Test-ProtossBuildable logs what is not.
#
#   $pai = Add-ProtossAI @{
#       House = 'GDI2'; HouseNo = 8; Prefix = 'pai'; Rally = 21; Player = 'Allies'; PlayerNo = 2; Watchdog = 200
#       Squads = (Get-ProtossSquads -Target 12 -Base 23)       # or an own [ordered] table like Add-ZergAI's
#       Orders = (Get-ProtossOrders -When @('36,7'))           # SC Difficult timeline, gated by mission locals
#       Alarm = @{ Tag = 'ARKA6P01'; HitTag = 'ARKA6P02'; Zone = $cells; Sq = 'Def'; Counter = 'Counter'; Cooldown = 150 }
#       Pylons = @('ARKA6P10', 'ARKA6P11', 'ARKA6P12'); LostTags = @('ARKA6P13')
#   }
#   $pai.Lost   # local set when the base is lost (all Pylons, or a LostTags object)

# SC campaign squads (PHIx). Scripts: patrol to the target waypoint, then Hunt; the guard stays at home (Area Guard);
# the Dark Templar go for harvesters (0,3 = attack quarry "harvesters"), then Hunt.
function Get-ProtossSquads([int]$Target, [int]$Base) {
    $go = @("16,$Target", '11,14')
    [ordered]@{
        Wave1   = @{ Name = 'Protossi: fala 1'; M = @('SCPZEAL') * 3; S = $go }
        Wave2   = @{ Name = 'Protossi: fala 2'; M = @('SCPZEAL') * 4 + @('SCPDRAG') * 2; S = $go }
        Wave3   = @{ Name = 'Protossi: fala 3'; M = @('SCPZEAL') * 6 + @('SCPDRAG') * 4; S = $go }
        Wave4   = @{ Name = 'Protossi: fala 4'; M = @('SCPZEAL') * 6 + @('SCPDRAG') * 4 + @('SCPREAV'); S = $go }
        Templar = @{ Name = 'Protossi: templariusze'; M = @('SCPDRAG') * 4 + @('SCPHTMP') * 2 + @('SCPZEAL') * 4; S = $go }
        Raid    = @{ Name = 'Protossi: Dark Templar'; M = @('SCPDTMP') * 2; S = @('0,3', '11,14') }
        Def     = @{ Name = 'Protossi: obrona'; M = @('SCPZEAL') * 2 + @('SCPDRAG'); S = @("16,$Base", '11,10') }
        Counter = @{ Name = 'Protossi: kontratak'; M = @('SCPZEAL') * 4 + @('SCPDRAG') * 2; S = $go }
    }
}

# SC Difficult timeline: first wave at 189 s, then one every 126 s, bigger each time; the Templars and Dark Templar once
# the base has its tech (later). $When = extra events on every order (mission phase locals).
function Get-ProtossOrders([string[]]$When = @(), [int]$Start = 189, [int]$Step = 126) {
    $w = @($When | Where-Object { $_ })
    @(
        @{ Sq = 'Wave1'; At = $Start; When = $w }
        @{ Sq = 'Wave2'; At = $Start + $Step; When = $w }
        @{ Sq = 'Wave3'; At = $Start + 2 * $Step; When = $w }
        @{ Sq = 'Wave4'; At = $Start + 3 * $Step; Every = 2 * $Step; When = $w }
        @{ Sq = 'Raid'; At = $Start + 4 * $Step; Every = 3 * $Step; When = $w }
        @{ Sq = 'Templar'; At = $Start + 5 * $Step; Every = 3 * $Step; When = $w }
    )
}

# logs every squad member the house cannot build in this map (production would wait for it; the warp-in still comes)
function Test-ProtossBuildable($c) {
    $tl = [int]$ini.Get($c.House, 'TechLevel', '10'); $bad = 0
    foreach ($t in @($c.Squads.Values | ForEach-Object { $_.M }) | Select-Object -Unique) {
        $lvl = [int]$ini.Get($t, 'TechLevel', '-1'); $own = @($ini.Get($t, 'Owner', '') -split ',' | ForEach-Object { $_.Trim() })
        $why = @()
        if ($lvl -lt 0 -or $lvl -gt $tl) { $why += "TechLevel=$lvl (house $tl)" }
        if ($own -notcontains $c.House) { $why += "Owner=$($own -join ',')" }
        if ($why) { $bad++; $log.Add("Protoss AI WARNING: $t not buildable by $($c.House): $($why -join ', ')") }
    }
    $bad
}

function Add-ProtossAI($c) {
    $P = $c.Prefix; $hn = $c.House
    $cfg = @{}; foreach ($k in $c.Keys) { if ($k -ne 'Pylons') { $cfg[$k] = $c[$k] } }
    $cfg.Label = 'Protossi'; $cfg.FallbackWord = 'przywolanie'; $cfg.NearText = 'gracz przy bazie'
    [void](Test-ProtossBuildable $c)
    $r = Add-ZergAI $cfg

    # the Pylons: one local per Pylon, the base is lost when all are set
    $pylons = @($c.Pylons | Where-Object { $_ })
    if ($pylons.Count) {
        $last = -1; foreach ($kv in $ini.Section('VariableNames')) { $last = [Math]::Max($last, [int]$kv.Key) }
        $ev = @()
        for ($i = 0; $i -lt $pylons.Count; $i++) {
            $v = $last + 1 + $i
            $ini.Set('VariableNames', "$v", "Pylon $($i + 1) zniszczony,0")
            Trigger "${P}py$i" "Protossi: Pylon $($i + 1) zniszczony" @((Ev 48)) @((Act 56 $v)) -house $hn -tag $pylons[$i] | Out-Null
            $ev += Ev 36 $v
        }
        Trigger "${P}pyAll" 'Protossi: wszystkie Pylony zniszczone' $ev @((Act 56 $r.Lost)) -house $hn | Out-Null
        $log.Add("Protoss AI ${hn}: $($pylons.Count) Pylons (tags $($pylons -join ',')) end the reinforcements")
    }
    $r
}
