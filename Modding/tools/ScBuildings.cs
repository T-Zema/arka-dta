// StarCraft GRP -> DTA (TS) SHP conversion for buildings. C# 5 for PowerShell Add-Type.
// Add-Type -Path Casc.cs,ModTools.cs,ScBuild.cs,ScBuildings.cs -ReferencedAssemblies System.Drawing
// Placement rule (measured on DTA's BIB43/WEAP/RAPOWR): the SHP canvas centre is the TOP vertex of the foundation
// diamond; a WxH foundation spans x -H*24..+W*24 and y 0..(W+H)*12 from it. The SC sprite centre (= SC footprint
// centre) goes to the diamond centre ((W-H)*12, (W+H)*6). Sprites are not rescaled: SC 32 px tiles ~ DTA cells.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;

public class ScLayer
{
    public Grp G; public int Frame; public bool Shadow;
    public ScLayer(Grp g, int frame, bool shadow) { G = g; Frame = frame; Shadow = shadow; }
}

public class ScBuildingShape
{
    public int Fw, Fh, Cw, Ch, Dx, Dy;

    public ScBuildingShape(int fw, int fh, int maxSw, int maxSh, int yAdjust)
    {
        Fw = fw; Fh = fh;
        Dx = (fw - fh) * 12; Dy = (fw + fh) * 6 + yAdjust;
        Cw = maxSw + 2 * Math.Abs(Dx); Ch = maxSh + 2 * Math.Abs(Dy);
        Cw += Cw & 1; Ch += Ch & 1;
    }

    // Draws layers (bottom first) into one full-canvas frame. Shadow layers write index 1.
    public Frame Compose(List<ScLayer> layers, byte[] map, byte[] dmgMap, int dmgSeed)
    {
        Frame f = new Frame(0, 0, Cw, Ch);
        foreach (ScLayer l in layers)
        {
            if (l.G == null || l.Frame < 0 || l.Frame >= l.G.Frames.Count) continue;
            byte[] src = ScBuild.ToCanvas(l.G.Frames[l.Frame], l.G.Width, l.G.Height);
            int ox = Cw / 2 + Dx - l.G.Width / 2, oy = Ch / 2 + Dy - l.G.Height / 2;
            for (int y = 0; y < l.G.Height; y++) for (int x = 0; x < l.G.Width; x++)
            {
                byte v = src[y * l.G.Width + x];
                if (v == 0) continue;
                int tx = x + ox, ty = y + oy;
                if (tx < 0 || ty < 0 || tx >= Cw || ty >= Ch) continue;
                byte o;
                if (l.Shadow) o = 1;
                else if (dmgMap != null && Scorch(x, y, dmgSeed)) o = dmgMap[v];
                else o = map[v];
                f.Pixels[ty * Cw + tx] = o;
            }
        }
        return f;
    }

    // Low-frequency blotches so the damaged frame looks burnt in patches, not noisy.
    static bool Scorch(int x, int y, int seed)
    {
        double n = Math.Sin(x * 0.21 + seed) * Math.Cos(y * 0.27 - seed * 0.7) + Math.Sin((x + y) * 0.13 + seed * 1.3) * 0.6;
        return n > 0.35;
    }

    // TS building: normal, damaged, then the same two as shadows.
    public Shp Building(List<ScLayer> body, List<ScLayer> shadow, byte[] map, byte[] dmgMap)
    {
        Shp s = new Shp(); s.Width = Cw; s.Height = Ch;
        s.Frames.Add(Compose(body, map, null, 0));
        s.Frames.Add(Compose(body, map, dmgMap, 3));
        Frame sh = Compose(shadow, map, null, 0);
        s.Frames.Add(sh); s.Frames.Add(sh);
        return s;
    }

    // Buildup: stages[i] (body layers) shown repeat[i] times, shadows in the second half.
    public Shp Buildup(List<List<ScLayer>> stages, List<List<ScLayer>> shadows, int[] repeat, byte[] map)
    {
        Shp s = new Shp(); s.Width = Cw; s.Height = Ch;
        List<Frame> sh = new List<Frame>();
        for (int i = 0; i < stages.Count; i++)
        {
            Frame b = Compose(stages[i], map, null, 0), d = Compose(shadows[i], map, null, 0);
            for (int k = 0; k < repeat[i]; k++) { s.Frames.Add(b); sh.Add(d); }
        }
        s.Frames.AddRange(sh);
        return s;
    }

    // Turret anim (TurretAnim=): 32 facings clockwise from north, then 32 empty shadow frames.
    public Shp Turret(Grp head, int firstFrame, byte[] map)
    {
        Shp s = new Shp(); s.Width = Cw; s.Height = Ch;
        for (int facing = 0; facing < 32; facing++)
        {
            bool mirror;
            int dir = ScBuild.ScDir(facing, out mirror);
            byte[] src = ScBuild.ToCanvas(head.Frames[firstFrame + dir], head.Width, head.Height);
            int ox = Cw / 2 + Dx - head.Width / 2, oy = Ch / 2 + Dy - head.Height / 2;
            s.Frames.Add(ScBuild.Place(src, head.Width, head.Height, Cw, Ch, ox, oy, mirror, map));
        }
        for (int i = 0; i < 32; i++) s.Frames.Add(new Frame(0, 0, Cw, Ch));
        return s;
    }
}

