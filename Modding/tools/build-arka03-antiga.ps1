# Terrain of ARKA mission 3 "Sygnal z nieba" (Antiga Prime, 2499): the StarCraft Terran campaign map T5 "Revolution"
# (the SC mission of the Antiga uprising and Kerrigan's debut, read from the user's StarCraft: Remastered CASC,
# SD/campaign/Terran/Terran05) turned 90 degrees clockwise, and in its top-right corner the ARKA base of mission 4 cut
# from T6 "Norad II" (the same Antiga plain, user 2026-10-30: "this is the starting point, take it as the top-right
# corner of the map, the battlefield goes down"). Both SC maps are badlands; they are joined on the SC minitile level
# (walkability, elevation, colour), so the converter (ScToDta) draws cliffs and shores across the seam itself. Scale
# 1.5x and the Antiga ground (mudflats and scrub) as in build-arka04-antiga.ps1; the base corner keeps mission 4's
# ground pattern and trees, so the start looks like mission 4's base without the laboratory.
# Writes Maps\Custom\arka03_antiga.map (viewable as a skirmish "Custom Map") and the mission waypoints 10-79, which are
# the contract with build-arka03-mission.ps1.
#
#   powershell -NoProfile -File .\build-arka03-antiga.ps1            # build + checks + preview + render (~2 min)
#   powershell -NoProfile -File .\build-arka03-antiga.ps1 -NoRender  # no CNCMaps render
#
# Work files: %TEMP%\arka03-terrain\ (sc.png composite, grid.png, reach.png, waypoints.png, log.txt).
# Wiki: Modding/wiki/missions/arka-03-sygnal.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$Out = "",
    [switch]$NoRender
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Out) { $Out = "$game\Maps\Custom\arka03_antiga.map" }
$work = "$env:TEMP\arka03-terrain"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScMap.cs", "$tools\TsMap.cs", "$tools\ScToDta.cs" -ReferencedAssemblies System.Drawing
$Zoom = 1.5

# ================================================================ StarCraft side: T5 turned + T6 base corner
$casc = New-Object Casc $StarCraft
function Load-Sc($m) {
    $c = New-Object Chk (, $casc.ReadFile("SD/campaign/Terran/$m/staredit/scenario.chk"))
    $ts = New-Object ScTileset $casc, ([Chk]::EraNames[$c.Era])
    "SC $m : $($c.Width)x$($c.Height) $([Chk]::EraNames[$c.Era])" | Out-Host
    @($c, (New-Object ScTerrain $c, $ts))
}
$r = Load-Sc 'Terran05'; $chk = $r[0]; $ter = $r[1]
$r = Load-Sc 'Terran06'; $chk6 = $r[0]; $ter6 = $r[1]
# geysers out (the converter turns them into Tiberium trees; nobody here knows Tiberium yet)
foreach ($c in $chk, $chk6) { $c.Units.RemoveAll([Predicate[ScUnit]] { param($u) $u.Id -eq 188 }) | Out-Null }

# T5 turned 90 degrees clockwise: (x, y) -> (H-1-y, x). The player's start (T5 top-left) goes to the top-right, the
# Confederate base (T5 top-right, a high plateau) to the bottom-right, the rebels' corner (T5 bottom-left) to the
# top-left, the lake stays in the middle
$W0 = $ter.W; $H0 = $ter.H
$f = New-Object 'int[]' ($W0 * $H0); $c = New-Object 'int[]' ($W0 * $H0)
for ($y = 0; $y -lt $H0; $y++) { for ($x = 0; $x -lt $W0; $x++) { $d = $x * $H0 + ($H0 - 1 - $y); $f[$d] = $ter.Flags[$y * $W0 + $x]; $c[$d] = $ter.Rgb[$y * $W0 + $x] } }
$ter.W = $H0; $ter.H = $W0; $ter.Flags = $f; $ter.Rgb = $c
$pxH = $chk.Height * 32
foreach ($u in $chk.Units) { $x = $u.X; $u.X = $pxH - $u.Y; $u.Y = $x }
foreach ($s in $chk.Sprites) { $x = $s.X; $s.X = $pxH - $s.Y; $s.Y = $x }
$w = $chk.Width; $chk.Width = $chk.Height; $chk.Height = $w

