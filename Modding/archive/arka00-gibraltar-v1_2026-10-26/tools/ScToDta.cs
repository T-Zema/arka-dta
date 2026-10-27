// Converts a StarCraft scenario (Chk + tileset) into a DTA (Tiberian Sun engine) multiplayer map.
// Geometry: SC pixels map to TS screen pixels at 3/4 scale, so one SC tile ~ one TS cell and the
// SC isometric diagonals stay TS isometric diagonals. DTA terrain is flat: SC high ground becomes
// areas fenced by DTA cliff pieces chained like WAE's connected-tile tool does.
// C# 5. Needs Casc.cs, ModTools.cs, ScMap.cs, TsMap.cs.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Text;

public enum Kind { Low, High, Cliff, Water, Block }

// ---------------------------------------------------------------- connected tile sets (WAE ConnectedTileDrawer.ini)
public class CPoint { public int X, Y, Dirs; public bool Front; }
public class CPiece
{
    public int Id;
    public List<int> Tiles = new List<int>();     // indices inside the tile set
    public List<CPoint> Points = new List<CPoint>();
    public Tmp Tmp;                                 // first variant, used for the footprint
}

public class ConnectedSet
{
    public string Name;
    public TileSetInfo Set;
    public List<CPiece> Pieces = new List<CPiece>();
    // N, NE, E, SE, S, SW, W, NW in TS cell coordinates (N = screen top-right)
    public static readonly int[] DX = { 0, 1, 1, 1, 0, -1, -1, -1 };
    public static readonly int[] DY = { -1, -1, 0, 1, 1, 1, 0, -1 };

    public ConnectedSet(string iniPath, string prefix, Theater th)
    {
        Name = prefix;
        Ini ini = Ini.Load(iniPath);
        for (int i = 0; ; i++)
        {
            string sec = prefix + "." + i;
            if (!ini.Has(sec)) break;
            CPiece p = new CPiece(); p.Id = i;
            string setName = ini.Get(sec, "TileSet", "").Split(';')[0].Trim();
            if (Set == null) Set = th.SetByName(setName);
            foreach (string t in ini.Get(sec, "TileIndices", "").Split(',')) { string s = t.Split(';')[0].Trim(); if (s.Length > 0) p.Tiles.Add(int.Parse(s)); }
            for (int k = 0; ; k++)
            {
                string pos = ini.Get(sec, "ConnectionPoint" + k, null);
                if (pos == null) break;
                string[] xy = pos.Split(';')[0].Split(',');
                CPoint c = new CPoint();
                c.X = int.Parse(xy[0].Trim()); c.Y = int.Parse(xy[1].Trim());
                string d = ini.Get(sec, "ConnectionPoint" + k + ".Directions", "").Split(';')[0].Trim();
                for (int b = 0; b < 8 && b < d.Length; b++) if (d[b] == '1') c.Dirs |= 1 << b;
                c.Front = ini.Get(sec, "ConnectionPoint" + k + ".Side", "Front").Trim().StartsWith("F", StringComparison.OrdinalIgnoreCase);
                p.Points.Add(c);
            }
            p.Tmp = th.Get(Set.Start + p.Tiles[0]);
            if (p.Tmp != null && p.Points.Count > 0) Pieces.Add(p);
        }
    }

    // High side of a cliff edge at a connection point, as a TS cell direction index.
    // E-W pieces (horizontal on screen): Front = high ground north (screen up), Back = south.
    // N-S pieces (vertical on screen, NW/SE connections): Front = high ground east, Back = west.
    public static int HighDir(CPoint p)
    {
        bool ns = (p.Dirs & ((1 << 7) | (1 << 3))) != 0;
        if (ns) return p.Front ? 1 : 5;   // NE (screen right) / SW (screen left)
        return p.Front ? 7 : 3;           // NW (screen up) / SE (screen down)
    }
}

public class Placement { public CPiece Piece; public int Tile, X, Y; }

// ---------------------------------------------------------------- the converter
public class ScToDta
{
    public Chk Chk; public ScTerrain Ter; public Theater Th; public Random Rnd = new Random(1998);
    public int PadX = 2, PadTop = 5, PadBottom = 4;
    public int W, H, N;                 // TS map Size and array stride
    public int LocalW, LocalH;          // visible area (LocalSize) after the padding
    public Kind[] K;                    // per cell kind (index y*N+x)
    public bool[] Valid, Visible;
    public int[] Rgb;                   // average SC colour of walkable minitiles
    public float[] Blue;                // share of bluish minitiles (water detection)
    public int[] Lev;                   // SC level of high cells: 1 mid, 2 high
    public List<int> PlateauLevel = new List<int>();
    public bool[] Bridge;               // narrow land between two waters (SC bridges), kept free of shore pieces
    public HashSet<int> Decor = new HashSet<int>();   // rock tiles placed as decoration (removable)
    public int[] Plateau;               // plateau component id per cell (-1 none)
    public bool[] Used;                 // cells taken by chained pieces
    public bool[] UsedWater;            // ...whose tile cell is water
    public int[] Tile, Sub;             // output iso map
    public byte[] Overlay, OverlayData;
    public List<string> Log = new List<string>();
    public List<Placement> Placed = new List<Placement>();
    public Dictionary<int, string> Terrain = new Dictionary<int, string>();   // cell -> terrain object
    public List<string> Structures = new List<string>();
    public List<int[]> Starts = new List<int[]>();
    public List<List<int>> DebugArcs = new List<List<int>>();

    public ScToDta(Chk chk, ScTerrain ter, Theater th)
    {
        Chk = chk; Ter = ter; Th = th;
        LocalW = chk.Width / 2; LocalH = chk.Height;
        Alloc(LocalW + 2 * PadX, LocalH + PadTop + PadBottom);
    }

    // Map without a StarCraft source (see DesignToDta): visible area localW x localH plus padding.
    // Valid and Visible are set here; the caller classifies the cells.
    protected ScToDta(Theater th, int localW, int localH, int padX, int padTop, int padBottom)
    {
        Th = th; PadX = padX; PadTop = padTop; PadBottom = padBottom;
        LocalW = localW; LocalH = localH;
        Alloc(localW + 2 * padX, localH + padTop + padBottom);
        for (int dy = 0; dy < 2 * H; dy++)
            for (int dx = dy & 1; dx <= 2 * W - 2; dx += 2)
            {
                int i = Idx((dx + dy + 2) / 2, (dy - dx + 2 * W) / 2);
                Valid[i] = true;
                double sx = (dx + 1) * 24.0, sy = (dy + 1) * 12.0;
                Visible[i] = sx > PadX * 48 && sy > PadTop * 24 && sx < (PadX + LocalW) * 48 && sy < (PadTop + LocalH) * 24;
            }
    }

    void Alloc(int w, int h)
    {
        W = w; H = h;
        N = W + H + 2;
        K = new Kind[N * N]; Valid = new bool[N * N]; Visible = new bool[N * N]; Rgb = new int[N * N]; Blue = new float[N * N]; Lev = new int[N * N]; Bridge = new bool[N * N];
        Plateau = new int[N * N]; Used = new bool[N * N]; UsedWater = new bool[N * N]; Tile = new int[N * N]; Sub = new int[N * N];
        Overlay = new byte[512 * 512]; OverlayData = new byte[512 * 512];
        for (int i = 0; i < Overlay.Length; i++) Overlay[i] = 255;
        for (int i = 0; i < Tile.Length; i++) Tile[i] = -1;
    }

    public int Idx(int x, int y) { return y * N + x; }
    public void ToScreen(int x, int y, out int dx, out int dy) { dx = x - y + W - 1; dy = x + y - W - 1; }
    public bool In(int x, int y) { return x >= 0 && y >= 0 && x < N && y < N && Valid[y * N + x]; }

    // SC pixel at the centre of a TS cell
    public void ScPixel(int x, int y, out double px, out double py)
    {
        int dx, dy; ToScreen(x, y, out dx, out dy);
        px = (dx + 1) * 32.0 - PadX * 64; py = (dy + 1) * 16.0 - PadTop * 32;
    }

    // TS cell whose centre is nearest to an SC pixel
    public void CellAt(double px, double py, out int x, out int y)
    {
        double dx = (px + PadX * 64) / 32.0 - 1, dy = (py + PadTop * 32) / 16.0 - 1;
        double fx = (dx + dy + 2) / 2.0, fy = (dy - dx + 2 * W) / 2.0;
        x = (int)Math.Round(fx); y = (int)Math.Round(fy);
    }

