# Builds the terrain map of the ARKA campaign prelude "Ostatnia brama" (Gibraltar, 1953) from a Google Maps
# screenshot (Modding\raw\maps\gibraltar-google.png, 620x930). All coordinates below are screenshot pixels
# ("design px"); y < 0 is Spain north of the screenshot. Water comes from the screenshot colour; the Rock,
# the east lane, ramps, roads, beaches and objects are hand-placed here (traced over the screenshot).
#
#   .\build-arka-gibraltar.ps1                 # build Maps\Custom\arka00_gibraltar.map + preview + checks
#   .\build-arka-gibraltar.ps1 -DesignOnly     # only render the design layers (work dir) for tuning
#
# Waypoints (mission author's reference) are listed in the log and in wiki missions/arka-00-gibraltar.
param(
    [string]$Out = "",
    [string]$Work = "$env:TEMP\arka-gibraltar",
    [switch]$DesignOnly,
    [switch]$NoPreview
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $Out) { $Out = "$game\Maps\Custom\arka00_gibraltar.map" }
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScMap.cs", "$tools\TsMap.cs", "$tools\ScToDta.cs", "$tools\DesignToDta.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $Work | Out-Null
$shot = [Drawing.Bitmap]::FromFile("$game\Modding\raw\maps\gibraltar-google.png")

# design canvas (bigger than the visible rectangle so edge cells sample real data)
$U0 = 0; $V0 = -80; $DW = 640; $DH = 1020
# visible rectangle in design px and map size in cells (about 7.8 x 4.5 design px per cell)
$du0 = 115; $du1 = 590; $dv0 = -60; $dv1 = 930
$localW = 60; $localH = 220; $padX = 2; $padTop = 5; $padBottom = 4

function P([double[]]$pts) { , $pts }

# ---------------------------------------------------------------- kind: water / low / high (Rock) / ramp
$W_ = [DesignToDta]::KWater; $L_ = [DesignToDta]::KLow; $H_ = [DesignToDta]::KHigh; $R_ = [DesignToDta]::KRamp
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
# east lane (Sir Herbert Miles Road): the coast is pushed east so cliffs, shore and a road fit (>= 6 cells)
$kind.Polygon((P 462,262, 522,262, 522,600, 516,650, 506,720, 490,780, 465,815, 440,815), $L_, $W_)
$kind.Vote($W_, $L_, 3, 0.5)
[void]$kind.RemoveSmall($L_, $W_, 400)
[void]$kind.RemoveSmall($W_, $L_, 300)

# the Rock, traced over the hill shading; the east lane stays low ground
$rock = P 395,262, 420,240, 450,236, 468,245, 470,262, 468,300, 462,360, 458,420, 455,480, 455,540, 458,600, 460,640, 455,700, 445,760, 432,800, 420,815, 405,805, 400,780, 392,740, 380,700, 372,660, 370,620, 372,580, 365,540, 355,500, 345,460, 345,420, 355,380, 365,340, 375,300, 385,275
$kind.Polygon($rock, $H_, $L_)
# ramps: Willis's Road (NW, by the Moorish Castle), Queen's Road (SW, by St Michael's Cave), Windmill Hill (S)
$ramps = @{
    'NW' = (P 355,296, 397,296, 397,330, 355,330)
    'SW' = (P 350,596, 392,596, 392,630, 350,630)
    'S'  = (P 398,790, 440,790, 440,826, 398,826)
}
foreach ($r in $ramps.Values) { $kind.Polygon($r, $R_, 255) }

