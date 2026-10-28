# Terrain of ARKA mission 4 "Zielony krysztal" (Antiga Prime, 2499): the StarCraft Terran campaign map T6 "Norad II"
# (read from the user's StarCraft: Remastered CASC, SD/campaign/Terran/Terran06) scaled 1.5x and converted to a DTA
# TEMPERATE map with the SC map converter (ScToDta). In StarCraft this is the very mission of the plan: Duke's flagship
# Norad II crashed on Antiga Prime inside Zerg territory and Raynor breaks through to it. Antiga Prime is not Mar Sara:
# mudflats, low mesas and scrub (StarCraft lore), so temperate ground instead of the desert of missions 1-2.
# Writes Maps\Custom\arka04_antiga.map (viewable as a skirmish "Custom Map") and the mission waypoints 10-62, which are
# the contract with build-arka04-mission.ps1.
#
#   powershell -NoProfile -File .\build-arka04-antiga.ps1            # build + checks + preview + render (~2 min)
#   powershell -NoProfile -File .\build-arka04-antiga.ps1 -NoRender  # no CNCMaps render
#
# Work files: %TEMP%\arka04-terrain\ (sc.png, sc_grid.png, grid.png, reach.png, compare_sc.png, waypoints.png, log.txt).
# Wiki: Modding/wiki/missions/arka-04-zielony-krysztal.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$Out = "",
    [double]$Zoom = 1.5,
    [switch]$NoRender
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Out) { $Out = "$game\Maps\Custom\arka04_antiga.map" }
$work = "$env:TEMP\arka04-terrain"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScMap.cs", "$tools\TsMap.cs", "$tools\ScToDta.cs" -ReferencedAssemblies System.Drawing

# ================================================================ StarCraft side: T6 "Norad II", badlands, 96x96
$casc = New-Object Casc $StarCraft
$chk  = New-Object Chk (, $casc.ReadFile('SD/campaign/Terran/Terran06/staredit/scenario.chk'))
$ts   = New-Object ScTileset $casc, ([Chk]::EraNames[$chk.Era])
$ter  = New-Object ScTerrain $chk, $ts
"SC map: $($chk.Width)x$($chk.Height) $([Chk]::EraNames[$chk.Era]), zoom $Zoom"
$sc = $ter.RenderNatural(4); $sc.Save("$work\sc.png"); $sc.Dispose()

# drop the vespene geysers (the converter turns them into Tiberium trees; nobody here may know Tiberium yet)
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

# ================================================================ DTA side: TEMPERATE theater (as convert-scmap.ps1)
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
# ground slots (ScToDta.Ground): 0 = grass, 1 = dirt (the mudflats), 2 = pavement, 3 = tall grass (the scrub)
$base = [int[]]@(0, $th.SetByName('Dirt LAT').Start, $th.SetByName('Pavement LAT').Start, $th.SetByName('Tall Grass').Start)
$lat  = [int[]]@(0, $th.SetByName('Clear/Dirt LAT').Start, $th.SetByName('Clear/Pavement LAT').Start, $th.SetByName('Tall/Short Grass LAT').Start)

