# Decompiles the trigger logic of a TS/DTA map into readable text: triggers with their tag, events and actions
# (names from FinalSun's FSData.ini), Text Trigger lines resolved from the map's [Tutorial] or INI\Tutorial.ini,
# local variables, teams (taskforce + script) and objects with a tag attached.
#
#   .\dump-triggers.ps1 -Map "Maps\Missions\rsovm1.map"            # print to the console
#   .\dump-triggers.ps1 -Map "Maps\Missions\rsovm1.map" -Out x.txt
param(
    [Parameter(Mandatory)] [string]$Map,
    [string]$Out = ""
)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path "$PSScriptRoot\..\..").Path
if (-not [IO.Path]::IsPathRooted($Map)) { $Map = Join-Path $game $Map }

function Read-Ini([string]$path) {
    $ini = [ordered]@{}; $sec = $null
    foreach ($l in [IO.File]::ReadAllLines($path, [Text.Encoding]::GetEncoding(1252))) {
        if ($l -match '^\s*\[([^\]]+)\]') { $sec = $matches[1]; if (-not $ini.Contains($sec)) { $ini[$sec] = [ordered]@{} }; continue }
        if ($null -eq $sec -or $l -match '^\s*;' -or $l -notmatch '=') { continue }
        $i = $l.IndexOf('='); $k = $l.Substring(0, $i).Trim(); $v = $l.Substring($i + 1)
        $c = $v.IndexOf(';'); if ($c -ge 0 -and $sec -ne 'Tutorial') { $v = $v.Substring(0, $c) }
        $ini[$sec][$k] = $v.Trim()
    }
    $ini
}
function Sec($ini, $name) { if ($ini.Contains($name)) { $ini[$name] } else { [ordered]@{} } }

$fs  = Read-Ini "$game\Map Editor\FinalSun\FSData.ini"
$m = Read-Ini $Map
$tut = Sec (Read-Ini "$game\INI\Tutorial.ini") 'Tutorial'
$mapTut = Sec $m 'Tutorial'
$evName = @{}; foreach ($k in $fs['Events'].Keys) { $evName[$k] = ($fs['Events'][$k] -split ',')[0] -replace '%1', ',' }
$acName = @{}; foreach ($k in $fs['Actions'].Keys) { $acName[$k] = ($fs['Actions'][$k] -split ',')[0] -replace '%1', ',' }
$scName = @{}; foreach ($k in $fs['Scripts'].Keys) { $scName[$k] = ($fs['Scripts'][$k] -split ',')[0] }

# waypoint letters: A=0 ... Z=25, AA=26 (bijective base 26)
function WpNum([string]$s) { $n = 0; foreach ($ch in $s.ToCharArray()) { $n = $n * 26 + ([int]$ch - 64) }; $n - 1 }

$trig = Sec $m 'Triggers'; $tags = Sec $m 'Tags'; $ev = Sec $m 'Events'; $ac = Sec $m 'Actions'
$names = @{}; foreach ($k in $trig.Keys) { $names[$k] = ($trig[$k] -split ',')[2] }
foreach ($k in $tags.Keys) { $names[$k] = ($tags[$k] -split ',')[1] }
foreach ($id in (Sec $m 'TeamTypes').Values) { if ($m.Contains($id)) { $names[$id] = $m[$id]['Name'] } }
$locals = @{}; foreach ($k in (Sec $m 'VariableNames').Keys) { $locals[$k] = ((Sec $m 'VariableNames')[$k] -split ',')[0] }
function Ref($id) { if ($names.ContainsKey($id)) { "$id '$($names[$id])'" } else { $id } }
function Text($n) { if ($mapTut.Contains("$n")) { "[map] " + $mapTut["$n"] } elseif ($tut.Contains("$n")) { "[Tutorial.ini] " + $tut["$n"] } else { '(brak tekstu)' } }

