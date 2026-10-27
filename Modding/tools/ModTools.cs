// Asset helpers for DTA (Tiberian Sun) modding. C# 5 for PowerShell 5.1 Add-Type.
// Add-Type -Path Casc.cs,ModTools.cs -ReferencedAssemblies System.Drawing
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Text;

// ---------------------------------------------------------------- MIX (TS, unencrypted)
public class Mix
{
    public string Path;
    public Dictionary<uint, long[]> Entries = new Dictionary<uint, long[]>(); // id -> [offset, size]
    long bodyStart;

    public Mix(string path)
    {
        Path = path;
        using (BinaryReader r = new BinaryReader(File.OpenRead(path)))
        {
            ushort first = r.ReadUInt16();
            int count;
            if (first == 0)
            {
                ushort flagsHi = r.ReadUInt16();
                if ((flagsHi & 0x2) != 0) throw new Exception("encrypted MIX not supported: " + path);
                count = r.ReadUInt16();
            }
            else count = first;
            r.ReadUInt32(); // body size
            for (int i = 0; i < count; i++)
            {
                uint id = r.ReadUInt32();
                uint off = r.ReadUInt32();
                uint size = r.ReadUInt32();
                Entries[id] = new long[] { off, size };
            }
            bodyStart = r.BaseStream.Position;
        }
    }

    public static uint Id(string name)
    {
        string n = name.ToUpperInvariant();
        int l = n.Length;
        int a = l >> 2 << 2;
        if ((l & 3) != 0)
        {
            StringBuilder sb = new StringBuilder(n);
            sb.Append((char)(l - a));
            int i = 3 - (l & 3);
            while (i-- > 0) sb.Append(n[a]);
            n = sb.ToString();
        }
        return Crc32(Encoding.ASCII.GetBytes(n));
    }

    public bool Has(string name) { return Entries.ContainsKey(Id(name)); }

    public byte[] Read(string name)
    {
        long[] e;
        if (!Entries.TryGetValue(Id(name), out e)) return null;
        using (FileStream fs = File.OpenRead(Path))
        {
            fs.Seek(bodyStart + e[0], SeekOrigin.Begin);
            byte[] b = new byte[e[1]];
            fs.Read(b, 0, b.Length);
            return b;
        }
    }

    static uint[] crcTable;
    public static uint Crc32(byte[] data)
    {
        if (crcTable == null)
        {
            crcTable = new uint[256];
            for (uint i = 0; i < 256; i++)
            {
                uint c = i;
                for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
                crcTable[i] = c;
            }
        }
        uint crc = 0xFFFFFFFF;
        foreach (byte b in data) crc = crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
        return crc ^ 0xFFFFFFFF;
    }

    // Writes an unencrypted TS MIX from name -> data.
    public static void Write(string path, Dictionary<string, byte[]> files)
    {
        List<KeyValuePair<uint, byte[]>> list = new List<KeyValuePair<uint, byte[]>>();
        foreach (KeyValuePair<string, byte[]> kv in files) list.Add(new KeyValuePair<uint, byte[]>(Id(kv.Key), kv.Value));
        list.Sort(delegate (KeyValuePair<uint, byte[]> x, KeyValuePair<uint, byte[]> y) { return ((int)x.Key).CompareTo((int)y.Key); });
        using (BinaryWriter w = new BinaryWriter(File.Create(path)))
        {
            w.Write((ushort)0); w.Write((ushort)0); // new format, no flags
            w.Write((ushort)list.Count);
            uint body = 0;
            foreach (KeyValuePair<uint, byte[]> kv in list) body += (uint)kv.Value.Length;
            w.Write(body);
            uint off = 0;
            foreach (KeyValuePair<uint, byte[]> kv in list) { w.Write(kv.Key); w.Write(off); w.Write((uint)kv.Value.Length); off += (uint)kv.Value.Length; }
            foreach (KeyValuePair<uint, byte[]> kv in list) w.Write(kv.Value);
        }
    }
}

