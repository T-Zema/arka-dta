# Records OUR changes to the DTA install, so git tracks them in place and tools/dta-restore.ps1 can re-apply them after a DTA
# update. Run it after every mod change, then commit. Wiki: workflow/repo-and-updates.
# It compares every file of the game folder with the client's manifest "version" (MD5 of every DTA file):
#   new       not a DTA file (our MIX, maps, INI of the mods...)                      git tracks the file
#   modified  a DTA file we changed (Rules.ini, Art.ini...)                           git tracks the file; the pristine DTA copy
#                                                                                     goes to Modding\dta\base\ (3-way merge base)
#   patched   a binary rebuilt by patch scripts (sync.json "patched": game.exe...)    NOT in git: rebuilt from the pristine .bak;
#                                                                                     checked to be bit-identical (unless -SkipVerify)
# Runtime files (saves, logs, client settings, .bak) are skipped by the regexes in Modding\dta\sync.json.
# Writes Modding\dta\state.json, Modding\dta\dta-version.ini (the manifest the bases belong to), the generated block of .gitignore,
# and copies of the pristine and patched binaries to Modding\.dta-cache\ (local only: the fallback of dta-restore.ps1 -OnPatchFail).
# Usage: dta-capture.ps1 [-SkipVerify] [-Force]. -Force: capture although the installed DTA version differs from the state
# (normally dta-restore.ps1 does that itself after re-applying our changes).
param([switch]$SkipVerify, [switch]$Force)
. "$PSScriptRoot\dta-common.ps1"

$cfg = Read-DtaSyncConfig
$man = Read-DtaManifest (Join-Path $DtaRoot 'version')
$old = Read-DtaState
if ($old -and $old.dtaVersion -ne $man.Version -and -not $Force) {
    throw "installed DTA is $($man.Version) but the state is from $($old.dtaVersion): run dta-restore.ps1 first (it re-applies our changes, then captures)"
}
$oldByPath = @{}; if ($old) { foreach ($e in $old.files) { $oldByPath[$e.path] = $e } }
$patchedNames = @($cfg.patched.PSObject.Properties.Name)
$warn = New-Object System.Collections.Generic.List[string]

# ---- 1. scan the game folder (ignored directories are not entered)
function Get-GameFiles([string]$Dir) {
    foreach ($i in Get-ChildItem -LiteralPath $Dir -Force) {
        $rel = ConvertTo-DtaRel $i.FullName.Substring($DtaRoot.Length + 1)
        if ($i.PSIsContainer) { if (-not (Test-DtaIgnored "$rel/" $cfg)) { Get-GameFiles $i.FullName } }
        elseif (-not (Test-DtaIgnored $rel $cfg)) { [pscustomobject]@{ Rel = $rel; File = $i } }
    }
}
$entries = New-Object System.Collections.Generic.List[object]
foreach ($g in Get-GameFiles $DtaRoot) {
    $rel = $g.Rel; $key = ConvertTo-DtaKey $rel
    $h = Get-DtaHash $g.File.FullName
    $m = $man.Files[$key]
    if ($m -and $m.Hash -eq $h) { continue }                     # pristine DTA file
    if ($g.File.Length -gt $cfg.maxFileMB * 1MB) { $warn.Add("$rel : $([int]($g.File.Length / 1MB)) MB > maxFileMB, NOT captured (GitHub limit 100 MB)"); continue }
    if (-not $m) { $entries.Add([ordered]@{ path = $rel; kind = 'new'; ours = $h }); continue }
    if ($patchedNames -contains $rel) { $entries.Add([ordered]@{ path = $rel; kind = 'patched'; base = ''; ours = $h; pinned = $false; reproducible = $null }); continue }
    $entries.Add([ordered]@{ path = $rel; kind = 'modified'; base = $m.Hash; ours = $h; binary = (Test-BinaryFile $g.File.FullName) })
}

