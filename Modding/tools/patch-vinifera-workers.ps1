# Binary patch of Vinifera.dll (DTA 16.2.2 and 16.2.3 builds, see $builds; checked by the original bytes): StarCraft workers bring resources to their
# main building (Command Center, Nexus, Hatchery/Lair/Hive) and play their SC gathering animation only while harvesting.
# Source: Vinifera source (houseext.cpp HouseClassExtension::Place_Object, unitext_hooks.cpp _UnitClass_Draw_Shape_IdleRate_Patch)
# + disassembly of this Vinifera.dll (capstone) + field offsets from Vinifera.pdb (llvm-pdbutil).
# Wiki: mods/sc-workers, engine/transform-deploy (one radio channel per building). Installed by tools/build-scworkers.ps1 -Install.
#
# A) + B) Building placement. When a building is placed, the building factory that "built" it (Who_Can_Build_Me) does
#    builder->Transmit_Message(RADIO_HELLO, tech) and then tech->Transmit_Message(RADIO_COMPLETE, builder). A building has ONE
#    radio channel, so a construction yard that is also a refinery loses its docked harvester at every placed building
#    (test 2026-10-25: SCVs stuck on the CC). Patch: both messages are skipped when the builder is a refinery
#    (BuildingTypeClass::IsRefinery). The only loss is the construction yard's "building" animation (SC buildings have none).
#    A) 0x100BCA54  8B 01 57 6A 02 FF 90 18 02 00 00           mov eax,[ecx] / push edi / push 2 / call [eax+218h]
#    B) 0x100BCB02  FF 75 0C 8B 07 8B CF 6A 0C FF 90 18 02 00 00  push [ebp+0Ch] / mov eax,[edi] / mov ecx,edi / push 0Ch / call
# C) SHP vehicle idle animation (Vinifera IdleRate/StartIdleFrame/IdleFrames): for a harvester type (UnitTypeClass::IsToHarvest)
#    it is drawn only while the unit is in MISSION_HARVEST (MissionClass::Mission +0x4C = 9) AND UnitClass::IsHarvesting is set
#    (the game sets it while collecting, 0x654C47, but clears it only in Do_MISSION_MOVE/PATROL/REPAIR, so after Stop/Guard it
#    stays set: user test 2026-10-26, idle workers kept "mining") AND its harvest state is HARVESTING (MissionClass::Status
#    +0x58 = 1; without a refinery Do_MISSION_HARVEST drops to Guard every time and the stale flag flashed the animation:
#    user test 2026-10-27, idle Zerg drones "chewing"); otherwise the standing frame. Units that are not harvesters
#    keep the idle animation as before (e.g. DTA [CTNK2T]). Running the script on an older patched DLL rewrites the caves.
#    C) 0x101153D6  8B 45 F8 39 B0 90 01 00 00 76 22           mov eax,[ebp-8] / cmp [eax+190h],esi / jbe 0x10115403
# Offsets (Vinifera.pdb): BuildingClass::Class +0x220, BuildingTypeClass::IsRefinery +0x81B, UnitTypeClass::IsToHarvest +0x48E,
# UnitClass::IsHarvesting +0x36E, UnitTypeClassExtension::IdleRate +0x190.
# The caves live in a new section ".scdock" appended to the DLL (the .text has no free run longer than 18 bytes); all jumps are
# relative, so a relocated DLL still works.
# Usage: patch-vinifera-workers.ps1 [-Revert] [-Dll <copy>]. -Revert undoes every byte itself (no backup needed); the first
# patch also leaves Vinifera.dll.bak (original). Close the game first.
# A DTA client update may replace Vinifera.dll: then run this again (it refuses a different Vinifera version).
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

$name = '.scdock'
$have = $false; $haveIdx = -1; for ($i = 0; $i -lt $nsec; $i++) { if ((SecName $i) -eq $name) { $have = $true; $haveIdx = $i } }
function TextOff([int]$va) { return $va - $imageBase - 0x1000 + 0x400 }

# ---- patch sites per Vinifera build (VA as linked; original bytes must match). The build is told by the PE TimeDateStamp,
# which the patches never change. 16.2.3 (2026-10-27): the same code at other addresses (byte patterns unique, disassembly of
# every site identical, struct offsets from Vinifera.pdb unchanged). V1 = patch-vinifera-veins.ps1's hook (for -Revert).
$builds = @{
    '6AC3EA33' = @{ Name = 'DTA 16.2.2'; A = 0x100BCA54; B = 0x100BCB02; C = 0x101153D6; V1 = 0x1003DDBA }
    '6AD94075' = @{ Name = 'DTA 16.2.3'; A = 0x100BDD77; B = 0x100BDE25; C = 0x101170D7; V1 = 0x1003E36F }
}
$build = $builds['{0:X8}' -f [BitConverter]::ToUInt32($bytes, $pe + 8)]
if (-not $build) { throw ("Vinifera.dll build 0x{0:X8} is unknown: not the Vinifera.dll this patch was made for (port it: add a build)" -f [BitConverter]::ToUInt32($bytes, $pe + 8)) }
$A = $build.A; $Aret = $A + 11; $AOrig = Hex '8B 01 57 6A 02 FF 90 18 02 00 00'
$B = $build.B; $Bret = $B + 15; $BOrig = Hex 'FF 75 0C 8B 07 8B CF 6A 0C FF 90 18 02 00 00'
$C = $build.C; $Cret = $C + 11; $Cskip = $C + 0x2D; $COrig = Hex '8B 45 F8 39 B0 90 01 00 00 76 22'

