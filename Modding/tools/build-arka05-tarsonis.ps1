# Terrain of ARKA mission 5 "Upadek Tarsonis" (Tarsonis, 2500): the StarCraft Terran campaign map "Operation Silent
# Scream" (CASC SD/campaign/Terran/Terran10; the briefing line reads "Command Ship Hyperion, holding close orbit over
# Confederate Capitol World, Tarsonis"). It is the psi-emitter mission of the plan: three emitters on beacons by the
# west edge, the south-west coast and the south-east pocket, three Confederate towns (Delta NW, Nova NE, Omega SW) with
# SC civilians, a settlement of civilians in the east (here district Gamma), and the landing zone in a crater in the
# middle, where Kerrigan and Raynor start in StarCraft. Jungle -> DTA TEMPERATE, zoom 1.25.
# On top of the port: paved squares in the four districts and on the landing zone, paved streets (Paved Road LAT, the
# DTA way) from the landing zone to every district, three crystal fields and a crystal mine (workflow/mission-design).
# Writes Maps\Custom\arka05_tarsonis.map (viewable as a skirmish "Custom Map") and the mission waypoints 10-64 and 71-73, which
# are the contract with build-arka05-mission.ps1.
#
#   powershell -NoProfile -File .\build-arka05-tarsonis.ps1            # build + checks + preview + render (~2 min)
#   powershell -NoProfile -File .\build-arka05-tarsonis.ps1 -NoRender  # no CNCMaps render
#
# Work files: %TEMP%\arka05-terrain\ (sc.png, sc_grid.png, grid.png, reach.png, compare_sc.png, waypoints.png, log.txt).
# Wiki: Modding/wiki/missions/arka-05-tarsonis.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$Out = "",
    [double]$Zoom = 1.25,
    [switch]$NoRender
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Out) { $Out = "$game\Maps\Custom\arka05_tarsonis.map" }
$work = "$env:TEMP\arka05-terrain"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScMap.cs", "$tools\TsMap.cs", "$tools\ScToDta.cs" -ReferencedAssemblies System.Drawing

# ================================================================ StarCraft side: "Operation Silent Scream", jungle, 128x128
$casc = New-Object Casc $StarCraft
$chk  = New-Object Chk (, $casc.ReadFile('SD/campaign/Terran/Terran10/staredit/scenario.chk'))
$ts   = New-Object ScTileset $casc, ([Chk]::EraNames[$chk.Era])
$ter  = New-Object ScTerrain $chk, $ts
"SC map: $($chk.Width)x$($chk.Height) $([Chk]::EraNames[$chk.Era]), zoom $Zoom"
$sc = $ter.RenderNatural(4); $sc.Save("$work\sc.png"); $sc.Dispose()

# drop the vespene geysers (the converter turns them into Tiberium trees; nobody here knows Tiberium yet)
$chk.Units.RemoveAll([Predicate[ScUnit]] { param($u) $u.Id -eq 188 }) | Out-Null

if ($Zoom -ne 1) {
    $w0 = $ter.W; $h0 = $ter.H; $w1 = [int]($w0 * $Zoom); $h1 = [int]($h0 * $Zoom)
    $fl = New-Object 'int[]' ($w1 * $h1); $rgb = New-Object 'int[]' $fl.Length
    for ($y = 0; $y -lt $h1; $y++) { for ($x = 0; $x -lt $w1; $x++) {
        $src = [Math]::Min($h0 - 1, [Math]::Floor($y / $Zoom)) * $w0 + [Math]::Min($w0 - 1, [Math]::Floor($x / $Zoom))
        $fl[$y * $w1 + $x] = $ter.Flags[$src]; $rgb[$y * $w1 + $x] = $ter.Rgb[$src]
    } }
    $ter.W = $w1; $ter.H = $h1; $ter.Flags = $fl; $ter.Rgb = $rgb
    $chk.Width = [int]($chk.Width * $Zoom); $chk.Height = [int]($chk.Height * $Zoom)
    foreach ($u in $chk.Units) { $u.X = [int]($u.X * $Zoom); $u.Y = [int]($u.Y * $Zoom) }
    foreach ($s in $chk.Sprites) { $s.X = [int]($s.X * $Zoom); $s.Y = [int]($s.Y * $Zoom) }
}

# ================================================================ DTA side: TEMPERATE theater (as build-arka04-antiga.ps1)
$mixes  = New-Object MixSet "$game\MIX"
$th     = New-Object Theater "$game\INI\Temperat.ini", "tem", $mixes
$wae    = "$game\Map Editor\Editor\Config\ConnectedTileDrawer.ini"
$cliffs = New-Object ConnectedSet $wae, "TemperateCliffSet", $th
$shores = New-Object ConnectedSet $wae, "TemperateWaterCliffSet", $th
"cliff pieces: $($cliffs.Pieces.Count), water cliff pieces: $($shores.Pieces.Count)"