// Searches every MIX in a folder (and loose files in given dirs) for a name.
public class MixSet
{
    public List<Mix> Mixes = new List<Mix>();
    public MixSet(string mixDir)
    {
        foreach (string f in Directory.GetFiles(mixDir, "*.mix")) Mixes.Add(new Mix(f));
    }
    public byte[] Read(string name)
    {
        foreach (Mix m in Mixes) { byte[] b = m.Read(name); if (b != null) return b; }
        return null;
    }
    public string Where(string name)
    {
        List<string> r = new List<string>();
        foreach (Mix m in Mixes) if (m.Has(name)) r.Add(System.IO.Path.GetFileName(m.Path));
        return string.Join(",", r.ToArray());
    }
}

// ---------------------------------------------------------------- 8-bit frame
public class Frame
{
    public int X, Y, W, H;      // placement inside the full canvas
    public byte[] Pixels;       // W*H palette indices, 0 = transparent
    public Frame(int x, int y, int w, int h) { X = x; Y = y; W = w; H = h; Pixels = new byte[Math.Max(0, w * h)]; }
}

// ---------------------------------------------------------------- TS SHP
public class Shp
{
    public int Width, Height;
    public List<Frame> Frames = new List<Frame>();

    public static Shp Read(byte[] d)
    {
        Shp s = new Shp();
        s.Width = BitConverter.ToUInt16(d, 2);
        s.Height = BitConverter.ToUInt16(d, 4);
        int count = BitConverter.ToUInt16(d, 6);
        for (int i = 0; i < count; i++)
        {
            int h = 8 + i * 24;
            int x = BitConverter.ToUInt16(d, h), y = BitConverter.ToUInt16(d, h + 2);
            int w = BitConverter.ToUInt16(d, h + 4), hh = BitConverter.ToUInt16(d, h + 6);
            int comp = d[h + 8];
            int off = BitConverter.ToInt32(d, h + 20);
            Frame f = new Frame(x, y, w, hh);
            if (off != 0 && w > 0 && hh > 0)
            {
                if (comp <= 1) Buffer.BlockCopy(d, off, f.Pixels, 0, w * hh);
                else
                {
                    int p = off;
                    for (int row = 0; row < hh; row++)
                    {
                        int len = BitConverter.ToUInt16(d, p);
                        int end = p + len; p += 2;
                        int col = 0;
                        while (p < end && col < w)
                        {
                            byte v = d[p++];
                            if (comp == 3 && v == 0) { col += d[p++]; }
                            else f.Pixels[row * w + col++] = v;
                        }
                        p = end;
                    }
                }
            }
            s.Frames.Add(f);
        }
        return s;
    }

    // Writes with compression 3 (RLE of zero runs), like XCC/OS SHP Builder.
    public byte[] Write()
    {
        MemoryStream ms = new MemoryStream();
        BinaryWriter w = new BinaryWriter(ms);
        w.Write((ushort)0); w.Write((ushort)Width); w.Write((ushort)Height); w.Write((ushort)Frames.Count);
        long headerStart = ms.Position;
        for (int i = 0; i < Frames.Count; i++) w.Write(new byte[24]);
        List<long> offsets = new List<long>();
        List<Frame> trimmed = new List<Frame>();
        foreach (Frame f in Frames)
        {
            Frame t = Trim(f);
            trimmed.Add(t);
            if (t.W == 0 || t.H == 0) { offsets.Add(0); continue; }
            offsets.Add(ms.Position);
            for (int row = 0; row < t.H; row++)
            {
                MemoryStream line = new MemoryStream();
                int col = 0;
                while (col < t.W)
                {
                    byte v = t.Pixels[row * t.W + col];
                    if (v == 0)
                    {
                        int run = 0;
                        while (col < t.W && t.Pixels[row * t.W + col] == 0 && run < 255) { run++; col++; }
                        line.WriteByte(0); line.WriteByte((byte)run);
                    }
                    else { line.WriteByte(v); col++; }
                }
                w.Write((ushort)(line.Length + 2));
                w.Write(line.ToArray());
            }
            while (ms.Position % 8 != 0) w.Write((byte)0);
        }
        for (int i = 0; i < trimmed.Count; i++)
        {
            Frame t = trimmed[i];
            ms.Position = headerStart + i * 24;
            w.Write((ushort)t.X); w.Write((ushort)t.Y); w.Write((ushort)t.W); w.Write((ushort)t.H);
            w.Write((uint)(t.W == 0 ? 0 : 3));
            w.Write((uint)0); w.Write((uint)0);
            w.Write((uint)offsets[i]);
        }
        return ms.ToArray();
    }

