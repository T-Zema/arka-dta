# StarCraft-style briefing movie for an ARKA mission: talking-head tiles on the left (static noise, the speaker lights
# up), a transmission log typed out on the right, the mission objectives box, transmission beeps. Rendered frame by
# frame with System.Drawing, encoded with ffmpeg (pixi) to MOVIES\<movie>.MP4, which Vinifera plays for the map's
# [Basic] Brief=<movie> (it resolves <movie>.VQA to .MP4/.WMV/.AVI on the search path, which has MOVIES).
#
#   powershell -NoProfile -File .\build-briefing.ps1 -Spec ..\briefings\arka02.json            # movie
#   powershell -NoProfile -File .\build-briefing.ps1 -Spec ..\briefings\arka02.json -Preview   # a few PNG frames
#
# Spec (UTF-8 JSON): movie, title, place, link, speakers[key,name,tint,intercept], lines[speaker,text],
# objectives[text,warn]. Portraits: Modding\briefings\portraits\<key>.png if present (any size, cropped to fill),
# otherwise a tinted silhouette. Text is rendered into the picture, so Polish letters are fine here.
# This file has Polish letters in the C# below and must keep its UTF-8 BOM, or Windows PowerShell 5.1 reads it as ANSI.
param(
    [Parameter(Mandatory = $true)][string]$Spec,
    [switch]$Preview,
    [string]$Out = ""
)
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$game  = (Resolve-Path "$tools\..\..").Path
$Spec  = (Resolve-Path $Spec).Path
$j = [IO.File]::ReadAllText($Spec, [Text.Encoding]::UTF8) | ConvertFrom-Json

$cs = @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;

public class BrSpeaker { public string Name; public Color Tint; public bool Intercept; public Bitmap Portrait; public double FirstTalk = 1e9; }
public class BrLine { public int Sp; public string Text; public double Start, TypeEnd, End; public List<string> Rows; }

public class BriefingRenderer {
    public int W = 1280, H = 720, Fps = 30;
    public string Title = "", Place = "", Link = "";
    public List<BrSpeaker> Speakers = new List<BrSpeaker>();
    public List<BrLine> Lines = new List<BrLine>();
    public List<string> Objectives = new List<string>();
    public List<bool> ObjWarn = new List<bool>();
    public double Intro = 1.6, CharsPerSec = 40, ObjStart, ObjStep = 0.9, Total;

    Bitmap bg, scan; Bitmap[] noise; Random rnd = new Random(7);
    Font fTitle, fPlace, fName, fText, fTextB, fObj, fHead, fSmall, fNoSig;
    StringFormat sf;
    static readonly Color Amber = Color.FromArgb(232, 181, 74), Steel = Color.FromArgb(58, 74, 85), SteelHi = Color.FromArgb(111, 135, 148);
    static readonly Color TextCol = Color.FromArgb(205, 225, 215), Dim = Color.FromArgb(110, 130, 135), Warn = Color.FromArgb(235, 90, 80);
    const int TileX = 40, TileW = 220, TileH = 135, TileY0 = 95, TileStep = 150, Plate = 24;
    Rectangle objBox = new Rectangle(290, 95, 950, 205), txtBox = new Rectangle(290, 315, 950, 365);

    static Font MkFont(string fam, float size, FontStyle st, string fallback) {
        try { return new Font(new FontFamily(fam), size, st, GraphicsUnit.Pixel); }
        catch (ArgumentException) { return new Font(new FontFamily(fallback), size, st, GraphicsUnit.Pixel); }
    }

