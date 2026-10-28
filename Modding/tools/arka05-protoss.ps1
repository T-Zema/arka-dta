# ARKA 5 "Upadek Tarsonis": the Protoss landing site (house GDI, hostile to everybody) builds itself up over the
# mission, so it looks like the Protoss arrive slowly (user 2026-10-28: "protosi maja sie zbudowac, zeby wygladalo, ze
# przychodza tam powoli"). Dot-sourced by build-arka05-mission.ps1 (before the SC type closure); the generator calls
# Add-ProtossLanding where the static site used to be and Add-ProtossTriggers just before Split-MultiText.
#
# How: GDI is a computer house that builds (wiki engine/triggers-and-dialogue "Komputerowy dom, ktory gra", the pattern
# of Raynor's colony in ARKA 1): IQ=5, a Nexus (ConYard, added to [AI] BuildConst: Vinifera builds no structure without
# a BuildConst type), base nodes in the house section (NodeCount + 000=TYPE,x,y; the AI builds the first missing node,
# then the next, each with its warp-in Buildup) and "3 Production Begins". The pace comes from money: the house has 0
# credits and gets the price of one building at a time ("106 Give Credits"), so the base grows on a timeline instead of
# appearing within two minutes (BuildSpeed .8 = 48 s per 1000 credits). Zealots and Dragoons warp in at the guard spot
# (wp 51) by reinforcement with a light flash once the Gateway / Cybernetics Core should stand. They only guard the site
# (Area Guard); two small Overlord drops give the site a local fight with the swarm. No new texts.
#
# Start (0:00): Nexus (tag ARKA5G06 = "Protoss discovered") + 1 Pylon + 2 Zealots. Everything else by ~25:00.

# extra SC sections for the closure: the Nexus (ConYard), the Forge (Photon Cannon prerequisite), the Cybernetics Core
$ProtossRoots = @('SCPNEX', 'SCPFOR', 'SCPCYB')

# build order = base node order (the AI builds the first missing node; each one's prerequisite comes earlier):
# type, dx, dy of the top-left cell from the Nexus' top-left cell, game second the money for it arrives (0 = stands
# from the start). Laid out by hand on the terrain round wp 50 (cliffs west and north-west of the Nexus, the map edge
# north-east, a cliff and water east): one free cell between buildings, the guard spot wp 51 kept clear. A spot that
# is not free (the terrain map changed) falls back to the nearest free one
$ProtossPlan = @(
    @('SCPPYL',  5,  0,    0),   # the first Pylon, east of the Nexus (node 0, so it is rebuilt if lost)
    @('SCPPYL',  7, -4,   45),   # north-east
    @('SCPGAT',  4,  4,  150),   # south-east
    @('SCPFOR', -1,  4,  300),   # south
    @('SCPCAN',  8, -1,  480),   # east
    @('SCPPYL',  0,  8,  660),   # south, by the guard spot
    @('SCPCAN',  4,  9,  780),   # south-east
    @('SCPCYB',  1, 12,  960),   # far south
    @('SCPCAN', -4, 12, 1140),   # south-west, over the guard spot
    @('SCPPYL',  9,  2, 1320))   # east
# warp-ins at the guard spot: game second, members (Dragoons only after the Cybernetics Core)
$ProtossWarps = @(
    @(420,  @('SCPZEAL', 'SCPZEAL')),
    @(900,  @('SCPZEAL', 'SCPZEAL')),
    @(1260, @('SCPDRAG', 'SCPDRAG')),
    @(1500, @('SCPZEAL', 'SCPDRAG')))
# after the build-up: a little money now and then, so the AI rebuilds what the swarm or the player destroys
$ProtossRebuild = @(1680, 360, 400)   # first, every, credits

