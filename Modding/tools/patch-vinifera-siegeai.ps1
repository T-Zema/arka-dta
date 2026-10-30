# Binary patch of Vinifera.dll (DTA 16.2.3 build, see $builds): the computer uses Siege Tanks like SC (user 2026-10-30:
# "make it switch the Siege Tanks into siege mode; the DTA AI deploys the Enforcer, so it is possible").
# Wiki: engine/advanced-ai ("Deploying units"), mods/terran-ai.
# Source: disassembly of this Vinifera.dll + game.exe (capstone), Vinifera.pdb (names, vtable slots, offsets).
#
# How the DTA AI deploys the Enforcer: Vinifera's UnitClassExt::_Do_MISSION_HUNT (0x101157E3, replaces game.exe
# UnitClass::Mission_Hunt 0x655270) deploys a unit with DeploysInto= when the house is human, or the DeploysInto is in
# [AI] BuildConst (MCV), or the unit HAS A TARGET. Hunt picks a target anywhere on the map, so a computer deployer unfolds
# as soon as its team starts hunting, wherever it stands. AdvAI_Undeploy_Enforcers (0x100C3B89) later folds idle ones
# (building with UndeploysInto=, no TarCom, the undeployed type has a Primary weapon; every 2250 frames), but only for
# [Houses] index 2 (Allies).
# A) 0x10115815 (_Do_MISSION_HUNT, the "has a target" test, 23 bytes): a computer unit deploys only when its target is in
#    range of its own primary weapon (ObjectClass::In_Range(Coord&, WeaponSlotType), vtable +0x138; target coordinate from
#    AbstractClass::Center_Coord, vtable +0x4C, safe for cells) and the unit can deploy where it stands (game 0x650680,
#    the same check the deploy step makes). Otherwise FootClass::Mission_Hunt: it drives to the target and fights unfolded.
#    Human units and MCVs as before. Changes every computer deployer the same way: Siege Tank, Enforcer, upgraded Vulture
#    (spider mines when an enemy is near), deploying ships.
#      orig: 39 BE 1C 01 00 00 75 0F 8B 8E EC 00 00 00 E8 14 22 08 00 84 C0 74 68
#            cmp [esi+11Ch],edi / jne deploy / mov ecx,[esi+ECh] / call Is_Human / test al,al / je base_hunt
# B) 0x100C3B93 (AdvAI_Undeploy_Enforcers, house check, 10 bytes): also for [Houses] index 6 (Terran GDI1), so sieged
#    tanks without a target fold back and rejoin the army.
#      orig: 83 78 60 02 0F 85 9F 00 00 00   cmp dword [eax+60h],2 / jne exit
# The caves live in a new section ".scsiege" appended after ".scai"; calls are relative (game thunks inside the DLL).
# Order (patch-vinifera.ps1): workers (.scdock) -> veins -> overlord (.scstor) -> navalai (.scai) -> this. Revert this first.
# Usage: patch-vinifera-siegeai.ps1 [-Revert] [-Dll <copy>]. Close the game first.
param([switch]$Revert, [string]$Dll = "")
$ErrorActionPreference = 'Stop'
# (PowerShell names are case-insensitive: $Dll is the parameter, $target the file; never name a variable $dll here)
$isCopy = [bool]$Dll
$target = if ($isCopy) { $Dll } else { "$((Resolve-Path "$PSScriptRoot\..\..").Path)\Vinifera.dll" }
if (-not $isCopy -and (Get-Process -Name game -ErrorAction SilentlyContinue)) { throw "game.exe is running: close the game first" }
$bytes = [IO.File]::ReadAllBytes($target)

$pe = [BitConverter]::ToInt32($bytes, 0x3C); $nsec = [BitConverter]::ToInt16($bytes, $pe + 6); $optSize = [BitConverter]::ToInt16($bytes, $pe + 20)
$opt = $pe + 24; $imageBase = [BitConverter]::ToInt32($bytes, $opt + 28); $secTab = $opt + $optSize
function Hex([string]$s) { return ,([byte[]]($s -split ' ' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })) }
function Rel([int]$at, [int]$len, [int]$to) { return ,([BitConverter]::GetBytes([int]($to - ($at + $len)))) }
function SecName([int]$i) { return [Text.Encoding]::ASCII.GetString($bytes, $secTab + 40 * $i, 8).TrimEnd([char]0) }
function TextOff([int]$va) { return $va - $imageBase - 0x1000 + 0x400 }

