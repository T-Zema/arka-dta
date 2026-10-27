# build-sczergside.ps1 - Zerg EVA voice + Zerg-coloured sidebar for the Zerg faction (house Nod1, ZergSide = side 7).
#
# Builds new MIX/Speech08.mix (EVA) and MIX/SideC08.mix (sidebar) from the current Nod copies:
#   * Speech08: selected 00-iNNN.aud lines replaced by StarCraft Zerg advisor WAVs (SD/sound/zerg/advisor/*.wav from CASC),
#     re-encoded to Westwood AUD (IMA ADPCM, 22050 Hz, 16-bit mono, like the originals) and loudness-matched (RMS) to the line
#     they replace. All other entries (incl. "local mix database.dat") are copied byte-for-byte.
#   * SideC08: sidebar.pal recoloured (Nod red -> Zerg purple, grey stone -> dark organic brown); functional colours
#     (power bar green/yellow/red/blue, radar green lines, black, transparent) are left alone. The dialog PCX pieces
#     (bar_*, bde_*, bue_*, trof*, sbgrip*, arrows...) get the same recolour of their own embedded palettes.
#   * sidenc08.mix holds no sidebar art (fonts, campaign globe, score sounds) and is NOT rebuilt.
#
# Default: writes everything to the preview folder (-Out), plus preview PNGs and WAVs; the game is not touched.
# -Install : copies Speech08.mix and SideC08.mix from the preview folder into MIX\ (a <file>.bak is made first, only if none exists).
# Run in its own process (Add-Type):  powershell -NoProfile -ExecutionPolicy Bypass -File Modding\tools\build-sczergside.ps1 [-Install]
param(
    [switch]$Install,
    [string]$Out = 'C:\Users\zemat\AppData\Local\Temp\claude\c--Users-zemat-OneDrive-Desktop-Dawn-of-the-Tiberium-Age\0aa0c7da-69ba-490e-94e2-2f70699ebe71\scratchpad\zergside',
    [string]$StarCraft = 'C:\Program Files (x86)\StarCraft'
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = Split-Path (Split-Path $tools)
$mixDir = Join-Path $game 'MIX'

# ------------------------------------------------------------------ EVA mapping
# Slot names/files: game.exe Speech[] table (VOX index -> file) + Vinifera EvaNames[] (audio_vox.cpp). No EVA.INI exists,
# so Vinifera uses these built-ins and loads the file from the side's SPEECH%02d.MIX.
# SC lines: SD/sound/zerg/advisor (only 8 exist). Meaning from SC sfxdata naming (Err/Upd) + offline speech recognition check.
$EvaMap = [ordered]@{
    '00-i022.aud' = @{ Slot = 'EVA_InsufficientFunds';      Src = 'zaderr00'; Say = 'We require more minerals' }
    '00-i024.aud' = @{ Slot = 'EVA_LowPower';               Src = 'zaderr02'; Say = 'Spawn more Overlords' }
    '00-i082.aud' = @{ Slot = 'EVA_BaseUnderAttack';        Src = 'zadupd00'; Say = 'The hive cluster is under attack' }
    '00-i090.aud' = @{ Slot = 'EVA_HarvesterUnderAttack';   Src = 'zadupd01'; Say = 'Our forces are under attack' }
    '00-i018.aud' = @{ Slot = 'EVA_ConstructionComplete';   Src = 'zadupd02'; Say = 'Evolution complete' }
    '00-i068.aud' = @{ Slot = 'EVA_UnitArmorUpgraded';      Src = 'zadupd02'; Say = 'Evolution complete' }
    '00-i070.aud' = @{ Slot = 'EVA_UnitFirepowerUpgraded';  Src = 'zadupd02'; Say = 'Evolution complete' }
    '00-i080.aud' = @{ Slot = 'EVA_UnitSpeedUpgraded';      Src = 'zadupd02'; Say = 'Evolution complete' }
    '00-i150.aud' = @{ Slot = 'EVA_MissileLaunchDetected';  Src = 'zadupd04'; Say = 'Nuclear launch detected' }
}
# Not used: zaderr01 ("We require more vespene gas": no gas in DTA; SilosNeeded means "storage full", so Nod line kept),
# zaderr06 ("Not enough energy": no matching TS event).

# ------------------------------------------------------------------ helpers
Add-Type -Path "$tools\Casc.cs", "$tools\ModTools.cs" -ReferencedAssemblies System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.IO; using System.Collections.Generic; using System.Drawing;
public static class ZergSideKit
{
    // ---- MIX by id (keeps entries whose names are unknown, e.g. the LMD)
    public static List<KeyValuePair<uint, byte[]>> ReadAll(string path)
    {
        byte[] d = File.ReadAllBytes(path);
        if (BitConverter.ToUInt16(d, 0) != 0 || BitConverter.ToUInt16(d, 2) != 0) throw new Exception("unexpected MIX header (flags): " + path);
        int count = BitConverter.ToUInt16(d, 4);
        int body = 10 + count * 12;
        List<KeyValuePair<uint, byte[]>> list = new List<KeyValuePair<uint, byte[]>>();
        for (int i = 0; i < count; i++)
        {
            int h = 10 + i * 12;
            uint id = BitConverter.ToUInt32(d, h); int off = BitConverter.ToInt32(d, h + 4); int size = BitConverter.ToInt32(d, h + 8);
            byte[] b = new byte[size]; Buffer.BlockCopy(d, body + off, b, 0, size);
            list.Add(new KeyValuePair<uint, byte[]>(id, b));
        }
        return list;
    }
    public static void WriteAll(string path, List<KeyValuePair<uint, byte[]>> entries)
    {
        List<KeyValuePair<uint, byte[]>> list = new List<KeyValuePair<uint, byte[]>>(entries);
        list.Sort(delegate (KeyValuePair<uint, byte[]> x, KeyValuePair<uint, byte[]> y) { return ((int)x.Key).CompareTo((int)y.Key); }); // TS: signed order
        using (BinaryWriter w = new BinaryWriter(File.Create(path)))
        {
            w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)list.Count);
            uint body = 0; foreach (KeyValuePair<uint, byte[]> kv in list) body += (uint)kv.Value.Length;
            w.Write(body);
            uint off = 0;
            foreach (KeyValuePair<uint, byte[]> kv in list) { w.Write(kv.Key); w.Write(off); w.Write((uint)kv.Value.Length); off += (uint)kv.Value.Length; }
            foreach (KeyValuePair<uint, byte[]> kv in list) w.Write(kv.Value);
        }
    }

    // ---- AUD (IMA ADPCM type 99) decoder, low nibble first
    static readonly int[] IT = { -1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8 };
    static readonly int[] ST = { 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97,
        107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
        876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428,
        4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350,
        22385, 24623, 27086, 29794, 32767 };
    public static short[] DecodeAud(byte[] d)
    {
        if (d[11] != 99) throw new Exception("AUD type " + d[11]);
        int total = BitConverter.ToInt32(d, 6) / 2;
        short[] o = new short[total]; int n = 0, p = 12, pred = 0, idx = 0;
        while (p + 8 <= d.Length && n < total)
        {
            int cs = BitConverter.ToUInt16(d, p); p += 8;
            for (int i = 0; i < cs && p + i < d.Length; i++)
                for (int h = 0; h < 2 && n < total; h++)
                {
                    int code = h == 0 ? (d[p + i] & 15) : (d[p + i] >> 4);
                    int step = ST[idx], diff = step >> 3;
                    if ((code & 4) != 0) diff += step; if ((code & 2) != 0) diff += step >> 1; if ((code & 1) != 0) diff += step >> 2;
                    pred += (code & 8) != 0 ? -diff : diff;
                    if (pred > 32767) pred = 32767; if (pred < -32768) pred = -32768;
                    idx += IT[code]; if (idx < 0) idx = 0; if (idx > 88) idx = 88;
                    o[n++] = (short)pred;
                }
            p += cs;
        }
        return o;
    }
    public static double Rms(short[] s)
    {
        double a = 0; int n = 0;
        foreach (short x in s) { if (Math.Abs((int)x) > 300) { a += (double)x * x; n++; } } // ignore near-silence
        return n == 0 ? 0 : Math.Sqrt(a / n);
    }
    public static short[] Scale(short[] s, double gain)   // same rounding as Aud.Encode: (int)(sample * (float)gain), clamped
    {
        short[] o = new short[s.Length]; float g = (float)gain;
        for (int i = 0; i < s.Length; i++) { int v = (int)(s[i] * g); o[i] = (short)Math.Max(-32768, Math.Min(32767, v)); }
        return o;
    }
    public static int Peak(short[] s) { int m = 0; foreach (short x in s) m = Math.Max(m, Math.Abs((int)x)); return m; }
    public static double Corr(short[] a, short[] b)
    {
        int n = Math.Min(a.Length, b.Length); double sab = 0, saa = 0, sbb = 0;
        for (int i = 0; i < n; i++) { sab += (double)a[i] * b[i]; saa += (double)a[i] * a[i]; sbb += (double)b[i] * b[i]; }
        return sab / Math.Sqrt(saa * sbb + 1e-9);
    }
    public static byte[] Wav(short[] s, int rate)
    {
        MemoryStream ms = new MemoryStream(); BinaryWriter w = new BinaryWriter(ms);
        w.Write(new char[] { 'R', 'I', 'F', 'F' }); w.Write(36 + s.Length * 2); w.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
        w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(rate); w.Write(rate * 2); w.Write((short)2); w.Write((short)16);
        w.Write(new char[] { 'd', 'a', 't', 'a' }); w.Write(s.Length * 2); foreach (short x in s) w.Write(x);
        return ms.ToArray();
    }

    // ---- colour scheme
    static void ToHsv(Color c, out double h, out double s, out double v)
    {
        double r = c.R / 255.0, g = c.G / 255.0, b = c.B / 255.0;
        double mx = Math.Max(r, Math.Max(g, b)), mn = Math.Min(r, Math.Min(g, b)), d = mx - mn;
        v = mx; s = mx == 0 ? 0 : d / mx; h = 0;
        if (d > 0) { if (mx == r) h = 60 * (((g - b) / d) % 6); else if (mx == g) h = 60 * ((b - r) / d + 2); else h = 60 * ((r - g) / d + 4); }
        if (h < 0) h += 360;
    }
    static Color FromHsv(double h, double s, double v)
    {
        h = ((h % 360) + 360) % 360; s = Math.Max(0, Math.Min(1, s)); v = Math.Max(0, Math.Min(1, v));
        double c = v * s, x = c * (1 - Math.Abs((h / 60) % 2 - 1)), m = v - c, r = 0, g = 0, b = 0;
        if (h < 60) { r = c; g = x; } else if (h < 120) { r = x; g = c; } else if (h < 180) { g = c; b = x; }
        else if (h < 240) { g = x; b = c; } else if (h < 300) { r = x; b = c; } else { r = c; b = x; }
        return Color.FromArgb((int)Math.Round((r + m) * 255), (int)Math.Round((g + m) * 255), (int)Math.Round((b + m) * 255));
    }
    // Red/orange accents -> Zerg violet; neutral or weakly tinted greys -> dark organic brown; strong other hues kept.
    public static Color Zergify(Color c)
    {
        double h, s, v; ToHsv(c, out h, out s, out v);
        if (v < 0.03) return c;                                     // black stays black
        bool red = s >= 0.30 && (h <= 45 || h >= 320);
        if (red)
        {
            double rel = h <= 45 ? h : h - 360;                      // -40..45
            return FromHsv(278 + rel * 0.4, s * 0.82, v * 0.95);
        }
        if (s < 0.45)
        {
            double tint = 0.36 * (1 - 0.6 * v);                    // dark stone gets a stronger tint, highlights stay pale
            return FromHsv(24, Math.Max(s * 0.3, tint), v * 0.97);
        }
        return c;                                                    // greens, yellows, blues: functional colours
    }
}
'@

