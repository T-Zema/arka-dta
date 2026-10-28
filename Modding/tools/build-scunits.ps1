# Builds the StarCraft Terran UNITS (all except the Marine) for DTA from the user's StarCraft: Remastered install.
# Output: -OutMix (default <game>\MIX\ECACHE97.MIX: SHPs, cameos, death anims, AUDs) and preview PNGs in -PreviewDir.
# Rules/Art/Sound for these files: block "StarCraft Terran units" in INI/Game Options/StarCraft.ini, INI/Art.ini, INI/Sound.ini.
# Marine: build-scmarine.ps1 (ECACHE77, other session). Buildings + construction tank: build-scterran.ps1 (ECACHE98).
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\scunits-preview",
    [string]$OutMix = ""
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $OutMix) { $OutMix = "$game\MIX\ECACHE97.MIX" }
Add-Type -Path "$tools\Casc.cs","$tools\ModTools.cs","$tools\ScBuild.cs","$tools\ScBuildings.cs","$tools\ScUnits.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null

$casc  = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"

# --- palettes (same as build-scmarine.ps1)
$scPal    = [Pal]::ReadWpe($casc.ReadFile('TileSet/jungle.wpe'))
$unitPal  = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$cameoPal = [Pal]::ReadTs($mixes.Read('CAMEO.PAL'))
$w = 0; $h = 0; $tpal = $null
$tunit = [Pal]::ReadPcx($casc.ReadFile('game/tunit.pcx'), [ref]$w, [ref]$h, [ref]$tpal)
$ramp = New-Object 'System.Drawing.Color[]' 8
for ($i = 0; $i -lt 8; $i++) { $ramp[$i] = $tpal[$tunit[$i]] }
$map     = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)
$mapStim = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0.35)   # stimpack: red tint
$mapAnim = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $false, 0)     # death anims: fixed colours
$ident   = [ScVehicle]::Identity()
# muzzle flashes: SC draws them through the remap table ofire.pcx (row = GRP index - 1, column = background);
# baked here over a black background, too-dark pixels dropped
$w = 0; $h = 0; $opal = $null
$ofire = [Pal]::ReadPcx($casc.ReadFile('TileSet/jungle/ofire.pcx'), [ref]$w, [ref]$h, [ref]$opal)
$mapFire = New-Object byte[] 256
for ($i = 1; $i -lt 64; $i++) { $c = $scPal[$ofire[($i - 1) * 256]]; if ([Math]::Max($c.R, [Math]::Max($c.G, $c.B)) -ge 40) { $mapFire[$i] = [Pal]::Nearest($c, $unitPal, 32, 254) } }

$grpCache = @{}
function G($name) {
    $path = if ($name -like '*/*') { "unit/$name.grp" } else { "unit/terran/$name.grp" }   # 'thingy/esifire' = other folders
    if (-not $grpCache.ContainsKey($name)) { $grpCache[$name] = [Grp]::Read($casc.ReadFile($path)) }
    return $grpCache[$name]
}
function Lo($name) { return ,([ScVehicle]::ReadLo($casc.ReadFile("unit/terran/$name"))) }   # ',' keeps int[][] intact
# Centre of a turret mount over all 32 DTA facings (mirrored for the west side): the TS turret is drawn at one offset.
function LoMean($lo, $set) {
    $sx = 0; $sy = 0
    for ($f = 0; $f -lt 32; $f++) { $m = $false; $d = [ScBuild]::ScDir($f, [ref]$m); $o = $lo[$set * 17 + $d]; $sx += $(if ($m) { -$o[0] } else { $o[0] }); $sy += $o[1] }
    return @([int][Math]::Round($sx / 32), [int][Math]::Round($sy / 32))
}

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$cameoFrames = New-Object 'System.Collections.Generic.List[Frame]'
function Cameo($id, [scriptblock]$compose, $cw, $ch) {
    $ub = New-Object UnitBuilder $cw, $ch, $ident
    $f = & $compose $ub
    $layers = New-Object 'System.Collections.Generic.List[ScLayer]'
    $layers.Add((New-Object ScLayer ([ScUnits]::AsGrp($f, $cw, $ch)), 0, $false))
    $c = [ScBuildings]::Cameo($layers, $scPal, $ramp, $cameoPal)
    $files["${id}I.SHP"] = $c.Write()
    $cameoFrames.Add($c.Frames[0])
}
function Save($id, $shp, [int[]]$preview) {
    $files["$id.SHP"] = $shp.Write()
    [Pal]::Sheet($shp.Frames, $preview, $shp.Width, $shp.Height, $unitPal, 2, [Math]::Min(16, $preview.Length), "$PreviewDir\$id.png")
    "{0,-8} {1,4} frames {2}x{3}" -f $id, $shp.Frames.Count, $shp.Width, $shp.Height
}
$prev8 = [int[]](0,4,8,12,16,20,24,28)

