# Binary patch of game.exe (TS 2.03 + DTA, CRC 0x3E8F84B0): VEHICLES with the aircraft (Fly) locomotor hover instead of landing.
# Wiki: Modding/wiki/engine/fly-locomotor.md. Aircraft (What_Am_I() == RTTI_AIRCRAFT) keep the original code paths.
#
# FlyLocomotionClass (vtable 0x6D0188; this = ILocomotion ptr = object+4) lands a unit in four places:
#   A  Move_To(COORD_NONE) 0x4998AC: lands when HeightAGL > IFlyControl::Landing_Altitude (0 for non-aircraft).
#      Patch: non-aircraft -> IsMoving=0, TargetSpeed=CurrentSpeed=0, Dest=NONE (0x4998FB) = hover in place.
#   B  arrival check in 0x499F20 at 0x49AEDA: at destination, speed 0, no TarCom (or Ammo 0) -> IsLanding=1.
#      Patch: non-aircraft -> ARRIVE (subroutine F) and skip landing (0x49AF03).
#   C  fly-to routine 0x49BBA0 at 0x49C566: closer than 0x80 leptons to the destination and slow -> IsLanding=1
#      (the landing after every move order; added 2026-10-25 after the first in-game test).
#      Patch: non-aircraft -> ARRIVE (F) and skip landing (0x49C5AD).
#   F  ARRIVE: IsMoving is cleared only by the landing routine (0x49BB43); without landing the unit kept "moving" and
#      circled its destination like an aircraft over a field (the weaving after test 3). F = IsMoving=0, IsElevating=0,
#      TargetSpeed=CurrentSpeed=0, Dest=COORD_NONE (as cave A). ecx = locomotor object.
#   G  (not landing) fly-to routine 0x49BE59: steers PrimaryFacing toward the destination while flying forward, so a target
#      inside the turning circle was orbited (weaving when the target was out of range). Patch: non-aircraft facing more
#      than 45 deg (0x2000; 22.5 deg made it stop-and-go) off the destination -> CurrentSpeed=0 = turn in place first, like a helicopter.
#      And closer than one cell to the destination -> ARRIVE (F) at once: the engine arrives only within 0x80 leptons while almost
#      stopped, so flyers overshot, turned 180 deg and overshot again (the spinning seen in the -Debug log of test 8).
#   D  Stop_Moving 0x499AC7: picks a free cell and lands there.
#      Patch: non-aircraft -> Move_To(COORD_NONE) (= A) and return.
#   E  (not landing) Do_Turn 0x49CCC1 turns SecondaryFacing (+0x1C8) = aircraft body, but a vehicle's TURRET: a turretless
#      vehicle never faced its target, could not fire and kept weaving. Patch: non-aircraft -> PrimaryFacing (+0x1B0), but only
#      while hovering (Dest == NONE); in flight the fly-to steering owns the body (test 6: both fought = spinning).
# Code cave: zero padding at the end of .text (0x6C9A40, mapped, unused by Vinifera).
# Usage: patch-flyhover.ps1 [-Revert] [-FromBackup] [-Exe <copy>]. Backup: game.exe.bak (made once, = original).
param([switch]$Revert, [switch]$FromBackup, [switch]$Debug, [string]$Exe = "")
$ErrorActionPreference = 'Stop'
$exe = if ($Exe) { $Exe } else { "$((Resolve-Path "$PSScriptRoot\..\..").Path)\game.exe" }
$textVA = 0x401000; $textRaw = 0x1000
function Off([int]$va) { return $va - $textVA + $textRaw }
function Rel([int]$from, [int]$to) { return ,([byte[]][BitConverter]::GetBytes([int]($to - $from))) }   # from = address after the rel32
function Hex([string]$s) { return ,([byte[]]($s -split ' ' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })) }

$caveA = 0x6C9A40; $caveB = 0x6C9A80; $caveD = 0x6C9AC0; $caveC = 0x6C9B00; $caveE = 0x6C9B40; $caveG = 0x6C9BC0; $caveF = 0x6C9C90
# -Debug only: logging hooks H (Move_To), I (Stop_Moving), J (Do_Turn), log stubs LF (arrive), LG (turn in place), strings
$caveH = 0x6C9D00; $caveI = 0x6C9D60; $caveJ = 0x6C9DC0; $caveLF = 0x6C9E20; $caveLG = 0x6C9E60; $caveStr = 0x6C9EA0; $caveEnd = 0x6C9FC0   # 0x6C9FC0+ = patch-buildup.ps1 (Zerg session)
$DebugPrint = 0x4082D0; $GetTickCountIAT = 0x6CA134   # game printf (Vinifera writes it to Debug/DEBUG_*.LOG), [KERNEL32!GetTickCount]

