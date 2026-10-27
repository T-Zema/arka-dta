# Binary patch of game.exe (TS 2.03 + DTA): INFANTRY CAN DEPLOY. The D key changes infantry type X into the infantry type
# named X_D and back (no list in the patch: a type opts in by having its _D partner in the INI). Made for SC stimpacks on
# real infantry (Modding/tools/build-scinfstim.ps1), usable for any infantry.
#   X -> X_D: costs 1/4 of max HP (refused at or below), plays the Sound.ini entry named "X_D" if it exists, and ends by
#             itself after 30 game seconds (450 frames, timer in InfantryClass padding +0x36E)
#   X_D -> X: by hand (D again) or when the timer runs out; HP keeps its ratio of the max
# Why a patch (Game.pdb / Vinifera.pdb, 2026-10-27): DeployCommandClass::Execute sends EVENT_DEPLOY only when
# Can_Deploy_Now() is true, and Vinifera replaces that function (TechnoClassExt::_Can_Deploy_Now: non-units without
# passengers = false); the EVENT_DEPLOY handler only assigns MISSION_UNLOAD, which infantry ignore. Vinifera's
# TransformsInto exists for UnitClass only.
# Hooks (jmp into the cave 0x86C400-0x86C637, 568 B in a window up to 0x86C6FF, zero tail of .p_text; source with comments: patch-infdeploy.asm,
# assemble with  pixi exec --spec nasm nasm -f bin -o x.bin patch-infdeploy.asm  and paste the bytes below):
#   0x494C04  8B 16 6A 00 68 D8 47 7E 00     EVENT_DEPLOY before Assign_Mission: the swap (in place: InfantryClass+0x350)
#   0x4E9482  8B 07 8B CF FF 90 A0 02 00 00  D key: infantry with a partner skips Vinifera's Can_Deploy_Now
#   0x632265  8B 55 00 8B CD                 Can_Deploy_Now non-unit path (dead in game because of Vinifera; harmless)
#   0x4E9400  A1 68 48 7E 00                 (v3-v5 diagnostics hook; v6 restores the original bytes)
#   0x4D4EB0  83 EC 0C 56 8B F1              InfantryClass::AI entry: stim timer, back to X when it runs out
# The swap sits between HouseClass::Tracking_Remove/Tracking_Add: the object keeps selection, control group, veterancy,
# trigger tag, target and team. Events and AI run in lockstep, so it stays in sync in multiplayer.
# History: v1 two hooks (Can_Deploy_Now hook dead because of Vinifera), v2 + D-key hook, v3 diagnostics (crashed: "ret 4"
# returned into a string), v4 fixed, v5 stim sound + 30 s timer (804 B: ran into the creep patch cave at 0x86C700), v6 = v5 without the diagnostics, inside 0x86C400-0x86C6FF. v4 and v5 are recognised and replaced; older ones: -Revert with
# the script version that installed them, or restore game.exe.bak and run patch-game.ps1.
# Usage: patch-infdeploy.ps1 [-Revert] [-Exe <copy>]. Part of Modding/tools/patch-game.ps1. Wiki: mods/sc-infantry-stim.
param([switch]$Revert, [string]$Exe = "")
$ErrorActionPreference = 'Stop'
$exe = if ($Exe) { $Exe } else { "$((Resolve-Path "$PSScriptRoot\..\..").Path)\game.exe" }
if (-not $Exe -and (Get-Process game -ErrorAction SilentlyContinue)) { throw "game.exe is running: close the game first" }
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
function Pad([byte[]]$a, [int]$n) { $o = New-Object byte[] $n; [Array]::Copy($a, $o, $a.Length); ,$o }