// SHP vehicle from an SC body + turret overlay (turret baked in, always facing forward), e.g. the Siege Tank.
public static class ScVehicle
{
    // SC .lo? file: int32 frames, int32 overlays, int32 offset per frame -> overlays x (sbyte x, sbyte y).
    public static int[][] ReadLo(byte[] d)
    {
        int n = BitConverter.ToInt32(d, 0);
        int[][] r = new int[n][];
        for (int i = 0; i < n; i++)
        {
            int p = BitConverter.ToInt32(d, 8 + 4 * i);
            r[i] = new int[] { (sbyte)d[p], (sbyte)d[p + 1] };
        }
        return r;
    }

    static void Merge(Frame dst, Frame src)
    {
        for (int i = 0; i < dst.Pixels.Length; i++) if (src.Pixels[i] != 0) dst.Pixels[i] = src.Pixels[i];
    }

    // One full-canvas frame: body set `set`, SC direction for DTA `facing`; turret placed by the .lol offset of that body frame.
    public static Frame Compose(Grp body, Grp turret, int[][] lo, int set, int facing, byte[] map)
    {
        bool mirror;
        int dir = ScBuild.ScDir(facing, out mirror);
        int idx = set * 17 + dir, cw = body.Width, ch = body.Height;
        Frame f = ScBuild.Place(ScBuild.ToCanvas(body.Frames[idx], cw, ch), cw, ch, cw, ch, 0, 0, mirror, map);
        if (turret != null)
        {
            int ox = lo == null ? 0 : lo[idx][0], oy = lo == null ? 0 : lo[idx][1];
            if (mirror) ox = -ox;
            Merge(f, ScBuild.Place(ScBuild.ToCanvas(turret.Frames[dir], turret.Width, turret.Height), turret.Width, turret.Height,
                                   cw, ch, ox + (cw - turret.Width) / 2, oy + (ch - turret.Height) / 2, mirror, map));
        }
        return f;
    }

    // 32 stand frames (set 0), then walkSets frames per facing (sets 0..walkSets-1), then all shadows.
    public static Shp Build(Grp body, Grp turret, int[][] lo, Grp shadow, byte[] map, int walkSets)
    {
        Shp s = new Shp(); s.Width = body.Width; s.Height = body.Height;
        List<int[]> plan = new List<int[]>();
        for (int f = 0; f < 32; f++) plan.Add(new int[] { 0, f });
        for (int f = 0; f < 32; f++) for (int k = 0; k < walkSets; k++) plan.Add(new int[] { k, f });
        List<Frame> shadows = new List<Frame>();
        foreach (int[] p in plan)
        {
            s.Frames.Add(Compose(body, turret, lo, p[0], p[1], map));
            bool mirror;
            int idx = p[0] * 17 + ScBuild.ScDir(p[1], out mirror);
            shadows.Add(ScBuild.Place(ScBuild.ToCanvas(shadow.Frames[idx], shadow.Width, shadow.Height), shadow.Width, shadow.Height,
                                      s.Width, s.Height, (s.Width - shadow.Width) / 2, (s.Height - shadow.Height) / 2, mirror, null));
        }
        s.Frames.AddRange(shadows);
        return s;
    }

    // SC-index frame wrapped as a one-frame Grp, for ScBuildings.Cameo.
    public static Grp AsGrp(Frame f, int w, int h)
    {
        Grp g = new Grp(); g.Width = w; g.Height = h; g.Frames.Add(f);
        return g;
    }

    public static byte[] Identity()
    {
        byte[] m = new byte[256];
        for (int i = 0; i < 256; i++) m[i] = (byte)i;
        return m;
    }
}

public static class ScBuildings
{
    // Damaged palette: same colours darkened and slightly reddened; remap ramp shifted 4 steps darker.
    public static byte[] DamageMap(byte[] map, Color[] ts)
    {
        byte[] d = new byte[256];
        for (int i = 1; i < 256; i++)
        {
            byte v = map[i];
            if (v >= 16 && v <= 31) { d[i] = (byte)Math.Min(31, v + 4); continue; }
            Color c = ts[v];
            Color k = Color.FromArgb((int)(c.R * 0.55 + 12), (int)(c.G * 0.45), (int)(c.B * 0.4));
            d[i] = Pal.Nearest(k, ts, 32, 254);
        }
        return d;
    }

