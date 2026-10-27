# Binary patch of Vinifera.dll (DTA 16.2.2 and 16.2.3 builds, see $builds; addresses below are 16.2.2): Zerg creep spreaders (zerg-creep, 2026-10-27).
# Vinifera replaces AnimClass::AI with AnimClassExt::_AI (Vinifera.pdb ?_AI@AnimClassExt, 0x1003D788), and its tiberium-spawn
# loop is a copy of the game's: Map[AdjacentCell(anim cell, dx & 7)] (north neighbour at radius 0), Can_Tiberium_Germinate,
# new OverlayClass(OverlayTypes[TiberiumSpawnType->ID + Random(0,3)]), OverlayData = Random(0,2). The game.exe sites 2, 3 and 5
# of patch-veins.ps1 (AnimClass::AI) therefore never run. In-game test 7 (memory probe 2026-10-27): building shards landed on
# their cell every 60 frames, but holes only came from the 1-in-4 random hit, one cell north (OverlayData 2), the other hits
# left CORPSE (168) / PAVLAT; under-building seeding never passed Can_Tiberium_Germinate. Same three fixes here, VEINHOLE only:
#   V1 0x1003DDBA  33 FF 89 45 E0 57 8B C8 E8 65 48 15 00  xor edi,edi / mov [ebp-20h],eax / push edi / mov ecx,eax /
#                  call Can_Tiberium_Germinate  ->  own cell ([ebp-28h]) and "no overlay" only
#   V2 0x1003DE13  8B 4E 64 8B 89 C0 01 00 00 03 81 24 01 00 00  ... add eax,[ecx+124h]  ->  no Random(0,3) for 0xA7
#   V3 0x1003DE5A  8B 4D E0 88 81 96 00 00 00  mov ecx,[ebp-20h] / mov [ecx+96h],al  ->  OverlayData 0 for the hole centre
# Caves: section .scdock (added by patch-vinifera-workers.ps1, which owns its first 0x100 bytes) + 0x100, source
# patch-vinifera-veins.asm (org 0x106DB100). No hooked byte carries a relocation; caves use only relative jumps and calls
# (game functions through Vinifera's own "mov eax,addr / jmp eax" thunks), so a relocated DLL still works.
# Usage: patch-vinifera-veins.ps1 [-Revert] [-Dll <copy>]. Needs patch-vinifera-workers.ps1 first (the section); revert this one
# before reverting that one. Close the game first. Wiki: mods/zerg-creep, engine/veins.
param([switch]$Revert, [string]$Dll = "")
$ErrorActionPreference = 'Stop'
$isCopy = [bool]$Dll
$target = if ($isCopy) { $Dll } else { "$((Resolve-Path "$PSScriptRoot\..\..").Path)\Vinifera.dll" }
if (-not $isCopy -and (Get-Process -Name game -ErrorAction SilentlyContinue)) { throw "game.exe is running: close the game first" }
$bytes = [IO.File]::ReadAllBytes($target)
$pe = [BitConverter]::ToInt32($bytes, 0x3C); $nsec = [BitConverter]::ToInt16($bytes, $pe + 6); $optSize = [BitConverter]::ToInt16($bytes, $pe + 20)
$opt = $pe + 24; $imageBase = [BitConverter]::ToInt32($bytes, $opt + 28); $secTab = $opt + $optSize
function Hex([string]$s) { return ,([byte[]]($s -split ' ' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })) }
function Rel([int]$at, [int]$len, [int]$to) { return ,([BitConverter]::GetBytes([int]($to - ($at + $len)))) }
function Off([int]$va) {
    $rva = $va - $imageBase
    for ($i = 0; $i -lt $nsec; $i++) {
        $s = $secTab + 40 * $i; $sva = [BitConverter]::ToInt32($bytes, $s + 12); $rsize = [BitConverter]::ToInt32($bytes, $s + 16); $raw = [BitConverter]::ToInt32($bytes, $s + 20)
        if ($rva -ge $sva -and $rva -lt $sva + $rsize) { return $raw + ($rva - $sva) }
    }
    throw ("VA 0x{0:X} is not in the file" -f $va)
}
$scdock = $null
for ($i = 0; $i -lt $nsec; $i++) { if ([Text.Encoding]::ASCII.GetString($bytes, $secTab + 40 * $i, 8).TrimEnd([char]0) -eq '.scdock') { $scdock = $secTab + 40 * $i } }
if (-not $scdock) { throw "no .scdock section: run patch-vinifera-workers.ps1 first" }
$cave = $imageBase + [BitConverter]::ToInt32($bytes, $scdock + 12) + 0x100

# per Vinifera build, told by the PE TimeDateStamp (the patches never change it). 16.2.3 (2026-10-27): AnimClassExt::_AI is the
# same code 0x5B5 bytes further (same stack frame), the two thunks moved. Map = Vinifera thunk -> MapClass::operator[] (0x50F280),
# Germ = thunk -> CellClass::Can_Tiberium_Germinate (0x4596C0).
$builds = @{
    '6AC3EA33' = @{ Name = 'DTA 16.2.2'; V1 = 0x1003DDBA; V2 = 0x1003DE13; V3 = 0x1003DE5A; Map = 0x10190CA7; Germ = 0x1019262C }
    '6AD94075' = @{ Name = 'DTA 16.2.3'; V1 = 0x1003E36F; V2 = 0x1003E3C8; V3 = 0x1003E40F; Map = 0x10192A34; Germ = 0x101943C0 }
}
$build = $builds['{0:X8}' -f [BitConverter]::ToUInt32($bytes, $pe + 8)]
if (-not $build) { throw ("Vinifera.dll build 0x{0:X8} is unknown: not the Vinifera.dll this patch was made for (port it: add a build)" -f [BitConverter]::ToUInt32($bytes, $pe + 8)) }
$V1ret = $build.V1 + 13; $V2ret = $build.V2 + 15; $V3ret = $build.V3 + 9

