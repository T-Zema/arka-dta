# Zerg units for DTA as real infantry (trained in any barracks), from the user's StarCraft: Remastered install.
#   .\build-sczerg.ps1              -> MIX/ECACHE80.MIX (SHP, cameos, AUD) + preview sheets in -PreviewDir
#   .\build-sczerg.ps1 -Install     -> also writes the "StarCraft Zerg units" blocks into StarCraft.ini, Art.ini, Sound.ini
# INI blocks sit between "; >>> StarCraft Zerg units" and "; <<< StarCraft Zerg units" markers, so re-running replaces them.
# Wiki: Modding/wiki/mods/starcraft-zerg.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\sczerg-preview",
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScBuild.cs", "$tools\ScInfantry.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null
$casc  = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"

$scPal    = [Pal]::ReadWpe($casc.ReadFile('TileSet/jungle.wpe'))
$unitPal  = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$cameoPal = [Pal]::ReadTs($mixes.Read('CAMEO.PAL'))
$w = 0; $h = 0; $tpal = $null
$tunit = [Pal]::ReadPcx($casc.ReadFile('game/tunit.pcx'), [ref]$w, [ref]$h, [ref]$tpal)
$ramp = New-Object 'System.Drawing.Color[]' 8
for ($i = 0; $i -lt 8; $i++) { $ramp[$i] = $tpal[$tunit[$i]] }
$map = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)

