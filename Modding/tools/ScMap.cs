// StarCraft map reading: MPQ (.scm/.scx), CHK sections, tileset terrain data.
// C# 5 for PowerShell 5.1 Add-Type. Add-Type -Path Casc.cs,ModTools.cs,ScMap.cs -ReferencedAssemblies System.Drawing
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.IO.Compression;
using System.Text;

// ---------------------------------------------------------------- MPQ (format 0/1, as used by StarCraft maps)
public class Mpq
{
    static uint[] crypt;
    byte[] d;
    int arc;                 // archive start inside the file
    int sectorSize;
    uint[] hashTable, blockTable;

    public Mpq(byte[] data)
    {
        d = data;
        arc = -1;
        for (int p = 0; p + 32 <= d.Length; p += 512)
            if (d[p] == 'M' && d[p + 1] == 'P' && d[p + 2] == 'Q' && d[p + 3] == 0x1A) { arc = p; break; }
        if (arc < 0) throw new Exception("no MPQ header");
        sectorSize = 512 << BitConverter.ToUInt16(d, arc + 14);
        uint hashPos = BitConverter.ToUInt32(d, arc + 16), blockPos = BitConverter.ToUInt32(d, arc + 20);
        uint hashCount = BitConverter.ToUInt32(d, arc + 24), blockCount = BitConverter.ToUInt32(d, arc + 28);
        hashTable = ReadTable(arc + (int)hashPos, (int)hashCount * 4, Hash("(hash table)", 3));
        blockTable = ReadTable(arc + (int)blockPos, (int)blockCount * 4, Hash("(block table)", 3));
    }

    uint[] ReadTable(int pos, int words, uint key)
    {
        uint[] t = new uint[words];
        for (int i = 0; i < words; i++) t[i] = pos + i * 4 + 4 <= d.Length ? BitConverter.ToUInt32(d, pos + i * 4) : 0;
        Decrypt(t, key);
        return t;
    }

    static void InitCrypt()
    {
        crypt = new uint[0x500];
        uint seed = 0x00100001;
        for (int i1 = 0; i1 < 0x100; i1++)
            for (int i2 = i1, i = 0; i < 5; i++, i2 += 0x100)
            {
                seed = (seed * 125 + 3) % 0x2AAAAB; uint t1 = (seed & 0xFFFF) << 16;
                seed = (seed * 125 + 3) % 0x2AAAAB; uint t2 = seed & 0xFFFF;
                crypt[i2] = t1 | t2;
            }
    }

    public static uint Hash(string s, uint type)
    {
        if (crypt == null) InitCrypt();
        uint s1 = 0x7FED7FED, s2 = 0xEEEEEEEE;
        foreach (char c0 in s.ToUpperInvariant())
        {
            uint c = (uint)c0;
            s1 = crypt[(type << 8) + c] ^ (s1 + s2);
            s2 = c + s1 + s2 + (s2 << 5) + 3;
        }
        return s1;
    }

    static void Decrypt(uint[] data, uint key)
    {
        if (crypt == null) InitCrypt();
        uint seed = 0xEEEEEEEE;
        for (int i = 0; i < data.Length; i++)
        {
            seed += crypt[0x400 + (key & 0xFF)];
            uint ch = data[i] ^ (key + seed);
            key = ((~key << 0x15) + 0x11111111) | (key >> 0x0B);
            seed = ch + seed + (seed << 5) + 3;
            data[i] = ch;
        }
    }

    static byte[] DecryptBytes(byte[] b, uint key)
    {
        uint[] w = new uint[b.Length / 4];
        Buffer.BlockCopy(b, 0, w, 0, w.Length * 4);
        Decrypt(w, key);
        byte[] o = (byte[])b.Clone();
        Buffer.BlockCopy(w, 0, o, 0, w.Length * 4);
        return o;
    }

    public bool Has(string name) { return FindBlock(name) >= 0; }