$conv = New-Object ScToDta $chk, $ter, $th
$conv.Classify()
$conv.Resources()
$conv.Cliffs($cliffs)
$conv.Shores($shores, $true)
$conv.SettleWater()
$conv.FillWater($th.SetByName('Animated Water'), $th.SetByName('Water').Start)
$trees = [string[]]@('T01', 'T02', 'T03', 'T05', 'T06', 'T07', 'T08', 'T09', 'T10', 'T11', 'T12', 'T13', 'T14', 'T15', 'T16', 'T17', 'JBR01', 'JBR02', 'JBR03', 'JBR04', 'JBR05')
$rocks = $th.SetByName('Small Rocks').Start
$conv.Obstacles($trees, [int[]]@($rocks, ($rocks + 3)))
$conv.Cleanup()
$conv.RepairDecorations()
$conv.PaintGround()
# ground slots (ScToDta.Ground): 0 = grass, 1 = dirt, 2 = pavement (squares), 3 = tall grass (the jungle), 4 = paved road
$RoadG = 4
$base = [int[]]@(0, $th.SetByName('Dirt LAT').Start, $th.SetByName('Pavement LAT').Start, $th.SetByName('Tall Grass').Start, $th.SetByName('Paved Road LAT & addons').Start)
$lat  = [int[]]@(0, $th.SetByName('Clear/Dirt LAT').Start, $th.SetByName('Clear/Pavement LAT').Start, $th.SetByName('Tall/Short Grass LAT').Start, $th.SetByName('Clear/Paved Road LAT').Start)
$roadOnPave = $th.SetByName('Pavement/Paved Road LAT').Start

# ================================================================ mission waypoints (contract 10-64 with build-arka05-mission.ps1)
# ORIGINAL SC tile coordinates (128x128 grid of sc_grid.png); each is moved to the nearest passable cell
$wps = [ordered]@{
    '10' = @(56, 66, 'landing zone (crater): Raynor''s transports, the civilians'' goal')
    '11' = @(52, 71, 'player start army')
    '12' = @(61, 74, 'player MCV / base centre')
    '13' = @(48, 62, 'Sons of Korhal outpost W of the landing zone')
    '14' = @(64, 61, 'Sons of Korhal outpost E of the landing zone')
    '15' = @(54, 50, 'crystal field 1: safe, north of the crater')
    '16' = @(52, 79, 'crater wreck (money crate)')
    '17' = @(54, 84, 'base: south exit')
    '18' = @(38, 64, 'base: west entrance')
    '19' = @(78, 68, 'base: east entrance')
    '20' = @(16, 10, 'district Delta (NW): square, civilians come out')
    '21' = @(10, 12, 'Delta: Confederate Command Center')
    '22' = @(4, 10, 'Delta: crystal field')
    '23' = @(26, 18, 'Delta: Zerg pack')
    '24' = @(12, 16, 'Delta: bank (money crate)')
    '25' = @(110, 26, 'district Nova (NE): square, civilians come out')
    '26' = @(117, 30, 'Nova: Confederate Command Center')
    '27' = @(97, 26, 'Nova: crystal field')
    '28' = @(104, 40, 'Nova: Zerg pack')
    '29' = @(108, 36, 'Nova: armoury (money crate)')
    '30' = @(42, 98, 'district Omega (SW): square, civilians come out')
    '31' = @(34, 98, 'Omega: Confederate Command Center')
    '32' = @(18, 102, 'Omega: crystal field')
    '33' = @(48, 108, 'Omega: Zerg pack')
    '34' = @(30, 106, 'Omega: depot (money crate)')
    '35' = @(113, 70, 'district Gamma (E): square, civilians come out')
    '36' = @(120, 66, 'Gamma: town hall')
    '37' = @(104, 80, 'Gamma: Zerg pack')
    '38' = @(121, 74, 'Gamma: warehouse (money crate)')
    '40' = @(4, 65, 'psi emitter W (SC Beacon 3)')
    '41' = @(20, 113, 'psi emitter SW (SC Beacon 1)')
    '42' = @(103, 113, 'psi emitter SE (SC Beacon 2), by Kerrigan')
    '43' = @(1, 72, 'wave entry: west edge (emitter W)')
    '44' = @(6, 108, 'wave entry: south-west coast (emitter SW)')
    '45' = @(126, 92, 'wave entry: east edge, south (emitter SE)')
    '46' = @(50, 3, 'wave entry: north edge')
    '47' = @(126, 52, 'wave entry: east edge')
    '48' = @(79, 110, 'Kerrigan''s position: her holdout (marked by the user, moved 4 tiles down 2026-10-28)')
    '49' = @(95, 110, 'the slime trail: into the swarm (towards the SE emitter)')
    '50' = @(118, 102, 'Protoss landing site')
    '51' = @(111, 103, 'Protoss landing site: guard')
    '52' = @(26, 48, 'crystal field 2: west plain, contested, with the crystal mine')
    '53' = @(86, 56, 'crystal field 3: east plain, rich, open to the east')
    '54' = @(60, 40, 'centre plain north (muster)')
    '55' = @(124, 3, 'Mutalisk entry: north-east corner')
    '56' = @(127, 40, 'Protoss fleet flyover: start (east edge)')
    '57' = @(1, 30, 'Protoss fleet flyover: end (west edge)')
    '58' = @(74, 108, 'Kerrigan''s holdout: west side')
    '59' = @(88, 107, 'swarm round Kerrigan: east drop')
    '60' = @(77, 115, 'swarm round Kerrigan: south drop')
    '61' = @(28, 30, 'road Delta: west plain north')
    '62' = @(36, 84, 'road Omega: south-west approach')
    '63' = @(86, 74, 'road Gamma: east approach')
    '64' = @(84, 40, 'road Nova: north-east approach')
    '71' = @(100, 90, 'Zerg nest on the jungle plateau north of Kerrigan and the Protoss: Hatchery')
    '72' = @(107, 87, 'Zerg nest: crystal field and mine')
    '73' = @(96, 96, 'Zerg nest: rally / south exit')
    '76' = @(120, 7, 'crystal field 4: the north-east corner, big (user 2026-10-28)')
}
function Passable($x, $y) {
    if (-not $conv.In($x, $y)) { return $false }
    $i = $conv.Idx($x, $y)
    if (-not $conv.Visible[$i]) { return $false }
    $k = "$($conv.K[$i])"; if ($k -ne 'Low' -and $k -ne 'High') { return $false }
    if ($conv.Used[$i]) { return $false }
    if ($conv.Terrain.ContainsKey($y * 1000 + $x)) { return $false }
    if ($conv.Overlay[$y * 512 + $x] -ne 255) { return $false }
    $true
}
$wpCell = @{}
foreach ($k in $wps.Keys) {
    $p = $wps[$k]; $cx = 0; $cy = 0
    $conv.CellAt(($p[0] + 0.5) * 32 * $Zoom, ($p[1] + 0.5) * 32 * $Zoom, [ref]$cx, [ref]$cy)
    $best = $null
    for ($r = 0; $r -le 8 -and -not $best; $r++) {
        $bd = 1e9
        for ($x = $cx - $r; $x -le $cx + $r; $x++) { for ($y = $cy - $r; $y -le $cy + $r; $y++) {
            if ([Math]::Max([Math]::Abs($x - $cx), [Math]::Abs($y - $cy)) -ne $r) { continue }
            if (Passable $x $y) { $d = ($x - $cx) * ($x - $cx) + ($y - $cy) * ($y - $cy); if ($d -lt $bd) { $bd = $d; $best = @($x, $y) } }
        } }
    }
    if (-not $best) { throw "waypoint $k ($($p[2])): no passable cell near $cx,$cy" }
    if ($best[0] -ne $cx -or $best[1] -ne $cy) { "wp $k moved $cx,$cy -> $($best[0]),$($best[1]) ($($p[2]))" }
    $wpCell[$k] = $best
}