# frame sets per unit (GRP set = 17 directions), found on contact sheets of the GRPs (see the wiki page)
# Fire lists = SC iscript ground attack (anim 2) with SC timing: TS plays infantry fire frames at 1 tick each (measured with
# tools/morphprobe.ps1 -TraceInfantry), an SC tick is ~2 TS ticks at 45 FPS, so every SC frame is held twice and the return
# frames are kept. FireFrame = index of the SC ATTACK/melee point. The old 5-frame lists played in 5 ticks and the unit snapped
# back to its stand pose for the rest of the reload: user 2026-10-25 "zacinaja sie". Ultralisk scaled to fit ROF 20.
$units = @(
    @{ Id = 'SCZLING'; Grp = 'zergling'; Shadow = 'zzeshad'; Remains = 'zzedeath'; Stand = 5; Walk = 5..11; Fire = 0, 0, 1, 1, 2, 2, 3, 3, 4, 4
       DeathUnit = 289..295; DeathRemains = 0..4; FireFrame = 4; Flh = '0,0,20' }
    @{ Id = 'SCHYDRA'; Grp = 'hydra'; Shadow = 'zhyshad'; Remains = 'zhydeath'; Stand = 0; Walk = 5..11; Fire = 0, 0, 1, 1, 2, 2, 3, 3, 3, 3, 4, 4, 3, 3, 2, 2, 1, 1, 0, 0
       DeathUnit = @(); DeathRemains = 0, 0, 1, 1, 2, 3; FireFrame = 10; Flh = '40,0,60' }
    @{ Id = 'SCULTRA'; Grp = 'ultra'; Shadow = 'zulshad'; Remains = 'zuldeath'; Stand = 0; Walk = 0..8; Fire = 14, 14, 14, 14, 13, 13, 13, 12, 12, 12, 11, 11, 11, 12, 12, 12, 13, 13, 13
       DeathUnit = 255..264; DeathRemains = 0..4; FireFrame = 7; Flh = '60,0,40' }
    # TEST units (terran-faction session, 2026-10-25, user: "kolejne jednostki naziemne zergow, testowo z barakow").
    # Sets read from SC's iscript.bin (tools/ScIscript.cs Anim(): playfram = set*17+dir). Drone and Defiler have no shadow
    # GRP in SD (SC draws their shadow from the body), so the body doubles as the shadow silhouette.
    @{ Id = 'SCDRONE'; Grp = 'drone'; Shadow = 'drone'; Remains = 'zdrdeath'; Stand = 0; Walk = 0..4; Fire = @(0)
       DeathUnit = 170, 187, 204, 221, 238, 255, 272, 289; DeathRemains = 0..4; FireFrame = 0; Flh = '30,0,40' }
    @{ Id = 'SCBROOD'; Grp = 'brood'; Shadow = 'zbrshad'; Remains = 'zbrdeath'; Stand = 1; Walk = 0..6; Fire = 7, 7, 8, 8, 9, 9, 10, 10, 11, 11
       DeathUnit = @(); DeathRemains = 0..4; FireFrame = 4; Flh = '0,0,10' }
    # SCLURK (infantry Lurker) removed 2026-10-25 at the user's request: the Lurker is the burrowing vehicle of the Zerg faction
    # (SCZLRV/SCZLRB, build-sczergbase.ps1). Its sounds SCLK* stay (used by that Lurker).
    @{ Id = 'SCDEFIL'; Grp = 'defiler'; Shadow = 'defiler'; Remains = 'zdedeath'; Stand = 0; Walk = 0..7; Fire = 0, 0, 0, 1, 1, 1, 2, 2, 2, 1, 1, 1
       DeathUnit = 136, 153, 170, 187; DeathRemains = 0..5; FireFrame = 1; Flh = '30,0,40' }
)

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$layouts = @{}
foreach ($u in $units) {
    $body = [Grp]::Read($casc.ReadFile("unit/zerg/$($u.Grp).grp"))
    $shad = [Grp]::Read($casc.ReadFile("unit/zerg/$($u.Shadow).grp"))
    $rem  = [Grp]::Read($casc.ReadFile("unit/zerg/$($u.Remains).grp"))
    $death = New-Object 'System.Collections.Generic.List[Frame]'
    foreach ($i in $u.DeathUnit) { $death.Add($body.Frames[$i]) }
    foreach ($i in $u.DeathRemains) { $death.Add($rem.Frames[$i]) }
    $lay = $null
    $shp = [ScInfantry]::Build($body, $shad, $map, $u.Stand, [int[]]$u.Walk, [int[]]$u.Fire, $death, [ref]$lay)
    $layouts[$u.Id] = $lay
    $files["$($u.Id).SHP"] = $shp.Write()
    $cameo = [ScInfantry]::Cameo($body.Frames[$u.Stand * 17 + 12], $body.Width, $body.Height, $scPal, $ramp, $cameoPal, [Drawing.Color]::FromArgb(150, 60, 140))
    $files["$($u.Id)I.SHP"] = $cameo.Write()
    "{0}: {1}x{2}, {3} frames (+shadows), walk {4}x{5} @{6}, fire {7}x{8} @{9}, death {10} @{11}" -f $u.Id, $shp.Width, $shp.Height, $lay.Total,
        8, $lay.WalkFrames, $lay.Walk, 8, $lay.FireFrames, $lay.Fire, $lay.DeathFrames, $lay.Death
    # preview: stand (8 facings), walk + fire facing E, death
    $idx = @(0..7) + @(($lay.Walk + 6 * $lay.WalkFrames)..($lay.Walk + 7 * $lay.WalkFrames - 1)) + @(($lay.Fire + 6 * $lay.FireFrames)..($lay.Fire + 7 * $lay.FireFrames - 1)) + @($lay.Death..($lay.Death + $lay.DeathFrames - 1))
    [Pal]::Sheet($shp.Frames, [int[]]$idx, $shp.Width, $shp.Height, $unitPal, 2, 12, "$PreviewDir\$($u.Id).png")
    $both = New-Object 'System.Collections.Generic.List[Frame]'; $both.Add($cameo.Frames[0])
    [Pal]::Sheet($both, [int[]]@(0), 64, 48, $cameoPal, 3, 1, "$PreviewDir\$($u.Id)_cameo.png")
}