# ================================================================ mission waypoints (contract 10-62 with build-arka04-mission.ps1)
# ORIGINAL SC tile coordinates (96x96 grid of sc_grid.png); each is moved to the nearest passable cell
$wps = [ordered]@{
    '10' = @(13, 77, 'ARKA (SW base; the SC Confederate base)')
    '11' = @(24, 86, 'player start army')
    '12' = @(18, 81, 'Einstein''s laboratory')
    '13' = @(22, 76, 'Allied construction yard')
    '14' = @(27, 83, 'Allied barracks')
    '15' = @(9, 85, 'Allied refinery (base crystals by the west edge)')
    '16' = @(19, 89, 'Allied war factory')
    '17' = @(8, 72, 'power plant 1')
    '18' = @(12, 71, 'power plant 2')
    '19' = @(28, 77, 'second MCV / helipad')
    '20' = @(13, 37, 'expansion NW: crystal field')
    '21' = @(33, 29, 'expansion centre: crystal field of the Lair nest')
    '22' = @(33, 36, 'Lair nest: Lair')
    '23' = @(28, 33, 'Lair nest: Spawning Pool')
    '24' = @(38, 33, 'Lair nest: Hydralisk Den')
    '25' = @(26, 41, 'Lair nest: Evolution Chamber')
    '26' = @(29, 45, 'Lair nest: Spire')
    '27' = @(41, 45, 'Lair nest: Sunken Colony S')
    '28' = @(64, 5, 'Hive nest: Hive')
    '29' = @(60, 9, 'Hive nest: Spawning Pool')
    '30' = @(62, 13, 'Hive nest: Hydralisk Den')
    '31' = @(70, 9, 'Hive nest: Spire')
    '32' = @(57, 6, 'Hive nest: Sunken Colony W')
    '33' = @(59, 13, 'Hive nest: Sunken Colony S')
    '34' = @(72, 70, 'Norad II (crashed battlecruiser)')
    '35' = @(70, 67, 'Duke and the Norad II crew')
    '36' = @(72, 65, 'Norad II: bunker N')
    '37' = @(76, 69, 'Norad II: bunker E')
    '38' = @(67, 71, 'Norad II basin (the player arrives)')
    '39' = @(86, 19, 'expansion NE: Stickler Woods (crystals that grow back)')
    '40' = @(88, 8, 'NE nest: the green-crystal Zerg (secret)')
    '41' = @(71, 3, 'expansion N: crystal field of the Hive')
    '42' = @(1, 52, 'wave entry: west edge')
    '43' = @(20, 1, 'wave entry: north-west edge')
    '44' = @(95, 45, 'wave entry: east edge')
    '45' = @(95, 76, 'wave entry: south-east edge (the SE corner valley below it is closed)')
    '46' = @(40, 52, 'centre plain (muster)')
    '47' = @(14, 64, 'base: north defence line')
    '48' = @(36, 84, 'base: east approach')
    '49' = @(58, 74, 'Norad II: Zerg pack W')
    '50' = @(70, 56, 'Norad II: Zerg pack N')
    '51' = @(68, 84, 'Norad II: Zerg pack S')
    '52' = @(59, 79, 'colony field: Sunken S')
    '53' = @(51, 72, 'colony field: Sunken W')
    '54' = @(70, 84, 'colony field: Sunken SE')
    '55' = @(56, 64, 'colony field: Spore NW')
    '56' = @(63, 78, 'colony field: Spore S')
    '57' = @(71, 53, 'colony field: Sunken N')
    '58' = @(78, 52, 'colony field: Sunken NE')
    '59' = @(60, 1, 'final wave entry (Mutalisks, Guardians): north edge')
    '60' = @(36, 40, 'Lair nest: guard pack')
    '61' = @(13, 45, 'expansion NW: Zergling guard')
    '62' = @(58, 18, 'Hive nest: guard pack')
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

# ================================================================ resources: a modest home field, rich expansions, Stickler Woods
# The mission is about mining and expanding (user 2026-10-27), so the field by the base gets thin crystals (stage 3-5
# instead of 9-11) and runs dry; the expansions keep the converter's full fields. Crystals = blue gems (no growth).
function Near($i, $k, $r) { $c = $wpCell[$k]; $x = $i % 512; $y = [Math]::Floor($i / 512); [Math]::Abs($x - $c[0]) -le $r -and [Math]::Abs($y - $c[1]) -le $r }
$nHome = 0; $nOre = 0; $fields = @{}
for ($i = 0; $i -lt $conv.Overlay.Length; $i++) {
    $o = $conv.Overlay[$i]; if ($o -lt 27 -or $o -gt 38) { continue }
    if (Near $i '15' 16) { $conv.OverlayData[$i] = [byte](3 + ($i % 3)); $nHome++ }
    # Stickler Woods (NE): rich blue crystals that grow back slowly (the mission gives [BlueGems] a growth rate and a
    # crystal mine stands by every field). Lore: the resources of the Stickler Woods regenerate over time. No gold ore
    # anywhere (user 2026-10-27: only blue crystals on this map)
    elseif (Near $i '39' 12) { $conv.Overlay[$i] = [byte](31 + ($i % 4)); $conv.OverlayData[$i] = [byte](7 + ($i % 5)); $nOre++ }
}
# Stickler Woods: widen the crystal field round the old minerals (every open cell within 5 of wp 39 gets a 60% chance)
$rnd = New-Object Random 2478
$c39 = $wpCell['39']
for ($x = $c39[0] - 5; $x -le $c39[0] + 5; $x++) { for ($y = $c39[1] - 5; $y -le $c39[1] + 5; $y++) {
    if (-not (Passable $x $y) -or ($x -eq $c39[0] -and $y -eq $c39[1])) { continue }
    if (($x - $c39[0]) * ($x - $c39[0]) + ($y - $c39[1]) * ($y - $c39[1]) -gt 26 -or $rnd.NextDouble() -gt 0.6) { continue }
    $o = $y * 512 + $x; $conv.Overlay[$o] = [byte](31 + $rnd.Next(4)); $conv.OverlayData[$o] = [byte](4 + $rnd.Next(8)); $nOre++
} }
"resources: home field thinned ($nHome cells, stage 3-5), Stickler Woods blue crystals $nOre cells"

# ================================================================ Antiga ground: mudflats and scrub, not a green meadow
# User 2026-10-28: "was Antiga Prime that green?" No: hard mudflats where the oceans dried up and low mesas covered by
# native scrub (StarCraft lore; the SC maps of Antiga use the same badlands tileset as Mar Sara). The converter paints
# low ground as grass, so: low ground -> dirt (slot 1) with sparse scrub, the mesas mostly scrub, scrub = slot 3 drawn
# with Autumn Grass (rusty), a few small grass patches left for colour. Pavement (slot 2, roads/platforms) untouched.
# Patches come from smooth value noise, so they form blobs, not salt and pepper.
$gN = $conv.N; $step = 7
$gw = [int][Math]::Ceiling($gN / $step) + 2
$vn = New-Object 'double[]' ($gw * $gw); $nr = New-Object Random 2499
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
    if ($g -eq 2) { continue }                                   # pavement stays
    $high = $conv.Plateau[$i] -ge 0
    $n1 = Noise $vn $x $y; $n2 = Noise $vn2 $x $y
    if ($high) { $g = if ($n1 -lt 0.62) { 3 } else { 1 } }       # mesas: mostly scrub, bare dirt between
    else { $g = if ($n1 -gt 0.72) { 3 } elseif ($n2 -gt 0.80) { 0 } else { 1 } }   # mudflats, scrub clumps, a little grass
    $conv.Ground[$i] = $g; $cnt[$g]++
} }
"ground: dirt $($cnt[1]), scrub $($cnt[3]), grass $($cnt[0]) cells (pavement unchanged)"
$base[3] = $th.SetByName('Autumn Grass').Start
$lat[3]  = $th.SetByName('Autumn Grass/Clear LAT').Start
# crystal mines next to the fields (user 2026-10-27): terrain objects that keep seeding crystals round themselves.
# OREMINE2 is turned into a blue-crystal mine by the mission map (TiberiumToSpawn=6 = BlueGems), Stickler Woods
# included. Spot: the open cell nearest to the field's centre that touches the field and has no
# overlay or object on itself or its 8 neighbours except crystals, so it never closes a path
$mines = [ordered]@{ '15' = 'OREMINE2'; '20' = 'OREMINE2'; '21' = 'OREMINE2'; '41' = 'OREMINE2'; '39' = 'OREMINE2' }
foreach ($k in $mines.Keys) {
    $cells = @(); for ($i = 0; $i -lt $conv.Overlay.Length; $i++) { $o = $conv.Overlay[$i]; if ((($o -ge 27 -and $o -le 38) -or ($o -ge 147 -and $o -le 150)) -and (Near $i $k 12)) { $cells += $i } }
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
            $o = $conv.Overlay[$ny * 512 + $nx]; $res = ($o -ge 27 -and $o -le 38) -or ($o -ge 147 -and $o -le 150)
            if ($res) { $touch = $true; continue }
            if (-not (Passable $nx $ny)) { $ok = $false }
        } }
        if (-not $ok -or -not $touch) { continue }
        $d = ($x - $mx) * ($x - $mx) + ($y - $my) * ($y - $my); if ($d -lt $bd) { $bd = $d; $best = @($x, $y) }
    } }
    if (-not $best) { "WARN no free cell for the mine at wp $k"; continue }
    $conv.Terrain[$best[1] * 1000 + $best[0]] = $mines[$k]
    "mine $($mines[$k]) at $($best[0]),$($best[1]) by the field of wp $k ($($cells.Count) cells)"
}
$conv.ApplyGround(0, $base, $lat)

