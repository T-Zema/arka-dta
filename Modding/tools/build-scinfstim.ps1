# StarCraft Marine, Firebat and Medic as REAL INFANTRY, Marine/Firebat with a stimpack on the D key (TEST units of the Terran faction, house GDI1,
# trained in the Terran Barracks). The stimpack is the infantry deploy patch Modding/tools/patch-infdeploy.ps1: infantry type
# X deploys into X_D and back. X_D = red-tinted image, the stim weapon (ROF halved) and +40% speed; going on stim costs 1/4
# of the max HP (in the patch). The vehicle Marines/Firebats (SCMARINE, SCFIRE + research upgrades) stay as they are.
#   .\build-scinfstim.ps1              -> MIX/ECACHE81.MIX (SHP + cameos) + preview sheets in -PreviewDir
#   .\build-scinfstim.ps1 -Install     -> also writes the "SC infantry stim" blocks into StarCraft.ini, Art.ini, Sound.ini
# Needs the STARCRAFT checkbox (StarCraft.ini) like every Terran unit. Wiki: Modding/wiki/mods/sc-infantry-stim.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\scinfstim-preview",
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (Get-Process game -ErrorAction SilentlyContinue) { throw "the game is running: close it first (the script rewrites MIX/ECACHE81.MIX, and -Install the INI files)" }
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScBuild.cs", "$tools\ScInfantry.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null
$casc  = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"

# palettes as in build-scmarine.ps1 / build-sczerg.ps1
$scPal    = [Pal]::ReadWpe($casc.ReadFile('TileSet/jungle.wpe'))
$unitPal  = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$cameoPal = [Pal]::ReadTs($mixes.Read('CAMEO.PAL'))
$w = 0; $h = 0; $tpal = $null
$tunit = [Pal]::ReadPcx($casc.ReadFile('game/tunit.pcx'), [ref]$w, [ref]$h, [ref]$tpal)
$ramp = New-Object 'System.Drawing.Color[]' 8
for ($i = 0; $i -lt 8; $i++) { $ramp[$i] = $tpal[$tunit[$i]] }
$map     = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)
$mapStim = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0.35)   # same red tint as the vehicle stim (SCMARSTM)

function G($name) { [Grp]::Read($casc.ReadFile("unit/terran/$name.grp")) }
# a GRP moved onto a bigger canvas (the Firebat is 32x32, its remains are the Marine's 64x64 blood splat)
function Grow($grp, [int]$size) {
    $d = [int](($size - $grp.Width) / 2); $g = New-Object Grp; $g.Width = $size; $g.Height = $size
    foreach ($f in $grp.Frames) { $n = New-Object Frame ($f.X + $d), ($f.Y + $d), $f.W, $f.H; [Array]::Copy($f.Pixels, $n.Pixels, $f.Pixels.Length); $g.Frames.Add($n) }
    $g
}