$o = New-Object Collections.Generic.List[string]
$o.Add("# $Map"); $b = Sec $m 'Basic'; $o.Add("Name=$($b['Name'])  Player=$($b['Player'])  Theme=$($b['Theme'])")
$tagOf = @{}; foreach ($k in $tags.Keys) { $p = $tags[$k] -split ','; $tagOf[$p[2]] = @($k, $p[0]) }
foreach ($k in $trig.Keys) {
    $p = $trig[$k] -split ','
    $flags = "house=$($p[0])"; if ($p[1] -ne '<none>') { $flags += " linked=$(Ref $p[1])" }
    if ($p[3] -eq '1') { $flags += ' DISABLED' }; $flags += " diff(E/N/H)=$($p[4])$($p[5])$($p[6])"
    $t = $tagOf[$k]; if ($t) { $flags += " tag=$($t[0]) persist=$($t[1])" }
    $o.Add(""); $o.Add("== $k '$($p[2])'  $flags")
    if ($ev.Contains($k)) {
        $e = $ev[$k] -split ','; $i = 1
        for ($n = 0; $n -lt [int]$e[0]; $n++) {
            $id = $e[$i]; $pt = $e[$i + 1]
            if ($pt -eq '2') { $par = "$($e[$i + 2]),$($e[$i + 3])"; $i += 4 } else { $par = $e[$i + 2]; $i += 3 }
            $o.Add("   IF  [$id] $($evName[$id]) ($par)")
        }
    }
    if ($ac.Contains($k)) {
        $a = $ac[$k] -split ','; $i = 1
        for ($n = 0; $n -lt [int]$a[0]; $n++) {
            $id = $a[$i]; $pk = $a[$i + 1]; $ps = $a[($i + 2)..($i + 6)]; $wp = $a[$i + 7]; $i += 8
            $par = $ps[0]
            switch ($id) {
                '11' { $par = "$($ps[0]) -> " + (Text $ps[0]) }
                { $_ -in '4', '5', '7', '80', '101', '105', '12', '22', '53', '54', '70' } { $par = Ref $ps[0] }
                { $_ -in '56', '57' } { $par = "$($ps[0]) '$($locals[$ps[0]])'" }
            }
            $w = if ($wp -and $wp -ne 'A' -or $id -in '8', '41', '42', '48', '55', '80', '94', '95', '99') { " @wp$(WpNum $wp)" } else { '' }
            $o.Add("   DO  [$id] $($acName[$id]) (kind=$pk, $par$(if ($ps[1] -ne '0') { ", $($ps[1..4] -join ',')" }))$w")
        }
    }
}
if ($locals.Count) { $o.Add(""); $o.Add("== Local variables"); foreach ($k in $locals.Keys | Sort-Object { [int]$_ }) { $o.Add("   $k = $($locals[$k])") } }
$o.Add(""); $o.Add("== TeamTypes")
foreach ($id in (Sec $m 'TeamTypes').Values) {
    $t = $m[$id]; $tf = $m[$t['TaskForce']]; $sc = $m[$t['Script']]
    $mem = if ($tf) { ($tf.Keys | Where-Object { $_ -match '^\d+$' } | ForEach-Object { $tf[$_] }) -join ' ' } else { '?' }
    $lines = if ($sc) { ($sc.Keys | Where-Object { $_ -match '^\d+$' } | ForEach-Object { $q = $sc[$_] -split ','; "$($scName[$q[0]])=$($q[1])" }) -join ' | ' } else { '?' }
    $o.Add("   $id '$($t['Name'])' house=$($t['House']) wp=$($t['Waypoint']) [$mem] script: $lines")
}
$o.Add(""); $o.Add("== Objects with tags")
foreach ($s in 'Structures', 'Units', 'Infantry', 'Aircraft') {
    foreach ($v in (Sec $m $s).Values) {
        $p = $v -split ','
        $tagIdx = switch ($s) { 'Structures' { 6 } 'Infantry' { 8 } default { 7 } }
        if ($p[$tagIdx] -and $p[$tagIdx] -ne 'None') { $o.Add("   $s $($p[0]) $($p[1]) @ $($p[3]),$($p[4]) -> $(Ref $p[$tagIdx])") }
    }
}
$ct = Sec $m 'CellTags'; if ($ct.Count) { $o.Add("   CellTags: " + (($ct.Values | Group-Object | ForEach-Object { "$(Ref $_.Name) x$($_.Count)" }) -join ', ')) }
if ($Out) { $o | Set-Content $Out -Encoding UTF8; "written $Out ($($o.Count) lines)" } else { $o }
