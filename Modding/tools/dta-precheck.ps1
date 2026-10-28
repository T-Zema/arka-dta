# BEFORE a DTA client update: what will the update do to our changes? Reads the new manifest (version_u, which the client
# downloads when it finds an update, or the mirror's "version"), downloads only the new DTA files that we change, and tries
# on copies what dta-restore.ps1 would do: 3-way merges of our modified files and the patch scripts on the new binaries.
# Nothing in the game folder is written; downloads go to Modding\.dta-cache\pristine\ (dta-restore.ps1 reuses them).
# Wiki: workflow/repo-and-updates.
# Note: the client's update CHECK lists only the files that changed between the manifests (client.log "Local file X is
# different"), but the update itself (16.2.2 -> 16.2.3, 2026-10-27) put back EVERY DTA file that differed from the manifest
# (all our modified files and game.exe) and ran the [Delete] lists of preupdateexec/updateexec. So after every update: restore.
# Usage: dta-precheck.ps1 [-Manifest <path to a version file>]
param([string]$Manifest = "")
. "$PSScriptRoot\dta-common.ps1"

$cfg = Read-DtaSyncConfig
$cur = Read-DtaManifest (Join-Path $DtaRoot 'version')
$state = Read-DtaState
if (-not $state) { throw "no Modding\dta\state.json: run dta-capture.ps1 first" }
if (-not $Manifest) {
    $u = Join-Path $DtaRoot 'version_u'
    if ((Test-Path $u) -and (Read-DtaManifest $u).Version -ne $cur.Version) { $Manifest = $u }
    else {
        $Manifest = Join-Path $DtaCache 'mirror-version'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        New-Item -ItemType Directory -Force $DtaCache | Out-Null
        Invoke-WebRequest -Uri ($cfg.mirror.TrimEnd('/') + '/version') -OutFile $Manifest -UseBasicParsing -TimeoutSec 120
    }
}
$new = Read-DtaManifest $Manifest
"installed DTA $($cur.Version), update $($new.Version) ($Manifest)"
if ($new.Version -eq $cur.Version) { "no update"; return }

$changed = @{}
foreach ($k in $new.Files.Keys) { if (-not $cur.Files.ContainsKey($k) -or $cur.Files[$k].Hash -ne $new.Files[$k].Hash) { $changed[$k] = $true } }
foreach ($k in $cur.Files.Keys) { if (-not $new.Files.ContainsKey($k)) { $changed[$k] = $true } }
"files the update changes: $($changed.Count)"

# the updater's own scripts run at EVERY update: [Delete]/[Rename] of preupdateexec/updateexec (DTA 16.2.3 deletes
# MIX/ECache99.mix, our Marine MIX until it moved to 77, and INI/BattleE.ini, names old DTA versions used)
$execHit = @{}
foreach ($x in 'preupdateexec', 'updateexec') {
    try {
        $t = (Invoke-WebRequest -Uri ($cfg.mirror.TrimEnd('/') + '/' + $x) -UseBasicParsing -TimeoutSec 60).Content
        if ($t -is [byte[]]) { $t = [Text.Encoding]::UTF8.GetString($t) }
        $sec = ''
        foreach ($l in $t -split "`r?`n") {
            $l = $l.Trim()
            if ($l -match '^\[(.+)\]$') { $sec = $matches[1] }
            elseif ($l -and -not $l.StartsWith(';') -and $sec -in 'Delete', 'Rename', 'ForceDeleteFolder', 'RenameFolder') { $execHit[(ConvertTo-DtaKey ($l -split '=')[0]).TrimEnd('\')] = "$x [$sec]" }
        }
    } catch { "WARN could not read ${x}: $($_.Exception.Message)" }
}

$problems = 0; $ours = @{}
foreach ($e in $state.files) {
    $rel = $e.path; $k = ConvertTo-DtaKey $rel; $ours[$k] = $true
    $hit = $execHit.Keys | Where-Object { $k -eq $_ -or $k.StartsWith($_ + '\') } | Select-Object -First 1
    if ($hit) { "DELETED    $rel : $($execHit[$hit]) removes it at every update (restore brings it back)" }
    # the update also re-downloads every DTA file that differs from the manifest (seen 2026-10-27), changed or not
    if (-not $changed[$k] -and $e.kind -ne 'new') { "OVERWRITE  $rel : the update puts DTA's file back (restore re-applies ours)" }
    if (-not $changed[$k]) { continue }
    $n = $new.Files[$k]
    if ($e.kind -eq 'new') { "COLLISION  $rel : DTA $($new.Version) adds a file with the name of ours (restore keeps ours, theirs as .dta-new)"; $problems++; continue }
    if (-not $n) { "REMOVED    $rel : DTA $($new.Version) drops this file; ours stays"; continue }
    $theirs = Find-DtaPristine $rel $n.Hash $cfg
    if (-not $theirs) { "UNKNOWN    $rel : could not download DTA $($new.Version)'s file"; $problems++; continue }
    if ($e.kind -eq 'modified' -and $e.binary) { "BINARY     $rel : DTA changes a binary file we replace (restore keeps ours)"; $problems++; continue }
    if ($e.kind -eq 'modified') {
        $base = Join-Path $DtaDir ('base\' + ($rel -replace '/', '\'))
        $tmp = Join-Path $DtaCache ('precheck\' + ($rel -replace '/', '\')); New-Item -ItemType Directory -Force (Split-Path $tmp) | Out-Null
        Copy-Item (Get-DtaFull $rel) $tmp -Force
        $c = Invoke-MergeFile @('--diff3', '-L', 'ours', '-L', "DTA $($cur.Version)", '-L', "DTA $($new.Version)") $tmp $base $theirs
        if ($c -eq 0) { "MERGE OK   $rel : our changes merge cleanly into DTA $($new.Version)"; Remove-Item $tmp }
        else { "CONFLICT   $rel : $c conflicting hunk(s), restore keeps our side; preview with markers: $tmp"; $problems++ }
        continue
    }
    if ($e.kind -eq 'patched') {
        $spec = $cfg.patched.($rel)
        $tmp = Join-Path $DtaCache ('precheck\' + (Split-Path $rel -Leaf)); New-Item -ItemType Directory -Force (Split-Path $tmp) | Out-Null
        Copy-Item $theirs $tmp -Force
        $r = Invoke-DtaPatchChain $spec $tmp
        Remove-Item $tmp
        if ($r.Ok) { "PATCH OK   $rel : every patch of $($spec.script) applies to DTA $($new.Version)" }
        else {
            "PATCH FAIL $rel : these patches refuse DTA $($new.Version) (restore keeps our old binary, see -OnPatchFail):"; $problems++
            $r.Lines | Where-Object { $_ -match 'FAILED' } | ForEach-Object { "             $_" }
        }
    }
}
$other = @($changed.Keys | Where-Object { -not $ours[$_] })
"not ours, simply updated: $($other.Count) file(s)"
if ($problems) { "VERDICT: $problems problem(s) above. Update only if you accept them; afterwards run dta-restore.ps1." }
else { "VERDICT: safe. Commit, update in the client, close it, run dta-restore.ps1." }