$name = '.scsiege'; $secSize = 0x200
# per Vinifera build, told by the PE TimeDateStamp (the patches never change it)
$builds = @{
    '6AD94075' = @{ Name = 'DTA 16.2.3'; A = 0x10115815;ADeploy = 0x1011582C; ABase = 0x10115894
                    IsHuman = 0x10197A3C; CanDeploy = 0x10196DC8; B = 0x100C3B93; BGo = 0x100C3B9D; BExit = 0x100C3C3C }
}
$build = $builds['{0:X8}' -f [BitConverter]::ToUInt32($bytes, $pe + 8)]
if (-not $build) { throw ("Vinifera.dll build 0x{0:X8} is unknown: not the Vinifera.dll this patch was made for (port it: add a build)" -f [BitConverter]::ToUInt32($bytes, $pe + 8)) }
$sites = @(
    @{ Va = $build.A; Orig = (Hex '39 BE 1C 01 00 00 75 0F 8B 8E EC 00 00 00 E8 14 22 08 00 84 C0 74 68') },
    @{ Va = $build.B; Orig = (Hex '83 78 60 02 0F 85 9F 00 00 00') })
$have = $false; for ($i = 0; $i -lt $nsec; $i++) { if ((SecName $i) -eq $name) { $have = $true } }
$last = $secTab + 40 * ($nsec - 1)

if ($Revert) {
    if (-not $have) { "not patched"; return }
    if ((SecName ($nsec - 1)) -ne $name) { throw "$name is not the last section" }
    $vs = [BitConverter]::ToInt32($bytes, $last + 8); $rva = [BitConverter]::ToInt32($bytes, $last + 12); $raw = [BitConverter]::ToInt32($bytes, $last + 20)
    $out = New-Object byte[] $raw
    [Array]::Copy($bytes, $out, $raw)
    for ($i = 0; $i -lt 40; $i++) { $out[$last + $i] = 0 }
    [Array]::Copy([BitConverter]::GetBytes([int16]($nsec - 1)), 0, $out, $pe + 6, 2)
    [Array]::Copy([BitConverter]::GetBytes([int]$rva), 0, $out, $opt + 56, 4)    # SizeOfImage = end of the previous section
    [Array]::Copy([BitConverter]::GetBytes([int]([BitConverter]::ToInt32($bytes, $opt + 4) - $vs)), 0, $out, $opt + 4, 4)
    foreach ($s in $sites) { [Array]::Copy($s.Orig, 0, $out, (TextOff $s.Va), $s.Orig.Length) }
    [IO.File]::WriteAllBytes($target, $out); "reverted $target"; return
}

if ($have) {
    # patches added later may append sections after this one: find it by name
    $mine = $null; for ($i = 0; $i -lt $nsec; $i++) { if ((SecName $i) -eq $name) { $mine = $secTab + 40 * $i } }
    $newRva = [BitConverter]::ToInt32($bytes, $mine + 12); $newRaw = [BitConverter]::ToInt32($bytes, $mine + 20)
} else {
    $t0 = $secTab; if ((SecName 0) -ne '.text' -or [BitConverter]::ToInt32($bytes, $t0 + 12) -ne 0x1000 -or [BitConverter]::ToInt32($bytes, $t0 + 20) -ne 0x400) { throw "unexpected .text layout" }
    foreach ($s in $sites) {
        $o = TextOff $s.Va
        for ($i = 0; $i -lt $s.Orig.Length; $i++) { if ($bytes[$o + $i] -ne $s.Orig[$i]) { throw ("bytes at 0x{0:X} differ: not the Vinifera.dll this patch was made for" -f $s.Va) } }
    }
    $secAlign = [BitConverter]::ToInt32($bytes, $opt + 32)
    $newRva = [BitConverter]::ToInt32($bytes, $last + 12) + [BitConverter]::ToInt32($bytes, $last + 8)
    $newRva = [int]([Math]::Ceiling($newRva / $secAlign) * $secAlign)
    $newRaw = [BitConverter]::ToInt32($bytes, $last + 20) + [BitConverter]::ToInt32($bytes, $last + 16)
    if ($newRaw -ne $bytes.Length) { throw "the DLL has data after its last section" }
    $hdrEnd = $secTab + 40 * $nsec
    for ($i = 0; $i -lt 40; $i++) { if ($bytes[$hdrEnd + $i] -ne 0) { throw "no room for a section header" } }
    if ($hdrEnd + 40 -gt [BitConverter]::ToInt32($bytes, $opt + 60)) { throw "no room for a section header" }
}
$caveVa = $imageBase + $newRva

