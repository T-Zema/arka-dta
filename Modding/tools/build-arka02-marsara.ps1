# Terrain of ARKA mission 2 "Ewakuacja" (Mar Sara, 2499): the StarCraft Terran campaign map T3 "Desperate Alliance"
# (read from the user's StarCraft: Remastered CASC, SD/campaign/Terran/Terran03) scaled 1.5x and converted to a DTA
# DESERT map with the SC map converter (ScToDta). Writes Maps\Custom\arka02_marsara.map (viewable as a skirmish
# "Custom Map") and the mission waypoints 10-55, which are the contract with build-arka02-mission.ps1.
# Mission 1 used T2 "Backwater Station" (build-arka01-marsara.ps1); T3 is the SC survival-until-evacuation mission,
# which is what "Ewakuacja" is about.
#
#   powershell -NoProfile -File .\build-arka02-marsara.ps1            # build + checks + preview + render (~2 min)
#   powershell -NoProfile -File .\build-arka02-marsara.ps1 -NoRender  # no CNCMaps render
#
# Work files: %TEMP%\arka02-terrain\ (sc.png, sc_grid.png, cells.png, reach.png, compare_sc.png, waypoints.png, log.txt).
# Wiki: Modding/wiki/missions/arka-02-ewakuacja.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$Out = "",
    [double]$Zoom = 1.5,
    [switch]$NoRender
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Out) { $Out = "$game\Maps\Custom\arka02_marsara.map" }
$work = "$env:TEMP\arka02-terrain"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScMap.cs", "$tools\TsMap.cs", "$tools\ScToDta.cs" -ReferencedAssemblies System.Drawing

# ================================================================ StarCraft side: T3 "Desperate Alliance", badlands, 96x96
$casc = New-Object Casc $StarCraft
$chk  = New-Object Chk (, $casc.ReadFile('SD/campaign/Terran/Terran03/staredit/scenario.chk'))
$ts   = New-Object ScTileset $casc, ([Chk]::EraNames[$chk.Era])
$ter  = New-Object ScTerrain $chk, $ts
"SC map: $($chk.Width)x$($chk.Height) $([Chk]::EraNames[$chk.Era]), zoom $Zoom"
$sc = $ter.RenderNatural(4); $sc.Save("$work\sc.png"); $sc.Dispose()

# drop the vespene geysers (the converter turns them into Tiberium trees; nobody on Mar Sara may know Tiberium yet)
$chk.Units.RemoveAll([Predicate[ScUnit]] { param($u) $u.Id -eq 188 }) | Out-Null

# scale the SC terrain by $Zoom (nearest neighbour on the 8 px minitile grid): 96x96 SC tiles at 1.5x give a map a
# little larger than mission 1 (64x64 at 2x); 2x would make the walk to the city and back too long
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

# ================================================================ DTA side: DESERT theater
$mixes  = New-Object MixSet "$game\MIX"
$th     = New-Object Theater "$game\INI\Desert.ini", "des", $mixes
$wae    = "$game\Map Editor\Editor\Config\ConnectedTileDrawer.ini"
$cliffs = New-Object ConnectedSet $wae, "DesertCliffSet", $th
$shores = New-Object ConnectedSet $wae, "DesertWaterCliffSet", $th
"cliff pieces: $($cliffs.Pieces.Count), water cliff pieces: $($shores.Pieces.Count)"

$conv = New-Object ScToDta $chk, $ter, $th
$conv.Classify()
$conv.Resources()
$conv.Cliffs($cliffs)
$conv.Shores($shores, $true)
$conv.SettleWater()
$conv.FillWater($th.SetByName('Animated Water'), $th.SetByName('Water').Start)
$deco = [string[]]@('BR1', 'BR2', 'BR3', 'BR4', 'BR5', 'BR6', 'BR7', 'BR8', 'BR9', 'BR4', 'BR5', 'BR1',
    'SROCK01', 'SROCK02', 'SROCK03', 'SROCK04', 'SROCK05', 'SROCK06', 'SROCK07', 'CACTUS02', 'CACTUS05', 'BT08', 'BT14')
