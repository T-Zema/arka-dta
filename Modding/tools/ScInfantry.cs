// StarCraft GRP -> DTA (TS) SHP for real INFANTRY (InfantryTypes, built in any barracks). C# 5 for PowerShell Add-Type.
// Needs ModTools.cs (Grp, Shp, Frame) and ScBuild.cs (ToCanvas, Place, BuildMap).
// TS infantry: 8 facings ordered N, NW, W, SW, S, SE, E, NE (counter-clockwise from screen-up, checked on E1.SHP),
// sequences in Art.ini as "Name=start,frames,facingStep", shadows in the second half of the file.
using System;
using System.Collections.Generic;
using System.Text;

public class InfantryLayout
{
    public int Walk, WalkFrames, Fire, FireFrames, Death, DeathFrames, Total;

    // Art.ini sequence section body. Zerg do not go prone: prone/crawl reuse stand/walk.
    public string Sequence()
    {
        StringBuilder sb = new StringBuilder();
        string stand = "0,1,1", walk = Walk + "," + WalkFrames + "," + WalkFrames, fire = Fire + "," + FireFrames + "," + FireFrames;
        string die = Death + "," + DeathFrames + ",0";
        string[] keys = { "Ready", "Guard", "Prone", "Walk", "FireUp", "Down", "Crawl", "Up", "FireProne", "Idle1", "Idle2", "Struggle",
                          "Die1", "Die2", "Die3", "Die4", "Die5" };
        string[] vals = { stand, stand, stand, walk, fire, stand, walk, stand, fire, stand, stand, stand, die, die, die, die, die };
        for (int i = 0; i < keys.Length; i++) sb.Append(keys[i]).Append('=').Append(vals[i]).Append('\n');
        return sb.ToString();
    }
}

public static class ScInfantry
{
    // SC 32-direction index (clockwise from N) for each TS infantry facing
    static readonly int[] Dir32 = { 0, 28, 24, 20, 16, 12, 8, 4 };

    static Frame DirFrame(Grp g, int set, int facing, out bool mirror)
    {
        int d = Dir32[facing];
        mirror = d > 16;
        return g.Frames[set * 17 + (mirror ? 32 - d : d)];
    }

    // body: unit GRP; shadow: matching shadow GRP (may be null); death: non-directional frames (from the unit GRP
    // and/or the *death.grp remains), all on the same canvas size as body.
    public static Shp Build(Grp body, Grp shadow, byte[] map, int standSet, int[] walkSets, int[] fireSets, List<Frame> death, out InfantryLayout lay)
    {
        lay = new InfantryLayout();
        List<Frame> src = new List<Frame>(); List<bool> mir = new List<bool>(); List<Frame> sh = new List<Frame>();
        Action<int, int> add = delegate (int set, int facing)
        {
            bool m;
            src.Add(DirFrame(body, set, facing, out m)); mir.Add(m);
            sh.Add(shadow != null && set * 17 + 16 < shadow.Frames.Count ? DirFrame(shadow, set, facing, out m) : null);
        };
        for (int f = 0; f < 8; f++) add(standSet, f);
        lay.Walk = src.Count; lay.WalkFrames = walkSets.Length;
        for (int f = 0; f < 8; f++) foreach (int s in walkSets) add(s, f);
        lay.Fire = src.Count; lay.FireFrames = fireSets.Length;
        for (int f = 0; f < 8; f++) foreach (int s in fireSets) add(s, f);
        lay.Death = src.Count; lay.DeathFrames = death.Count;
        foreach (Frame d in death) { src.Add(d); mir.Add(false); sh.Add(null); }
        lay.Total = src.Count;

        // tight canvas, centred where the SC canvas is centred (= unit position)
        int cw = body.Width, ch = body.Height, hw = 1, hh = 1;
        List<Frame> all = new List<Frame>(src);
        foreach (Frame f in sh) if (f != null) all.Add(f);
        foreach (Frame f in all)
        {
            if (f.W == 0) continue;
            hw = Math.Max(hw, Math.Max(cw / 2 - f.X, f.X + f.W - cw / 2));
            hh = Math.Max(hh, Math.Max(ch / 2 - f.Y, f.Y + f.H - ch / 2));
        }
        int w = Math.Min(cw, hw * 2 + 2), h = Math.Min(ch, hh * 2 + 2), ox = (w - cw) / 2, oy = (h - ch) / 2;

        Shp shp = new Shp(); shp.Width = w; shp.Height = h;
        for (int i = 0; i < src.Count; i++)
            shp.Frames.Add(ScBuild.Place(ScBuild.ToCanvas(src[i], cw, ch), cw, ch, w, h, ox, oy, mir[i], map));
        for (int i = 0; i < src.Count; i++)
            shp.Frames.Add(sh[i] == null ? new Frame(0, 0, w, h)
                : ScBuild.Place(ScBuild.ToCanvas(sh[i], shadow.Width, shadow.Height), shadow.Width, shadow.Height, w, h,
                                ox + (cw - shadow.Width) / 2, oy + (ch - shadow.Height) / 2, mir[i], null));
        return shp;
    }