# ---------------------------------------------------------------- infantry-like (SHP vehicles, marine layout)
# stand 0-31, walk 32.. (W per facing), fire 2 per facing (flash, aim), shadows in the 2nd half. Same as SCMARINE.
$fire  = [ScBuild]::BuildUnit((G 'firebat'), (G 'tfbshad'), $map,     [int[]](2..9), 1, 1)
$fireS = [ScBuild]::BuildUnit((G 'firebat'), (G 'tfbshad'), $mapStim, [int[]](2..9), 1, 1)
Save 'SCFIRE' $fire ($prev8 + 32,33,34 + 288,289)
Save 'SCFIRES' $fireS $prev8
Cameo 'SCFIRE' { param($u) $u.Layer($u.New(), (G 'firebat'), 0, 11, $true, $null, 0, 0, $false) } 32 32

$ghost = [ScBuild]::BuildUnit((G 'ghost'), (G 'tghshad'), $map, [int[]](1..9), 11, 12)
Save 'SCGHOST' $ghost ($prev8 + 32,33,34 + 320,321)
Cameo 'SCGHOST' { param($u) $u.Layer($u.New(), (G 'ghost'), 0, 11, $true, $null, 0, 0, $false) } 64 64

$medic = [ScBuild]::BuildUnit((G 'medic'), (G 'tmeshad'), $map, [int[]](6..12), 4, 5)
Save 'SCMEDIC' $medic ($prev8 + 32,33,34 + 256,257)
Cameo 'SCMEDIC' { param($u) $u.Layer($u.New(), (G 'medic'), 0, 11, $true, $null, 0, 0, $false) } 64 64

# death anims with remains (Ghost, Medic); the other units use DTA explosions with an SC death sound (Art.ini)
$gd = New-Object 'System.Collections.Generic.List[Frame]'
foreach ($i in 221..228) { $gd.Add((G 'ghost').Frames[$i]) }; foreach ($f in (G 'tghdeath').Frames) { $gd.Add($f) }
Save 'SCGHDTH' ([ScBuild]::BuildAnim($gd, 64, 64, $mapAnim)) ([int[]](0..10))
$md = New-Object 'System.Collections.Generic.List[Frame]'
foreach ($i in 221..229) { $md.Add((G 'medic').Frames[$i]) }; foreach ($f in (G 'tmeDeath').Frames) { $md.Add($f) }
Save 'SCMEDTH' ([ScBuild]::BuildAnim($md, 64, 64, $mapAnim)) ([int[]](0..12))

