# Extra StarCraft weapon sounds that the unit/building MIXes of other sessions lack (terran-faction session).
# Which sound SC plays was read from SC's own data (scripts/iscript.bin + arr/sfxdata.dat), not guessed:
#   Goliath Hellfire missiles and the Missile Turret's Longbolt missile -> Bullet\HKMISSLE.wav (bullet\missile.grp iscript).
# Output: MIX/ECACHE88.MIX. Sound.ini: [SoundList] keys TFS01+ (block "StarCraft weapon sounds" at the end).
# Wiki: Modding/wiki/mods/starcraft-terran-buildings.md (section "Dźwięki ataku").
param([string]$StarCraft = "C:\Program Files (x86)\StarCraft",
      [string]$Game = (Resolve-Path "$PSScriptRoot\..\..").Path)
$ErrorActionPreference = 'Stop'
Add-Type -Path "$PSScriptRoot\Casc.cs", "$PSScriptRoot\ModTools.cs" -ReferencedAssemblies System.Drawing
$casc = New-Object Casc $StarCraft

$sounds = [ordered]@{
    SCHKMISL = 'SD/sound/bullet/hkmissle.wav'
}
$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
foreach ($k in $sounds.Keys) {
    $rate = 0
    $pcm = [Aud]::ReadWav($casc.ReadFile($sounds[$k]), [ref]$rate)
    $files["$k.AUD"] = [Aud]::Encode($pcm, $rate, 1.0)
}
[Mix]::Write("$Game\MIX\ECACHE88.MIX", $files)
"ECACHE88.MIX: " + (($files.Keys | ForEach-Object { "$_ ($($files[$_].Length) B)" }) -join ', ')
