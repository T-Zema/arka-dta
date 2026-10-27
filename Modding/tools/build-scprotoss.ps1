# Protoss FACTION for DTA: every Protoss building and unit of StarCraft: Brood War (user 2026-10-25: "zrob cala frakcje protosow").
# 16 buildings (Nexus ... Arbiter Tribunal), Probe, Gateway infantry (Zealot, Dragoon, High Templar, Dark Templar, Archon,
# Dark Archon), Robotics units (Shuttle, Reaver, Observer) and Stargate flyers (Scout, Corsair, Carrier, Arbiter).
# Build range the StarCraft way: only the Nexus and Pylons count as "base" for placement (BaseNormal=yes, the rest
# BaseNormal=no) and every Protoss building may be placed far from them (Adjacent=), so new buildings go near Pylons.
#   .\build-scprotoss.ps1           -> MIX/ECACHE85.MIX (SHP, cameos, AUD) + previews in -PreviewDir
#   .\build-scprotoss.ps1 -Install  -> also the INI side: faction (INI/Map Code/Terran Faction.ini, block "Protoss faction"),
#                                      Art.ini / Sound.ini blocks, StarCraft.ini [AI] BuildConst +SCPNEX, lobby
#                                      (Resources/GameOptions.ini, INI/MPMaps.ini) and side files (SideC09/sidenc09/Speech09,
#                                      protossicon.png, loading screens) copied from GDI.
# House GDI2 (helper house 8 of GDI, missions only) becomes the playable "Protoss". Blocks sit between
# "; >>> Protoss faction" and "; <<< Protoss faction", list entries use PRB/PRI/PRV/PRA keys and [SoundList] 1400+,
# so re-running replaces them. Wiki: Modding/wiki/mods/protoss-faction.md
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\scprotoss-preview",
    [string]$OutMix = "",   # default: <game>\MIX\ECACHE85.MIX; another path = build only (e.g. while the game runs)
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs", "$tools\ScBuild.cs", "$tools\ScBuildings.cs", "$tools\ScInfantry.cs", "$tools\ScZerg.cs", "$tools\ScProtoss.cs" -ReferencedAssemblies System.Drawing
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
$map    = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)
$dmgMap = [ScBuildings]::DamageMap($map, $unitPal)
$gold   = [Drawing.Color]::FromArgb(200, 160, 50)

$grpCache = @{}
function G($name) {
    if (-not $name) { return $null }
    $path = if ($name.Contains('/')) { "unit/$name.grp" } else { "unit/protoss/$name.grp" }
    if (-not $grpCache.ContainsKey($path)) { $grpCache[$path] = [Grp]::Read($casc.ReadFile($path)) }
    return $grpCache[$path]
}
function Layers { $l = New-Object 'System.Collections.Generic.List[ScLayer]'; foreach ($a in $args) { if ($a) { $l.Add($a) } }; return ,$l }
function L($grp, $frame, $shadow = $false) { $g = if ($grp -is [string]) { G $grp } else { $grp }; if (-not $g) { return $null }; return New-Object ScLayer $g, $frame, $shadow }

# Buildings. GRP and shadow names from SC's data (units.dat -> flingy -> sprites -> images.dat/images.tbl; the shadow is
# the image right after the building's). Foundations = SC footprints, except the Assimilator (SC 4x2) which gets 4x3 + Bib
# like every DTA refinery. Top = overlay drawn over frame 0 (Forge hammer, Cybernetics Core dish).
# $Bldgs, not $B: PowerShell names are case-insensitive, so a loop "foreach ($b in $B)" would overwrite it
$Bldgs = @(
    @{ Id = 'SCPNEX'; Grp = 'nexus';    Shad = 'pneshad'; Top = '';         Fw = 4; Fh = 3 }
    @{ Id = 'SCPPYL'; Grp = 'pylon';    Shad = 'ppyshad'; Top = '';         Fw = 2; Fh = 2 }
    @{ Id = 'SCPASM'; Grp = 'assim';    Shad = 'passhad'; Top = '';         Fw = 4; Fh = 3 }
    @{ Id = 'SCPGAT'; Grp = 'gateway';  Shad = 'pgashad'; Top = '';         Fw = 4; Fh = 3 }
    @{ Id = 'SCPFOR'; Grp = 'forge';    Shad = 'pfoshad'; Top = 'forget';   Fw = 3; Fh = 2 }
    @{ Id = 'SCPCAN'; Grp = 'photon';   Shad = 'ppbshad'; Top = '';         Fw = 2; Fh = 2 }
    @{ Id = 'SCPCYB'; Grp = 'gencore';  Shad = 'pgcshad'; Top = 'gencoret'; Fw = 3; Fh = 2 }
    @{ Id = 'SCPROB'; Grp = 'robotic';  Shad = 'proshad'; Top = '';         Fw = 3; Fh = 2 }
    @{ Id = 'SCPARC'; Grp = 'archives'; Shad = 'pacshad'; Top = '';         Fw = 3; Fh = 2 }
    # historical GRP names: Robotics Support Bay = stasis, Fleet Beacon = warp, Observatory = beacon, Arbiter Tribunal = prism
    @{ Id = 'SCPBAT'; Grp = 'sbattery'; Shad = 'pbashad'; Top = '';         Fw = 2; Fh = 2 }
    @{ Id = 'SCPSTG'; Grp = 'stargate'; Shad = 'psgshad'; Top = '';         Fw = 4; Fh = 3 }
    @{ Id = 'SCPCIT'; Grp = 'citadel';  Shad = 'pcishad'; Top = '';         Fw = 3; Fh = 2 }
    @{ Id = 'SCPRSB'; Grp = 'stasis';   Shad = 'pstshad'; Top = '';         Fw = 3; Fh = 2 }
    @{ Id = 'SCPFLB'; Grp = 'warp';     Shad = 'pwashad'; Top = '';         Fw = 3; Fh = 2 }
    @{ Id = 'SCPOBS'; Grp = 'beacon';   Shad = 'pbeshad'; Top = '';         Fw = 3; Fh = 2 }
    @{ Id = 'SCPTRB'; Grp = 'prism';    Shad = 'paushad'; Top = '';         Fw = 3; Fh = 2 }
)

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$cameoFrames = New-Object 'System.Collections.Generic.List[Frame]'
$bodies = @{}
$texture = G 'texture'
$warpSteps = 12
foreach ($b in $Bldgs) {
    $sizes = @($b.Grp, $b.Shad, $b.Top) | ? { $_ } | % { G $_ }
    $maxW = ($sizes | % { $_.Width } | Measure-Object -Maximum).Maximum
    $maxH = ($sizes | % { $_.Height } | Measure-Object -Maximum).Maximum
    $shape = New-Object ScBuildingShape $b.Fw, $b.Fh, $maxW, $maxH, 0
    $top  = if ($b.Top) { L $b.Top 0 } else { $null }
    $body = Layers (L $b.Grp 0) $top
    $shad = Layers (L $b.Shad 0 $true)
    $bodies[$b.Id] = $body
    $bldg = $shape.Building($body, $shad, $map, $dmgMap)

    # Buildup = warp-in: silhouette full of the SC warp texture, the building solidifies, then the finished building.
    $stages  = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[ScLayer]]'
    $shadows = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[ScLayer]]'
    $repeat  = New-Object 'System.Collections.Generic.List[int]'
    for ($k = 0; $k -lt $warpSteps; $k++) {
        $reveal = [Math]::Pow($k / ($warpSteps - 1), 1.6)
        $warp = [ScProtoss]::Warp((G $b.Grp), 0, $texture, $k, $reveal, $scPal)
        $stages.Add((Layers (L $warp 0)))
        if ($k -ge $warpSteps / 2) { $shadows.Add($shad) } else { $shadows.Add((Layers)) }
        $repeat.Add(2)
    }
    $stages.Add($body); $shadows.Add($shad); $repeat.Add(2)
    $mk = $shape.Buildup($stages, $shadows, $repeat.ToArray(), $map)

    $files["$($b.Id).SHP"]   = $bldg.Write()
    $files["$($b.Id)MK.SHP"] = $mk.Write()
    $cameo = [ScBuildings]::Cameo($body, $scPal, $ramp, $cameoPal)
    $files["$($b.Id)IC.SHP"] = $cameo.Write()
    $cameoFrames.Add($cameo.Frames[0])
    if ($b.Id -eq 'SCPBAT') {
        # ActiveAnim of the Shield Battery: the SC glow overlay pbaGlow (3 frames, ping-pong) on the building's canvas, so it
        # sits exactly on the building (like RAMSLO_A / the Terran silo doors): 4 normal + 4 damaged frames, then 8 empty shadows.
        $ga = New-Object Shp; $ga.Width = $shape.Cw; $ga.Height = $shape.Ch
        $glowGrp = [ScProtoss]::Glow((G 'pbaglow'), $scPal)
        foreach ($rep in 1, 2) { foreach ($k in 0, 1, 2, 1) { $ga.Frames.Add($shape.Compose((Layers (L $glowGrp $k)), $map, $null, 0)) } }
        foreach ($k in 1..8) { $ga.Frames.Add((New-Object Frame 0, 0, $shape.Cw, $shape.Ch)) }
        $files['SCPBATGL.SHP'] = $ga.Write()
        [Pal]::Sheet($ga.Frames, [int[]](0..3), $shape.Cw, $shape.Ch, $unitPal, 1, 4, "$PreviewDir\glow_SCPBAT.png")
    }

    [ScBuildings]::FitPreview($bldg, 0, 2, $shape, $unitPal, 2, "$PreviewDir\fit_$($b.Id).png")
    $n = $mk.Frames.Count / 2
    [Pal]::Sheet($mk.Frames, [int[]](0, 6, 12, 16, 20, ($n - 1)), $shape.Cw, $shape.Ch, $unitPal, 1, 6, "$PreviewDir\mk_$($b.Id).png")
    "{0,-7} foundation {1}x{2} canvas {3}x{4} buildup {5} frames" -f $b.Id, $b.Fw, $b.Fh, $shape.Cw, $shape.Ch, $n
}

