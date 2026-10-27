# Binary patch of game.exe (TS 2.03 + DTA): a vehicle with Storage= that is not a harvester (Zerg Overlord, Storage=100) raises
# its house's silo capacity, like a building with Storage= does. Wiki: plans/overlord-storage, engine/houses-economy.
# Engine (Game.pdb + capstone, 2026-10-27): House->Capacity (+0x1A8) is changed only by HouseClass::Tracking_Active_Add (0x4C45D0,
# called from TechnoClass::Unlimbo and Captured) and Tracking_Active_Remove (0x4C4450, from TechnoClass::Limbo and Captured).
# Both switch on What_Am_I; only the BUILDING case does Capacity +/- Class->Storage. Storage= is a TechnoTypeClass field (+0x3EC),
# so vehicles read it too, but for harvesters it is their own cargo (SCZWORK Storage=13) and must stay out of the capacity.
# Patch: the UNIT case of both functions (jump table entry 0) first does Capacity +/- Storage when Storage > 0 and the type is
# neither a harvester (UnitTypeClass::IsToHarvest +0x48E) nor a weeder (IsToVeinHarvest +0x48F); then the original code.
#   0x4C457B (Remove, unit)  8B 06 8B CE FF 90 84 00 00 00   mov eax,[esi] / mov ecx,esi / call [eax+84h] (Techno_Type_Class)
#   0x4C46D9 (Add, unit)     same bytes                      ->  E9 <cave> 90 x5
#   caves 0x86CC80 (Remove, back to 0x4C4585) and 0x86CCC0 (Add, back to 0x4C46E3), zero tail of .p_text; edi = house, esi = techno.
# The tiberium itself still lives in buildings: Vinifera's HouseClassExt::_Harvested fills only buildings, so the surplus over
# their own Storage is put into one storage building by tools/patch-vinifera-overlord.ps1 (Vinifera.dll). Without that patch this
# one only lifts the limit used by the "Silos needed" check.
# Usage: patch-overlordstorage.ps1 [-Revert] [-Exe <copy>]. All game.exe patches together: Modding/tools/patch-game.ps1.
param([switch]$Revert, [string]$Exe = "")
$ErrorActionPreference = 'Stop'
$exe = if ($Exe) { $Exe } else { "$((Resolve-Path "$PSScriptRoot\..\..").Path)\game.exe" }
if (-not $Exe -and (Get-Process -Name game -ErrorAction SilentlyContinue)) { throw "game.exe is running: close the game first" }
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

# one cave per function; $op = 29 (sub) for Remove, 01 (add) for Add
function Cave([int]$at, [string]$op, [int]$back) {
    $c = New-Object System.Collections.Generic.List[byte]
    $c.AddRange((Hex '8B 06'))                  # +0   mov eax,[esi]
    $c.AddRange((Hex '8B CE'))                  # +2   mov ecx,esi
    $c.AddRange((Hex 'FF 90 84 00 00 00'))      # +4   call [eax+84h]          Techno_Type_Class -> UnitTypeClass*
    $c.AddRange((Hex '8B 88 EC 03 00 00'))      # +10  mov ecx,[eax+3ECh]      Storage
    $c.AddRange((Hex '85 C9'))                  # +16  test ecx,ecx
    $c.AddRange((Hex '7E 18'))                  # +18  jle back (+44)
    $c.AddRange((Hex '80 B8 8E 04 00 00 00'))   # +20  cmp byte [eax+48Eh],0   IsToHarvest
    $c.AddRange((Hex '75 0F'))                  # +27  jne back
    $c.AddRange((Hex '80 B8 8F 04 00 00 00'))   # +29  cmp byte [eax+48Fh],0   IsToVeinHarvest
    $c.AddRange((Hex '75 06'))                  # +36  jne back
    $c.AddRange((Hex "$op 8F A8 01 00 00"))     # +38  sub|add [edi+1A8h],ecx  House->Capacity
    $c.AddRange((Jmp ($at + 44) $back))         # +44  back: original code continues with eax = type
    if ($c.Count -ne 49) { throw "cave layout $($c.Count)" }
    return ,$c.ToArray()
}
$caveR = 0x86CC80; $caveA = 0x86CCC0
$orig = Hex '8B 06 8B CE FF 90 84 00 00 00'
function Hook([int]$at, [int]$to) { return ,([byte[]](Jmp $at $to) + (Hex '90 90 90 90 90')) }
$sites = @(
    @{ VA = $caveR;   Orig = (New-Object byte[] 49); New = (Cave $caveR '29' 0x4C4585) }
    @{ VA = $caveA;   Orig = (New-Object byte[] 49); New = (Cave $caveA '01' 0x4C46E3) }
    @{ VA = 0x4C457B; Orig = $orig;                 New = (Hook 0x4C457B $caveR) }
    @{ VA = 0x4C46D9; Orig = $orig;                 New = (Hook 0x4C46D9 $caveA) }
)

function Is([byte[]]$want, [int]$va) { $o = Off $va; for ($i = 0; $i -lt $want.Length; $i++) { if ($bytes[$o + $i] -ne $want[$i]) { return $false } }; return $true }
$from = if ($Revert) { 'New' } else { 'Orig' }; $to = if ($Revert) { 'Orig' } else { 'New' }
$todo = @($sites | Where-Object { -not (Is $_[$to] $_.VA) })
if ($todo.Count -eq 0) { "already $(if ($Revert) { 'original' } else { 'patched' }), nothing to do"; return }
foreach ($s in $todo) { if (-not (Is $s[$from] $s.VA)) { throw ("unexpected bytes at 0x{0:X} (different game.exe version, or the cave is used by another patch?)" -f $s.VA) } }
if (-not $Revert -and -not $Exe -and -not (Test-Path "$exe.bak")) { Copy-Item $exe "$exe.bak"; "backup: $exe.bak" }
foreach ($s in $todo) { [Array]::Copy([byte[]]$s[$to], 0, $bytes, (Off $s.VA), $s[$to].Length) }
[IO.File]::WriteAllBytes($exe, $bytes)
"{0}: {1} of {2} sites written" -f $(if ($Revert) { 'reverted' } else { 'patched' }), $todo.Count, $sites.Count
