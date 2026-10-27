# Converts a StarCraft (Remastered) map into a DTA skirmish map.
# Usage: .\convert-scmap.ps1 -Map "C:\Program Files (x86)\StarCraft\Maps\ladder\(4)Lost Temple.scm" -Out "<game>\Maps\Custom\sc_lost_temple.map"
param(
    [string]$Map = "C:\Program Files (x86)\StarCraft\Maps\ladder\(4)Lost Temple.scm",
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$Out = "",
    [string]$Name = "",
    [string]$DebugDir = "$env:TEMP\scmap-debug",
    [ValidateSet('cliffs', 'shores')][string]$WaterStyle = 'cliffs',
    [switch]$Render,
    [switch]$Preview
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs","$tools\ModTools.cs","$tools\ScMap.cs","$tools\TsMap.cs","$tools\ScToDta.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $DebugDir | Out-Null

# --- StarCraft side
$casc = New-Object Casc $StarCraft
$mpq  = New-Object Mpq (,[IO.File]::ReadAllBytes($Map))
$chk  = New-Object Chk (,$mpq.Read('staredit\scenario.chk'))
$era  = [Chk]::EraNames[$chk.Era]
$ts   = New-Object ScTileset $casc, $era
$ter  = New-Object ScTerrain $chk, $ts
$sprp = $chk.Sections['SPRP']
$scName = if ($sprp) { $chk.Str([BitConverter]::ToUInt16($sprp, 0)) } else { '' }
$scName = ($scName -replace '[\x00-\x1F]', '').Trim()
$fileName = ([IO.Path]::GetFileNameWithoutExtension($Map) -replace '^\(\d+\)', '' -replace '_', ' ').Trim()
# scenario names of ladder maps carry tags ("| iCCup | ...") or Korean text; then the file name reads better
$display = if ($scName -match '^[A-Za-z0-9 .,''!&-]+$') { $scName } else { $fileName }
if (-not $Name) { $Name = "$display (StarCraft)" }
if (-not $Out) { $Out = Join-Path $game ("Maps\Custom\sc_" + (($fileName -replace '[^A-Za-z0-9]+', '_').Trim('_').ToLower()) + ".map") }
"SC map: $scName, $($chk.Width)x$($chk.Height), tileset $era"

# --- DTA side
$mixes = New-Object MixSet "$game\MIX"
$th    = New-Object Theater "$game\INI\Temperat.ini", "tem", $mixes
$wae   = "$game\Map Editor\Editor\Config\ConnectedTileDrawer.ini"
$cliffs = New-Object ConnectedSet $wae, "TemperateCliffSet", $th
$shoreSet = if ($WaterStyle -eq 'cliffs') { "TemperateWaterCliffSet" } else { "TemperateShoreSet" }
$shores = New-Object ConnectedSet $wae, $shoreSet, $th
"cliff pieces: $($cliffs.Pieces.Count), $shoreSet pieces: $($shores.Pieces.Count)"

$conv = New-Object ScToDta $chk, $ter, $th
$conv.Classify()
$conv.Resources()
$conv.Cliffs($cliffs)
$conv.Shores($shores, $WaterStyle -eq 'cliffs')
$conv.SettleWater()
$conv.FillWater($th.SetByName('Animated Water'), $th.SetByName('Water').Start)
$trees = [string[]]@('T01','T02','T03','T05','T06','T07','T08','T09','T10','T11','T12','T13','T14','T15','T16','T17','JBR01','JBR02','JBR03','JBR04','JBR05')
$rocks = $th.SetByName('Small Rocks').Start
$conv.Obstacles($trees, [int[]]@($rocks, ($rocks + 3)))
$conv.Cleanup()
$conv.RepairDecorations()
$conv.PaintGround()
# ground order: grass, dirt, pavement, tall grass (see ScToDta.Ground)
$base = [int[]]@(0, $th.SetByName('Dirt LAT').Start, $th.SetByName('Pavement LAT').Start, $th.SetByName('Tall Grass').Start)
$lat  = [int[]]@(0, $th.SetByName('Clear/Dirt LAT').Start, $th.SetByName('Clear/Pavement LAT').Start, $th.SetByName('Tall/Short Grass LAT').Start)
$conv.ApplyGround(0, $base, $lat)
$conv.WallFrames(2, [int[]]@(0, 2, 4, 6))
$conv.CheckConnectivity()
$cmp = $conv.CompareWithSc(); $cmp.Save("$DebugDir\compare_sc.png"); $cmp.Dispose()
$text = $conv.WriteMap($Name, "Blizzard Entertainment (port: Claude)")
[IO.File]::WriteAllText($Out, $text, [Text.Encoding]::GetEncoding(1252))
$conv.Log
"written $Out ($([Math]::Round((Get-Item $Out).Length / 1KB)) KB), Size 0,0,$($conv.W),$($conv.H)"
$dbg = $conv.DebugImage(); $dbg.Save("$DebugDir\cells.png"); $dbg.Dispose()
$dbg = $conv.ReachImage(); $dbg.Save("$DebugDir\reach.png"); $dbg.Dispose()
# original for comparison: 8 px per SC tile, starts white, minerals cyan, geysers green
$sc = $ter.RenderNatural(4); $g = [Drawing.Graphics]::FromImage($sc)
foreach ($u in $chk.Units) {
    $col = if ($u.Id -eq 214) { 'White' } elseif ($u.Id -eq 188) { 'Lime' } elseif ($u.Id -ge 176 -and $u.Id -le 178) { 'Cyan' } else { $null }
    if ($col) { $g.FillRectangle((New-Object Drawing.SolidBrush ([Drawing.Color]::$col)), $u.X / 4 - 3, $u.Y / 4 - 2, 6, 4) }
}
$g.Dispose(); $sc.Save("$DebugDir\sc.png"); $sc.Dispose()
$summary = [ordered]@{
    scName = $scName; name = $Name; source = $Map; out = $Out; tileset = $era
    size = "$($chk.Width)x$($chk.Height)"; dtaSize = "$($conv.W)x$($conv.H)"; starts = $conv.Starts.Count
    startsConnected = $conv.StartsConnected; gemsReachable = $conv.GemsReachable; gemsTotal = $conv.GemsTotal
    leaks = $conv.Leaks; sealed = $conv.Sealed; chainFailures = $conv.ChainFailures
}
$summary | ConvertTo-Json | Set-Content "$DebugDir\summary.json" -Encoding UTF8

# -Render: full-size picture with start markers into DebugDir.
# -Preview: client preview next to the map (<map>.png, 800 px wide, no markers: the client draws them).
function Invoke-Renderer([string]$outName, [string]$extra) {
    # CNCMaps renders a 128x128 SC map in ~3 s; kill it after 3 minutes instead of hanging the pipeline
    $dir = "$game\Map Editor\Map Renderer"
    $argList = "-i `"$Out`" -o $outName -d `"$DebugDir`" -p -T -m `"..\..\MIX`" -M modconfig.xml $extra"
    $p = Start-Process -FilePath "$dir\CNCMaps.Renderer.exe" -ArgumentList $argList -WorkingDirectory $dir -NoNewWindow -PassThru -RedirectStandardOutput "$DebugDir\render.log"
    if (-not $p.WaitForExit(180000)) { $p.Kill(); throw "CNCMaps renderer timed out (see $DebugDir\render.log)" }
    "rendered $outName.png"
}
if ($Render -or $Preview) {
    $base = [IO.Path]::GetFileNameWithoutExtension($Out)
    if ($Render) { Invoke-Renderer $base "--mark-start-pos -s" }
    if ($Preview) { Invoke-Renderer "${base}_full" "" }
    if ($Preview) {
        $full = [Drawing.Image]::FromFile("$DebugDir\${base}_full.png")
        $h = [int]($full.Height * 800 / $full.Width)
        $thumb = New-Object Drawing.Bitmap 800, $h
        $g = [Drawing.Graphics]::FromImage($thumb)
        $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($full, 0, 0, 800, $h); $g.Dispose(); $full.Dispose()
        $png = [IO.Path]::ChangeExtension($Out, '.png')
        $thumb.Save($png, [Drawing.Imaging.ImageFormat]::Png)
        # the client shows previews of Maps/Custom maps only from [PreviewPack] inside the map
        $ini = [Ini]::Load($Out)
        [MapPreview]::Set($ini, $thumb, 400); $thumb.Dispose()
        [IO.File]::WriteAllText($Out, $ini.Write(), [Text.Encoding]::GetEncoding(1252))
        "preview $png (800x$h) + [PreviewPack] 400 px in the map"
    }
}
