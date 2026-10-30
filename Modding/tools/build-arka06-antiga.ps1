# Terrain of ARKA mission 6 "Ogien z nieba" (Antiga Prime, 2500): the StarCraft Terran campaign map T7 "Biting the
# Bullet" (CASC SD/campaign/Terran/Terran07, never released in StarCraft; briefing "Secret Staging Area, Antiga Prime
# Colony: 08:56 SCT, 01.03.2500"). It is the Protoss arrival on Antiga: the author placed Tassadar's Gantrithor with
# Carriers and Scouts by the west edge. Badlands -> DTA TEMPERATE with the Antiga ground of mission 4 (mudflats, scrub).
# ARKA moved a year after mission 4: the Terrans bolted jet engines to it (it lifts off like a Terran building) and it
# landed on the south shore, a wide flat land fit for a big base.
# In StarCraft the centre, the north-east and the south-east are islands (the map was an air map). The mission needs
# ground routes, so the script raises four causeways across the dry-ocean channels before the conversion (the
# converter paves them as bridges): ARKA <-> centre (Einstein's walk to Tassadar), centre <-> the Protoss west,
# centre <-> the north-east (Raynor's Sons of Korhal), ARKA <-> the south-east island (a rich, exposed expansion).
# The west and the south are joined by land already (the Protoss come along the south-west shore too).
# Writes Maps\Custom\arka06_antiga.map (viewable as a skirmish "Custom Map") and the mission waypoints, the contract
# with the mission script (build-arka06-mission.ps1, not written yet).
#
#   powershell -NoProfile -File .\build-arka06-antiga.ps1            # build + checks + preview + render (~2 min)
#   powershell -NoProfile -File .\build-arka06-antiga.ps1 -NoRender  # no CNCMaps render
#
# Work files: %TEMP%\arka06-terrain\ (sc.png, sc_grid.png, grid.png, reach.png, compare_sc.png, waypoints.png, log.txt).
# Wiki: Modding/wiki/missions/arka-06-ogien-z-nieba.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$Out = "",
    [double]$Zoom = 1.25,
    [switch]$NoRender
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Out) { $Out = "$game\Maps\Custom\arka06_antiga.map" }
$work = "$env:TEMP\arka06-terrain"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScMap.cs", "$tools\TsMap.cs", "$tools\ScToDta.cs" -ReferencedAssemblies System.Drawing

# ================================================================ StarCraft side: T7 "Biting the Bullet", badlands, 128x128
$casc = New-Object Casc $StarCraft
$chk  = New-Object Chk (, $casc.ReadFile('SD/campaign/Terran/Terran07/staredit/scenario.chk'))
$ts   = New-Object ScTileset $casc, ([Chk]::EraNames[$chk.Era])
$ter  = New-Object ScTerrain $chk, $ts
"SC map: $($chk.Width)x$($chk.Height) $([Chk]::EraNames[$chk.Era]), zoom $Zoom"
$sc = $ter.RenderNatural(4); $sc.Save("$work\sc.png"); $sc.Dispose()

# drop the vespene geysers (the converter turns them into Tiberium trees)
$chk.Units.RemoveAll([Predicate[ScUnit]] { param($u) $u.Id -eq 188 }) | Out-Null

# ================================================================ causeways across the channels (SC tile coordinates)
# A strip of walkable low ground, $w tiles wide, from one shore to the other; both ends sit well inside land. Colour =
# the mean of the map's walkable low ground, so the converter sees land, not water. 5 tiles wide: a 3-tile strip was
# taken for an SC bridge (paved, no shore pieces, saw-tooth edges on the water) and was a 2-cell choke for armies;
# at 5 tiles it is an isthmus with water cliffs and the street runs on it. North-south strips need 8: the isometric
# projection makes a vertical SC strip fewer cells wide than a horizontal one.
$sr = 0; $sg = 0; $sb = 0; $sn = 0
for ($i = 0; $i -lt $ter.Flags.Length; $i += 7) { if ($ter.Walkable($i) -and $ter.Level($i) -eq 0) { $c = [Drawing.Color]::FromArgb($ter.Rgb[$i]); $sr += $c.R; $sg += $c.G; $sb += $c.B; $sn++ } }
$mud = [Drawing.Color]::FromArgb([int]($sr / $sn), [int]($sg / $sn), [int]($sb / $sn)).ToArgb()
$causeways = [ordered]@{
    'ARKA - centre'       = @(57, 81, 55, 100, 8)
    'centre - west'       = @(42, 64, 24, 63, 5)
    'centre - north-east' = @(70, 55, 93, 44, 5)
    'ARKA - SE island'    = @(96, 101, 96, 120, 8)
}
foreach ($k in $causeways.Keys) {
    $c = $causeways[$k]; $ax = $c[0] * 4 + 2; $ay = $c[1] * 4 + 2; $bx = $c[2] * 4 + 2; $by = $c[3] * 4 + 2; $hw = $c[4] * 2
    $len2 = ($bx - $ax) * ($bx - $ax) + ($by - $ay) * ($by - $ay); $n = 0
    for ($my = [Math]::Min($ay, $by) - $hw - 1; $my -le [Math]::Max($ay, $by) + $hw + 1; $my++) {
        for ($mx = [Math]::Min($ax, $bx) - $hw - 1; $mx -le [Math]::Max($ax, $bx) + $hw + 1; $mx++) {
            if ($mx -lt 0 -or $my -lt 0 -or $mx -ge $ter.W -or $my -ge $ter.H) { continue }
            # 0.0/1.0, not 0/1: [Math]::Min(1, double) picks the int overload and rounds t to 0 or 1
            $t = [Math]::Max(0.0, [Math]::Min(1.0, [double](($mx - $ax) * ($bx - $ax) + ($my - $ay) * ($by - $ay)) / $len2))
            $px = $ax + $t * ($bx - $ax) - $mx; $py = $ay + $t * ($by - $ay) - $my
            if ($px * $px + $py * $py -gt $hw * $hw) { continue }
            $m = $my * $ter.W + $mx
            if (-not $ter.Walkable($m)) { $ter.Flags[$m] = 1; $ter.Rgb[$m] = $mud; $n++ }
        }
    }
    "causeway ${k}: $n minitiles raised"
}

