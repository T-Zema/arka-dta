# Binary patch of game.exe (TS 2.03 + DTA): Veinhole Monsters (veins) can be created during the game, as Zerg creep (user 2026-10-27).
# 1. 0x661C10 (Veinhole Monster placement test) wants the centre cell at Height >= 1 outside map loading; DTA maps are all
#    level 0, so the test always failed. The height check is skipped:
#      0x661C86  83 FD 01 7D 0A  cmp ebp,1 / jge +0Ah   ->   jge becomes jmp (0x661C89  7D -> EB)
# 2. AnimClass::AI seeds overlay "TiberiumSpawnType + Random(0,3)" (tiberium variants lie side by side). For VEINHOLE (overlay
#    0xA7 = 167) the +0..3 would hit CORPSE / PAVLAT1 / PAVLAT2, so the random offset is skipped for that one type:
#      0x4154EC  8B 91 24 01 00 00 03 D0  mov edx,[ecx+124h] / add edx,eax   ->  E9 <cave1> 90 90 90
#      cave1 0x86C380: mov edx,[ecx+124h] / cmp edx,0A7h / je +2 / add edx,eax / jmp 0x4154F4
# 3. Right after that, the anim writes Random(0,2) into the cell's OverlayData; Mark sets 0 for the monster centre, keep it 0:
#      0x415519  88 87 96 00 00 00  mov [edi+96h],al   ->  E9 <cave2> 90
#      cave2 0x86C3A0: cmp dword [edi+30h],0A7h / jne +2 / xor eax,eax / mov [edi+96h],al / jmp 0x41551F
#    (eax is overwritten at 0x41551F, so clearing it is safe.)
# 4. The VeinholeMonsterClass constructor, outside map loading, carves a pit: for the 3x3 area it sets the iso tile to
#    "[0x804434] + table(0x711709) - 1", subtile 0, and lowers Height by 1. That was why the test wanted Height >= 1; on
#    level-0 DTA maps it gave broken tiles -> crash in CellClass::Cell_Render_Rect (0x4561F2, 2026-10-27). Skip the pit,
#    the monster stands on flat ground (Destroy_Monster never restores tiles, so nothing else depends on it):
#      0x660D0B  0F 85 A6 00 00 00  jne 0x660DB7   ->  E9 A7 00 00 00 90  jmp 0x660DB7
# 5. Creep from under the Zerg building (user 2026-10-27). AnimClass::AI picks the cell "anim cell + AdjacentCoord[x & 7]"
#    (TS bug: with radius 0 always the north neighbour) and tests it with CellClass::Can_Tiberium_Germinate, which refuses any
#    cell with a visible building. For VEINHOLE only: undo the north offset (own cell) and only require "no overlay there";
#    the monster test in OverlayClass::Mark checks the rest (flat Clear 3x3, 3 cells to the next monster, no building test).
#      0x41548D  8B F8 6A 00 8B CF E8 28 42 04 00  mov edi,eax / push 0 / mov ecx,edi / call 0x4596C0  ->  E9 <cave3> 90 x6
# 6. A monster made during the game never grows veins: its growth queue is only built by VeinholeMonsterClass::Place_Monsters
#    (map load / RMG), and Grow takes cells from that queue (in-game test 2026-10-27: hole stays, no veins). After the
#    constructor call in OverlayClass::Mark, outside map loading, call Place_Monsters(false) (fastcall, cl = 0): it rebuilds
#    the growth queues of all monsters (and drops VEINS cells no monster owns, as at map load).
#    Build_Growth_Queue starts only from VEINS cells within 2 cells of the monster; a map/RMG monster has them, an in-game
#    one only has the 3x3 VEINHOLEDUMMY ring (in-game test 4, 2026-10-27: still no growth). So first seed veins on the 5x5
#    ring exactly like the RMG (Place_Veins + Recalc_Attributes(-1) per cell). Source: patch-veins-cave4.asm (124 B).
#      0x58B71A  E9 C1 06 00 00  jmp 0x58BDE0   ->  E9 <cave4>      (0x58BDE0 reads no eax/ecx/edx; ebp = centre cell)
#      cave4 0x86CE60-0x86CEDB: if ScenarioInit == 0: ring veins, Place_Monsters(false); jmp 0x58BDE0
# 7. The monster test wants Land == Clear on all 3x3 cells; Zerg buildings on other ground (in-game test 5, 2026-10-27: Hatchery
#    and colonies on the green plateau made no creep, tumors on the plain did) never got a hole. Accept Clear, Road, Rough
#    and Weeds (bit mask 0x883 over LandType); Water, Rock, Wall, Tiberium, Beach, Ice, Railroad, Tunnel still refuse:
#      0x661CD3  8B 48 78 85 C9 75 B1  mov ecx,[eax+78h] / test ecx,ecx / jne fail   ->  E9 <cave5> 90 90
#      cave5 0x86CEE0: mov ecx,[eax+78h] / cmp ecx,31 / ja fail / mov edx,883h / bt edx,ecx / jnc fail / jmp 0x661CDA /
#                      fail: jmp 0x661C8B      (edx is reloaded at 0x661C9B, unused before)
# 8. VeinholeMonsterClass::AI: with something within 2 cells (MapClass::Is_Something_Nearby) the monster plays its attack and,
#    on the attack frame, spawns particle GasCloudM1 -> GasCloud1 (Damage=50, Warhead=Gas). The gas ignores ImmuneToVeins
#    (in-game test 6, 2026-10-27: vehicles next to the holes died). Never spawn it (the one-shot flag +9Dh stays 0, as when
#    the attack frame is not reached):
#      0x661612  0F 85 14 01 00 00  jne 0x66172C   ->  E9 15 01 00 00 90  jmp 0x66172C
# 9. Creep radius 8 (user 2026-10-27): in VeinholeMonsterClass::Grow a neighbour cell joins the growth queue only when
#    dx*dx + dy*dy <= 72 from MonsterCell (before Can_Place_Veins). Before: the creep grew to MaxVeinholeGrowth (2000 cells).
#      0x661F1B  8B CF E8 AE 91 DF FF  mov ecx,edi / call 0x45B0D0   ->  E9 <cave6> 90 90      (back to 0x661F22)
# 10. A hole under a Zerg building dies with it (user 2026-10-27): at the start of VeinholeMonsterClass::AI, a monster whose
#    MonsterCell holds a building of type SCZ* gets the magic word 'ZG' in its padding +9Eh; when the building is gone, a
#    marked monster dies as on RESULT_DESTROYED in Take_Damage (next state 3, Detach_This_From_All). Tumor holes stay.
#      0x661420  83 EC 24 55 56  sub esp,24h / push ebp / push esi   ->  E9 <cave6+40h>   (replayed, back to 0x661425)
#      cave6 0x86C900-0x86C9D4, source patch-veins-growth.asm
#      cave3 0x86CE00 (0x86C700 was taken by patch-infdeploy; after the call to MapClass::operator[] the cell struct is at [esp+20h]), back to 0x415498 (test al,al).
# Caves are in the zero tail of .p_text (see the cave registry in Modding/wiki/engine/game-exe-patching.md).
# Usage: patch-veins.ps1 [-Revert] [-Exe <copy>]. Backup game.exe.bak = original (made by whichever patch ran first).
# Included in Modding/tools/patch-game.ps1. Wiki: engine/veins, mods/zerg-creep.
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