# the caves of patch-vinifera-veins.asm (V1 at +0x00, V2 at +0x50, V3 at +0x80), emitted here so the relative calls and jumps
# fit any build and section address; for DTA 16.2.2 this is byte for byte the nasm output (org 0x106DB100).
$cb = New-Object System.Collections.Generic.List[byte]
function Emit([byte[]]$b) { $cb.AddRange($b) }
function EmitRel([string]$op, [int]$to) { $b = Hex $op; Emit $b; Emit (Rel ($cave + $cb.Count - $b.Length) ($b.Length + 4) $to) }
function PadTo([int]$n) { while ($cb.Count -lt $n) { Emit (Hex 'CC') } }
Emit (Hex '31 FF 89 45 E0')                  # v1: xor edi,edi / mov [ebp-20h],eax       (original)
Emit (Hex '8B 4E 64 8B 89 C0 01 00 00')      #     ecx = AnimType->TiberiumSpawnType
Emit (Hex '85 C9 74 29')                     #     test ecx,ecx / jz .normal
Emit (Hex '81 B9 24 01 00 00 A7 00 00 00 75 1D')   # cmp [ecx+124h],0A7h (VEINHOLE) / jne .normal
Emit (Hex '8D 45 D8 50 B9 48 83 74 00')      #     lea eax,[ebp-28h] (own cell) / push eax / mov ecx,748348h (Map)
EmitRel 'E8' $build.Map                      #     call MapClass::operator[]
Emit (Hex '89 45 E0 83 78 30 FF 0F 94 C0')   #     mov [ebp-20h],eax / cmp [eax+30h],-1 (no overlay) / sete al
EmitRel 'E9' $V1ret                          #     jmp test al,al
Emit (Hex '57 8B 4D E0')                     # .normal: push edi / mov ecx,[ebp-20h]
EmitRel 'E8' $build.Germ                     #     call Can_Tiberium_Germinate
EmitRel 'E9' $V1ret
PadTo 0x50
Emit (Hex '8B 4E 64 8B 89 C0 01 00 00 81 B9 24 01 00 00 A7 00 00 00 75 02 31 C0 03 81 24 01 00 00')   # v2: no Random(0,3) for VEINHOLE
EmitRel 'E9' $V2ret
PadTo 0x80
Emit (Hex '8B 4D E0 81 79 30 A7 00 00 00 75 02 31 C0 88 81 96 00 00 00')   # v3: OverlayData 0 for the hole centre
EmitRel 'E9' $V3ret
$caveBytes = $cb.ToArray()
if ($caveBytes.Length -ne 153) { throw "cave layout $($caveBytes.Length)" }
function Hook([int]$at, [int]$to, [int]$len) { $b = New-Object System.Collections.Generic.List[byte]; $b.Add(0xE9); $b.AddRange((Rel $at 5 $to)); while ($b.Count -lt $len) { $b.Add(0x90) }; return ,$b.ToArray() }
$sites = @(
    @{ VA = $cave;     Orig = (New-Object byte[] 0x100);                                             New = ([byte[]]$caveBytes + (New-Object byte[] (0x100 - 153))) }
    @{ VA = $build.V1; Orig = ([byte[]](Hex '33 FF 89 45 E0 57 8B C8 E8') + (Rel ($build.V1 + 8) 5 $build.Germ)); New = (Hook $build.V1 $cave 13) }
    @{ VA = $build.V2; Orig = (Hex '8B 4E 64 8B 89 C0 01 00 00 03 81 24 01 00 00');                  New = (Hook $build.V2 ($cave + 0x50) 15) }
    @{ VA = $build.V3; Orig = (Hex '8B 4D E0 88 81 96 00 00 00');                                    New = (Hook $build.V3 ($cave + 0x80) 9) }
)
function Is([byte[]]$want, [int]$va) { $o = Off $va; for ($i = 0; $i -lt $want.Length; $i++) { if ($bytes[$o + $i] -ne $want[$i]) { return $false } }; return $true }
$from = if ($Revert) { 'New' } else { 'Orig' }; $to = if ($Revert) { 'Orig' } else { 'New' }
$todo = @($sites | Where-Object { -not (Is $_[$to] $_.VA) })
if ($todo.Count -eq 0) { "already $(if ($Revert) { 'original' } else { 'patched' }), nothing to do"; return }
foreach ($s in $todo) { if (-not (Is $s[$from] $s.VA)) { throw ("unexpected bytes at 0x{0:X}: not the Vinifera.dll this patch was made for" -f $s.VA) } }
if (-not $isCopy -and -not $Revert -and -not (Test-Path "$target.bak")) { Copy-Item $target "$target.bak" }
foreach ($s in $todo) { [Array]::Copy([byte[]]$s[$to], 0, $bytes, (Off $s.VA), $s[$to].Length) }
[IO.File]::WriteAllBytes($target, $bytes)
"{0}: {1} of {2} sites written" -f $(if ($Revert) { 'reverted' } else { 'patched' }), $todo.Count, $sites.Count