function Zoom-Ter($t, $c) {
    $w0 = $t.W; $h0 = $t.H; $w1 = [int]($w0 * $Zoom); $h1 = [int]($h0 * $Zoom)
    $fl = New-Object 'int[]' ($w1 * $h1); $rgb = New-Object 'int[]' $fl.Length
    for ($y = 0; $y -lt $h1; $y++) { for ($x = 0; $x -lt $w1; $x++) {
        $src = [Math]::Min($h0 - 1, [Math]::Floor($y / $Zoom)) * $w0 + [Math]::Min($w0 - 1, [Math]::Floor($x / $Zoom))
        $fl[$y * $w1 + $x] = $t.Flags[$src]; $rgb[$y * $w1 + $x] = $t.Rgb[$src]
    } }
    $t.W = $w1; $t.H = $h1; $t.Flags = $fl; $t.Rgb = $rgb
    $c.Width = [int]($c.Width * $Zoom); $c.Height = [int]($c.Height * $Zoom)
    foreach ($u in $c.Units) { $u.X = [int]($u.X * $Zoom); $u.Y = [int]($u.Y * $Zoom) }
    foreach ($s in $c.Sprites) { $s.X = [int]($s.X * $Zoom); $s.Y = [int]($s.Y * $Zoom) }
}
Zoom-Ter $ter $chk; Zoom-Ter $ter6 $chk6

