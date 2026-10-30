# Binary patch of Vinifera.dll (DTA 16.2.2 and 16.2.3 builds, see $builds; addresses below are 16.2.2): harvested tiberium that fits under the house's
# silo capacity but not into its storage buildings goes into one storage building anyway (over its own Storage), instead of
# being lost. Together with the game.exe patch tools/patch-overlordstorage.ps1 (vehicles with Storage= raise House->Capacity)
# this makes the Zerg Overlord (Storage=100) a silo. Wiki: plans/overlord-storage, engine/houses-economy.
# Vinifera replaces HouseClass::Harvested with HouseClassExt::_Harvested (Vinifera.pdb, 0x100C5806, source houseext_hooks.cpp):
#     if (tiberium + Tiberium.Get_Total_Amount() > Capacity) tiberium = Capacity - Tiberium.Get_Total_Amount();
#     for each building b (b->IsDown && b->House == this && b->Class->Storage > 0)
#         while (tiberium > 0 && b->Storage.Get_Total_Amount() < b->Class->Storage) { b->Storage +1; Tiberium +1; tiberium--; }
#     Silo_Redraw_Check(oldtib, oldcap);
# Compiled: edi = tiberium left, esi = this, [ebp+0Ch] = slot, [ebp-4] = &Tiberium, ebx free (pushed/popped by the function).
# Hook after the loop, at the argument pushes of Silo_Redraw_Check:
#   0x100C5929  FF 75 F4 8B CE FF 75 F0   push [ebp-0Ch] / mov ecx,esi / push [ebp-10h]   ->  E9 <cave> 90 90 90
# Cave (new section ".scstor" after ".scdock"): if edi > 0, the first building of this house with IsDown and Class->Storage > 0
# gets b->Storage.Increase_Amount(edi, slot) and Tiberium.Increase_Amount(edi, slot); then the original pushes and back to
# 0x100C5931 (call Silo_Redraw_Check). Buildings vector = game.exe DynamicVectorClass at 0x7E4708 (Vector 0x7E470C, ActiveCount
# 0x7E4718; Vinifera's [0x10522C30] points there). Increase_Amount through Vinifera's thunk 0x1019585F (relative call), game
# addresses are absolute (game.exe is never relocated), so a relocated DLL still works.
# Spending (game.exe Spend_Money) takes tiberium from any building's storage, so an over-full building pays out normally; Vinifera
# draws at most Max_Pips pips, so it just shows a full bar. If the over-full building is destroyed, its whole content is lost.
# Order: patch-vinifera-workers.ps1 (.scdock) -> patch-vinifera-veins.ps1 -> this. Revert in reverse order (this one first).
# Usage: patch-vinifera-overlord.ps1 [-Revert] [-Dll <copy>]. Close the game first.
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

$name = '.scstor'; $secSize = 0x200
# per Vinifera build, told by the PE TimeDateStamp (the patches never change it); 16.2.3: same code at other addresses
$builds = @{
    '6AC3EA33' = @{ Name = 'DTA 16.2.2'; Hook = 0x100C5929; IncAmount = 0x1019585F }
    '6AD94075' = @{ Name = 'DTA 16.2.3'; Hook = 0x100C6C6F; IncAmount = 0x101975FA }
}
$build = $builds['{0:X8}' -f [BitConverter]::ToUInt32($bytes, $pe + 8)]
if (-not $build) { throw ("Vinifera.dll build 0x{0:X8} is unknown: not the Vinifera.dll this patch was made for (port it: add a build)" -f [BitConverter]::ToUInt32($bytes, $pe + 8)) }
$HookVa = $build.Hook; $HookRet = $HookVa + 8; $HookOrig = Hex 'FF 75 F4 8B CE FF 75 F0'
$IncAmount = $build.IncAmount   # Vinifera thunk (mov eax,60ADE0h / jmp eax) -> game StorageClass::Increase_Amount
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
    [Array]::Copy($HookOrig, 0, $out, (TextOff $HookVa), $HookOrig.Length)
    [IO.File]::WriteAllBytes($target, $out); "reverted $target"; return
}