# --- subroutine F: ARRIVE (ecx = FlyLocomotionClass object)
$f = New-Object System.Collections.Generic.List[byte]
if ($Debug) { $f.Add(0xE8); $f.AddRange((Rel ($caveF + $f.Count + 4) $caveLF)) }   # call LF (log)
$f.AddRange((Hex 'C6 41 2C 00 C6 41 54 00'))                        # IsMoving = 0; IsElevating = 0
$f.AddRange((Hex 'C7 41 38 00 00 00 00 C7 41 3C 00 00 00 00'))      # TargetSpeed = 0.0
$f.AddRange((Hex 'C7 41 40 00 00 00 00 C7 41 44 00 00 00 00'))      # CurrentSpeed = 0.0
$f.AddRange((Hex 'A1 A0 31 7B 00 89 41 14 A1 A4 31 7B 00 89 41 18 A1 A8 31 7B 00 89 41 1C'))   # Dest = COORD_NONE
# As the end of a real landing (0x49BB6B): LinkedTo->Assign_Destination(nullptr, true) clears the NavCom. Without it the move
# mission never ended (same MoveTo every 0.4 s) and the unit never went to guard = no automatic attacks (test 12).
$f.AddRange((Hex '8B 41 08 6A 01 6A 00 8B C8 8B 10 FF 92 50 03 00 00'))   # mov eax,[ecx+8]; push 1; push 0; mov ecx,eax; mov edx,[eax]; call [edx+350h]
$f.Add(0xC3)                                                         # ret

# --- cave A: Move_To(NONE) branch
$a = New-Object System.Collections.Generic.List[byte]
$a.AddRange((Hex '8B 0F 8B 01 FF 50 78 83 F8 02'))                 # mov ecx,[edi]; mov eax,[ecx]; call [eax+78h] (What_Am_I); cmp eax,2
$a.AddRange((Hex '74 25'))                                          # je aircraft (+0x25)
$a.AddRange((Hex 'C6 46 28 00'))                                    # IsMoving = 0
$a.AddRange((Hex 'C7 46 34 00 00 00 00 C7 46 38 00 00 00 00'))      # TargetSpeed = 0.0
$a.AddRange((Hex 'C7 46 3C 00 00 00 00 C7 46 40 00 00 00 00'))      # CurrentSpeed = 0.0
$a.Add(0xE9); $a.AddRange((Rel ($caveA + $a.Count + 4) 0x4998FB))   # jmp Dest=NONE (no landing)
if ($a.Count -ne 0x31) { throw "cave A layout $($a.Count)" }        # aircraft label must be at +0x31 (0x0C + 0x25)
$a.AddRange((Hex '8B 0F 8B 01 FF 90 9C 01 00 00'))                 # original: mov ecx,[edi]; mov eax,[ecx]; call [eax+19Ch]
$a.Add(0xE9); $a.AddRange((Rel ($caveA + $a.Count + 4) 0x4998B6))

# --- cave B: arrival landing check
$b = New-Object System.Collections.Generic.List[byte]
$b.AddRange((Hex '8B 0E 8B 01 FF 50 78 83 F8 02'))                 # mov ecx,[esi]; mov eax,[ecx]; call What_Am_I; cmp eax,2
$b.AddRange((Hex '0F 85')); $b.AddRange((Rel ($caveB + $b.Count + 4) ($caveB + 0x1D)))   # jne unit (+0x1D)
$b.AddRange((Hex '8B 06 8B 88 1C 01 00 00'))                       # original: mov eax,[esi]; mov ecx,[eax+11Ch]
$b.Add(0xE9); $b.AddRange((Rel ($caveB + $b.Count + 4) 0x49AEE2))
if ($b.Count -ne 0x1D) { throw "cave B layout $($b.Count)" }
$b.AddRange((Hex '8B CD'))                                          # unit: mov ecx,ebp (this object)
$b.Add(0xE8); $b.AddRange((Rel ($caveB + $b.Count + 4) $caveF))     # call ARRIVE
$b.Add(0xE9); $b.AddRange((Rel ($caveB + $b.Count + 4) 0x49AF03))   # jmp past the landing

