# Zerg research (SC upgrades) for the Zerg faction (house Nod1), the same pattern as build-scresearch.ps1 for the Terrans:
# research = building upgrades (PowersUpBuilding) bought in the Structures tab and placed on the Zerg building that does
# the research in SC + one "upgraded" copy of each Zerg unit that requires the matching research (max 2 icons per unit).
# The Zerg have no construction yard, so the Zerg tech buildings (Evolution Chamber, Hydralisk Den, Spire, Greater Spire,
# Queen's Nest, Ultralisk Cavern, Defiler Mound) get Factory=BuildingType + [AI] BuildConst: any of them opens the
# Structures tab, which only ever lists these research items (every Zerg building is TechLevel=-1, made by a Drone).
# Writes: block "Zerg research" at the end of INI/Map Code/Terran Faction.ini and INI/Art.ini (regenerated on every run;
# the client merges repeated sections, later keys win, so the block can add keys to the Zerg buildings without touching
# the "Zerg faction" block of build-sczergbase.ps1), StarCraft.ini [AI] BuildConst (+ labs), MIX/ECACHE84.MIX.
# Run it again after build-sczergbase.ps1 -Install changes the base units (the copies would go stale).
param([string]$StarCraft = "C:\Program Files (x86)\StarCraft", [string]$PreviewDir = "$env:TEMP\sczergresearch-preview")
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
Add-Type -Path "$tools\Casc.cs","$tools\ModTools.cs","$tools\ScBuild.cs" -ReferencedAssemblies System.Drawing
New-Item -ItemType Directory -Force $PreviewDir | Out-Null
$latin1  = [Text.Encoding]::GetEncoding(28591)
$facPath = "$game\INI\Map Code\Terran Faction.ini"
$optPath = "$game\INI\Game Options\StarCraft.ini"
$artPath = "$game\INI\Art.ini"
foreach ($p in $facPath, $optPath, $artPath) { if (-not (Test-Path "$p.bak")) { Copy-Item $p "$p.bak" } }

# ------------------------------------------------------------------ research (SC data: arr/upgrades.dat; cost = (minerals + 2 x gas) x 4)
# Weapons and Carapace levels 1-3 are merged into one research per class, like the Terran "Weapons & Armor".
$research = @(
  @{ Id='SCYMEL'; Name='Melee Attacks & Carapace';   Parent='SCZEVO'; Pre='SCZEVO';         Icon=299; Cost=1200; Caption='MELEE ATT.';   Text='Upgraded Zergling, Ultralisk and Broodling: +30% damage, +25% health.' }
  @{ Id='SCYMIS'; Name='Missile Attacks & Carapace'; Parent='SCZEVO'; Pre='SCZEVO';         Icon=300; Cost=1200; Caption='MISSILE ATT.'; Text='Upgraded Hydralisk and Lurker: +30% damage, +25% health. Defiler: +25% health.' }
  @{ Id='SCYFLY'; Name='Flyer Attacks & Carapace';   Parent='SCZSPI'; Pre='SCZSPI';         Icon=301; Cost=1200; Caption='FLYER ATT.';   Text='Upgraded Mutalisk, Guardian and Devourer: +30% damage. All upgraded flyers: +25% health.' }
  @{ Id='SCYMET'; Name='Metabolic Boost';            Parent='SCZPOL'; Pre='SCZPOL';         Icon=263; Cost=1200; Caption='METABOLIC';    Text='Upgraded Zergling: +50% speed.' }
  @{ Id='SCYADR'; Name='Adrenal Glands';             Parent='SCZPOL'; Pre='SCZPOL,ZHIVEUP'; Icon=264; Cost=2400; Caption='ADRENAL';      Text='Needs a Hive.@@Upgraded Zergling: attacks faster.' }
  @{ Id='SCYMUS'; Name='Muscular Augments';          Parent='SCZHDN'; Pre='SCZHDN,ZLAIRUP'; Icon=266; Cost=1800; Caption='MUSCULAR';     Text='Needs a Lair.@@Upgraded Hydralisk: +50% speed.' }
  @{ Id='SCYGRV'; Name='Grooved Spines';             Parent='SCZHDN'; Pre='SCZHDN,ZLAIRUP'; Icon=268; Cost=1800; Caption='GROOVED';      Text='Needs a Lair.@@Upgraded Hydralisk: +25% range.' }
  @{ Id='SCYPNE'; Name='Pneumatized Carapace';       Parent='SCZLAI'; Pre='SCZLAI';         Icon=296; Cost=1800; Caption='PNEUMAT.';Text='Upgraded Overlord: 3x speed.' }
  @{ Id='SCYANT'; Name='Antennae';                   Parent='SCZLAI'; Pre='SCZLAI';         Icon=262; Cost=1800; Caption='ANTENNAE';     Text='Upgraded Overlord: +3 sight and detection range.' }
  @{ Id='SCYGAM'; Name='Gamete Meiosis';             Parent='SCZNES'; Pre='SCZNES';         Icon=294; Cost=1800; Caption='GAMETE';       Text='Upgraded Queen: spits faster.' }
  @{ Id='SCYMSN'; Name='Metasynaptic Node';          Parent='SCZDFM'; Pre='SCZDFM';         Icon=295; Cost=1800; Caption='METASYN.';Text='Upgraded Defiler: Plague more often.' }
  @{ Id='SCYANA'; Name='Anabolic Synthesis';         Parent='SCZULC'; Pre='SCZULC';         Icon=378; Cost=2400; Caption='ANABOLIC';     Text='Upgraded Ultralisk: +50% speed.' }
  @{ Id='SCYCHI'; Name='Chitinous Plating';          Parent='SCZULC'; Pre='SCZULC';         Icon=379; Cost=1800; Caption='CHITINOUS';    Text='Upgraded Ultralisk: +50% health instead of +25%.' }
)
# Zerg tech buildings that can grow research (Factory=BuildingType). Pool and Lair are already factories (one Factory= per building).
$labs = @('SCZEVO','SCZHDN','SCZSPI','SCZGSP','SCZNES','SCZULC','SCZDFM')

