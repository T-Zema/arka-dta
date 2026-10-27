# Read-only memory probe of the running game.exe: every Veinhole Monster (cell, state, growth counters) and all creep-related
# overlays on the map (126 VEINS, 167 VEINHOLE, 168 CORPSE, 169/170 PAVLAT, 178 VEINHOLEDUMMY), to see why a Zerg building
# makes no creep (zerg-creep, 2026-10-27). Offsets: monsters DynamicVector 0x80FBAC (vector) / 0x80FBB8 (count);
# VeinholeMonsterClass +0x4C growth cells, +0x50 growth heap (count at [heap]), +0x68 state, +0x6C next state, +0x70 frame,
# +0x94 cell (X,Y words), +0x9C/+0x9D flags, +0xA0 grown; Map 0x748348, cell array [Map+0x168] indexed y*512+x;
# CellClass +0x30 overlay, +0x78 land, +0x93 height, +0x94 ramp, +0x96 overlay data, +0x70 first occupier.
param([string]$Out = "$PSScriptRoot\veinprobe.log")
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices; using System.Text;
public static class VP {
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool i, int pid);
  [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out int read);
  public static IntPtr H;
  public static byte[] R(long a, int n){ var b=new byte[n]; int r; ReadProcessMemory(H,(IntPtr)a,b,n,out r); return b; }
  public static int I(long a){ return BitConverter.ToInt32(R(a,4),0); }
  public static string Overlays(){
    var sb = new StringBuilder(); int arr = I(0x748348 + 0x168);
    byte[] ptrs = R(arr, 0x40000 * 4); var counts = new System.Collections.Generic.Dictionary<int,int>();
    for (int i = 0; i < 0x40000; i++) {
      int c = BitConverter.ToInt32(ptrs, i * 4); if (c == 0) continue;
      byte[] cb = R(c, 0xA8); int ov = BitConverter.ToInt32(cb, 0x30);
      if (ov == 126 || ov == 167 || ov == 168 || ov == 169 || ov == 170 || ov == 178) {
        int n; counts.TryGetValue(ov, out n); counts[ov] = n + 1;
        if (ov != 126 && ov != 178) sb.AppendFormat("  overlay {0} at ({1},{2}) data {3} land {4} h {5} occupier 0x{6:X}\n", ov, i % 512, i / 512, cb[0x96], BitConverter.ToInt32(cb, 0x78), (sbyte)cb[0x93], BitConverter.ToInt32(cb, 0x70));
      }
    }
    foreach (var k in counts.Keys) sb.AppendFormat("  count overlay {0}: {1}\n", k, counts[k]);
    return sb.ToString();
  }
}
"@
$p = Get-Process | Where-Object { $_.Path -like '*Dawn of the Tiberium Age*' -and $_.ProcessName -match '^game' } | Select-Object -First 1
if (-not $p) { "no game process"; exit 1 }
[VP]::H = [VP]::OpenProcess(0x0410, $false, $p.Id)
$sb = New-Object Text.StringBuilder
$vec = [VP]::I(0x80FBAC); $cnt = [VP]::I(0x80FBB8)
[void]$sb.AppendLine("probe $(Get-Date -Format HH:mm:ss) frame $([VP]::I(0x7E4924)) monsters $cnt  VeinGrowthEnabled $(([VP]::R([VP]::I(0x7E2438) + 0x1D83, 1))[0])")
for ($i = 0; $i -lt $cnt -and $i -lt 200; $i++) {
    $m = [VP]::I($vec + 4 * $i); $b = [VP]::R($m, 0xA4)
    $x = [BitConverter]::ToInt16($b, 0x94); $y = [BitConverter]::ToInt16($b, 0x96); $heap = [BitConverter]::ToInt32($b, 0x50)
    [void]$sb.AppendLine(("  monster 0x{0:X} cell ({1},{2}) state {3} next {4} frame {5} cells {6} queue {7} grown {8} flags {9}/{10}" -f $m, $x, $y,
        [BitConverter]::ToInt32($b, 0x68), [BitConverter]::ToInt32($b, 0x6C), [BitConverter]::ToInt32($b, 0x70), [BitConverter]::ToInt32($b, 0x4C),
        $(if ($heap) { [VP]::I($heap) } else { 'null' }), [BitConverter]::ToInt32($b, 0xA0), $b[0x9C], $b[0x9D]))
}
[void]$sb.Append([VP]::Overlays())
$sb.ToString() | Tee-Object -FilePath $Out
