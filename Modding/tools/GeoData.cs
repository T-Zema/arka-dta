// Real-world data for map designs (see DesignToDta.cs): OpenStreetMap XML extracts
// (api.openstreetmap.org/api/0.6/map?bbox=..., max 50k nodes per request) and Terrarium elevation
// tiles (s3.amazonaws.com/elevation-tiles-prod/terrarium/z/x/y.png), projected into the design
// pixels of a north-up Web Mercator screenshot (Google Maps, OSM) by a fitted scale + offset.
// C# 5. Needs DesignToDta.cs (Layer).
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Xml;

// Web Mercator (0..1, y down) -> design px: u = S*mx + BU, v = S*my + BV (one scale: the projection is conformal)
public class GeoRef
{
    public double S, BU, BV;

    public static double MercX(double lon) { return (lon + 180) / 360; }
    public static double MercY(double lat)
    {
        double r = lat * Math.PI / 180;
        return (1 - Math.Log(Math.Tan(r) + 1 / Math.Cos(r)) / Math.PI) / 2;
    }

    // least squares over control points {lat, lon, u, v}; returns RMS error in design px
    public double Fit(List<double[]> pts)
    {
        // unknowns S, BU, BV; rows: u = S*mx + BU, v = S*my + BV
        double[,] ata = new double[3, 3]; double[] atb = new double[3];
        foreach (double[] p in pts)
        {
            double mx = MercX(p[1]), my = MercY(p[0]);
            double[][] rows = { new double[] { mx, 1, 0, p[2] }, new double[] { my, 0, 1, p[3] } };
            foreach (double[] r in rows)
                for (int i = 0; i < 3; i++) { atb[i] += r[i] * r[3]; for (int j = 0; j < 3; j++) ata[i, j] += r[i] * r[j]; }
        }
        double[] x = Solve3(ata, atb);
        S = x[0]; BU = x[1]; BV = x[2];
        double e = 0;
        foreach (double[] p in pts) { double u, v; ToDesign(p[0], p[1], out u, out v); e += (u - p[2]) * (u - p[2]) + (v - p[3]) * (v - p[3]); }
        return Math.Sqrt(e / pts.Count);
    }

    static double[] Solve3(double[,] a, double[] b)
    {
        int n = 3; double[,] m = new double[n, n + 1];
        for (int i = 0; i < n; i++) { for (int j = 0; j < n; j++) m[i, j] = a[i, j]; m[i, n] = b[i]; }
        for (int c = 0; c < n; c++)
        {
            int piv = c; for (int r = c + 1; r < n; r++) if (Math.Abs(m[r, c]) > Math.Abs(m[piv, c])) piv = r;
            for (int j = 0; j <= n; j++) { double t = m[c, j]; m[c, j] = m[piv, j]; m[piv, j] = t; }
            for (int r = 0; r < n; r++)
            {
                if (r == c) continue;
                double f = m[r, c] / m[c, c];
                for (int j = c; j <= n; j++) m[r, j] -= f * m[c, j];
            }
        }
        return new double[] { m[0, n] / m[0, 0], m[1, n] / m[1, 1], m[2, n] / m[2, 2] };
    }

    public void ToDesign(double lat, double lon, out double u, out double v) { u = S * MercX(lon) + BU; v = S * MercY(lat) + BV; }

    public void ToLatLon(double u, double v, out double lat, out double lon)
    {
        double mx = (u - BU) / S, my = (v - BV) / S;
        lon = mx * 360 - 180;
        lat = Math.Atan(Math.Sinh(Math.PI * (1 - 2 * my))) * 180 / Math.PI;
    }