# --- cave D: Stop_Moving
$d = New-Object System.Collections.Generic.List[byte]
$d.AddRange((Hex '8B 4E 04 8B 01 FF 50 78 83 F8 02'))              # mov ecx,[esi+4]; mov eax,[ecx]; call What_Am_I; cmp eax,2
$d.AddRange((Hex '74 1D'))                                          # je aircraft (+0x1D)
$d.AddRange((Hex 'FF 35 A8 31 7B 00 FF 35 A4 31 7B 00 FF 35 A0 31 7B 00 56'))   # push COORD_NONE (z,y,x); push this
$d.Add(0xE8); $d.AddRange((Rel ($caveD + $d.Count + 4) 0x4997C0))   # call FlyLocomotionClass::Move_To
$d.Add(0xE9); $d.AddRange((Rel ($caveD + $d.Count + 4) 0x499C8C))   # jmp epilogue
if ($d.Count -ne 0x2A) { throw "cave D layout $($d.Count)" }        # aircraft label at +0x2A (0x0D + 0x1D)
$d.AddRange((Hex '8B 4E 04 8D 44 24 14'))                          # original: mov ecx,[esi+4]; lea eax,[esp+14h]
$d.Add(0xE9); $d.AddRange((Rel ($caveD + $d.Count + 4) 0x499ACE))

# --- cave C: near-destination landing in the fly-to routine (edi = this object, esi = &LinkedTo, ebx = 0)
$c = New-Object System.Collections.Generic.List[byte]
$c.AddRange((Hex '8B 0E 8B 01 FF 50 78 83 F8 02'))                 # mov ecx,[esi]; mov eax,[ecx]; call What_Am_I; cmp eax,2
$c.AddRange((Hex '0F 85')); $c.AddRange((Rel ($caveC + $c.Count + 4) ($caveC + 0x24)))   # jne unit (+0x24)
$c.AddRange((Hex 'C6 47 48 00 C6 47 49 01 C6 47 4A 00 89 5F 30'))   # original: IsTakingOff=0, IsLanding=1, WasLanding=0, FlightLevel=ebx
$c.Add(0xE9); $c.AddRange((Rel ($caveC + $c.Count + 4) 0x49C5AD))
if ($c.Count -ne 0x24) { throw "cave C layout $($c.Count)" }
$c.AddRange((Hex '8B CF'))                                          # unit: mov ecx,edi (this object)
$c.Add(0xE8); $c.AddRange((Rel ($caveC + $c.Count + 4) $caveF))     # call ARRIVE
$c.Add(0xE9); $c.AddRange((Rel ($caveC + $c.Count + 4) 0x49C5AD))

# --- cave E: Do_Turn (edx = this, the dir pointer is already pushed for FacingClass::Set_Desired at 0x496670)
$e = New-Object System.Collections.Generic.List[byte]
$e.AddRange((Hex '52 8B 4A 04 8B 01 FF 50 78 5A 8B 4A 04 83 F8 02'))   # push edx; mov ecx,[edx+4]; mov eax,[ecx]; call What_Am_I; pop edx; mov ecx,[edx+4]; cmp eax,2
$e.AddRange((Hex '74 16'))                                           # je aircraft (+0x16)
$e.AddRange((Hex '8B 42 10 3B 05 A0 31 7B 00 75 0B'))                # mov eax,[edx+10h] (Dest.X); cmp eax,COORD_NONE.X; jne -> flying: leave the
                                                                     # body to the fly-to steering (else Do_Turn toward the target fought it = spinning)
$e.AddRange((Hex '81 C1 B0 01 00 00'))                               # hovering: add ecx,1B0h (PrimaryFacing)
$e.Add(0xE9); $e.AddRange((Rel ($caveE + $e.Count + 4) 0x49CCCA))
if ($e.Count -ne 0x28) { throw "cave E layout $($e.Count)" }         # aircraft/original label at +0x28 (0x12 + 0x16)
$e.AddRange((Hex '81 C1 C8 01 00 00'))                               # original: add ecx,1C8h (SecondaryFacing)
$e.Add(0xE9); $e.AddRange((Rel ($caveE + $e.Count + 4) 0x49CCCA))

