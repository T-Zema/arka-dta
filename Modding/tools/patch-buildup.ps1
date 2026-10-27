# Binary patch of game.exe (TS 2.03 + DTA): a building's buildup (construction) animation may last LONGER than ~81 ticks.
# The engine sets the buildup frame rate when it loads <Buildup>.SHP (BuildingTypeClass, game.exe):
#   0x4403DD / 0x443C7B:  rate = ftol(Rules BuildupTime x 900 / (SHP frames / 2))     (DTA buildings, NewTheater=no)
#   0x43FD52:             rate = 75 / SHP frames                                         (theater-specific buildups)
# so every buildup lasts ~81 (75) ticks, and one with more frames gets rate 0 and never finishes.
# Patch: rate >= 1. A buildup with N > 81 frames then lasts N ticks (1 frame per tick); shorter buildups are unchanged.
# Used by the Zerg faction (build-sczergbase.ps1): morph time = buildup length. Wiki: Modding/wiki/engine/buildup-timing.md
# Code cave: the last zero padding of .text (0x6C9FC0-0x6CA000) right after patch-flyhover.ps1's caves, which end at 0x6C9FC0
# since its 2026-10-25 version (they used to end at 0x6C9C40, where this cave was first: the new fly caves took that place).
# Usage: patch-buildup.ps1 [-Revert] [-Exe <copy>]. Backup game.exe.bak is the original (made by whichever patch ran first).
param([switch]$Revert, [string]$Exe = "")
$ErrorActionPreference = 'Stop'
$exe = if ($Exe) { $Exe } else { "$((Resolve-Path "$PSScriptRoot\..\..").Path)\game.exe" }
$textVA = 0x401000; $textRaw = 0x1000
function Off([int]$va) { return $va - $textVA + $textRaw }
function Rel([int]$from, [int]$to) { return ,([byte[]][BitConverter]::GetBytes([int]($to - $from))) }   # from = address after the rel32
function Hex([string]$s) { return ,([byte[]]($s -split ' ' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })) }
function Call([int]$at, [int]$to) { $c = New-Object System.Collections.Generic.List[byte]; $c.Add(0xE8); $c.AddRange((Rel ($at + 5) $to)); return ,$c.ToArray() }

$ftol = 0x6B2330
$cave = 0x6C9FC0
# cave: eax = ftol(st0); if (eax == 0) eax = 1; ret
$cv = New-Object System.Collections.Generic.List[byte]
$cv.AddRange((Call $cave $ftol))
$cv.AddRange((Hex '85 C0 75 01 40 C3'))                              # test eax,eax; jnz +1; inc eax; ret

$sites = @(
    @{ VA = $cave;    Orig = (New-Object byte[] $cv.Count); New = $cv.ToArray() }
    @{ VA = 0x440420; Orig = (Call 0x440420 $ftol); New = (Call 0x440420 $cave) }
    @{ VA = 0x443C91; Orig = (Call 0x443C91 $ftol); New = (Call 0x443C91 $cave) }
    # theater path: cmp ecx,ebx / mov eax,1 / je / mov eax,75 / cdq / idiv ecx  ->  mov eax,75 / cdq / jecxz / idiv ecx /
    # test eax,eax / jnz +1 / inc eax / nop nop   (ecx = frame count, 0 keeps eax = 75: no buildup, rate unused)
    @{ VA = 0x43FD56; Orig = (Hex '3B CB B8 01 00 00 00 74 08 B8 4B 00 00 00 99 F7 F9'); New = (Hex 'B8 4B 00 00 00 99 E3 02 F7 F9 85 C0 75 01 40 90 90') }
)

$bytes = [IO.File]::ReadAllBytes($exe)
function Is([byte[]]$want, [int]$va) { $o = Off $va; for ($i = 0; $i -lt $want.Length; $i++) { if ($bytes[$o + $i] -ne $want[$i]) { return $false } }; return $true }
$from = if ($Revert) { 'New' } else { 'Orig' }; $to = if ($Revert) { 'Orig' } else { 'New' }
$todo = @($sites | Where-Object { -not (Is $_[$to] $_.VA) })
if ($todo.Count -eq 0) { "already $(if ($Revert) { 'original' } else { 'patched' }), nothing to do"; return }
foreach ($s in $todo) { if (-not (Is $s[$from] $s.VA)) { throw ("unexpected bytes at 0x{0:X} (different game.exe version, or the cave is used by another patch?)" -f $s.VA) } }
if (-not $Revert -and -not (Test-Path "$exe.bak")) { Copy-Item $exe "$exe.bak"; "backup: $exe.bak" }
foreach ($s in $todo) { [Array]::Copy([byte[]]$s[$to], 0, $bytes, (Off $s.VA), $s[$to].Length) }
[IO.File]::WriteAllBytes($exe, $bytes)
"{0}: {1} of {2} sites written" -f $(if ($Revert) { 'reverted' } else { 'patched' }), $todo.Count, $sites.Count
