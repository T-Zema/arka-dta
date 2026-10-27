# Builds the Uber Supply Depot graphics (SCUDEPO) from the Terran Supply Depot SHPs in ECACHE98.MIX:
# gilded hull, brighter lights, cameo with a "x4" badge. Output: MIX/ECACHE96.MIX (only this building).
# Rules/Art: block "Uber Supply Depot" in INI/Game Options/StarCraft.ini and INI/Art.ini.
# Wiki: Modding/wiki/mods/starcraft-terran-buildings.md. Previews: %TEMP%\scuberdepot\*.png
param([string]$Game = (Resolve-Path "$PSScriptRoot\..\..").Path)
$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot\ModTools.cs" -ReferencedAssemblies System.Drawing
Add-Type -AssemblyName System.Drawing

$mixes    = New-Object MixSet "$Game\MIX"
$unitPal  = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$cameoPal = [Pal]::ReadTs($mixes.Read('CAMEO.PAL'))
$prev = Join-Path $env:TEMP 'scuberdepot'; New-Item -ItemType Directory -Force $prev | Out-Null

function Lerp([System.Drawing.Color]$a, [double[]]$b, [double]$t) {
    [System.Drawing.Color]::FromArgb(
        [int][Math]::Min(255, $a.R + ($b[0] - $a.R) * $t),
        [int][Math]::Min(255, $a.G + ($b[1] - $a.G) * $t),
        [int][Math]::Min(255, $a.B + ($b[2] - $a.B) * $t))
}

# Per-index recolour table: neutral metal -> gold, bright coloured lights -> hotter. 0 (transparent), 1 (shadow)
# and 16-31 (player remap) stay as they are, so the house colour still shows.
function Gild-Map($pal, [int]$from, [int]$to) {
    $map = New-Object byte[] 256
    for ($i = 0; $i -lt 256; $i++) {
        $map[$i] = [byte]$i
        if ($i -le 1 -or ($i -ge 16 -and $i -le 31)) { continue }
        $c = $pal[$i]
        $mx = [Math]::Max($c.R, [Math]::Max($c.G, $c.B)); $mn = [Math]::Min($c.R, [Math]::Min($c.G, $c.B))
        $lum = 0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B
        if (($mx - $mn) -lt 56) {
            $gold = @(($lum * 1.25 + 22), ($lum * 1.0 + 8), ($lum * 0.38))
            $out = Lerp $c $gold 0.8
        } elseif ($lum -gt 140) {
            $out = Lerp $c @(255, 236, 140) 0.4
        } else { continue }
        $map[$i] = [Pal]::Nearest($out, $pal, $from, $to)
    }
    return ,$map
}

function Recolor-Shp([byte[]]$data, $map, [int]$colourFrames) {
    $shp = [Shp]::Read($data)
    for ($f = 0; $f -lt $colourFrames; $f++) {
        $px = $shp.Frames[$f].Pixels
        for ($k = 0; $k -lt $px.Length; $k++) { $px[$k] = $map[$px[$k]] }
    }
    return $shp
}

$unitMap = Gild-Map $unitPal 32 254

# Building: frames normal, damaged, 2 shadows.
$bld = Recolor-Shp $mixes.Read('SCDEPO.SHP') $unitMap 2
# Buildup: first half colour, second half shadows.
$mkSrc = [Shp]::Read($mixes.Read('SCDEPOMK.SHP'))
$mk = Recolor-Shp $mixes.Read('SCDEPOMK.SHP') $unitMap ($mkSrc.Frames.Count / 2)

# Cameo: gild the sprite but keep the navy background gradient (bluish indices are background: the depot hull is
# grey), then stamp a "x4" badge (only the changed pixels are re-quantised).
$cameoMap = Gild-Map $cameoPal 1 255
for ($i = 0; $i -lt 256; $i++) { $c = $cameoPal[$i]; if (($c.B - [Math]::Max($c.R, $c.G)) -ge 6) { $cameoMap[$i] = [byte]$i } }   # bg: 20,20,28 and 32,32,52
$cam = Recolor-Shp $mixes.Read('SCDEPOIC.SHP') $cameoMap 1
$cf = $cam.Frames[0]
$bmp = New-Object System.Drawing.Bitmap 64, 48
for ($y = 0; $y -lt $cf.H; $y++) { for ($x = 0; $x -lt $cf.W; $x++) {
    $v = $cf.Pixels[$y * $cf.W + $x]; if ($v -ne 0) { $bmp.SetPixel($cf.X + $x, $cf.Y + $y, $cameoPal[$v]) } } }
$before = $bmp.Clone()
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::SingleBitPerPixelGridFit
$font = New-Object System.Drawing.Font('Arial', 11, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$tx = 41; $ty = 33
foreach ($d in @(@(-1,0),@(1,0),@(0,-1),@(0,1),@(-1,-1),@(1,1),@(-1,1),@(1,-1))) {
    $g.DrawString('x4', $font, [System.Drawing.Brushes]::Black, $tx + $d[0], $ty + $d[1]) }
$g.DrawString('x4', $font, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 250, 210, 60))), $tx, $ty)
$g.Dispose()
$full = New-Object Frame 0, 0, 64, 48
for ($y = 0; $y -lt 48; $y++) { for ($x = 0; $x -lt 64; $x++) {
    $orig = 0
    if ($x -ge $cf.X -and $y -ge $cf.Y -and $x -lt $cf.X + $cf.W -and $y -lt $cf.Y + $cf.H) { $orig = $cf.Pixels[($y - $cf.Y) * $cf.W + ($x - $cf.X)] }
    if ($bmp.GetPixel($x, $y).ToArgb() -ne $before.GetPixel($x, $y).ToArgb()) { $orig = [Pal]::Nearest($bmp.GetPixel($x, $y), $cameoPal, 1, 255) }
    $full.Pixels[$y * 64 + $x] = $orig } }
$cam.Frames[0] = $full

# Previews: original vs uber.
$orig = [Shp]::Read($mixes.Read('SCDEPO.SHP'))
$cmp = New-Object 'System.Collections.Generic.List[Frame]'; $cmp.Add($orig.Frames[0]); $cmp.Add($bld.Frames[0]); $cmp.Add($orig.Frames[1]); $cmp.Add($bld.Frames[1])
[Pal]::Sheet($cmp, @(0,1,2,3), $bld.Width, $bld.Height, $unitPal, 2, 2, "$prev\building.png")
$oc = [Shp]::Read($mixes.Read('SCDEPOIC.SHP'))
$cc = New-Object 'System.Collections.Generic.List[Frame]'; $cc.Add($oc.Frames[0]); $cc.Add($cam.Frames[0])
[Pal]::Sheet($cc, @(0,1), 64, 48, $cameoPal, 4, 2, "$prev\cameo.png")
$n = $mk.Frames.Count / 2
[Pal]::Sheet($mk.Frames, @(0, [int]($n/3), [int](2*$n/3), ($n-1)), $mk.Width, $mk.Height, $unitPal, 2, 4, "$prev\buildup.png")

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$files['SCUDEPO.SHP']  = $bld.Write()
$files['SCUDEPMK.SHP'] = $mk.Write()
$files['SCUDEPIC.SHP'] = $cam.Write()
[Mix]::Write("$Game\MIX\ECACHE96.MIX", $files)
"ECACHE96.MIX: " + (($files.Keys | ForEach-Object { "$_ ($($files[$_].Length) B)" }) -join ', ')
"previews: $prev"
