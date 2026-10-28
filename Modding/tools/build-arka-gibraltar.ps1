# Builds the terrain map of the ARKA campaign prelude "Ostatnia brama" (Gibraltar, 1953), version 2.
# Sources (Modding\raw\maps\): gibraltar-google.png (620x930 Google Maps screenshot: water, design space),
# gibraltar-geo\osm\*.osm (OpenStreetMap: roads, buildings, land use, attractions) and gibraltar-geo\dem15\
# (Terrarium elevation: the two levels of the Rock). Fetch new data with fetch-geodata.ps1.
# Coordinates below are screenshot pixels ("design px"); y < 0 is Spain north of the screenshot. OSM and DEM
# are projected into them by GeoRef (fitted to named places, then to the coastline).
#
#   .\build-arka-gibraltar.ps1                 # build Maps\Custom\arka00_gibraltar.map + preview + checks
#   .\build-arka-gibraltar.ps1 -DesignOnly     # only render the design layers (work dir) for tuning
#
# Waypoint NUMBERS 10-45 are a contract with the mission layer (build-arka00-mission.ps1): never renumber.
# Version 1 (hand-drawn Rock, pavement roads): Modding\archive\arka00-gibraltar-v1_2026-10-26.
param(
    [string]$Out = "",
    [string]$Work = "$env:TEMP\arka-gibraltar",
    [switch]$DesignOnly,
    [switch]$NoPreview
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
$raw   = "$game\Modding\raw\maps"
if (-not $Out) { $Out = "$game\Maps\Custom\arka00_gibraltar.map" }
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScMap.cs", "$tools\TsMap.cs", "$tools\ScToDta.cs", "$tools\DesignToDta.cs", "$tools\GeoData.cs" -ReferencedAssemblies System.Drawing, System.Xml
New-Item -ItemType Directory -Force $Work | Out-Null
$shot = [Drawing.Bitmap]::FromFile("$raw\gibraltar-google.png")

# design canvas (bigger than the visible rectangle so edge cells sample real data)
$U0 = 0; $V0 = -80; $DW = 640; $DH = 1020
# visible rectangle in design px and map size in cells (about 7.8 x 4.5 design px per cell)
$du0 = 115; $du1 = 590; $dv0 = -60; $dv1 = 930
$localW = 60; $localH = 220; $padX = 2; $padTop = 5; $padBottom = 4
# Rock levels (metres, DEM): level 1 = Upper Rock, level 2 = the crest
$elev1 = 100; $elev2 = 220

function P([double[]]$pts) { , $pts }
function DesignOf($lat, $lon) { $u = 0.0; $v = 0.0; $geo.ToDesign($lat, $lon, [ref]$u, [ref]$v); , @($u, $v) }

# ---------------------------------------------------------------- real-world data
$osm = New-Object Osm
foreach ($f in Get-ChildItem "$raw\gibraltar-geo\osm\*.osm") { $osm.Load($f.FullName) }
$geo = New-Object GeoRef
$ctrl = [ordered]@{ 'Trafalgar Cemetery' = @(320, 438); "Michael's Cave" = @(421, 594); 'Morrisons' = @(213, 272); 'The Clipper' = @(298, 309); 'Sunborn' = @(298, 198); 'Eastern Beach' = @(507, 195) }
$cp = New-Object 'System.Collections.Generic.List[double[]]'
foreach ($k in $ctrl.Keys) { $f = $osm.Find($k); if ($f.Count -gt 0) { $cp.Add([double[]]@($f[0][0], $f[0][1], $ctrl[$k][0], $ctrl[$k][1])) } }
$fitIcons = $geo.Fit($cp)
$wm = New-Object Layer 0, 0, 620, 930, 1
$wm.FromColor($shot, 0, 0, 144, 217, 237, 40, 0)
$edge = [GeoRef]::EdgeDistance($wm, 0)
$coast = New-Object 'System.Collections.Generic.List[double[]]'
foreach ($w in $osm.Select('natural', 'coastline')) { foreach ($n in $w.Nodes) { $ll = $null; if ($osm.Nodes.TryGetValue($n, [ref]$ll)) { $d = DesignOf $ll[0] $ll[1]; if ($d[0] -gt 5 -and $d[0] -lt 615 -and $d[1] -gt 5 -and $d[1] -lt 925) { $coast.Add($ll) } } } }
$fitCoast = $geo.RefineToEdge($coast, $edge, $wm, 350, 500)
$dem = New-Object Dem "$raw\gibraltar-geo\dem15", 15
$elev = $dem.Grid($geo, $U0, $V0, $DW, $DH)
"georef: icons rms $([Math]::Round($fitIcons, 1)) px, coastline mean $([Math]::Round($fitCoast, 2)) px, $([Math]::Round($geo.MetresPerPx(36.14), 2)) m/px"

# ---------------------------------------------------------------- kind: water / low / Rock level 1 / level 2
$W_ = [DesignToDta]::KWater; $L_ = [DesignToDta]::KLow; $H_ = [DesignToDta]::KHigh; $H2 = [DesignToDta]::KHigh2
$kind = New-Object Layer $U0, $V0, $DW, $DH, $L_
$kind.FromColor($shot, 0, 0, 144, 217, 237, 40, $W_)
# north of the screenshot: the bay goes on in the west, the Mediterranean in the east, La Linea between
$kind.Polygon((P 0,-80, 155,-80, 155,-10, 212,-4, 212,2, 0,2), $W_, 255)
$kind.Polygon((P 523,-80, 640,-80, 640,2, 523,2), $W_, 255)
# map labels and thin moles drawn over the water, marina slips simplified to plain basins
$kind.Line((P 150,462, 255,622), 14, $W_, 255)                              # Detached Mole
$kind.Polygon((P 250,866, 348,866, 348,896, 250,896), $W_, 255)             # "Europa Point Lighthouse"
$kind.Polygon((P 172,424, 238,424, 238,470, 172,470), $W_, 255)             # "Trafalgar Cemetery" + pier
$kind.Polygon((P 115,182, 212,182, 212,297, 115,297), $W_, 255)             # Marina Bay (west marina)
$kind.Polygon((P 212,182, 305,182, 305,203, 212,203), $W_, 255)             # Ocean Village basin
$kind.Polygon((P 255,203, 305,203, 305,248, 255,248), $L_, $W_)             # Ocean Village slip -> land
$kind.Polygon((P 155,0, 213,0, 213,98, 155,98), $W_, 255)                   # La Linea marina
$kind.Polygon((P 212,98, 333,98, 333,156, 212,156), $W_, 255)               # bay inlet north of the runway
$kind.Polygon((P 213,42, 303,42, 303,97, 213,97), $W_, 255)                 # La Linea port basin
$kind.Polygon((P 238,395, 288,395, 302,568, 272,578, 238,525), $L_, $W_)    # Dockyard as one quay
$kind.Polygon((P 262,558, 306,558, 306,596, 262,596), $L_, $W_)             # ...and its south basin
$kind.Polygon((P 202,536, 224,536, 268,604, 258,618), $W_, 255)             # stub of the Detached Mole
# the runway jetty in the bay is too narrow for water cliffs on both sides: the runway starts at the coast
$kind.Polygon((P 205,150, 335,150, 335,188, 205,188), $W_, 255)
$kind.Vote($W_, $L_, 3, 0.5)
[void]$kind.RemoveSmall($L_, $W_, 400)
[void]$kind.RemoveSmall($W_, $L_, 300)
# south of Catalan Bay the "EAST SIDE" label of the screenshot left a water notch and a land tongue in the sea (cells
# about 147-156, 114-122 came out as a staircase, user 2026-10-27): the coast follows the real shoreline of the
# screenshot instead, (525,342) -> (501,362) -> (494,372) -> (492,397)
$kind.Polygon((P 470,340, 525,340, 501,362, 494,372, 492,398, 470,398), $L_, $W_)            # notch -> land
$kind.Polygon((P 525,340, 565,340, 565,398, 492,398, 494,372, 501,362), $W_, $L_)            # tongue -> sea

# the Rock from the DEM: level 1 above $elev1, level 2 (crest) above $elev2
$kind.FromGrid($elev, $elev1, $H_, $L_)
$kind.FromGrid($elev, $elev2, $H2, $H_)
# east lane (Sir Herbert Miles Road): the Rock drops into the sea there, so land within 48 px of the east coast
# stays low ground for cliffs, shore and a road; its edge follows the real coastline (48 px = 6 cells)
$kind.NearLabel($H2, $W_, 48, $L_, 395, 640, 230, 840)
$kind.NearLabel($H_, $W_, 48, $L_, 395, 640, 230, 840)
$kind.Vote($H_, $L_, 4, 0.5)
# the crest keeps about 2-3 cells of level 1 around it (two cliff lines need room)
$kind.NearLabel($H2, $L_, 18, $H_, 0, 640, -80, 940)
$kind.Vote($H2, $H_, 7, 0.5)   # a wide vote: the crest outline from DEM steps is blocky
[void]$kind.RemoveSmall($H2, $H_, 600)
[void]$kind.RemoveSmall($H_, $L_, 800)

# ramps (snapped to the level edge near the real roads up the Rock); no ramps on the east cliffs
$rampL = New-Object Layer $U0, $V0, $DW, $DH, 0
$rampSeeds = [ordered]@{
    'NW' = @(352, 335, 'L1', "Willis's Road (Moorish Castle)")
    'W'  = @(352, 478, 'L1', "Gardiner's Road / Alameda (dolna stacja kolejki)")
    'SW' = @(372, 612, 'L1', "Queen's Road / South Barrack Road (St Michael's Cave)")
    'S'  = @(425, 818, 'L1', 'Windmill Hill Road')
    'C1' = @(395, 430, 'L2', 'Middle Hill (gorna stacja kolejki)')
    'C2' = @(440, 640, 'L2', 'Spur Battery Road')
    # the pass from the east lane (Catalan Bay) onto the Rock ore was one cell wide: the level-1 cliff (cells x 151-153,
    # y 120-133) ended one row above the crest cliff (y 135). A ramp at the foot of that cliff, about cell 152,131,
    # widens it to ~6 cells (user 2026-10-27; route of the Soviet ambush, mission wp 61-63)
    'E'  = @(436, 410, 'L1', 'przesmyk od Catalan Bay (zasadzka na zloze na Skale)')
}
$rampAt = [ordered]@{}
foreach ($k in $rampSeeds.Keys) {
    $s = $rampSeeds[$k]
    $hit = if ($s[2] -eq 'L1') { $kind.NearestEdge($s[0], $s[1], $H_, $L_, 45) } else { $kind.NearestEdge($s[0], $s[1], $H2, $H_, 45) }
    if (-not $hit) { "WARN ramp $k : no level edge near $($s[0]),$($s[1])"; continue }
    $rampL.Disc($hit[0], $hit[1], 13, 1, 255)
    $rampAt[$k] = $hit
}

# ---------------------------------------------------------------- ground: 0 grass, 1 dirt, 2 pavement, 3 tall grass
$ground = New-Object Layer $U0, $V0, $DW, $DH, 0
$ground.Where($kind, $H_, 1, 255); $ground.Where($kind, $H2, 1, 255)   # the Rock is dirt...
$ground.FromGreen($shot, 0, 0, 10, 3, 0)              # parks on low ground: tall grass
$ground.FromGreen($shot, 0, 0, 10, 0, 1)              # ...with green patches (Upper Rock macchia)
[void]$osm.FillAreas($ground, $geo, 'landuse', 'farmland,meadow,grass,village_green', 0, 255)
[void]$osm.FillAreas($ground, $geo, 'landuse', 'industrial,port,railway,commercial,retail', 2, 255)   # not military: MOD land covers half of Gibraltar
[void]$osm.FillAreas($ground, $geo, 'aeroway', 'apron', 2, 255)
[void]$osm.FillAreas($ground, $geo, 'amenity', 'parking', 2, 255)
[void]$osm.FillAreas($ground, $geo, 'leisure', 'park,garden', 3, 255)
$ground.Polygon((P 165,-55, 230,-58, 290,-40, 280,-12, 200,-8, 168,-25), 1, 0)   # fields around La Linea
$ground.Polygon((P 405,-55, 470,-58, 515,-45, 505,-28, 440,-22, 410,-35), 1, 0)
$ground.Polygon((P 216,156, 502,156, 502,181, 216,181), 2, 255)   # runway
$ground.Polygon((P 238,398, 288,398, 300,565, 272,575, 240,522), 2, 255)   # Dockyard
$ground.Polygon((P 283,258, 322,258, 322,286, 283,286), 2, 255)   # Casemates Square

# ---------------------------------------------------------------- zones: 1 beach, 2 trees, 3 sparse trees, 9 base (kept empty)
$zone = New-Object Layer $U0, $V0, $DW, $DH, 0
$zone.FromGreen($shot, 0, 0, 10, 2, 0)
[void]$osm.FillAreas($zone, $geo, 'natural', 'wood,scrub,heath', 2, 255)
[void]$osm.FillAreas($zone, $geo, 'landuse', 'forest', 2, 255)
[void]$osm.FillAreas($zone, $geo, 'landuse', 'cemetery', 2, 255)
$zone.Polygon((P 160,-60, 520,-60, 520,95, 160,95), 3, 0)          # La Linea outskirts
$zone.Polygon((P 355,700, 445,700, 445,860, 355,860), 3, 0)        # South District
$zone.Polygon((P 455,262, 640,262, 640,840, 430,840), 3, 2)        # east lane: sparse trees only
# the player's base (North District, old town): no trees, no civilian buildings
$zone.Polygon((P 214,252, 372,252, 372,300, 360,330, 352,410, 300,415, 236,412, 222,330), 9, 255)
$beaches = [ordered]@{
    'Playa de Levante (Hiszpania)' = (P 500,-60, 545,-60, 545,100, 500,100)
    'Eastern Beach'                = (P 490,125, 545,125, 545,245, 490,245)
    'Catalan Bay'                  = (P 490,305, 545,305, 545,390, 490,390)
    'Sandy Bay'                    = (P 485,430, 545,430, 545,475, 485,475)
    'Camp Bay'                     = (P 282,676, 332,676, 332,742, 282,742)
    'Little Bay / Europa Point'    = (P 300,820, 455,820, 455,925, 300,925)
}
foreach ($b in $beaches.Values) { $zone.Polygon($b, 1, 255) }

# building cover from OSM footprints: 1 houses, 2 industrial/port, 3 church, 4 hospital
$bcov = New-Object Layer $U0, $V0, $DW, $DH, 0
[void]$osm.FillAreas($bcov, $geo, 'building', '*', 1, 255)
[void]$osm.FillAreas($bcov, $geo, 'building', 'industrial,warehouse,hangar,storage_tank,shed,service,depot', 2, 255)
$ind = New-Object Layer $U0, $V0, $DW, $DH, 0
[void]$osm.FillAreas($ind, $geo, 'landuse', 'industrial,port,railway', 1, 255)
$bcov.Where($ind, 1, 2, 1)
[void]$osm.FillAreas($bcov, $geo, 'building', 'church,cathedral,chapel', 3, 255)
[void]$osm.FillAreas($bcov, $geo, 'amenity', 'hospital', 4, 255)

function Save-Layer($layer, [int[]]$pal, [string]$name) {
    $b = $layer.Render($pal)
    $g = [Drawing.Graphics]::FromImage($b)
    $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(90, 255, 0, 0)), 1
    $f = New-Object Drawing.Font 'Arial', 8
    for ($x = 0; $x -le 640; $x += 20) { $g.DrawLine($pen, $x - $U0, 0, $x - $U0, $DH) }
    for ($y = -80; $y -le 940; $y += 20) { $g.DrawLine($pen, 0, $y - $V0, $DW, $y - $V0) }
    for ($x = 0; $x -le 600; $x += 100) { for ($y = 0; $y -le 900; $y += 100) { $g.DrawString("$x,$y", $f, [Drawing.Brushes]::Red, $x - $U0 + 1, $y - $V0 + 1) } }
    $g.DrawRectangle([Drawing.Pens]::Black, $du0 - $U0, $dv0 - $V0, $du1 - $du0, $dv1 - $dv0)
    $g.Dispose(); $b.Save("$Work\$name.png"); $b.Dispose()
}
function Argb($r, $g, $b) { [Drawing.Color]::FromArgb($r, $g, $b).ToArgb() }
$kpal = [int[]]@((Argb 40 80 190), (Argb 235 235 225), (Argb 190 140 70), (Argb 40 200 40), (Argb 110 55 20))
$kind2 = New-Object Layer $U0, $V0, $DW, $DH, 0; $kind2.L = $kind.L.Clone(); $kind2.Where($rampL, 1, 3, 255)
Save-Layer $kind2  $kpal 'design_kind'
Save-Layer $ground ([int[]]@((Argb 120 190 90), (Argb 170 130 80), (Argb 150 150 150), (Argb 40 110 40))) 'design_ground'
Save-Layer $zone   ([int[]]@((Argb 235 235 225), (Argb 240 220 120), (Argb 30 120 30), (Argb 140 200 140), 0, 0, 0, 0, 0, (Argb 230 120 120))) 'design_zone'
Save-Layer $bcov   ([int[]]@((Argb 235 235 225), (Argb 120 120 120), (Argb 60 60 160), (Argb 200 60 60), (Argb 60 160 60))) 'design_buildings'
if ($DesignOnly) { "design layers in $Work"; return }

