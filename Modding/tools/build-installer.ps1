# Builds the installer of our mods: Modding\dist\DTA-SCMod-Setup.exe (one file; it leaves an uninstaller in <game>\SCMod\).
# Wiki: workflow/installer.
#   1. assets (Modding\installer\assets, only when missing or -Assets): DTA client graphics (main menu background, Classic
#      buttons, race icons, icon) + StarCraft portraits (HD2 webm -> JPEG strips, ffmpeg via pixi) and UI sounds from CASC
#   2. the program: tools\ScModSetup.cs compiled with the csc of .NET Framework 4, assets as resources
#   3. the payload: every file of Modding\dta\state.json as it is on disk (files/<path>) + the pristine DTA copy of each
#      modified/patched file (base/<path>, for a clean uninstall even where our file was already in place) + manifest.json
#   4. exe = program + zip + int64 zip length + "SCMODPK1"
# Usage: build-installer.ps1 [-Assets] [-NoPayload] [-Version 2026.10.28] [-Out <exe>]
#   -NoPayload: only the program (= the uninstaller), for trying the window: <exe> /shot <png> [idle|busy|ask|done|hover]
param([switch]$Assets, [switch]$NoPayload, [string]$Version = (Get-Date -Format 'yyyy.MM.dd'), [string]$Out = '')
. "$PSScriptRoot\dta-common.ps1"

$assetDir = Join-Path $DtaRoot 'Modding\installer\assets'
$work = Join-Path $DtaCache 'installer'
if (-not $Out) { $Out = Join-Path $DtaRoot 'Modding\dist\DTA-SCMod-Setup.exe' }
New-Item -ItemType Directory -Force $assetDir, $work, (Split-Path $Out) | Out-Null
$scDir = 'C:\Program Files (x86)\StarCraft'

# ---- 1. assets ----
$dtaAssets = [ordered]@{
    'bg.png'      = 'Resources\DTA Theme\MainMenu\mainmenubg.png'
    'lineh.png'   = 'Resources\DTA Theme\MainMenu\lineh.png'
    'btn.png'     = 'Resources\Classic Theme\MainMenu\button1.png'
    'btn_c.png'   = 'Resources\Classic Theme\MainMenu\button1_c.png'
    'terran.png'  = 'Resources\terranicon.png'
    'zerg.png'    = 'Resources\zergicon.png'
    'protoss.png' = 'Resources\protossicon.png'
    'app.ico'     = 'Resources\mainclienticon.ico'
}
$scSounds = [ordered]@{
    'click.wav' = 'SD/sound/misc/button.wav'; 'hover.wav' = 'SD/sound/glue/mouseover.wav'
    'transmission.wav' = 'SD/sound/misc/transmission.wav'; 'done.wav' = 'SD/sound/glue/scorefillend.wav'
    'error.wav' = 'SD/sound/misc/buzz.wav'; 'open.wav' = 'SD/sound/glue/swishin.wav'
}
# portrait key -> CASC folder/prefix; clips fid00-02 (idle, fidgets) and tlk00 (talking)
$heroes = [ordered]@{ raynor = 'HD2/portrait/ujim/ura'; kerrigan = 'HD2/portrait/uikerr/uik'; zeratul = 'HD2/portrait/uzeratul/uze' }
$clips = 'fid00', 'fid01', 'fid02', 'tlk00'

foreach ($k in $dtaAssets.Keys) {
    $d = Join-Path $assetDir $k
    if ($Assets -or -not (Test-Path $d)) { Copy-Item (Join-Path $DtaRoot $dtaAssets[$k]) $d -Force }
}
$needSc = $Assets -or @($scSounds.Keys | Where-Object { -not (Test-Path (Join-Path $assetDir $_)) }).Count -gt 0 -or
          @(foreach ($h in $heroes.Keys) { foreach ($c in $clips) { if (-not (Test-Path (Join-Path $assetDir "${h}_$c.jpg"))) { 1 } } }).Count -gt 0
if ($needSc) {
    "assets: StarCraft portraits and sounds from CASC"
    Add-Type -Path "$PSScriptRoot\Casc.cs" -ReferencedAssemblies System.IO.Compression
    Add-Type -AssemblyName System.Drawing
    $casc = New-Object Casc $scDir
    foreach ($k in $scSounds.Keys) { [IO.File]::WriteAllBytes((Join-Path $assetDir $k), $casc.ReadFile($scSounds[$k])) }
    $jpg = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), 90L
    foreach ($h in $heroes.Keys) {
        foreach ($c in $clips) {
            $tmp = Join-Path $work "portrait\$h-$c"
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $tmp | Out-Null
            $path = $heroes[$h] + $c + '.webm'
            $key = @($casc.Root.Keys | Where-Object { $_ -ieq $path })[0]   # CASC paths keep their odd casing
            if (-not $key) { Write-Warning "no $path in CASC"; continue }
            [IO.File]::WriteAllBytes("$tmp\clip.webm", $casc.ReadFile($key))
            $ErrorActionPreference = 'Continue'
            & pixi exec --spec ffmpeg ffmpeg -hide_banner -loglevel error -y -i "$tmp\clip.webm" "$tmp\f%03d.png" 2>&1 | Out-Null
            $ErrorActionPreference = 'Stop'
            $frames = @(Get-ChildItem "$tmp\f*.png" | Sort-Object Name)
            if (-not $frames) { throw "ffmpeg gave no frames for $path" }
            $strip = New-Object Drawing.Bitmap (224 * $frames.Count), 240
            $g = [Drawing.Graphics]::FromImage($strip)
            for ($i = 0; $i -lt $frames.Count; $i++) { $im = [Drawing.Image]::FromFile($frames[$i].FullName); $g.DrawImage($im, $i * 224, 0, 224, 240); $im.Dispose() }
            $g.Dispose(); $strip.Save((Join-Path $assetDir "${h}_$c.jpg"), $jpg, $ep); $strip.Dispose()
            "  $h $c : $($frames.Count) frames"
        }
    }
}