# ---------------------------------------------------------------- simple vehicles: one frame per facing
function Simple($id, $grp, $shadowGrp, $sdx, $sdy, $cw, $ch, $m) {
    $u = New-Object UnitBuilder $cw, $ch, $m
    for ($f = 0; $f -lt 32; $f++) {
        $b = $u.Layer($u.New(), (G $grp), 0, $f, $true, $null, 0, 0, $false)
        $s = if ($shadowGrp) { $u.Layer($u.New(), (G $shadowGrp), 0, $f, $true, $null, 0, 0, $true) } else { $u.Silhouette($b, $sdx, $sdy) }
        $u.Add($b, $s)
    }
    Save $id $u.ToShp() ($prev8 + 32,40)
    Cameo $id { param($c) $c.Layer($c.New(), (G $grp), 0, 11, $true, $null, 0, 0, $false) } $cw $ch
}
Simple 'SCSCV'  'scv'      $null 0 5  72  72 $map
Simple 'SCVULT' 'vulture'  $null 0 5  100 100 $map
Simple 'SCDROP' 'dropship' $null 0 0  60  60 $map

# ---------------------------------------------------------------- warships = jumpjet INFANTRY (they hover instead of landing)
# TS infantry SHP: 8 facings counter-clockwise from north, one frame each (Art sequence SCJJSequence), shadows 8-15.
function JJ($id, [scriptblock]$draw, $cw, $ch) {
    $u = New-Object UnitBuilder $cw, $ch, $map
    for ($i = 0; $i -lt 8; $i++) { $b = & $draw $u ([ScUnits]::InfantryFacing32($i)); $u.Add($b, $u.Silhouette($b, 0, 0)) }
    Save $id $u.ToShp() ([int[]](0..7))
}
JJ 'SCWRAI' { param($u, $f) $u.Layer($u.New(), (G 'phoenix'), 0, $f, $true, $null, 0, 0, $false) } 64 64
JJ 'SCVALK' { param($u, $f) $u.Layer($u.New(), (G 'bomber'), 0, $f, $true, $null, 0, 0, $false) } 128 128
JJ 'SCBC'   { param($u, $f) $u.Layer($u.New(), (G 'battlecr'), 0, $f, $true, $null, 0, 0, $false) } 120 120
Cameo 'SCWRAI' { param($c) $c.Layer($c.New(), (G 'phoenix'), 0, 11, $true, $null, 0, 0, $false) } 64 64
Cameo 'SCVALK' { param($c) $c.Layer($c.New(), (G 'bomber'), 0, 11, $true, $null, 0, 0, $false) } 128 128
Cameo 'SCBC'   { param($c) $c.Layer($c.New(), (G 'battlecr'), 0, 11, $true, $null, 0, 0, $false) } 120 120

# Science Vessel: round base (one frame) + rotating dish baked in, at the base's .lol mount
$vLo = Lo 'wessel.lol'
JJ 'SCVESS' { param($u, $f) $x = $u.Layer($u.New(), (G 'wessel'), 0, $f, $false, $null, 0, 0, $false); $u.Layer($x, (G 'wesselt'), 0, $f, $true, $null, $vLo[0][0], $vLo[0][1], $false) } 100 128
Cameo 'SCVESS' { param($c) $x = $c.Layer($c.New(), (G 'wessel'), 0, 11, $false, $null, 0, 0, $false); $c.Layer($x, (G 'wesselt'), 0, 11, $true, $null, $vLo[0][0], $vLo[0][1], $false) } 100 128

