# StarCraft research (SC upgrades) for DTA: building upgrades placed on SC buildings (like GDI's Ion Cannon Uplink on the
# Comm Center) + one "upgraded" copy of each SC unit that requires the matching research (max 2 icons per unit).
# Writes: MIX/ECACHE87.MIX, block "StarCraft research" at the end of INI/Game Options/StarCraft.ini and INI/Art.ini
# (regenerated on every run), registration lines SCR*/SCX* in [BuildingTypes]/[VehicleTypes], Upgrades=N on parents.
# Base units are copied from the other sessions' blocks (resolving $Inherits and later patch sections); their
# sections are never modified, except one Upgrades= line per parent building.
param([string]$StarCraft = "C:\Program Files (x86)\StarCraft", [string]$PreviewDir = "$env:TEMP\scresearch-preview")
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs","$tools\ModTools.cs","$tools\ScBuild.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null
$latin1  = [Text.Encoding]::GetEncoding(28591)
$optPath = "$game\INI\Game Options\StarCraft.ini"
$artPath = "$game\INI\Art.ini"

# ------------------------------------------------------------------ research definitions (SC data: arr/upgrades.dat, techdata.dat)
$research = @(
  @{ Id='SCRINF'; Name='Infantry Weapons & Armor'; Parent='SCEBAY'; Icon=288; Cost=1200; Caption='INF. WEAPONS'; Text='Engineering Bay research.@@Upgraded Marine, Firebat, Ghost and Medic: +30% damage, +25% health.' }
  @{ Id='SCU238'; Name='U-238 Shells';             Parent='SCACAD'; Icon=238; Cost=1800; Caption='U-238 SHELLS'; Text='Academy research.@@Upgraded Marine: longer range.' }
  @{ Id='SCRCAD'; Name='Caduceus Reactor';         Parent='SCACAD'; Icon=384; Cost=1800; Caption='CADUCEUS';     Text='Academy research.@@Upgraded Medic: heals faster.' }
  @{ Id='SCROCU'; Name='Ocular Implants';          Parent='SCCOVO'; Icon=249; Cost=1200; Caption='OCULAR';       Text='Covert Ops research.@@Upgraded Ghost: sight and range.' }
  @{ Id='SCRVEH'; Name='Vehicle Weapons & Plating';Parent='SCARMO'; Icon=289; Cost=1200; Caption='VEH. WEAPONS'; Text='Armory research.@@Upgraded Vulture, Siege Tank and Goliath: +30% damage, +25% health.' }
  @{ Id='SCRSHP'; Name='Ship Weapons & Plating';   Parent='SCARMO'; Icon=290; Cost=1200; Caption='SHIP WEAPONS'; Text='Armory research.@@Upgraded Wraith, Valkyrie, Battlecruiser and Science Vessel: +30% damage, +25% health.' }
  @{ Id='SCRION'; Name='Ion Thrusters';            Parent='SCMSHP'; Icon=287; Cost=1200; Caption='ION THRUST';   Text='Machine Shop research.@@Upgraded Vulture: +50% speed.' }
  @{ Id='SCRCHA'; Name='Charon Boosters';          Parent='SCMSHP'; Icon=380; Cost=1200; Caption='CHARON';       Text='Machine Shop research.@@Upgraded Goliath: +3 range for Hellfire missiles.' }
  @{ Id='SCRCLK'; Name='Cloaking Field';           Parent='SCCTWR'; Icon=252; Cost=1800; Caption='CLOAKING';     Text='Control Tower research.@@Upgraded Wraith: cloaking.' }
  @{ Id='SCRCOL'; Name='Colossus Reactor';         Parent='SCPHYS'; Icon=285; Cost=1800; Caption='COLOSSUS';     Text='Physics Lab research.@@Upgraded Battlecruiser: Yamato Gun fires faster.' }
  @{ Id='SCRTIT'; Name='Titan Reactor';            Parent='SCSCIF'; Icon=248; Cost=1800; Caption='TITAN';        Text='Science Facility research.@@Upgraded Science Vessel: EMP Shockwave more often.' }
  @{ Id='SCRSPM'; Name='Spider Mines';             Parent='SCMSHP'; Icon=243; Cost=1200; Caption='SPIDER MINES'; Text='Machine Shop research.@@Upgraded Vultures carry 3 Spider Mines: Deploy the Vulture to lay a mine.' }
)

