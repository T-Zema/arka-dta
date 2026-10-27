# One command from a StarCraft map name to a DTA skirmish map:
# find the .scm/.scx -> convert -> checks -> review sheet -> install into Maps\Custom (-> archive).
#
#   .\port-scmap.ps1 -List                       # unique SC maps: players, size, tileset (add -Filter "temple")
#   .\port-scmap.ps1 -Map "Fighting Spirit"      # convert + check + install when the checks pass
#   .\port-scmap.ps1 -Map "Python" -NoInstall    # build and review only
#   .\port-scmap.ps1 -Map "Lost Temple" -Archive # also snapshot into Modding\archive (+ zip)
#
# Look at <Work>\<slug>\review.png (original | DTA | reachability vs SC) before telling anyone it is good.
param(
    [string]$Map = "",
    [switch]$List,
    [string]$Filter = "",
    [int]$Pick = 0,
    [string]$Name = "",
    [string]$Work = "$env:TEMP\scmap",
    [switch]$NoInstall,
    [switch]$Force,
    [switch]$Archive,
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft"
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -AssemblyName System.Drawing

function Slug($path) { (([IO.Path]::GetFileNameWithoutExtension($path) -replace '^\(\d+\)', '') -replace '[^A-Za-z0-9]+', '_').Trim('_').ToLower() }

# unique map files (the ladder folders repeat the same map many times)
function UniqueMaps($pattern) {
    $files = Get-ChildItem "$StarCraft\Maps" -Recurse -File -Include *.scm, *.scx |
        Where-Object { -not $pattern -or ($_.BaseName -replace '_', ' ') -like "*$($pattern -replace '_', ' ')*" }
    $files | Group-Object { (Get-FileHash $_.FullName -Algorithm MD5).Hash } | ForEach-Object {
        $_.Group | Sort-Object { $_.FullName.Length } | Select-Object -First 1
    } | Sort-Object Name
}

if ($List) {
    Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScMap.cs" -ReferencedAssemblies System.Drawing
    $eras = [Chk]::EraNames
    UniqueMaps $Filter | ForEach-Object {
        $info = try {
            $chk = New-Object Chk (, (New-Object Mpq (, [IO.File]::ReadAllBytes($_.FullName))).Read('staredit\scenario.chk'))
            $starts = @($chk.Units | Where-Object { $_.Id -eq 214 }).Count
            "{0,3}x{1,-3} {2,-9} starts {3}" -f $chk.Width, $chk.Height, $eras[$chk.Era], $starts
        } catch { "unreadable ($($_.Exception.Message))" }
        "{0,-42} {1}  {2}" -f $_.Name, $info, $_.DirectoryName.Replace("$StarCraft\Maps", 'Maps')
    }
    return
}
if (-not $Map) { throw "Give -Map <name or path>, or -List." }

# --- resolve the map file
if (Test-Path -LiteralPath $Map) { $src = (Get-Item -LiteralPath $Map) }
else {
    $cands = @(UniqueMaps $Map)
    if ($cands.Count -eq 0) { throw "No StarCraft map matches '$Map'. Try -List -Filter <part of name>." }
    if ($cands.Count -gt 1) {
        "Several maps match '$Map' (using -Pick $Pick):"
        for ($i = 0; $i -lt $cands.Count; $i++) { "  [$i] $($cands[$i].FullName)" }
    }
    $src = $cands[$Pick]
}
$slug = Slug $src.FullName
$dir  = Join-Path $Work $slug
New-Item -ItemType Directory -Force $dir | Out-Null
$built = Join-Path $dir "sc_$slug.map"
"== $($src.Name) -> sc_$slug.map   (work: $dir)"

# --- convert (full log in log.txt)
$args2 = @{ Map = $src.FullName; Out = $built; DebugDir = $dir; Preview = $true }
if ($Name) { $args2.Name = $Name }
& "$tools\convert-scmap.ps1" @args2 *>&1 | ForEach-Object { "$_" } | Set-Content "$dir\log.txt" -Encoding UTF8
$s = Get-Content "$dir\summary.json" -Raw | ConvertFrom-Json

# --- verdict
$problems = @(); $notes = @()
if ($s.starts -lt 2) { $problems += "fewer than 2 start locations" }
if (-not $s.startsConnected) { $problems += "some starts cannot reach each other by ground" }
if ($s.chainFailures -gt 0) { $notes += "$($s.chainFailures) cliff/shore chains failed (raw edges there)" }
if ($s.sealed -gt 15) { $notes += "$($s.sealed) cells walkable in SC are cut off here" }
if ($s.leaks -gt 150) { $notes += "$($s.leaks) cells reachable here but not in SC (missing cliff?)" }
if ($s.gemsTotal -gt 0 -and $s.gemsReachable -lt $s.gemsTotal) { $notes += "$($s.gemsTotal - $s.gemsReachable) gem cells not reachable by ground (islands?)" }
$verdict = if ($problems.Count) { 'FAIL' } elseif ($notes.Count) { 'WARN' } else { 'PASS' }

# --- review sheet: original | DTA preview | reachability compared with SC
$panel = 560
$imgs = @("$dir\sc.png", "$dir\sc_$slug.png", "$dir\compare_sc.png") | ForEach-Object { [Drawing.Image]::FromFile($_) }
$sheet = New-Object Drawing.Bitmap ($panel * 3 + 40), ($panel + 150)
$g = [Drawing.Graphics]::FromImage($sheet)
$g.Clear([Drawing.Color]::FromArgb(24, 24, 24)); $g.InterpolationMode = 'HighQualityBicubic'
$font = New-Object Drawing.Font 'Segoe UI', 11; $big = New-Object Drawing.Font 'Segoe UI', 14, ([Drawing.FontStyle]::Bold)
$titles = 'StarCraft original', 'DTA (client preview)', 'ground reach vs SC: red = extra, orange = cut off'
for ($i = 0; $i -lt 3; $i++) {
    $im = $imgs[$i]; $h = [int]($im.Height * $panel / $im.Width)
    $g.DrawImage($im, 10 + $i * ($panel + 10), 110, $panel, $h)
    $g.DrawString($titles[$i], $font, [Drawing.Brushes]::Gainsboro, 10 + $i * ($panel + 10), 86)
}
$color = @{ PASS = [Drawing.Brushes]::LimeGreen; WARN = [Drawing.Brushes]::Orange; FAIL = [Drawing.Brushes]::Red }[$verdict]
$g.DrawString("$verdict  $($s.name)   [$($s.size) $($s.tileset) -> DTA $($s.dtaSize)]", $big, $color, 10, 8)
$line = "starts $($s.starts) connected=$($s.startsConnected)   gems reachable $($s.gemsReachable)/$($s.gemsTotal)   leaks $($s.leaks)   sealed $($s.sealed)   failed chains $($s.chainFailures)"
$g.DrawString($line, $font, [Drawing.Brushes]::Gainsboro, 10, 38)
$g.DrawString((($problems + $notes) -join ' | '), $font, [Drawing.Brushes]::Khaki, 10, 60)
$g.Dispose(); $imgs | ForEach-Object { $_.Dispose() }
$sheet.Save("$dir\review.png"); $sheet.Dispose()

"$verdict  $line"
($problems + $notes) | ForEach-Object { "  - $_" }
"review sheet: $dir\review.png"

# --- install
$installed = $false
if (-not $NoInstall -and ($verdict -ne 'FAIL' -or $Force)) {
    $dest = Join-Path $game "Maps\Custom\sc_$slug.map"
    if ((Test-Path $dest) -and -not $Force -and -not (Select-String -Path $dest -Pattern '^Author=.*port: Claude' -Quiet)) {
        "NOT installed: $dest exists and was not made by this tool (use -Force)."
    } else {
        Copy-Item $built, ([IO.Path]::ChangeExtension($built, '.png')) (Join-Path $game 'Maps\Custom') -Force
        $installed = $true
        "installed: Maps\Custom\sc_$slug.map (+ .png) -> client: Skirmish, game mode 'Custom Map'"
        $log = Join-Path $game 'Modding\log.md'
        $entry = "$(Get-Date -Format yyyy-MM-dd) | mod | port-scmap: $($s.name) -> Maps/Custom/sc_$slug.map ($verdict; sealed $($s.sealed), leaks $($s.leaks), gems $($s.gemsReachable)/$($s.gemsTotal))"
        [IO.File]::AppendAllText($log, $entry + "`r`n", (New-Object Text.UTF8Encoding $false))
    }
}

# --- archive
if ($Archive -and $installed) {
    $date = Get-Date -Format yyyy-MM-dd
    $a = Join-Path $game "Modding\archive\sc-$($slug -replace '_', '-')_$date"
    New-Item -ItemType Directory -Force "$a\modified\Maps\Custom" | Out-Null
    Copy-Item (Join-Path $game "Maps\Custom\sc_$slug.map"), (Join-Path $game "Maps\Custom\sc_$slug.png") "$a\modified\Maps\Custom\" -Force
    Copy-Item "$dir\review.png", "$dir\summary.json" $a -Force
    @"
# $($s.name) for DTA — archive ($date)

Generated by ``Modding/tools/port-scmap.ps1`` from ``$($s.source)``. Checks: $verdict ($line).

## Install
Copy ``modified/`` over the game root. Client: Skirmish -> game mode **Custom Map** -> "$($s.name)".

## Uninstall
Delete ``Maps/Custom/sc_$slug.map`` and ``Maps/Custom/sc_$slug.png``. Nothing else in the game is changed.
"@ | Set-Content "$a\README.md" -Encoding UTF8
    Compress-Archive -Path "$a\*" -DestinationPath "$a.zip" -Force
    "archived: $a (+ .zip)"
}
