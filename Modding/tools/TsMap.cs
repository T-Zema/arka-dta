// Tiberian Sun map data: IsoMapPack5 (LZO), OverlayPack/OverlayDataPack (Format80), TMP tiles, theater tile indexes.
// C# 5 for PowerShell 5.1 Add-Type. Add-Type -Path ModTools.cs,TsMap.cs -ReferencedAssemblies System.Drawing
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Text;

public static class Lzo
{
    // LZO1X decompression.
    public static byte[] Decompress(byte[] src, int srcPos, int srcLen, int outLen)
    {
        byte[] o = new byte[outLen];
        int ip = srcPos, op = 0, t = 0, m;
        const int Instr = 0, FirstLiteralRun = 1, Match = 2, MatchNext = 3;
        int state = Instr;
        if (src[ip] > 17)
        {
            t = src[ip++] - 17;
            if (t < 4) state = MatchNext;
            else { while (t-- > 0) o[op++] = src[ip++]; state = FirstLiteralRun; }
        }
        while (true)
        {
            if (state == Instr)
            {
                t = src[ip++];
                if (t >= 16) { state = Match; continue; }
                if (t == 0) { while (src[ip] == 0) { t += 255; ip++; } t += 15 + src[ip++]; }
                t += 3;
                while (t-- > 0) o[op++] = src[ip++];
                state = FirstLiteralRun;
                continue;
            }
            if (state == FirstLiteralRun)
            {
                t = src[ip++];
                if (t >= 16) { state = Match; continue; }
                m = op - (1 + 0x0800) - (t >> 2) - (src[ip++] << 2);
                o[op++] = o[m++]; o[op++] = o[m++]; o[op++] = o[m];
            }
            else if (state == MatchNext)
            {
                while (t-- > 0) o[op++] = src[ip++];
                t = src[ip++];
                state = Match;
                continue;
            }
            else
            {
                if (t >= 64)
                {
                    m = op - 1 - ((t >> 2) & 7) - (src[ip++] << 3);
                    t = (t >> 5) - 1 + 2;
                    while (t-- > 0) o[op++] = o[m++];
                }
                else if (t >= 32)
                {
                    t &= 31;
                    if (t == 0) { while (src[ip] == 0) { t += 255; ip++; } t += 31 + src[ip++]; }
                    m = op - 1 - ((src[ip] >> 2) + (src[ip + 1] << 6)); ip += 2;
                    t += 2;
                    while (t-- > 0) o[op++] = o[m++];
                }
                else if (t >= 16)
                {
                    m = op - ((t & 8) << 11);
                    t &= 7;
                    if (t == 0) { while (src[ip] == 0) { t += 255; ip++; } t += 7 + src[ip++]; }
                    m -= (src[ip] >> 2) + (src[ip + 1] << 6); ip += 2;
                    if (m == op) return o;
                    m -= 0x4000;
                    t += 2;
                    while (t-- > 0) o[op++] = o[m++];
                }
                else
                {
                    m = op - 1 - (t >> 2) - (src[ip++] << 2);
                    o[op++] = o[m++]; o[op++] = o[m];
                }
            }
            // match done: the low 2 bits of the byte before last say how many literals follow
            t = src[ip - 2] & 3;
            state = t == 0 ? Instr : MatchNext;
        }
    }

    // Valid LZO1X stream made of one literal run + end marker (no real compression; the game only needs to decode it).
    public static byte[] CompressLiteral(byte[] src, int pos, int len)
    {
        MemoryStream ms = new MemoryStream();
        if (len <= 238 && len >= 1) ms.WriteByte((byte)(len + 17));
        else
        {
            int rem = len - 3;
            if (rem <= 15) ms.WriteByte((byte)rem);
            else
            {
                ms.WriteByte(0);
                rem -= 15;
                while (rem > 255) { ms.WriteByte(0); rem -= 255; }
                ms.WriteByte((byte)rem);
            }
        }
        ms.Write(src, pos, len);
        ms.WriteByte(0x11); ms.WriteByte(0); ms.WriteByte(0);
        return ms.ToArray();
    }
}

