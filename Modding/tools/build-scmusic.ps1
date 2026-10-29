# StarCraft music in DTA (user 2026-10-29: "dodaj całą muzykę SC do naszego moda żeby wczuć się w środowisko").
#   - All 23 tracks of SC:R's SD/music/*.wav (22 050 Hz 16-bit stereo) from the user's own CASC install, downmixed to mono
#     and encoded as Westwood IMA AUD like every DTA score (Scores.mix / Scores01.mix: 22 050 Hz, flags=2, type 99).
#     Loudness matches DTA's scores (RMS 4-7k on both sides, measured 2026-10-29), so gain stays 1.0.
#   - The AUDs are LOOSE files in MUSIC\ (on the engine search path ;SOUNDS;SPEECH;MUSIC;...), not in an ECACHE MIX: the
#     ~65 MB would otherwise be cached in RAM, and themes are streamed from file anyway.
#   - 14 full tracks join the in-game playlist (Scenario=1 like DTA's own); the ready-room, victory and defeat cues are
#     declared with Normal=no Repeat=no, so map triggers can play them (action 20 Play Music Theme, index from the comment).
# Writes: MUSIC\SC*.AUD and two blocks in INI/Theme.ini: "; >>> SC music themes" lines inside [Themes] (indices after DTA's last)
# and "; >>> SC music sections" at the end. Without -Install only the AUDs go to %TEMP%\scmusic.
# Wiki: Modding/wiki/mods/sc-music.md.
param([switch]$Install)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path "$PSScriptRoot\..\..").Path
$latin = [Text.Encoding]::GetEncoding(28591)
Add-Type -Path "$PSScriptRoot\Casc.cs", "$PSScriptRoot\ModTools.cs" -ReferencedAssemblies System.Drawing
$casc = New-Object Casc 'C:\Program Files (x86)\StarCraft'

# file, theme ID (8.3), display name, in playlist
$tracks = @(
    @('title',         'SCTITLE',  'SC: Title',             $true),
    @('terran1',       'SCTERR1',  'SC: Terran Theme 1',    $true),
    @('terran2',       'SCTERR2',  'SC: Terran Theme 2',    $true),
    @('terran3',       'SCTERR3',  'SC: Terran Theme 3',    $true),
    @('terran4',       'SCTERR4',  'SC: Terran Theme 4',    $true),
    @('zerg1',         'SCZERG1',  'SC: Zerg Theme 1',      $true),
    @('zerg2',         'SCZERG2',  'SC: Zerg Theme 2',      $true),
    @('zerg3',         'SCZERG3',  'SC: Zerg Theme 3',      $true),
    @('zerg4',         'SCZERG4',  'SC: Zerg Theme 4',      $true),
    @('protoss1',      'SCPROT1',  'SC: Protoss Theme 1',   $true),
    @('protoss2',      'SCPROT2',  'SC: Protoss Theme 2',   $true),
    @('protoss3',      'SCPROT3',  'SC: Protoss Theme 3',   $true),
    @('protoss4',      'SCPROT4',  'SC: Protoss Theme 4',   $true),
    @('radiofreezerg', 'SCRFZERG', 'SC: Radio Free Zerg',   $true),
    @('trdyroom',      'SCTRDY',   'SC: Terran Ready Room', $false),
    @('zrdyroom',      'SCZRDY',   'SC: Zerg Ready Room',   $false),
    @('prdyroom',      'SCPRDY',   'SC: Protoss Ready Room',$false),
    @('tvict',         'SCTVICT',  'SC: Terran Victory',    $false),
    @('zvict',         'SCZVICT',  'SC: Zerg Victory',      $false),
    @('pvict',         'SCPVICT',  'SC: Protoss Victory',   $false),
    @('tdefeat',       'SCTDEF',   'SC: Terran Defeat',     $false),
    @('zdefeat',       'SCZDEF',   'SC: Zerg Defeat',       $false),
    @('pdefeat',       'SCPDEF',   'SC: Protoss Defeat',    $false))

$out = if ($Install) { "$game\MUSIC" } else { "$env:TEMP\scmusic" }
New-Item -ItemType Directory -Force $out | Out-Null
$len = @{}
foreach ($t in $tracks) {
    $rate = 0
    $pcm = [Aud]::ReadWav($casc.ReadFile("SD/music/$($t[0]).wav"), [ref]$rate)
    if ($rate -ne 22050) { throw "$($t[0]): $rate Hz" }
    [IO.File]::WriteAllBytes("$out\$($t[1]).AUD", [Aud]::Encode($pcm, $rate, 1.0))
    $len[$t[1]] = $pcm.Length / $rate
    '{0,-9} {1,4:N0} s' -f $t[1], $len[$t[1]]
}
if (-not $Install) { "AUDs in $out (no -Install: Theme.ini untouched)"; return }

$theme = "$game\INI\Theme.ini"
if (-not (Test-Path "$theme.bak")) { Copy-Item $theme "$theme.bak" }
function Set-Block([string]$text, [string]$begin, [string]$end, [string]$body, [int]$at) {
    $block = $begin + "`r`n" + $body.TrimEnd() + "`r`n" + $end + "`r`n"
    $a = $text.IndexOf($begin)
    if ($a -ge 0) { $z = $text.IndexOf("`n", $text.IndexOf($end, $a)) + 1; return $text.Substring(0, $a) + $block + $text.Substring($z) }
    if ($at -lt 0) { if (-not $text.EndsWith("`n")) { $text += "`r`n" }; return $text + "`r`n" + $block }
    return $text.Insert($at, $block)
}
$t = [IO.File]::ReadAllText($theme, $latin)
# indices continue after DTA's last [Themes] entry (outside our block)
$own = $t.IndexOf('; >>> SC music themes'); $plain = if ($own -ge 0) { $t.Substring(0, $own) } else { $t }
$s = $plain.IndexOf("[Themes]"); $e = $plain.IndexOf("`n[", $s); if ($e -lt 0) { $e = $plain.Length }
$last = -1; $lastEnd = 0
foreach ($m in [regex]::Matches($plain.Substring($s, $e - $s), '(?m)^(\d+)=[^\r\n]*\r?\n')) { $last = [int]$m.Groups[1].Value; $lastEnd = $s + $m.Index + $m.Length }
$i = $last + 1
$list = foreach ($tr in $tracks) { '{0}={1}' -f $i++, $tr[1] }
$secs = foreach ($tr in $tracks) {
    $l = $len[$tr[1]]; $mm = [int][Math]::Floor($l / 60); $ss = [int][Math]::Floor($l % 60)
    $avail = if ($tr[3]) { "Scenario=1" } else { "Normal=no`r`nRepeat=no" }
    ("[{0}]`r`nName={1}`r`nLength={2}`t;{3}:{4:00}`r`n{5}`r`n" -f $tr[1], $tr[2], ($l / 60).ToString('0.00', [Globalization.CultureInfo]::InvariantCulture), $mm, $ss, $avail)
}
$t = Set-Block $t '; >>> SC music sections' '; <<< SC music sections' ($secs -join "`r`n") -1
$t = Set-Block $t '; >>> SC music themes' '; <<< SC music themes' ($list -join "`r`n") $lastEnd
[IO.File]::WriteAllText($theme, $t, $latin)
"Theme.ini: indices $($last + 1)-$($i - 1)"