# frame sets (GRP set = 17 directions; same sets as the vehicle versions in build-scmarine.ps1 / build-scunits.ps1):
# Marine 0 stand, 2 aim, 3 fire with muzzle flash, 4-12 walk, 221-228 death + tmadeath; Firebat 0 stand, 1 flame, 2-9 walk.
# Fire lists hold every SC frame twice (TS plays infantry fire frames at 1 tick, see build-sczerg.ps1).
$marine = G 'marine'; $mShad = G 'tmashad'; $remains = G 'tmadeath'
$fbat = Grow (G 'firebat') 64; $fShad = Grow (G 'tfbshad') 64
$medic = G 'medic'; $mdShad = G 'tmeshad'; $mdRemains = G 'tmeDeath'
# Medic (user 2026-10-27: "dodaj jeszcze taka sama jednostke infantry medyk ale po odblokowaniu akademii"): sets as the
# vehicle SCMEDIC (build-scunits.ps1): 0 stand, 4-5 heal, 6-12 walk; death 221-229 + tmeDeath. No stim (Stim = $false).
$units = @(
    @{ Id = 'SCMARI'; Body = $marine; Shadow = $mShad; Stand = 0; Walk = 4..12; Fire = 2, 2, 3, 3, 2, 2; FireFrame = 2; Flh = '60,0,70'; Stim = $true
       Death = @(@(221..228 | ForEach-Object { $marine.Frames[$_] }) + @($remains.Frames)) }
    @{ Id = 'SCFIRI'; Body = $fbat; Shadow = $fShad; Stand = 0; Walk = 2..9; Fire = 1, 1, 1, 1, 1, 1; FireFrame = 1; Flh = '50,0,60'; Stim = $true
       Death = @($remains.Frames) }
    @{ Id = 'SCMEDI'; Body = $medic; Shadow = $mdShad; Stand = 0; Walk = 6..12; Fire = 4, 4, 5, 5, 4, 4; FireFrame = 2; Flh = '40,0,60'; Stim = $false
       Death = @(@(221..229 | ForEach-Object { $medic.Frames[$_] }) + @($mdRemains.Frames)) }
)

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$layouts = @{}
foreach ($u in $units) {
    $death = New-Object 'System.Collections.Generic.List[Frame]'; foreach ($f in $u.Death) { $death.Add($f) }
    $lay = $null; $layS = $null
    $shp  = [ScInfantry]::Build($u.Body, $u.Shadow, $map,     $u.Stand, [int[]]$u.Walk, [int[]]$u.Fire, $death, [ref]$lay)
    $layouts[$u.Id] = $lay
    $files["$($u.Id).SHP"] = $shp.Write()
    if ($u.Stim) {
        $shpS = [ScInfantry]::Build($u.Body, $u.Shadow, $mapStim, $u.Stand, [int[]]$u.Walk, [int[]]$u.Fire, $death, [ref]$layS)
        $files["$($u.Id)_D.SHP"] = $shpS.Write()
        [Pal]::Sheet($shpS.Frames, [int[]](0..7), $shpS.Width, $shpS.Height, $unitPal, 2, 8, "$PreviewDir\$($u.Id)_D.png")
    }
    $cameo = [ScInfantry]::Cameo($u.Body.Frames[$u.Stand * 17 + 12], $u.Body.Width, $u.Body.Height, $scPal, $ramp, $cameoPal, [Drawing.Color]::FromArgb(60, 90, 150))
    $files["$($u.Id)I.SHP"] = $cameo.Write()
    "{0}: {1}x{2}, {3} frames (+shadows), walk 8x{4} @{5}, fire 8x{6} @{7}, death {8} @{9}" -f $u.Id, $shp.Width, $shp.Height, $lay.Total,
        $lay.WalkFrames, $lay.Walk, $lay.FireFrames, $lay.Fire, $lay.DeathFrames, $lay.Death
    $idx = @(0..7) + @(($lay.Walk + 6 * $lay.WalkFrames)..($lay.Walk + 7 * $lay.WalkFrames - 1)) + @(($lay.Fire + 6 * $lay.FireFrames)..($lay.Fire + 7 * $lay.FireFrames - 1)) + @($lay.Death..($lay.Death + $lay.DeathFrames - 1))
    [Pal]::Sheet($shp.Frames, [int[]]$idx, $shp.Width, $shp.Height, $unitPal, 2, 12, "$PreviewDir\$($u.Id).png")
    $one = New-Object 'System.Collections.Generic.List[Frame]'; $one.Add($cameo.Frames[0])
    [Pal]::Sheet($one, [int[]]@(0), 64, 48, $cameoPal, 3, 1, "$PreviewDir\$($u.Id)_cameo.png")
}
[Mix]::Write("$game\MIX\ECACHE81.MIX", $files)
"ECACHE81.MIX: $($files.Count) files, $([Math]::Round((Get-Item "$game\MIX\ECACHE81.MIX").Length / 1KB)) KB; previews -> $PreviewDir"
if (-not $Install) { return }

# ------------------------------------------------------------------ INI blocks (between markers; re-running replaces them)
$latin = [Text.Encoding]::GetEncoding(28591)
$begin = '; >>> SC infantry stim'; $end = '; <<< SC infantry stim'
function Set-Block([string]$path, [string]$body, [string]$nl) {
    $t = [IO.File]::ReadAllText($path, $latin)
    $block = ($begin + $nl + ($body.TrimEnd() -replace "`r?`n", $nl) + $nl + $end + $nl)
    $a = $t.IndexOf($begin)
    if ($a -ge 0) { $b = $t.IndexOf($end, $a); $b = $t.IndexOf("`n", $b) + 1; $t = $t.Substring(0, $a) + $block + $t.Substring($b) }
    else { if (-not $t.EndsWith("`n")) { $t += $nl }; $t += $nl + $block }
    [IO.File]::WriteAllText($path, $t, $latin)
}
$sc = "$game\INI\Game Options\StarCraft.ini"; $art = "$game\INI\Art.ini"
foreach ($f in $sc, $art) { if (-not (Test-Path "$f.bak")) { Copy-Item $f "$f.bak" } }

