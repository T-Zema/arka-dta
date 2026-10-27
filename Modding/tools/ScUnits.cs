// Generic StarCraft unit -> DTA (TS) SHP frame composer. C# 5 for PowerShell Add-Type.
// Add-Type -Path Casc.cs,ModTools.cs,ScBuild.cs,ScBuildings.cs,ScUnits.cs -ReferencedAssemblies System.Drawing
// Every frame is a full canvas (Cw x Ch) with the unit at the canvas centre; Shp.Write() trims it.
// Shadows go to the second half of the file in the same order as the body frames (DTA convention).
using System;
using System.Collections.Generic;
using System.Drawing;

public class UnitBuilder
{
    public int Cw, Ch;
    public byte[] Map;
    public List<Frame> Frames = new List<Frame>();
    public List<Frame> Shadows = new List<Frame>();

    public UnitBuilder(int cw, int ch, byte[] map) { Cw = cw; Ch = ch; Map = map; }

    public Frame New() { return new Frame(0, 0, Cw, Ch); }

    // SC frame index for a DTA facing (0..31, clockwise from north): set * 17 + direction, west side mirrored.
    // directional=false: `set` is an absolute frame index and nothing is mirrored (non-rotating parts).
    static int Index(int set, int facing, bool directional, out bool mirror)
    {
        mirror = false;
        if (!directional) return set;
        int dir = ScBuild.ScDir(facing, out mirror);
        return set * 17 + dir;
    }

    // Draws one GRP frame centred on the canvas, shifted by (dx, dy) plus the .lo? offset of that frame.
    // shadow=true writes palette index 1 (TS shadow) for every opaque pixel.
    public Frame Layer(Frame dst, Grp g, int set, int facing, bool directional, int[][] lo, int dx, int dy, bool shadow)
    {
        if (g == null) return dst;
        bool mirror;
        int idx = Index(set, facing, directional, out mirror);
        if (idx < 0 || idx >= g.Frames.Count) return dst;
        int ox = dx, oy = dy;
        if (lo != null && idx < lo.Length) { ox += lo[idx][0]; oy += lo[idx][1]; }
        if (mirror) ox = -ox;
        byte[] src = ScBuild.ToCanvas(g.Frames[idx], g.Width, g.Height);
        Frame p = ScBuild.Place(src, g.Width, g.Height, Cw, Ch, (Cw - g.Width) / 2 + ox, (Ch - g.Height) / 2 + oy, mirror, shadow ? null : Map);
        for (int i = 0; i < dst.Pixels.Length; i++) if (p.Pixels[i] != 0) dst.Pixels[i] = p.Pixels[i];
        return dst;
    }

    // Same as Layer, for GRPs that are not "set * 17 + direction": the caller gives the frame index and the mirror flag
    // (e.g. stankt.grp = direction * 6 + deploy phase).
    public Frame LayerAt(Frame dst, Grp g, int idx, bool mirror, int dx, int dy, bool shadow)
    {
        if (g == null || idx < 0 || idx >= g.Frames.Count) return dst;
        int ox = mirror ? -dx : dx;
        byte[] src = ScBuild.ToCanvas(g.Frames[idx], g.Width, g.Height);
        Frame p = ScBuild.Place(src, g.Width, g.Height, Cw, Ch, (Cw - g.Width) / 2 + ox, (Ch - g.Height) / 2 + dy, mirror, shadow ? null : Map);
        for (int i = 0; i < dst.Pixels.Length; i++) if (p.Pixels[i] != 0) dst.Pixels[i] = p.Pixels[i];
        return dst;
    }

    // Shadow from the body silhouette (SC air units have no shadow GRP; SC draws them offset below the unit).
    public Frame Silhouette(Frame body, int dx, int dy)
    {
        Frame s = New();
        for (int y = 0; y < Ch; y++) for (int x = 0; x < Cw; x++)
        {
            if (body.Pixels[y * Cw + x] == 0) continue;
            int tx = x + dx, ty = y + dy;
            if (tx >= 0 && ty >= 0 && tx < Cw && ty < Ch) s.Pixels[ty * Cw + tx] = 1;
        }
        return s;
    }

    public void Add(Frame body, Frame shadow) { Frames.Add(body); Shadows.Add(shadow ?? New()); }

    public Shp ToShp()
    {
        Shp s = new Shp(); s.Width = Cw; s.Height = Ch;
        s.Frames.AddRange(Frames);
        s.Frames.AddRange(Shadows);
        return s;
    }
}

public static class ScUnits
{
    // Average .lol mount offset: centre (c) and radius of the turret circle around it, for TurretOffset estimates.
    public static int[] LoCentre(int[][] lo, int count)
    {
        long sx = 0, sy = 0;
        int n = Math.Min(count, lo.Length);
        for (int i = 0; i < n; i++) { sx += lo[i][0]; sy += lo[i][1]; }
        return new int[] { (int)(sx / Math.Max(1, n)), (int)(sy / Math.Max(1, n)) };
    }

    // SC -> TS colour map with a colour multiplier (e.g. gold hero: 1.25, 1.1, 0.55); player colour keeps the TS remap ramp.
    public static byte[] TintMap(Color[] sc, Color[] ts, Color[] playerRamp, double r, double g, double b)
    {
        byte[] map = ScBuild.BuildMap(sc, ts, playerRamp, true, 0);
        for (int i = 1; i < 256; i++)
        {
            if (i >= 8 && i <= 15) continue;
            Color c = sc[i];
            Color k = Color.FromArgb(Math.Min(255, (int)(c.R * r)), Math.Min(255, (int)(c.G * g)), Math.Min(255, (int)(c.B * b)));
            map[i] = Pal.Nearest(k, ts, 32, 254);
        }
        return map;
    }

    public static Color[] TintPalette(Color[] sc, double r, double g, double b)
    {
        Color[] o = new Color[256];
        for (int i = 0; i < 256; i++) o[i] = Color.FromArgb(Math.Min(255, (int)(sc[i].R * r)), Math.Min(255, (int)(sc[i].G * g)), Math.Min(255, (int)(sc[i].B * b)));
        return o;
    }

    // TS infantry SHP facing i (0..7) is counter-clockwise from north (N, NW, W, SW, S, SE, E, NE; checked on E1 FireUp);
    // returns the matching 32-step vehicle facing (clockwise from north) for ScBuild.ScDir.
    public static int InfantryFacing32(int i) { return (32 - 4 * i) % 32; }

    // Wraps a canvas frame (SC palette indices) as a Grp so ScBuildings.Cameo can read it.
    public static Grp AsGrp(Frame f, int w, int h) { return ScVehicle.AsGrp(f, w, h); }
}
