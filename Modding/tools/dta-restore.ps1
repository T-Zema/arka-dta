# Re-applies OUR changes after a DTA client update (or a fresh install / the client's file repair), from git HEAD and
# Modding\dta\state.json (written by dta-capture.ps1). Wiki: workflow/repo-and-updates. Close the client and the game first.
# Per file of the state:
#   new       missing or deleted -> restored from git. If DTA now ships a file with the same name, DTA's copy is kept as
#             <file>.dta-new and ours goes back (WARN: check it).
#   modified  DTA put its pristine file back -> ours from git. DTA UPDATED the file -> 3-way merge (git merge-file): base =
#             Modding\dta\base\<file> (the old pristine), ours = git HEAD, theirs = the new DTA file. Conflicting hunks keep OUR
#             side; the diff3 version with conflict markers goes to Modding\.dta-cache\conflicts\ for review. <file>.bak becomes
#             the new pristine. A binary file DTA changed: ours is kept, DTA's copy goes to the cache (WARN).
#   patched   the pristine DTA binary is rebuilt with its patch scripts (on a copy first). Same DTA file as before: the result
#             must be bit-identical to the captured one. New DTA file and a patch refuses it (bytes differ): -OnPatchFail
#             KeepOld (default) puts back our previous patched binary and its .bak from Modding\.dta-cache (= the mod keeps
#             working on the old Vinifera/game.exe; the patches need porting); UseNew leaves DTA's new binary unpatched.
# A file that matches neither DTA nor our captured version has local edits that were never captured: skipped (WARN), unless -Force.
# When everything went fine it runs dta-capture.ps1 (new bases, new state); then test the game and commit.
# Usage: dta-restore.ps1 [-DryRun] [-OnPatchFail KeepOld|UseNew] [-Force]
param([switch]$DryRun, [ValidateSet('KeepOld', 'UseNew')][string]$OnPatchFail = 'KeepOld', [switch]$Force)
. "$PSScriptRoot\dta-common.ps1"

if (-not $DryRun -and (Test-GameRunning)) { throw "the DTA client or the game is running: close it first" }
$cfg = Read-DtaSyncConfig
$man = Read-DtaManifest (Join-Path $DtaRoot 'version')
$state = Read-DtaState
if (-not $state) { throw "no Modding\dta\state.json: run dta-capture.ps1 on a modded install first" }
& git -C $DtaRoot diff --quiet HEAD -- Modding/dta
if ($LASTEXITCODE -ne 0) { throw "Modding/dta has uncommitted changes: commit the last capture first (git HEAD is the source of our files)" }

$warn = New-Object System.Collections.Generic.List[string]
$errors = 0
function Say([string]$Path, [string]$What) { "{0,-44} {1}" -f $Path, $What }
function Restore-FromGit([string]$Rel, [string]$Ours) {
    if ($DryRun) { return }
    Invoke-Git checkout -q HEAD -- $Rel | Out-Null
    $h = Get-DtaHash (Get-DtaFull $Rel)
    if ($h -ne $Ours) { $script:warn.Add("$Rel : the git HEAD version differs from the state (capture was not committed together with the files?)") }
}
function Set-Pristine([string]$Rel, [string]$PristinePath) {
    # <file>.bak = the pristine file of the installed DTA version; the old .bak stays in the cache
    $bak = (Get-DtaFull $Rel) + '.bak'
    if (Test-Path $bak) { Save-DtaPristine $bak $Rel | Out-Null }
    Copy-Item $PristinePath $bak -Force
}