# Gateway units = real INFANTRY again (user, test 3: "Zealot nie powinien byc czolgiem, to samo Dragoon, robotem jest tylko
# Reaver, archont w sumie jest tankiem, fabryka bedzie Robotics"): Zealot, Dragoon, High and Dark Templar are infantry from the
# Gateway; Archon and Dark Archon stay SHP vehicles (Inf=$false) and come from the Robotics Facility, like the Probes.
# Frame sets from SC's iscript.bin (playfram = set*17+dir). Infantry: Stand, Walk, Fire sets, the SC death frames at the end
# of the SHP (ScInfantry.Build), death sound = VoiceDie. Vehicles: Walk sets (the first doubles as stand), Aim/Flash = two attack
# sets for the 2 fire frames, the death frames become the Explosion= anim with the SC death sound as Report (Terran SCSCDTH
# pattern; vehicles ignore DieSound). Dragoon death + its remains GRP; Dark Templar borrows the High Templar's death (SC: a
# flash); Archons: the swirl fading. Dark Templar: no shadow GRP (cloaked), body = silhouette.
$units = @(
    @{ Id = 'SCPZEAL'; Inf = $true; Grp = 'zealot';   Shadow = 'pzeshad';  Stand = 5;  Walk = 5..12; Fire = 0..4; FireFrame = 4; Flh = '0,0,20'
       Death = @(, @('zealot', (221..227))) }
    @{ Id = 'SCPDRAG'; Inf = $true; Grp = 'dragoon';  Shadow = 'pdrshad';  Stand = 0;  Walk = 8..15; Fire = 16..23; FireFrame = 7; Flh = '60,0,60'
       Death = @(@('dragoon', (408..414)), @('pdrdeath', $null)) }
    @{ Id = 'SCPHTMP'; Inf = $true; Grp = 'templar';  Shadow = 'pteshad';  Stand = 6;  Walk = 14, 15, 16, 5; Fire = 0..4; FireFrame = 4; Flh = '30,0,50'
       Death = @(, @('templar', (289..295))) }
    @{ Id = 'SCPDTMP'; Inf = $true; Grp = 'dtemplar'; Shadow = 'dtemplar'; Stand = 13; Walk = 14, 15, 16, 17, 10, 11, 12, 13; Fire = 0..9; FireFrame = 5; Flh = '0,0,20'
       Death = @(, @('templar', (289..295))) }
    # Archons: energy ball + directional being (archonT/darchnT iscript) + swirl, stacked by ScProtoss.Stack; no shadow (pure energy).
    # Archon being: idle/walk sets 10-13 (ping-pong), attack 0-9 (shot at set 5); Dark Archon: walk 0-9, attack 10.
    @{ Id = 'SCPARCH'; Body = [ScProtoss]::Stack((G 'archon'), 10, (G 'archont'), (G 'archont2')); Shadow = ''; Walk = 10, 11, 12, 13, 12, 11
       Aim = 4; Flash = 5; Flh = '40,0,60'; Death = @(, @('archont2', (0..14))); DAnim = 'SCPADTHX'; DSnd = 'SCPADTH' }
    @{ Id = 'SCPDARC'; Body = [ScProtoss]::Stack((G 'darchn'), 10, (G 'darchnT'), (G 'darchnT2')); Shadow = ''; Walk = 0..9
       Aim = 10; Flash = 10; Flh = '40,0,60'; Death = @(, @('darchnT2', (0..14))); DAnim = 'SCPXDTHX'; DSnd = 'SCPADTH' }
)
$layouts = @{}
foreach ($u in $units) {
    $body = if ($u.Body) { $u.Body } else { G $u.Grp }
    $death = New-Object 'System.Collections.Generic.List[Frame]'
    foreach ($d in $u.Death) {
        $dg = G $d[0]
        $idx = if ($d[1]) { [int[]]$d[1] } else { [int[]](0..($dg.Frames.Count - 1)) }
        $death.AddRange([ScProtoss]::OnCanvas($dg, $idx, $body.Width, $body.Height))
    }
    $sh = if ($u.Shadow) { G $u.Shadow } else { [ScProtoss]::Blank($body) }
    if ($u.Inf) {
        $lay = $null
        $shp = [ScInfantry]::Build($body, $sh, $map, $u.Stand, [int[]]$u.Walk, [int[]]$u.Fire, $death, [ref]$lay)
        $layouts[$u.Id] = $lay
        $files["$($u.Id).SHP"] = $shp.Write()
        $cameo = [ScInfantry]::Cameo($body.Frames[$u.Stand * 17 + 12], $body.Width, $body.Height, $scPal, $ramp, $cameoPal, $gold)
        "{0}: infantry {1}x{2}, {3} frames (+shadows), walk {4} fire {5} death {6}" -f $u.Id, $shp.Width, $shp.Height, $lay.Total, $lay.WalkFrames, $lay.FireFrames, $lay.DeathFrames
        $idx = @(0..7) + @(($lay.Walk + 6 * $lay.WalkFrames)..($lay.Walk + 7 * $lay.WalkFrames - 1)) + @(($lay.Fire + 6 * $lay.FireFrames)..($lay.Fire + 7 * $lay.FireFrames - 1)) + @($lay.Death..($lay.Death + $lay.DeathFrames - 1))
        [Pal]::Sheet($shp.Frames, [int[]]$idx, $shp.Width, $shp.Height, $unitPal, 2, 12, "$PreviewDir\$($u.Id).png")
    } else {
        $shp = [ScBuild]::BuildUnit($body, $sh, $map, [int[]]$u.Walk, $u.Aim, $u.Flash)
        $layouts[$u.Id] = $u.Walk.Count
        $files["$($u.Id).SHP"] = $shp.Write()
        $da = [ScBuild]::BuildAnim($death, $body.Width, $body.Height, $map)
        $files["$($u.DAnim).SHP"] = $da.Write()
        $cameo = [ScInfantry]::Cameo($body.Frames[$u.Walk[0] * 17 + 12], $body.Width, $body.Height, $scPal, $ramp, $cameoPal, $gold)
        "{0}: vehicle {1}x{2}, {3} frames, walk {4}, death anim {5} frames" -f $u.Id, $shp.Width, $shp.Height, $shp.Frames.Count, $u.Walk.Count, $da.Frames.Count
        $nw = $u.Walk.Count
        [Pal]::Sheet($shp.Frames, [int[]](@(0, 4, 8, 12, 16, 20, 24, 28) + @(32..(32 + $nw - 1)) + @((32 + 32 * $nw), (33 + 32 * $nw))), $shp.Width, $shp.Height, $unitPal, 2, 12, "$PreviewDir\$($u.Id).png")
    }
    $files["$($u.Id)I.SHP"] = $cameo.Write(); $cameoFrames.Add($cameo.Frames[0])
}

# Archon hit: SC's thingy\emsHit.grp (image of weapon 70 "Psionic Shockwave"), shows the splash
$ahx = G 'thingy/emsHit'
$ahxFrames = New-Object 'System.Collections.Generic.List[Frame]'; foreach ($f in $ahx.Frames) { $ahxFrames.Add($f) }
$files['SCPARCHH.SHP'] = ([ScBuild]::BuildAnim($ahxFrames, $ahx.Width, $ahx.Height, $map)).Write()

# Dragoon / Arbiter phase disruptor: a real projectile (user: Dragoons were hitscan). SC bullet\dragbull.grp (5 frames, animated
# via AnimLow/AnimHigh/AnimRate of the projectile art, like DTA's PLASMORB) and its hit thingy\HKexplod.grp (SC iscript of dragbull).
$db = G 'bullet/dragbull'
$dbFrames = New-Object 'System.Collections.Generic.List[Frame]'; foreach ($f in $db.Frames) { $dbFrames.Add($f) }
$files['SCPDRBUL.SHP'] = ([ScBuild]::BuildAnim($dbFrames, $db.Width, $db.Height, $map)).Write()
$dh = G 'thingy/HKexplod'
$dhFrames = New-Object 'System.Collections.Generic.List[Frame]'; foreach ($f in $dh.Frames) { $dhFrames.Add($f) }
$files['SCPDRHIT.SHP'] = ([ScBuild]::BuildAnim($dhFrames, $dh.Width, $dh.Height, $map)).Write()
"dragbull projectile {0} frames, hit {1} frames" -f $db.Frames.Count, $dh.Frames.Count
# Photon Cannon bolt: SC bullet\epbBul.grp (weapons 80/81, 11 frames: the blue ball), animated like the dragbull
$pb = [ScProtoss]::BlueByLuma((G 'bullet/epbBul'), $scPal)   # SC draws it blue through a remap; unit palette would show it green
$pbFrames = New-Object 'System.Collections.Generic.List[Frame]'; foreach ($f in $pb.Frames) { $pbFrames.Add($f) }
$files['SCPPHBUL.SHP'] = ([ScBuild]::BuildAnim($pbFrames, $pb.Width, $pb.Height, $map)).Write()
# Reaver Scarab: the SC Scarab unit (protoss\sapper.grp, 17 directions) as a rotating projectile (32 facings)
$files['SCPSCARB.SHP'] = ([ScProtoss]::Rotating((G 'sapper'), 0, $map)).Write()
"photon bolt {0} frames, scarab 32 facings" -f $pb.Frames.Count

# Reaver Scarab explosion: SC's thingy\psaExplo.grp with Bullet\psaHit00 (SC iscript of the Scarab, unit 85)
$scx = G 'thingy/psaExplo'
$scxFrames = New-Object 'System.Collections.Generic.List[Frame]'; foreach ($f in $scx.Frames) { $scxFrames.Add($f) }
$files['SCPSCAEX.SHP'] = ([ScBuild]::BuildAnim($scxFrames, $scx.Width, $scx.Height, $map)).Write()

# Probe: SHP vehicle, 32 facings, one SC frame set (it hovers): 0-31 stand, 32-63 walk, 64-127 "fire", then shadows.
# probe.grp has no shadow GRP (SC draws it from the body), so the shadow is the body moved down (it floats).
$probeRaw = G 'probe'
$bb = [ScZerg]::Bounds($probeRaw)
$probe = [ScZerg]::Crop($probeRaw, $bb[0], [Math]::Min($probeRaw.Height, $bb[1] + 16))
$probeShp = [ScBuild]::BuildUnit($probe, [ScZerg]::Shifted($probe, 8), $map, [int[]]@(0), 0, 0)
$probeBytes = $probeShp.Write()
"Probe   vehicle {0} frames {1}x{2}" -f $probeShp.Frames.Count, $probeShp.Width, $probeShp.Height
[Pal]::Sheet($probeShp.Frames, [int[]](0, 4, 8, 12, 16, 20, 24, 28, 128, 132), $probeShp.Width, $probeShp.Height, $unitPal, 2, 10, "$PreviewDir\probe.png")
$files['SCPPROBE.SHP'] = $probeBytes
$pc = [ScInfantry]::Cameo($probe.Frames[12], $probe.Width, $probe.Height, $scPal, $ramp, $cameoPal, $gold)
$files['SCPPROBEI.SHP'] = $pc.Write(); $cameoFrames.Add($pc.Frames[0])
# "Probe: Nexus" = start unit / new base (deploys into the Nexus); own SHP copy because art and cameo follow the image name
$files['SCPDNEX.SHP'] = $probeBytes
$nc = [ScZerg]::DroneCameo($bodies['SCPNEX'], $probe, 12, $scPal, $ramp, $cameoPal)
$files['SCPDNEXI.SHP'] = $nc.Write(); $cameoFrames.Add($nc.Frames[0])

# Robotics and Stargate units: SHP vehicles, 32 facings: 0-31 stand, 32+ walk (Walk sets per facing), then 2 fire frames
# (Aim, Flash set), shadows in the second half. Sets from SC's iscript: Reaver (trilob) walks through sets 1-8 and 0; flyers
# have one body set, Scout/Arbiter a second "firing" set 1, Corsair attack sets 1-4. Flyers: Fly locomotor (Zerg/Terran
# pattern, game.exe patch-flyhover.ps1), shadow = their own silhouette; the Reaver has its shadow GRP ptrShad.
$Vehicles = @(
    @{ Id = 'SCPREAV'; Grp = 'trilob';   Shadow = 'ptrshad'; Walk = 0..8; Aim = 0; Flash = 0; Fly = $false; Flh = '40,0,30' }
    @{ Id = 'SCPSHUT'; Grp = 'shuttle';  Shadow = '';        Walk = @(0); Aim = 0; Flash = 0; Fly = $true;  Flh = '0,0,0' }
    @{ Id = 'SCPOBSV'; Grp = 'witness';  Shadow = '';        Walk = @(0); Aim = 0; Flash = 0; Fly = $true;  Flh = '0,0,0' }
    @{ Id = 'SCPSCOU'; Grp = 'scout';    Shadow = '';        Walk = @(0); Aim = 0; Flash = 1; Fly = $true;  Flh = '30,0,0' }
    @{ Id = 'SCPCORS'; Grp = 'corsair';  Shadow = '';        Walk = @(0); Aim = 1; Flash = 3; Fly = $true;  Flh = '30,0,0' }
    # Carrier = "hover" ground vehicle drawn 60 px up with its shadow on the ground: Vinifera's spawner takes an Interceptor
    # back only when |Z(interceptor) - Z(owner)| < 20 (SpawnManagerClass::AI, Returning); a Fly carrier at FlightLevel 450
    # never matched, its Interceptors circled forever (user test 3). DTA's hovercraft (HVC, HVCSAM) are the model.
    # Carrier FLIES again like the Terran warships (Fly locomotor + patch-flyhover) at FlightLevel=450 = the cruise height of the
    # Interceptors (Rules [General] FlightLevel=450): Vinifera docks a returning spawn only over the owner's cell with |dZ| < 20.
    # As a ground vehicle (tests 3-4) the Interceptors hung around it at 450 and never docked (user: "drony sa wokol carriera").
    @{ Id = 'SCPCARR'; Grp = 'carrier';  Shadow = '';        Walk = @(0); Aim = 0; Flash = 0; Fly = $true;  Flh = '40,0,0' }
    @{ Id = 'SCPARBI'; Grp = 'arbiter';  Shadow = '';        Walk = @(0); Aim = 0; Flash = 1; Fly = $true;  Flh = '30,0,0' }
)
$vehLayout = @{}
foreach ($ve in $Vehicles) {
    $raw = G $ve.Grp; $vb = [ScZerg]::Bounds($raw); $g2 = [ScZerg]::Crop($raw, $vb[0], $vb[1])
    $sh = if ($ve.Shadow) { [ScZerg]::Crop((G $ve.Shadow), $vb[0], $vb[1]) } else { $g2 }   # same canvas as the body
    if ($ve.Raise) {
        # ground unit that looks airborne: taller canvas, body moved up, shadow (its own silhouette) stays at the unit's position
        $tall = [ScZerg]::Crop($raw, $vb[0], $vb[1] + 2 * $ve.Raise + 8)
        $g2 = [ScZerg]::Shifted($tall, -$ve.Raise); $sh = $tall
    }
    $shp = [ScBuild]::BuildUnit($g2, $sh, $map, [int[]]$ve.Walk, $ve.Aim, $ve.Flash)
    $files["$($ve.Id).SHP"] = $shp.Write()
    $vehLayout[$ve.Id] = $ve.Walk.Count
    $cm = [ScInfantry]::Cameo($g2.Frames[12], $g2.Width, $g2.Height, $scPal, $ramp, $cameoPal, $gold)
    $files["$($ve.Id)I.SHP"] = $cm.Write(); $cameoFrames.Add($cm.Frames[0])
    [Pal]::Sheet($shp.Frames, [int[]](0, 4, 8, 12, 16, 20, 24, 28, 32, 33), $shp.Width, $shp.Height, $unitPal, 2, 10, "$PreviewDir\$($ve.Id).png")
    "{0,-7} vehicle {1} frames {2}x{3} ({4})" -f $ve.Id, $shp.Frames.Count, $shp.Width, $shp.Height, $(if ("$($ve.Fly)" -eq 'hover') { 'hover, raised' } elseif ($ve.Fly) { 'Fly' } else { 'ground' })
}

