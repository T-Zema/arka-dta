// Builds a DTA map from a hand-made design instead of a StarCraft scenario. The design is a few label
// rasters in "design pixels" (e.g. the pixels of a screenshot of a real map): kind (water / low / high /
// ramp), ground (grass / dirt / pavement / tall grass) and free zones (beach, keep clear, trees...).
// Every TS cell samples them, then ScToDta's cliff, shore, water and LAT stages run unchanged.
// C# 5. Needs ModTools.cs, TsMap.cs, ScMap.cs, ScToDta.cs.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

// A label raster over design coordinates u in [U0, U0+W), v in [V0, V0+H).
public class Layer
{
    public int W, H, U0, V0;
    public byte[] L;

    public Layer(int u0, int v0, int w, int h, byte fill)
    {
        U0 = u0; V0 = v0; W = w; H = h; L = new byte[w * h];
        for (int i = 0; i < L.Length; i++) L[i] = fill;
    }

    public byte Get(double u, double v)
    {
        int x = (int)Math.Floor(u) - U0, y = (int)Math.Floor(v) - V0;
        x = Math.Max(0, Math.Min(W - 1, x)); y = Math.Max(0, Math.Min(H - 1, y));
        return L[y * W + x];
    }

    // only: replace only pixels that currently hold this label (255 = any)
    public void Polygon(double[] p, byte val, byte only)
    {
        double minU = double.MaxValue, maxU = double.MinValue, minV = double.MaxValue, maxV = double.MinValue;
        for (int k = 0; k < p.Length; k += 2) { minU = Math.Min(minU, p[k]); maxU = Math.Max(maxU, p[k]); minV = Math.Min(minV, p[k + 1]); maxV = Math.Max(maxV, p[k + 1]); }
        int n = p.Length / 2;
        for (int y = Math.Max(0, (int)minV - V0); y <= Math.Min(H - 1, (int)maxV - V0 + 1); y++)
            for (int x = Math.Max(0, (int)minU - U0); x <= Math.Min(W - 1, (int)maxU - U0 + 1); x++)
            {
                double pu = x + U0 + 0.5, pv = y + V0 + 0.5;
                bool inside = false;
                for (int a = 0, b = n - 1; a < n; b = a++)
                {
                    double ua = p[2 * a], va = p[2 * a + 1], ub = p[2 * b], vb = p[2 * b + 1];
                    if ((va > pv) != (vb > pv) && pu < (ub - ua) * (pv - va) / (vb - va) + ua) inside = !inside;
                }
                if (inside && (only == 255 || L[y * W + x] == only)) L[y * W + x] = val;
            }
    }

    // thick polyline (width in design px)
    public void Line(double[] p, double width, byte val, byte only)
    {
        double r = width / 2;
        for (int k = 0; k + 3 < p.Length; k += 2)
        {
            double ua = p[k], va = p[k + 1], ub = p[k + 2], vb = p[k + 3];
            int x0 = (int)(Math.Min(ua, ub) - r) - U0 - 1, x1 = (int)(Math.Max(ua, ub) + r) - U0 + 1;
            int y0 = (int)(Math.Min(va, vb) - r) - V0 - 1, y1 = (int)(Math.Max(va, vb) + r) - V0 + 1;
            double du = ub - ua, dv = vb - va, len2 = du * du + dv * dv;
            for (int y = Math.Max(0, y0); y <= Math.Min(H - 1, y1); y++)
                for (int x = Math.Max(0, x0); x <= Math.Min(W - 1, x1); x++)
                {
                    double pu = x + U0 + 0.5 - ua, pv = y + V0 + 0.5 - va;
                    double t = len2 > 0 ? Math.Max(0, Math.Min(1, (pu * du + pv * dv) / len2)) : 0;
                    double eu = pu - t * du, ev = pv - t * dv;
                    if (eu * eu + ev * ev <= r * r && (only == 255 || L[y * W + x] == only)) L[y * W + x] = val;
                }
        }
    }

    // pixels of a picture (placed at design u0, v0) whose colour is within tol (L1) of rgb get val
    public void FromColor(Bitmap img, int u0, int v0, int r, int g, int b, int tol, byte val)
    {
        int[] px = Pixels(img);
        for (int y = 0; y < img.Height; y++) for (int x = 0; x < img.Width; x++)
        {
            int lx = x + u0 - U0, ly = y + v0 - V0;
            if (lx < 0 || ly < 0 || lx >= W || ly >= H) continue;
            Color c = Color.FromArgb(px[y * img.Width + x]);
            if (Math.Abs(c.R - r) + Math.Abs(c.G - g) + Math.Abs(c.B - b) <= tol) L[ly * W + lx] = val;
        }
    }