function Add-ProtossLanding {
    # the AI house: builds base nodes once production begins; no money of its own
    $ini.Set('GDI', 'IQ', '5'); $ini.Set('GDI', 'Credits', '0')
    # Vinifera builds structures only for a house that owns a [AI] BuildConst type; the map key replaces the Rules
    # list, so the Rules entries stay (StarCraft.ini is not loaded in a campaign mission)
    $bc = $ini.Get('AI', 'BuildConst', $rules['AI']['BuildConst'])
    if (($bc -split ',') -notcontains 'SCPNEX') { $ini.Set('AI', 'BuildConst', "$bc,SCPNEX") }
    # the AI may build these: owned by GDI (the copies say GDI2) and a real tech level (the generator sets -1 on every
    # SC type; the player cannot build them anyway: Owner=GDI, and the Pylon needs a Nexus)
    # (AIBuildThis=no stays: it is the skirmish base planner's key; the ARKA 1 colony rebuilt its SC bunkers from base
    # nodes with it, with TechLevel=1 and the house in Owner, as here)
    foreach ($t in 'SCPNEX', 'SCPPYL', 'SCPGAT', 'SCPFOR', 'SCPCAN', 'SCPCYB') { $ini.Set($t, 'Owner', 'GDI'); $ini.Set($t, 'TechLevel', '1') }

    # the guard spot stays free of buildings (the warp-ins appear there)
    Reserve $wp[51][0] $wp[51][1] 2
    Place-AtWp 'GDI' 'SCPNEX' 50 1 'ARKA5G06'
    $nex = $structs[$structs.Count - 1].Value -split ','; $nexF = Foundation 'SCPNEX'
    $matrix = New-Object Collections.Generic.List[object]   # Nexus + Pylons: what gives the build range
    $matrix.Add(@([int]$nex[3], [int]$nex[4], $nexF[0], $nexF[1]))
    $nodes = New-Object Collections.Generic.List[string]
    foreach ($b in $ProtossPlan) {
        $type = $b[0]; $f = Foundation $type
        $s = @(([int]$nex[3] + $b[1]), ([int]$nex[4] + $b[2]))
        $script:noStreet = $true
        try { if (-not (Free $s[0] $s[1] $f[0] $f[1] 0 $false)) { $log.Add("Protoss $type : planned spot $($s[0]),$($s[1]) not free, nearest free one used"); $s = Find-Spot $s[0] $s[1] $f[0] $f[1] 1 $false } }
        finally { $script:noStreet = $false }
        # gap to the nearest Nexus/Pylon placed before it (the Protoss build range is 6 cells, Adjacent=6/8)
        $gap = 99
        foreach ($m in $matrix) {
            $gx = [Math]::Max(0, [Math]::Max($m[0] - ($s[0] + $f[0] - 1), $s[0] - ($m[0] + $m[2] - 1)))
            $gy = [Math]::Max(0, [Math]::Max($m[1] - ($s[1] + $f[1] - 1), $s[1] - ($m[1] + $m[3] - 1)))
            $gap = [Math]::Min($gap, [Math]::Max($gx, $gy) - 1)
        }
        if ($gap -gt 6) { $log.Add("WARN Protoss $type @ $($s[0]),$($s[1]) is $gap cells from the matrix (more than 6)") }
        if ($b[3] -eq 0) { Add-Building 'GDI' $type $s[0] $s[1] 'None' 0 }
        else { Occupy $s[0] $s[1] $f[0] $f[1]; $log.Add("Protoss node $type @ $($s[0]),$($s[1]) built after $($b[3]) s (gap $gap)") }
        if ($type -eq 'SCPPYL') { $matrix.Add(@($s[0], $s[1], $f[0], $f[1])) }
        $nodes.Add("$type,$($s[0]),$($s[1])")
    }
    $ini.Set('GDI', 'NodeCount', "$($nodes.Count)")
    for ($i = 0; $i -lt $nodes.Count; $i++) { $ini.Set('GDI', ('{0:D3}' -f $i), $nodes[$i]) }
    # the vanguard: two Zealots on the guard spot
    Squad 'GDI' @('SCPZEAL', 'SCPZEAL') 51 0 0 'Area Guard'
}

