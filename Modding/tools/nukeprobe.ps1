param([int]$Seconds = 1800, [string]$Out = "$PSScriptRoot\nukeprobe.log", [switch]$Once)
# Read-only memory probe of the running TS/Vinifera game.exe: superweapon state of the player house
# and every NukeSilo building, to see where the Terran nuke launch stops.
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class PM {
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool i, int pid);
  [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out int read);
  public static IntPtr H;
  public static byte[] R(long a, int n){ var b=new byte[n]; int r; ReadProcessMemory(H,(IntPtr)a,b,n,out r); return b; }
  public static int I(long a){ return BitConverter.ToInt32(R(a,4),0); }
  public static byte B(long a){ return R(a,1)[0]; }
  public static string S(long a){ var b=R(a,32); int z=Array.IndexOf(b,(byte)0); if(z<0)z=32; return System.Text.Encoding.ASCII.GetString(b,0,z); }
}
"@
$p = Get-Process | Where-Object { $_.Path -like '*Dawn of the Tiberium Age*' -and $_.ProcessName -match '^game' } | Select-Object -First 1
if (-not $p) { "no game process"; exit 1 }
[PM]::H = [PM]::OpenProcess(0x0410, $false, $p.Id)

function Snapshot {
  $sb = New-Object Text.StringBuilder
  $frame = [PM]::I(0x7E4924)
  $player = [PM]::I(0x7E2284)
  [void]$sb.AppendLine(("=== frame $frame  player house 0x{0:X}  NukeTarget(+572)=0x{1:X}" -f $player, ([PM]::I($player+0x572))))
  # superweapon types
  $swc = [PM]::I(0x7E4008); $swa = [PM]::I(0x7E3FFC)
  $swv = [PM]::I($player+0x12C)
  for ($i=0; $i -lt $swc; $i++) {
    $t = [PM]::I($swa+4*$i); $name = [PM]::S($t+0x14)
    if ($name -notmatch 'SCNuke|MultiSpecial') { continue }
    $s = [PM]::I($swv+4*$i)
    $line = "SW[{0}] {1} heap={2} type={3} weap=0x{4:X} pow={5} man={6} | super 0x{7:X} cls={8} start={9} acc={10} delay={11} f29={12} f2A={13} f2B={14} f2C={15} f30={16}" -f $i,$name,([PM]::I($t+0x60)),([PM]::I($t+0x7C)),([PM]::I($t+0x64)),([PM]::B($t+0xA6)),([PM]::B($t+0xA7)),$s,([PM]::S(([PM]::I($s+0x14))+0x14)),([PM]::I($s+0x1C)),([PM]::I($s+0x20)),([PM]::I($s+0x24)),([PM]::B($s+0x29)),([PM]::B($s+0x2A)),([PM]::B($s+0x2B)),([PM]::B($s+0x2C)),([PM]::I($s+0x30))
    [void]$sb.AppendLine($line)
  }
  # NukeSilo building types, in array order (the launch code takes the FIRST match)
  $btc = [PM]::I(0x7E21B0); $bta = [PM]::I(0x7E21A4)
  $trk = [PM]::I($player+0x328+4); $trkN = [PM]::I($player+0x328+8)
  $siloIdx = @{}
  for ($i=0; $i -lt $btc; $i++) {
    $t = [PM]::I($bta+4*$i)
    if ([PM]::B($t+0x81A) -ne 0) {
      $cnt = if ($i -lt $trkN) { [PM]::I($trk+4*$i) } else { 'n/a' }
      $siloIdx[$t] = $i
      [void]$sb.AppendLine(("silo type [{0}] {1} SW={2} SW2={3} houseCount={4}" -f $i, ([PM]::S($t+0x14)), ([PM]::I($t+0x830)), ([PM]::I($t+0x834)), $cnt))
    }
  }
  # silo buildings on the map
  $bc = [PM]::I(0x7E4718); $ba = [PM]::I(0x7E470C)
  for ($i=0; $i -lt $bc; $i++) {
    $b = [PM]::I($ba+4*$i); $t = [PM]::I($b+0x220)
    if ($siloIdx.ContainsKey($t)) {
      $m = [PM]::R($b+0x40, 0x20); $hex = ($m | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
      [void]$sb.AppendLine(("building 0x{0:X} {1} house=0x{2:X} limbo={3} status(+58)={4} f298={5} f301={6} +40..5F: {7}" -f $b, ([PM]::S($t+0x14)), ([PM]::I($b+0xEC)), ([PM]::B($b+0x2F)), ([PM]::I($b+0x58)), ([PM]::I($b+0x298)), ([PM]::B($b+0x301)), $hex))
    }
  }
  $sb.ToString()
}

if ($Once) { Snapshot; exit }
$last = ''
$end = (Get-Date).AddSeconds($Seconds)
"probe start $(Get-Date -Format HH:mm:ss) pid $($p.Id)" | Out-File $Out -Encoding utf8
while ((Get-Date) -lt $end -and -not $p.HasExited) {
  $snap = Snapshot
  $key = ($snap -split "`n" | Select-Object -Skip 1) -join "`n" -replace 'start=\S+ acc=\S+ ', ''
  if ($key -ne $last) { "$(Get-Date -Format HH:mm:ss.fff)`n$snap" | Out-File $Out -Append -Encoding utf8; $last = $key }
  Start-Sleep -Milliseconds 250
}
"probe end" | Out-File $Out -Append -Encoding utf8
