# StarCraft building select sounds ("what" sounds) for the Terran, Zerg and Protoss buildings, like in SC.
# The engine plays VoiceSelect= for buildings too: TechnoClass::Select (game.exe 0x62F900) calls Response_Select
# (0x637330) for every techno class, BuildingClass included (wiki engine/sounds-aud).
# Which sound SC plays is read from SC's own data (arr/units.dat "What Sound Start/End" -> arr/sfxdata.dat/.tbl), not
# guessed by file name. Several SC buildings only click (Misc\Button.wav: CC, Barracks, Factory, Starport, Bunker, ...).
# Also: the Terran lift-off flyers (<ID>F) get their building's sound; deployed units (Siege Mode, burrowed Lurker,
# cloaking Arbiter, Duke) get the VoiceSelect of their mobile form, as in SC.
#   .\build-scbldgsounds.ps1            -> MIX/ECACHE79.MIX (AUD) only
#   .\build-scbldgsounds.ps1 -Install   -> + Sound.ini [SoundList] keys SBW01+, and a block "; >>> SC building select
#                                          sounds" at the end of StarCraft.ini and Terran Faction.ini (the client merges
#                                          repeated sections, the block only adds VoiceSelect=)
# Re-run after any generator that rebuilds the building sections is harmless; re-running this one replaces its own entries.
# Wiki: Modding/wiki/mods/sc-building-sounds.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScIscript.cs" -ReferencedAssemblies System.Drawing
$casc = New-Object Casc $StarCraft
$units = $casc.ReadFile('arr/units.dat')
$sc = New-Object ScIscript $casc.ReadFile('scripts/iscript.bin'), $casc.ReadFile('arr/images.dat'), $casc.ReadFile('arr/images.tbl'),
    $casc.ReadFile('arr/sprites.dat'), $casc.ReadFile('arr/flingy.dat'), $casc.ReadFile('arr/weapons.dat'), $units,
    $casc.ReadFile('arr/sfxdata.dat'), $casc.ReadFile('arr/sfxdata.tbl')

# DTA building -> SC unit id (units.dat)
$Map = [ordered]@{
    SCCC = 106; SCCOMS = 107; SCNUKE = 108; SCDEPO = 109; SCUDEPO = 109; SCREFI = 110; SCBARR = 111; SCACAD = 112
    SCFACT = 113; SCSTAR = 114; SCCTWR = 115; SCSCIF = 116; SCCOVO = 117; SCPHYS = 118; SCMSHP = 120; SCEBAY = 122
    SCARMO = 123; SCMTUR = 124; SCBUNK = 125
    SCZICC = 130; SCZHAT = 131; SCZHTS = 131; SCZLAI = 132; SCZHIV = 133; SCZNYD = 134; SCZHDN = 135; SCZDFM = 136
    SCZGSP = 137; SCZNES = 138; SCZEVO = 139; SCZULC = 140; SCZSPI = 141; SCZPOL = 142; SCZCRP = 143; SCZSPO = 144
    SCZSUN = 146; SCZOVS = 147; SCZOVM = 148; SCZEXT = 149; SCZCHR = 150; SCZCRB = 151; SCZDAG = 152
    SCPNEX = 154; SCPROB = 155; SCPPYL = 156; SCPASM = 157; SCPOBS = 159; SCPGAT = 160; SCPCAN = 162; SCPCIT = 163
    SCPCYB = 164; SCPARC = 165; SCPFOR = 166; SCPSTG = 167; SCPFLB = 169; SCPTRB = 170; SCPRSB = 171; SCPBAT = 172
}
# lift-off flyers: same SC unit as the building
foreach ($id in 'SCCC', 'SCBARR', 'SCFACT', 'SCSTAR', 'SCSCIF', 'SCEBAY', 'SCACAD', 'SCARMO', 'SCBUNK', 'SCMTUR', 'SCREFI') { $Map["$($id)F"] = $Map[$id] }
# deployed units: VoiceSelect copied from the mobile form named in UndeploysInto=
$Deployed = 'SCSIEGB', 'SCSIEGB2', 'SCHEROB', 'SCZLRB', 'SCZLRB2', 'SCPARBD', 'SCPARBD2'