# Infested Terran is a SHP VEHICLE (like the Marines), built in the War Factory: Vinifera's Suicide=yes kills the firer
# inside TechnoClass::Fire_At (hook 0x0063039B) and lets the shot go on; infantry then crash in InfantryClass::AI
# (null target after Ready_To_Commence, user test 2026-10-25), units cope with it (DTA's DTRK).
$bug  = [Grp]::Read($casc.ReadFile('unit/zerg/bugguy.grp'))
$bugS = [Grp]::Read($casc.ReadFile('unit/zerg/zbgshad.grp'))
$inft = [ScBuild]::BuildUnit($bug, $bugS, $map, [int[]](0..7), 0, 0)   # stand 0-31, walk 32-287 (8 per facing), fire 288-351
$files['SCINFT.SHP'] = $inft.Write()
$cameo = [ScInfantry]::Cameo($bug.Frames[12], $bug.Width, $bug.Height, $scPal, $ramp, $cameoPal, [Drawing.Color]::FromArgb(150, 60, 140))
$files['SCINFTI.SHP'] = $cameo.Write()
"SCINFT (vehicle): $($inft.Width)x$($inft.Height), $($inft.Frames.Count / 2) frames (+shadows)"
[Pal]::Sheet($inft.Frames, [int[]](@(0, 4, 8, 12, 16, 20, 24, 28) + @(96..103) + @(304, 305)), $inft.Width, $inft.Height, $unitPal, 2, 12, "$PreviewDir\SCINFT.png")

