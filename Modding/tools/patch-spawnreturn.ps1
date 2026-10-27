# Binary patch of game.exe (TS 2.03 + DTA): aircraft may take a FLYING non-aircraft unit as their move destination, so the
# Protoss Carrier's Interceptors (Vinifera spawner) fly back to the flying Carrier and dock.
# Cause (found with Modding/tools/spawnprobe.ps1 + Game.pdb/Vinifera.pdb, 2026-10-26): Vinifera's SpawnManagerClass::AI sends a
# returning spawn home with Assign_Destination(Owner), but AircraftClass::Assign_Destination (0x40E1B0) begins with
#     if (target->In_Air()) { FootClass::Assign_Destination(nullptr, ...); return; }      // vtable +0x58 = AbstractClass::In_Air
# so a Carrier with the Fly locomotor is refused: NavCom stays 0 and the Interceptors hang where they attacked.
# Patch: the In_Air() test stays (every AbstractClass has it, the destination is often a CellClass), and only a target that is
# in the air AND an aircraft is refused; its RTTI comes from the same IRTTITypeInfo call the function itself makes at 0x40E1E1
# ([obj+4] -> call [ecx+0Ch], stdcall). Flying vehicles (Protoss Carrier, Terran warships) are accepted, everything else as before.
#   0x40E1C5  FF 50 58 84 C0 74 15        call [eax+58h] / test al,al / je 0x40E1E1
#         ->  E9 <cave> 90 90             jmp cave
#   cave 0x86CF00 (zero tail of .p_text, executable; like the fly caves it lies past VirtualSize but inside the raw data):
#     call [eax+58h] ; test al,al ; je accept ; mov ecx,[edi+4] ; lea eax,[edi+4] ; push eax ; call [ecx+0Ch]
#     cmp eax,2 (RTTI_AIRCRAFT) ; je reject ; accept: jmp 0x40E1E1 ; reject: jmp 0x40E1CC
# The first version (2026-10-26, 7 bytes in place: What_Am_I via vtable +0x78) CRASHED: a CellClass destination has no such slot
# (jump to 0x66666666). Its bytes are recognised and replaced.
# Usage: patch-spawnreturn.ps1 [-Revert] [-Exe <copy>]. Backup game.exe.bak is the original (made by whichever patch ran first).
# All game.exe patches together (e.g. after a DTA update replaced game.exe): Modding/tools/patch-game.ps1. Wiki: engine/spawners.
param([switch]$Revert, [string]$Exe = "")
$ErrorActionPreference = 'Stop'
$exe = if ($Exe) { $Exe } else { "$((Resolve-Path "$PSScriptRoot\..\..").Path)\game.exe" }
$bytes = [IO.File]::ReadAllBytes($exe)

# VA -> file offset through the section table (the cave is in .p_text, not .text)
$pe = [BitConverter]::ToInt32($bytes, 0x3C); $nsec = [BitConverter]::ToInt16($bytes, $pe + 6); $optSize = [BitConverter]::ToInt16($bytes, $pe + 20)
$imageBase = [BitConverter]::ToInt32($bytes, $pe + 24 + 28); $secTab = $pe + 24 + $optSize
function Off([int]$va) {
    $rva = $va - $imageBase
    for ($i = 0; $i -lt $nsec; $i++) {
        $s = $secTab + 40 * $i; $sva = [BitConverter]::ToInt32($bytes, $s + 12); $rsize = [BitConverter]::ToInt32($bytes, $s + 16); $raw = [BitConverter]::ToInt32($bytes, $s + 20)
        if ($rva -ge $sva -and $rva -lt $sva + $rsize) { return $raw + ($rva - $sva) }
    }
    throw ("VA 0x{0:X} is not in the file" -f $va)
}
function Hex([string]$s) { return ,([byte[]]($s -split ' ' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })) }
function Jmp([int]$at, [int]$to) { $b = New-Object System.Collections.Generic.List[byte]; $b.Add(0xE9); $b.AddRange([BitConverter]::GetBytes([int]($to - ($at + 5)))); return ,$b.ToArray() }

$hook = 0x40E1C5; $cave = 0x86CF00
$cv = New-Object System.Collections.Generic.List[byte]
$cv.AddRange((Hex 'FF 50 58'))          # +0   call [eax+58h]        In_Air()
$cv.AddRange((Hex '84 C0'))             # +3   test al,al
$cv.AddRange((Hex '74 0F'))             # +5   je +0Fh -> +22 (accept)
$cv.AddRange((Hex '8B 4F 04'))          # +7   mov ecx,[edi+4]       IRTTITypeInfo of the target
$cv.AddRange((Hex '8D 47 04'))          # +10  lea eax,[edi+4]
$cv.AddRange((Hex '50'))                # +13  push eax
$cv.AddRange((Hex 'FF 51 0C'))          # +14  call [ecx+0Ch]        What_Am_I (stdcall)
$cv.AddRange((Hex '83 F8 02'))          # +17  cmp eax,2             RTTI_AIRCRAFT
$cv.AddRange((Hex '74 05'))             # +20  je +5 -> +27 (reject)
$cv.AddRange((Jmp ($cave + 22) 0x40E1E1))   # +22 accept: back to the normal path
$cv.AddRange((Jmp ($cave + 27) 0x40E1CC))   # +27 reject: destination = nullptr, as the original does for flying targets
if ($cv.Count -ne 32) { throw "cave layout $($cv.Count)" }
$hookNew = New-Object System.Collections.Generic.List[byte]; $hookNew.AddRange((Jmp $hook $cave)); $hookNew.AddRange((Hex '90 90'))

$sites = @(
    @{ VA = $cave; Orig = (New-Object byte[] 32);               New = $cv.ToArray() }
    @{ VA = $hook; Orig = (Hex 'FF 50 58 84 C0 74 15');         New = $hookNew.ToArray(); Legacy = (Hex 'FF 50 78 3C 02 75 15') }
)

function Is([byte[]]$want, [int]$va) { $o = Off $va; for ($i = 0; $i -lt $want.Length; $i++) { if ($bytes[$o + $i] -ne $want[$i]) { return $false } }; return $true }
$from = if ($Revert) { 'New' } else { 'Orig' }; $to = if ($Revert) { 'Orig' } else { 'New' }
$todo = @($sites | Where-Object { -not (Is $_[$to] $_.VA) })
if ($todo.Count -eq 0) { "already $(if ($Revert) { 'original' } else { 'patched' }), nothing to do"; return }
foreach ($s in $todo) {
    if (Is $s[$from] $s.VA) { continue }
    if ($s.Legacy -and (Is $s.Legacy $s.VA)) { "replacing the crashing first version at 0x{0:X}" -f $s.VA; continue }
    throw ("unexpected bytes at 0x{0:X} (different game.exe version, or the cave is used by another patch?)" -f $s.VA)
}
if (-not $Revert -and -not (Test-Path "$exe.bak")) { Copy-Item $exe "$exe.bak"; "backup: $exe.bak" }
foreach ($s in $todo) { [Array]::Copy([byte[]]$s[$to], 0, $bytes, (Off $s.VA), $s[$to].Length) }
[IO.File]::WriteAllBytes($exe, $bytes)
"{0}: {1} of {2} sites written" -f $(if ($Revert) { 'reverted' } else { 'patched' }), $todo.Count, $sites.Count