    int FindBlock(string name)
    {
        int n = hashTable.Length / 4;
        uint start = Hash(name, 0) % (uint)n, a = Hash(name, 1), b = Hash(name, 2);
        for (int k = 0; k < n; k++)
        {
            int i = (int)((start + k) % n);
            uint blk = hashTable[i * 4 + 3];
            if (blk == 0xFFFFFFFF) return -1;
            if (hashTable[i * 4] == a && hashTable[i * 4 + 1] == b && blk < blockTable.Length / 4) return (int)blk;
        }
        return -1;
    }

    public byte[] Read(string name)
    {
        int blk = FindBlock(name);
        if (blk < 0) return null;
        uint off = blockTable[blk * 4], csize = blockTable[blk * 4 + 1], fsize = blockTable[blk * 4 + 2], flags = blockTable[blk * 4 + 3];
        int abs = arc + (int)off;
        bool enc = (flags & 0x00010000) != 0, implode = (flags & 0x100) != 0, compress = (flags & 0x200) != 0;
        uint key = 0;
        if (enc)
        {
            string bn = name.Substring(name.LastIndexOf('\\') + 1);
            key = Hash(bn, 3);
            if ((flags & 0x00020000) != 0) key = (key + off) ^ fsize;
        }
        if ((flags & 0x01000000) != 0)
        {
            byte[] raw = Slice(abs, (int)csize);
            if (enc) raw = DecryptBytes(raw, key);
            if (csize < fsize) raw = Decompress(raw, (int)fsize, implode);
            return raw;
        }
        int sectors = (int)((fsize + sectorSize - 1) / sectorSize);
        MemoryStream outp = new MemoryStream();
        if (implode || compress)
        {
            int entries = sectors + 1 + ((flags & 0x04000000) != 0 ? 1 : 0);
            uint[] tab = new uint[entries];
            for (int i = 0; i < entries; i++) tab[i] = BitConverter.ToUInt32(d, abs + i * 4);
            if (enc) Decrypt(tab, key - 1);
            for (int i = 0; i < sectors; i++)
            {
                int expect = (int)Math.Min(sectorSize, fsize - i * sectorSize);
                byte[] s = Slice(abs + (int)tab[i], (int)(tab[i + 1] - tab[i]));
                if (enc) s = DecryptBytes(s, key + (uint)i);
                if (s.Length < expect) s = Decompress(s, expect, implode && !compress);
                outp.Write(s, 0, Math.Min(s.Length, expect));
            }
        }
        else
        {
            for (int i = 0; i < sectors; i++)
            {
                int expect = (int)Math.Min(sectorSize, fsize - i * sectorSize);
                byte[] s = Slice(abs + i * sectorSize, expect);
                if (enc) s = DecryptBytes(s, key + (uint)i);
                outp.Write(s, 0, s.Length);
            }
        }
        return outp.ToArray();
    }

    byte[] Slice(int pos, int len)
    {
        byte[] b = new byte[len];
        Buffer.BlockCopy(d, pos, b, 0, Math.Min(len, d.Length - pos));
        return b;
    }

    static byte[] Decompress(byte[] s, int expect, bool pkwareOnly)
    {
        if (pkwareOnly) return Explode.Run(s, 0, expect);
        int mask = s[0];
        byte[] body = new byte[s.Length - 1];
        Buffer.BlockCopy(s, 1, body, 0, body.Length);
        if ((mask & ~0x0A) != 0) throw new Exception("unsupported MPQ compression mask 0x" + mask.ToString("X2"));
        if ((mask & 0x08) != 0) body = Explode.Run(body, 0, expect);
        if ((mask & 0x02) != 0)
        {
            using (MemoryStream ms = new MemoryStream(body, 2, body.Length - 2))
            using (DeflateStream ds = new DeflateStream(ms, CompressionMode.Decompress))
            using (MemoryStream o = new MemoryStream()) { ds.CopyTo(o); body = o.ToArray(); }
        }
        return body;
    }
}