# ---------------------------------------------------------------- cells, cliffs, shores, water
$mixes = New-Object MixSet "$game\MIX"
$th    = New-Object Theater "$game\INI\Temperat.ini", "tem", $mixes
$wae   = "$game\Map Editor\Editor\Config\ConnectedTileDrawer.ini"
$cliffSet  = New-Object ConnectedSet $wae, "TemperateCliffSet", $th
$wcliffSet = New-Object ConnectedSet $wae, "TemperateWaterCliffSet", $th
$beachSet  = New-Object ConnectedSet $wae, "TemperateShoreSet", $th
$plainWater = $th.SetByName('Water').Start

$conv = New-Object DesignToDta $th, $localW, $localH, $padX, $padTop, $padBottom, $du0, $dv0, $du1, $dv1
$conv.Classify($kind, $ground, $zone, $rampL, 40)
$conv.Cliffs($cliffSet)
# hard coast = Water Cliffs; beaches = Shores (hovercraft and landing craft need a passable beach)
$notBeach = [ScToDta+CellPred]{ param($i) $conv.Zone[$i] -ne 1 }
$isBeach  = [ScToDta+CellPred]{ param($i) $conv.Zone[$i] -eq 1 }
$conv.Shores($wcliffSet, $true, $notBeach)
$conv.Beaches($beachSet, $isBeach)
# (a second Beaches pass over the bare gaps, BeachMinArc = 2, put lone beach pieces out in the sea: not used)