    // 64x48 cameo: the sprite cropped to its bounds and scaled (up or down) to fit, on a dark gradient,
    // quantised to the cameo palette. Player colours use the given ramp.
    public static Shp Cameo(Frame f, int cw, int ch, System.Drawing.Color[] sc, System.Drawing.Color[] ramp, System.Drawing.Color[] cameoPal, System.Drawing.Color tint)
    {
        byte[] canvas = ScBuild.ToCanvas(f, cw, ch);
        int minX = cw, minY = ch, maxX = 0, maxY = 0;
        for (int y = 0; y < ch; y++) for (int x = 0; x < cw; x++)
            if (canvas[y * cw + x] != 0) { minX = Math.Min(minX, x); maxX = Math.Max(maxX, x); minY = Math.Min(minY, y); maxY = Math.Max(maxY, y); }
        int sw = maxX - minX + 1, sh = maxY - minY + 1;
        using (System.Drawing.Bitmap spr = new System.Drawing.Bitmap(sw, sh))
        using (System.Drawing.Bitmap bmp = new System.Drawing.Bitmap(64, 48))
        {
            for (int y = 0; y < sh; y++) for (int x = 0; x < sw; x++)
            {
                byte v = canvas[(minY + y) * cw + minX + x];
                if (v != 0) spr.SetPixel(x, y, v >= 8 && v <= 15 ? ramp[v - 8] : sc[v]);
            }
            for (int y = 0; y < 48; y++) for (int x = 0; x < 64; x++)
            {
                double r = Math.Sqrt((x - 32) * (x - 32) + (y - 22) * (y - 22)) / 40.0, k = Math.Max(0, 1 - r);
                bmp.SetPixel(x, y, System.Drawing.Color.FromArgb((int)(12 + tint.R * k * 0.5), (int)(12 + tint.G * k * 0.5), (int)(12 + tint.B * k * 0.5)));
            }
            double s = Math.Min(60.0 / sw, 44.0 / sh);
            int dw = (int)(sw * s), dh = (int)(sh * s);
            using (System.Drawing.Graphics g = System.Drawing.Graphics.FromImage(bmp))
            {
                g.InterpolationMode = s >= 1.5 ? System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor : System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
                g.DrawImage(spr, (64 - dw) / 2, (48 - dh) / 2, dw, dh);
                using (System.Drawing.Pen p = new System.Drawing.Pen(System.Drawing.Color.FromArgb(140, 60, 120), 1)) g.DrawRectangle(p, 0, 0, 63, 47);
            }
            Frame cf = new Frame(0, 0, 64, 48);
            for (int y = 0; y < 48; y++) for (int x = 0; x < 64; x++) cf.Pixels[y * 64 + x] = Pal.Nearest(bmp.GetPixel(x, y), cameoPal, 1, 255);
            Shp shp = new Shp(); shp.Width = 64; shp.Height = 48; shp.Frames.Add(cf);
            return shp;
        }
    }
}
