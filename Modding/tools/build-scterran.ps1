# Builds the StarCraft Terran BUILDINGS for DTA from the user's StarCraft: Remastered install.
# Output: -OutMix (default <game>\MIX\ECACHE98.MIX: SHPs) and preview PNGs in -PreviewDir.
# Rules/Art for these files: INI/Game Options/StarCraft.ini and INI/Art.ini, blocks "StarCraft Terran buildings".
# Marine/units are built separately by build-scmarine.ps1 into ECACHE77.MIX (other session, do not merge).
param(
    [string]$StarCraft = "C:\Program Files (x86)\StarCraft",
    [string]$PreviewDir = "$env:TEMP\scterran-preview",
    [string]$OutMix = ""
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
if (-not $OutMix) { $OutMix = "$game\MIX\ECACHE98.MIX" }
Add-Type -Path "$tools\Casc.cs","$tools\ModTools.cs","$tools\ScBuild.cs","$tools\ScBuildings.cs" -ReferencedAssemblies System.Drawing
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
$map    = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)
$dmgMap = [ScBuildings]::DamageMap($map, $unitPal)

$grpCache = @{}
function G($name) {
    if (-not $name) { return $null }
    if (-not $grpCache.ContainsKey($name)) { $grpCache[$name] = [Grp]::Read($casc.ReadFile("unit/terran/$name.grp")) }
    return $grpCache[$name]
}
function Layers { $l = New-Object 'System.Collections.Generic.List[ScLayer]'; foreach ($a in $args) { if ($a) { $l.Add($a) } }; return ,$l }
function L($grp, $frame, $shadow = $false) { $g = G $grp; if (-not $g) { return $null }; return New-Object ScLayer $g, $frame, $shadow }

# Id, body GRP, completed frame, construction frame, top overlay (frame 0), shadow GRP, foundation, scaffold size, y adjust
# Shadow frame index = body frame index. Scaffold: lrg/med/sml = tbldlrg/tbldmed/tbldsml + tb2shad/tb1shad/tb3shad.
$B = @(
    @{ Id='SCCC';   Grp='control';  Done=0; Cons=1; Top='controlt'; Shad='tccshad'; Fw=4; Fh=3; Bld='lrg' }
    @{ Id='SCDEPO'; Grp='depot';    Done=0; Cons=1; Top='depott';   Shad='tdeshad'; Fw=3; Fh=2; Bld='med' }
    @{ Id='SCREFI'; Grp='refinery'; Done=0; Cons=1; Top='';         Shad='treshad'; Fw=4; Fh=3; Bld='lrg' }
    @{ Id='SCBARR'; Grp='tbarrack'; Done=0; Cons=1; Top='';         Shad='tbrshad'; Fw=4; Fh=3; Bld='lrg' }
    @{ Id='SCEBAY'; Grp='weaponpl'; Done=0; Cons=1; Top='weaponpt'; Shad='twpshad'; Fw=4; Fh=3; Bld='lrg' }
    @{ Id='SCMTUR'; Grp='missile';  Done=2; Cons=1; Top='';         Shad='tmishad'; Fw=2; Fh=2; Bld='sml'; Head='missilet' }
    @{ Id='SCACAD'; Grp='academy';  Done=0; Cons=1; Top='academyt'; Shad='tacshad'; Fw=3; Fh=2; Bld='med' }
    @{ Id='SCBUNK'; Grp='pillbox';  Done=0; Cons=1; Top='';         Shad='tpbshad'; Fw=3; Fh=2; Bld='med' }
    @{ Id='SCFACT'; Grp='factory';  Done=0; Cons=1; Top='factoryt'; Shad='tfashad'; Fw=4; Fh=3; Bld='lrg' }
    @{ Id='SCSTAR'; Grp='starport'; Done=0; Cons=1; Top='starpot';  Shad='tspshad'; Fw=4; Fh=3; Bld='lrg' }
    @{ Id='SCSCIF'; Grp='research'; Done=0; Cons=1; Top='researct'; Shad='trlshad'; Fw=4; Fh=3; Bld='lrg' }
    @{ Id='SCARMO'; Grp='chemlab';  Done=0; Cons=1; Top='chemlabt'; Shad='tclshad'; Fw=3; Fh=2; Bld='med' }
    @{ Id='SCCOMS'; Grp='comsat';   Done=0; Cons=1; Top='comsatt';  Shad='tcsshad'; Fw=2; Fh=2; Bld='sml' }
    # addons (standalone here): unlock units like SC research (Machine Shop -> Siege Tank, Control Tower -> air, ...)
    @{ Id='SCMSHP'; Grp='machines'; Done=0; Cons=1; Top='';         Shad='tmsshad'; Fw=2; Fh=2; Bld='sml' }
    @{ Id='SCCTWR'; Grp='drydocks'; Done=0; Cons=1; Top='drydockt'; Shad='tddshad'; Fw=2; Fh=2; Bld='sml' }
    @{ Id='SCPHYS'; Grp='physics';  Done=0; Cons=1; Top='';         Shad='tplshad'; Fw=2; Fh=2; Bld='sml' }
    @{ Id='SCCOVO'; Grp='genelab';  Done=0; Cons=1; Top='genelabt'; Shad='tglshad'; Fw=2; Fh=2; Bld='sml' }
    @{ Id='SCNUKE'; Grp='nukesilo'; Done=0; Cons=1; Top='nukesilt'; Shad='tnsshad'; Fw=2; Fh=2; Bld='sml'; Special=$true }
)
$scaffold = @{ lrg = @('tbldlrg','tb2shad'); med = @('tbldmed','tb1shad'); sml = @('tbldsml','tb3shad') }