function Add-ProtossTriggers {
    # the AI starts building at once (the first node waits for its money)
    Trigger 'pProd' 'Protossi: budowa' @((Ev 13 1)) @((Act 3 $H.GDI)) -house 'GDI'
    # the money for one building at a time
    $i = 0
    foreach ($b in $ProtossPlan) {
        if ($b[3] -eq 0) { continue }
        $i++; $cost = [int]$scSec[$b[0]]['Cost']
        Trigger "pCash$i" "Protossi: $($b[0]) ($cost)" @((Ev 13 $b[3])) @((Credits 'GDI' $cost)) -house 'GDI'
    }
    Trigger 'pCash1R' 'Protossi: odbudowa (start)' @((Ev 13 $ProtossRebuild[0])) @((Credits 'GDI' $ProtossRebuild[2]), (Enable 'pCashR')) -house 'GDI'
    Trigger 'pCashR' 'Protossi: odbudowa' @((Ev 13 $ProtossRebuild[1])) @((Credits 'GDI' $ProtossRebuild[2])) -house 'GDI' -Disabled -Repeat
    # warp-ins: a small flash on the guard spot and the squad appears there, then guards the site
    $w = 0
    foreach ($x in $ProtossWarps) {
        $w++
        $tm = Team "Protossi: przywolanie $w" 'GDI' 51 $x[1] @('11,10')
        Trigger "pWarp$w" "Protossi: przywolanie $w" @((Ev 13 $x[0])) @((Act 64 51), (Reinf $tm 51)) -house 'GDI'
    }
    # local fights: two small Overlord drops of the swarm on the site, from the east-south entry
    $zL = 'SCZLNG'; $zH = 'SCZHYL'
    $tz1 = Drop 'Roj na Protossow 1' 45 51 @($zL, $zL, $zL, $zL, $zH, $zH) @('16,50', '11,10')
    $tz2 = Drop 'Roj na Protossow 2' 45 51 @($zL, $zL, $zL, $zL, $zL, $zL, $zH, $zH) @('16,50', '11,10')
    Trigger 'pZerg1' 'Roj na Protossow 1' @((Ev 13 1150)) @((Reinf $tz1 45)) -house 'Nod1'
    Trigger 'pZerg2' 'Roj na Protossow 2' @((Ev 13 2150)) @((Reinf $tz2 45)) -house 'Nod1'
    # raids on the Zerg nest (user 2026-10-28: the Protoss were too passive): warped in on the guard spot, they move
    # along the cliffs (wp 74, 75: the terrain map's route that keeps 16 cells away from Kerrigan, so they do not pick a
    # fight with the Terrans on the way; still hostile to them), attack-move into the nest (wp 71) and guard its ruins
    $pZ = 'SCPZEAL'; $pD = 'SCPDRAG'
    # unit limit (user 2026-10-28: "protosi spamuja"): the raids stayed guarding the nest's ruins and piled up, one
    # squad every 420 s and one every 540 s. Now each stream has one squad out at a time: its members carry the stream's
    # tag (TeamType Tag=), a semi-persistent trigger on "destroyed" springs when the whole squad is dead and only then
    # re-arms the stream's timer; the timer trigger disables itself when it sends the next squad. At most one big raid
    # (7) and one Dragoon raid (6) on the map, besides the site's guards
    $tagZ = 'ARKA5GPZ'; $tagD = 'ARKA5GPD'
    $tr1 = Team 'Protossi: wypad na gniazdo' 'GDI' 51 @($pZ, $pZ, $pZ, $pD, $pD) @('3,74', '3,75', '16,71', '11,10') $tagZ
    $tr2 = Team 'Protossi: wypad na gniazdo (duzy)' 'GDI' 51 @($pZ, $pZ, $pZ, $pZ, $pD, $pD, $pD) @('3,74', '3,75', '16,71', '11,10') $tagZ
    # more aggressive (user 2026-10-28: "protosi bardziej agresywni wobec bazy zergow"): first raid at 15:00 (was 25:00),
    # the big raid 420 s after the last one died (was every 600 s), and from 20:00 a second, Dragoon-heavy stream
    # 540 s after its last squad died
    $tr3 = Team 'Protossi: wypad Dragoonow' 'GDI' 51 @($pD, $pD, $pD, $pD, $pZ, $pZ) @('3,74', '3,75', '16,71', '11,10') $tagD
    Trigger 'pRaid1' 'Protossi: pierwszy wypad' @((Ev 13 900)) @((Act 64 51), (Reinf $tr1 51)) -house 'GDI'
    Trigger 'pRaidZX' 'Protossi: wypad rozbity' @((Ev 48)) @((Enable 'pRaidR')) -house 'GDI' -tag $tagZ -Semi
    Trigger 'pRaidR' 'Protossi: wypad (po rozbiciu poprzedniego)' @((Ev 13 420)) @((Act 64 51), (Reinf $tr2 51), (Disable 'pRaidR')) -house 'GDI' -Disabled -Repeat
    Trigger 'pRaidD' 'Protossi: wypad Dragoonow' @((Ev 13 1200)) @((Act 64 51), (Reinf $tr3 51)) -house 'GDI'
    Trigger 'pRaidDX' 'Protossi: wypad Dragoonow rozbity' @((Ev 48)) @((Enable 'pRaidDR')) -house 'GDI' -tag $tagD -Semi
    Trigger 'pRaidDR' 'Protossi: wypad Dragoonow (540 s po rozbiciu)' @((Ev 13 540)) @((Act 64 51), (Reinf $tr3 51), (Disable 'pRaidDR')) -house 'GDI' -Disabled -Repeat
}
