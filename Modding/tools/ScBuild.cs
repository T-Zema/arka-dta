// StarCraft GRP -> DTA (TS) SHP conversion for unit-type sprites. C# 5 for PowerShell Add-Type.
// Layout produced for a SHP *vehicle* (UnitType) with Facings=32, frames ordered facing-major, clockwise from
// screen-north (DTA convention, see Modding/wiki/engine/shp-graphics.md), shadows in the second half of the file.
using System;
using System.Collections.Generic;
using System.Drawing;

public static class ScBuild
{
    // SC GRP frame index for a 32-facing DTA facing: SC stores 17 directions N..S clockwise, west side mirrored.
    public static int ScDir(int facing, out bool mirror)
    {
        mirror = facing > 16;
        return mirror ? 32 - facing : facing;
    }

    public static byte[] ToCanvas(Frame f, int cw, int ch)
    {
        byte[] px = new byte[cw * ch];
        for (int y = 0; y < f.H; y++) for (int x = 0; x < f.W; x++)
        {
            int cx = f.X + x, cy = f.Y + y;
            if (cx < 0 || cy < 0 || cx >= cw || cy >= ch) continue;
            byte v = f.Pixels[y * f.W + x];
            if (v != 0) px[cy * cw + cx] = v;
        }
        return px;
    }

    // Places a canvas (with optional mirror, offset and colour map) into a new full-size frame.
    public static Frame Place(byte[] src, int sw, int sh, int dw, int dh, int ox, int oy, bool mirror, byte[] map)
    {
        Frame f = new Frame(0, 0, dw, dh);
        for (int y = 0; y < sh; y++) for (int x = 0; x < sw; x++)
        {
            byte v = src[y * sw + x];
            if (v == 0) continue;
            int tx = (mirror ? sw - 1 - x : x) + ox, ty = y + oy;
            if (tx < 0 || ty < 0 || tx >= dw || ty >= dh) continue;
            f.Pixels[ty * dw + tx] = map == null ? (byte)1 : map[v];
        }
        return f;
    }

    // SC palette index -> TS unit palette index. Player colour 8..15 goes to the TS remap ramp 16..31.
    public static byte[] BuildMap(Color[] sc, Color[] ts, Color[] playerRamp, bool remap, float redTint)
    {
        byte[] map = new byte[256];
        for (int i = 1; i < 256; i++)
        {
            Color c = sc[i];
            if (i >= 8 && i <= 15)
            {
                Color p = playerRamp[i - 8];
                if (remap)
                {
                    int lum = Math.Max(p.R, Math.Max(p.G, p.B));
                    int idx = 16 + (int)Math.Round((246 - lum) / 16.0);
                    map[i] = (byte)Math.Max(16, Math.Min(31, idx));
                    continue;
                }
                c = p;
            }
            if (redTint > 0)
            {
                int r = (int)Math.Min(255, c.R * (1 + redTint) + 25 * redTint);
                int g = (int)(c.G * (1 - redTint * 0.6f));
                int b = (int)(c.B * (1 - redTint * 0.6f));
                c = Color.FromArgb(r, g, b);
            }
            map[i] = Pal.Nearest(c, ts, 32, 254);
        }
        return map;
    }

    // Builds the unit SHP: stand (1), walk (walkFrames), fire (2: index0 = muzzle flash, index1 = aim) per facing.
    public static Shp BuildUnit(Grp body, Grp shadow, byte[] map, int[] walkSets, int aimSet, int flashSet)
    {
        int cw = body.Width, ch = body.Height;
        List<int[]> plan = new List<int[]>(); // [scFrameBaseSet, facing]
        for (int f = 0; f < 32; f++) plan.Add(new int[] { 0, f });
        for (int f = 0; f < 32; f++) foreach (int s in walkSets) plan.Add(new int[] { s, f });
        for (int f = 0; f < 32; f++) { plan.Add(new int[] { flashSet, f }); plan.Add(new int[] { aimSet, f }); }

        Shp shp = new Shp(); shp.Width = cw; shp.Height = ch;
        List<Frame> shadows = new List<Frame>();
        foreach (int[] p in plan)
        {
            bool mirror;
            int dir = ScDir(p[1], out mirror);
            int idx = p[0] * 17 + dir;
            shp.Frames.Add(Place(ToCanvas(body.Frames[idx], cw, ch), cw, ch, cw, ch, 0, 0, mirror, map));
            Frame sf = new Frame(0, 0, cw, ch);
            if (shadow != null && idx < shadow.Frames.Count)
                sf = Place(ToCanvas(shadow.Frames[idx], shadow.Width, shadow.Height), shadow.Width, shadow.Height, cw, ch,
                           (cw - shadow.Width) / 2, (ch - shadow.Height) / 2, mirror, null);
            shadows.Add(sf);
        }
        shp.Frames.AddRange(shadows);
        return shp;
    }