if ($Revert) {
    if (-not $have) { "not patched"; return }
    # patch-vinifera-veins.ps1 keeps its caves in .scdock + 0x100 and jumps there from AnimClassExt::_AI
    if ($bytes[(TextOff $build.V1)] -eq 0xE9) { throw "patch-vinifera-veins.ps1 uses this section: run it with -Revert first" }
    # patch-vinifera-overlord.ps1 appends its own section ".scstor" after this one
    if ((SecName ($nsec - 1)) -eq '.scstor') { throw "patch-vinifera-overlord.ps1 added a section after $name : run it with -Revert first" }
    # undone byte for byte (independent of the backup): drop the last section, restore the header fields and the 3 sites
    $last = $secTab + 40 * ($nsec - 1)
    if ((SecName ($nsec - 1)) -ne $name) { throw "$name is not the last section" }
    $vs = [BitConverter]::ToInt32($bytes, $last + 8); $rva = [BitConverter]::ToInt32($bytes, $last + 12); $raw = [BitConverter]::ToInt32($bytes, $last + 20)
    $out = New-Object byte[] $raw
    [Array]::Copy($bytes, $out, $raw)
    for ($i = 0; $i -lt 40; $i++) { $out[$last + $i] = 0 }
    [Array]::Copy([BitConverter]::GetBytes([int16]($nsec - 1)), 0, $out, $pe + 6, 2)
    [Array]::Copy([BitConverter]::GetBytes([int]$rva), 0, $out, $opt + 56, 4)
    [Array]::Copy([BitConverter]::GetBytes([int]([BitConverter]::ToInt32($bytes, $opt + 4) - $vs)), 0, $out, $opt + 4, 4)
    foreach ($s in @(@($A, $AOrig), @($B, $BOrig), @($C, $COrig))) { [Array]::Copy($s[1], 0, $out, (TextOff $s[0]), $s[1].Length) }
    [IO.File]::WriteAllBytes($target, $out); "reverted $target"; return
}
$secSize = 0x200
$last = $secTab + 40 * ($nsec - 1)
if ($have) {
    # already patched: the caves may be an older version -> rewrite only the section data (the hooks jump to the same offsets);
    # found by name, because patch-vinifera-overlord.ps1 may have appended ".scstor" after it
    $sec = $secTab + 40 * $haveIdx
    $newRva = [BitConverter]::ToInt32($bytes, $sec + 12); $newRaw = [BitConverter]::ToInt32($bytes, $sec + 20)
} else {
    # section layout of the original DLL: .text at RVA 0x1000 / file 0x400 (checked), new section after the last one
    $t0 = $secTab; if ((SecName 0) -ne '.text' -or [BitConverter]::ToInt32($bytes, $t0 + 12) -ne 0x1000 -or [BitConverter]::ToInt32($bytes, $t0 + 20) -ne 0x400) { throw "unexpected .text layout" }
    $secAlign = [BitConverter]::ToInt32($bytes, $opt + 32)
    $newRva = [BitConverter]::ToInt32($bytes, $last + 12) + [BitConverter]::ToInt32($bytes, $last + 8)
    $newRva = [int]([Math]::Ceiling($newRva / $secAlign) * $secAlign)
    $newRaw = [BitConverter]::ToInt32($bytes, $last + 20) + [BitConverter]::ToInt32($bytes, $last + 16)
    if ($newRaw -ne $bytes.Length) { throw "the DLL has data after its last section" }
    $hdrEnd = $secTab + 40 * $nsec
    for ($i = 0; $i -lt 40; $i++) { if ($bytes[$hdrEnd + $i] -ne 0) { throw "no room for a section header" } }
    if ($hdrEnd + 40 -gt [BitConverter]::ToInt32($bytes, $opt + 60)) { throw "no room for a section header" }
    foreach ($s in @(@($A, $AOrig), @($B, $BOrig), @($C, $COrig))) {
        $o = TextOff $s[0]
        for ($i = 0; $i -lt $s[1].Length; $i++) { if ($bytes[$o + $i] -ne $s[1][$i]) { throw ("bytes at 0x{0:X} differ: not the Vinifera.dll this patch was made for" -f $s[0]) } }
    }
}
$caveVa = $imageBase + $newRva

