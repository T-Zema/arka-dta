# Contact sheet of building types as they look in game: a flat TEMPERATE copy of a terrain map gets the given types in a
# grid (house Neutral), CNCMaps renders it, and every building is cut out with its name and foundation.
#   powershell -NoProfile -File .\build-bldg-sheet.ps1 -Types CITY02,CITY03,CITY04 -Name city -Cols 4
# Output: %TEMP%\bldg-sheet\<Name>_sheet.png (+ the render). Wiki: catalog/city-buildings.
param([string[]]$Types, [string]$Name = 'sheet', [int]$Cols = 8, [string]$Map = '')
$ErrorActionPreference = 'Stop'
$Types = @($Types -join ',' -split ',' | Where-Object { $_ })
$game = (Resolve-Path "$PSScriptRoot\..\..").Path
$tools = $PSScriptRoot
if (-not $Map) { $Map = "$game\Maps\Custom\arka05_tarsonis.map" }
$out = "$env:TEMP\bldg-sheet"
New-Item -ItemType Directory -Force $out | Out-Null
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\TsMap.cs" -ReferencedAssemblies System.Drawing
$enc = [Text.Encoding]::GetEncoding(1252)
$ini = [Ini]::Load($Map)
# flat clear map: every tile clear grass at level 0, no overlay, no terrain objects
$tiles = [IsoMap]::Decode([Pack]::Unpack($ini.Joined('IsoMapPack5'), $true))
$valid = @{}
foreach ($t in $tiles) { $t.Tile = 0; $t.Sub = 0; $t.Level = 0; $valid["$($t.X),$($t.Y)"] = 1 }
$ini.SetPack('IsoMapPack5', [Pack]::PackData([IsoMap]::Encode($tiles), $true, 8192))
$o = New-Object 'byte[]' (512 * 512); for ($i = 0; $i -lt $o.Length; $i++) { $o[$i] = 255 }; $d = New-Object 'byte[]' (512 * 512)
$ini.SetPack('OverlayPack', [Pack]::PackData($o, $false, 8192)); $ini.SetPack('OverlayDataPack', [Pack]::PackData($d, $false, 8192))
foreach ($s in 'Terrain', 'Structures', 'Units', 'Infantry', 'Smudge', 'Preview', 'PreviewPack') { $ini.Sections.Remove($s) | Out-Null; $ini.Order.Remove($s) | Out-Null }
$W = [int](($ini.Get('Map', 'Size', '') -split ',')[2]); $ls = $ini.Get('Map', 'LocalSize', '') -split ','; $LX = [int]$ls[0]; $LY = [int]$ls[1]
$art = @{}; $sec = $null
foreach ($l in [IO.File]::ReadAllLines("$game\INI\Art.ini")) { if ($l -match '^\[(.+)\]') { $sec = $matches[1]; continue }; if ($sec -and $l -match '^Foundation=(\d+)x(\d+)') { $art[$sec] = @([int]$matches[1], [int]$matches[2]) } }
$pos = @(); $i = 0
foreach ($ty in $Types) {
    $c = $i % $Cols; $r = [Math]::Floor($i / $Cols)
    # screen column = x - y (12 cells = 288 px apart), screen row = x + y (20 cells = 240 px apart)
    $sum = 110 + 20 * $r; $dif = -42 + 12 * $c; $x = [int](( $sum + $dif) / 2); $y = [int](($sum - $dif) / 2)
    $f = if ($art[$ty]) { $art[$ty] } else { @(1, 1) }
    $ini.Set('Structures', "$i", "Neutral,$ty,256,$x,$y,64,None,0,0,1,0,0,None,None,None,0,0")
    $pos += , @($ty, $x, $y, $f[0], $f[1]); $i++
}
$tmp = "$out\$Name.map"; [IO.File]::WriteAllText($tmp, $ini.Write(), $enc)
$dir = "$game\Map Editor\Map Renderer"
$p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList "-i `"$tmp`" -o $Name -d `"$out`" -p -m `"..\..\MIX`" -M modconfig.xml" -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$out\$Name.log"
if (-not $p.WaitForExit(400000)) { $p.Kill(); throw 'render timeout' }
$img = [Drawing.Image]::FromFile("$out\$Name.png")
$cw = 230; $ch = 250
$sheet = New-Object Drawing.Bitmap ($Cols * $cw), ([Math]::Ceiling($Types.Count / $Cols) * $ch)
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear([Drawing.Color]::FromArgb(30, 30, 30))
$font = New-Object Drawing.Font 'Arial', 11, ([Drawing.FontStyle]::Bold)
for ($k = 0; $k -lt $pos.Count; $k++) {
    $q = $pos[$k]; $cx = $q[1] + $q[3] / 2.0; $cy = $q[2] + $q[4] / 2.0
    $px = ($cx - $cy + $W - 1) * 24 - $LX * 48 + 24; $py = ($cx + $cy - $W - 1) * 12 - $LY * 24 + 60
    $src = New-Object Drawing.Rectangle ([int]($px - $cw / 2)), ([int]($py - $ch + 70)), $cw, ($ch - 20)
    $dst = New-Object Drawing.Rectangle (($k % $Cols) * $cw), ([Math]::Floor($k / $Cols) * $ch), $cw, ($ch - 20)
    $g.DrawImage($img, $dst, $src, 'Pixel')
    $g.DrawString("$($q[0]) $($q[3])x$($q[4])", $font, [Drawing.Brushes]::Yellow, $dst.X + 4, $dst.Y + $ch - 20)
}
$g.Dispose(); $sheet.Save("$out\$Name`_sheet.png"); $sheet.Dispose(); $img.Dispose()
"sheet: $out\$Name`_sheet.png"