# sounds (SD WAV 22 050 Hz mono -> AUD)
$sounds = [ordered]@{
    SCZLWHT0 = 'zerg/zergling/zzewht00'; SCZLWHT1 = 'zerg/zergling/zzewht01'; SCZLWHT2 = 'zerg/zergling/zzewht02'; SCZLWHT3 = 'zerg/zergling/zzewht03'
    SCZLYES0 = 'zerg/zergling/zzeyes00'; SCZLYES1 = 'zerg/zergling/zzeyes01'; SCZLYES2 = 'zerg/zergling/zzeyes02'; SCZLYES3 = 'zerg/zergling/zzeyes03'
    SCZLDTH0 = 'zerg/zergling/zzedth00'; SCZLATK  = 'zerg/ultra/zulhit00'   # SC iscript: Zergling attackmelee = zulHit00 (was bullet/zdrhit00)
    SCHYWHT0 = 'zerg/hydra/zhywht00'; SCHYWHT1 = 'zerg/hydra/zhywht01'; SCHYWHT2 = 'zerg/hydra/zhywht02'
    SCHYYES0 = 'zerg/hydra/zhyyes00'; SCHYYES1 = 'zerg/hydra/zhyyes01'; SCHYYES2 = 'zerg/hydra/zhyyes02'; SCHYYES3 = 'zerg/hydra/zhyyes03'
    SCHYDTH0 = 'zerg/hydra/zhydth00'; SCHYFIRE = 'bullet/spooghit'   # SC iscript: Hydralisk attack playsnd = SpoogHit (was bullet/zhyfir00)
    SCULWHT0 = 'zerg/ultra/zulwht00'; SCULWHT1 = 'zerg/ultra/zulwht01'; SCULWHT2 = 'zerg/ultra/zulwht02'; SCULWHT3 = 'zerg/ultra/zulwht03'
    SCULYES0 = 'zerg/ultra/zulyes00'; SCULYES1 = 'zerg/ultra/zulyes01'; SCULYES2 = 'zerg/ultra/zulyes02'; SCULYES3 = 'zerg/ultra/zulyes03'
    SCULDTH0 = 'zerg/ultra/zuldth00'; SCULATK0 = 'zerg/ultra/zulatt00'; SCULATK1 = 'zerg/ultra/zulatt01'; SCULATK2 = 'zerg/ultra/zulatt02'
    SCULHIT0 = 'zerg/ultra/zulhit00'; SCULHIT1 = 'zerg/ultra/zulhit01'   # SC iscript: Ultralisk attackmelee hit sounds
    # TEST units. Attack sounds from SC iscript: Drone and Lurker = Bullet\SpoogHit (= SCHYFIRE), Broodling attackmelee =
    # zbrAtt00, Infested Terran = Bullet\ZBGHit00 (its death/explosion), Defiler = Bullet\zdeAtt00. Lurker files are mixed-case in CASC.
    SCDNWHT0 = 'zerg/drone/zdrwht00'; SCDNWHT1 = 'zerg/drone/zdrwht01'; SCDNWHT2 = 'zerg/drone/zdrwht02'; SCDNWHT3 = 'zerg/drone/zdrwht03'; SCDNWHT4 = 'zerg/drone/zdrwht04'
    SCDNYES0 = 'zerg/drone/zdryes00'; SCDNYES1 = 'zerg/drone/zdryes01'; SCDNYES2 = 'zerg/drone/zdryes02'; SCDNYES3 = 'zerg/drone/zdryes03'; SCDNYES4 = 'zerg/drone/zdryes04'
    SCDNDTH0 = 'zerg/drone/zdrdth00'
    SCBLWHT0 = 'zerg/broodling/zbrwht00'; SCBLWHT1 = 'zerg/broodling/zbrwht01'; SCBLWHT2 = 'zerg/broodling/zbrwht02'; SCBLWHT3 = 'zerg/broodling/zbrwht03'
    SCBLYES0 = 'zerg/broodling/zbryes00'; SCBLYES1 = 'zerg/broodling/zbryes01'; SCBLYES2 = 'zerg/broodling/zbryes02'; SCBLYES3 = 'zerg/broodling/zbryes03'
    SCBLDTH0 = 'zerg/broodling/zbrdth00'; SCBLATK = 'zerg/broodling/zbratt00'
    SCITWHT0 = 'zerg/bugguy/zbgwht00'; SCITWHT1 = 'zerg/bugguy/zbgwht01'; SCITWHT2 = 'zerg/bugguy/zbgwht02'; SCITWHT3 = 'zerg/bugguy/zbgwht03'
    SCITYES0 = 'zerg/bugguy/zbgyes00'; SCITYES1 = 'zerg/bugguy/zbgyes01'; SCITYES2 = 'zerg/bugguy/zbgyes02'; SCITYES3 = 'zerg/bugguy/zbgyes03'
    SCITBOOM = 'bullet/zbghit00'
    SCLKWHT0 = 'zerg/lurker/ZLuWht00'; SCLKWHT1 = 'zerg/lurker/ZLuWht01'; SCLKWHT2 = 'zerg/lurker/ZLuWht02'; SCLKWHT3 = 'zerg/lurker/ZLuWht03'
    SCLKYES0 = 'zerg/lurker/ZLuYes00'; SCLKYES1 = 'zerg/lurker/ZLuYes01'; SCLKYES2 = 'zerg/lurker/ZLuYes02'; SCLKYES3 = 'zerg/lurker/ZLuYes03'
    SCLKDTH0 = 'zerg/lurker/ZLuDth00'
    SCDFWHT0 = 'zerg/defiler/zdewht00'; SCDFWHT1 = 'zerg/defiler/zdewht01'; SCDFWHT2 = 'zerg/defiler/zdewht02'; SCDFWHT3 = 'zerg/defiler/zdewht03'
    SCDFYES0 = 'zerg/defiler/zdeyes00'; SCDFYES1 = 'zerg/defiler/zdeyes01'; SCDFYES2 = 'zerg/defiler/zdeyes02'; SCDFYES3 = 'zerg/defiler/zdeyes03'
    SCDFDTH0 = 'zerg/defiler/zdedth00'; SCDFATK = 'bullet/zdeatt00'
}
foreach ($k in $sounds.Keys) {
    $rate = 0
    $pcm = [Aud]::ReadWav($casc.ReadFile("SD/sound/$($sounds[$k]).wav"), [ref]$rate)
    $files["$k.AUD"] = [Aud]::Encode($pcm, $rate, 1.0)
}
[Mix]::Write("$game\MIX\ECACHE80.MIX", $files)
"ECACHE80.MIX: $($files.Count) files, $([Math]::Round((Get-Item "$game\MIX\ECACHE80.MIX").Length / 1KB)) KB; previews -> $PreviewDir"
if (-not $Install) { return }

# ------------------------------------------------------------------ INI blocks
$latin = [Text.Encoding]::GetEncoding(28591)
$begin = '; >>> StarCraft Zerg units'; $end = '; <<< StarCraft Zerg units'