# the Protoss raid route to the Zerg nest (user 2026-10-28: "protossi ida po krawedzi klifu, zeby nie atakowac
# terranow"): the shortest open path from the Protoss guard spot (wp 51) to the nest (wp 71) that keeps 16 cells away
# from Kerrigan's holdout (wp 48); the shortest path hugs the cliffs. Waypoints 74 and 75 at 1/3 and 2/3 of it
$W2 = $conv.N; $prev = New-Object 'int[]' ($W2 * $W2); for ($i = 0; $i -lt $prev.Length; $i++) { $prev[$i] = -2 }
$ka = $wpCell['48']; $sa = $wpCell['51']; $ta = $wpCell['71']
$q = New-Object 'Collections.Generic.Queue[int]'; $ia = $sa[1] * $W2 + $sa[0]; $ib = $ta[1] * $W2 + $ta[0]; $prev[$ia] = -1; $q.Enqueue($ia)
while ($q.Count -and $prev[$ib] -eq -2) {
    $c = $q.Dequeue(); $x = $c % $W2; $y = [Math]::Floor($c / $W2)
    foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1), @(1, 1), @(-1, -1), @(1, -1), @(-1, 1))) {
        $nx = $x + $d[0]; $ny = $y + $d[1]; if (-not $conv.In($nx, $ny)) { continue }
        $nn = $ny * $W2 + $nx; if ($prev[$nn] -ne -2 -or -not (Passable $nx $ny)) { continue }
        if ([Math]::Max([Math]::Abs($nx - $ka[0]), [Math]::Abs($ny - $ka[1])) -lt 16) { continue }
        $prev[$nn] = $c; $q.Enqueue($nn)
    }
}
if ($prev[$ib] -eq -2) { throw "no Protoss route from wp 51 to wp 71 that avoids Kerrigan" }
$path = New-Object Collections.Generic.List[int]; $c = $ib; while ($c -ne -1) { $path.Insert(0, $c); $c = $prev[$c] }
foreach ($pr in @(@('74', 3), @('75', 1.5))) {
    $c = $path[[int]($path.Count / $pr[1])]; $wpCell[$pr[0]] = @(($c % $W2), [Math]::Floor($c / $W2))
    $wps[$pr[0]] = @(-1, -1, "Protoss raid route to the Zerg nest, $(if ($pr[0] -eq '74') { 'first' } else { 'second' }) point (computed)")
}
"Protoss route wp 51 -> 71: $($path.Count) cells, wp 74 = $($wpCell['74'] -join ','), wp 75 = $($wpCell['75'] -join ',')"
# ================================================================ resources (workflow/mission-design: 3+ fields on different risk + a mine)
# The SC minerals stay in the three Confederate towns (blue crystals, rich and Zerg-infested). On top: crystal fields
# round wp 15 (safe, by the crater), wp 52 (the west plain on the way of the west waves, with a crystal mine) and wp 53
# (the east plain, the richest, open to the east). Crystals, not ore (user 2026-10-27: "zamiast zlota na ziemi maja byc
# krysztaly"): the converter's gem overlays 31-34, as the SC minerals.
$rnd = New-Object Random 2500
$ore = @{ '15' = @(4, 0.75, 6); '52' = @(5, 0.7, 7); '53' = @(6, 0.8, 9); '72' = @(4, 0.8, 8); '76' = @(7, 0.85, 8) }   # radius, density, minimum stage
$nOre = @{}
foreach ($k in $ore.Keys) {
    $c = $wpCell[$k]; $r = $ore[$k][0]; $n = 0
    for ($x = $c[0] - $r; $x -le $c[0] + $r; $x++) { for ($y = $c[1] - $r; $y -le $c[1] + $r; $y++) {
        if (-not (Passable $x $y) -or ($x -eq $c[0] -and $y -eq $c[1])) { continue }
        if (($x - $c[0]) * ($x - $c[0]) + ($y - $c[1]) * ($y - $c[1]) -gt $r * $r + 1 -or $rnd.NextDouble() -gt $ore[$k][1]) { continue }
        $o = $y * 512 + $x; $conv.Overlay[$o] = [byte](31 + $rnd.Next(4)); $conv.OverlayData[$o] = [byte]($ore[$k][2] + $rnd.Next(12 - $ore[$k][2])); $n++
    } }
    $nOre[$k] = $n
}
"crystal fields: wp 15 $($nOre['15']) cells, wp 52 $($nOre['52']) cells, wp 53 $($nOre['53']) cells, wp 72 (Zerg nest) $($nOre['72']) cells, wp 76 (NE corner) $($nOre['76']) cells"
# the crystal mine on the west plain (OREMINE2, made a blue-crystal mine by the mission map as in mission 4): the open
# cell nearest to the field's centre that touches the field and has nothing on its 8 neighbours except crystals, so it
# never closes a path
function Near($i, $k, $r) { $c = $wpCell[$k]; $x = $i % 512; $y = [Math]::Floor($i / 512); [Math]::Abs($x - $c[0]) -le $r -and [Math]::Abs($y - $c[1]) -le $r }
function Place-Mine($k) {
    $mineAt = $null
    $cells = @(); for ($i = 0; $i -lt $conv.Overlay.Length; $i++) { $o = $conv.Overlay[$i]; if ($o -ge 27 -and $o -le 38 -and (Near $i $k 8)) { $cells += $i } }
    $mx = ($cells | ForEach-Object { $_ % 512 } | Measure-Object -Average).Average; $my = ($cells | ForEach-Object { [Math]::Floor($_ / 512) } | Measure-Object -Average).Average
    $bd = 1e9
    for ($x = [int]$mx - 8; $x -le [int]$mx + 8; $x++) { for ($y = [int]$my - 8; $y -le [int]$my + 8; $y++) {
        if (-not (Passable $x $y)) { continue }
        if (@($wpCell.Values | Where-Object { [Math]::Abs($_[0] - $x) -le 1 -and [Math]::Abs($_[1] - $y) -le 1 }).Count) { continue }
        $ok = $true; $touch = $false
        for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) {
            if (-not ($dx -or $dy)) { continue }
            $nx = $x + $dx; $ny = $y + $dy; if (-not $conv.In($nx, $ny)) { $ok = $false; continue }
            $o = $conv.Overlay[$ny * 512 + $nx]
            if ($o -ge 27 -and $o -le 38) { $touch = $true; continue }
            if (-not (Passable $nx $ny)) { $ok = $false }
        } }
        if (-not $ok -or -not $touch) { continue }
        $d = ($x - $mx) * ($x - $mx) + ($y - $my) * ($y - $my); if ($d -lt $bd) { $bd = $d; $mineAt = @($x, $y) }
    } }
    if (-not $mineAt) { throw "no free cell for the crystal mine at wp $k" }
    $conv.Terrain[$mineAt[1] * 1000 + $mineAt[0]] = 'OREMINE2'
    "crystal mine OREMINE2 at $($mineAt[0]),$($mineAt[1]) by the field of wp $k ($($cells.Count) cells)"
}
Place-Mine '52'
# the Zerg nest on the jungle plateau north of Kerrigan and the Protoss (user 2026-10-28: "mala baza zergow na gorze
# wraz z kopalnia i mineralami"): its own crystal field and mine
Place-Mine '72'
$gems = 0; for ($i = 0; $i -lt $conv.Overlay.Length; $i++) { if ($conv.Overlay[$i] -ge 27 -and $conv.Overlay[$i] -le 38) { $gems++ } }
"town crystals (SC minerals): $gems cells"

