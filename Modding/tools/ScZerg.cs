// Helpers for the Zerg faction (build-sczergbase.ps1). C# 5 for PowerShell Add-Type.
// Add-Type -Path Casc.cs,ModTools.cs,ScBuild.cs,ScBuildings.cs,ScInfantry.cs,ScZerg.cs -ReferencedAssemblies System.Drawing
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;

public static class ScZerg
{
    // Same frames on a smaller canvas, centred (SC unit GRPs are 128x128 with a lot of empty border).
    public static Grp Crop(Grp g, int w, int h)
    {
        Grp r = new Grp(); r.Width = w; r.Height = h;
        int dx = (g.Width - w) / 2, dy = (g.Height - h) / 2;
        foreach (Frame f in g.Frames)
        {
            Frame n = new Frame(f.X - dx, f.Y - dy, f.W, f.H);
            n.Pixels = f.Pixels;
            r.Frames.Add(n);
        }
        return r;
    }

    // Shadow silhouette = the body moved down by dy pixels (SC draws the Drone's shadow from its own sprite).
    public static Grp Shifted(Grp g, int dy)
    {
        Grp r = new Grp(); r.Width = g.Width; r.Height = g.Height;
        foreach (Frame f in g.Frames)
        {
            Frame n = new Frame(f.X, f.Y + dy, f.W, f.H);
            n.Pixels = f.Pixels;
            r.Frames.Add(n);
        }
        return r;
    }

    // Smallest centred canvas that holds every frame of the given GRP (even sizes).
    public static int[] Bounds(Grp g)
    {
        int cx = g.Width / 2, cy = g.Height / 2, hw = 0, hh = 0;
        foreach (Frame f in g.Frames)
        {
            if (f.W == 0 || f.H == 0) continue;
            hw = Math.Max(hw, Math.Max(cx - f.X, f.X + f.W - cx));
            hh = Math.Max(hh, Math.Max(cy - f.Y, f.Y + f.H - cy));
        }
        return new int[] { Math.Min(g.Width, 2 * hw + 2), Math.Min(g.Height, 2 * hh + 2) };
    }