function Write-Bytes($path, $bytes) { [IO.File]::WriteAllBytes($path, $bytes) }
function Find-Entry($list, [string]$name) { $id = [Mix]::Id($name); for ($i = 0; $i -lt $list.Count; $i++) { if ($list[$i].Key -eq $id) { return $i } }; return -1 }
function Set-Entry($list, [int]$i, [byte[]]$data) { $list[$i] = New-Object 'System.Collections.Generic.KeyValuePair[uint32,byte[]]' ($list[$i].Key, $data) }

# Original sources: prefer the .bak made by -Install, so re-running after install still starts from the Nod copies.
function Source-Mix([string]$name) { $p = Join-Path $mixDir $name; if (Test-Path "$p.bak") { return "$p.bak" }; return $p }

if ($Install) {
    if (Get-Process game -ErrorAction SilentlyContinue) { throw 'game.exe is running: close the game before -Install.' }
    foreach ($n in 'Speech08.mix', 'SideC08.mix') {
        $src = Join-Path $Out $n; if (-not (Test-Path $src)) { throw "missing $src - run without -Install first" }
        $dst = Join-Path $mixDir $n
        if ((Test-Path $dst) -and -not (Test-Path "$dst.bak")) { Copy-Item $dst "$dst.bak"; "backup: $dst.bak" }
        Copy-Item $src $dst -Force; "installed: $dst"
    }
    return
}