# ================================================================ Tarsonis: paved squares (districts, landing zone) and streets
# Squares: discs of pavement round the district squares, the Command Centers and the landing zone, on the cell's own
# level only (a square never spills over a cliff). Streets: the shortest open path from the landing zone to each
# district square (8-connected, through the SC ramps), painted 2 cells wide as Paved Road LAT; both ends sit in a
# square, so no street ends in the grass (workflow/mission-maps, "Drogi").
$lvlOf = { param($i) if ($conv.Plateau[$i] -lt 0) { 0 } else { $conv.PlateauLevel[$conv.Plateau[$i]] } }
function Pave($k, $r) {
    $c = $wpCell[$k]; $l0 = & $lvlOf $conv.Idx($c[0], $c[1]); $n = 0
    for ($x = $c[0] - $r; $x -le $c[0] + $r; $x++) { for ($y = $c[1] - $r; $y -le $c[1] + $r; $y++) {
        if (($x - $c[0]) * ($x - $c[0]) + ($y - $c[1]) * ($y - $c[1]) -gt $r * $r + 1 -or -not $conv.In($x, $y)) { continue }
        $i = $conv.Idx($x, $y); $kk = "$($conv.K[$i])"
        if (($kk -eq 'High' -or $kk -eq 'Low') -and -not $conv.Used[$i] -and (& $lvlOf $i) -eq $l0) { $conv.Ground[$i] = 2; $n++ }
    } }
    $n
}
$sq = [ordered]@{ '10' = 5; '20' = 5; '21' = 3; '24' = 2; '25' = 5; '26' = 3; '29' = 2; '30' = 5; '31' = 3; '34' = 2; '35' = 5; '36' = 3; '38' = 2 }
foreach ($k in $sq.Keys) { $n = Pave $k $sq[$k]; "square at wp ${k}: $n cells" }
$road = New-Object 'bool[]' ($conv.N * $conv.N)
function Street($from, $to, [string[]]$via) {
    # BFS through the given waypoints in order; returns the cell list
    $path = New-Object Collections.Generic.List[int]
    $pts = @($from) + $via + @($to)
    for ($s = 0; $s -lt $pts.Count - 1; $s++) {
        $a = $wpCell[$pts[$s]]; $b = $wpCell[$pts[$s + 1]]
        $W = $conv.N; $prev = New-Object 'int[]' ($W * $W); for ($i = 0; $i -lt $prev.Length; $i++) { $prev[$i] = -2 }
        $q = New-Object 'Collections.Generic.Queue[int]'; $ia = $a[1] * $W + $a[0]; $ib = $b[1] * $W + $b[0]; $prev[$ia] = -1; $q.Enqueue($ia)
        while ($q.Count -and $prev[$ib] -eq -2) {
            $c = $q.Dequeue(); $x = $c % $W; $y = [Math]::Floor($c / $W)
            foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1), @(1, 1), @(-1, -1), @(1, -1), @(-1, 1))) {
                $nx = $x + $d[0]; $ny = $y + $d[1]; if (-not $conv.In($nx, $ny)) { continue }
                $n = $ny * $W + $nx; if ($prev[$n] -ne -2) { continue }
                if (-not (Passable $nx $ny)) { continue }
                # a diagonal step needs a side cell open, or the street would squeeze between two cliff corners
                if ($d[0] -and $d[1] -and -not ((Passable ($x + $d[0]) $y) -or (Passable $x ($y + $d[1])))) { continue }
                $prev[$n] = $c; $q.Enqueue($n)
            }
        }
        if ($prev[$ib] -eq -2) { "WARN street $from -> ${to}: no open path from wp $($pts[$s]) to wp $($pts[$s + 1])"; $script:free++; return }
        $seg = New-Object Collections.Generic.List[int]; $c = $ib; while ($c -ne -1) { $seg.Insert(0, $c); $c = $prev[$c] }
        if ($path.Count) { $seg.RemoveAt(0) }
        $path.AddRange($seg)
    }
    # make the path side-connected: a diagonal step also takes an open side cell (a corner-only contact renders as a
    # grass gap between two LAT road pieces)
    for ($j = $path.Count - 1; $j -gt 0; $j--) {
        $p0 = $path[$j - 1]; $p1 = $path[$j]; $W = $conv.N
        $x0 = $p0 % $W; $y0 = [Math]::Floor($p0 / $W); $x1 = $p1 % $W; $y1 = [Math]::Floor($p1 / $W)
        if ($x0 -eq $x1 -or $y0 -eq $y1) { continue }
        $side = if (Passable $x1 $y0) { $y0 * $W + $x1 } else { $y1 * $W + $x0 }
        $path.Insert($j, $side)
    }
    $n = 0
    foreach ($c in $path) {
        $x = $c % $conv.N; $y = [Math]::Floor($c / $conv.N)
        for ($k = 0; $k -lt 4; $k++) {
            $nx = $x + ($k -band 1); $ny = $y + ($k -shr 1)
            if (-not (Passable $nx $ny)) { continue }
            $i = $conv.Idx($nx, $ny); if ($conv.Ground[$i] -ne 2 -and -not $road[$i]) { $road[$i] = $true; $conv.Ground[$i] = $RoadG; $n++ }
        }
    }
    "street wp $from -> wp ${to}: $($path.Count) path cells, $n road cells"
}
Street '10' '20' @('61')
Street '10' '25' @('64')
Street '10' '30' @('62')
Street '10' '35' @('63')
# free-end check: a street end (road cell with exactly one road/pavement neighbour side... simplified: every road
# component must touch the landing-zone square and a district square)
$pave = New-Object 'bool[]' ($conv.N * $conv.N); for ($i = 0; $i -lt $pave.Length; $i++) { $pave[$i] = $conv.Ground[$i] -eq 2 -and $conv.Valid[$i] }
$seen = New-Object 'bool[]' ($conv.N * $conv.N); $free = 0; $comps = 0
for ($i = 0; $i -lt $road.Length; $i++) {
    if (-not $road[$i] -or $seen[$i]) { continue }
    $comps++; $touch = 0; $q = New-Object 'Collections.Generic.Queue[int]'; $q.Enqueue($i); $seen[$i] = $true; $sqTouched = @{}
    while ($q.Count) {
        $c = $q.Dequeue(); $x = $c % $conv.N; $y = [Math]::Floor($c / $conv.N)
        foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
            $nx = $x + $d[0]; $ny = $y + $d[1]; if (-not $conv.In($nx, $ny)) { continue }
            $n = $conv.Idx($nx, $ny)
            if ($pave[$n]) { foreach ($k in $sq.Keys) { $w = $wpCell[$k]; if ([Math]::Abs($w[0] - $nx) -le 6 -and [Math]::Abs($w[1] - $ny) -le 6) { $sqTouched[$k] = 1 } } }
            if ($road[$n] -and -not $seen[$n]) { $seen[$n] = $true; $q.Enqueue($n) }
        }
    }
    if ($sqTouched.Count -lt 2) { $free++; "WARN road component $comps touches $($sqTouched.Count) square(s)" }
}
"roads: $comps component(s), free ends $free"

