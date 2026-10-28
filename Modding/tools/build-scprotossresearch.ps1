# Protoss research (SC upgrades) for the Protoss faction (house GDI2), the same pattern as build-scresearch.ps1 (Terran) and
# build-sczergresearch.ps1 (Zerg): research = building upgrades (PowersUpBuilding) bought in the Structures tab (the Nexus
# is the Construction Yard) and placed on the Protoss building that does the research in SC + one "upgraded" copy of each
# Protoss unit that requires the matching research (max 2 icons per unit; Vinifera Has_Prerequisite scans Upgrades[]).
# Writes: block "Protoss research" in the map code layer of that name (INI/Map Code/SC Factions) and INI/Art.ini (regenerated on every run;
# the client merges repeated sections, later keys win, so the block adds Upgrades=N to the Protoss buildings without touching
# the "Protoss faction" block of build-scprotoss.ps1), MIX/ECACHE83.MIX (research icons, empty research SHPs, unit SHP copies,
# gold cameos). Run it AFTER build-scprotoss.ps1 -Install (it copies the installed units; the copies go stale otherwise).
# Wiki: Modding/wiki/mods/protoss-faction.md (section "Badania").
param([string]$StarCraft = "C:\Program Files (x86)\StarCraft", [string]$PreviewDir = "$env:TEMP\scprotossresearch-preview")
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs","$tools\ModTools.cs","$tools\ScBuild.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null
$latin1  = [Text.Encoding]::GetEncoding(28591)
. "$tools\MapCode.ps1"   # our layer "Protoss research" of the faction map code
$facPath = Get-MapCodeLayer 'Protoss research'
$artPath = "$game\INI\Art.ini"
foreach ($p in $facPath, $artPath) { if (-not (Test-Path "$p.bak")) { Copy-Item $p "$p.bak" } }

# ------------------------------------------------------------------ research (SC data: arr/upgrades.dat, Protoss = race 2;
# cost = (minerals + 2 x gas) x 4 of level 1). Weapons and Armor/Plating levels 1-3 merged into one research per class, like
# the Terran "Weapons & Armor" and the Zerg "Attacks & Carapace". Spells of techdata.dat (Hallucination, Recall, Stasis Field,
# Disruption Web, Mind Control, Feedback, Maelstrom) are skipped: no spell mechanic; Psionic Storm the High Templar has already.
$research = @(
  @{ Id='SCQGWA'; Name='Ground Weapons & Armor'; Parent='SCPFOR'; Icon=305; Cost=1200; Caption='GROUND W+A'; Text='Upgraded Zealot, Dragoon, Templar, Archons and Reaver: +30% damage, +25% health.' }
  @{ Id='SCQSHD'; Name='Plasma Shields';         Parent='SCPFOR'; Icon=310; Cost=2400; Caption='PLASMA SH.'; Text='Upgraded Archon and Dark Archon: +50% health instead of +25% (they are almost all shields).' }
  @{ Id='SCQAWA'; Name='Air Weapons & Armor';    Parent='SCPCYB'; Icon=306; Cost=1200; Caption='AIR W+A';    Text='Upgraded Stargate and Robotics flyers: +30% damage, +25% health.' }
  @{ Id='SCQSIN'; Name='Singularity Charge';     Parent='SCPCYB'; Icon=281; Cost=1800; Caption='SINGULAR.';  Text='Upgraded Dragoon: +50% range.' }
  @{ Id='SCQLEG'; Name='Leg Enhancements';       Parent='SCPCIT'; Icon=307; Cost=1800; Caption='LEG ENH.';   Text='Upgraded Zealot: +50% speed.' }
  @{ Id='SCQSCA'; Name='Scarab Damage';          Parent='SCPRSB'; Icon=314; Cost=2400; Caption='SCARAB DMG'; Text='Upgraded Reaver: Scarabs +25% damage.' }
  @{ Id='SCQRCP'; Name='Reaver Capacity';        Parent='SCPRSB'; Icon=315; Cost=2400; Caption='REAVER CAP'; Text='Upgraded Reaver: fires Scarabs 25% more often.' }
  @{ Id='SCQGRD'; Name='Gravitic Drive';         Parent='SCPRSB'; Icon=316; Cost=2400; Caption='GRAV.DRIVE'; Text='Upgraded Shuttle: +50% speed.' }
  @{ Id='SCQSEN'; Name='Sensor Array';           Parent='SCPOBS'; Icon=317; Cost=1800; Caption='SENSOR ARR'; Text='Upgraded Observer: +3 sight and detection range.' }
  @{ Id='SCQGRB'; Name='Gravitic Boosters';      Parent='SCPOBS'; Icon=276; Cost=1800; Caption='GRAV.BOOST'; Text='Upgraded Observer: +50% speed.' }
  @{ Id='SCQKHA'; Name='Khaydarin Amulet';       Parent='SCPARC'; Icon=318; Cost=1800; Caption='KHAYD.AMUL'; Text='Upgraded High Templar: Psionic Storm more often.' }
  @{ Id='SCQARG'; Name='Argus Talisman';         Parent='SCPARC'; Icon=385; Cost=1800; Caption='ARGUS TAL.'; Text='Upgraded Dark Archon: Maelstrom more often.' }
  @{ Id='SCQAPI'; Name='Apial Sensors';          Parent='SCPFLB'; Icon=319; Cost=1200; Caption='APIAL SENS'; Text='Upgraded Scout: +2 sight.' }
  @{ Id='SCQGTH'; Name='Gravitic Thrusters';     Parent='SCPFLB'; Icon=320; Cost=2400; Caption='GRAV.THRST'; Text='Upgraded Scout: +50% speed.' }
  @{ Id='SCQCAR'; Name='Carrier Capacity';       Parent='SCPFLB'; Icon=321; Cost=1200; Caption='CARRIER CP'; Text='Upgraded Carrier: 8 Interceptors instead of 4 (they also hit 30% harder).' }
  @{ Id='SCQARJ'; Name='Argus Jewel';            Parent='SCPFLB'; Icon=383; Cost=1200; Caption='ARGUS JEWL'; Text='Upgraded Corsair: fires 25% more often.' }
  @{ Id='SCQKHC'; Name='Khaydarin Core';         Parent='SCPTRB'; Icon=322; Cost=1800; Caption='KHAYD.CORE'; Text='Upgraded Arbiter: fires more often (also in its cloaking field).' }
)