"DTA installed: $($man.Version), state captured on: $($state.dtaVersion)$(if ($DryRun) { '   (dry run: nothing is written)' })"
foreach ($e in $state.files) {
    $rel = $e.path; $full = Get-DtaFull $rel
    $cur = if (Test-Path -LiteralPath $full) { Get-DtaHash $full } else { $null }
    $m = $man.Files[(ConvertTo-DtaKey $rel)]; $mh = if ($m) { $m.Hash } else { $null }

    if ($e.kind -eq 'new') {
        if ($mh) {
            $warn.Add("$rel : DTA $($man.Version) now ships a file with this name; ours is restored, DTA's copy is $rel.dta-new")
            if ($cur -eq $mh -and -not $DryRun) { Copy-Item $full "$full.dta-new" -Force }
            if ($cur -ne $e.ours) { Say $rel 'restore ours (DTA collision)'; Restore-FromGit $rel $e.ours }
            continue
        }
        if ($cur -eq $e.ours) { continue }
        if (-not $cur -or $Force) { Say $rel 'restore from git'; Restore-FromGit $rel $e.ours }
        else { $warn.Add("$rel : local changes that were never captured: skipped (capture + commit them, or -Force)") }
        continue
    }

    if ($e.kind -eq 'modified') {
        if ($cur -eq $e.ours) {
            if ($mh -and $mh -ne $e.base) { $warn.Add("$rel : the manifest says DTA changed this file, but our version is still in place (DTA's changes are missing)") }
            continue
        }
        if (-not $cur -or $cur -eq $e.base) { Say $rel 'DTA original in place: restore ours'; Restore-FromGit $rel $e.ours; continue }
        if ($cur -ne $mh -and -not $Force) { $warn.Add("$rel : matches neither DTA $($man.Version) nor our version (local changes never captured): skipped"); continue }
        $theirs = Save-DtaPristine $full $rel
        if ($e.binary) {
            Say $rel 'DTA changed this binary file: keep ours'
            $warn.Add("$rel : DTA $($man.Version) changed a binary file we replace; ours is restored, DTA's new copy: $theirs")
            Restore-FromGit $rel $e.ours; if (-not $DryRun) { Set-Pristine $rel $theirs }
            continue
        }
        $base = Join-Path $DtaDir ('base\' + ($rel -replace '/', '\'))
        if (-not ((Test-Path $base) -and (Get-DtaHash $base) -eq $e.base)) { $errors++; $warn.Add("$rel : the merge base Modding\dta\base\$rel is missing or wrong: not merged, DTA's file stays"); continue }
        # conflict count and the diff3 review copy first (on a temporary copy of ours)
        $review = Join-Path $DtaCache ('conflicts\' + ($rel -replace '/', '\'))
        New-Item -ItemType Directory -Force (Split-Path $review) | Out-Null
        Export-GitBlob $rel $review
        $conflicts = Invoke-MergeFile @('--diff3', '-L', 'ours', '-L', "base DTA $($state.dtaVersion)", '-L', "DTA $($man.Version)") $review $base $theirs
        if ($conflicts -lt 0 -or $conflicts -gt 127) { $errors++; $warn.Add("$rel : git merge-file failed ($conflicts)"); continue }
        if ($conflicts -eq 0) { Remove-Item $review }
        Say $rel ("DTA updated it: 3-way merge, {0}" -f $(if ($conflicts) { "$conflicts CONFLICT(S) resolved to ours, review $review" } else { 'clean' }))
        if ($conflicts) { $warn.Add("$rel : $conflicts conflicting hunk(s) kept our side; DTA's side is in $review") }
        if ($DryRun) { continue }
        Restore-FromGit $rel $e.ours
        Invoke-MergeFile @('--ours') $full $base $theirs | Out-Null
        Set-Pristine $rel $theirs
        continue
    }

    if ($e.kind -eq 'patched') {
        if ($cur -eq $e.ours -and -not $e.pinned) { continue }
        $spec = $cfg.patched.($rel)
        if (-not $spec) { $errors++; $warn.Add("$rel : patched in the state but not in sync.json"); continue }
        $stillPinned = ($cur -eq $e.ours)
        if ($stillPinned) {
            # PINNED (our old binary on a newer DTA): try the patches on the installed DTA version's file again (ported meanwhile?)
            $pristine = Find-DtaPristine $rel $mh $cfg
            if (-not $pristine) { $warn.Add("$rel : pinned, and DTA $($man.Version)'s pristine file was not found (cache, mirror)"); continue }
        }
        elseif ($cur -eq $mh -or $cur -eq $e.base) { $pristine = Save-DtaPristine $full $rel }
        else { $warn.Add("$rel : neither DTA's pristine file nor our patched one: skipped (patched by hand?)"); continue }
        $tmp = Join-Path $DtaCache ('verify\' + (Split-Path $rel -Leaf)); New-Item -ItemType Directory -Force (Split-Path $tmp) | Out-Null
        Copy-Item $pristine $tmp -Force
        $r = Invoke-DtaPatchChain $spec $tmp
        $newHash = Get-DtaHash $tmp
        if ($r.Ok) {
            $same = ($newHash -eq $e.ours)
            Say $rel ("patched with {0}: {1}" -f $spec.script, $(if ($same) { 'bit-identical to the captured file' } elseif ($cur -eq $e.base) { 'DIFFERS from the captured file' } else { 'new DTA file, all patches applied' }))
            if (-not $same -and $cur -eq $e.base) { $warn.Add("$rel : rebuilt from the same DTA file but not bit-identical: the patch scripts changed since the capture?") }
            if (-not $DryRun) { Set-Pristine $rel $pristine; Copy-Item $tmp $full -Force }
        } else {
            $failed = ($r.Lines | Where-Object { $_ -match 'FAILED' }) -join '; '
            $oldPatched = Join-Path $DtaCache ('patched\' + $e.ours + '\' + ($rel -replace '/', '\'))
            $oldPristine = Join-Path $DtaCache ('pristine\' + $e.base + '\' + ($rel -replace '/', '\'))
            if ($stillPinned -and $OnPatchFail -eq 'KeepOld') {
                Say $rel "still PINNED: the patches refuse DTA $($man.Version)'s file"
                $warn.Add("$rel : pinned to an older DTA file; $failed")
            }
            elseif ($OnPatchFail -eq 'KeepOld' -and (Test-Path $oldPatched) -and (Test-Path $oldPristine)) {
                Say $rel 'patches refuse the new DTA file: KEEP OUR OLD BINARY'
                $warn.Add("$rel : $failed`n      -> kept our previous patched binary (PINNED to the old DTA file). DTA's new file: $pristine. Port the patches, then run dta-restore.ps1 again (or -OnPatchFail UseNew to drop them)")
                if (-not $DryRun) { Copy-Item $oldPristine "$full.bak" -Force; Copy-Item $oldPatched $full -Force }
            } else {
                if ($OnPatchFail -eq 'KeepOld') { $errors++ }   # UseNew is a choice, KeepOld without the old binary is not
                Say $rel 'patches refuse the new DTA file: left UNPATCHED'
                $warn.Add("$rel : $failed`n      -> DTA's new file stays unpatched$(if ($OnPatchFail -eq 'KeepOld') { ' (no old binary in Modding\.dta-cache)' }); the mods that need these patches do not work")
                if (-not $DryRun) { Set-Pristine $rel $pristine; Copy-Item $pristine $full -Force }
            }
        }
        Remove-Item $tmp
    }
}

foreach ($w in $warn) { "WARN $w" }
if ($DryRun) { return }
Write-DtaLog 'mod' ("dta-restore.ps1: DTA {0} -> {1}, {2} warning(s), {3} error(s)" -f $state.dtaVersion, $man.Version, $warn.Count, $errors)
if ($errors -eq 0) {
    "--- dta-capture.ps1"
    & "$PSScriptRoot\dta-capture.ps1" -Force
    "next: test the game; then git add -A; git commit -m 'DTA $($man.Version): re-applied mods'"
} else {
    "errors: fix them and run dta-restore.ps1 again (it is safe to repeat), then dta-capture.ps1 -Force"
}
