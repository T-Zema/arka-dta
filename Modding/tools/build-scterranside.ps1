# Terran side look and voice (terran-faction session): sidebar + EVA for TerranSide (side 6 -> SIDEC07.MIX, SPEECH07.MIX).
#  - Sidebar: SideC03.mix (Allies) with SIDEBAR.PAL recoloured like StarCraft's Terran console (SD/game/tconsole.DDS:
#    dark rusty metal + cyan stripes): neutral greys -> rusty dark metal, gold -> cyan; functional colours stay. The 8-bit
#    PCX dialog pieces get the same palette treatment. Radar start-up frames 0-9: the Allied logo becomes the SC Terran
#    lobby marine (webui/dist/lib/images/terran.webm, needs ffmpeg) fading out over the radar grid.
#  - EVA: Speech03.mix (Allied EVA) with the events StarCraft voices replaced by the Terran adjutant (advisor lines
#    identified with the en-US speech recogniser + phrase grammar, see the wiki), the SCV "Job's finished" and SC win/lose.
# Output: MIX/SideC07.mix, MIX/Speech07.mix (SIDENC07.MIX stays the Allied copy). Previews: %TEMP%\scterranside\*.png
# Wiki: Modding/wiki/mods/terran-faction.md (section "Sidebar i EVA").
param([string]$StarCraft = "C:\Program Files (x86)\StarCraft",
      [string]$FFmpeg = "",
      [string]$Game = (Resolve-Path "$PSScriptRoot\..\..").Path)
$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot\Casc.cs", "$PSScriptRoot\ModTools.cs" -ReferencedAssemblies System.Drawing
Add-Type -AssemblyName System.Drawing
$casc = New-Object Casc $StarCraft
$prev = Join-Path $env:TEMP 'scterranside'; New-Item -ItemType Directory -Force $prev | Out-Null

# --- MIX entries with their names (from the XCC "local mix database.dat" of the source MIX)
function Mix-Files([string]$path) {
    $m = New-Object Mix $path
    $lmd = $m.Read('local mix database.dat')
    $names = [Text.Encoding]::ASCII.GetString($lmd, 52, $lmd.Length - 52).Split([char]0) | Where-Object { $_ -and $_ -ne 'local mix database.dat' }
    $d = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
    foreach ($n in $names) { $b = $m.Read($n); if ($b) { $d[$n] = $b } }
    return ,$d
}

# --- colour transform: neutral greys -> rusty dark metal, gold/yellow -> cyan, everything else unchanged
function Terranize([System.Drawing.Color]$c) {
    $mx = [Math]::Max($c.R, [Math]::Max($c.G, $c.B)); $mn = [Math]::Min($c.R, [Math]::Min($c.G, $c.B)); $sat = $mx - $mn
    $l = 0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B
    if ($sat -lt 34) {
        # SC Terran console metal: dark maroon-brown (the Allied sidebar greys sit around 190 -> about 89,63,59)
        return [System.Drawing.Color]::FromArgb([int][Math]::Min(255, $l * 0.45 + 4), [int][Math]::Min(255, $l * 0.33), [int][Math]::Min(255, $l * 0.31))
    }
    $h = $c.GetHue()
    if ($h -ge 28 -and $h -le 62) {   # gold -> cyan, keep brightness
        return [System.Drawing.Color]::FromArgb([int]($l * 0.35), [int][Math]::Min(255, $l * 1.15), [int][Math]::Min(255, $l * 1.2))
    }
    return $c
}
function Ts-Pal-Bytes($colors) { $b = New-Object byte[] 768; for ($i = 0; $i -lt 256; $i++) { $b[$i*3] = [byte]($colors[$i].R -shr 2); $b[$i*3+1] = [byte]($colors[$i].G -shr 2); $b[$i*3+2] = [byte]($colors[$i].B -shr 2) }; return ,$b }

# ================================================================== sidebar
$side = Mix-Files "$Game\MIX\SideC03.mix"
$oldPal = [Pal]::ReadTs($side['sidebar.pal'])
$newPal = New-Object 'System.Drawing.Color[]' 256
for ($i = 0; $i -lt 256; $i++) { $newPal[$i] = if ($i -eq 0) { $oldPal[0] } else { Terranize $oldPal[$i] } }
$side['sidebar.pal'] = Ts-Pal-Bytes $newPal