$conv.SettleWater()
[void]$conv.DrownSpecks(40)   # strips left outside a beach chain; real land pieces are hundreds of cells
$conv.MarkCoastPieces()
$conv.FillWater($th.SetByName('Animated Water'), $plainWater)
$rawBefore = $conv.RawCoast().Count
[void]$conv.DrownRawCoast(3, $plainWater)

function Cell($u, $v) { $conv.CellAt($u, $v) }
function XY($c) { "{0},{1}" -f ($c % $conv.N), [Math]::Floor($c / $conv.N) }
# plots kept empty for the mission author (ARKA, power plants, staging areas) + the whole base zone;
# reserved before the roads, which keep off the plots
$conv.Reserve(300, 335, 4, 4)
foreach ($pp in @(@(262, 300, 2), @(338, 300, 2), @(262, 378, 2), @(336, 382, 3))) { $conv.Reserve($pp[0], $pp[1], $pp[2], $pp[2]) }
$conv.Reserve(290, -30, 5, 5); $conv.Reserve(470, -35, 5, 5); $conv.Reserve(440, 35, 2, 2)
$plotCells = New-Object 'System.Collections.Generic.HashSet[int]' (, [int[]]@($conv.Reserved))
$conv.RoadAvoid = $plotCells
[void]$conv.ReserveZone(9)