# common keys of the four types; stats: real infantry goes prone (half damage), so HP = vehicle version / 1.6 (wiki
# engine/transform-deploy: the vehicle Marine got 800 instead of 500 for that reason)
$common = @"
Category=Soldier
Locomotor={4A582744-9839-11d1-B709-00A024DDAFD1}
MovementZone=Infantry
Armor=none
Owner=GDI1
Crewed=no
Trainable=yes
PhysicalSize=1
Pip=green
AllowedToStartInMultiplayer=no
IsWebImmune=true
ImmuneToVeins=yes
VeteranAbilities=STRONGER,FASTER
EliteAbilities=SELF_HEAL,ROF
VoiceFeedback=
"@
$marineVoices = "VoiceSelect=SCMAWHT0,SCMAWHT1,SCMAWHT2,SCMAWHT3`r`nVoiceMove=SCMAYES0,SCMAYES1,SCMAYES2,SCMAYES3`r`nVoiceAttack=SCMAYES0,SCMAYES1,SCMAYES2,SCMAYES3`r`nVoiceDie=SCMADTH0,SCMADTH1"
$fbatVoices   = "VoiceSelect=SCFBWHT0,SCFBWHT1,SCFBWHT2,SCFBWHT3`r`nVoiceMove=SCFBYES0,SCFBYES1,SCFBYES2,SCFBYES3`r`nVoiceAttack=SCFBYES0,SCFBYES1,SCFBYES2,SCFBYES3`r`nVoiceDie=SCFBDTH0"
Set-Block $sc @"
; =====================================================================================================================
; SC infantry stim (2026-10-27, user: "zrob moda zeby infantry dalo sie deployowac ... wtedy stim packi zadzialaja").
; TEST units: Marine and Firebat as REAL infantry (Terran Barracks, prone, healed by medics, fit in transports) with a
; stimpack on the D key. Needs the game.exe patch Modding/tools/patch-infdeploy.ps1 (part of patch-game.ps1): infantry
; type X deploys into X_D and back; X -> X_D costs 1/4 of the max HP. Generated by Modding/tools/build-scinfstim.ps1
; (graphics MIX/ECACHE81.MIX). Wiki: Modding/wiki/mods/sc-infantry-stim.md
; =====================================================================================================================
[InfantryTypes]
SCI01=SCMARI
SCI02=SCMARI_D
SCI03=SCFIRI
SCI04=SCFIRI_D
SCI05=SCMEDI

[SCMARI]
Name=Marine (infantry)
Description=StarCraft Terran infantry (TEST: real infantry).@@Gauss rifle, effective against infantry.@@D: Stimpack - costs 1/4 of max health, doubles rate of fire and boosts speed for 30 seconds (D again ends it sooner).
Image=SCMARI
Prerequisite=SCBARR
Primary=SCGauss
Strength=500
TechLevel=1
Sight=6
Speed=8
Cost=200
Points=5
ThreatPosed=10
$marineVoices
$common

[SCMARI_D]
Name=Marine (Stimpack)
Description=Marine on stimpack (30 seconds). D to end it sooner.
Image=SCMARI_D
Prerequisite=SCBARR
Primary=SCGaussS
Strength=500
TechLevel=-1
Sight=6
Speed=11
Cost=200
Points=5
ThreatPosed=12
$marineVoices
$common

[SCFIRI]
Name=Firebat (infantry)
Description=StarCraft Terran flamethrower infantry (TEST: real infantry).@@Strong against infantry and light buildings.@@D: Stimpack - costs 1/4 of max health, doubles rate of fire and boosts speed for 30 seconds (D again ends it sooner).
Image=SCFIRI
Prerequisite=SCBARR,SCACAD
Primary=SCFlamer
Strength=625
TechLevel=2
Sight=6
Speed=8
Cost=400
Points=8
ThreatPosed=15
$fbatVoices
$common