# ------------------------------------------------------------------ upgraded unit variants
# HP = Strength factor, Dmg = Damage factor (all weapons), RofX/RangeX = weapon factors, SpeedX, Sight/SensorsAdd = additions.
$variants = @(
  @{ Base='SCZLNG'; Req='SCYMEL,SCYMET,SCYADR'; Inf=$true; HP=1.25; Dmg=1.3; SpeedX=1.5; RofX=0.75 }
  # SpeedX 4/3: base Hydralisk 8 -> 6 (user 2026-10-25, 30% slower), upgraded 12 -> 8 (Zerg session)
  @{ Base='SCZHYL'; Req='SCYMIS,SCYMUS,SCYGRV'; Inf=$true; HP=1.25; Dmg=1.3; SpeedX=(4.0/3); RangeX=1.25 }
  # SCZLRK2 removed (Zerg session 2026-10-25): the Lurker is now a vehicle SCZLRV that attacks only as the burrowed building
  # SCZLRB (user request), so an upgraded copy of the moving Lurker would have nothing to upgrade.
  #@{ Base='SCZLRK'; Req='SCYMIS';               Inf=$true; HP=1.25; Dmg=1.3 }
  @{ Base='SCZULT'; Req='SCYMEL,SCYANA,SCYCHI'; Inf=$true; HP=1.5;  Dmg=1.3; SpeedX=1.5 }
  @{ Base='SCZDFL'; Req='SCYMIS,SCYMSN';        Inf=$true; HP=1.25; Dmg=1.0; RofX=0.6 }
  @{ Base='SCZBRD'; Req='SCYMEL';               Inf=$true; HP=1.25; Dmg=1.3 }
  @{ Base='SCZOVL'; Req='SCYFLY,SCYPNE,SCYANT'; HP=1.25; Dmg=1.0; SpeedX=3; Sight=3; SensorsAdd=3 }
  @{ Base='SCZMUT'; Req='SCYFLY';               HP=1.25; Dmg=1.3 }
  @{ Base='SCZSCG'; Req='SCYFLY';               HP=1.25; Dmg=1.0 }
  @{ Base='SCZGRD'; Req='SCYFLY';               HP=1.25; Dmg=1.3 }
  @{ Base='SCZDEV'; Req='SCYFLY';               HP=1.25; Dmg=1.3 }
  @{ Base='SCZQUN'; Req='SCYFLY,SCYGAM';        HP=1.25; Dmg=1.0; RofX=0.6 }
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
  $chain = @(); $n = $name; $seen = @{}
  while ($n -and $ini.ContainsKey($n) -and -not $seen[$n]) { $seen[$n] = 1; $chain = ,$n + $chain; $n = $ini[$n]['$Inherits'] }
  $r = [ordered]@{}
  foreach ($c in $chain) { foreach ($k in $ini[$c].Keys) { if ($k -ne '$Inherits') { $r[$k] = $ini[$c][$k] } } }
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

$begin = '; >>> Zerg research'; $end = '; <<< Zerg research'
$facOld = [IO.File]::ReadAllText($facPath, $latin1)
$nl = if ($facOld.Contains("`r`n")) { "`r`n" } else { "`n" }
# keep list entries other scripts may have put into this block's [BuildingTypes]/[InfantryTypes]/[VehicleTypes] (their first occurrence)
$foreign = @{ BuildingTypes = @(); InfantryTypes = @(); VehicleTypes = @() }
$a0 = $facOld.IndexOf($begin)
if ($a0 -ge 0) {
  $sec = $null
  foreach ($l in ($facOld.Substring($a0, $facOld.IndexOf($end, $a0) - $a0) -split "`r?`n")) {
    if ($l -match '^\[([^\]]+)\]') { $sec = $matches[1]; continue }
    if ($sec -and $foreign.ContainsKey($sec) -and $l -match '^\S+=' -and $l -notmatch '^ZU[BIV]\d+=') { $foreign[$sec] += $l }
  }
}
$facBase = Strip-Block $facOld $begin $end
$fac = Read-Ini ($facBase -split "`r?`n")
$artText = Strip-Block ([IO.File]::ReadAllText($artPath, $latin1)) $begin $end
$art = Read-Ini ($artText -split "`r?`n")
$bldgName = @{}; foreach ($p in @($parents.Keys) + $labs) { $bldgName[$p] = (Resolve-Sec $fac $p)['Name']; if (-not $bldgName[$p]) { throw "Zerg building [$p] not found in Terran Faction.ini (run build-sczergbase.ps1 -Install first)" } }

# ------------------------------------------------------------------ rules block
$sb = New-Object Text.StringBuilder
function Out([string]$s) { [void]$sb.AppendLine($s) }
Out $begin
Out '; =====================================================================================================================';
Out '; Zerg research (generated by Modding/tools/build-sczergresearch.ps1, do not edit by hand; wiki: mods/zerg-research).'
Out '; SC upgrades = building upgrades (PowersUpBuilding) grown in the Structures tab and placed on the Zerg building that'
Out '; researches them in SC (like the Terran research of build-scresearch.ps1). Units list research in Prerequisite='
Out '; (Vinifera Has_Prerequisite scans Upgrades[]). Repeated sections below ADD keys to the "Zerg faction" sections (the'
Out '; client merges repeated sections, later keys win): Upgrades=N on the parents, Factory=BuildingType on the tech buildings.'
Out '; =====================================================================================================================';
Out ''
$bc = $null; foreach ($l in ($facBase -split "`r?`n")) { if ($l -match '^BuildConst=([^;\r\n]*)') { $bc = $matches[1].Trim() } }
if (-not $bc) { $bc = 'GFACT,NFACT,AFACT,SFACT' }
$bcList = @($bc -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $labs -notcontains $_ }) + $labs
Out '[AI]'
Out "BuildConst=$($bcList -join ',')	; + Zerg tech buildings: they grow research (Vinifera lets a house build structures only with a BuildConst type)"
Out ''
Out '[BuildingTypes]'
$n = 1; foreach ($r in $research) { Out ('ZUB{0:D2}={1}' -f $n, $r.Id); $n++ }
foreach ($l in $foreign.BuildingTypes) { Out $l }
Out ''
Out '[InfantryTypes]'
$n = 1; foreach ($v in ($variants | Where-Object { $_.Inf })) { Out ('ZUI{0:D2}={1}2' -f $n, $v.Base); $n++ }
foreach ($l in $foreign.InfantryTypes) { Out $l }
Out ''
Out '[VehicleTypes]'
$n = 1; foreach ($v in ($variants | Where-Object { -not $_.Inf })) { Out ('ZUV{0:D2}={1}2' -f $n, $v.Base); $n++ }
foreach ($l in $foreign.VehicleTypes) { Out $l }
Out ''
Out '; ---------------------------------------------------------------- keys added to the Zerg buildings'
Out ''
$labNote = 'Grows Zerg research: Structures tab.'
foreach ($p in (@($labs) + @($parents.Keys) | Select-Object -Unique)) {
  $base = Resolve-Sec $fac $p
  Out "[$p]"
  if ($labs -contains $p) {
    Out "Description=$(Clip ("$($base['Description'])@@$labNote"))"
    Out 'Factory=BuildingType	; research only: every other Zerg building is TechLevel=-1 (grown by a Drone)'
  }
  if ($parents.Contains($p)) {
    $here = ($research | Where-Object { $_.Parent -eq $p } | ForEach-Object { $_.Name }) -join ', '
    Out "Upgrades=$($parents[$p])	; research placed here: $here"
  }
  Out ''
}
Out '; ---------------------------------------------------------------- research (building upgrades)'
Out ''
$labNames = ($labs | ForEach-Object { $bldgName[$_] }) -join ', '
foreach ($r in $research) {
  $where = $bldgName[$r.Parent]
  $desc = "$where research.@@$($r.Text)@@Place it on the $where."
  if ($labs -notcontains $r.Parent) { $desc += ' Grown by any Zerg tech building (e.g. Evolution Chamber).' }
  Out "[$($r.Id)]"
  foreach ($kv in @(
    "Name=$($r.Name)", "Description=$(Clip $desc)", "Prerequisite=$($r.Pre)",
    "PowersUpBuilding=$($r.Parent)", 'PowersUpToLevel=-1', 'TechLevel=1', 'Owner=Nod1',
    "Cost=$($r.Cost)", 'Points=5', 'Strength=1000', 'Armor=wood', 'Power=0', 'Sight=1', 'Crewed=no', 'Capturable=no',
    'Explosion=FBALL1', 'ScrapExplosion=FBALL1', 'ThreatPosed=0', 'DeploySound=SCZBPLC', 'AIBuildThis=no')) { Out $kv }
  Out ''
}
Out '; ---------------------------------------------------------------- upgraded units (copies of the "Zerg faction" units)'
Out ''
$reqName = @{}; foreach ($r in $research) { $reqName[$r.Id] = $r.Name }
$newWeapons = [ordered]@{}
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
  if ($s.Contains('Strength')) { $s['Strength'] = Fmt-Num ([math]::Round((Num $s['Strength']) * $v.HP)) }
  if ($s.Contains('SelfHealingStep')) { $s['SelfHealingStep'] = Fmt-Num ([math]::Max(1, [math]::Round((Num $s['SelfHealingStep']) * $v.HP))) }   # same regen time as the base
  if ($v.Sight -and $s.Contains('Sight')) { $s['Sight'] = Fmt-Num ((Num $s['Sight']) + $v.Sight) }
  if ($v.SensorsAdd -and $s.Contains('SensorsSight')) { $s['SensorsSight'] = Fmt-Num ((Num $s['SensorsSight']) + $v.SensorsAdd) }
  if ($v.SpeedX -and $s.Contains('Speed')) { $s['Speed'] = Fmt-Num ([math]::Round((Num $s['Speed']) * $v.SpeedX)) }
  $weaponMod = ($v.Dmg -ne 1.0) -or $v.RofX -or $v.RangeX
  foreach ($slot in 'Primary','Secondary','ElitePrimary','EliteSecondary') {
    if (-not $weaponMod -or -not $s.Contains($slot) -or -not $s[$slot] -or $s[$slot] -eq 'none') { continue }
    $wName = $s[$slot]; $newName = "${wName}U"
    if (-not $newWeapons.Contains($newName)) {
      $w = Resolve-Sec $fac $wName
      if ($w.Count -eq 0) { Write-Warning "weapon $wName not in Terran Faction.ini, kept as is"; continue }
      if ($w.Contains('Damage') -and $v.Dmg -ne 1.0) { $w['Damage'] = Fmt-Num ([math]::Round((Num $w['Damage']) * $v.Dmg)) }
      if ($v.RofX -and $w.Contains('ROF')) { $w['ROF'] = Fmt-Num ([math]::Max(1, [math]::Round((Num $w['ROF']) * $v.RofX))) }
      if ($v.RangeX -and $w.Contains('Range')) { $w['Range'] = Fmt-Num ((Num $w['Range']) * $v.RangeX) }
      $newWeapons[$newName] = $w
    }
    $s[$slot] = $newName
  }
  Out "[$id]"
  foreach ($k in $s.Keys) { Out "$k=$($s[$k])" }
  Out ''
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
[IO.File]::WriteAllText($facPath, ($facBase.TrimEnd() -replace "`r?`n", $nl) + $nl + $nl + $block, $latin1)