    // Distance (px, chamfer 3-4) from every pixel of a label layer to the nearest edge between `val` and other labels.
    public static float[] EdgeDistance(Layer m, byte val)
    {
        int w = m.W, h = m.H; float[] d = new float[w * h];
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            int i = y * w + x; bool a = m.L[i] == val, edge = false;
            if (x > 0 && (m.L[i - 1] == val) != a) edge = true;
            if (y > 0 && (m.L[i - w] == val) != a) edge = true;
            d[i] = edge ? 0 : 1e9f;
        }
        for (int pass = 0; pass < 2; pass++)
            for (int k = 0; k < w * h; k++)
            {
                int i = pass == 0 ? k : w * h - 1 - k, x = i % w, y = i / w, s = pass == 0 ? -1 : 1;
                float best = d[i];
                if (x + s >= 0 && x + s < w) best = Math.Min(best, d[i + s] + 3);
                if (y + s >= 0 && y + s < h) best = Math.Min(best, d[i + s * w] + 3);
                if (x + s >= 0 && x + s < w && y + s >= 0 && y + s < h) best = Math.Min(best, d[i + s * w + s] + 4);
                if (x - s >= 0 && x - s < w && y + s >= 0 && y + s < h) best = Math.Min(best, d[i + s * w - s] + 4);
                d[i] = best;
            }
        for (int i = 0; i < d.Length; i++) d[i] /= 3;
        return d;
    }

    // Mean distance of points {lat, lon} to the edge field (geometry of layer m); points off the layer count 30 px.
    public double EdgeError(List<double[]> pts, float[] dist, Layer m)
    {
        double e = 0;
        foreach (double[] p in pts)
        {
            double u, v; ToDesign(p[0], p[1], out u, out v);
            int x = (int)Math.Round(u) - m.U0, y = (int)Math.Round(v) - m.V0;
            e += x < 0 || y < 0 || x >= m.W || y >= m.H ? 30 : Math.Min(30, dist[y * m.W + x]);
        }
        return e / pts.Count;
    }

    // Coordinate descent on scale and offsets (scale about the design point cu, cv) to fit coastline points to the edge field.
    public double RefineToEdge(List<double[]> pts, float[] dist, Layer m, double cu, double cv)
    {
        double best = EdgeError(pts, dist, m);
        double[] steps = { 8, 4, 2, 1, 0.5, 0.25 };
        foreach (double st in steps)
            for (bool improved = true; improved; )
            {
                improved = false;
                for (int k = 0; k < 6; k++)
                {
                    double oS = S, oU = BU, oV = BV;
                    if (k < 2) { double f = 1 + (k == 0 ? 1 : -1) * st * 0.002; BU = cu - (cu - BU) * f; BV = cv - (cv - BV) * f; S *= f; }
                    else if (k < 4) BU += (k == 2 ? st : -st);
                    else BV += (k == 4 ? st : -st);
                    double e = EdgeError(pts, dist, m);
                    if (e < best - 1e-6) { best = e; improved = true; } else { S = oS; BU = oU; BV = oV; }
                }
            }
        return best;
    }

    // metres per design px at a latitude
    public double MetresPerPx(double lat) { return 40075016.686 * Math.Cos(lat * Math.PI / 180) / S; }
}

public class OsmWay
{
    public long Id;
    public List<long> Nodes = new List<long>();
    public Dictionary<string, string> Tags = new Dictionary<string, string>();
    public string Tag(string k) { string v; return Tags.TryGetValue(k, out v) ? v : null; }
}

public class Osm
{
    public Dictionary<long, double[]> Nodes = new Dictionary<long, double[]>();          // id -> lat, lon
    public Dictionary<long, Dictionary<string, string>> NodeTags = new Dictionary<long, Dictionary<string, string>>();
    public Dictionary<long, OsmWay> Ways = new Dictionary<long, OsmWay>();

    public void Load(string path)
    {
        XmlReaderSettings s = new XmlReaderSettings(); s.IgnoreWhitespace = true;
        using (XmlReader r = XmlReader.Create(path, s))
        {
            Dictionary<string, string> tags = null; OsmWay way = null;
            while (r.Read())
            {
                if (r.NodeType == XmlNodeType.Element)
                {
                    if (r.Name == "node")
                    {
                        long id = long.Parse(r.GetAttribute("id"));
                        Nodes[id] = new double[] { double.Parse(r.GetAttribute("lat"), CultureInfo.InvariantCulture), double.Parse(r.GetAttribute("lon"), CultureInfo.InvariantCulture) };
                        way = null;
                        if (!r.IsEmptyElement) { tags = new Dictionary<string, string>(); NodeTags[id] = tags; } else tags = null;
                    }
                    else if (r.Name == "way")
                    {
                        way = new OsmWay(); way.Id = long.Parse(r.GetAttribute("id"));
                        tags = way.Tags; Ways[way.Id] = way;
                    }
                    else if (r.Name == "relation") { way = null; tags = null; }
                    else if (r.Name == "nd" && way != null) way.Nodes.Add(long.Parse(r.GetAttribute("ref")));
                    else if (r.Name == "tag" && tags != null) tags[r.GetAttribute("k")] = r.GetAttribute("v");
                }
            }
        }
    }