# ================================================================ the north-east mesa flattened
# In DTA its west edge read as a stray zig-zag cliff line on flat ground (user 2026-10-30 screenshot: the same dirt on
# both sides). Raynor's camps do not need the height: every high or cliff minitile of the NE land (SC tiles x >= 84,
# y < 42) becomes walkable low ground with the mud colour.
$nFlat = 0
for ($my = 0; $my -lt 42 * 4; $my++) { for ($mx = 84 * 4; $mx -lt $ter.W; $mx++) {
    $m = $my * $ter.W + $mx
    if ($ter.Level($m) -gt 0) { if (-not $ter.Walkable($m)) { $ter.Rgb[$m] = $mud }; $ter.Flags[$m] = 1; $nFlat++ }
} }
"NE mesa flattened: $nFlat minitiles"

# ================================================================ the channel NW mesa - centre filled
# About 2 SC tiles wide, it kept producing saw-tooth water whatever we did, and the user chose to fill it
# (2026-10-30). Water of the channel (SC tiles 42-58 x 41-50; the west lake and the north water lie outside) becomes
# low land at the foot of the mesa cliffs; the mesa top is still reached from the west only (paths unchanged).
$nChan = 0
for ($my = 41 * 4; $my -lt 50 * 4; $my++) { for ($mx = 42 * 4; $mx -lt 58 * 4; $mx++) {
    $m = $my * $ter.W + $mx
    if (-not $ter.Walkable($m) -and $ter.Level($m) -eq 0) { $ter.Flags[$m] = 1; $ter.Rgb[$m] = $mud; $nChan++ }
} }
"channel NW mesa - centre filled: $nChan minitiles"

# ================================================================ beaches under the mesa cliffs
# Many SC mesas drop almost into the water: between the cliff and the water there is a strip of low ground one DTA
# cell wide, too thin for a water-cliff piece, so it stayed a raw saw-tooth edge (user 2026-10-30 screenshot, SE island
# and NW mesa). Water within $beach minitiles of high ground becomes low land, so cliff and shore both fit.
# A beach never joins two pieces of land: a water minitile that has walkable ground of two different components
# within $beach + 3 stays water (8 minitiles closed the channel NW mesa - centre and tore the NE pond into scraps).
$beach = 6
# except the channel between the NW mesa and the centre, filled above (its leftovers may join the land there)
function In-NwChannel($i) { $x = $i % $ter.W; $y = [Math]::Floor($i / $ter.W); $x -ge 38 * 4 -and $x -lt 62 * 4 -and $y -ge 40 * 4 -and $y -lt 52 * 4 }
$lab = New-Object 'int[]' $ter.Flags.Length; for ($i = 0; $i -lt $lab.Length; $i++) { $lab[$i] = -1 }
$nLab = 0
for ($s = 0; $s -lt $lab.Length; $s++) {
    if ($lab[$s] -ge 0 -or -not $ter.Walkable($s)) { continue }
    $q = New-Object 'Collections.Generic.Queue[int]'; $q.Enqueue($s); $lab[$s] = $nLab
    while ($q.Count) {
        $c = $q.Dequeue(); $x = $c % $ter.W; $y = [Math]::Floor($c / $ter.W)
        for ($dy = -1; $dy -le 1; $dy++) { for ($dx = -1; $dx -le 1; $dx++) {
            $nx = $x + $dx; $ny = $y + $dy; if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $ter.W -or $ny -ge $ter.H) { continue }
            $n = $ny * $ter.W + $nx; if ($lab[$n] -lt 0 -and $ter.Walkable($n)) { $lab[$n] = $nLab; $q.Enqueue($n) }
        } }
    }
    $nLab++
}
# scraps of beach under a cliff are components of their own in SC; they must not count as "another piece of land"
# (the SE island's west shore kept its saw-tooth because of them)
$size = New-Object 'int[]' $nLab; foreach ($l in $lab) { if ($l -ge 0) { $size[$l]++ } }
for ($i = 0; $i -lt $lab.Length; $i++) { if ($lab[$i] -ge 0 -and $size[$lab[$i]] -lt 200) { $lab[$i] = -1 } }
$dHigh = New-Object 'int[]' $ter.Flags.Length; for ($i = 0; $i -lt $dHigh.Length; $i++) { $dHigh[$i] = 99 }
$q = New-Object 'Collections.Generic.Queue[int]'
for ($i = 0; $i -lt $ter.Flags.Length; $i++) { if ($ter.Level($i) -gt 0) { $dHigh[$i] = 0; $q.Enqueue($i) } }
while ($q.Count) {
    $c = $q.Dequeue(); if ($dHigh[$c] -ge $beach) { continue }
    $x = $c % $ter.W; $y = [Math]::Floor($c / $ter.W)
    foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1), @(1, 1), @(-1, -1), @(1, -1), @(-1, 1))) {
        $nx = $x + $d[0]; $ny = $y + $d[1]; if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $ter.W -or $ny -ge $ter.H) { continue }
        $n = $ny * $ter.W + $nx; if ($dHigh[$n] -le $dHigh[$c] + 1) { continue }
        $dHigh[$n] = $dHigh[$c] + 1; $q.Enqueue($n)
    }
}
$nBeach = 0; $nKept = 0; $fill = New-Object Collections.Generic.List[int]; $rg = $beach + 3
for ($i = 0; $i -lt $ter.Flags.Length; $i++) {
    if ($dHigh[$i] -gt $beach -or $ter.Walkable($i) -or $ter.Level($i) -gt 0) { continue }
    # no "bluish" test: the water at the foot of a cliff is shaded brown in SC and stayed water (saw-tooth kept)
    $x = $i % $ter.W; $y = [Math]::Floor($i / $ter.W); $one = -1; $two = $false
    for ($yy = [Math]::Max(0, $y - $rg); $yy -le [Math]::Min($ter.H - 1, $y + $rg) -and -not $two; $yy++) {
        for ($xx = [Math]::Max(0, $x - $rg); $xx -le [Math]::Min($ter.W - 1, $x + $rg); $xx++) {
            $l = $lab[$yy * $ter.W + $xx]; if ($l -lt 0) { continue }
            if ($one -lt 0) { $one = $l } elseif ($l -ne $one) { $two = $true; break }
        }
    }
    if ($two -and -not (In-NwChannel $i)) { $nKept++; continue }
    $fill.Add($i)
}
foreach ($i in $fill) { $ter.Flags[$i] = 1; $ter.Rgb[$i] = $mud; $nBeach++ }
"beaches under mesa cliffs: $nBeach water minitiles made land, $nKept kept as water (would join two pieces of land)"