# T6 corner -> composite top-right. Zoomed tiles: T6 x 0..72, y 84..144 (the ARKA base of mission 4 with its home
# field, the bunker lines and the eastern cliffs) to composite x 72..144, y 0..60. The x shift must be even: then
# every DTA cell maps to a whole cell of mission 4's map (both maps are 144x144 zoomed tiles, the same DTA Size):
# composite cell = mission-4 cell + ($CellDX, $CellDY)
$CutX = 0; $CutY = 84; $CutW = 72; $CutH = 60; $PasteX = 72; $PasteY = 0
$TX = $PasteX - $CutX; $TY = $PasteY - $CutY
if ($TX % 2) { throw "paste x shift must be even" }
$CellDX = ($TX + 2 * $TY) / 2; $CellDY = (2 * $TY - $TX) / 2
"corner: T6 zoomed tiles $CutX..$($CutX + $CutW) x $CutY..$($CutY + $CutH) -> composite $PasteX,$PasteY; cell shift $CellDX,$CellDY"
# seam: a band of 40 minitiles (10 tiles) along the corner's west and south sides where a smooth noise decides, so the
# lake shore and the plain run ragged instead of along a ruler; T6 high ground never enters the band (its plateau in
# the SW of the cut would end in a straight cliff)
$band = 40; $mw = $ter.W
$sn = New-Object Random 2499; $gs = 16; $gw = [int]($mw / $gs) + 2
$sv = New-Object 'double[]' ($gw * $gw); for ($i = 0; $i -lt $sv.Length; $i++) { $sv[$i] = $sn.NextDouble() }
function SeamNoise($x, $y) {
    $fx = $x / $gs; $fy = $y / $gs; $x0 = [Math]::Floor($fx); $y0 = [Math]::Floor($fy); $tx = $fx - $x0; $ty = $fy - $y0
    $tx = $tx * $tx * (3 - 2 * $tx); $ty = $ty * $ty * (3 - 2 * $ty)
    $a = $sv[$y0 * $gw + $x0]; $b = $sv[$y0 * $gw + $x0 + 1]; $c = $sv[($y0 + 1) * $gw + $x0]; $d = $sv[($y0 + 1) * $gw + $x0 + 1]
    ($a * (1 - $tx) + $b * $tx) * (1 - $ty) + ($c * (1 - $tx) + $d * $tx) * $ty
}
$mx0 = $PasteX * 4; $my1 = ($PasteY + $CutH) * 4
$fromT6 = New-Object 'bool[]' ($mw * $ter.H)
$n6 = 0
for ($y = $PasteY * 4; $y -lt $my1; $y++) { for ($x = $mx0; $x -lt $mw; $x++) {
    $sx = $x - $TX * 4; $sy = $y - $TY * 4; $s = $sy * $ter6.W + $sx
    $dEdge = [Math]::Min($x - $mx0, $my1 - 1 - $y)
    if ($dEdge -lt $band) {
        $t = $dEdge / $band + (SeamNoise $x $y) - 0.5
        if ($t -lt 0.5 -or ($ter6.Flags[$s] -band 6)) { continue }
    }
    $d = $y * $mw + $x; $ter.Flags[$d] = $ter6.Flags[$s]; $ter.Rgb[$d] = $ter6.Rgb[$s]; $fromT6[$d] = $true; $n6++
} }
"corner: $n6 minitiles from T6"
# two causeways across the lake (T5's dark diagonal "bridges" are doodads the converter cannot cross): the island west
# of the base to the west shore (the Sons of Korhal camp, T5's rebel corner), and the SW island to the low shore under
# the Confederate plateau. Without them the whole west third is cut off from the ARKA. Zoomed tile coordinates; the
# converter finds narrow land between two waters and paves it
$lowRgb = @(0, 0, 0); $nLow = 0
for ($i = 0; $i -lt $ter.Flags.Length; $i += 7) { if (($ter.Flags[$i] -band 7) -eq 1) { $col = [Drawing.Color]::FromArgb($ter.Rgb[$i]); if ($col.B -le $col.R) { $lowRgb[0] += $col.R; $lowRgb[1] += $col.G; $lowRgb[2] += $col.B; $nLow++ } } }
$dirt = [Drawing.Color]::FromArgb([int]($lowRgb[0] / $nLow), [int]($lowRgb[1] / $nLow), [int]($lowRgb[2] / $nLow)).ToArgb()
# the lake arm between the island and the base ends in a tip 1-2 tiles wide (tiles 72-76, rows 17-24): no water-cliff
# chain fits round it and a bare straight edge stayed (user screenshot 2026-10-30). The tip becomes land, so the arm
# ends where it is 5 tiles wide
$tipN = 0
for ($y = 17 * 4; $y -lt 25 * 4; $y++) { for ($x = 70 * 4; $x -lt 79 * 4; $x++) { $d = $y * $mw + $x; if (($ter.Flags[$d] -band 1) -eq 0) { $ter.Flags[$d] = 1; $tipN++ } } }
"lake arm tip by the base filled: $tipN minitiles"
$fords = @(@(31, 25, 51, 23, 'island W of the base -> west shore'), @(25, 130, 42, 130, 'SW island -> shore under the plateau'))
foreach ($fd in $fords) {
    $ax = $fd[0] * 4 + 2; $ay = $fd[1] * 4 + 2; $bx = $fd[2] * 4 + 2; $by = $fd[3] * 4 + 2; $len2 = ($bx - $ax) * ($bx - $ax) + ($by - $ay) * ($by - $ay); $n = 0
    for ($y = [Math]::Min($ay, $by) - 12; $y -le [Math]::Max($ay, $by) + 12; $y++) { for ($x = [Math]::Min($ax, $bx) - 12; $x -le [Math]::Max($ax, $bx) + 12; $x++) {
        $t = [Math]::Max(0.0, [Math]::Min(1.0, [double](($x - $ax) * ($bx - $ax) + ($y - $ay) * ($by - $ay)) / $len2))   # doubles: Min(1, x) would round x to an int
        $qx = $ax + $t * ($bx - $ax) - $x; $qy = $ay + $t * ($by - $ay) - $y
        # half width 18 minitiles = 9 tiles across: a narrower strip becomes a FindBridges causeway, paved straight onto
        # the water without shore pieces (a grey saw in the lake); this wide one is an isthmus with water cliffs
        if ($qx * $qx + $qy * $qy -gt 324) { continue }
        $d = $y * $mw + $x; if (($ter.Flags[$d] -band 1) -eq 0) { $ter.Flags[$d] = 1; $ter.Rgb[$d] = $dirt; $n++ }
    } }
    "causeway $($fd[4]): $n minitiles"
}
# bevel the concave corner where causeway A's south side meets the island's west shore (tiles ~48,28.5): at a right
# angle the two water-cliff chains missed each other and left 3 cells of bare edge (render check 2026-10-30)
$bev = 0
for ($y = 26 * 4; $y -lt 36 * 4; $y++) { for ($x = 38 * 4; $x -lt 50 * 4; $x++) {
    if ((48 * 4 - $x) + ($y - 28.5 * 4) -ge 5 * 4) { continue }
    $d = $y * $mw + $x; if (($ter.Flags[$d] -band 1) -eq 0) { $ter.Flags[$d] = 1; $ter.Rgb[$d] = $dirt; $bev++ }
} }
"causeway A corner bevelled: $bev minitiles"
function InCorner($px, $py) { $mx = [int][Math]::Floor($px / 8); $my = [int][Math]::Floor($py / 8); $mx -ge 0 -and $my -ge 0 -and $mx -lt $mw -and $my -lt $ter.H -and $fromT6[$my * $mw + $mx] }
# objects: T5's outside the corner, T6's inside it (moved by the tile shift)
$chk.Units.RemoveAll([Predicate[ScUnit]] { param($u) InCorner $u.X $u.Y }) | Out-Null
$chk.Sprites.RemoveAll([Predicate[ScDoodad]] { param($s) InCorner $s.X $s.Y }) | Out-Null
$nU = 0
foreach ($u in $chk6.Units) { $u.X += $TX * 32; $u.Y += $TY * 32; if (InCorner $u.X $u.Y) { $chk.Units.Add($u); $nU++ } }
foreach ($s in $chk6.Sprites) { $s.X += $TX * 32; $s.Y += $TY * 32; if (InCorner $s.X $s.Y) { $chk.Sprites.Add($s) } }
# the only start location: the ARKA (T5's was in the corner)
$chk.Units.RemoveAll([Predicate[ScUnit]] { param($u) $u.Id -eq 214 }) | Out-Null
$chk.Units.Add((New-Object ScUnit -Property @{ X = (13 * 1.5 + $TX + 0.5) * 32; Y = (77 * 1.5 + $TY + 0.5) * 32; Id = 214; Owner = 0 }))
"objects: $($chk.Units.Count) units ($nU from T6), $($chk.Sprites.Count) sprites"
$sc = [Img]::FromBuffer($ter.Rgb, $ter.W, $ter.H); $sc.Save("$work\sc.png"); $sc.Dispose()