    public void Init() {
        fTitle = MkFont("Bahnschrift SemiBold", 30, FontStyle.Regular, "Segoe UI");
        fPlace = MkFont("Bahnschrift", 17, FontStyle.Regular, "Segoe UI");
        fHead  = MkFont("Bahnschrift SemiBold", 16, FontStyle.Regular, "Segoe UI");
        fName  = MkFont("Bahnschrift SemiBold", 14, FontStyle.Regular, "Segoe UI");
        fSmall = MkFont("Bahnschrift", 13, FontStyle.Regular, "Segoe UI");
        fNoSig = MkFont("Consolas", 14, FontStyle.Bold, "Courier New");
        fText  = MkFont("Consolas", 21, FontStyle.Regular, "Courier New");
        fTextB = MkFont("Consolas", 21, FontStyle.Bold, "Courier New");
        fObj   = MkFont("Bahnschrift", 19, FontStyle.Regular, "Segoe UI");
        sf = new StringFormat(StringFormat.GenericTypographic); sf.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces;
        BuildBackground(); BuildNoise(); BuildScan();
    }

    Graphics G(Bitmap b) {
        Graphics g = Graphics.FromImage(b);
        g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        return g;
    }

    void Panel(Graphics g, Rectangle r, Color fill) {
        using (SolidBrush b = new SolidBrush(fill)) g.FillRectangle(b, r);
        using (Pen p = new Pen(Steel, 2)) g.DrawRectangle(p, r);
        using (Pen p = new Pen(SteelHi, 2)) {          // corner brackets
            int c = 14;
            g.DrawLines(p, new Point[] { new Point(r.Left, r.Top + c), new Point(r.Left, r.Top), new Point(r.Left + c, r.Top) });
            g.DrawLines(p, new Point[] { new Point(r.Right - c, r.Top), new Point(r.Right, r.Top), new Point(r.Right, r.Top + c) });
            g.DrawLines(p, new Point[] { new Point(r.Left, r.Bottom - c), new Point(r.Left, r.Bottom), new Point(r.Left + c, r.Bottom) });
            g.DrawLines(p, new Point[] { new Point(r.Right - c, r.Bottom), new Point(r.Right, r.Bottom), new Point(r.Right, r.Bottom - c) });
        }
    }