New-Item -ItemType Directory -Force $Out, "$Out\wav" | Out-Null

# ================================================================== EVA (Speech08.mix)
$speechSrc = Source-Mix 'Speech08.mix'
$speech = [ZergSideKit]::ReadAll($speechSrc)
$speechCount = $speech.Count
$casc = New-Object Casc $StarCraft
$report = @()
foreach ($file in $EvaMap.Keys) {
    $e = $EvaMap[$file]
    $i = Find-Entry $speech $file; if ($i -lt 0) { throw "$file not in $speechSrc" }
    $orig = $speech[$i].Value
    $origRate = [BitConverter]::ToUInt16($orig, 0)
    if ($origRate -ne 22050 -or $orig[10] -ne 2 -or $orig[11] -ne 99) { throw "$file has unexpected format" }
    $origPcm = [ZergSideKit]::DecodeAud($orig)
    $rate = 0
    $pcm = [Aud]::ReadWav($casc.ReadFile("SD/sound/zerg/advisor/$($e.Src).wav"), [ref]$rate)
    if ($rate -ne $origRate) { throw "$($e.Src).wav is $rate Hz, expected $origRate" }
    $gain = [ZergSideKit]::Rms($origPcm) / [Math]::Max(1, [ZergSideKit]::Rms($pcm))
    $gain = [Math]::Max(0.5, [Math]::Min(3.0, $gain))
    $peak = [ZergSideKit]::Peak($pcm); if ($peak * $gain -gt 32000) { $gain = 32000 / $peak }
    $aud = [Aud]::Encode($pcm, $rate, [single]$gain)
    $back = [ZergSideKit]::DecodeAud($aud)
    $scaled = [ZergSideKit]::Scale($pcm, $gain)
    $corr = [ZergSideKit]::Corr($scaled, $back)
    if ($corr -lt 0.98) { throw "$file re-encode check failed (corr $corr)" }
    Set-Entry $speech $i $aud
    Write-Bytes "$Out\wav\$($file -replace '\.aud$','')_nod.wav" ([ZergSideKit]::Wav($origPcm, $origRate))
    Write-Bytes "$Out\wav\$($file -replace '\.aud$','')_zerg.wav" ([ZergSideKit]::Wav($back, $rate))
    $report += [pscustomobject]@{ File = $file; Slot = $e.Slot; Source = "SD/sound/zerg/advisor/$($e.Src).wav"; Says = $e.Say
        Seconds = [Math]::Round($pcm.Length / $rate, 2); NodSeconds = [Math]::Round($origPcm.Length / $origRate, 2); Gain = [Math]::Round($gain, 2); Corr = [Math]::Round($corr, 4) }
}
[ZergSideKit]::WriteAll("$Out\Speech08.mix", $speech)