# LAT with paved roads (as DesignToDta.ApplyGroundRoads): pavement counts a road next to it as its own ground, and a
# road cell whose differing neighbours are all pavement takes the Pavement/Paved Road LAT
$conv.ApplyGround(0, $base, $lat)
$NX = 0, 1, 0, -1; $NY = -1, 0, 1, 0
for ($y = 0; $y -lt $conv.N; $y++) { for ($x = 0; $x -lt $conv.N; $x++) {
    $i = $conv.Idx($x, $y); if (-not $conv.Valid[$i] -or $conv.Used[$i]) { continue }
    $g = $conv.Ground[$i]; if ($g -ne 2 -and $g -ne $RoadG) { continue }
    $mask = 0; $onlyPave = $true
    for ($d = 0; $d -lt 4; $d++) {
        $nx = $x + $NX[$d]; $ny = $y + $NY[$d]; if (-not $conv.In($nx, $ny)) { continue }
        $n = $conv.Idx($nx, $ny)
        $same = -not $conv.Used[$n] -and "$($conv.K[$n])" -ne 'Water' -and ($conv.Ground[$n] -eq $g -or ($g -eq 2 -and $conv.Ground[$n] -eq $RoadG))
        if ($same) { continue }
        $mask = $mask -bor (1 -shl $d)
        if ($conv.Used[$n] -or "$($conv.K[$n])" -eq 'Water' -or $conv.Ground[$n] -ne 2) { $onlyPave = $false }
    }
    $conv.Tile[$i] = if ($mask -eq 0) { $base[$g] } elseif ($g -eq $RoadG -and $onlyPave) { $roadOnPave + $mask } else { $lat[$g] + $mask }
    $conv.Sub[$i] = 0
} }