# Northern Defences (concrete wall) with Landport and Waterport gates; roads cross it only at the gates
$wall = New-Object 'System.Collections.Generic.List[int]'
foreach ($seg in @(@(212, 248, 238, 248), @(258, 248, 328, 248), @(354, 248, 410, 253))) {
    $wall.AddRange($conv.CellLine($seg[0], $seg[1], $seg[2], $seg[3]))
}
foreach ($c in $wall) { [void]$plotCells.Add($c) }   # $plotCells is $conv.RoadAvoid

# ---------------------------------------------------------------- roads (OSM main roads) as Paved Road LAT
# DTA paints roads as Paved Road LAT and every road leads somewhere (another road, the map edge, a square); the tile
# roads of v2 broke into stubs that ended in the grass (review 2026-10-27). FinishRoads links each free end to a road
# within 10 cells or cuts it back to its last junction (wiki workflow/mission-maps).
$roadWays = New-Object 'System.Collections.Generic.List[OsmWay]'
# main roads only: a road is 2 cells wide, tertiary streets too filled the old town with parallel strips
foreach ($w in $osm.Select('highway', 'trunk,primary,secondary,trunk_link,primary_link,secondary_link')) { $roadWays.Add($w) }
$junctions = New-Object 'System.Collections.Generic.List[long]'
$chains = $osm.Chains($roadWays, $junctions)
foreach ($ch in $chains) { $conv.RoadLat($osm.DesignNodes($ch, $geo)) }
$conv.FinishRoads(10, 30)
"roads: $($roadWays.Count) OSM ways -> $($chains.Count) chains, $($conv.RoadCells) road cells"

# ---------------------------------------------------------------- objects
$wallCells = $conv.OverlayCells($wall, 2, 0)