# Arbiter cloaking field: the deployed Arbiter is a 1x1 building (CloakGenerator=yes, like Nod's Stealth Generator), drawn
# hovering (sprite raised by ~60 px = FlightLevel 450) with its shadow on the ground. SC frame 10 = facing east-south-east.
$arb = G 'arbiter'
$fieldShape = New-Object ScBuildingShape 1, 1, $arb.Width, ($arb.Height + 140), -60
$fieldBody = Layers (L $arb 10)
# shadow lands on the 1x1 foundation (checked on fit_SCPARBD.png); taller canvas first, or the shift is clipped away
$fieldShad = Layers (L ([ScZerg]::Shifted([ScZerg]::Crop($arb, $arb.Width, $arb.Height + 200), 62)) 10 $true)
$field = $fieldShape.Building($fieldBody, $fieldShad, $map, $dmgMap)
$files['SCPARBD.SHP'] = $field.Write()
[ScBuildings]::FitPreview($field, 0, 2, $fieldShape, $unitPal, 2, "$PreviewDir\fit_SCPARBD.png")
"SCPARBD field 1x1 canvas {0}x{1}" -f $fieldShape.Cw, $fieldShape.Ch
[Pal]::Sheet($cameoFrames, [int[]](0..($cameoFrames.Count - 1)), 64, 48, $cameoPal, 3, 8, "$PreviewDir\cameos.png")

# Psionic Storm animation (warhead AnimList of the High Templar), unit palette (AltPalette=yes), translucent in Art.ini
$storm = G 'thingy/psistorm'
$stormFrames = New-Object 'System.Collections.Generic.List[Frame]'
foreach ($f in $storm.Frames) { $stormFrames.Add($f) }
$stormShp = [ScBuild]::BuildAnim($stormFrames, $storm.Width, $storm.Height, $map)
$files['SCPSTORM.SHP'] = $stormShp.Write()
[Pal]::Sheet($stormShp.Frames, [int[]](0..([Math]::Min(13, $stormShp.Frames.Count - 1))), $stormShp.Width, $stormShp.Height, $unitPal, 1, 7, "$PreviewDir\storm.png")

# sounds (SD WAV -> AUD). Attack sounds from SC's iscript: Zealot pzeHit00, Dark Templar Bullet\UZeFir00, Dragoon bullet
# Bullet\DragBull, Photon Cannon Bullet\PhoFir00, Psionic Storm = the High Templar's PTeSto00, Probe mining PPrMin00.
$sounds = [ordered]@{
    SCPZWHT0 = 'protoss/zealot/pzewht00'; SCPZWHT1 = 'protoss/zealot/pzewht01'; SCPZWHT2 = 'protoss/zealot/pzewht02'; SCPZWHT3 = 'protoss/zealot/pzewht03'
    SCPZYES0 = 'protoss/zealot/pzeyes00'; SCPZYES1 = 'protoss/zealot/pzeyes01'; SCPZYES2 = 'protoss/zealot/pzeyes02'; SCPZYES3 = 'protoss/zealot/pzeyes03'
    SCPZDTH  = 'protoss/zealot/pzedth00'; SCPZATK  = 'protoss/zealot/pzehit00'
    SCPDWHT0 = 'protoss/dragoon/pdrwht00'; SCPDWHT1 = 'protoss/dragoon/pdrwht01'; SCPDWHT2 = 'protoss/dragoon/pdrwht02'; SCPDWHT3 = 'protoss/dragoon/pdrwht03'
    SCPDYES0 = 'protoss/dragoon/pdryes00'; SCPDYES1 = 'protoss/dragoon/pdryes01'; SCPDYES2 = 'protoss/dragoon/pdryes02'; SCPDYES3 = 'protoss/dragoon/pdryes03'
    SCPDDTH  = 'protoss/dragoon/pdrdth00'; SCPDFIR  = 'bullet/dragbull'
    SCPHWHT0 = 'protoss/templar/ptewht00'; SCPHWHT1 = 'protoss/templar/ptewht01'; SCPHWHT2 = 'protoss/templar/ptewht02'; SCPHWHT3 = 'protoss/templar/ptewht03'
    SCPHYES0 = 'protoss/templar/pteyes00'; SCPHYES1 = 'protoss/templar/pteyes01'; SCPHYES2 = 'protoss/templar/pteyes02'; SCPHYES3 = 'protoss/templar/pteyes03'
    SCPHDTH  = 'protoss/templar/ptedth00'; SCPHSTO  = 'protoss/templar/ptesto00'
    SCPKWHT0 = 'protoss/darktemplar/pdtwht00'; SCPKWHT1 = 'protoss/darktemplar/pdtwht01'; SCPKWHT2 = 'protoss/darktemplar/pdtwht02'; SCPKWHT3 = 'protoss/darktemplar/pdtwht03'
    SCPKYES0 = 'protoss/darktemplar/pdtyes00'; SCPKYES1 = 'protoss/darktemplar/pdtyes01'; SCPKYES2 = 'protoss/darktemplar/pdtyes02'; SCPKYES3 = 'protoss/darktemplar/pdtyes03'
    SCPKDTH  = 'protoss/darktemplar/pdtdth00'; SCPKATK  = 'bullet/uzefir00'
    SCPPWHT0 = 'protoss/probe/pprwht00'; SCPPWHT1 = 'protoss/probe/pprwht01'; SCPPWHT2 = 'protoss/probe/pprwht02'; SCPPWHT3 = 'protoss/probe/pprwht03'
    SCPPYES0 = 'protoss/probe/ppryes00'; SCPPYES1 = 'protoss/probe/ppryes01'; SCPPYES2 = 'protoss/probe/ppryes02'; SCPPYES3 = 'protoss/probe/ppryes03'
    SCPPDTH  = 'protoss/probe/pprdth00'; SCPPMIN  = 'protoss/probe/pprmin00'
    SCPBPLC  = 'misc/pbldgplc'; SCPCFIR  = 'bullet/phofir00'
    # full faction (2026-10-25). Attack sounds from SC's iscript: Archon/Dark Archon Bullet\PArFir00, Reaver Bullet\pTrFir00,
    # Scout ground Bullet\BlastGn2 + air Bullet\HKMISSLE, Corsair Protoss\Corsair\PCorlasr2, Arbiter Bullet\DragBull (= SCPDFIR);
    # Carrier interceptors have no sound of their own in the Carrier's script: Bullet\BlastCan. No death voice: Dark Archon,
    # Corsair (SC uses the explosion), so they borrow the Archon's / Scout's.
    SCPAWHT0 = 'protoss/archon/parwht00'; SCPAWHT1 = 'protoss/archon/parwht01'; SCPAWHT2 = 'protoss/archon/parwht02'; SCPAWHT3 = 'protoss/archon/parwht03'
    SCPAYES0 = 'protoss/archon/paryes00'; SCPAYES1 = 'protoss/archon/paryes01'; SCPAYES2 = 'protoss/archon/paryes02'; SCPAYES3 = 'protoss/archon/paryes03'
    SCPADTH  = 'protoss/archon/pardth00'; SCPAFIR  = 'bullet/parfir00'
    SCPXWHT0 = 'protoss/darchon/pdawht00'; SCPXWHT1 = 'protoss/darchon/pdawht01'; SCPXWHT2 = 'protoss/darchon/pdawht02'; SCPXWHT3 = 'protoss/darchon/pdawht03'
    SCPXYES0 = 'protoss/darchon/pdayes00'; SCPXYES1 = 'protoss/darchon/pdayes01'; SCPXYES2 = 'protoss/darchon/pdayes02'; SCPXYES3 = 'protoss/darchon/pdayes03'
    SCPXFIR  = 'protoss/darchon/feedback'
    SCPRWHT0 = 'protoss/trilobyte/ptrwht00'; SCPRWHT1 = 'protoss/trilobyte/ptrwht01'; SCPRWHT2 = 'protoss/trilobyte/ptrwht02'; SCPRWHT3 = 'protoss/trilobyte/ptrwht03'
    SCPRYES0 = 'protoss/trilobyte/ptryes00'; SCPRYES1 = 'protoss/trilobyte/ptryes01'; SCPRYES2 = 'protoss/trilobyte/ptryes02'; SCPRYES3 = 'protoss/trilobyte/ptryes03'
    SCPRDTH  = 'protoss/trilobyte/ptrdth00'; SCPRFIR  = 'bullet/ptrfir00'; SCPRFIR1 = 'bullet/ptrfir01'; SCPSAHIT = 'bullet/psahit00'
    SCPUWHT0 = 'protoss/shuttle/pshwht00'; SCPUWHT1 = 'protoss/shuttle/pshwht01'; SCPUWHT2 = 'protoss/shuttle/pshwht02'; SCPUWHT3 = 'protoss/shuttle/pshwht03'
    SCPUYES0 = 'protoss/shuttle/pshyes00'; SCPUYES1 = 'protoss/shuttle/pshyes01'; SCPUYES2 = 'protoss/shuttle/pshyes02'; SCPUYES3 = 'protoss/shuttle/pshyes03'
    SCPUDTH  = 'protoss/shuttle/pshdth00'
    SCPOWHT0 = 'protoss/witness/pwiwht00'; SCPOWHT1 = 'protoss/witness/pwiwht01'; SCPOYES0 = 'protoss/witness/pwiyes00'; SCPOYES1 = 'protoss/witness/pwiyes01'
    SCPODTH  = 'protoss/witness/pwidth00'
    SCPSWHT0 = 'protoss/scout/pscwht00'; SCPSWHT1 = 'protoss/scout/pscwht01'; SCPSWHT2 = 'protoss/scout/pscwht02'; SCPSWHT3 = 'protoss/scout/pscwht03'
    SCPSYES0 = 'protoss/scout/pscyes00'; SCPSYES1 = 'protoss/scout/pscyes01'; SCPSYES2 = 'protoss/scout/pscyes02'; SCPSYES3 = 'protoss/scout/pscyes03'
    SCPSDTH  = 'protoss/scout/pscdth00'; SCPSFIR  = 'bullet/blastgn2'; SCPSMIS  = 'bullet/hkmissle'
    SCPCWHT0 = 'protoss/corsair/pcowht00'; SCPCWHT1 = 'protoss/corsair/pcowht01'; SCPCWHT2 = 'protoss/corsair/pcowht02'; SCPCWHT3 = 'protoss/corsair/pcowht03'
    SCPCYES0 = 'protoss/corsair/pcoyes00'; SCPCYES1 = 'protoss/corsair/pcoyes01'; SCPCYES2 = 'protoss/corsair/pcoyes02'; SCPCYES3 = 'protoss/corsair/pcoyes03'
    SCPCOLAS = 'protoss/corsair/pcorlasr2'
    SCPVWHT0 = 'protoss/carrier/pcawht00'; SCPVWHT1 = 'protoss/carrier/pcawht01'; SCPVWHT2 = 'protoss/carrier/pcawht02'; SCPVWHT3 = 'protoss/carrier/pcawht03'
    SCPVYES0 = 'protoss/carrier/pcayes00'; SCPVYES1 = 'protoss/carrier/pcayes01'; SCPVYES2 = 'protoss/carrier/pcayes02'; SCPVYES3 = 'protoss/carrier/pcayes03'
    SCPVDTH  = 'protoss/carrier/pcadth00'; SCPVFIR  = 'bullet/blastcan'
    SCPBWHT0 = 'protoss/arbiter/pabwht00'; SCPBWHT1 = 'protoss/arbiter/pabwht01'; SCPBWHT2 = 'protoss/arbiter/pabwht02'; SCPBWHT3 = 'protoss/arbiter/pabwht03'
    SCPBYES0 = 'protoss/arbiter/pabyes00'; SCPBYES1 = 'protoss/arbiter/pabyes01'; SCPBYES2 = 'protoss/arbiter/pabyes02'; SCPBYES3 = 'protoss/arbiter/pabyes03'
    SCPBDTH  = 'protoss/arbiter/pabdth00'
}
foreach ($k in $sounds.Keys) {
    $rate = 0
    $pcm = [Aud]::ReadWav($casc.ReadFile("SD/sound/$($sounds[$k]).wav"), [ref]$rate)
    $files["$k.AUD"] = [Aud]::Encode($pcm, $rate, 1.0)
}