# ================================================================ dressing: sparse trees and bushes on open ground
# never within 4 cells of a waypoint, never on a street or square, and only where all 8 neighbours are open, so nothing
# closes a ramp or a 1-cell gap
$nearWp = New-Object 'bool[]' ($conv.N * $conv.N)
foreach ($k in $wpCell.Keys) { $c = $wpCell[$k]; for ($x = $c[0] - 4; $x -le $c[0] + 4; $x++) { for ($y = $c[1] - 4; $y -le $c[1] + 4; $y++) { if ($conv.In($x, $y)) { $nearWp[$conv.Idx($x, $y)] = $true } } } }
$nDeco = 0
for ($y = 1; $y -lt $conv.N - 1; $y++) { for ($x = 1; $x -lt $conv.N - 1; $x++) {
    $i = $conv.Idx($x, $y)
    if (-not (Passable $x $y) -or $nearWp[$i] -or $conv.Ground[$i] -eq 2 -or $conv.Ground[$i] -eq $RoadG) { continue }
    $open = $true
    for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { if (($dx -or $dy) -and (-not (Passable ($x + $dx) ($y + $dy)) -or $road[$conv.Idx($x + $dx, $y + $dy)])) { $open = $false } } }
    if (-not $open) { continue }
    $chance = if ($conv.Ground[$i] -eq 3) { 0.03 } else { 0.01 }   # the jungle a little thicker
    if ($rnd.NextDouble() -lt $chance) { $conv.Terrain[$y * 1000 + $x] = $trees[$rnd.Next($trees.Length)]; $nDeco++ }
} }
"dressing: $nDeco trees/bushes"

