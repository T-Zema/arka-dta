# Builds the StarCraft Marine assets for DTA from the user's StarCraft: Remastered install.
# Output: <game>\MIX\ECACHE99.MIX (SHPs + AUDs) and preview PNGs in -PreviewDir.
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\scmarine-preview",
    [string]$FFmpeg = ""    # optional: path to ffmpeg.exe, used to grab the portrait cameo from the .webm
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs","$tools\ModTools.cs","$tools\ScBuild.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null

$casc = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"

# --- palettes
$scPal    = [Pal]::ReadWpe($casc.ReadFile('TileSet/jungle.wpe'))
$unitPal  = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$cameoPal = [Pal]::ReadTs($mixes.Read('CAMEO.PAL'))
$w = 0; $h = 0; $tpal = $null
$tunit = [Pal]::ReadPcx($casc.ReadFile('game/tunit.pcx'), [ref]$w, [ref]$h, [ref]$tpal)
$ramp = New-Object 'System.Drawing.Color[]' 8
for ($i = 0; $i -lt 8; $i++) { $ramp[$i] = $tpal[$tunit[$i]] }   # player 1 (red) colour ramp

$mapRemap = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)     # normal marine, house colours
$mapStim  = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0.35)  # stimmed: red tint, house colours kept
$mapAnim  = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $false, 0)    # death anim: fixed colours

# --- sprites
$body   = [Grp]::Read($casc.ReadFile('unit/terran/marine.grp'))
$shadow = [Grp]::Read($casc.ReadFile('unit/terran/tmashad.grp'))
$remain = [Grp]::Read($casc.ReadFile('unit/terran/tmadeath.grp'))
$walk = [int[]](4..12)          # SC sets 4..12 = 9 walk frames
$unitShp = [ScBuild]::BuildUnit($body, $shadow, $mapRemap, $walk, 2, 3)
$stimShp = [ScBuild]::BuildUnit($body, $shadow, $mapStim,  $walk, 2, 3)

$deathFrames = New-Object 'System.Collections.Generic.List[Frame]'
foreach ($i in 221..228) { $deathFrames.Add($body.Frames[$i]) }
foreach ($f in $remain.Frames) { $deathFrames.Add($f) }
$deathShp = [ScBuild]::BuildAnim($deathFrames, 64, 64, $mapAnim)

# --- cameos: first frame of the HD2 portrait video (needs ffmpeg), fallback = upscaled sprite
if ($FFmpeg -and (Test-Path $FFmpeg)) {
    $webm = Join-Path $PreviewDir 'tmafid00.webm'; $png = Join-Path $PreviewDir 'portrait.png'
    [IO.File]::WriteAllBytes($webm, $casc.ReadFile('HD2/portrait/tmarine/tmafid00.webm'))
    & $FFmpeg -hide_banner -loglevel error -y -i $webm -frames:v 1 $png
    $portrait = [System.Drawing.Bitmap]::FromFile($png)
    $crop = New-Object System.Drawing.Rectangle 0, 40, 224, 168      # 4:3 band around the face
    $cameo  = [ScBuild]::BuildPortraitCameo($portrait, $crop, $cameoPal, $false)
    $cameo2 = [ScBuild]::BuildPortraitCameo($portrait, $crop, $cameoPal, $true)
    $portrait.Dispose()
} else {
    $cameo  = [ScBuild]::BuildCameo($body.Frames[12], 64, 64, $scPal, $ramp, $cameoPal, 2, 0, 2)
    $cameo2 = $cameo
}

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$files['SCMARINE.SHP']   = $unitShp.Write()
$files['SCMARSTM.SHP']   = $stimShp.Write()
# Upgraded Marine needs its own file names: Art.ini Image= is ignored for units, and the cameo comes from the art section.
$files['SCMARIN2.SHP']   = $files['SCMARINE.SHP']
$files['SCMARST2.SHP']   = $files['SCMARSTM.SHP']
$files['SCMADTH.SHP']    = $deathShp.Write()
$files['SCMARICON.SHP']  = $cameo.Write()
$files['SCMAR2ICON.SHP'] = $cameo2.Write()