# ---------------------------------------------------------------- turret vehicles (TS Turret=yes, Vinifera StartTurretFrame)
# Siege Tank, tank mode: body stand 0-31, walk 32-127 (3 track phases), turret 128-159, shadows 160-319.
$tLo = Lo 'tank.lol'; $tC = LoMean $tLo 0
$sLo = Lo 'stank.lol'
function TankMode($id, $m) {
    $u = New-Object UnitBuilder 128, 128, $m
    for ($f = 0; $f -lt 32; $f++) { $u.Add($u.Layer($u.New(), (G 'tank'), 0, $f, $true, $null, 0, 0, $false), $u.Layer($u.New(), (G 'ttashad'), 0, $f, $true, $null, 0, 0, $true)) }
    for ($f = 0; $f -lt 32; $f++) { foreach ($k in 0..2) { $u.Add($u.Layer($u.New(), (G 'tank'), $k, $f, $true, $null, 0, 0, $false), $u.Layer($u.New(), (G 'ttashad'), $k, $f, $true, $null, 0, 0, $true)) } }
    for ($f = 0; $f -lt 32; $f++) { $u.Add($u.Layer($u.New(), (G 'tankt'), 0, $f, $true, $null, $tC[0], $tC[1], $false), $null) }
    Save $id $u.ToShp() ([int[]](0,8,16,24,32,33,34,128,132,136,140,144))
}
# Siege mode: deployed body (stank frame 5, does not rotate) x32, siege turret 32-63, shadows 64-127.
# stankt.grp: frames 0-16 = siege cannon in 17 directions, 17-101 = deploy transition (facing south-east only).
function SiegeMode($id, $m) {
    $u = New-Object UnitBuilder 128, 128, $m
    for ($f = 0; $f -lt 32; $f++) { $u.Add($u.Layer($u.New(), (G 'stank'), 5, $f, $false, $null, 0, 0, $false), $u.Layer($u.New(), (G 'tstshad'), 5, $f, $false, $null, 0, 0, $true)) }
    # the body does not turn, so the mount must not flip with the cannon (LayerAt negates dx when mirroring)
    for ($f = 0; $f -lt 32; $f++) { $mi = $false; $d = [ScBuild]::ScDir($f, [ref]$mi); $u.Add($u.LayerAt($u.New(), (G 'stankt'), $d, $mi, $(if ($mi) { -1 } else { 1 }) * $sLo[5][0], $sLo[5][1], $false), $null) }
    Save $id $u.ToShp() ([int[]](0,32,36,40,44,48,52,56,60))
}
TankMode 'SCSIEGE' $map
SiegeMode 'SCSIEGS' $map
Cameo 'SCSIEGE' { param($c) $x = $c.Layer($c.New(), (G 'tank'), 0, 11, $true, $null, 0, 0, $false); $c.Layer($x, (G 'tankt'), 0, 11, $true, $tLo, 0, 0, $false) } 128 128
"  tank turret offset $($tC -join ',')"

# Siege Mode as a BUILDING (deploy = DeploysInto, like MCV -> ConYard; a unit with Speed=0 got stuck on move orders).
# 1x1 building: canvas centre = top vertex of the cell diamond, so the tank sits 12 px lower than in the unit SHP.
# <id>.SHP = body (normal, damaged, 2 shadows), <turret>.SHP = TurretAnim (32 facings + 32 empty shadows),
# <mk>.SHP = buildup = the real SC siege deploy (stank 0-5 + stankt transition frames 17/34/51/68/85/101), played backwards on undeploy.
function SiegeBuilding($id, $turret, $mk, $m) {
    $shape = New-Object ScBuildingShape 1, 1, 128, 128, 0
    $dmg = [ScBuildings]::DamageMap($m, $unitPal)
    $body = New-Object 'System.Collections.Generic.List[ScLayer]'; $body.Add((New-Object ScLayer (G 'stank'), 5, $false))
    $shad = New-Object 'System.Collections.Generic.List[ScLayer]'; $shad.Add((New-Object ScLayer (G 'tstshad'), 5, $true))
    $files["$id.SHP"] = $shape.Building($body, $shad, $m, $dmg).Write()
    # TurretAnim frames run COUNTER-clockwise from north (GUN_A, ART_A: frame 4 = NW), unlike vehicle turrets;
    # the mount stays put when the cannon is mirrored (fixed body)
    $u = New-Object UnitBuilder $shape.Cw, $shape.Ch, $m
    for ($f = 0; $f -lt 32; $f++) {
        $mi = $false; $d = [ScBuild]::ScDir((32 - $f) % 32, [ref]$mi)
        $u.Add($u.LayerAt($u.New(), (G 'stankt'), $d, $mi, $(if ($mi) { -1 } else { 1 }) * ($sLo[5][0] + $shape.Dx), $sLo[5][1] + $shape.Dy, $false), $null)
    }
    Save $turret $u.ToShp() ([int[]](0,4,8,12,16,20,24,28))
    $u = New-Object UnitBuilder $shape.Cw, $shape.Ch, $m
    foreach ($k in 0..5) { foreach ($r in 1..3) {
        $b = $u.Layer($u.New(), (G 'stank'), $k, 0, $false, $null, $shape.Dx, $shape.Dy, $false)
        $b = $u.LayerAt($b, (G 'stankt'), $(if ($k -lt 5) { 17 + 17 * $k } else { 101 }), $false, $sLo[$k][0] + $shape.Dx, $sLo[$k][1] + $shape.Dy, $false)
        $u.Add($b, $u.Layer($u.New(), (G 'tstshad'), $k, 0, $false, $null, $shape.Dx, $shape.Dy, $true))
    } }
    Save $mk $u.ToShp() ([int[]](0,3,6,9,12,15,17))
}
SiegeBuilding 'SCSIEGB' 'SCSIEGBT' 'SCSIEGMK' $map