# --- cave G: turn in place (entered by jmp instead of the call to FacingClass::Set_Desired; arg already pushed;
#     esi = &LinkedTo, [esp+0Ch] = this object, word [esp+24h] = desired direction)
$gg = New-Object System.Collections.Generic.List[byte]
$gg.Add(0xE8); $gg.AddRange((Rel ($caveG + $gg.Count + 4) 0x496590))   # original: call PrimaryFacing.Set_Desired (ret 4)
$gg.AddRange((Hex '8B 0E 8B 01 FF 50 78 83 F8 02'))                 # mov ecx,[esi]; mov eax,[ecx]; call What_Am_I; cmp eax,2
$dbg = if ($Debug) { 5 } else { 0 }                                  # -Debug adds "call LG" (5 bytes) before the speed reset
$gg.AddRange((Hex '0F 84')); $gg.AddRange((Rel ($caveG + $gg.Count + 4) ($caveG + 0xBC + $dbg)))   # je done (near)
# within one cell (0x100 leptons, [esp+14h] = distance to the destination) -> ARRIVE now. The engine only arrives within 0x80
# AND almost stopped (and never while IsElevating = attacking); a flyer overshot that point, turned 180 deg, overshot again,
# or hovered right above it turning forever (debug logs, tests 8 and 10).
# Only when already airborne (test 9: a fresh unit "arrived" next to the Starport on the ground and never took off):
# HeightAGL >= the TYPE's FlightLevel - 40h (the FlightLevel field adds terrain height on hills; IsElevating is always set
# while attacking, so it cannot be used).
# Test 11: ARRIVE already at 1 cell left flyers just short of their approach cell: the engine re-sent the same MoveTo
# every 0.4 s and the unit froze out of range. Now: within 1 cell -> crawl at 25 % speed; ARRIVE only within 40h.
$gg.AddRange((Hex '81 7C 24 14 00 01 00 00 7D 59'))                  # cmp dword [esp+14h],100h; jge far
$gg.AddRange((Hex '8B 0E 8B 01 FF 90 9C 01 00 00 50'))               # mov ecx,[esi]; mov eax,[ecx]; call [eax+19Ch] (HeightAGL); push eax
$gg.AddRange((Hex '8B 0E 8B 01 FF 90 84 00 00 00'))                  # mov ecx,[esi]; mov eax,[ecx]; call [eax+84h] (TechnoType)
$gg.AddRange((Hex '8B C8 8B 10 FF 92 B4 00 00 00'))                  # mov ecx,eax; mov edx,[eax]; call [edx+0B4h] (type FlightLevel)
$gg.AddRange((Hex '5A 83 E8 40 3B D0 7C 32'))                        # pop edx; eax -= 40h; cmp edx,eax; jl far
$gg.AddRange((Hex '83 7C 24 14 40 7D 0B 8B 4C 24 0C'))               # cmp dword [esp+14h],40h; jge slow; mov ecx,[esp+0Ch]
$gg.Add(0xE8); $gg.AddRange((Rel ($caveG + $gg.Count + 4) $caveF))     # call ARRIVE (ecx = object)
$gg.Add(0xEB); $gg.Add([byte](0x64 + $dbg))                           # jmp short done
$gg.AddRange((Hex '8B 4C 24 0C'))                                    # slow: mov ecx,[esp+0Ch]
$gg.AddRange((Hex 'C7 41 38 00 00 00 00 C7 41 3C 00 00 D0 3F'))      # TargetSpeed = 0.25
$gg.AddRange((Hex 'C7 41 40 00 00 00 00 C7 41 44 00 00 D0 3F'))      # CurrentSpeed = 0.25 (then the turn check below)
if ($gg.Count -ne 0x78) { throw "cave G layout (far) $($gg.Count)" }
# far:
$gg.AddRange((Hex '0F B7 54 24 24 52 83 EC 04'))                     # movzx edx,word [esp+24h]; push edx; sub esp,4 (out buffer)
$gg.AddRange((Hex '8B 0E 81 C1 B0 01 00 00 54'))                     # mov ecx,[esi]; add ecx,1B0h; push esp
$gg.Add(0xE8); $gg.AddRange((Rel ($caveG + $gg.Count + 4) 0x496740))   # call PrimaryFacing.Current (returns eax = out buffer)
$gg.AddRange((Hex '0F B7 00 83 C4 04 5A'))                           # movzx eax,word [eax]; add esp,4; pop edx
$gg.AddRange((Hex '66 29 C2 0F BF D2 8B C2 99 33 C2 2B C2'))          # dx -= ax; eax = |(short)dx|
$gg.AddRange((Hex '3D 00 20 00 00 7E')); $gg.Add([byte](0x12 + $dbg))   # cmp eax,2000h (45 deg); jle done
if ($Debug) { $gg.Add(0xE8); $gg.AddRange((Rel ($caveG + $gg.Count + 4) $caveLG)) }   # call LG (log; eax = |diff|)
$gg.AddRange((Hex '8B 4C 24 0C C7 41 40 00 00 00 00 C7 41 44 00 00 00 00'))   # mov ecx,[esp+0Ch]; CurrentSpeed = 0.0
if ($gg.Count -ne 0xBC + $dbg) { throw "cave G layout $($gg.Count)" }  # done label at +0xBC (+5 with -Debug)
$gg.Add(0xE9); $gg.AddRange((Rel ($caveG + $gg.Count + 4) 0x49BE5E))   # done: back after the original call