# ================================================================ DTA side: TEMPERATE theater (as build-arka04-antiga.ps1)
$mixes  = New-Object MixSet "$game\MIX"
$th     = New-Object Theater "$game\INI\Temperat.ini", "tem", $mixes
$wae    = "$game\Map Editor\Editor\Config\ConnectedTileDrawer.ini"
$cliffs = New-Object ConnectedSet $wae, "TemperateCliffSet", $th
$shores = New-Object ConnectedSet $wae, "TemperateWaterCliffSet", $th

$conv = New-Object ScToDta $chk, $ter, $th
$conv.Classify()
$conv.Resources()
$conv.Cliffs($cliffs)
$conv.Shores($shores, $true)
$conv.SettleWater()
$rawWater = New-Object 'bool[]' $conv.K.Length   # water that no shore piece covers (plain water fill), for the raw-coast map
for ($i = 0; $i -lt $rawWater.Length; $i++) { $rawWater[$i] = "$($conv.K[$i])" -eq 'Water' -and -not $conv.Used[$i] }
$seamCells = @($conv.TipSeams())   # bare land against water that no piece closes: cropped from the render below (coast.png)
"coast: $($seamCells.Count) seam cells left after the converter's repair"
$conv.FillWater($th.SetByName('Animated Water'), $th.SetByName('Water').Start)
$trees = [string[]]@('T01', 'T02', 'T03', 'T05', 'T06', 'T07', 'T08', 'T09', 'T10', 'T11', 'T12', 'T13', 'T14', 'T15', 'T16', 'T17', 'JBR01', 'JBR02', 'JBR03', 'JBR04', 'JBR05')
$rocks = $th.SetByName('Small Rocks').Start
$conv.Obstacles($trees, [int[]]@($rocks, ($rocks + 3)))
$conv.Cleanup()
$conv.RepairDecorations()
$conv.PaintGround()
$base = [int[]]@(0, $th.SetByName('Dirt LAT').Start, $th.SetByName('Pavement LAT').Start, $th.SetByName('Tall Grass').Start)
$lat  = [int[]]@(0, $th.SetByName('Clear/Dirt LAT').Start, $th.SetByName('Clear/Pavement LAT').Start, $th.SetByName('Tall/Short Grass LAT').Start)
# a DTA cell is in the corner when the SC pixel of its centre came from T6
function CellInCorner($x, $y) { $px = 0.0; $py = 0.0; $conv.ScPixel($x, $y, [ref]$px, [ref]$py); InCorner $px $py }

