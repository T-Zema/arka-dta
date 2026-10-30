# StarCraft NEUTRAL buildings as DTA building art (user 2026-10-30: "use the sc_neutral preview, Starbase and Generate,
# wherever they fit"). SC's neutral structures with a picture (unit/neutral/*.grp; names and shadows from SC's data:
# units.dat -> flingy -> sprites -> images.dat/images.tbl, the shadow is the image right after the building's;
# footprints = SC placement boxes, 32 px = 1 cell):
#   SCNGEN  Power Generator  (SC 200)  Generate.grp + tgnShad   4x3
#   SCNSTB  Starbase         (unused)  starbase.grp, no shadow  3x3  (a blue station that no SC unit uses)
#   SCNPSI  Psi Disrupter    (SC 190)  PsiDisr.grp + tpdShad    5x3
#   SCNION  Ion Cannon       (SC 127)  ion.grp, no shadow       4x3  (SC box 3x2; the dome overhangs it, so 4x3)
#   SCNSTA  Stasis Cell      (SC 168)  stasis.grp, no shadow    4x3
# Output: MIX\ECACHE75.MIX (frame 0 normal, 1 damaged, 2-3 shadows, like build-scterran.ps1) and the Art.ini block
# "; >>> SC neutral buildings". No buildup and no cameo: these are placed by maps, nobody builds them. The rules side (Name,
# Strength, Armor, TechLevel=-1, ...) lives in the map that uses them (campaign maps do not read Game Options), with
# [BuildingTypes] entries; the section name = the art name, so no Image= is needed.
#   powershell -NoProfile -File .\build-scneutral.ps1            # build MIX + Art.ini block + previews
#   powershell -NoProfile -File .\build-scneutral.ps1 -WhatIf    # previews only
# Previews: %TEMP%\scneutral-preview\fit_<ID>.png. Wiki: Modding/wiki/mods/sc-neutral-buildings.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\scneutral-preview",
    [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
$mixOut = "$game\MIX\ECACHE75.MIX"; $art = "$game\INI\Art.ini"
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScBuild.cs", "$tools\ScBuildings.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null
$latin = [Text.Encoding]::GetEncoding(28591)
$casc  = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"

# palettes as build-scterran.ps1 (badlands/jungle palette, unit palette, player colour ramp from tunit.pcx)
$scPal   = [Pal]::ReadWpe($casc.ReadFile('TileSet/jungle.wpe'))
$unitPal = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$w = 0; $h = 0; $tpal = $null
$tunit = [Pal]::ReadPcx($casc.ReadFile('game/tunit.pcx'), [ref]$w, [ref]$h, [ref]$tpal)
$ramp = New-Object 'System.Drawing.Color[]' 8
for ($i = 0; $i -lt 8; $i++) { $ramp[$i] = $tpal[$tunit[$i]] }
$map    = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)
$dmgMap = [ScBuildings]::DamageMap($map, $unitPal)

$grpCache = @{}
function G($name) { if (-not $name) { return $null }; if (-not $grpCache.ContainsKey($name)) { $grpCache[$name] = [Grp]::Read($casc.ReadFile("unit/neutral/$name.grp")) }; $grpCache[$name] }
function Layers { $l = New-Object 'System.Collections.Generic.List[ScLayer]'; foreach ($a in $args) { if ($a) { $l.Add($a) } }; return ,$l }
function L($grp, $frame, $shadow = $false) { $g = G $grp; if (-not $g) { return $null }; New-Object ScLayer $g, $frame, $shadow }