# ================================================================ no water narrower than ~2 tiles
# Narrow coves, 1-tile channels and tiny ponds came out as shore pieces whose water part lies on land (user 2026-10-30
# screenshots: Antioch, NW pond, SW lake). Morphological opening of the water (erode, then grow back, radius $open
# minitiles): water that does not survive becomes land, with the same guard as the beaches (never joins two pieces of
# land). Water = unwalkable level-0 minitiles of a bluish component (doodads stay obstacles).
$open = 4
$isW = New-Object 'bool[]' $ter.Flags.Length; $seenU = New-Object 'bool[]' $ter.Flags.Length
for ($s = 0; $s -lt $isW.Length; $s++) {
    if ($seenU[$s] -or $ter.Walkable($s) -or $ter.Level($s) -gt 0) { continue }
    $comp = New-Object Collections.Generic.List[int]; $nb = 0
    $q = New-Object 'Collections.Generic.Queue[int]'; $q.Enqueue($s); $seenU[$s] = $true
    while ($q.Count) {
        $c = $q.Dequeue(); $comp.Add($c); $x = $c % $ter.W; $y = [Math]::Floor($c / $ter.W)
        $cl = [Drawing.Color]::FromArgb($ter.Rgb[$c]); if ($cl.B -gt $cl.R + 12 -and $cl.B -gt $cl.G + 4) { $nb++ }
        for ($dy = -1; $dy -le 1; $dy++) { for ($dx = -1; $dx -le 1; $dx++) {
            $nx = $x + $dx; $ny = $y + $dy; if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $ter.W -or $ny -ge $ter.H) { continue }
            $n = $ny * $ter.W + $nx; if (-not $seenU[$n] -and -not $ter.Walkable($n) -and $ter.Level($n) -eq 0) { $seenU[$n] = $true; $q.Enqueue($n) }
        } }
    }
    if ($nb / $comp.Count -ge 0.12) { foreach ($c in $comp) { $isW[$c] = $true } }
}
# erode: distance to the nearest non-water minitile (map edge counts as water)
$dLand = New-Object 'int[]' $isW.Length; $q = New-Object 'Collections.Generic.Queue[int]'
for ($i = 0; $i -lt $isW.Length; $i++) { if ($isW[$i]) { $dLand[$i] = 99 } else { $dLand[$i] = 0; $q.Enqueue($i) } }
while ($q.Count) {
    $c = $q.Dequeue(); if ($dLand[$c] -ge $open + 1) { continue }
    $x = $c % $ter.W; $y = [Math]::Floor($c / $ter.W)
    for ($dy = -1; $dy -le 1; $dy++) { for ($dx = -1; $dx -le 1; $dx++) {
        $nx = $x + $dx; $ny = $y + $dy; if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $ter.W -or $ny -ge $ter.H) { continue }
        $n = $ny * $ter.W + $nx; if ($dLand[$n] -gt $dLand[$c] + 1) { $dLand[$n] = $dLand[$c] + 1; $q.Enqueue($n) }
    } }
}
# grow back: water within $open of a core minitile (deeper than $open) survives
$dCore = New-Object 'int[]' $isW.Length; $q = New-Object 'Collections.Generic.Queue[int]'
for ($i = 0; $i -lt $isW.Length; $i++) { if ($isW[$i] -and $dLand[$i] -gt $open) { $dCore[$i] = 0; $q.Enqueue($i) } else { $dCore[$i] = 99 } }
while ($q.Count) {
    $c = $q.Dequeue(); if ($dCore[$c] -ge $open) { continue }
    $x = $c % $ter.W; $y = [Math]::Floor($c / $ter.W)
    for ($dy = -1; $dy -le 1; $dy++) { for ($dx = -1; $dx -le 1; $dx++) {
        $nx = $x + $dx; $ny = $y + $dy; if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $ter.W -or $ny -ge $ter.H) { continue }
        $n = $ny * $ter.W + $nx; if ($dCore[$n] -gt $dCore[$c] + 1) { $dCore[$n] = $dCore[$c] + 1; $q.Enqueue($n) }
    } }
}
$nOpen = 0; $nOpenKept = 0; $fill = New-Object Collections.Generic.List[int]
for ($i = 0; $i -lt $isW.Length; $i++) {
    if (-not $isW[$i] -or $dCore[$i] -le $open) { continue }
    $x = $i % $ter.W; $y = [Math]::Floor($i / $ter.W); $one = -1; $two = $false
    for ($yy = [Math]::Max(0, $y - $rg); $yy -le [Math]::Min($ter.H - 1, $y + $rg) -and -not $two; $yy++) {
        for ($xx = [Math]::Max(0, $x - $rg); $xx -le [Math]::Min($ter.W - 1, $x + $rg); $xx++) {
            $l = $lab[$yy * $ter.W + $xx]; if ($l -lt 0) { continue }
            if ($one -lt 0) { $one = $l } elseif ($l -ne $one) { $two = $true; break }
        }
    }
    if ($two -and -not (In-NwChannel $i)) { $nOpenKept++; continue }
    $fill.Add($i)
}
foreach ($i in $fill) { $ter.Flags[$i] = 1; $ter.Rgb[$i] = $mud; $nOpen++ }
"narrow water removed: $nOpen minitiles made land, $nOpenKept kept (would join two pieces of land)"
# new land cut off from the old land by the water the guard kept (an islet under the NW mesa, user screenshot) goes
# back to water: walkable components under 600 minitiles made mostly of filled minitiles
$wr = 0; $wg = 0; $wb = 0; $wn = 0
for ($i = 0; $i -lt $isW.Length; $i += 3) { if ($isW[$i] -and -not $ter.Walkable($i)) { $cl = [Drawing.Color]::FromArgb($ter.Rgb[$i]); $wr += $cl.R; $wg += $cl.G; $wb += $cl.B; $wn++ } }
$waterRgb = [Drawing.Color]::FromArgb([int]($wr / $wn), [int]($wg / $wn), [int]($wb / $wn)).ToArgb()
$isNew = New-Object 'bool[]' $isW.Length; foreach ($i in $fill) { $isNew[$i] = $true }
for ($i = 0; $i -lt $dHigh.Length; $i++) { if ($dHigh[$i] -le $beach -and $lab[$i] -lt 0 -and $ter.Walkable($i) -and $ter.Rgb[$i] -eq $mud) { $isNew[$i] = $true } }
$seenN = New-Object 'bool[]' $isW.Length; $nBack = 0
for ($s = 0; $s -lt $isW.Length; $s++) {
    if ($seenN[$s] -or -not $ter.Walkable($s)) { continue }
    $comp = New-Object Collections.Generic.List[int]; $q = New-Object 'Collections.Generic.Queue[int]'; $q.Enqueue($s); $seenN[$s] = $true; $nNew = 0
    while ($q.Count) {
        $c = $q.Dequeue(); $comp.Add($c); if ($isNew[$c]) { $nNew++ }; $x = $c % $ter.W; $y = [Math]::Floor($c / $ter.W)
        for ($dy = -1; $dy -le 1; $dy++) { for ($dx = -1; $dx -le 1; $dx++) {
            $nx = $x + $dx; $ny = $y + $dy; if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $ter.W -or $ny -ge $ter.H) { continue }
            $n = $ny * $ter.W + $nx; if (-not $seenN[$n] -and $ter.Walkable($n)) { $seenN[$n] = $true; $q.Enqueue($n) }
        } }
    }
    if ($comp.Count -lt 600 -and $nNew * 2 -ge $comp.Count) { foreach ($c in $comp) { $ter.Flags[$c] = 0; $ter.Rgb[$c] = $waterRgb }; $nBack += $comp.Count }
}
"islets of new land returned to water: $nBack minitiles"

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
# leftovers the user saw on renders (2026-10-30): ponds and slivers of water a few cells big (on the Antioch island,
# NW, SW: the beaches leave scraps of shallow ponds) become ground, and an obstacle cell standing in water (SW lake,
# the SC strip doodad) becomes water. Map-edge water stays.
$kLow = [Kind]::Low; $kWater = [Kind]::Water; $kBlock = [Kind]::Block
$seenW = New-Object 'bool[]' $conv.K.Length; $nPond = 0; $nPondCells = 0
for ($s = 0; $s -lt $conv.K.Length; $s++) {
    if ($seenW[$s] -or -not $conv.Valid[$s] -or $conv.K[$s] -ne $kWater) { continue }
    $comp = New-Object Collections.Generic.List[int]; $edge = $false
    $q = New-Object 'Collections.Generic.Queue[int]'; $q.Enqueue($s); $seenW[$s] = $true
    while ($q.Count) {
        $c = $q.Dequeue(); $comp.Add($c); $x = $c % $conv.N; $y = [Math]::Floor($c / $conv.N)
        if (-not $conv.Visible[$c]) { $edge = $true }
        for ($dy = -1; $dy -le 1; $dy++) { for ($dx = -1; $dx -le 1; $dx++) {
            $nx = $x + $dx; $ny = $y + $dy; if (-not $conv.In($nx, $ny)) { $edge = $true; continue }
            $n = $conv.Idx($nx, $ny); if (-not $seenW[$n] -and $conv.K[$n] -eq $kWater) { $seenW[$n] = $true; $q.Enqueue($n) }
        } }
    }
    if ($comp.Count -lt 25 -and -not $edge) { foreach ($c in $comp) { $conv.K[$c] = $kLow }; $nPond++; $nPondCells += $comp.Count }
}
$nIslet = 0
for ($i = 0; $i -lt $conv.K.Length; $i++) {
    if ($conv.K[$i] -ne $kBlock) { continue }
    $x = $i % $conv.N; $y = [Math]::Floor($i / $conv.N); $wn = 0
    for ($dy = -1; $dy -le 1; $dy++) { for ($dx = -1; $dx -le 1; $dx++) { if (($dx -or $dy) -and $conv.In($x + $dx, $y + $dy) -and $conv.K[$conv.Idx($x + $dx, $y + $dy)] -eq $kWater) { $wn++ } } }
    if ($wn -ge 5) { $conv.K[$i] = $kWater; $nIslet++ }
}
# ...and scraps of low ground cut off by water and cliffs (a strip at the foot of the NW mesa in the channel, a cell in
# the NW lake): ground components under 40 cells that touch no other ground become water
# (not after SettleWater: there it drowned the beach between the mesa cliff and the shore pieces, raw edges all round)
function Remove-GroundScraps {
    $seenL = New-Object 'bool[]' $conv.K.Length; $n0 = 0
    for ($s = 0; $s -lt $conv.K.Length; $s++) {
        if ($seenL[$s] -or -not $conv.Valid[$s] -or $conv.Used[$s] -or ($conv.K[$s] -ne $kLow -and $conv.K[$s] -ne [Kind]::High)) { continue }
        $comp = New-Object Collections.Generic.List[int]; $q = New-Object 'Collections.Generic.Queue[int]'; $q.Enqueue($s); $seenL[$s] = $true; $wet = $false
        while ($q.Count) {
            $c = $q.Dequeue(); $comp.Add($c); $x = $c % $conv.N; $y = [Math]::Floor($c / $conv.N)
            for ($dy = -1; $dy -le 1; $dy++) { for ($dx = -1; $dx -le 1; $dx++) {
                $nx = $x + $dx; $ny = $y + $dy; if (-not $conv.In($nx, $ny)) { continue }
                $n = $conv.Idx($nx, $ny); $k = $conv.K[$n]
                if ($k -eq $kWater -and -not $conv.Used[$n]) { $wet = $true }
                if (-not $seenL[$n] -and -not $conv.Used[$n] -and ($k -eq $kLow -or $k -eq [Kind]::High)) { $seenL[$n] = $true; $q.Enqueue($n) }
            } }
        }
        if ($comp.Count -lt 40 -and $wet) { foreach ($c in $comp) { $conv.K[$c] = $kWater }; $n0 += $comp.Count }
    }
    $n0
}
$nScrap = Remove-GroundScraps
"small ponds made ground: $nPond ($nPondCells cells); obstacle cells in water made water: $nIslet; ground scraps made water: $nScrap cells"
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
# ground slots (ScToDta.Ground): 0 = grass, 1 = dirt (mudflats), 2 = pavement (pads, squares, causeways), 3 = scrub,
# 4 = paved road
$RoadG = 4
$base = [int[]]@(0, $th.SetByName('Dirt LAT').Start, $th.SetByName('Pavement LAT').Start, $th.SetByName('Autumn Grass').Start, $th.SetByName('Paved Road LAT & addons').Start)
$lat  = [int[]]@(0, $th.SetByName('Clear/Dirt LAT').Start, $th.SetByName('Clear/Pavement LAT').Start, $th.SetByName('Autumn Grass/Clear LAT').Start, $th.SetByName('Clear/Paved Road LAT').Start)
$roadOnPave = $th.SetByName('Pavement/Paved Road LAT').Start