    static Frame Trim(Frame f)
    {
        int minX = f.W, minY = f.H, maxX = -1, maxY = -1;
        for (int y = 0; y < f.H; y++) for (int x = 0; x < f.W; x++)
            if (f.Pixels[y * f.W + x] != 0) { if (x < minX) minX = x; if (y < minY) minY = y; if (x > maxX) maxX = x; if (y > maxY) maxY = y; }
        if (maxX < 0) return new Frame(0, 0, 0, 0);
        Frame t = new Frame(f.X + minX, f.Y + minY, maxX - minX + 1, maxY - minY + 1);
        for (int y = 0; y < t.H; y++) Buffer.BlockCopy(f.Pixels, (minY + y) * f.W + minX, t.Pixels, y * t.W, t.W);
        return t;
    }
}

// ---------------------------------------------------------------- StarCraft GRP
public class Grp
{
    public int Width, Height;
    public List<Frame> Frames = new List<Frame>();

    public static Grp Read(byte[] d)
    {
        Grp g = new Grp();
        int count = BitConverter.ToUInt16(d, 0);
        g.Width = BitConverter.ToUInt16(d, 2);
        g.Height = BitConverter.ToUInt16(d, 4);
        for (int i = 0; i < count; i++)
        {
            int h = 6 + i * 8;
            int x = d[h], y = d[h + 1], w = d[h + 2], hh = d[h + 3];
            int off = BitConverter.ToInt32(d, h + 4);
            Frame f = new Frame(x, y, w, hh);
            for (int row = 0; row < hh; row++)
            {
                int p = off + BitConverter.ToUInt16(d, off + row * 2);
                int col = 0;
                while (col < w)
                {
                    byte c = d[p++];
                    if ((c & 0x80) != 0) col += c & 0x7F;
                    else if ((c & 0x40) != 0) { int n = c & 0x3F; byte v = d[p++]; for (int k = 0; k < n && col < w; k++) f.Pixels[row * w + col++] = v; }
                    else { for (int k = 0; k < c && col < w; k++) f.Pixels[row * w + col++] = d[p++]; }
                }
            }
            g.Frames.Add(f);
        }
        return g;
    }
}

// ---------------------------------------------------------------- Westwood AUD (IMA ADPCM, type 99)
public static class Aud
{
    static readonly int[] IndexTable = { -1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8 };
    static readonly int[] StepTable = {
        7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97,
        107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
        876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428,
        4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350,
        22385, 24623, 27086, 29794, 32767 };

    // Returns 16-bit mono samples and sample rate from a PCM WAV.
    public static short[] ReadWav(byte[] d, out int rate)
    {
        int channels = BitConverter.ToUInt16(d, 22);
        rate = BitConverter.ToInt32(d, 24);
        int bits = BitConverter.ToUInt16(d, 34);
        int p = 12;
        while (p + 8 <= d.Length)
        {
            string id = Encoding.ASCII.GetString(d, p, 4);
            int len = BitConverter.ToInt32(d, p + 4);
            if (id == "data")
            {
                int frames = len / (bits / 8) / channels;
                short[] s = new short[frames];
                for (int i = 0; i < frames; i++)
                {
                    int acc = 0;
                    for (int c = 0; c < channels; c++)
                    {
                        int o = p + 8 + (i * channels + c) * (bits / 8);
                        acc += bits == 16 ? BitConverter.ToInt16(d, o) : (d[o] - 128) << 8;
                    }
                    s[i] = (short)(acc / channels);
                }
                return s;
            }
            p += 8 + len + (len & 1);
        }
        throw new Exception("no data chunk");
    }

