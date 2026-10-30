# Terrain of ARKA mission 7 "Zdrada" (Antiga Prime, 2500): the StarCraft Terran campaign map "The Trump Card" (CASC
# SD/campaign/Terran/Terran08; briefing: "The Secret Base has been surrounded by the Confederates"), badlands, 128x96,
# scaled 1.5x to the DTA TEMPERATE theater with the Antiga ground of mission 4 (mudflats and scrub).
# In StarCraft the west of the map is Mengsk's secret base: concrete platforms joined by asphalt roads and bridges over
# the water. Here it has grown into the Dominion city on Antiga (built of StarCraft Terran buildings by the mission
# script), with the spaceport on the big south-west platform, where the Hyperion is docked. The open east plain, where
# the Confederate base stands in StarCraft, is the Allied base round the ARKA, surrounded on three sides: the north
# plateau (bunkers, Duke's siege tanks over the plain), the city in the west and the scrub in the south.
# On top of the port: paved squares at the Allied base, a paved highway from the city's east bridge to the base, three
# extra crystal fields with crystal mines (workflow/mission-design).
# Writes Maps\Custom\arka07_antiga.map (viewable as a skirmish "Custom Map") and the mission waypoints 10-69, which are
# the contract with build-arka07-mission.ps1.
#
#   powershell -NoProfile -File .\build-arka07-antiga.ps1            # build + checks + preview + render (~2 min)
#   powershell -NoProfile -File .\build-arka07-antiga.ps1 -NoRender  # no CNCMaps render
#
# Work files: %TEMP%\arka07-terrain\ (sc.png, sc_grid.png, grid.png, reach.png, compare_sc.png, waypoints.png, log.txt).
# Wiki: Modding/wiki/missions/arka-07-zdrada.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$Out = "",
    [double]$Zoom = 1.5,
    [switch]$NoRender
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Out) { $Out = "$game\Maps\Custom\arka07_antiga.map" }
$work = "$env:TEMP\arka07-terrain"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScMap.cs", "$tools\TsMap.cs", "$tools\ScToDta.cs" -ReferencedAssemblies System.Drawing

# ================================================================ StarCraft side: T8 "The Trump Card", badlands, 128x96
$casc = New-Object Casc $StarCraft
$chk  = New-Object Chk (, $casc.ReadFile('SD/campaign/Terran/Terran08/staredit/scenario.chk'))
$ts   = New-Object ScTileset $casc, ([Chk]::EraNames[$chk.Era])
$ter  = New-Object ScTerrain $chk, $ts
"SC map: $($chk.Width)x$($chk.Height) $([Chk]::EraNames[$chk.Era]), zoom $Zoom"
$sc = $ter.RenderNatural(4); $sc.Save("$work\sc.png"); $sc.Dispose()

# The city's pavement is decided per SC tile, before the zoom: the asphalt and concrete platforms of the SC secret base
# are dark grey (minitile average 26-31, R=G=B within 5; dirt is 52-57 and brown), and the converter's PaintGround
# only takes light grey (mx > 60). A tile is pavement when 10+ of its 16 minitiles are dark grey. The platforms are
# rectangles of whole SC tiles, so their DTA edges come out as even stairs (classifying single DTA cells by their
# average colour gave ragged edges and holes, user 2026-10-30)
$scPave = New-Object 'bool[]' ($chk.Width * $chk.Height); $nScPave = 0
for ($ty = 0; $ty -lt $chk.Height; $ty++) { for ($tx = 0; $tx -lt $chk.Width; $tx++) {
    $dark = 0
    for ($my = 0; $my -lt 4; $my++) { for ($mx = 0; $mx -lt 4; $mx++) {
        $c = [Drawing.Color]::FromArgb($ter.Rgb[($ty * 4 + $my) * $ter.W + $tx * 4 + $mx])
        $hi = [Math]::Max($c.R, [Math]::Max($c.G, $c.B)); $lo = [Math]::Min($c.R, [Math]::Min($c.G, $c.B))
        if ($hi -gt 8 -and $hi -lt 45 -and $hi - $lo -lt 10) { $dark++ }
    } }
    if ($dark -ge 10) { $scPave[$ty * $chk.Width + $tx] = $true; $nScPave++ }
} }
$scW = $chk.Width; $scH = $chk.Height
"SC pavement tiles (asphalt, platforms): $nScPave"