# ---- 2. bases: pristine copies of modified text files (tracked), pristine + patched binaries (local cache)
$baseDir = Join-Path $DtaDir 'base'
$keepBase = @{}
foreach ($e in $entries) {
    $full = Get-DtaFull $e.path
    if ($e.kind -eq 'modified') {
        $src = Find-DtaPristine $e.path $e.base $cfg
        if (-not $src) { $warn.Add("$($e.path) : no pristine DTA copy (.bak, base, cache, mirror): dta-restore.ps1 cannot merge it after an update"); continue }
        if ($e.binary) { Save-DtaPristine $src $e.path | Out-Null; continue }   # DTA binaries stay out of git
        $dest = Join-Path $baseDir ($e.path -replace '/', '\'); $keepBase[$dest.ToLowerInvariant()] = $true
        if (-not ((Test-Path $dest) -and (Get-DtaHash $dest) -eq $e.base)) { New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null; Copy-Item $src $dest -Force }
    }
    elseif ($e.kind -eq 'patched') {
        # the base is the pristine file the patches were applied to: the .bak (made by the first patch), else the manifest's
        $mh = $man.Files[(ConvertTo-DtaKey $e.path)].Hash
        $bak = "$full.bak"
        $e.base = if (Test-Path $bak) { Get-DtaHash $bak } else { $mh }
        $e.pinned = ($e.base -ne $mh)
        $prev = $oldByPath[$e.path]
        if ($e.pinned -and -not ($prev -and $prev.base -eq $e.base)) { $warn.Add("$($e.path).bak is not the pristine file of DTA $($man.Version) and not the base of the last state: check it") }
        if ($e.pinned) { $warn.Add("$($e.path) is PINNED: built from an older DTA file ($($e.base)); the patches still need porting to DTA $($man.Version)") }
        $src = Find-DtaPristine $e.path $e.base $cfg -NoDownload:$e.pinned
        if (-not $src) { $warn.Add("$($e.path) : pristine base not found, cannot verify or rebuild it"); continue }
        Save-DtaPristine $src $e.path | Out-Null
        Save-DtaPatched $full $e.path | Out-Null
        if (-not $SkipVerify) {
            $tmp = Join-Path $DtaCache ('verify\' + (Split-Path $e.path -Leaf))
            New-Item -ItemType Directory -Force (Split-Path $tmp) | Out-Null; Copy-Item $src $tmp -Force
            $r = Invoke-DtaPatchChain $cfg.patched.($e.path) $tmp
            $e.reproducible = $r.Ok -and ((Get-DtaHash $tmp) -eq $e.ours)
            Remove-Item $tmp
            if (-not $e.reproducible) { $warn.Add("$($e.path) is NOT reproducible from its base with $($cfg.patched.($e.path).script) $($cfg.patched.($e.path).args): fix the scripts or sync.json args`n      " + ($r.Lines -join "`n      ")) }
        } elseif ($prev -and $prev.ours -eq $e.ours) { $e.reproducible = $prev.reproducible }
    }
}
if (Test-Path $baseDir) {
    foreach ($f in Get-ChildItem $baseDir -Recurse -File) { if (-not $keepBase[$f.FullName.ToLowerInvariant()]) { Remove-Item $f.FullName } }
    Get-ChildItem $baseDir -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending | Where-Object { -not (Get-ChildItem $_.FullName -Force) } | Remove-Item
}

# ---- 3. state.json + manifest copy
$sorted = @($entries | Sort-Object { $_.path })
$state = [ordered]@{ dtaVersion = $man.Version; captured = (Get-Date -Format 'yyyy-MM-dd HH:mm'); files = $sorted }
[IO.File]::WriteAllText((Join-Path $DtaDir 'state.json'), ($state | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
Copy-Item (Join-Path $DtaRoot 'version') (Join-Path $DtaDir 'dta-version.ini') -Force

# ---- 4. generated block of .gitignore: un-ignore exactly the new and modified files (and their directories)
function Get-GitPattern([string]$s) { return ($s -replace '([\[\]\*\?\\])', '\$1') }
$lines = New-Object System.Collections.Generic.List[string]; $dirs = @{}
foreach ($e in $sorted | Where-Object { $_.kind -ne 'patched' }) {
    $parts = $e.path -split '/'
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $d = ($parts[0..($i - 1)] -join '/')
        if (-not $dirs[$d]) { $dirs[$d] = $true; $lines.Add("!/$(Get-GitPattern $d)/"); $lines.Add("/$(Get-GitPattern $d)/*") }
    }
    $lines.Add("!/$(Get-GitPattern $e.path)")
}
$gi = Join-Path $DtaRoot '.gitignore'
$begin = '# >>> dta-capture: generated by Modding/tools/dta-capture.ps1 (do not edit; change Modding/dta/sync.json instead)'
$end = '# <<< dta-capture'
$text = [IO.File]::ReadAllText($gi)
$i0 = $text.IndexOf($begin); $i1 = $text.IndexOf($end)
if ($i0 -lt 0 -or $i1 -lt $i0) { throw ".gitignore has no '$begin' ... '$end' block" }
$text = $text.Substring(0, $i0) + $begin + "`n" + ($lines -join "`n") + "`n" + $text.Substring($i1)
[IO.File]::WriteAllText($gi, $text, (New-Object Text.UTF8Encoding $false))

# ---- 5. report
$count = $sorted | Group-Object { $_['kind'] } | ForEach-Object { "$($_.Name) $($_.Count)" }
"DTA $($man.Version): " + ($count -join ', ')
if ($old) {
    $now = @{}; foreach ($e in $sorted) { $now[$e.path] = $e }
    foreach ($e in $sorted) { $p = $oldByPath[$e.path]; if (-not $p) { "  + $($e.kind) $($e.path)" } elseif ($p.ours -ne $e.ours) { "  ~ $($e.kind) $($e.path)" } }
    foreach ($p in $old.files) { if (-not $now[$p.path]) { "  - $($p.kind) $($p.path)" } }
}
foreach ($e in $sorted | Where-Object { $_['kind'] -eq 'patched' }) { "  patched {0}: reproducible={1} pinned={2}" -f $e.path, $e.reproducible, $e.pinned }
if (Test-Path (Join-Path $DtaRoot '.git')) {
    # what git would track outside Modding must be exactly the captured files
    $tracked = @{}; foreach ($e in $sorted | Where-Object { $_['kind'] -ne 'patched' }) { $tracked[$e.path] = $true }
    $git = & git -C $DtaRoot -c core.quotepath=off ls-files --cached --others --exclude-standard
    foreach ($p in $git) { if ($p -notmatch '^(Modding/|\.gitignore$|\.gitattributes$|README\.md$|CLAUDE\.md$)' -and -not $tracked[$p]) { $warn.Add("git tracks $p but it is not in the state (git rm --cached it?)") } }
    foreach ($p in $tracked.Keys) { if ($git -notcontains $p) { $warn.Add("$p is in the state but git ignores it: .gitignore pattern problem") } }
}
foreach ($w in $warn) { "WARN $w" }
"next: git add -A; git commit"