$rocks = $th.SetByName('Rocks').Start
$conv.Obstacles($deco, [int[]]@($rocks, ($rocks + 1), ($rocks + 2)))
$tmpl = @($conv.Structures | Where-Object { $_ -match ',DBTMPL,' })
foreach ($s in $tmpl) { $conv.Structures.Remove($s) | Out-Null; "removed centre temple: $s" }
$conv.Cleanup()
$conv.RepairDecorations()
$conv.PaintGround()
# ground slots: 0 = clear sand (low ground), 1 = light sand (plateaus), 2 = pavement (SC asphalt roads), 3 = rough scrub
for ($i = 0; $i -lt $conv.Ground.Length; $i++) { if ($conv.Plateau[$i] -ge 0 -and $conv.Ground[$i] -eq 0) { $conv.Ground[$i] = 3 } }
$base = [int[]]@(0, $th.SetByName('Light Sand').Start, $th.SetByName('Pavement LAT tile').Start, $th.SetByName('~~~Rough LAT tile').Start)
$lat  = [int[]]@(0, $th.SetByName('Light/Dark Sand LAT').Start, $th.SetByName('Clear/Pavement LAT').Start, $th.SetByName('~~~Clear/Rough LAT').Start)
# the grey concrete platforms of the SC base (one of them is the landing pad of the Sons of Korhal) become pavement
$nPave = 0
for ($i = 0; $i -lt $conv.Ground.Length; $i++) {
    if ($conv.Plateau[$i] -lt 0 -or "$($conv.K[$i])" -ne 'High') { continue }
    $c = [Drawing.Color]::FromArgb($conv.Rgb[$i])
    if ([Math]::Abs($c.R - $c.G) -lt 14 -and [Math]::Abs($c.G - $c.B) -lt 14 -and $c.R -gt 40) { $conv.Ground[$i] = 2; $nPave++ }
}
"platform pavement: $nPave cells"

