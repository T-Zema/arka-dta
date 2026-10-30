# Binary patch of Vinifera.dll (DTA 16.2.3 build, see $builds): the computer can play the Protoss, whose factories and
# vehicles are Naval=yes on land (the Vinifera naval-yard exit is how SC units appear next to the Robotics Facility and the
# Stargate, wiki mods/protoss-faction). Wiki: engine/skirmish-ai, engine/advanced-ai, mods/protoss-ai.
# Source: Vinifera source (houseext.cpp HouseClassExtension::AI_Unit, houseext_hooks.cpp _Find_Build_Location) + disassembly of
# this Vinifera.dll (capstone) + Vinifera.pdb (names, field offsets).
#
# A) Advanced AI (AdvancedAI_AI_Unit 0x100BBF0F): a replacement harvester (Probe) and a replacement MCV (Nexus warp-in SCPDNEX)
#    are put into the LAND queue House->BuildUnit (+0x448). No land factory builds a Naval=yes unit, so the queue stays full
#    for ever: HouseClass::AI then skips AI_Infantry/AI_Aircraft (Vinifera hook 0x4BD0BC: "building a harvester") and
#    AI_Building (_Production_Check: a queued unit somebody can build) -> the Protoss AI froze after its first Probe loss.
#    Patch: a Naval=yes unit goes into the naval queue HouseClassExtension::BuildNavalUnit (+0x34) instead, which the naval
#    factories (PRODFLAG_NAVAL, Suggest_New_Object) take. Other houses: their harvesters/MCVs are not naval, nothing changes.
#    0x100BC0F9  89 86 48 04 00 00 E9 61 02 00 00     mov [esi+448h],eax / jmp 0x100BC365   (esi = house, edi = extension,
#                                                    eax = UnitType heap id; UnitTypes vector of game.exe at 0x7E2218)
# B) Classic AI (HouseClassExtension::AI_Unit, Advanced AI unchecked): the same for the replacement harvester.
#    0x100BB028  8B 88 78 04 00 00 89 8A 48 04 00 00 E9 2C 03 00 00   mov ecx,[eax+478h] / mov [edx+448h],ecx / jmp 0x100BB365
#                                                    (eax = UnitTypeClass*, edx = house, esi = extension)
# C) Classic AI placement (_Find_Build_Location): every Naval=yes building was placed on WATER near a construction yard, so the
#    AI never found a place for the Robotics Facility/Stargate on land and its build queue stopped. Patch: the water branch
#    only for WaterBound=yes buildings (game.exe BuildingTypeClass::Read_INI sets TechnoTypeClass::Speed +0x358 = SPEED_FLOAT 5
#    for them, 0x440B7A), i.e. DTA's real shipyards keep it. (Advanced AI places buildings elsewhere and already does this.)
#    0x100C6976  80 B8 F1 02 00 00 00 0F 84 AF 01 00 00   cmp byte [eax+2F1h],0 (ext IsNaval) / je land   (edi = BuildingType)
# Offsets (Vinifera.pdb): TechnoTypeClassExtension::IsNaval +0x2F1, HouseClassExtension::BuildNavalUnit +0x34,
# HouseClass::BuildUnit +0x448, UnitTypeClass heap id +0x478. Extension::Private::Fetch_Internal thunk 0x1003949A (ecx = object).
# The caves live in a new section ".scai" appended after the others; calls/jumps into the DLL are relative and the only absolute
# address is game.exe's (never relocated), so a relocated DLL still works.
# Order (patch-vinifera.ps1): workers (.scdock) -> veins -> overlord (.scstor) -> this. Revert in reverse order (this one first).
# Usage: patch-vinifera-navalai.ps1 [-Revert] [-Dll <copy>]. Close the game first.
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