[SCFIRI_D]
Name=Firebat (Stimpack)
Description=Firebat on stimpack (30 seconds). D to end it sooner.
Image=SCFIRI_D
Prerequisite=SCBARR,SCACAD
Primary=SCFlamerS
Strength=625
TechLevel=-1
Sight=6
Speed=11
Cost=400
Points=8
ThreatPosed=18
$fbatVoices
$common

[SCMEDI]
Name=Medic (infantry)
Description=StarCraft Terran combat medic (TEST: real infantry).@@Heals Marines, Firebats and all other infantry. Seeks out units to heal while in guard mode.
Image=SCMEDI
Prerequisite=SCBARR,SCACAD
Primary=SCHealGun
Strength=750
TechLevel=2
Sight=6
Speed=8
Cost=400
Points=8
GuardRange=6
ThreatPosed=0
SpecialThreatValue=1
VoiceSelect=SCMDWHT0,SCMDWHT1,SCMDWHT2,SCMDWHT3
VoiceMove=SCMDYES0,SCMDYES1,SCMDYES2,SCMDYES3
VoiceAttack=SCMDYES0,SCMDYES1,SCMDYES2,SCMDYES3
VoiceDie=SCMDDTH0
$common
"@ "`n"

# stim sounds: the deploy patch plays the Sound.ini entry named like the new type (SCMARI_D, SCFIRI_D) at the soldier,
# so the stimpack sounds like the vehicle Marines' (VoiceDeploy=SCMASTI0,SCMASTI1)
$snd = "$game\INI\Sound.ini"; if (-not (Test-Path "$snd.bak")) { Copy-Item $snd "$snd.bak" }
$sl = [IO.File]::ReadAllText($snd, $latin)
$sl = [regex]::Replace($sl, "(?m)^\d+=SC(MARI|FIRI)_D[^\r\n]*\r?\n", '')     # re-run: drop our old entries
$m = [regex]::Match($sl, "(?ms)^\[SoundList\]\r?\n(.*?)(?=^\[)")
$used = @([regex]::Matches($m.Groups[1].Value, "(?m)^(\d+)=") | ForEach-Object { [int]$_.Groups[1].Value })
$k = ($used | Measure-Object -Maximum).Maximum + 1
$lastLine = [regex]::Matches($m.Groups[1].Value, "(?m)^\d+=[^\r\n]*\r?\n") | Select-Object -Last 1
$insertAt = $m.Groups[1].Index + $lastLine.Index + $lastLine.Length
$sl = $sl.Insert($insertAt, "$k=SCMARI_D`t; SC infantry stim: stimpack sound (build-scinfstim.ps1)`r`n$($k + 1)=SCFIRI_D`r`n")
[IO.File]::WriteAllText($snd, $sl, $latin)
Set-Block $snd @"
; SC infantry stim (Modding/tools/build-scinfstim.ps1): played by the infantry deploy patch when X turns into X_D
[SCMARI_D]
Sounds=SCMASTI0
Priority=20

[SCFIRI_D]
Sounds=SCMASTI1
Priority=20
"@ "`r`n"

# art: one sequence section per unit, shared by X and X_D (identical frame layout, only the colours differ)
$artBody = "; SC infantry stim (Modding/tools/build-scinfstim.ps1): images in MIX/ECACHE81.MIX, 8 facings N,NW,W,SW,S,SE,E,NE.`r`n"
foreach ($u in $units) {
    foreach ($img in @($u.Id) + @(if ($u.Stim) { "$($u.Id)_D" })) {
        $artBody += "`r`n[$img]`r`nCameo=$($u.Id)I`r`nSequence=$($u.Id)Sequence`r`nRemapable=yes`r`nCrawls=no`r`nFireUp=$($u.FireFrame)`r`nFireProne=$($u.FireFrame)`r`nPrimaryFireFLH=$($u.Flh)`r`n"
    }
    $artBody += "`r`n[$($u.Id)Sequence]`r`n" + ($layouts[$u.Id].Sequence() -replace "`n", "`r`n")
}
Set-Block $art $artBody "`r`n"
"installed: StarCraft.ini + Art.ini blocks '$begin'"
