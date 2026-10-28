# Map code of the skirmish factions (Terran, Zerg, Protoss), shared by the generators. Dot-source after $game is set:
#   . "$PSScriptRoot\MapCode.ps1"
# Layout:
#   INI/Map Code/Terran Faction.ini           the file the client loads (INI/MPMaps.ini MapCodeININame): only a pointer
#   INI/Map Code/SC Factions/NNN <name>.ini   one layer per block, each "[INISystem] BasedOn=" the layer below it
# The client builds the map code with Rampastring.Tools IniFile (DTAClient GameMode.GetMapRulesIniFile), which loads a
# BasedOn file first and lays the file over it (later keys win, repeated list sections merge), recursively. So the chain
# from the entry down to "000 Terran faction.ini" works like one file with the layers in chain order (bottom first).
# Generators find their layer by name without the number ('Zerg faction' -> "010 Zerg faction.ini"), so layers may be
# renumbered. Wiki: engine/map-code-layers.
$MapCodeEntry = "$game\INI\Map Code\Terran Faction.ini"
$MapCodeDir   = "$game\INI\Map Code\SC Factions"
$MapCodeEnc   = [Text.Encoding]::GetEncoding(28591)

# full path of the file named by [INISystem] BasedOn= of $path (relative to $path's folder, like the client), or $null
function Get-MapCodeBasedOn([string]$path) {
    $sec = $null
    foreach ($l in [IO.File]::ReadAllLines($path, $MapCodeEnc)) {
        if ($l -match '^\s*\[([^\]]+)\]') { $sec = $Matches[1]; continue }
        if ($sec -eq 'INISystem' -and $l -match '^\s*BasedOn\s*=\s*([^;\t]*)') {
            $b = $Matches[1].Trim(); if ($b) { return [IO.Path]::GetFullPath((Join-Path (Split-Path $path) $b)) }
        }
    }
    return $null
}

# layer files in merge order: the bottom layer first, the top layer (the one the entry points to) last
function Get-MapCodeLayers {
    $chain = New-Object Collections.Generic.List[string]; $seen = @{}
    $p = Get-MapCodeBasedOn $MapCodeEntry
    while ($p) {
        if ($seen[$p]) { throw "Map code: BasedOn loop at $p" }; $seen[$p] = 1
        if (-not (Test-Path $p)) { throw "Map code: BasedOn names a missing file: $p" }
        $chain.Insert(0, $p); $p = Get-MapCodeBasedOn $p
    }
    return $chain.ToArray()
}

function Get-MapCodeLayerName([string]$path) { return ([IO.Path]::GetFileNameWithoutExtension($path) -replace '^\d+\s+', '') }

function Get-MapCodeLayer([string]$name) {
    foreach ($p in @(Get-MapCodeLayers)) { if ((Get-MapCodeLayerName $p) -eq $name) { return $p } }
    throw "Map code: no layer '$name' in the BasedOn chain of $MapCodeEntry (a new one: New-MapCodeLayer, wiki engine/map-code-layers)"
}

# text of every layer in merge order (what the client sees, as one INI text), optionally without one layer
function Read-MapCodeText([string]$Exclude) {
    $x = if ($Exclude) { [IO.Path]::GetFullPath($Exclude) } else { $null }
    $sb = New-Object Text.StringBuilder
    foreach ($p in @(Get-MapCodeLayers)) {
        if ($x -and $p -eq $x) { continue }
        [void]$sb.Append([IO.File]::ReadAllText($p, $MapCodeEnc).TrimEnd()).Append("`r`n`r`n")
    }
    return $sb.ToString()
}

# writes $block (text from its "; >>> X" line to its "; <<< X" line) into a layer: replaces the old block and everything
# after it, keeps the layer header above it
function Set-MapCodeBlock([string]$path, [string]$block) {
    $t = [IO.File]::ReadAllText($path, $MapCodeEnc)
    $nl = if ($t.Contains("`r`n")) { "`r`n" } else { "`n" }
    $begin = ($block -split "`r?`n")[0]
    $a = $t.IndexOf($begin)
    $head = if ($a -ge 0) { $t.Substring(0, $a) } else { $t.TrimEnd() + $nl + $nl }
    [IO.File]::WriteAllText($path, $head + ($block.TrimEnd() -replace "`r?`n", $nl) + $nl, $MapCodeEnc)
}

# new empty layer "<NNN> $Name.ini" right above the layer $Below (default: right below "Hand edits", so that the hand-made
# overrides stay on top); $Header = comment lines (what the layer is, which script writes it)
function New-MapCodeLayer([string]$Name, [string]$Header, [string]$Below) {
    $layers = @(Get-MapCodeLayers)
    if (-not $Below) { $hand = @($layers | Where-Object { (Get-MapCodeLayerName $_) -eq 'Hand edits' }); $i = if ($hand) { [Array]::IndexOf($layers, $hand[0]) - 1 } else { $layers.Count - 1 } }
    else { $i = [Array]::IndexOf($layers, (Get-MapCodeLayer $Below)) }
    $under = $layers[$i]; $over = if ($i + 1 -lt $layers.Count) { $layers[$i + 1] } else { $MapCodeEntry }
    $nUnder = [int]([IO.Path]::GetFileName($under) -replace '^(\d+).*', '$1')
    $nOver = if ($over -eq $MapCodeEntry) { $nUnder + 20 } else { [int]([IO.Path]::GetFileName($over) -replace '^(\d+).*', '$1') }
    if ($nOver - $nUnder -lt 2) { throw "Map code: no free number between '$under' and '$over': renumber the layers (and their BasedOn=)" }
    $path = Join-Path $MapCodeDir ('{0:D3} {1}.ini' -f [int](($nUnder + $nOver) / 2), $Name)
    $h = (($Header -split "`r?`n") | ForEach-Object { if ($_ -match '^;') { $_ } else { "; $_" } }) -join "`r`n"
    [IO.File]::WriteAllText($path, "$h`r`n[INISystem]`r`nBasedOn=$([IO.Path]::GetFileName($under))`r`n", $MapCodeEnc)
    $rel = if ($over -eq $MapCodeEntry) { "SC Factions/$([IO.Path]::GetFileName($path))" } else { [IO.Path]::GetFileName($path) }
    $t = [IO.File]::ReadAllText($over, $MapCodeEnc)
    $t = ([regex]'(?m)^(\s*BasedOn\s*=\s*)[^;\t\r\n]*').Replace($t, { param($m) $m.Groups[1].Value + $rel }, 1)
    [IO.File]::WriteAllText($over, $t, $MapCodeEnc)
    return $path
}