# ore ("gold"; review 2026-10-27: nothing to harvest, ~15 cells in v2): a big field on the Rock (level 1 north of the
# crest, up the NW ramp from the base: rich but exposed), the contested airfield field, and in the south an Ore Mine
# (TerrainType OREMINE, TiberiumToSpawn=3: grows ore round itself) with its field on Windmill Hill
$ore = 0
function Put-Ore($cells, [double]$p) {
    foreach ($c in $cells) {
        if ($conv.Rnd.NextDouble() -ge $p) { continue }
        $l = New-Object 'System.Collections.Generic.List[int]'; $l.Add($c)
        $script:ore += $conv.OverlayCells($l, [byte](147 + $conv.Rnd.Next(4)), [byte](5 + $conv.Rnd.Next(7)))
    }
}
$oreL = New-Object Layer $U0, $V0, $DW, $DH, 0
$oreL.Polygon((P 372,258, 472,258, 472,296, 410,300, 404,398, 366,400, 358,330), 1, 255)   # the Rock, level 1
$oreL.Disc(445, 128, 24, 2, 255)                                                            # airfield (contested)
$oreL.Disc(378, 768, 26, 3, 255)                                                            # Windmill Hill (south)
Put-Ore ($conv.CellsIn($oreL, 1, 1)) 0.85
Put-Ore ($conv.CellsIn($oreL, 2, 0)) 0.75
# the mine: the free cell nearest to the field centre (Free: not road, ramp, plot, tree or building)
$mineCell = -1
$c0 = Cell 378 768; $cx = $c0 % $conv.N; $cy = [Math]::Floor($c0 / $conv.N)
for ($r = 0; $r -le 6 -and $mineCell -lt 0; $r++) {
    for ($y = $cy - $r; $y -le $cy + $r -and $mineCell -lt 0; $y++) { for ($x = $cx - $r; $x -le $cx + $r; $x++) {
        if ([Math]::Max([Math]::Abs($x - $cx), [Math]::Abs($y - $cy)) -eq $r -and $conv.Free($x, $y)) { $mineCell = $y * $conv.N + $x; break }
    } }
}
$mines = 0
if ($mineCell -ge 0) { $conv.Terrain[[int]([Math]::Floor($mineCell / $conv.N) * 1000 + $mineCell % $conv.N)] = 'OREMINE'; $mines = 1 } else { 'WARN no free cell for the Ore Mine' }
Put-Ore ($conv.CellsIn($oreL, 3, 0)) 0.7

# attractions and landmarks: OSM position (by name or tag), else the given design point
$placed = @{}
function Place-Civ([string]$type, [int]$fw, [int]$fh, [double]$u, [double]$v, [double]$ru, [double]$rv, [int]$count) {
    $n = 0
    for ($k = 0; $k -lt 200 -and $n -lt $count; $k++) {
        $c = Cell ($u + ($conv.Rnd.NextDouble() * 2 - 1) * $ru * [Math]::Min(1, $k / 20 + 0.1)) ($v + ($conv.Rnd.NextDouble() * 2 - 1) * $rv * [Math]::Min(1, $k / 20 + 0.1))
        if ($conv.PlaceBuilding('Neutral', $type, $fw, $fh, $c % $conv.N, [Math]::Floor($c / $conv.N))) { $n++ }
    }
    $script:placed[$type] = $n + $script:placed[$type]
    $n
}
$landmarks = @(
    # name or tag=value | type | fw fh | fallback u v | spread
    @('Tower of Homage', 'RUS02A', 1, 1, 352, 318, 6),
    @('Great Siege Tunnels', 'DBTWR', 1, 1, 430, 262, 8),
    @('Great Siege Tunnels', 'AMMOCRAT', 1, 1, 430, 262, 10),
    @('World War II Tunnels', 'AMMOCRAT', 1, 1, 405, 300, 8),
    @("O'Hara's Battery", 'DBATWR', 1, 1, 440, 700, 8),
    @("Princess Caroline's Battery", 'DBTWR', 1, 1, 420, 300, 8),
    @("Princess Anne's Battery", 'DBTWR', 1, 1, 450, 330, 8),
    @("Lord Airey's Battery", 'DBTWR', 1, 1, 435, 560, 8),
    @('100 Ton Gun', 'DBATWR', 1, 1, 330, 700, 8),
    @("Devil's Gap Battery", 'DBTWR', 1, 1, 390, 470, 8),
    @("St Michael's Cave", 'CA0008', 2, 2, 421, 594, 10),
    @("Apes' Den", 'CMPFRA', 1, 1, 410, 560, 8),
    @('The convent', 'V01', 1, 1, 315, 440, 6),
    @("King's Chapel", 'V25', 1, 1, 318, 446, 6),
    @('man_made=lighthouse', 'LHUS', 1, 1, 425, 878, 8),
    @('Windmill Hill Batteries', 'WDML', 1, 1, 395, 845, 10),
    @('aeroway=terminal', 'HANGAR', 2, 3, 395, 120, 12),
    @('amenity=hospital', 'HOSP', 2, 2, 352, 700, 10)
)
$landLog = @()
foreach ($lm in $landmarks) {
    # (assign the List directly: `$x = if (...) { List }` unrolls a one-item list into the bare {lat, lon})
    if ($lm[0] -match '^(\w+)=(\w+)$') { $pos = $osm.Points($matches[1], $matches[2]) } else { $pos = $osm.Find($lm[0]) }
    $uv = @($lm[4], $lm[5]); $bestD = 1e9
    foreach ($q in $pos) { $d = DesignOf $q[0] $q[1]; $dd = [Math]::Pow($d[0] - $lm[4], 2) + [Math]::Pow($d[1] - $lm[5], 2); if ($dd -lt $bestD -and $dd -lt 120 * 120) { $bestD = $dd; $uv = $d } }
    $got = Place-Civ $lm[1] $lm[2] $lm[3] $uv[0] $uv[1] $lm[6] ($lm[6] * 0.6) 1
    # the Convent's church holds the money crate of the mission layer (waypoint 46 = a free cell at its door)
    if ($got -and $lm[0] -eq 'The convent') { $p = $conv.Buildings[$conv.Buildings.Count - 1] -split ','; $conventCell = [int]$p[4] * $conv.N + [int]$p[3] }
    $landLog += "{0,-28} {1,-8} at {2:F0},{3:F0} ({4}) {5}" -f $lm[0], $lm[1], $uv[0], $uv[1], $(if ($bestD -lt 1e9) { 'OSM' } else { 'fallback' }), $(if ($got) { 'OK' } else { 'no room' })
}
# port and industry (west side: Dockyard, Coaling Island, North Mole, Europort): warehouses, sheds, tanks, cranes
Place-Civ 'CRANE' 1 1 270 470 18 60 4 | Out-Null
Place-Civ 'CRANE' 1 1 232 360 12 20 2 | Out-Null
Place-Civ 'CA0011' 1 2 160 330 25 30 3 | Out-Null       # fuel tanks on the North Mole side
$indN = $conv.PlaceOnCover($bcov, 2, [string[]]@('CITY09', 'CITY09', 'NV18', 'NV17', 'STEELCRATE', 'WOODCRATE', 'RABARL'), 1, 1, 0.4, 0.75, 'Neutral')
$churchN = $conv.PlaceOnCover($bcov, 3, [string[]]@('V01', 'V25'), 1, 1, 0.4, 1.0, 'Neutral')
$bigN = $conv.PlaceOnCover($bcov, 1, [string[]]@('V03', 'CITY10'), 2, 2, 0.8, 0.12, 'Neutral')
$houseN = $conv.PlaceOnCover($bcov, 1, [string[]]@('V02', 'V04', 'V05', 'V06', 'V07', 'V08', 'V09', 'V10', 'V11', 'CITY09'), 1, 1, 0.4, 0.5, 'Neutral')