$name = '.scai'; $secSize = 0x200
# per Vinifera build, told by the PE TimeDateStamp (the patches never change it)
$builds = @{
    '6AD94075' = @{ Name = 'DTA 16.2.3'; A = 0x100BC0F9; ARet = 0x100BC365; B = 0x100BB028; BRet = 0x100BB365
                    C = 0x100C6976; CLand = 0x100C6B32; CNaval = 0x100C6983; Fetch = 0x1003949A }
}
$build = $builds['{0:X8}' -f [BitConverter]::ToUInt32($bytes, $pe + 8)]
if (-not $build) { throw ("Vinifera.dll build 0x{0:X8} is unknown: not the Vinifera.dll this patch was made for (port it: add a build)" -f [BitConverter]::ToUInt32($bytes, $pe + 8)) }
$sites = @(
    @{ Va = $build.A; Orig = (Hex '89 86 48 04 00 00 E9 61 02 00 00') },
    @{ Va = $build.B; Orig = (Hex '8B 88 78 04 00 00 89 8A 48 04 00 00 E9 2C 03 00 00') },
    @{ Va = $build.C; Orig = (Hex '80 B8 F1 02 00 00 00 0F 84 AF 01 00 00') })
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
    # later patches (siegeai .scsiege) append sections after this one: find it by name
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
# cave A (Advanced AI): eax = heap id of the unit to queue
$cA = Here
Emit (Hex '50')                         # push eax
Emit (Hex '8B 0D 1C 22 7E 00')          # mov ecx,[7E221Ch]         game UnitTypes.Vector
Emit (Hex '8B 0C 81')                   # mov ecx,[ecx+eax*4]       UnitTypeClass*
$h = Here; Emit (Hex 'E8'); Emit (Rel $h 5 $build.Fetch)   # call Fetch_Internal -> extension
Emit (Hex '80 B8 F1 02 00 00 00')       # cmp byte [eax+2F1h],0     IsNaval
Emit (Hex '58')                         # pop eax
Emit (Hex '75 0B')                      # jne naval
Emit (Hex '89 86 48 04 00 00')          # mov [esi+448h],eax        BuildUnit (as before)
$h = Here; Emit (Hex 'E9'); Emit (Rel $h 5 $build.ARet)
Emit (Hex '89 47 34')                   # naval: mov [edi+34h],eax  extension->BuildNavalUnit
$h = Here; Emit (Hex 'E9'); Emit (Rel $h 5 $build.ARet)
Align
# cave B (classic AI): eax = UnitTypeClass* of the harvester, edx = house, esi = extension
$cB = Here
Emit (Hex '50 52')                      # push eax / push edx
Emit (Hex '8B C8')                      # mov ecx,eax
$h = Here; Emit (Hex 'E8'); Emit (Rel $h 5 $build.Fetch)
Emit (Hex '80 B8 F1 02 00 00 00')       # cmp byte [eax+2F1h],0
Emit (Hex '5A 58')                      # pop edx / pop eax
Emit (Hex '8B 88 78 04 00 00')          # mov ecx,[eax+478h]        heap id
Emit (Hex '75 0B')                      # jne naval
Emit (Hex '89 8A 48 04 00 00')          # mov [edx+448h],ecx        BuildUnit
$h = Here; Emit (Hex 'E9'); Emit (Rel $h 5 $build.BRet)
Emit (Hex '89 4E 34')                   # naval: mov [esi+34h],ecx
$h = Here; Emit (Hex 'E9'); Emit (Rel $h 5 $build.BRet)
Align
# cave C (classic placement): eax = BuildingTypeClassExtension, edi = BuildingTypeClass
$cC = Here
Emit (Hex '80 B8 F1 02 00 00 00')       # cmp byte [eax+2F1h],0     IsNaval
$h = Here; Emit (Hex '0F 84'); Emit (Rel $h 6 $build.CLand)
Emit (Hex '83 BF 58 03 00 00 05')       # cmp dword [edi+358h],5    Speed == SPEED_FLOAT (WaterBound=yes)
$h = Here; Emit (Hex '0F 85'); Emit (Rel $h 6 $build.CLand)
$h = Here; Emit (Hex 'E9'); Emit (Rel $h 5 $build.CNaval)    # water search as before
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
foreach ($s in @(@($sites[0], $cA), @($sites[1], $cB), @($sites[2], $cC))) {
    $o = TextOff $s[0].Va
    $out[$o] = 0xE9; [Array]::Copy((Rel $s[0].Va 5 $s[1]), 0, $out, $o + 1, 4)
    for ($i = 5; $i -lt $s[0].Orig.Length; $i++) { $out[$o + $i] = 0x90 }
}
[IO.File]::WriteAllBytes($target, $out)
"patched {0}: section {1} at 0x{2:X} ({3} bytes of caves), hooks 0x{4:X} 0x{5:X} 0x{6:X}" -f $target, $name, $caveVa, $cave.Count, $build.A, $build.B, $build.C