# ================================================================== sidebar (SideC08.mix)
$sideSrc = Source-Mix 'SideC08.mix'
$side = [ZergSideKit]::ReadAll($sideSrc)
$sideCount = $side.Count
# sidebar.pal indices left untouched: 0 transparent, 10/11 power bar blue, 12 black, power bar segments
# (141/143 green, 187/188 yellow, 122/124 red), 224-247 radar grid/scan lines (green/cyan/blue).
$keep = @(0, 10, 11, 12, 122, 124, 141, 143, 187, 188) + (224..247)
$pi = Find-Entry $side 'sidebar.pal'
$palBytes = $side[$pi].Value
$oldPal = [Pal]::ReadTs($palBytes)
$newPalBytes = [byte[]]$palBytes.Clone()
$newPal = New-Object 'System.Drawing.Color[]' 256
$changed = 0
for ($c = 0; $c -lt 256; $c++) {
    $newPal[$c] = $oldPal[$c]
    if ($keep -contains $c) { continue }
    $z = [ZergSideKit]::Zergify($oldPal[$c])
    $r6 = [byte][Math]::Round($z.R * 63 / 255); $g6 = [byte][Math]::Round($z.G * 63 / 255); $b6 = [byte][Math]::Round($z.B * 63 / 255)
    if ($r6 -ne $palBytes[$c * 3] -or $g6 -ne $palBytes[$c * 3 + 1] -or $b6 -ne $palBytes[$c * 3 + 2]) { $changed++ }
    $newPalBytes[$c * 3] = $r6; $newPalBytes[$c * 3 + 1] = $g6; $newPalBytes[$c * 3 + 2] = $b6
}
$newPal = [Pal]::ReadTs($newPalBytes)
Set-Entry $side $pi $newPalBytes