# ================================================================ mission waypoints (contract 10-79 with build-arka03-mission.ps1)
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
# the base (10-19) and its two bunker lines (20, 21) where mission 4 has them: mission 4's waypoints moved by the cell
# shift. The rest in COMPOSITE zoomed tile coordinates (144x144, grid.png)
$m4 = [Ini]::Load("$game\Maps\Custom\arka04_antiga.map")
$m4wp = @{}; foreach ($kv in $m4.Section('Waypoints')) { $v = [int]$kv.Value; $m4wp[$kv.Key] = @(($v % 1000 + $CellDX), ([Math]::Floor($v / 1000) + $CellDY)) }
$wps = [ordered]@{
    '10' = @('m4', '10', 'ARKA')
    '11' = @('m4', '11', 'player start army')
    '12' = @('m4', '13', 'Allied barracks (where mission 4 has the ConYard; no ConYard here, a covert mission)')
    '13' = @('m4', '14', 'helipad (where mission 4 has the barracks)')
    '14' = @('m4', '15', 'Allied refinery (home crystals by the west seam)')
    '15' = @('m4', '16', 'Allied war factory')
    '16' = @('m4', '17', 'power plant 1')
    '17' = @('m4', '18', 'power plant 2')
    '18' = @('m4', '12', 'Kerrigan and the Sons of Korhal liaison (where the laboratory stands in mission 4)')
    '19' = @('m4', '19', 'radar / free spot')
    '20' = @('m4', '47', 'base: north bunker line')
    '21' = @('m4', '48', 'base: east bunker line')
    # the Sons of Korhal camp (NW, T5's rebel corner) and the two causeways
    '22' = @(10, 6, 'Sons of Korhal: Command Center')
    '23' = @(8, 15, 'Sons of Korhal: barracks')
    '24' = @(30, 19, 'Sons of Korhal: camp exit (east, to causeway A)')
    '25' = @(44, 23, 'causeway A (island W of the base <-> camp)')
    '26' = @(35, 130, 'causeway B (SW island <-> SW shore)')
    '27' = @(50, 118, 'SW shore under the plateau (staging)')
    # the two observation towers and their guards (guards >= 15 tiles from their tower: Kerrigan, cloaked, slips past)
    '28' = @(110, 95, 'observation tower 1 (south end of the plain, over the SE valley)')
    '29' = @(122, 82, 'tower 1 guard post A (city checkpoint side)')
    '30' = @(62, 105, 'observation tower 2 (lakeside path to the SW shore)')
    '31' = @(84, 101, 'tower 2 guard post (east end of the lakeside path)')
    # the prison camp on the SW shore
    '32' = @(52, 112, 'prison: the cell block (barracks)')
    '33' = @(56, 116, 'prison: gate (inside the fence)')
    '34' = @(58, 122, 'prison: guard post')
    # the city outskirts on the plain south of the base (neutral SC buildings)
    '35' = @(120, 64, 'Antiga outskirts: centre')
    '36' = @(114, 86, 'Antiga outskirts: Confederate checkpoint')
    # the Confederate garrison on the SE plateau (T5's Confederate base)
    '37' = @(121, 131, 'garrison: Command Center (objective)')
    '38' = @(127, 117, 'garrison: barracks')
    '39' = @(116, 119, 'garrison: factory')
    '40' = @(109, 126, 'garrison: ramp from the SE valley (entrance)')
    '41' = @(124, 107, 'garrison: north defence')
    '42' = @(134, 131, 'garrison: crystal field')
    '43' = @(100, 118, 'psi emitter (SE valley under the garrison ramp)')
    # enemy entries
    '44' = @(84, 141, 'Zerg entry S (bottom edge, plateau B)')
    '45' = @(141, 76, 'Zerg entry E (right edge, high strip)')
    '46' = @(140, 41, 'Zerg entry NE (right edge, the plain by the base)')
    '47' = @(4, 141, 'Zerg flyers entry (SW corner, over the lake)')
    '48' = @(104, 108, 'Confederate patrol staging (SE valley)')
    # crates, fields, posts
    '50' = @(126, 70, 'crate: outskirts customs office')
    '51' = @(60, 18, 'crate: island W of the base')
    '52' = @(20, 126, 'crate: SW island (rebel cache)')
    '53' = @(140, 106, 'crate: garrison depot')
    '54' = @(22, 6, 'field: Sons of Korhal camp')
    '55' = @(74, 116, 'field: central plateau (contested, crystal mine)')
    '56' = @(22, 131, 'field: SW island (crystal mine)')
    '57' = @(106, 80, 'tower 1 patrol point B (west side of the plain)')
    '58' = @(62, 129, 'plateau B: west ramp top (Sons of Korhal assault route)')
    '59' = @(80, 130, 'plateau B: centre (Zerg path to the garrison)')
    '60' = @(46, 139, 'SW shore: south end')
    '61' = @(10, 60, 'west strip: middle (Sons of Korhal route south)')
}
$wpCell = @{}
function Resolve-Wp($k) {
    $p = $wps[$k]
    if ($p[0] -eq 'm4') { $c = $m4wp[$p[1]]; $cx = $c[0]; $cy = $c[1] }
    else { $cx = 0; $cy = 0; $conv.CellAt(($p[0] + 0.5) * 32, ($p[1] + 0.5) * 32, [ref]$cx, [ref]$cy) }
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
    $script:wpCell[$k] = $best
}
foreach ($k in $wps.Keys) { Resolve-Wp $k }

# ================================================================ resources: the thin home field of mission 4
function Near($i, $k, $r) { $c = $wpCell[$k]; $x = $i % 512; $y = [Math]::Floor($i / 512); [Math]::Abs($x - $c[0]) -le $r -and [Math]::Abs($y - $c[1]) -le $r }
$nHome = 0; $nGem = 0
for ($i = 0; $i -lt $conv.Overlay.Length; $i++) {
    $o = $conv.Overlay[$i]; if ($o -lt 27 -or $o -gt 38) { continue }
    $nGem++
    if (Near $i '14' 16) { $conv.OverlayData[$i] = [byte](3 + ($i % 3)); $nHome++ }
}
"resources: $nGem crystal cells, home field thinned ($nHome cells, stage 3-5)"
# crystal mines (workflow/mission-design: a mine far from the base worth holding) by the contested field on the central
# plateau and by the SW island field; OREMINE2, which the mission turns into a blue-crystal mine (as mission 4). Spot:
# the open cell nearest to the field's centre that touches the field, is not by a waypoint and has open neighbours
foreach ($k in '55', '56') {
    $cells = @(); for ($i = 0; $i -lt $conv.Overlay.Length; $i++) { $o = $conv.Overlay[$i]; if ($o -ge 27 -and $o -le 38 -and (Near $i $k 10)) { $cells += $i } }
    if (-not $cells.Count) { "WARN no field at wp $k for a mine"; continue }
    $mx = ($cells | ForEach-Object { $_ % 512 } | Measure-Object -Average).Average; $my = ($cells | ForEach-Object { [Math]::Floor($_ / 512) } | Measure-Object -Average).Average
    $best = $null; $bd = 1e9
    for ($x = [int]$mx - 10; $x -le [int]$mx + 10; $x++) { for ($y = [int]$my - 10; $y -le [int]$my + 10; $y++) {
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
        $d = ($x - $mx) * ($x - $mx) + ($y - $my) * ($y - $my); if ($d -lt $bd) { $bd = $d; $best = @($x, $y) }
    } }
    if (-not $best) { "WARN no free cell for the mine at wp $k"; continue }
    $conv.Terrain[$best[1] * 1000 + $best[0]] = 'OREMINE2'
    "mine OREMINE2 at $($best[0]),$($best[1]) by the field of wp $k ($($cells.Count) cells)"
}