public static class Format80
{
    public static byte[] Decompress(byte[] s, int pos, int outLen)
    {
        byte[] d = new byte[outLen];
        int i = pos, o = 0;
        while (o < outLen)
        {
            int cmd = s[i++];
            if ((cmd & 0x80) == 0)
            {
                int count = (cmd >> 4) + 3, off = ((cmd & 0x0F) << 8) | s[i++];
                for (int k = 0; k < count; k++, o++) d[o] = d[o - off];
            }
            else if ((cmd & 0x40) == 0)
            {
                int count = cmd & 0x3F;
                if (count == 0) break;
                for (int k = 0; k < count; k++) d[o++] = s[i++];
            }
            else if (cmd == 0xFE)
            {
                int count = s[i] | (s[i + 1] << 8); byte v = s[i + 2]; i += 3;
                for (int k = 0; k < count; k++) d[o++] = v;
            }
            else
            {
                int count = cmd == 0xFF ? (s[i] | (s[i + 1] << 8)) : (cmd & 0x3F) + 3;
                if (cmd == 0xFF) i += 2;
                int p = s[i] | (s[i + 1] << 8); i += 2;
                for (int k = 0; k < count; k++) d[o++] = d[p + k];
            }
        }
        return d;
    }

    // Runs of equal bytes as 0xFE fills, everything else as literal blocks.
    public static byte[] Compress(byte[] s, int pos, int len)
    {
        MemoryStream ms = new MemoryStream();
        int i = pos, end = pos + len;
        while (i < end)
        {
            int run = 1;
            while (i + run < end && s[i + run] == s[i] && run < 0xFFFF) run++;
            if (run >= 4)
            {
                ms.WriteByte(0xFE); ms.WriteByte((byte)run); ms.WriteByte((byte)(run >> 8)); ms.WriteByte(s[i]);
                i += run;
                continue;
            }
            int start = i, n = 0;
            while (i < end && n < 63)
            {
                int r = 1;
                while (i + r < end && s[i + r] == s[i] && r < 4) r++;
                if (r >= 4) break;
                i++; n++;
            }
            ms.WriteByte((byte)(0x80 | n));
            ms.Write(s, start, n);
        }
        ms.WriteByte(0x80);
        return ms.ToArray();
    }
}

// Westwood "pack" container: chunks of [u16 compressed][u16 uncompressed][data].
public static class Pack
{
    public static byte[] Unpack(string base64, bool lzo)
    {
        byte[] b = Convert.FromBase64String(base64);
        MemoryStream o = new MemoryStream();
        int p = 0;
        while (p + 4 <= b.Length)
        {
            int c = BitConverter.ToUInt16(b, p), u = BitConverter.ToUInt16(b, p + 2);
            p += 4;
            byte[] chunk = lzo ? Lzo.Decompress(b, p, c, u) : Format80.Decompress(b, p, u);
            o.Write(chunk, 0, u);
            p += c;
        }
        return o.ToArray();
    }

    public static string PackData(byte[] data, bool lzo, int chunkSize)
    {
        MemoryStream o = new MemoryStream();
        for (int p = 0; p < data.Length; p += chunkSize)
        {
            int n = Math.Min(chunkSize, data.Length - p);
            byte[] c = lzo ? Lzo.CompressLiteral(data, p, n) : Format80.Compress(data, p, n);
            o.Write(BitConverter.GetBytes((ushort)c.Length), 0, 2);
            o.Write(BitConverter.GetBytes((ushort)n), 0, 2);
            o.Write(c, 0, c.Length);
        }
        return Convert.ToBase64String(o.ToArray());
    }

    // INI section body: base64 split in numbered lines of 70 chars.
    public static string ToIniLines(string b64)
    {
        StringBuilder sb = new StringBuilder();
        int line = 1;
        for (int p = 0; p < b64.Length; p += 70, line++)
            sb.Append(line).Append('=').Append(b64.Substring(p, Math.Min(70, b64.Length - p))).Append("\r\n");
        return sb.ToString();
    }
}

// Minimal ordered INI (keeps section and key order, last duplicate key wins).
public class Ini
{
    public List<string> Order = new List<string>();
    public Dictionary<string, List<KeyValuePair<string, string>>> Sections = new Dictionary<string, List<KeyValuePair<string, string>>>(StringComparer.OrdinalIgnoreCase);

    public static Ini Load(string path)
    {
        Ini ini = new Ini();
        string sec = null;
        foreach (string raw in File.ReadAllLines(path, Encoding.GetEncoding(1252)))
        {
            string l = raw.Trim();
            if (l.StartsWith("[")) { int e = l.IndexOf(']'); if (e > 0) { sec = l.Substring(1, e - 1); ini.Section(sec); } continue; }
            if (sec == null || l.StartsWith(";")) continue;
            int eq = l.IndexOf('=');
            if (eq <= 0) continue;
            ini.Set(sec, l.Substring(0, eq).Trim(), l.Substring(eq + 1));
        }
        return ini;
    }

    public List<KeyValuePair<string, string>> Section(string name)
    {
        List<KeyValuePair<string, string>> s;
        if (!Sections.TryGetValue(name, out s)) { s = new List<KeyValuePair<string, string>>(); Sections[name] = s; Order.Add(name); }
        return s;
    }

