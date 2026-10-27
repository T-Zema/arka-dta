// Helpers for the Protoss faction (build-scprotoss.ps1). C# 5 for PowerShell Add-Type.
// Add-Type -Path Casc.cs,ModTools.cs,ScBuild.cs,ScBuildings.cs,ScInfantry.cs,ScZerg.cs,ScProtoss.cs -ReferencedAssemblies System.Drawing
using System;
using System.Collections.Generic;
using System.Drawing;

public static class ScProtoss
{
    // One warp-in stage of a building, as a one-frame GRP on the body's canvas (so ScBuildingShape places it like the body).
    // SC fills the building silhouette with the animated warp texture (protoss/texture.grp) and then fades the building in;
    // here a growing share of real body pixels (reveal 0..1, fixed noise order, so the building "solidifies" in place)
    // replaces the texture. Texture holes become a blue glow that follows the body's brightness.
    public static Grp Warp(Grp body, int frame, Grp tex, int texFrame, double reveal, Color[] sc)
    {
        int w = body.Width, h = body.Height;
        byte[] src = ScBuild.ToCanvas(body.Frames[frame], w, h);
        byte[] t = null; int tw = 0, th = 0;
        if (tex != null)
        {
            tw = tex.Width; th = tex.Height;
            t = ScBuild.ToCanvas(tex.Frames[texFrame % tex.Frames.Count], tw, th);
        }
        byte[] glow = GlowRamp(sc);
        Frame f = new Frame(0, 0, w, h);
        int dx = (tw - w) / 2, dy = (th - h) / 2;
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            byte v = src[y * w + x];
            if (v == 0) continue;
            byte o;
            if (Noise(x, y) < reveal) o = v;
            else
            {
                byte tv = 0;
                if (t != null)
                {
                    int tx = ((x + dx) % tw + tw) % tw, ty = ((y + dy) % th + th) % th;
                    tv = t[ty * tw + tx];
                }
                // the SC texture is dark navy in the unit palette (SC draws it with its own warp palette): use its
                // brightness, doubled, on the blue glow ramp; holes follow the body's brightness
                Color c = tv != 0 && (tv < 8 || tv > 15) ? sc[tv] : sc[v];
                int k = tv != 0 ? (c.R + c.G + c.B) / 40 : (c.R + c.G + c.B) / 96;
                o = glow[Math.Min(7, k)];
            }
            f.Pixels[y * w + x] = o;
        }
        Grp g = new Grp(); g.Width = w; g.Height = h; g.Frames.Add(f);
        return g;
    }

    static double Noise(int x, int y)
    {
        uint n = (uint)(x * 374761393 + y * 668265263);
        n = (n ^ (n >> 13)) * 1274126177u;
        return ((n ^ (n >> 16)) & 0xFFFF) / 65536.0;
    }

    // SC glow overlays (pbaGlow ...) store an intensity 1..15 drawn with a glow palette; in the unit palette those low
    // indices are black and player remap. Re-map the intensity onto the blue glow ramp.
    public static Grp Glow(Grp g, Color[] sc)
    {
        byte[] ramp = GlowRamp(sc);
        Grp r = new Grp(); r.Width = g.Width; r.Height = g.Height;
        foreach (Frame f in g.Frames)
        {
            Frame n = new Frame(f.X, f.Y, f.W, f.H);
            for (int i = 0; i < f.Pixels.Length; i++)
            {
                byte v = f.Pixels[i];
                n.Pixels[i] = v == 0 ? (byte)0 : ramp[Math.Min(7, v / 2)];   // >= 16: hottest = brightest
            }
            r.Frames.Add(n);
        }
        return r;
    }

    // Projectiles SC draws with a remapped palette (bullet\epbBul, dragbull: blue energy): the unit palette shows them
    // green/yellow, so every pixel goes onto the blue glow ramp by its brightness.
    public static Grp BlueByLuma(Grp g, Color[] sc)
    {
        byte[] ramp = GlowRamp(sc);
        Grp r = new Grp(); r.Width = g.Width; r.Height = g.Height;
        foreach (Frame f in g.Frames)
        {
            Frame n = new Frame(f.X, f.Y, f.W, f.H);
            for (int i = 0; i < f.Pixels.Length; i++)
            {
                byte v = f.Pixels[i]; if (v == 0) continue;
                Color c = sc[v];
                int lum = Math.Max(c.R, Math.Max(c.G, c.B));
                n.Pixels[i] = ramp[Math.Min(7, lum * 8 / 256)];
            }
            r.Frames.Add(n);
        }
        return r;
    }

    // 8 SC palette indices from dark to bright blue-white (never the player remap 8-15).
    static byte[] GlowRamp(Color[] sc)
    {
        byte[] r = new byte[8];
        for (int i = 0; i < 8; i++)
        {
            Color want = Color.FromArgb(Math.Min(255, 30 + i * 30), Math.Min(255, 90 + i * 24), 255);
            r[i] = Pal.Nearest(want, sc, 16, 254);
        }
        return r;
    }

    // Archon / Dark Archon: SC draws a non-directional energy ball (archon.grp, frames 0..energyLoop-1), the directional
    // being on top (archonT.grp, sets of 17) and a swirl overlay (archonT2.grp). One directional GRP with all three
    // layers per (set, direction), so ScInfantry.Build can treat it like any unit. Energy and swirl advance per set.
    public static Grp Stack(Grp energy, int energyLoop, Grp being, Grp swirl)
    {
        int w = being.Width, h = being.Height, sets = being.Frames.Count / 17;
        Grp r = new Grp(); r.Width = w; r.Height = h;
        for (int s = 0; s < sets; s++) for (int d = 0; d < 17; d++)
        {
            byte[] px = new byte[w * h];
            Over(px, w, h, energy, (s + d) % energyLoop);
            Over(px, w, h, being, s * 17 + d);
            if (swirl != null) Over(px, w, h, swirl, (s * 3 + d) % swirl.Frames.Count);
            Frame f = new Frame(0, 0, w, h); f.Pixels = px;
            r.Frames.Add(f);
        }
        return r;
    }

    static void Over(byte[] px, int w, int h, Grp g, int frame)
    {
        byte[] src = ScBuild.ToCanvas(g.Frames[frame], g.Width, g.Height);
        int dx = (w - g.Width) / 2, dy = (h - g.Height) / 2;
        for (int y = 0; y < g.Height; y++) for (int x = 0; x < g.Width; x++)
        {
            byte v = src[y * g.Width + x];
            int tx = x + dx, ty = y + dy;
            if (v != 0 && tx >= 0 && ty >= 0 && tx < w && ty < h) px[ty * w + tx] = v;
        }
    }

    // Rotating projectile (art Rotates=yes): 32 facings clockwise from north, from one SC set of 17 directions (left side
    // mirrored, ScBuild.ScDir), on the GRP's own canvas, like the turret frames of ScBuildingShape.Turret.
    public static Shp Rotating(Grp g, int set, byte[] map)
    {
        Shp s = new Shp(); s.Width = g.Width; s.Height = g.Height;
        for (int facing = 0; facing < 32; facing++)
        {
            bool mirror;
            int dir = ScBuild.ScDir(facing, out mirror);
            byte[] src = ScBuild.ToCanvas(g.Frames[set * 17 + dir], g.Width, g.Height);
            s.Frames.Add(ScBuild.Place(src, g.Width, g.Height, g.Width, g.Height, 0, 0, mirror, map));
        }
        return s;
    }

    // Same frame count and canvas, nothing drawn: shadow GRP for units that cast none (Archons are pure energy).
    public static Grp Blank(Grp g)
    {
        Grp r = new Grp(); r.Width = g.Width; r.Height = g.Height;
        foreach (Frame f in g.Frames) r.Frames.Add(new Frame(0, 0, 0, 0));
        return r;
    }

    // Frames of another GRP (death remains, another unit's death) moved onto the given canvas, centres aligned.
    public static List<Frame> OnCanvas(Grp g, int[] frames, int cw, int ch)
    {
        List<Frame> r = new List<Frame>();
        int dx = (cw - g.Width) / 2, dy = (ch - g.Height) / 2;
        foreach (int i in frames)
        {
            Frame f = g.Frames[i];
            Frame n = new Frame(f.X + dx, f.Y + dy, f.W, f.H);
            n.Pixels = f.Pixels;
            r.Add(n);
        }
        return r;
    }
}