    // way geometry in design px (nodes missing from the extract are skipped)
    public double[] Design(OsmWay w, GeoRef g)
    {
        List<double> p = new List<double>();
        foreach (long n in w.Nodes)
        {
            double[] ll; if (!Nodes.TryGetValue(n, out ll)) continue;
            double u, v; g.ToDesign(ll[0], ll[1], out u, out v); p.Add(u); p.Add(v);
        }
        return p.ToArray();
    }

    public double[] Centre(OsmWay w)
    {
        double la = 0, lo = 0; int c = 0;
        foreach (long n in w.Nodes) { double[] ll; if (Nodes.TryGetValue(n, out ll)) { la += ll[0]; lo += ll[1]; c++; } }
        return c == 0 ? null : new double[] { la / c, lo / c };
    }

    // Road network from selected ways: chains of nodes between junctions (node degree != 2), so roads cut by OSM
    // into many short ways become one polyline each. Junction node ids go to `junctions`.
    public List<List<long>> Chains(List<OsmWay> ways, List<long> junctions)
    {
        Dictionary<long, List<long>> adj = new Dictionary<long, List<long>>();
        foreach (OsmWay w in ways)
            for (int k = 0; k + 1 < w.Nodes.Count; k++)
            {
                long a = w.Nodes[k], b = w.Nodes[k + 1];
                if (a == b || !Nodes.ContainsKey(a) || !Nodes.ContainsKey(b)) continue;
                List<long> l;
                if (!adj.TryGetValue(a, out l)) { l = new List<long>(); adj[a] = l; } if (!l.Contains(b)) l.Add(b);
                if (!adj.TryGetValue(b, out l)) { l = new List<long>(); adj[b] = l; } if (!l.Contains(a)) l.Add(a);
            }
        HashSet<string> seen = new HashSet<string>();   // undirected edges
        List<List<long>> res = new List<List<long>>();
        foreach (KeyValuePair<long, List<long>> kv in adj)
        {
            if (kv.Value.Count == 2) continue;
            junctions.Add(kv.Key);
            foreach (long nb in kv.Value)
            {
                List<long> chain = new List<long>(); chain.Add(kv.Key);
                long prev = kv.Key, cur = nb;
                if (!seen.Add(EdgeKey(prev, cur))) continue;
                while (true)
                {
                    chain.Add(cur);
                    List<long> next = adj[cur];
                    if (next.Count != 2) break;
                    long nx = next[0] == prev ? next[1] : next[0];
                    if (!seen.Add(EdgeKey(cur, nx))) break;
                    prev = cur; cur = nx;
                }
                res.Add(chain);
            }
        }
        return res;
    }

    static string EdgeKey(long a, long b) { return a < b ? a + ":" + b : b + ":" + a; }

    public double[] DesignNodes(List<long> ids, GeoRef g)
    {
        List<double> p = new List<double>();
        foreach (long n in ids) { double[] ll = Nodes[n]; double u, v; g.ToDesign(ll[0], ll[1], out u, out v); p.Add(u); p.Add(v); }
        return p.ToArray();
    }

    // Closed ways whose tag `key` has one of `values` ("*" = any value) are filled into the layer; returns count.
    public int FillAreas(Layer l, GeoRef g, string key, string values, byte val, byte only)
    {
        HashSet<string> vs = new HashSet<string>(values.Split(','));
        int n = 0;
        foreach (OsmWay w in Ways.Values)
        {
            string v = w.Tag(key);
            if (v == null || !(vs.Contains("*") || vs.Contains(v))) continue;
            if (w.Nodes.Count < 4 || w.Nodes[0] != w.Nodes[w.Nodes.Count - 1]) continue;
            double[] p = Design(w, g);
            if (p.Length < 6) continue;
            l.Polygon(p, val, only); n++;
        }
        return n;
    }