    public bool Has(string sec) { return Sections.ContainsKey(sec); }

    public string Get(string sec, string key, string def)
    {
        List<KeyValuePair<string, string>> s;
        if (!Sections.TryGetValue(sec, out s)) return def;
        for (int i = s.Count - 1; i >= 0; i--) if (string.Equals(s[i].Key, key, StringComparison.OrdinalIgnoreCase)) return s[i].Value;
        return def;
    }

    public void Set(string sec, string key, string value)
    {
        List<KeyValuePair<string, string>> s = Section(sec);
        for (int i = 0; i < s.Count; i++)
            if (string.Equals(s[i].Key, key, StringComparison.OrdinalIgnoreCase)) { s[i] = new KeyValuePair<string, string>(key, value); return; }
        s.Add(new KeyValuePair<string, string>(key, value));
    }

    // Concatenated values of a numbered pack section (1=,2=,...).
    public string Joined(string sec)
    {
        List<KeyValuePair<string, string>> s;
        if (!Sections.TryGetValue(sec, out s)) return "";
        List<KeyValuePair<string, string>> l = new List<KeyValuePair<string, string>>(s);
        l.Sort(delegate (KeyValuePair<string, string> a, KeyValuePair<string, string> b) { int x, y; int.TryParse(a.Key, out x); int.TryParse(b.Key, out y); return x.CompareTo(y); });
        StringBuilder sb = new StringBuilder();
        foreach (KeyValuePair<string, string> kv in l) sb.Append(kv.Value.Trim());
        return sb.ToString();
    }

    public void SetPack(string sec, string b64)
    {
        if (Sections.ContainsKey(sec)) Sections[sec].Clear(); else Section(sec);
        int line = 1;
        for (int p = 0; p < b64.Length; p += 70, line++) Sections[sec].Add(new KeyValuePair<string, string>(line.ToString(), b64.Substring(p, Math.Min(70, b64.Length - p))));
    }

    public string Write()
    {
        StringBuilder sb = new StringBuilder();
        foreach (string sec in Order)
        {
            sb.Append('[').Append(sec).Append("]\r\n");
            foreach (KeyValuePair<string, string> kv in Sections[sec]) sb.Append(kv.Key).Append('=').Append(kv.Value).Append("\r\n");
            sb.Append("\r\n");
        }
        return sb.ToString();
    }
}

// [Preview] Size=0,0,W,H + [PreviewPack] = LZO chunks of 24-bit RGB rows. The DTA client draws the lobby preview
// of maps in Maps/Custom only from this section (PNG next to the map is used just for MPMaps.ini maps).
public static class MapPreview
{
    public static void Set(Ini ini, Image img, int width)
    {
        int h = img.Height * width / img.Width;
        using (Bitmap b = new Bitmap(width, h, System.Drawing.Imaging.PixelFormat.Format24bppRgb))
        {
            using (Graphics g = Graphics.FromImage(b))
            {
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.DrawImage(img, 0, 0, width, h);
            }
            byte[] rgb = new byte[width * h * 3];
            System.Drawing.Imaging.BitmapData bd = b.LockBits(new Rectangle(0, 0, width, h), System.Drawing.Imaging.ImageLockMode.ReadOnly, System.Drawing.Imaging.PixelFormat.Format24bppRgb);
            byte[] row = new byte[bd.Stride];
            for (int y = 0; y < h; y++)
            {
                System.Runtime.InteropServices.Marshal.Copy(bd.Scan0 + y * bd.Stride, row, 0, bd.Stride);
                for (int x = 0; x < width; x++)
                {
                    int o = (y * width + x) * 3;
                    rgb[o] = row[x * 3 + 2]; rgb[o + 1] = row[x * 3 + 1]; rgb[o + 2] = row[x * 3];   // memory is BGR
                }
            }
            b.UnlockBits(bd);
            ini.Set("Preview", "Size", "0,0," + width + "," + h);
            ini.SetPack("PreviewPack", Pack.PackData(rgb, true, 8192));
        }
    }

    // Decodes [PreviewPack] back to an image (for checks).
    public static Bitmap Get(Ini ini)
    {
        string[] s = ini.Get("Preview", "Size", "0,0,0,0").Split(',');
        int w = int.Parse(s[2]), h = int.Parse(s[3]);
        byte[] rgb = Pack.Unpack(ini.Joined("PreviewPack"), true);
        Bitmap b = new Bitmap(w, h);
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            int o = (y * w + x) * 3;
            b.SetPixel(x, y, Color.FromArgb(rgb[o], rgb[o + 1], rgb[o + 2]));
        }
        return b;
    }
}