# ---- SC what sounds -> AUD names SBW<stem> (tacwht00.wav -> SBWTAC, Misc\Button.wav -> SBWBUTTO)
function SoundName([string]$wav) {
    $stem = [IO.Path]::GetFileNameWithoutExtension($wav).ToUpper() -replace 'WHT\d\d$', ''
    return ('SBW' + $stem).Substring(0, [Math]::Min(8, 3 + $stem.Length))
}
$voice = [ordered]@{}            # DTA id -> list of sound names
$wavs = [ordered]@{}             # sound name -> CASC path
foreach ($id in $Map.Keys) {
    $u = $Map[$id]
    $a = [BitConverter]::ToUInt16($units, 9524 + $u * 2); $b = [BitConverter]::ToUInt16($units, 9980 + $u * 2)
    $names = @()
    foreach ($s in $a..$b) {
        $wav = $sc.Sound($s); $n = SoundName $wav
        $wavs[$n] = 'SD/sound/' + ($wav -replace '\\', '/').ToLower()
        $names += $n
    }
    $voice[$id] = $names
}

# per-sound loudness (user request 2026-10-26: Academy louder). SC WAVs already peak at ~100%, so a plain gain would clip:
# soft limiter y = tanh(g*x)/tanh(g) raises the quiet parts about g times and squeezes the peaks back under full scale.
$Gain = @{ SBWTAC = 2.5 }
function Louder([int16[]]$pcm, [double]$g) {
    $norm = [Math]::Tanh($g); $out = New-Object int16[] $pcm.Length
    for ($i = 0; $i -lt $pcm.Length; $i++) { $out[$i] = [int16][Math]::Round(32767 * [Math]::Tanh($g * $pcm[$i] / 32768.0) / $norm) }
    return ,$out
}

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
foreach ($n in $wavs.Keys) {
    $rate = 0
    $pcm = [Aud]::ReadWav($casc.ReadFile($wavs[$n]), [ref]$rate)
    if ($Gain.ContainsKey($n)) { $pcm = Louder $pcm $Gain[$n] }
    $files["$n.AUD"] = [Aud]::Encode($pcm, $rate, 1.0)
}
[Mix]::Write("$game\MIX\ECACHE79.MIX", $files)
"ECACHE79.MIX: $($files.Count) sounds: " + (($wavs.Keys | ForEach-Object { "$_ <- $($wavs[$_])" }) -join '; ')
if (-not $Install) { return }

# ------------------------------------------------------------------ INI side
$latin = [Text.Encoding]::GetEncoding(28591)
$begin = '; >>> SC building select sounds'; $end = '; <<< SC building select sounds'
function Backup([string]$path) { if (-not (Test-Path "$path.bak")) { Copy-Item $path "$path.bak" } }
function Nl([string]$path) { if ([IO.File]::ReadAllText($path, $latin).Contains("`r`n")) { "`r`n" } else { "`n" } }
function Set-Block([string]$path, [string]$body, [string]$nl) {
    $t = [IO.File]::ReadAllText($path, $latin)
    $block = ($begin + $nl + ($body.TrimEnd() -replace "`r?`n", $nl) + $nl + $end + $nl)
    $a = $t.IndexOf($begin)
    if ($a -ge 0) { $b = $t.IndexOf($end, $a); $b = $t.IndexOf("`n", $b) + 1; $t = $t.Substring(0, $a) + $block + $t.Substring($b) }
    else { if (-not $t.EndsWith("`n")) { $t += $nl }; $t += $nl + $block }
    [IO.File]::WriteAllText($path, $t, $latin)
}
# entries inside an existing section, after its last key line; old entries matching $own are removed first
function Set-SectionEntries([string]$path, [string]$section, [string[]]$entries, [string]$own, [string]$nl) {
    $t = [IO.File]::ReadAllText($path, $latin)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.AddRange([string[]]($t -split "`n"))
    $s = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimEnd("`r") -eq "[$section]") { $s = $i; break } }
    if ($s -lt 0) { throw "[$section] not found in $path" }
    $e = $lines.Count; for ($j = $s + 1; $j -lt $lines.Count; $j++) { if ($lines[$j].StartsWith('[')) { $e = $j; break } }
    for ($i = $e - 1; $i -gt $s; $i--) { if ($lines[$i] -match $own) { $lines.RemoveAt($i); $e-- } }
    $last = $s; for ($j = $s + 1; $j -lt $e; $j++) { $x = $lines[$j].Trim(); if ($x -and -not $x.StartsWith(';')) { $last = $j } }
    $cr = if ($nl -eq "`r`n") { "`r" } else { '' }
    $lines.InsertRange($last + 1, [string[]]($entries | ForEach-Object { $_ + $cr }))
    [IO.File]::WriteAllText($path, ($lines -join "`n"), $latin)
}
# section -> key/value, ignoring this script's own block
function Read-Sections([string]$path) {
    $t = [IO.File]::ReadAllText($path, $latin); $a = $t.IndexOf($begin)
    if ($a -ge 0) { $b = $t.IndexOf("`n", $t.IndexOf($end, $a)) + 1; $t = $t.Substring(0, $a) + $t.Substring($b) }
    $d = @{}; $sec = $null
    foreach ($l in ($t -split "`r?`n")) {
        if ($l -match '^\[([^\]]+)\]') { $sec = $Matches[1]; if (-not $d.ContainsKey($sec)) { $d[$sec] = @{} }; continue }
        if ($sec -and $l -match '^\s*([A-Za-z]+)\s*=\s*([^;\t]*)') { $d[$sec][$Matches[1]] = $Matches[2].Trim() }
    }
    return $d
}