$cave = New-Object System.Collections.Generic.List[byte]
function Emit([byte[]]$b) { $cave.AddRange($b) }
function Here { return $caveVa + $cave.Count }
# cave A: builder (ecx) is a refinery -> no RADIO_HELLO
$cA = Here
Emit (Hex '8B 81 20 02 00 00')          # mov eax,[ecx+220h]       builder->Class
Emit (Hex '80 B8 1B 08 00 00 00')       # cmp byte [eax+81Bh],0    IsRefinery
Emit (Hex '75 0B')                      # jne skip
Emit $AOrig                             # builder->Transmit_Message(RADIO_HELLO, tech)
$h = Here; Emit (Hex 'E9'); Emit (Rel $h 5 $Aret)
while ($cave.Count % 16) { Emit (Hex 'CC') }
# cave B: builder ([ebp+0Ch]) is a refinery -> no RADIO_COMPLETE
$cB = Here
Emit (Hex '8B 45 0C')                   # mov eax,[ebp+0Ch]        builder
Emit (Hex '8B 80 20 02 00 00')          # mov eax,[eax+220h]
Emit (Hex '80 B8 1B 08 00 00 00')       # cmp byte [eax+81Bh],0
Emit (Hex '75 0F')                      # jne skip
Emit $BOrig                             # tech->Transmit_Message(RADIO_COMPLETE, builder)
$h = Here; Emit (Hex 'E9'); Emit (Rel $h 5 $Bret)
while ($cave.Count % 16) { Emit (Hex 'CC') }
# cave C: idle frames of a harvester only while it is harvesting
$cC = Here
Emit (Hex '8B 45 F8')                   # mov eax,[ebp-8]          UnitTypeClassExtension
Emit (Hex '39 B0 90 01 00 00')          # cmp [eax+190h],esi       IdleRate vs 0
$h = Here; Emit (Hex '0F 86'); Emit (Rel $h 6 $Cskip)   # jbe -> no idle frame
Emit (Hex '80 BB 8E 04 00 00 00')       # cmp byte [ebx+48Eh],0    UnitTypeClass::IsToHarvest
$jeIdle = $cave.Count; Emit (Hex '74 00')   # je idle (not a harvester), displacement set below
Emit (Hex '80 BF 6E 03 00 00 00')       # cmp byte [edi+36Eh],0    UnitClass::IsHarvesting
$h = Here; Emit (Hex '0F 84'); Emit (Rel $h 6 $Cskip)   # je -> standing frame
Emit (Hex '83 7F 4C 09')                # cmp dword [edi+4Ch],9    MissionClass::Mission == MISSION_HARVEST
$h = Here; Emit (Hex '0F 85'); Emit (Rel $h 6 $Cskip)   # jne -> standing frame (IsHarvesting stays set after Stop/Guard)
Emit (Hex '83 7F 58 01')                # cmp dword [edi+58h],1    MissionClass::Status == HARVESTING (LOOKING=0, FINDHOME=2...)
$h = Here; Emit (Hex '0F 85'); Emit (Rel $h 6 $Cskip)   # jne -> standing frame (no refinery: Harvest<->Guard loop in LOOKING)
$cave[$jeIdle + 1] = [byte]($cave.Count - ($jeIdle + 2))
$h = Here; Emit (Hex 'E9'); Emit (Rel $h 5 $Cret)       # idle: frame computation (eax = extension)
# this script owns the first 0x100 bytes of the section; patch-vinifera-veins.ps1 has the rest
$own = 0x100
if ($cave.Count -gt $own) { throw "cave too big" }

if ($have) {
    $img = New-Object byte[] $own; [Array]::Copy($cave.ToArray(), $img, $cave.Count)
    $same = $true; for ($i = 0; $i -lt $own; $i++) { if ($bytes[$newRaw + $i] -ne $img[$i]) { $same = $false; break } }
    if ($same) { "already patched"; return }
    [Array]::Copy($img, 0, $bytes, $newRaw, $own)
    [IO.File]::WriteAllBytes($target, $bytes)
    "updated the caves in {0} ({1} bytes)" -f $target, $cave.Count; return
}

# ---- write: backup, section header, section data, hooks
if (-not $isCopy -and -not (Test-Path "$target.bak")) { Copy-Item $target "$target.bak" }
$out = New-Object byte[] ($bytes.Length + $secSize)
[Array]::Copy($bytes, $out, $bytes.Length)
[Array]::Copy($cave.ToArray(), 0, $out, $newRaw, $cave.Count)
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
foreach ($s in @(@($A, $cA, $AOrig.Length), @($B, $cB, $BOrig.Length), @($C, $cC, $COrig.Length))) {
    $o = TextOff $s[0]
    $out[$o] = 0xE9; [Array]::Copy((Rel $s[0] 5 $s[1]), 0, $out, $o + 1, 4)
    for ($i = 5; $i -lt $s[2]; $i++) { $out[$o + $i] = 0x90 }
}
[IO.File]::WriteAllBytes($target, $out)
"patched {0}: section {1} at 0x{2:X} ({3} bytes of caves), hooks 0x{4:X} 0x{5:X} 0x{6:X}" -f $target, $name, $caveVa, $cave.Count, $A, $B, $C