    public static byte[] Encode(short[] samples, int rate, float gain)
    {
        MemoryStream body = new MemoryStream();
        int pred = 0, index = 0;
        for (int start = 0; start < samples.Length; start += 1024)
        {
            int n = Math.Min(1024, samples.Length - start);
            byte[] chunk = new byte[(n + 1) / 2];
            for (int i = 0; i < n; i++)
            {
                int s = (int)(samples[start + i] * gain);
                if (s > 32767) s = 32767; if (s < -32768) s = -32768;
                int step = StepTable[index];
                int diff = s - pred, code = 0;
                if (diff < 0) { code = 8; diff = -diff; }
                int vpdiff = step >> 3;
                if (diff >= step) { code |= 4; diff -= step; vpdiff += step; }
                step >>= 1;
                if (diff >= step) { code |= 2; diff -= step; vpdiff += step; }
                step >>= 1;
                if (diff >= step) { code |= 1; vpdiff += step; }
                pred += (code & 8) != 0 ? -vpdiff : vpdiff;
                if (pred > 32767) pred = 32767; if (pred < -32768) pred = -32768;
                index += IndexTable[code];
                if (index < 0) index = 0; if (index > 88) index = 88;
                if ((i & 1) == 0) chunk[i / 2] = (byte)code; else chunk[i / 2] |= (byte)(code << 4);
            }
            BinaryWriter cw = new BinaryWriter(body);
            cw.Write((ushort)chunk.Length); cw.Write((ushort)(n * 2)); cw.Write((uint)0x0000DEAF); cw.Write(chunk);
        }
        MemoryStream outp = new MemoryStream();
        BinaryWriter w = new BinaryWriter(outp);
        w.Write((ushort)rate); w.Write((uint)body.Length); w.Write((uint)(samples.Length * 2));
        w.Write((byte)2); w.Write((byte)99);
        w.Write(body.ToArray());
        return outp.ToArray();
    }
}

// ---------------------------------------------------------------- SC:R "*.dds.grp" (frames of DDS images, DXT1/DXT5)
public static class DdsGrp
{
    // Layout: uint32 filesize, uint16 frames, uint16 ?, then per frame: uint32 ?, uint16 w, uint16 h, uint32 size, DDS bytes.
    public static List<Bitmap> Read(byte[] d)
    {
        List<Bitmap> list = new List<Bitmap>();
        int frames = BitConverter.ToUInt16(d, 4);
        int p = 8;
        for (int i = 0; i < frames && p + 12 <= d.Length; i++)
        {
            int size = BitConverter.ToInt32(d, p + 8);
            list.Add(DecodeDds(d, p + 12));
            p += 12 + size;
        }
        return list;
    }

    public static Bitmap DecodeDds(byte[] d, int o)
    {
        int h = BitConverter.ToInt32(d, o + 12), w = BitConverter.ToInt32(d, o + 16);
        string fourcc = Encoding.ASCII.GetString(d, o + 84, 4);
        int p = o + 128;
        Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        bool dxt5 = fourcc == "DXT5";
        for (int by = 0; by < (h + 3) / 4; by++)
            for (int bx = 0; bx < (w + 3) / 4; bx++)
            {
                byte[] alpha = null;
                if (dxt5)
                {
                    alpha = new byte[16];
                    int a0 = d[p], a1 = d[p + 1];
                    ulong bits = 0; for (int k = 0; k < 6; k++) bits |= (ulong)d[p + 2 + k] << (8 * k);
                    int[] av = new int[8]; av[0] = a0; av[1] = a1;
                    if (a0 > a1) for (int k = 1; k < 7; k++) av[k + 1] = ((7 - k) * a0 + k * a1) / 7;
                    else { for (int k = 1; k < 5; k++) av[k + 1] = ((5 - k) * a0 + k * a1) / 5; av[6] = 0; av[7] = 255; }
                    for (int k = 0; k < 16; k++) alpha[k] = (byte)av[(bits >> (3 * k)) & 7];
                    p += 8;
                }
                int c0 = BitConverter.ToUInt16(d, p), c1 = BitConverter.ToUInt16(d, p + 2);
                uint idx = BitConverter.ToUInt32(d, p + 4);
                p += 8;
                Color[] c = new Color[4];
                c[0] = C565(c0); c[1] = C565(c1);
                if (c0 > c1 || dxt5)
                {
                    c[2] = Color.FromArgb((2 * c[0].R + c[1].R) / 3, (2 * c[0].G + c[1].G) / 3, (2 * c[0].B + c[1].B) / 3);
                    c[3] = Color.FromArgb((c[0].R + 2 * c[1].R) / 3, (c[0].G + 2 * c[1].G) / 3, (c[0].B + 2 * c[1].B) / 3);
                }
                else { c[2] = Color.FromArgb((c[0].R + c[1].R) / 2, (c[0].G + c[1].G) / 2, (c[0].B + c[1].B) / 2); c[3] = Color.FromArgb(0, 0, 0, 0); }
                for (int k = 0; k < 16; k++)
                {
                    int x = bx * 4 + (k & 3), y = by * 4 + (k >> 2);
                    if (x >= w || y >= h) continue;
                    Color col = c[(idx >> (2 * k)) & 3];
                    if (alpha != null) col = Color.FromArgb(alpha[k], col.R, col.G, col.B);
                    bmp.SetPixel(x, y, col);
                }
            }
        return bmp;
    }