    // 64x48 cameo: building frame downscaled into a dark blue gradient, mapped to the cameo palette.
    public static Shp Cameo(List<ScLayer> layers, Color[] sc, Color[] playerRamp, Color[] cameoPal)
    {
        int W = 0, H = 0;
        foreach (ScLayer l in layers) { W = Math.Max(W, l.G.Width); H = Math.Max(H, l.G.Height); }
        Bitmap full = new Bitmap(W, H, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        int minX = W, minY = H, maxX = -1, maxY = -1;
        foreach (ScLayer l in layers)
        {
            if (l.Shadow) continue;
            byte[] src = ScBuild.ToCanvas(l.G.Frames[l.Frame], l.G.Width, l.G.Height);
            int ox = (W - l.G.Width) / 2, oy = (H - l.G.Height) / 2;
            for (int y = 0; y < l.G.Height; y++) for (int x = 0; x < l.G.Width; x++)
            {
                byte v = src[y * l.G.Width + x];
                if (v == 0) continue;
                Color c = (v >= 8 && v <= 15) ? playerRamp[v - 8] : sc[v];
                int px = x + ox, py = y + oy;
                full.SetPixel(px, py, Color.FromArgb(255, c.R, c.G, c.B));
                minX = Math.Min(minX, px); maxX = Math.Max(maxX, px); minY = Math.Min(minY, py); maxY = Math.Max(maxY, py);
            }
        }
        Bitmap bmp = new Bitmap(64, 48);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            for (int y = 0; y < 48; y++) for (int x = 0; x < 64; x++)
            {
                double t = y / 47.0, r = Math.Sqrt((x - 32) * (x - 32) + (y - 22) * (y - 22)) / 40.0;
                int v = (int)(18 + 40 * (1 - r) * (1 - t * 0.5));
                bmp.SetPixel(x, y, Color.FromArgb(Math.Max(0, v / 2), Math.Max(0, v), Math.Max(0, (int)(v * 1.5))));
            }
            int bw = maxX - minX + 1, bh = maxY - minY + 1;
            float scale = Math.Min(60f / bw, 44f / bh);
            if (scale > 1.5f) scale = 1.5f;
            int dw = (int)(bw * scale), dh = (int)(bh * scale);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(full, new Rectangle((64 - dw) / 2, (48 - dh) / 2 + 1, dw, dh), new Rectangle(minX, minY, bw, bh), GraphicsUnit.Pixel);
        }
        full.Dispose();
        for (int x = 0; x < 64; x++) { bmp.SetPixel(x, 0, Color.FromArgb(90, 110, 140)); bmp.SetPixel(x, 47, Color.FromArgb(20, 25, 35)); }
        for (int y = 0; y < 48; y++) { bmp.SetPixel(0, y, Color.FromArgb(90, 110, 140)); bmp.SetPixel(63, y, Color.FromArgb(20, 25, 35)); }
        Frame cf = new Frame(0, 0, 64, 48);
        for (int y = 0; y < 48; y++) for (int x = 0; x < 64; x++) cf.Pixels[y * 64 + x] = Pal.Nearest(bmp.GetPixel(x, y), cameoPal, 1, 255);
        bmp.Dispose();
        Shp shp = new Shp(); shp.Width = 64; shp.Height = 48; shp.Frames.Add(cf);
        return shp;
    }

    // Preview: frame drawn over its foundation grid (yellow) on a dark green ground.
    public static void FitPreview(Shp s, int frame, int shadowFrame, ScBuildingShape shape, Color[] pal, int scale, string outPng)
    {
        Bitmap bmp = new Bitmap(s.Width * scale, s.Height * scale);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.FromArgb(40, 60, 40));
            int ox = s.Width / 2, oy = s.Height / 2;
            using (Pen p = new Pen(Color.Yellow, 1))
            {
                for (int i = 0; i <= shape.Fw; i++) g.DrawLine(p, (ox + i * 24) * scale, (oy + i * 12) * scale, (ox + i * 24 - shape.Fh * 24) * scale, (oy + i * 12 + shape.Fh * 12) * scale);
                for (int j = 0; j <= shape.Fh; j++) g.DrawLine(p, (ox - j * 24) * scale, (oy + j * 12) * scale, (ox - j * 24 + shape.Fw * 24) * scale, (oy + j * 12 + shape.Fw * 12) * scale);
            }
            foreach (int fi in new int[] { shadowFrame, frame })
            {
                if (fi < 0) continue;
                Frame f = s.Frames[fi];
                for (int y = 0; y < f.H; y++) for (int x = 0; x < f.W; x++)
                {
                    byte v = f.Pixels[y * f.W + x];
                    if (v == 0) continue;
                    Color c = fi == shadowFrame ? Color.FromArgb(120, 0, 0, 0) : pal[v];
                    using (SolidBrush b = new SolidBrush(c)) g.FillRectangle(b, (f.X + x) * scale, (f.Y + y) * scale, scale, scale);
                }
            }
        }
        bmp.Save(outPng, System.Drawing.Imaging.ImageFormat.Png);
        bmp.Dispose();
    }
}
