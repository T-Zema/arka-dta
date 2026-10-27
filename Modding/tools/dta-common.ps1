# Shared helpers for dta-capture.ps1, dta-restore.ps1 and dta-precheck.ps1 (dot-source it). Wiki: workflow/repo-and-updates.
# Paths: "rel" = relative to the game folder with forward slashes (git style); "key" = lower-case with backslashes (the key
# of the DTA manifest file "version"). Hashes use the DTA manifest format: the 16 MD5 bytes as decimal numbers, concatenated.
$ErrorActionPreference = 'Stop'
$DtaRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$DtaDir = Join-Path $DtaRoot 'Modding\dta'            # tracked: state.json, sync.json, dta-version.ini, base\
$DtaCache = Join-Path $DtaRoot 'Modding\.dta-cache'   # local only (git-ignored): pristine and patched binaries, downloads

function Get-DtaHash([string]$Path) {
    $md5 = [Security.Cryptography.MD5]::Create(); $s = [IO.File]::OpenRead($Path)
    try { return (($md5.ComputeHash($s) | ForEach-Object { $_.ToString() }) -join '') } finally { $s.Close(); $md5.Dispose() }
}
function ConvertTo-DtaKey([string]$Rel) { return ($Rel -replace '/', '\').ToLowerInvariant() }
function ConvertTo-DtaRel([string]$Path) { return ($Path -replace '\\', '/') }
function Get-DtaFull([string]$Rel) { return Join-Path $DtaRoot ($Rel -replace '/', '\') }

# Manifest ("version" file of the client updater): [DTA] Version=, [FileVersions] path=hash,sizeKB
function Read-DtaManifest([string]$Path) {
    $m = @{ Version = ''; Files = @{} }
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^Version=(.+)$' -and -not $m.Version) { $m.Version = $matches[1].Trim() }
        elseif ($line -match '^(.+?)=(\d+),(\d+)') { $m.Files[$matches[1].ToLowerInvariant()] = @{ Rel = (ConvertTo-DtaRel $matches[1]); Hash = $matches[2] } }
    }
    return $m
}

function Read-DtaSyncConfig { return Get-Content (Join-Path $DtaDir 'sync.json') -Raw | ConvertFrom-Json }
function Read-DtaState {
    $p = Join-Path $DtaDir 'state.json'
    if (-not (Test-Path $p)) { return $null }
    return Get-Content $p -Raw | ConvertFrom-Json
}
function Test-DtaIgnored([string]$Rel, $Cfg) {
    foreach ($re in $Cfg.ignore) { if ($Rel -match $re) { return $true } }
    return $false
}
function Test-BinaryFile([string]$Path) {
    $fs = [IO.File]::OpenRead($Path)
    try { $buf = New-Object byte[] 8192; $n = $fs.Read($buf, 0, $buf.Length); for ($i = 0; $i -lt $n; $i++) { if ($buf[$i] -eq 0) { return $true } }; return $false }
    finally { $fs.Close() }
}
# The game or the client started from THIS folder (another DTA copy, e.g. a test sandbox, does not count).
function Test-GameRunning {
    $p = Get-Process -Name game, DTA, clientdx, clientogl, clientxna -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($DtaRoot + '\', [StringComparison]::OrdinalIgnoreCase) }
    return [bool]$p
}

# git writes progress ("Updated 1 path") to stderr; under ErrorActionPreference=Stop PowerShell 5.1 would turn that into an
# exception, so only the exit code decides.
function Invoke-Git {
    $ErrorActionPreference = 'Continue'
    $out = & git -C $DtaRoot @args 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed ($LASTEXITCODE): $out" }
    return $out
}

# git merge-file <current> <base> <other>: writes the merge into $Current, returns the number of conflicts (<0 or >127 = error).
function Invoke-MergeFile([string[]]$Options, [string]$Current, [string]$Base, [string]$Other) {
    $ErrorActionPreference = 'Continue'
    & git merge-file @Options $Current $Base $Other 2>&1 | Out-Null
    return $LASTEXITCODE
}

# The bytes of $Rel at git HEAD into $Dest (PowerShell 5.1 would re-encode redirected stdout, so read the stream directly).
function Export-GitBlob([string]$Rel, [string]$Dest) {
    $psi = New-Object Diagnostics.ProcessStartInfo 'git', "-C `"$DtaRoot`" cat-file blob `"HEAD:$Rel`""
    $psi.RedirectStandardOutput = $true; $psi.UseShellExecute = $false
    $p = [Diagnostics.Process]::Start($psi)
    $fs = [IO.File]::Create($Dest)
    try { $p.StandardOutput.BaseStream.CopyTo($fs) } finally { $fs.Close() }
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { throw "git cat-file HEAD:$Rel failed ($($p.ExitCode))" }
}

# Download one file of a DTA version from the update mirror and check it against the manifest hash.
function Get-DtaMirrorFile([string]$Rel, [string]$Hash, [string]$Dest, $Cfg) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    New-Item -ItemType Directory -Force (Split-Path $Dest) | Out-Null
    $url = $Cfg.mirror.TrimEnd('/') + '/' + (($Rel -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
    Invoke-WebRequest -Uri $url -OutFile $Dest -UseBasicParsing -TimeoutSec 300
    if ((Get-DtaHash $Dest) -ne $Hash) { Remove-Item $Dest; throw "$url does not match the manifest hash (mirror has another DTA version?)" }
}

# A pristine copy of $Rel with $Hash: Modding\dta\base, the .bak next to the file, the local cache, or the mirror (if the
# hash is the one of the manifest the mirror serves). Returns the path or $null.
function Find-DtaPristine([string]$Rel, [string]$Hash, $Cfg, [switch]$NoDownload) {
    $cands = @((Join-Path $DtaDir ('base\' + ($Rel -replace '/', '\'))), ((Get-DtaFull $Rel) + '.bak'), (Join-Path $DtaCache ('pristine\' + $Hash + '\' + ($Rel -replace '/', '\'))))
    foreach ($c in $cands) { if ((Test-Path $c) -and (Get-DtaHash $c) -eq $Hash) { return $c } }
    if ($NoDownload) { return $null }
    $dest = $cands[2]
    try { Get-DtaMirrorFile $Rel $Hash $dest $Cfg; return $dest } catch { Write-Warning "mirror: $($_.Exception.Message)"; return $null }
}
function Save-DtaPristine([string]$Path, [string]$Rel) {
    $h = Get-DtaHash $Path
    $dest = Join-Path $DtaCache ('pristine\' + $h + '\' + ($Rel -replace '/', '\'))
    if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null; Copy-Item $Path $dest }
    return $dest
}
function Save-DtaPatched([string]$Path, [string]$Rel) {
    $h = Get-DtaHash $Path
    $dest = Join-Path $DtaCache ('patched\' + $h + '\' + ($Rel -replace '/', '\'))
    if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null; Copy-Item $Path $dest }
    return $dest
}

# Run the patch chain of a binary (sync.json "patched") on a COPY in its own powershell process (several patch scripts use
# Add-Type). Returns @{ Ok; Lines }: Ok = no script reported FAILED.
function Invoke-DtaPatchChain($Spec, [string]$CopyPath) {
    $ErrorActionPreference = 'Continue'   # an error of the child arrives as stderr: report it, do not throw
    $script = Join-Path $PSScriptRoot $Spec.script
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script) + @($Spec.args) + @("-$($Spec.copyParam)", $CopyPath)
    $lines = & powershell.exe @argList 2>&1 | ForEach-Object { "$_" }
    $ok = ($LASTEXITCODE -eq 0) -and -not ($lines | Where-Object { $_ -match 'FAILED' })
    return @{ Ok = $ok; Lines = $lines }
}

function Write-DtaLog([string]$Kind, [string]$Text) {
    $line = '{0} | {1} | {2}' -f (Get-Date -Format 'yyyy-MM-dd'), $Kind, $Text
    [IO.File]::AppendAllText((Join-Path $DtaRoot 'Modding\log.md'), "$line`n", (New-Object Text.UTF8Encoding $false))   # log.md: UTF-8 without BOM, LF
}