# --- sites: original bytes and their replacement
function Jmp($site, $target, $len) { $x = New-Object System.Collections.Generic.List[byte]; $x.Add(0xE9); $x.AddRange((Rel ($site + 5) $target)); while ($x.Count -lt $len) { $x.Add(0x90) }; return ,$x.ToArray() }
$sites = @(
    @{ VA = 0x4998AC; Orig = (Hex '8B 0F 8B 01 FF 90 9C 01 00 00'); New = (Jmp 0x4998AC $caveA 10) },
    @{ VA = 0x49AEDA; Orig = (Hex '8B 06 8B 88 1C 01 00 00');       New = (Jmp 0x49AEDA $caveB 8) },
    @{ VA = 0x499AC7; Orig = (Hex '8B 4E 04 8D 44 24 14');          New = (Jmp 0x499AC7 $caveD 7) },
    @{ VA = 0x49C566; Orig = (Hex 'C6 47 48 00 C6 47 49 01 C6 47 4A 00 89 5F 30'); New = (Jmp 0x49C566 $caveC 15) },
    @{ VA = $caveC; Orig = (New-Object byte[] $c.Count); New = $c.ToArray() },
    @{ VA = 0x49CCC1; Orig = (Hex '8B 4A 04 81 C1 C8 01 00 00'); New = (Jmp 0x49CCC1 $caveE 9) },
    @{ VA = $caveE; Orig = (New-Object byte[] $e.Count); New = $e.ToArray() },
    @{ VA = $caveA; Orig = (New-Object byte[] $a.Count); New = $a.ToArray() },
    @{ VA = $caveB; Orig = (New-Object byte[] $b.Count); New = $b.ToArray() },
    @{ VA = $caveD; Orig = (New-Object byte[] $d.Count); New = $d.ToArray() },
    @{ VA = $caveF; Orig = (New-Object byte[] $f.Count); New = $f.ToArray() },
    @{ VA = 0x49BE59; Orig = (Hex 'E8 32 A7 FF FF'); New = (Jmp 0x49BE59 $caveG 5) },
    @{ VA = $caveG; Orig = (New-Object byte[] $gg.Count); New = $gg.ToArray() }
)
if ($caveA + $a.Count -gt $caveB -or $caveB + $b.Count -gt $caveD -or $caveD + $d.Count -gt $caveC -or $caveC + $c.Count -gt $caveE -or $caveE + $e.Count -gt $caveG -or $caveG + $gg.Count -gt $caveF -or $caveF + $f.Count -gt $caveH) { throw "caves overlap" }