function Set-Block([string]$path, [string]$body, [string]$nl) {
    $t = [IO.File]::ReadAllText($path, $latin)
    $block = ($begin + $nl + ($body.TrimEnd() -replace "`r?`n", $nl) + $nl + $end + $nl)
    $a = $t.IndexOf($begin)
    if ($a -ge 0) { $b = $t.IndexOf($end, $a); $b = $t.IndexOf("`n", $b) + 1; $t = $t.Substring(0, $a) + $block + $t.Substring($b) }
    else { if (-not $t.EndsWith("`n")) { $t += $nl }; $t += $nl + $block }
    [IO.File]::WriteAllText($path, $t, $latin)
}

# entries inside an existing list section, after its last key line; old entries matching $own are removed first
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

$sc = "$game\INI\Game Options\StarCraft.ini"; $art = "$game\INI\Art.ini"; $snd = "$game\INI\Sound.ini"

Set-SectionEntries $sc 'InfantryTypes' @('SCZ01=SCZLING	; StarCraft Zerg units block (end of file)', 'SCZ02=SCHYDRA', 'SCZ03=SCULTRA',
    'SCZ04=SCDRONE	; TEST units from here on', 'SCZ05=SCBROOD', 'SCZ08=SCDEFIL') '^SCZ\d+=' "`n"
Set-SectionEntries $sc 'VehicleTypes' @('SCZV01=SCINFT	; StarCraft Zerg units block: Infested Terran is a vehicle (Suicide crashes infantry)') '^SCZV\d+=' "`n"

$owner = 'GDI1'   # SC factions only (user 2026-10-25): GDI1 = Terran. The Zerg faction (Nod1) has its own copies with SC prerequisites (build-sczergbase.ps1)
$common = @"
Category=Soldier
Locomotor={4A582744-9839-11d1-B709-00A024DDAFD1}
MovementZone=Infantry
Armor=none
Owner=$owner
Fearless=yes
NotHuman=yes
Crushable=no
SelfHealing=yes
Crewed=no
Trainable=yes
PhysicalSize=1
AllowedToStartInMultiplayer=no
IsWebImmune=true
ImmuneToVeins=yes
VeteranAbilities=STRONGER,FASTER
EliteAbilities=SELF_HEAL,ROF
VoiceFeedback=
"@
Set-Block $sc @"
; =====================================================================================================================
; StarCraft Zerg units (map session, 2026-10-25; user: "dodaj do barakow zergi"). Real INFANTRY, so every barracks in
; [General] PrerequisiteBarracks (incl. SCBARR) trains them. Registered at the top: [InfantryTypes] SCZ01+,
; [VehicleTypes] SCZV01 (Infested Terran: Suicide=yes only works on vehicles, built in the War Factory).
; Graphics + sounds: MIX/ECACHE80.MIX (Modding/tools/build-sczerg.ps1); sequences: Art.ini block of the same name;
; sounds: Sound.ini [SoundList] 950+. Scale like the Terran blocks: HP = SC HP x 20, cost = (minerals + 2 x gas) x 4.
; Zerg regenerate (SelfHealing) and never go prone. Wiki: Modding/wiki/mods/starcraft-zerg.md
; =====================================================================================================================

[SCZLING]
Name=Zergling
Description=Zerg swarm beast.@@Very fast, very cheap. Claws hurt infantry, vehicles and buildings alike.@@Regenerates.
Prerequisite=BARRACKS
Primary=SCZClaw
Strength=700
TechLevel=1
Sight=5
Speed=12
Cost=100
Points=2
ThreatPosed=5
VoiceSelect=SCZLWHT0,SCZLWHT1,SCZLWHT2,SCZLWHT3
VoiceMove=SCZLYES0,SCZLYES1,SCZLYES2,SCZLYES3
VoiceAttack=SCZLYES0,SCZLYES1,SCZLYES2,SCZLYES3
VoiceDie=SCZLDTH0
$common