$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$cameoFrames = New-Object 'System.Collections.Generic.List[Frame]'
foreach ($b in $B) {
    $sc = $scaffold[$b.Bld]
    $sizes = @($b.Grp, $b.Shad, $sc[0], $sc[1], $b.Top, $b.Head) | ? { $_ } | % { G $_ }
    $maxW = ($sizes | % { $_.Width } | Measure-Object -Maximum).Maximum
    $maxH = ($sizes | % { $_.Height } | Measure-Object -Maximum).Maximum
    $shape = New-Object ScBuildingShape $b.Fw, $b.Fh, $maxW, $maxH, 0

    $top = if ($b.Top) { L $b.Top 0 } else { $null }
    $body = Layers (L $b.Grp $b.Done) $top
    $shad = Layers (L $b.Shad $b.Done $true)
    $bldg = $shape.Building($body, $shad, $map, $dmgMap)

    $stages  = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[ScLayer]]'
    $shadows = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[ScLayer]]'
    foreach ($k in 0..2) { $stages.Add((Layers (L $sc[0] $k))); $shadows.Add((Layers (L $sc[1] $k $true))) }
    $stages.Add((Layers (L $b.Grp $b.Cons)));  $shadows.Add((Layers (L $b.Shad $b.Cons $true)))
    $stages.Add($body);                         $shadows.Add($shad)
    $mk = $shape.Buildup($stages, $shadows, [int[]](3,3,4,5,5), $map)

    $files["$($b.Id).SHP"]   = $bldg.Write()
    $files["$($b.Id)MK.SHP"] = $mk.Write()
    $cameoLayers = Layers (L $b.Grp $b.Done) $top
    if ($b.Head) {
        $files["$($b.Id)_A.SHP"] = $shape.Turret((G $b.Head), 0, $map).Write()
        $cameoLayers = Layers (L $b.Grp 0)
    }
    if ($b.Special) {
        # Silo doors for SpecialAnim/Two/Three (NukeSilo=yes waits for them before the missile launches), like RAMSLO_A:
        # 0-7 normal (closed, closed, open x4, closed x2), 8-15 damaged, then shadows. Open = construction frame (no lids).
        $open = Layers (L $b.Grp $b.Cons)
        $openShad = Layers (L $b.Shad $b.Cons $true)
        $seq = @($false, $false, $true, $true, $true, $true, $false, $false)
        $sa = New-Object Shp; $sa.Width = $shape.Cw; $sa.Height = $shape.Ch
        $saShad = New-Object 'System.Collections.Generic.List[Frame]'
        foreach ($dmg in $null, $dmgMap) { foreach ($o in $seq) {
            $sa.Frames.Add($shape.Compose($(if ($o) { $open } else { $body }), $map, $dmg, 3))
            $saShad.Add($shape.Compose($(if ($o) { $openShad } else { $shad }), $map, $null, 0))
        } }
        $sa.Frames.AddRange($saShad)
        $files["$($b.Id)_A.SHP"] = $sa.Write()
        [Pal]::Sheet($sa.Frames, [int[]](0..15), $shape.Cw, $shape.Ch, $unitPal, 1, 8, "$PreviewDir\special_$($b.Id).png")
    }
    $cameo = [ScBuildings]::Cameo($cameoLayers, $scPal, $ramp, $cameoPal)
    $files["$($b.Id)IC.SHP"] = $cameo.Write()
    $cameoFrames.Add($cameo.Frames[0])

    [ScBuildings]::FitPreview($bldg, 0, 2, $shape, $unitPal, 2, "$PreviewDir\fit_$($b.Id).png")
    [ScBuildings]::FitPreview($bldg, 1, -1, $shape, $unitPal, 2, "$PreviewDir\dmg_$($b.Id).png")
    [Pal]::Sheet($mk.Frames, [int[]](0,3,6,10,15), $shape.Cw, $shape.Ch, $unitPal, 1, 5, "$PreviewDir\mk_$($b.Id).png")
    "{0,-7} foundation {1}x{2} canvas {3}x{4}" -f $b.Id, $b.Fw, $b.Fh, $shape.Cw, $shape.Ch
}
# --- SCMCV: Terran construction tank (Siege Tank graphics, turret baked in) that deploys into SCCC, like DTA's MCVs.
# 0-31 stand, 32-127 walk (3 track phases per facing), 128-255 shadows. Turret position per body frame from tank.lol.
$tankLo = [ScVehicle]::ReadLo($casc.ReadFile('unit/terran/tank.lol'))
$mcv = [ScVehicle]::Build((G 'tank'), (G 'tankt'), $tankLo, (G 'ttashad'), $map, 3)
$files['SCMCV.SHP'] = $mcv.Write()
$camFrame = [ScVehicle]::Compose((G 'tank'), (G 'tankt'), $tankLo, 0, 11, [ScVehicle]::Identity())
$camGrp = [ScVehicle]::AsGrp($camFrame, (G 'tank').Width, (G 'tank').Height)
$mcvCameo = [ScBuildings]::Cameo((Layers (New-Object ScLayer $camGrp, 0, $false)), $scPal, $ramp, $cameoPal)
$files['SCMCVIC.SHP'] = $mcvCameo.Write()
$cameoFrames.Add($mcvCameo.Frames[0])
[Pal]::Sheet($mcv.Frames, [int[]](0,4,8,12,16,20,24,28 + 32,33,34 + 128,132,136), $mcv.Width, $mcv.Height, $unitPal, 2, 14, "$PreviewDir\mcv.png")
"SCMCV   vehicle {0} frames {1}x{2}" -f $mcv.Frames.Count, $mcv.Width, $mcv.Height

[Pal]::Sheet($cameoFrames, [int[]](0..($cameoFrames.Count-1)), 64, 48, $cameoPal, 2, 8, "$PreviewDir\cameos.png")

[Mix]::Write($OutMix, $files)
"$OutMix : $($files.Count) files"
# round-trip check
$check = New-Object Mix $OutMix
foreach ($k in $files.Keys) { $s = [Shp]::Read($check.Read($k)); if ($s.Frames.Count -eq 0) { throw "bad $k" } }
"round-trip OK; previews -> $PreviewDir"
