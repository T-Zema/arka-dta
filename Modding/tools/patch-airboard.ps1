# Binary patch of game.exe (TS 2.03 + DTA): infantry boards a transport that HOVERS above its cell (Terran Dropship and Protoss
# Shuttle with the Fly locomotor + patch-flyhover).
# Cause (2026-10-27, user test: "a landed Dropship takes everybody, a flying one only vehicles"; Debug/DEBUG_27-10-2026_18-09-06.LOG
# shows the infantry repeating "A* without HS: (74,43) to (74,43)" under the hovering Dropship): InfantryClass::Per_Cell_Process
# (PCP_END) looks for the transport with Cell_Unit/Cell_Aircraft/Cell_Building of its own cell. Those read the cell occupier list,
# which holds only ground-layer objects (FootClass::Mark), so a flying transport is never found and the infantry never boards.
# Vehicles board through DTA's own code (0x86BF90), which takes the transport from NavCom, so they were not affected.
# Patch: when nothing was found, the infantry is on MISSION_ENTER and its NavCom is a UnitClass in the same cell (Get_Cell, the
# compare the original makes at 0x4D3A14), that unit is taken as the occupant; then the original boarding runs (RADIO_CAN_LOAD,
# CargoClass::Attach). RTTI of NavCom via IRTTITypeInfo ([obj+4] -> call [ecx+0Ch]) because NavCom may be a CellClass.
#   0x4D38B3  8B 8E 78 02 00 00        mov ecx,[esi+278h]
#         ->  E9 <cave> 90             jmp cave
#   cave 0x86CB40-0x86CBA5 (.p_text, free gap 0x86CB30-0x86CC7F), source patch-airboard.asm (nasm), bytes copied below.
# Vinifera hooks in this function (0x4D3551, 0x4D356B, 0x4D35F9, 0x4D3A7B, 0x4D3F5D) are elsewhere.
# Usage: patch-airboard.ps1 [-Revert] [-Exe <copy>]. Backup game.exe.bak is the original (made by whichever patch ran first).
# All game.exe patches together: Modding/tools/patch-game.ps1. Wiki: engine/transports.
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

$hook = 0x4D38B3; $cave = 0x86CB40
# nasm output of patch-airboard.asm (org 0x86CB40); ends with jmp 0x4D38B9
$cv = Hex ('85 FF 75 57 8B AE 78 02 00 00 85 ED 74 4D 8B 06 89 F1 FF 90 54 01 00 00 83 F8 07 75 3E 8B 4D 04 8D 45 04 50 FF 51 0C ' +
           '83 F8 01 75 2F 83 EC 08 8B 45 00 89 E1 51 89 E9 FF 90 8C 01 00 00 8B 06 8D 4C 24 04 51 89 F1 FF 90 8C 01 00 00 8B 04 24 ' +
           '3B 44 24 04 8D 64 24 08 75 02 89 EF 8B 8E 78 02 00 00 E9 13 6D C6 FF')
if ($cv.Length -ne 102) { throw "cave layout $($cv.Length)" }
$back = (Jmp ($cave + 97) 0x4D38B9); for ($i = 0; $i -lt 5; $i++) { if ($cv[97 + $i] -ne $back[$i]) { throw "cave return jump does not land on 0x4D38B9" } }
$hookNew = New-Object System.Collections.Generic.List[byte]; $hookNew.AddRange((Jmp $hook $cave)); $hookNew.Add(0x90)

$sites = @(
    @{ VA = $cave; Orig = (New-Object byte[] 102);              New = $cv }
    @{ VA = $hook; Orig = (Hex '8B 8E 78 02 00 00');            New = $hookNew.ToArray() }
)

function Is([byte[]]$want, [int]$va) { $o = Off $va; for ($i = 0; $i -lt $want.Length; $i++) { if ($bytes[$o + $i] -ne $want[$i]) { return $false } }; return $true }
$from = if ($Revert) { 'New' } else { 'Orig' }; $to = if ($Revert) { 'Orig' } else { 'New' }
$todo = @($sites | Where-Object { -not (Is $_[$to] $_.VA) })
if ($todo.Count -eq 0) { "already $(if ($Revert) { 'original' } else { 'patched' }), nothing to do"; return }
foreach ($s in $todo) {
    if (Is $s[$from] $s.VA) { continue }
    throw ("unexpected bytes at 0x{0:X} (different game.exe version, or the cave is used by another patch?)" -f $s.VA)
}
if (-not $Revert -and -not (Test-Path "$exe.bak")) { Copy-Item $exe "$exe.bak"; "backup: $exe.bak" }
foreach ($s in $todo) { [Array]::Copy([byte[]]$s[$to], 0, $bytes, (Off $s.VA), $s[$to].Length) }
[IO.File]::WriteAllBytes($exe, $bytes)
"{0}: {1} of {2} sites written" -f $(if ($Revert) { 'reverted' } else { 'patched' }), $todo.Count, $sites.Count