[SCHYDRA]
Name=Hydralisk
Description=Zerg ranged attacker.@@Needle spines hit ground and air targets and pierce armor.@@Regenerates.
Prerequisite=BARRACKS
Primary=SCNeedleSpine
Strength=1600
TechLevel=2
Sight=8
Speed=6	; user 2026-10-25: 30% slower (was 8)
Cost=500
Points=8
ThreatPosed=15
VoiceSelect=SCHYWHT0,SCHYWHT1,SCHYWHT2
VoiceMove=SCHYYES0,SCHYYES1,SCHYYES2,SCHYYES3
VoiceAttack=SCHYYES0,SCHYYES1,SCHYYES2,SCHYYES3
VoiceDie=SCHYDTH0
$common

[SCULTRA]
Name=Ultralisk
Description=Huge Zerg assault beast.@@Kaiser blades shred everything in melee. Heavily armored.@@Regenerates. Needs a Tech Center.
Prerequisite=BARRACKS,TECH
Primary=SCKaiserBlade
Strength=10000
TechLevel=6
Sight=6
Speed=10
Cost=2400
Points=40
ThreatPosed=40
VoiceSelect=SCULWHT0,SCULWHT1,SCULWHT2,SCULWHT3
VoiceMove=SCULYES0,SCULYES1,SCULYES2,SCULYES3
VoiceAttack=SCULYES0,SCULYES1,SCULYES2,SCULYES3
VoiceDie=SCULDTH0
$($common -replace 'Armor=none', 'Armor=heavy')

; ---------------------------------------------------------------- Zerg weapons (damage x Modifier; listed armors x10 like SA)
[SCZClaw]
Damage=13
ROF=11
Range=1.75
Projectile=Invisible
Speed=100
Warhead=SCZClawWH
Report=SCZLATK

; SC "normal" damage: hurts every armor about the same
[SCZClawWH]
CellSpread=0
Modifier.none=1000%
Modifier.wood=600%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
InfDeath=1
AnimList=PIFF
ProneDamage=100%

[SCNeedleSpine]
Damage=33
ROF=20
Range=7.8
Projectile=Invisible3
Speed=100
Warhead=SCSpineWH
Report=SCHYFIRE

; SC "explosive" damage: better against armor than against infantry
[SCSpineWH]
CellSpread=0
Modifier.none=600%
Modifier.wood=700%
Modifier.medium=900%
Modifier.heavy=1000%
Modifier.concrete=500%
InfDeath=1
AnimList=PIFFPIFF
ProneDamage=100%

[SCKaiserBlade]
Damage=120
ROF=20
Range=2.5
Projectile=Invisible
Speed=100
Warhead=SCKaiserWH
Report=SCULHIT0,SCULHIT1

; Kaiser Blades sweep: SC "normal" damage like SCZClawWH plus a cleave splash (user request, 2026-10-25).
; AffectsAllies=no (Vinifera): the splash spares own and allied units, e.g. the Zerglings around the Ultralisk.
[SCKaiserWH]
CellSpread=1
PercentAtMax=0.5
AffectsAllies=no
Modifier.none=1000%
Modifier.wood=600%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
InfDeath=1
AnimList=PIFF
ProneDamage=100%

; ---------------------------------------------------------------- TEST units (terran-faction session, 2026-10-25)
; Same scale as above: HP = SC HP x 20, cost = (minerals + 2 x gas) x 4, damage about SC x 2.5, ROF about SC cooldown x 1.33.

[SCDRONE]
Name=Drone
Description=Zerg worker (TEST: cannot harvest, harvesters must be vehicles).@@Weak acid spit. Cheap.@@Regenerates.
Prerequisite=BARRACKS
Primary=SCDroneSpit
Strength=800
TechLevel=1
Sight=7
Speed=9
Cost=200
Points=3
ThreatPosed=3
VoiceSelect=SCDNWHT0,SCDNWHT1,SCDNWHT2,SCDNWHT3,SCDNWHT4
VoiceMove=SCDNYES0,SCDNYES1,SCDNYES2,SCDNYES3,SCDNYES4
VoiceAttack=SCDNYES0,SCDNYES1,SCDNYES2,SCDNYES3,SCDNYES4
VoiceDie=SCDNDTH0
$common