public class IsoTile { public int X, Y, Tile, Sub, Level, Ice; }

public static class IsoMap
{
    public static List<IsoTile> Decode(byte[] raw)
    {
        List<IsoTile> l = new List<IsoTile>();
        for (int p = 0; p + 11 <= raw.Length; p += 11)
            l.Add(new IsoTile { X = BitConverter.ToUInt16(raw, p), Y = BitConverter.ToUInt16(raw, p + 2), Tile = BitConverter.ToInt32(raw, p + 4), Sub = raw[p + 8], Level = raw[p + 9], Ice = raw[p + 10] });
        return l;
    }

    public static byte[] Encode(List<IsoTile> tiles)
    {
        byte[] b = new byte[tiles.Count * 11];
        for (int i = 0; i < tiles.Count; i++)
        {
            IsoTile t = tiles[i]; int p = i * 11;
            Buffer.BlockCopy(BitConverter.GetBytes((ushort)t.X), 0, b, p, 2);
            Buffer.BlockCopy(BitConverter.GetBytes((ushort)t.Y), 0, b, p + 2, 2);
            Buffer.BlockCopy(BitConverter.GetBytes(t.Tile), 0, b, p + 4, 4);
            b[p + 8] = (byte)t.Sub; b[p + 9] = (byte)t.Level; b[p + 10] = (byte)t.Ice;
        }
        return b;
    }
}

// ---------------------------------------------------------------- TMP (TS isometric tile template)
public class TmpCell
{
    public int Index;            // position in the template grid (i = y*Width + x)
    public int X, Y;             // pixel offset of the cell image
    public int Height, Terrain, Ramp;
    public Color RadarLeft, RadarRight;
    public byte[] Diamond;       // 48x24 diamond pixels (576 bytes, row-packed)
    public bool HasExtra;
    public int ExtraX, ExtraY, ExtraW, ExtraH;
    public byte[] Extra;
}

public class Tmp
{
    public int Width, Height, BlockW, BlockH;
    public TmpCell[] Cells;      // null where the template has no cell

    public static Tmp Read(byte[] d)
    {
        Tmp t = new Tmp();
        t.Width = BitConverter.ToInt32(d, 0); t.Height = BitConverter.ToInt32(d, 4);
        t.BlockW = BitConverter.ToInt32(d, 8); t.BlockH = BitConverter.ToInt32(d, 12);
        int n = t.Width * t.Height;
        t.Cells = new TmpCell[n];
        int diamondSize = t.BlockW * t.BlockH / 2;
        for (int i = 0; i < n; i++)
        {
            int off = BitConverter.ToInt32(d, 16 + i * 4);
            if (off == 0) continue;
            TmpCell c = new TmpCell();
            c.Index = i;
            c.X = BitConverter.ToInt32(d, off); c.Y = BitConverter.ToInt32(d, off + 4);
            int extraOff = BitConverter.ToInt32(d, off + 8);
            c.ExtraX = BitConverter.ToInt32(d, off + 20); c.ExtraY = BitConverter.ToInt32(d, off + 24);
            c.ExtraW = BitConverter.ToInt32(d, off + 28); c.ExtraH = BitConverter.ToInt32(d, off + 32);
            uint flags = BitConverter.ToUInt32(d, off + 36);
            c.Height = d[off + 40]; c.Terrain = d[off + 41]; c.Ramp = d[off + 42];
            c.RadarLeft = Color.FromArgb(d[off + 43], d[off + 44], d[off + 45]);
            c.RadarRight = Color.FromArgb(d[off + 46], d[off + 47], d[off + 48]);
            c.Diamond = new byte[diamondSize];
            Buffer.BlockCopy(d, off + 52, c.Diamond, 0, Math.Min(diamondSize, d.Length - off - 52));
            c.HasExtra = (flags & 1) != 0;
            if (c.HasExtra && extraOff > 0 && c.ExtraW > 0 && c.ExtraH > 0)
            {
                c.Extra = new byte[c.ExtraW * c.ExtraH];
                Buffer.BlockCopy(d, off + extraOff, c.Extra, 0, Math.Min(c.Extra.Length, d.Length - off - extraOff));
            }
            t.Cells[i] = c;
        }
        return t;
    }
}