$conv.WallFrames(2, [int[]]@(0, 2, 4, 6))
$conv.CheckConnectivity()
$cmp = $conv.CompareWithSc(); $cmp.Save("$work\compare_sc.png"); $cmp.Dispose()
$text = $conv.WriteMap('ARKA #5: Upadek Tarsonis (teren)', 'Claude (kampania ARKA; teren: Blizzard T10 Operation Silent Scream, port: Claude)')
$conv.Log | Set-Content "$work\log.txt" -Encoding UTF8
"converter: $($conv.Log.Count) log lines; starts $($conv.Starts.Count) connected=$($conv.StartsConnected) sealed $($conv.Sealed) leaks $($conv.Leaks) failed chains $($conv.ChainFailures)"
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::GetEncoding(1252))
$ini = [Ini]::Load($Out)
$ini.Set('Map', 'Theater', 'TEMPERATE')
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; $ini.Set('Waypoints', $k, "$($c[1] * 1000 + $c[0])") }
$ini.Set('Basic', 'Name', 'ARKA #5: Upadek Tarsonis (teren, Tarsonis)')
# the converter's "temple" for an unwalkable blob in the middle of a map: the crater has the SC wreckage there
$st = $ini.Section('Structures'); $nT = 0
for ($i = $st.Count - 1; $i -ge 0; $i--) { if ($st[$i].Value -match ',DBTMPL,') { $st.RemoveAt($i); $nT++ } }
if ($nT) { "removed $nT converter temple(s) (DBTMPL)" }
[IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))
"written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB), Size 0,0,$($conv.W),$($conv.H)"

# ================================================================ checks: every waypoint reachable by ground from the landing zone
$reach = New-Object 'bool[]' ($conv.N * $conv.N); $dist = New-Object 'int[]' ($conv.N * $conv.N)
$q = New-Object 'Collections.Generic.Queue[int]'
$s0 = $wpCell['10']; $reach[$conv.Idx($s0[0], $s0[1])] = $true; $q.Enqueue($conv.Idx($s0[0], $s0[1]))
while ($q.Count) {
    $c = $q.Dequeue(); $x = $c % $conv.N; $y = [Math]::Floor($c / $conv.N)
    foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1), @(1, 1), @(-1, -1), @(1, -1), @(-1, 1))) {
        $nx = $x + $d[0]; $ny = $y + $d[1]
        if (-not $conv.In($nx, $ny)) { continue }
        $n = $conv.Idx($nx, $ny)
        if ($reach[$n]) { continue }
        $k = "$($conv.K[$n])"
        $pass = ($k -eq 'Low' -or $k -eq 'High') -and -not $conv.Used[$n] -and -not $conv.Terrain.ContainsKey($ny * 1000 + $nx)
        if ($pass) { $reach[$n] = $true; $dist[$n] = $dist[$c] + 1; $q.Enqueue($n) }
    }
}
$fail = 0
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; "wp $k path $($dist[$conv.Idx($c[0], $c[1])]) cells ($($wps[$k][2]))"; if (-not $reach[$conv.Idx($c[0], $c[1])]) { "WARN wp $k ($($wps[$k][2])) not reachable from the landing zone by ground (conservative test)"; $fail++ } }
"CHECKS: " + $(if ($fail) { "$fail waypoint(s) unreachable" } else { "PASS (all $($wps.Count) waypoints reachable from the landing zone)" }) + "; road free ends $free"