# ------------------------------------------------------------------ upgraded unit variants (all Protoss units are vehicles)
# HP = Strength factor, Dmg = Damage factor (all weapons), RofX/RangeX = weapon factors, SpeedX, Sight/SensorsAdd = additions,
# Set = keys replaced as they are, Copies = extra sections copied with the same bonus (new id = old id + "2").
$variants = @(
  @{ Base='SCPZEAL'; Req='SCQGWA,SCQLEG';        HP=1.25; Dmg=1.3; SpeedX=1.5 }
  @{ Base='SCPDRAG'; Req='SCQGWA,SCQSIN';        HP=1.25; Dmg=1.3; RangeX=1.5 }
  @{ Base='SCPHTMP'; Req='SCQGWA,SCQKHA';        HP=1.25; Dmg=1.0; RofX=0.7 }
  @{ Base='SCPDTMP'; Req='SCQGWA';               HP=1.25; Dmg=1.3 }
  @{ Base='SCPARCH'; Req='SCQGWA,SCQSHD';        HP=1.5;  Dmg=1.3 }
  @{ Base='SCPDARC'; Req='SCQGWA,SCQSHD,SCQARG'; HP=1.5;  Dmg=1.0; RofX=0.7 }
  @{ Base='SCPREAV'; Req='SCQGWA,SCQSCA,SCQRCP'; HP=1.25; Dmg=1.6; RofX=0.8 }
  @{ Base='SCPSHUT'; Req='SCQAWA,SCQGRD';        HP=1.25; Dmg=1.0; SpeedX=1.5 }
  @{ Base='SCPOBSV'; Req='SCQAWA,SCQSEN,SCQGRB'; HP=1.25; Dmg=1.0; SpeedX=1.5; Sight=3; SensorsAdd=3 }
  @{ Base='SCPSCOU'; Req='SCQAWA,SCQAPI,SCQGTH'; HP=1.25; Dmg=1.3; SpeedX=1.5; Sight=2 }
  @{ Base='SCPCORS'; Req='SCQAWA,SCQARJ';        HP=1.25; Dmg=1.3; RofX=0.8 }
  @{ Base='SCPCARR'; Req='SCQAWA,SCQCAR';        HP=1.25; Dmg=1.0; Set=@{ SpawnsNumber='8'; Spawns='SCPINTC2' }
     Copies=@(@{ Id='SCPINTC'; HP=1.25; Dmg=1.3; Set=@{} }) }
  @{ Base='SCPARBI'; Req='SCQAWA,SCQKHC';        HP=1.25; Dmg=1.3; RofX=0.7; Set=@{ DeploysInto='SCPARBD2' }
     Copies=@(@{ Id='SCPARBD'; HP=1.25; Dmg=1.3; RofX=0.7; Set=@{ UndeploysInto='SCPARBI2'; Image='SCPARBD'; Name='Arbiter (Upgraded, cloaking field)' } }) }
)
$parents = [ordered]@{}; foreach ($r in $research) { $parents[$r.Parent] = 1 + [int]$parents[$r.Parent] }