# ================================================================ mission waypoints (contract with build-arka06-mission.ps1)
# ORIGINAL SC tile coordinates (128x128 grid of sc_grid.png); each is moved to the nearest passable cell
$wps = [ordered]@{
    '10' = @(54, 115, 'ARKA: landing pad on the south shore (SC: Raynor and Duke start here)')
    '11' = @(54, 106, 'player start army')
    '12' = @(62, 113, 'player base centre / construction yard')
    '13' = @(50, 109, 'Einstein next to ARKA (the walk to Tassadar starts here)')
    '14' = @(70, 118, 'base: power plants, east')
    '15' = @(42, 113, 'crystal field 1: home field (safe)')
    '16' = @(30, 110, 'base: west gate (the Protoss come along the south-west shore)')
    '17' = @(56, 101, 'base: north gate, south end of the ARKA - centre causeway')
    '18' = @(82, 119, 'base: east')
    '19' = @(96, 121, 'south end of the causeway to the SE island')
    '20' = @(12, 50, 'Pylon 1: north-west, under the Gantrithor')
    '21' = @(17, 76, 'Pylon 2: west, by the west crystal field')
    '22' = @(10, 97, 'Pylon 3: south-west landing zone (SC: Zerg Landing Zone)')
    '23' = @(20, 64, 'Protoss forward camp / Fenix rally, west end of the west causeway')
    '24' = @(6, 52, 'Gantrithor: Tassadar''s carrier hovers here (SC location Gantrithor)')
    '25' = @(7, 81, 'crystal field 2: west, in the Protoss zone')
    '26' = @(40, 26, 'crystal field 3: north-west mesa, far and rich')
    '30' = @(57, 62, 'centre of the map: Einstein meets Tassadar (high plateau)')
    '31' = @(61, 46, 'crystal field 4: centre, contested (Fenix and Raynor cross here)')
    '32' = @(44, 64, 'centre: west end of the west causeway')
    '33' = @(72, 54, 'centre: north-east end of the causeway to Raynor')
    '34' = @(57, 80, 'centre: south end, north end of the ARKA causeway')
    '35' = @(100, 45, 'Sons of Korhal forward camp (Raynor), east end of the NE causeway')
    '36' = @(104, 12, 'Sons of Korhal main camp, north-east')
    '37' = @(119, 6, 'crystal field 5: north-east corner, Raynor''s')
    '38' = @(89, 101, 'crystal field 6: SE island, rich and exposed')
    '39' = @(100, 88, 'SE island: centre (money crate)')
    '40' = @(110, 35, 'crystal field 7: NE lower lobe, by Raynor''s forward camp')
    '50' = @(104, 91, 'Antioch (the Antigan colony on the SE island): main square')
    '51' = @(110, 84, 'Antioch: civic district (Command Center + Comsat, Academy, Engineering Bay)')
    '52' = @(101, 77, 'Antioch: spaceport (Starports + Control Towers, Science Facility + Physics Lab)')
    '53' = @(84, 95, 'Antioch: mining district on the mesa by the crystals (Factory + Machine Shop, Armory, depots)')
    '42' = @(1, 60, 'wave entry: west edge (Protoss)')
    '43' = @(2, 3, 'wave entry: north-west corner')
    '44' = @(1, 108, 'wave entry: south-west edge')
    '45' = @(126, 2, 'wave entry: north-east corner (Raynor)')
    '46' = @(126, 52, 'wave entry: east edge')
    '47' = @(126, 96, 'air entry: east edge, south (SE island)')
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
# The SC minerals become the converter's crystals: home field (wp 15), west (25, Protoss), centre (31, contested),
# SE island (38), NE (37, 40, Raynor's). Blue crystals only, no gold (user 2026-10-27). On top: a rich field on the
# NW mesa (26) and a wider SE island field; crystal mines (OREMINE2, made blue-crystal mines by the mission map as in
# missions 4-5) by the centre field and on the SE island.
$rnd = New-Object Random 2500
$ore = @{ '26' = @(5, 0.75, 7); '38' = @(4, 0.7, 7) }   # radius, density, minimum stage
foreach ($k in $ore.Keys) {
    $c = $wpCell[$k]; $r = $ore[$k][0]; $n = 0
    for ($x = $c[0] - $r; $x -le $c[0] + $r; $x++) { for ($y = $c[1] - $r; $y -le $c[1] + $r; $y++) {
        if (-not (Passable $x $y) -or ($x -eq $c[0] -and $y -eq $c[1])) { continue }
        if (($x - $c[0]) * ($x - $c[0]) + ($y - $c[1]) * ($y - $c[1]) -gt $r * $r + 1 -or $rnd.NextDouble() -gt $ore[$k][1]) { continue }
        $o = $y * 512 + $x; $conv.Overlay[$o] = [byte](31 + $rnd.Next(4)); $conv.OverlayData[$o] = [byte]($ore[$k][2] + $rnd.Next(12 - $ore[$k][2])); $n++
    } }
    "crystal field at wp ${k}: $n cells added"
}
function Near($i, $k, $r) { $c = $wpCell[$k]; $x = $i % 512; $y = [Math]::Floor($i / 512); [Math]::Abs($x - $c[0]) -le $r -and [Math]::Abs($y - $c[1]) -le $r }
function Place-Mine($k) {
    $mineAt = $null
    $cells = @(); for ($i = 0; $i -lt $conv.Overlay.Length; $i++) { $o = $conv.Overlay[$i]; if ($o -ge 27 -and $o -le 38 -and (Near $i $k 9)) { $cells += $i } }
    if (-not $cells.Count) { "WARN no crystal field at wp $k for a mine"; return }
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
    if (-not $mineAt) { "WARN no free cell for the crystal mine at wp $k"; return }
    $conv.Terrain[$mineAt[1] * 1000 + $mineAt[0]] = 'OREMINE2'
    "crystal mine OREMINE2 at $($mineAt[0]),$($mineAt[1]) by the field of wp $k ($($cells.Count) cells)"
}
Place-Mine '31'
Place-Mine '38'
foreach ($k in @('15', '25', '26', '31', '37', '38', '40')) {
    $n = 0; for ($i = 0; $i -lt $conv.Overlay.Length; $i++) { $o = $conv.Overlay[$i]; if ($o -ge 27 -and $o -le 38 -and (Near $i $k 9)) { $n++ } }
    "field wp ${k}: $n crystal cells ($($wps[$k][2]))"
}

# ================================================================ Antiga ground: mudflats and scrub (as mission 4)
# Low ground -> dirt with scrub clumps and a little grass, mesas mostly scrub (Autumn Grass, rusty), from smooth value
# noise so the patches form blobs. Pavement (causeways) untouched.
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
    $n1 = Noise $vn $x $y; $n2 = Noise $vn2 $x $y
    if ($conv.Plateau[$i] -ge 0) { $g = if ($n1 -lt 0.62) { 3 } else { 1 } }
    else { $g = if ($n1 -gt 0.72) { 3 } elseif ($n2 -gt 0.80) { 0 } else { 1 } }
    $conv.Ground[$i] = $g; $cnt[$g]++
} }
"ground: dirt $($cnt[1]), scrub $($cnt[3]), grass $($cnt[0]) cells (pavement unchanged)"

