param([int]$WaitSeconds = 3600, [int]$Seconds = 3600, [string]$Out = "$PSScriptRoot\morphprobe.log", [switch]$TraceInfantry)
# -TraceInfantry: also log every change of state of Zerg infantry (types SCZ*): Doing, CurrentMission, target, IsFiring, IsProne,
# rearm timer, cell. Offsets from Vinifera.pdb (llvm-pdbutil): ObjectClass Position +0x40, MissionClass CurrentMission +0x4C,
# TechnoClass TarCom +0x11C, Arm +0x128 (timer: +0 start frame, +4 delay), FootClass IsFiring +0x345, InfantryClass Class +0x350,
# Doing +0x354, IsProne +0x36B. The Infantry vector is found at runtime near the Buildings vector (0x7E4708).
# Read-only memory probe of the running game.exe: real game FPS and the morph (buildup) of every Zerg building (type SCZ*):
# Anims[BSTATE_CONSTRUCTION].Count/Rate of its type, current stage, and the real time from the first sight to the end of the
# construction state. Verifies Modding/wiki/engine/buildup-timing.md (patched rate >= 1: morph = Count ticks) in game.
# Addresses (TS 2.03 + DTA game.exe): Frame 0x7E4924 (Begin_Mode stores it as the stage timer start), Buildings vector
# 0x7E470C/0x7E4718; BuildingClass: Class +0x220, BState +0x234, Stage +0x84, stage Rate +0x94; BuildingTypeClass: IniName +0x14,
# Anims[0] = {Start +0x538, Count +0x53C, Rate +0x540}. Waits up to -WaitSeconds for the game to start.
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class MP {
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool i, int pid);
  [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out int read);
  public static IntPtr H;
  public static byte[] R(long a, int n){ var b=new byte[n]; int r; ReadProcessMemory(H,(IntPtr)a,b,n,out r); return b; }
  public static int I(long a){ return BitConverter.ToInt32(R(a,4),0); }
  public static string S(long a){ var b=R(a,32); int z=Array.IndexOf(b,(byte)0); if(z<0)z=32; return System.Text.Encoding.ASCII.GetString(b,0,z); }
}
"@
function Log($s) { $line = "$(Get-Date -Format HH:mm:ss.fff) $s"; $line | Out-File $Out -Append -Encoding utf8; $line }
"morphprobe start $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), waiting for game.exe" | Out-File $Out -Encoding utf8
# The client may start game.exe more than once (a short first process, then the match): after every exit, wait for the next one.
$deadline = (Get-Date).AddSeconds($WaitSeconds)
$sessions = 0
while ((Get-Date) -lt $deadline) {
$p = $null
while (-not $p -and (Get-Date) -lt $deadline) {
    $p = Get-Process | Where-Object { $_.Path -like '*Dawn of the Tiberium Age*' -and $_.ProcessName -eq 'game' } | Select-Object -First 1
    if (-not $p) { Start-Sleep -Seconds 2 }
}
if (-not $p) { break }
$sessions++
[MP]::H = [MP]::OpenProcess(0x0410, $false, $p.Id)
Log "attached pid $($p.Id)"

$sw = [Diagnostics.Stopwatch]::StartNew()
$infVec = 0; $unitVec = 0; $infState = @{}; $nextScan = 0; $tgtSeen = @{}
# DynamicVectorClass: +4 Vector, +16 ActiveCount. Candidate = a vector whose first element has an InfantryTypeClass at +0x350
# (type IniName at +0x14 starting with a letter and the type's vtable equal for all elements).
# $clsOff: InfantryClass::Class +0x350, UnitClass::Class +0x360 (an infantry's +0x360 / a unit's +0x350 is no type pointer)
function Find-Vector([int]$clsOff, [string]$firstPattern) {
    for ($a = 0x7E3000; $a -lt 0x7E6000; $a += 4) {
        $cnt = [MP]::I($a + 16); $vec = [MP]::I($a + 4)
        if ($cnt -lt 1 -or $cnt -gt 3000 -or $vec -lt 0x10000) { continue }
        $ok = 0
        for ($i = 0; $i -lt [Math]::Min($cnt, 5); $i++) {
            $o = [MP]::I($vec + 4 * $i); if ($o -lt 0x10000) { break }
            $t = [MP]::I($o + $clsOff); if ($t -lt 0x10000) { break }
            $nm = [MP]::S($t + 0x14)
            if ($nm -match '^[A-Z][A-Z0-9_]{1,15}$' -and ([MP]::I($o + 0x40)) -gt 0) { $ok++ } else { break }
        }
        if ($ok -ge 1 -and $ok -ge [Math]::Min($cnt, 5)) {
            $first = [MP]::S(([MP]::I(([MP]::I($vec)) + $clsOff)) + 0x14)
            if ($first -match $firstPattern) { return $a }
        }
    }
    return 0
}
$seen = @{}          # building address -> @{ Name; F0; T0; Count; Rate }
$fpsF = [MP]::I(0x7E4924); $fpsT = $sw.Elapsed.TotalSeconds
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end -and -not $p.HasExited) {
    $frame = [MP]::I(0x7E4924); $now = $sw.Elapsed.TotalSeconds
    if ($now - $fpsT -ge 10) {
        $fps = ($frame - $fpsF) / ($now - $fpsT)
        if ($fps -gt 0) { Log ("fps {0:N1} (frame {1})" -f $fps, $frame) }
        $fpsF = $frame; $fpsT = $now
    }
    $bc = [MP]::I(0x7E4718); $ba = [MP]::I(0x7E470C)
    $alive = @{}
    for ($i = 0; $i -lt $bc; $i++) {
        $b = [MP]::I($ba + 4 * $i); if ($b -eq 0) { continue }
        $t = [MP]::I($b + 0x220); $name = [MP]::S($t + 0x14)
        if (-not $name.StartsWith('SCZ')) { continue }
        $alive[$b] = $true
        $state = [MP]::I($b + 0x234)
        if ($state -eq 0 -and -not $seen.ContainsKey($b)) {
            $seen[$b] = @{ Name = $name; F0 = $frame; T0 = $now; Count = [MP]::I($t + 0x53C); Rate = [MP]::I($t + 0x540); Done = $false }
            Log ("morph start {0} at 0x{1:X}: Count {2}, type Rate {3}, stage Rate {4}, stage {5}" -f $name, $b, $seen[$b].Count, $seen[$b].Rate, ([MP]::I($b + 0x94)), ([MP]::I($b + 0x84)))
        }
        if ($state -ne 0 -and $name -match '^SCZ(LRB|SUN|SPO)') {
            # armed Zerg buildings: log every new target (TechnoClass TarCom +0x11C) with its distance in cells
            $tc = [MP]::I($b + 0x11C)
            if ($tgtSeen[$b] -ne $tc) {
                $tgtSeen[$b] = $tc
                if ($tc) {
                    $dx = ([MP]::I($tc + 0x40) - [MP]::I($b + 0x40)) / 256.0; $dy = ([MP]::I($tc + 0x44) - [MP]::I($b + 0x44)) / 256.0
                    Log ("target  {0} at 0x{1:X}: new target {2:N1} cells away (frame {3})" -f $name, $b, [Math]::Sqrt($dx * $dx + $dy * $dy), $frame)
                }
            }
        }
        if ($seen.ContainsKey($b) -and -not $seen[$b].Done -and $state -ne 0) {
            $e = $seen[$b]; $e.Done = $true
            $df = $frame - $e.F0; $dt = $now - $e.T0
            Log ("morph done  {0}: {1} frames in {2:N1} s (expected Count x Rate = {3} frames; {4:N1} frames/s)" -f $e.Name, $df, $dt, ($e.Count * $e.Rate), ($df / [Math]::Max($dt, 0.001)))
        }
    }
    if ($TraceInfantry) {
        # all StarCraft-mod objects (types SC*): infantry (Doing, prone) and vehicles (UnitClass)
        if (($infVec -eq 0 -or $unitVec -eq 0) -and $now -ge $nextScan) {
            if (-not $infVec) { $infVec = Find-Vector 0x350 '^(E\d|SC|ENG|DOG|MED|SPY|THI|TAN|MEC|CYB|GHO|JUMP|UMAG|C\d)'; if ($infVec) { Log ("infantry vector at 0x{0:X}" -f $infVec) } }
            if (-not $unitVec) { $unitVec = Find-Vector 0x360 '^(SC|[A-Z0-9]*MCV|[A-Z0-9]*TNK|[A-Z0-9]*HARV|APC|JEEP|BIKE|BGGY|HVR|MTNK|LTNK|HTNK|ARTY)'; if ($unitVec) { Log ("unit vector at 0x{0:X}" -f $unitVec) } }
            $nextScan = $now + 5
        }
        foreach ($vk in @(@($infVec, 0x350, 'inf'), @($unitVec, 0x360, 'veh'))) {
            if (-not $vk[0]) { continue }
            $ic = [MP]::I($vk[0] + 16); $iv = [MP]::I($vk[0] + 4)
            for ($i = 0; $i -lt $ic; $i++) {
                $o = [MP]::I($iv + 4 * $i); if ($o -eq 0) { continue }
                $t = [MP]::I($o + $vk[1]); $nm = [MP]::S($t + 0x14)
                if (-not $nm.StartsWith('SC')) { continue }
                $x = [MP]::I($o + 0x40); $y = [MP]::I($o + 0x44)
                $armS = [MP]::I($o + 0x128); $armD = [MP]::I($o + 0x12C)
                $doing = if ($vk[2] -eq 'inf') { "doing {0,2} prone {1} " -f ([MP]::I($o + 0x354)), ([MP]::R($o + 0x36B, 1)[0]) } else { '' }
                $state = "{0}mission {1,2} target {2} firing {3} cell {4},{5}" -f $doing, ([MP]::I($o + 0x4C)), $(if ([MP]::I($o + 0x11C)) { 'yes' } else { 'no ' }), ([MP]::R($o + 0x345, 1)[0]), [int]($x / 256), [int]($y / 256)
                if ($infState[$o] -ne $state) { $infState[$o] = $state; Log ("{0} 0x{1:X} {2,-8} f{3} {4} arm {5}+{6}" -f $vk[2], $o, $nm, $frame, $state, $armS, $armD) }
            }
        }
        Start-Sleep -Milliseconds 20
    } else { Start-Sleep -Milliseconds 250 }
}
Log "game pid $($p.Id) ended"
}
Log "probe end ($sessions game sessions)"
if ($sessions -eq 0) { exit 1 }