# Dialog PCX pieces: recolour their own 256-colour palette (last 768 bytes after the 0x0C marker); pixels unchanged.
$pcxNames = 'bar_ll bar_lr bar_ul bar_ur bde_li24 bde_mi24 bde_ri24 bue_li24 bue_mi24 bue_ri24 cce_i cue_i dnarrowp dnarrowr leftbar rightbar sbgripb sbgripm sbgript trakgrip trofl trofm trofr uparrowp uparrowr' -split ' '
$pcxDone = @()
foreach ($n in $pcxNames) {
    $i = Find-Entry $side "$n.pcx"; if ($i -lt 0) { continue }
    $d = [byte[]]$side[$i].Value.Clone(); $po = $d.Length - 768
    if ($d[0] -ne 10 -or $d[3] -ne 8 -or $d[$po - 1] -ne 12) { Write-Warning "$n.pcx: not an 8-bit PCX with palette, skipped"; continue }
    for ($c = 0; $c -lt 256; $c++) {
        $z = [ZergSideKit]::Zergify([Drawing.Color]::FromArgb($d[$po + $c * 3], $d[$po + $c * 3 + 1], $d[$po + $c * 3 + 2]))
        $d[$po + $c * 3] = $z.R; $d[$po + $c * 3 + 1] = $z.G; $d[$po + $c * 3 + 2] = $z.B
    }
    Set-Entry $side $i $d; $pcxDone += $n
}
[ZergSideKit]::WriteAll("$Out\SideC08.mix", $side)

# ================================================================== round-trip checks
foreach ($pair in @(@("$Out\Speech08.mix", $speechSrc, $speech), @("$Out\SideC08.mix", $sideSrc, $side))) {
    $written = [ZergSideKit]::ReadAll($pair[0]); $orig = [ZergSideKit]::ReadAll($pair[1]); $want = $pair[2]
    if ($written.Count -ne $orig.Count) { throw "$($pair[0]): $($written.Count) entries, original $($orig.Count)" }
    $m = New-Object Mix $pair[0]          # also readable by the shared reader
    $same = 0; $diff = 0
    foreach ($kv in $want) {
        $j = -1; for ($q = 0; $q -lt $written.Count; $q++) { if ($written[$q].Key -eq $kv.Key) { $j = $q; break } }
        if ($j -lt 0) { throw "entry $('{0:X8}' -f $kv.Key) missing in $($pair[0])" }
        if (-not [Linq.Enumerable]::SequenceEqual([byte[]]$written[$j].Value, [byte[]]$kv.Value)) { throw "entry $('{0:X8}' -f $kv.Key) differs" }
        $o = $null; foreach ($x in $orig) { if ($x.Key -eq $kv.Key) { $o = $x; break } }
        if ([Linq.Enumerable]::SequenceEqual([byte[]]$o.Value, [byte[]]$kv.Value)) { $same++ } else { $diff++ }
    }
    "{0}: {1} entries (original {2}), {3} unchanged, {4} replaced, {5} bytes - OK" -f (Split-Path $pair[0] -Leaf), $written.Count, $orig.Count, $same, $diff, (Get-Item $pair[0]).Length
}