# ================================================================ ARKA landing pad, camp squares and streets
# Squares: pavement discs on the waypoint's own level (never over a cliff): the ARKA pad (big: ARKA + the first base
# buildings), the meeting place in the centre, the Protoss and Sons of Korhal camps. Streets: the shortest open path
# between squares through the causeways, 2 cells wide as Paved Road LAT; every street ends in a square on both ends,
# so there are no dead ends (workflow/mission-design rule 5).
$lvlOf = { param($i) if ($conv.Plateau[$i] -lt 0) { 0 } else { $conv.PlateauLevel[$conv.Plateau[$i]] } }
function Pave($k, $r) {
    $c = $wpCell[$k]; $l0 = & $lvlOf $conv.Idx($c[0], $c[1]); $n = 0
    for ($x = $c[0] - $r; $x -le $c[0] + $r; $x++) { for ($y = $c[1] - $r; $y -le $c[1] + $r; $y++) {
        if (($x - $c[0]) * ($x - $c[0]) + ($y - $c[1]) * ($y - $c[1]) -gt $r * $r + 1 -or -not $conv.In($x, $y)) { continue }
        $i = $conv.Idx($x, $y); $kk = "$($conv.K[$i])"
        if (($kk -eq 'High' -or $kk -eq 'Low') -and -not $conv.Used[$i] -and $conv.Overlay[$y * 512 + $x] -eq 255 -and (& $lvlOf $i) -eq $l0) { $conv.Ground[$i] = 2; $n++ }
    } }
    $n
}
$sq = [ordered]@{ '10' = 7; '30' = 4; '23' = 3; '35' = 3; '36' = 4; '50' = 4; '51' = 3; '52' = 3; '53' = 3 }
foreach ($k in $sq.Keys) { $n = Pave $k $sq[$k]; "square at wp ${k}: $n cells ($($wps[$k][2]))" }
$road = New-Object 'bool[]' ($conv.N * $conv.N)
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
        if ($prev[$ib] -eq -2) { "WARN street $from -> ${to}: no open path from wp $($pts[$s]) to wp $($pts[$s + 1])"; return }
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
Street '10' '30' @('17', '34')     # Einstein's walk: ARKA -> the meeting place
Street '30' '23' @('32')           # centre -> the Protoss camp
Street '30' '35' @('33')           # centre -> Raynor's forward camp
Street '35' '36' @()               # Raynor's forward camp -> main camp
Street '10' '50' @('19')           # ARKA -> Antioch over the SE causeway
Street '50' '51' @()               # Antioch: square -> civic district
Street '50' '52' @()               # Antioch: square -> spaceport
Street '50' '53' @()               # Antioch: square -> mining district on the mesa
# free-end check: every road component must touch two squares. The converter paves the causeways (bridge cells), so
# a street crossing one is cut in two; a road piece that touches a causeway joins the piece on the other side
$pave = New-Object 'bool[]' ($conv.N * $conv.N); for ($i = 0; $i -lt $pave.Length; $i++) { $pave[$i] = $conv.Ground[$i] -eq 2 -and $conv.Valid[$i] }
$link = New-Object 'bool[]' ($conv.N * $conv.N); for ($i = 0; $i -lt $link.Length; $i++) { $link[$i] = $road[$i] -or ($pave[$i] -and $conv.Bridge[$i]) }
$seen = New-Object 'bool[]' ($conv.N * $conv.N); $free = 0; $comps = 0
for ($i = 0; $i -lt $road.Length; $i++) {
    if (-not $road[$i] -or $seen[$i]) { continue }
    $comps++; $q = New-Object 'Collections.Generic.Queue[int]'; $q.Enqueue($i); $seen[$i] = $true; $sqTouched = @{}
    while ($q.Count) {
        $c = $q.Dequeue(); $x = $c % $conv.N; $y = [Math]::Floor($c / $conv.N)
        foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
            $nx = $x + $d[0]; $ny = $y + $d[1]; if (-not $conv.In($nx, $ny)) { continue }
            $n = $conv.Idx($nx, $ny)
            if ($pave[$n]) { foreach ($k in $sq.Keys) { $w = $wpCell[$k]; if ([Math]::Abs($w[0] - $nx) -le 8 -and [Math]::Abs($w[1] - $ny) -le 8) { $sqTouched[$k] = 1 } } }
            if ($link[$n] -and -not $seen[$n]) { $seen[$n] = $true; $q.Enqueue($n) }
        }
    }
    if ($sqTouched.Count -lt 2) { $free++; "WARN road component $comps touches $($sqTouched.Count) square(s)" }
}
"roads: $comps component(s), free ends $free"