# Spider Mines only inside Vultures (user request): TS has no mine laying / initial payload, so the Upgraded Vulture
# DeploysInto a mine BUILDING (like DTA's land mine VMINE: cloaked, MineSuicide + MINEBOMB explosion) whose FreeUnit=
# (TS refinery mechanism) is the same Vulture with one mine less: 3 -> 2 -> 1 -> 0 mines. Mines cannot be bought.
$mineStages = @( @{ Mine='SCSPMB3'; Next='SCVULT2B' }, @{ Mine='SCSPMB2'; Next='SCVULT2C' }, @{ Mine='SCSPMB1'; Next='SCVULT2D' } )
$spiderMine = ''
foreach ($m in $mineStages) {
  $spiderMine += @"
[$($m.Mine)]
Name=Spider Mine
Description=Spider Mine laid by a Vulture.@@Cloaked; explodes when an enemy ground unit comes close.
Image=$($m.Mine)
Strength=100
Armor=none
TechLevel=-1
GuardRange=3
Repairable=false
Sight=3
Owner=GDI1
Capturable=false
Cost=25
Points=1
Power=0
Selectable=no
Crewed=no
Primary=MineSuicide
Explosion=MINEBOMB
ScrapExplosion=MINEBOMB
ThreatPosed=5
DamageParticleSystems=none
BaseNormal=no
WallOwner=no
TogglePower=no
Insignificant=yes
Sensors=yes
HasStupidGuardMode=false
Cloakable=yes
CloakingSpeed=0
FreeUnit=$($m.Next)
DeploySound=SCSPMIN0
AIBuildThis=no

"@
}

# ------------------------------------------------------------------ upgraded unit variants
# Mods: HP = Strength factor, Dmg = Damage factor (all weapons), plus optional per-weapon tweaks and extra keys.
$variants = @(
  @{ Base='SCFIRE';  Id='SCFIRE2';  Req='SCRINF';        HP=1.25; Dmg=1.3 }
  @{ Base='SCFIRES'; Id='SCFIRE2S'; Req='SCRINF';        HP=1.25; Dmg=1.3 }
  @{ Base='SCGHOST'; Id='SCGHOST2'; Req='SCRINF,SCROCU'; HP=1.25; Dmg=1.3; Sight=3; RangeX=1.15 }
  @{ Base='SCMEDIC'; Id='SCMEDIC2'; Req='SCRINF,SCRCAD'; HP=1.25; Dmg=1.0; RofX=0.7 }
  @{ Base='SCVULT';  Id='SCVULT2';  Req='SCRVEH,SCRION,SCRSPM'; HP=1.25; Dmg=1.3; SpeedX=1.5; Name='Vulture (Upgraded, 3 Spider Mines)'; Extra=@{ DeploysInto='SCSPMB3'; VoiceDeploy='SCSPMIN0' } }
  @{ Base='SCVULT';  Id='SCVULT2B'; Req='SCRVEH,SCRION,SCRSPM'; HP=1.25; Dmg=1.3; SpeedX=1.5; Name='Vulture (Upgraded, 2 Spider Mines)'; TechLevel='-1'; Extra=@{ DeploysInto='SCSPMB2'; VoiceDeploy='SCSPMIN0' } }
  @{ Base='SCVULT';  Id='SCVULT2C'; Req='SCRVEH,SCRION,SCRSPM'; HP=1.25; Dmg=1.3; SpeedX=1.5; Name='Vulture (Upgraded, 1 Spider Mine)'; TechLevel='-1'; Extra=@{ DeploysInto='SCSPMB1'; VoiceDeploy='SCSPMIN0' } }
  @{ Base='SCVULT';  Id='SCVULT2D'; Req='SCRVEH,SCRION,SCRSPM'; HP=1.25; Dmg=1.3; SpeedX=1.5; Name='Vulture (Upgraded, no mines)'; TechLevel='-1' }
  @{ Base='SCSIEGE'; Id='SCSIEGE2'; Req='SCRVEH';        HP=1.25; Dmg=1.3 }
  @{ Base='SCSIEGB'; Id='SCSIEGB2'; Req='SCRVEH';        HP=1.25; Dmg=1.3; Building=$true }
  @{ Base='SCGOLI';  Id='SCGOLI2';  Req='SCRVEH,SCRCHA'; HP=1.25; Dmg=1.3; SecRangeAdd=3 }
  @{ Base='SCWRAF';  Id='SCWRAF2';  Req='SCRSHP,SCRCLK'; HP=1.25; Dmg=1.3; Extra=@{ Cloakable='yes'; CloakingSpeed='5' } }
  @{ Base='SCVALF';  Id='SCVALF2';  Req='SCRSHP';        HP=1.25; Dmg=1.3 }
  @{ Base='SCBCF';   Id='SCBCF2';   Req='SCRSHP,SCRCOL'; HP=1.25; Dmg=1.3; SecRofX=0.6 }
  @{ Base='SCVESF';  Id='SCVESF2';  Req='SCRSHP,SCRTIT'; HP=1.25; Dmg=1.0; RofX=0.6 }
)
$idMap = @{}; foreach ($v in $variants) { if (-not $idMap.ContainsKey($v.Base)) { $idMap[$v.Base] = $v.Id } }
$parents = [ordered]@{}; foreach ($r in $research) { $parents[$r.Parent] = 1 + [int]$parents[$r.Parent] }