# ================================================================ dressing: scrub, trees, "purple blossoms" (autumn grass)
# Trees and rocks sparsely on open ground, a thicker wood round Stickler Woods; never within 4 cells of a waypoint and
# only where all 8 neighbours are open, so nothing closes a ramp or a 1-cell gap
$nearWp = New-Object 'bool[]' ($conv.N * $conv.N)
foreach ($k in $wpCell.Keys) { $c = $wpCell[$k]; $r = if ($k -eq '39') { 2 } else { 4 }; for ($x = $c[0] - $r; $x -le $c[0] + $r; $x++) { for ($y = $c[1] - $r; $y -le $c[1] + $r; $y++) { if ($conv.In($x, $y)) { $nearWp[$conv.Idx($x, $y)] = $true } } } }
$smallRocks = $th.SetByName('Small Rocks').Start
$nDeco = 0; $nWood = 0
for ($y = 1; $y -lt $conv.N - 1; $y++) { for ($x = 1; $x -lt $conv.N - 1; $x++) {
    if (-not (Passable $x $y) -or $nearWp[$conv.Idx($x, $y)]) { continue }
    $open = $true
    for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { if (($dx -or $dy) -and -not (Passable ($x + $dx) ($y + $dy))) { $open = $false } } }
    if (-not $open) { continue }
    $dw = [Math]::Sqrt(($x - $c39[0]) * ($x - $c39[0]) + ($y - $c39[1]) * ($y - $c39[1]))
    $chance = if ($dw -ge 6 -and $dw -le 11) { 0.22 } else { 0.012 }
    if ($rnd.NextDouble() -lt $chance) { $conv.Terrain[$y * 1000 + $x] = $trees[$rnd.Next($trees.Length)]; if ($dw -le 11) { $nWood++ } else { $nDeco++ } }
} }
"dressing: $nDeco trees/bushes, Stickler Woods $nWood trees"