[SCBROOD]
Name=Broodling
Description=Tiny Zerg swarm creature (TEST).@@Very fast melee biter, very cheap.@@Regenerates.
Prerequisite=BARRACKS
Primary=SCBroodBite
Strength=600
TechLevel=2
Sight=5
Speed=12
Cost=75
Points=1
ThreatPosed=3
VoiceSelect=SCBLWHT0,SCBLWHT1,SCBLWHT2,SCBLWHT3
VoiceMove=SCBLYES0,SCBLYES1,SCBLYES2,SCBLYES3
VoiceAttack=SCBLYES0,SCBLYES1,SCBLYES2,SCBLYES3
VoiceDie=SCBLDTH0
$common

; a SHP VEHICLE built in the War Factory (map session fix 2026-10-25): Suicide=yes on infantry crashed the game
[SCINFT]
Name=Infested Terran
Description=Zerg suicide bomber (TEST).@@Runs into the target and explodes, hurting everything around it.@@Built in the War Factory.
Prerequisite=BARRACKS,RADAR
Primary=SCInfestBlast
Strength=1200
Armor=none
Category=AFV
TechLevel=4
Sight=6
Speed=7
ROT=10
Owner=$owner
Cost=800
Points=10
Crusher=no
Crewed=no
Explosion=FBALL1
ScrapExplosion=FBALL1
MaxDebris=0
VoiceSelect=SCITWHT0,SCITWHT1,SCITWHT2,SCITWHT3
VoiceMove=SCITYES0,SCITYES1,SCITYES2,SCITYES3
VoiceAttack=SCITYES0,SCITYES1,SCITYES2,SCITYES3
VoiceFeedback=
SpeedType=Track
Locomotor={4A582741-9839-11d1-B709-00A024DDAFD1}
MovementZone=Normal
SlowdownDistance=1
AccelerationFactor=1
Weight=1
ThreatPosed=20
SelfHealing=yes
Trainable=yes
VeteranAbilities=STRONGER,FASTER
EliteAbilities=SELF_HEAL,ROF
AllowedToStartInMultiplayer=no
CanShakeScreen=false
Totable=false

[SCDEFIL]
Name=Defiler
Description=Zerg spellcaster (TEST).@@Spits Plague: acid that hurts everything in a small area.@@Regenerates. Needs a Tech Center.
Prerequisite=BARRACKS,TECH
Primary=SCPlague
Strength=1600
TechLevel=6
Sight=8
Speed=7
Cost=1400
Points=20
ThreatPosed=20
VoiceSelect=SCDFWHT0,SCDFWHT1,SCDFWHT2,SCDFWHT3
VoiceMove=SCDFYES0,SCDFYES1,SCDFYES2,SCDFYES3
VoiceAttack=SCDFYES0,SCDFYES1,SCDFYES2,SCDFYES3
VoiceDie=SCDFDTH0
$common

; SC Drone "Spines": 5 dmg, cooldown 22, range 1 cell; SC plays Bullet\SpoogHit
[SCDroneSpit]
Damage=13
ROF=29
Range=1.75
Projectile=Invisible
Speed=100
Warhead=SCZClawWH
Report=SCHYFIRE

; SC Broodling "Toxic Spores": 4 dmg, cooldown 15, melee
[SCBroodBite]
Damage=10
ROF=20
Range=1.93
Projectile=Invisible
Speed=100
Warhead=SCZClawWH
Report=SCBLATK

; SC Infested Terran: 500 dmg suicide, splash 20/40/60 px (Vinifera Suicide=yes: the unit dies when it fires).
; Suicide=yes ONLY on vehicles: on infantry it crashes InfantryClass::AI. Range 1.5: a vehicle cannot enter the target's cell.
[SCInfestBlast]
Damage=800
ROF=10
Range=1.5
Projectile=Invisible
Speed=100
Warhead=SCInfestWH
Report=SCITBOOM
Suicide=yes

[SCInfestWH]
CellSpread=2
PercentAtMax=0.3
Modifier.none=600%
Modifier.wood=700%
Modifier.medium=900%
Modifier.heavy=1000%
Modifier.concrete=500%
Wall=yes
Wood=yes
InfDeath=2
AnimList=FBALL1
ProneDamage=100%
Conventional=yes

