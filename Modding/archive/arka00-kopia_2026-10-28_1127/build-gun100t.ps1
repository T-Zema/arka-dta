# ARKA 0 "100 Ton Gun" (Nelson's Anchorage): a 2x2 version of RA Shore Artillery for the type GUN100T of the mission map
# (user 2026-10-27: "zrob wieksza armate, 2x2"). The base SHP and the turret of RAPARTY (Cache.mix, 1x1, 48x48 canvas)
# are scaled 2x by nearest neighbour (palette indices, shadow and remap colours stay exact) into GUN100T.SHP and
# GUN100T_A.SHP, packed into MIX\ECACHE76.MIX. The centre of a building canvas is the top corner of its foundation
# (wiki engine/shp-graphics), so scaling round that centre turns the 1x1 footprint into a 2x2 one.
#   - MIX\ECACHE76.MIX (registry in wiki engine/shp-graphics)
#   - Art.ini, block "; >>> 100 Ton Gun": [GUN100T] Foundation=2x2, [GUN100T_A] turret animation
# The type itself lives in the mission map (build-arka00-mission.ps1). Re-running replaces its own files and block.
# Usage: build-gun100t.ps1 [-WhatIf]
param([switch]$WhatIf)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\ModTools.cs" -ReferencedAssemblies System.Drawing
$art = "$game\INI\Art.ini"; $mixOut = "$game\MIX\ECACHE76.MIX"
$latin = [Text.Encoding]::GetEncoding(28591)
$begin = '; >>> 100 Ton Gun'; $end = '; <<< 100 Ton Gun'

function Backup([string]$path) { if (-not (Test-Path "$path.bak")) { Copy-Item $path "$path.bak" } }
function Nl([string]$path) { if ([IO.File]::ReadAllText($path, $latin).Contains("`r`n")) { "`r`n" } else { "`n" } }
function Set-Block([string]$path, [string]$body) {
    $nl = Nl $path
    $t = [IO.File]::ReadAllText($path, $latin)
    $block = ($begin + $nl + ($body.TrimEnd() -replace "`r?`n", $nl) + $nl + $end + $nl)
    $a = $t.IndexOf($begin)
    if ($a -ge 0) { $b = $t.IndexOf($end, $a); $b = $t.IndexOf("`n", $b) + 1; $t = $t.Substring(0, $a) + $block + $t.Substring($b) }
    else { if (-not $t.EndsWith("`n")) { $t += $nl }; $t += $nl + $block }
    [IO.File]::WriteAllText($path, $t, $latin)
}
# 2x nearest neighbour; frame offsets double with the canvas, so the canvas centre stays the reference point
function Scale2([Shp]$s) {
    $o = New-Object Shp; $o.Width = $s.Width * 2; $o.Height = $s.Height * 2
    foreach ($f in $s.Frames) {
        $g = New-Object Frame ($f.X * 2), ($f.Y * 2), ($f.W * 2), ($f.H * 2)
        for ($y = 0; $y -lt $g.H; $y++) {
            $src = [Math]::Floor($y / 2) * $f.W; $dst = $y * $g.W
            for ($x = 0; $x -lt $g.W; $x++) { $g.Pixels[$dst + $x] = $f.Pixels[$src + [Math]::Floor($x / 2)] }
        }
        $o.Frames.Add($g)
    }
    $o
}

$mixes = New-Object MixSet "$game\MIX"
if (Test-Path $mixOut) { $mixes.Mixes.RemoveAll({ param($m) $m.Path -eq $mixOut }) | Out-Null }   # always scale the originals
$files = New-Object 'Collections.Generic.Dictionary[string,byte[]]'
foreach ($p in @(@('RAPARTY.SHP', 'GUN100T.SHP'), @('RAPARTY_A.SHP', 'GUN100T_A.SHP'))) {
    $b = $mixes.Read($p[0]); if (-not $b) { throw "$($p[0]) not found in MIX\" }
    $s = [Shp]::Read($b); $o = Scale2 $s
    $files[$p[1]] = $o.Write()
    "$($p[0]) $($s.Width)x$($s.Height) ($($s.Frames.Count) frames) -> $($p[1]) $($o.Width)x$($o.Height)"
}
$artBody = @'
; ARKA 0 mission map type GUN100T (Modding/tools/build-gun100t.ps1): RAPARTY Shore Artillery scaled 2x, 2x2 footprint
[GUN100T]
Height=2
Remapable=yes
Normalized=yes
Cameo=RAPARTYICN
Foundation=2x2
PrimaryFireFLH=216,0,-48
UseTurretShadow=yes

[GUN100T_A]
$Inherits=GUN_A
'@
if ($WhatIf) { "WhatIf: would write $mixOut ($($files.Count) files) and the Art.ini block"; return }
[Mix]::Write($mixOut, $files)
Backup $art
Set-Block $art $artBody
"written $mixOut and Art.ini block '$begin'"