# Muzzle flashes = weapon Anim lists of 32 (index = facing clockwise from north, like FTNKFLM00-31), fired with FireFLH 0,0,0:
# the anim is drawn centred on the cell/unit centre and the flash is baked at the barrel tip.
# SCSFL00-31 Siege Mode: esifire.grp (7 phases x 17 dirs) at stank.lol mount + stankt.loa barrel offset.
# SCTFL00-31 tank mode: ettflash.grp (1 frame x 17 dirs, tip already baked around the turret centre) at the turret mount.
$loa = Lo 'stankt.loa'
for ($f = 0; $f -lt 32; $f++) {
    $mi = $false; $d = [ScBuild]::ScDir($f, [ref]$mi)
    $x = $sLo[5][0] + $(if ($mi) { -$loa[$d][0] } else { $loa[$d][0] }); $y = $sLo[5][1] + $loa[$d][1]
    $u = New-Object UnitBuilder 200, 200, $mapFire
    foreach ($k in 0..6) { $u.Frames.Add($u.LayerAt($u.New(), (G 'thingy/esifire'), $k * 17 + $d, $mi, $(if ($mi) { -$x } else { $x }), $y, $false)) }
    $files[('SCSFL{0:D2}.SHP' -f $f)] = $u.ToShp().Write()
    $u = New-Object UnitBuilder 160, 160, $mapFire
    $fl = $u.Layer($u.New(), (G 'thingy/ettflash'), 0, $f, $true, $null, $tC[0], $tC[1], $false)
    foreach ($k in 0..2) { $u.Frames.Add($fl) }
    $files[('SCTFL{0:D2}.SHP' -f $f)] = $u.ToShp().Write()
}

# Hero Siege Tank (Edmund Duke): same sprites, gold armour; cameo from a gold-tinted SC palette
$mapGold = [ScUnits]::TintMap($scPal, $unitPal, $ramp, 1.35, 1.15, 0.45)
TankMode 'SCHERO' $mapGold
SiegeMode 'SCHEROS' $mapGold
SiegeBuilding 'SCHEROB' 'SCHEROBT' 'SCHEROMK' $mapGold
$scGold = [ScUnits]::TintPalette($scPal, 1.35, 1.15, 0.45)
$ub = New-Object UnitBuilder 128, 128, $ident
$hf = $ub.Layer($ub.New(), (G 'tank'), 0, 11, $true, $null, 0, 0, $false); $hf = $ub.Layer($hf, (G 'tankt'), 0, 11, $true, $tLo, 0, 0, $false)
$hl = New-Object 'System.Collections.Generic.List[ScLayer]'; $hl.Add((New-Object ScLayer ([ScUnits]::AsGrp($hf, 128, 128)), 0, $false))
$hc = [ScBuildings]::Cameo($hl, $scGold, $ramp, $cameoPal); $files['SCHEROI.SHP'] = $hc.Write(); $cameoFrames.Add($hc.Frames[0])