    static Color C565(int v) { return Color.FromArgb(((v >> 11) & 31) * 255 / 31, ((v >> 5) & 63) * 255 / 63, (v & 31) * 255 / 31); }

    public static void Sheet(List<Bitmap> imgs, int cols, int scale, string outPng)
    {
        int cw = 0, ch = 0; foreach (Bitmap b in imgs) { cw = Math.Max(cw, b.Width); ch = Math.Max(ch, b.Height); }
        cw += 4; ch += 12;
        int rows = (imgs.Count + cols - 1) / cols;
        using (Bitmap s = new Bitmap(cols * cw * scale, rows * ch * scale))
        using (Graphics g = Graphics.FromImage(s))
        {
            g.Clear(Color.FromArgb(30, 30, 40));
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            for (int i = 0; i < imgs.Count; i++)
            {
                int x = (i % cols) * cw * scale, y = (i / cols) * ch * scale;
                g.DrawImage(imgs[i], x, y + 10 * scale, imgs[i].Width * scale, imgs[i].Height * scale);
                g.DrawString(i.ToString(), SystemFonts.DefaultFont, Brushes.Yellow, x, y);
            }
            s.Save(outPng, ImageFormat.Png);
        }
    }
}

// ---------------------------------------------------------------- palettes & images
public static class Pal
{
    // TS .pal: 256 * RGB, 6-bit components.
    public static Color[] ReadTs(byte[] d)
    {
        Color[] c = new Color[256];
        for (int i = 0; i < 256; i++) c[i] = Color.FromArgb(Scale6(d[i * 3]), Scale6(d[i * 3 + 1]), Scale6(d[i * 3 + 2]));
        return c;
    }
    static int Scale6(byte v) { return Math.Min(255, (v & 63) * 255 / 63); }

    // StarCraft .wpe: 256 * RGBA (8-bit).
    public static Color[] ReadWpe(byte[] d)
    {
        Color[] c = new Color[256];
        for (int i = 0; i < 256; i++) c[i] = Color.FromArgb(d[i * 4], d[i * 4 + 1], d[i * 4 + 2]);
        return c;
    }

    // Nearest colour among palette indices [from, to].
    public static byte Nearest(Color c, Color[] pal, int from, int to)
    {
        int best = from; long bestD = long.MaxValue;
        for (int i = from; i <= to; i++)
        {
            long dr = c.R - pal[i].R, dg = c.G - pal[i].G, db = c.B - pal[i].B;
            long dist = 2 * dr * dr + 4 * dg * dg + 3 * db * db;
            if (dist < bestD) { bestD = dist; best = i; }
        }
        return (byte)best;
    }

    public static Bitmap ToBitmap(Frame f, int canvasW, int canvasH, Color[] pal, int scale)
    {
        Bitmap bmp = new Bitmap(canvasW * scale, canvasH * scale, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) g.Clear(Color.FromArgb(255, 40, 60, 40));
        for (int y = 0; y < f.H; y++) for (int x = 0; x < f.W; x++)
        {
            byte v = f.Pixels[y * f.W + x];
            if (v == 0) continue;
            Color c = v == 1 ? Color.FromArgb(255, 0, 0, 0) : pal[v];
            for (int sy = 0; sy < scale; sy++) for (int sx = 0; sx < scale; sx++)
            {
                int px = (f.X + x) * scale + sx, py = (f.Y + y) * scale + sy;
                if (px >= 0 && py >= 0 && px < bmp.Width && py < bmp.Height) bmp.SetPixel(px, py, c);
            }
        }
        return bmp;
    }