$cave = 0x86C400; $size = 0x300   # window 0x86C400-0x86C6FF; 0x86C700+ belongs to patch-veins.ps1
$cv = Hex ((@(
    '89 F1 E8 AC 01 00 00 85 C0 74 5F 85 D2 74 42 50 8B 8E 50 03 00 00 8B 49 68 89 CA C1 EA 02 8B 46'
    '28 39 D0 7E 3F 29 D0 89 46 28 58 E8 08 01 00 00 A1 24 49 7E 00 05 C2 01 00 00 66 85 C0 75 01 40'
    '66 89 86 6E 03 00 00 E8 39 01 00 00 E9 EC 87 C2 FF 66 C7 86 6E 03 00 00 00 00 E8 D9 00 00 00 E9'
    'D9 87 C2 FF 58 E9 D3 87 C2 FF 8B 16 6A 00 68 D8 47 7E 00 E9 95 87 C2 FF 89 E9 E8 34 01 00 00 85'
    'C0 74 0A 5F 5E 5D 5B B0 01 83 C4 20 C3 8B 55 00 89 E9 E9 D3 5D DC FF 89 F9 E8 15 01 00 00 85 C0'
    '0F 85 EA CF C7 FF 8B 07 89 F9 FF 90 A0 02 00 00 E9 D7 CF C7 FF 60 89 CE 8B 86 50 03 00 00 85 C0'
    '74 6A 8D 78 14 31 C9 80 3C 0F 00 74 08 41 83 F9 18 72 F4 EB 57 83 F9 02 72 52 66 81 7C 0F FE 5F'
    '44 75 49 66 8B 86 6E 03 00 00 66 85 C0 75 19 A1 24 49 7E 00 05 C2 01 00 00 66 85 C0 75 01 40 66'
    '89 86 6E 03 00 00 EB 24 8B 15 24 49 7E 00 66 29 C2 78 19 89 F1 E8 99 00 00 00 85 C0 74 0E 66 C7'
    '86 6E 03 00 00 00 00 E8 0C 00 00 00 61 83 EC 0C 56 89 CE E9 7E 89 C6 FF 50 8B 8E 50 03 00 00 8B'
    '49 68 8B 46 28 85 C9 7E 14 8B 14 24 0F AF 42 68 99 F7 F9 83 F8 01 7D 05 B8 01 00 00 00 89 46 28'
    '8B 8E EC 00 00 00 56 E8 F4 5A C5 FF 8B 04 24 89 86 50 03 00 00 8B 8E EC 00 00 00 56 E8 0F 5C C5'
    'FF 83 C4 04 C3 8B 86 50 03 00 00 8D 48 14 E8 6D 8B DF FF 83 F8 FF 74 1A 50 83 EC 0C 54 89 F1 8B'
    '16 FF 52 4C 89 C2 8B 4C 24 0C E8 61 87 DF FF 83 C4 10 C3 56 57 53 83 EC 20 89 CE 8B 06 FF 50 2C'
    '83 F8 0F 75 68 8B 86 50 03 00 00 85 C0 74 5E 8D 70 14 89 E7 31 C9 8A 04 0E 88 04 0F 84 C0 74 08'
    '41 83 F9 18 72 F0 EB 45 31 DB 83 F9 02 72 10 66 81 7C 0F FE 5F 44 75 07 C6 44 0F FE 00 EB 15 83'
    'F9 15 77 29 66 C7 04 0F 5F 44 C6 44 0F 02 00 BB 01 00 00 00 89 F9 E8 C5 DF C6 FF 83 F8 FF 74 0D'
    '8B 0D 14 40 7E 00 8B 04 81 89 DA EB 04 31 C0 31 D2 83 C4 20 5B 5F 5E C3'
) -join ' '))
# v5 (installed 2026-10-27 11:20; 804 B, reached into 0x86C700 used by patch-veins.ps1), recognised and replaced
$cvV5 = Hex ((@(
    '89 F1 E8 38 02 00 00 85 C0 74 5F 85 D2 74 42 50 8B 8E 50 03 00 00 8B 49 68 89 CA C1 EA 02 8B 46'
    '28 39 D0 7E 3F 29 D0 89 46 28 58 E8 08 01 00 00 A1 24 49 7E 00 05 C2 01 00 00 66 85 C0 75 01 40'
    '66 89 86 6E 03 00 00 E8 39 01 00 00 E9 EC 87 C2 FF 66 C7 86 6E 03 00 00 00 00 E8 D9 00 00 00 E9'
    'D9 87 C2 FF 58 E9 D3 87 C2 FF 8B 16 6A 00 68 D8 47 7E 00 E9 95 87 C2 FF 89 E9 E8 34 01 00 00 85'
    'C0 74 0A 5F 5E 5D 5B B0 01 83 C4 20 C3 8B 55 00 89 E9 E9 D3 5D DC FF 89 F9 E8 9A 01 00 00 85 C0'
    '0F 85 EA CF C7 FF 8B 07 89 F9 FF 90 A0 02 00 00 E9 D7 CF C7 FF 60 89 CE 8B 86 50 03 00 00 85 C0'
    '74 6A 8D 78 14 31 C9 80 3C 0F 00 74 08 41 83 F9 18 72 F4 EB 57 83 F9 02 72 52 66 81 7C 0F FE 5F'
    '44 75 49 66 8B 86 6E 03 00 00 66 85 C0 75 19 A1 24 49 7E 00 05 C2 01 00 00 66 85 C0 75 01 40 66'
    '89 86 6E 03 00 00 EB 24 8B 15 24 49 7E 00 66 29 C2 78 19 89 F1 E8 99 00 00 00 85 C0 74 0E 66 C7'
    '86 6E 03 00 00 00 00 E8 0C 00 00 00 61 83 EC 0C 56 89 CE E9 7E 89 C6 FF 50 8B 8E 50 03 00 00 8B'
    '49 68 8B 46 28 85 C9 7E 14 8B 14 24 0F AF 42 68 99 F7 F9 83 F8 01 7D 05 B8 01 00 00 00 89 46 28'
    '8B 8E EC 00 00 00 56 E8 F4 5A C5 FF 8B 04 24 89 86 50 03 00 00 8B 8E EC 00 00 00 56 E8 0F 5C C5'
    'FF 83 C4 04 C3 8B 86 50 03 00 00 8D 48 14 E8 6D 8B DF FF 83 F8 FF 74 1A 50 83 EC 0C 54 89 F1 8B'
    '16 FF 52 4C 89 C2 8B 4C 24 0C E8 61 87 DF FF 83 C4 10 C3 56 57 53 83 EC 20 89 CE 8B 06 FF 50 2C'
    '83 F8 0F 75 68 8B 86 50 03 00 00 85 C0 74 5E 8D 70 14 89 E7 31 C9 8A 04 0E 88 04 0F 84 C0 74 08'
    '41 83 F9 18 72 F0 EB 45 31 DB 83 F9 02 72 10 66 81 7C 0F FE 5F 44 75 07 C6 44 0F FE 00 EB 15 83'
    'F9 15 77 29 66 C7 04 0F 5F 44 C6 44 0F 02 00 BB 01 00 00 00 89 F9 E8 C5 DF C6 FF 83 F8 FF 74 0D'
    '8B 0D 14 40 7E 00 8B 04 81 89 DA EB 04 31 C0 31 D2 83 C4 20 5B 5F 5E C3 68 B5 C6 86 00 EB 05 68'
    'E8 C6 86 00 51 E8 69 FF FF FF 59 60 89 CE 89 C3 89 D7 8B 06 89 F1 FF 50 2C BA 22 C7 86 00 85 DB'
    '74 03 8D 53 14 57 52 50 56 FF 74 24 30 E8 5E BC B9 FF 83 C4 14 61 8D 64 24 04 C3 60 FF 35 68 48'
    '7E 00 68 9A C6 86 00 E8 44 BC B9 FF 83 C4 08 61 A1 68 48 7E 00 E9 6B CD C7 FF 49 4E 46 44 45 50'
    '20 44 20 6B 65 79 3A 20 25 64 20 73 65 6C 65 63 74 65 64 0A 00 49 4E 46 44 45 50 20 44 20 6B 65'
    '79 20 6F 62 6A 65 63 74 20 25 30 38 58 20 72 74 74 69 20 25 64 20 70 61 72 74 6E 65 72 20 25 73'
    '20 75 70 20 25 64 0A 00 49 4E 46 44 45 50 20 45 56 45 4E 54 5F 44 45 50 4C 4F 59 20 6F 62 6A 65'
    '63 74 20 25 30 38 58 20 72 74 74 69 20 25 64 20 70 61 72 74 6E 65 72 20 25 73 20 75 70 20 25 64'
    '0A 00 2D 00'
) -join ' '))
# v4 (installed 2026-10-27 before v5), recognised and replaced
$cvV4 = Hex ((@(
    '89 F1 E8 3E 01 00 00 85 C0 74 63 50 52 8B 8E 50 03 00 00 8B 49 68 85 C9 7E 4C 8B 46 28 85 D2 74'
    '0B 89 CA C1 EA 02 39 D0 7E 3C 29 D0 8B 54 24 04 0F AF 42 68 99 F7 F9 83 F8 01 7D 05 B8 01 00 00'
    '00 89 46 28 8B 8E EC 00 00 00 56 E8 10 5C C5 FF 8B 44 24 04 89 86 50 03 00 00 8B 8E EC 00 00 00'
    '56 E8 2A 5D C5 FF 83 C4 08 E9 CF 87 C2 FF 8B 16 6A 00 68 D8 47 7E 00 E9 91 87 C2 FF 89 E9 E8 18'
    '00 00 00 85 C0 74 0A 5F 5E 5D 5B B0 01 83 C4 20 C3 8B 55 00 89 E9 E9 CF 5D DC FF 56 57 53 83 EC'
    '20 89 CE 8B 06 FF 50 2C 83 F8 0F 75 68 8B 86 50 03 00 00 85 C0 74 5E 8D 70 14 89 E7 31 C9 8A 04'
    '0E 88 04 0F 84 C0 74 08 41 83 F9 18 72 F0 EB 45 31 DB 83 F9 02 72 10 66 81 7C 0F FE 5F 44 75 07'
    'C6 44 0F FE 00 EB 15 83 F9 15 77 29 66 C7 04 0F 5F 44 C6 44 0F 02 00 BB 01 00 00 00 89 F9 E8 DD'
    'E0 C6 FF 83 F8 FF 74 0D 8B 0D 14 40 7E 00 8B 04 81 89 DA EB 04 31 C0 31 D2 83 C4 20 5B 5F 5E C3'
    '89 F9 E8 17 00 00 00 85 C0 0F 85 61 CF C7 FF 8B 07 89 F9 FF 90 A0 02 00 00 E9 4E CF C7 FF 68 BB'
    'C5 86 00 EB 05 68 EE C5 86 00 51 E8 4B FF FF FF 59 60 89 CE 89 C3 89 D7 8B 06 89 F1 FF 50 2C BA'
    '28 C6 86 00 85 DB 74 03 8D 53 14 57 52 50 56 FF 74 24 30 E8 58 BD B9 FF 83 C4 14 61 8D 64 24 04'
    'C3 60 FF 35 68 48 7E 00 68 A0 C5 86 00 E8 3E BD B9 FF 83 C4 08 61 A1 68 48 7E 00 E9 65 CE C7 FF'
    '49 4E 46 44 45 50 20 44 20 6B 65 79 3A 20 25 64 20 73 65 6C 65 63 74 65 64 0A 00 49 4E 46 44 45'
    '50 20 44 20 6B 65 79 20 6F 62 6A 65 63 74 20 25 30 38 58 20 72 74 74 69 20 25 64 20 70 61 72 74'
    '6E 65 72 20 25 73 20 75 70 20 25 64 0A 00 49 4E 46 44 45 50 20 45 56 45 4E 54 5F 44 45 50 4C 4F'
    '59 20 6F 62 6A 65 63 74 20 25 30 38 58 20 72 74 74 69 20 25 64 20 70 61 72 74 6E 65 72 20 25 73'
    '20 75 70 20 25 64 0A 00 2D 00'
) -join ' '))
if ($cv.Length -ne 568 -or $cvV5.Length -ne 804 -or $cvV4.Length -ne 554) { throw "cave layout $($cv.Length)/$($cvV5.Length)/$($cvV4.Length)" }
$cvV5head = New-Object byte[] $size; [Array]::Copy($cvV5, $cvV5head, $size)
$cvV5tail = New-Object byte[] ($cvV5.Length - $size); [Array]::Copy($cvV5, $size, $cvV5tail, 0, $cvV5tail.Length)
function Hook([int]$at, [int]$to, [int]$len) { $b = New-Object System.Collections.Generic.List[byte]; $b.AddRange((Jmp $at $to)); while ($b.Count -lt $len) { $b.Add(0x90) }; ,$b.ToArray() }