    // pixels darker than lumMax (and not near the colour skip) get val, only where the label is `only`
    public void FromDark(Bitmap img, int u0, int v0, double lumMax, int sr, int sg, int sb, byte val, byte only)
    {
        int[] px = Pixels(img);
        for (int y = 0; y < img.Height; y++) for (int x = 0; x < img.Width; x++)
        {
            int lx = x + u0 - U0, ly = y + v0 - V0;
            if (lx < 0 || ly < 0 || lx >= W || ly >= H) continue;
            Color c = Color.FromArgb(px[y * img.Width + x]);
            if (Math.Abs(c.R - sr) + Math.Abs(c.G - sg) + Math.Abs(c.B - sb) <= 40) continue;
            if (0.3 * c.R + 0.59 * c.G + 0.11 * c.B < lumMax && (only == 255 || L[ly * W + lx] == only)) L[ly * W + lx] = val;
        }
    }

    // greenish pixels (vegetation) get val
    public void FromGreen(Bitmap img, int u0, int v0, int margin, byte val, byte only)
    {
        int[] px = Pixels(img);
        for (int y = 0; y < img.Height; y++) for (int x = 0; x < img.Width; x++)
        {
            int lx = x + u0 - U0, ly = y + v0 - V0;
            if (lx < 0 || ly < 0 || lx >= W || ly >= H) continue;
            Color c = Color.FromArgb(px[y * img.Width + x]);
            if (c.G > c.R + margin && c.G >= c.B - 4 && (only == 255 || L[ly * W + lx] == only)) L[ly * W + lx] = val;
        }
    }

    // Box-filter vote: inside pixels labelled val or other, val wins where its share in the window >= frac.
    public void Vote(byte val, byte other, int r, double frac)
    {
        int[] sum = new int[(W + 1) * (H + 1)];
        for (int y = 0; y < H; y++)
        {
            int row = 0;
            for (int x = 0; x < W; x++) { row += L[y * W + x] == val ? 1 : 0; sum[(y + 1) * (W + 1) + x + 1] = sum[y * (W + 1) + x + 1] + row; }
        }
        byte[] res = (byte[])L.Clone();
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++)
        {
            byte l = L[y * W + x];
            if (l != val && l != other) continue;
            int xa = Math.Max(0, x - r), xb = Math.Min(W, x + r + 1), ya = Math.Max(0, y - r), yb = Math.Min(H, y + r + 1);
            int s = sum[yb * (W + 1) + xb] - sum[ya * (W + 1) + xb] - sum[yb * (W + 1) + xa] + sum[ya * (W + 1) + xa];
            res[y * W + x] = s >= frac * (xb - xa) * (yb - ya) ? val : other;
        }
        L = res;
    }

    // 4-connected components of val smaller than minSize become repl
    public int RemoveSmall(byte val, byte repl, int minSize)
    {
        bool[] seen = new bool[L.Length]; int removed = 0;
        for (int s = 0; s < L.Length; s++)
        {
            if (seen[s] || L[s] != val) continue;
            List<int> comp = new List<int>(); Stack<int> st = new Stack<int>(); st.Push(s); seen[s] = true;
            while (st.Count > 0)
            {
                int c = st.Pop(); comp.Add(c); int x = c % W, y = c / W;
                if (x > 0 && !seen[c - 1] && L[c - 1] == val) { seen[c - 1] = true; st.Push(c - 1); }
                if (x < W - 1 && !seen[c + 1] && L[c + 1] == val) { seen[c + 1] = true; st.Push(c + 1); }
                if (y > 0 && !seen[c - W] && L[c - W] == val) { seen[c - W] = true; st.Push(c - W); }
                if (y < H - 1 && !seen[c + W] && L[c + W] == val) { seen[c + W] = true; st.Push(c + W); }
            }
            if (comp.Count < minSize) { foreach (int c in comp) L[c] = repl; removed += comp.Count; }
        }
        return removed;
    }

    // where the other layer (same geometry) holds otherVal, set val (only over `only`, 255 = any)
    public void Where(Layer other, byte otherVal, byte val, byte only)
    {
        for (int i = 0; i < L.Length; i++)
            if (other.L[i] == otherVal && (only == 255 || L[i] == only)) L[i] = val;
    }

    public Bitmap Render(int[] palette)
    {
        int[] buf = new int[W * H];
        for (int i = 0; i < buf.Length; i++) buf[i] = palette[L[i] % palette.Length];
        return Img.FromBuffer(buf, W, H);
    }

    public static int[] Pixels(Bitmap img)
    {
        Bitmap b = img.PixelFormat == PixelFormat.Format32bppArgb ? img : img.Clone(new Rectangle(0, 0, img.Width, img.Height), PixelFormat.Format32bppArgb);
        BitmapData d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int[] px = new int[b.Width * b.Height];
        for (int y = 0; y < b.Height; y++) Marshal.Copy(new IntPtr(d.Scan0.ToInt64() + (long)y * d.Stride), px, y * b.Width, b.Width);
        b.UnlockBits(d);
        if (b != img) b.Dispose();
        return px;
    }
}