if ($have) {
    # later patches (navalai .scai, siegeai .scsiege) append sections after this one: find it by name
    $mine = $null; for ($i = 0; $i -lt $nsec; $i++) { if ((SecName $i) -eq $name) { $mine = $secTab + 40 * $i } }
    $newRva = [BitConverter]::ToInt32($bytes, $mine + 12); $newRaw = [BitConverter]::ToInt32($bytes, $mine + 20)
} else {
    $t0 = $secTab; if ((SecName 0) -ne '.text' -or [BitConverter]::ToInt32($bytes, $t0 + 12) -ne 0x1000 -or [BitConverter]::ToInt32($bytes, $t0 + 20) -ne 0x400) { throw "unexpected .text layout" }
    $o = TextOff $HookVa
    for ($i = 0; $i -lt $HookOrig.Length; $i++) { if ($bytes[$o + $i] -ne $HookOrig[$i]) { throw ("bytes at 0x{0:X} differ: not the Vinifera.dll this patch was made for" -f $HookVa) } }
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
Emit (Hex '85 FF')                      # +00  test edi,edi              tiberium left over
Emit (Hex '7E 58')                      # +02  jle done (+5C)
Emit (Hex '8B 0D 18 47 7E 00')          # +04  mov ecx,[7E4718h]         Buildings.ActiveCount
Emit (Hex '85 C9')                      # +0A  test ecx,ecx
Emit (Hex '7E 4E')                      # +0C  jle done
Emit (Hex '8B 15 0C 47 7E 00')          # +0E  mov edx,[7E470Ch]         Buildings.Vector
Emit (Hex '8B 1A')                      # +14  loop: mov ebx,[edx]
Emit (Hex '85 DB')                      # +16  test ebx,ebx
Emit (Hex '74 1D')                      # +18  je next (+37)
Emit (Hex '80 7B 2C 00')                # +1A  cmp byte [ebx+2Ch],0      IsDown
Emit (Hex '74 17')                      # +1E  je next
Emit (Hex '39 B3 EC 00 00 00')          # +20  cmp [ebx+0ECh],esi        House == this
Emit (Hex '75 0F')                      # +26  jne next
Emit (Hex '8B 83 20 02 00 00')          # +28  mov eax,[ebx+220h]        Class
Emit (Hex '83 B8 EC 03 00 00 00')       # +2E  cmp dword [eax+3ECh],0    Class->Storage
Emit (Hex '7F 08')                      # +35  jg found (+3F)
Emit (Hex '83 C2 04')                   # +37  next: add edx,4
Emit (Hex '49')                         # +3A  dec ecx
Emit (Hex '75 D7')                      # +3B  jnz loop (+14)
Emit (Hex 'EB 1D')                      # +3D  jmp done
Emit (Hex 'FF 75 0C')                   # +3F  found: push [ebp+0Ch]     slot
Emit (Hex '57')                         # +42  push edi                  amount
Emit (Hex '8D 8B 68 01 00 00')          # +43  lea ecx,[ebx+168h]        b->Storage
$h = Here; Emit (Hex 'E8'); Emit (Rel $h 5 $IncAmount)   # +49  call Increase_Amount
Emit (Hex 'FF 75 0C')                   # +4E  push [ebp+0Ch]
Emit (Hex '57')                         # +51  push edi
Emit (Hex '8B 4D FC')                   # +52  mov ecx,[ebp-4]           &this->Tiberium
$h = Here; Emit (Hex 'E8'); Emit (Rel $h 5 $IncAmount)   # +55  call Increase_Amount
Emit (Hex '33 FF')                      # +5A  xor edi,edi
Emit $HookOrig                             # +5C  done: the replaced pushes of Silo_Redraw_Check
$h = Here; Emit (Hex 'E9'); Emit (Rel $h 5 $HookRet)        # +64  back to the call
if ($cave.Count -ne 0x69) { throw ("cave layout 0x{0:X}" -f $cave.Count) }
$img = New-Object byte[] $secSize; [Array]::Copy($cave.ToArray(), $img, $cave.Count)

if ($have) {
    $same = $true; for ($i = 0; $i -lt $secSize; $i++) { if ($bytes[$newRaw + $i] -ne $img[$i]) { $same = $false; break } }
    if ($same) { "already patched"; return }
    [Array]::Copy($img, 0, $bytes, $newRaw, $secSize)
    [IO.File]::WriteAllBytes($target, $bytes)
    "updated the cave in {0} ({1} bytes)" -f $target, $cave.Count; return
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
$o = TextOff $HookVa
$out[$o] = 0xE9; [Array]::Copy((Rel $HookVa 5 $caveVa), 0, $out, $o + 1, 4)
for ($i = 5; $i -lt $HookOrig.Length; $i++) { $out[$o + $i] = 0x90 }
[IO.File]::WriteAllBytes($target, $out)
"patched {0}: section {1} at 0x{2:X} ({3} bytes), hook 0x{4:X}" -f $target, $name, $caveVa, $cave.Count, $HookVa