# ------------------------------------------------------------------ INI helpers (duplicate sections merge, later wins)
function Read-Ini([string[]]$lines) {
  $d = @{}; $order = @{}; $sec = $null
  foreach ($l in $lines) {
    if ($l -match '^\[([^\]]+)\]') { $sec = $matches[1]; if (-not $d.ContainsKey($sec)) { $d[$sec] = [ordered]@{} }; continue }
    if ($sec -and $l -match '^([^;=\s][^=]*?)\s*=\s*(.*)$') {
      $v = ($matches[2] -replace '\s*;.*$', '').Trim()
      $d[$sec][$matches[1].Trim()] = $v
    }
  }
  return $d
}
function Resolve-Sec($ini, [string]$name) {
  $chain = @(); $n = $name; $seen = @{}
  while ($n -and $ini.ContainsKey($n) -and -not $seen[$n]) { $seen[$n] = 1; $chain = ,$n + $chain; $n = $ini[$n]['$Inherits'] }
  $r = [ordered]@{}
  foreach ($c in $chain) { foreach ($k in $ini[$c].Keys) { if ($k -ne '$Inherits') { $r[$k] = $ini[$c][$k] } } }
  return $r
}
function Fmt-Num($x) { if ([math]::Abs($x - [math]::Round($x)) -lt 0.001) { return [string][int][math]::Round($x) } else { return ([math]::Round($x, 2)).ToString([Globalization.CultureInfo]::InvariantCulture) } }
function Num($s) { return [double]::Parse(($s -replace '%',''), [Globalization.CultureInfo]::InvariantCulture) }

$optLines = [IO.File]::ReadAllLines($optPath)
$beginMark = '; ===== StarCraft research (marine session) BEGIN: generated by Modding/tools/build-scresearch.ps1, do not edit by hand ====='
$endMark   = '; ===== StarCraft research END ====='
# strip our own previous block before reading the base definitions
$bi = [Array]::IndexOf($optLines, $beginMark); $ei = [Array]::IndexOf($optLines, $endMark)
if ($bi -ge 0 -and $ei -gt $bi) { $optLines = @($optLines[0..($bi-1)]) + @(if ($ei+1 -lt $optLines.Count) { $optLines[($ei+1)..($optLines.Count-1)] }) }
$opt = Read-Ini $optLines
$artText = [IO.File]::ReadAllText($artPath, $latin1)
$artBegin = $beginMark; $artEnd = $endMark
$abi = $artText.IndexOf($artBegin); $aei = $artText.IndexOf($artEnd)
if ($abi -ge 0 -and $aei -gt $abi) { $artText = $artText.Substring(0, $abi).TrimEnd() + "`r`n" + $artText.Substring($aei + $artEnd.Length).TrimStart("`r","`n") }
$art = Read-Ini ($artText -split "`r?`n")