public class DesignToDta : ScToDta
{
    // kind labels
    public const byte KWater = 0, KLow = 1, KHigh = 2, KRamp = 3;
    public bool[] Ramp;
    public byte[] Zone;                         // per cell zone label (meaning chosen by the build script)
    public double DU0, DV0, ScaleX, ScaleY;     // design point at the visible top-left; screen px per design px
    public HashSet<int> Reserved = new HashSet<int>();   // cells kept free of trees and buildings
    public Dictionary<int, string> Occupied = new Dictionary<int, string>();   // cells under buildings
    public List<string> Buildings = new List<string>();

    // the design rectangle [du0, du1] x [dv0, dv1] fills the visible area localW x localH
    public DesignToDta(Theater th, int localW, int localH, int padX, int padTop, int padBottom, double du0, double dv0, double du1, double dv1)
        : base(th, localW, localH, padX, padTop, padBottom)
    {
        DU0 = du0; DV0 = dv0;
        ScaleX = localW * 48.0 / (du1 - du0); ScaleY = localH * 24.0 / (dv1 - dv0);
        Ramp = new bool[N * N]; Zone = new byte[N * N];
        for (int i = 0; i < Plateau.Length; i++) Plateau[i] = -1;
    }

    public void Design(int x, int y, out double u, out double v)
    {
        int dx, dy; ToScreen(x, y, out dx, out dy);
        u = DU0 + ((dx + 1) * 24.0 - PadX * 48) / ScaleX;
        v = DV0 + ((dy + 1) * 12.0 - PadTop * 24) / ScaleY;
    }

    // cell whose centre is nearest to a design point
    public int CellAt(double u, double v)
    {
        double dx = ((u - DU0) * ScaleX + PadX * 48) / 24.0 - 1, dy = ((v - DV0) * ScaleY + PadTop * 24) / 12.0 - 1;
        int x = (int)Math.Round((dx + dy + 2) / 2.0), y = (int)Math.Round((dy - dx + 2 * W) / 2.0);
        return Idx(x, y);
    }

    public override bool LocalWalk(int a, int b) { return Ramp[a] || Ramp[b]; }