# ------------------------------------------------------------------ INI helpers (duplicate sections merge, later wins: like the client)
function Read-Ini([string[]]$lines) {
  $d = @{}; $sec = $null
  foreach ($l in $lines) {
    if ($l -match '^\[([^\]]+)\]') { $sec = $matches[1]; if (-not $d.ContainsKey($sec)) { $d[$sec] = [ordered]@{} }; continue }
    if ($sec -and $l -match '^([^;=\s][^=]*?)\s*=\s*(.*)$') { $d[$sec][$matches[1].Trim()] = ($matches[2] -replace '\s*;.*$', '').Trim() }
  }
  return $d
}
function Resolve-Sec($ini, [string]$name) {
  $r = [ordered]@{}
  if ($ini.ContainsKey($name)) { foreach ($k in $ini[$name].Keys) { $r[$k] = $ini[$name][$k] } }
  return $r
}
function Fmt-Num($x) { if ([math]::Abs($x - [math]::Round($x)) -lt 0.001) { return [string][int][math]::Round($x) } else { return ([math]::Round($x, 2)).ToString([Globalization.CultureInfo]::InvariantCulture) } }
function Num($s) { return [double]::Parse(($s -replace '%',''), [Globalization.CultureInfo]::InvariantCulture) }
function Clip([string]$s) { if ($s.Length -gt 199) { return $s.Substring(0, 199) } else { return $s } }   # Vinifera Description[200]
function Strip-Block([string]$text, [string]$b, [string]$e) {
  $a = $text.IndexOf($b); if ($a -lt 0) { return $text }
  $z = $text.IndexOf($e, $a); if ($z -lt 0) { throw "block end marker missing: $e" }
  return $text.Substring(0, $a).TrimEnd() + "`r`n" + $text.Substring($z + $e.Length).TrimStart("`r","`n")
}

$begin = '; >>> Protoss research'; $end = '; <<< Protoss research'
$facOld = [IO.File]::ReadAllText($facPath, $latin1)
$nl = if ($facOld.Contains("`r`n")) { "`r`n" } else { "`n" }
$facBase = Read-MapCodeText -Exclude $facPath   # every other layer, in merge order
$fac = Read-Ini ($facBase -split "`r?`n")
$artText = Strip-Block ([IO.File]::ReadAllText($artPath, $latin1)) $begin $end
$art = Read-Ini ($artText -split "`r?`n")
$bldgName = @{}; foreach ($p in $parents.Keys) { $bldgName[$p] = (Resolve-Sec $fac $p)['Name']; if (-not $bldgName[$p]) { throw "Protoss building [$p] not found (run build-scprotoss.ps1 -Install first)" } }