# (research upgrades and upgraded unit variants: Modding/tools/build-scresearch.ps1 -> MIX/ECACHE89.MIX)

# --- sounds (SD = 22050 Hz 16-bit mono, matches DTA .aud)
$sounds = [ordered]@{
    'SCMAWHT0'='SD/sound/terran/marine/tmawht00.wav'; 'SCMAWHT1'='SD/sound/terran/marine/tmawht01.wav'
    'SCMAWHT2'='SD/sound/terran/marine/tmawht02.wav'; 'SCMAWHT3'='SD/sound/terran/marine/tmawht03.wav'
    'SCMAYES0'='SD/sound/terran/marine/tmayes00.wav'; 'SCMAYES1'='SD/sound/terran/marine/tmayes01.wav'
    'SCMAYES2'='SD/sound/terran/marine/tmayes02.wav'; 'SCMAYES3'='SD/sound/terran/marine/tmayes03.wav'
    'SCMASTI0'='SD/sound/terran/marine/tmasti00.wav'; 'SCMASTI1'='SD/sound/terran/marine/tmasti01.wav'
    'SCMADTH0'='SD/sound/terran/marine/tmadth00.wav'; 'SCMADTH1'='SD/sound/terran/marine/tmadth01.wav'
    'SCMARDY0'='SD/sound/terran/marine/tmardy00.wav'
    'SCMAFIRE'='SD/sound/bullet/tmafir00.wav'
}
foreach ($k in $sounds.Keys) {
    $rate = 0
    $pcm = [Aud]::ReadWav($casc.ReadFile($sounds[$k]), [ref]$rate)
    $gain = if ($k -like 'SCMADTH*') { 2.0 } else { 1.0 }   # death screams: louder (user request), encoder clips
    $files["$k.AUD"] = [Aud]::Encode($pcm, $rate, $gain)
}

[Mix]::Write("$game\MIX\ECACHE99.MIX", $files)
"ECACHE99.MIX: $($files.Count) files"
foreach ($k in $files.Keys) { "  {0,-14} {1,8} B" -f $k, $files[$k].Length }

# --- previews
$n = $unitShp.Frames.Count / 2
[Pal]::Sheet($unitShp.Frames, [int[]](0..31), 64, 64, $unitPal, 2, 16, "$PreviewDir\stand_32.png")
[Pal]::Sheet($unitShp.Frames, [int[]](32..49 + ($n)..($n+15)), 64, 64, $unitPal, 2, 18, "$PreviewDir\walk_and_shadow.png")
[Pal]::Sheet($stimShp.Frames, [int[]](0,4,8,12,16,20,24,28) + (320..335), 64, 64, $unitPal, 2, 12, "$PreviewDir\stim_and_fire.png")
[Pal]::Sheet($deathShp.Frames, [int[]](0..10), 64, 64, $unitPal, 2, 11, "$PreviewDir\death.png")
$both = New-Object 'System.Collections.Generic.List[Frame]'; $both.Add($cameo.Frames[0]); $both.Add($cameo2.Frames[0])[Pal]::Sheet($both, [int[]](0..($both.Count-1)), 64, 48, $cameoPal, 4, $both.Count, "$PreviewDir\cameo.png")
# round-trip check: re-read the written SHP from the MIX
$check = [Shp]::Read((New-Object Mix "$game\MIX\ECACHE99.MIX").Read('SCMARINE.SHP'))
"round-trip SCMARINE.SHP: $($check.Frames.Count) frames, $($check.Width)x$($check.Height)"
[Pal]::Sheet($check.Frames, [int[]](0,8,16,24,40,328,329,384), 64, 64, $unitPal, 2, 8, "$PreviewDir\roundtrip.png")
"previews -> $PreviewDir"