$trees = [string[]]@('T01','T02','T03','T05','T06','T07','T08','T09','T10','T11','T12','T13','T14','T15','T16','T17')
$treeCount = $conv.PlaceTrees(2, $trees, 0.22) + $conv.PlaceTrees(3, $trees, 0.05)

$conv.SmoothGround(2)
$base = [int[]]@(0, $th.SetByName('Dirt LAT').Start, $th.SetByName('Pavement LAT').Start, $th.SetByName('Tall Grass').Start, $th.SetByName('Paved Road LAT & addons').Start)
$lat  = [int[]]@(0, $th.SetByName('Clear/Dirt LAT').Start, $th.SetByName('Clear/Pavement LAT').Start, $th.SetByName('Tall/Short Grass LAT').Start, $th.SetByName('Clear/Paved Road LAT').Start)
$conv.ApplyGroundRoads(0, $base, $lat, $th.SetByName('Pavement/Paved Road LAT').Start)
$conv.WallFrames(2, [int[]]@(0, 2, 4, 6))
$rawAfter = $conv.RawCoast()

# ---------------------------------------------------------------- waypoints (10+ for the mission; 0/1 = skirmish test starts)
$wp = [ordered]@{
    '10' = @('ARKA (srodek dzialki 9x9)', 300, 335, 'g')
    '11' = @('Elektrownia 1 (NW)', 262, 300, 'g'); '12' = @('Elektrownia 2 (NE)', 338, 300, 'g')
    '13' = @('Elektrownia 3 (SW)', 262, 378, 'g'); '14' = @('Elektrownia 4 (SE)', 336, 382, 'g')
    '15' = @('Brama Landport (mur polnocny, droga z lotniska)', 341, 250, 'g')
    '16' = @('Brama Waterport (mur polnocny, zachod)', 248, 250, 'g')
    '17' = @('Tanya: park w La Linea (za liniami wroga)', 440, 35, 'g')
    '18' = @('Sowieci: zbiorka NW (La Linea)', 290, -30, 'g')
    '19' = @('Sowieci: zbiorka NE (La Linea)', 470, -35, 'g')
    '20' = @('Przejscie graniczne (Winston Churchill Ave)', 382, 105, 'g')
    '21' = @('Pas startowy, skrzyzowanie z droga', 378, 168, 'g')
    '22' = @('Devil''s Tower Rd (pod polnocna sciana Skaly)', 470, 215, 'g')
    '23' = @('Ladowisko: Eastern Beach', 515, 185, 'g')
    '24' = @('Ladowisko: Catalan Bay', 505, 345, 'g')
    '25' = @('Pas wschodni, odcinek tunelu (Dudley Ward)', 482, 690, 'g')
    '26' = @('Ladowisko: Camp Bay (zachod, poludnie miasta)', 305, 712, 'g')
    '27' = @('Ladowisko: Europa Point', 395, 895, 'g')
    '28' = @('Skala: gora rampy NW', 0, 0, 'NW1'); '29' = @('Skala: dol rampy NW', 0, 0, 'NW0')
    '30' = @('Skala: gora rampy SW', 0, 0, 'SW1'); '31' = @('Skala: dol rampy SW', 0, 0, 'SW0')
    '32' = @('Skala: gora rampy S', 0, 0, 'S1'); '33' = @('Skala: dol rampy S', 0, 0, 'S0')
    '34' = @('Skala: szczyt polnocny (baterie)', 440, 280, 'g')
    '35' = @('Skala: Middle Hill (gran, poziom 2)', 0, 0, 'C12')
    '36' = @('Latarnia Europa Point', 425, 878, 'g')
    '37' = @('Doki (Dockyard)', 270, 480, 'g')
    '38' = @('Ruda: Windmill Hill', 372, 765, 'g')
    '39' = @('Ruda: lotnisko (sporna)', 445, 128, 'g')
    '40' = @('Morze: zatoka, wejscie od polnocnego zachodu', 150, -40, 'w')
    '41' = @('Morze: zatoka przy dokach', 200, 400, 'w')
    '42' = @('Morze: Morze Srodziemne, wschod', 565, 450, 'w')
    '43' = @('Morze: poludnie (Ciesnina)', 300, 915, 'w')
    '44' = @('Morze: zatoka przy pasie startowym', 160, 160, 'w')
    '45' = @('Morze: wschod, przy Eastern Beach', 565, 180, 'w')
    # 46+ added 2026-10-27 (review): append only, 10-45 keep their numbers
    '46' = @('Kosciol The Convent: skrzynka z pieniedzmi (przy drzwiach)', 0, 0, 'church')
    '47' = @('Ruda: Skala, poziom 1 (zloze zlota na gorze)', 385, 330, 'g')
}
$points = [ordered]@{}
foreach ($k in $wp.Keys) {
    $w = $wp[$k]
    if ($w[3] -match '^([A-Z]+\d?)(\d)$' -and $rampAt.Contains($matches[1])) {
        # ramp top/bottom: nearest cell of that level to the ramp centre (level 0 = low ground)
        $r = $rampAt[$matches[1]]; $points[$k] = $conv.NearestOfLevel((Cell $r[0] $r[1]), [int]$matches[2])
    }
    elseif ($w[3] -eq 'church') { $points[$k] = if ($conventCell) { $conv.Nearest($conventCell, $false) } else { -1 } }
    elseif ($k -eq '47') { $points[$k] = $conv.NearestOfLevel((Cell $w[1] $w[2]), 1) }
    else { $points[$k] = $conv.Nearest((Cell $w[1] $w[2]), $w[3] -eq 'w') }
}
# skirmish test starts: player at the ARKA plot, enemy in Spain
foreach ($s in @(@(0, 300, 335), @(1, 380, -40))) { $c = $conv.Nearest((Cell $s[1] $s[2]), $false); $conv.Starts.Add([int[]]@($s[0], ($c % $conv.N), [Math]::Floor($c / $conv.N))) }