# ------------------------------------------------------------------ build Rules block
$sb = New-Object Text.StringBuilder
[void]$sb.AppendLine($beginMark)
[void]$sb.AppendLine('; SC research = building upgrades (PowersUpBuilding) bought from the sidebar and placed on the SC building, like the')
[void]$sb.AppendLine('; Ion Cannon Uplink on the GDI Comm Center. Units list research in Prerequisite= (Vinifera Has_Prerequisite scans')
[void]$sb.AppendLine('; Upgrades[]; the parent must be powered). Upgraded units are copies of the base units with better stats.')
[void]$sb.AppendLine('')
foreach ($r in $research) {
  [void]$sb.AppendLine("[$($r.Id)]")
  foreach ($kv in @(
    "Name=$($r.Name)", "Description=$($r.Text)@@Must be placed on: $($r.Parent).", "Prerequisite=$($r.Parent)",
    "PowersUpBuilding=$($r.Parent)", 'PowersUpToLevel=-1', 'TechLevel=1', 'Owner=GDI1',
    "Cost=$($r.Cost)", 'Points=5', 'Strength=1000', 'Armor=wood', 'Power=0', 'Sight=1', 'Crewed=no', 'Capturable=no',
    'Explosion=FBALL1', 'ScrapExplosion=FBALL1_SCRAP', 'ThreatPosed=0', 'DeploySound=CONSTRU2', 'AIBuildThis=no')) { [void]$sb.AppendLine($kv) }
  [void]$sb.AppendLine('')
}

$newWeapons = [ordered]@{}
$reqName = @{}; foreach ($r in $research) { $reqName[$r.Id] = $r.Name }
foreach ($v in $variants) {
  $s = Resolve-Sec $opt $v.Base
  if ($s.Count -eq 0) { throw "base section not found: $($v.Base)" }
  $s['Image'] = $v.Id
  if ($v.Name) { $s['Name'] = $v.Name } elseif ($s.Contains('Name')) { $s['Name'] = "$($s['Name']) (Upgraded)" }
  if ($v.TechLevel) { $s['TechLevel'] = $v.TechLevel }
  $reqList = ($v.Req -split ',' | ForEach-Object { $reqName[$_] }) -join ', '
  $s['Description'] = "Upgraded by research: $reqList.@@" + [string]$s['Description']
  if ($s.Contains('Prerequisite') -and $s['Prerequisite']) { $s['Prerequisite'] = "$($s['Prerequisite']),$($v.Req)" } else { $s['Prerequisite'] = $v.Req }
  if ($s.Contains('Strength')) { $s['Strength'] = Fmt-Num ([math]::Round((Num $s['Strength']) * $v.HP)) }
  if ($v.Sight -and $s.Contains('Sight')) { $s['Sight'] = Fmt-Num ((Num $s['Sight']) + $v.Sight) }
  if ($v.SpeedX -and $s.Contains('Speed')) { $s['Speed'] = Fmt-Num ([math]::Round((Num $s['Speed']) * $v.SpeedX)) }
  foreach ($k in 'TransformsInto','DeploysInto','UndeploysInto') { if ($s.Contains($k) -and $idMap.ContainsKey($s[$k])) { $s[$k] = $idMap[$s[$k]] } }
  if ($v.Extra) { foreach ($k in $v.Extra.Keys) { $s[$k] = $v.Extra[$k] } }
  foreach ($slot in 'Primary','Secondary','Elite','EliteSecondary') {
    if (-not $s.Contains($slot) -or -not $s[$slot] -or $s[$slot] -eq 'none') { continue }
    $wName = $s[$slot]; $newName = "${wName}U"
    if (-not $newWeapons.Contains($newName)) {
      $w = Resolve-Sec $opt $wName
      if ($w.Count -eq 0) { Write-Warning "weapon $wName not in StarCraft.ini, kept as is"; continue }
      if ($w.Contains('Damage') -and $v.Dmg -ne 1.0) { $w['Damage'] = Fmt-Num ([math]::Round((Num $w['Damage']) * $v.Dmg)) }
      if ($v.RofX -and $w.Contains('ROF')) { $w['ROF'] = Fmt-Num ([math]::Max(1, [math]::Round((Num $w['ROF']) * $v.RofX))) }
      if ($v.RangeX -and $w.Contains('Range')) { $w['Range'] = Fmt-Num ((Num $w['Range']) * $v.RangeX) }
      $isSec = $slot -match 'Secondary'
      if ($isSec -and $v.SecRangeAdd -and $w.Contains('Range')) { $w['Range'] = Fmt-Num ((Num $w['Range']) + $v.SecRangeAdd) }
      if ($isSec -and $v.SecRofX -and $w.Contains('ROF')) { $w['ROF'] = Fmt-Num ([math]::Max(1, [math]::Round((Num $w['ROF']) * $v.SecRofX))) }
      $newWeapons[$newName] = $w
    }
    $s[$slot] = $newName
  }
  [void]$sb.AppendLine("[$($v.Id)]")
  foreach ($k in $s.Keys) { [void]$sb.AppendLine("$k=$($s[$k])") }
  [void]$sb.AppendLine('')
}
[void]$sb.AppendLine('; ---- Spider Mines (research SCRSPM)')
foreach ($l in ($spiderMine -split "`r?`n")) { [void]$sb.AppendLine($l) }
[void]$sb.AppendLine('')
[void]$sb.AppendLine('; ---- upgraded weapons (copies with the research bonus)')
foreach ($wn in $newWeapons.Keys) {
  [void]$sb.AppendLine("[$wn]")
  foreach ($k in $newWeapons[$wn].Keys) { [void]$sb.AppendLine("$k=$($newWeapons[$wn][$k])") }
  [void]$sb.AppendLine('')
}
[void]$sb.AppendLine($endMark)

