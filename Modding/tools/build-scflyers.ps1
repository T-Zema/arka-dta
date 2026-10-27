# EXPERIMENT 2026-10-25: Terran warships as SHP VEHICLES with the aircraft (Fly) locomotor, like the TS Hunter-Seeker
# ([HUNTSEEK1] in Rules.ini). Jumpjet vehicles land when idle; jumpjet infantry hover but only have 8 facings.
# Output: -OutMix (default <game>\MIX\ECACHE90.MIX): SCWRAF, SCVALF, SCVESF, SCBCF = 32 facings + silhouette shadows.
# NOT 91-95: the DTA client copies Resources\ECache91-95.mix into MIX\ for its options (95 = RA radar sounds).
# Cameos and sounds are reused from ECACHE97 (build-scunits.ps1). Rules/Art: block "StarCraft flyers TEST" at the end of
# INI/Game Options/StarCraft.ini and INI/Art.ini. Wiki: Modding/wiki/mods/starcraft-terran-units.md.
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\scflyers-preview",
    [string]$OutMix = ""
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $OutMix) { $OutMix = "$game\MIX\ECACHE90.MIX" }
Add-Type -Path "$tools\Casc.cs","$tools\ModTools.cs","$tools\ScBuild.cs","$tools\ScBuildings.cs","$tools\ScUnits.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null

$casc  = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"

# --- palettes (same as build-scunits.ps1)
$scPal   = [Pal]::ReadWpe($casc.ReadFile('TileSet/jungle.wpe'))
$unitPal = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$w = 0; $h = 0; $tpal = $null
$tunit = [Pal]::ReadPcx($casc.ReadFile('game/tunit.pcx'), [ref]$w, [ref]$h, [ref]$tpal)
$ramp = New-Object 'System.Drawing.Color[]' 8
for ($i = 0; $i -lt 8; $i++) { $ramp[$i] = $tpal[$tunit[$i]] }
$map = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)

$grpCache = @{}
function G($name) {
    if (-not $grpCache.ContainsKey($name)) { $grpCache[$name] = [Grp]::Read($casc.ReadFile("unit/terran/$name.grp")) }
    return $grpCache[$name]
}
function Lo($name) { return ,([ScVehicle]::ReadLo($casc.ReadFile("unit/terran/$name"))) }

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
# vehicle SHP layout: stand 0-31 (one frame per facing, clockwise from north), shadows 32-63 (Art: Facings=32, WalkFrames=1)
function Flyer($id, [scriptblock]$draw, $cw, $ch) {
    $u = New-Object UnitBuilder $cw, $ch, $map
    for ($f = 0; $f -lt 32; $f++) { $b = & $draw $u $f; $u.Add($b, $u.Silhouette($b, 0, 0)) }
    $shp = $u.ToShp()
    $files["$id.SHP"] = $shp.Write()
    [Pal]::Sheet($shp.Frames, [int[]](0,4,8,12,16,20,24,28,32,40), $shp.Width, $shp.Height, $unitPal, 2, 10, "$PreviewDir\$id.png")
    "{0,-8} {1,4} frames {2}x{3}" -f $id, $shp.Frames.Count, $shp.Width, $shp.Height
}
Flyer 'SCWRAF' { param($u, $f) $u.Layer($u.New(), (G 'phoenix'), 0, $f, $true, $null, 0, 0, $false) } 64 64
Flyer 'SCVALF' { param($u, $f) $u.Layer($u.New(), (G 'bomber'), 0, $f, $true, $null, 0, 0, $false) } 128 128
Flyer 'SCBCF'  { param($u, $f) $u.Layer($u.New(), (G 'battlecr'), 0, $f, $true, $null, 0, 0, $false) } 120 120
$vLo = Lo 'wessel.lol'
Flyer 'SCVESF' { param($u, $f) $x = $u.Layer($u.New(), (G 'wessel'), 0, $f, $false, $null, 0, 0, $false); $u.Layer($x, (G 'wesselt'), 0, $f, $true, $null, $vLo[0][0], $vLo[0][1], $false) } 100 128

[Mix]::Write($OutMix, $files)
"$OutMix : $($files.Count) files"
$check = New-Object Mix $OutMix
foreach ($k in $files.Keys) { if (-not $check.Has($k)) { throw "missing $k" }; $s = [Shp]::Read($check.Read($k)); if ($s.Frames.Count -ne 64) { throw "bad $k" } }
"round-trip OK; previews -> $PreviewDir"
