# Binary patch of game.exe (TS 2.03 + DTA): Zerg building rules on creep (user 2026-10-27, mods/zerg-creep).
#   - Only Zerg buildings (type IniName SCZ*) may be built on creep (overlay VEINS / VEINHOLEDUMMY). Decided by the type, not
#     the house: UnitClass::Try_To_Deploy checks Legal_Placement(cell, NULL).
#   - Zerg buildings need creep under every foundation cell, except Hatchery/Lair/Hive/Infested CC (Factory=UnitType), the
#     Extractor (Refinery=yes) and 1x1 non-wall buildings (burrowed Lurker). The Creep Tumor needs creep, as in SC2.
# A wrapper around CellClass::Is_Clear_To_Build (0x452250): sidebar placement, MCV/drone deploy (Legal_Placement),
# BuildingClass::Mark at Unlimbo and the placement grid colours all go through it. Source: patch-zergbuild.asm.
#      0x452250  A1 94 43 7E 00  mov eax,[7E4394h]   ->  E9 <cave>       (first instruction, repeated in the cave)
#      cave 0x86CD00-0x86CD9B (.p_text, see the cave registry in Modding/wiki/engine/game-exe-patching.md)
# Placement grid while the deploy cursor is over a selected unit that deploys into a building (Zerg drones, MCVs...): the
# building's foundation is drawn where Try_To_Deploy would put it, green/red from Is_Clear_To_Build (creep rules included).
# Source: patch-zergbuild-grid.asm. Tactical::Render calls Draw_Placement twice; both calls go to the cave:
#      0x611ADC  E8 EF 02 00 00  call 0x611DD0  ->  call <cave2>     0x611B65  E8 66 02 00 00  ->  call <cave2>
#      cave2 0x86CA00-0x86CB2D (v2 uses 261 bytes: a grid for every selected deployer; v1 matched the mouse cell and never drew)
# Usage: patch-zergbuild.ps1 [-Revert] [-Exe <copy>]. Included in Modding/tools/patch-game.ps1.
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
function Jmp([int]$at, [int]$to) { $b = New-Object System.Collections.Generic.List[byte]; $b.Add(0xE9); $b.AddRange([BitConverter]::GetBytes([int]($to - ($at + 5)))); return ,$b.ToArray() }

$hook = 0x452250; $cave = 0x86CD00
# nasm output of patch-zergbuild.asm (org 0x86CD00), v2: Zerg decided by the building type name (SCZ*)
$c = Hex ('56 57 89 CE FF 74 24 14 FF 74 24 14 FF 74 24 14 89 F1 E8 6B 00 00 00 84 C0 74 62 83 3D 94 43 7E 00 00 75 59 8B 7C 24 10 ' +
    '85 FF 74 51 31 D2 66 81 7F 14 53 43 75 07 80 7F 16 5A 75 01 42 8B 4E 30 83 F9 7E 74 32 81 F9 B2 00 00 00 74 2A 85 D2 74 2C 83 ' +
    'BF 08 05 00 00 28 74 23 80 BF 1B 08 00 00 00 75 1A 83 BF 28 05 00 00 00 75 0F 80 BF 09 08 00 00 00 74 08 EB 04 85 D2 75 02 31 ' +
    'C0 5F 5E C2 0C 00 A1 94 43 7E 00 E9 C9 54 BE FF')
if ($c.Length -ne 140) { throw "cave layout $($c.Length)" }
$c = [byte[]]$c + (New-Object byte[] 16)      # the cave keeps 156 bytes (size of v1)
# v1 (2026-10-27, Zerg = house type Nod1; deploy checks Legal_Placement without a house, so drones were never restricted)
$v1 = Hex ('56 57 89 CE FF 74 24 14 FF 74 24 14 FF 74 24 14 89 F1 E8 7B 00 00 00 84 C0 74 72 83 3D 94 43 7E 00 00 75 69 8B 7C 24 10 ' +
    '85 FF 74 61 8B 4C 24 14 85 C9 74 59 8B 49 24 85 C9 74 52 31 D2 81 79 14 4E 6F 64 31 75 07 80 79 18 00 75 01 42 8B 4E 30 83 F9 ' +
    '7E 74 32 81 F9 B2 00 00 00 74 2A 85 D2 74 2C 83 BF 08 05 00 00 28 74 23 80 BF 1B 08 00 00 00 75 1A 83 BF 28 05 00 00 00 75 0F ' +
    '80 BF 09 08 00 00 00 74 08 EB 04 85 D2 75 02 31 C0 5F 5E C2 0C 00 A1 94 43 7E 00 E9 B9 54 BE FF')
# cave 2: placement grid under the deploy cursor (patch-zergbuild-grid.asm, org 0x86CA00), called from Tactical::Render
$grid = 0x86CA00
# v2: grid for every selected deployer under the deploy cursor
$g = Hex ('83 3D FC 94 74 00 00 0F 85 C3 53 DA FF A1 68 A0 74 00 83 F8 1B 74 08 83 F8 1C 74 03 C2 04 00 55 53 56 57 89 CD 83 EC 28 ' +
    'BE E4 94 74 00 8D 7C 24 08 B9 08 00 00 00 F3 A5 31 DB 3B 1D 68 48 7E 00 0F 8D A5 00 00 00 A1 5C 48 7E 00 8B 34 98 43 85 ' +
    'F6 74 E7 89 F1 8B 06 FF 50 2C 83 F8 01 75 DB 8B 86 60 03 00 00 8B 80 74 02 00 00 85 C0 74 CB 89 04 24 8B 4E 40 C1 F9 08 ' +
    '8B 7E 44 C1 FF 08 C1 E7 10 66 89 CF 89 C1 E8 35 74 BD FF 84 C0 75 14 66 03 3D 64 11 76 00 C1 CF 10 66 03 3D 66 11 76 00 ' +
    'C1 CF 10 89 3D E4 94 74 00 C7 05 E8 94 74 00 00 00 00 00 8B 0C 24 6A 01 E8 13 34 BD FF A3 EC 94 74 00 C6 05 F0 94 74 00 ' +
    '01 C7 05 F8 94 74 00 00 00 00 00 8B 04 24 A3 FC 94 74 00 FF 74 24 3C 89 E9 E8 EA 52 DA FF E9 4F FF FF FF 8D 74 24 08 BF ' +
    'E4 94 74 00 B9 08 00 00 00 F3 A5 83 C4 28 5F 5E 5B 5D C2 04 00')