public static class TmpRender
{
    // Draws a template into an ARGB buffer; (ox,oy) = screen position of cell (0,0)'s top-left corner.
    public static void Draw(Tmp t, Color[] pal, int[] buf, int bw, int bh, int ox, int oy)
    {
        foreach (TmpCell c in t.Cells)
        {
            if (c == null) continue;
            int cx = c.Index % t.Width, cy = c.Index / t.Width;
            int bx = ox + (cx - cy) * t.BlockW / 2, by = oy + (cx + cy) * t.BlockH / 2 - c.Height * t.BlockH / 2;
            int width = 4, p = 0;
            for (int j = 0; j < t.BlockH; j++)
            {
                int start = (t.BlockW - width) / 2;
                for (int i = 0; i < width; i++, p++)
                {
                    byte v = c.Diamond[p];
                    int x = bx + start + i, y = by + j;
                    if (v != 0 && x >= 0 && y >= 0 && x < bw && y < bh) buf[y * bw + x] = pal[v].ToArgb();
                }
                width += (j < t.BlockH / 2 - 1 ? 1 : -1) * 4;
            }
            if (c.Extra != null)
                for (int j = 0; j < c.ExtraH; j++) for (int i = 0; i < c.ExtraW; i++)
                {
                    byte v = c.Extra[j * c.ExtraW + i];
                    int x = bx + c.ExtraX - c.X + i, y = by + c.ExtraY - c.Y + j;
                    if (v != 0 && x >= 0 && y >= 0 && x < bw && y < bh) buf[y * bw + x] = pal[v].ToArgb();
                }
        }
    }
}

// ---------------------------------------------------------------- theater: tile index <-> set/file
public class TileSetInfo { public int Index, Start, Count; public string Name, File; public bool Morphable, AllowToPlace = true; }

public class Theater
{
    public List<TileSetInfo> Sets = new List<TileSetInfo>();
    public Dictionary<string, string> General = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    public string Ext;
    MixSet mixes;
    Dictionary<int, Tmp> cache = new Dictionary<int, Tmp>();

    public Theater(string iniPath, string ext, MixSet mixSet)
    {
        Ext = ext; mixes = mixSet;
        string sec = null;
        Dictionary<string, Dictionary<string, string>> ini = new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);
        List<string> order = new List<string>();
        foreach (string raw in File.ReadAllLines(iniPath))
        {
            string l = raw; int sc = l.IndexOf(';'); if (sc >= 0) l = l.Substring(0, sc); l = l.Trim();
            if (l.StartsWith("[") && l.EndsWith("]")) { sec = l.Substring(1, l.Length - 2); if (!ini.ContainsKey(sec)) { ini[sec] = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase); order.Add(sec); } continue; }
            int eq = l.IndexOf('=');
            if (sec != null && eq > 0) ini[sec][l.Substring(0, eq).Trim()] = l.Substring(eq + 1).Trim();
        }
        General = ini["General"];
        int start = 0;
        for (int i = 0; ; i++)
        {
            string name = "TileSet" + i.ToString("D4");
            if (!ini.ContainsKey(name)) break;
            Dictionary<string, string> s = ini[name];
            TileSetInfo t = new TileSetInfo();
            t.Index = i; t.Start = start;
            t.Name = s.ContainsKey("SetName") ? s["SetName"] : "";
            t.File = s.ContainsKey("FileName") ? s["FileName"] : "";
            t.Count = s.ContainsKey("TilesInSet") ? int.Parse(s["TilesInSet"]) : 0;
            t.Morphable = s.ContainsKey("Morphable") && s["Morphable"].ToLower().StartsWith("t");
            t.AllowToPlace = !(s.ContainsKey("AllowToPlace") && s["AllowToPlace"].ToLower().StartsWith("n"));
            Sets.Add(t);
            start += t.Count;
        }
    }

    public int TotalTiles { get { TileSetInfo l = Sets[Sets.Count - 1]; return l.Start + l.Count; } }

    public TileSetInfo SetOf(int tile)
    {
        foreach (TileSetInfo s in Sets) if (tile >= s.Start && tile < s.Start + s.Count) return s;
        return null;
    }

    public TileSetInfo SetByName(string name)
    {
        foreach (TileSetInfo s in Sets) if (string.Equals(s.Name, name, StringComparison.OrdinalIgnoreCase)) return s;
        return null;
    }

    public string FileOf(int tile)
    {
        TileSetInfo s = SetOf(tile);
        if (s == null) return null;
        return s.File + (tile - s.Start + 1).ToString("D2") + "." + Ext;
    }

    public Tmp Get(int tile)
    {
        Tmp t;
        if (cache.TryGetValue(tile, out t)) return t;
        string f = FileOf(tile);
        byte[] b = f == null ? null : mixes.Read(f);
        t = b == null ? null : Tmp.Read(b);
        cache[tile] = t;
        return t;
    }
}