$height = 0x661C89; $hook1 = 0x4154EC; $hook2 = 0x415519; $cave1 = 0x86C380; $cave2 = 0x86C3A0

$c1 = New-Object System.Collections.Generic.List[byte]
$c1.AddRange((Hex '8B 91 24 01 00 00'))        # +0   mov edx,[ecx+124h]   TiberiumSpawnType->ID
$c1.AddRange((Hex '81 FA A7 00 00 00'))        # +6   cmp edx,0A7h         VEINHOLE
$c1.AddRange((Hex '74 02'))                    # +12  je +2
$c1.AddRange((Hex '03 D0'))                    # +14  add edx,eax          + Random(0,3)
$c1.AddRange((Jmp ($cave1 + 16) 0x4154F4))     # +16  back
if ($c1.Count -ne 21) { throw "cave1 layout $($c1.Count)" }
$c2 = New-Object System.Collections.Generic.List[byte]
$c2.AddRange((Hex '81 7F 30 A7 00 00 00'))     # +0   cmp dword [edi+30h],0A7h   cell overlay = VEINHOLE
$c2.AddRange((Hex '75 02'))                    # +7   jne +2
$c2.AddRange((Hex '33 C0'))                    # +9   xor eax,eax
$c2.AddRange((Hex '88 87 96 00 00 00'))        # +11  mov [edi+96h],al     OverlayData
$c2.AddRange((Jmp ($cave2 + 17) 0x41551F))     # +17  back
if ($c2.Count -ne 22) { throw "cave2 layout $($c2.Count)" }
$hook3 = 0x41548D; $cave3 = 0x86CE00
function Call([int]$at, [int]$to) { $b = New-Object System.Collections.Generic.List[byte]; $b.Add(0xE8); $b.AddRange((Rel $at $to)); return ,$b.ToArray() }
$c3 = New-Object System.Collections.Generic.List[byte]
$c3.AddRange((Hex '8B F8'))                    # +0   mov edi,eax            cell from Map[]
$c3.AddRange((Hex '8B 4E 64'))                 # +2   mov ecx,[esi+64h]      AnimType
$c3.AddRange((Hex '8B 89 C0 01 00 00'))        # +5   mov ecx,[ecx+1C0h]     TiberiumSpawnType
$c3.AddRange((Hex '85 C9'))                    # +11  test ecx,ecx
$c3.AddRange((Hex '74 3F'))                    # +13  jz normal (+78)
$c3.AddRange((Hex '81 B9 24 01 00 00 A7 00 00 00')) # +15 cmp dword [ecx+124h],0A7h   VEINHOLE
$c3.AddRange((Hex '75 33'))                    # +25  jne normal (+78)
$c3.AddRange((Hex '66 A1 48 11 76 00'))        # +27  mov ax,[761148h]       AdjacentCoord[0].X
$c3.AddRange((Hex '66 29 44 24 20'))           # +33  sub [esp+20h],ax
$c3.AddRange((Hex '66 A1 4A 11 76 00'))        # +38  mov ax,[76114Ah]       AdjacentCoord[0].Y
$c3.AddRange((Hex '66 29 44 24 22'))           # +44  sub [esp+22h],ax       -> the anim's own cell
$c3.AddRange((Hex '8D 44 24 20'))              # +49  lea eax,[esp+20h]
$c3.AddRange((Hex '50'))                       # +53  push eax
$c3.AddRange((Hex 'B9 48 83 74 00'))           # +54  mov ecx,748348h        Map
$c3.AddRange((Call ($cave3 + 59) 0x50F280))    # +59  call MapClass::operator[]
$c3.AddRange((Hex '8B F8'))                    # +64  mov edi,eax
$c3.AddRange((Hex '83 7F 30 FF'))              # +66  cmp dword [edi+30h],-1  no overlay
$c3.AddRange((Hex '0F 94 C0'))                 # +70  sete al
$c3.AddRange((Jmp ($cave3 + 73) 0x415498))     # +73  back
$c3.AddRange((Hex '6A 00'))                    # +78  normal: push 0
$c3.AddRange((Hex '8B CF'))                    # +80  mov ecx,edi
$c3.AddRange((Call ($cave3 + 82) 0x4596C0))    # +82  call CellClass::Can_Tiberium_Germinate
$c3.AddRange((Jmp ($cave3 + 87) 0x415498))     # +87  back
if ($c3.Count -ne 92) { throw "cave3 layout $($c3.Count)" }
$h3 = New-Object System.Collections.Generic.List[byte]; $h3.AddRange((Jmp $hook3 $cave3)); $h3.AddRange((Hex '90 90 90 90 90 90'))
$hook4 = 0x58B71A; $cave4 = 0x86CE60
# cave4 v2 = nasm output of patch-veins-cave4.asm (org 0x86CE60): veins on the 5x5 ring, then Place_Monsters(false)
$c4 = New-Object System.Collections.Generic.List[byte]
$c4.AddRange((Hex ('83 3D 94 43 7E 00 00 75 6E 53 56 57 BB FE FF FF FF BE FE FF FF FF 83 FE FE 74 0F 83 FE 02 74 0A 83 FB FE 74 05 ' +
    '83 FB 02 75 37 66 8B 45 16 66 01 D8 C1 E0 10 66 8B 45 14 66 01 F0 50 54 B9 48 83 74 00 E8 D9 23 CA FF 59 3D 48 5B 80 00 74 12 ' +
    '89 C7 89 C1 E8 A8 E8 BE FF 6A FF 89 F9 E8 7F 63 BE FF 46 83 FE 02 7E AF 43 83 FB 02 7E A4 5F 5E 5B 31 C9 E8 19 55 DF FF E9 04 EF D1 FF')))