if ($g.Length -ne 261) { throw "grid cave layout $($g.Length)" }
$g = [byte[]]$g + (New-Object byte[] 41)      # the cave keeps 302 bytes (size of v1)
# v1 (2026-10-27): only the unit whose cell was under the mouse; the cursor sits on the unit picture above its cell, no grid
$gv1 = Hex ('83 3D FC 94 74 00 00 0F 85 C3 53 DA FF A1 68 A0 74 00 83 F8 1B 74 08 83 F8 1C 74 03 C2 04 00 55 53 56 57 89 CD 83 EC 30 ' +
    '8B 0D F0 C8 74 00 8D 04 24 50 8B 11 FF 52 34 50 8D 44 24 0C 50 8B 0D F4 C5 74 00 E8 78 67 DA FF 8B 7C 24 08 31 DB 3B 1D 68 48 ' +
    '7E 00 0F 8D CA 00 00 00 A1 5C 48 7E 00 8B 34 98 43 89 F1 8B 06 FF 50 2C 83 F8 01 75 DF 8B 86 60 03 00 00 8B 80 74 02 00 00 85 ' +
    'C0 74 CF 8B 4E 40 C1 F9 08 8B 56 44 C1 FA 08 C1 E2 10 66 89 CA 39 FA 75 B9 89 44 24 0C 89 C1 E8 20 74 BD FF 84 C0 75 14 66 03 ' +
    '3D 64 11 76 00 C1 CF 10 66 03 3D 66 11 76 00 C1 CF 10 89 7C 24 08 BE E4 94 74 00 8D 7C 24 10 B9 08 00 00 00 F3 A5 8B 44 24 08 ' +
    'A3 E4 94 74 00 C7 05 E8 94 74 00 00 00 00 00 8B 4C 24 0C 6A 01 E8 E6 33 BD FF A3 EC 94 74 00 C6 05 F0 94 74 00 01 C7 05 F8 94 ' +
    '74 00 00 00 00 00 8B 44 24 0C A3 FC 94 74 00 FF 74 24 44 89 E9 E8 BC 52 DA FF 8D 74 24 10 BF E4 94 74 00 B9 08 00 00 00 F3 A5 ' +
    '83 C4 30 5F 5E 5B 5D C2 04 00')
if ($gv1.Length -ne 302) { throw "grid cave v1 layout $($gv1.Length)" }
function Call([int]$at, [int]$to) { $b = New-Object System.Collections.Generic.List[byte]; $b.Add(0xE8); $b.AddRange([BitConverter]::GetBytes([int]($to - ($at + 5)))); return ,$b.ToArray() }
$sites = @(
    @{ VA = $cave; Orig = (New-Object byte[] $c.Length); New = $c; Legacy = $v1 }
    @{ VA = $hook; Orig = (Hex 'A1 94 43 7E 00');       New = (Jmp $hook $cave) }
    @{ VA = $grid; Orig = (New-Object byte[] $g.Length); New = $g; Legacy = $gv1 }
    @{ VA = 0x611ADC; Orig = (Hex 'E8 EF 02 00 00');    New = (Call 0x611ADC $grid) }   # Draw_Placement(false)
    @{ VA = 0x611B65; Orig = (Hex 'E8 66 02 00 00');    New = (Call 0x611B65 $grid) }   # Draw_Placement(true)
)

function Is([byte[]]$want, [int]$va) { $o = Off $va; for ($i = 0; $i -lt $want.Length; $i++) { if ($bytes[$o + $i] -ne $want[$i]) { return $false } }; return $true }
$from = if ($Revert) { 'New' } else { 'Orig' }; $to = if ($Revert) { 'Orig' } else { 'New' }
$todo = @($sites | Where-Object { -not (Is $_[$to] $_.VA) })
if ($todo.Count -eq 0) { "already $(if ($Revert) { 'original' } else { 'patched' }), nothing to do"; return }
foreach ($s in $todo) {
    if (Is $s[$from] $s.VA) { continue }
    if ($s.Legacy -and (Is $s.Legacy $s.VA)) { continue }
    throw ("unexpected bytes at 0x{0:X} (different game.exe version, or the cave is used by another patch?)" -f $s.VA)
}
if (-not $Exe -and (Get-Process -Name game -ErrorAction SilentlyContinue)) { throw "game.exe is running: close the game first" }
if (-not $Revert -and -not $Exe -and -not (Test-Path "$exe.bak")) { Copy-Item $exe "$exe.bak"; "backup: $exe.bak" }
foreach ($s in $todo) { [Array]::Copy([byte[]]$s[$to], 0, $bytes, (Off $s.VA), $s[$to].Length) }
[IO.File]::WriteAllBytes($exe, $bytes)
"{0}: {1} of {2} sites written" -f $(if ($Revert) { 'reverted' } else { 'patched' }), $todo.Count, $sites.Count