$conv.ApplyGround(0, $base, $lat)
# $DirX/$DirY, not $NX/$NY: PowerShell names are case-insensitive, so $nx below would overwrite the array
$DirX = 0, 1, 0, -1; $DirY = -1, 0, 1, 0
for ($y = 0; $y -lt $conv.N; $y++) { for ($x = 0; $x -lt $conv.N; $x++) {
    $i = $conv.Idx($x, $y); if (-not $conv.Valid[$i] -or $conv.Used[$i]) { continue }
    $g = $conv.Ground[$i]; if ($g -ne 2 -and $g -ne $RoadG) { continue }
    $mask = 0; $onlyPave = $true
    for ($d = 0; $d -lt 4; $d++) {
        $nx = $x + $DirX[$d]; $ny = $y + $DirY[$d]; if (-not $conv.In($nx, $ny)) { continue }
        $n = $conv.Idx($nx, $ny)
        $same = -not $conv.Used[$n] -and "$($conv.K[$n])" -ne 'Water' -and ($conv.Ground[$n] -eq $g -or ($g -eq 2 -and $conv.Ground[$n] -eq $RoadG))
        if ($same) { continue }
        $mask = $mask -bor (1 -shl $d)
        if ($conv.Used[$n] -or "$($conv.K[$n])" -eq 'Water' -or $conv.Ground[$n] -ne 2) { $onlyPave = $false }
    }
    $conv.Tile[$i] = if ($mask -eq 0) { $base[$g] } elseif ($g -eq $RoadG -and $onlyPave) { $roadOnPave + $mask } else { $lat[$g] + $mask }
    $conv.Sub[$i] = 0
} }