# Two narrow lake ends by the city's east bridge platform (user 2026-10-30, "artefakty przy water cliffach"): the
# water-cliff chains of both banks reach the point and stop side by side (Water Cliffs have no end piece), leaving a
# notch of plain water; ScToDta's tip pass (TipSeams) tried both and put them back. The tips are filled with land in
# the SC terrain itself, a disc of 1.5 tiles, so each lake ends blunt and one chain goes round it. Centres in SC tiles,
# from the DTA cells of the seams (93,141 and 130,155) by the zoom-1.5 cell map x = 8.5 + 0.75 sx + 1.5 sy,
# y = 103.5 - 0.75 sx + 1.5 sy (fitted on wp 30 and 41)
$tipFill = 0
foreach ($tip in @(@(31.7, 40.8), @(46.7, 57.7))) {
    $mx0 = $tip[0] * 4; $my0 = $tip[1] * 4; $r = 6   # minitiles (1.5 tiles)
    for ($my = [int]($my0 - $r); $my -le [int]($my0 + $r); $my++) { for ($mx = [int]($mx0 - $r); $mx -le [int]($mx0 + $r); $mx++) {
        if ($mx -lt 0 -or $my -lt 0 -or $mx -ge $ter.W -or $my -ge $ter.H) { continue }
        if (($mx - $mx0) * ($mx - $mx0) + ($my - $my0) * ($my - $my0) -gt $r * $r) { continue }
        $i = $my * $ter.W + $mx; if ($ter.Walkable($i)) { continue }
        $ter.Flags[$i] = 1; $ter.Rgb[$i] = [Drawing.Color]::FromArgb(53, 43, 26).ToArgb(); $tipFill++
    } }
}
"lake tips filled with land: $tipFill minitiles"

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
# water still touching bare land after ScToDta.RepairCoast and its lake-tip pass (counted before FillWater: after it
# every water cell is Used and RawCoast() reads 0). The chain-end seams left (bare land beside the water of a chain
# end) get a bush over them below. Filling or widening more of the lakes only moved the seams along the shore: the
# chains are laid one after another over the whole map (2026-10-30)
$seams = @($conv.TipSeams())
"raw coast after the coast repair: $($conv.RawCoast()); chain-end seams: " + (($seams | ForEach-Object { "$($_ % $conv.N),$([Math]::Floor($_ / $conv.N))" }) -join " ")
$conv.FillWater($th.SetByName('Animated Water'), $th.SetByName('Water').Start)
$trees = [string[]]@('T01', 'T02', 'T03', 'T05', 'T06', 'T07', 'T08', 'T09', 'T10', 'T11', 'T12', 'T13', 'T14', 'T15', 'T16', 'T17', 'JBR01', 'JBR02', 'JBR03', 'JBR04', 'JBR05')
$rocks = $th.SetByName('Small Rocks').Start
$conv.Obstacles($trees, [int[]]@($rocks, ($rocks + 3)))
$conv.Cleanup()
$conv.RepairDecorations()
$conv.PaintGround()
# The city (SC tiles found above): sample every pavement tile and its neighbours every 8 px of the zoomed map; a cell is
# pavement when most of its samples fall on pavement tiles. Then clean up on the cell grid: close notches (an open cell
# with pavement on two opposite sides or 5+ of 8 neighbours), drop spurs (a pavement cell with at most one pavement side)
# and crumbs (pieces under 8 cells). The converter's own light-grey pavement elsewhere stays as it is
$N2 = $conv.N; $pv = New-Object 'int[]' ($N2 * $N2); $tot = New-Object 'int[]' ($N2 * $N2)
$seenT = New-Object 'bool[]' ($scW * $scH); $tileStep = 32 * $Zoom
for ($t = 0; $t -lt $scPave.Length; $t++) {
    if (-not $scPave[$t]) { continue }
    $tx0 = $t % $scW; $ty0 = [Math]::Floor($t / $scW)
    for ($ny = $ty0 - 1; $ny -le $ty0 + 1; $ny++) { for ($nx = $tx0 - 1; $nx -le $tx0 + 1; $nx++) {
        if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $scW -or $ny -ge $scH) { continue }
        $tn = $ny * $scW + $nx; if ($seenT[$tn]) { continue }; $seenT[$tn] = $true; $isP = $scPave[$tn]
        for ($sy = 4; $sy -lt $tileStep; $sy += 8) { for ($sx = 4; $sx -lt $tileStep; $sx += 8) {
            $cx = 0; $cy = 0; $conv.CellAt($nx * $tileStep + $sx, $ny * $tileStep + $sy, [ref]$cx, [ref]$cy)
            if (-not $conv.In($cx, $cy)) { continue }
            $ci = $conv.Idx($cx, $cy); $tot[$ci]++; if ($isP) { $pv[$ci]++ }
        } }
    } }
}
function Walk2($i) { $k = "$($conv.K[$i])"; $conv.Valid[$i] -and -not $conv.Used[$i] -and ($k -eq 'Low' -or $k -eq 'High') }
$cityPave = New-Object 'bool[]' ($N2 * $N2)
for ($i = 0; $i -lt $cityPave.Length; $i++) { if ($tot[$i] -and $pv[$i] * 2 -ge $tot[$i] -and (Walk2 $i)) { $cityPave[$i] = $true } }
$D8X = 1, 1, 0, -1, -1, -1, 0, 1; $D8Y = 0, 1, 1, 1, 0, -1, -1, -1
for ($pass = 0; $pass -lt 3; $pass++) {
    $add = New-Object Collections.Generic.List[int]; $drop = New-Object Collections.Generic.List[int]
    for ($y = 1; $y -lt $N2 - 1; $y++) { for ($x = 1; $x -lt $N2 - 1; $x++) {
        $i = $conv.Idx($x, $y); $nb = @(); for ($d = 0; $d -lt 8; $d++) { $nb += $cityPave[$conv.Idx($x + $D8X[$d], $y + $D8Y[$d])] }
        $n8 = @($nb | Where-Object { $_ }).Count; $n4 = [int]$nb[0] + [int]$nb[2] + [int]$nb[4] + [int]$nb[6]
        if (-not $cityPave[$i]) {
            if ((Walk2 $i) -and (($nb[0] -and $nb[4]) -or ($nb[2] -and $nb[6]) -or $n8 -ge 5)) { $add.Add($i) }
        } elseif ($n4 -le 1) { $drop.Add($i) }
    } }
    foreach ($i in $add) { $cityPave[$i] = $true }; foreach ($i in $drop) { $cityPave[$i] = $false }
}
$seenC = New-Object 'bool[]' ($N2 * $N2); $nPave = 0; $nCrumb = 0
for ($i = 0; $i -lt $cityPave.Length; $i++) {
    if (-not $cityPave[$i] -or $seenC[$i]) { continue }
    $comp = New-Object Collections.Generic.List[int]; $q = New-Object 'Collections.Generic.Queue[int]'; $q.Enqueue($i); $seenC[$i] = $true
    while ($q.Count) {
        $c = $q.Dequeue(); $comp.Add($c); $x = $c % $N2; $y = [Math]::Floor($c / $N2)
        for ($d = 0; $d -lt 8; $d += 2) { $nx = $x + $D8X[$d]; $ny = $y + $D8Y[$d]; if (-not $conv.In($nx, $ny)) { continue }; $n = $conv.Idx($nx, $ny); if ($cityPave[$n] -and -not $seenC[$n]) { $seenC[$n] = $true; $q.Enqueue($n) } }
    }
    if ($comp.Count -lt 8) { $nCrumb += $comp.Count; continue }
    foreach ($c in $comp) { $conv.Ground[$c] = 2; $nPave++ }
}
# no trees on the pavement (the converter planted the SC doodad sprites before the city was known)
$nTree = 0
foreach ($key in @($conv.Terrain.Keys)) {
    $x = $key % 1000; $y = [Math]::Floor($key / 1000)
    if ($conv.In($x, $y) -and $cityPave[$conv.Idx($x, $y)] -and $conv.Terrain[$key] -ne 'OREMINE2') { $conv.Terrain.Remove($key) | Out-Null; $nTree++ }
}
"city pavement (SC asphalt and platforms): $nPave cells, $nCrumb crumb cells dropped, $nTree trees removed from it"
# ground slots (ScToDta.Ground): 0 = grass, 1 = dirt (the mudflats), 2 = pavement (the SC platforms and roads),
# 3 = scrub (Autumn Grass, set below), 4 = paved road (the highway)
$RoadG = 4
$base = [int[]]@(0, $th.SetByName('Dirt LAT').Start, $th.SetByName('Pavement LAT').Start, $th.SetByName('Tall Grass').Start, $th.SetByName('Paved Road LAT & addons').Start)
$lat  = [int[]]@(0, $th.SetByName('Clear/Dirt LAT').Start, $th.SetByName('Clear/Pavement LAT').Start, $th.SetByName('Tall/Short Grass LAT').Start, $th.SetByName('Clear/Paved Road LAT').Start)
$roadOnPave = $th.SetByName('Pavement/Paved Road LAT').Start