    // kind: majority of 5 samples in the cell diamond; ground and zone: centre sample
    public void Classify(Layer kind, Layer ground, Layer zone, int minPlateau)
    {
        double hu = 12.0 / ScaleX, hv = 6.0 / ScaleY;   // a quarter of the cell diamond, in design px
        Ground = new int[K.Length];
        for (int i = 0; i < K.Length; i++)
        {
            if (!Valid[i]) continue;
            double u, v; Design(i % N, i / N, out u, out v);
            int[] votes = new int[4];
            votes[kind.Get(u, v)] += 2;
            votes[kind.Get(u - hu, v)]++; votes[kind.Get(u + hu, v)]++; votes[kind.Get(u, v - hv)]++; votes[kind.Get(u, v + hv)]++;
            int land = votes[KLow] + votes[KHigh] + votes[KRamp];
            if (votes[KWater] > land) K[i] = Kind.Water;
            else if (votes[KHigh] > votes[KLow] + votes[KRamp]) K[i] = Kind.High;
            else { K[i] = Kind.Low; Ramp[i] = votes[KRamp] >= 2; }
            Ground[i] = ground.Get(u, v);
            Zone[i] = zone.Get(u, v);
        }
        // specks: small land in water becomes water, small enclosed water becomes land
        foreach (List<int> comp in Components(delegate (int i) { return K[i] != Kind.Water; }, false))
            if (comp.Count < 12) foreach (int i in comp) K[i] = Kind.Water;
        foreach (List<int> comp in Components(delegate (int i) { return K[i] == Kind.Water; }, false))
        {
            if (comp.Count >= 30) continue;
            bool edge = false;
            foreach (int i in comp) if (!Visible[i]) { edge = true; break; }
            if (!edge) foreach (int i in comp) K[i] = Kind.Low;
        }
        int id = 0;
        foreach (List<int> comp in Components(delegate (int i) { return K[i] == Kind.High; }, false))
        {
            if (comp.Count < minPlateau) { foreach (int i in comp) K[i] = Kind.Low; continue; }
            foreach (int i in comp) { Plateau[i] = id; Lev[i] = 1; }
            PlateauLevel.Add(1);
            id++;
        }
        // no FindBridges(): a design draws its quays explicitly, and a half-detected causeway (runway tip,
        // mole stubs) left raw staircase edges and water channels cut by the next shore chain
        int[] cnt = new int[5]; int ramps = 0;
        for (int i = 0; i < K.Length; i++) if (Valid[i]) { cnt[(int)K[i]]++; if (Ramp[i]) ramps++; }
        Log.Add(string.Format("cells: low {0} high {1} water {2}; plateaus {3}; ramp cells {4}", cnt[0], cnt[1], cnt[3], id, ramps));
    }

    // Beaches (WAE shore set) along coast whose land cell passes `land`. The shore set has no Front/Back
    // rule and its templates are mostly sand, so ScToDta.Shores let chains drift inland or even face the
    // land. Here every piece pays for water cells on land and land cells on water alike, and is probed
    // two cells beyond its water part (must be water) and beyond its land part (must be land).
    public void Beaches(ConnectedSet cs, CellPred land)
    {
        int n = 0;
        foreach (List<int> comp in Components(delegate (int i) { return K[i] == Kind.Water; }, false))
        {
            HashSet<int> water = new HashSet<int>(comp);
            List<Arc> arcs = TraceArcs(delegate (int i) { return water.Contains(i); }, delegate (int a, int b)
            {
                if (!Visible[a] || !Visible[b]) return 2;
                if (Used[b]) return 0;
                return land(b) ? 1 : 3;
            }, n++, 1);
            foreach (Arc arc in arcs)
            {
                if (arc.Path.Count < 4) continue;
                DebugArcs.Add(arc.Path);
                Log.Add("beach arc " + arc.Path.Count + " cells, edges " + arc.StartAtEdge + "/" + arc.EndAtEdge);
                Chain(cs, arc, 3, BeachCellCost, BeachOrientCost, false);
            }
        }
    }

    // Shore templates draw water with code 9 or 1 (shallow water, passable); 2 is sand. Checked on the
    // rendered TemperateShoreSet pieces, 2026-10-26.
    static bool Wet(TmpCell tc) { return tc.Terrain == 9 || tc.Terrain == 1; }

    double BeachCellCost(CPiece p, int i, TmpCell tc)
    {
        if (!Visible[i]) return 0;
        bool w = K[i] == Kind.Water;
        return Wet(tc) == w ? 0 : 2;
    }

    Dictionary<CPiece, double[]> beachAxis = new Dictionary<CPiece, double[]>();

    double BeachOrientCost(CPiece p, int ox, int oy)
    {
        double[] a;
        if (!beachAxis.TryGetValue(p, out a))
        {
            double wx = 0, wy = 0, lx = 0, ly = 0; int nw = 0, nl = 0;
            foreach (TmpCell tc in p.Tmp.Cells)
            {
                if (tc == null) continue;
                int cx = tc.Index % p.Tmp.Width, cy = tc.Index / p.Tmp.Width;
                if (Wet(tc)) { wx += cx; wy += cy; nw++; } else { lx += cx; ly += cy; nl++; }
            }
            a = nw == 0 || nl == 0 ? null : new double[] { wx / nw, wy / nw, lx / nl, ly / nl };
            beachAxis[p] = a;
        }
        if (a == null) return 0;
        double dx = a[0] - a[2], dy = a[1] - a[3], len = Math.Sqrt(dx * dx + dy * dy);
        if (len < 0.1) return 0;
        dx /= len; dy /= len;
        double c = 0;
        int sx = ox + (int)Math.Round(a[0] + 2 * dx), sy = oy + (int)Math.Round(a[1] + 2 * dy);
        int tx = ox + (int)Math.Round(a[2] - 2 * dx), ty = oy + (int)Math.Round(a[3] - 2 * dy);
        if (In(sx, sy) && Visible[Idx(sx, sy)] && K[Idx(sx, sy)] != Kind.Water) c += 4;
        if (In(tx, ty) && Visible[Idx(tx, ty)] && K[Idx(tx, ty)] == Kind.Water) c += 4;
        return c;
    }

