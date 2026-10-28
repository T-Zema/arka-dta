# ARKA 5 "Upadek Tarsonis": a small Zerg nest on the jungle plateau north of Kerrigan's holdout and west of the Protoss
# landing site (user 2026-10-28: "dodaj mala baze zergow na gorze wraz z kopalnia i mineralami no i AI zergow ma sie bic
# z protossami jak i z terranami ma tworzyc jednostki zerglingi i hydraliski"). Dot-sourced by build-arka05-mission.ps1
# before the SC type closure; the generator calls Add-ZergNest (objects, after the Protoss site) and Add-ZergTriggers
# (just before Split-MultiText). Waypoints of the terrain map: 71 Hatchery, 72 crystal field (+ OREMINE2), 73 rally.
#
# House: Nod (index 1, unused before), the nest's own house, so its AI does not touch the scripted Nod1 waves. Allied
# with the other Zerg houses (Nod1, Nod2) and with GDI2/Soviet2 (everybody's friends); enemies: the Protoss (GDI), the
# player (Allies), Kerrigan (GDI1), the city (Allies1), the Sons of Korhal (Soviet), the civilians.
#
# Production (real, from the buildings): IQ=5 + "3 Production Begins"; on a timeline the trigger action "4 Create Team"
# creates a team (Zerglings + Hydralisks) and pays its price to the house ("106 Give Credits"); the house's AI builds the
# missing members in the Spawning Pool (Factory=InfantryType), the way ARKA 1's colony filled its AI teams from its
# Factory (confirmed in game, test 6) and the way ARKA 4's centre nest builds its squads. Chosen over [AITriggerTypes]
# because every team has its own time and target (Kerrigan only before her call, the Protoss only once their defence
# stands, the player only late), and no global ai.ini trigger of the Nod side is started (no "74 AI triggers begin").
# The units need the Pool AND the Hatchery (Hydralisks also the Hydralisk Den): no Hatchery, no new Zerg.
# Watchdog: the first line of every produced team's script sets the local "Gniazdo produkuje" (39,N). If it is still
# clear 240 s after a team was ordered (production did not work in game: no factory exit, AI quirk), the same squad
# hatches at the rally point by "80" instead, so the nest attacks in any case. Once one produced team has started its
# script, the local stays set and no hatching ever happens.
# Fights: every team attack-moves to its target (16,N) and then hunts (11,14), so it keeps fighting until it dies.

# extra SC sections for the closure: Hatchery, Spawning Pool, Hydralisk Den, Extractor (the nest's refinery) and Drone
$ZergRoots = @('SCZHAT', 'SCZPOL', 'SCZHDN', 'SCZEXT', 'SCZWORK')

# layout: type, dx, dy of the top-left cell from wp 71, tag. Laid out by hand on the terrain round wp 71 (a cliff runs
# south-west of the Hatchery, a ridge south-east, the crystal field wp 72 north with the mine at 186,129): one free cell
# between buildings, the field and the mine kept clear, the cells south of the Pool free for its exit. A spot that is
# not free (the terrain map changed) falls back to the nearest free one
$ZergTags = @{ Hatch = 'ARKA5Z01'; Pool = 'ARKA5Z02'; Seen = 'ARKA5Z03' }
$ZergPlan = @(
    @('SCZHAT', -1, -1, 'Hatch'),   # Hatchery (wp 71 in it)
    @('SCZPOL',  4,  0, 'Pool'),    # Spawning Pool, east of the Hatchery: the Zerg come out here
    @('SCZHDN',  5, -4, 'Seen'),    # Hydralisk Den, north-east, by the field
    @('SCZEXT', -8, -7, 'Seen'),    # Extractor, west of the crystal field (the Drones bring crystals here)
    @('SCZSUN',  1,  3, 'Seen'),    # Sunken Colony, south, over the cliff
    @('SCZSUN', 10, -1, 'Seen'),    # Sunken Colony, east, towards the Protoss
    @('SCZCRP',  9, -7, 'Seen'))    # Creep Colony, north-east