# --- -Debug: log every Move_To / Stop_Moving / Do_Turn of non-aircraft Fly units, plus ARRIVE and turn-in-place, to the game log
#     ("FLY <ms> <event> u=<unit> from=<caller>"). Hooks steal the first bytes of the function and run them after logging.
if ($Debug) {
    $strs = [ordered]@{
        H = "FLY %u MoveTo u=%08X from=%08X to=%d,%d,%d`n"; I = "FLY %u Stop u=%08X from=%08X moving=%d`n"
        J = "FLY %u Turn u=%08X from=%08X dir=%04X destx=%d`n"; F = "FLY %u Arrive u=%08X via=%08X`n"; G = "FLY %u TurnInPlace u=%08X diff=%04X`n" }
    $sb = New-Object System.Collections.Generic.List[byte]; $sa = @{}
    foreach ($k in $strs.Keys) { $sa[$k] = $caveStr + $sb.Count; $sb.AddRange([Text.Encoding]::ASCII.GetBytes($strs[$k])); $sb.Add(0) }
    function Imm([int]$v) { return ,([byte[]][BitConverter]::GetBytes($v)) }
    function Hook($cave, $stolen, $back, [scriptblock]$body) {   # pushad; esi = this (ILocomotion); skip aircraft; body; popad; stolen; jmp back
        $x = New-Object System.Collections.Generic.List[byte]
        $x.AddRange((Hex '60 8B 74 24 24 8B 4E 04 8B 01 FF 50 78 83 F8 02 0F 84 00 00 00 00'))   # je skip (patched below)
        $je = $x.Count
        $x.AddRange((Hex 'FF 15')); $x.AddRange((Imm $GetTickCountIAT))                         # call [GetTickCount] -> eax
        & $body $x
        $x.Add(0xE8); $x.AddRange((Rel ($cave + $x.Count + 4) $DebugPrint))
        $x.AddRange((Hex '83 C4')); $x.Add([byte]$script:argBytes)                             # add esp, args
        $rel =[BitConverter]::GetBytes([int]($x.Count - $je)); for ($i = 0; $i -lt 4; $i++) { $x[$je - 4 + $i] = $rel[$i] }
        $x.Add(0x61); $x.AddRange([byte[]]$stolen)                                               # skip: popad; stolen bytes
        $x.Add(0xE9); $x.AddRange((Rel ($cave + $x.Count + 4) $back))
        return ,$x.ToArray()
    }
    # H Move_To(this, x, y, z): after pushad ret=[esp+20h], x=[esp+28h]
    $script:argBytes = 0x1C
    $h = Hook $caveH (Hex '83 EC 0C 53 55') 0x4997C5 { param($x)
        $x.AddRange((Hex 'FF 74 24 30 FF 74 24 30 FF 74 24 30 FF 74 24 2C FF 76 04 50 68')); $x.AddRange((Imm $sa.H)) }
    # I Stop_Moving(this): IsMoving byte [esi+28h]
    $script:argBytes = 0x14
    $i2 = Hook $caveI (Hex '83 EC 18 56 8B 74 24 20') 0x499AB8 { param($x)
        $x.AddRange((Hex '0F B6 56 28 52 FF 74 24 24 FF 76 04 50 68')); $x.AddRange((Imm $sa.I)) }
    # J Do_Turn(this, dir): dir=[esp+28h] after pushad; Dest.X=[esi+10h]
    $script:argBytes = 0x18
    $j = Hook $caveJ (Hex '8B 54 24 04 8B 44 24 08') 0x49CCB8 { param($x)
        $x.AddRange((Hex 'FF 76 10 0F B7 54 24 2C 52 FF 74 24 28 FF 76 04 50 68')); $x.AddRange((Imm $sa.J)) }
    # LF (called first in ARRIVE, ecx = object): log unit and the cave that called ARRIVE ([esp+24h] after pushad)
    $lf = New-Object System.Collections.Generic.List[byte]
    $lf.AddRange((Hex '60 8B F1 FF 15')); $lf.AddRange((Imm $GetTickCountIAT))
    $lf.AddRange((Hex 'FF 74 24 24 FF 76 08 50 68')); $lf.AddRange((Imm $sa.F))
    $lf.Add(0xE8); $lf.AddRange((Rel ($caveLF + $lf.Count + 4) $DebugPrint)); $lf.AddRange((Hex '83 C4 10 61 C3'))
    # LG (called in cave G, eax = |diff|, esi = &LinkedTo)
    $lg = New-Object System.Collections.Generic.List[byte]
    $lg.AddRange((Hex '60 8B 1E 8B F8 FF 15')); $lg.AddRange((Imm $GetTickCountIAT))
    $lg.AddRange((Hex '57 53 50 68')); $lg.AddRange((Imm $sa.G))
    $lg.Add(0xE8); $lg.AddRange((Rel ($caveLG + $lg.Count + 4) $DebugPrint)); $lg.AddRange((Hex '83 C4 10 61 C3'))
    if ($caveH + $h.Length -gt $caveI -or $caveI + $i2.Length -gt $caveJ -or $caveJ + $j.Length -gt $caveLF -or $caveLF + $lf.Count -gt $caveLG -or $caveLG + $lg.Count -gt $caveStr -or $caveStr + $sb.Count -gt $caveEnd) { throw "debug caves overlap" }
    $sites += @(
        @{ VA = 0x4997C0; Orig = (Hex '83 EC 0C 53 55'); New = (Jmp 0x4997C0 $caveH 5) },
        @{ VA = 0x499AB0; Orig = (Hex '83 EC 18 56 8B 74 24 20'); New = (Jmp 0x499AB0 $caveI 8) },
        @{ VA = 0x49CCB0; Orig = (Hex '8B 54 24 04 8B 44 24 08'); New = (Jmp 0x49CCB0 $caveJ 8) },
        @{ VA = $caveH; Orig = (New-Object byte[] $h.Length); New = $h },
        @{ VA = $caveI; Orig = (New-Object byte[] $i2.Length); New = $i2 },
        @{ VA = $caveJ; Orig = (New-Object byte[] $j.Length); New = $j },
        @{ VA = $caveLF; Orig = (New-Object byte[] $lf.Count); New = $lf.ToArray() },
        @{ VA = $caveLG; Orig = (New-Object byte[] $lg.Count); New = $lg.ToArray() },
        @{ VA = $caveStr; Orig = (New-Object byte[] $sb.Count); New = $sb.ToArray() }
    )
}