# ================================================================ mission waypoints (contract 10-55 with build-arka02-mission.ps1)
# given in ORIGINAL SC tile coordinates (96x96 grid of sc_grid.png); each is moved to the nearest passable cell
$wps = [ordered]@{
    '10' = @(9, 86, 'ARKA wreck (SC player base)')
    '11' = @(22, 88, 'player start army')
    '12' = @(3, 81, 'ARKA power plant 1')
    '13' = @(16, 82, 'ARKA power plant 2')
    '14' = @(3, 92, 'ARKA power plant 3')
    '15' = @(17, 93, 'ARKA power plant 4')
    '16' = @(27, 90, 'Allied construction yard')
    '17' = @(31, 86, 'Allied barracks')
    '18' = @(21, 80, 'Allied refinery (crystals)')
    '19' = @(47, 88, 'landing zone of the Sons of Korhal (platform)')
    '20' = @(44, 20, 'Zerg wave muster (nest)')
    '21' = @(42, 22, 'Zerg nest: Hatchery')
    '22' = @(40, 17, 'Zerg nest: Spawning Pool')
    '23' = @(49, 16, 'Zerg nest: Hydralisk Den')
    '24' = @(47, 25, 'Zerg nest: Spire')
    '25' = @(32, 21, 'Zerg nest: Sunken Colony W')
    '26' = @(52, 22, 'Zerg nest: Sunken Colony E')
    '27' = @(44, 28, 'Zerg nest: Sunken Colony S')
    '28' = @(37, 12, 'Zerg nest: Creep Colony N')
    '29' = @(55, 14, 'Zerg nest: Creep Colony NE')
    '30' = @(88, 70, 'Mar Sara City: infested Command Center')
    '31' = @(84, 75, 'city: in front of the Command Center (Raynor comes out)')
    '32' = @(82, 85, 'city: shelter 1')
    '33' = @(92, 90, 'city: shelter 2')
    '34' = @(93, 64, 'city: shelter 3')
    '35' = @(78, 67, 'city gate')
    '36' = @(87, 80, 'city building')
    '37' = @(91, 76, 'city building')
    '38' = @(85, 91, 'city building')
    '39' = @(94, 82, 'city building')
    '40' = @(24, 57, 'road: west ford (pack 1)')
    '41' = @(40, 46, 'road: central plain (pack 2)')
    '42' = @(62, 58, 'road: east plain (pack 3)')
    '43' = @(73, 63, 'road: before the city (pack 4)')
    '44' = @(30, 2, 'wave entry: north edge')
    '45' = @(14, 66, 'base: north defence line')
    '46' = @(1, 38, 'wave entry: west edge')
    '47' = @(95, 44, 'wave entry: east edge')
    '48' = @(95, 28, 'Confederate entry (east edge)')
    '49' = @(60, 40, 'Protoss fleet on the radar (centre)')
    '50' = @(95, 2, 'Mutalisk entry (NE corner)')
    '51' = @(56, 76, 'road: south ford')
    '52' = @(90, 68, 'city: Zerg in the town')
    '53' = @(33, 76, 'base: east approach')
    '54' = @(53, 81, 'Sons of Korhal guard post (by the landing zone)')
    '55' = @(1, 71, 'Confederate entry (west edge, by the base)')
}
# passable cell test from the converter's arrays (ground, not cliff/water/rock/tree)
function Passable($x, $y) {
    if (-not $conv.In($x, $y)) { return $false }
    $i = $conv.Idx($x, $y)
    if (-not $conv.Visible[$i]) { return $false }
    $k = "$($conv.K[$i])"; if ($k -ne 'Low' -and $k -ne 'High') { return $false }
    if ($conv.Used[$i] -and $conv.Decor.Contains($i)) { return $false }
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

# Mar Sara City on the SE plateau: paved squares round the Command Center, the shelters and the city buildings
foreach ($k in '30', '31', '32', '33', '34', '36', '37', '38', '39', '52') {
    $c = $wpCell[$k]; $r = if ($k -eq '30') { 5 } else { 3 }
    for ($x = $c[0] - $r; $x -le $c[0] + $r; $x++) { for ($y = $c[1] - $r; $y -le $c[1] + $r; $y++) {
        if (($x - $c[0]) * ($x - $c[0]) + ($y - $c[1]) * ($y - $c[1]) -gt $r * $r + 1 -or -not $conv.In($x, $y)) { continue }
        $i = $conv.Idx($x, $y); if ("$($conv.K[$i])" -eq 'High' -or "$($conv.K[$i])" -eq 'Low') { $conv.Ground[$i] = 2 }
    } }
}
$conv.ApplyGround(0, $base, $lat)

# ================================================================ desert dressing (the SC badlands doodads alone leave the map bare)
# boulders/rocks/cacti as terrain objects at the cliff feet and sparsely on open ground, pebble tiles in the clear sand;
# never within 5 cells of a waypoint (bases, units, routes) and only on cells whose 8 neighbours are open ground,
# so a rock never closes a ramp or a 1-cell gap
$rnd = New-Object Random 2500
$pebbles = $th.SetByName('Pebbles').Start
$nearWp = New-Object 'bool[]' ($conv.N * $conv.N)
foreach ($c in $wpCell.Values) { for ($x = $c[0] - 5; $x -le $c[0] + 5; $x++) { for ($y = $c[1] - 5; $y -le $c[1] + 5; $y++) { if ($conv.In($x, $y)) { $nearWp[$conv.Idx($x, $y)] = $true } } } }
$rocksBig = [string[]]@('BR1', 'BR2', 'BR3', 'BR4', 'BR5', 'BR6', 'BR7', 'BR8', 'BR9')
$rocksSmall = [string[]]@('SROCK01', 'SROCK02', 'SROCK03', 'SROCK04', 'SROCK05', 'SROCK06', 'SROCK07')
$plants = [string[]]@('CACTUS00', 'CACTUS02', 'CACTUS03', 'CACTUS05', 'CACTUS06', 'BT08', 'BT10', 'BT14')
$nDeco = 0; $nPeb = 0
for ($y = 1; $y -lt $conv.N - 1; $y++) { for ($x = 1; $x -lt $conv.N - 1; $x++) {
    if (-not (Passable $x $y) -or $nearWp[$conv.Idx($x, $y)]) { continue }
    $open = $true; $cliffNear = $false
    for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { if (($dx -or $dy) -and -not (Passable ($x + $dx) ($y + $dy))) { $open = $false } } }
    for ($dx = -2; $dx -le 2 -and -not $cliffNear; $dx++) { for ($dy = -2; $dy -le 2; $dy++) { $n = $conv.Idx($x + $dx, $y + $dy); if ($conv.In($x + $dx, $y + $dy) -and "$($conv.K[$n])" -eq 'Cliff') { $cliffNear = $true; break } } }
    $i = $conv.Idx($x, $y); $high = $conv.Plateau[$i] -ge 0
    $p = $rnd.NextDouble()
    if ($open) {
        $chance = if ($cliffNear) { 0.05 } elseif ($high) { 0.010 } else { 0.007 }
        if ($p -lt $chance) {
            $r2 = $rnd.NextDouble()
            $obj = if ($r2 -lt 0.45) { $rocksBig[$rnd.Next($rocksBig.Length)] } elseif ($r2 -lt 0.85) { $rocksSmall[$rnd.Next($rocksSmall.Length)] } else { $plants[$rnd.Next($plants.Length)] }
            $conv.Terrain[$y * 1000 + $x] = $obj; $nDeco++; continue
        }
    }
    # pebbles only on plain clear sand (tile 0), so LAT transitions stay intact
    if ($conv.Tile[$i] -eq 0 -and -not $high -and $rnd.NextDouble() -lt 0.04) { $conv.Tile[$i] = $pebbles + $rnd.Next(3); $conv.Sub[$i] = 0; $nPeb++ }
} }
"dressing: $nDeco terrain objects, $nPeb pebble tiles"