    // Ways with a tag value (e.g. highway=primary,secondary): the list for Chains()
    public List<OsmWay> Select(string key, string values)
    {
        HashSet<string> vs = new HashSet<string>(values.Split(','));
        List<OsmWay> res = new List<OsmWay>();
        foreach (OsmWay w in Ways.Values) { string v = w.Tag(key); if (v != null && (vs.Contains("*") || vs.Contains(v))) res.Add(w); }
        return res;
    }

    // Nodes and closed-way centres with a tag value: {lat, lon} (e.g. man_made=lighthouse)
    public List<double[]> Points(string key, string value)
    {
        List<double[]> res = new List<double[]>();
        foreach (KeyValuePair<long, Dictionary<string, string>> kv in NodeTags) { string v; if (kv.Value.TryGetValue(key, out v) && v == value) res.Add(Nodes[kv.Key]); }
        foreach (OsmWay w in Ways.Values) if (w.Tag(key) == value) { double[] c = Centre(w); if (c != null) res.Add(c); }
        return res;
    }

    // named features (nodes and way centres) whose name contains the text: {lat, lon}
    public List<double[]> Find(string name)
    {
        List<double[]> res = new List<double[]>();
        foreach (KeyValuePair<long, Dictionary<string, string>> kv in NodeTags)
        {
            string v; if (kv.Value.TryGetValue("name", out v) && v.IndexOf(name, StringComparison.OrdinalIgnoreCase) >= 0) res.Add(Nodes[kv.Key]);
        }
        foreach (OsmWay w in Ways.Values)
        {
            string v = w.Tag("name"); if (v != null && v.IndexOf(name, StringComparison.OrdinalIgnoreCase) >= 0) { double[] c = Centre(w); if (c != null) res.Add(c); }
        }
        return res;
    }
}

// Terrarium tiles: elevation = R*256 + G + B/256 - 32768 metres (sea floor negative)
public class Dem
{
    public string Dir; public int Z;
    Dictionary<string, int[]> cache = new Dictionary<string, int[]>();

    public Dem(string dir, int z) { Dir = dir; Z = z; }

    double Px(int tx, int ty, int x, int y)
    {
        while (x < 0) { x += 256; tx--; } while (x > 255) { x -= 256; tx++; }
        while (y < 0) { y += 256; ty--; } while (y > 255) { y -= 256; ty++; }
        string key = tx + "_" + ty;
        int[] px;
        if (!cache.TryGetValue(key, out px))
        {
            string f = Path.Combine(Dir, key + ".png");
            px = null;
            if (File.Exists(f)) using (Bitmap b = new Bitmap(f)) px = Layer.Pixels(b);
            cache[key] = px;
        }
        if (px == null) return 0;
        Color c = Color.FromArgb(px[y * 256 + x]);
        return c.R * 256 + c.G + c.B / 256.0 - 32768;
    }

    public double Elevation(double lat, double lon)
    {
        double n = Math.Pow(2, Z);
        double fx = GeoRef.MercX(lon) * n * 256 - 0.5, fy = GeoRef.MercY(lat) * n * 256 - 0.5;
        int x0 = (int)Math.Floor(fx), y0 = (int)Math.Floor(fy);
        double ax = fx - x0, ay = fy - y0;
        int tx = x0 >> 8, ty = y0 >> 8, px = x0 & 255, py = y0 & 255;
        double e00 = Px(tx, ty, px, py), e10 = Px(tx, ty, px + 1, py), e01 = Px(tx, ty, px, py + 1), e11 = Px(tx, ty, px + 1, py + 1);
        return (e00 * (1 - ax) + e10 * ax) * (1 - ay) + (e01 * (1 - ax) + e11 * ax) * ay;
    }

    // elevation in metres for every pixel of a layer geometry (u0, v0, w, h)
    public float[] Grid(GeoRef g, int u0, int v0, int w, int h)
    {
        float[] e = new float[w * h];
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            double lat, lon; g.ToLatLon(u0 + x + 0.5, v0 + y + 0.5, out lat, out lon);
            e[y * w + x] = (float)Elevation(lat, lon);
        }
        return e;
    }
}