// ---------------------------------------------------------------- PKWARE DCL explode (port of zlib's contrib/blast)
public static class Explode
{
    const int MAXBITS = 13;
    class Huff { public short[] Count = new short[MAXBITS + 1]; public short[] Symbol; public Huff(int n) { Symbol = new short[n]; } }
    static Huff lit, len, dist;
    static readonly byte[] LitLen = {
        11, 124, 8, 7, 28, 7, 188, 13, 76, 4, 10, 8, 12, 10, 12, 10, 8, 23, 8,
        9, 7, 6, 7, 8, 7, 6, 55, 8, 23, 24, 12, 11, 7, 9, 11, 12, 6, 7, 22, 5,
        7, 24, 6, 11, 9, 6, 7, 22, 7, 11, 38, 7, 9, 8, 25, 11, 8, 11, 9, 12,
        8, 12, 5, 38, 5, 38, 5, 11, 7, 5, 6, 21, 6, 10, 53, 8, 7, 24, 10, 27,
        44, 253, 253, 253, 252, 252, 252, 13, 12, 45, 12, 45, 12, 61, 12, 45,
        44, 173 };
    static readonly byte[] LenLen = { 2, 35, 36, 53, 38, 23 };
    static readonly byte[] DistLen = { 2, 20, 53, 230, 247, 151, 248 };
    static readonly short[] Base = { 3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264 };
    static readonly byte[] Extra = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8 };

    static int Construct(Huff h, byte[] rep)
    {
        short[] length = new short[256];
        int symbol = 0;
        foreach (byte r in rep) { int l = r & 15, left = (r >> 4) + 1; while (left-- > 0) length[symbol++] = (short)l; }
        int n = symbol;
        for (int l = 0; l <= MAXBITS; l++) h.Count[l] = 0;
        for (int s = 0; s < n; s++) h.Count[length[s]]++;
        if (h.Count[0] == n) return 0;
        int lft = 1;
        for (int l = 1; l <= MAXBITS; l++) { lft <<= 1; lft -= h.Count[l]; if (lft < 0) return lft; }
        short[] offs = new short[MAXBITS + 1];
        for (int l = 1; l < MAXBITS; l++) offs[l + 1] = (short)(offs[l] + h.Count[l]);
        for (int s = 0; s < n; s++) if (length[s] != 0) h.Symbol[offs[length[s]]++] = (short)s;
        return lft;
    }

    class St { public byte[] In; public int Pos, End; public int BitBuf, BitCnt; }

    static int Bits(St s, int need)
    {
        int val = s.BitBuf;
        while (s.BitCnt < need)
        {
            if (s.Pos >= s.End) throw new Exception("explode: out of input");
            val |= s.In[s.Pos++] << s.BitCnt;
            s.BitCnt += 8;
        }
        s.BitBuf = val >> need;
        s.BitCnt -= need;
        return val & ((1 << need) - 1);
    }

    static int Decode(St s, Huff h)
    {
        int bitbuf = s.BitBuf, left = s.BitCnt, code = 0, first = 0, index = 0, ln = 1, next = 1;
        while (true)
        {
            while (left-- > 0)
            {
                code |= (bitbuf & 1) ^ 1;
                bitbuf >>= 1;
                int count = h.Count[next++];
                if (code < first + count) { s.BitBuf = bitbuf; s.BitCnt = (s.BitCnt - ln) & 7; return h.Symbol[index + (code - first)]; }
                index += count; first += count; first <<= 1; code <<= 1; ln++;
            }
            left = (MAXBITS + 1) - ln;
            if (left == 0) break;
            if (s.Pos >= s.End) throw new Exception("explode: out of input");
            bitbuf = s.In[s.Pos++];
            if (left > 8) left = 8;
        }
        throw new Exception("explode: bad code");
    }

    public static byte[] Run(byte[] input, int pos, int expect)
    {
        if (len == null)
        {
            lit = new Huff(256); len = new Huff(16); dist = new Huff(64);
            if (Construct(lit, LitLen) != 0 || Construct(len, LenLen) != 0 || Construct(dist, DistLen) != 0)
                throw new Exception("explode: bad code tables");
        }
        St s = new St { In = input, Pos = pos, End = input.Length };
        List<byte> o = new List<byte>(expect);
        int litMode = Bits(s, 8), dict = Bits(s, 8);
        if (litMode > 1 || dict < 4 || dict > 6) throw new Exception("explode: bad header");
        while (true)
        {
            if (Bits(s, 1) != 0)
            {
                int sym = Decode(s, len);
                int l = Base[sym] + Bits(s, Extra[sym]);
                if (l == 519) break;
                int sh = l == 2 ? 2 : dict;
                int dd = (Decode(s, dist) << sh) + Bits(s, sh) + 1;
                if (dd > o.Count) throw new Exception("explode: distance too far");
                int from = o.Count - dd;
                for (int k = 0; k < l; k++) o.Add(o[from + k]);
            }
            else o.Add((byte)(litMode != 0 ? Decode(s, lit) : Bits(s, 8)));
            if (o.Count >= expect && s.Pos >= s.End) break;
        }
        return o.ToArray();
    }
}