# ---------------------------------------------------------------- checks
$conv.CheckConnectivity()
$checks = @(
    @(18, 10, 'Hiszpania -> ARKA'), @(23, 10, 'Eastern Beach -> ARKA'), @(24, 27, 'Catalan Bay -> Europa Point (pas wschodni)'),
    @(26, 10, 'Camp Bay -> ARKA'), @(29, 28, 'rampa NW'), @(31, 30, 'rampa SW'), @(33, 32, 'rampa S'), @(10, 34, 'ARKA -> szczyt Skaly'),
    @(10, 35, 'ARKA -> gran (poziom 2)'), @(17, 18, 'Tanya -> zbiorka sowiecka'), @(10, 38, 'ARKA -> ruda Windmill Hill'), @(10, 37, 'ARKA -> doki'),
    @(10, 46, 'ARKA -> kosciol (skrzynka)'), @(10, 47, 'ARKA -> ruda na Skale'), @(10, 39, 'ARKA -> ruda lotnisko')
)
$checkLines = foreach ($ck in $checks) { "{0,-44} {1}" -f $ck[2], $(if ($conv.Connected($points["$($ck[0])"], $points["$($ck[1])"])) { 'OK' } else { 'BRAK' }) }
$conv.FlushBuildings()
$text = $conv.WriteMap("ARKA 0: Ostatnia brama (Gibraltar 1953)", "Claude (kampania ARKA)")
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::GetEncoding(1252))
$ini = [Ini]::Load($Out)
foreach ($k in $points.Keys) { if ($points[$k] -ge 0) { $c = $points[$k]; $ini.Set('Waypoints', "$k", "$([Math]::Floor($c / $conv.N) * 1000 + $c % $conv.N)") } }
$ini.Set('Basic', 'Percent', '0')
[IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))