$cave = New-Object System.Collections.Generic.List[byte]
function Emit([byte[]]$b) { $cave.AddRange($b) }
function Here { return $caveVa + $cave.Count }
function Align { while ($cave.Count % 16) { Emit (Hex 'CC') } }
function Jcc([string]$op, [int]$to) { $h = Here; Emit (Hex $op); Emit (Rel $h (($op -split ' ').Count + 4) $to) }
# cave A (_Do_MISSION_HUNT): esi = unit, edi = 0 (both must survive), the unit has DeploysInto= that is not a construction yard
$cA = Here
Emit (Hex '8B 8E EC 00 00 00')          # mov ecx,[esi+ECh]          House
Jcc 'E8' $build.IsHuman                 # call Is_Human
Emit (Hex '84 C0')                      # test al,al
Jcc '0F 85' $build.ADeploy              # human: deploy as before
Emit (Hex '8B 86 1C 01 00 00')          # mov eax,[esi+11Ch]         TarCom
Emit (Hex '85 C0')                      # test eax,eax
Jcc '0F 84' $build.ABase                # computer without a target: hunt
Emit (Hex '83 EC 0C')                   # sub esp,0Ch                Coord on the stack
Emit (Hex '54')                         # push esp                   (its address)
Emit (Hex '8B C8')                      # mov ecx,eax
Emit (Hex '8B 10')                      # mov edx,[eax]
Emit (Hex 'FF 52 4C')                   # call [edx+4Ch]             TarCom->Center_Coord(&coord), eax = &coord
Emit (Hex '6A 00')                      # push 0                     WEAPON_SLOT_PRIMARY
Emit (Hex '50')                         # push eax
Emit (Hex '8B CE')                      # mov ecx,esi
Emit (Hex '8B 16')                      # mov edx,[esi]
Emit (Hex 'FF 92 38 01 00 00')          # call [edx+138h]            In_Range(coord, primary)
Emit (Hex '83 C4 0C')                   # add esp,0Ch
Emit (Hex '84 C0')                      # test al,al
Jcc '0F 84' $build.ABase                # out of range: hunt (drive closer, fight unfolded)
Emit (Hex '8B CE')                      # mov ecx,esi
Jcc 'E8' $build.CanDeploy               # call: can it deploy here?
Emit (Hex '84 C0')                      # test al,al
Jcc '0F 84' $build.ABase                # no room: keep fighting unfolded
Jcc 'E9' $build.ADeploy                 # deploy
Align
# cave B (AdvAI_Undeploy_Enforcers): eax = HouseTypeClass*, ecx = house (must survive)
$cB = Here
Emit (Hex '83 78 60 02')                # cmp dword [eax+60h],2      Allies
Emit (Hex '74 0B')                      # je go
Emit (Hex '83 78 60 06')                # cmp dword [eax+60h],6      Terran (GDI1)
Emit (Hex '74 05')                      # je go
Jcc 'E9' $build.BExit
Jcc 'E9' $build.BGo                     # go:
$img = New-Object byte[] $secSize; [Array]::Copy($cave.ToArray(), $img, $cave.Count)

if ($have) {
    $same = $true; for ($i = 0; $i -lt $secSize; $i++) { if ($bytes[$newRaw + $i] -ne $img[$i]) { $same = $false; break } }
    if ($same) { "already patched"; return }
    [Array]::Copy($img, 0, $bytes, $newRaw, $secSize)
    [IO.File]::WriteAllBytes($target, $bytes)
    "updated the caves in {0} ({1} bytes)" -f $target, $cave.Count; return
}

if (-not $isCopy -and -not (Test-Path "$target.bak")) { Copy-Item $target "$target.bak" }
$out = New-Object byte[] ($bytes.Length + $secSize)
[Array]::Copy($bytes, $out, $bytes.Length)
[Array]::Copy($img, 0, $out, $newRaw, $secSize)
$sh = New-Object byte[] 40
[Array]::Copy([Text.Encoding]::ASCII.GetBytes($name), $sh, $name.Length)
[Array]::Copy([BitConverter]::GetBytes([int]$secSize), 0, $sh, 8, 4)        # VirtualSize
[Array]::Copy([BitConverter]::GetBytes([int]$newRva), 0, $sh, 12, 4)        # VirtualAddress
[Array]::Copy([BitConverter]::GetBytes([int]$secSize), 0, $sh, 16, 4)       # SizeOfRawData
[Array]::Copy([BitConverter]::GetBytes([int]$newRaw), 0, $sh, 20, 4)        # PointerToRawData
[Array]::Copy([BitConverter]::GetBytes([int]0x60000020), 0, $sh, 36, 4)     # code | execute | read
[Array]::Copy($sh, 0, $out, $hdrEnd, 40)
[Array]::Copy([BitConverter]::GetBytes([int16]($nsec + 1)), 0, $out, $pe + 6, 2)
[Array]::Copy([BitConverter]::GetBytes([int]($newRva + $secAlign)), 0, $out, $opt + 56, 4)   # SizeOfImage
[Array]::Copy([BitConverter]::GetBytes([int]([BitConverter]::ToInt32($bytes, $opt + 4) + $secSize)), 0, $out, $opt + 4, 4)  # SizeOfCode
foreach ($s in @(@($sites[0], $cA), @($sites[1], $cB))) {
    $o = TextOff $s[0].Va
    $out[$o] = 0xE9; [Array]::Copy((Rel $s[0].Va 5 $s[1]), 0, $out, $o + 1, 4)
    for ($i = 5; $i -lt $s[0].Orig.Length; $i++) { $out[$o + $i] = 0x90 }
}
[IO.File]::WriteAllBytes($target, $out)
"patched {0}: section {1} at 0x{2:X} ({3} bytes of caves), hooks 0x{4:X} 0x{5:X}" -f $target, $name, $caveVa, $cave.Count, $build.A, $build.B