$sites = @(
    @{ VA = $cave;    Orig = (New-Object byte[] $size);               New = (Pad $cv $size);                  Legacy = @((Pad $cvV4 $size), $cvV5head) }
    @{ VA = 0x494C04; Orig = (Hex '8B 16 6A 00 68 D8 47 7E 00');     New = (Hook 0x494C04 $cave 9) }
    @{ VA = 0x4E9482; Orig = (Hex '8B 07 8B CF FF 90 A0 02 00 00');  New = (Hook 0x4E9482 ($cave + 0x97) 10);  Legacy = @(,(Hook 0x4E9482 ($cave + 0x120) 10)) }
    @{ VA = 0x632265; Orig = (Hex '8B 55 00 8B CD');                 New = (Hook 0x632265 ($cave + 0x78) 5);   Legacy = @(,(Hook 0x632265 ($cave + 0x7C) 5)) }
    @{ VA = 0x4E9400; Orig = (Hex 'A1 68 48 7E 00');                 New = (Hex 'A1 68 48 7E 00');          Legacy = @((Hook 0x4E9400 ($cave + 0x181) 5), (Hook 0x4E9400 ($cave + 0x27B) 5)) }   # diagnostics hook of v3-v5 removed in v6
    @{ VA = 0x4D4EB0; Orig = (Hex '83 EC 0C 56 8B F1');              New = (Hook 0x4D4EB0 ($cave + 0xB5) 6) }
)

