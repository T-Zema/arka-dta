# Binary patch of game.exe (TS 2.03 + DTA): a building whose FreeUnit= is SCSCV gives TWO SCVs (Terran Refinery, user 2026-10-26).
# BuildingClass::Grand_Opening creates the FreeUnit in one block (0x42E56F .. 0x42E8E0): new unit, Unlimbo at the docking cell
# or a nearby free cell, Assign_Mission(MISSION_HARVEST), Commence; every exit goes through 0x42E909 (jmp 0x86AB70).
# Patch: after the first successful placement the block runs once more (the second SCV finds the dock cell taken and uses the
# nearby-cell path, as for a blocked dock). A flag in .p_data marks the second pass; the common exit 0x42E909 clears it, so a
# failed second placement (no free cell: the game refunds it) leaves no stale state.
#   0x42E8D6  8B 07 8B CF FF 90 A8 01 00 00 EB 27   mov eax,[edi] / mov ecx,edi / call [eax+1A8h] (Commence) / jmp 0x42E909
#         ->  E9 <cave1> 90 x7
#   0x42E909  E9 62 C2 43 00                         jmp 0x86AB70 (DTA code after the FreeUnit block)
#         ->  E9 <cave2>
#   cave1 0x86C300 (.p_text zero tail): Commence; if flag = 0 and FreeUnit IniName = "SCSCV" (AbstractTypeClass +0x14,
#         BuildingTypeClass::FreeUnit +0x4FC, building Class +0x220): flag = 1, jmp 0x42E56F; else jmp 0x42E909
#   cave2 0x86C350: flag = 0, jmp 0x86AB70
#   flag  0x86E400 (.p_data past VirtualSize 0x1CC, same page, writable)
# Usage: patch-freescv.ps1 [-Revert] [-Exe <copy>]. Backup game.exe.bak = original (made by whichever patch ran first).
# Included in Modding/tools/patch-game.ps1. Wiki: mods/sc-workers, engine/game-exe-patching.
param([switch]$Revert, [string]$Exe = "")
$ErrorActionPreference = 'Stop'
$exe = if ($Exe) { $Exe } else { "$((Resolve-Path "$PSScriptRoot\..\..").Path)\game.exe" }
$bytes = [IO.File]::ReadAllBytes($exe)

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
function Rel([int]$at, [int]$to) { return ,([BitConverter]::GetBytes([int]($to - ($at + 5)))) }
function Jmp([int]$at, [int]$to) { $b = New-Object System.Collections.Generic.List[byte]; $b.Add(0xE9); $b.AddRange((Rel $at $to)); return ,$b.ToArray() }

$hook1 = 0x42E8D6; $hook2 = 0x42E909; $cave1 = 0x86C300; $cave2 = 0x86C350; $flag = 0x86E400
$again = 0x42E56F; $exit = 0x42E909; $after = 0x86AB70
$flagB = [BitConverter]::GetBytes([int]$flag)

$c1 = New-Object System.Collections.Generic.List[byte]
function E1([byte[]]$b) { $c1.AddRange($b) }
E1 (Hex '8B 07 8B CF FF 90 A8 01 00 00')            # +0   unit->Commence() (moved original)
E1 (Hex '80 3D'); E1 $flagB; E1 (Hex '00')           # +10  cmp byte [flag],0
E1 (Hex '75 29')                                     # +17  jne exit (+60)
E1 (Hex '8B 86 20 02 00 00')                         # +19  mov eax,[esi+220h]   building->Class
E1 (Hex '8B 80 FC 04 00 00')                         # +25  mov eax,[eax+4FCh]   FreeUnit
E1 (Hex '81 78 14 53 43 53 43')                      # +31  cmp dword [eax+14h],"SCSC"
E1 (Hex '75 14')                                     # +38  jne exit
E1 (Hex '66 81 78 18 56 00')                         # +40  cmp word [eax+18h],"V\0"
E1 (Hex '75 0C')                                     # +46  jne exit
E1 (Hex 'C6 05'); E1 $flagB; E1 (Hex '01')           # +48  mov byte [flag],1
E1 (Jmp ($cave1 + 55) $again)                        # +55  run the FreeUnit block again
E1 (Jmp ($cave1 + 60) $exit)                         # +60  exit
if ($c1.Count -ne 65) { throw "cave1 layout $($c1.Count)" }
$c2 = New-Object System.Collections.Generic.List[byte]
$c2.AddRange((Hex 'C6 05')); $c2.AddRange($flagB); $c2.AddRange((Hex '00'))   # mov byte [flag],0
$c2.AddRange((Jmp ($cave2 + 7) $after))
$h1 = New-Object System.Collections.Generic.List[byte]; $h1.AddRange((Jmp $hook1 $cave1)); $h1.AddRange((Hex '90 90 90 90 90 90 90'))

$sites = @(
    @{ VA = $cave1; Orig = (New-Object byte[] $c1.Count); New = $c1.ToArray() }
    @{ VA = $cave2; Orig = (New-Object byte[] $c2.Count); New = $c2.ToArray() }
    @{ VA = $flag;  Orig = (Hex '00');                    New = (Hex '00') }
    @{ VA = $hook1; Orig = (Hex '8B 07 8B CF FF 90 A8 01 00 00 EB 27'); New = $h1.ToArray() }
    @{ VA = $hook2; Orig = (Hex 'E9 62 C2 43 00');        New = (Jmp $hook2 $cave2) }
)

function Is([byte[]]$want, [int]$va) { $o = Off $va; for ($i = 0; $i -lt $want.Length; $i++) { if ($bytes[$o + $i] -ne $want[$i]) { return $false } }; return $true }
$from = if ($Revert) { 'New' } else { 'Orig' }; $to = if ($Revert) { 'Orig' } else { 'New' }
$todo = @($sites | Where-Object { -not (Is $_[$to] $_.VA) })
if ($todo.Count -eq 0) { "already $(if ($Revert) { 'original' } else { 'patched' }), nothing to do"; return }
foreach ($s in $todo) {
    if (Is $s[$from] $s.VA) { continue }
    throw ("unexpected bytes at 0x{0:X} (different game.exe version, or the cave is used by another patch?)" -f $s.VA)
}
if (-not $Exe -and (Get-Process -Name game -ErrorAction SilentlyContinue)) { throw "game.exe is running: close the game first" }
if (-not $Revert -and -not $Exe -and -not (Test-Path "$exe.bak")) { Copy-Item $exe "$exe.bak"; "backup: $exe.bak" }
foreach ($s in $todo) { [Array]::Copy([byte[]]$s[$to], 0, $bytes, (Off $s.VA), $s[$to].Length) }
[IO.File]::WriteAllBytes($exe, $bytes)
"{0}: {1} of {2} sites written" -f $(if ($Revert) { 'reverted' } else { 'patched' }), $todo.Count, $sites.Count