# weapon copies with the research bonus ("<weapon>U"); one copy per weapon (every variant using a weapon has the same bonus)
$newWeapons = [ordered]@{}
function Upgrade-Weapons($s, $v) {
  $weaponMod = ($v.Dmg -and $v.Dmg -ne 1.0) -or $v.RofX -or $v.RangeX
  if (-not $weaponMod) { return }
  foreach ($slot in 'Primary','Secondary','ElitePrimary','EliteSecondary') {
    if (-not $s.Contains($slot) -or -not $s[$slot] -or $s[$slot] -eq 'none') { continue }
    $wName = $s[$slot]; $newName = "${wName}U"
    if (-not $newWeapons.Contains($newName)) {
      $w = Resolve-Sec $fac $wName
      if ($w.Count -eq 0) { Write-Warning "weapon $wName not found, kept as is"; continue }
      if ($w.Contains('Damage') -and $v.Dmg -and $v.Dmg -ne 1.0 -and (Num $w['Damage']) -gt 1) { $w['Damage'] = Fmt-Num ([math]::Round((Num $w['Damage']) * $v.Dmg)) }
      if ($v.RofX -and $w.Contains('ROF')) { $w['ROF'] = Fmt-Num ([math]::Max(1, [math]::Round((Num $w['ROF']) * $v.RofX))) }
      if ($v.RangeX -and $w.Contains('Range')) { $w['Range'] = Fmt-Num ((Num $w['Range']) * $v.RangeX) }
      $newWeapons[$newName] = $w
    }
    $s[$slot] = $newName
  }
}
function Apply-Bonus($s, $v) {
  if ($v.HP -and $s.Contains('Strength')) {
    $s['Strength'] = Fmt-Num ([math]::Round((Num $s['Strength']) * $v.HP))
    if ($s.Contains('SelfHealingStep')) { $s['SelfHealingStep'] = Fmt-Num ([math]::Max(1, [math]::Round((Num $s['SelfHealingStep']) * $v.HP))) }
  }
  if ($v.Sight -and $s.Contains('Sight')) { $s['Sight'] = Fmt-Num ((Num $s['Sight']) + $v.Sight) }
  if ($v.SensorsAdd -and $s.Contains('SensorsSight')) { $s['SensorsSight'] = Fmt-Num ((Num $s['SensorsSight']) + $v.SensorsAdd) }
  if ($v.SpeedX -and $s.Contains('Speed')) { $s['Speed'] = Fmt-Num ([math]::Round((Num $s['Speed']) * $v.SpeedX)) }
  Upgrade-Weapons $s $v
  if ($v.Set) { foreach ($k in $v.Set.Keys) { $s[$k] = $v.Set[$k] } }
}