    // Contact sheet of selected frames.
    public static void Sheet(List<Frame> frames, int[] idx, int canvasW, int canvasH, Color[] pal, int scale, int cols, string outPng)
    {
        int rows = (idx.Length + cols - 1) / cols;
        using (Bitmap sheet = new Bitmap(cols * canvasW * scale, rows * canvasH * scale))
        using (Graphics g = Graphics.FromImage(sheet))
        {
            g.Clear(Color.Black);
            for (int i = 0; i < idx.Length; i++)
            {
                if (idx[i] < 0 || idx[i] >= frames.Count) continue;
                using (Bitmap b = ToBitmap(frames[idx[i]], canvasW, canvasH, pal, scale))
                    g.DrawImage(b, (i % cols) * canvasW * scale, (i / cols) * canvasH * scale);
                g.DrawString(idx[i].ToString(), SystemFonts.DefaultFont, Brushes.Yellow, (i % cols) * canvasW * scale, (i / cols) * canvasH * scale);
            }
            sheet.Save(outPng, ImageFormat.Png);
        }
    }

    // Decodes an 8-bit RLE PCX: returns pixel indices, outputs size and palette.
    public static byte[] ReadPcx(byte[] d, out int w, out int h, out Color[] pal)
    {
        w = BitConverter.ToUInt16(d, 8) - BitConverter.ToUInt16(d, 4) + 1;
        h = BitConverter.ToUInt16(d, 10) - BitConverter.ToUInt16(d, 6) + 1;
        int bpl = BitConverter.ToUInt16(d, 66);
        byte[] px = new byte[w * h];
        int p = 128;
        for (int y = 0; y < h; y++)
        {
            int x = 0;
            while (x < bpl)
            {
                byte b = d[p++];
                int run = 1;
                if ((b & 0xC0) == 0xC0) { run = b & 0x3F; b = d[p++]; }
                for (int k = 0; k < run; k++, x++) if (x < w) px[y * w + x] = b;
            }
        }
        pal = new Color[256];
        int po = d.Length - 768;
        for (int i = 0; i < 256; i++) pal[i] = Color.FromArgb(d[po + i * 3], d[po + i * 3 + 1], d[po + i * 3 + 2]);
        return px;
    }

    // 8-bit RLE PCX with the given palette (8-bit RGB).
    public static byte[] WritePcx(byte[] pixels, int w, int h, Color[] pal)
    {
        MemoryStream ms = new MemoryStream();
        BinaryWriter bw = new BinaryWriter(ms);
        int bpl = w + (w & 1);
        bw.Write((byte)10); bw.Write((byte)5); bw.Write((byte)1); bw.Write((byte)8);
        bw.Write((ushort)0); bw.Write((ushort)0); bw.Write((ushort)(w - 1)); bw.Write((ushort)(h - 1));
        bw.Write((ushort)72); bw.Write((ushort)72);
        bw.Write(new byte[48]); bw.Write((byte)0); bw.Write((byte)1); bw.Write((ushort)bpl); bw.Write((ushort)1);
        bw.Write(new byte[58]);
        for (int y = 0; y < h; y++)
        {
            int x = 0;
            while (x < bpl)
            {
                byte v = x < w ? pixels[y * w + x] : (byte)0;
                int run = 1;
                while (x + run < bpl && run < 63 && (x + run < w ? pixels[y * w + x + run] : (byte)0) == v) run++;
                if (run > 1 || (v & 0xC0) == 0xC0) { bw.Write((byte)(0xC0 | run)); bw.Write(v); }
                else bw.Write(v);
                x += run;
            }
        }
        bw.Write((byte)12);
        for (int i = 0; i < 256; i++) { bw.Write(pal[i].R); bw.Write(pal[i].G); bw.Write(pal[i].B); }
        return ms.ToArray();
    }
}
