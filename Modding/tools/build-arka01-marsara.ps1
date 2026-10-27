# Terrain of ARKA mission 1 "Obcy piasek" (Mar Sara, 2499): the StarCraft Terran campaign map T2 "Backwater Station"
# (read from the user's StarCraft: Remastered CASC, SD/campaign/Terran/Terran02) scaled 2x and converted to a DTA
# DESERT map with the SC map converter (ScToDta). Writes Maps\Custom\arka01_marsara.map (viewable as a skirmish
# "Custom Map") and the mission waypoints 10-45, which are the contract with build-arka01-mission.ps1.
#
#   powershell -NoProfile -File .\build-arka01-marsara.ps1            # build + checks + preview + render (~1-2 min)
#   powershell -NoProfile -File .\build-arka01-marsara.ps1 -NoRender  # no CNCMaps render
#
# Work files: %TEMP%\arka01-terrain\ (sc.png, sc_grid.png, cells.png, reach.png, compare_sc.png, waypoints.png, log.txt).
# Wiki: Modding/wiki/missions/arka-01-marsara.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$Out = "",
    [int]$Zoom = 2,
    [switch]$NoRender
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Out) { $Out = "$game\Maps\Custom\arka01_marsara.map" }
$work = "$env:TEMP\arka01-terrain"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScMap.cs", "$tools\TsMap.cs", "$tools\ScToDta.cs" -ReferencedAssemblies System.Drawing

# ================================================================ StarCraft side: T2 "Backwater Station", badlands, 64x64
$casc = New-Object Casc $StarCraft
$chk  = New-Object Chk (, $casc.ReadFile('SD/campaign/Terran/Terran02/staredit/scenario.chk'))
$ts   = New-Object ScTileset $casc, ([Chk]::EraNames[$chk.Era])
$ter  = New-Object ScTerrain $chk, $ts
"SC map: $($chk.Width)x$($chk.Height) $([Chk]::EraNames[$chk.Era]), zoom $Zoom"
$sc = $ter.RenderNatural(4); $sc.Save("$work\sc.png"); $sc.Dispose()

# mission objects of the SC map that the converter would turn into resources: drop the two vespene geysers
# (they become Tiberium trees, and nobody on Mar Sara may know Tiberium yet; wiki plans/campaign-arka)
$chk.Units.RemoveAll([Predicate[ScUnit]] { param($u) $u.Id -eq 188 }) | Out-Null
# extra crystal field (mineral fields 176-178 become blue gems) by the MCV in the south: "krystaliczne pole zloz"
foreach ($m in @(@(44, 61), @(46, 61), @(48, 61), @(45, 62), @(47, 62))) {
    $u = New-Object ScUnit; $u.Id = 176; $u.Owner = 11; $u.X = $m[0] * 32 + 32; $u.Y = $m[1] * 32 + 16; $chk.Units.Add($u)
}