# what the nest sends: key, members, script after the watchdog line. L = Zergling (100), H = Hydralisk (500)
$zL = 'SCZLNG'; $zH = 'SCZHYL'
$ZergSquads = [ordered]@{
    Ker  = @{ Name = 'Gniazdo: na Kerrigan';      M = @($zL, $zL, $zL, $zL, $zL, $zL, $zH, $zH); S = @('16,48', '11,14') }
    Pro  = @{ Name = 'Gniazdo: na Protossow';     M = @($zL, $zL, $zL, $zL, $zL, $zL, $zH, $zH); S = @('16,51', '11,14') }
    ProL = @{ Name = 'Gniazdo: zerglingi na Protossow'; M = @($zL, $zL, $zL, $zL, $zL, $zL, $zL, $zL); S = @('16,51', '11,14') }
    Gam  = @{ Name = 'Gniazdo: na Gamme';         M = @($zL, $zL, $zL, $zL, $zL, $zH, $zH, $zH); S = @('16,35', '11,14') }
    Ply  = @{ Name = 'Gniazdo: na gracza';        M = @($zL, $zL, $zL, $zL, $zL, $zL, $zH, $zH); S = @('0,3', '16,10', '11,14') }
}
# timeline (game seconds): one-shot orders, then three repeating ones. 'call' = only while Kerrigan has not called yet.
# Calm start as the rest of the mission: the first squad goes for Kerrigan's holdout at 7:00 (it is under pressure from
# 2:00 anyway), the Protoss only from 12:00 (Gateway, Forge, a cannon and 4 Zealots stand by then), the player from 30:00
$ZergOrders = @(
    @{ At = 420;  Sq = 'Ker';  Gate = 'call' },
    @{ At = 720;  Sq = 'Pro' },
    @{ At = 1020; Sq = 'Gam' },
    @{ At = 1320; Sq = 'ProL' },
    @{ At = 1560; Sq = 'Ker';  Gate = 'call' },
    @{ At = 1800; Sq = 'Ply' },
    @{ At = 2040; Sq = 'Pro';  Every = 600 },
    @{ At = 2340; Sq = 'Gam';  Every = 720 },
    @{ At = 2700; Sq = 'Ply';  Every = 900 })
$ZergWatchdog = 240   # seconds after an order before the squad hatches by itself (production did not start)