# ------------------------------------------------------------------ write StarCraft.ini (block + registrations + parents)
$lines = New-Object 'System.Collections.Generic.List[string]'; $lines.AddRange([string[]]$optLines)
function Set-ListEntries($listName, [string]$keyPattern, [string[]]$entries) {
  $start = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -eq "[$listName]") { $start = $i; break } }
  if ($start -lt 0) { throw "[$listName] not found" }
  $i = $start + 1; $last = $start
  while ($i -lt $lines.Count -and $lines[$i] -notmatch '^\[') {
    if ($lines[$i] -match $keyPattern) { $lines.RemoveAt($i); continue }
    if ($lines[$i] -match '^\S+=') { $last = $i }
    $i++
  }
  $lines.InsertRange($last + 1, $entries)
}
$bEntries = @(); $n = 1; foreach ($r in $research) { $bEntries += ('SCR{0:D2}={1}	; research (marine session, build-scresearch.ps1)' -f $n, $r.Id); $n++ }
$bEntries += 'SCX90=SCSIEGB2	; Siege Mode of the upgraded Siege Tank (build-scresearch.ps1)'
$n = 91; foreach ($m in $mineStages) { $bEntries += ('SCX{0}={1}	; Spider Mine laid by an Upgraded Vulture (build-scresearch.ps1)' -f $n, $m.Mine); $n++ }
Set-ListEntries 'BuildingTypes' '^SC[RX]\d+=' $bEntries
$vEntries = @(); $n = 1; foreach ($v in ($variants | Where-Object { -not $_.Building })) { $vEntries += ('SCX{0:D2}={1}	; upgraded unit (build-scresearch.ps1)' -f $n, $v.Id); $n++ }
Set-ListEntries 'VehicleTypes' '^SCX\d+=' $vEntries
Set-ListEntries 'InfantryTypes' '^SCX\d+=' @()     # (the old buyable infantry Spider Mine SCSPMINE is gone)
# remove the earlier Passengers/PipScale lines from the base Vulture (passenger-mine design, replaced)
for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i] -match 'research session: Spider Mines \(build-scresearch\.ps1\)') { $lines.RemoveAt($i) } }
# Upgrades=N on parents (first occurrence of the section)
foreach ($p in $parents.Keys) {
  $start = -1; for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -eq "[$p]") { $start = $i; break } }
  if ($start -lt 0) { Write-Warning "parent [$p] not found"; continue }
  $i = $start + 1; $done = $false; $prereqAt = -1
  while ($i -lt $lines.Count -and $lines[$i] -notmatch '^\[') {
    if ($lines[$i] -match '^Upgrades=') { $lines[$i] = "Upgrades=$($parents[$p])	;research session: room for building-upgrade research (build-scresearch.ps1)"; $done = $true }
    if ($lines[$i] -match '^Prerequisite=') { $prereqAt = $i }
    $i++
  }
  if (-not $done) { $at = if ($prereqAt -ge 0) { $prereqAt + 1 } else { $start + 1 }; $lines.Insert($at, "Upgrades=$($parents[$p])	;research session: room for building-upgrade research (build-scresearch.ps1)") }
}
# Upgraded Marine (marine session block): needs Infantry Weapons & Armor + U-238
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^Prerequisite=FACTORY,SCU238\b') { $lines[$i] = 'Prerequisite=FACTORY,SCRINF,SCU238	;research: Infantry Weapons & Armor (E-Bay) + U-238 Shells (Academy)' } }
while ($lines.Count -gt 0 -and $lines[$lines.Count-1].Trim() -eq '') { $lines.RemoveAt($lines.Count-1) }
$lines.Add(''); foreach ($l in ($sb.ToString().TrimEnd() -split "`r?`n")) { $lines.Add($l) }
[IO.File]::WriteAllLines($optPath, $lines, (New-Object Text.UTF8Encoding($false)))