# scale the SC terrain by $Zoom (nearest neighbour on the 8 px minitile grid): a 64x64 SC map is only 32x64 DTA
# cells, too small for a mission with a crash site, a colony and a Zerg nest
if ($Zoom -gt 1) {
    $w0 = $ter.W; $h0 = $ter.H
    $fl = New-Object 'int[]' ($w0 * $h0 * $Zoom * $Zoom); $rgb = New-Object 'int[]' $fl.Length
    for ($y = 0; $y -lt $h0 * $Zoom; $y++) { for ($x = 0; $x -lt $w0 * $Zoom; $x++) {
        $src = [Math]::Floor($y / $Zoom) * $w0 + [Math]::Floor($x / $Zoom)
        $fl[$y * $w0 * $Zoom + $x] = $ter.Flags[$src]; $rgb[$y * $w0 * $Zoom + $x] = $ter.Rgb[$src]
    } }
    $ter.W = $w0 * $Zoom; $ter.H = $h0 * $Zoom; $ter.Flags = $fl; $ter.Rgb = $rgb
    $chk.Width *= $Zoom; $chk.Height *= $Zoom
    foreach ($u in $chk.Units) { $u.X *= $Zoom; $u.Y *= $Zoom }
    foreach ($s in $chk.Sprites) { $s.X *= $Zoom; $s.Y *= $Zoom }
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
# desert decoration: boulders, small rocks, a few cacti and dead trees (no green trees on Mar Sara)
$deco = [string[]]@('BR1', 'BR2', 'BR3', 'BR4', 'BR5', 'BR6', 'BR7', 'BR8', 'BR9', 'BR4', 'BR5', 'BR1',
    'SROCK01', 'SROCK02', 'SROCK03', 'SROCK04', 'SROCK05', 'SROCK06', 'SROCK07', 'CACTUS02', 'CACTUS05', 'BT08', 'BT14')
$rocks = $th.SetByName('Rocks').Start
$conv.Obstacles($deco, [int[]]@($rocks, ($rocks + 1), ($rocks + 2)))
# the converter turns an obstacle at the map centre into the ruined Temple of Nod (Lost Temple); not on Mar Sara
$tmpl = @($conv.Structures | Where-Object { $_ -match ',DBTMPL,' })
foreach ($s in $tmpl) { $conv.Structures.Remove($s) | Out-Null; "removed centre temple: $s" }
$conv.Cleanup()
$conv.RepairDecorations()
$conv.PaintGround()
# ground slots: 0 = clear sand (low ground), 1 = light sand (plateaus), 2 = pavement, 3 = rough scrub
# plateau cells the converter painted "grass" (SC yellow grass on high ground) become rough scrub
for ($i = 0; $i -lt $conv.Ground.Length; $i++) { if ($conv.Plateau[$i] -ge 0 -and $conv.Ground[$i] -eq 0) { $conv.Ground[$i] = 3 } }
$base = [int[]]@(0, $th.SetByName('Light Sand').Start, $th.SetByName('Pavement LAT tile').Start, $th.SetByName('~~~Rough LAT tile').Start)
$lat  = [int[]]@(0, $th.SetByName('Light/Dark Sand LAT').Start, $th.SetByName('Clear/Pavement LAT').Start, $th.SetByName('~~~Clear/Rough LAT').Start)
$conv.ApplyGround(0, $base, $lat)

# ================================================================ mission waypoints (contract 10-45 with build-arka01-mission.ps1)
# given in ORIGINAL SC tile coordinates (64x64 grid of sc_grid.png); each is moved to the nearest passable cell
$wps = [ordered]@{
    '10' = @(6, 50, 'ARKA wreck (crater, SC player CC)')
    '11' = @(10, 55, 'player start army')
    '12' = @(3, 50, 'cracked core of the ARKA (secret)')
    '13' = @(44, 58, 'damaged MCV (south)')
    '14' = @(17, 34, 'survivors 1 (west strip, first contact)')
    '15' = @(36, 30, 'survivors 2 (central valley)')
    '16' = @(57, 41, 'survivors 3 (east plateau, by the crystals)')
    '17' = @(7, 5, 'Mar Sara colony: Command Center')
    '18' = @(12, 14, 'colony: Raynor and the Marines')
    '19' = @(55, 5, 'Zerg nest: Hatchery')
    '20' = @(51, 10, 'Zerg wave muster (nest)')
    '21' = @(42, 30, 'route: central valley')
    '22' = @(22, 33, 'route: west strip')
    '23' = @(28, 7, 'Zerg colony attack muster (north plateau)')
    '24' = @(24, 31, 'zergling ambush on survivors 1')
    '25' = @(62, 1, 'mutalisk entry (NE corner)')
    '26' = @(62, 62, 'Protoss Observer (SE edge)')
    '27' = @(12, 44, 'wreck: Allied barracks')
    '28' = @(4, 45, 'wreck: Allied power plant')
    '29' = @(46, 51, 'zerglings by the MCV')
    '30' = @(50, 4, 'Zerg: Spawning Pool')
    '31' = @(44, 8, 'Zerg: Creep Colony 1')
    '32' = @(48, 15, 'Zerg: Creep Colony 2')
    '33' = @(58, 12, 'Zerg: Creep Colony 3')
    '34' = @(45, 18, 'Zerg: Sunken Colony 1 (south approach)')
    '35' = @(40, 11, 'Zerg: Sunken Colony 2 (west approach)')
    '36' = @(20, 4, 'colony: bunker north')
    '37' = @(20, 11, 'colony: bunker east')
    '38' = @(11, 21, 'colony: bunker south')
    '39' = @(5, 10, 'colony: Academy')
    '40' = @(15, 9, 'colony: Barracks')
    '41' = @(3, 3, 'colony: Supply Depots')
    '42' = @(30, 50, 'Zerg raid muster (south plateau)')
    '43' = @(8, 40, 'crash site north edge (defence line)')
    '44' = @(56, 40, 'east crystal field')
    '45' = @(33, 22, 'route: north ravine exit')
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

# ================================================================ desert dressing (the SC badlands doodads alone leave the map bare)
# boulders/rocks/cacti as terrain objects at the cliff feet and sparsely on open ground, pebble tiles in the clear sand;
# never within 5 cells of a waypoint (bases, units, routes) and only on cells whose 8 neighbours are open ground,
# so a rock never closes a ramp or a 1-cell gap
$rnd = New-Object Random 2499
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
$text = $conv.WriteMap('ARKA #1: Obcy piasek (teren)', 'Claude (kampania ARKA; teren: Blizzard T2 Backwater Station, port: Claude)')
$conv.Log | Set-Content "$work\log.txt" -Encoding UTF8
"converter: $($conv.Log.Count) log lines; starts $($conv.Starts.Count) connected=$($conv.StartsConnected) sealed $($conv.Sealed) leaks $($conv.Leaks) failed chains $($conv.ChainFailures)"
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::GetEncoding(1252))
$ini = [Ini]::Load($Out)
$ini.Set('Map', 'Theater', 'DESERT')
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; $ini.Set('Waypoints', $k, "$($c[1] * 1000 + $c[0])") }
# skirmish starts 0-3 come from the SC start locations; 98 = HomeCell of the converter
$ini.Set('Basic', 'Name', 'ARKA #1: Obcy piasek (teren, Mar Sara)')
[IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))
"written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB), Size 0,0,$($conv.W),$($conv.H)"