$out = if ($OutMix) { $OutMix } else { "$game\MIX\ECACHE85.MIX" }
if ($OutMix -and $Install) { throw "-OutMix builds elsewhere; -Install needs the real MIX/ECACHE85.MIX" }
[Mix]::Write($out, $files)
$check = New-Object Mix $out
foreach ($k in $files.Keys) { if ($k.EndsWith('.SHP') -and ([Shp]::Read($check.Read($k))).Frames.Count -eq 0) { throw "bad $k" } }
"ECACHE85.MIX: $($files.Count) files, $([Math]::Round((Get-Item $out).Length / 1KB)) KB, round-trip OK; previews -> $PreviewDir"
if (-not $Install) { return }

# ------------------------------------------------------------------ INI side
$latin = [Text.Encoding]::GetEncoding(28591)
$begin = '; >>> Protoss faction'; $end = '; <<< Protoss faction'

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

# removes a house from the Owner= of one section
function Remove-Owner([string]$path, [string]$section, [string]$house) {
    $t = [IO.File]::ReadAllText($path, $latin)
    $a = $t.IndexOf("[$section]"); if ($a -lt 0) { return }
    $z = $t.IndexOf("`n[", $a + 1); if ($z -lt 0) { $z = $t.Length }
    $sec = $t.Substring($a, $z - $a)
    $sec = [regex]::Replace($sec, "(?m)^(Owner=[^\r\n]*?),$house\b", '$1')
    $sec = [regex]::Replace($sec, "(?m)^Owner=$house,", 'Owner=')
    [IO.File]::WriteAllText($path, $t.Substring(0, $a) + $sec + $t.Substring($z), $latin)
}

function Backup([string]$path) { if (-not (Test-Path "$path.bak")) { Copy-Item $path "$path.bak" } }
function Nl([string]$path) { if ([IO.File]::ReadAllText($path, $latin).Contains("`r`n")) { "`r`n" } else { "`n" } }

# ---- faction file (appended to skirmish maps by MPMaps.ini MapCodeININame; the client takes one file, so Protoss shares it)
$fac = "$game\INI\Map Code\Terran Faction.ini"; Backup $fac; $nl = Nl $fac
# [Sides] order = side index: TerranSide 6, ZergSide 7, ProtossSide 8 (both lines rewritten together to keep the order)
Set-SectionEntries $fac 'Sides' @('ZergSide=Nod1	; Zerg faction: side index 7 (block at the end)', 'ProtossSide=GDI2	; Protoss faction: side index 8 (block at the end)') '^(ZergSide|ProtossSide)=' $nl
$t = [IO.File]::ReadAllText($fac, $latin)
$t = [regex]::Replace($t, '(?m)^(BaseUnit=[^\r\n;]*?)(,SCPDNEX)?(,GMCV)', '$1,SCPDNEX$3')
$t = [regex]::Replace($t, '(?m)^(HarvesterUnit=[^\r\n;\t ]*?)(,SCPPROBE)?(?=[\t ;]|\r?$)', '$1,SCPPROBE')
[IO.File]::WriteAllText($fac, $t, $latin)
$vt = @('PRV01=SCPPROBE	; Protoss faction (block at the end)', 'PRV02=SCPDNEX') + ((@($Vehicles) + @($units | Where-Object { -not $_.Inf })) | ForEach-Object -Begin { $n = 3 } -Process { 'PRV{0:D2}={1}' -f $n, $_.Id; $n++ })
Set-SectionEntries $fac 'VehicleTypes' $vt '^PRV\d+=' $nl
# GDI2 owned a few helper types in Rules (missions); in skirmish they would show up for Protoss
foreach ($s in 'TDPROC', 'TDPROC_AI', 'DEPCARR') { Remove-Owner $fac $s 'GDI2' }

# Gateway infantry (Zealot, Dragoon, High and Dark Templar)
$infCommon = @"
Category=Soldier
Locomotor={4A582744-9839-11d1-B709-00A024DDAFD1}
MovementZone=Infantry
Owner=GDI2
Fearless=yes
NotHuman=yes
Crushable=no
SelfHealing=yes	; plasma shields recharge
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
# Archon and Dark Archon: SHP vehicles warped in next to the Robotics Facility (Naval=yes + BuiltAt, Vinifera naval-yard exit)
$archonCommon = @"
Category=AFV
SpeedType=Track
Locomotor={4A582741-9839-11d1-B709-00A024DDAFD1}
MovementZone=Normal
SlowdownDistance=1
AccelerationFactor=1
Weight=1
ROT=16
Owner=GDI2
Naval=yes	; warped in next to the Robotics Facility (Vinifera naval-yard exit), see [SCPROB]
BuiltAt=SCPROB
Crusher=no
SelfHealing=yes	; plasma shields recharge
Crewed=no
Trainable=yes
AllowedToStartInMultiplayer=no
ImmuneToVeins=yes
VeteranAbilities=STRONGER,FASTER
EliteAbilities=SELF_HEAL,ROF
VoiceFeedback=
MaxDebris=0
CanShakeScreen=false
Totable=false
"@
$probeKeys = @"
Category=Support
Strength=800
Armor=medium
Sight=6
Speed=9
ROT=12
Owner=GDI2
Crusher=no
Crewed=no
SelfHealing=yes
Naval=yes	; warped in at the Robotics Facility (Vinifera naval-yard exit: appears next to it)
BuiltAt=SCPROB
SpeedType=Track
Locomotor={4A582741-9839-11d1-B709-00A024DDAFD1}
MovementZone=Normal
SlowdownDistance=1
AccelerationFactor=1
Weight=1
Explosion=SCPPDTHX	; explosion anim with the SC death sound (vehicles ignore DieSound)
ScrapExplosion=SCPPDTHX
MaxDebris=0
VoiceSelect=SCPPWHT0,SCPPWHT1,SCPPWHT2,SCPPWHT3
VoiceMove=SCPPYES0,SCPPYES1,SCPPYES2,SCPPYES3
VoiceAttack=SCPPYES0,SCPPYES1,SCPPYES2,SCPPYES3
VoiceFeedback=
ThreatPosed=0
CanShakeScreen=false
Totable=false
"@
$bldg = @"
TechLevel=1
Owner=GDI2
Capturable=false
Crewed=no
Explosion=FBALL1,FBALL2,FBALL3
ScrapExplosion=FBALL1,FBALL2,FBALL3
MaxDebris=0
AIBuildThis=no
SelfHealing=yes	; plasma shields recharge (SC buildings have shields too)
"@
# Psionic matrix glow (user 2026-10-26): Nexus and Pylon light the ground light blue like DTA's lamp posts ([BLUELAMP]: tints
# 0.005/0.005/0.35, intensity 0.01). LightVisibility (leptons, 256 per cell) is set per building. The light fades linearly to
# zero at that radius, so it is ~1.3x the distance to the build-range edge (user 2026-10-26: "nie dochodzi do granicy").
# The build range is a square, the light a circle: the square's corners stay dimmer. No Powered=, so it stays on in low power.
$matrixLight = @"
LightIntensity=0.05
LightRedTint=0.03
LightGreenTint=0.18
LightBlueTint=0.45
"@
# Shield regeneration. Vinifera self-heal (TechnoClassExt::_Should_Self_Heal_Now + hook 0x0062E9EF): heals while
# health < SelfHealingCap (default Rules ConditionYellow = 50%, the "only to half" the user saw), every SelfHealingRate
# minutes (default RepairRate .016 = ~14 ticks), SelfHealingStep HP (default only 1 HP: invisible on 3000+ HP units).
# Protoss: back to FULL, 0.5% of Strength per step for units (~45 s from zero at 60 FPS), 0.25% for buildings.
function Add-ShieldRegen([string]$text) {
    $parts = [regex]::Split($text, '(?m)(?=^\[)')
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $p = $parts[$i]
        if ($p -notmatch '(?m)^SelfHealing=yes' -or $p -notmatch '(?m)^Strength=(\d+)') { continue }
        $hp = [int]$Matches[1]
        $isBuilding = $p -match '(?m)^(Foundation|Factory|Power|BaseNormal)='
        $step = [Math]::Max(1, [int][Math]::Round($hp * $(if ($isBuilding) { 0.0025 } else { 0.005 })))
        $parts[$i] = $p.TrimEnd() + "`nSelfHealingCap=1.0`t; shields: regenerate to full (Vinifera)`nSelfHealingStep=$step`n`n"
    }
    return ($parts -join '')
}
# Robotics / Stargate units: SHP vehicles appearing next to their factory (Vinifera naval-yard exit, Starport pattern)
$vehCommon = @"
Owner=GDI2
Crusher=no
Crewed=no
SelfHealing=yes	; plasma shields recharge
Naval=yes	; built only at the factory in BuiltAt= (naval-yard exit: appears next to it)
Trainable=yes
VeteranAbilities=STRONGER,FASTER
EliteAbilities=SELF_HEAL,ROF
AllowedToStartInMultiplayer=no
CanShakeScreen=false
Totable=false
VoiceFeedback=
MaxDebris=0
"@
# "hover" like DTA's hovercraft [HVC]/[HVCSAM]: drive locomotor at ground height, SpeedType=Hover, MovementZone=Fly (land + water)
$hoverKeys = @"
Category=AFV
SpeedType=Hover
Locomotor={4A582741-9839-11d1-B709-00A024DDAFD1}
MovementZone=Fly
SlowdownDistance=1
AccelerationFactor=1
Weight=3
"@
$groundKeys = @"
Category=AFV
SpeedType=Track
Locomotor={4A582741-9839-11d1-B709-00A024DDAFD1}
MovementZone=Normal
SlowdownDistance=1
AccelerationFactor=1
Weight=3
"@
# Fly locomotor like the Terran warships and Zerg flyers (game.exe patch-flyhover.ps1: they hover instead of landing)
$flyKeys = @"
Category=AFV
Locomotor={4A582746-9839-11d1-B709-00A024DDAFD1}
MovementZone=Fly
FlightLevel=450
"@
function Voices($c, $n) { $sel = (0..($n - 1) | % { "SCP$($c)WHT$_" }) -join ','; $yes = (0..($n - 1) | % { "SCP$($c)YES$_" }) -join ','; return "VoiceSelect=$sel`nVoiceMove=$yes`nVoiceAttack=$yes" }
# Id, Name, Description (<= 199 chars, Vinifera), Prerequisite, BuiltAt, Primary, Secondary, HP, Armor, TechLevel (<= 7: the
# lobby's tech level 7 hides 8+; Carrier and Arbiter had 8 and never showed up, user test 2026-10-25), Sight, Speed, ROT, Cost,
# voices, death sound, fly, extra keys. The death sound plays through the Explosion anim <die>X (vehicles ignore DieSound=).
function VehSec($id, $name, $desc, $pre, $at, $pri, $sec, $hp, $armor, $tl, $sight, $speed, $rot, $cost, $vc, $vn, $die, $fly, $extra) {
    return "[$id]`nName=$name`nDescription=$desc`nPrerequisite=$pre`nBuiltAt=$at`n$(if ($pri) { "Primary=$pri`n" })$(if ($sec) { "Secondary=$sec`n" })" +
           "Strength=$hp`nArmor=$armor`nTechLevel=$tl`nSight=$sight`nSpeed=$speed`nROT=$rot`nCost=$cost`nPoints=$([int]($cost / 50) + 1)`n" +
           "ThreatPosed=$([int]($cost / 60))`n$(Voices $vc $vn)`nExplosion=$($die)X`nScrapExplosion=$($die)X`n$(if ("$fly" -eq 'hover') { $hoverKeys } elseif ($fly) { $flyKeys } else { $groundKeys })`n$vehCommon`n$extra`n"
}
$vehText  = VehSec 'SCPREAV' 'Reaver' 'Protoss siege crawler.@@Fires Scarabs as far as a sieged Siege Tank: huge splash damage, ground targets only.@@Very slow. Needs a Robotics Support Bay.' 'SCPROB,SCPRSB' 'SCPROB' 'SCPScarab' '' 3600 'heavy' 6 10 3 6 1600 'R' 4 'SCPRDTH' $false ''
$vehText += VehSec 'SCPSHUT' 'Shuttle' 'Protoss flying transport.@@Carries up to 8 infantry or vehicles. Stop it and they board it in the air. Unarmed.' 'SCPROB' 'SCPROB' '' '' 2800 'medium' 4 8 14 24 800 'U' 4 'SCPUDTH' $true "Passengers=8`nIsVehicleTransport=yes`t; 2026-10-27: vehicles may board (DTA game.exe key)`nPipScale=Passengers"
$vehText += VehSec 'SCPOBSV' 'Observer' 'Protoss flying scout.@@Permanently cloaked; sees far and reveals cloaked units. Unarmed.@@Needs an Observatory.' 'SCPROB,SCPOBS' 'SCPROB' '' '' 1200 'medium' 4 11 10 20 700 'O' 2 'SCPODTH' $true "Cloakable=yes`nSensors=yes`nSensorsSight=9"
$vehText += VehSec 'SCPSCOU' 'Scout' 'Protoss fighter.@@Photon blasters against ground, anti-matter missiles against air.' 'SCPSTG' 'SCPSTG' 'SCPScoutGround' 'SCPScoutAir' 5000 'medium' 5 9 16 24 2100 'S' 4 'SCPSDTH' $true ''
$vehText += VehSec 'SCPCORS' 'Corsair' 'Protoss air-superiority fighter.@@Neutron flares with splash, air targets only. Very fast.' 'SCPSTG' 'SCPSTG' 'SCPNeutron' '' 3600 'medium' 5 9 18 28 1400 'C' 4 'SCPSDTH' $true ''
# Carrier = DTA's [CARRIER]/[CARRTRUK] spawner mechanic (Vinifera SpawnManager): a Spawner=yes weapon launches Spawns=
# aircraft that attack, return and are rebuilt (SpawnRegenRate) when shot down. Spawned types must be AircraftTypes.
# death anims: Gateway units have their SC death frames (built above); the other vehicles get FBALL1 + their SC death sound
$vehDeath = @('SCPPDTH', 'SCPRDTH', 'SCPUDTH', 'SCPODTH', 'SCPSDTH', 'SCPVDTH', 'SCPBDTH')
$deathAnims = @($units | Where-Object { -not $_.Inf } | ForEach-Object { $_.DAnim }) + @($vehDeath | ForEach-Object { "$($_)X" })
$carrierKeys = "Spawns=SCPINTC`nSpawnsNumber=4`t; SC: 4, 8 with Carrier Capacity (upgraded Carrier, Protoss research)`nSpawnRegenRate=300`t; a lost interceptor is rebuilt after 300 frames`nSpawnReloadRate=60`nSpawnSpawnRate=15`nSpawnLogicRate=5`nMaxRandomSpawnOffset=15`nGuardRange=10"
$vehText += VehSec 'SCPCARR' 'Carrier' 'Protoss capital ship.@@Launches 4 Interceptors (8 after Carrier Capacity) against ground and air; lost ones are rebuilt.@@Slow. Needs a Fleet Beacon.' 'SCPSTG,SCPFLB' 'SCPSTG' 'SCPInterceptLauncher' '' 9000 'heavy' 7 11 7 10 3400 'V' 4 'SCPVDTH' $true $carrierKeys
$vehText += VehSec 'SCPARBI' 'Arbiter' 'Protoss support ship. Phase disruptor vs ground and air, reveals cloaked units.@@DEPLOY: hovers in place as a cloaking field that hides nearby allies; deploy again to fly.' 'SCPSTG,SCPTRB' 'SCPSTG' 'SCPArbiterGun' '' 7000 'heavy' 7 10 10 16 3200 'B' 4 'SCPBDTH' $true "Sensors=yes`nSensorsSight=8`nDeploysInto=SCPARBD`t; cloaking field (building with CloakGenerator=yes)"