    // Small bits of plain land left on the sea side of a shore chain (4-connected, touching water) become water.
    public int DrownSpecks(int maxSize)
    {
        int n = 0;
        foreach (List<int> comp in Components(delegate (int i) { return K[i] != Kind.Water && !Used[i]; }, false))
        {
            if (comp.Count > maxSize) continue;
            bool sea = false;
            foreach (int i in comp)
            {
                int x = i % N, y = i / N;
                for (int d = 0; d < 8 && !sea; d += 2)
                {
                    int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d];
                    if (!In(nx, ny)) continue;
                    int j = Idx(nx, ny);
                    if (K[j] == Kind.Water && !Used[j] || UsedWater[j]) sea = true;
                }
                if (sea) break;
            }
            if (!sea) continue;
            foreach (int i in comp) { K[i] = Kind.Water; n++; }
        }
        Log.Add("land specks on the sea side turned to water: " + n);
        return n;
    }

    // Removes ground islands of a single cell and smooths ragged LAT edges (cells with <= 2 of 8 alike).
    public void SmoothGround(int passes)
    {
        for (int pass = 0; pass < passes; pass++)
        {
            int[] g2 = (int[])Ground.Clone();
            for (int y = 1; y < N - 1; y++) for (int x = 1; x < N - 1; x++)
            {
                int i = Idx(x, y); if (!Valid[i]) continue;
                int[] votes = new int[4];
                for (int d = 0; d < 8; d++) { int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d]; if (In(nx, ny)) votes[Ground[Idx(nx, ny)]]++; }
                if (votes[Ground[i]] <= 2) { int bestG = 0; for (int g = 1; g < 4; g++) if (votes[g] > votes[bestG]) bestG = g; g2[i] = bestG; }
            }
            Ground = g2;
        }
    }

    // free plain ground: valid, visible, not water, not under a cliff/shore piece, no object
    public bool Free(int x, int y)
    {
        if (!In(x, y)) return false;
        int i = Idx(x, y);
        return Visible[i] && !Used[i] && K[i] != Kind.Water && !Ramp[i] && !Reserved.Contains(i) && !Occupied.ContainsKey(i)
            && Overlay[y * 512 + x] == 255 && !Terrain.ContainsKey(y * 1000 + x);
    }

    public void Reserve(double u, double v, int rx, int ry)
    {
        int c = CellAt(u, v), cx = c % N, cy = c / N;
        for (int y = cy - ry; y <= cy + ry; y++) for (int x = cx - rx; x <= cx + rx; x++) if (In(x, y)) Reserved.Add(Idx(x, y));
    }

    // Building with a WxH foundation whose top cell is at (x, y); every cell must be free and on one plateau level.
    public bool PlaceBuilding(string house, string type, int fw, int fh, int x, int y)
    {
        int p0 = In(x, y) ? Plateau[Idx(x, y)] : -2;
        for (int yy = y - 1; yy <= y + fh; yy++) for (int xx = x - 1; xx <= x + fw; xx++)
        {
            bool core = xx >= x && yy >= y && xx < x + fw && yy < y + fh;
            if (core && (!Free(xx, yy) || Plateau[Idx(xx, yy)] != p0)) return false;
            if (!core && In(xx, yy) && Occupied.ContainsKey(Idx(xx, yy))) return false;   // one cell of street between buildings
        }
        for (int yy = y; yy < y + fh; yy++) for (int xx = x; xx < x + fw; xx++) Occupied[Idx(xx, yy)] = type;
        Buildings.Add(house + "," + type + ",256," + x + "," + y + ",64,None,1,0,1,0,0,None,None,None,0,0");
        return true;
    }

    // ScToDta.Passable treats every structure as 2x2, so buildings join [Structures] only before WriteMap
    public void FlushBuildings() { Structures.AddRange(Buildings); Buildings.Clear(); }

    // Trees where the zone label matches, with the given probability; never on pavement, ramps or reserved cells.
    public int PlaceTrees(byte zone, string[] types, double p)
    {
        int n = 0;
        for (int y = 0; y < N && y < 512; y++) for (int x = 0; x < N && x < 512; x++)
        {
            if (!Free(x, y)) continue;
            int i = Idx(x, y);
            if (Zone[i] != zone || Ground[i] == Pave || Rnd.NextDouble() >= p) continue;
            bool nearRamp = false;
            for (int d = 0; d < 8; d++) { int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d]; if (In(nx, ny) && Ramp[Idx(nx, ny)]) nearRamp = true; }
            if (nearRamp) continue;
            Terrain[y * 1000 + x] = types[Rnd.Next(types.Length)]; n++;
        }
        return n;
    }

    // Overlay along a list of cells (walls, resources). Returns cells actually set.
    public int OverlayCells(List<int> cells, byte id, byte data)
    {
        int n = 0;
        foreach (int c in cells)
        {
            int x = c % N, y = c / N;
            if (!Free(x, y) || Ground[c] == Pave && id != 2) continue;
            Overlay[y * 512 + x] = id; OverlayData[y * 512 + x] = data; n++;
        }
        return n;
    }

    // Cells along a straight design segment, 4-connected (walls join only N/E/S/W).
    public List<int> CellLine(double u0, double v0, double u1, double v1)
    {
        List<int> res = new List<int>();
        int steps = (int)(Math.Max(Math.Abs(u1 - u0) * ScaleX / 12, Math.Abs(v1 - v0) * ScaleY / 6)) + 1;
        int last = -1;
        for (int s = 0; s <= steps; s++)
        {
            double t = (double)s / steps;
            int c = CellAt(u0 + (u1 - u0) * t, v0 + (v1 - v0) * t);
            if (c == last) continue;
            if (last >= 0)
            {
                int lx = last % N, ly = last / N, cx = c % N, cy = c / N;
                if (lx != cx && ly != cy) { int m = Idx(cx, ly); if (!res.Contains(m)) res.Add(m); }
            }
            if (!res.Contains(c)) res.Add(c);
            last = c;
        }
        return res;
    }

    // Free cells in a design-space disc (resource fields).
    public List<int> CellDisc(double u, double v, double r)
    {
        List<int> res = new List<int>();
        int c = CellAt(u, v), cx = c % N, cy = c / N;
        int rr = (int)(r * Math.Max(ScaleX / 24, ScaleY / 12)) + 2;
        for (int y = cy - rr; y <= cy + rr; y++) for (int x = cx - rr; x <= cx + rr; x++)
        {
            if (!In(x, y)) continue;
            double pu, pv; Design(x, y, out pu, out pv);
            if ((pu - u) * (pu - u) + (pv - v) * (pv - v) <= r * r) res.Add(Idx(x, y));
        }
        return res;
    }

    // Nearest cell (by ring distance) that is passable ground, or open water when water is set.
    public int Nearest(int c, bool water)
    {
        bool[] pass = Passable();
        int cx = c % N, cy = c / N;
        for (int r = 0; r < 12; r++)
            for (int y = cy - r; y <= cy + r; y++) for (int x = cx - r; x <= cx + r; x++)
            {
                if (Math.Max(Math.Abs(x - cx), Math.Abs(y - cy)) != r || !In(x, y)) continue;
                int i = Idx(x, y);
                if (!Visible[i]) continue;
                if (water ? LandCode(i) == 9 : pass[i] && K[i] != Kind.Water) return i;
            }
        return -1;
    }

    // terrain code of the placed tile cell (0 clear, 7/8 rock, 9 water, ...)
    public int LandCode(int i)
    {
        Tmp t = Th.Get(Tile[i] < 0 ? 0 : Tile[i]);
        if (t == null || Sub[i] >= t.Cells.Length || t.Cells[Sub[i]] == null) return 0;
        return t.Cells[Sub[i]].Terrain;
    }

    // Ground reachability between named cells (after all objects are placed).
    public bool Connected(int a, int b)
    {
        bool[] pass = Passable();
        if (!pass[a] || !pass[b]) return false;
        return new HashSet<int>(Reach(pass, a)).Contains(b);
    }

    public new bool[] Passable()
    {
        bool[] pass = base.Passable();
        foreach (int c in Occupied.Keys) pass[c] = false;
        return pass;
    }
}