# Goliath: body stand 0-31, walk 32-319 (9 phases), turret 320-351, shadows 352-703.
$gLo = Lo 'goliath.lol'; $gC = LoMean $gLo 0
$u = New-Object UnitBuilder 76, 76, $map
for ($f = 0; $f -lt 32; $f++) { $u.Add($u.Layer($u.New(), (G 'goliath'), 0, $f, $true, $null, 0, 0, $false), $u.Layer($u.New(), (G 'tgoshad'), 0, $f, $true, $null, 0, 0, $true)) }
for ($f = 0; $f -lt 32; $f++) { foreach ($k in 1..9) { $u.Add($u.Layer($u.New(), (G 'goliath'), $k, $f, $true, $null, 0, 0, $false), $u.Layer($u.New(), (G 'tgoshad'), $k, $f, $true, $null, 0, 0, $true)) } }
for ($f = 0; $f -lt 32; $f++) { $u.Add($u.Layer($u.New(), (G 'goliatht'), 0, $f, $true, $null, $gC[0], $gC[1], $false), $null) }
Save 'SCGOLI' $u.ToShp() ([int[]](0,8,16,24,32,33,34,320,324,328,332,336))
Cameo 'SCGOLI' { param($c) $x = $c.Layer($c.New(), (G 'goliath'), 0, 11, $true, $null, 0, 0, $false); $c.Layer($x, (G 'goliatht'), 0, 11, $true, $gLo, 0, 0, $false) } 76 76
"  goliath turret offset $($gC -join ',')"

# ---------------------------------------------------------------- HERO: Jim Raynor (gold Marine, marine.grp layout as SCMARINE)
$mapRay  = [ScUnits]::TintMap($scPal, $unitPal, $ramp, 1.35, 1.15, 0.45)
$mapRayS = [ScUnits]::TintMap($scPal, $unitPal, $ramp, 1.6, 0.9, 0.35)      # stimpack: red-gold
Save 'SCRAYN'  ([ScBuild]::BuildUnit((G 'marine'), (G 'tmashad'), $mapRay,  [int[]](4..12), 2, 3)) ($prev8 + 32,33,34 + 320,321)
Save 'SCRAYNS' ([ScBuild]::BuildUnit((G 'marine'), (G 'tmashad'), $mapRayS, [int[]](4..12), 2, 3)) $prev8
$ub = New-Object UnitBuilder 64, 64, $ident
$rf = $ub.Layer($ub.New(), (G 'marine'), 0, 11, $true, $null, 0, 0, $false)
$rl = New-Object 'System.Collections.Generic.List[ScLayer]'; $rl.Add((New-Object ScLayer ([ScUnits]::AsGrp($rf, 64, 64)), 0, $false))
$rc = [ScBuildings]::Cameo($rl, $scGold, $ramp, $cameoPal); $files['SCRAYNI.SHP'] = $rc.Write(); $cameoFrames.Add($rc.Frames[0])

[Pal]::Sheet($cameoFrames, [int[]](0..($cameoFrames.Count-1)), 64, 48, $cameoPal, 2, 7, "$PreviewDir\cameos.png")