# 8-bit PCX pieces (dialogs, scroll bars, trophies): same transform on their own palettes; pictures stay as they are
foreach ($n in @($side.Keys)) {
    if ($n -notmatch '\.pcx$' -or $n -in 'briefing.pcx', 'score.pcx') { continue }
    $w = 0; $h = 0; $p = $null
    $px = [Pal]::ReadPcx($side[$n], [ref]$w, [ref]$h, [ref]$p)
    if (-not $px) { continue }
    $np = New-Object 'System.Drawing.Color[]' 256; for ($i = 0; $i -lt 256; $i++) { $np[$i] = Terranize $p[$i] }
    $side[$n] = [Pal]::WritePcx($px, $w, $h, $np)
}

# radar start-up: frames 0-9 show the side logo fading out; replace it with the SC Terran lobby marine over the radar grid
$radar = [Shp]::Read($side['radar.shp'])
$marine = $null
if (-not $FFmpeg) { $FFmpeg = (Get-ChildItem "$env:TEMP\claude" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName }
if ($FFmpeg -and (Test-Path $FFmpeg)) {
    $webm = "$prev\terran.webm"; [IO.File]::WriteAllBytes($webm, $casc.ReadFile('webui/dist/lib/images/terran.webm'))
    & $FFmpeg -hide_banner -loglevel error -y -c:v libvpx-vp9 -ss 2.5 -i $webm -frames:v 1 "$prev\marine.png"
    if (Test-Path "$prev\marine.png") { $marine = [System.Drawing.Bitmap]::FromFile("$prev\marine.png") }
}
if ($marine) {
    # screen = pixels that are black in frame 10 (empty screen); everything else is the frame border
    $f10 = $radar.Frames[10]; $grid = $radar.Frames[40]
    $W = $radar.Width; $H = $radar.Height
    function Px($f, $x, $y) { if ($x -lt $f.X -or $y -lt $f.Y -or $x -ge $f.X + $f.W -or $y -ge $f.Y + $f.H) { return 0 }; return $f.Pixels[($y - $f.Y) * $f.W + ($x - $f.X)] }
    $screen = New-Object 'bool[,]' $W, $H; $sx0 = $W; $sy0 = $H; $sx1 = 0; $sy1 = 0
    for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) { $v = Px $f10 $x $y; $c = $oldPal[$v]; if ($v -ne 0 -and ($c.R + $c.G + $c.B) -lt 30) { $screen[$x, $y] = $true; if ($x -lt $sx0) { $sx0 = $x }; if ($y -lt $sy0) { $sy0 = $y }; if ($x -gt $sx1) { $sx1 = $x }; if ($y -gt $sy1) { $sy1 = $y } } } }
    # crop the marine (white background) and fit it into the screen
    $bx0 = $marine.Width; $by0 = $marine.Height; $bx1 = 0; $by1 = 0
    for ($y = 0; $y -lt $marine.Height; $y += 2) { for ($x = 0; $x -lt $marine.Width; $x += 2) { $c = $marine.GetPixel($x, $y); if (($c.R + $c.G + $c.B) -lt 690) { if ($x -lt $bx0) { $bx0 = $x }; if ($y -lt $by0) { $by0 = $y }; if ($x -gt $bx1) { $bx1 = $x }; if ($y -gt $by1) { $by1 = $y } } } }
    $sw = $sx1 - $sx0 + 1; $sh = $sy1 - $sy0 + 1; $scale = [Math]::Min(($sh - 6) / ($by1 - $by0 + 1), ($sw - 6) / ($bx1 - $bx0 + 1))
    $mw = [int](($bx1 - $bx0 + 1) * $scale); $mh = [int](($by1 - $by0 + 1) * $scale)
    $small = New-Object System.Drawing.Bitmap $mw, $mh
    $g = [System.Drawing.Graphics]::FromImage($small); $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($marine, (New-Object System.Drawing.Rectangle 0, 0, $mw, $mh), $bx0, $by0, ($bx1 - $bx0 + 1), ($by1 - $by0 + 1), 'Pixel'); $g.Dispose()
    $ox = $sx0 + [int](($sw - $mw) / 2); $oy = $sy0 + [int](($sh - $mh) / 2)
    $cache = @{}
    function Near([System.Drawing.Color]$c) { $k = $c.ToArgb(); if (-not $cache.ContainsKey($k)) { $cache[$k] = [Pal]::Nearest($c, $newPal, 1, 255) }; return $cache[$k] }
    for ($fi = 0; $fi -le 9; $fi++) {
        $fade = 1.0 - $fi / 10.0
        $src = $radar.Frames[$fi]; $nf = New-Object Frame 0, 0, $W, $H
        for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) {
            $v = Px $src $x $y
            if ($screen[$x, $y]) {
                $c = $newPal[(Px $grid $x $y)]; $c = [System.Drawing.Color]::FromArgb([int]($c.R * $fade * 0.6), [int]($c.G * $fade * 0.6), [int]($c.B * $fade * 0.6))
                $mx = $x - $ox; $my = $y - $oy
                if ($mx -ge 0 -and $my -ge 0 -and $mx -lt $mw -and $my -lt $mh) { $m = $small.GetPixel($mx, $my); if (($m.R + $m.G + $m.B) -lt 690) { $c = [System.Drawing.Color]::FromArgb([int]($m.R * $fade), [int]($m.G * $fade), [int]($m.B * $fade)) } }
                $v = Near $c
            }
            $nf.Pixels[$y * $W + $x] = [byte]$v } }
        $radar.Frames[$fi] = $nf
    }
    $side['radar.shp'] = $radar.Write()
    $small.Dispose(); $marine.Dispose()
} else { "ffmpeg not found: radar logo frames left unchanged (only recoloured by the palette)" }