# ================================================================ mission waypoints (contract 10-69 with build-arka07-mission.ps1)
# ORIGINAL SC tile coordinates (128x96 grid of sc_grid.png); each is moved to the nearest passable cell
$wps = [ordered]@{
    # the Allied base round the ARKA (east plain; the SC Confederate base and its beacon)
    '10' = @(116, 50, 'ARKA (the SC beacon)')
    '11' = @(108, 56, 'player start army')
    '12' = @(121, 44, 'Einstein''s laboratory')
    '13' = @(111, 43, 'Allied construction yard')
    '14' = @(106, 50, 'Allied barracks')
    '15' = @(118, 34, 'Allied refinery: home crystals under the north plateau (SC minerals)')
    '16' = @(117, 60, 'Allied war factory')
    '17' = @(123, 39, 'power plant 1')
    '18' = @(124, 55, 'power plant 2')
    '19' = @(110, 34, 'base: north defence line (under the plateau)')
    '20' = @(99, 50, 'base: west entrance (the highway from the city)')
    '21' = @(110, 66, 'base: south entrance (the scrub)')
    '22' = @(124, 63, 'Raynor''s Command Center (where it lands)')
    # the Dominion city on the SC platforms (west)
    '30' = @(16, 80, 'spaceport: the Hyperion on the big platform')
    '31' = @(10, 77, 'spaceport: docking clamp 1 (W)')
    '32' = @(22, 77, 'spaceport: docking clamp 2 (E)')
    '33' = @(16, 85, 'spaceport: docking clamp 3 (S)')
    '34' = @(27, 76, 'Raynor''s squad: inside the Dominion base by the spaceport')
    '35' = @(7, 84, 'spaceport: Starports and Control Towers')
    '36' = @(12, 56, 'palace district (Mengsk''s seat, the SC Command Center)')
    '37' = @(5, 52, 'palace district: treasury (money crate)')
    '38' = @(35, 68, 'industrial district (SC Factory)')
    '39' = @(30, 28, 'north district: garrison and research (SC Science Facility)')
    '40' = @(12, 68, 'housing blocks (Supply Depots)')
    '41' = @(46, 52, 'east bridge platform: checkpoint')
    '42' = @(66, 80, 'south-east road end: city gate to the highway')
    '43' = @(22, 61, 'city crossroads (palace / industry / port)')
    '44' = @(34, 37, 'north road: bridge to the north district')
    # the Dominion around the Allied base
    '45' = @(30, 10, 'north-west fort (SC Engineering Bay, bunkers)')
    '46' = @(96, 8, 'north-east fort (SC Bunkers location)')
    '47' = @(112, 22, 'Duke''s siege tanks: north plateau edge over the base')
    '48' = @(101, 30, 'Duke''s siege tanks: centre mesa over the west entrance')
    '49' = @(92, 64, 'Duke''s siege tanks: south mesa')
    '50' = @(113, 6, 'Duke''s headquarters on the north plateau')
    '51' = @(100, 1, 'wave entry: north edge')
    '52' = @(66, 84, 'wave entry: the city gate (west)')
    '53' = @(104, 95, 'wave entry: south edge')
    '54' = @(127, 86, 'wave entry: east edge, south')
    # resources (workflow/mission-design): the SC minerals (home field wp 15, city wp 57, centre wp 56) + new fields
    '55' = @(126, 70, 'crystal field: safe, behind the base by the east edge')
    '56' = @(73, 74, 'crystal field: centre (SC minerals), contested, on the way of the west waves')
    '57' = @(13, 62, 'crystal field: palace district (SC minerals), inside the city')
    '58' = @(108, 84, 'crystal field: the scrub in the south, rich, with a mine')
    '59' = @(70, 34, 'crystal field: the north-centre mesa, with a mine')
    # loot and the middle
    '60' = @(34, 6, 'north-west fort: armoury (money crate)')
    '61' = @(118, 80, 'the scrub: abandoned depot (money crate)')
    '62' = @(80, 56, 'centre plain (muster)')
    '63' = @(56, 52, 'centre: east end of the bridge road')
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

# ================================================================ resources (workflow/mission-design: 3+ fields on different risk + mines)
# Crystals only (user 2026-10-27, all ARKA maps): the SC minerals became crystals in the converter (home field under the
# north plateau, the centre, the palace district). New fields: wp 55 behind the base (safe), wp 58 in the southern scrub
# (rich, on the way of the south waves) and wp 59 on the north-centre mesa (between the base and the city)
$rnd = New-Object Random 2500
function Near($i, $k, $r) { $c = $wpCell[$k]; $x = $i % 512; $y = [Math]::Floor($i / 512); [Math]::Abs($x - $c[0]) -le $r -and [Math]::Abs($y - $c[1]) -le $r }
$ore = @{ '55' = @(4, 0.7, 5); '58' = @(6, 0.8, 8); '59' = @(5, 0.75, 7) }   # radius, density, minimum stage
foreach ($k in $ore.Keys) {
    $c = $wpCell[$k]; $r = $ore[$k][0]; $n = 0
    for ($x = $c[0] - $r; $x -le $c[0] + $r; $x++) { for ($y = $c[1] - $r; $y -le $c[1] + $r; $y++) {
        if (-not (Passable $x $y) -or ($x -eq $c[0] -and $y -eq $c[1])) { continue }
        if (($x - $c[0]) * ($x - $c[0]) + ($y - $c[1]) * ($y - $c[1]) -gt $r * $r + 1 -or $rnd.NextDouble() -gt $ore[$k][1]) { continue }
        $o = $y * 512 + $x; $conv.Overlay[$o] = [byte](31 + $rnd.Next(4)); $conv.OverlayData[$o] = [byte]($ore[$k][2] + $rnd.Next(12 - $ore[$k][2])); $n++
    } }
    "crystal field wp ${k}: $n cells"
}
# the crystal mines (OREMINE2, made blue-crystal mines by the mission map as in missions 4-5): the open cell nearest to
# the field's centre that touches the field and has nothing on its 8 neighbours except crystals (never closes a path)
function Place-Mine($k) {
    $mineAt = $null
    $cells = @(); for ($i = 0; $i -lt $conv.Overlay.Length; $i++) { $o = $conv.Overlay[$i]; if ($o -ge 27 -and $o -le 38 -and (Near $i $k 9)) { $cells += $i } }
    if (-not $cells.Count) { "WARN no crystal field at wp $k for a mine"; return }
    $mx = ($cells | ForEach-Object { $_ % 512 } | Measure-Object -Average).Average; $my = ($cells | ForEach-Object { [Math]::Floor($_ / 512) } | Measure-Object -Average).Average
    $bd = 1e9
    for ($x = [int]$mx - 9; $x -le [int]$mx + 9; $x++) { for ($y = [int]$my - 9; $y -le [int]$my + 9; $y++) {
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
    if (-not $mineAt) { "WARN no free cell for the crystal mine at wp $k"; return }
    $conv.Terrain[$mineAt[1] * 1000 + $mineAt[0]] = 'OREMINE2'
    "crystal mine OREMINE2 at $($mineAt[0]),$($mineAt[1]) by the field of wp $k ($($cells.Count) cells)"
}
Place-Mine '56'; Place-Mine '58'; Place-Mine '59'
$gems = 0; for ($i = 0; $i -lt $conv.Overlay.Length; $i++) { if ($conv.Overlay[$i] -ge 27 -and $conv.Overlay[$i] -le 38) { $gems++ } }
"crystals on the map: $gems cells"

# ================================================================ Antiga ground (as mission 4): mudflats and scrub
# Low ground -> dirt with scrub clumps and a little grass, the mesas mostly scrub. Pavement (slot 2: the SC platforms
# and asphalt roads of the city) stays. The SC map's own jungle-like patches in the south-east become scrub anyway.
$gN = $conv.N; $step = 7
$gw = [int][Math]::Ceiling($gN / $step) + 2
$vn = New-Object 'double[]' ($gw * $gw); $nr = New-Object Random 2500
for ($i = 0; $i -lt $vn.Length; $i++) { $vn[$i] = $nr.NextDouble() }
$vn2 = New-Object 'double[]' ($gw * $gw); for ($i = 0; $i -lt $vn2.Length; $i++) { $vn2[$i] = $nr.NextDouble() }
function Noise($arr, $x, $y) {
    $fx = $x / $step; $fy = $y / $step; $x0 = [Math]::Floor($fx); $y0 = [Math]::Floor($fy); $tx = $fx - $x0; $ty = $fy - $y0
    $tx = $tx * $tx * (3 - 2 * $tx); $ty = $ty * $ty * (3 - 2 * $ty)
    $a = $arr[$y0 * $gw + $x0]; $b = $arr[$y0 * $gw + $x0 + 1]; $c = $arr[($y0 + 1) * $gw + $x0]; $d = $arr[($y0 + 1) * $gw + $x0 + 1]
    ($a * (1 - $tx) + $b * $tx) * (1 - $ty) + ($c * (1 - $tx) + $d * $tx) * $ty
}
$cnt = @(0, 0, 0, 0)
for ($y = 0; $y -lt $gN; $y++) { for ($x = 0; $x -lt $gN; $x++) {
    $i = $conv.Idx($x, $y); $g = $conv.Ground[$i]
    if ($g -eq 2) { continue }
    $high = $conv.Plateau[$i] -ge 0
    $n1 = Noise $vn $x $y; $n2 = Noise $vn2 $x $y
    if ($high) { $g = if ($n1 -lt 0.62) { 3 } else { 1 } }
    else { $g = if ($n1 -gt 0.72) { 3 } elseif ($n2 -gt 0.80) { 0 } else { 1 } }
    $conv.Ground[$i] = $g; $cnt[$g]++
} }
"ground: dirt $($cnt[1]), scrub $($cnt[3]), grass $($cnt[0]) cells (pavement unchanged)"
$base[3] = $th.SetByName('Autumn Grass').Start
$lat[3]  = $th.SetByName('Autumn Grass/Clear LAT').Start

# ================================================================ the Allied base squares and the highway to the city
# Squares: discs of pavement round the ARKA, the west and south entrances of the base and Raynor's landing spot, on the
# cell's own level only. Highway: the shortest open path from the city gate (wp 42, on an SC platform, i.e. pavement)
# through the centre (wp 62) to the west entrance square (wp 20) and on to the ARKA square (wp 10), 2 cells wide as
# Paved Road LAT; both ends sit in pavement, so no street ends in the grass (workflow/mission-maps, "Drogi")
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
$sq = [ordered]@{ '10' = 6; '20' = 4; '21' = 3; '22' = 3; '42' = 3 }
foreach ($k in $sq.Keys) { $n = Pave $k $sq[$k]; "square at wp ${k}: $n cells" }
$road = New-Object 'bool[]' ($conv.N * $conv.N); $free = 0
function Street($from, $to, [string[]]$via) {
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
                if ($d[0] -and $d[1] -and -not ((Passable ($x + $d[0]) $y) -or (Passable $x ($y + $d[1])))) { continue }
                $prev[$n] = $c; $q.Enqueue($n)
            }
        }
        if ($prev[$ib] -eq -2) { "WARN street $from -> ${to}: no open path from wp $($pts[$s]) to wp $($pts[$s + 1])"; $script:free++; return }
        $seg = New-Object Collections.Generic.List[int]; $c = $ib; while ($c -ne -1) { $seg.Insert(0, $c); $c = $prev[$c] }
        if ($path.Count) { $seg.RemoveAt(0) }
        $path.AddRange($seg)
    }
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
Street '42' '20' @('62')
Street '20' '10' @()
Street '21' '10' @()
Street '22' '10' @()
# a road cell squeezed into pavement (3+ pavement sides) becomes pavement: road and pavement cells taking turns drew a
# grid of LAT edges on the city gate platform (user 2026-10-30)
$nGrid = 0
for ($pass = 0; $pass -lt 2; $pass++) {
    for ($y = 1; $y -lt $conv.N - 1; $y++) { for ($x = 1; $x -lt $conv.N - 1; $x++) {
        $i = $conv.Idx($x, $y); if (-not $road[$i]) { continue }
        $n4 = 0; foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) { if ($conv.Ground[$conv.Idx($x + $d[0], $y + $d[1])] -eq 2) { $n4++ } }
        if ($n4 -ge 3) { $road[$i] = $false; $conv.Ground[$i] = 2; $nGrid++ }
    } }
}
"road cells absorbed into pavement: $nGrid"
# free-end check: every road component must touch pavement at two different places (squares or the SC platforms)
$pave = New-Object 'bool[]' ($conv.N * $conv.N); for ($i = 0; $i -lt $pave.Length; $i++) { $pave[$i] = $conv.Ground[$i] -eq 2 -and $conv.Valid[$i] }
$seen = New-Object 'bool[]' ($conv.N * $conv.N); $comps = 0
for ($i = 0; $i -lt $road.Length; $i++) {
    if (-not $road[$i] -or $seen[$i]) { continue }
    $comps++; $q = New-Object 'Collections.Generic.Queue[int]'; $q.Enqueue($i); $seen[$i] = $true; $touched = @{}
    while ($q.Count) {
        $c = $q.Dequeue(); $x = $c % $conv.N; $y = [Math]::Floor($c / $conv.N)
        foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
            $nx = $x + $d[0]; $ny = $y + $d[1]; if (-not $conv.In($nx, $ny)) { continue }
            $n = $conv.Idx($nx, $ny)
            if ($pave[$n]) { $touched["$([Math]::Floor($nx / 12)),$([Math]::Floor($ny / 12))"] = 1 }
            if ($road[$n] -and -not $seen[$n]) { $seen[$n] = $true; $q.Enqueue($n) }
        }
    }
    if ($touched.Count -lt 2) { $free++; "WARN road component $comps touches pavement in $($touched.Count) place(s)" }
}
"roads: $comps component(s), free ends $free"