$report = @()
$report += $conv.Log
$report += "raw coast cells: $rawBefore before fix, $($rawAfter.Count) left"
$report += "ramps: " + (($rampAt.Keys | ForEach-Object { "{0} {1:F0},{2:F0}" -f $_, $rampAt[$_][0], $rampAt[$_][1] }) -join '; ')
$report += "road ends in a square: $($conv.SquareEnds.Count); free road ends (should be 0): $($conv.OpenEnds.Count)" + $(if ($conv.OpenEnds.Count) { ' at ' + (($conv.OpenEnds | ForEach-Object { XY $_ }) -join '; ') } else { '' })
$report += "wall cells $wallCells, ore cells $ore, ore mines $mines (OREMINE @ $(XY $mineCell)), trees $treeCount; buildings from OSM cover: industry $indN, churches $churchN, big $bigN, houses $houseN"
$report += "placed: " + (($placed.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', ')
$report += "--- landmarks"; $report += $landLog
$report += "--- connectivity"; $report += $checkLines
$report += "--- waypoints (nr | x,y | cell y*1000+x | opis)"
foreach ($k in $wp.Keys) {
    $c = $points[$k]
    if ($c -ge 0) { $line = "{0,3} | {1,-7} | {2,6} | {3}" -f $k, (XY $c), ([Math]::Floor($c / $conv.N) * 1000 + $c % $conv.N), $wp[$k][0] }
    else { $line = "{0,3} | BRAK wolnej komorki | {1}" -f $k, $wp[$k][0] }
    $report += $line
}
$report += "written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB), Size 0,0,$($conv.W),$($conv.H), LocalSize $padX,$padTop,$localW,$localH"
$report | Set-Content "$Work\log.txt" -Encoding UTF8
$report
$dbg = $conv.DebugImage(); $dbg.Save("$Work\cells.png"); $dbg.Dispose()
$dbg = $conv.ReachImage(); $dbg.Save("$Work\reach.png"); $dbg.Dispose()

# ---------------------------------------------------------------- preview (CNCMaps renderer) + [PreviewPack]
if (-not $NoPreview) {
    $dir = "$game\Map Editor\Map Renderer"
    $base = [IO.Path]::GetFileNameWithoutExtension($Out)
    $argList = "-i `"$Out`" -o ${base}_full -d `"$Work`" -p -T -m `"..\..\MIX`" -M modconfig.xml"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList $argList -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$Work\render.log"
    if (-not $p.WaitForExit(300000)) { $p.Kill(); throw "CNCMaps renderer timed out (see $Work\render.log)" }
    $full = [Drawing.Image]::FromFile("$Work\${base}_full.png")
    $h = [int]($full.Height * 800 / $full.Width)
    $thumb = New-Object Drawing.Bitmap 800, $h
    $g = [Drawing.Graphics]::FromImage($thumb); $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($full, 0, 0, 800, $h); $g.Dispose(); $full.Dispose()
    $thumb.Save([IO.Path]::ChangeExtension($Out, '.png'), [Drawing.Imaging.ImageFormat]::Png)
    $ini = [Ini]::Load($Out)
    [MapPreview]::Set($ini, $thumb, 400); $thumb.Dispose()
    [IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))
    "preview: $([IO.Path]::ChangeExtension($Out, '.png')), full render $Work\${base}_full.png"

    # waypoint sheet for the mission author (raw coast cells left = red rings): cell centre = ((dx+1)*24, (dy+1)*12)
    $full = [Drawing.Bitmap]::FromFile("$Work\${base}_full.png")
    $scale = 1200.0 / $full.Width
    $sheet = New-Object Drawing.Bitmap 1200, ([int]($full.Height * $scale))
    $g = [Drawing.Graphics]::FromImage($sheet); $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'
    $g.DrawImage($full, 0, 0, $sheet.Width, $sheet.Height); $full.Dispose()
    function ScreenOf($c) { $dx = ($c % $conv.N) - [Math]::Floor($c / $conv.N) + $conv.W - 1; $dy = ($c % $conv.N) + [Math]::Floor($c / $conv.N) - $conv.W - 1; , @(((($dx + 1) * 24 - $padX * 48) * $scale), ((($dy + 1) * 12 - $padTop * 24) * $scale)) }
    $font = New-Object Drawing.Font 'Arial', 11, ([Drawing.FontStyle]::Bold)
    $all = [ordered]@{}; foreach ($k in $points.Keys) { $all[$k] = $points[$k] }
    foreach ($s in $conv.Starts) { $all["S$($s[0])"] = $s[2] * $conv.N + $s[1] }
    foreach ($k in $all.Keys) {
        $c = $all[$k]; if ($c -lt 0) { continue }
        $sp = ScreenOf $c; $px = $sp[0]; $py = $sp[1]
        $col = if ("$k" -like 'S*') { [Drawing.Brushes]::Orange } elseif ([int]"$k" -ge 40 -and [int]"$k" -le 45) { [Drawing.Brushes]::DeepSkyBlue } else { [Drawing.Brushes]::Yellow }
        $g.FillEllipse([Drawing.Brushes]::Black, $px - 5, $py - 5, 10, 10); $g.FillEllipse($col, $px - 3.5, $py - 3.5, 7, 7)
        $g.DrawString("$k", $font, [Drawing.Brushes]::Black, $px + 6, $py - 8); $g.DrawString("$k", $font, $col, $px + 5, $py - 9)
    }
    # road ends: orange square = ends in a square (pavement), red = free end (should not exist)
    $epen = New-Object Drawing.Pen ([Drawing.Color]::Orange), 2; $fpen = New-Object Drawing.Pen ([Drawing.Color]::Red), 3
    foreach ($c in $conv.SquareEnds) { $sp = ScreenOf $c; $g.DrawRectangle($epen, $sp[0] - 5, $sp[1] - 5, 10, 10) }
    foreach ($c in $conv.OpenEnds) { $sp = ScreenOf $c; $g.DrawEllipse($fpen, $sp[0] - 8, $sp[1] - 8, 16, 16) }
    $g.Dispose()
    $sheet.Save("$Work\waypoints.png"); $sheet.Dispose()
    # raw coast check picture
    $chk = [Drawing.Bitmap]::FromFile("$Work\${base}_full.png")
    $cs2 = 1200.0 / $chk.Width; $rc = New-Object Drawing.Bitmap 1200, ([int]($chk.Height * $cs2))
    $g = [Drawing.Graphics]::FromImage($rc); $g.DrawImage($chk, 0, 0, $rc.Width, $rc.Height); $chk.Dispose()
    $rpen = New-Object Drawing.Pen ([Drawing.Color]::Red), 2
    foreach ($c in $rawAfter) { $sp = ScreenOf $c; $g.DrawEllipse($rpen, $sp[0] - 6, $sp[1] - 6, 12, 12) }
    $g.Dispose(); $rc.Save("$Work\rawcoast.png"); $rc.Dispose()
    "waypoint sheet: $Work\waypoints.png, raw coast: $Work\rawcoast.png"
}