# build range: only the Nexus and Pylons are "base" (BaseNormal=yes); Adjacent = how far from them a building may stand
$range = 'BaseNormal=no	; does not extend the build range (only Nexus and Pylons do)' + "`n" + 'Adjacent=6	; may stand up to 6 cells from a Nexus or Pylon (user: 8 -> 7 -> 6, to match the matrix light)'

$facText = @"
; =====================================================================================================================
; Protoss faction (2026-10-25; user: "zrob testowo protosow gdzie pylon jak i glowny budynek ma wyjatkowy zasieg
; budowania a pozostale budynki nie maja zasiegu", "zeby uzylo domu GDI ale ma byc osobna frakcja do wybrania",
; then "zrob cala frakcje protosow"): all 16 buildings and 16 units of Brood War. Tech tree as in SC, except: Probes come
; from the Robotics Facility (needs only a Pylon; a ConYard cannot also train units), Archons are warped in directly.
; Helper house GDI2 (house 8, a GDI helper used by missions only) becomes the playable "Protoss" in skirmish; side
; ProtossSide = side 8 -> SIDEC09.MIX / SIDENC09.MIX / SPEECH09.MIX (copies of GDI). Lobby: GameOptions.ini Sides=...,Protoss.
; BUILD RANGE: TS checks placement against the house's buildings with BaseNormal=yes, within the PLACED building's
; Adjacent= cells. Only the Nexus and Pylons have BaseNormal=yes; every other Protoss building has BaseNormal=no, so
; new buildings must go near a Nexus or Pylon (up to 6 cells; Pylons and Nexus up to 8, so Pylons can leapfrog).
; The area is a SQUARE: Vinifera's Passes_Proximity_Check (replaces game.exe 0x4762E4) scans the placed footprint grown by
; Adjacent+1 cells, i.e. up to Adjacent empty cells between it and the anchor. One range for all anchors (the placed
; building decides); per-anchor ranges would need a Vinifera.dll patch (user chose one range, 2026-10-26).
; Nexus = Construction Yard ([AI] BuildConst +SCPNEX; StarCraft.ini repeats the list and gets SCPNEX too).
; Start: "Probe: Nexus" (BaseUnit SCPDNEX) deploys into the Nexus. Probes (harvesters) come from the Robotics Facility
; (Vinifera naval-yard exit like the Starport) and one free with every Assimilator. Gateway trains the infantry below.
; Independent of the STARCRAFT checkbox. Graphics/sounds: MIX/ECACHE85.MIX (Modding/tools/build-scprotoss.ps1),
; art: Art.ini block "Protoss faction", sounds: Sound.ini [SoundList] 1400+.
; Scale like the other SC blocks: building HP = (SC HP + shields) x 8, unit HP = (HP + shields) x 20,
; cost = (minerals + 2 x gas) x 4. Wiki: Modding/wiki/mods/protoss-faction.md
; =====================================================================================================================

[ProtossSide]
UIColor=White
OptionsMenuTextColor=255,210,90
ScreenTextColor=255,210,90
ToolTipColor=RAGold
HoverHighlightColor=RAGold
RegularPowerPlant=SCPPYL
AdvancedPowerPlant=SCPPYL

[GDI2]
Name=Protoss
Suffix=PRT
Prefix=G
ActsLike=8
Multiplay=yes
Side=ProtossSide

[AI]
BuildConst=GFACT,NFACT,AFACT,SFACT,SCPNEX

; helper types GDI2 owns in Rules/Enhance (missions); not for the Protoss
[ASTRP]
Owner=Nod2,GDI

[AIA10]
Owner=GDI

[BuildingTypes]
PRB01=SCPNEX
PRB02=SCPPYL
PRB03=SCPASM
PRB04=SCPGAT
PRB05=SCPFOR
PRB06=SCPCAN
PRB07=SCPCYB
PRB08=SCPROB
PRB09=SCPARC
PRB10=SCPBAT
PRB11=SCPSTG
PRB12=SCPCIT
PRB13=SCPRSB
PRB14=SCPFLB
PRB15=SCPOBS
PRB16=SCPTRB
PRB17=SCPARBD

[AircraftTypes]
PRC01=SCPINTC

[InfantryTypes]
$(($units | Where-Object { $_.Inf } | ForEach-Object -Begin { $n = 1 } -Process { 'PRI{0:D2}={1}' -f $n, $_.Id; $n++ }) -join "`n")

[Animations]
PRA01=SCPSTORM
PRA02=SCPBATGL
PRA03=SCPBATTR
PRA04=SCPSCAEX
PRA05=SCPARCHH
PRA06=SCPDRHIT
$(($deathAnims | ForEach-Object -Begin { $n = 10 } -Process { 'PRA{0:D2}={1}' -f $n, $_; $n++ }) -join "`n")

; ---------------------------------------------------------------- buildings

[SCPNEX]
Name=Nexus
Description=Protoss nexus. Works as a Construction Yard and gives radar.@@Its psionic matrix lets buildings be warped in up to 6 cells away (Pylons do the same).@@Stores a little Tiberium.
Prerequisite=none
ConstructionYard=yes
Factory=BuildingType
Radar=yes
Storage=40
PipScale=Tiberium
Strength=16000
Armor=wood
Sight=9
Cost=1600
Points=100
Power=50
BaseNormal=yes	; extends the build range
Adjacent=8
Nominal=yes
TogglePower=no
ThreatPosed=0
DeploySound=SCPBPLC
$matrixLight
LightVisibility=3328	; 13 cells; the user matched the build range (2 + 7 cells from the centre) to the visible glow
$bldg

[SCPPYL]
Name=Pylon
Description=Protoss power and psionic matrix.@@Lots of power, stores Tiberium like a silo.@@Buildings must stand within 6 cells of a Pylon or Nexus; Pylons reach 8, so they extend the base.
Prerequisite=SCPNEX
Storage=100	; silo (user 2026-10-25), like the Terran Supply Depot
PipScale=Tiberium
Strength=4800
Armor=wood
Sight=6
Cost=400
Points=10
Power=100
BaseNormal=yes	; extends the build range
Adjacent=8
ThreatPosed=0
$matrixLight
LightVisibility=3072	; 12 cells; the user matched the build range (1 + 7 cells from the centre) to the visible glow
$bldg

[SCPASM]
Name=Assimilator
Description=Protoss refinery: Probes bring Tiberium, Ore and Gems here.@@Comes with a Probe.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPNEX
Refinery=yes
Bib=yes	; every DTA refinery has it: the harvester docks on the bib row of the foundation
FreeUnit=SCPPROBE
DockUnload=yes
Storage=200	; was 40 (user 2026-10-25: more resources in the Assimilator)
PipScale=Tiberium
Strength=7200
Armor=wood
Sight=5
Cost=400
Points=10
Power=-10
ThreatPosed=0
$range
$bldg