# ================================================================ Antiga ground: mudflats and scrub (as mission 4)
# The corner uses mission 4's noise at mission 4's cell, so the base looks the same; the rest its own
$gN = $conv.N; $step = 7
$gw2 = [int][Math]::Ceiling(($gN + 200) / $step) + 2
$vn = New-Object 'double[]' ($gw2 * $gw2); $nr = New-Object Random 2499
# mission 4 drew $gw = ceil(N/7)+2 values per row; its noise is rebuilt with the same generator and stride
$gw4 = [int][Math]::Ceiling($gN / $step) + 2
$vn4 = New-Object 'double[]' ($gw4 * $gw4); for ($i = 0; $i -lt $vn4.Length; $i++) { $vn4[$i] = $nr.NextDouble() }
$vn42 = New-Object 'double[]' ($gw4 * $gw4); for ($i = 0; $i -lt $vn42.Length; $i++) { $vn42[$i] = $nr.NextDouble() }
$nr3 = New-Object Random 2500
for ($i = 0; $i -lt $vn.Length; $i++) { $vn[$i] = $nr3.NextDouble() }
$vn2 = New-Object 'double[]' ($gw2 * $gw2); for ($i = 0; $i -lt $vn2.Length; $i++) { $vn2[$i] = $nr3.NextDouble() }
function Noise($arr, $stride, $x, $y) {
    $fx = $x / $step; $fy = $y / $step; $x0 = [Math]::Floor($fx); $y0 = [Math]::Floor($fy); $tx = $fx - $x0; $ty = $fy - $y0
    $tx = $tx * $tx * (3 - 2 * $tx); $ty = $ty * $ty * (3 - 2 * $ty)
    $a = $arr[$y0 * $stride + $x0]; $b = $arr[$y0 * $stride + $x0 + 1]; $c = $arr[($y0 + 1) * $stride + $x0]; $d = $arr[($y0 + 1) * $stride + $x0 + 1]
    ($a * (1 - $tx) + $b * $tx) * (1 - $ty) + ($c * (1 - $tx) + $d * $tx) * $ty
}
$cnt = @(0, 0, 0, 0); $inCorner = New-Object 'bool[]' ($gN * $gN)
for ($y = 0; $y -lt $gN; $y++) { for ($x = 0; $x -lt $gN; $x++) {
    $i = $conv.Idx($x, $y); if (-not $conv.Valid[$i]) { continue }
    $corner = CellInCorner $x $y; $inCorner[$i] = $corner
    $g = $conv.Ground[$i]
    if ($g -eq 2) { continue }
    $high = $conv.Plateau[$i] -ge 0
    $x4 = $x - $CellDX; $y4 = $y - $CellDY
    if ($corner -and $x4 -ge 0 -and $y4 -ge 0 -and $x4 -lt $gN -and $y4 -lt $gN) { $n1 = Noise $vn4 $gw4 $x4 $y4; $n2 = Noise $vn42 $gw4 $x4 $y4 }
    else { $n1 = Noise $vn $gw2 $x $y; $n2 = Noise $vn2 $gw2 $x $y }
    if ($high) { $g = if ($n1 -lt 0.62) { 3 } else { 1 } }
    else { $g = if ($n1 -gt 0.72) { 3 } elseif ($n2 -gt 0.80) { 0 } else { 1 } }
    $conv.Ground[$i] = $g; $cnt[$g]++
} }
"ground: dirt $($cnt[1]), scrub $($cnt[3]), grass $($cnt[0]) cells (pavement unchanged)"
$base[3] = $th.SetByName('Autumn Grass').Start
$lat[3]  = $th.SetByName('Autumn Grass/Clear LAT').Start