if ($c4.Count -ne 124) { throw "cave4 layout $($c4.Count)" }
# cave4 v1 (2026-10-27, queues only; a new monster had no VEINS to start from): may be overwritten
$c4v1 = New-Object System.Collections.Generic.List[byte]
$c4v1.AddRange((Hex '83 3D 94 43 7E 00 00 75 07 33 C9')); $c4v1.AddRange((Call ($cave4 + 11) 0x6623F0)); $c4v1.AddRange((Jmp ($cave4 + 16) 0x58BDE0))
$c4v1.AddRange((New-Object byte[] (124 - 21)))
$hook5 = 0x661CD3; $cave5 = 0x86CEE0
$c5 = New-Object System.Collections.Generic.List[byte]
$c5.AddRange((Hex '8B 48 78'))                 # +0   mov ecx,[eax+78h]      LandType
$c5.AddRange((Hex '83 F9 1F'))                 # +3   cmp ecx,31
$c5.AddRange((Hex '77 0F'))                    # +6   ja fail (+23)
$c5.AddRange((Hex 'BA 83 08 00 00'))           # +8   mov edx,883h           Clear, Road, Rough, Weeds
$c5.AddRange((Hex '0F A3 CA'))                 # +13  bt edx,ecx
$c5.AddRange((Hex '73 05'))                    # +16  jnc fail (+23)
$c5.AddRange((Jmp ($cave5 + 18) 0x661CDA))     # +18  ok: height check
$c5.AddRange((Jmp ($cave5 + 23) 0x661C8B))     # +23  fail: return false
if ($c5.Count -ne 28) { throw "cave5 layout $($c5.Count)" }
$h5 = New-Object System.Collections.Generic.List[byte]; $h5.AddRange((Jmp $hook5 $cave5)); $h5.AddRange((Hex '90 90'))
# sites 9 + 10: nasm output of patch-veins-growth.asm (org 0x86C900): radius cave at +0, building-link cave at +0x40
$cave6 = 0x86C900
$c6 = Hex ('0F BF 44 24 14 0F BF 96 94 00 00 00 29 D0 0F AF C0 0F BF 54 24 16 0F BF 8E 96 00 00 00 29 CA 0F AF D2 01 D0 83 F8 48 ' +
    '7F 0C 89 F9 E8 A0 E7 BE FF E9 ED 55 DF FF 31 C0 E9 E6 55 DF FF CC CC CC CC 51 56 57 53 89 CE 83 7E 6C 03 74 7B 83 7E 68 03 ' +
    '74 75 8D 86 94 00 00 00 50 B9 48 83 74 00 E8 1D 29 CA FF 8B 78 70 31 DB 85 FF 74 28 89 F9 8B 07 FF 50 2C 83 F8 06 75 17 8B ' +
    '87 20 02 00 00 66 81 78 14 53 43 75 09 80 78 16 5A 75 03 43 EB 05 8B 7F 20 EB D4 85 DB 74 0B 66 C7 86 9E 00 00 00 5A 47 EB ' +
    '24 66 81 BE 9E 00 00 00 5A 47 75 19 66 C7 86 9E 00 00 00 00 00 C7 46 6C 03 00 00 00 31 D2 89 F1 E8 E9 BF DD FF 5B 5F 5E 59 ' +
    '83 EC 24 55 56 E9 50 4A DF FF')