# ------------------------------------------------------------------ rules block
$sb = New-Object Text.StringBuilder
function Out([string]$s) { [void]$sb.AppendLine($s) }
Out $begin
Out '; =====================================================================================================================';
Out '; Protoss research (generated by Modding/tools/build-scprotossresearch.ps1, do not edit by hand; wiki: mods/protoss-faction).'
Out '; SC upgrades = building upgrades (PowersUpBuilding) built from the Nexus (Structures tab) and placed on the Protoss'
Out '; building that researches them in SC. Upgraded units list research in Prerequisite= (Vinifera Has_Prerequisite scans'
Out '; Upgrades[]). Repeated building sections below ADD Upgrades=N to the "Protoss faction" sections (the client merges).'
Out '; =====================================================================================================================';
Out ''
Out '[BuildingTypes]'
$n = 1; foreach ($r in $research) { Out ('PUB{0:D2}={1}' -f $n, $r.Id); $n++ }
foreach ($v in $variants) { foreach ($c in @($v.Copies)) { if ($c -and (Resolve-Sec $fac $c.Id).Contains('UndeploysInto')) { Out ('PUB{0:D2}={1}2' -f $n, $c.Id); $n++ } } }
Out ''
# infantry (Gateway: Zealot, Dragoon, Templar) or vehicle (everything else): as the base unit is listed in the faction file
$infBase = @(); foreach ($l in ($facBase -split "`r?`n")) { if ($l -match '^PRI\d+=(\w+)') { $infBase += $matches[1] } }
Out '[InfantryTypes]'
$n = 1; foreach ($v in ($variants | Where-Object { $infBase -contains $_.Base })) { Out ('PUI{0:D2}={1}2' -f $n, $v.Base); $n++ }
Out ''
Out '[VehicleTypes]'
$n = 1; foreach ($v in ($variants | Where-Object { $infBase -notcontains $_.Base })) { Out ('PUV{0:D2}={1}2' -f $n, $v.Base); $n++ }
Out ''
Out '[AircraftTypes]'
$n = 1; foreach ($v in $variants) { foreach ($c in @($v.Copies)) { if ($c -and (Resolve-Sec $fac $c.Id).Contains('Spawned')) { Out ('PUA{0:D2}={1}2' -f $n, $c.Id); $n++ } } }
Out ''
Out '; ---------------------------------------------------------------- keys added to the Protoss buildings'
Out ''
foreach ($p in $parents.Keys) {
  $here = ($research | Where-Object { $_.Parent -eq $p } | ForEach-Object { $_.Name }) -join ', '
  Out "[$p]"
  Out "Upgrades=$($parents[$p])	; research placed here: $here"
  Out ''
}
Out '; ---------------------------------------------------------------- research (building upgrades, Structures tab of the Nexus)'
Out ''
foreach ($r in $research) {
  $where = $bldgName[$r.Parent]
  Out "[$($r.Id)]"
  foreach ($kv in @(
    "Name=$($r.Name)", "Description=$(Clip "$where research.@@$($r.Text)@@Place it on the $where.")", "Prerequisite=$($r.Parent)",
    "PowersUpBuilding=$($r.Parent)", 'PowersUpToLevel=-1', 'TechLevel=1', 'Owner=GDI2',
    "Cost=$($r.Cost)", 'Points=5', 'Strength=1000', 'Armor=wood', 'Power=0', 'Sight=1', 'Crewed=no', 'Capturable=no',
    'BaseNormal=no', 'Adjacent=6', 'Explosion=FBALL1', 'ScrapExplosion=FBALL1', 'ThreatPosed=0', 'DeploySound=SCPBPLC', 'AIBuildThis=no')) { Out $kv }
  Out ''
}
Out '; ---------------------------------------------------------------- upgraded units (copies of the "Protoss faction" units)'
Out ''
$reqName = @{}; foreach ($r in $research) { $reqName[$r.Id] = $r.Name }
foreach ($v in $variants) {
  $id = "$($v.Base)2"; $v.Id = $id
  $s = Resolve-Sec $fac $v.Base
  if ($s.Count -eq 0) { throw "base section not found: $($v.Base)" }
  $v.ArtName = if ($s.Contains('Image') -and $s['Image']) { $s['Image'] } else { $v.Base }
  $s['Image'] = $id
  $s['Name'] = "$($s['Name']) (Upgraded)"
  $reqList = ($v.Req -split ',' | ForEach-Object { $reqName[$_] }) -join ', '
  $s['Description'] = Clip ("Upgraded: $reqList.@@" + [string]$s['Description'])
  $s['Prerequisite'] = if ($s['Prerequisite'] -and $s['Prerequisite'] -ne 'none') { "$($s['Prerequisite']),$($v.Req)" } else { $v.Req }
  Apply-Bonus $s $v
  Out "[$id]"
  foreach ($k in $s.Keys) { Out "$k=$($s[$k])" }
  Out ''
  foreach ($c in @($v.Copies)) {
    if (-not $c) { continue }
    $cs = Resolve-Sec $fac $c.Id
    if ($cs.Count -eq 0) { throw "copy source not found: $($c.Id)" }
    Apply-Bonus $cs $c
    Out "[$($c.Id)2]"
    foreach ($k in $cs.Keys) { Out "$k=$($cs[$k])" }
    Out ''
  }
}
Out '; ---------------------------------------------------------------- upgraded weapons (copies with the research bonus)'
Out ''
foreach ($wn in $newWeapons.Keys) {
  Out "[$wn]"
  foreach ($k in $newWeapons[$wn].Keys) { Out "$k=$($newWeapons[$wn][$k])" }
  Out ''
}
Out $end
$block = ($sb.ToString().TrimEnd() -replace "`r?`n", $nl) + $nl
Set-MapCodeBlock $facPath $block