# $Bldgs, not $B: PowerShell names are case-insensitive
$Bldgs = @(
    @{ Id = 'SCNGEN'; Name = 'Power Generator'; Grp = 'Generate'; Shad = 'tgnShad'; Fw = 4; Fh = 3; Height = 3 }
    @{ Id = 'SCNSTB'; Name = 'Starbase';        Grp = 'starbase'; Shad = '';        Fw = 3; Fh = 3; Height = 4 }
    @{ Id = 'SCNPSI'; Name = 'Psi Disrupter';   Grp = 'PsiDisr';  Shad = 'tpdShad'; Fw = 5; Fh = 3; Height = 3 }
    @{ Id = 'SCNION'; Name = 'Ion Cannon';      Grp = 'ion';      Shad = '';        Fw = 4; Fh = 3; Height = 3 }
    @{ Id = 'SCNSTA'; Name = 'Stasis Cell';     Grp = 'stasis';   Shad = '';        Fw = 4; Fh = 3; Height = 3 }
)
$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$artBody = New-Object Text.StringBuilder
[void]$artBody.AppendLine('; StarCraft neutral buildings (Modding/tools/build-scneutral.ps1, MIX/ECACHE75.MIX; wiki mods/sc-neutral-buildings).')
[void]$artBody.AppendLine('; SHP: frame 0 normal, 1 damaged, 2-3 shadows. Placed by maps only (no buildup, no cameo); rules in the map.')
foreach ($bd in $Bldgs) {
    $sizes = @($bd.Grp, $bd.Shad) | Where-Object { $_ } | ForEach-Object { G $_ }
    $maxW = ($sizes | ForEach-Object { $_.Width } | Measure-Object -Maximum).Maximum
    $maxH = ($sizes | ForEach-Object { $_.Height } | Measure-Object -Maximum).Maximum
    $shape = New-Object ScBuildingShape $bd.Fw, $bd.Fh, $maxW, $maxH, 0
    $body = Layers (L $bd.Grp 0)
    $shad = Layers (L $bd.Shad 0 $true)
    $bldg = $shape.Building($body, $shad, $map, $dmgMap)
    $files["$($bd.Id).SHP"] = $bldg.Write()
    [ScBuildings]::FitPreview($bldg, 0, 2, $shape, $unitPal, 2, "$PreviewDir\fit_$($bd.Id).png")
    "{0,-7} {1,-16} grp {2}x{3} ({4} frames) foundation {5}x{6} canvas {7}x{8}" -f $bd.Id, $bd.Name, (G $bd.Grp).Width, (G $bd.Grp).Height, (G $bd.Grp).Frames.Count, $bd.Fw, $bd.Fh, $shape.Cw, $shape.Ch
    [void]$artBody.AppendLine("[$($bd.Id)]")
    [void]$artBody.AppendLine("Foundation=$($bd.Fw)x$($bd.Fh)")
    [void]$artBody.AppendLine("Height=$($bd.Height)")
    [void]$artBody.AppendLine('Remapable=yes')
    [void]$artBody.AppendLine('NewTheater=no')
    [void]$artBody.AppendLine('')
}
if ($WhatIf) { "WhatIf: previews in $PreviewDir, nothing written"; return }
[Mix]::Write($mixOut, $files)
$check = New-Object Mix $mixOut
foreach ($k in $files.Keys) { $s = [Shp]::Read($check.Read($k)); if ($s.Frames.Count -ne 4) { throw "bad $k ($($s.Frames.Count) frames)" } }
# Art.ini block (re-running replaces it); backup once, as every generator
$begin = '; >>> SC neutral buildings'; $end = '; <<< SC neutral buildings'
if (-not (Test-Path "$art.bak")) { Copy-Item $art "$art.bak" }
$t = [IO.File]::ReadAllText($art, $latin); $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
$block = $begin + $nl + ($artBody.ToString().TrimEnd() -replace "`r?`n", $nl) + $nl + $end + $nl
$a = $t.IndexOf($begin)
if ($a -ge 0) { $e = $t.IndexOf("`n", $t.IndexOf($end, $a)) + 1; $t = $t.Substring(0, $a) + $block + $t.Substring($e) }
else { if (-not $t.EndsWith("`n")) { $t += $nl }; $t += $nl + $block }
[IO.File]::WriteAllText($art, $t, $latin)
"written $mixOut ($($files.Count) files, round-trip OK) and the Art.ini block '$begin'; previews in $PreviewDir"