    void BuildBackground() {
        bg = new Bitmap(W, H, PixelFormat.Format24bppRgb);
        using (Graphics g = G(bg)) {
            using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(0, 0, W, H), Color.FromArgb(13, 20, 26), Color.FromArgb(5, 8, 11), 90f)) g.FillRectangle(b, 0, 0, W, H);
            using (Pen p = new Pen(Color.FromArgb(18, 30, 37))) { for (int x = 0; x < W; x += 32) g.DrawLine(p, x, 0, x, H); for (int y = 0; y < H; y += 32) g.DrawLine(p, 0, y, W, y); }
            Rectangle bar = new Rectangle(20, 15, W - 40, 62);
            Panel(g, bar, Color.FromArgb(14, 22, 28));
            using (SolidBrush b = new SolidBrush(Amber)) g.DrawString(Title, fTitle, b, 40, 29, sf);
            using (SolidBrush b = new SolidBrush(Color.FromArgb(170, 185, 190))) {
                SizeF s1 = g.MeasureString(Place, fPlace, 1000, sf); g.DrawString(Place, fPlace, b, bar.Right - 20 - s1.Width, 24, sf);
            }
            using (SolidBrush b = new SolidBrush(Color.FromArgb(90, 170, 190))) {
                SizeF s2 = g.MeasureString(Link, fSmall, 1000, sf); g.DrawString(Link, fSmall, b, bar.Right - 20 - s2.Width, 48, sf);
            }
            Panel(g, objBox, Color.FromArgb(9, 15, 19));
            Panel(g, txtBox, Color.FromArgb(9, 15, 19));
            using (SolidBrush b = new SolidBrush(Amber)) { g.DrawString("CELE MISJI", fHead, b, objBox.Left + 16, objBox.Top + 10, sf); g.DrawString("ZAPIS ŁĄCZNOŚCI", fHead, b, txtBox.Left + 16, txtBox.Top + 10, sf); }
            using (Pen p = new Pen(Steel)) { g.DrawLine(p, objBox.Left + 12, objBox.Top + 34, objBox.Right - 12, objBox.Top + 34); g.DrawLine(p, txtBox.Left + 12, txtBox.Top + 34, txtBox.Right - 12, txtBox.Top + 34); }
            using (SolidBrush b = new SolidBrush(Dim)) { string h = "ESC — pomiń"; SizeF s = g.MeasureString(h, fSmall, 1000, sf); g.DrawString(h, fSmall, b, W - 22 - s.Width, H - 30, sf); }
            for (int i = 0; i < Speakers.Count; i++) Panel(g, TileRect(i), Color.FromArgb(5, 8, 10));
        }
    }

    void BuildNoise() {
        noise = new Bitmap[8];
        for (int k = 0; k < noise.Length; k++) {
            Bitmap n = new Bitmap(TileW, TileH, PixelFormat.Format32bppArgb);
            BitmapData d = n.LockBits(new Rectangle(0, 0, TileW, TileH), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            byte[] px = new byte[d.Stride * TileH];
            for (int y = 0; y < TileH; y++) {
                int band = rnd.Next(100) < 4 ? 60 : 0;               // occasional bright tear line
                for (int x = 0; x < TileW; x++) {
                    int v = Math.Min(255, rnd.Next(200) + band); int o = y * d.Stride + x * 4;
                    px[o] = (byte)v; px[o + 1] = (byte)Math.Min(255, v + 10); px[o + 2] = (byte)v; px[o + 3] = 255;
                }
            }
            System.Runtime.InteropServices.Marshal.Copy(px, 0, d.Scan0, px.Length); n.UnlockBits(d); noise[k] = n;
        }
    }

    void BuildScan() {
        scan = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(scan)) using (Pen p = new Pen(Color.FromArgb(38, 0, 0, 0))) { for (int y = 0; y < H; y += 3) g.DrawLine(p, 0, y, W, y); }
    }

    Rectangle TileRect(int i) { return new Rectangle(TileX, TileY0 + i * TileStep, TileW, TileH); }

    List<string> Wrap(Graphics g, string text, Font f, float width) {
        List<string> rows = new List<string>(); string cur = "";
        foreach (string w in text.Split(' ')) {
            string t = cur.Length == 0 ? w : cur + " " + w;
            if (g.MeasureString(t, f, 5000, sf).Width > width && cur.Length > 0) { rows.Add(cur + " "); cur = w; } else cur = t;
        }
        if (cur.Length > 0) rows.Add(cur);
        return rows;
    }

    public void AddLine(int sp, string text) { BrLine l = new BrLine(); l.Sp = sp; l.Text = text; Lines.Add(l); }

    public void Layout() {
        double t = Intro;
        using (Bitmap b = new Bitmap(8, 8)) using (Graphics g = G(b)) {
            foreach (BrLine l in Lines) {
                l.Start = t; l.TypeEnd = t + 0.4 + l.Text.Length / CharsPerSec; l.End = l.TypeEnd + 1.7; t = l.End;
                if (Speakers[l.Sp].FirstTalk > l.Start) Speakers[l.Sp].FirstTalk = l.Start;
                l.Rows = Wrap(g, Speakers[l.Sp].Name + ": " + l.Text, fText, txtBox.Width - 40);
            }
        }
        ObjStart = t + 0.3; Total = ObjStart + Objectives.Count * ObjStep + 4.0;
    }

    int Talking(double t) { foreach (BrLine l in Lines) if (t >= l.Start && t < l.End) return l.Sp; return -1; }

    static ImageAttributes Alpha(float a, float bright) {
        ColorMatrix m = new ColorMatrix(); m.Matrix00 = bright; m.Matrix11 = bright; m.Matrix22 = bright; m.Matrix33 = a;
        ImageAttributes ia = new ImageAttributes(); ia.SetColorMatrix(m); return ia;
    }

    void Silhouette(Graphics g, Rectangle r, Color tint, float bright) {
        Color c1 = Color.FromArgb((int)(tint.R * 0.55f * bright), (int)(tint.G * 0.55f * bright), (int)(tint.B * 0.55f * bright));
        Color c2 = Color.FromArgb((int)(tint.R * 0.12f * bright), (int)(tint.G * 0.12f * bright), (int)(tint.B * 0.12f * bright));
        float cx = r.Left + r.Width / 2f, hr = r.Height * 0.2f, hy = r.Top + r.Height * 0.38f;
        using (GraphicsPath p = new GraphicsPath()) {
            p.AddEllipse(cx - hr * 0.85f, hy - hr, hr * 1.7f, hr * 2.05f);
            p.AddBezier(cx - r.Width * 0.42f, r.Bottom, cx - r.Width * 0.38f, hy + hr * 1.6f, cx - hr * 0.6f, hy + hr * 1.3f, cx, hy + hr * 1.25f);
            p.AddBezier(cx, hy + hr * 1.25f, cx + hr * 0.6f, hy + hr * 1.3f, cx + r.Width * 0.38f, hy + hr * 1.6f, cx + r.Width * 0.42f, r.Bottom);
            p.CloseFigure();
            using (LinearGradientBrush b = new LinearGradientBrush(r, c1, c2, 90f)) g.FillPath(b, p);
        }
    }

    void DrawTile(Graphics g, int i, double t, int fi) {
        BrSpeaker s = Speakers[i]; Rectangle r = TileRect(i);
        Rectangle pa = new Rectangle(r.Left + 3, r.Top + 3, r.Width - 6, r.Height - 6 - Plate);
        bool talking = Talking(t) == i, known = t >= s.FirstTalk;
        float bright = talking ? 1f : 0.6f;
        if (talking && rnd.Next(100) < 6) bright *= 0.8f;            // flicker
        GraphicsState st = g.Save(); g.SetClip(pa);
        if (known) {
            if (s.Portrait != null) {
                float sc = Math.Max((float)pa.Width / s.Portrait.Width, (float)pa.Height / s.Portrait.Height);
                int w = (int)(s.Portrait.Width * sc), h = (int)(s.Portrait.Height * sc);
                using (ImageAttributes ia = Alpha(1f, bright)) g.DrawImage(s.Portrait, new Rectangle(pa.Left + (pa.Width - w) / 2, pa.Top + (pa.Height - h) / 2, w, h), 0, 0, s.Portrait.Width, s.Portrait.Height, GraphicsUnit.Pixel, ia);
            } else Silhouette(g, pa, s.Tint, bright);
        }
        float na = !known ? 0.85f : talking ? (s.Intercept ? 0.38f : 0.12f) : 0.3f;
        using (ImageAttributes ia = Alpha(na, 1f)) g.DrawImage(noise[(fi + i * 3) % noise.Length], pa, 0, 0, pa.Width, pa.Height, GraphicsUnit.Pixel, ia);
        if (talking) {                                                 // rolling bright band of the transmission
            int by = pa.Top + (int)((t * 70 + i * 40) % pa.Height);
            using (SolidBrush b = new SolidBrush(Color.FromArgb(28, s.Tint))) g.FillRectangle(b, pa.Left, by, pa.Width, 10);
        }
        if (!known && ((int)(t * 2) % 2 == 0)) {
            using (SolidBrush b = new SolidBrush(Color.FromArgb(200, 225, 235, 230))) {
                string m = "BRAK SYGNAŁU"; SizeF z = g.MeasureString(m, fNoSig, 1000, sf);
                using (SolidBrush bb = new SolidBrush(Color.FromArgb(170, 0, 0, 0))) g.FillRectangle(bb, pa.Left + (pa.Width - z.Width) / 2 - 6, pa.Top + (pa.Height - z.Height) / 2 - 3, z.Width + 12, z.Height + 6);
                g.DrawString(m, fNoSig, b, pa.Left + (pa.Width - z.Width) / 2, pa.Top + (pa.Height - z.Height) / 2, sf);
            }
        }
        if (s.Intercept && known) {
            using (SolidBrush bb = new SolidBrush(Color.FromArgb(190, 60, 10, 10))) g.FillRectangle(bb, pa.Left + 4, pa.Top + 4, 112, 18);
            using (SolidBrush b = new SolidBrush(Warn)) g.DrawString("PRZECHWYCONO", fSmall, b, pa.Left + 9, pa.Top + 6, sf);
        }
        g.Restore(st);
        Rectangle pl = new Rectangle(r.Left + 3, r.Bottom - 3 - Plate, r.Width - 6, Plate);
        using (SolidBrush b = new SolidBrush(Color.FromArgb(14, 24, 30))) g.FillRectangle(b, pl);
        using (SolidBrush b = new SolidBrush(known ? (talking ? s.Tint : Color.FromArgb(150, s.Tint)) : Dim)) g.DrawString(known ? s.Name : "???", fName, b, pl.Left + 8, pl.Top + 4, sf);
        if (talking) {                                                 // voice level bars
            for (int k = 0; k < 7; k++) {
                double v = Math.Abs(Math.Sin(t * (9 + k * 1.7) + k)) * (0.4 + 0.6 * rnd.NextDouble());
                int h = 3 + (int)(v * 14);
                using (SolidBrush b = new SolidBrush(s.Tint)) g.FillRectangle(b, pl.Right - 70 + k * 9, pl.Bottom - 4 - h, 6, h);
            }
        }
        Color edge = talking ? s.Tint : Steel;
        using (Pen p = new Pen(edge, talking ? 3 : 2)) g.DrawRectangle(p, r);
    }

    void DrawObjectives(Graphics g, double t) {
        float y0 = objBox.Top + 46;
        if (t < ObjStart) {
            if ((int)(t * 1.6) % 2 == 0) using (SolidBrush b = new SolidBrush(Dim)) g.DrawString("oczekiwanie na rozkazy...", fObj, b, objBox.Left + 20, y0, sf);
            return;
        }
        for (int k = 0; k < Objectives.Count; k++) {
            double a = (t - (ObjStart + k * ObjStep)) / 0.35; if (a <= 0) break; if (a > 1) a = 1;
            float y = y0 + k * 30, dx = (float)((1 - a) * 30);
            Color c = ObjWarn[k] ? Warn : TextCol;
            using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(255 * a), ObjWarn[k] ? Warn : Amber))) g.FillRectangle(b, objBox.Left + 22 + dx, y + 7, 9, 9);
            using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(255 * a), c))) g.DrawString(Objectives[k], fObj, b, objBox.Left + 42 + dx, y, sf);
        }
    }

    void DrawTranscript(Graphics g, double t) {
        float x0 = txtBox.Left + 20, top = txtBox.Top + 46, lh = 29;
        if (t < Intro) {
            if ((int)(t * 3) % 2 == 0) using (SolidBrush b = new SolidBrush(Color.FromArgb(90, 170, 190))) g.DrawString("NAWIĄZYWANIE POŁĄCZENIA...", fText, b, x0, top, sf);
            return;
        }
        List<BrLine> vis = new List<BrLine>(); int rows = 0;
        foreach (BrLine l in Lines) if (t >= l.Start) { vis.Add(l); rows += l.Rows.Count + 1; }
        int maxRows = (int)((txtBox.Bottom - 12 - top) / lh);
        while (vis.Count > 1 && rows - 1 > maxRows) { rows -= vis[0].Rows.Count + 1; vis.RemoveAt(0); }
        float y = top;
        foreach (BrLine l in vis) {
            BrSpeaker s = Speakers[l.Sp];
            int shown = l.Rows.Count > 0 ? (s.Name.Length + 2) + (int)Math.Max(0, Math.Min(l.Text.Length, (t - l.Start - 0.4) * CharsPerSec)) : 0;
            bool typing = t < l.TypeEnd; bool current = t < l.End;
            float lastX = x0, lastY = y, y0 = y;
            for (int ri = 0; ri < l.Rows.Count && shown > 0; ri++) {
                string row = l.Rows[ri]; string part = row.Length <= shown ? row : row.Substring(0, shown); shown -= row.Length;
                float x = x0;
                if (ri == 0) {
                    string nm = s.Name + ":"; int n = Math.Min(nm.Length, part.Length);
                    using (SolidBrush b = new SolidBrush(current ? s.Tint : Color.FromArgb(160, s.Tint))) g.DrawString(part.Substring(0, n), fTextB, b, x, y, sf);
                    x += g.MeasureString(part.Substring(0, n), fTextB, 5000, sf).Width; part = part.Substring(n);
                }
                using (SolidBrush b = new SolidBrush(current ? TextCol : Color.FromArgb(150, 165, 170))) g.DrawString(part, fText, b, x, y, sf);
                lastX = x + g.MeasureString(part, fText, 5000, sf).Width; lastY = y;
                y += lh;
            }
            if (typing || (current && (int)(t * 2.5) % 2 == 0)) using (SolidBrush b = new SolidBrush(s.Tint)) g.FillRectangle(b, lastX + 3, lastY + 4, 11, 20);
            y = y0 + (l.Rows.Count + 1) * lh;
        }
    }

    public Bitmap Frame(double t, int fi) {
        Bitmap bmp = new Bitmap(W, H, PixelFormat.Format24bppRgb);
        using (Graphics g = G(bmp)) {
            g.DrawImageUnscaled(bg, 0, 0);
            if ((int)(t * 1.5) % 2 == 0 && t < Total - 1) using (SolidBrush b = new SolidBrush(Warn)) { g.FillEllipse(b, 660, 39, 12, 12); g.DrawString("TRANSMISJA", fSmall, b, 680, 36, sf); }
            for (int i = 0; i < Speakers.Count; i++) DrawTile(g, i, t, fi);
            DrawObjectives(g, t);
            DrawTranscript(g, t);
            g.DrawImageUnscaled(scan, 0, 0);
            double a = 1; if (t < 0.8) a = t / 0.8; if (t > Total - 1.0) a = Math.Max(0, (Total - t) / 1.0);
            if (a < 1) using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(255 * (1 - a)), 0, 0, 0))) g.FillRectangle(b, 0, 0, W, H);
        }
        return bmp;
    }

    public int RenderAll(string dir) {
        int n = (int)Math.Ceiling(Total * Fps);
        for (int f = 0; f < n; f++) { using (Bitmap b = Frame((double)f / Fps, f)) b.Save(Path.Combine(dir, string.Format("f{0:D5}.png", f)), ImageFormat.Png); }
        return n;
    }

    // transmission sounds: low hum, a two-tone beep per line, static for intercepted speakers, key clicks while typing,
    // a blip per objective, a rising sweep for the connection
    public void WriteWav(string path) {
        int rate = 22050, n = (int)(Total * rate); float[] a = new float[n]; Random r = new Random(3);
        for (int i = 0; i < n; i++) { double t = (double)i / rate; a[i] = (float)(0.018 * Math.Sin(2 * Math.PI * 55 * t) + 0.008 * Math.Sin(2 * Math.PI * 110 * t) + 0.004 * (r.NextDouble() - 0.5)); }
        Action<double, double, double, double, double> tone = (start, dur, f0, f1, amp) => {
            int s0 = (int)(start * rate), len = (int)(dur * rate); double ph = 0;
            for (int k = 0; k < len && s0 + k < n; k++) { double x = (double)k / len; double f = f0 + (f1 - f0) * x; ph += 2 * Math.PI * f / rate; double env = Math.Min(1, Math.Min(k / (0.004 * rate), (len - k) / (0.01 * rate))); a[s0 + k] += (float)(amp * env * Math.Sin(ph)); }
        };
        Action<double, double, double> hiss = (start, dur, amp) => {
            int s0 = (int)(start * rate), len = (int)(dur * rate);
            for (int k = 0; k < len && s0 + k < n; k++) { double env = Math.Min(1, (len - k) / (0.05 * rate)); a[s0 + k] += (float)(amp * env * (r.NextDouble() * 2 - 1)); }
        };
        tone(0.3, 0.45, 300, 1200, 0.12);
        foreach (BrLine l in Lines) {
            tone(l.Start, 0.06, 1320, 1320, 0.2); tone(l.Start + 0.08, 0.07, 990, 990, 0.2);
            if (Speakers[l.Sp].Intercept) hiss(l.Start, 0.5, 0.12);
            for (double c = l.Start + 0.4; c < l.TypeEnd; c += 2.0 / CharsPerSec) hiss(c, 0.004, 0.18);
        }
        for (int k = 0; k < Objectives.Count; k++) tone(ObjStart + k * ObjStep, 0.05, 1760, 1760, 0.15);
        using (BinaryWriter w = new BinaryWriter(File.Create(path))) {
            w.Write(new char[] { 'R', 'I', 'F', 'F' }); w.Write(36 + n * 2); w.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
            w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(rate); w.Write(rate * 2); w.Write((short)2); w.Write((short)16);
            w.Write(new char[] { 'd', 'a', 't', 'a' }); w.Write(n * 2);
            for (int i = 0; i < n; i++) w.Write((short)(Math.Max(-1, Math.Min(1, a[i])) * 32000));
        }
    }
}
'@
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$r = New-Object BriefingRenderer
$r.Title = $j.title; $r.Place = $j.place; $r.Link = $j.link
$keys = @()
foreach ($s in $j.speakers) {
    $sp = New-Object BrSpeaker; $sp.Name = $s.name; $sp.Tint = [Drawing.ColorTranslator]::FromHtml($s.tint); $sp.Intercept = [bool]$s.intercept
    $pp = "$game\Modding\briefings\portraits\$($s.key).png"; if (Test-Path $pp) { $sp.Portrait = New-Object Drawing.Bitmap $pp }
    $r.Speakers.Add($sp); $keys += $s.key
}
foreach ($l in $j.lines) { $i = [Array]::IndexOf($keys, $l.speaker); if ($i -lt 0) { throw "unknown speaker '$($l.speaker)'" }; $r.AddLine($i, $l.text) }
foreach ($o in $j.objectives) { $r.Objectives.Add($o.text); $r.ObjWarn.Add([bool]$o.warn) }
$r.Init(); $r.Layout()
"briefing $($j.movie): $([Math]::Round($r.Total, 1)) s, $($r.Lines.Count) lines, $($r.Objectives.Count) objectives"