# ================================================================ checks: every waypoint reachable by ground from the crash site
$reach = New-Object 'bool[]' ($conv.N * $conv.N)
$q = New-Object 'Collections.Generic.Queue[int]'
$s0 = $wpCell['11']; $reach[$conv.Idx($s0[0], $s0[1])] = $true; $q.Enqueue($conv.Idx($s0[0], $s0[1]))
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
        if ($pass) { $reach[$n] = $true; $q.Enqueue($n) }
    }
}
$fail = 0
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; if (-not $reach[$conv.Idx($c[0], $c[1])]) { "WARN wp $k ($($wps[$k][2])) not reachable from the start by ground (conservative test)"; $fail++ } }
"CHECKS: " + $(if ($fail) { "$fail waypoint(s) unreachable" } else { 'PASS (all 36 waypoints reachable from the crash site)' })

# ================================================================ pictures: SC grid for planning, waypoints on the cell map
$g0 = [Drawing.Image]::FromFile("$work\sc.png")   # 4 px per minitile = 16 px per SC tile (64 tiles = 1024 px)
$grid = New-Object Drawing.Bitmap 1024, 1024; $g = [Drawing.Graphics]::FromImage($grid); $g.DrawImage($g0, 0, 0, 1024, 1024); $g0.Dispose()
$pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(110, 255, 255, 255)), 1; $font = New-Object Drawing.Font 'Arial', 8
for ($k = 0; $k -le 64; $k += 4) { $g.DrawLine($pen, $k * 16, 0, $k * 16, 1024); $g.DrawLine($pen, 0, $k * 16, 1024, $k * 16); $g.DrawString("$k", $font, [Drawing.Brushes]::White, $k * 16 + 1, 1); $g.DrawString("$k", $font, [Drawing.Brushes]::White, 1, $k * 16 + 1) }
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