# ================================================================ trees: mission 4's in the corner, sparse elsewhere
# Mission 4's trees and rocks inside the corner move with the cell shift (only where the cell is open here too), the
# converter's own in the corner are dropped. Never within 4 cells of a waypoint (except the copied ones, as in mission 4)
$nCopied = 0; $nDropped = 0
foreach ($k in @($conv.Terrain.Keys)) { $x = $k % 1000; $y = [Math]::Floor($k / 1000); if ($inCorner[$conv.Idx($x, $y)]) { $conv.Terrain.Remove($k) | Out-Null; $nDropped++ } }
foreach ($kv in $m4.Section('Terrain')) {
    $v = [int]$kv.Key; $x = $v % 1000 + $CellDX; $y = [Math]::Floor($v / 1000) + $CellDY
    if ($kv.Value -like 'OREMINE*') { continue }
    if (-not $conv.In($x, $y) -or -not $inCorner[$conv.Idx($x, $y)] -or -not (Passable $x $y)) { continue }
    $conv.Terrain[$y * 1000 + $x] = $kv.Value; $nCopied++
}
"corner trees: $nCopied from mission 4 ($nDropped converter objects dropped)"
$conv.ApplyGround(0, $base, $lat)
$nearWp = New-Object 'bool[]' ($conv.N * $conv.N)
foreach ($k in $wpCell.Keys) { $c = $wpCell[$k]; for ($x = $c[0] - 4; $x -le $c[0] + 4; $x++) { for ($y = $c[1] - 4; $y -le $c[1] + 4; $y++) { if ($conv.In($x, $y)) { $nearWp[$conv.Idx($x, $y)] = $true } } } }
$rnd = New-Object Random 2478; $nDeco = 0
for ($y = 1; $y -lt $conv.N - 1; $y++) { for ($x = 1; $x -lt $conv.N - 1; $x++) {
    if (-not (Passable $x $y) -or $nearWp[$conv.Idx($x, $y)] -or $inCorner[$conv.Idx($x, $y)]) { continue }
    $open = $true
    for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { if (($dx -or $dy) -and -not (Passable ($x + $dx) ($y + $dy))) { $open = $false } } }
    if (-not $open) { continue }
    if ($rnd.NextDouble() -lt 0.012) { $conv.Terrain[$y * 1000 + $x] = $trees[$rnd.Next($trees.Length)]; $nDeco++ }
} }
"dressing: $nDeco trees/bushes outside the corner"

$conv.WallFrames(2, [int[]]@(0, 2, 4, 6))
$conv.CheckConnectivity()
$text = $conv.WriteMap('ARKA #3: Sygnal z nieba (teren)', 'Claude (kampania ARKA; teren: Blizzard T5 Revolution + rog bazy z T6 Norad II, port: Claude)')
$conv.Log | Set-Content "$work\log.txt" -Encoding UTF8
"converter: $($conv.Log.Count) log lines; starts $($conv.Starts.Count) connected=$($conv.StartsConnected) sealed $($conv.Sealed) leaks $($conv.Leaks) failed chains $($conv.ChainFailures)"
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::GetEncoding(1252))
$ini = [Ini]::Load($Out)
$ini.Set('Map', 'Theater', 'TEMPERATE')
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; $ini.Set('Waypoints', $k, "$($c[1] * 1000 + $c[0])") }
$ini.Set('Basic', 'Name', 'ARKA #3: Sygnal z nieba (teren, Antiga Prime)')
[IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))
"written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB), Size 0,0,$($conv.W),$($conv.H)"