# ---- StarCraft.ini (STARCRAFT checkbox) repeats [AI] BuildConst after the faction file: the labs must stay in it.
# Inserted before ",SCPNEX" so build-scprotoss.ps1's regex (which appends SCPNEX at the end if missing) keeps matching.
$opt = [IO.File]::ReadAllText($optPath, $latin1)
$opt = [regex]::Replace($opt, '(?m)^BuildConst=([^\r\n;]*?)(\s*(;[^\r\n]*)?)$', {
  param($m)
  $items = @($m.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $labs -notcontains $_ })
  $at = [Array]::IndexOf($items, 'SCPNEX'); if ($at -lt 0) { $at = $items.Count }
  $out = @(); if ($at -gt 0) { $out += $items[0..($at-1)] }; $out += $labs; if ($at -lt $items.Count) { $out += $items[$at..($items.Count-1)] }
  'BuildConst=' + ($out -join ',') + $m.Groups[2].Value })
[IO.File]::WriteAllText($optPath, $opt, $latin1)

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
[void]$ab.AppendLine('; Zerg research (Modding/tools/build-sczergresearch.ps1, MIX/ECACHE84.MIX): research icons + upgraded Zerg units (gold cameo)')
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
[Mix]::Write("$game\MIX\ECACHE84.MIX", $files)