# ---------------------------------------------------------------- ground: 0 grass, 1 dirt, 2 pavement, 3 tall grass
$ground = New-Object Layer $U0, $V0, $DW, $DH, 0
$ground.Where($kind, $H_, 1, 255)                     # the Rock is dirt...
$ground.FromGreen($shot, 0, 0, 10, 3, 0)              # parks on low ground: tall grass
$ground.FromGreen($shot, 0, 0, 10, 0, 1)              # ...with green patches (Upper Rock macchia)
$ground.Polygon((P 165,-55, 230,-58, 290,-40, 280,-12, 200,-8, 168,-25), 1, 0)   # fields around La Linea
$ground.Polygon((P 405,-55, 470,-58, 515,-45, 505,-28, 440,-22, 410,-35), 1, 0)
$ground.Polygon((P 216,156, 502,156, 502,181, 216,181), 2, 255)   # runway
$ground.Polygon((P 238,398, 288,398, 300,565, 272,575, 240,522), 2, 255)   # Dockyard
$ground.Polygon((P 283,258, 322,258, 322,286, 283,286), 2, 255)   # Casemates Square
$roads = @(
    ,(P 382,-60, 384,40, 380,100, 378,156, 372,200, 352,238, 325,262, 300,275)                      # Winston Churchill Ave
    ,(P 300,275, 288,330, 282,400, 290,480, 305,560, 330,620, 362,660, 384,705, 390,780, 400,840, 425,875)   # Main St / Europa Rd
    ,(P 372,200, 440,205, 488,215, 500,250, 494,300, 490,400, 488,500, 486,600, 480,680, 470,750, 452,800, 425,832)  # Devil's Tower / Sir Herbert Miles
    ,(P 300,275, 262,300, 245,360, 255,420, 280,520, 305,560)                                       # Queensway
    ,(P 250,10, 400,5, 515,8)                                                                         # Av. del Ejercito (La Linea)
    ,(P 330,-60, 318,40)
    ,(P 455,-60, 460,8)
    ,(P 362,313, 400,330, 425,380, 432,450, 426,520, 412,580, 375,612)                              # Upper Rock road
    ,(P 426,520, 432,650, 418,740, 420,806)
)
foreach ($r in $roads) { $ground.Line($r, 10, 2, 255) }   # < 10 design px leaves gaps between cells

# ---------------------------------------------------------------- zones: 0 none, 1 beach, 2 trees, 3 sparse trees
$zone = New-Object Layer $U0, $V0, $DW, $DH, 0
$zone.FromGreen($shot, 0, 0, 10, 2, 0)
# the east lane is a road under the cliffs (green on the screenshot is the Rock's slope): sparse trees only
$zone.Polygon((P 455,262, 530,262, 530,820, 430,820), 3, 2)
foreach ($r in $roads) { $zone.Line($r, 9, 0, 255) }
$zone.Polygon((P 160,-60, 520,-60, 520,95, 160,95), 3, 0)          # La Linea outskirts
$zone.Polygon((P 355,700, 445,700, 445,860, 355,860), 3, 0)        # South District
$beaches = [ordered]@{
    'Playa de Levante (Hiszpania)' = (P 500,-60, 545,-60, 545,100, 500,100)
    'Eastern Beach'                = (P 490,125, 545,125, 545,245, 490,245)
    'Catalan Bay'                  = (P 498,305, 545,305, 545,390, 498,390)
    'Sandy Bay'                    = (P 498,430, 545,430, 545,470, 498,470)
    'Camp Bay'                     = (P 282,676, 332,676, 332,742, 282,742)
    'Europa Point'                 = (P 335,858, 455,858, 455,925, 335,925)
}
foreach ($b in $beaches.Values) { $zone.Polygon($b, 1, 255) }

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
Save-Layer $kind   ([int[]]@((Argb 40 80 190), (Argb 235 235 225), (Argb 150 90 40), (Argb 40 200 40))) 'design_kind'
Save-Layer $ground ([int[]]@((Argb 120 190 90), (Argb 170 130 80), (Argb 150 150 150), (Argb 40 110 40))) 'design_ground'
Save-Layer $zone   ([int[]]@((Argb 235 235 225), (Argb 240 220 120), (Argb 30 120 30), (Argb 140 200 140))) 'design_zone'
if ($DesignOnly) { "design layers in $Work"; return }

# ---------------------------------------------------------------- cells, cliffs, shores, water
$mixes = New-Object MixSet "$game\MIX"
$th    = New-Object Theater "$game\INI\Temperat.ini", "tem", $mixes
$wae   = "$game\Map Editor\Editor\Config\ConnectedTileDrawer.ini"
$cliffSet  = New-Object ConnectedSet $wae, "TemperateCliffSet", $th
$wcliffSet = New-Object ConnectedSet $wae, "TemperateWaterCliffSet", $th
$beachSet  = New-Object ConnectedSet $wae, "TemperateShoreSet", $th

$conv = New-Object DesignToDta $th, $localW, $localH, $padX, $padTop, $padBottom, $du0, $dv0, $du1, $dv1
$conv.Classify($kind, $ground, $zone, 40)
$conv.Cliffs($cliffSet)
# hard coast = Water Cliffs; beaches = Shores (hovercraft and landing craft need a passable beach)
$notBeach = [ScToDta+CellPred]{ param($i) $conv.Zone[$i] -ne 1 }
$isBeach  = [ScToDta+CellPred]{ param($i) $conv.Zone[$i] -eq 1 }
$conv.Shores($wcliffSet, $true, $notBeach)
$conv.Beaches($beachSet, $isBeach)
$conv.SettleWater()
[void]$conv.DrownSpecks(40)   # strips left outside a beach chain; real land pieces are hundreds of cells
$conv.FillWater($th.SetByName('Animated Water'), $th.SetByName('Water').Start)