[SCPGAT]
Name=Gateway
Description=Protoss warp gate. Warps in Zealots, Dragoons, High Templar and Dark Templar.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPPYL
Factory=InfantryType
ExitCoord=0,0,0
GDIBarracks=yes
Strength=8000
Armor=wood
Sight=5
Cost=600
Points=15
Power=-20
ThreatPosed=0
$range
$bldg

[SCPFOR]
Name=Forge
Description=Protoss forge.@@Unlocks the Photon Cannon.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPPYL
Strength=8800
Armor=wood
Sight=5
Cost=600
Points=10
Power=-20
ThreatPosed=0
$range
$bldg

[SCPCAN]
Name=Photon Cannon
Description=Protoss defense. Hits ground and air targets and detects cloaked units.@@Needs power.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPFOR
Primary=SCPPhoton
Strength=3000
Armor=heavy
Sight=9
Cost=600
Points=6
Power=-20
Powered=yes
GuardRange=8
Sensors=yes
IsBaseDefense=yes
SortCameoAsBaseDefense=yes
HasStupidGuardMode=false
ThreatPosed=30
$range
$bldg

[SCPCYB]
Name=Cybernetics Core
Description=Protoss technology center.@@Unlocks the Dragoon, the Stargate and the Citadel of Adun.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPGAT
Strength=8800
Armor=wood
Sight=5
Cost=800
Points=10
Power=-20
ThreatPosed=0
$range
$bldg

[SCPROB]
Name=Robotics Facility
Description=Protoss robotics bay. Builds Probes, "Probe: Nexus", Shuttles, Reavers, Observers, Archons and Dark Archons next to it.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPPYL
Factory=UnitType
WeaponsFactory=yes
Naval=yes
ExclusiveFactory=yes	; only units with BuiltAt=SCPROB
Strength=8000
Armor=wood
Sight=5
Cost=800
Points=15
Power=-30
ThreatPosed=0
$range
$bldg

[SCPARC]
Name=Templar Archives
Description=Protoss psionic archives.@@Unlocks High and Dark Templar, Archon, Dark Archon and the Arbiter Tribunal.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPCIT
Strength=8000
Armor=wood
Sight=5
Cost=1600
Points=15
Power=-30
ThreatPosed=0
$range
$bldg

[SCPBAT]
Name=Shield Battery
Description=Protoss shield battery.@@Keeps releasing healing energy: heals all units and buildings within ~3 cells (enemies too).@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPGAT
Strength=3200
Armor=wood
Sight=5
Cost=400
Points=6
Power=-10
ThreatPosed=0
$range
$bldg

[SCPSTG]
Name=Stargate
Description=Protoss starship gate. Builds Scouts, Corsairs, Carriers and Arbiters; they appear next to it.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPCYB
Factory=UnitType
WeaponsFactory=yes
Naval=yes
ExclusiveFactory=yes	; only units with BuiltAt=SCPSTG
Strength=9600
Armor=wood
Sight=5
Cost=1800
Points=20
Power=-40
ThreatPosed=0
$range
$bldg

[SCPCIT]
Name=Citadel of Adun
Description=Protoss temple of the Templar.@@Unlocks the Templar Archives.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPCYB
Strength=7200
Armor=wood
Sight=5
Cost=1400
Points=15
Power=-30
ThreatPosed=0
$range
$bldg

[SCPRSB]
Name=Robotics Support Bay
Description=Protoss robotics workshop.@@Unlocks the Reaver.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPROB
Strength=7200
Armor=wood
Sight=5
Cost=1400
Points=15
Power=-30
ThreatPosed=0
$range
$bldg

[SCPFLB]
Name=Fleet Beacon
Description=Protoss fleet command.@@Unlocks the Carrier.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPSTG
Strength=8000
Armor=wood
Sight=5
Cost=2800
Points=20
Power=-30
ThreatPosed=0
$range
$bldg

[SCPOBS]
Name=Observatory
Description=Protoss observatory.@@Unlocks the Observer.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPROB
Strength=4000
Armor=wood
Sight=8
Cost=1000
Points=10
Power=-20
ThreatPosed=0
$range
$bldg

[SCPTRB]
Name=Arbiter Tribunal
Description=Protoss tribunal of the Arbiters.@@Unlocks the Arbiter.@@Must be placed near a Pylon or the Nexus.
Prerequisite=SCPARC,SCPSTG
Strength=8000
Armor=wood
Sight=5
Cost=2000
Points=20
Power=-40
ThreatPosed=0
$range
$bldg

; ---------------------------------------------------------------- Probes (SHP vehicles, Robotics Facility)

[SCPPROBE]
Name=Probe
Description=Protoss worker. Gathers Tiberium, Ore and Gems for the Assimilator.@@Warped in at the Robotics Facility. Shields recharge.
Prerequisite=SCPROB
Harvester=yes
Dock=SCPASM
Storage=13	; 10 +30% (user 2026-10-25: workers deliver 30% more; SCV and Zerg Drone in the "Worker capacity" blocks)
PipScale=Tiberium
ToProtect=yes
TechLevel=1
Cost=300
Points=10
AllowedToStartInMultiplayer=yes	; the game's starting units for Protoss are Probes
Trainable=yes
VoiceHarvest=SCPPMIN
$probeKeys

[SCPDNEX]
Name=Probe: Nexus
Description=Probe that warps in a Nexus.@@Move it where the new base should be and DEPLOY it: the Probe becomes a Nexus (Construction Yard).
Prerequisite=SCPPYL
DeploysInto=SCPNEX
TechLevel=1
Cost=1800
Points=20
AllowedToStartInMultiplayer=no
Trainable=no
$probeKeys

; ---------------------------------------------------------------- Robotics Facility and Stargate units (SHP vehicles)
; Reaver = ground vehicle; Shuttle, Observer, Scout, Corsair, Carrier, Arbiter = Fly locomotor (hover patch of game.exe).