    // Shp.Write with shared data: identical frames (after trimming) point at the same RLE data, so a long buildup made of
    // repeated cocoon frames stays small. TS keeps the SHP in memory and decodes each frame through its own offset.
    public static byte[] WriteShared(Shp s)
    {
        System.IO.MemoryStream ms = new System.IO.MemoryStream();
        System.IO.BinaryWriter w = new System.IO.BinaryWriter(ms);
        w.Write((ushort)0); w.Write((ushort)s.Width); w.Write((ushort)s.Height); w.Write((ushort)s.Frames.Count);
        long headerStart = ms.Position;
        for (int i = 0; i < s.Frames.Count; i++) w.Write(new byte[24]);
        Dictionary<string, long> seen = new Dictionary<string, long>();
        Dictionary<Frame, Frame> trimCache = new Dictionary<Frame, Frame>();   // reference keys: repeated Frame objects are trimmed once
        Dictionary<Frame, long> refSeen = new Dictionary<Frame, long>();
        List<Frame> trimmed = new List<Frame>();
        List<long> offsets = new List<long>();
        foreach (Frame f in s.Frames)
        {
            Frame t;
            if (!trimCache.TryGetValue(f, out t)) { t = Trim(f); trimCache[f] = t; }
            trimmed.Add(t);
            if (t.W == 0 || t.H == 0) { offsets.Add(0); continue; }
            long at;
            if (refSeen.TryGetValue(f, out at)) { offsets.Add(at); continue; }
            string key = t.X + "," + t.Y + "," + t.W + "," + t.H + ":" + Convert.ToBase64String(t.Pixels);
            if (seen.TryGetValue(key, out at)) { refSeen[f] = at; offsets.Add(at); continue; }
            at = ms.Position; seen[key] = at; refSeen[f] = at; offsets.Add(at);
            for (int row = 0; row < t.H; row++)
            {
                System.IO.MemoryStream line = new System.IO.MemoryStream();
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

    // Buildup from a schedule: every distinct stage is composed ONCE and then referenced (keyIndex[j] shown repeat[j] ticks),
    // so a 4500-frame morph costs a few dozen frames of memory. Shadows in the second half, like ScBuildingShape.Buildup.
    public static Shp BuildupCached(ScBuildingShape shape, List<List<ScLayer>> bodies, List<List<ScLayer>> shadows, int[] keyIndex, int[] repeat, byte[] map)
    {
        Frame[] b = new Frame[bodies.Count], d = new Frame[bodies.Count];
        for (int i = 0; i < bodies.Count; i++) { b[i] = shape.Compose(bodies[i], map, null, 0); d[i] = shape.Compose(shadows[i], map, null, 0); }
        Shp s = new Shp(); s.Width = shape.Cw; s.Height = shape.Ch;
        List<Frame> sh = new List<Frame>();
        for (int j = 0; j < keyIndex.Length; j++) for (int k = 0; k < repeat[j]; k++) { s.Frames.Add(b[keyIndex[j]]); sh.Add(d[keyIndex[j]]); }
        s.Frames.AddRange(sh);
        return s;
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

    // Green acid frame (unit palette indices): SC draws some bullets through a remap table, so in the plain palette they come out
    // orange (Guardian acid spore = thingy\ep3Shot). Every pixel gets an acid-green colour by its brightness; scale = nearest-neighbour zoom.
    public static Frame AcidGreen(Grp g, int frame, int scale, Color[] sc, Color[] ts)
    {
        int w = g.Width * scale, h = g.Height * scale;
        byte[] src = ScBuild.ToCanvas(g.Frames[frame], g.Width, g.Height);
        Frame f = new Frame(0, 0, w, h);
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            byte v = src[(y / scale) * g.Width + x / scale];
            if (v == 0) continue;
            Color c = sc[v];
            double l = 0.3 * c.R + 0.59 * c.G + 0.11 * c.B;
            Color a = Color.FromArgb((int)Math.Min(255, l * 0.55), (int)Math.Min(255, 40 + l * 0.95), (int)Math.Min(255, l * 0.2));
            f.Pixels[y * w + x] = Pal.Nearest(a, ts, 32, 254);
        }
        return f;
    }

    // Cameo of a "Drone -> building" unit: the building cameo with a small Drone in the lower left corner.
    public static Shp DroneCameo(List<ScLayer> building, Grp drone, int droneFrame, Color[] sc, Color[] ramp, Color[] cameoPal)
    {
        Shp shp = ScBuildings.Cameo(building, sc, ramp, cameoPal);
        Frame cf = shp.Frames[0];

        Frame df = drone.Frames[droneFrame];
        Bitmap src = new Bitmap(df.W, df.H, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        for (int y = 0; y < df.H; y++) for (int x = 0; x < df.W; x++)
        {
            byte v = df.Pixels[y * df.W + x];
            if (v == 0) continue;
            Color c = (v >= 8 && v <= 15) ? ramp[v - 8] : sc[v];
            src.SetPixel(x, y, Color.FromArgb(255, c.R, c.G, c.B));
        }
        float scale = Math.Min(26f / df.W, 22f / df.H);
        int w = Math.Max(1, (int)(df.W * scale)), h = Math.Max(1, (int)(df.H * scale));
        Bitmap small = new Bitmap(w, h, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(small))
        {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(src, new Rectangle(0, 0, w, h), new Rectangle(0, 0, df.W, df.H), GraphicsUnit.Pixel);
        }
        src.Dispose();

        int ox = 2, oy = 48 - h - 2;
        byte black = Pal.Nearest(Color.FromArgb(8, 8, 8), cameoPal, 1, 255);
        bool[,] solid = new bool[w, h];
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) solid[x, y] = small.GetPixel(x, y).A >= 110;
        // 1 px dark outline first, so the Drone reads well over the building
        for (int y = -1; y <= h; y++) for (int x = -1; x <= w; x++)
        {
            if (x >= 0 && y >= 0 && x < w && y < h && solid[x, y]) continue;
            bool near = false;
            for (int k = -1; k <= 1 && !near; k++) for (int l = -1; l <= 1 && !near; l++)
            {
                int a = x + k, b = y + l;
                if (a >= 0 && b >= 0 && a < w && b < h && solid[a, b]) near = true;
            }
            int px = ox + x, py = oy + y;
            if (near && px >= 1 && py >= 1 && px < 63 && py < 47) cf.Pixels[py * 64 + px] = black;
        }
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            if (!solid[x, y]) continue;
            Color c = small.GetPixel(x, y);
            int px = ox + x, py = oy + y;
            if (px >= 1 && py >= 1 && px < 63 && py < 47) cf.Pixels[py * 64 + px] = Pal.Nearest(Color.FromArgb(c.R, c.G, c.B), cameoPal, 1, 255);
        }
        small.Dispose();
        return shp;
    }
}
