// Minimal read-only CASC reader for a local StarCraft: Remastered install.
// C# 5 so it compiles with PowerShell 5.1 Add-Type (no .NET SDK needed).
// Supports: .build.info -> build config -> encoding -> text root ("path|ckey"), v7 .idx, BLTE (N/Z chunks).
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;

public class Casc
{
    string dataDir;
    Dictionary<string, long[]> index = new Dictionary<string, long[]>(); // ekey9 hex -> [archive, offset, size]
    Dictionary<string, string> ckeyToEkey = new Dictionary<string, string>();
    public Dictionary<string, string> Root = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase); // path -> ckey hex
    public string RootRaw;

    public Casc(string installDir)
    {
        dataDir = Path.Combine(installDir, "Data");
        string buildKey = null;
        string[] info = File.ReadAllLines(Path.Combine(installDir, ".build.info"));
        string[] cols = info[0].Split('|');
        for (int i = 1; i < info.Length; i++)
        {
            string[] v = info[i].Split('|');
            if (v.Length < cols.Length) continue;
            for (int c = 0; c < cols.Length; c++)
                if (cols[c].StartsWith("Build Key") && v[1] == "1") buildKey = v[c];
        }
        string cfgPath = Path.Combine(dataDir, "config", buildKey.Substring(0, 2), buildKey.Substring(2, 2), buildKey);
        Dictionary<string, string> cfg = new Dictionary<string, string>();
        foreach (string line in File.ReadAllLines(cfgPath))
        {
            int eq = line.IndexOf(" = ");
            if (eq > 0) cfg[line.Substring(0, eq)] = line.Substring(eq + 3);
        }
        LoadIndices();
        string[] enc = cfg["encoding"].Split(' ');
        ParseEncoding(ReadByEkey(enc[1]));
        byte[] root = ReadByCkey(cfg["root"]);
        RootRaw = Encoding.UTF8.GetString(root);
        foreach (string line in RootRaw.Split('\n'))
        {
            string l = line.Trim('\r');
            int bar = l.LastIndexOf('|');
            if (bar > 0) Root[l.Substring(0, bar)] = l.Substring(bar + 1).ToLowerInvariant();
        }
    }

    void LoadIndices()
    {
        Dictionary<int, string> latest = new Dictionary<int, string>();
        foreach (string f in Directory.GetFiles(Path.Combine(dataDir, "data"), "*.idx"))
        {
            string n = Path.GetFileNameWithoutExtension(f);
            int bucket = Convert.ToInt32(n.Substring(0, 2), 16);
            if (!latest.ContainsKey(bucket) || string.CompareOrdinal(Path.GetFileName(f), Path.GetFileName(latest[bucket])) > 0)
                latest[bucket] = f;
        }
        foreach (string f in latest.Values)
        {
            byte[] b = File.ReadAllBytes(f);
            int hdrSize = BitConverter.ToInt32(b, 0);
            int pos = 8 + hdrSize;
            pos = (pos + 15) & ~15;
            int entriesSize = BitConverter.ToInt32(b, pos);
            pos += 8;
            int end = pos + entriesSize;
            for (; pos + 18 <= end; pos += 18)
            {
                string key = Hex(b, pos, 9);
                long packed = 0;
                for (int i = 0; i < 5; i++) packed = (packed << 8) | b[pos + 9 + i];
                long archive = packed >> 30;
                long offset = packed & 0x3FFFFFFF;
                long size = BitConverter.ToUInt32(b, pos + 14);
                if (!index.ContainsKey(key)) index[key] = new long[] { archive, offset, size };
            }
        }
    }

    void ParseEncoding(byte[] e)
    {
        int ckeySize = e[3], ekeySize = e[4];
        int cePageSize = BE16(e, 5) * 1024;
        int cePageCount = BE32(e, 9);
        int especSize = BE32(e, 18);
        int pos = 22 + especSize;
        pos += cePageCount * 32;
        for (int p = 0; p < cePageCount; p++)
        {
            int pageStart = pos + p * cePageSize;
            int q = pageStart;
            while (q < pageStart + cePageSize)
            {
                int keyCount = e[q];
                if (keyCount == 0) break;
                string ckey = Hex(e, q + 6, ckeySize);
                string ekey = Hex(e, q + 6 + ckeySize, ekeySize);
                ckeyToEkey[ckey] = ekey;
                q += 6 + ckeySize + keyCount * ekeySize;
            }
        }
    }

    public bool Exists(string path) { return Root.ContainsKey(path); }

    public byte[] ReadFile(string path) { return ReadByCkey(Root[path]); }

    public byte[] ReadByCkey(string ckey)
    {
        string ekey;
        if (!ckeyToEkey.TryGetValue(ckey.ToLowerInvariant(), out ekey)) throw new Exception("ckey not in encoding: " + ckey);
        return ReadByEkey(ekey);
    }

    public byte[] ReadByEkey(string ekey)
    {
        long[] loc;
        if (!index.TryGetValue(ekey.Substring(0, 18).ToLowerInvariant(), out loc)) throw new Exception("ekey not in index: " + ekey);
        string file = Path.Combine(dataDir, "data", "data." + loc[0].ToString("D3"));
        byte[] raw;
        using (FileStream fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        {
            fs.Seek(loc[1] + 30, SeekOrigin.Begin);
            raw = new byte[loc[2] - 30];
            int read = 0;
            while (read < raw.Length) { int r = fs.Read(raw, read, raw.Length - read); if (r <= 0) break; read += r; }
        }
        return Blte(raw);
    }

    static byte[] Blte(byte[] d)
    {
        if (d[0] != 'B' || d[1] != 'L' || d[2] != 'T' || d[3] != 'E') throw new Exception("not BLTE");
        int headerSize = BE32(d, 4);
        MemoryStream outp = new MemoryStream();
        if (headerSize == 0)
        {
            DecodeChunk(d, 8, d.Length - 8, outp);
        }
        else
        {
            int count = (d[9] << 16) | (d[10] << 8) | d[11];
            int pos = headerSize;
            for (int i = 0; i < count; i++)
            {
                int comp = BE32(d, 12 + i * 24);
                DecodeChunk(d, pos, comp, outp);
                pos += comp;
            }
        }
        return outp.ToArray();
    }

    static void DecodeChunk(byte[] d, int pos, int len, MemoryStream outp)
    {
        char mode = (char)d[pos];
        if (mode == 'N') outp.Write(d, pos + 1, len - 1);
        else if (mode == 'Z')
        {
            // zlib: skip 2-byte header, raw deflate
            using (MemoryStream ms = new MemoryStream(d, pos + 3, len - 3))
            using (DeflateStream ds = new DeflateStream(ms, CompressionMode.Decompress))
                ds.CopyTo(outp);
        }
        else throw new Exception("unsupported BLTE chunk mode " + mode);
    }

    static int BE16(byte[] b, int p) { return (b[p] << 8) | b[p + 1]; }
    static int BE32(byte[] b, int p) { return (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3]; }
    static string Hex(byte[] b, int p, int n)
    {
        StringBuilder sb = new StringBuilder(n * 2);
        for (int i = 0; i < n; i++) sb.Append(b[p + i].ToString("x2"));
        return sb.ToString();
    }
}