$conv.ApplyGround(0, $base, $lat)
# LAT with paved roads (as build-arka05-tarsonis.ps1 / DesignToDta.ApplyGroundRoads)
# (the direction tables must not be called $NX/$NY: PowerShell names ignore case, so $nx = ... overwrote them after the
# first step and gave pavement cells random LAT edges, a grid on the platforms; user 2026-10-30)
$LX = 0, 1, 0, -1; $LY = -1, 0, 1, 0
for ($y = 0; $y -lt $conv.N; $y++) { for ($x = 0; $x -lt $conv.N; $x++) {
    $i = $conv.Idx($x, $y); if (-not $conv.Valid[$i] -or $conv.Used[$i]) { continue }
    $g = $conv.Ground[$i]; if ($g -ne 2 -and $g -ne $RoadG) { continue }
    $mask = 0; $onlyPave = $true
    for ($d = 0; $d -lt 4; $d++) {
        $nx = $x + $LX[$d]; $ny = $y + $LY[$d]; if (-not $conv.In($nx, $ny)) { continue }
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
# never within 4 cells of a waypoint, never on pavement or a road, and only where all 8 neighbours are open
$nearWp = New-Object 'bool[]' ($conv.N * $conv.N)
foreach ($k in $wpCell.Keys) { $c = $wpCell[$k]; for ($x = $c[0] - 4; $x -le $c[0] + 4; $x++) { for ($y = $c[1] - 4; $y -le $c[1] + 4; $y++) { if ($conv.In($x, $y)) { $nearWp[$conv.Idx($x, $y)] = $true } } } }
$nDeco = 0
for ($y = 1; $y -lt $conv.N - 1; $y++) { for ($x = 1; $x -lt $conv.N - 1; $x++) {
    $i = $conv.Idx($x, $y)
    if (-not (Passable $x $y) -or $nearWp[$i] -or $conv.Ground[$i] -eq 2 -or $conv.Ground[$i] -eq $RoadG) { continue }
    $open = $true
    for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { if (($dx -or $dy) -and (-not (Passable ($x + $dx) ($y + $dy)) -or $road[$conv.Idx($x + $dx, $y + $dy)] -or $conv.Ground[$conv.Idx($x + $dx, $y + $dy)] -eq 2)) { $open = $false } } }
    if (-not $open) { continue }
    $chance = if ($conv.Ground[$i] -eq 3) { 0.02 } else { 0.008 }
    if ($rnd.NextDouble() -lt $chance) { $conv.Terrain[$y * 1000 + $x] = $trees[$rnd.Next($trees.Length)]; $nDeco++ }
} }
"dressing: $nDeco trees/bushes"
# a bush over every chain-end seam left (the terrain object is drawn over the hard water edge); never on a road
$nSeamBush = 0
foreach ($i in $seams) {
    $x = $i % $conv.N; $y = [Math]::Floor($i / $conv.N)
    if ($road[$i] -or $conv.Ground[$i] -eq 2 -or $conv.Terrain.ContainsKey($y * 1000 + $x)) { continue }
    $conv.Terrain[$y * 1000 + $x] = 'JBR0' + (1 + $rnd.Next(5)); $nSeamBush++
}
"bushes over chain-end seams: $nSeamBush of $($seams.Count)"

$conv.WallFrames(2, [int[]]@(0, 2, 4, 6))
$conv.CheckConnectivity()
$cmp = $conv.CompareWithSc(); $cmp.Save("$work\compare_sc.png"); $cmp.Dispose()
$text = $conv.WriteMap('ARKA #7: Zdrada (teren)', 'Claude (kampania ARKA; teren: Blizzard T8 The Trump Card, port: Claude)')
$conv.Log | Set-Content "$work\log.txt" -Encoding UTF8
"converter: $($conv.Log.Count) log lines; starts $($conv.Starts.Count) connected=$($conv.StartsConnected) sealed $($conv.Sealed) leaks $($conv.Leaks) failed chains $($conv.ChainFailures)"
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::GetEncoding(1252))
$ini = [Ini]::Load($Out)
$ini.Set('Map', 'Theater', 'TEMPERATE')
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; $ini.Set('Waypoints', $k, "$($c[1] * 1000 + $c[0])") }
$ini.Set('Basic', 'Name', 'ARKA #7: Zdrada (teren, Antiga Prime)')
$st = $ini.Section('Structures'); $nT = 0
for ($i = $st.Count - 1; $i -ge 0; $i--) { if ($st[$i].Value -match ',DBTMPL,') { $st.RemoveAt($i); $nT++ } }
if ($nT) { "removed $nT converter temple(s) (DBTMPL)" }
[IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))
"written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB), Size 0,0,$($conv.W),$($conv.H)"