; SC Lurker "Subterranean Spines": 20 dmg, cooldown 37, range 6 cells, line splash (here: round splash)
[SCLurkerSpine]
Damage=50
ROF=50
Range=8.5
Projectile=Invisible
Speed=100
Warhead=SCLurkerWH
Report=SCHYFIRE

[SCLurkerWH]
CellSpread=1
PercentAtMax=0.5
Modifier.none=1000%
Modifier.wood=600%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
InfDeath=1
AnimList=PIFFPIFF
ProneDamage=100%

; Defiler "Plague" (SC: spell, damage over time) as a slow area acid spit; same damage on every armor
[SCPlague]
Damage=30
ROF=60
Range=5
Projectile=Invisible
Speed=100
Warhead=SCPlagueWH
Report=SCDFATK

[SCPlagueWH]
CellSpread=1.5
PercentAtMax=0.6
Modifier.none=800%
Modifier.wood=800%
Modifier.medium=800%
Modifier.heavy=800%
Modifier.concrete=800%
InfDeath=1
AnimList=PIFFPIFF
ProneDamage=100%
"@ "`n"

$artBody = "; StarCraft Zerg units (map session, 2026-10-25): infantry SHP from Modding/tools/build-sczerg.ps1 (MIX/ECACHE80.MIX),`r`n" +
           "; 8 facings N,NW,W,SW,S,SE,E,NE; frame layout in the sequence sections below.`r`n"
foreach ($u in $units) {
    $lay = $layouts[$u.Id]
    $artBody += "`r`n[$($u.Id)]`r`nCameo=$($u.Id)I`r`nSequence=$($u.Id)Sequence`r`nRemapable=yes`r`nCrawls=no`r`nFireUp=$($u.FireFrame)`r`nFireProne=$($u.FireFrame)`r`nPrimaryFireFLH=$($u.Flh)`r`n"
    $artBody += "`r`n[$($u.Id)Sequence]`r`n" + ($lay.Sequence() -replace "`n", "`r`n")
}
$artBody += "`r`n; Infested Terran is a SHP vehicle (32 facings, layout like SCMARINE)`r`n[SCINFT]`r`nCameo=SCINFTI`r`nVoxel=no`r`nRemapable=yes`r`nFacings=32`r`n" +
            "StartStandFrame=0`r`nStandingFrames=1`r`nStartWalkFrame=32`r`nWalkFrames=8`r`nStartFiringFrame=288`r`nFiringFrames=2`r`nFiringSyncFrame0=1`r`nPrimaryFireFLH=20,0,20`r`n"
Set-Block $art $artBody "`r`n"

# Zerg sounds live at 1100+ (950-997 is too small; 998/999 are DTA's DUMMY/BOOP). The regex also removes the old 950-982 entries.
$n = 1100; $list = @()
foreach ($k in $sounds.Keys) { $list += "$n=$k"; $n++ }
Set-SectionEntries $snd 'SoundList' $list '^(9[5-9]\d|1[1-9]\d\d)=SC(ZL|HY|UL|DN|BL|IT|LK|DF)' "`r`n"
$sndBody = "; StarCraft Zerg units (map session): louder death screams, many zerglings at once`r`n"
foreach ($k in 'SCZLDTH0', 'SCHYDTH0', 'SCULDTH0') { $sndBody += "`r`n[$k]`r`nPriority=40`r`nRange=14`r`nLimit=4`r`n" }
$sndBody += "`r`n[SCZLATK]`r`nLimit=6`r`n"
foreach ($k in 'SCDNDTH0', 'SCBLDTH0', 'SCLKDTH0', 'SCDFDTH0') { $sndBody += "`r`n[$k]`r`nPriority=40`r`nRange=14`r`nLimit=4`r`n" }
$sndBody += "`r`n[SCITBOOM]`r`nPriority=60`r`nRange=18`r`nLimit=6`r`n`r`n[SCBLATK]`r`nLimit=6`r`n"
Set-Block $snd $sndBody "`r`n"
"INI blocks written: StarCraft.ini, Art.ini, Sound.ini ([SoundList] 1100-$($n - 1))"