# ================================================================ dressing: sparse trees and scrub on open ground
$nearWp = New-Object 'bool[]' ($conv.N * $conv.N)
foreach ($k in $wpCell.Keys) { $c = $wpCell[$k]; for ($x = $c[0] - 4; $x -le $c[0] + 4; $x++) { for ($y = $c[1] - 4; $y -le $c[1] + 4; $y++) { if ($conv.In($x, $y)) { $nearWp[$conv.Idx($x, $y)] = $true } } } }
$nDeco = 0
for ($y = 1; $y -lt $conv.N - 1; $y++) { for ($x = 1; $x -lt $conv.N - 1; $x++) {
    $i = $conv.Idx($x, $y)
    if (-not (Passable $x $y) -or $nearWp[$i] -or $conv.Ground[$i] -eq 2 -or $conv.Ground[$i] -eq $RoadG) { continue }
    $open = $true
    for ($dx = -1; $dx -le 1; $dx++) { for ($dy = -1; $dy -le 1; $dy++) { if (($dx -or $dy) -and (-not (Passable ($x + $dx) ($y + $dy)) -or $road[$conv.Idx($x + $dx, $y + $dy)] -or $conv.Ground[$conv.Idx($x + $dx, $y + $dy)] -eq 2)) { $open = $false } } }
    if (-not $open) { continue }
    $chance = if ($conv.Ground[$i] -eq 3) { 0.025 } else { 0.01 }
    if ($rnd.NextDouble() -lt $chance) { $conv.Terrain[$y * 1000 + $x] = $trees[$rnd.Next($trees.Length)]; $nDeco++ }
} }
"dressing: $nDeco trees/bushes"