# ================================================================ checks: every waypoint reachable by ground from the ARKA
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
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; "wp $k path $($dist[$conv.Idx($c[0], $c[1])]) cells ($($wps[$k][2]))"; if (-not $reach[$conv.Idx($c[0], $c[1])]) { "WARN wp $k ($($wps[$k][2])) not reachable from the ARKA by ground (conservative test)"; $fail++ } }
"CHECKS: " + $(if ($fail) { "$fail waypoint(s) unreachable" } else { "PASS (all $($wps.Count) waypoints reachable from the ARKA)" }) + "; road free ends $free"

# ================================================================ pictures: SC grid for planning, waypoints on the cell map
$g0 = [Drawing.Image]::FromFile("$work\sc.png")
$grid = New-Object Drawing.Bitmap 2048, 1536; $g = [Drawing.Graphics]::FromImage($grid); $g.DrawImage($g0, 0, 0, 2048, 1536); $g0.Dispose()
$pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(110, 255, 255, 255)), 1; $font = New-Object Drawing.Font 'Arial', 8
for ($k = 0; $k -le 128; $k += 4) { $g.DrawLine($pen, $k * 16, 0, $k * 16, 1536); $g.DrawString("$k", $font, [Drawing.Brushes]::White, $k * 16 + 1, 1) }
for ($k = 0; $k -le 96; $k += 4) { $g.DrawLine($pen, 0, $k * 16, 2048, $k * 16); $g.DrawString("$k", $font, [Drawing.Brushes]::White, 1, $k * 16 + 1) }
$bf = New-Object Drawing.Font 'Arial', 9, ([Drawing.FontStyle]::Bold)
foreach ($k in $wps.Keys) { $p = $wps[$k]; $g.FillEllipse([Drawing.Brushes]::Red, $p[0] * 16 + 4, $p[1] * 16 + 4, 8, 8); $g.DrawString($k, $bf, [Drawing.Brushes]::Yellow, $p[0] * 16 + 10, $p[1] * 16 - 2) }
$g.Dispose(); $grid.Save("$work\sc_grid.png"); $grid.Dispose()
$dbg = $conv.DebugImage(); $g = [Drawing.Graphics]::FromImage($dbg)
foreach ($k in $wps.Keys) {
    $c = $wpCell[$k]; $dx = 0; $dy = 0; $conv.ToScreen($c[0], $c[1], [ref]$dx, [ref]$dy)
    $sx = $dbg.Width * ($dx + 1) / (2 * $conv.W); $sy = $dbg.Height * ($dy + 1) / (2 * $conv.H)
    $g.FillEllipse([Drawing.Brushes]::Red, $sx - 4, $sy - 4, 8, 8); $g.DrawString($k, $bf, [Drawing.Brushes]::Yellow, $sx + 5, $sy - 6)
}
$g.Dispose(); $dbg.Save("$work\waypoints.png"); $dbg.Dispose()
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