$conv.WallFrames(2, [int[]]@(0, 2, 4, 6))
$conv.CheckConnectivity()
$cmp = $conv.CompareWithSc(); $cmp.Save("$work\compare_sc.png"); $cmp.Dispose()
$text = $conv.WriteMap('ARKA #4: Zielony krysztal (teren)', 'Claude (kampania ARKA; teren: Blizzard T6 Norad II, port: Claude)')
$conv.Log | Set-Content "$work\log.txt" -Encoding UTF8
"converter: $($conv.Log.Count) log lines; starts $($conv.Starts.Count) connected=$($conv.StartsConnected) sealed $($conv.Sealed) leaks $($conv.Leaks) failed chains $($conv.ChainFailures)"
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::GetEncoding(1252))
$ini = [Ini]::Load($Out)
$ini.Set('Map', 'Theater', 'TEMPERATE')
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; $ini.Set('Waypoints', $k, "$($c[1] * 1000 + $c[0])") }
$ini.Set('Basic', 'Name', 'ARKA #4: Zielony krysztal (teren, Antiga Prime)')
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
"CHECKS: " + $(if ($fail) { "$fail waypoint(s) unreachable" } else { "PASS (all $($wps.Count) waypoints reachable from ARKA)" })

# ================================================================ pictures: SC grid for planning, waypoints on the cell map
$g0 = [Drawing.Image]::FromFile("$work\sc.png")
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