# ================================================================ checks: every waypoint reachable by ground from ARKA
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
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; "wp $k path $($dist[$conv.Idx($c[0], $c[1])]) cells ($($wps[$k][2]))"; if (-not $reach[$conv.Idx($c[0], $c[1])]) { "WARN wp $k ($($wps[$k][2])) not reachable from the start by ground (conservative test)"; $fail++ } }
$nReach = 0; $nOpen = 0; for ($i = 0; $i -lt $reach.Length; $i++) { if ($conv.Valid[$i] -and $conv.Visible[$i] -and ("$($conv.K[$i])" -in 'Low', 'High')) { $nOpen++; if ($reach[$i]) { $nReach++ } } }
"reach: $nReach of $nOpen open cells reachable from ARKA"
# planning map: one character per zoomed tile (the coordinates of $wps): . low, H high, ^ cliff, ~ water, # blocked,
# T tree/rock, $ crystals; lower case / x = not reachable from the ARKA by ground
$asc = New-Object Collections.Generic.List[string]
$asc.Add('     ' + (-join (0..143 | ForEach-Object { if ($_ % 10 -eq 0) { [string]([int]($_ / 10) % 10) } else { ' ' } })))
for ($ty = 0; $ty -lt 144; $ty++) {
    $s = ''
    for ($tx = 0; $tx -lt 144; $tx++) {
        $cx = 0; $cy = 0; $conv.CellAt(($tx + 0.5) * 32, ($ty + 0.5) * 32, [ref]$cx, [ref]$cy)
        if (-not $conv.In($cx, $cy)) { $s += ' '; continue }
        $i = $conv.Idx($cx, $cy); $k = "$($conv.K[$i])"
        $ch = switch ($k) { 'Low' { '.' } 'High' { 'H' } 'Cliff' { '^' } 'Water' { '~' } default { '#' } }
        if ($conv.Terrain.ContainsKey($cy * 1000 + $cx)) { $ch = 'T' }
        $o = $conv.Overlay[$cy * 512 + $cx]; if ($o -ge 27 -and $o -le 38) { $ch = '$' }
        if ($ch -in '.', 'H', '$', 'T' -and -not $reach[$i]) { $ch = if ($ch -eq '.') { 'x' } else { $ch.ToLower() } }
        if ($conv.Bridge[$i]) { $ch = 'B' }
        if (-not $conv.Used[$i] -and $k -in 'Low', 'High') {   # raw coast: land touching a water tile that no piece covers
            foreach ($d in @(@(0, -1), @(1, 0), @(0, 1), @(-1, 0))) { $j = $conv.Idx($cx + $d[0], $cy + $d[1]); if ("$($conv.K[$j])" -eq 'Water' -and $rawWater[$j]) { $ch = 'R' } }
        }
        $s += $ch
    }
    $asc.Add(('{0,3}  ' -f $ty) + $s)
}
$asc | Set-Content "$work\ascii.txt" -Encoding ASCII
"CHECKS: " + $(if ($fail) { "$fail waypoint(s) unreachable" } else { "PASS (all $($wps.Count) waypoints reachable from ARKA)" })

# ================================================================ pictures: composite tile grid for planning, cells with waypoints
$bf = New-Object Drawing.Font 'Arial', 9, ([Drawing.FontStyle]::Bold); $font = New-Object Drawing.Font 'Arial', 8
$dbg = $conv.DebugImage()
$big = New-Object Drawing.Bitmap ($dbg.Width * 2), ($dbg.Height * 2); $g = [Drawing.Graphics]::FromImage($big)
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor; $g.DrawImage($dbg, 0, 0, $big.Width, $big.Height); $dbg.Dispose()
$gp = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(90, 0, 0, 0)), 1
for ($k = 0; $k -le 144; $k += 8) {   # composite zoomed tiles (the coordinates of $wps)
    $sx = $big.Width * ($k + 2 * $conv.PadX) / (2 * $conv.W); $sy = $big.Height * ($k * 2 + 2 * $conv.PadTop) / (2 * $conv.H)
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
    # coast self-check: a 240x160 crop of the render round every leftover seam (render pixel of a cell, wiki
    # engine/triggers-and-dialogue "Podgląd misji": px = (x-y+W-1)*24 - LX*48 + 24, py = (x+y-W-1)*12 - LY*24 + 60)
    $full = [Drawing.Image]::FromFile("$work\${bn}_full.png")
    $spots = New-Object Collections.Generic.List[object]
    foreach ($i in $seamCells) {
        $x = $i % $conv.N; $y = [Math]::Floor($i / $conv.N)
        $px = ($x - $y + $conv.W - 1) * 24 - $conv.PadX * 48 + 24; $py = ($x + $y - $conv.W - 1) * 12 - $conv.PadTop * 24 + 60
        if (@($spots | Where-Object { [Math]::Abs($_[0] - $px) -lt 120 -and [Math]::Abs($_[1] - $py) -lt 80 }).Count) { continue }
        $spots.Add(@($px, $py, $x, $y))
    }
    if ($spots.Count) {
        $cols = [Math]::Min(4, $spots.Count); $rows = [Math]::Ceiling($spots.Count / $cols)
        $sheet = New-Object Drawing.Bitmap ($cols * 240), ($rows * 160); $g = [Drawing.Graphics]::FromImage($sheet)
        for ($k = 0; $k -lt $spots.Count; $k++) {
            $s = $spots[$k]; $dst = New-Object Drawing.Rectangle (($k % $cols) * 240), ([Math]::Floor($k / $cols) * 160), 240, 160
            $g.DrawImage($full, $dst, (New-Object Drawing.Rectangle ($s[0] - 120), ($s[1] - 80), 240, 160), [Drawing.GraphicsUnit]::Pixel)
            $g.DrawString("$($s[2]),$($s[3])", $font, [Drawing.Brushes]::Yellow, $dst.X + 2, $dst.Y + 2)
        }
        $g.Dispose(); $sheet.Save("$work\coast.png"); $sheet.Dispose()
    }
    $full.Dispose()
    "coast check: $($spots.Count) places -> $(if ($spots.Count) { "$work\coast.png" } else { 'none' })"
}