// ---------------------------------------------------------------- CHK scenario
public class ScUnit { public int X, Y, Id, Owner, Resources; }
public class ScDoodad { public int X, Y, Id, Owner, Flags; }

public class Chk
{
    public Dictionary<string, byte[]> Sections = new Dictionary<string, byte[]>();
    public int Width, Height, Era;
    public ushort[] Mtxm;
    public List<ScUnit> Units = new List<ScUnit>();
    public List<ScDoodad> Sprites = new List<ScDoodad>();
    public List<string> Strings = new List<string>();
    public static readonly string[] EraNames = { "badlands", "platform", "install", "ashworld", "jungle", "Desert", "Ice", "Twilight" };

    public Chk(byte[] d)
    {
        int p = 0;
        Dictionary<string, List<byte[]>> all = new Dictionary<string, List<byte[]>>();
        while (p + 8 <= d.Length)
        {
            string name = Encoding.ASCII.GetString(d, p, 4);
            int size = BitConverter.ToInt32(d, p + 4);
            p += 8;
            if (size < 0) { p += size; continue; }
            int n = Math.Min(size, d.Length - p);
            byte[] b = new byte[n];
            Buffer.BlockCopy(d, p, b, 0, n);
            if (!all.ContainsKey(name)) all[name] = new List<byte[]>();
            all[name].Add(b);
            p += size;
        }
        foreach (KeyValuePair<string, List<byte[]>> kv in all) Sections[kv.Key] = kv.Value[kv.Value.Count - 1];
        byte[] dim = Sections["DIM "];
        Width = BitConverter.ToUInt16(dim, 0); Height = BitConverter.ToUInt16(dim, 2);
        Era = BitConverter.ToUInt16(Sections["ERA "], 0) & 7;
        Mtxm = new ushort[Width * Height];
        foreach (byte[] m in all["MTXM"])   // later sections overwrite earlier ones, like the game
            for (int i = 0; i < Mtxm.Length && i * 2 + 1 < m.Length; i++) Mtxm[i] = BitConverter.ToUInt16(m, i * 2);
        if (Sections.ContainsKey("UNIT"))
        {
            byte[] u = Sections["UNIT"];
            for (int i = 0; i + 36 <= u.Length; i += 36)
                Units.Add(new ScUnit { X = BitConverter.ToUInt16(u, i + 4), Y = BitConverter.ToUInt16(u, i + 6), Id = BitConverter.ToUInt16(u, i + 8), Owner = u[i + 16], Resources = BitConverter.ToInt32(u, i + 20) });
        }
        if (Sections.ContainsKey("THG2"))
        {
            byte[] t = Sections["THG2"];
            for (int i = 0; i + 10 <= t.Length; i += 10)
                Sprites.Add(new ScDoodad { Id = BitConverter.ToUInt16(t, i), X = BitConverter.ToUInt16(t, i + 2), Y = BitConverter.ToUInt16(t, i + 4), Owner = t[i + 6], Flags = BitConverter.ToUInt16(t, i + 8) });
        }
        byte[] str;
        if (Sections.TryGetValue("STR ", out str) && str.Length >= 2)
        {
            int count = BitConverter.ToUInt16(str, 0);
            for (int i = 0; i < count && 2 + i * 2 + 1 < str.Length; i++)
            {
                int o = BitConverter.ToUInt16(str, 2 + i * 2), e = o;
                while (e < str.Length && str[e] != 0) e++;
                Strings.Add(o < str.Length ? Encoding.GetEncoding(1252).GetString(str, o, e - o) : "");
            }
        }
    }