if ($c6.Length -ne 213) { throw "cave6 layout $($c6.Length)" }
$h1 = New-Object System.Collections.Generic.List[byte]; $h1.AddRange((Jmp $hook1 $cave1)); $h1.AddRange((Hex '90 90 90'))
$h2 = New-Object System.Collections.Generic.List[byte]; $h2.AddRange((Jmp $hook2 $cave2)); $h2.AddRange((Hex '90'))

$sites = @(
    @{ VA = $cave1;  Orig = (New-Object byte[] $c1.Count); New = $c1.ToArray() }
    @{ VA = $cave2;  Orig = (New-Object byte[] $c2.Count); New = $c2.ToArray() }
    @{ VA = $height; Orig = (Hex '7D');                    New = (Hex 'EB') }
    @{ VA = $hook1;  Orig = (Hex '8B 91 24 01 00 00 03 D0'); New = $h1.ToArray() }
    @{ VA = $hook2;  Orig = (Hex '88 87 96 00 00 00');     New = $h2.ToArray() }
    @{ VA = 0x660D0B; Orig = (Hex '0F 85 A6 00 00 00');    New = (Jmp 0x660D0B 0x660DB7) + (Hex '90') }
    @{ VA = $cave3;  Orig = (New-Object byte[] $c3.Count); New = $c3.ToArray() }
    @{ VA = $hook3;  Orig = (Hex '8B F8 6A 00 8B CF E8 28 42 04 00'); New = $h3.ToArray() }
    @{ VA = $cave4;  Orig = (New-Object byte[] $c4.Count); New = $c4.ToArray(); Legacy = $c4v1.ToArray() }
    @{ VA = $hook4;  Orig = (Hex 'E9 C1 06 00 00');        New = (Jmp $hook4 $cave4) }
    @{ VA = $cave5;  Orig = (New-Object byte[] $c5.Count); New = $c5.ToArray() }
    @{ VA = $hook5;  Orig = (Hex '8B 48 78 85 C9 75 B1');  New = $h5.ToArray() }
    @{ VA = 0x661612; Orig = (Hex '0F 85 14 01 00 00');    New = (Jmp 0x661612 0x66172C) + (Hex '90') }
    @{ VA = $cave6;  Orig = (New-Object byte[] $c6.Length); New = $c6 }
    @{ VA = 0x661F1B; Orig = (Hex '8B CF E8 AE 91 DF FF');  New = (Jmp 0x661F1B $cave6) + (Hex '90 90') }
    @{ VA = 0x661420; Orig = (Hex '83 EC 24 55 56');        New = (Jmp 0x661420 ($cave6 + 0x40)) }
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