$conv.WallFrames(2, [int[]]@(0, 2, 4, 6))
$conv.CheckConnectivity()
$cmp = $conv.CompareWithSc(); $cmp.Save("$work\compare_sc.png"); $cmp.Dispose()
$text = $conv.WriteMap('ARKA #6: Ogien z nieba (teren)', 'Claude (kampania ARKA; teren: Blizzard T7 Biting the Bullet, port: Claude)')
$conv.Log | Set-Content "$work\log.txt" -Encoding UTF8
"converter: $($conv.Log.Count) log lines; starts $($conv.Starts.Count) connected=$($conv.StartsConnected) sealed $($conv.Sealed) leaks $($conv.Leaks) failed chains $($conv.ChainFailures)"
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::GetEncoding(1252))
$ini = [Ini]::Load($Out)
$ini.Set('Map', 'Theater', 'TEMPERATE')
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; $ini.Set('Waypoints', $k, "$($c[1] * 1000 + $c[0])") }
$ini.Set('Basic', 'Name', 'ARKA #6: Ogien z nieba (teren, Antiga Prime)')
$st = $ini.Section('Structures'); $nT = 0
for ($i = $st.Count - 1; $i -ge 0; $i--) { if ($st[$i].Value -match ',DBTMPL,') { $st.RemoveAt($i); $nT++ } }
if ($nT) { "removed $nT converter temple(s) (DBTMPL)" }
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
foreach ($k in $wps.Keys) { $c = $wpCell[$k]; "wp $k path $($dist[$conv.Idx($c[0], $c[1])]) cells ($($wps[$k][2]))"; if (-not $reach[$conv.Idx($c[0], $c[1])]) { "WARN wp $k ($($wps[$k][2])) not reachable from ARKA by ground (conservative test)"; $fail++ } }
"CHECKS: " + $(if ($fail) { "$fail waypoint(s) unreachable" } else { "PASS (all $($wps.Count) waypoints reachable from ARKA)" }) + "; road free ends $free"

# ================================================================ pictures: SC grid for planning, waypoints on the cell map
$g0 = [Drawing.Image]::FromFile("$work\sc.png")
$grid = New-Object Drawing.Bitmap 2048, 2048; $g = [Drawing.Graphics]::FromImage($grid); $g.DrawImage($g0, 0, 0, 2048, 2048); $g0.Dispose()
$pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(110, 255, 255, 255)), 1; $font = New-Object Drawing.Font 'Arial', 8
for ($k = 0; $k -le 128; $k += 4) { $g.DrawLine($pen, $k * 16, 0, $k * 16, 2048); $g.DrawLine($pen, 0, $k * 16, 2048, $k * 16); $g.DrawString("$k", $font, [Drawing.Brushes]::White, $k * 16 + 1, 1); $g.DrawString("$k", $font, [Drawing.Brushes]::White, 1, $k * 16 + 1) }
$cw = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(200, 255, 160, 0)), 24
foreach ($k in $causeways.Keys) { $c = $causeways[$k]; $g.DrawLine($cw, $c[0] * 16 + 8, $c[1] * 16 + 8, $c[2] * 16 + 8, $c[3] * 16 + 8) }
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