# ================================================================ pictures: SC grid for planning, waypoints on the cell map
$g0 = [Drawing.Image]::FromFile("$work\sc.png")
$grid = New-Object Drawing.Bitmap 2048, 2048; $g = [Drawing.Graphics]::FromImage($grid); $g.DrawImage($g0, 0, 0, 2048, 2048); $g0.Dispose()
$pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(110, 255, 255, 255)), 1; $font = New-Object Drawing.Font 'Arial', 8
for ($k = 0; $k -le 128; $k += 4) { $g.DrawLine($pen, $k * 16, 0, $k * 16, 2048); $g.DrawLine($pen, 0, $k * 16, 2048, $k * 16); $g.DrawString("$k", $font, [Drawing.Brushes]::White, $k * 16 + 1, 1); $g.DrawString("$k", $font, [Drawing.Brushes]::White, 1, $k * 16 + 1) }
$bf = New-Object Drawing.Font 'Arial', 9, ([Drawing.FontStyle]::Bold)
foreach ($k in $wps.Keys) { $p = $wps[$k]; $g.FillEllipse([Drawing.Brushes]::Red, $p[0] * 16 + 4, $p[1] * 16 + 4, 8, 8); $g.DrawString($k, $bf, [Drawing.Brushes]::Yellow, $p[0] * 16 + 10, $p[1] * 16 - 2) }
$g.Dispose(); $grid.Save("$work\sc_grid.png"); $grid.Dispose()
$dbg = $conv.DebugImage(); $g = [Drawing.Graphics]::FromImage($dbg)
foreach ($k in $wps.Keys) {
    $c = $wpCell[$k]; $dx = 0; $dy = 0; $conv.ToScreen($c[0], $c[1], [ref]$dx, [ref]$dy)
    $sx = $dbg.Width * ($dx + 1) / (2 * $conv.W); $sy = $dbg.Height * ($dy + 1) / (2 * $conv.H)
    $g.FillEllipse([Drawing.Brushes]::Red, $sx - 4, $sy - 4, 8, 8); $g.DrawString($k, $bf, [Drawing.Brushes]::Yellow, $sx + 5, $sy - 6)
}
$g.Dispose(); $dbg.Save("$work\waypoints.png")
$big = New-Object Drawing.Bitmap ($dbg.Width * 2), ($dbg.Height * 2); $g = [Drawing.Graphics]::FromImage($big)
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor; $g.DrawImage($dbg, 0, 0, $big.Width, $big.Height); $dbg.Dispose()
$gp = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(90, 0, 0, 0)), 1
for ($k = 0; $k -le 128; $k += 4) {
    $sx = $big.Width * ($k * $Zoom + 2 * $conv.PadX) / (2 * $conv.W); $sy = $big.Height * ($k * $Zoom * 2 + 2 * $conv.PadTop) / (2 * $conv.H)
    $g.DrawLine($gp, $sx, 0, $sx, $big.Height); $g.DrawLine($gp, 0, $sy, $big.Width, $sy)
    $g.DrawString("$k", $font, [Drawing.Brushes]::Black, $sx + 1, 1); $g.DrawString("$k", $font, [Drawing.Brushes]::Black, 1, $sy + 1)
}
foreach ($k in $wps.Keys) {
    $c = $wpCell[$k]; $dx = 0; $dy = 0; $conv.ToScreen($c[0], $c[1], [ref]$dx, [ref]$dy)
    $sx = $big.Width * ($dx + 1) / (2 * $conv.W); $sy = $big.Height * ($dy + 1) / (2 * $conv.H)
    $g.FillEllipse([Drawing.Brushes]::Red, $sx - 5, $sy - 5, 10, 10); $g.DrawString($k, $bf, [Drawing.Brushes]::Black, $sx + 6, $sy - 7)
}
$g.Dispose(); $big.Save("$work\grid.png"); $big.Dispose()
$dbg = $conv.ReachImage(); $dbg.Save("$work\reach.png"); $dbg.Dispose()

# ================================================================ preview (client needs [PreviewPack] for Maps\Custom) + full render
if (-not $NoRender) {
    $dir = "$game\Map Editor\Map Renderer"
    $bn = [IO.Path]::GetFileNameWithoutExtension($Out)
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$Out`" -o ${bn}_full -d `"$work`" -p -T -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "CNCMaps renderer timed out (see $work\render.log)" }
    $full = [Drawing.Image]::FromFile("$work\${bn}_full.png")
    $h = [int]($full.Height * 800 / $full.Width)
    $thumb = New-Object Drawing.Bitmap 800, $h
    $g = [Drawing.Graphics]::FromImage($thumb); $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($full, 0, 0, 800, $h); $g.Dispose(); $full.Dispose()
    $thumb.Save([IO.Path]::ChangeExtension($Out, '.png'), [Drawing.Imaging.ImageFormat]::Png)
    $ini = [Ini]::Load($Out)
    [MapPreview]::Set($ini, $thumb, 400); $thumb.Dispose()
    [IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))
    "render: $work\${bn}_full.png, preview $([IO.Path]::ChangeExtension($Out, '.png'))"
}
