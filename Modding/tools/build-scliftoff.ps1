# Builds the "lifted" (flying) versions of the Terran buildings: a jumpjet UnitType per building that DeploysInto the
# building, while the building UndeploysInto it (SC lift-off). The sprite is the finished building frame (frame 0 of
# <ID>.SHP from ECACHE98.MIX), re-centred on the unit (foundation centre -> canvas centre), 8 identical facings
# (lifted SC buildings do not turn) + 8 shadow frames (building shadow, frame 2). Missile Turret also gets its head.
# Output: MIX/ECACHE89.MIX (<ID>F.SHP). Rules/Art: block "Lifted Terran buildings" in StarCraft.ini and Art.ini.
# Wiki: Modding/wiki/mods/starcraft-terran-buildings.md. Previews: %TEMP%\scliftoff\lifted.png
param([string]$Game = (Resolve-Path "$PSScriptRoot\..\..").Path)
$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot\ModTools.cs" -ReferencedAssemblies System.Drawing

# Id, foundation W, H (from Art.ini). Addons, Supply Depots, Comsat and Nuclear Silo (SC addons) stay grounded.
# 2026-10-25, user decision (map session): only the SC lifters fly - SCCC, SCBARR, SCEBAY, SCFACT, SCSTAR, SCSCIF. The
# UndeploysInto lines of SCREFI, SCMTUR, SCACAD, SCBUNK, SCARMO are commented out in StarCraft.ini; their <ID>F SHPs are
# still built here because the (unreachable) vehicles stay registered. Do not re-enable them without asking the user.
$liftable = @(
    @('SCCC',4,3), @('SCREFI',4,3), @('SCBARR',4,3), @('SCEBAY',4,3), @('SCMTUR',2,2), @('SCACAD',3,2),
    @('SCBUNK',3,2), @('SCFACT',4,3), @('SCSTAR',4,3), @('SCSCIF',4,3), @('SCARMO',3,2))
$facings = 8

$mixes   = New-Object MixSet "$Game\MIX"
$unitPal = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$prev = Join-Path $env:TEMP 'scliftoff'; New-Item -ItemType Directory -Force $prev | Out-Null

function Shift-Frame($f, [int]$ox, [int]$oy) {
    $n = New-Object Frame ($f.X + $ox), ($f.Y + $oy), $f.W, $f.H
    [Array]::Copy($f.Pixels, $n.Pixels, $f.Pixels.Length)
    return $n
}

# Paints $top over $base (both in the same canvas); returns a frame covering both.
function Merge-Frames($base, $top) {
    $x0 = [Math]::Min($base.X, $top.X); $y0 = [Math]::Min($base.Y, $top.Y)
    $x1 = [Math]::Max($base.X + $base.W, $top.X + $top.W); $y1 = [Math]::Max($base.Y + $base.H, $top.Y + $top.H)
    $m = New-Object Frame $x0, $y0, ($x1 - $x0), ($y1 - $y0)
    foreach ($f in @($base, $top)) {
        for ($y = 0; $y -lt $f.H; $y++) { for ($x = 0; $x -lt $f.W; $x++) {
            $v = $f.Pixels[$y * $f.W + $x]; if ($v -ne 0) { $m.Pixels[($f.Y + $y - $y0) * $m.W + ($f.X + $x - $x0)] = $v } } }
    }
    return $m
}

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$sheet = New-Object 'System.Collections.Generic.List[Frame]'; $maxW = 0; $maxH = 0
foreach ($b in $liftable) {
    $id = $b[0]; $fw = $b[1]; $fh = $b[2]
    $src = [Shp]::Read($mixes.Read("$id.SHP"))
    $body = $src.Frames[0]; $shadow = $src.Frames[2]
    if ($id -eq 'SCMTUR') { $head = [Shp]::Read($mixes.Read('SCMTUR_A.SHP')); $body = Merge-Frames $body $head.Frames[0] }
    # Building canvas centre = top vertex of the foundation diamond; foundation centre is (12(W-H), 6(W+H)) below it.
    $dx = 12 * ($fw - $fh); $dy = 6 * ($fw + $fh)
    $out = New-Object Shp
    $out.Width = $src.Width + 2 * [Math]::Abs($dx); $out.Height = $src.Height + 2 * [Math]::Abs($dy)
    $ox = [Math]::Abs($dx) - $dx; $oy = [Math]::Abs($dy) - $dy
    for ($i = 0; $i -lt $facings; $i++) { $out.Frames.Add((Shift-Frame $body $ox $oy)) }
    for ($i = 0; $i -lt $facings; $i++) { $out.Frames.Add((Shift-Frame $shadow $ox $oy)) }
    $files["${id}F.SHP"] = $out.Write()
    $sheet.Add($out.Frames[0]); $maxW = [Math]::Max($maxW, $out.Width); $maxH = [Math]::Max($maxH, $out.Height)
}
[Mix]::Write("$Game\MIX\ECACHE89.MIX", $files)

# Preview: each lifted sprite centred in a common canvas (the cross marks the unit position = canvas centre).
$prevFrames = New-Object 'System.Collections.Generic.List[Frame]'
for ($k = 0; $k -lt $sheet.Count; $k++) {
    $s = [Shp]::Read($files["$($liftable[$k][0])F.SHP"])
    $f = Shift-Frame $s.Frames[0] (($maxW - $s.Width) / 2) (($maxH - $s.Height) / 2)
    $cross = New-Object Frame ($maxW / 2 - 3), ($maxH / 2), 7, 1; for ($x = 0; $x -lt 7; $x++) { $cross.Pixels[$x] = 1 }
    $prevFrames.Add((Merge-Frames $f $cross))
}
[Pal]::Sheet($prevFrames, @(0..($prevFrames.Count - 1)), $maxW, $maxH, $unitPal, 1, 6, "$prev\lifted.png")
"ECACHE89.MIX: " + (($files.Keys | ForEach-Object { "$_ ($($files[$_].Length) B)" }) -join ', ')
"preview: $prev\lifted.png"