    public string Str(int id) { return id >= 1 && id <= Strings.Count ? Strings[id - 1] : ""; }
}

// ---------------------------------------------------------------- tileset: cv5 / vf4 / vx4ex / vr4 / wpe
public class ScTileset
{
    public byte[] Cv5, Vf4, Vx4, Vr4;
    public Color[] Pal;
    public int Groups { get { return Cv5.Length / 52; } }

    public ScTileset(Casc casc, string era)
    {
        Cv5 = casc.ReadFile("TileSet/" + era + ".cv5");
        Vf4 = casc.ReadFile("TileSet/" + era + ".vf4");
        Vx4 = casc.ReadFile("TileSet/" + era + ".vx4ex");
        Vr4 = casc.ReadFile("TileSet/" + era + ".vr4");
        Pal = global::Pal.ReadWpe(casc.ReadFile("TileSet/" + era + ".wpe"));
    }

    public int GroupType(int group) { return group * 52 + 2 <= Cv5.Length ? BitConverter.ToUInt16(Cv5, group * 52) : 0; }
    public int GroupFlags(int group) { return group * 52 + 4 <= Cv5.Length ? BitConverter.ToUInt16(Cv5, group * 52 + 2) : 0; }

    public int Megatile(ushort tile)
    {
        int g = tile >> 4, s = tile & 15;
        if (g * 52 + 52 > Cv5.Length) return 0;
        return BitConverter.ToUInt16(Cv5, g * 52 + 20 + s * 2);
    }

    // VF4 flags of minitile (mx,my) 0..3 of a megatile: 1 walkable, 2 mid, 4 high, 8 blocks view.
    public int MiniFlags(int mega, int mx, int my)
    {
        int o = mega * 32 + (my * 4 + mx) * 2;
        return o + 2 <= Vf4.Length ? BitConverter.ToUInt16(Vf4, o) : 0;
    }

    // Colour of pixel (px,py) 0..31 inside a megatile.
    public Color Pixel(int mega, int px, int py)
    {
        int mini = (py >> 3) * 4 + (px >> 3);
        uint v = BitConverter.ToUInt32(Vx4, mega * 64 + mini * 4);
        int img = (int)(v >> 1);
        bool flip = (v & 1) != 0;
        int x = px & 7, y = py & 7;
        if (flip) x = 7 - x;
        int o = img * 64 + y * 8 + x;
        return o < Vr4.Length ? Pal[Vr4[o]] : Color.Black;
    }

    public Color MiniAverage(int mega, int mx, int my)
    {
        int r = 0, g = 0, b = 0;
        for (int y = 0; y < 8; y++) for (int x = 0; x < 8; x++)
        {
            Color c = Pixel(mega, mx * 8 + x, my * 8 + y);
            r += c.R; g += c.G; b += c.B;
        }
        return Color.FromArgb(r / 64, g / 64, b / 64);
    }
}