# ------------------------------------------------------------------ assets + Art block
$casc  = New-Object Casc $StarCraft
$mixes = New-Object MixSet "$game\MIX"
$cameoPal = [Pal]::ReadTs($mixes.Read('CAMEO.PAL'))
$cmdIcons = [DdsGrp]::Read($casc.ReadFile('SD/unit/cmdicons/cmdicons.dds.grp'))
$files = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
$gold  = [Pal]::Nearest([Drawing.Color]::FromArgb(230,180,40), $cameoPal, 1, 255)
$gold2 = [Pal]::Nearest([Drawing.Color]::FromArgb(255,215,70), $cameoPal, 1, 255)
$ab = New-Object Text.StringBuilder
[void]$ab.AppendLine($begin)
[void]$ab.AppendLine('; Protoss research (Modding/tools/build-scprotossresearch.ps1, MIX/ECACHE83.MIX): research icons + upgraded Protoss units (gold cameo)')
foreach ($r in $research) {
  $files["$($r.Id)IC.SHP"] = [ScBuild]::BuildResearchCameo($cmdIcons[$r.Icon], $cameoPal, $r.Caption).Write()
  $files["$($r.Id).SHP"]   = [ScBuild]::BuildEmptyBuilding(48, 48).Write()
  [void]$ab.AppendLine("[$($r.Id)]`r`nCameo=$($r.Id)IC`r`nFoundation=1x1`r`nNewTheater=no`r`nRemapable=yes`r`n")
}
foreach ($v in $variants) {
  $a = Resolve-Sec $art $v.ArtName
  if ($a.Count -eq 0) { throw "art section not found: $($v.ArtName)" }
  $srcImage = if ($a.Contains('Image') -and $a['Image']) { $a['Image'] } else { $v.ArtName }
  $shp = $mixes.Read("$srcImage.SHP"); if (-not $shp) { throw "SHP not found: $srcImage.SHP" }
  $files["$($v.Id).SHP"] = $shp
  $cs = if ($a['Cameo']) { $mixes.Read("$($a['Cameo']).SHP") } else { $null }
  if (-not $cs) { throw "cameo not found for $($v.Base): $($a['Cameo'])" }
  $c = [Shp]::Read($cs); $f = $c.Frames[0]
  for ($x = 0; $x -lt $f.W; $x++) { foreach ($y in 0,1,($f.H-2),($f.H-1)) { $f.Pixels[$y*$f.W+$x] = $gold } }
  for ($y = 0; $y -lt $f.H; $y++) { foreach ($x in 0,1,($f.W-2),($f.W-1)) { $f.Pixels[$y*$f.W+$x] = $gold } }
  foreach ($oy in 4,9) { for ($k = 0; $k -le 5; $k++) { foreach ($t2 in 0,1) { $px = $f.W-14+$k; $py = $oy+$k+$t2; if ($py -lt $f.H) { $f.Pixels[$py*$f.W+$px] = $gold2 }; $px2 = $f.W-4-$k; if ($py -lt $f.H) { $f.Pixels[$py*$f.W+$px2] = $gold2 } } } }
  $files["$($v.Id)I.SHP"] = $c.Write()
  $a['Cameo'] = "$($v.Id)I"
  $a.Remove('Image')
  [void]$ab.AppendLine("[$($v.Id)]")
  foreach ($k in $a.Keys) { [void]$ab.AppendLine("$k=$($a[$k])") }
  [void]$ab.AppendLine('')
}
[void]$ab.AppendLine($end)
[IO.File]::WriteAllText($artPath, $artText.TrimEnd() + "`r`n`r`n" + $ab.ToString(), $latin1)
[Mix]::Write("$game\MIX\ECACHE83.MIX", $files)

# ------------------------------------------------------------------ report + checks + previews
$merged = Read-Ini ((Read-MapCodeText) -split "`r?`n")
foreach ($v in $variants) { foreach ($q in ($merged[$v.Id]['Prerequisite'] -split ',')) { if (-not $merged.ContainsKey($q)) { Write-Warning "$($v.Id): prerequisite $q undefined" } } }
foreach ($l in ((Read-MapCodeText) -split "`r?`n")) { if ($l -match '^Description=(.*)$' -and $matches[1].Length -gt 199) { Write-Warning "Description too long: $($l.Substring(0, 60))" } }
"ECACHE83.MIX: $($files.Count) files, $([Math]::Round((Get-Item "$game\MIX\ECACHE83.MIX").Length / 1KB)) KB"
"research: " + (($research | ForEach-Object { "$($_.Id)->$($_.Parent)" }) -join ', ')
"variants: " + (($variants | ForEach-Object { $_.Id }) -join ', ')
"weapons:  " + ($newWeapons.Keys -join ', ')
"parents:  " + (($parents.Keys | ForEach-Object { "$_ Upgrades=$($parents[$_])" }) -join ', ')
$prev = New-Object 'System.Collections.Generic.List[Frame]'
foreach ($r in $research) { $prev.Add(([Shp]::Read($files["$($r.Id)IC.SHP"])).Frames[0]) }
foreach ($v in $variants) { $prev.Add(([Shp]::Read($files["$($v.Id)I.SHP"])).Frames[0]) }
[Pal]::Sheet($prev, [int[]](0..($prev.Count-1)), 64, 48, $cameoPal, 2, 10, "$PreviewDir\cameos.png")
"preview: $PreviewDir\cameos.png"