function Is([byte[]]$want, [int]$va) { $o = Off $va; for ($i = 0; $i -lt $want.Length; $i++) { if ($bytes[$o + $i] -ne $want[$i]) { return $false } }; return $true }
# v5 reached 36 bytes into 0x86C700 (patch-veins.ps1 cave 3): zero them, but only if they are exactly our old bytes
$tailVA = $cave + $size; $tailDirty = $false
if (Is $cvV5tail $tailVA) { [Array]::Copy((New-Object byte[] $cvV5tail.Length), 0, $bytes, (Off $tailVA), $cvV5tail.Length); $tailDirty = $true; "cleared the v5 tail at 0x{0:X} (free again for patch-veins.ps1)" -f $tailVA }
$from = if ($Revert) { 'New' } else { 'Orig' }; $to = if ($Revert) { 'Orig' } else { 'New' }
$todo = @($sites | Where-Object { -not (Is $_[$to] $_.VA) })
if ($todo.Count -eq 0) { if ($tailDirty) { [IO.File]::WriteAllBytes($exe, $bytes) }; "already $(if ($Revert) { 'original' } else { 'patched' }), nothing to do"; return }
foreach ($s in $todo) {
    if (Is $s[$from] $s.VA) { continue }
    if ($s.Legacy -and @($s.Legacy | Where-Object { Is $_ $s.VA }).Count) { "updating an earlier version of the patch at 0x{0:X}" -f $s.VA; continue }
    throw ("unexpected bytes at 0x{0:X} (different game.exe version, or the cave is used by another patch?)" -f $s.VA)
}
if (-not $Revert -and -not (Test-Path "$exe.bak")) { Copy-Item $exe "$exe.bak"; "backup: $exe.bak" }
foreach ($s in $todo) { [Array]::Copy([byte[]]$s[$to], 0, $bytes, (Off $s.VA), $s[$to].Length) }
[IO.File]::WriteAllBytes($exe, $bytes)
"{0}: {1} of {2} sites written" -f $(if ($Revert) { 'reverted' } else { 'patched' }), $todo.Count, $sites.Count