    // ------------------------------------------------------------ 1. classify cells
    public void Classify()
    {
        int mw = Ter.W, mh = Ter.H;
        for (int dy = 0; dy < 2 * H; dy++)
            for (int dx = dy & 1; dx <= 2 * W - 2; dx += 2)
            {
                int x = (dx + dy + 2) / 2, y = (dy - dx + 2 * W) / 2;
                int i = Idx(x, y);
                Valid[i] = true;
                double px = (dx + 1) * 32.0 - PadX * 64, py = (dy + 1) * 16.0 - PadTop * 32;
                Visible[i] = px > 0 && py > 0 && px < Chk.Width * 32 && py < Chk.Height * 32;
                int wl = 0, wh = 0, ul = 0, uh = 0, w2 = 0, blue = 0, all = 0; long r = 0, g = 0, b = 0; int nc = 0;
                int mx0 = (int)Math.Floor((px - 32) / 8), mx1 = (int)Math.Ceiling((px + 32) / 8);
                int my0 = (int)Math.Floor((py - 16) / 8), my1 = (int)Math.Ceiling((py + 16) / 8);
                for (int my = my0; my <= my1; my++) for (int mx = mx0; mx <= mx1; mx++)
                {
                    double cx = mx * 8 + 4, cy = my * 8 + 4;
                    if (Math.Abs(cx - px) / 32 + Math.Abs(cy - py) / 16 > 1) continue;
                    int qx = Math.Min(mw - 1, Math.Max(0, mx)), qy = Math.Min(mh - 1, Math.Max(0, my));
                    int m = qy * mw + qx;
                    bool walk = Ter.Walkable(m); int lv = Ter.Level(m);
                    Color mc = Color.FromArgb(Ter.Rgb[m]); all++;
                    if (mc.B > mc.R + 12 && mc.B > mc.G + 4) blue++;
                    if (walk)
                    {
                        if (lv > 0) wh++; else wl++;
                        if (lv == 2) w2++;
                        Color c = Color.FromArgb(Ter.Rgb[m]); r += c.R; g += c.G; b += c.B; nc++;
                    }
                    else { if (lv > 0) uh++; else ul++; }
                }
                Kind k;
                if (wl + wh >= ul + uh) k = wh > wl ? Kind.High : Kind.Low;
                else k = uh >= ul ? Kind.Cliff : Kind.Water;
                K[i] = k;
                Blue[i] = all > 0 ? (float)blue / all : 0;
                Lev[i] = k == Kind.High ? (w2 * 2 > wh ? 2 : 1) : 0;
                Rgb[i] = nc > 0 ? Color.FromArgb((int)(r / nc), (int)(g / nc), (int)(b / nc)).ToArgb() : 0;
            }
        // unwalkable low ground: big blue areas are water, the rest are obstacles (doodads, temple)
        foreach (List<int> comp in Components(delegate (int i) { return K[i] == Kind.Water; }, true))
        {
            // narrow channels have brown rock edges, so judge by the share of blue minitiles, not the mean colour
            double bf = 0; foreach (int i in comp) bf += Blue[i];
            bf /= comp.Count;
            bool water = comp.Count >= 40 && bf >= 0.12;
            if (comp.Count >= 40) Log.Add(string.Format("  unwalkable low area {0} cells, blue share {1:0.00} -> {2}", comp.Count, bf, water ? "water" : "obstacles"));
            if (!water) foreach (int i in comp) K[i] = Kind.Block;
        }
        // specks of land enclosed by water (sampling noise, tiny SC islets) become water
        foreach (List<int> comp in Components(delegate (int i) { return K[i] != Kind.Water; }, false))
        {
            if (comp.Count >= 30) continue;
            bool enclosed = true;
            foreach (int i in comp)
            {
                int x = i % N, y = i / N;
                for (int d = 0; d < 8 && enclosed; d += 2) { int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d]; if (!In(nx, ny)) enclosed = false; }
            }
            if (enclosed) foreach (int i in comp) K[i] = Kind.Water;
        }
        // high ground components per level (2 = SC high, 1 = SC mid), highest first; tiny ones are bumps
        int id = 0;
        for (int i = 0; i < Plateau.Length; i++) Plateau[i] = -1;
        for (int lv = 2; lv >= 1; lv--)
        {
            int level = lv;
            foreach (List<int> comp in Components(delegate (int i) { return K[i] == Kind.High && Lev[i] == level; }, false))
            {
                if (comp.Count < 25) { foreach (int i in comp) { if (level == 1) K[i] = Kind.Low; else Lev[i] = 1; } continue; }
                foreach (int i in comp) Plateau[i] = id;
                PlateauLevel.Add(level);
                id++;
            }
        }
        // cliff cells not next to any plateau (e.g. temple walls) are obstacles
        foreach (List<int> comp in Components(delegate (int i) { return K[i] == Kind.Cliff; }, true))
        {
            bool near = false;
            foreach (int i in comp) { if (NearPlateau(i, 2) >= 0) { near = true; break; } }
            if (!near) foreach (int i in comp) K[i] = Kind.Block;
        }
        FindBridges();
        int[] cnt = new int[5];
        for (int i = 0; i < K.Length; i++) if (Valid[i]) cnt[(int)K[i]]++;
        Log.Add(string.Format("cells: low {0} high {1} cliff {2} water {3} block {4}; plateaus {5}", cnt[0], cnt[1], cnt[2], cnt[3], cnt[4], id));
    }

    // SC bridges and narrow causeways: walkable cells with water within 2 cells whose 7x7 surroundings hold
    // two separate pieces of water (a bank of a winding channel sees one connected piece). They stay free of
    // shore pieces, so they remain passable, and are paved.
    public void FindBridges()
    {
        int n = 0;
        for (int i = 0; i < K.Length; i++)
        {
            if (!Valid[i] || (K[i] != Kind.Low && K[i] != Kind.High)) continue;
            int x = i % N, y = i / N;
            if (!NearKind(i, Kind.Water, 2)) continue;
            int[] lab = new int[49]; int parts = 0;
            for (int s = 0; s < 49; s++)
            {
                int sx = x + s % 7 - 3, sy = y + s / 7 - 3;
                if (lab[s] != 0 || !In(sx, sy) || K[Idx(sx, sy)] != Kind.Water) continue;
                parts++;
                Stack<int> st = new Stack<int>(); st.Push(s); lab[s] = parts;
                while (st.Count > 0)
                {
                    int c = st.Pop();
                    for (int d = 0; d < 8; d++)
                    {
                        int nx = c % 7 + ConnectedSet.DX[d], ny = c / 7 + ConnectedSet.DY[d];
                        if (nx < 0 || ny < 0 || nx > 6 || ny > 6) continue;
                        int t = ny * 7 + nx;
                        if (lab[t] != 0 || !In(x + nx - 3, y + ny - 3) || K[Idx(x + nx - 3, y + ny - 3)] != Kind.Water) continue;
                        lab[t] = parts; st.Push(t);
                    }
                }
            }
            if (parts >= 2) { Bridge[i] = true; n++; }
        }
        Log.Add("bridge/causeway cells: " + n);
    }

    bool NearHigherPlateau(int i, int level, int r)
    {
        int x = i % N, y = i / N;
        for (int yy = y - r; yy <= y + r; yy++) for (int xx = x - r; xx <= x + r; xx++)
        {
            if (!In(xx, yy)) continue;
            int p = Plateau[Idx(xx, yy)];
            if (p >= 0 && PlateauLevel[p] > level) return true;
        }
        return false;
    }

    // Walkable SC minitiles inside the diamond of a TS cell (grown by `grow` minitiles).
    List<int> CellMinis(int i, double grow)
    {
        List<int> l = new List<int>();
        double px, py; ScPixel(i % N, i / N, out px, out py);
        double hw = 32 + grow * 8, hh = 16 + grow * 4;
        int mx0 = (int)Math.Floor((px - hw) / 8), mx1 = (int)Math.Ceiling((px + hw) / 8);
        int my0 = (int)Math.Floor((py - hh) / 8), my1 = (int)Math.Ceiling((py + hh) / 8);
        for (int my = my0; my <= my1; my++) for (int mx = mx0; mx <= mx1; mx++)
        {
            if (mx < 0 || my < 0 || mx >= Ter.W || my >= Ter.H) continue;
            if (Math.Abs(mx * 8 + 4 - px) / hw + Math.Abs(my * 8 + 4 - py) / hh > 1) continue;
            int m = my * Ter.W + mx;
            if (Ter.Walkable(m)) l.Add(m);
        }
        return l;
    }

    // True when SC units can walk from cell a to the neighbouring cell b without leaving the two cells' area.
    // A plateau edge where this holds is a ramp (no cliff piece).
    public virtual bool LocalWalk(int a, int b)
    {
        List<int> ma = CellMinis(a, 0.5), mb = CellMinis(b, 0.5);
        if (ma.Count == 0 || mb.Count == 0) return false;
        HashSet<int> area = new HashSet<int>(ma); foreach (int m in mb) area.Add(m);
        HashSet<int> target = new HashSet<int>(mb), seen = new HashSet<int>();
        Queue<int> q = new Queue<int>();
        foreach (int m in ma) { seen.Add(m); q.Enqueue(m); }
        while (q.Count > 0)
        {
            int c = q.Dequeue();
            if (target.Contains(c)) return true;
            int x = c % Ter.W, y = c / Ter.W;
            for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++)
            {
                int n = (y + dy) * Ter.W + x + dx;
                if (area.Contains(n) && seen.Add(n)) q.Enqueue(n);
            }
        }
        return false;
    }

    public bool NearKind(int i, Kind k, int r)
    {
        int x = i % N, y = i / N;
        for (int yy = y - r; yy <= y + r; yy++) for (int xx = x - r; xx <= x + r; xx++)
            if (In(xx, yy) && K[Idx(xx, yy)] == k) return true;
        return false;
    }

    public int NearPlateau(int i, int r)
    {
        int x = i % N, y = i / N;
        for (int yy = y - r; yy <= y + r; yy++) for (int xx = x - r; xx <= x + r; xx++)
            if (In(xx, yy) && Plateau[Idx(xx, yy)] >= 0) return Plateau[Idx(xx, yy)];
        return -1;
    }

    public delegate bool CellPred(int i);

    public List<List<int>> Components(CellPred pred, bool eight)
    {
        List<List<int>> res = new List<List<int>>();
        bool[] seen = new bool[K.Length];
        for (int s = 0; s < K.Length; s++)
        {
            if (!Valid[s] || seen[s] || !pred(s)) continue;
            List<int> comp = new List<int>();
            Queue<int> q = new Queue<int>(); q.Enqueue(s); seen[s] = true;
            while (q.Count > 0)
            {
                int c = q.Dequeue(); comp.Add(c);
                int x = c % N, y = c / N;
                for (int d = 0; d < 8; d++)
                {
                    if (!eight && (d & 1) == 1) continue;
                    int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d];
                    if (!In(nx, ny)) continue;
                    int n = Idx(nx, ny);
                    if (seen[n] || !pred(n)) continue;
                    seen[n] = true; q.Enqueue(n);
                }
            }
            res.Add(comp);
        }
        return res;
    }

    // ------------------------------------------------------------ 2. arcs (ordered cell paths along a boundary band)
    public class Arc { public List<int> Path = new List<int>(); public bool StartAtEdge, EndAtEdge; public int Group, EndKind; }

    public List<Arc> BandArcs(CellPred inBand, int group)
    {
        List<Arc> arcs = new List<Arc>();
        foreach (List<int> comp in Components(inBand, true))
        {
            if (comp.Count < 3) continue;
            HashSet<int> set = new HashSet<int>(comp);
            int a = Farthest(comp[0], set, null), b;
            int[] prev = new int[0];
            Dictionary<int, int> par = new Dictionary<int, int>();
            b = Farthest(a, set, par);
            Arc arc = new Arc(); arc.Group = group;
            for (int c = b; ; c = par[c]) { arc.Path.Add(c); if (c == a) break; }
            arc.Path.Reverse();
            arc.StartAtEdge = !Visible[arc.Path[0]] || NearInvisible(arc.Path[0]);
            arc.EndAtEdge = !Visible[arc.Path[arc.Path.Count - 1]] || NearInvisible(arc.Path[arc.Path.Count - 1]);
            arcs.Add(arc);
        }
        return arcs;
    }

    // Contour tracing: walks the cracks between region cells and outside cells (region on the right,
    // right turns first, so diagonal touches stay separate), then cuts each closed contour into arcs.
    // edgeClass(inCell, outCell): 0 = no cliff here (e.g. ramp), 1 = cliff/shore here, 2 = map edge,
    // 3 = handled by another chain (water). Arcs next to class 2/3 are open-ended and run a few cells into it.
    public delegate int EdgeClass(int inCell, int outCell);

    public List<Arc> TraceArcs(CellPred region, EdgeClass edgeClass, int group, int bridge)
    {
        // directed edges keyed by start vertex (vx, vy) -> list of edges
        Dictionary<long, List<int[]>> from = new Dictionary<long, List<int[]>>();
        List<int[]> edges = new List<int[]>();  // x0,y0,x1,y1,in,out,cls
        int[] sx0 = { 0, 1, 1, 0 }, sy0 = { 0, 0, 1, 1 }, sx1 = { 1, 1, 0, 0 }, sy1 = { 0, 1, 1, 0 };
        int[] ox = { 0, 1, 0, -1 }, oy = { -1, 0, 1, 0 };   // top, right, bottom, left neighbour
        for (int y = 0; y < N; y++) for (int x = 0; x < N; x++)
        {
            int i = Idx(x, y);
            if (!Valid[i] || !region(i)) continue;
            for (int s = 0; s < 4; s++)
            {
                int nx = x + ox[s], ny = y + oy[s];
                int o = (nx >= 0 && ny >= 0 && nx < N && ny < N) ? Idx(nx, ny) : -1;
                if (o >= 0 && Valid[o] && region(o)) continue;
                int cls = o < 0 || !Valid[o] ? 2 : edgeClass(i, o);
                int[] e = { x + sx0[s], y + sy0[s], x + sx1[s], y + sy1[s], i, o, cls, 0 };
                long key = (long)e[0] * 100000 + e[1];
                List<int[]> l; if (!from.TryGetValue(key, out l)) { l = new List<int[]>(); from[key] = l; }
                l.Add(e); edges.Add(e);
            }
        }
        List<Arc> arcs = new List<Arc>();
        foreach (int[] start in edges)
        {
            if (start[7] != 0) continue;
            List<int[]> loop = new List<int[]>();
            int[] e = start;
            while (e != null && e[7] == 0)
            {
                e[7] = 1; loop.Add(e);
                int dx = e[2] - e[0], dy = e[3] - e[1];
                List<int[]> nexts; from.TryGetValue((long)e[2] * 100000 + e[3], out nexts);
                int[] pick = null; int bestTurn = 9;
                if (nexts != null)
                    foreach (int[] n in nexts)
                    {
                        if (n[7] != 0 && n != start) continue;
                        int ndx = n[2] - n[0], ndy = n[3] - n[1];
                        int cross = dx * ndy - dy * ndx, dot = dx * ndx + dy * ndy;
                        int turn = cross > 0 ? 0 : dot > 0 ? 1 : cross < 0 ? 2 : 3;   // right, straight, left, back
                        if (turn < bestTurn) { bestTurn = turn; pick = n; }
                    }
                e = pick;
            }
            // bridge short gaps of class 0 between class-1 runs (sampling noise)
            int L = loop.Count;
            int[] cls = new int[L];
            for (int k = 0; k < L; k++) cls[k] = loop[k][6];
            for (int k = 0; k < L; k++)
            {
                if (cls[k] != 0) continue;
                int run = 0; while (run < L && cls[(k + run) % L] == 0) run++;
                if (run <= bridge && cls[(k - 1 + L) % L] == 1 && cls[(k + run) % L] == 1)
                    for (int r = 0; r < run; r++) cls[(k + r) % L] = 1;
                k += run - 1;
            }
            // find a starting point that is not inside an active run
            int s0 = -1;
            for (int k = 0; k < L; k++) if (cls[k] != 1) { s0 = k; break; }
            if (s0 < 0)
            {   // closed contour: cut it anywhere
                Arc a = new Arc(); a.Group = group;
                foreach (int[] le in loop) if (a.Path.Count == 0 || a.Path[a.Path.Count - 1] != le[5]) a.Path.Add(le[5]);
                arcs.Add(a);
                continue;
            }
            for (int k = 0; k < L; k++)
            {
                int kk = (s0 + k) % L;
                if (cls[kk] != 1 || cls[(kk - 1 + L) % L] == 1) continue;
                Arc a = new Arc(); a.Group = group;
                int before = cls[(kk - 1 + L) % L];
                a.StartAtEdge = before >= 2;
                if (a.StartAtEdge)   // lead-in from beyond the visible border / from the water side
                    for (int b = Math.Min(4, L - 1); b >= 1; b--)
                    {
                        int pk = (kk - b + L) % L; if (cls[pk] != before) continue;
                        int c = loop[pk][5] >= 0 && Valid[loop[pk][5]] ? loop[pk][5] : loop[pk][4];
                        if (a.Path.Count == 0 || a.Path[a.Path.Count - 1] != c) a.Path.Add(c);
                    }
                int m = 0;
                while (m < L && cls[(kk + m) % L] == 1)
                {
                    int outCell = loop[(kk + m) % L][5];
                    if (outCell >= 0 && (a.Path.Count == 0 || a.Path[a.Path.Count - 1] != outCell)) a.Path.Add(outCell);
                    m++;
                }
                int after = cls[(kk + m) % L];
                a.EndAtEdge = after >= 2; a.EndKind = after;
                if (a.EndAtEdge)
                    for (int b = 0; b < 4 && cls[(kk + m + b) % L] == after; b++)
                    {
                        int[] le = loop[(kk + m + b) % L];
                        int c = le[5] >= 0 && Valid[le[5]] ? le[5] : le[4];
                        if (a.Path[a.Path.Count - 1] != c) a.Path.Add(c);
                    }
                if (a.Path.Count >= 3) arcs.Add(a);
            }
        }
        return arcs;
    }

    bool NearInvisible(int i)
    {
        int x = i % N, y = i / N;
        for (int d = 0; d < 8; d++) { int nx = x + 2 * ConnectedSet.DX[d], ny = y + 2 * ConnectedSet.DY[d]; if (!In(nx, ny) || !Visible[Idx(nx, ny)]) return true; }
        return false;
    }

    int Farthest(int s, HashSet<int> set, Dictionary<int, int> par)
    {
        Queue<int> q = new Queue<int>(); q.Enqueue(s);
        HashSet<int> seen = new HashSet<int>(); seen.Add(s);
        if (par != null) par[s] = s;
        int last = s;
        while (q.Count > 0)
        {
            int c = q.Dequeue(); last = c;
            int x = c % N, y = c / N;
            for (int d = 0; d < 8; d++)
            {
                int n = Idx(x + ConnectedSet.DX[d], y + ConnectedSet.DY[d]);
                if (!set.Contains(n) || !seen.Add(n)) continue;
                if (par != null) par[n] = c;
                q.Enqueue(n);
            }
        }
        return last;
    }

    // ------------------------------------------------------------ 3. chain search (A*)
    public delegate double CellCost(CPiece p, int cell, TmpCell tc);
    public delegate double PieceCost(CPiece p, int ox, int oy);

    class Node : IComparable<Node>
    {
        public double F, G; public int X, Y, Progress; public CPoint Socket; public Node Parent; public Placement Place; public long Seq;
        public int CompareTo(Node o) { int c = F.CompareTo(o.F); return c != 0 ? c : Seq.CompareTo(o.Seq); }
    }

    // Index of the path cell nearest to (x,y), searched in a window ahead of `from` so the chain
    // cannot jump between parts of the path that happen to lie close together.
    int PathProgress(Arc arc, int from, int x, int y)
    {
        int best = -1; int bestD = int.MaxValue;
        for (int j = Math.Max(0, from - 3); j < Math.Min(arc.Path.Count, from + 14); j++)
        {
            int c = arc.Path[j], dx = c % N - x, dy = c / N - y, d = dx * dx + dy * dy;
            if (d < bestD) { bestD = d; best = j; }
        }
        return bestD <= 18 ? best : -1;
    }

    // An open-ended chain must run past the visible border (map edge) or touch the water (water side).
    bool OpenEndReached(Arc arc, int x, int y, int left)
    {
        if (left == 0) return true;
        if (arc.EndKind == 2) return left <= 4 && (!In(x, y) || !Visible[Idx(x, y)]);
        if (arc.EndKind == 3) return left <= 5 && In(x, y) && NearKind(Idx(x, y), Kind.Water, 1);
        return left <= 2;
    }

    // Places pieces along `arc`. Returns false when no chain was found.
    public bool Chain(ConnectedSet cs, Arc arc, int corridor, CellCost cellCost, PieceCost pieceCost, bool needEnds)
    {
        HashSet<int> corr = new HashSet<int>();
        foreach (int c in arc.Path)
        {
            int x = c % N, y = c / N;
            for (int yy = y - corridor; yy <= y + corridor; yy++) for (int xx = x - corridor; xx <= x + corridor; xx++)
                if (xx >= 0 && yy >= 0 && xx < N && yy < N) corr.Add(Idx(xx, yy));
        }
        int L = arc.Path.Count, start = arc.Path[0];
        SortedSet<Node> open = new SortedSet<Node>();
        Dictionary<long, double> best = new Dictionary<long, double>();
        long seq = 0;
        int sx = start % N, sy = start / N;
        // start: an end piece (or, at a map edge, any piece) near the first path cell
        bool openStart = arc.StartAtEdge || !needEnds, openEnd = arc.EndAtEdge || !needEnds;
        foreach (CPiece p in cs.Pieces)
        {
            bool single = p.Points.Count == 1;
            if (!openStart && !single) continue;
            if (openStart && single) continue;
            for (int k = 0; k < p.Points.Count; k++)
            {
                CPoint entry = p.Points[k];
                CPoint exit = single ? entry : p.Points[1 - k];
                for (int oy = -1; oy <= 1; oy++) for (int ox = -1; ox <= 1; ox++)
                {
                    int px = sx + ox - entry.X, py = sy + oy - entry.Y;
                    double c = Cost(p, px, py, corr, cellCost, pieceCost);
                    if (c < 0) continue;
                    Node n = new Node { X = px + exit.X, Y = py + exit.Y, Socket = exit, G = c + 1, Seq = seq++ };
                    n.Place = new Placement { Piece = p, X = px, Y = py };
                    n.Progress = PathProgress(arc, 0, n.X, n.Y);
                    if (n.Progress < 0) continue;
                    n.F = n.G + (L - 1 - n.Progress) / 3.0 * 1.5;
                    open.Add(n);
                }
            }
        }
        Node goal = null; int expansions = 0;
        while (open.Count > 0 && expansions < 60000)
        {
            Node cur = open.Min; open.Remove(cur);
            long key = (((long)Idx(cur.X, cur.Y) * 256 + cur.Socket.Dirs) * 2 + (cur.Socket.Front ? 1 : 0)) * 64 + cur.Progress / 8;
            double bg; if (best.TryGetValue(key, out bg) && bg <= cur.G) continue;
            best[key] = cur.G;
            expansions++;
            int left = L - 1 - cur.Progress;
            // goal tests
            if (openEnd && cur.Parent != null && OpenEndReached(arc, cur.X, cur.Y, left)) { goal = cur; break; }
            if (cur.Place != null && cur.Place.Piece.Points.Count == 1 && cur.Parent != null) { goal = cur; break; }
            for (int pi = 0; pi < cs.Pieces.Count; pi++)
            {
                CPiece p = cs.Pieces[pi];
                bool single = p.Points.Count == 1;
                if (single && (openEnd || left > 3)) continue;
                for (int k = 0; k < p.Points.Count; k++)
                {
                    CPoint entry = p.Points[k];
                    if (entry.Front != cur.Socket.Front) continue;
                    for (int d = 0; d < 8; d++)
                    {
                        if ((cur.Socket.Dirs & (1 << d)) == 0 || (entry.Dirs & (1 << ((d + 4) & 7))) == 0) continue;
                        int px = cur.X + ConnectedSet.DX[d] - entry.X, py = cur.Y + ConnectedSet.DY[d] - entry.Y;
                        if (Overlaps(cur, p, px, py)) continue;
                        double c = Cost(p, px, py, corr, cellCost, pieceCost);
                        if (c < 0) continue;
                        CPoint exit = single ? entry : p.Points[1 - k];
                        Node n = new Node { X = px + exit.X, Y = py + exit.Y, Socket = exit, Parent = cur, G = cur.G + c + 1, Seq = seq++ };
                        n.Place = new Placement { Piece = p, X = px, Y = py };
                        n.Progress = single ? L - 1 : PathProgress(arc, cur.Progress, n.X, n.Y);
                        if (n.Progress < 0 || n.Progress < cur.Progress - 2) continue;
                        n.F = n.G + (L - 1 - n.Progress) / 3.0 * 1.5;
                        open.Add(n);
                    }
                }
            }
        }
        if (goal == null) { ChainFailures++; Log.Add("  chain FAILED (" + cs.Name + ", path " + arc.Path.Count + ", expansions " + expansions + ")"); return false; }
        int count = 0;
        for (Node n = goal; n != null; n = n.Parent) { Commit(cs, n.Place); count++; }
        Log.Add("  chain ok: " + count + " pieces, path " + arc.Path.Count + ", expansions " + expansions);
        return true;
    }

    bool Overlaps(Node cur, CPiece p, int ox, int oy)
    {
        // a new piece must not overlap any earlier piece of the same chain (in narrow channels a chain
        // could otherwise walk back over itself instead of following the far bank)
        for (Node n = cur; n != null; n = n.Parent)
        {
            Tmp a = n.Place.Piece.Tmp;
            foreach (TmpCell tc in p.Tmp.Cells)
            {
                if (tc == null) continue;
                int cx = ox + tc.Index % p.Tmp.Width - n.Place.X, cy = oy + tc.Index / p.Tmp.Width - n.Place.Y;
                if (cx < 0 || cy < 0 || cx >= a.Width || cy >= a.Height) continue;
                if (a.Cells[cy * a.Width + cx] != null) return true;
            }
        }
        return false;
    }

    double Cost(CPiece p, int ox, int oy, HashSet<int> corr, CellCost cellCost, PieceCost pieceCost)
    {
        double c = 0;
        foreach (TmpCell tc in p.Tmp.Cells)
        {
            if (tc == null) continue;
            int x = ox + tc.Index % p.Tmp.Width, y = oy + tc.Index / p.Tmp.Width;
            if (!In(x, y)) return -1;
            int i = Idx(x, y);
            if (Used[i]) return -1;
            if (!corr.Contains(i)) c += 3;
            if (Overlay[y * 512 + x] != 255 || Terrain.ContainsKey(y * 1000 + x)) c += 5;
            c += cellCost(p, i, tc);
        }
        if (pieceCost != null) c += pieceCost(p, ox, oy);
        return c;
    }

    void Commit(ConnectedSet cs, Placement pl)
    {
        CPiece p = pl.Piece;
        pl.Tile = cs.Set.Start + p.Tiles[Rnd.Next(p.Tiles.Count)];
        Tmp t = Th.Get(pl.Tile) ?? p.Tmp;
        foreach (TmpCell tc in t.Cells)
        {
            if (tc == null) continue;
            int x = pl.X + tc.Index % t.Width, y = pl.Y + tc.Index / t.Width;
            if (!In(x, y)) continue;
            int i = Idx(x, y);
            Used[i] = true; Tile[i] = pl.Tile; Sub[i] = tc.Index; UsedWater[i] = tc.Terrain == 9;
        }
        Placed.Add(pl);
    }

    // ------------------------------------------------------------ 4. cliffs around plateaus
    public void Cliffs(ConnectedSet cs)
    {
        int plateaus = 0;
        for (int i = 0; i < Plateau.Length; i++) if (Plateau[i] + 1 > plateaus) plateaus = Plateau[i] + 1;
        for (int pid = 0; pid < plateaus; pid++)
        {
            int id = pid;
            // edges facing water are left to the water-cliff chain (SC cliffs drop straight into the water there)
            List<Arc> arcs = TraceArcs(delegate (int i) { return Plateau[i] == id; }, delegate (int a, int b)
            {
                if (!Visible[a] || !Visible[b]) return 2;
                if (Used[b] || NearHigherPlateau(b, PlateauLevel[id], 2)) return 0;           // a higher plateau's cliff is here
                if (K[b] == Kind.Low || K[b] == Kind.High) return LocalWalk(a, b) ? 0 : 1;   // ramp only if SC can walk here
                return NearKind(b, Kind.Water, 2) ? 3 : 1;
            }, id, 1);
            Log.Add("plateau " + id + ": " + arcs.Count + " cliff arcs");
            foreach (Arc arc in arcs)
            {
                double ax, ay, bx, by;
                ScPixel(arc.Path[0] % N, arc.Path[0] / N, out ax, out ay);
                ScPixel(arc.Path[arc.Path.Count - 1] % N, arc.Path[arc.Path.Count - 1] / N, out bx, out by);
                Log.Add(string.Format("  arc {0} cells, SC px ({1:0},{2:0}){3} -> ({4:0},{5:0}){6}", arc.Path.Count, ax, ay, arc.StartAtEdge ? " open" : "", bx, by, arc.EndAtEdge ? " open" : ""));
                if (arc.Path.Count < 4) continue;
                DebugArcs.Add(arc.Path);
                Chain(cs, arc, 3, CliffCellCost, delegate (CPiece p, int ox, int oy) { return CliffOrientCost(p, ox, oy, id); }, true);
            }
        }
    }

    double CliffCellCost(CPiece p, int i, TmpCell tc)
    {
        bool rock = tc.Terrain == 7 || tc.Terrain == 8 || tc.Terrain == 15;
        if (!Visible[i]) return 0;
        Kind k = K[i];
        if (rock)
        {
            if (k == Kind.Cliff) return 0;
            if (k == Kind.High) return 3;
            if (k == Kind.Low) return 1.5;
            return 0.8;
        }
        return k == Kind.Cliff ? 0.4 : 0;
    }

    double CliffOrientCost(CPiece p, int ox, int oy, int plateau)
    {
        double c = 0;
        foreach (CPoint pt in p.Points)
        {
            int hd = ConnectedSet.HighDir(pt), x = ox + pt.X, y = oy + pt.Y;
            for (int s = 2; s <= 4; s++)
            {
                int hx = x + s * ConnectedSet.DX[hd], hy = y + s * ConnectedSet.DY[hd];
                int lx = x - s * ConnectedSet.DX[hd], ly = y - s * ConnectedSet.DY[hd];
                if (In(hx, hy) && Visible[Idx(hx, hy)]) { int i = Idx(hx, hy); if (Plateau[i] != plateau && (K[i] == Kind.Low || K[i] == Kind.Water)) c += 1.5; }
                if (In(lx, ly) && Visible[Idx(lx, ly)]) { int i = Idx(lx, ly); if (Plateau[i] == plateau) c += 1.5; }
            }
        }
        return c;
    }

    // ------------------------------------------------------------ 5. shores around water
    // cliffStyle: the set is a cliff-like set (Water Cliffs) oriented by the Front/Back rule, land = high side
    public void Shores(ConnectedSet cs, bool cliffStyle) { Shores(cs, cliffStyle, null); }

    // land: only coast whose land cell passes gets this set; the rest is left to another chain (class 3),
    // e.g. beaches between water-cliff coasts
    public void Shores(ConnectedSet cs, bool cliffStyle, CellPred land)
    {
        int n = 0;
        foreach (List<int> comp in Components(delegate (int i) { return K[i] == Kind.Water; }, false))
        {
            HashSet<int> water = new HashSet<int>(comp);
            List<Arc> arcs = TraceArcs(delegate (int i) { return water.Contains(i); }, delegate (int a, int b)
            {
                if (!Visible[a] || !Visible[b]) return 2;
                if (Used[b] || Bridge[b]) return 0;
                return land != null && !land(b) ? 3 : 1;
            }, n++, 1);
            foreach (Arc arc in arcs)
            {
                if (arc.Path.Count < 4) continue;
                DebugArcs.Add(arc.Path);
                Log.Add("water body " + (n - 1) + " shore arc " + arc.Path.Count + " cells, edges " + arc.StartAtEdge + "/" + arc.EndAtEdge);
                if (cliffStyle) Chain(cs, arc, 3, WaterCliffCellCost, WaterCliffOrientCost, false);
                else Chain(cs, arc, 3, ShoreCellCost, null, false);
            }
        }
    }

    double WaterCliffCellCost(CPiece p, int i, TmpCell tc)
    {
        Kind k = K[i];
        if (!Visible[i]) return 0;
        if (Bridge[i]) return 6;
        if (tc.Terrain == 9) return k == Kind.Water ? 0 : 3;
        if (tc.Terrain == 7 || tc.Terrain == 8) return 0.3;
        return k == Kind.Water ? 1.5 : 0;
    }

    double WaterCliffOrientCost(CPiece p, int ox, int oy)
    {
        double c = 0;
        foreach (CPoint pt in p.Points)
        {
            int hd = ConnectedSet.HighDir(pt), x = ox + pt.X, y = oy + pt.Y;
            for (int s = 2; s <= 3; s++)
            {
                int hx = x + s * ConnectedSet.DX[hd], hy = y + s * ConnectedSet.DY[hd];
                if (In(hx, hy) && Visible[Idx(hx, hy)] && K[Idx(hx, hy)] == Kind.Water) c += 1.5;
            }
            // the water side is probed right next to the point only: a narrow channel's far bank is 2-3 cells away
            int lx = x - ConnectedSet.DX[hd], ly = y - ConnectedSet.DY[hd];
            if (In(lx, ly) && Visible[Idx(lx, ly)] && K[Idx(lx, ly)] != Kind.Water) c += 3;
        }
        return c;
    }

    // After shores are placed: water is only what is reachable from open water without crossing a shore piece;
    // leftover water cells on the land side of a shore become land.
    public void SettleWater()
    {
        // erode leftover water that pokes into land between shore pieces (saw teeth; 1-cell strips erode
        // from their ends, so run until stable; 2+ cells wide water never has 3 land neighbours)
        int eroded = 0;
        for (int pass = 0; pass < 60; pass++)
        {
            List<int> dry = new List<int>();
            for (int i = 0; i < K.Length; i++)
            {
                if (!Valid[i] || K[i] != Kind.Water || Used[i]) continue;
                // land = raw land or the land/rock part of a shore piece; a piece's water cells count as water
                int x = i % N, y = i / N, land = 0;
                for (int d = 0; d < 8; d += 2)
                {
                    int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d];
                    if (!In(nx, ny)) continue;
                    int n = Idx(nx, ny);
                    if (Used[n] ? !UsedWater[n] : K[n] != Kind.Water) land++;
                }
                if (land >= 3) dry.Add(i);
            }
            foreach (int i in dry) K[i] = Kind.Low;
            eroded += dry.Count;
            if (dry.Count == 0) break;
        }
        Log.Add("eroded water cells: " + eroded);
        bool[] reach = new bool[K.Length];
        Queue<int> q = new Queue<int>();
        for (int i = 0; i < K.Length; i++)
        {
            if (!Valid[i] || K[i] != Kind.Water || Used[i]) continue;
            // open water = no raw land nearby (narrow channels between two shore chains count too)
            int x = i % N, y = i / N; bool deep = true;
            for (int yy = y - 2; yy <= y + 2 && deep; yy++) for (int xx = x - 2; xx <= x + 2; xx++)
                if (In(xx, yy) && !Used[Idx(xx, yy)] && K[Idx(xx, yy)] != Kind.Water) { deep = false; break; }
            if (deep) { reach[i] = true; q.Enqueue(i); }
        }
        while (q.Count > 0)
        {
            int c = q.Dequeue(); int x = c % N, y = c / N;
            for (int d = 0; d < 8; d += 2)
            {
                int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d];
                if (!In(nx, ny)) continue;
                int n = Idx(nx, ny);
                if (reach[n] || !(UsedWater[n] || K[n] == Kind.Water && !Used[n])) continue;
                reach[n] = true; q.Enqueue(n);
            }
        }
        int dried = 0;
        for (int i = 0; i < K.Length; i++)
            if (Valid[i] && K[i] == Kind.Water && !Used[i] && !reach[i]) { K[i] = Kind.Low; dried++; }
        Log.Add("water cells turned to land behind shores: " + dried);
    }

    double ShoreCellCost(CPiece p, int i, TmpCell tc)
    {
        if (Bridge[i]) return 6;
        bool water = tc.Terrain == 9;
        Kind k = K[i];
        if (water) return k == Kind.Water ? 0 : 3;
        if (tc.Terrain == 7 || tc.Terrain == 8) return k == Kind.Water ? 0.5 : 2;
        return k == Kind.Water ? 1 : 0;
    }

    // ------------------------------------------------------------ 6. fill: water, ground LATs
    public void FillWater(TileSetInfo anim, int plainWater)
    {
        // biggest animated-water templates first, then 1x1
        List<Tmp> temps = new List<Tmp>(); List<int> ids = new List<int>();
        for (int k = 0; k < anim.Count; k++) { Tmp t = Th.Get(anim.Start + k); if (t != null) { temps.Add(t); ids.Add(anim.Start + k); } }
        List<int> order = new List<int>();
        for (int k = 0; k < temps.Count; k++) order.Add(k);
        order.Sort(delegate (int a, int b) { return (temps[b].Width * temps[b].Height).CompareTo(temps[a].Width * temps[a].Height); });
        for (int y = 0; y < N; y++) for (int x = 0; x < N; x++)
        {
            int i = Idx(x, y);
            if (!Valid[i] || K[i] != Kind.Water || Used[i]) continue;
            bool done = false;
            foreach (int k in order)
            {
                Tmp t = temps[k];
                bool ok = true;
                foreach (TmpCell tc in t.Cells)
                {
                    if (tc == null) continue;
                    int cx = x + tc.Index % t.Width, cy = y + tc.Index / t.Width;
                    if (!In(cx, cy)) { ok = false; break; }
                    int j = Idx(cx, cy);
                    if (K[j] != Kind.Water || Used[j]) { ok = false; break; }
                }
                if (!ok) continue;
                foreach (TmpCell tc in t.Cells)
                {
                    if (tc == null) continue;
                    int j = Idx(x + tc.Index % t.Width, y + tc.Index / t.Width);
                    Used[j] = true; Tile[j] = ids[k]; Sub[j] = tc.Index;
                }
                done = true; break;
            }
            if (!done) { Used[i] = true; Tile[i] = plainWater; Sub[i] = 0; }
        }
    }

    // Ground[i]: 0 = clear grass, 1 = dirt, 2 = pavement, 3 = tall grass.
    // Plateaus keep the SC look (tan dirt, green patches = grass); low ground becomes grass with
    // tall grass where SC has jungle, so the two levels read apart on the flat DTA terrain.
    public int[] Ground;
    public const int Grass = 0, Dirt = 1, Pave = 2, TallGrass = 3;

    public void PaintGround()
    {
        Ground = new int[K.Length];
        bool[] known = new bool[K.Length];
        // high side: plateau cells plus up to 3 cells beyond them that are not separated by a placed cliff
        int[] hd = new int[K.Length];
        Queue<int> q = new Queue<int>();
        for (int i = 0; i < K.Length; i++) { hd[i] = Plateau[i] >= 0 ? 0 : int.MaxValue; if (hd[i] == 0) q.Enqueue(i); }
        while (q.Count > 0)
        {
            int c = q.Dequeue(); int x = c % N, y = c / N;
            if (hd[c] >= 3) continue;
            for (int d = 0; d < 8; d += 2)
            {
                int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d];
                if (!In(nx, ny)) continue;
                int n = Idx(nx, ny);
                if (hd[n] <= hd[c] + 1 || Used[n] || K[n] == Kind.Water) continue;
                hd[n] = hd[c] + 1; q.Enqueue(n);
            }
        }
        for (int i = 0; i < K.Length; i++)
        {
            if (!Valid[i] || Rgb[i] == 0) continue;
            Color c = Color.FromArgb(Rgb[i]);
            int mx = Math.Max(c.R, Math.Max(c.G, c.B)), mn = Math.Min(c.R, Math.Min(c.G, c.B));
            bool green = c.G > c.R + 4, high = hd[i] <= 3;
            if (Bridge[i] || mx - mn < 14 && mx > 60) Ground[i] = Pave;
            else if (high) Ground[i] = green ? Grass : Dirt;
            else Ground[i] = green ? TallGrass : Grass;
            known[i] = true; q.Enqueue(i);
        }
        // cells without walkable SC pixels (cliff faces, former water) take the nearest known ground;
        // placed cliffs are barriers, so each side of a cliff takes the ground of its own level
        while (q.Count > 0)
        {
            int c = q.Dequeue(); int x = c % N, y = c / N;
            if (Used[c]) continue;
            for (int d = 0; d < 8; d += 2)
            {
                int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d];
                if (!In(nx, ny)) continue;
                int n = Idx(nx, ny);
                if (known[n]) continue;
                known[n] = true; Ground[n] = Ground[c]; q.Enqueue(n);
            }
        }
        // smooth isolated cells so LAT transitions look intentional
        for (int pass = 0; pass < 2; pass++)
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

    // LAT: a cell of a LAT ground uses base tile when its N,E,S,W neighbours share the ground,
    // otherwise transition tile latStart + mask (bit 1 N, 2 E, 4 S, 8 W = neighbour differs).
    public void ApplyGround(int clear, int[] baseTile, int[] latStart)
    {
        int[] NX = { 0, 1, 0, -1 }, NY = { -1, 0, 1, 0 };
        for (int y = 0; y < N; y++) for (int x = 0; x < N; x++)
        {
            int i = Idx(x, y);
            if (!Valid[i] || Used[i]) continue;
            int g = Ground[i];
            if (g == Grass) { Tile[i] = clear; Sub[i] = 0; continue; }
            int mask = 0;
            for (int d = 0; d < 4; d++)
            {
                int nx = x + NX[d], ny = y + NY[d];
                int n = In(nx, ny) ? Idx(nx, ny) : -1;
                // cliff and rock tiles carry grass around them, so they count as grass for transitions
                bool same = n < 0 || (Used[n] ? g == Grass && !UsedWater[n] : Ground[n] == g && K[n] != Kind.Water);
                if (!same) mask |= 1 << d;
            }
            Tile[i] = mask == 0 ? baseTile[g] : latStart[g] + mask;
            Sub[i] = 0;
        }
    }

    // ------------------------------------------------------------ 7. objects
    public void Resources()
    {
        int gems = 0, trees = 0;
        foreach (ScUnit u in Chk.Units)
        {
            if (u.Id >= 176 && u.Id <= 178)   // mineral fields 64x32
            {
                for (int k = 0; k < 8; k++)
                {
                    int x, y; CellAt(u.X - 24 + (k % 4) * 16, u.Y + (k < 4 ? -8 : 8), out x, out y);
                    if (!In(x, y)) continue;
                    int o = y * 512 + x;
                    if (Overlay[o] != 255) continue;
                    Overlay[o] = (byte)(31 + Rnd.Next(4)); OverlayData[o] = (byte)(9 + Rnd.Next(3)); gems++;
                    K[Idx(x, y)] = K[Idx(x, y)] == Kind.High ? Kind.High : Kind.Low;
                }
            }
            else if (u.Id == 188)             // vespene geyser 128x64 -> tiberium tree + field
            {
                int x, y; CellAt(u.X, u.Y, out x, out y);
                Terrain[y * 1000 + x] = "TIBTREE"; trees++;
                for (int yy = y - 2; yy <= y + 2; yy++) for (int xx = x - 2; xx <= x + 2; xx++)
                {
                    if (!In(xx, yy) || (xx == x && yy == y)) continue;
                    int i = Idx(xx, yy);
                    if (K[i] == Kind.Water || K[i] == Kind.Cliff || Used[i] && !IsGround(Tile[i])) continue;
                    int o = yy * 512 + xx;
                    if (Overlay[o] != 255) continue;
                    if (Math.Abs(xx - x) + Math.Abs(yy - y) > 3) continue;
                    Overlay[o] = (byte)(102 + Rnd.Next(12)); OverlayData[o] = (byte)(3 + Rnd.Next(6));
                }
            }
            else if (u.Id == 214)             // start location
            {
                int x, y; CellAt(u.X, u.Y, out x, out y);
                Starts.Add(new int[] { u.Owner, x, y });
            }
        }
        Starts.Sort(delegate (int[] a, int[] b) { return a[0].CompareTo(b[0]); });
        Log.Add("gem cells " + gems + ", tiberium trees " + trees + ", starts " + Starts.Count);
    }

    public HashSet<int> GroundTiles = new HashSet<int>();
    bool IsGround(int t) { return GroundTiles.Contains(t); }

    public void Obstacles(string[] treeTypes, int[] rockTiles)
    {
        // centre temple: the obstacle component nearest to the map centre becomes the ruined Temple of Nod,
        // wall-like obstacles around it become concrete walls, elongated ones elsewhere become rock lines,
        // small blobs become trees
        int cx, cy; CellAt(Chk.Width * 16, Chk.Height * 16, out cx, out cy);
        List<List<int>> comps = Components(delegate (int i) { return K[i] == Kind.Block && Visible[i]; }, true);
        List<int> temple = null; int bestD = int.MaxValue;
        foreach (List<int> comp in comps)
            foreach (int i in comp) { int d = Math.Abs(i % N - cx) + Math.Abs(i / N - cy); if (d < bestD) { bestD = d; temple = comp; } }
        int walls = 0, treeCount = 0;
        if (bestD >= 6) temple = null;   // nothing sits right at the centre
        if (temple != null)
        {
            Structures.Add("Neutral,DBTMPL,256," + (cx - 1) + "," + (cy - 1) + ",64,None,1,0,1,0,0,None,None,None,0,0");
            foreach (int i in temple) K[i] = Kind.Low;
            for (int y = cy - 2; y <= cy + 1; y++) for (int x = cx - 2; x <= cx + 1; x++) Overlay[y * 512 + x] = 255;
        }
        foreach (List<int> comp in comps)
        {
            if (comp == temple) continue;
            int minX = int.MaxValue, maxX = 0, minY = int.MaxValue, maxY = 0;
            foreach (int i in comp) { int dx, dy; ToScreen(i % N, i / N, out dx, out dy); minX = Math.Min(minX, dx); maxX = Math.Max(maxX, dx); minY = Math.Min(minY, dy); maxY = Math.Max(maxY, dy); }
            bool longShape = comp.Count >= 6 && (maxX - minX >= 8 || maxY - minY >= 8);
            double sx = 0, sy = 0;
            foreach (int i in comp) { double px, py; ScPixel(i % N, i / N, out px, out py); sx += px; sy += py; }
            sx = sx / comp.Count - Chk.Width * 16; sy = sy / comp.Count - Chk.Height * 16;
            bool central = Math.Sqrt(sx * sx + sy * sy) < Chk.Width * 32 * 0.3;
            bool wall = longShape && central;
            if (longShape && !central)
            {
                foreach (int i in comp)
                {
                    if (Rnd.NextDouble() > 0.85) continue;
                    Used[i] = true; Tile[i] = rockTiles[Rnd.Next(rockTiles.Length)]; Sub[i] = 0; Decor.Add(i); walls++;
                }
                continue;
            }
            if (wall)
                foreach (int c in Skeleton(comp)) { Overlay[(c / N) * 512 + c % N] = 2; walls++; }
            foreach (int i in comp)
            {
                int x = i % N, y = i / N;
                if (!wall && Rnd.NextDouble() < 0.8) { Terrain[y * 1000 + x] = treeTypes[Rnd.Next(treeTypes.Length)]; treeCount++; }
                K[i] = Kind.Low;
            }
        }
        // StarCraft doodad sprites (jungle trees and bushes)
        foreach (ScDoodad s in Chk.Sprites)
        {
            int x, y; CellAt(s.X, s.Y, out x, out y);
            if (!In(x, y) || !Visible[Idx(x, y)]) continue;
            int i = Idx(x, y);
            if (K[i] == Kind.Water || Used[i] || Overlay[y * 512 + x] != 255 || Terrain.ContainsKey(y * 1000 + x)) continue;
            Terrain[y * 1000 + x] = treeTypes[Rnd.Next(treeTypes.Length)]; treeCount++;
        }
        Log.Add("walls/rocks " + walls + " cells, trees " + treeCount + (temple != null ? ", temple at " + cx + "," + cy : ""));
    }

    // Zhang-Suen thinning of a cell set, then diagonal steps are filled so the line is 4-connected
    // (walls only join N/E/S/W). Keeps X, L and T shapes whole.
    List<int> Skeleton(List<int> comp)
    {
        HashSet<int> s = new HashSet<int>(comp);
        int[] ox = { 0, 1, 1, 1, 0, -1, -1, -1 }, oy = { -1, -1, 0, 1, 1, 1, 0, -1 };   // P2..P9 clockwise from north
        for (bool changed = true; changed; )
        {
            changed = false;
            for (int step = 0; step < 2; step++)
            {
                List<int> del = new List<int>();
                foreach (int c in s)
                {
                    int x = c % N, y = c / N;
                    bool[] p = new bool[8]; int cnt = 0, trans = 0;
                    for (int k = 0; k < 8; k++) { p[k] = s.Contains(Idx(x + ox[k], y + oy[k])); if (p[k]) cnt++; }
                    for (int k = 0; k < 8; k++) if (!p[k] && p[(k + 1) % 8]) trans++;
                    if (cnt < 2 || cnt > 6 || trans != 1) continue;
                    if (step == 0 && (p[0] && p[2] && p[4] || p[2] && p[4] && p[6])) continue;
                    if (step == 1 && (p[0] && p[2] && p[6] || p[0] && p[4] && p[6])) continue;
                    del.Add(c);
                }
                foreach (int c in del) s.Remove(c);
                if (del.Count > 0) changed = true;
            }
        }
        List<int> res = new List<int>(s);
        foreach (int c in new List<int>(s))
        {
            int x = c % N, y = c / N;
            for (int d = 1; d < 8; d += 2)
            {
                int n = Idx(x + ConnectedSet.DX[d], y + ConnectedSet.DY[d]);
                if (!s.Contains(n)) continue;
                int m1 = Idx(x + ConnectedSet.DX[d], y), m2 = Idx(x, y + ConnectedSet.DY[d]);
                if (s.Contains(m1) || s.Contains(m2)) continue;
                int m = comp.Contains(m1) ? m1 : m2;
                s.Add(m); res.Add(m);
            }
        }
        return res;
    }

    // Per-cell StarCraft reachability from the first start: +1 reachable, -1 walkable area not reachable, 0 unknown.
    int[] scState;
    public int[] ScState()
    {
        if (scState != null) return scState;
        ScUnit st = null;
        foreach (ScUnit u in Chk.Units) if (u.Id == 214 && (st == null || u.Owner < st.Owner)) st = u;
        bool[] sc = new bool[Ter.W * Ter.H];
        Queue<int> q = new Queue<int>();
        int s0 = (st.Y / 8) * Ter.W + st.X / 8;
        sc[s0] = true; q.Enqueue(s0);
        while (q.Count > 0)
        {
            int c = q.Dequeue(); int x = c % Ter.W, y = c / Ter.W;
            for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++)
            {
                int nx = x + dx, ny = y + dy;
                if (nx < 0 || ny < 0 || nx >= Ter.W || ny >= Ter.H) continue;
                int n = ny * Ter.W + nx;
                if (sc[n] || !Ter.Walkable(n)) continue;
                sc[n] = true; q.Enqueue(n);
            }
        }
        scState = new int[K.Length];
        for (int i = 0; i < K.Length; i++)
        {
            if (!Valid[i] || !Visible[i]) continue;
            List<int> ms = CellMinis(i, 0);
            if (ms.Count < 4) continue;
            int inSc = 0; foreach (int m in ms) if (sc[m]) inSc++;
            scState[i] = inSc * 2 > ms.Count ? 1 : inSc == 0 ? -1 : 0;
        }
        return scState;
    }

    // Decorations (trees, decorative rocks, walls) must not cut off ground that StarCraft units can reach:
    // remove the ones bordering such pockets until none is left.
    public void RepairDecorations()
    {
        int[] sc = ScState();
        int removed = 0;
        for (int round = 0; round < 12; round++)
        {
            bool[] pass = Passable();
            HashSet<int> reach = new HashSet<int>(Reach(pass, Idx(Starts[0][1], Starts[0][2])));
            int got = 0;
            for (int i = 0; i < K.Length; i++)
            {
                if (!Valid[i] || !pass[i] || sc[i] != 1 || reach.Contains(i)) continue;
                int x = i % N, y = i / N;
                for (int yy = y - 1; yy <= y + 1; yy++) for (int xx = x - 1; xx <= x + 1; xx++)
                {
                    if (!In(xx, yy)) continue;
                    int j = Idx(xx, yy);
                    string t;
                    if (Terrain.TryGetValue(yy * 1000 + xx, out t) && t != "TIBTREE") { Terrain.Remove(yy * 1000 + xx); got++; }
                    if (Decor.Remove(j)) { Used[j] = false; Tile[j] = -1; got++; }
                    if (Overlay[yy * 512 + xx] == 2) { Overlay[yy * 512 + xx] = 255; OverlayData[yy * 512 + xx] = 0; got++; }
                }
            }
            removed += got;
            if (got == 0) break;
        }
        Log.Add("decorations removed to keep SC-walkable ground reachable: " + removed);
    }

    // Cells covered by cliffs, shores or water cannot keep resources, trees or walls.
    public void Cleanup()
    {
        int removed = 0;
        for (int y = 0; y < N && y < 512; y++) for (int x = 0; x < N && x < 512; x++)
        {
            int i = Idx(x, y);
            if (!Valid[i] || !Used[i]) continue;
            if (Overlay[y * 512 + x] != 255) { Overlay[y * 512 + x] = 255; OverlayData[y * 512 + x] = 0; removed++; }
            if (Terrain.Remove(y * 1000 + x)) removed++;
        }
        Log.Add("cleanup: removed " + removed + " objects under cliffs/water");
    }

    // wall overlay frames: bit per connected neighbour (learned from DTA maps)
    public void WallFrames(int wallId, int[] bitDir)
    {
        for (int y = 1; y < 511; y++) for (int x = 1; x < 511; x++)
        {
            if (Overlay[y * 512 + x] != wallId) continue;
            int m = 0;
            for (int b = 0; b < bitDir.Length; b++)
            {
                int d = bitDir[b];
                if (Overlay[(y + ConnectedSet.DY[d]) * 512 + x + ConnectedSet.DX[d]] == wallId) m |= 1 << b;
            }
            OverlayData[y * 512 + x] = (byte)m;
        }
    }

    // ------------------------------------------------------------ 8. checks
    // Ground passability from the final tiles (TMP land: 7/8/15 rock, 9 water), walls, terrain objects, structures.
    public bool[] Passable()
    {
        bool[] pass = new bool[K.Length];
        for (int y = 0; y < N; y++) for (int x = 0; x < N; x++)
        {
            int i = Idx(x, y);
            if (!Valid[i] || !Visible[i]) continue;
            int t = Tile[i] < 0 ? 0 : Tile[i];
            Tmp tmp = Th.Get(t);
            int land = 0;
            if (tmp != null && Sub[i] < tmp.Cells.Length && tmp.Cells[Sub[i]] != null) land = tmp.Cells[Sub[i]].Terrain;
            bool ok = land != 7 && land != 8 && land != 9 && land != 15;
            if (x < 512 && y < 512 && Overlay[y * 512 + x] == 2) ok = false;
            if (Terrain.ContainsKey(y * 1000 + x)) ok = false;
            pass[i] = ok;
        }
        foreach (string s in Structures)
        {
            string[] f = s.Split(',');
            int sx = int.Parse(f[3]), sy = int.Parse(f[4]);
            for (int y = sy; y < sy + 2; y++) for (int x = sx; x < sx + 2; x++) if (In(x, y)) pass[Idx(x, y)] = false;
        }
        return pass;
    }

    public List<int> Reach(bool[] pass, int start)
    {
        List<int> seen = new List<int>();
        bool[] mark = new bool[K.Length];
        Queue<int> q = new Queue<int>(); q.Enqueue(start); mark[start] = true;
        while (q.Count > 0)
        {
            int c = q.Dequeue(); seen.Add(c); int x = c % N, y = c / N;
            for (int d = 0; d < 8; d++)
            {
                int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d];
                if (!In(nx, ny)) continue;
                int n = Idx(nx, ny);
                if (mark[n] || !pass[n]) continue;
                // no corner cutting between two blocked cells
                if ((d & 1) == 1 && !pass[Idx(x + ConnectedSet.DX[d], y)] && !pass[Idx(x, y + ConnectedSet.DY[d])]) continue;
                mark[n] = true; q.Enqueue(n);
            }
        }
        return seen;
    }

    // green = reachable from start 0, red = passable but cut off, grey = blocked, blue = water
    public Bitmap ReachImage()
    {
        bool[] pass = Passable();
        HashSet<int> rs = Starts.Count > 0 ? new HashSet<int>(Reach(pass, Idx(Starts[0][1], Starts[0][2]))) : new HashSet<int>();
        int bw = 2 * W, bh = 2 * H;
        int[] buf = new int[bw * bh];
        for (int y = 0; y < N; y++) for (int x = 0; x < N; x++)
        {
            int i = Idx(x, y); if (!Valid[i]) continue;
            int dx, dy; ToScreen(x, y, out dx, out dy);
            Color c = rs.Contains(i) ? Color.FromArgb(60, 150, 60) : pass[i] ? Color.FromArgb(220, 40, 40) : K[i] == Kind.Water || UsedWater[i] ? Color.FromArgb(40, 70, 160) : Color.FromArgb(60, 60, 60);
            if (!Visible[i]) c = Color.Black;
            for (int yy = dy; yy <= dy + 1 && yy < bh; yy++) for (int xx = dx; xx <= dx + 1 && xx < bw; xx++) buf[yy * bw + xx] = c.ToArgb();
        }
        Bitmap b = Img.FromBuffer(buf, bw, bh);
        Bitmap big = new Bitmap(bw * 4, bh * 2);
        using (Graphics g = Graphics.FromImage(big)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor; g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half; g.DrawImage(b, 0, 0, big.Width, big.Height); }
        b.Dispose();
        return big;
    }

    // Compares ground reachability from the first start with StarCraft's: "leak" cells are reachable in DTA
    // but not in SC (missing cliff), "sealed" cells the other way round. Returns a picture of both.
    // summary numbers for the pipeline's verdict
    public int Leaks, Sealed, ChainFailures, GemsReachable, GemsTotal;
    public bool StartsConnected = true;

    public Bitmap CompareWithSc()
    {
        int[] sc = ScState();
        bool[] pass = Passable();
        HashSet<int> dta = new HashSet<int>(Reach(pass, Idx(Starts[0][1], Starts[0][2])));
        int bw = 2 * W, bh = 2 * H, leaks = 0, closed = 0;
        int[] buf = new int[bw * bh];
        for (int y = 0; y < N; y++) for (int x = 0; x < N; x++)
        {
            int i = Idx(x, y); if (!Valid[i] || !Visible[i]) continue;
            bool scYes = sc[i] == 1, scNo = sc[i] == -1;
            Color c = Color.FromArgb(50, 50, 50);
            if (dta.Contains(i)) c = Color.FromArgb(60, 150, 60);
            if (dta.Contains(i) && scNo) { c = Color.FromArgb(230, 30, 30); leaks++; }
            if (!dta.Contains(i) && pass[i] && scYes) { c = Color.FromArgb(240, 160, 0); closed++; }
            int dx, dy; ToScreen(x, y, out dx, out dy);
            for (int yy = dy; yy <= dy + 1 && yy < bh; yy++) for (int xx = dx; xx <= dx + 1 && xx < bw; xx++) buf[yy * bw + xx] = c.ToArgb();
        }
        Leaks = leaks; Sealed = closed;
        Log.Add("CHECK vs StarCraft: leak cells " + leaks + " (reachable here, not in SC), sealed cells " + closed + " (reachable in SC, not here)");
        Bitmap b = Img.FromBuffer(buf, bw, bh);
        Bitmap big = new Bitmap(bw * 4, bh * 2);
        using (Graphics g = Graphics.FromImage(big)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor; g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half; g.DrawImage(b, 0, 0, big.Width, big.Height); }
        b.Dispose();
        return big;
    }

    public void CheckConnectivity()
    {
        bool[] pass = Passable();
        for (int s = 0; s < Starts.Count; s++)
        {
            int si = Idx(Starts[s][1], Starts[s][2]);
            if (!pass[si]) { Log.Add("CHECK: start " + s + " is on a blocked cell!"); continue; }
            List<int> r = Reach(pass, si);
            HashSet<int> rs = new HashSet<int>(r);
            StringBuilder sb = new StringBuilder("CHECK: start " + s + " reaches " + r.Count + " cells; other starts:");
            for (int t = 0; t < Starts.Count; t++)
            {
                if (t == s) continue;
                bool ok = rs.Contains(Idx(Starts[t][1], Starts[t][2]));
                if (!ok) StartsConnected = false;
                sb.Append(" " + t + "=" + (ok ? "yes" : "NO"));
            }
            int gemsReached = 0, gemsAll = 0;
            for (int y = 0; y < N && y < 512; y++) for (int x = 0; x < N && x < 512; x++)
            {
                int o = Overlay[y * 512 + x];
                if (o < 31 || o > 34) continue;
                gemsAll++;
                bool near = false;
                for (int d = 0; d < 8 && !near; d++) { int nx = x + ConnectedSet.DX[d], ny = y + ConnectedSet.DY[d]; if (In(nx, ny) && rs.Contains(Idx(nx, ny))) near = true; }
                if (near || rs.Contains(Idx(x, y))) gemsReached++;
            }
            sb.Append("; gem cells reachable " + gemsReached + "/" + gemsAll);
            if (s == 0) { GemsReachable = gemsReached; GemsTotal = gemsAll; }
            Log.Add(sb.ToString());
        }
    }

    // ------------------------------------------------------------ 9. output
    public string WriteMap(string name, string author)
    {
        List<IsoTile> tiles = new List<IsoTile>();
        for (int y = 0; y < N; y++) for (int x = 0; x < N; x++)
        {
            int i = Idx(x, y);
            if (!Valid[i]) continue;
            tiles.Add(new IsoTile { X = x, Y = y, Tile = Tile[i] < 0 ? 0 : Tile[i], Sub = Tile[i] < 0 ? 0 : Sub[i] });
        }
        Ini ini = new Ini();
        ini.Set("Basic", "Name", name);
        ini.Set("Basic", "Author", author);
        foreach (string kv in new string[] { "Percent=0", "GameMode=standard", "HomeCell=98", "InitTime=10000", "Official=yes", "EndOfGame=no",
            "FreeRadar=no", "MaxPlayer=" + Math.Max(2, Starts.Count), "MinPlayer=2", "SkipScore=no", "TrainCrate=no", "TruckCrate=no", "AltHomeCell=99",
            "OneTimeOnly=no", "CarryOverCap=0", "NewINIFormat=4", "NextScenario=", "SkipMapSelect=no", "CarryOverMoney=0.000000",
            "AltNextScenario=", "MultiplayerOnly=1", "IceGrowthEnabled=no", "VeinGrowthEnabled=no", "TiberiumGrowthEnabled=yes",
            "IgnoreGlobalAITriggers=no", "TiberiumDeathToVisceroid=yes" })
        { int e = kv.IndexOf('='); ini.Set("Basic", kv.Substring(0, e), kv.Substring(e + 1)); }
        ini.Set("Map", "Size", "0,0," + W + "," + H);
        ini.Set("Map", "Theater", "TEMPERATE");
        ini.Set("Map", "LocalSize", PadX + "," + PadTop + "," + LocalW + "," + LocalH);
        foreach (string kv in new string[] { "Red=1.000000", "Blue=1.000000", "Green=1.000000", "Level=0.032000", "Ground=0.000000", "Ambient=0.950000",
            "IonRed=1.500000", "IonBlue=0.700000", "IonGreen=1.000000", "IonLevel=0.032000", "IonGround=0.000000", "IonAmbient=0.500000" })
        { int e = kv.IndexOf('='); ini.Set("Lighting", kv.Substring(0, e), kv.Substring(e + 1)); }
        foreach (string kv in new string[] { "Inert=no", "FogOfWar=no", "IonStorms=no", "MCVDeploy=no", "Meteorites=no", "Visceroids=no",
            "FixedAlliance=no", "TiberiumGrows=yes", "InitialVeteran=no", "HarvesterImmune=no", "TiberiumSpreads=yes", "TiberiumExplosive=no", "DestroyableBridges=yes" })
        { int e = kv.IndexOf('='); ini.Set("SpecialFlags", kv.Substring(0, e), kv.Substring(e + 1)); }
        for (int s = 0; s < Starts.Count; s++) ini.Set("Waypoints", s.ToString(), (Starts[s][2] * 1000 + Starts[s][1]).ToString());
        for (int s = 0; s < Structures.Count; s++) ini.Set("Structures", s.ToString(), Structures[s]);
        List<int> tk = new List<int>(Terrain.Keys); tk.Sort();
        foreach (int k in tk) ini.Set("Terrain", k.ToString(), Terrain[k]);
        ini.SetPack("IsoMapPack5", Pack.PackData(IsoMap.Encode(tiles), true, 8192 / 11 * 11));
        ini.SetPack("OverlayPack", Pack.PackData(Overlay, false, 8192));
        ini.SetPack("OverlayDataPack", Pack.PackData(OverlayData, false, 8192));
        return ini.Write();
    }

    // Debug picture of cell kinds in screen layout (1 px = 12x12 screen px), arcs in white.
    public Bitmap DebugImage()
    {
        int bw = 2 * W, bh = 2 * H;
        int[] buf = new int[bw * bh];
        int[] pal = { Color.FromArgb(70, 140, 60).ToArgb(), Color.FromArgb(210, 190, 80).ToArgb(), Color.FromArgb(110, 70, 30).ToArgb(), Color.FromArgb(40, 80, 200).ToArgb(), Color.FromArgb(200, 40, 200).ToArgb() };
        for (int y = 0; y < N; y++) for (int x = 0; x < N; x++)
        {
            int i = Idx(x, y); if (!Valid[i]) continue;
            int dx, dy; ToScreen(x, y, out dx, out dy);
            int col = pal[(int)K[i]];
            if (Used[i] && K[i] != Kind.Water) col = Color.FromArgb(255, 255, 255).ToArgb();
            if (!Visible[i]) col = Color.FromArgb(Color.FromArgb(col).R / 3, Color.FromArgb(col).G / 3, Color.FromArgb(col).B / 3).ToArgb();
            for (int yy = dy; yy <= dy + 1 && yy < bh; yy++) for (int xx = dx; xx <= dx + 1 && xx < bw; xx++) buf[yy * bw + xx] = col;
        }
        foreach (List<int> arc in DebugArcs)
            foreach (int i in arc) { int dx, dy; ToScreen(i % N, i / N, out dx, out dy); if (dy < bh && dx < bw) buf[dy * bw + dx] = Color.Red.ToArgb(); }
        Bitmap b = Img.FromBuffer(buf, bw, bh);
        Bitmap big = new Bitmap(bw * 4, bh * 2);
        using (Graphics g = Graphics.FromImage(big)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor; g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half; g.DrawImage(b, 0, 0, big.Width, big.Height); }
        b.Dispose();
        return big;
    }
}