$conv.WallFrames(2, [int[]]@(0, 2, 4, 6))
$conv.CheckConnectivity()
$cmp = $conv.CompareWithSc(); $cmp.Save("$work\compare_sc.png"); $cmp.Dispose()
$text = $conv.WriteMap('ARKA #2: Ewakuacja (teren)', 'Claude (kampania ARKA; teren: Blizzard T3 Desperate Alliance, port: Claude)')
$conv.Log | Set-Content "$work\log.txt" -Encoding UTF8
"converter: $($conv.Log.Count) log lines; starts $($conv.Starts.Count) connected=$($conv.StartsConnected) sealed $($conv.Sealed) leaks $($conv.Leaks) failed chains $($conv.ChainFailures)"
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::GetEncoding(1252))
$ini = [Ini]::Load($Out)
$ini.Set('Map', 'Theater', 'DESERT')
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; $ini.Set('Waypoints', $k, "$($c[1] * 1000 + $c[0])") }
# skirmish starts 0-3 come from the SC start locations; 98 = HomeCell of the converter
$ini.Set('Basic', 'Name', 'ARKA #2: Ewakuacja (teren, Mar Sara)')
[IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))
"written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB), Size 0,0,$($conv.W),$($conv.H)"

# ================================================================ checks: every waypoint reachable by ground from the ARKA wreck
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
        $pass = ($k -eq 'Low' -or $k -eq 'High') -and -not ($conv.Used[$n] -and -not ($conv.Tile[$n] -ge 0 -and $conv.GroundTiles.Contains($conv.Tile[$n]))) -and -not $conv.Terrain.ContainsKey($ny * 1000 + $nx)
        # cliff pieces mark their cells Used; their passable cells are not distinguished here, so Used = blocked (conservative)
        if ($conv.Used[$n]) { $pass = $false }
        if ($pass) { $reach[$n] = $true; $dist[$n] = $dist[$c] + 1; $q.Enqueue($n) }
    }
}
$fail = 0
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; "wp $k path $($dist[$conv.Idx($c[0], $c[1])]) cells ($($wps[$k][2]))"; if (-not $reach[$conv.Idx($c[0], $c[1])]) { "WARN wp $k ($($wps[$k][2])) not reachable from the start by ground (conservative test)"; $fail++ } }
"CHECKS: " + $(if ($fail) { "$fail waypoint(s) unreachable" } else { "PASS (all $($wps.Count) waypoints reachable from the ARKA wreck)" })

# ================================================================ pictures: SC grid for planning, waypoints on the cell map
$g0 = [Drawing.Image]::FromFile("$work\sc.png")   # 4 px per minitile = 16 px per SC tile (96 tiles = 1536 px)
$grid = New-Object Drawing.Bitmap 1536, 1536; $g = [Drawing.Graphics]::FromImage($grid); $g.DrawImage($g0, 0, 0, 1536, 1536); $g0.Dispose()
$pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(110, 255, 255, 255)), 1; $font = New-Object Drawing.Font 'Arial', 8
for ($k = 0; $k -le 96; $k += 4) { $g.DrawLine($pen, $k * 16, 0, $k * 16, 1536); $g.DrawLine($pen, 0, $k * 16, 1536, $k * 16); $g.DrawString("$k", $font, [Drawing.Brushes]::White, $k * 16 + 1, 1); $g.DrawString("$k", $font, [Drawing.Brushes]::White, 1, $k * 16 + 1) }
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
# the same cell map, 2x, with the SC tile grid every 4 tiles: where a waypoint in SC tiles lands on the DTA terrain
$big = New-Object Drawing.Bitmap ($dbg.Width * 2), ($dbg.Height * 2); $g = [Drawing.Graphics]::FromImage($big)
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor; $g.DrawImage($dbg, 0, 0, $big.Width, $big.Height); $dbg.Dispose()
$gp = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(90, 0, 0, 0)), 1
for ($k = 0; $k -le 96; $k += 4) {
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
    $base = [IO.Path]::GetFileNameWithoutExtension($Out)
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$Out`" -o ${base}_full -d `"$work`" -p -T -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "CNCMaps renderer timed out (see $work\render.log)" }
    $full = [Drawing.Image]::FromFile("$work\${base}_full.png")
    $h = [int]($full.Height * 800 / $full.Width)
    $thumb = New-Object Drawing.Bitmap 800, $h
    $g = [Drawing.Graphics]::FromImage($thumb); $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($full, 0, 0, 800, $h); $g.Dispose(); $full.Dispose()
    $thumb.Save([IO.Path]::ChangeExtension($Out, '.png'), [Drawing.Imaging.ImageFormat]::Png)
    $ini = [Ini]::Load($Out)
    [MapPreview]::Set($ini, $thumb, 400); $thumb.Dispose()
    [IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))
    "render: $work\${base}_full.png, preview $([IO.Path]::ChangeExtension($Out, '.png'))"
}