$vehText
; Carrier Interceptor: spawned AircraftType (keys from DTA's [ORCAHORN]/[DLHORNET]). Every DTA aircraft is a voxel and TS has no
; known SHP aircraft, so it borrows the small voxel of the Drone Launcher Hornet (Image=ORCAHORNS) instead of SC's intercep.grp.
[SCPINTC]
Name=Interceptor
Image=ORCAHORNS
Primary=SCPInterBeam
TypeImmune=yes
Strength=800	; SC 40 HP + 40 shields x 10 (half the unit scale: there are 8 of them)
Category=AirPower
Armor=medium
TechLevel=-1
Owner=GDI2
Sight=0
RadarInvisible=no
Landable=yes	; needed to fly home: with Landable=no a returning Interceptor got no NavCom (spawnprobe.ps1, test 6) and hung at the target
; the flying Carrier is at Z 450 = FlightLevel of the Interceptor, so Vinifera's docking check (|dZ| < 20, same cell) matches on arrival
FlightLevel=450
MoveToShroud=yes
Speed=14	; movement exactly like DTA's working [ORCAHORN]/[DLHORNET] (test 4: Interceptors stalled the Carrier)
PitchAngle=10
RollAngle=20
PitchSpeed=.16
Cost=50
Points=2
ROT=5
Ammo=1	; one strike pass (Burst=2), then home, like the Hornet (Ammo=4 kept them circling; no new wave meanwhile)
PipScale=Ammo
Crewed=no
GuardRange=30
Explosion=VEH-HIT1RA
ScrapExplosion=VEH-HIT1RA
MaxDebris=0
Locomotor={4A582746-9839-11d1-B709-00A024DDAFD1}
MovementZone=Fly
ThreatPosed=5
AuxSound1=none
AuxSound2=none
Trainable=no
Spawned=yes
Insignificant=yes
Selectable=no
VeteranAbilities=STRONGER,FIREPOWER
EliteAbilities=STRONGER,FIREPOWER

; Arbiter deployed: a hovering cloaking field (CloakGenerator like Nod's [SGEN], no power needed); UndeploysInto = the flyer again
[SCPARBD]
Name=Arbiter (cloaking field)
Description=Deployed Arbiter: hides allied units and buildings nearby (6 cells) and keeps firing.@@Deploy again to fly.
UndeploysInto=SCPARBI
CloakGenerator=yes
CloakRadiusInCells=6
Primary=SCPArbiterGun
Strength=7000
Armor=heavy
TechLevel=-1	; only the Arbiter's deploy creates it
Owner=GDI2
Sight=10
Sensors=yes
Cost=3200
Points=40
Power=0
Capturable=false
Crewed=no
Unsellable=yes
BaseNormal=no
Explosion=FBALL1,FBALL2,FBALL3
ScrapExplosion=FBALL1,FBALL2,FBALL3
MaxDebris=0
GuardRange=7
HasStupidGuardMode=false
ThreatPosed=30
AIBuildThis=no

; ---------------------------------------------------------------- Gateway infantry
; HP = (SC HP + shields) x 20, damage about SC x 2.5, ROF about SC cooldown x 1.33, range about SC x 1.9.

[SCPZEAL]
Name=Zealot
Description=Protoss warrior.@@Psi blades cut through infantry, vehicles and buildings in melee.@@Shields recharge.
Prerequisite=SCPGAT
Primary=SCPPsiBlades
Strength=3200
Armor=none
TechLevel=1
Sight=6
Speed=9
Cost=400
Points=6
ThreatPosed=10
VoiceSelect=SCPZWHT0,SCPZWHT1,SCPZWHT2,SCPZWHT3
VoiceMove=SCPZYES0,SCPZYES1,SCPZYES2,SCPZYES3
VoiceAttack=SCPZYES0,SCPZYES1,SCPZYES2,SCPZYES3
VoiceDie=SCPZDTH
$infCommon

[SCPDRAG]
Name=Dragoon
Description=Protoss assault walker.@@Phase disruptor hits ground and air targets, strong against armor.@@Shields recharge. Needs a Cybernetics Core.
Prerequisite=SCPGAT,SCPCYB
Primary=SCPPhase
Strength=3600
Armor=medium
TechLevel=2
Sight=8
Speed=8
Cost=900
Points=12
ThreatPosed=20
VoiceSelect=SCPDWHT0,SCPDWHT1,SCPDWHT2,SCPDWHT3
VoiceMove=SCPDYES0,SCPDYES1,SCPDYES2,SCPDYES3
VoiceAttack=SCPDYES0,SCPDYES1,SCPDYES2,SCPDYES3
VoiceDie=SCPDDTH
$infCommon

[SCPHTMP]
Name=High Templar
Description=Protoss psionic master.@@Psionic Storm: a long-range storm that hurts everything in a wide area (spares your own units).@@Slow. Shields recharge. Needs Templar Archives.
Prerequisite=SCPGAT,SCPARC
Primary=SCPStorm
Strength=2400
Armor=none
TechLevel=5
Sight=9
Speed=5
Cost=1400
Points=20
ThreatPosed=25
VoiceSelect=SCPHWHT0,SCPHWHT1,SCPHWHT2,SCPHWHT3
VoiceMove=SCPHYES0,SCPHYES1,SCPHYES2,SCPHYES3
VoiceAttack=SCPHYES0,SCPHYES1,SCPHYES2,SCPHYES3
VoiceDie=SCPHDTH
$infCommon

[SCPDTMP]
Name=Dark Templar
Description=Protoss assassin.@@Permanently cloaked; warp blades deal huge melee damage.@@Shields recharge. Needs Templar Archives.
Prerequisite=SCPGAT,SCPARC
Primary=SCPWarpBlades
Cloakable=yes
Strength=2400
Armor=none
TechLevel=5
Sight=7
Speed=11
Cost=1300
Points=20
ThreatPosed=25
VoiceSelect=SCPKWHT0,SCPKWHT1,SCPKWHT2,SCPKWHT3
VoiceMove=SCPKYES0,SCPKYES1,SCPKYES2,SCPKYES3
VoiceAttack=SCPKYES0,SCPKYES1,SCPKYES2,SCPKYES3
VoiceDie=SCPKDTH
$infCommon

; in SC two High (Dark) Templar merge into an Archon (Dark Archon); TS cannot merge units, so the Robotics Facility makes them (vehicles)
[SCPARCH]
Name=Archon
Description=Protoss psionic giant (in SC two High Templar merge into it).@@Psionic shockwave with splash, ground and air. Huge shields.@@Robotics Facility, needs Templar Archives.
Prerequisite=SCPROB,SCPARC
Primary=SCPShockwave
Strength=21600	; 7200 +200% (user 2026-10-25)
Armor=medium
TechLevel=6
Sight=8
Speed=10
Cost=2800
Points=40
ThreatPosed=40
VoiceSelect=SCPAWHT0,SCPAWHT1,SCPAWHT2,SCPAWHT3
VoiceMove=SCPAYES0,SCPAYES1,SCPAYES2,SCPAYES3
VoiceAttack=SCPAYES0,SCPAYES1,SCPAYES2,SCPAYES3
Explosion=SCPADTHX
ScrapExplosion=SCPADTHX
$archonCommon

[SCPDARC]
Name=Dark Archon
Description=Protoss dark psionic giant (two Dark Templar in SC).@@Feedback/Maelstrom bolts: area damage that stuns vehicles (EMP). Ground and air.@@Robotics Facility, needs Templar Archives.
Prerequisite=SCPROB,SCPARC
Primary=SCPMaelstrom
Strength=4500
Armor=medium
TechLevel=6
Sight=9
Speed=10
Cost=2600
Points=40
ThreatPosed=40
VoiceSelect=SCPXWHT0,SCPXWHT1,SCPXWHT2,SCPXWHT3
VoiceMove=SCPXYES0,SCPXYES1,SCPXYES2,SCPXYES3
VoiceAttack=SCPXYES0,SCPXYES1,SCPXYES2,SCPXYES3
Explosion=SCPXDTHX
ScrapExplosion=SCPXDTHX
$archonCommon

; ---------------------------------------------------------------- weapons (damage x Modifier; listed armors x10 like SA)

; Dragoon / Arbiter phase disruptor bolt: SC bullet\dragbull.grp (art SCPDRBUL: AnimLow/AnimHigh/AnimRate, like DTA's PLASMORB).
; Homing (ROT) so it also reaches moving flyers; AA and AG.
[SCPDragBull]
Image=SCPDRBUL
AA=yes
AG=yes
ROT=12
Ranged=yes
Shadow=no

; "explosive" like SCPExplosiveWH, with the SC hit (thingy\HKexplod.grp)
[SCPPhaseWH]
CellSpread=0
Modifier.none=600%
Modifier.wood=700%
Modifier.light=800%
Modifier.medium=900%
Modifier.heavy=1000%
Modifier.concrete=500%
InfDeath=1
AnimList=SCPDRHIT
ProneDamage=100%

; SC Archon "Psionic Shockwave": 30 normal, splash, cooldown 20, range 2, ground and air
[SCPShockwave]
Damage=113	; 75 +50% (user 2026-10-25)
ROF=27
Range=3
Projectile=Invisible3
Speed=100
Warhead=SCPShockWH
Report=SCPAFIR

[SCPShockWH]
CellSpread=2	; splash (user test 3: was 1 / 50%)
PercentAtMax=0.8
AffectsAllies=no
Modifier.none=1000%
Modifier.wood=600%
Modifier.light=800%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
InfDeath=1
AnimList=SCPARCHH	; SC emsHit.grp (Psionic Shockwave hit)
ProneDamage=100%

; Dark Archon: spells only in SC (Feedback, Mind Control, Maelstrom = stun); here a psionic bolt with an EMP stun on vehicles
[SCPMaelstrom]
Damage=60
ROF=60
Range=8
Projectile=Invisible3
Speed=100
Warhead=SCPMaelstromWH
Report=SCPXFIR

[SCPMaelstromWH]
CellSpread=1.5
PercentAtMax=0.6
AffectsAllies=no
EMEffect=yes
Modifier.none=800%
Modifier.wood=800%
Modifier.light=800%
Modifier.medium=800%
Modifier.heavy=800%
Modifier.concrete=800%
InfDeath=1
AnimList=SCPSTORM
ProneDamage=100%

; SC Reaver "Scarab": 100 normal, splash, cooldown 60, ground only. Range = the Terran Siege Tank in Siege Mode
; (SCShockCan 20.4, user 2026-10-25). Launch sounds from SC's iscript: Bullet\pTrFir00 / pTrFir01.
[SCPScarab]
Damage=250
ROF=80
Range=20.4
Projectile=SCPScarabPr	; the Scarab crawls to the target (was hitscan Invisible, user test 4)
Speed=25
Warhead=SCPScarabWH
Report=SCPRFIR,SCPRFIR1

; Scarab: SC protoss\sapper.grp turned with its flight (art SCPSCARB: Rotates=yes, 32 facings); homing, low, ground only
[SCPScarabPr]
Image=SCPSCARB
AA=no
AG=yes
ROT=10
High=no
Shadow=no

[SCPScarabWH]
CellSpread=1.5
PercentAtMax=0.4
Modifier.none=1000%
Modifier.wood=600%
Modifier.light=800%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
Wall=yes
Wood=yes
InfDeath=2
AnimList=SCPSCAEX	; SC Scarab explosion (thingy\psaExplo.grp + Bullet\psaHit00)
ProneDamage=100%
Conventional=yes

; SC Scout: ground "Dual Photon Blasters" 8 normal, cooldown 30, range 4; air "Anti-matter Missiles" 14 x 2 explosive, cooldown 22, range 4
[SCPScoutGround]
Damage=20
ROF=40
Range=6
Projectile=Invisible
Speed=100
Warhead=SCPNormalWH
Report=SCPSFIR

[SCPScoutAir]
Damage=70
ROF=29
Range=7
Projectile=InvisibleAA
Speed=100
Warhead=SCPExplosiveWH
Report=SCPSMIS

; SC Corsair "Neutron Flare": 5 explosive, splash, cooldown 8, range 5, air only
[SCPNeutron]
Damage=17	; 13 +33% (user 2026-10-25)
ROF=11
Range=7
Projectile=InvisibleAA
Speed=100
Warhead=SCPNeutronWH
Report=SCPCOLAS

[SCPNeutronWH]
CellSpread=0.5
PercentAtMax=0.5
AffectsAllies=no
Modifier.none=600%
Modifier.wood=700%
Modifier.light=800%
Modifier.medium=900%
Modifier.heavy=1000%
Modifier.concrete=500%
InfDeath=1
AnimList=PIFF
ProneDamage=100%

; SC Carrier: launches Interceptors at targets up to 8 cells away (like DTA's HornetLauncher: Spawner=yes, OmniFire)
[SCPInterceptLauncher]
Damage=1
ROF=100
Range=12
Spawner=yes
Projectile=Invisible3	; AA too: the Carrier launches against aircraft and flyers as well
Speed=10
Warhead=Super
OmniFire=yes

; SC Interceptor: 6 normal, cooldown 30, range 4, ground and air. Timing like DTA's Hornet weapon [MiniMaverick]
; (Burst=2, ROF=3, Range=3.2, MinimumRange=1.5): one pass fires both shots, then the Interceptor flies home.
[SCPInterBeam]
Damage=30
Burst=2
ROF=3
Range=3.2
MinimumRange=1.5
Projectile=Invisible3
Speed=100
Warhead=SCPNormalWH
Report=SCPVFIR

; SC Arbiter "Phase Disruptor Cannon": 10 explosive, cooldown 45, range 5, ground and air
[SCPArbiterGun]
Damage=25
ROF=60
Range=7
Projectile=SCPDragBull	; visible SC phase disruptor bolt (was hitscan Invisible3)
Speed=40
Warhead=SCPPhaseWH
Report=SCPDFIR

; SC Zealot "Psi Blades": 8 x 2 normal, cooldown 22, melee
[SCPPsiBlades]
Damage=40
ROF=29
Range=1.75
Projectile=Invisible
Speed=100
Warhead=SCPNormalWH
Report=SCPZATK

; SC Dragoon "Phase Disruptor": 20 explosive, cooldown 30, range 4, ground and air
[SCPPhase]
Damage=50
ROF=40
Range=7.5
Projectile=SCPDragBull	; visible SC phase disruptor bolt (was hitscan Invisible3)
Speed=40
Warhead=SCPPhaseWH
Report=SCPDFIR

; SC Dark Templar "Warp Blades": 40 normal, cooldown 30, melee
[SCPWarpBlades]
Damage=100
ROF=40
Range=1.75
Projectile=Invisible
Speed=100
Warhead=SCPNormalWH
Report=SCPKATK

; SC High Templar "Psionic Storm" (a spell: 112 damage over time, 3x3 cells) as a slow, long-range area attack
[SCPStorm]
Damage=60
ROF=120
Range=9
Projectile=Invisible
Speed=100
Warhead=SCPStormWH
Report=SCPHSTO

; SC Photon Cannon "STS Photon Cannon": 20 normal, cooldown 22, range 7, ground and air
[SCPPhoton]
Damage=50
ROF=29
Range=8
Projectile=SCPPhotonBall	; blue SC ball (was hitscan Invisible3, user test 4)
Speed=40
Warhead=SCPNormalWH
Report=SCPCFIR

; Photon Cannon bolt: SC bullet\epbBul.grp (art SCPPHBUL: AnimLow/AnimHigh/AnimRate); homing, AA and AG
[SCPPhotonBall]
Image=SCPPHBUL
AA=yes
AG=yes
ROT=12
Ranged=yes
Shadow=no

; SC "normal" damage: hurts every armor about the same
[SCPNormalWH]
CellSpread=0
Modifier.none=1000%
Modifier.wood=600%
Modifier.light=800%
Modifier.medium=700%
Modifier.heavy=500%
Modifier.concrete=400%
InfDeath=1
AnimList=PIFF
ProneDamage=100%

; SC "explosive" damage: better against armor than against infantry
[SCPExplosiveWH]
CellSpread=0
Modifier.none=600%
Modifier.wood=700%
Modifier.light=800%
Modifier.medium=900%
Modifier.heavy=1000%
Modifier.concrete=500%
InfDeath=1
AnimList=PIFFPIFF
ProneDamage=100%

; Psionic Storm: same damage on every armor; AffectsAllies=no (Vinifera) spares own and allied units
[SCPStormWH]
CellSpread=2
PercentAtMax=1
AffectsAllies=no
Modifier.none=800%
Modifier.wood=800%
Modifier.light=800%
Modifier.medium=800%
Modifier.heavy=800%
Modifier.concrete=800%
InfDeath=1
AnimList=SCPSTORM
ProneDamage=100%

; ---------------------------------------------------------------- Shield Battery area heal (DTA's heal crate chain)
; DTA crate "Invulnerability" plays AREAHEAL: its TrailerAnim HEALINIT (Bouncer, Damage=1, Warhead=AreaHealWH) lands and
; the warhead's Particle=AreaHealSys spreads gas particles with Damage=-8 that heal whatever stands in them. Shield Battery:
; ActiveAnim SCPBATGL (glow, loops forever) drops a trailer SCPBATTR (= HEALINIT, Warhead=SCPBatWH) every TrailerSeperation
; frames -> SCPBatSys (3 cells, 300 frames) -> SCPBatPart, Damage=-40 (5x the crate: Protoss units have ~6x more HP).
; The gas heals everything in it, enemies too (like the crate).
[SCPBatWH]
CellSpread=0
Modifier.none=1%
Modifier.wood=1%
Modifier.medium=1%
Modifier.heavy=1%
InfDeath=0
Particle=SCPBatSys

[SCPBatSys]
HoldsWhat=SCPBatPart
Spawns=yes
SpawnFrames=3
SpawnRadius=768
Slowdown=0
ParticleCap=40
SpawnCutoff=100
SpawnTranslucencyCutoff=100
BehavesLike=Smoke
Lifetime=300

[SCPBatPart]
Image=MAGIHEAL
MaxDC=1
MaxEC=200
Translucency=75
Velocity=1.0
Deacc=.05
WindEffect=0
Damage=-40
Warhead=AreaHealWH
BehavesLike=Gas
DeleteOnStateLimit=no
StartStateAI=0
EndStateAI=13
StateAIAdvance=1

[ParticleSystems]
PRS01=SCPBatSys

[Particles]
PRQ01=SCPBatPart
"@
Set-Block $fac (Add-ShieldRegen $facText) $nl
"faction: Terran Faction.ini (block, [Sides], [General], [VehicleTypes], GDI2 off TDPROC/TDPROC_AI/DEPCARR)"
# Vinifera keeps 199 characters of Description= (TechnoTypeClassExtension::Description[200])
$t = [IO.File]::ReadAllText($fac, $latin); $a = $t.IndexOf($begin)
foreach ($ln in ($t.Substring($a) -split "`n")) { if ($ln -match '^Description=(.*)$' -and $Matches[1].TrimEnd("`r").Length -gt 199) { Write-Warning "Description too long ($($Matches[1].TrimEnd("`r").Length)): $($ln.Substring(0, 60))" } }

# ---- Art.ini
$art = "$game\INI\Art.ini"; Backup $art
$artBody = "; Protoss faction (TEST, 2026-10-25): MIX/ECACHE85.MIX from Modding/tools/build-scprotoss.ps1. Buildings: normal,`r`n" +
           "; damaged, 2 shadows; Buildup <ID>MK = warp-in (SC warp texture, the building solidifies). Probes: SHP vehicles,`r`n" +
           "; 32 facings. Infantry: 8 facings N,NW,W,SW,S,SE,E,NE.`r`n"
foreach ($b in $Bldgs) {
    # Height like the Terran buildings: 4x3 and 3x2 = 2 (Command Center/Nexus 3), 2x2 = 1.5
    $height = if ($b.Id -eq 'SCPNEX') { 3 } elseif ($b.Fw -eq 2) { 1.5 } else { 2 }
    $artBody += "`r`n[$($b.Id)]`r`nCameo=$($b.Id)IC`r`nFoundation=$($b.Fw)x$($b.Fh)`r`nHeight=$height`r`nRemapable=yes`r`nNewTheater=no`r`nBuildup=$($b.Id)MK`r`n"
    if ($b.Id -eq 'SCPBAT') { $artBody += "ActiveAnim=SCPBATGL`t; glow that keeps dropping heal pulses (see SCPBATGL below)`r`n" }
}
foreach ($d in 'SCPPROBE', 'SCPDNEX') {
    $artBody += "`r`n[$d]`r`nCameo=$($d)I`r`nVoxel=no`r`nRemapable=yes`r`nFacings=32`r`nStartStandFrame=0`r`nStandingFrames=1`r`nStartWalkFrame=32`r`nWalkFrames=1`r`nStartFiringFrame=64`r`nFiringFrames=2`r`n"
}
foreach ($u in $units) {
    if ($u.Inf) {
        # Gateway infantry: 8 facings, sequences from ScInfantry.Build (death frames inside the SHP)
        $lay = $layouts[$u.Id]
        $artBody += "`r`n[$($u.Id)]`r`nCameo=$($u.Id)I`r`nSequence=$($u.Id)Sequence`r`nRemapable=yes`r`nCrawls=no`r`nFireUp=$($u.FireFrame)`r`nFireProne=$($u.FireFrame)`r`nPrimaryFireFLH=$($u.Flh)`r`n"
        $artBody += "`r`n[$($u.Id)Sequence]`r`n" + ($lay.Sequence() -replace "`n", "`r`n")
        continue
    }
    # Archons: SHP vehicles (layout like the Robotics/Stargate units) + their SC death frames as Explosion anim
    $nw = $layouts[$u.Id]
    $artBody += "`r`n[$($u.Id)]`r`nCameo=$($u.Id)I`r`nVoxel=no`r`nRemapable=yes`r`nFacings=32`r`nStartStandFrame=0`r`nStandingFrames=1`r`nStartWalkFrame=32`r`nWalkFrames=$nw`r`nStartFiringFrame=$(32 + 32 * $nw)`r`nFiringFrames=2`r`nPrimaryFireFLH=$($u.Flh)`r`n"
    $artBody += "`r`n[$($u.DAnim)]`r`nNormalized=yes`r`nAltPalette=yes`r`nReport=$($u.DSnd)`r`n"
}
# the other vehicles: DTA's fireball with the SC death sound (the Terran [SCSCDTH] pattern)
foreach ($dd in $vehDeath) {
    $artBody += "`r`n[$($dd)X]`r`nImage=FBALL1`r`nNormalized=yes`r`nUseNormalLight=yes`r`nScorch=yes`r`nNext=SMOKE_M`r`nReport=$dd`r`n"
}
$artBody += "`r`n; Reaver Scarab explosion (SC thingy\psaExplo.grp)`r`n[SCPSCAEX]`r`nNormalized=yes`r`nAltPalette=yes`r`nReport=SCPSAHIT`r`n"
$artBody += "`r`n; Archon Psionic Shockwave hit (SC thingy\emsHit.grp)`r`n[SCPARCHH]`r`nNormalized=yes`r`nAltPalette=yes`r`nTranslucent=yes`r`n"
# Dragoon/Arbiter bolt: projectile art animates through its 5 frames (AnimLow/AnimHigh/AnimRate, DTA's PLASMORB pattern)
$artBody += "`r`n; Dragoon/Arbiter bolt (projectile art) and its hit`r`n[SCPDRBUL]`r`nAnimLow=0`r`nAnimHigh=4`r`nAnimRate=1`r`n`r`n[SCPDRHIT]`r`nNormalized=yes`r`nAltPalette=yes`r`n"
$artBody += "`r`n; Photon Cannon bolt (11 frames) and Reaver Scarab (32 facings, turns with its flight)`r`n[SCPPHBUL]`r`nAnimLow=0`r`nAnimHigh=10`r`nAnimRate=1`r`n`r`n[SCPSCARB]`r`nRotates=yes`r`n"
foreach ($ve in $Vehicles) {
    $nw = $vehLayout[$ve.Id]
    $artBody += "`r`n[$($ve.Id)]`r`nCameo=$($ve.Id)I`r`nVoxel=no`r`nRemapable=yes`r`nFacings=32`r`nStartStandFrame=0`r`nStandingFrames=1`r`nStartWalkFrame=32`r`nWalkFrames=$nw`r`nStartFiringFrame=$(32 + 32 * $nw)`r`nFiringFrames=2`r`nPrimaryFireFLH=$($ve.Flh)`r`nSecondaryFireFLH=$($ve.Flh)`r`n"
}
# Shield Battery heal: glow (ActiveAnim, endless loop) with a TrailerAnim like DTA's AREAHEAL crate anim; the trailer is
# a copy of DTA's [HEALINIT] (Image=HEALINIT) whose landing hits Warhead=SCPBatWH -> healing particle system SCPBatSys.
$artBody += "`r`n; Shield Battery glow + heal pulses (DTA heal crate chain, see SCPBatWH in the faction file)`r`n[SCPBATGL]`r`nLoopStart=0`r`nLoopEnd=4`r`nLoopCount=-1`r`nRate=200`r`nNormalized=yes`r`nAltPalette=yes`r`nTranslucent=yes`r`nTrailerAnim=SCPBATTR`r`nTrailerSeperation=60`r`n"
$artBody += "`r`n[SCPBATTR]`r`nImage=HEALINIT`r`nElasticity=0.0`r`nMinZVel=-1.0`r`nMaxXYVel=1.0`r`nExpireAnim=HEALONE`r`nDamage=1`r`nDamageRadius=1`r`nWarhead=SCPBatWH`r`nLoopStart=0`r`nLoopEnd=1`r`nLoopCount=-1`r`nRate=500`r`nBouncer=yes`r`n"
$artBody += "`r`n; deployed Arbiter (cloaking field): no Buildup, the flyer turns into it at once`r`n[SCPARBD]`r`nCameo=SCPARBII`r`nFoundation=1x1`r`nHeight=3`r`nRemapable=yes`r`nNewTheater=no`r`n"
$artBody += "`r`n; Psionic Storm (warhead SCPStormWH)`r`n[SCPSTORM]`r`nNormalized=yes`r`nRate=200`r`nAltPalette=yes`r`nTranslucent=yes`r`n"
Set-Block $art $artBody "`r`n"
"art: Art.ini block"

# ---- Sound.ini
$snd = "$game\INI\Sound.ini"; Backup $snd
$n = 1400; $list = @()
foreach ($k in $sounds.Keys) { $list += "$n=$k"; $n++ }
Set-SectionEntries $snd 'SoundList' $list '^1[45]\d\d=SCP' "`r`n"
$sndBody = "; Protoss faction: louder deaths, storms and blades`r`n"
foreach ($k in 'SCPZDTH', 'SCPDDTH', 'SCPHDTH', 'SCPKDTH', 'SCPPDTH', 'SCPADTH', 'SCPRDTH', 'SCPUDTH', 'SCPODTH', 'SCPSDTH', 'SCPVDTH', 'SCPBDTH') { $sndBody += "`r`n[$k]`r`nPriority=40`r`nRange=14`r`nLimit=4`r`n" }
$sndBody += "`r`n[SCPHSTO]`r`nPriority=60`r`nRange=18`r`nLimit=4`r`n`r`n[SCPZATK]`r`nLimit=6`r`n`r`n[SCPBPLC]`r`nPriority=30`r`nLimit=2`r`n"
Set-Block $snd $sndBody "`r`n"
"sound: Sound.ini [SoundList] 1400-$($n - 1)"

# ---- StarCraft.ini (STARCRAFT checkbox) repeats [AI] BuildConst after the faction file: the Nexus must stay in it
$sc = "$game\INI\Game Options\StarCraft.ini"; Backup $sc
$t = [IO.File]::ReadAllText($sc, $latin)
$t = [regex]::Replace($t, '(?m)^(BuildConst=[^\r\n;]*?)(,SCPNEX)?(\s*(;[^\r\n]*)?)$', '$1,SCPNEX$3')
[IO.File]::WriteAllText($sc, $t, $latin)
"StarCraft.ini: [AI] BuildConst +SCPNEX"

# ---- lobby: 9th side "Protoss" (index 8); every mode without the faction file must disallow it
$go = "$game\Resources\GameOptions.ini"; Backup $go
$t = [IO.File]::ReadAllText($go, $latin)
$t = [regex]::Replace($t, '(?m)^Sides=GDI,Nod,Allies,Soviet,Neutral,Special,Terran,Zerg(,Protoss)?', 'Sides=GDI,Nod,Allies,Soviet,Neutral,Special,Terran,Zerg,Protoss')
[IO.File]::WriteAllText($go, $t, $latin)
$mp = "$game\INI\MPMaps.ini"; Backup $mp
$t = [IO.File]::ReadAllText($mp, $latin)
$t = [regex]::Replace($t, '(?m)^DisallowedPlayerSides=4,5,6,7(,8)?(?=\s*$)', 'DisallowedPlayerSides=4,5,6,7,8')
[IO.File]::WriteAllText($mp, $t, $latin)
"lobby: GameOptions.ini Sides +Protoss, MPMaps.ini DisallowedPlayerSides 4,5,6,7 -> 4,5,6,7,8"

# ---- side files (side 8 -> file number 09), copied from GDI (side 0 -> 01); never overwrite
$copies = [ordered]@{ 'MIX\SideC01.mix' = 'MIX\SideC09.mix'; 'MIX\sidenc01.mix' = 'MIX\sidenc09.mix'; 'MIX\Speech01.mix' = 'MIX\Speech09.mix'
    'Resources\gdiicon.png' = 'Resources\protossicon.png'; 'Resources\l600s01.pcx' = 'Resources\l600s81.pcx'; 'Resources\l600s02.pcx' = 'Resources\l600s82.pcx'
    'Resources\l480s01.pcx' = 'Resources\l480s81.pcx'; 'Resources\l480s02.pcx' = 'Resources\l480s82.pcx' }
foreach ($k in $copies.Keys) { if (-not (Test-Path "$game\$($copies[$k])")) { Copy-Item "$game\$k" "$game\$($copies[$k])"; "copied $k -> $($copies[$k])" } }
"install done"
