param([int]$Seconds = 1200, [string]$Out = "$PSScriptRoot\spawnprobe.log", [string]$Types = 'SCPCARR,SCPCARR2,SCPINTC,SCPINTC2')
# Read-only memory probe of the running TS/Vinifera game.exe: position (X,Y,Z leptons), cell, mission and limbo state of the
# Protoss Carriers and their Interceptors, to see why a returning Interceptor never docks. Vinifera docks a spawn only when
# it is in the owner's cell AND |Z(spawn) - Z(owner)| < 20 (SpawnManagerClass::AI, Vinifera.dll RVA 0x157E33 -> 0x101580CB).
# Offsets (Vinifera.pdb, see morphprobe.ps1): ObjectClass Position +0x40 (X,Y,Z ints), Limbo +0x2F, MissionClass Mission +0x4C,
# TechnoClass TarCom +0x11C; type IniName +0x14; DynamicVectorClass +4 Vector, +16 ActiveCount; Frame 0x7E4924.
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class SP {
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool i, int pid);
  [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out int read);
  public static IntPtr H;
  public static byte[] R(long a, int n){ var b=new byte[n]; int r; ReadProcessMemory(H,(IntPtr)a,b,n,out r); return b; }
  public static int I(long a){ return BitConverter.ToInt32(R(a,4),0); }
  public static byte B(long a){ return R(a,1)[0]; }
  public static string S(long a){ var b=R(a,24); int z=Array.IndexOf(b,(byte)0); if(z<0)z=24; return System.Text.Encoding.ASCII.GetString(b,0,z); }
}
"@
$want = $Types -split ','
$p = Get-Process | Where-Object { $_.Path -like '*Dawn of the Tiberium Age*' -and $_.ProcessName -match '^game' } | Select-Object -First 1
if (-not $p) { "no game process"; exit 1 }
[SP]::H = [SP]::OpenProcess(0x0410, $false, $p.Id)
$missions = @{ 0='Sleep';1='Attack';2='Move';3='QMove';4='Retreat';5='Guard';6='Sticky';7='Enter';8='Capture';9='Eaten';10='Harvest';11='AreaGuard';12='Return';13='Stop';14='Ambush';15='Hunt';16='Unload';17='Sabotage';18='Construction';19='Selling';20='Repair';21='Rescue';22='Missile';23='Harmless';24='Open';25='Patrol' }

# find the object vectors (Units, Aircraft...) near the Buildings vector and the Class offset of each
function Find-Vectors {
  $found = @()
  for ($a = 0x7E3000; $a -lt 0x7E6000; $a += 4) {
    $vec = [SP]::I($a + 4); $cnt = [SP]::I($a + 16)
    if ($cnt -le 0 -or $cnt -gt 4000 -or $vec -lt 0x10000) { continue }
    if ([SP]::I($vec) -lt 0x10000) { continue }
    # Class pointer (Vinifera.pdb): InfantryClass +0x350, AircraftClass +0x354 (852), UnitClass +0x360. The offset must give a
    # type name for the first (up to) 3 elements, so a random pointer at a wrong offset does not pass.
    foreach ($off in 0x354, 0x360, 0x350) {
      $ok = $true
      for ($k = 0; $k -lt [Math]::Min(3, $cnt); $k++) {
        $o = [SP]::I($vec + 4 * $k); $t = if ($o -ge 0x10000) { [SP]::I($o + $off) } else { 0 }
        if ($t -lt 0x10000 -or ([SP]::S($t + 0x14)) -notmatch '^[A-Z][A-Z0-9_]{1,15}$') { $ok = $false; break }
      }
      if ($ok) { $found += [pscustomobject]@{ Base = $a; Off = $off }; break }
    }
  }
  return $found
}

$end = (Get-Date).AddSeconds($Seconds)
"probe start $(Get-Date -Format HH:mm:ss) pid $($p.Id)" | Out-File $Out -Encoding utf8
$vecs = @(); $last = ''; $lastScan = [DateTime]::MinValue; $vecKey = ''
while ((Get-Date) -lt $end -and -not $p.HasExited) {
  # rescan every 10 s: a vector that is empty at the start (no aircraft yet) is skipped by Find-Vectors
  if (((Get-Date) - $lastScan).TotalSeconds -ge 10) {
    $lastScan = Get-Date; $vecs = @(Find-Vectors)
    $k = ($vecs | % { '0x{0:X}(+0x{1:X})' -f $_.Base, $_.Off }) -join ' '
    if ($k -ne $vecKey) { "vectors: $k" | Out-File $Out -Append -Encoding utf8; $vecKey = $k }
  }
  $sb = New-Object Text.StringBuilder
  foreach ($v in $vecs) {
    $vec = [SP]::I($v.Base + 4); $cnt = [SP]::I($v.Base + 16)
    for ($i = 0; $i -lt $cnt -and $i -lt 4000; $i++) {
      $o = [SP]::I($vec + 4 * $i); $t = [SP]::I($o + $v.Off); $n = [SP]::S($t + 0x14)
      if ($want -notcontains $n) { continue }
      $x = [SP]::I($o + 0x40); $y = [SP]::I($o + 0x44); $z = [SP]::I($o + 0x48); $m = [SP]::I($o + 0x4C)
      # TechnoClass Ammo +0x134 (308), FootClass NavCom +0x278 (632), AircraftClass AttacksRemaining +0x36C (876): Vinifera.pdb
      $extra = if ($v.Off -eq 0x354) { " attacksLeft=$([SP]::I($o + 0x36C))" } else { '' }
      [void]$sb.AppendLine(("{0,-9} 0x{1:X8} limbo={2} mission={3,-9} cell={4},{5} xyz={6},{7},{8} tarcom=0x{9:X} navcom=0x{10:X} ammo={11}{12}" -f $n, $o, ([SP]::B($o + 0x2F)), $missions[$m], [int][Math]::Floor($x / 256), [int][Math]::Floor($y / 256), $x, $y, $z, ([SP]::I($o + 0x11C)), ([SP]::I($o + 0x278)), ([SP]::I($o + 0x134)), $extra))
    }
  }
  $snap = $sb.ToString()
  if ($snap -ne $last) { "--- $(Get-Date -Format HH:mm:ss.fff) frame $([SP]::I(0x7E4924))`n$snap" | Out-File $Out -Append -Encoding utf8; $last = $snap }
  Start-Sleep -Milliseconds 500
}
"probe end" | Out-File $Out -Append -Encoding utf8
