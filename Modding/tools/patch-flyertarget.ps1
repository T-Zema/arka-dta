# Binary patch of game.exe (TS 2.03 + DTA): units with an anti-air weapon automatically acquire FLYING VEHICLES (Fly
# locomotor: Zerg Mutalisks/Overlords, Protoss and Terran flyers) when they guard, not only when ordered to attack.
# Cause (found 2026-10-27, ARKA 1 test: Marines and Rocket Soldiers in Guard ignored the Mutalisk; Game.pdb + capstone):
# TechnoClass::Greatest_Threat (0x62DC80) scans the air only when the method has THREAT_AIR (an AA=yes projectile), and
# then walks the TOP layer list (0x7A2000), accepting RTTI_AIRCRAFT (2) and jumpjet infantry (0xF + InfantryType IsJumpJet)
# only. A flying Fly-locomotor vehicle is RTTI_UNIT (1) and sits in the same TOP layer (FlyLocomotionClass::In_Which_Layer
# 0x49CD90: HeightAGL > 0 -> LAYER_TOP), but it is skipped there, and the ground cell scan never sees it either (FootClass::
# Mark 0x4A0590 puts only LAYER_GROUND objects into cell occupier lists). So flyers could be shot only on a direct order.
# Patch (in place, no cave): the RTTI test in that loop accepts 1 and 2.
#   0x62DF2F  83 F8 02 74 24     cmp eax,2 / je 0x62DF58 (evaluate)
#         ->  48 3C 01 76 24     dec eax / cmp al,1 / jbe 0x62DF58     (RTTI 1 or 2; eax is reloaded at 0x62DF34)
# The evaluation path that follows still skips objects whose In_Which_Layer is GROUND (landed), and Evaluate_Object
# (Vinifera's TechnoClassExt::_Evaluate_Object) checks owner, range, visibility and the threat mask as for aircraft.
# Usage: patch-flyertarget.ps1 [-Revert] [-Exe <copy>]. Backup game.exe.bak is the original (made by whichever patch ran first).
# All game.exe patches together: Modding/tools/patch-game.ps1. Wiki: engine/fly-locomotor ("Automatyczne celowanie").
param([switch]$Revert, [string]$Exe = "")
$ErrorActionPreference = 'Stop'
$exe = if ($Exe) { $Exe } else { "$((Resolve-Path "$PSScriptRoot\..\..").Path)\game.exe" }
$bytes = [IO.File]::ReadAllBytes($exe)

# VA -> file offset through the section table
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

$sites = @(
    @{ VA = 0x62DF2F; Orig = (Hex '83 F8 02 74 24'); New = (Hex '48 3C 01 76 24') }
)

function Is([byte[]]$want, [int]$va) { $o = Off $va; for ($i = 0; $i -lt $want.Length; $i++) { if ($bytes[$o + $i] -ne $want[$i]) { return $false } }; return $true }
$from = if ($Revert) { 'New' } else { 'Orig' }; $to = if ($Revert) { 'Orig' } else { 'New' }
$todo = @($sites | Where-Object { -not (Is $_[$to] $_.VA) })
if ($todo.Count -eq 0) { "already $(if ($Revert) { 'original' } else { 'patched' }), nothing to do"; return }
foreach ($s in $todo) {
    if (Is $s[$from] $s.VA) { continue }
    throw ("unexpected bytes at 0x{0:X} (different game.exe version, or another patch hooks here?)" -f $s.VA)
}
if (-not $Revert -and -not (Test-Path "$exe.bak")) { Copy-Item $exe "$exe.bak"; "backup: $exe.bak" }
foreach ($s in $todo) { [Array]::Copy([byte[]]$s[$to], 0, $bytes, (Off $s.VA), $s[$to].Length) }
[IO.File]::WriteAllBytes($exe, $bytes)
"{0}: {1} of {2} sites written" -f $(if ($Revert) { 'reverted' } else { 'patched' }), $todo.Count, $sites.Count
