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

    // Nearest pixel (within r) labelled a that touches a pixel labelled b: {u, v}, or null.
    public double[] NearestEdge(double u, double v, byte a, byte b, int r)
    {
        int cx = (int)u - U0, cy = (int)v - V0; double best = double.MaxValue; double[] res = null;
        for (int y = Math.Max(1, cy - r); y <= Math.Min(H - 2, cy + r); y++)
            for (int x = Math.Max(1, cx - r); x <= Math.Min(W - 2, cx + r); x++)
            {
                int i = y * W + x;
                if (L[i] != a || (L[i - 1] != b && L[i + 1] != b && L[i - W] != b && L[i + W] != b)) continue;
                double d = (x - cx) * (x - cx) + (y - cy) * (y - cy);
                if (d < best) { best = d; res = new double[] { x + U0 + 0.5, y + V0 + 0.5 }; }
            }
        return res;
    }

    public void Disc(double u, double v, double r, byte val, byte only)
    {
        for (int y = Math.Max(0, (int)(v - r) - V0); y <= Math.Min(H - 1, (int)(v + r) - V0 + 1); y++)
            for (int x = Math.Max(0, (int)(u - r) - U0); x <= Math.Min(W - 1, (int)(u + r) - U0 + 1); x++)
            {
                double du = x + U0 + 0.5 - u, dv = y + V0 + 0.5 - v;
                if (du * du + dv * dv <= r * r && (only == 255 || L[y * W + x] == only)) L[y * W + x] = val;
            }
    }

    // Pixels of label `from` closer than dist to a pixel of label `to` become val (e.g. land near the sea).
    public void NearLabel(byte from, byte to, double dist, byte val, double minU, double maxU, double minV, double maxV)
    {
        float[] d = GeoRef.EdgeDistance(this, to);
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++)
        {
            int i = y * W + x; double u = x + U0, v = y + V0;
            if (L[i] == from && d[i] <= dist && u >= minU && u <= maxU && v >= minV && v <= maxV) L[i] = val;
        }
    }

    // pixels whose grid value (same geometry, e.g. Dem.Grid elevation) is >= min get val (only over `only`)
    public void FromGrid(float[] grid, float min, byte val, byte only)
    {
        for (int i = 0; i < L.Length; i++) if (grid[i] >= min && (only == 255 || L[i] == only)) L[i] = val;
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
    // kind labels (KHigh2 = second plateau level on top of KHigh, e.g. a mountain crest)
    public const byte KWater = 0, KLow = 1, KHigh = 2, KRamp = 3, KHigh2 = 4;
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
        return In(x, y) ? Idx(x, y) : -1;   // -1: off the map (Idx would wrap into another row)
    }

    public override bool LocalWalk(int a, int b) { return Ramp[a] || Ramp[b]; }

    public void Classify(Layer kind, Layer ground, Layer zone, int minPlateau) { Classify(kind, ground, zone, null, minPlateau); }

    // kind: majority of 5 samples in the cell diamond; ground, zone and ramp (label != 0): centre sample.
    // A ramp layer marks cells whose plateau edges get no cliff, without changing their level.
    public void Classify(Layer kind, Layer ground, Layer zone, Layer ramp, int minPlateau)
    {
        double hu = 12.0 / ScaleX, hv = 6.0 / ScaleY;   // a quarter of the cell diamond, in design px
        Ground = new int[K.Length];
        for (int i = 0; i < K.Length; i++)
        {
            if (!Valid[i]) continue;
            double u, v; Design(i % N, i / N, out u, out v);
            int[] votes = new int[5];
            votes[kind.Get(u, v)] += 2;
            votes[kind.Get(u - hu, v)]++; votes[kind.Get(u + hu, v)]++; votes[kind.Get(u, v - hv)]++; votes[kind.Get(u, v + hv)]++;
            int high = votes[KHigh] + votes[KHigh2];
            int land = votes[KLow] + votes[KRamp] + high;
            if (votes[KWater] > land) K[i] = Kind.Water;
            else if (high > votes[KLow] + votes[KRamp]) { K[i] = Kind.High; Lev[i] = votes[KHigh2] * 2 > high ? 2 : 1; }
            else { K[i] = Kind.Low; Ramp[i] = votes[KRamp] >= 2; }
            if (ramp != null && ramp.Get(u, v) != 0) Ramp[i] = true;
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
        // plateaus per level, highest first (as ScToDta.Classify): a small level-2 bump joins level 1
        int id = 0;
        for (int lv = 2; lv >= 1; lv--)
        {
            int level = lv;
            foreach (List<int> comp in Components(delegate (int i) { return K[i] == Kind.High && Lev[i] == level; }, false))
            {
                if (comp.Count < minPlateau) { foreach (int i in comp) { if (level == 2) Lev[i] = 1; else K[i] = Kind.Low; } continue; }
                foreach (int i in comp) Plateau[i] = id;
                PlateauLevel.Add(level);
                id++;
            }
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
    // A second call with land = any cell and BeachMinArc = 2 closes the gaps where a beach chain meets a
    // water-cliff chain (otherwise grass touches the water in a straight saw-tooth there).
    public int BeachMinArc = 4;

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
                if (arc.Path.Count < BeachMinArc) continue;
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

    // ------------------------------------------------------------ roads from real road tiles
    // Cells along a design polyline (no duplicates, 8-connected steps).
    public List<int> CellPath(double[] p)
    {
        List<int> res = new List<int>();
        for (int k = 0; k + 3 < p.Length; k += 2)
        {
            List<int> seg = CellLine(p[k], p[k + 1], p[k + 2], p[k + 3]);
            foreach (int c in seg) if (res.Count == 0 || res[res.Count - 1] != c) res.Add(c);
        }
        return res;
    }

    public int RoadsChained, RoadsPaved, RoadCellsPaved;
    public HashSet<int> RoadAvoid = new HashSet<int>();   // cells roads should not cross (building plots)
    int roadLevel;

    double RoadCellCost(CPiece p, int i, TmpCell tc)
    {
        if (K[i] == Kind.Water || RoadAvoid.Contains(i)) return 30;
        if (!Ramp[i] && (Plateau[i] < 0 ? 0 : PlateauLevel[Plateau[i]]) != roadLevel) return 30;
        return Occupied.ContainsKey(i) ? 30 : 0;
    }

    // One road (design polyline): split where it changes plateau level outside a ramp, chain each run with the
    // road tile set; runs that fail (or are too short) become pavement LAT instead.
    public void Road(ConnectedSet cs, double[] p, int trim)
    {
        List<int> path = CellPath(p);
        if (path.Count > 2 * trim + 2) path = path.GetRange(trim, path.Count - 2 * trim);
        List<int> run = new List<int>(); int lvl = -1;
        foreach (int c in path)
        {
            // points off the map (OSM data beyond the design) give indices outside the arrays
            if (c < 0 || c >= K.Length || !Valid[c] || !Visible[c] || K[c] == Kind.Water) { RoadRun(cs, run, lvl); run = new List<int>(); lvl = -1; continue; }
            int l = Plateau[c] < 0 ? 0 : PlateauLevel[Plateau[c]];
            if (lvl >= 0 && l != lvl && !Ramp[c]) { RoadRun(cs, run, lvl); run = new List<int>(); }
            if (run.Count == 0 || !Ramp[c]) lvl = l;
            run.Add(c);
        }
        RoadRun(cs, run, lvl);
    }

    void RoadRun(ConnectedSet cs, List<int> run, int lvl)
    {
        if (run.Count < 2) return;
        bool ok = false;
        if (run.Count >= 6)
        {
            Arc arc = new Arc(); arc.Path = run; roadLevel = lvl;
            ok = Chain(cs, arc, 2, RoadCellCost, null, false);
        }
        if (ok) { RoadsChained++; return; }
        RoadsPaved++;
        foreach (int c in run) if (!Used[c] && K[c] != Kind.Water) { Ground[c] = Pave; RoadCellsPaved++; }
    }

    // Pavement disc (junctions, squares) on free cells.
    public void PaveAt(double u, double v, double r)
    {
        foreach (int c in CellDisc(u, v, r)) if (!Used[c] && K[c] != Kind.Water) Ground[c] = Pave;
    }

    // ------------------------------------------------------------ roads as Paved Road LAT (the DTA way)
    // DTA missions paint roads as Paved Road LAT (dark asphalt, soft edges; se03/se04/reclamation) and every road
    // leads somewhere: into another road, off the map edge, or into a square / parking lot. OSM main roads alone end
    // wherever a smaller street joined them, and road tiles that A* could not lay broke them into stubs ("roads to
    // nowhere", review 2026-10-27). So: collect the runs (RoadLat), then FinishRoads links or trims every free end.
    public const int RoadG = 4;   // Ground value of a paved road (LAT); pavement plazas stay Pave
    List<List<int>> roadRuns = new List<List<int>>();
    List<int> roadRunLevel = new List<int>();
    public int RoadsLinked, RoadsTrimmed, RoadsDropped, RoadCells;

    int LevelOf(int c) { return Plateau[c] < 0 ? 0 : PlateauLevel[Plateau[c]]; }

    bool RoadOk(int c, int lvl)
    {
        return c >= 0 && c < K.Length && Valid[c] && Visible[c] && K[c] != Kind.Water && !Used[c] && !RoadAvoid.Contains(c)
            && (Ramp[c] || LevelOf(c) == lvl);
    }

    // One road (design polyline): cut where it leaves the land, hits a cliff or a kept-free plot, or changes level
    // outside a ramp; each piece of 3+ cells is a run. A path cell on a cliff, the shore or a plot moves to the nearest
    // allowed cell within 2 (OSM lines along a narrow lane, e.g. Sir Herbert Road under the Rock, lie on the cliff
    // cells and broke into specks); a jump left by the move is bridged by a straight piece.
    public void RoadLat(double[] p)
    {
        List<int> run = new List<int>(); int lvl = -1;
        foreach (int c0 in CellPath(p))
        {
            int c = c0;
            if (c < 0 || c >= K.Length) { AddRun(run, lvl); run = new List<int>(); lvl = -1; continue; }
            if (!RoadOk(c, LevelOf(c))) c = SnapRoad(c, run.Count > 0 ? lvl : -1);
            if (c < 0) { AddRun(run, lvl); run = new List<int>(); lvl = -1; continue; }
            int l = LevelOf(c);
            if (run.Count > 0 && !Ramp[c] && l != lvl) { AddRun(run, lvl); run = new List<int>(); }
            if (run.Count == 0 || !Ramp[c]) lvl = l;
            if (run.Count > 0)
            {
                int last = run[run.Count - 1];
                if (last == c || run.Contains(c)) continue;
                if (Math.Max(Math.Abs(last % N - c % N), Math.Abs(last / N - c / N)) > 1)
                {
                    List<int> gap = StraightPath(last, c, lvl);
                    if (gap == null) { AddRun(run, lvl); run = new List<int>(); }
                    else { gap.RemoveAt(gap.Count - 1); foreach (int g in gap) if (!run.Contains(g)) run.Add(g); }
                }
            }
            run.Add(c);
        }
        AddRun(run, lvl);
    }

    // nearest allowed road cell within 2 of c (on level lvl, or any level when lvl < 0), or -1
    int SnapRoad(int c, int lvl)
    {
        int x = c % N, y = c / N;
        for (int r = 1; r <= 2; r++)
            for (int yy = y - r; yy <= y + r; yy++) for (int xx = x - r; xx <= x + r; xx++)
            {
                if (Math.Max(Math.Abs(xx - x), Math.Abs(yy - y)) != r || !In(xx, yy)) continue;
                int i = Idx(xx, yy);
                if (RoadOk(i, lvl < 0 ? LevelOf(i) : lvl)) return i;
            }
        return -1;
    }

    void AddRun(List<int> run, int lvl) { if (run.Count >= 3) { roadRuns.Add(run); roadRunLevel.Add(lvl); } }

    // a run is 2 cells wide: each path cell plus its +x, +y and +x+y neighbours on the same level
    HashSet<int> RunCells(int r)
    {
        HashSet<int> s = new HashSet<int>();
        foreach (int c in roadRuns[r])
        {
            int x = c % N, y = c / N;
            for (int k = 0; k < 4; k++) { int nx = x + (k & 1), ny = y + (k >> 1); if (In(nx, ny) && RoadOk(Idx(nx, ny), roadRunLevel[r])) s.Add(Idx(nx, ny)); }
        }
        return s;
    }

    bool NearEdge(int c, int r)
    {
        int x = c % N, y = c / N;
        for (int yy = y - r; yy <= y + r; yy++) for (int xx = x - r; xx <= x + r; xx++) if (!In(xx, yy) || !Visible[Idx(xx, yy)]) return true;
        return false;
    }

    // pavement cells round c on c's level (a square only counts on the same side of a cliff)
    int PaveAround(int c, int r)
    {
        int x = c % N, y = c / N, n = 0, lvl = LevelOf(c);
        for (int yy = y - r; yy <= y + r; yy++) for (int xx = x - r; xx <= x + r; xx++)
        {
            if (!In(xx, yy)) continue;
            int i = Idx(xx, yy);
            if (Ground[i] == Pave && K[i] != Kind.Water && !Used[i] && LevelOf(i) == lvl) n++;
        }
        return n;
    }
    const int SquareCells = 12;   // pavement cells within 3 that make a square a road may end in

    // cells of all runs except one: cell -> run index
    Dictionary<int, int> OtherCells(List<HashSet<int>> cells, int skip)
    {
        Dictionary<int, int> d = new Dictionary<int, int>();
        for (int r = 0; r < cells.Count; r++) if (r != skip && cells[r] != null) foreach (int c in cells[r]) d[c] = r;
        return d;
    }

    // another road within r of c on the same level (a road beyond a cliff does not count)
    bool Touches(Dictionary<int, int> other, int c, int r, int lvl)
    {
        int x = c % N, y = c / N;
        for (int yy = y - r; yy <= y + r; yy++) for (int xx = x - r; xx <= x + r; xx++)
            if (In(xx, yy) && other.ContainsKey(Idx(xx, yy)) && (Ramp[Idx(xx, yy)] || LevelOf(Idx(xx, yy)) == lvl)) return true;
        return false;
    }

    // an end is joined when its 2x2 piece (e, +x, +y) shares a cell side with another road cell on its level
    // (a corner-only contact renders as a grass gap between the two LAT roads)
    bool Joined(Dictionary<int, int> other, int e, int lvl)
    {
        int x = e % N, y = e / N;
        int[] NX = { 0, 1, 0, -1 }, NY = { -1, 0, 1, 0 };
        for (int k = 0; k < 4; k++)
            for (int d = 0; d < 5; d++)
            {
                int nx = x + (k & 1) + (d < 4 ? NX[d] : 0), ny = y + (k >> 1) + (d < 4 ? NY[d] : 0);
                if (!In(nx, ny)) continue;
                int i = Idx(nx, ny);
                if (other.ContainsKey(i) && (Ramp[i] || LevelOf(i) == lvl)) return true;
            }
        return false;
    }

    // straight cell path a -> b (8-connected steps; diagonal steps also take the side cell so the road stays joined)
    List<int> StraightPath(int a, int b, int lvl)
    {
        List<int> res = new List<int>();
        int x = a % N, y = a / N, bx = b % N, by = b / N;
        while (x != bx || y != by)
        {
            int sx = Math.Sign(bx - x), sy = Math.Sign(by - y);
            if (Math.Abs(bx - x) > Math.Abs(by - y) * 2) sy = 0; else if (Math.Abs(by - y) > Math.Abs(bx - x) * 2) sx = 0;
            if (sx != 0 && sy != 0) { if (!In(x + sx, y)) return null; int side = Idx(x + sx, y); if (!RoadOk(side, lvl)) return null; res.Add(side); }
            x += sx; y += sy;
            if (!In(x, y)) return null;
            int c = Idx(x, y); if (!RoadOk(c, lvl)) return null;
            res.Add(c);
        }
        return res;
    }

    // An end is anchored when it reaches the map edge (the road goes on off the map), another road, or a square
    // (6+ pavement cells round it: port, parking, plaza). A free end is linked to the nearest road within maxLink
    // cells by a straight piece; failing that the run is cut back to its last junction, or dropped when it touches no
    // other road at all. Repeated until nothing changes (a dropped run can free other ends).
    public void FinishRoads(int maxLink, int minComponent)
    {
        List<HashSet<int>> cells = new List<HashSet<int>>();
        for (int r = 0; r < roadRuns.Count; r++) cells.Add(RunCells(r));
        for (int pass = 0; pass < 12; pass++)
        {
            bool changed = false;
            for (int r = 0; r < roadRuns.Count; r++)
            {
                if (cells[r] == null) continue;
                Dictionary<int, int> other = OtherCells(cells, r);
                for (int end = 0; end < 2 && cells[r] != null; end++)
                {
                    List<int> path = roadRuns[r]; int lvl = roadRunLevel[r];
                    int e = end == 0 ? path[0] : path[path.Count - 1];
                    if (Joined(other, e, lvl) || NearEdge(e, 3)) continue;
                    // link: nearest other road cell within maxLink, reachable by a straight piece on this level
                    int best = -1, bd = int.MaxValue; List<int> link = null;
                    foreach (KeyValuePair<int, int> kv in other)
                    {
                        int dx = kv.Key % N - e % N, dy = kv.Key / N - e / N, d = Math.Max(Math.Abs(dx), Math.Abs(dy));
                        if (d > maxLink || d >= bd) continue;
                        List<int> sp = StraightPath(e, kv.Key, roadRunLevel[r]);
                        if (sp == null) continue;
                        best = kv.Key; bd = d; link = sp;
                    }
                    if (link != null)
                    {
                        if (end == 0) { link.Reverse(); path.InsertRange(0, link); } else path.AddRange(link);
                        cells[r] = RunCells(r); RoadsLinked++; changed = true; continue;
                    }
                    if (PaveAround(e, 3) >= SquareCells) continue;   // ends in a square / parking / quay
                    // trim back to the last path cell that touches another road
                    int k = -1;
                    for (int j = 0; j < path.Count; j++) { int idx = end == 0 ? j : path.Count - 1 - j; if (Touches(other, path[idx], 1, lvl)) { k = idx; break; } }
                    if (k < 0) { cells[r] = null; RoadsDropped++; changed = true; break; }
                    if (end == 0) path.RemoveRange(0, k); else path.RemoveRange(k + 1, path.Count - k - 1);
                    if (path.Count < 2) { cells[r] = null; RoadsDropped++; changed = true; break; }
                    cells[r] = RunCells(r); RoadsTrimmed++; changed = true;
                }
            }
            if (!changed) break;
        }
        HashSet<int> all = new HashSet<int>();
        foreach (HashSet<int> s in cells) if (s != null) all.UnionWith(s);
        // small islands of road that reach neither the edge nor a square are dropped too
        foreach (List<int> comp in Components(delegate (int i) { return all.Contains(i); }, true))
        {
            if (comp.Count >= minComponent) continue;
            bool keep = false; foreach (int c in comp) if (NearEdge(c, 3) || PaveAround(c, 3) >= SquareCells) { keep = true; break; }
            if (!keep) foreach (int c in comp) all.Remove(c);
        }
        foreach (int c in all) Ground[c] = RoadG;
        RoadCells = all.Count;
        // review list: ends that stop in a square, and ends left free (none expected)
        SquareEnds.Clear(); OpenEnds.Clear();
        int kept = 0;
        for (int r = 0; r < roadRuns.Count; r++)
        {
            if (cells[r] == null) continue;
            kept++;
            Dictionary<int, int> other = OtherCells(cells, r);
            foreach (int e in new int[] { roadRuns[r][0], roadRuns[r][roadRuns[r].Count - 1] })
            {
                if (!all.Contains(e) || Joined(other, e, roadRunLevel[r]) || NearEdge(e, 3)) continue;
                if (PaveAround(e, 3) >= SquareCells) SquareEnds.Add(e); else OpenEnds.Add(e);
            }
        }
        Log.Add(string.Format("roads (LAT): {0} runs, {1} kept, {2} ends linked, {3} trimmed, {4} runs dropped, {5} cells; ends in a square {6}, free ends {7}",
            roadRuns.Count, kept, RoadsLinked, RoadsTrimmed, RoadsDropped, RoadCells, SquareEnds.Count, OpenEnds.Count));
    }
    public List<int> SquareEnds = new List<int>(), OpenEnds = new List<int>();
    // LAT with paved roads: as ApplyGround, but pavement counts a road next to it as its own ground (no grass seam),
    // and a road cell whose differing neighbours are all pavement takes the Pavement/Paved Road LAT.
    public void ApplyGroundRoads(int clear, int[] baseTile, int[] latStart, int roadOnPaveLat)
    {
        ApplyGround(clear, baseTile, latStart);
        int[] NX = { 0, 1, 0, -1 }, NY = { -1, 0, 1, 0 };
        for (int y = 0; y < N; y++) for (int x = 0; x < N; x++)
        {
            int i = Idx(x, y);
            if (!Valid[i] || Used[i]) continue;
            int g = Ground[i];
            if (g != Pave && g != RoadG) continue;
            int mask = 0; bool onlyPave = true;
            for (int d = 0; d < 4; d++)
            {
                int nx = x + NX[d], ny = y + NY[d];
                int n = In(nx, ny) ? Idx(nx, ny) : -1;
                if (n < 0) continue;
                bool same = !Used[n] && K[n] != Kind.Water && (Ground[n] == g || g == Pave && Ground[n] == RoadG);
                if (same) continue;
                mask |= 1 << d;
                if (Used[n] || K[n] == Kind.Water || Ground[n] != Pave) onlyPave = false;
            }
            Tile[i] = mask == 0 ? baseTile[g] : (g == RoadG && onlyPave ? roadOnPaveLat : latStart[g]) + mask;
            Sub[i] = 0;
        }
    }

    // ------------------------------------------------------------ coast check
    // Land cells (not under a shore/cliff piece) that touch a plain water tile: the coast has no shore piece
    // there, the edge is a raw saw-tooth of diamonds. Returns the cells.
    public List<int> RawCoast()
    {
        List<int> res = new List<int>();
        for (int y = 1; y < N - 1; y++) for (int x = 1; x < N - 1; x++)
        {
            int i = Idx(x, y);
            if (!Valid[i] || !Visible[i] || Used[i] || K[i] == Kind.Water) continue;
            bool raw = false;
            for (int d = 0; d < 8 && !raw; d += 2)
            {
                int j = Idx(x + ConnectedSet.DX[d], y + ConnectedSet.DY[d]);
                if (Valid[j] && Visible[j] && LandCode(j) == 9 && !UsedWater[j] && (Tile[j] < 0 || !IsShorePiece(j))) raw = true;
            }
            if (raw) res.Add(i);
        }
        return res;
    }

    HashSet<int> shorePieceCells;
    bool IsShorePiece(int j) { return shorePieceCells != null && shorePieceCells.Contains(j); }

    // Remember which cells belong to coast chains (before FillWater adds plain water to Used).
    public void MarkCoastPieces() { shorePieceCells = new HashSet<int>(); for (int i = 0; i < Used.Length; i++) if (Used[i]) shorePieceCells.Add(i); }

    // Raw coast cells that stick out (2+ water neighbours) become water, a few passes; returns cells drowned.
    public int DrownRawCoast(int passes, int plainWater)
    {
        int n = 0;
        for (int pass = 0; pass < passes; pass++)
        {
            List<int> raw = RawCoast(); int got = 0;
            foreach (int i in raw)
            {
                if (Used[i] || Terrain.ContainsKey((i / N) * 1000 + i % N) || Occupied.ContainsKey(i)) continue;
                int x = i % N, y = i / N, w = 0;
                for (int d = 0; d < 8; d += 2) { int j = Idx(x + ConnectedSet.DX[d], y + ConnectedSet.DY[d]); if (Valid[j] && LandCode(j) == 9) w++; }
                if (w < 2) continue;
                K[i] = Kind.Water; Used[i] = true; Tile[i] = plainWater; Sub[i] = 0; got++;
                if (x < 512 && y < 512) { Overlay[y * 512 + x] = 255; OverlayData[y * 512 + x] = 0; }
            }
            n += got;
            if (got == 0) break;
        }
        Log.Add("raw coast cells drowned: " + n);
        return n;
    }

    // ------------------------------------------------------------ buildings from a coverage layer
    // Share of the 5 cell samples whose label is val.
    public double Cover(Layer l, int i, byte val)
    {
        double hu = 12.0 / ScaleX, hv = 6.0 / ScaleY, u, v; Design(i % N, i / N, out u, out v);
        int c = 0;
        if (l.Get(u, v) == val) c++; if (l.Get(u - hu, v) == val) c++; if (l.Get(u + hu, v) == val) c++;
        if (l.Get(u, v - hv) == val) c++; if (l.Get(u, v + hv) == val) c++;
        return c / 5.0;
    }

    // Buildings of random types (all with foundation fw x fh) on cells covered by label val, in a shuffled order.
    public int PlaceOnCover(Layer cover, byte val, string[] types, int fw, int fh, double minShare, double p, string house)
    {
        List<int> cells = new List<int>();
        for (int i = 0; i < K.Length; i++) if (Valid[i] && Visible[i] && K[i] != Kind.Water && Cover(cover, i, val) >= minShare) cells.Add(i);
        for (int k = cells.Count - 1; k > 0; k--) { int j = Rnd.Next(k + 1); int t = cells[k]; cells[k] = cells[j]; cells[j] = t; }
        int n = 0;
        foreach (int c in cells)
        {
            if (Rnd.NextDouble() >= p) continue;
            if (PlaceBuilding(house, types[Rnd.Next(types.Length)], fw, fh, c % N, c / N)) n++;
        }
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
                int i = Idx(x, y); if (!Valid[i] || Ground[i] == RoadG) continue;   // roads are exact, never smoothed
                int[] votes = new int[5];
                for (int d = 0; d < 8; d++) { int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d]; if (In(nx, ny) && Ground[Idx(nx, ny)] != RoadG) votes[Ground[Idx(nx, ny)]]++; }
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
        // LAT roads are plain ground cells: buildings, trees and ore keep off them explicitly
        return Visible[i] && !Used[i] && K[i] != Kind.Water && !Ramp[i] && !Reserved.Contains(i) && !Occupied.ContainsKey(i)
            && (Ground == null || Ground[i] != RoadG) && Overlay[y * 512 + x] == 255 && !Terrain.ContainsKey(y * 1000 + x);
    }

    public void Reserve(double u, double v, int rx, int ry)
    {
        int c = CellAt(u, v), cx = c % N, cy = c / N;
        for (int y = cy - ry; y <= cy + ry; y++) for (int x = cx - rx; x <= cx + rx; x++) if (In(x, y)) Reserved.Add(Idx(x, y));
    }

    // All cells of a zone label become reserved (e.g. the player's base area: no trees, no civilian buildings).
    public int ReserveZone(byte zone)
    {
        int n = 0;
        for (int i = 0; i < Zone.Length; i++) if (Valid[i] && Zone[i] == zone && Reserved.Add(i)) n++;
        return n;
    }

    // Nearest passable cell on a plateau level (0 = low ground) to cell c, or -1.
    public int NearestOfLevel(int c, int level)
    {
        bool[] pass = Passable();
        int cx = c % N, cy = c / N;
        for (int r = 0; r < 14; r++)
            for (int y = cy - r; y <= cy + r; y++) for (int x = cx - r; x <= cx + r; x++)
            {
                if (Math.Max(Math.Abs(x - cx), Math.Abs(y - cy)) != r || !In(x, y)) continue;
                int i = Idx(x, y);
                if (!Visible[i] || !pass[i] || K[i] == Kind.Water) continue;
                int l = Plateau[i] < 0 ? 0 : PlateauLevel[Plateau[i]];
                if (l == level) return i;
            }
        return -1;
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
            if (c < 0) { last = -1; continue; }
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

    // Cells whose centre has label val in a design layer, on one plateau level (-1 = any): resource fields drawn
    // as polygons, e.g. ore on the Rock's level 1 that must not spill over the cliff to the town below.
    public List<int> CellsIn(Layer l, byte val, int level)
    {
        List<int> res = new List<int>();
        for (int i = 0; i < K.Length; i++)
        {
            if (!Valid[i] || !Visible[i] || K[i] == Kind.Water || level >= 0 && LevelOf(i) != level) continue;
            double u, v; Design(i % N, i / N, out u, out v);
            if (l.Get(u, v) == val) res.Add(i);
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