$ini = [ordered]@{ "$game\INI\Game Options\StarCraft.ini" = $null; "$game\INI\Map Code\Terran Faction.ini" = $null }
foreach ($p in @($ini.Keys)) { $ini[$p] = Read-Sections $p }
function Owner-File([string]$id) { foreach ($p in $ini.Keys) { if ($ini[$p].ContainsKey($id)) { return $p } }; return $null }

$bodies = @{}; foreach ($p in $ini.Keys) { $bodies[$p] = '' }
$missing = @()
foreach ($id in $voice.Keys) {
    $p = Owner-File $id; if (-not $p) { $missing += $id; continue }
    $bodies[$p] += "`r`n[$id]`r`nVoiceSelect=$($voice[$id] -join ',')`r`n"
}
foreach ($id in $Deployed) {
    $p = Owner-File $id; if (-not $p) { $missing += $id; continue }
    $src = $ini[$p][$id]['UndeploysInto']; $sp = if ($src) { Owner-File $src }
    $vs = if ($sp) { $ini[$sp][$src]['VoiceSelect'] }
    if (-not $vs) { $missing += "$id (no VoiceSelect on '$src')"; continue }
    $bodies[$p] += "`r`n[$id]`r`nVoiceSelect=$vs`t; = $src`r`n"
}
foreach ($p in $ini.Keys) {
    Backup $p
    $head = "; SC building select sounds (Modding/tools/build-scbldgsounds.ps1, MIX/ECACHE79.MIX): SC plays a 'what' sound`r`n" +
            "; when a building is selected; the engine plays VoiceSelect= for buildings too. Only VoiceSelect= is set here.`r`n"
    Set-Block $p ($head + $bodies[$p]) (Nl $p)
}

$snd = "$game\INI\Sound.ini"; Backup $snd
$n = 1; $list = @()
foreach ($k in $wavs.Keys) { $list += ('SBW{0:D2}={1}' -f $n, $k) + $(if ($n -eq 1) { "`t; SC building select sounds, MIX/ECACHE79.MIX (build-scbldgsounds.ps1)" }); $n++ }
Set-SectionEntries $snd 'SoundList' $list '^SBW\d+=' "`r`n"

"installed: VoiceSelect on $(($bodies.Values | ForEach-Object { ([regex]::Matches($_, 'VoiceSelect=')).Count } | Measure-Object -Sum).Sum) types, Sound.ini SBW01-SBW$('{0:D2}' -f ($n - 1))"
if ($missing) { "WARNING, not set: " + ($missing -join ', ') }