# ================================================================== preview PNGs
$mOld = New-Object Mix $sideSrc
$mNew = New-Object Mix "$Out\SideC08.mix"
function Render-Shp([Mix]$m, [string]$name, [int]$frame, $pal) {
    $s = [Shp]::Read($m.Read("$name.shp")); $f = $s.Frames[$frame]
    $b = New-Object Drawing.Bitmap $s.Width, $s.Height
    for ($y = 0; $y -lt $f.H; $y++) { for ($x = 0; $x -lt $f.W; $x++) { $v = $f.Pixels[$y * $f.W + $x]; if ($v -ne 0) { $b.SetPixel($f.X + $x, $f.Y + $y, $pal[$v]) } } }
    return $b
}
function Render-Pcx([Mix]$m, [string]$name) {
    $w = 0; $h = 0; $p = $null; $px = [Pal]::ReadPcx($m.Read("$name.pcx"), [ref]$w, [ref]$h, [ref]$p)
    $b = New-Object Drawing.Bitmap $w, $h
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $b.SetPixel($x, $y, $p[$px[$y * $w + $x]]) } }
    return $b
}
$pieces = @(@('radar', 0), @('radar', 5), @('tabs', 0), @('side1', 0), @('side2', 0), @('side2', 0), @('side3', 0), @('addon', 0))
$small = @(@('tab-bld', 0), @('tab-bld', 1), @('tab-inf', 0), @('tab-unt', 0), @('tab-spc', 0), @('power', 0), @('repair', 0), @('sell', 0), @('wayp', 0), @('r-up', 0), @('r-dn', 0), @('powerp', 1), @('powerp', 2), @('powerp', 3), @('powerp', 4))
$sc = 2; $colW = 168 * $sc + 16
$sheet = New-Object Drawing.Bitmap ($colW * 2 + 20), 1600
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear([Drawing.Color]::FromArgb(24, 24, 24)); $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$font = New-Object Drawing.Font 'Segoe UI', 11
foreach ($col in 0, 1) {
    $m = @($mOld, $mNew)[$col]; $pal = @($oldPal, $newPal)[$col]; $x0 = 8 + $col * ($colW + 4); $y = 6
    $g.DrawString(@('Nod (current SideC08)', 'Zerg (new SideC08)')[$col], $font, [Drawing.Brushes]::White, $x0, $y); $y += 24
    foreach ($pc in $pieces) { $b = Render-Shp $m $pc[0] $pc[1] $pal; $g.DrawImage($b, $x0, $y, $b.Width * $sc, $b.Height * $sc); $y += $b.Height * $sc; $b.Dispose() }
    $y += 10; $x = $x0; $rowH = 0
    foreach ($pc in $small) {
        $b = Render-Shp $m $pc[0] $pc[1] $pal
        if ($x + $b.Width * $sc -gt $x0 + $colW - 8) { $x = $x0; $y += $rowH + 6; $rowH = 0 }
        $g.DrawImage($b, $x, $y, $b.Width * $sc, $b.Height * $sc); $x += $b.Width * $sc + 6; $rowH = [Math]::Max($rowH, $b.Height * $sc); $b.Dispose()
    }
    $y += $rowH + 12
    foreach ($n in 'bar_ul', 'bde_mi24', 'bue_mi24', 'trofm') { $b = Render-Pcx $m $n; $wd = [Math]::Min($b.Width, 168); $g.DrawImage($b, (New-Object Drawing.Rectangle $x0, $y, ($wd * $sc), ($b.Height * $sc)), (New-Object Drawing.Rectangle 0, 0, $wd, $b.Height), 'Pixel'); $y += $b.Height * $sc + 4; $b.Dispose() }
    $y += 8
    for ($c = 0; $c -lt 256; $c++) { $br = New-Object Drawing.SolidBrush $pal[$c]; $g.FillRectangle($br, $x0 + ($c % 32) * 10, $y + [Math]::Floor($c / 32) * 10, 10, 10); $br.Dispose() }
}
$g.Dispose(); $sheet.Save("$Out\sidebar_preview.png", [Drawing.Imaging.ImageFormat]::Png); $sheet.Dispose()

$report | Format-Table -AutoSize | Out-String -Width 220
$report | Export-Csv "$Out\eva_mapping.csv" -NoTypeInformation -Encoding UTF8
"sidebar.pal: $changed of 256 entries recoloured; PCX palettes recoloured: $($pcxDone.Count)"
"preview: $Out\sidebar_preview.png, $Out\wav\*_nod.wav / *_zerg.wav, $Out\eva_mapping.csv"
"install: powershell -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Install"