# ---------------------------------------------------------------- objects
function Cell($u, $v) { $conv.CellAt($u, $v) }
function XY($c) { "{0},{1}" -f ($c % $conv.N), [Math]::Floor($c / $conv.N) }

# plots kept empty for the mission author (ARKA, power plants, staging areas)
$conv.Reserve(300, 335, 4, 4)
foreach ($pp in @(@(262, 300), @(338, 300), @(262, 378), @(336, 382))) { $conv.Reserve($pp[0], $pp[1], 2, 2) }
$conv.Reserve(290, -30, 5, 5); $conv.Reserve(470, -35, 5, 5); $conv.Reserve(440, 35, 2, 2)

# Northern Defences (concrete wall) with Landport and Waterport gates
$wall = New-Object 'System.Collections.Generic.List[int]'
foreach ($seg in @(@(212, 248, 238, 248), @(258, 248, 328, 248), @(354, 248, 410, 253))) {
    $wall.AddRange($conv.CellLine($seg[0], $seg[1], $seg[2], $seg[3]))
}
$wallCells = $conv.OverlayCells($wall, 2, 0)

# ore: Windmill Hill (safe, south) and the airfield between border and runway (contested)
$ore = 0
foreach ($f in @(@(372, 765, 11), @(445, 128, 12))) {
    $cells = $conv.CellDisc($f[0], $f[1], $f[2])
    foreach ($c in $cells) { $l = New-Object 'System.Collections.Generic.List[int]'; $l.Add($c); $ore += $conv.OverlayCells($l, [byte](147 + $conv.Rnd.Next(4)), [byte](3 + $conv.Rnd.Next(9))) }
}

# civilian buildings (house Neutral), placed at random free spots of a design box
$placed = @{}
function Place-Civ([string]$type, [int]$fw, [int]$fh, [double]$u, [double]$v, [double]$ru, [double]$rv, [int]$count) {
    $n = 0
    for ($k = 0; $k -lt 200 -and $n -lt $count; $k++) {
        $c = Cell ($u + ($conv.Rnd.NextDouble() * 2 - 1) * $ru) ($v + ($conv.Rnd.NextDouble() * 2 - 1) * $rv)
        if ($conv.PlaceBuilding('Neutral', $type, $fw, $fh, $c % $conv.N, [Math]::Floor($c / $conv.N))) { $n++ }
    }
    $script:placed[$type] = $n + $script:placed[$type]
}
Place-Civ 'LHUS' 1 1 425 878 6 5 1          # Europa Point Lighthouse
Place-Civ 'WDML' 1 1 395 845 10 8 1         # Windmill Hill
Place-Civ 'CRANE' 1 1 270 470 18 60 3       # Dockyard
Place-Civ 'CITY09' 1 1 268 480 18 60 3
Place-Civ 'HOSP' 2 2 352 700 10 10 1        # Royal Naval Hospital
$village = 'V01', 'V02', 'V04', 'V05', 'V06', 'V07', 'V08', 'V09', 'V10', 'V11'
foreach ($box in @(@(325, 660, 30, 30, 8), @(395, 735, 25, 30, 6), @(505, 345, 6, 25, 3), @(300, 30, 50, 25, 8), @(470, 5, 35, 20, 6), @(240, -40, 40, 15, 5))) {
    for ($k = 0; $k -lt $box[4]; $k++) { Place-Civ $village[$conv.Rnd.Next($village.Count)] 1 1 $box[0] $box[1] $box[2] $box[3] 1 }
}
Place-Civ 'V03' 2 2 320 650 30 25 1

$trees = [string[]]@('T01','T02','T03','T05','T06','T07','T08','T09','T10','T11','T12','T13','T14','T15','T16','T17')
$treeCount = $conv.PlaceTrees(2, $trees, 0.22) + $conv.PlaceTrees(3, $trees, 0.05)