# ---------------------------------------------------------------- sounds (SD = 22050 Hz 16-bit mono = DTA .aud)
$snd = [ordered]@{}
function Voices($p, $dir, $sc) {   # SC<p>WHT0-3, SC<p>YES0-3, SC<p>DTH0 from SD/sound/terran/<dir>/<sc>wht00.. etc.
    foreach ($k in 0..3) { $snd["SC${p}WHT$k"] = "SD/sound/terran/$dir/${sc}wht0$k.wav"; $snd["SC${p}YES$k"] = "SD/sound/terran/$dir/${sc}yes0$k.wav" }
    $snd["SC${p}DTH0"] = "SD/sound/terran/$dir/${sc}dth00.wav"
}
Voices 'SC' 'scv' 'tsc';      Voices 'FB' 'firebat' 'tfb';  Voices 'GH' 'ghost' 'tgh';   Voices 'MD' 'medic' 'TMd'
Voices 'VU' 'vulture' 'tvu';  Voices 'TA' 'tank' 'tta';     Voices 'GO' 'goliath' 'tgo'; Voices 'PH' 'phoenix' 'tph'
Voices 'DR' 'dropship' 'tdr'; Voices 'VE' 'vessel' 'tve';   Voices 'BA' 'battle' 'tba';  Voices 'VK' 'frigate' 'TVk'
Voices 'DK' 'duket' 'udt'    # Edmund Duke in his siege tank (hero)
Voices 'RA' 'raynorm' 'ura'  # Jim Raynor as a marine (hero)
foreach ($k in 0..4) { $snd["SCDKPSS$k"] = "SD/sound/terran/duket/udtpss0$k.wav" }   # "annoyed" click lines, used as extra select voices
foreach ($k in 0..3) { $snd["SCRAPSS$k"] = "SD/sound/terran/raynorm/urapss0$k.wav" }
$snd['SCFBFIRE'] = 'SD/sound/terran/firebat/tfbfir00.wav'
$snd['SCGHFIRE'] = 'SD/sound/bullet/tghfir00.wav'
$snd['SCGHLKD']  = 'SD/sound/terran/ghost/tghlkd00.wav'
$snd['SCMDHEAL'] = 'SD/sound/terran/medic/Tmedheal.wav'
$snd['SCVUFIRE'] = 'SD/sound/bullet/tvufir00.wav'
$snd['SCTAFIRE'] = 'SD/sound/bullet/ttafir00.wav'
$snd['SCTAFIR2'] = 'SD/sound/bullet/ttafi200.wav'
$snd['SCTATRA0'] = 'SD/sound/terran/tank/ttatra00.wav'
$snd['SCTATRA1'] = 'SD/sound/terran/tank/ttatra01.wav'
$snd['SCGOFIRE'] = 'SD/sound/bullet/tgofir00.wav'
$snd['SCGOFIR2'] = 'SD/sound/bullet/tgofi200.wav'
$snd['SCPHFIR1'] = 'SD/sound/bullet/tphfi100.wav'
$snd['SCPHFIR2'] = 'SD/sound/bullet/tphfi200.wav'
$snd['SCPHCLO0'] = 'SD/sound/terran/phoenix/tphclo00.wav'
$snd['SCVEEMP0'] = 'SD/sound/terran/vessel/tveemp00.wav'
$snd['SCBAFIRE'] = 'SD/sound/bullet/laserb.wav'
$snd['SCBAYAM0'] = 'SD/sound/bullet/tbayam00.wav'
$snd['SCBAYAM1'] = 'SD/sound/terran/battle/tbayam01.wav'
$snd['SCVKFIRE'] = 'SD/sound/bullet/Tfrshoot.wav'
$snd['SCSCFIRE'] = 'SD/sound/bullet/tscfir00.wav'
foreach ($k in @($snd.Keys)) {
    if (-not $casc.Exists($snd[$k])) { Write-Warning "missing sound $($snd[$k]) ($k)"; $snd.Remove($k); continue }
    $rate = 0
    $pcm = [Aud]::ReadWav($casc.ReadFile($snd[$k]), [ref]$rate)
    $files["$k.AUD"] = [Aud]::Encode($pcm, $rate, 1.0)
}
"sounds: $($snd.Count)"

[Mix]::Write($OutMix, $files)
"$OutMix : $($files.Count) files"
$check = New-Object Mix $OutMix
foreach ($k in $files.Keys) { if (-not $check.Has($k)) { throw "missing $k" }; if ($k -like '*.SHP') { $s = [Shp]::Read($check.Read($k)); if ($s.Frames.Count -eq 0) { throw "bad $k" } } }
"round-trip OK; previews -> $PreviewDir"
# list of sound names for Sound.ini
($snd.Keys -join ',') | Set-Content -Encoding ASCII "$PreviewDir\sounds.txt"