$work = "$env:TEMP\briefing-$($j.movie)"
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force $work | Out-Null
if ($Preview) {
    $times = @(0.5, ($r.Lines[0].Start + 2.5), ($r.Lines[1].Start + 2.0), ($r.Lines[$r.Lines.Count - 1].TypeEnd), ($r.Total - 1.5))
    $k = 0; foreach ($t in $times) { $b = $r.Frame($t, $k); $b.Save("$work\preview_$k.png", [Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); $k++ }
    "preview frames: $work\preview_*.png"
    return
}
$n = $r.RenderAll($work); $r.WriteWav("$work\audio.wav")
"frames: $n"
if (-not $Out) { New-Item -ItemType Directory -Force "$game\MOVIES" | Out-Null; $Out = "$game\MOVIES\$($j.movie).MP4" }
& pixi exec --spec ffmpeg ffmpeg -hide_banner -loglevel error -y -framerate $r.Fps -i "$work\f%05d.png" -i "$work\audio.wav" `
    -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -profile:v high -level 4.0 -c:a aac -b:a 128k -shortest -movflags +faststart $Out
if ($LASTEXITCODE) { throw "ffmpeg failed ($LASTEXITCODE)" }
"movie: $Out ($([Math]::Round((Get-Item $Out).Length / 1MB, 1)) MB)"