    public static Shp BuildAnim(List<Frame> frames, int cw, int ch, byte[] map)
    {
        Shp shp = new Shp(); shp.Width = cw; shp.Height = ch;
        foreach (Frame f in frames) shp.Frames.Add(Place(ToCanvas(f, cw, ch), cw, ch, cw, ch, 0, 0, false, map));
        return shp;
    }

    // 64x48 cameo from a full-colour portrait image (e.g. a frame of the SC portrait video).
    // crop = source rectangle; gold = draw the "upgraded" gold frame + chevron.
    public static Shp BuildPortraitCameo(Bitmap src, Rectangle crop, Color[] cameoPal, bool gold)
    {
        Bitmap bmp = new Bitmap(64, 48);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
            g.DrawImage(src, new Rectangle(0, 0, 64, 48), crop, GraphicsUnit.Pixel);
            if (gold)
            {
                using (Pen p = new Pen(Color.FromArgb(230, 180, 40), 2)) g.DrawRectangle(p, 1, 1, 61, 45);
                Point[] chev1 = { new Point(52, 6), new Point(57, 10), new Point(62, 6) };
                Point[] chev2 = { new Point(52, 11), new Point(57, 15), new Point(62, 11) };
                using (Pen p = new Pen(Color.FromArgb(255, 210, 60), 2)) { g.DrawLines(p, chev1); g.DrawLines(p, chev2); }
            }
            else
            {
                using (Pen p = new Pen(Color.FromArgb(90, 110, 140), 1)) g.DrawRectangle(p, 0, 0, 63, 47);
            }
        }
        Frame cf = new Frame(0, 0, 64, 48);
        for (int y = 0; y < 48; y++) for (int x = 0; x < 64; x++) cf.Pixels[y * 64 + x] = Pal.Nearest(bmp.GetPixel(x, y), cameoPal, 1, 255);
        bmp.Dispose();
        Shp shp = new Shp(); shp.Width = 64; shp.Height = 48; shp.Frames.Add(cf);
        return shp;
    }

    // 64x48 research cameo from a grey SC command icon (32x32): tinted gold on a dark panel, with a caption strip.
    public static Shp BuildResearchCameo(Bitmap icon, Color[] cameoPal, string caption)
    {
        Bitmap bmp = new Bitmap(64, 48);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            using (System.Drawing.Drawing2D.LinearGradientBrush br = new System.Drawing.Drawing2D.LinearGradientBrush(
                new Rectangle(0, 0, 64, 48), Color.FromArgb(40, 34, 18), Color.FromArgb(10, 10, 14), 90f))
                g.FillRectangle(br, 0, 0, 64, 48);
            for (int y = 0; y < icon.Height; y++) for (int x = 0; x < icon.Width; x++)
            {
                Color c = icon.GetPixel(x, y);
                if (c.A < 128) continue;
                int v = (c.R + c.G + c.B) / 3;
                if (v < 24) continue;                    // icon background
                Color t = Color.FromArgb(Math.Min(255, v + 40), Math.Min(255, (int)(v * 0.85) + 20), (int)(v * 0.25));
                bmp.SetPixel(16 + x, 2 + y, t);
            }
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.SingleBitPerPixelGridFit;
            using (Font f = new Font("Tahoma", 9f, FontStyle.Regular, GraphicsUnit.Pixel))
            using (StringFormat sf = new StringFormat { Alignment = StringAlignment.Center })
                g.DrawString(caption, f, new SolidBrush(Color.FromArgb(255, 220, 90)), new RectangleF(0, 35, 64, 13), sf);
            using (Pen p = new Pen(Color.FromArgb(200, 160, 40), 1)) g.DrawRectangle(p, 0, 0, 63, 47);
        }
        Frame cf = new Frame(0, 0, 64, 48);
        for (int y = 0; y < 48; y++) for (int x = 0; x < 64; x++) cf.Pixels[y * 64 + x] = Pal.Nearest(bmp.GetPixel(x, y), cameoPal, 1, 255);
        bmp.Dispose();
        Shp shp = new Shp(); shp.Width = 64; shp.Height = 48; shp.Frames.Add(cf);
        return shp;
    }

    // Minimal building SHP for an upgrade that is never drawn on its own (normal, damaged + 2 shadows, all empty).
    public static Shp BuildEmptyBuilding(int w, int h)
    {
        Shp shp = new Shp(); shp.Width = w; shp.Height = h;
        for (int i = 0; i < 4; i++) shp.Frames.Add(new Frame(0, 0, w, h));
        return shp;
    }

    // 64x48 cameo: dark gradient + upscaled sprite, mapped to the cameo palette.
    public static Shp BuildCameo(Frame f, int cw, int ch, Color[] sc, Color[] playerRamp, Color[] cameoPal, int scale, int dx, int dy)
    {
        Bitmap bmp = new Bitmap(64, 48);
        for (int y = 0; y < 48; y++) for (int x = 0; x < 64; x++)
        {
            double t = y / 47.0, r = Math.Sqrt((x - 32) * (x - 32) + (y - 20) * (y - 20)) / 40.0;
            int v = (int)(18 + 40 * (1 - r) * (1 - t * 0.5));
            bmp.SetPixel(x, y, Color.FromArgb(Math.Max(0, v / 2), Math.Max(0, v), Math.Max(0, (int)(v * 1.5))));
        }
        byte[] canvas = ToCanvas(f, cw, ch);
        int minX = cw, minY = ch, maxX = 0, maxY = 0;
        for (int y = 0; y < ch; y++) for (int x = 0; x < cw; x++) if (canvas[y * cw + x] != 0) { minX = Math.Min(minX, x); maxX = Math.Max(maxX, x); minY = Math.Min(minY, y); maxY = Math.Max(maxY, y); }
        int sw = (maxX - minX + 1) * scale, sh = (maxY - minY + 1) * scale;
        int ox = (64 - sw) / 2 + dx, oy = (48 - sh) / 2 + dy;
        for (int y = minY; y <= maxY; y++) for (int x = minX; x <= maxX; x++)
        {
            byte v = canvas[y * cw + x];
            if (v == 0) continue;
            Color c = (v >= 8 && v <= 15) ? playerRamp[v - 8] : sc[v];
            for (int sy = 0; sy < scale; sy++) for (int sx = 0; sx < scale; sx++)
            {
                int px = ox + (x - minX) * scale + sx, py = oy + (y - minY) * scale + sy;
                if (px >= 0 && py >= 0 && px < 64 && py < 48) bmp.SetPixel(px, py, c);
            }
        }
        // 1px frame
        for (int x = 0; x < 64; x++) { bmp.SetPixel(x, 0, Color.FromArgb(90, 110, 140)); bmp.SetPixel(x, 47, Color.FromArgb(20, 25, 35)); }
        for (int y = 0; y < 48; y++) { bmp.SetPixel(0, y, Color.FromArgb(90, 110, 140)); bmp.SetPixel(63, y, Color.FromArgb(20, 25, 35)); }

        Frame cf = new Frame(0, 0, 64, 48);
        for (int y = 0; y < 48; y++) for (int x = 0; x < 64; x++) cf.Pixels[y * 64 + x] = Pal.Nearest(bmp.GetPixel(x, y), cameoPal, 1, 255);
        bmp.Dispose();
        Shp shp = new Shp(); shp.Width = 64; shp.Height = 48; shp.Frames.Add(cf);
        return shp;
    }
}