# ---- 2. program ----
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$manifestXml = Join-Path $work 'app.manifest'
[IO.File]::WriteAllText($manifestXml, @'
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity version="1.0.0.0" name="DTA.SCMod.Setup"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2"><security><requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
    <requestedExecutionLevel level="asInvoker" uiAccess="false"/>
  </requestedPrivileges></security></trustInfo>
  <application xmlns="urn:schemas-microsoft-com:asm.v3"><windowsSettings>
    <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true</dpiAware>
  </windowsSettings></application>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1"><application>
    <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/><supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
  </application></compatibility>
</assembly>
'@)
$stub = Join-Path $work 'stub.exe'
$resArgs = Get-ChildItem $assetDir -File | ForEach-Object { "/resource:$($_.FullName),$($_.Name)" }
$cscArgs = @('/nologo', '/target:winexe', '/optimize+', '/codepage:65001', "/win32icon:$assetDir\app.ico", "/win32manifest:$manifestXml",
    '/r:System.dll', '/r:System.Core.dll', '/r:System.Drawing.dll', '/r:System.Windows.Forms.dll', '/r:System.IO.Compression.dll',
    '/r:System.Web.Extensions.dll', "/out:$stub") + $resArgs + @("$PSScriptRoot\ScModSetup.cs")
$o = & $csc @cscArgs 2>&1
if ($LASTEXITCODE) { $o; throw "csc failed ($LASTEXITCODE)" }
"program: $([math]::Round((Get-Item $stub).Length / 1MB, 1)) MB"
if ($NoPayload) { Copy-Item $stub $Out -Force; "-> $Out (no payload: uninstaller mode)"; return }

# ---- 3. payload ----
$cfg = Read-DtaSyncConfig
$state = Read-DtaState
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zipPath = Join-Path $work 'payload.zip'
Remove-Item $zipPath -ErrorAction SilentlyContinue
$files = New-Object System.Collections.Generic.List[object]
$stored = '\.(mp4|wmv|avi|png|jpg|webm|ogg|wma|zip)$'
$zs = [IO.File]::Open($zipPath, 'Create')
$za = New-Object IO.Compression.ZipArchive($zs, [IO.Compression.ZipArchiveMode]::Create)
function Add-ZipFile([string]$Name, [string]$Src) {
    $lvl = if ($Name -match $stored) { [IO.Compression.CompressionLevel]::NoCompression } else { [IO.Compression.CompressionLevel]::Optimal }
    $en = $za.CreateEntry($Name, $lvl); $os = $en.Open(); $is = [IO.File]::OpenRead($Src)
    try { $is.CopyTo($os) } finally { $is.Close(); $os.Close() }
}
try {
    foreach ($e in $state.files) {
        $full = Get-DtaFull $e.path
        if (-not (Test-Path -LiteralPath $full)) { throw "$($e.path) is in the state but missing on disk" }
        $h = Get-DtaHash $full
        if ($h -ne $e.ours) { Write-Warning "$($e.path): differs from the last capture (packed as it is on disk; run dta-capture.ps1)" }
        $base = $null
        if ($e.kind -ne 'new') {
            $base = $e.base
            $p = Find-DtaPristine $e.path $e.base $cfg -NoDownload
            if (-not $p) { throw "$($e.path): no pristine DTA copy (Modding\dta\base, .bak, .dta-cache)" }
            Add-ZipFile "base/$($e.path)" $p
        }
        Add-ZipFile "files/$($e.path)" $full
        $files.Add([ordered]@{ path = $e.path; kind = $e.kind; ours = $h; base = $base; size = (Get-Item -LiteralPath $full).Length })
    }
    $man = [ordered]@{ name = 'dta-scmod'; title = 'StarCraft mod'; version = $Version; dtaVersion = $state.dtaVersion
                       built = (Get-Date -Format 'yyyy-MM-dd HH:mm'); files = $files }
    $en = $za.CreateEntry('manifest.json'); $w = New-Object IO.StreamWriter($en.Open(), (New-Object Text.UTF8Encoding $false))
    $w.Write(($man | ConvertTo-Json -Depth 4 -Compress)); $w.Close()
} finally { $za.Dispose(); $zs.Close() }
$zipLen = (Get-Item $zipPath).Length
$total = 0L; foreach ($f in $files) { $total += $f.size }
"payload: $($files.Count) files, $([math]::Round($total / 1MB)) MB -> zip $([math]::Round($zipLen / 1MB)) MB"

# ---- 4. exe = program + zip + trailer ----
$fo = [IO.File]::Open($Out, 'Create')
try {
    foreach ($src in $stub, $zipPath) { $fi = [IO.File]::OpenRead($src); $fi.CopyTo($fo); $fi.Close() }
    $t = [BitConverter]::GetBytes([long]$zipLen) + [Text.Encoding]::ASCII.GetBytes('SCMODPK1')
    $fo.Write($t, 0, $t.Length)
} finally { $fo.Close() }
"-> $Out ($([math]::Round((Get-Item $Out).Length / 1MB)) MB), version $Version for DTA $($state.dtaVersion)"