// ---------------------------------------------------------------- per-minitile view of a map (8x8 px cells)
public class ScTerrain
{
    public int W, H;            // minitiles
    public int[] Flags;         // VF4 flags
    public int[] Rgb;           // average colour
    public Chk Map;
    public ScTileset Ts;

    public ScTerrain(Chk chk, ScTileset ts)
    {
        Map = chk; Ts = ts;
        W = chk.Width * 4; H = chk.Height * 4;
        Flags = new int[W * H]; Rgb = new int[W * H];
        for (int ty = 0; ty < chk.Height; ty++) for (int tx = 0; tx < chk.Width; tx++)
        {
            int mega = ts.Megatile(chk.Mtxm[ty * chk.Width + tx]);
            for (int my = 0; my < 4; my++) for (int mx = 0; mx < 4; mx++)
            {
                int i = (ty * 4 + my) * W + tx * 4 + mx;
                Flags[i] = ts.MiniFlags(mega, mx, my);
                Rgb[i] = ts.MiniAverage(mega, mx, my).ToArgb();
            }
        }
    }

    public int Level(int i) { int f = Flags[i]; return (f & 4) != 0 ? 2 : (f & 2) != 0 ? 1 : 0; }
    public bool Walkable(int i) { return (Flags[i] & 1) != 0; }

    // Real pixels, one sample every `step` px (step 4 -> 8 px per tile).
    public Bitmap RenderNatural(int step)
    {
        int tilePx = 32 / step;
        Bitmap bmp = new Bitmap(Map.Width * tilePx, Map.Height * tilePx, PixelFormat.Format32bppArgb);
        int[] buf = new int[bmp.Width * bmp.Height];
        for (int ty = 0; ty < Map.Height; ty++) for (int tx = 0; tx < Map.Width; tx++)
        {
            int mega = Ts.Megatile(Map.Mtxm[ty * Map.Width + tx]);
            for (int y = 0; y < tilePx; y++) for (int x = 0; x < tilePx; x++)
                buf[(ty * tilePx + y) * bmp.Width + tx * tilePx + x] = Ts.Pixel(mega, x * step, y * step).ToArgb();
        }
        Img.Put(bmp, buf);
        return bmp;
    }

    // Walkability / elevation: dark = unwalkable, green/yellow/orange = low/mid/high ground.
    public Bitmap RenderLevels(int scale)
    {
        int[] pal = { Color.FromArgb(70, 140, 60).ToArgb(), Color.FromArgb(200, 190, 70).ToArgb(), Color.FromArgb(220, 110, 50).ToArgb() };
        int[] dark = { Color.FromArgb(20, 40, 20).ToArgb(), Color.FromArgb(60, 55, 20).ToArgb(), Color.FromArgb(70, 35, 15).ToArgb() };
        int[] buf = new int[W * H];
        for (int i = 0; i < W * H; i++) buf[i] = Walkable(i) ? pal[Level(i)] : dark[Level(i)];
        return Img.Scale(Img.FromBuffer(buf, W, H), scale);
    }
}

public static class Img
{
    public static void Put(Bitmap bmp, int[] buf)
    {
        BitmapData bd = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        for (int y = 0; y < bmp.Height; y++) System.Runtime.InteropServices.Marshal.Copy(buf, y * bmp.Width, bd.Scan0 + y * bd.Stride, bmp.Width);
        bmp.UnlockBits(bd);
    }
    public static Bitmap FromBuffer(int[] buf, int w, int h)
    {
        Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        Put(bmp, buf);
        return bmp;
    }
    public static Bitmap Scale(Bitmap src, int s)
    {
        if (s == 1) return src;
        Bitmap b = new Bitmap(src.Width * s, src.Height * s, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(b))
        {
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
            g.DrawImage(src, 0, 0, b.Width, b.Height);
        }
        src.Dispose();
        return b;
    }
}
