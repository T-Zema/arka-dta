# Client previews for the ARKA missions: Maps\Missions\arka0N.png (300x200, the picture the campaign
# screen shows next to the mission list; the client takes <map name>.png beside the map).
# Each preview is a staged scene: a temporary copy of the mission map gets extra units and craters,
# CNCMaps renders it, and a window around the scene is scaled down to 300x200.
# Usage:
#   powershell -NoProfile -File .\build-arka-previews.ps1              # all ARKA missions
#   powershell -NoProfile -File .\build-arka-previews.ps1 -Only arka01
param([string]$Only)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game = (Resolve-Path "$tools\..\..").Path
$work = "$env:TEMP\arka-previews"
New-Item -ItemType Directory -Force $work | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\TsMap.cs" -ReferencedAssemblies System.Drawing
Add-Type -AssemblyName System.Drawing
$enc = [Text.Encoding]::GetEncoding(1252)

# facings (0 = map north): screen up = 224, down = 96, left = 160, right = 32
$scenes = @(
    @{ Map = 'arka00'; Window = @(905, 1830, 510, 340); Items = @(
        # Soviet assault from the city gate (top), Allied line round the Construction Yard, ARKA at the bottom
        @('U', 'Soviet', '4TNK', 1010, 1855, 96), @('U', 'Soviet', '4TNK', 1260, 1860, 96),
        @('U', 'Soviet', '3TNK', 930, 1895, 96), @('U', 'Soviet', '3TNK', 1080, 1890, 96), @('U', 'Soviet', '3TNK', 1180, 1895, 96), @('U', 'Soviet', '3TNK', 1340, 1890, 96),
        @('U', 'Soviet', 'V2RL', 1130, 1845, 96), @('U', 'Soviet', 'V2RL', 1400, 1850, 96), @('U', 'Soviet', 'TTNK', 950, 1845, 96),
        @('I', 'Soviet', 'E1', 990, 1930, 96), @('I', 'Soviet', 'E1', 1040, 1935, 96), @('I', 'Soviet', 'SHOK', 1130, 1935, 96),
        @('I', 'Soviet', 'E2', 1230, 1930, 96), @('I', 'Soviet', 'E1', 1290, 1935, 96), @('I', 'Soviet', 'DOG', 1380, 1940, 96),
        @('U', 'Allies', '2TNK', 980, 1985, 224), @('U', 'Allies', '2TNK', 1040, 1975, 224), @('U', 'Allies', '2TNK', 1260, 1990, 224),
        @('U', 'Allies', '1TNK', 1320, 1970, 224), @('U', 'Allies', 'RANG', 1000, 2060, 224), @('U', 'Allies', '2TNK', 1220, 2060, 224),
        @('I', 'Allies', 'E1', 1100, 1965, 224), @('I', 'Allies', 'E1', 1150, 1960, 224), @('I', 'Allies', 'E3', 1220, 1955, 224), @('I', 'Allies', 'MEDIC', 1080, 2010, 224),
        @('S', 'CR1A', 1020, 1945), @('S', 'CR2B', 1190, 1940), @('S', 'CR3C', 1100, 1905), @('S', 'CR1D', 1330, 1935), @('S', 'CR4A', 940, 1960)
    ) },
    @{ Map = 'arka01'; Window = @(100, 2300, 480, 320); Items = @(
        # survivors round the crashed ARKA (left) hold off a Zerg swarm coming from the right
        @('U', 'Allies', '1TNK', 360, 2420, 32), @('U', 'Allies', '1TNK', 375, 2480, 32), @('U', 'Allies', '2TNK', 360, 2545, 32), @('U', 'Allies', '2TNK', 315, 2595, 32),
        @('U', 'Allies', 'RANG', 300, 2385, 32),
        @('I', 'Allies', 'E1', 405, 2440, 32), @('I', 'Allies', 'E1', 410, 2505, 32), @('I', 'Allies', 'E3', 400, 2565, 32), @('I', 'Allies', 'E1', 330, 2450, 32),
        @('I', 'Allies', 'ARKEINST', 250, 2525, 32), @('I', 'Allies', 'MEDIC', 300, 2510, 32),
        @('I', 'Nod1', 'SCZLNG', 450, 2420, 160), @('I', 'Nod1', 'SCZLNG', 465, 2465, 160), @('I', 'Nod1', 'SCZLNG', 450, 2505, 160), @('I', 'Nod1', 'SCZLNG', 470, 2550, 160),
        @('I', 'Nod1', 'SCZLNG', 500, 2440, 160), @('I', 'Nod1', 'SCZLNG', 515, 2490, 160), @('I', 'Nod1', 'SCZLNG', 470, 2600, 160), @('I', 'Nod1', 'SCZLNG', 520, 2580, 160),
        @('I', 'Nod1', 'SCZLNG', 430, 2370, 160), @('I', 'Nod1', 'SCZLNG', 495, 2370, 160),
        @('I', 'Nod1', 'SCZHYL', 545, 2450, 160), @('I', 'Nod1', 'SCZHYL', 550, 2530, 160),
        @('U', 'Nod1', 'SCZMUT', 490, 2330, 160), @('U', 'Nod1', 'SCZMUT', 545, 2370, 160),
        @('S', 'CR1A', 410, 2470), @('S', 'CR2B', 420, 2560), @('S', 'CR3A', 395, 2410)
    ) },
    @{ Map = 'arka02'; Window = @(2870, 2480, 480, 320); Items = @(
        # Mar Sara City: the Allies (Tanya, tanks, Raynor's Marines) storm the infested Command Center (upper right)
        @('U', 'Allies', '2TNK', 2950, 2650, 32), @('U', 'Allies', '2TNK', 3000, 2700, 32), @('U', 'Allies', '1TNK', 2930, 2710, 32),
        @('U', 'Allies', 'SCMARINE', 3010, 2620, 32), @('U', 'Allies', 'SCMARINE', 3050, 2650, 32), @('U', 'Allies', 'SCMARINE', 3060, 2700, 32),
        @('I', 'Allies', 'TANYA', 3090, 2610, 32), @('I', 'Allies', 'E1', 2980, 2590, 32), @('I', 'Allies', 'E3A', 2960, 2610, 32),
        @('I', 'Nod1', 'SCZLNG', 3130, 2600, 160), @('I', 'Nod1', 'SCZLNG', 3150, 2640, 160), @('I', 'Nod1', 'SCZLNG', 3120, 2660, 160),
        @('I', 'Nod1', 'SCZLNG', 3170, 2680, 160), @('I', 'Nod1', 'SCZHYL', 3220, 2650, 160), @('I', 'Nod1', 'SCZHYL', 3250, 2690, 160),
        @('U', 'Nod1', 'SCZINF', 3140, 2560, 160), @('U', 'Nod1', 'SCZINF', 3190, 2720, 160),
        @('S', 'CR1A', 3080, 2660), @('S', 'CR2B', 3110, 2580), @('S', 'CR3C', 3030, 2600)
    ) }
)