[Mix]::Write("$Game\MIX\SideC07.mix", $side)
"SideC07.mix: $($side.Count) files (sidebar.pal recoloured, $(@($side.Keys | Where-Object { $_ -match '\.pcx$' }).Count) PCX, radar logo: $([bool]$marine))"

# previews with the new palette
$parts = New-Object 'System.Collections.Generic.List[Frame]'
foreach ($n in 'side1.shp', 'side2.shp', 'side3.shp', 'addon.shp', 'tabs.shp') { $s = [Shp]::Read($side[$n]); $parts.Add($s.Frames[0]) }
[Pal]::Sheet($parts, [int[]](0..4), 168, 63, $newPal, 2, 1, "$prev\sidebar_parts.png")
$r = [Shp]::Read($side['radar.shp']); [Pal]::Sheet($r.Frames, [int[]]@(0, 3, 6, 9, 20, 30, 40), $r.Width, $r.Height, $newPal, 1, 7, "$prev\radar.png")

# ================================================================== EVA (Terran adjutant)
# TS vox file (game.exe Speech[] table, order = Vinifera EvaNames) -> StarCraft sound
$eva = [ordered]@{
    '00-i016' = 'SD/sound/terran/advisor/taderr04.wav'   # Cannot deploy here      <- "Unacceptable landing zone" (recogniser 0.42)
    '00-i018' = 'SD/sound/terran/scv/tscupd00.wav'       # Construction complete   <- SCV "Job's finished"
    '00-i022' = 'SD/sound/terran/advisor/taderr00.wav'   # Insufficient funds      <- "Not enough minerals"
    '00-i024' = 'SD/sound/terran/advisor/taderr02.wav'   # Low power               <- "Additional supply depots required"
    '00-i032' = 'SD/sound/terran/advisor/tadupd02.wav'   # New construction options <- "Research complete" (likely)
    '00-i068' = 'SD/sound/terran/advisor/tadupd06.wav'   # Unit armor upgraded     <- "Upgrade complete" (likely)
    '00-i070' = 'SD/sound/terran/advisor/tadupd06.wav'   # Unit firepower upgraded
    '00-i080' = 'SD/sound/terran/advisor/tadupd06.wav'   # Unit speed upgraded
    '00-i082' = 'SD/sound/terran/advisor/tadupd00.wav'   # Base under attack       <- "Your base is under attack" (recogniser)
    '00-i090' = 'SD/sound/terran/advisor/tadupd01.wav'   # Harvester under attack  <- "Your forces are under attack"
    '00-i308' = 'SD/sound/terran/advisor/tadupd01.wav'   # Our ally is under attack
    '00-i150' = 'SD/sound/terran/advisor/tadupd04.wav'   # Missile launch detected <- "Nuclear launch detected"
    '00-i152' = 'SD/sound/terran/advisor/tadupd07.wav'   # Chemical missile ready  <- "Nuclear missile ready"
    '00-i154' = 'SD/sound/terran/advisor/tadupd07.wav'   # Cluster missile ready (MultiSpecial = SC Nuclear Silo)
    '00-i026' = 'SD/sound/misc/youwin.wav'               # Mission accomplished
    '00-i284' = 'SD/sound/misc/youwin.wav'               # You are victorious
    '00-i028' = 'SD/sound/misc/youlose.wav'              # Mission failed
    '00-i286' = 'SD/sound/misc/youlose.wav'              # You have lost
}
$speech = Mix-Files "$Game\MIX\Speech03.mix"
foreach ($k in $eva.Keys) {
    $rate = 0
    $pcm = [Aud]::ReadWav($casc.ReadFile($eva[$k]), [ref]$rate)
    $speech["$k.aud"] = [Aud]::Encode($pcm, $rate, 1.0)
}
[Mix]::Write("$Game\MIX\Speech07.mix", $speech)
"Speech07.mix: $($speech.Count) files ($($eva.Count) Terran lines)"
"previews: $prev"