$conv.SmoothGround(2)
$base = [int[]]@(0, $th.SetByName('Dirt LAT').Start, $th.SetByName('Pavement LAT').Start, $th.SetByName('Tall Grass').Start)
$lat  = [int[]]@(0, $th.SetByName('Clear/Dirt LAT').Start, $th.SetByName('Clear/Pavement LAT').Start, $th.SetByName('Tall/Short Grass LAT').Start)
$conv.ApplyGround(0, $base, $lat)
$conv.WallFrames(2, [int[]]@(0, 2, 4, 6))

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
    '24' = @('Ladowisko: Catalan Bay', 512, 345, 'g')
    '25' = @('Pas wschodni, odcinek tunelu (Dudley Ward)', 482, 690, 'g')
    '26' = @('Ladowisko: Camp Bay (zachod, poludnie miasta)', 305, 712, 'g')
    '27' = @('Ladowisko: Europa Point', 395, 895, 'g')
    '28' = @('Skala: gora rampy NW', 395, 345, 'g'); '29' = @('Skala: dol rampy NW', 345, 312, 'g')
    '30' = @('Skala: gora rampy SW', 400, 612, 'g'); '31' = @('Skala: dol rampy SW', 345, 612, 'g')
    '32' = @('Skala: gora rampy S', 415, 785, 'g'); '33' = @('Skala: dol rampy S', 420, 835, 'g')
    '34' = @('Skala: szczyt polnocny (baterie)', 445, 262, 'g')
    '35' = @('Skala: Middle Hill', 425, 470, 'g')
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
}
$points = [ordered]@{}
foreach ($k in $wp.Keys) {
    $w = $wp[$k]
    $c = $conv.Nearest((Cell $w[1] $w[2]), $w[3] -eq 'w')
    $points[$k] = $c
}
# skirmish test starts: player at the ARKA plot, enemy in Spain
foreach ($s in @(@(0, 300, 335), @(1, 380, -40))) { $c = $conv.Nearest((Cell $s[1] $s[2]), $false); $conv.Starts.Add([int[]]@($s[0], ($c % $conv.N), [Math]::Floor($c / $conv.N))) }

# ---------------------------------------------------------------- checks
$conv.CheckConnectivity()
$checks = @(
    @(18, 10, 'Hiszpania -> ARKA'), @(23, 10, 'Eastern Beach -> ARKA'), @(24, 27, 'Catalan Bay -> Europa Point (pas wschodni)'),
    @(26, 10, 'Camp Bay -> ARKA'), @(29, 28, 'rampa NW'), @(31, 30, 'rampa SW'), @(33, 32, 'rampa S'), @(10, 34, 'ARKA -> szczyt Skaly'),
    @(17, 18, 'Tanya -> zbiorka sowiecka'), @(10, 38, 'ARKA -> ruda Windmill Hill')
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
$report += "wall cells $wallCells, ore cells $ore, trees $treeCount, buildings: " + (($placed.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', ')
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

    # waypoint sheet for the mission author: the render covers LocalSize, cell centre = ((dx+1)*24, (dy+1)*12)
    $full = [Drawing.Bitmap]::FromFile("$Work\${base}_full.png")
    $scale = 1200.0 / $full.Width
    $sheet = New-Object Drawing.Bitmap 1200, ([int]($full.Height * $scale))
    $g = [Drawing.Graphics]::FromImage($sheet); $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'
    $g.DrawImage($full, 0, 0, $sheet.Width, $sheet.Height); $full.Dispose()
    $font = New-Object Drawing.Font 'Arial', 11, ([Drawing.FontStyle]::Bold)
    $all = [ordered]@{}; foreach ($k in $points.Keys) { $all[$k] = $points[$k] }
    foreach ($s in $conv.Starts) { $all["S$($s[0])"] = $s[2] * $conv.N + $s[1] }
    foreach ($k in $all.Keys) {
        $c = $all[$k]; if ($c -lt 0) { continue }
        $dx = ($c % $conv.N) - [Math]::Floor($c / $conv.N) + $conv.W - 1; $dy = ($c % $conv.N) + [Math]::Floor($c / $conv.N) - $conv.W - 1
        $px = (($dx + 1) * 24 - $padX * 48) * $scale; $py = (($dy + 1) * 12 - $padTop * 24) * $scale
        $col = if ("$k" -like 'S*') { [Drawing.Brushes]::Orange } elseif ([int]"$k" -ge 40) { [Drawing.Brushes]::DeepSkyBlue } else { [Drawing.Brushes]::Yellow }
        $g.FillEllipse([Drawing.Brushes]::Black, $px - 5, $py - 5, 10, 10); $g.FillEllipse($col, $px - 3.5, $py - 3.5, 7, 7)
        $g.DrawString("$k", $font, [Drawing.Brushes]::Black, $px + 6, $py - 8); $g.DrawString("$k", $font, $col, $px + 5, $py - 9)
    }
    $g.Dispose()
    $sheet.Save("$Work\waypoints.png"); $sheet.Dispose()
    "waypoint sheet: $Work\waypoints.png"
}