foreach ($sc in $scenes) {
    $m = $sc.Map
    if ($Only -and $Only -ne $m) { continue }
    $ini = [Ini]::Load("$game\Maps\Missions\$m.map")
    $W = [int](($ini.Get('Map', 'Size', '') -split ',')[2])
    $ls = $ini.Get('Map', 'LocalSize', '') -split ','; $LX = [int]$ls[0]; $LY = [int]$ls[1]
    # render pixel (where the unit sprite shows up) -> cell: px = (x-y+W-1)*24 - LX*48 + 24, py = (x+y-W-1)*12 - LY*24 + 60
    # (the +60 measured on the first renders: sprites stood ~50 px below the plain iso formula)
    function Cell($px, $py) {
        $u = [Math]::Round(($px - 24 + $LX * 48) / 24) - $W + 1
        $v = [Math]::Round(($py - 60 + $LY * 24) / 12) + $W + 1
        if (($u + $v) % 2) { $v++ }
        @((($u + $v) / 2), (($v - $u) / 2))
    }
    # cells taken by structures (3x3 from the top-left corner, enough to keep units off buildings)
    $busy = @{}
    foreach ($kv in $ini.Section('Structures')) { $p = $kv.Value -split ','; for ($i = 0; $i -lt 3; $i++) { for ($j = 0; $j -lt 3; $j++) { $busy["$([int]$p[3] + $i),$([int]$p[4] + $j)"] = 1 } } }
    foreach ($kv in $ini.Section('Units')) { $p = $kv.Value -split ','; $busy["$($p[3]),$($p[4])"] = 1 }
    $nU = @($ini.Section('Units')).Count; $nI = @($ini.Section('Infantry')).Count; $nS = @($ini.Section('Smudge')).Count
    $infAt = @{}; $skipped = 0
    foreach ($it in $sc.Items) {
        if ($it[0] -eq 'S') { $c = Cell $it[2] $it[3]; $ini.Set('Smudge', "$nS", "$($it[1]),$($c[0]),$($c[1]),0"); $nS++; continue }
        $c = Cell $it[3] $it[4]; $k = "$($c[0]),$($c[1])"
        if ($it[0] -eq 'U') {
            if ($busy[$k]) { $skipped++; continue }
            $busy[$k] = 1
            $ini.Set('Units', "$nU", "$($it[1]),$($it[2]),256,$($c[0]),$($c[1]),$($it[5]),Guard,None,0,-1,0,-1,0,0"); $nU++
        } else {
            if ($busy[$k] -and -not $infAt[$k]) { $skipped++; continue }
            $sub = 1 + [int]$infAt[$k]; if ($sub -gt 3) { $skipped++; continue }
            $infAt[$k] = $sub; $busy[$k] = 1
            $ini.Set('Infantry', "$nI", "$($it[1]),$($it[2]),256,$($c[0]),$($c[1]),$sub,Guard,$($it[5]),None,0,-1,0,0,0"); $nI++
        }
    }
    $tmp = "$work\${m}_scene.map"
    [IO.File]::WriteAllText($tmp, $ini.Write(), $enc)

    $dir = "$game\Map Editor\Map Renderer"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$tmp`" -o ${m}_scene -d `"$work`" -p -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$work\${m}_scene.log"
    if (-not $p.WaitForExit(400000)) { $p.Kill(); throw "renderer timed out ($m)" }

    $w = $sc.Window
    $src = [Drawing.Image]::FromFile("$work\${m}_scene.png")
    $out = New-Object Drawing.Bitmap 300, 200
    $g = [Drawing.Graphics]::FromImage($out)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
    $g.DrawImage($src, (New-Object Drawing.Rectangle 0, 0, 300, 200), (New-Object Drawing.Rectangle $w[0], $w[1], $w[2], $w[3]), 'Pixel')
    $png = "$game\Maps\Missions\$m.png"
    $out.Save($png, [Drawing.Imaging.ImageFormat]::Png)
    # same window at full size, for checking the staging
    $big = New-Object Drawing.Bitmap $w[2], $w[3]; $gb = [Drawing.Graphics]::FromImage($big)
    $gb.DrawImage($src, (New-Object Drawing.Rectangle 0, 0, $w[2], $w[3]), (New-Object Drawing.Rectangle $w[0], $w[1], $w[2], $w[3]), 'Pixel'); $big.Save("$work\${m}_window.png")
    $gb.Dispose(); $big.Dispose(); $g.Dispose(); $out.Dispose(); $src.Dispose()
    "$m -> $png ($($sc.Items.Count) scene items, $skipped skipped on occupied cells; full-size window $work\${m}_window.png)"
}