# ------------------------------------------------------------------ report + checks + previews
$merged = Read-Ini ([IO.File]::ReadAllLines($facPath, $latin1))
foreach ($v in $variants) { foreach ($q in ($merged[$v.Id]['Prerequisite'] -split ',')) { if (-not $merged.ContainsKey($q) -and -not $merged['PrerequisiteGroups'].Contains($q)) { Write-Warning "$($v.Id): prerequisite $q undefined" } } }
foreach ($l in ([IO.File]::ReadAllLines($facPath, $latin1))) { if ($l -match '^Description=(.*)$' -and $matches[1].Length -gt 199) { Write-Warning "Description too long: $($l.Substring(0, 60))" } }
"ECACHE84.MIX: $($files.Count) files, $([Math]::Round((Get-Item "$game\MIX\ECACHE84.MIX").Length / 1KB)) KB"
"research: " + (($research | ForEach-Object { "$($_.Id)->$($_.Parent)" }) -join ', ')
"variants: " + (($variants | ForEach-Object { $_.Id }) -join ', ')
"weapons:  " + ($newWeapons.Keys -join ', ')
"parents:  " + (($parents.Keys | ForEach-Object { "$_ Upgrades=$($parents[$_])" }) -join ', ')
"labs:     " + ($labs -join ', ')
"BuildConst (faction): " + ($bcList -join ',')
"BuildConst (StarCraft.ini): " + (([regex]::Match($opt, '(?m)^BuildConst=([^\r\n;]*)')).Groups[1].Value)
$prev = New-Object 'System.Collections.Generic.List[Frame]'
foreach ($r in $research) { $prev.Add(([Shp]::Read($files["$($r.Id)IC.SHP"])).Frames[0]) }
foreach ($v in $variants) { $prev.Add(([Shp]::Read($files["$($v.Id)I.SHP"])).Frames[0]) }
[Pal]::Sheet($prev, [int[]](0..($prev.Count-1)), 64, 48, $cameoPal, 2, 8, "$PreviewDir\cameos.png")
"preview: $PreviewDir\cameos.png"