# ------------------------------------------------------------------ assets + Art block
$casc = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"
$cameoPal = [Pal]::ReadTs($mixes.Read('CAMEO.PAL'))
$cmdIcons = [DdsGrp]::Read($casc.ReadFile('SD/unit/cmdicons/cmdicons.dds.grp'))
$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$gold  = [Pal]::Nearest([Drawing.Color]::FromArgb(230,180,40), $cameoPal, 1, 255)
$gold2 = [Pal]::Nearest([Drawing.Color]::FromArgb(255,215,70), $cameoPal, 1, 255)
$ab = New-Object Text.StringBuilder
[void]$ab.AppendLine($artBegin)
foreach ($r in $research) {
  $files["$($r.Id)IC.SHP"] = [ScBuild]::BuildResearchCameo($cmdIcons[$r.Icon], $cameoPal, $r.Caption).Write()
  $files["$($r.Id).SHP"]   = [ScBuild]::BuildEmptyBuilding(48, 48).Write()
  [void]$ab.AppendLine("[$($r.Id)]`r`nCameo=$($r.Id)IC`r`nFoundation=1x1`r`nNewTheater=no`r`nRemapable=yes`r`n")
}
foreach ($v in $variants) {
  $baseArtName = $v.Base
  $a = Resolve-Sec $art $baseArtName
  $srcImage = if ($a.Contains('Image') -and $a['Image']) { $a['Image'] } else { $baseArtName }
  $shp = $mixes.Read("$srcImage.SHP"); if (-not $shp) { throw "SHP not found: $srcImage.SHP" }
  $files["$($v.Id).SHP"] = $shp
  if ($a.Contains('Cameo') -and $a['Cameo'] -and -not $v.Building) {
    $cs = $mixes.Read("$($a['Cameo']).SHP")
    if ($cs) {
      $c = [Shp]::Read($cs); $f = $c.Frames[0]
      for ($x = 0; $x -lt $f.W; $x++) { foreach ($y in 0,1,($f.H-2),($f.H-1)) { $f.Pixels[$y*$f.W+$x] = $gold } }
      for ($y = 0; $y -lt $f.H; $y++) { foreach ($x in 0,1,($f.W-2),($f.W-1)) { $f.Pixels[$y*$f.W+$x] = $gold } }
      foreach ($oy in 4,9) { for ($k = 0; $k -le 5; $k++) { foreach ($t2 in 0,1) { $px = $f.W-14+$k; $py = $oy+$k+$t2; if ($py -lt $f.H) { $f.Pixels[$py*$f.W+$px] = $gold2 }; $px2 = $f.W-4-$k; if ($py -lt $f.H) { $f.Pixels[$py*$f.W+$px2] = $gold2 } } } }
      $files["$($v.Id)I.SHP"] = $c.Write()
      $a['Cameo'] = "$($v.Id)I"
    }
  }
  $a.Remove('Image')
  [void]$ab.AppendLine("[$($v.Id)]")
  foreach ($k in $a.Keys) { [void]$ab.AppendLine("$k=$($a[$k])") }
  [void]$ab.AppendLine('')
}
# ---- Spider Mine: infantry SHP (12 non-directional frames + silhouette shadows), cameo, sounds, art + sequence
$scPal   = [Pal]::ReadWpe($casc.ReadFile('TileSet/jungle.wpe'))
$unitPal = [Pal]::ReadTs($mixes.Read('UNITTEM.PAL'))
$pw = 0; $ph = 0; $tpal = $null
$tunit = [Pal]::ReadPcx($casc.ReadFile('game/tunit.pcx'), [ref]$pw, [ref]$ph, [ref]$tpal)
$ramp = New-Object 'System.Drawing.Color[]' 8; for ($i = 0; $i -lt 8; $i++) { $ramp[$i] = $tpal[$tunit[$i]] }
$map = [ScBuild]::BuildMap($scPal, $unitPal, $ramp, $true, 0)
$spider = [Grp]::Read($casc.ReadFile('unit/terran/spider.grp'))
# mine building SHP: burrowed spider (frame 11); building canvas centre = top vertex of the 1x1 diamond, so the cell
# centre is 12 px below it -> canvas 48x72 (centre 24,36), sprite centre at (24,48). Frames: normal, damaged, 2 shadows.
$cv = [ScBuild]::ToCanvas($spider.Frames[11], $spider.Width, $spider.Height)
$ox = 24 - [int]($spider.Width / 2); $oy = 48 - [int]($spider.Height / 2)
$mineShp = New-Object Shp; $mineShp.Width = 48; $mineShp.Height = 72
$body = [ScBuild]::Place($cv, $spider.Width, $spider.Height, 48, 72, $ox, $oy, $false, $map)
$shad = [ScBuild]::Place($cv, $spider.Width, $spider.Height, 48, 72, $ox + 3, $oy + 2, $false, $null)
$mineShp.Frames.Add($body); $mineShp.Frames.Add($body); $mineShp.Frames.Add($shad); $mineShp.Frames.Add($shad)
$mineBytes = $mineShp.Write()
$files['SCSPMINI.SHP'] = ([ScBuild]::BuildCameo($spider.Frames[0], $spider.Width, $spider.Height, $scPal, $ramp, $cameoPal, 3, 0, 0)).Write()
foreach ($m in $mineStages) {
  $files["$($m.Mine).SHP"] = $mineBytes
  [void]$ab.AppendLine("[$($m.Mine)]`r`nCameo=SCSPMINI`r`nFoundation=1x1`r`nHeight=1`r`nNewTheater=no`r`nRemapable=yes`r`n")
}
foreach ($snd in @(@('SCSPMIN0','SD/sound/terran/vulture/tvumin00.wav'), @('SCSPMIN1','SD/sound/terran/vulture/tvumin01.wav'))) {
  $rate = 0; $pcm = [Aud]::ReadWav($casc.ReadFile($snd[1]), [ref]$rate); $files["$($snd[0]).AUD"] = [Aud]::Encode($pcm, $rate, 1.3)
}
[void]$ab.AppendLine($artEnd)
$artText = $artText.TrimEnd() + "`r`n`r`n" + $ab.ToString()
[IO.File]::WriteAllText($artPath, $artText, $latin1)
[Mix]::Write("$game\MIX\ECACHE87.MIX", $files)

# ------------------------------------------------------------------ report + previews
"ECACHE87.MIX: $($files.Count) files"
"research: " + (($research | ForEach-Object { "$($_.Id)->$($_.Parent)" }) -join ', ')
"variants: " + (($variants | ForEach-Object { $_.Id }) -join ', ')
"weapons:  " + ($newWeapons.Keys -join ', ')
"parents:  " + (($parents.Keys | ForEach-Object { "$_ Upgrades=$($parents[$_])" }) -join ', ')
$prev = New-Object 'System.Collections.Generic.List[Frame]'
foreach ($r in $research) { $prev.Add(([Shp]::Read($files["$($r.Id)IC.SHP"])).Frames[0]) }
foreach ($v in $variants) { if ($files.ContainsKey("$($v.Id)I.SHP")) { $prev.Add(([Shp]::Read($files["$($v.Id)I.SHP"])).Frames[0]) } }
[Pal]::Sheet($prev, [int[]](0..($prev.Count-1)), 64, 48, $cameoPal, 2, 8, "$PreviewDir\cameos.png")
"preview: $PreviewDir\cameos.png"