# -FromBackup: start from the untouched game.exe.bak (needed when a cave's code changed between script versions)
if ($FromBackup) { if (-not (Test-Path "$exe.bak")) { throw "no $exe.bak" }; Copy-Item "$exe.bak" $exe -Force; "restored $exe from .bak" }
$bytes = [IO.File]::ReadAllBytes($exe)
function Is([byte[]]$want, [int]$va) { $o = Off $va; for ($i = 0; $i -lt $want.Length; $i++) { if ($bytes[$o + $i] -ne $want[$i]) { return $false } }; return $true }
$from = if ($Revert) { 'New' } else { 'Orig' }; $to = if ($Revert) { 'Orig' } else { 'New' }
$done = @($sites | Where-Object { Is $_[$to] $_.VA }).Count
if ($done -eq $sites.Count) { "already $(if ($Revert) { 'original' } else { 'patched' }), nothing to do"; return }
# sites already in the target state are skipped (lets a newer script version add sites to an older patch)
$todo = @($sites | Where-Object { -not (Is $_[$to] $_.VA) })
foreach ($s in $todo) { if (-not (Is $s[$from] $s.VA)) { throw ("unexpected bytes at 0x{0:X} (different game.exe version?)" -f $s.VA) } }
if (-not $Revert -and -not (Test-Path "$exe.bak")) { Copy-Item $exe "$exe.bak"; "backup: $exe.bak" }
foreach ($s in $todo) { [Array]::Copy([byte[]]$s[$to], 0, $bytes, (Off $s.VA), $s[$to].Length) }
[IO.File]::WriteAllBytes($exe, $bytes)
"{0}: {1} of {2} sites written" -f $(if ($Revert) { 'reverted' } else { 'patched' }), $todo.Count, $sites.Count
# Zerg session 2026-10-25: -FromBackup restores the original game.exe and so wipes the second patch, patch-buildup.ps1 (long Zerg
# morphs, cave 0x6C9FC0 right after $caveEnd). Without it every Zerg building appears instantly (buildup rate 0). Re-apply it.
if ($FromBackup -and -not $Revert -and (Test-Path "$PSScriptRoot\patch-buildup.ps1")) { "re-applying patch-buildup.ps1"; & "$PSScriptRoot\patch-buildup.ps1" -Exe $exe }