function Add-ZergNest {
    # the nest's house: a computer player that produces (IQ 5 = [IQ] Production), no money of its own (paid per order),
    # no base nodes (it does not rebuild: Zerg buildings come from Drones, engine/zerg-ai)
    $ini.Set('Nod', 'IQ', '5'); $ini.Set('Nod', 'Credits', '0'); $ini.Set('Nod', 'Edge', 'East')
    $ini.Set('Nod', 'Allies', 'Nod,Nod1,Nod2,GDI2,Soviet2')
    # the other Zerg houses and everybody's friends do not fight the nest
    # ($hn, not $h: PowerShell names ignore case and $H is the generator's house index)
    foreach ($hn in 'Nod1', 'Nod2', 'GDI2', 'Soviet2') {
        $a = @($ini.Get($hn, 'Allies', $hn) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($a -notcontains 'Nod') { $ini.Set($hn, 'Allies', (@($a) + 'Nod') -join ',') }
    }
    # the nest may build Zerglings and Hydralisks: its house in Owner, a real tech level (the generator sets -1 on every
    # SC type; the player cannot build them: Owner has no Allies), and the Hatchery as prerequisite next to the Pool
    # (Den), so that production stops with the Hatchery
    $ini.Set($zL, 'Owner', 'Nod1,Nod'); $ini.Set($zL, 'TechLevel', '1'); $ini.Set($zL, 'Prerequisite', 'SCZPOL,SCZHAT')
    $ini.Set($zH, 'Owner', 'Nod1,Nod'); $ini.Set($zH, 'TechLevel', '2'); $ini.Set($zH, 'Prerequisite', 'SCZPOL,SCZHDN,SCZHAT')
    # the Hydralisk Den is a research "construction yard" in the faction file (Factory=BuildingType, zerg-research):
    # nothing to research here, and an IQ 5 house must not take it for a ConYard
    $s = $ini.Section('SCZHDN'); for ($i = $s.Count - 1; $i -ge 0; $i--) { if ($s[$i].Key -in 'Factory', 'Upgrades') { $s.RemoveAt($i) } }
    # the Drones only mine for show (the house is paid per order; its AI builds nothing it was not ordered): a small
    # load, and no hatching flags (nobody hatches Drones here; Naval=yes is for the Hatchery's larva exit)
    $s = $ini.Section('SCZWORK'); for ($i = $s.Count - 1; $i -ge 0; $i--) { if ($s[$i].Key -in 'Naval', 'BuiltAt', 'Prerequisite') { $s.RemoveAt($i) } }
    $ini.Set('SCZWORK', 'Storage', '3')

    $c = $wp[71]
    foreach ($b in $ZergPlan) {
        $type = $b[0]; $f = Foundation $type
        $s = @(($c[0] + $b[1]), ($c[1] + $b[2]))
        $script:noStreet = $true
        try { if (-not (Free $s[0] $s[1] $f[0] $f[1] 0 $false)) { $log.Add("Zerg nest $type : planned spot $($s[0]),$($s[1]) not free, nearest free one used"); $s = Find-Spot $s[0] $s[1] $f[0] $f[1] 1 $false } }
        finally { $script:noStreet = $false }
        Add-Building 'Nod' $type $s[0] $s[1] $ZergTags[$b[3]] 0
        $log.Add("Zerg nest $type @ $($s[0]),$($s[1])")
    }
    # the rally point (fallback hatching spot): no building planned later may take it (Find-Spot without reserved cells)
    Reserve $wp[73][0] $wp[73][1] 1
    # guard: Zerglings by the Hatchery and the field, Hydralisks by the Pool (not recruitable: map units have the
    # recruit flags 0, so the ordered teams never take them away)
    Squad 'Nod' @($zL, $zL, $zL, $zL) 71 3 -3 'Area Guard'
    Squad 'Nod' @($zL, $zL, $zL) 71 -3 3 'Area Guard'
    Squad 'Nod' @($zH, $zH, $zH) 71 7 3 'Area Guard'
    # Overlords over the nest, and two Drones on the crystal field
    foreach ($o in @(@(3, -6), @(-5, -1), @(11, -4))) { Add-Unit 'Nod' 'SCZOVL' ($c[0] + $o[0]) ($c[1] + $o[1]) 'Guard' }
    foreach ($o in @(@(-3, -3), @(-2, -3))) { Add-Unit 'Nod' 'SCZWORK' ($c[0] + $o[0]) ($c[1] + $o[1]) 'Harvest' }
}

function Add-ZergTriggers {
    # two locals after the generator's own: "a produced team has started" (watchdog off) and "nest lost"
    $last = -1; foreach ($kv in $ini.Section('VariableNames')) { $last = [Math]::Max($last, [int]$kv.Key) }
    $vProd = $last + 1; $vLost = $last + 2
    $ini.Set('VariableNames', "$vProd", 'Gniazdo produkuje,0'); $ini.Set('VariableNames', "$vLost", 'Gniazdo zniszczone,0')

    # teams: the ordered one (filled by the house's production; Max 3 at once, members recruitable) and its fallback
    # twin hatched by "80" (same squad, the script without the watchdog line)
    $tmAI = @{}; $tmFb = @{}
    foreach ($k in $ZergSquads.Keys) {
        $q = $ZergSquads[$k]
        $tmAI[$k] = Team $q.Name 'Nod' 73 $q.M (@("39,$vProd") + $q.S)
        $ini.Set($tmAI[$k], 'Max', '3'); $ini.Set($tmAI[$k], 'AreTeamMembersRecruitable', 'yes')
        $tmFb[$k] = Team "$($q.Name) (wyklucie)" 'Nod' 73 $q.M $q.S
    }

    # production on from the start (the house has no money until the first order)
    Trigger 'zergProd' 'Gniazdo: produkcja' @((Ev 13 1)) @((Act 3 $H.Nod)) -house 'Nod'
    $i = 0
    foreach ($o in $ZergOrders) {
        $i++; $q = $ZergSquads[$o.Sq]
        $cost = 0; foreach ($m in $q.M) { $cost += [int]$scSec[$m]['Cost'] }
        $cost = [int]([Math]::Ceiling($cost * 1.1 / 100) * 100)   # a little extra, so a squad never waits for money
        $gate = @((Ev 37 $vLost)); if ($o.Gate -eq 'call') { $gate += (Ev 37 $V.Call) }
        $fb = "zergFb$i"
        $order = @((Act 4 $tmAI[$o.Sq] 1), (Credits 'Nod' $cost), (Enable $fb))
        if ($o.Every) {
            Trigger "zergOrd$i" "$($q.Name) (pierwszy)" (@((Ev 13 $o.At)) + $gate) (@($order) + @(Enable "zergRep$i")) -house 'Nod'
            Trigger "zergRep$i" "$($q.Name) (co $($o.Every) s)" (@((Ev 13 $o.Every)) + $gate) $order -house 'Nod' -Disabled -Repeat
        } else {
            Trigger "zergOrd$i" $q.Name (@((Ev 13 $o.At)) + $gate) $order -house 'Nod'
        }
        # watchdog: nothing produced yet -> the squad hatches at the rally point; it switches itself off (enabled again
        # by the next order of the same line; Enable resets its timer)
        Trigger $fb "$($q.Name): wyklucie zapasowe" @((Ev 13 $ZergWatchdog), (Ev 37 $vProd), (Ev 37 $vLost)) @(
            (Reinf $tmFb[$o.Sq] 73), (Disable $fb)) -house 'Nod' -Disabled -Repeat
        $log.Add("Zerg nest order ${i}: $($o.Sq) ($($q.M.Count) units, $cost credits) at $($o.At) s$(if ($o.Every) { ", then every $($o.Every) s" })$(if ($o.Gate) { ' (before Kerrigan calls)' })")
    }

    # the nest discovered (tag on the Den, the colonies and the Extractor)
    Trigger 'zergSeen' 'Gniazdo odkryte' @((Ev 4)) @(
        (Text 'Tanya: Gniazdo Zergow na plaskowyzu nad Kerrigan. Wylega nowe Zergi i rzuca je na Protossow i na nas.')) -house 'Nod' -tag $ZergTags.Seen
    # the nest lost: Hatchery or Spawning Pool destroyed -> no more orders, no fallback hatching
    Trigger 'zergHatch' 'Gniazdo: Wylegarnia zniszczona' @((Ev 48)) @((Act 56 $vLost),
        (Text 'Jim Raynor: Wylegarnia zgnieciona. Z tego gniazda nic juz nie wyjdzie.')) -house 'Nod' -tag $ZergTags.Hatch
    Trigger 'zergPool' 'Gniazdo: Niecka zniszczona' @((Ev 48)) @((Act 56 $vLost)) -house 'Nod' -tag $ZergTags.Pool
}
